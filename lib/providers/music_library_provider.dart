import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/local_track.dart';
import '../data/models/music_folder.dart';
import '../data/repositories/music_library_repository.dart';

enum MusicLibraryStatus {
  initial,
  noFolderSelected,
  scanning,
  loaded,
  empty,
  permissionRevoked,
  error,
}

enum SortOption { title, artist, album, duration, dateAdded }

/// Represents an aggregated album in the library.
class AlbumSummary {
  final String name;
  final String artist;
  final int trackCount;
  final LocalTrack sampleTrack;

  const AlbumSummary({
    required this.name,
    required this.artist,
    required this.trackCount,
    required this.sampleTrack,
  });
}

/// Represents an aggregated artist in the library.
class ArtistSummary {
  final String name;
  final int trackCount;
  final int albumCount;
  final LocalTrack sampleTrack;

  const ArtistSummary({
    required this.name,
    required this.trackCount,
    required this.albumCount,
    required this.sampleTrack,
  });
}

/// State for the Music Library.
class MusicLibraryState {
  final MusicLibraryStatus status;
  final MusicFolder? folder;
  final List<LocalTrack> tracks;
  final int discoveredCount;
  final String? currentScanningFile;
  final String? errorMessage;
  final SortOption sortOption;
  final bool sortAscending;
  final String searchQuery;
  final String selectedCategory; // 'all', 'songs', 'artists', 'albums'
  final bool isBackgroundSyncing;

  const MusicLibraryState({
    this.status = MusicLibraryStatus.initial,
    this.folder,
    this.tracks = const [],
    this.discoveredCount = 0,
    this.currentScanningFile,
    this.errorMessage,
    this.sortOption = SortOption.title,
    this.sortAscending = true,
    this.searchQuery = '',
    this.selectedCategory = 'all',
    this.isBackgroundSyncing = false,
  });

  MusicLibraryState copyWith({
    MusicLibraryStatus? status,
    MusicFolder? folder,
    List<LocalTrack>? tracks,
    int? discoveredCount,
    String? currentScanningFile,
    String? errorMessage,
    SortOption? sortOption,
    bool? sortAscending,
    String? searchQuery,
    String? selectedCategory,
    bool? isBackgroundSyncing,
    bool clearCurrentScanningFile = false,
  }) {
    return MusicLibraryState(
      status: status ?? this.status,
      folder: folder ?? this.folder,
      tracks: tracks ?? this.tracks,
      discoveredCount: discoveredCount ?? this.discoveredCount,
      currentScanningFile: clearCurrentScanningFile
          ? null
          : (currentScanningFile ?? this.currentScanningFile),
      errorMessage: errorMessage ?? this.errorMessage,
      sortOption: sortOption ?? this.sortOption,
      sortAscending: sortAscending ?? this.sortAscending,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isBackgroundSyncing: isBackgroundSyncing ?? this.isBackgroundSyncing,
    );
  }
}

/// SharedPreferences provider for instant synchronous preferences access.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// MusicLibraryRepository provider.
final musicLibraryRepositoryProvider = Provider<MusicLibraryRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return MusicLibraryRepositoryImpl(prefs: prefs);
});

/// MusicLibraryNotifier provider.
final musicLibraryProvider =
    StateNotifierProvider<MusicLibraryNotifier, MusicLibraryState>((ref) {
      final repo = ref.watch(musicLibraryRepositoryProvider);
      return MusicLibraryNotifier(repo);
    });

class MusicLibraryNotifier extends StateNotifier<MusicLibraryState> {
  final MusicLibraryRepository _repository;
  StreamSubscription? _scanSubscription;

  MusicLibraryNotifier(this._repository) : super(const MusicLibraryState()) {
    init();
  }

  /// Restores saved folder and cached tracks instantly on startup.
  Future<void> init() async {
    state = state.copyWith(status: MusicLibraryStatus.initial);

    // 1. ULTRA-FAST STARTUP: Start loading cached tracks and saved folder concurrently!
    final cachedTracksFuture = _repository.loadCachedTracks();
    final savedFolder = await _repository.getSavedFolder();

    if (savedFolder == null) {
      state = state.copyWith(status: MusicLibraryStatus.noFolderSelected);
      return;
    }

    final cachedTracks = await cachedTracksFuture;

    if (cachedTracks.isNotEmpty) {
      // Instant render of all tracks in 0ms
      state = state.copyWith(
        folder: savedFolder,
        tracks: cachedTracks,
        discoveredCount: cachedTracks.length,
        status: MusicLibraryStatus.loaded,
      );

      if (!savedFolder.hasValidPermission) {
        state = state.copyWith(
          status: MusicLibraryStatus.permissionRevoked,
          errorMessage:
              'Permission to access "${savedFolder.name}" has expired or was revoked. Please reselect your folder.',
        );
        return;
      }

      // Delay background scan by 3 seconds so cold launch has 100% CPU for instant responsiveness!
      Timer(const Duration(seconds: 3), () {
        if (mounted && state.status == MusicLibraryStatus.loaded) {
          startBackgroundScan(savedFolder.uri);
        }
      });
    } else {
      if (!savedFolder.hasValidPermission) {
        state = state.copyWith(
          status: MusicLibraryStatus.permissionRevoked,
          folder: savedFolder,
          errorMessage:
              'Permission to access "${savedFolder.name}" has expired or was revoked. Please reselect your folder.',
        );
        return;
      }
      state = state.copyWith(folder: savedFolder);
      await startScan(savedFolder.uri);
    }
  }

