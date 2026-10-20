import 'dart:convert';

/// Represents a single synchronized lyric line with timestamp, original text, and optional English translation.
class LyricLine {
  final Duration timestamp;
  final String text;
  final String? translation;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.translation,
  });

  LyricLine copyWith({
    Duration? timestamp,
    String? text,
    String? translation,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      translation: translation ?? this.translation,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestampMs': timestamp.inMilliseconds,
    'text': text,
    if (translation != null) 'translation': translation,
  };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    timestamp: Duration(milliseconds: json['timestampMs'] as int? ?? 0),
    text: json['text'] as String? ?? '',
    translation: json['translation'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          text == other.text &&
          translation == other.translation;

  @override
  int get hashCode =>
      timestamp.hashCode ^ text.hashCode ^ (translation?.hashCode ?? 0);

  @override
  String toString() =>
      '[${timestamp.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(timestamp.inSeconds.remainder(60)).toString().padLeft(2, '0')}.${(timestamp.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0')}] $text${translation != null ? ' ($translation)' : ''}';
}

/// Parsed lyrics data containing raw, plain, and timestamped lines, along with translation and language metadata.
class LyricsData {
  final String id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final int? durationSeconds;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyricsRaw;
  final List<LyricLine> syncedLines;
  final DateTime fetchedAt;
  final String? sourceLanguage;
  final String? plainLyricsTranslation;

  const LyricsData({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.durationSeconds,
    this.instrumental = false,
    this.plainLyrics,
    this.syncedLyricsRaw,
    this.syncedLines = const [],
    required this.fetchedAt,
    this.sourceLanguage,
    this.plainLyricsTranslation,
  });

  /// True if valid synchronized timestamped lines are available.
  bool get isSynced => syncedLines.isNotEmpty;

  /// True if plain text lyrics are available without timestamps.
  bool get hasPlainLyrics =>
      plainLyrics != null && plainLyrics!.trim().isNotEmpty;

  /// True if any lyrics (synced or plain) or instrumental confirmation exists.
  bool get hasAnyLyrics => isSynced || hasPlainLyrics || instrumental;

  /// True if English translation is available for either synced lines or plain text.
  bool get hasTranslation =>
      syncedLines.any((l) => l.translation != null && l.translation!.trim().isNotEmpty) ||
      (plainLyricsTranslation != null && plainLyricsTranslation!.trim().isNotEmpty);

  /// True if the detected source language is already English.
  bool get isSourceEnglish =>
      sourceLanguage != null && sourceLanguage!.toLowerCase().startsWith('en');

