import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/data/models/lyrics_model.dart';
import 'package:music/data/services/lyrics_translation_service.dart';
import 'package:music/providers/lyrics_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lyrics Translation Model Tests', () {
    test('LyricLine correctly serializes and deserializes translation', () {
      const line = LyricLine(
        timestamp: Duration(seconds: 12, milliseconds: 300),
        text: 'Bonjour le monde',
        translation: 'Hello world',
      );

      final json = line.toJson();
      expect(json['timestampMs'], equals(12300));
      expect(json['text'], equals('Bonjour le monde'));
      expect(json['translation'], equals('Hello world'));

      final reconstructed = LyricLine.fromJson(json);
      expect(reconstructed.timestamp, equals(line.timestamp));
      expect(reconstructed.text, equals(line.text));
      expect(reconstructed.translation, equals('Hello world'));
      expect(reconstructed, equals(line));
    });

    test('LyricsData correctly handles hasTranslation and isSourceEnglish', () {
      final untranslated = LyricsData(
        id: 'track_1',
        trackName: 'Sayonara',
        artistName: 'Artist',
        fetchedAt: DateTime.now(),
        syncedLines: const [
          LyricLine(timestamp: Duration(seconds: 5), text: 'さようなら'),
        ],
      );

      expect(untranslated.hasTranslation, isFalse);
      expect(untranslated.isSourceEnglish, isFalse);

      final translated = untranslated.copyWith(
        sourceLanguage: 'ja',
        syncedLines: const [
          LyricLine(
            timestamp: Duration(seconds: 5),
            text: 'さようなら',
            translation: 'Goodbye',
          ),
        ],
      );

      expect(translated.hasTranslation, isTrue);
      expect(translated.isSourceEnglish, isFalse);
      expect(translated.syncedLines.first.translation, equals('Goodbye'));

      // Test JSON roundtrip
      final json = translated.toJson();
      expect(json['sourceLanguage'], equals('ja'));
      final fromJson = LyricsData.fromJson(json);
      expect(fromJson.hasTranslation, isTrue);
      expect(fromJson.sourceLanguage, equals('ja'));
      expect(fromJson.syncedLines.first.translation, equals('Goodbye'));
    });
  });

  group('LyricsTranslationService Tests', () {
    test('translates foreign lines successfully using Google GTX format', () async {
      final mockClient = MockClient((request) async {
        final gtxResponse = [
          [
            ['Hello world\n', 'Bonjour le monde\n', null, null, 3],
            ['I love music', 'J\'aime la musique', null, null, 3],
          ],
          null,
          'fr',
        ];
        return http.Response(
          jsonEncode(gtxResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = LyricsTranslationService(httpClient: mockClient);
      final result = await service.translateLines([
        'Bonjour le monde',
        'J\'aime la musique',
      ]);

      expect(result.isSuccess, isTrue);
      expect(result.sourceLanguage, equals('fr'));
      expect(result.isAlreadyEnglish, isFalse);
      expect(result.translatedLines.length, equals(2));
      expect(result.translatedLines[0], equals('Hello world'));
      expect(result.translatedLines[1], equals('I love music'));
    });

    test('identifies English source lyrics without altering text', () async {
      final mockClient = MockClient((request) async {
        final gtxResponse = [
          [
            ['Blinding lights', 'Blinding lights', null, null, 3],
          ],
          null,
          'en',
        ];
        return http.Response(jsonEncode(gtxResponse), 200);
      });

      final service = LyricsTranslationService(httpClient: mockClient);
      final result = await service.translateLines(['Blinding lights']);

      expect(result.isSuccess, isTrue);
      expect(result.isAlreadyEnglish, isTrue);
      expect(result.sourceLanguage, equals('en'));
    });

    test('enriches LyricsData with line-by-line translation subtitles', () async {
      final mockClient = MockClient((request) async {
        final gtxResponse = [
          [
            ['Goodbye\n', 'さようなら\n', null, null, 3],
            ['See you tomorrow', 'また明日', null, null, 3],
          ],
          null,
          'ja',
        ];
        return http.Response(
          jsonEncode(gtxResponse),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = LyricsTranslationService(httpClient: mockClient);
      final data = LyricsData(
        id: 'track_2',
        trackName: 'Sayonara',
        artistName: 'Singer',
        fetchedAt: DateTime.now(),
        syncedLines: const [
          LyricLine(timestamp: Duration(seconds: 4), text: 'さようなら'),
          LyricLine(timestamp: Duration(seconds: 8), text: 'また明日'),
        ],
      );

      final enriched = await service.translateLyricsData(data);

      expect(enriched.hasTranslation, isTrue);
      expect(enriched.sourceLanguage, equals('ja'));
      expect(enriched.syncedLines[0].text, equals('さようなら'));
      expect(enriched.syncedLines[0].translation, equals('Goodbye'));
      expect(enriched.syncedLines[1].text, equals('また明日'));
      expect(enriched.syncedLines[1].translation, equals('See you tomorrow'));
    });
  });

  group('LyricsNotifier Display Mode & State Tests', () {
    test('cycles through display modes properly (Dual -> English -> Original -> Dual)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(lyricsProvider.notifier);

      expect(notifier.state.displayMode, equals(LyricsDisplayMode.dual));

      notifier.cycleDisplayMode();
      expect(notifier.state.displayMode, equals(LyricsDisplayMode.english));

      notifier.cycleDisplayMode();
      expect(notifier.state.displayMode, equals(LyricsDisplayMode.original));

      notifier.cycleDisplayMode();
      expect(notifier.state.displayMode, equals(LyricsDisplayMode.dual));
    });

    test('setDisplayMode sets exact desired mode directly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(lyricsProvider.notifier);

      notifier.setDisplayMode(LyricsDisplayMode.original);
      expect(notifier.state.displayMode, equals(LyricsDisplayMode.original));

      notifier.setDisplayMode(LyricsDisplayMode.english);
      expect(notifier.state.displayMode, equals(LyricsDisplayMode.english));

      notifier.setDisplayMode(LyricsDisplayMode.dual);
      expect(notifier.state.displayMode, equals(LyricsDisplayMode.dual));
    });
  });
}
