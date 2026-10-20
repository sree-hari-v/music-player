import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../models/local_track.dart';
import '../models/music_folder.dart';
import '../services/audio_metadata_service.dart';
import '../services/saf_folder_service.dart';
import '../services/track_cache_service.dart';

/// Progress emitted during a library scan.
class ScanProgressUpdate {
  final List<LocalTrack> tracks;
  final String? currentFileName;
  final int discoveredCount;
  final bool isComplete;
  final AppException? error;

  const ScanProgressUpdate({
    required this.tracks,
    this.currentFileName,
    required this.discoveredCount,
    this.isComplete = false,
    this.error,
  });
}

/// Repository interface for music library scanning and folder persistence.
abstract class MusicLibraryRepository {
  Future<MusicFolder?> getSavedFolder();
  Future<void> saveFolder(MusicFolder folder);
  Future<void> clearSavedFolder();
  Future<bool> checkPermissionValid(String folderUri);
  Stream<ScanProgressUpdate> scanFolder(
    String folderUri, {
    List<LocalTrack>? initialTracks,
  });
  Future<MusicFolder?> pickFolder();
  Future<List<LocalTrack>> loadCachedTracks() async => const [];
  Future<void> saveCachedTracks(List<LocalTrack> tracks) async {}
}

/// Concrete implementation of [MusicLibraryRepository].
class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  final SafFolderService _safService;
  final AudioMetadataService _metadataService;
  final TrackCacheService _cacheService;
  final SharedPreferences? prefs;

  bool _isScanning = false;

  MusicLibraryRepositoryImpl({
    SafFolderService? safService,
    AudioMetadataService? metadataService,
    TrackCacheService? cacheService,
    this.prefs,
  }) : _safService = safService ?? SafFolderService(),
       _metadataService = metadataService ?? AudioMetadataService(),
       _cacheService = cacheService ?? TrackCacheService();

  Future<SharedPreferences> _getPrefs() async {
    return prefs ?? await SharedPreferences.getInstance();
  }

  @override
  Future<List<LocalTrack>> loadCachedTracks() async {
    return await _cacheService.loadCachedTracks();
  }

  @override
  Future<void> saveCachedTracks(List<LocalTrack> tracks) async {
    await _cacheService.saveCachedTracks(tracks);
  }

  @override
  Future<MusicFolder?> getSavedFolder() async {
    try {
      final prefs = await _getPrefs();
      final uri = prefs.getString(AppConstants.keyFolderUri);
      final name = prefs.getString(AppConstants.keyFolderName);

      if (uri == null || uri.isEmpty) {
        return null;
      }

      // Verify whether the persisted permission is still held (single IPC check)
      final hasPermission = await _safService.hasPersistedPermission(uri);

      return MusicFolder(
        uri: uri,
        name: name ?? 'Music',
        hasValidPermission: hasPermission,
      );
    } catch (e) {
      debugPrint('MusicLibraryRepository: Error retrieving saved folder: $e');
      return null;
    }
  }

  @override
  Future<void> saveFolder(MusicFolder folder) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.keyFolderUri, folder.uri);
    await prefs.setString(AppConstants.keyFolderName, folder.name);
    await prefs.setString(
      AppConstants.keyLastScannedTime,
      DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> clearSavedFolder() async {
    final prefs = await _getPrefs();
    final uri = prefs.getString(AppConstants.keyFolderUri);
    if (uri != null) {
      await _safService.releasePermission(uri);
    }
    await prefs.remove(AppConstants.keyFolderUri);
    await prefs.remove(AppConstants.keyFolderName);
    await prefs.remove(AppConstants.keyLastScannedTime);
    await _cacheService.clearCache();
  }

  @override
  Future<bool> checkPermissionValid(String folderUri) async {
    return await _safService.hasPersistedPermission(folderUri);
  }

  @override
  Future<MusicFolder?> pickFolder() async {
    final picked = await _safService.pickFolder();
    if (picked == null) {
      return null; // User cancelled picker
    }

    final folder = MusicFolder(
      uri: picked.uri,
      name: picked.name.isNotEmpty ? picked.name : 'Music',
      hasValidPermission: true,
    );

    await saveFolder(folder);
    return folder;
  }

  @override
  Stream<ScanProgressUpdate> scanFolder(
    String folderUri, {
    List<LocalTrack>? initialTracks,
  }) async* {
    if (_isScanning) {
      debugPrint(
        'MusicLibraryRepository: Scan already in progress, ignoring duplicate call',
      );
      return;
    }

    _isScanning = true;
    final trackMap = <String, LocalTrack>{};

    // Prepopulate with any cached tracks so existing tracks are never lost
    if (initialTracks != null && initialTracks.isNotEmpty) {
      for (final track in initialTracks) {
        trackMap[track.id] = track;
      }
    }

    try {
      // Check permission first
      final hasPerm = await _safService.hasPersistedPermission(folderUri);
      if (!hasPerm) {
        yield ScanProgressUpdate(
          tracks: List<LocalTrack>.unmodifiable(trackMap.values),
          discoveredCount: trackMap.length,
          isComplete: true,
          error: const FolderPermissionException(
            'Storage permission for this folder has been revoked or expired. Please reselect your music folder.',
          ),
        );
        return;
      }

      var discoveredCount = trackMap.length;
      var newFilesDiscovered = 0;

      await for (final entry in _safService.discoverAudioFiles(folderUri)) {
        // If track is already in map and lastModified hasn't changed, skip extracting metadata again!
        final existing = trackMap[entry.file.uri];
        if (existing != null &&
            existing.fileSizeBytes == entry.file.length &&
            existing.lastModified.millisecondsSinceEpoch ==
                entry.file.lastModified) {
          continue;
        }

        discoveredCount++;
        newFilesDiscovered++;
        final track = await _metadataService.extractMetadata(entry);

        // Deduplicate using track id (URI)
        trackMap[track.id] = track;

        // Batch notifications every 16 tracks to prevent UI thread lockup and continuous rebuilds
        if (newFilesDiscovered % 16 == 0) {
          yield ScanProgressUpdate(
            tracks: List<LocalTrack>.unmodifiable(trackMap.values),
            currentFileName: entry.file.name,
            discoveredCount: discoveredCount,
            isComplete: false,
          );
        }
      }

      final finalList = List<LocalTrack>.unmodifiable(trackMap.values);
      // Persist to cache
      await _cacheService.saveCachedTracks(finalList);

      yield ScanProgressUpdate(
        tracks: finalList,
        currentFileName: null,
        discoveredCount: finalList.length,
        isComplete: true,
      );
    } catch (e) {
      debugPrint('MusicLibraryRepository: Error scanning folder: $e');
      yield ScanProgressUpdate(
        tracks: List<LocalTrack>.unmodifiable(trackMap.values),
        discoveredCount: trackMap.length,
        isComplete: true,
        error: LibraryScanException(
          'An error occurred while scanning the music folder: $e',
          e,
        ),
      );
    } finally {
      _isScanning = false;
    }
  }
}
