import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/local_track.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/music_library_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../shared/widgets/album_art.dart';
import '../../../shared/widgets/alphabet_fast_scroller.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../player/presentation/now_playing_screen.dart';
import 'widgets/track_tile.dart';

/// Screen presenting the full offline music library with Spotify tabs and instant playback.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _songsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _songsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    final sortedTracks = ref.watch(sortedTracksProvider);
    final albums = ref.watch(albumsListProvider);
    final artists = ref.watch(artistsListProvider);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    if (libraryState.status == MusicLibraryStatus.empty ||
        (libraryState.tracks.isEmpty &&
            libraryState.status != MusicLibraryStatus.scanning)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Your Library')),
        body: EmptyState(
          icon: Icons.library_music_outlined,
          title: 'Library is Empty',
          message: 'No music files found in your selected folder. Choose a folder with audio files to populate your library.',
          buttonText: 'Choose Music Folder',
          onAction: () => notifier.pickAndScanFolder(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Your Library',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (libraryState.isBackgroundSyncing)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 18,
              height: 18,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Sync Folder in Background',
            onPressed: () => notifier.rescan(),
          ),
          IconButton(
            icon: const Icon(
              Icons.create_new_folder_outlined,
              color: Colors.white,
            ),
            tooltip: 'Change Music Folder',
            onPressed: () => notifier.pickAndScanFolder(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
          tabs: [
            Tab(text: 'Songs (${sortedTracks.length})'),
            Tab(text: 'Albums (${albums.length})'),
            Tab(text: 'Artists (${artists.length})'),
            const Tab(text: 'Folder'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!notificationsEnabled) _buildNotificationAlertBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Songs Tab
                _buildSongsTab(
                  sortedTracks,
                  libraryState,
                  notifier,
                  playbackNotifier,
                ),

                // 2. Albums Tab
                _buildAlbumsTab(albums, sortedTracks, playbackNotifier),

                // 3. Artists Tab
                _buildArtistsTab(artists, sortedTracks, playbackNotifier),

                // 4. Folder Info Tab
                _buildFolderInfoTab(libraryState, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(
    List<LocalTrack> tracks,
    MusicLibraryState state,
    MusicLibraryNotifier notifier,
    AudioPlaybackNotifier playbackNotifier,
  ) {
    return Column(
      children: [
        // Sorting Header Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const Text(
                'Sort by:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<SortOption>(
                initialValue: state.sortOption,
                onSelected: (option) => notifier.setSortOption(option),
                color: AppColors.card,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSortLabel(state.sortOption),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: SortOption.title,
                    child: Text('Title'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.artist,
                    child: Text('Artist'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.album,
                    child: Text('Album'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.duration,
                    child: Text('Duration'),
                  ),
                  const PopupMenuItem(
                    value: SortOption.dateAdded,
                    child: Text('Date Added'),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  state.sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                tooltip: state.sortAscending ? 'Ascending' : 'Descending',
                onPressed: () => notifier.toggleSortAscending(),
              ),
            ],
          ),
        ),

        // High-Performance Virtualized Songs List View with A-Z Alphabet Scroller & Quick Jump Buttons
        Expanded(
          child: AlphabetFastScroller(
            scrollController: _songsScrollController,
            tracks: tracks,
            letterSelector: (track) {
              if (state.sortOption == SortOption.artist) {
                return track.artist;
              } else if (state.sortOption == SortOption.album) {
                return track.album;
              }
              return track.title;
            },
            child: ListView.separated(
              controller: _songsScrollController,
              padding: const EdgeInsets.only(top: 4.0, bottom: 20.0, right: 24.0),
              itemCount: tracks.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0x11FFFFFF)),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return TrackTile(
                  track: track,
                  index: index + 1,
                  onTap: () {
                    playbackNotifier.playTrack(track, queue: tracks);
                    NowPlayingScreen.open(context);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsTab(
    List<AlbumSummary> albums,
    List<LocalTrack> allTracks,
    AudioPlaybackNotifier playbackNotifier,
  ) {
    if (albums.isEmpty) {
      return const EmptyState(
        icon: Icons.album_outlined,
        title: 'No Albums',
        message: 'No album metadata was detected in your library.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.76,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return InkWell(
          onTap: () {
            final albumTracks = allTracks
                .where((t) => t.album == album.name)
                .toList();
            if (albumTracks.isNotEmpty) {
              playbackNotifier.playTrack(albumTracks.first, queue: albumTracks);
              NowPlayingScreen.open(context);
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artSize = constraints.maxWidth;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AlbumArt(
                        artPath: album.sampleTrack.albumArtPath,
                        artworkBytes: album.sampleTrack.albumArtBytes,
                        size: artSize,
                        borderRadius: 6,
                        format: album.sampleTrack.format,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${album.artist} • ${album.trackCount} trk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtistsTab(
    List<ArtistSummary> artists,
    List<LocalTrack> allTracks,
    AudioPlaybackNotifier playbackNotifier,
  ) {
    if (artists.isEmpty) {
      return const EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'No Artists',
        message: 'No artist metadata was detected in your library.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
      itemCount: artists.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0x11FFFFFF)),
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          onTap: () {
            final artistTracks = allTracks
                .where((t) => t.artist == artist.name)
                .toList();
            if (artistTracks.isNotEmpty) {
              playbackNotifier.playTrack(
                artistTracks.first,
                queue: artistTracks,
              );
              NowPlayingScreen.open(context);
            }
          },
          leading: ClipOval(
            child: SizedBox(
              width: 50,
              height: 50,
              child: AlbumArt(
                artPath: artist.sampleTrack.albumArtPath,
                artworkBytes: artist.sampleTrack.albumArtBytes,
                size: 50,
                format: artist.sampleTrack.format,
              ),
            ),
          ),
          title: Text(
            artist.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          subtitle: Text(
            '${artist.trackCount} ${artist.trackCount == 1 ? 'song' : 'songs'} • ${artist.albumCount} ${artist.albumCount == 1 ? 'album' : 'albums'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(
            Icons.play_circle_filled_rounded,
            color: AppColors.accent,
            size: 28,
          ),
        );
      },
    );
  }

  Widget _buildFolderInfoTab(
    MusicLibraryState state,
    MusicLibraryNotifier notifier,
  ) {
    final folder = state.folder;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder?.name ?? 'No Folder',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'SAF Persisted Music Directory',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0x1AFFFFFF)),
                const SizedBox(height: 10),
                _buildInfoLine('Total Tracks', '${state.tracks.length}'),
                _buildInfoLine(
                  'Folder Permission',
                  folder?.hasValidPermission == true
                      ? 'Active (Auto-Persisted)'
                      : 'Expired',
                  color: folder?.hasValidPermission == true
                      ? Colors.white
                      : AppColors.error,
                ),
                _buildInfoLine(
                  'Background Sync',
                  state.isBackgroundSyncing
                      ? 'Syncing...'
                      : 'Idle / Up to Date',
                ),
                _buildInfoLine(
                  'Content URI',
                  folder?.uri ?? 'N/A',
                  isMonospace: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => notifier.rescan(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Background Sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => notifier.pickAndScanFolder(),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Change Folder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(
    String label,
    String value, {
    Color? color,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: isMonospace ? 10.5 : 12.5,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.title:
        return 'Title';
      case SortOption.artist:
        return 'Artist';
      case SortOption.album:
        return 'Album';
      case SortOption.duration:
        return 'Duration';
      case SortOption.dateAdded:
        return 'Date Added';
    }
  }

  Widget _buildNotificationAlertBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B0B0E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Playback notification is disabled in Android settings. Turn on to control music from lock screen & panel.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => ref
                .read(notificationsEnabledProvider.notifier)
                .requestPermissionOrOpenSettings(),
            child: const Text(
              'Enable',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
