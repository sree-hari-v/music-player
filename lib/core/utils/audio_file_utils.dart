import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';

/// Utilities for audio file extensions, durations, formatting, and name cleaning.
class AudioFileUtils {
  AudioFileUtils._();

  /// Checks if a file has a supported audio extension.
  static bool isSupportedAudio(String fileName) {
    if (fileName.isEmpty) return false;
    final ext = p.extension(fileName).toLowerCase();
    return AppConstants.supportedAudioExtensions.contains(ext);
  }

  /// Extracts the audio format/codec string in uppercase (e.g. "MP3", "FLAC").
  static String extractFormat(String fileName) {
    final ext = p.extension(fileName);
    if (ext.startsWith('.')) {
      return ext.substring(1).toUpperCase();
    }
    if (ext.isNotEmpty) {
      return ext.toUpperCase();
    }
    return fileName.toUpperCase();
  }

  /// Formats a [Duration] into "m:ss" or "h:mm:ss".
  static String formatDuration(Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) {
      return '--:--';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    } else {
      return '$minutes:$secondsStr';
    }
  }

  /// Formats byte count into a human-readable string (e.g. "4.8 MB").
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Cleans and extracts a human-friendly fallback title from a file name.
  /// Example: "01 - Bohemian Rhapsody.mp3" -> "Bohemian Rhapsody"
  static String extractTitleFromFileName(String fileName) {
    if (fileName.isEmpty) return 'Unknown Title';

    // Remove extension
    var baseName = p.basenameWithoutExtension(fileName);

    // Strip common leading track numbering patterns (e.g. "01 - ", "1. ", "02_")
    final trackPrefixRegex = RegExp(r'^\d{1,3}\s*[-._\s]\s*');
    baseName = baseName.replaceFirst(trackPrefixRegex, '').trim();

    // Replace underscores with spaces
    baseName = baseName.replaceAll('_', ' ').trim();

    if (baseName.isEmpty) {
      return p.basenameWithoutExtension(fileName);
    }
    return baseName;
  }
}
