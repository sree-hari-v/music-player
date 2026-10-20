import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/local_track.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/music_library_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../shared/widgets/album_art.dart';
import '../../folder_picker/presentation/folder_selection_screen.dart';
import '../../player/presentation/now_playing_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'all_songs_folder_screen.dart';

/// Spotify-identical Home Screen with time-based greetings, 6-grid quick jump tiles, and horizontal carousels.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    final albums = ref.watch(albumsListProvider);
    final artists = ref.watch(artistsListProvider);
    final recentlyAdded = ref.watch(recentlyAddedTracksProvider);
    final allTracks = ref.watch(sortedTracksProvider);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    // Initial first-time folder picker
    if (libraryState.status == MusicLibraryStatus.noFolderSelected) {
      return const FolderSelectionScreen();
    }

    if (libraryState.status == MusicLibraryStatus.permissionRevoked) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.accent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Folder Access Expired',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    libraryState.errorMessage ??
                        'Permission to access your music folder has expired.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => notifier.pickAndScanFolder(),
                    child: const Text(
                      'Reselect Music Folder',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Only show full loading if there are ZERO tracks cached and we are scanning
    if (libraryState.status == MusicLibraryStatus.scanning &&
        libraryState.tracks.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
              const SizedBox(height: 20),
              const Text(
                'Scanning your music collection...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${libraryState.discoveredCount} tracks discovered so far',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Quick jump items for top 6-grid (first 6 tracks or albums)
    final quickItems = allTracks.take(6).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Spotify Top Bar
          SliverAppBar(
            floating: true,
            pinned: false,
            backgroundColor: AppColors.background,
            title: Text(
              _getGreeting(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
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
                tooltip: 'Scan Folder in Background',
                onPressed: () => notifier.rescan(),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Content Body
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!notificationsEnabled) _buildNotificationAlertBanner(ref),

                // Filter Pills (All, Music, Lossless)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildPill(label: 'All', isSelected: true),
                      const SizedBox(width: 8),
                      _buildPill(label: 'Music', isSelected: false),
                      const SizedBox(width: 8),
                      _buildPill(label: 'Lossless', isSelected: false),
                      const Spacer(),
                      // Folder info pill
                      InkWell(
                        onTap: () => notifier.pickAndScanFolder(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.folder_open_rounded,
                                size: 14,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                libraryState.folder?.name ?? 'Folder',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Spotify 6-Grid Quick Access Tiles (2 columns x 3 rows)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3.2,
                    children: [
                      // Tile 1: "All Songs" Folder
                      _buildAllSongsQuickTile(context, allTracks.length),
                      // Tiles 2-6: Top Tracks
                      ...quickItems.take(5).map((track) {
                        return _buildQuickTile(track, () {
                          playbackNotifier.playTrack(track, queue: allTracks);
                          NowPlayingScreen.open(context);
                        });
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // "Your Folders & Playlists" Section
                _buildSectionHeader('Your Folders'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Folder Card 1: All Songs
                      _buildFolderCard(
                        title: 'All Songs',
                        subtitle: '${allTracks.length} songs • Offline',
                        icon: Icons.folder_special_rounded,
                        isPrimary: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AllSongsFolderScreen(),
                            ),
                          );
                        },
                      ),
                      // Folder Card 2: Current Storage Folder
                      _buildFolderCard(
                        title: libraryState.folder?.name ?? 'Storage Folder',
                        subtitle: 'Root Audio Folder',
                        icon: Icons.folder_rounded,
                        isPrimary: false,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AllSongsFolderScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // "Recently added" Carousel
                if (recentlyAdded.isNotEmpty) ...[
                  _buildSectionHeader('Recently added'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: recentlyAdded.length,
                      itemBuilder: (context, index) {
                        final track = recentlyAdded[index];
                        return _buildMediaCard(
                          title: track.title,
                          subtitle: track.artist,
                          artPath: track.albumArtPath,
                          artworkBytes: track.albumArtBytes,
                          format: track.format,
                          onTap: () {
                            playbackNotifier.playTrack(
                              track,
                              queue: recentlyAdded,
                            );
                            NowPlayingScreen.open(context);
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // "Albums in your collection" Carousel
                if (albums.isNotEmpty) ...[
                  _buildSectionHeader('Albums in your library'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return _buildMediaCard(
                          title: album.name,
                          subtitle: '${album.artist} • ${album.trackCount} trk',
                          artPath: album.sampleTrack.albumArtPath,
                          artworkBytes: album.sampleTrack.albumArtBytes,
                          format: album.sampleTrack.format,
                          onTap: () {
                            // Find all tracks in this album and play first
                            final albumTracks = allTracks
                                .where((t) => t.album == album.name)
                                .toList();
                            if (albumTracks.isNotEmpty) {
                              playbackNotifier.playTrack(
                                albumTracks.first,
                                queue: albumTracks,
                              );
                              NowPlayingScreen.open(context);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // "Artists" Circle Carousel
                if (artists.isNotEmpty) ...[
                  _buildSectionHeader('Artists'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: artists.length,
                      itemBuilder: (context, index) {
                        final artist = artists[index];
                        return Container(
                          width: 124,
                          margin: const EdgeInsets.only(right: 14),
                          child: InkWell(
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
                            child: Column(
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 104,
                                    height: 104,
                                    child: AlbumArt(
                                      artPath: artist.sampleTrack.albumArtPath,
                                      artworkBytes:
                                          artist.sampleTrack.albumArtBytes,
                                      size: 104,
                                      format: artist.sampleTrack.format,
                                      showVinylGrooves: false,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  artist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Artist',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 80), // Padding above bottom nav
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({required String label, required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accent : const Color(0xFF242424),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAllSongsQuickTile(BuildContext context, int totalCount) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AllSongsFolderScreen()));
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderSubtle, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.folder_special_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Songs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$totalCount tracks',
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTile(LocalTrack track, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderSubtle, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: AlbumArt(
                artPath: track.albumArtPath,
                artworkBytes: track.albumArtBytes,
                size: 56,
                format: track.format,
                showVinylGrooves: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _buildMediaCard({
    required String title,
    required String subtitle,
    String? artPath,
    required dynamic artworkBytes,
    required String format,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 140,
                height: 140,
                child: AlbumArt(
                  artPath: artPath,
                  artworkBytes: artworkBytes,
                  size: 140,
                  format: format,
                  showVinylGrooves: false,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPrimary
                      ? [const Color(0xFFE50914), const Color(0xFF6B0000)]
                      : [const Color(0xFF161616), const Color(0xFF040404)],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isPrimary
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : AppColors.borderSubtle,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 52,
                  color: isPrimary ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationAlertBanner(WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_rounded,
            color: AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Playback notification is disabled. Turn on in device settings for lock screen & panel controls.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
