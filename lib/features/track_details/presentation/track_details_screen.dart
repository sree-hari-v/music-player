import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/local_track.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../shared/widgets/album_art.dart';
import '../../player/presentation/mini_player.dart';

/// Screen displaying track metadata, album artwork, and direct playback controls.
class TrackDetailsScreen extends ConsumerWidget {
  final LocalTrack track;

  const TrackDetailsScreen({super.key, required this.track});

  bool get _isLossless {
    final fmt = track.format.toLowerCase();
    return fmt == 'flac' || fmt == 'wav' || fmt == 'aiff' || fmt == 'alac';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = (screenWidth - 72).clamp(200.0, 320.0);
    final playbackState = ref.watch(audioPlaybackProvider);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);
    final isCurrent = playbackState.currentTrack?.id == track.id;
    final isPlaying = isCurrent && playbackState.isPlaying;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code_rounded),
            tooltip: 'SAF Technical Info',
            onPressed: () => _showTechnicalInfoDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Large Album Art with subtle shadow
            Center(
              child: AlbumArt(
                artPath: track.albumArtPath,
                artworkBytes: track.albumArtBytes,
                size: artSize,
                borderRadius: 8,
                showShadow: true,
                format: track.format,
              ),
            ),

            const SizedBox(height: 24),

            // Song Title
            Text(
              track.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            // Artist & Album
            Text(
              track.artist,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              track.album,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),

            const SizedBox(height: 16),

            // Lossless / Format Banner
            if (_isLossless)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'HI-RES LOSSLESS AUDIO • ${track.format}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Play / Pause Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isCurrent) {
                    playbackNotifier.togglePlayPause();
                  } else {
                    playbackNotifier.playTrack(track);
                  }
                },
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24,
                ),
                label: Text(
                  isPlaying ? 'Pause Playback' : 'Play Track',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // File Specifications Card
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'File Specifications',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSpecTile(
                    icon: Icons.audio_file_rounded,
                    label: 'Format / Codec',
                    value: track.format,
                  ),
                  const Divider(height: 1, color: Color(0x11FFFFFF)),
                  _buildSpecTile(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: track.formattedDuration,
                  ),
                  const Divider(height: 1, color: Color(0x11FFFFFF)),
                  _buildSpecTile(
                    icon: Icons.data_usage_rounded,
                    label: 'File Size',
                    value: track.formattedSize,
                  ),
                  const Divider(height: 1, color: Color(0x11FFFFFF)),
                  _buildSpecTile(
                    icon: Icons.folder_open_rounded,
                    label: 'Relative Path',
                    value: track.relativePath,
                    isMonospace: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }

  Widget _buildSpecTile({
    required IconData icon,
    required String label,
    required String value,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMonospace ? 11 : 13.5,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTechnicalInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          title: const Text(
            'SAF Technical Data',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField('Track ID', track.id),
                const SizedBox(height: 10),
                _buildDialogField('Document URI', track.uri),
                const SizedBox(height: 10),
                _buildDialogField('Filename', track.fileName),
                const SizedBox(height: 10),
                _buildDialogField('Bytes', '${track.fileSizeBytes} B'),
                const SizedBox(height: 10),
                _buildDialogField(
                  'Modified',
                  track.lastModified.toIso8601String(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
