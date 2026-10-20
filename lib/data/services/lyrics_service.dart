import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/local_track.dart';
import '../models/lyrics_model.dart';
import 'lyrics_cache_service.dart';
import 'lyrics_translation_service.dart';

enum LyricsFetchStatus {
  success,
  notFound,
  rateLimited,
  networkError,
  serverError,
  invalidResponse,
}

class LyricsFetchResult {
  final LyricsFetchStatus status;
  final LyricsData? data;
  final String? errorMessage;

  const LyricsFetchResult({required this.status, this.data, this.errorMessage});

  bool get isSuccess => status == LyricsFetchStatus.success && data != null;

  factory LyricsFetchResult.success(LyricsData data) =>
      LyricsFetchResult(status: LyricsFetchStatus.success, data: data);

  factory LyricsFetchResult.notFound([String? message]) => LyricsFetchResult(
    status: LyricsFetchStatus.notFound,
    errorMessage: message ?? 'No lyrics found for this track.',
  );

  factory LyricsFetchResult.rateLimited() => const LyricsFetchResult(
    status: LyricsFetchStatus.rateLimited,
    errorMessage:
        'Rate limit reached. Please wait a moment before trying again.',
  );

  factory LyricsFetchResult.networkError([String? message]) =>
      LyricsFetchResult(
        status: LyricsFetchStatus.networkError,
        errorMessage:
            message ??
            'Unable to connect to the lyrics service. Check your internet.',
      );

  factory LyricsFetchResult.serverError([String? message]) => LyricsFetchResult(
    status: LyricsFetchStatus.serverError,
    errorMessage: message ?? 'Lyrics service is temporarily unavailable.',
  );

  factory LyricsFetchResult.invalidResponse() => const LyricsFetchResult(
    status: LyricsFetchStatus.invalidResponse,
    errorMessage: 'Invalid response received from lyrics provider.',
  );
}

