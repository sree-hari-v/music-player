import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../providers/audio_player_provider.dart';
import '../../../../shared/widgets/album_art.dart';

/// Spotify-style Queue sheet showing strictly "Now Playing" and reorderable "Next Up".
class QueueModal extends ConsumerWidget {
  const QueueModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      builder: (context) => const QueueModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(
      audioPlaybackProvider.select((s) => s.currentTrack),
    );
    final upcomingTracks = ref.watch(
      audioPlaybackProvider.select((s) => s.upcomingTracks),
    );
    final isShuffle = ref.watch(
      audioPlaybackProvider.select((s) => s.isShuffle),
    );
    final queueIndex = ref.watch(
      audioPlaybackProvider.select((s) => s.queueIndex),
    );
    final notifier = ref.read(audioPlaybackProvider.notifier);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Queue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (upcomingTracks.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      notifier.clearUpcomingQueue();
                    },
                    child: const Text(
                      'Clear Queue',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECTION 1: NOW PLAYING ---
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Text(
                            'Now Playing',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        if (currentTrack != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                AlbumArt(
                                  artPath: currentTrack.albumArtPath,
                                  artworkBytes: currentTrack.albumArtBytes,
                                  size: 48,
                                  borderRadius: 4,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentTrack.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currentTrack.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.equalizer_rounded,
                                  color: AppColors.accent,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'No song currently playing',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),

                        // --- SECTION 2: NEXT UP (HEADER) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isShuffle ? 'Next Up (Shuffled)' : 'Next Up',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (upcomingTracks.isNotEmpty)
                                Text(
                                  '${upcomingTracks.length} tracks',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (upcomingTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 16,
                      ),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.textSecondary,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No upcoming tracks in queue',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Swipe right on any track to add it to your queue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverReorderableList(
                      itemCount: upcomingTracks.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIndex, newIndex) {
                        notifier.reorderQueue(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final track = upcomingTracks[index];
                        return Padding(
                          key: ValueKey(track.uniqueQueueId),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Material(
                            color: AppColors.card,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: const BorderSide(
                                color: AppColors.borderSubtle,
                                width: 0.5,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              leading: AlbumArt(
                                artPath: track.albumArtPath,
                                artworkBytes: track.albumArtBytes,
                                size: 40,
                                borderRadius: 4,
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () =>
                                        notifier.removeFromQueue(index),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: AppColors.textSecondary,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                notifier.playTrackAtIndex(
                                  queueIndex + 1 + index,
                                );
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
