import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../data/models/local_track.dart';
import '../../../../providers/audio_player_provider.dart';
import '../../../../shared/widgets/album_art.dart';
import 'track_options_bottom_sheet.dart';

/// Spotify-style dense track row with swipe-to-queue, now-playing indicator,
/// and long-press contextual options menu.
class TrackTile extends ConsumerWidget {
  final LocalTrack track;
  final int? index;
  final VoidCallback? onTap;

  const TrackTile({super.key, required this.track, this.index, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(
      audioPlaybackProvider.select((s) => s.currentTrack?.id == track.id),
    );
    final isPlaying =
        isCurrent &&
        ref.watch(audioPlaybackProvider.select((s) => s.isPlaying));

    return Dismissible(
      key: ValueKey('track_${track.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.queue_music_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Add to Queue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        ref.read(audioPlaybackProvider.notifier).addToQueue(track);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to queue: ${track.title}'),
            backgroundColor: const Color(0xFF333333),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false; // Return false so track stays in folder/list
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: () => TrackOptionsBottomSheet.show(context, track),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Track Index or Equalizer
              if (index != null) ...[
                SizedBox(
                  width: 24,
                  child: isCurrent
                      ? Icon(
                          isPlaying
                              ? Icons.equalizer_rounded
                              : Icons.pause_rounded,
                          color: AppColors.accent,
                          size: 18,
                        )
                      : Text(
                          '$index',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
              ],

              // Album Artwork (Spotify 48x48 square)
              AlbumArt(
                artPath: track.albumArtPath,
                artworkBytes: track.albumArtBytes,
                size: 48,
                borderRadius: 4,
              ),
              const SizedBox(width: 12),

              // Track Title & Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? AppColors.accent : Colors.white,
                        fontSize: 14.5,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (track.format == 'FLAC' ||
                            track.format == 'WAV') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              track.format,
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            '${track.artist}  •  ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Duration
              Text(
                track.formattedDuration,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),

              // More Options icon (opens bottom sheet)
              IconButton(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                padding: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => TrackOptionsBottomSheet.show(context, track),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
