import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lyrics_model.dart';

/// Handles offline local disk caching of successfully retrieved lyrics.
///
/// Lyrics are stored as individual JSON files in `<appDocsDir>/lyrics_cache/`.
/// Key is derived from track metadata (artist, title, and trackId hash) to ensure
/// stability and uniqueness across identical filenames.
class LyricsCacheService {
  final Future<Directory> Function()? customDirectoryProvider;

  LyricsCacheService({this.customDirectoryProvider});

  Directory? _cachedDir;

  Future<Directory?> _getCacheDirectory() async {
    if (_cachedDir != null && await _cachedDir!.exists()) {
      return _cachedDir;
    }

    try {
      final custom = customDirectoryProvider;
      final Directory baseDir = custom != null
          ? await custom()
          : await getApplicationDocumentsDirectory();

      final dir = Directory('${baseDir.path}/lyrics_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cachedDir = dir;
      return dir;
    } catch (e) {
      debugPrint('LyricsCacheService: Failed to get lyrics cache dir: $e');
      return null;
    }
  }

  /// Generates a stable filename key derived from track metadata and track identity.
  String generateCacheKey({
    required String trackId,
    required String title,
    required String artist,
  }) {
    final cleanArtist = artist.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '_',
    );
    final cleanTitle = title.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '_',
    );
    final idHash = trackId.hashCode.abs();
    return '${cleanArtist}_${cleanTitle}_$idHash.json';
  }

  /// Retrieves cached lyrics from disk if available.
  Future<LyricsData?> getCachedLyrics({
    required String trackId,
    required String title,
    required String artist,
  }) async {
    try {
      final dir = await _getCacheDirectory();
      if (dir == null) return null;

      final filename = generateCacheKey(
        trackId: trackId,
        title: title,
        artist: artist,
      );
      final file = File('${dir.path}/$filename');

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final dynamic decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        final lyrics = LyricsData.fromJson(decoded);
        // Only return if it actually has content (plain, synced, or marked instrumental)
        if (lyrics.hasAnyLyrics) {
          debugPrint('LyricsCacheService: Cache hit for "$title" by "$artist"');
          return lyrics;
        }
      }
      return null;
    } catch (e) {
      debugPrint('LyricsCacheService: Failed to read cached lyrics: $e');
      return null;
    }
  }

  /// Saves valid lyrics to disk cache.
  /// Ignores saving if lyrics have no content to avoid poisoning cache.
  Future<void> saveLyrics({
    required String trackId,
    required String title,
    required String artist,
    required LyricsData lyrics,
  }) async {
    if (!lyrics.hasAnyLyrics) {
      debugPrint('LyricsCacheService: Ignoring save for empty lyrics.');
      return;
    }

    try {
      final dir = await _getCacheDirectory();
      if (dir == null) return;

      final filename = generateCacheKey(
        trackId: trackId,
        title: title,
        artist: artist,
      );
      final file = File('${dir.path}/$filename');

      final jsonString = jsonEncode(lyrics.toJson());
      await file.writeAsString(jsonString, flush: true);
      debugPrint(
        'LyricsCacheService: Cached lyrics for "$title" by "$artist" ($filename)',
      );
    } catch (e) {
      debugPrint('LyricsCacheService: Failed to save lyrics cache: $e');
    }
  }

  /// Deletes cached lyrics for a track, useful when user taps refresh.
  Future<void> deleteCachedLyrics({
    required String trackId,
    required String title,
    required String artist,
  }) async {
    try {
      final dir = await _getCacheDirectory();
      if (dir == null) return;

      final filename = generateCacheKey(
        trackId: trackId,
        title: title,
        artist: artist,
      );
      final file = File('${dir.path}/$filename');

      if (await file.exists()) {
        await file.delete();
        debugPrint('LyricsCacheService: Deleted cached lyrics for "$title"');
      }
    } catch (e) {
      debugPrint('LyricsCacheService: Failed to delete cached lyrics: $e');
    }
  }

  /// Clears all cached lyrics.
  Future<void> clearAllLyricsCache() async {
    try {
      final dir = await _getCacheDirectory();
      if (dir != null && await dir.exists()) {
        await dir.delete(recursive: true);
        _cachedDir = null;
        debugPrint('LyricsCacheService: All lyrics caches cleared.');
      }
    } catch (e) {
      debugPrint('LyricsCacheService: Failed to clear all caches: $e');
    }
  }
}
