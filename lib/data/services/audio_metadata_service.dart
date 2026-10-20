import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:saf/saf.dart';

import '../../core/utils/audio_file_utils.dart';
import '../models/local_track.dart';
import 'saf_folder_service.dart';

/// Service responsible for extracting audio metadata (title, artist, album, duration, artwork)
/// from SAF document URIs using a dual strategy (file descriptor pseudo-path + temporary cache bridge).
class AudioMetadataService {
  final SafFolderService _safService;
  static bool _fdAccessSupported = true;

  AudioMetadataService({SafFolderService? safService})
    : _safService = safService ?? SafFolderService();

  /// Extracts metadata for a [SafWalkEntry] and returns a populated [LocalTrack].
  /// Never throws: handles all corruption, missing tags, and IO errors gracefully.
  Future<LocalTrack> extractMetadata(SafWalkEntry entry) async {
    final file = entry.file;
    final fallbackTitle = AudioFileUtils.extractTitleFromFileName(file.name);

    // Stable ID based on URI
    final id = file.uri;

    String? parsedTitle;
    String? parsedArtist;
    String? parsedAlbum;
    Duration? parsedDuration;
    Uint8List? parsedArt;

    try {
      if (_fdAccessSupported) {
        // Strategy 1: Direct file descriptor access via /proc/self/fd/<fd>
        try {
          final meta = await _readMetadataViaFd(file.uri);
          if (meta != null) {
            parsedTitle = meta.title;
            parsedArtist = meta.artist;
            parsedAlbum = meta.album;
            parsedDuration = meta.duration;
            if (meta.pictures.isNotEmpty) {
              parsedArt = meta.pictures.first.bytes;
            }
          }
        } catch (_) {
          _fdAccessSupported = false; // Mark FD access unsupported on this OS
        }
      }

      if (parsedTitle == null) {
        // Strategy 2: Safe temporary cache bridge (single-file probe, deleted immediately)
        final meta = await _readMetadataViaTempCache(file.uri, file.name);
        if (meta != null) {
          parsedTitle = meta.title;
          parsedArtist = meta.artist;
          parsedAlbum = meta.album;
          parsedDuration = meta.duration;
          if (meta.pictures.isNotEmpty) {
            parsedArt = meta.pictures.first.bytes;
          }
        }
      }
    } catch (_) {
      // Fallback gracefully
    }

    // If artwork wasn't extracted from tags, try querying SAF provider thumbnail
    if (parsedArt == null || parsedArt.isEmpty) {
      try {
        parsedArt = await _safService.getThumbnail(file.uri);
      } catch (_) {}
    }

    // Clean strings and apply fallbacks
    final cleanTitle = (parsedTitle != null && parsedTitle.trim().isNotEmpty)
        ? parsedTitle.trim()
        : fallbackTitle;

    final cleanArtist = (parsedArtist != null && parsedArtist.trim().isNotEmpty)
        ? parsedArtist.trim()
        : 'Unknown Artist';

    final cleanAlbum = (parsedAlbum != null && parsedAlbum.trim().isNotEmpty)
        ? parsedAlbum.trim()
        : 'Unknown Album';

    return LocalTrack(
      id: id,
      uri: file.uri,
      fileName: file.name,
      relativePath: entry.relativePath,
      title: cleanTitle,
      artist: cleanArtist,
      album: cleanAlbum,
      duration: parsedDuration,
      albumArtBytes: parsedArt,
      fileSizeBytes: file.length,
      lastModified: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
    );
  }

  /// Strategy 1: Read metadata through native open file descriptor.
  Future<AudioMetadata?> _readMetadataViaFd(String uri) async {
    return await _safService.withFileDescriptor(uri, 'r', (fd) async {
      final file = File(fd.path);
      return readMetadata(file, getImage: true);
    });
  }

  /// Strategy 2: Safe temporary cache bridge for APIs requiring standard filesystem path.
  Future<AudioMetadata?> _readMetadataViaTempCache(
    String uri,
    String fileName,
  ) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/sp_meta_${DateTime.now().microsecondsSinceEpoch}_$fileName',
    );

    try {
      await _safService.copyToLocalFile(uri, tempFile.path);
      if (await tempFile.exists()) {
        return readMetadata(tempFile, getImage: true);
      }
      return null;
    } finally {
      // Immediately clean up the single probe file so we do not fill up storage
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }
}
