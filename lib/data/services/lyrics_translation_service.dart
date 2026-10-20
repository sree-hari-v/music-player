import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/lyrics_model.dart';

class LyricsTranslationResult {
  final List<String> translatedLines;
  final String? sourceLanguage;
  final bool isAlreadyEnglish;
  final bool isSuccess;
  final String? errorMessage;

  const LyricsTranslationResult({
    required this.translatedLines,
    this.sourceLanguage,
    this.isAlreadyEnglish = false,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory LyricsTranslationResult.failure(String message) =>
      LyricsTranslationResult(
        translatedLines: const [],
        isSuccess: false,
        errorMessage: message,
      );
}

/// Service to translate synchronized or plain lyrics to English.
/// Uses free endpoints with graceful fallbacks and offline batch mapping.
class LyricsTranslationService {
  static const String _gtxUrl =
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t';
  static const Duration _timeout = Duration(seconds: 12);

  final http.Client _httpClient;

  LyricsTranslationService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Translates a list of lyric lines to English.
  Future<LyricsTranslationResult> translateLines(List<String> lines) async {
    if (lines.isEmpty) {
      return const LyricsTranslationResult(translatedLines: []);
    }

    // Try Google Translate Web endpoint first
    try {
      final result = await _translateWithGoogle(lines);
      if (result.isSuccess && result.translatedLines.isNotEmpty) {
        return result;
      }
    } catch (e) {
      debugPrint('LyricsTranslationService: Google translate failed ($e), falling back');
    }

    // Fallback to MyMemory API
    try {
      final fallback = await _translateWithMyMemory(lines);
      if (fallback.isSuccess && fallback.translatedLines.isNotEmpty) {
        return fallback;
      }
    } catch (e) {
      debugPrint('LyricsTranslationService: MyMemory fallback failed: $e');
    }

    return LyricsTranslationResult.failure('Translation service unavailable.');
  }

  /// Translates entire [LyricsData], enriching syncedLines or plainLyrics with English subtitles.
  Future<LyricsData> translateLyricsData(LyricsData data) async {
    if (data.instrumental || !data.hasAnyLyrics) {
      return data;
    }

    // If already has translation, return as is
    if (data.hasTranslation) {
      return data;
    }

    if (data.isSynced) {
      final originalTexts = data.syncedLines.map((l) => l.text).toList();
      final result = await translateLines(originalTexts);

      if (result.isAlreadyEnglish) {
        return data.copyWith(
          sourceLanguage: result.sourceLanguage ?? 'en',
        );
      }

      if (result.isSuccess && result.translatedLines.isNotEmpty) {
        final newSynced = <LyricLine>[];
        for (var i = 0; i < data.syncedLines.length; i++) {
          final line = data.syncedLines[i];
          final translation = (i < result.translatedLines.length)
              ? result.translatedLines[i].trim()
              : null;
          newSynced.add(line.copyWith(
            translation: (translation != null && translation.isNotEmpty && translation != line.text.trim())
                ? translation
                : null,
          ));
        }

        return data.copyWith(
          syncedLines: newSynced,
          sourceLanguage: result.sourceLanguage,
        );
      }
    } else if (data.hasPlainLyrics) {
      final lines = data.plainLyrics!.split('\n');
      final result = await translateLines(lines);

      if (result.isAlreadyEnglish) {
        return data.copyWith(
          sourceLanguage: result.sourceLanguage ?? 'en',
        );
      }

      if (result.isSuccess && result.translatedLines.isNotEmpty) {
        return data.copyWith(
          plainLyricsTranslation: result.translatedLines.join('\n'),
          sourceLanguage: result.sourceLanguage,
        );
      }
    }

    return data;
  }

  /// Primary translator: batches up to 40 lines per HTTP request using Google GTX.
  Future<LyricsTranslationResult> _translateWithGoogle(List<String> lines) async {
    final allTranslated = <String>[];
    String? detectedLang;
    const chunkSize = 40;

    for (var i = 0; i < lines.length; i += chunkSize) {
      final chunk = lines.sublist(
        i,
        (i + chunkSize > lines.length) ? lines.length : i + chunkSize,
      );

      final joined = chunk.map((l) => l.isEmpty ? ' ' : l).join('\n');

      final response = await _httpClient.post(
        Uri.parse(_gtxUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: {'q': joined},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        return LyricsTranslationResult.failure('HTTP ${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return LyricsTranslationResult.failure('Invalid JSON from translator');
      }

      // Check detected source language (usually at index 2 or 1)
      if (decoded.length > 2 && decoded[2] is String) {
        detectedLang = decoded[2] as String;
      }

      if (detectedLang != null && detectedLang.toLowerCase().startsWith('en')) {
        return LyricsTranslationResult(
          translatedLines: lines,
          sourceLanguage: detectedLang,
          isAlreadyEnglish: true,
        );
      }

      final dynamic sentences = decoded[0];
      if (sentences is List) {
        final buffer = StringBuffer();
        for (final item in sentences) {
          if (item is List && item.isNotEmpty && item[0] != null) {
            buffer.write(item[0].toString());
          }
        }
        final chunkResultLines = buffer.toString().split('\n');

        // Pad or trim to match exact chunk length
        for (var j = 0; j < chunk.length; j++) {
          if (j < chunkResultLines.length) {
            allTranslated.add(chunkResultLines[j].trim());
          } else {
            allTranslated.add('');
          }
        }
      }
    }

    return LyricsTranslationResult(
      translatedLines: allTranslated,
      sourceLanguage: detectedLang,
      isAlreadyEnglish: false,
    );
  }

  /// Fallback translator: MyMemory Translation API for key lines or short texts.
  Future<LyricsTranslationResult> _translateWithMyMemory(List<String> lines) async {
    final allTranslated = <String>[];

    // Translate non-empty lines (limit to 30 lines to stay within MyMemory limits)
    final limit = lines.length > 30 ? 30 : lines.length;
    for (var i = 0; i < limit; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        allTranslated.add('');
        continue;
      }

      try {
        final url = Uri.parse(
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(line)}&langpair=autodetect|en',
        );
        final response = await _httpClient.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final translated = json['responseData']?['translatedText'] as String?;
          allTranslated.add(translated?.trim() ?? line);
        } else {
          allTranslated.add(line);
        }
      } catch (_) {
        allTranslated.add(line);
      }
    }

    // Pad remaining if any
    while (allTranslated.length < lines.length) {
      allTranslated.add('');
    }

    return LyricsTranslationResult(
      translatedLines: allTranslated,
      isAlreadyEnglish: false,
    );
  }
}
