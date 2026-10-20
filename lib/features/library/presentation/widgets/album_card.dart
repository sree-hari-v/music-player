import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../providers/music_library_provider.dart';
import '../../../../shared/widgets/album_art.dart';
import '../../../track_details/presentation/track_details_screen.dart';

/// Reusable card displaying an album with artwork, name, and track count.
class AlbumCard extends StatelessWidget {
  final AlbumSummary album;
  final double? size;

  const AlbumCard({super.key, required this.album, this.size});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrackDetailsScreen(track: album.sampleTrack),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveArtSize = size != null
              ? (size! - 20)
              : (constraints.maxWidth - 20).clamp(40.0, 300.0);

          return Container(
            width: size,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Artwork
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AlbumArt(
                      artPath: album.sampleTrack.albumArtPath,
                      artBytes: album.sampleTrack.albumArtBytes,
                      size: effectiveArtSize,
                      borderRadius: 12,
                      fallbackIcon: Icons.album_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Album Name
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),

                // Artist & Track Count
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        album.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${album.trackCount} ${album.trackCount == 1 ? 'trk' : 'trks'}',
                      style: const TextStyle(
                        color: AppColors.accentSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