  LyricsData copyWith({
    String? id,
    String? trackName,
    String? artistName,
    String? albumName,
    int? durationSeconds,
    bool? instrumental,
    String? plainLyrics,
    String? syncedLyricsRaw,
    List<LyricLine>? syncedLines,
    DateTime? fetchedAt,
    String? sourceLanguage,
    String? plainLyricsTranslation,
  }) {
    return LyricsData(
      id: id ?? this.id,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      instrumental: instrumental ?? this.instrumental,
      plainLyrics: plainLyrics ?? this.plainLyrics,
      syncedLyricsRaw: syncedLyricsRaw ?? this.syncedLyricsRaw,
      syncedLines: syncedLines ?? this.syncedLines,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      plainLyricsTranslation:
          plainLyricsTranslation ?? this.plainLyricsTranslation,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trackName': trackName,
    'artistName': artistName,
    'albumName': albumName,
    'durationSeconds': durationSeconds,
    'instrumental': instrumental,
    'plainLyrics': plainLyrics,
    'syncedLyricsRaw': syncedLyricsRaw,
    'syncedLines': syncedLines.map((line) => line.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'sourceLanguage': sourceLanguage,
    'plainLyricsTranslation': plainLyricsTranslation,
  };

  factory LyricsData.fromJson(Map<String, dynamic> json) {
    final syncedRaw = json['syncedLyricsRaw'] as String?;
    List<LyricLine> parsedLines = [];

    if (json['syncedLines'] != null && json['syncedLines'] is List) {
      parsedLines = (json['syncedLines'] as List)
          .map((item) => LyricLine.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (syncedRaw != null && syncedRaw.isNotEmpty) {
      parsedLines = LrcParser.parse(syncedRaw);
    }

    return LyricsData(
      id: json['id'] as String? ?? '',
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumName: json['albumName'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyricsRaw: syncedRaw,
      syncedLines: parsedLines,
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.tryParse(json['fetchedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      sourceLanguage: json['sourceLanguage'] as String?,
      plainLyricsTranslation: json['plainLyricsTranslation'] as String?,
    );
  }

  /// Parses from LRCLIB API JSON response.
  factory LyricsData.fromLrclibJson(
    Map<String, dynamic> json, {
    required String trackId,
  }) {
    final syncedRaw = json['syncedLyrics'] as String?;
    final plain = json['plainLyrics'] as String?;
    final isInstrumental = json['instrumental'] as bool? ?? false;

    List<LyricLine> lines = [];
    if (syncedRaw != null && syncedRaw.trim().isNotEmpty) {
      lines = LrcParser.parse(syncedRaw);
    }

    return LyricsData(
      id: trackId,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumName: json['albumName'] as String?,
      durationSeconds: (json['duration'] as num?)?.round(),
      instrumental: isInstrumental,
      plainLyrics: plain,
      syncedLyricsRaw: syncedRaw,
      syncedLines: lines,
      fetchedAt: DateTime.now(),
    );
  }
}

/// Robust LRC parser supporting multiple timestamps per line, fractional seconds,
/// and metadata header tags like [offset:+/-ms].
class LrcParser {
  LrcParser._();

  // Matches [mm:ss.xx] or [mm:ss.xxx] or [mm:ss]
  static final RegExp _timestampPattern = RegExp(
    r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]',
  );

  // Matches [offset:+/-ms]
  static final RegExp _offsetPattern = RegExp(
    r'\[offset:\s*([+-]?\d+)\s*\]',
    caseSensitive: false,
  );

  /// Parses a raw LRC string into a sorted list of [LyricLine]s.
  static List<LyricLine> parse(String lrcContent) {
    if (lrcContent.trim().isEmpty) return const [];

    final rawLines = const LineSplitter().convert(lrcContent);
    final results = <LyricLine>[];
    int offsetMs = 0;

    // 1. Detect global offset tag if present
    for (final line in rawLines) {
      final offsetMatch = _offsetPattern.firstMatch(line.trim());
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
        break;
      }
    }

    // 2. Parse lines and timestamps
    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      // Skip metadata tags (e.g. [ar: ...], [ti: ...], [by: ...], [al: ...], [length: ...])
      if (trimmed.startsWith('[') &&
          !_timestampPattern.hasMatch(trimmed) &&
          trimmed.contains(':') &&
          trimmed.endsWith(']')) {
        continue;
      }

      final matches = _timestampPattern.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      // Extract the lyric text following the last timestamp tag
      final lastMatch = matches.last;
      final text = trimmed.substring(lastMatch.end).trim();

      // Support multiple timestamps pointing to the same lyric line: [00:10.00][00:20.00] Chorus
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final fractionStr = match.group(3);

        int milliseconds = 0;
        if (fractionStr != null) {
          if (fractionStr.length == 1) {
            milliseconds = int.parse(fractionStr) * 100;
          } else if (fractionStr.length == 2) {
            milliseconds = int.parse(fractionStr) * 10;
          } else {
            milliseconds = int.parse(fractionStr.substring(0, 3));
          }
        }

        var totalMs = (minutes * 60 * 1000) + (seconds * 1000) + milliseconds;
        totalMs += offsetMs;
        if (totalMs < 0) totalMs = 0;

        results.add(
          LyricLine(
            timestamp: Duration(milliseconds: totalMs),
            text: text,
          ),
        );
      }
    }

    // 3. Sort chronologically by timestamp
    results.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return results;
  }

  /// Finds the currently active lyric line index for a given playback position.
  /// Uses binary search for high efficiency.
  /// Returns -1 if playback position is before the first lyric line.
  static int findActiveIndex(List<LyricLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    if (position < lines.first.timestamp) return -1;

    int low = 0;
    int high = lines.length - 1;
    int result = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }
}