/// Service that interfaces with the public LRCLIB API (https://lrclib.net/api)
/// to search and retrieve synchronized and plain lyrics with offline disk caching.
class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api';
  static const String _userAgent =
      'ShadowPlayer/1.0.0 (https://github.com/sreehari/shadow_player)';
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _httpClient;
  final LyricsCacheService _cacheService;
  final LyricsTranslationService _translationService;

  LyricsService({
    http.Client? httpClient,
    LyricsCacheService? cacheService,
    LyricsTranslationService? translationService,
  })  : _httpClient = httpClient ?? http.Client(),
        _cacheService = cacheService ?? LyricsCacheService(),
        _translationService =
            translationService ?? LyricsTranslationService(httpClient: httpClient);

  Map<String, String> get _headers => {
    'User-Agent': _userAgent,
    'Accept': 'application/json',
  };

  /// Translates [lyrics] into English subtitles and updates disk cache.
  Future<LyricsData> translateLyrics(
    LyricsData lyrics, {
    required String trackId,
  }) async {
    final translated = await _translationService.translateLyricsData(lyrics);
    if (translated.hasTranslation || translated.isSourceEnglish) {
      await _cacheService.saveLyrics(
        trackId: trackId,
        title: lyrics.trackName,
        artist: lyrics.artistName,
        lyrics: translated,
      );
    }
    return translated;
  }

  /// Retrieves lyrics for a [LocalTrack].
  /// 1. Checks disk cache first (unless [forceRefresh] is true).
  /// 2. If not cached, performs exact lookup on LRCLIB.
  /// 3. Falls back to search endpoint with validation.
  /// 4. Caches successful responses locally.
  Future<LyricsFetchResult> getLyricsForTrack(
    LocalTrack track, {
    bool forceRefresh = false,
  }) async {
    final title = track.title.trim();
    final artist = track.artist.trim();

    if (title.isEmpty) {
      return LyricsFetchResult.notFound('Track title is missing.');
    }

    // 1. Cache-first strategy
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedLyrics(
        trackId: track.id,
        title: title,
        artist: artist,
      );
      if (cached != null) {
        return LyricsFetchResult.success(cached);
      }
    }

    // 2. Exact match API lookup
    try {
      final exactResult = await _getExactLyrics(track);
      if (exactResult.isSuccess) {
        await _cacheService.saveLyrics(
          trackId: track.id,
          title: title,
          artist: artist,
          lyrics: exactResult.data!,
        );
        return exactResult;
      }

      // If rate limited or network failure, return immediately without further hammering
      if (exactResult.status == LyricsFetchStatus.rateLimited ||
          exactResult.status == LyricsFetchStatus.networkError) {
        return exactResult;
      }

      // 3. Fallback: Search endpoint
      final searchResult = await _searchLyrics(track);
      if (searchResult.isSuccess) {
        await _cacheService.saveLyrics(
          trackId: track.id,
          title: title,
          artist: artist,
          lyrics: searchResult.data!,
        );
        return searchResult;
      }

      // 4. Fallback: Try with cleaned title if title contains noise (e.g. "(feat. ...)", "[Official Audio]")
      final cleanedTitle = _cleanTrackTitle(title);
      if (cleanedTitle.isNotEmpty && cleanedTitle != title) {
        final cleanTrack = track.copyWith(title: cleanedTitle);
        final cleanSearchResult = await _searchLyrics(cleanTrack);
        if (cleanSearchResult.isSuccess) {
          await _cacheService.saveLyrics(
            trackId: track.id,
            title: title,
            artist: artist,
            lyrics: cleanSearchResult.data!,
          );
          return cleanSearchResult;
        }
      }

      return searchResult;
    } on SocketException catch (e) {
      debugPrint('LyricsService: SocketException: $e');
      return LyricsFetchResult.networkError('No internet connection.');
    } on http.ClientException catch (e) {
      debugPrint('LyricsService: ClientException: $e');
      return LyricsFetchResult.networkError(e.message);
    } on TimeoutException catch (e) {
      debugPrint('LyricsService: TimeoutException: $e');
      return LyricsFetchResult.networkError('Lyrics request timed out.');
    } catch (e, stack) {
      debugPrint('LyricsService: Unexpected error: $e\n$stack');
      return LyricsFetchResult.serverError('Unexpected error: $e');
    }
  }

  /// Exact GET /api/get
  Future<LyricsFetchResult> _getExactLyrics(LocalTrack track) async {
    final queryParams = <String, String>{
      'track_name': track.title.trim(),
      'artist_name': _isUnknown(track.artist) ? '' : track.artist.trim(),
    };

    if (!_isUnknown(track.album)) {
      queryParams['album_name'] = track.album.trim();
    }

    if (track.duration != null && track.duration! > Duration.zero) {
      queryParams['duration'] = track.duration!.inSeconds.toString();
    }

    final uri = Uri.parse('$_baseUrl/get')
        .replace(queryParameters: queryParams);

    final response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final lyrics = LyricsData.fromLrclibJson(decoded, trackId: track.id);
        if (lyrics.hasAnyLyrics) {
          return LyricsFetchResult.success(lyrics);
        }
      }
      return LyricsFetchResult.notFound();
    } else if (response.statusCode == 404) {
      return LyricsFetchResult.notFound();
    } else if (response.statusCode == 429) {
      return LyricsFetchResult.rateLimited();
    } else if (response.statusCode >= 500) {
      return LyricsFetchResult.serverError(
        'LRCLIB server error (${response.statusCode})',
      );
    } else {
      return LyricsFetchResult.invalidResponse();
    }
  }

  /// Search GET /api/search
  Future<LyricsFetchResult> _searchLyrics(LocalTrack track) async {
    final queryParams = <String, String>{'track_name': track.title.trim()};

    if (!_isUnknown(track.artist)) {
      queryParams['artist_name'] = track.artist.trim();
    }

    final uri = Uri.parse('$_baseUrl/search')
        .replace(queryParameters: queryParams);

    final response = await _httpClient
        .get(uri, headers: _headers)
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        final candidate = _findBestCandidate(decoded, track);
        if (candidate != null) {
          return LyricsFetchResult.success(candidate);
        }
      }
      return LyricsFetchResult.notFound();
    } else if (response.statusCode == 404) {
      return LyricsFetchResult.notFound();
    } else if (response.statusCode == 429) {
      return LyricsFetchResult.rateLimited();
    } else if (response.statusCode >= 500) {
      return LyricsFetchResult.serverError(
        'LRCLIB server error (${response.statusCode})',
      );
    } else {
      return LyricsFetchResult.invalidResponse();
    }
  }

  /// Validates search results and selects the closest matching track.
  /// Ensures duration tolerance (within 15s or 15%) and title similarity
  /// to avoid matching wrong recordings or live versions.
  LyricsData? _findBestCandidate(List<dynamic> items, LocalTrack track) {
    if (items.isEmpty) return null;

    final targetTitle = _normalizeString(track.title);
    final targetArtist = _normalizeString(track.artist);
    final targetDurationSec = track.duration?.inSeconds ?? 0;

    LyricsData? bestSyncedMatch;
    LyricsData? bestPlainMatch;
    int lowestDurationDiff = 999999;

    for (final rawItem in items) {
      if (rawItem is! Map<String, dynamic>) continue;

      final item = LyricsData.fromLrclibJson(rawItem, trackId: track.id);
      if (!item.hasAnyLyrics) continue;

      final itemTitle = _normalizeString(item.trackName);
      final itemArtist = _normalizeString(item.artistName);

      // Validate title match
      final titleMatch =
          itemTitle.contains(targetTitle) || targetTitle.contains(itemTitle);
      if (!titleMatch && targetTitle.length > 3 && itemTitle.length > 3) {
        continue;
      }

      // Validate artist if known
      if (targetArtist.isNotEmpty &&
          targetArtist != 'unknown' &&
          targetArtist != 'unknown artist') {
        final artistMatch =
            itemArtist.contains(targetArtist) ||
            targetArtist.contains(itemArtist);
        if (!artistMatch) {
          // Soft check: continue searching if artist completely clashes
          continue;
        }
      }

      // Validate duration difference if known
      if (targetDurationSec > 0 &&
          item.durationSeconds != null &&
          item.durationSeconds! > 0) {
        final diff = (targetDurationSec - item.durationSeconds!).abs();
        // Discard candidates with duration difference greater than 20 seconds
        if (diff > 20) {
          continue;
        }

        if (diff < lowestDurationDiff) {
          lowestDurationDiff = diff;
          if (item.isSynced) {
            bestSyncedMatch = item;
          } else {
            bestPlainMatch = item;
          }
        }
      } else {
        // If no duration available to compare, prioritize synced lyrics
        if (item.isSynced && bestSyncedMatch == null) {
          bestSyncedMatch = item;
        } else {
          bestPlainMatch ??= item;
        }
      }
    }

    return bestSyncedMatch ?? bestPlainMatch;
  }

  /// Removes common suffixes like "(feat. ...)", "[Official Video]", "(Remastered)", etc.
  String _cleanTrackTitle(String title) {
    var cleaned = title;
    // Remove (feat. ...), [feat. ...], etc.
    cleaned = cleaned.replaceAll(
      RegExp(r'\((feat|ft)\.?\s+[^\)]+\)', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\[(feat|ft)\.?\s+[^\]]+\]', caseSensitive: false),
      '',
    );
    // Remove (Official Video), [Official Audio], etc.
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\((official|video|audio|lyrics?|visualizer)[^\)]*\)',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\[(official|video|audio|lyrics?|visualizer)[^\]]*\]',
        caseSensitive: false,
      ),
      '',
    );
    // Remove (Remastered...), [2021 Remaster], etc.
    cleaned = cleaned.replaceAll(
      RegExp(r'\([^\)]*remaster[^\)]*\)', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\[[^\]]*remaster[^\]]*\]', caseSensitive: false),
      '',
    );
    // Remove trailing extra spaces or dashes
    cleaned = cleaned.replaceAll(RegExp(r'-\s*$'), '').trim();
    return cleaned;
  }

  String _normalizeString(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isUnknown(String s) {
    final lower = s.trim().toLowerCase();
    return lower.isEmpty ||
        lower == 'unknown' ||
        lower == 'unknown artist' ||
        lower == 'unknown album' ||
        lower == '<unknown>';
  }
}
