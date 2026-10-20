import 'dart:convert';
import 'dart:typed_data';

import '../../core/utils/audio_file_utils.dart';

/// Represents a local audio track discovered through SAF folder access.
class LocalTrack {
  /// Unique stable identifier for this track (derived from URI or relative path).
  final String id;

  /// Content URI pointing to the document file (`content://...`).
  final String uri;

  /// File name with extension (e.g. "track01.mp3").
  final String fileName;

  /// Relative path from the root selected music folder (e.g. "Rock/Queen/01.mp3").
  final String relativePath;

  /// Song title from metadata or cleaned filename.
  final String title;

  /// Artist name from metadata or 'Unknown Artist'.
  final String artist;

  /// Album name from metadata or 'Unknown Album'.
  final String album;

  /// Track duration if reliably determined.
  final Duration? duration;

  /// Embedded artwork bytes or SAF thumbnail bytes if available in memory.
  final Uint8List? albumArtBytes;

  /// Path to locally cached artwork file on disk.
  final String? albumArtPath;

  /// File size in bytes.
  final int fileSizeBytes;

  /// File last modified timestamp.
  final DateTime lastModified;

  /// Optional unique identifier assigned when the track is in a playback queue.
  final String? queueKey;

  const LocalTrack({
    required this.id,
    required this.uri,
    required this.fileName,
    required this.relativePath,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.albumArtPath,
    this.albumArtBytes,
    required this.fileSizeBytes,
    required this.lastModified,
    this.queueKey,
  });

  /// Stable identifier for queue list widgets.
  String get uniqueQueueId => queueKey ?? id;

  /// Audio format extension uppercase (e.g. "MP3", "FLAC").
  String get format => AudioFileUtils.extractFormat(fileName);

  /// Human-readable duration string.
  String get formattedDuration => AudioFileUtils.formatDuration(duration);

  /// Human-readable file size string.
  String get formattedSize => AudioFileUtils.formatBytes(fileSizeBytes);

  /// Whether embedded or thumbnail artwork is available.
  bool get hasAlbumArt {
    final bytes = albumArtBytes;
    final path = albumArtPath;
    return (bytes != null && bytes.isNotEmpty) ||
        (path != null && path.isNotEmpty);
  }

  Map<String, dynamic> toJson() {
    final bytes = albumArtBytes;
    return {
      'id': id,
      'uri': uri,
      'fileName': fileName,
      'relativePath': relativePath,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': duration?.inMilliseconds,
      'albumArtPath': albumArtPath,
      if (albumArtPath == null && bytes != null)
        'albumArtBase64': base64Encode(bytes),
      'fileSizeBytes': fileSizeBytes,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'queueKey': queueKey,
    };
  }

  factory LocalTrack.fromJson(Map<String, dynamic> json) {
    Uint8List? artBytes;
    final base64Str = json['albumArtBase64'] as String?;
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        artBytes = base64Decode(base64Str);
      } catch (_) {}
    }
    final artPath =
        json['albumArtPath'] as String? ?? json['artPath'] as String?;

    return LocalTrack(
      id: json['id'] as String,
      uri: json['uri'] as String,
      fileName: json['fileName'] as String,
      relativePath: json['relativePath'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Unknown Album',
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
      albumArtPath: artPath,
      albumArtBytes: artBytes,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      lastModified: json['lastModified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastModified'] as int)
          : DateTime.now(),
      queueKey: json['queueKey'] as String?,
    );
  }

  LocalTrack copyWith({
    String? id,
    String? uri,
    String? fileName,
    String? relativePath,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? albumArtPath,
    Uint8List? albumArtBytes,
    int? fileSizeBytes,
    DateTime? lastModified,
    String? queueKey,
  }) {
    return LocalTrack(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      fileName: fileName ?? this.fileName,
      relativePath: relativePath ?? this.relativePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      albumArtBytes: albumArtBytes ?? this.albumArtBytes,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      lastModified: lastModified ?? this.lastModified,
      queueKey: queueKey ?? this.queueKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalTrack &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uri == other.uri;

  @override
  int get hashCode => id.hashCode ^ uri.hashCode;

  @override
  String toString() {
    return 'LocalTrack(id: $id, title: $title, artist: $artist, album: $album, duration: $duration)';
  }
}
