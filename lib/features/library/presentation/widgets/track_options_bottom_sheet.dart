import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../data/models/local_track.dart';
import '../../../../providers/audio_player_provider.dart';
import '../../../../providers/favorites_provider.dart';
import '../../../../providers/music_library_provider.dart';
import '../../../../shared/widgets/album_art.dart';
import '../../../player/presentation/now_playing_screen.dart';
import '../../../lyrics/presentation/lyrics_screen.dart';

/// Spotify-style long-press action menu for a track.
class TrackOptionsBottomSheet extends ConsumerWidget {
  final LocalTrack track;

  const TrackOptionsBottomSheet({super.key, required this.track});

  static void show(BuildContext context, LocalTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      isScrollControlled: true,
      builder: (context) => TrackOptionsBottomSheet(track: track),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController(text: track.title);
    final artistController = TextEditingController(text: track.artist);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Text(
          'Edit Track Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Song Title',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Artist',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newArtist = artistController.text.trim();
              if (newTitle.isNotEmpty) {
                ref
                    .read(musicLibraryProvider.notifier)
                    .updateTrackInfo(
                      track.id,
                      newTitle: newTitle,
                      newArtist: newArtist.isEmpty
                          ? 'Unknown Artist'
                          : newArtist,
                    );
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Track updated'),
                  backgroundColor: Color(0xFF333333),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Text(
          'Delete from Library?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove "${track.title}" from your library index?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              ref.read(musicLibraryProvider.notifier).deleteTrack(track.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${track.title}"'),
                  backgroundColor: const Color(0xFF333333),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.contains(track.id);
    final playerNotifier = ref.read(audioPlaybackProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center top drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Track Header
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: AlbumArt(
                      artPath: track.albumArtPath,
                      artworkBytes: track.albumArtBytes,
                      size: 52,
                      format: track.format,
                      showVinylGrooves: false,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${track.artist} • ${track.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 8),

            // Option 1: Play Next
            _OptionTile(
              icon: Icons.playlist_play_rounded,
              title: 'Play Next',
              onTap: () {
                Navigator.pop(context);
                playerNotifier.playNextInQueue(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Will play next: ${track.title}'),
                    backgroundColor: const Color(0xFF333333),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Option 2: Add to Queue
            _OptionTile(
              icon: Icons.queue_music_rounded,
              title: 'Add to Queue',
              onTap: () {
                Navigator.pop(context);
                playerNotifier.addToQueue(track);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added to queue: ${track.title}'),
                    backgroundColor: const Color(0xFF333333),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Option: View Canvas Fullscreen
            _OptionTile(
              icon: Icons.fullscreen_rounded,
              title: 'View Canvas Fullscreen',
              onTap: () {
                Navigator.pop(context);
                NowPlayingScreen.open(context, fullscreenCanvas: true);
              },
            ),

            // Option: Lyrics
            _OptionTile(
              icon: Icons.lyrics_rounded,
              title: 'Lyrics',
              onTap: () {
                Navigator.pop(context);
                LyricsScreen.open(context);
              },
            ),

            // Option 3: Add to Favorites / Favorite
            _OptionTile(
              icon: isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: isFav ? AppColors.accent : Colors.white,
              title: isFav ? 'Remove from Favorites' : 'Add to Favorites',
              onTap: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(track.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFav ? 'Removed from Favorites' : 'Added to Favorites',
                    ),
                    backgroundColor: const Color(0xFF333333),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            // Option 4: Edit Track Info
            _OptionTile(
              icon: Icons.edit_outlined,
              title: 'Edit Track Info',
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, ref);
              },
            ),

            // Option 5: View Details
            _OptionTile(
              icon: Icons.info_outline_rounded,
              title: 'Track Details',
              onTap: () {
                Navigator.pop(context);
                _showDetailsDialog(context);
              },
            ),

            // Option 6: Delete Track
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              iconColor: AppColors.accent,
              title: 'Delete from Library',
              titleColor: AppColors.accent,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Text(
          'Track Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('File Name', track.fileName),
            _detailRow('Format', track.format),
            _detailRow('Duration', track.formattedDuration),
            _detailRow('Size', track.formattedSize),
            _detailRow('Album', track.album),
            _detailRow('Artist', track.artist),
            _detailRow('Path', track.relativePath),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    this.iconColor = Colors.white,
    required this.title,
    this.titleColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
      onTap: onTap,
    );
  }
}