  /// Prompts folder picker, persists selection, and starts scanning.
  Future<void> pickAndScanFolder() async {
    try {
      final folder = await _repository.pickFolder();
      if (folder == null) {
        return; // User cancelled picker
      }

      state = state.copyWith(
        folder: folder,
        status: MusicLibraryStatus.scanning,
        tracks: const [],
        discoveredCount: 0,
      );

      await startScan(folder.uri);
    } catch (e) {
      state = state.copyWith(
        status: MusicLibraryStatus.error,
        errorMessage: 'Failed to select folder: $e',
      );
    }
  }

  /// Non-blocking background scan: checks for new/removed audio files.
  void startBackgroundScan(String folderUri) {
    _scanSubscription?.cancel();
    state = state.copyWith(isBackgroundSyncing: true);

    _scanSubscription = _repository
        .scanFolder(folderUri, initialTracks: state.tracks)
        .listen(
          (update) {
            if (update.error != null) {
              state = state.copyWith(isBackgroundSyncing: false);
              return;
            }

            if (update.isComplete) {
              state = state.copyWith(
                tracks: update.tracks,
                discoveredCount: update.tracks.length,
                isBackgroundSyncing: false,
                clearCurrentScanningFile: true,
              );
            } else {
              state = state.copyWith(
                tracks: update.tracks,
                discoveredCount: update.discoveredCount,
                currentScanningFile: update.currentFileName,
              );
            }
          },
          onError: (_) {
            state = state.copyWith(isBackgroundSyncing: false);
          },
        );
  }

  /// Rescans the current folder.
  Future<void> rescan() async {
    final folder = state.folder;
    if (folder == null) return;
    startBackgroundScan(folder.uri);
  }

  /// Cancels any active scan and starts a new one (used when picking new folder).
  Future<void> startScan(String folderUri) async {
    await _scanSubscription?.cancel();

    state = state.copyWith(
      status: MusicLibraryStatus.scanning,
      tracks: const [],
      discoveredCount: 0,
      errorMessage: null,
      isBackgroundSyncing: true,
    );

    _scanSubscription = _repository
        .scanFolder(folderUri)
        .listen(
          (update) {
            if (update.error != null) {
              state = state.copyWith(
                status: MusicLibraryStatus.error,
                errorMessage: update.error!.message,
                clearCurrentScanningFile: true,
                isBackgroundSyncing: false,
              );
              return;
            }

            if (update.isComplete) {
              final tracks = update.tracks;
              state = state.copyWith(
                status: tracks.isEmpty
                    ? MusicLibraryStatus.empty
                    : MusicLibraryStatus.loaded,
                tracks: tracks,
                discoveredCount: tracks.length,
                clearCurrentScanningFile: true,
                isBackgroundSyncing: false,
              );
            } else {
              state = state.copyWith(
                tracks: update.tracks,
                discoveredCount: update.discoveredCount,
                currentScanningFile: update.currentFileName,
              );
            }
          },
          onError: (err) {
            state = state.copyWith(
              status: MusicLibraryStatus.error,
              errorMessage: 'Scanning encountered an error: $err',
              clearCurrentScanningFile: true,
              isBackgroundSyncing: false,
            );
          },
        );
  }

  /// Clears saved folder permission, cache, and resets state.
  Future<void> clearFolder() async {
    await _scanSubscription?.cancel();
    await _repository.clearSavedFolder();
    state = const MusicLibraryState(
      status: MusicLibraryStatus.noFolderSelected,
    );
  }

