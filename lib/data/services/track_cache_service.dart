import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_track.dart';

/// Handles ultra-fast, lightweight serialization of discovered tracks to disk.
/// Automatically migrates legacy 161MB base64 caches to compact metadata + binary image files.
class TrackCacheService {
  static const String _v2FileName = 'shadow_tracks_v2.json';
  static const String _legacyFileName = 'shadow_tracks_cache.json';

  Future<File?> _getV2File() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_v2FileName');
    } catch (_) {
      return null;
    }
  }

  Future<File?> _getLegacyFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_legacyFileName');
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _getArtDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final artDir = Directory('${dir.path}/art_cache');
      if (!await artDir.exists()) {
        await artDir.create(recursive: true);
      }
      return artDir;
    } catch (_) {
      return null;
    }
  }

  /// Loads cached tracks.
  /// 1. Fast path: loads lightweight shadow_tracks_v2.json (<100KB) in ~2ms.
  /// 2. Migration path: migrates legacy 161MB shadow_tracks_cache.json, writes binary art files,
  ///    saves V2 cache, and permanently deletes the 161MB legacy file to free device storage.
  Future<List<LocalTrack>> loadCachedTracks() async {
    try {
      final v2File = await _getV2File();
      if (v2File != null && await v2File.exists()) {
        final jsonString = await v2File.readAsString();
        if (jsonString.isNotEmpty) {
          final dynamic decoded = jsonDecode(jsonString);
          if (decoded is List) {
            final tracks = decoded
                .map(
                  (item) => LocalTrack.fromJson(item as Map<String, dynamic>),
                )
                .toList();
            debugPrint(
              'TrackCacheService: Fast-loaded ${tracks.length} tracks from V2 cache.',
            );
            return tracks;
          }
        }
      }

      // Fallback: Legacy 161MB cache migration
      final legacyFile = await _getLegacyFile();
      if (legacyFile != null && await legacyFile.exists()) {
        debugPrint(
          'TrackCacheService: Migrating legacy cache to high-speed V2 format...',
        );
        final jsonString = await legacyFile.readAsString();
        if (jsonString.isNotEmpty) {
          final dynamic decoded = jsonDecode(jsonString);
          if (decoded is List) {
            final artDir = await _getArtDir();
            final migratedTracks = <LocalTrack>[];

            for (final item in decoded) {
              final track = LocalTrack.fromJson(item as Map<String, dynamic>);
              String? artPath;

              if (artDir != null &&
                  track.albumArtBytes != null &&
                  track.albumArtBytes!.isNotEmpty) {
                try {
                  final cleanId = track.id.hashCode.abs();
                  final artFile = File('${artDir.path}/$cleanId.jpg');
                  if (!await artFile.exists() ||
                      (await artFile.length()) == 0) {
                    await artFile.writeAsBytes(
                      track.albumArtBytes!,
                      flush: true,
                    );
                  }
                  artPath = artFile.path;
                } catch (_) {}
              }

              migratedTracks.add(track.copyWith(albumArtPath: artPath));
            }

            // Save new clean V2 cache
            await saveCachedTracks(migratedTracks);

            // Delete legacy 161MB file permanently!
            try {
              await legacyFile.delete();
              debugPrint(
                'TrackCacheService: Deleted legacy 161MB cache file successfully!',
              );
            } catch (_) {}

            return migratedTracks;
          }
        }
      }
      return const [];
    } catch (e) {
      debugPrint('TrackCacheService: Failed to read cache: $e');
      return const [];
    }
  }

  /// Saves tracks to disk asynchronously without blocking UI.
  /// Artwork bytes are written once to disk files; JSON metadata stays feather-light (<100KB).
  Future<void> saveCachedTracks(List<LocalTrack> tracks) async {
    try {
      final v2File = await _getV2File();
      if (v2File == null) return;

      final artDir = await _getArtDir();
      final optimizedTracks = <LocalTrack>[];

      for (final t in tracks) {
        String? artPath = t.albumArtPath;
        if (artPath == null &&
            artDir != null &&
            t.albumArtBytes != null &&
            t.albumArtBytes!.isNotEmpty) {
          try {
            final cleanId = t.id.hashCode.abs();
            final artFile = File('${artDir.path}/$cleanId.jpg');
            if (!await artFile.exists() || (await artFile.length()) == 0) {
              await artFile.writeAsBytes(t.albumArtBytes!, flush: true);
            }
            artPath = artFile.path;
          } catch (_) {}
        }
        optimizedTracks.add(t.copyWith(albumArtPath: artPath));
      }

      final jsonList = optimizedTracks.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await v2File.writeAsString(jsonString, flush: true);
      debugPrint(
        'TrackCacheService: Saved ${optimizedTracks.length} tracks to lightweight V2 cache.',
      );
    } catch (e) {
      debugPrint('TrackCacheService: Failed to write cache: $e');
    }
  }

  /// Removes all cache files and artwork when clearing folder.
  Future<void> clearCache() async {
    try {
      final v2File = await _getV2File();
      if (v2File != null && await v2File.exists()) {
        await v2File.delete();
      }
      final legacyFile = await _getLegacyFile();
      if (legacyFile != null && await legacyFile.exists()) {
        await legacyFile.delete();
      }
      final artDir = await _getArtDir();
      if (artDir != null && await artDir.exists()) {
        await artDir.delete(recursive: true);
      }
      debugPrint('TrackCacheService: All caches cleared.');
    } catch (e) {
      debugPrint('TrackCacheService: Failed to clear cache: $e');
    }
  }
}
