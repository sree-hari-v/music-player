import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Spotify-style Album Art renderer with support for direct cached files, embedded bytes, and vinyl/music fallback.
class AlbumArt extends StatelessWidget {
  final Uint8List? _bytes;
  final String? artPath;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final bool showShadow;
  final bool showVinylGrooves;
  final String? format;

  const AlbumArt({
    super.key,
    Uint8List? artBytes,
    Uint8List? artworkBytes,
    this.artPath,
    this.size = 52,
    this.borderRadius = 8, // Spotify standard radius
    this.fallbackIcon = Icons.music_note_rounded,
    this.showShadow = false,
    this.showVinylGrooves = false,
    this.format,
  }) : _bytes = artBytes ?? artworkBytes;

  @override
  Widget build(BuildContext context) {
    Widget content;
    final bytes = _bytes;
    final path = artPath;
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final targetPixelSize = (size * dpr).round().clamp(48, 800);

    if (path != null && path.isNotEmpty) {
      content = Image.file(
        File(path),
        width: size,
        height: size,
        cacheWidth: targetPixelSize,
        cacheHeight: targetPixelSize,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) {
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              width: size,
              height: size,
              cacheWidth: targetPixelSize,
              cacheHeight: targetPixelSize,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) => _buildFallback(),
            );
          }
          return _buildFallback();
        },
      );
    } else if (bytes != null && bytes.isNotEmpty) {
      content = Image.memory(
        bytes,
        width: size,
        height: size,
        cacheWidth: targetPixelSize,
        cacheHeight: targetPixelSize,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else {
      content = _buildFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.placeholderArtGradient,
      ),
      child: Center(
        child: Icon(fallbackIcon, size: size * 0.42, color: AppColors.accent),
      ),
    );
  }
}