  /// Sort settings
  void setSortOption(SortOption option) {
    if (state.sortOption == option) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(sortOption: option, sortAscending: true);
    }
  }

  void toggleSortAscending() {
    state = state.copyWith(sortAscending: !state.sortAscending);
  }

  /// Search & category filter
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Updates track metadata (title and artist) and saves to cache.
  Future<void> updateTrackInfo(
    String trackId, {
    required String newTitle,
    required String newArtist,
  }) async {
    final updatedTracks = state.tracks.map((t) {
      if (t.id == trackId) {
        return t.copyWith(title: newTitle, artist: newArtist);
      }
      return t;
    }).toList();

    state = state.copyWith(tracks: updatedTracks);
    await _repository.saveCachedTracks(updatedTracks);
  }

  /// Removes track from the active library and updates cache.
  Future<void> deleteTrack(String trackId) async {
    final updatedTracks = state.tracks.where((t) => t.id != trackId).toList();
    state = state.copyWith(
      tracks: updatedTracks,
      discoveredCount: updatedTracks.length,
    );
    await _repository.saveCachedTracks(updatedTracks);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for sorted tracks based on current sort criteria.
final sortedTracksProvider = Provider<List<LocalTrack>>((ref) {
  final tracks = ref.watch(musicLibraryProvider.select((s) => s.tracks));
  if (tracks.isEmpty) return const [];

  final sortOption = ref.watch(
    musicLibraryProvider.select((s) => s.sortOption),
  );
  final sortAscending = ref.watch(
    musicLibraryProvider.select((s) => s.sortAscending),
  );

  final sortedList = List<LocalTrack>.from(tracks);

  sortedList.sort((a, b) {
    int cmp;
    switch (sortOption) {
      case SortOption.title:
        cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        break;
      case SortOption.artist:
        cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
        break;
      case SortOption.album:
        cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
        break;
      case SortOption.duration:
        final durA = a.duration?.inMilliseconds ?? 0;
        final durB = b.duration?.inMilliseconds ?? 0;
        cmp = durA.compareTo(durB);
        break;
      case SortOption.dateAdded:
        cmp = a.lastModified.compareTo(b.lastModified);
        break;
    }
    return sortAscending ? cmp : -cmp;
  });

  return sortedList;
});

/// Provider for grouped albums.
final albumsListProvider = Provider<List<AlbumSummary>>((ref) {
  final tracks = ref.watch(musicLibraryProvider.select((s) => s.tracks));
  if (tracks.isEmpty) return const [];

  final map = <String, List<LocalTrack>>{};

  for (final track in tracks) {
    map.putIfAbsent(track.album, () => []).add(track);
  }

  final summaries = map.entries.map((e) {
    final sampleWithArt = e.value.firstWhere(
      (t) => t.hasAlbumArt,
      orElse: () => e.value.first,
    );
    return AlbumSummary(
      name: e.key,
      artist: e.value.first.artist,
      trackCount: e.value.length,
      sampleTrack: sampleWithArt,
    );
  }).toList();

  summaries.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return summaries;
});

/// Provider for grouped artists.
final artistsListProvider = Provider<List<ArtistSummary>>((ref) {
  final tracks = ref.watch(musicLibraryProvider.select((s) => s.tracks));
  if (tracks.isEmpty) return const [];

  final map = <String, List<LocalTrack>>{};

  for (final track in tracks) {
    map.putIfAbsent(track.artist, () => []).add(track);
  }

  final summaries = map.entries.map((e) {
    final sampleWithArt = e.value.firstWhere(
      (t) => t.hasAlbumArt,
      orElse: () => e.value.first,
    );
    final albums = e.value.map((t) => t.album).toSet().length;
    return ArtistSummary(
      name: e.key,
      trackCount: e.value.length,
      albumCount: albums,
      sampleTrack: sampleWithArt,
    );
  }).toList();

  summaries.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return summaries;
});

/// Provider for recently added tracks (last modified descending).
final recentlyAddedTracksProvider = Provider<List<LocalTrack>>((ref) {
  final tracks = ref.watch(musicLibraryProvider.select((s) => s.tracks));
  if (tracks.isEmpty) return const [];

  final sorted = List<LocalTrack>.from(tracks)
    ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

  return sorted.take(12).toList();
});

/// Provider for search results matching title, artist, album, and file name.
final searchResultsProvider = Provider<List<LocalTrack>>((ref) {
  final query = ref.watch(
    musicLibraryProvider.select((s) => s.searchQuery.trim().toLowerCase()),
  );
  if (query.isEmpty) {
    return const [];
  }

  final tracks = ref.watch(musicLibraryProvider.select((s) => s.tracks));

  return tracks.where((track) {
    return track.title.toLowerCase().contains(query) ||
        track.artist.toLowerCase().contains(query) ||
        track.album.toLowerCase().contains(query) ||
        track.fileName.toLowerCase().contains(query);
  }).toList();
});
