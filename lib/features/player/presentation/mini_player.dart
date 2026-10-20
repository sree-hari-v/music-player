import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../shared/widgets/album_art.dart';
import 'now_playing_screen.dart';

/// Spotify-style floating Mini-Player docked immediately above the bottom navigation bar.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      audioPlaybackProvider.select((s) => s.currentTrack),
    );
    final isVisible = ref.watch(
      audioPlaybackProvider.select((s) => s.isMiniPlayerVisible),
    );
    final isPlaying = ref.watch(
      audioPlaybackProvider.select((s) => s.isPlaying),
    );

    if (track == null || !isVisible) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(audioPlaybackProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => NowPlayingScreen.open(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Pure AMOLED black container
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Album Art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: AlbumArt(
                        artPath: track.albumArtPath,
                        artworkBytes: track.albumArtBytes,
                        size: 44,
                        format: track.format,
                        showVinylGrooves: false,
                      ),
                    ),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Device / Offline indicator
                  const Icon(
                    Icons.devices_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),

                  // Play / Pause button
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => notifier.togglePlayPause(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),

                  // Next button
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: () => notifier.playNext(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),

                  // Stop & Close App button
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: 'Stop & Close App',
                    onPressed: () => notifier.stopAndCloseApp(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),

            // Isolated high-performance real-time progress bar (only this rebuilds on tick)
            const _MiniPlayerProgressBar(),
          ],
        ),
      ),
    );
  }
}

/// Isolated progress indicator that listens strictly to progress changes,
/// preventing the entire MiniPlayer card from re-rendering on every position tick.
class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioPlaybackProvider.select((s) => s.progress));

    return LinearProgressIndicator(
      value: progress,
      minHeight: 2.5,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
    );
  }
}
