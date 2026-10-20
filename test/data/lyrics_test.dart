import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/data/models/lyrics_model.dart';
import 'package:music/data/services/lyrics_cache_service.dart';
import 'package:music/data/services/lyrics_service.dart';

void main() {
  group('LRC Parser & Synchronization Tests', () {
    test('parses simple standard LRC timestamps correctly', () {
      const lrc = '''
[00:04.50]First line of the song
[00:12.00]Second line continues
[01:30.85]One minute thirty point eight-five
''';

      final lines = LrcParser.parse(lrc);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('First line of the song'));
      expect(
        lines[0].timestamp,
        equals(const Duration(seconds: 4, milliseconds: 500)),
      );

      expect(lines[1].text, equals('Second line continues'));
      expect(lines[1].timestamp, equals(const Duration(seconds: 12)));

      expect(lines[2].text, equals('One minute thirty point eight-five'));
      expect(
        lines[2].timestamp,
        equals(const Duration(minutes: 1, seconds: 30, milliseconds: 850)),
      );
    });

    test('supports multiple timestamps pointing to the same lyric line', () {
      const lrc = '''
[00:05.00][00:25.00]This chorus is repeated twice
[00:15.00]Verse in between
''';

      final lines = LrcParser.parse(lrc);
      expect(lines.length, equals(3));

      // Must be sorted chronologically
      expect(lines[0].timestamp, equals(const Duration(seconds: 5)));
      expect(lines[0].text, equals('This chorus is repeated twice'));

      expect(lines[1].timestamp, equals(const Duration(seconds: 15)));
      expect(lines[1].text, equals('Verse in between'));

      expect(lines[2].timestamp, equals(const Duration(seconds: 25)));
      expect(lines[2].text, equals('This chorus is repeated twice'));
    });

    test('correctly handles metadata tags and [offset] tags', () {
      const lrc = '''
[ti:Sample Title]
[ar:Sample Artist]
[al:Sample Album]
[by:Encoder]
[offset:+1000]
[00:05.00]Lyric line delayed by 1000ms offset
''';

      final lines = LrcParser.parse(lrc);
      expect(lines.length, equals(1));
      expect(lines[0].text, equals('Lyric line delayed by 1000ms offset'));
      // 5000ms + 1000ms offset = 6000ms
      expect(lines[0].timestamp, equals(const Duration(seconds: 6)));
    });

    test('handles 1-digit, 2-digit, and 3-digit fractional seconds', () {
      const lrc = '''
[00:01.5]One digit fraction
[00:02.25]Two digit fraction
[00:03.125]Three digit fraction
''';

      final lines = LrcParser.parse(lrc);
      expect(lines[0].timestamp.inMilliseconds, equals(1500));
      expect(lines[1].timestamp.inMilliseconds, equals(2250));
      expect(lines[2].timestamp.inMilliseconds, equals(3125));
    });

    test('binary search findActiveIndex accurately finds current line', () {
      final lines = [
        const LyricLine(timestamp: Duration(seconds: 5), text: 'Intro'),
        const LyricLine(timestamp: Duration(seconds: 15), text: 'Verse 1'),
        const LyricLine(timestamp: Duration(seconds: 30), text: 'Chorus'),
        const LyricLine(timestamp: Duration(seconds: 50), text: 'Outro'),
      ];

      // Before first line -> -1
      expect(LrcParser.findActiveIndex(lines, Duration.zero), equals(-1));
      expect(
        LrcParser.findActiveIndex(
          lines,
          const Duration(seconds: 4, milliseconds: 999),
        ),
        equals(-1),
      );

      // Exactly at first line -> 0
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 5)),
        equals(0),
      );

      // Between first and second line -> 0
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 14)),
        equals(0),
      );

      // Exactly at second line -> 1
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 15)),
        equals(1),
      );

      // At Chorus -> 2
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 35)),
        equals(2),
      );

      // At or beyond Outro -> 3
      expect(
        LrcParser.findActiveIndex(lines, const Duration(seconds: 50)),
        equals(3),
      );
      expect(
        LrcParser.findActiveIndex(lines, const Duration(minutes: 2)),
        equals(3),
      );
    });
  });

  group('Lyrics Cache Service Tests', () {
    late Directory tempDir;
    late LyricsCacheService cacheService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lyrics_cache_test_');
      cacheService = LyricsCacheService(
        customDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates stable sanitized cache keys', () {
      final key1 = cacheService.generateCacheKey(
        trackId: 'content://media/12345',
        title: 'Bohemian Rhapsody (2011 Mix)',
        artist: 'Queen',
      );
      final key2 = cacheService.generateCacheKey(
        trackId: 'content://media/12345',
        title: 'Bohemian Rhapsody (2011 Mix)',
        artist: 'Queen',
      );
      expect(key1, equals(key2));
      expect(key1.endsWith('.json'), isTrue);
      expect(key1.contains('/'), isFalse);
      expect(key1.contains('\\'), isFalse);
    });

    test('saves and loads lyrics from disk cache', () async {
      const trackId = 'test_track_1';
      const title = 'Starboy';
      const artist = 'The Weeknd';

      final lyrics = LyricsData(
        id: trackId,
        trackName: title,
        artistName: artist,
        durationSeconds: 230,
        plainLyrics: 'I am a starboy',
        syncedLines: [
          const LyricLine(
            timestamp: Duration(seconds: 10),
            text: 'I am a starboy',
          ),
        ],
        fetchedAt: DateTime.now(),
      );

      // Save to cache
      await cacheService.saveLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
        lyrics: lyrics,
      );

      // Read from cache
      final loaded = await cacheService.getCachedLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
      );

      expect(loaded, isNotNull);
      expect(loaded!.trackName, equals(title));
      expect(loaded.artistName, equals(artist));
      expect(loaded.isSynced, isTrue);
      expect(loaded.syncedLines.length, equals(1));
      expect(loaded.syncedLines[0].text, equals('I am a starboy'));
    });

    test('does not save empty lyrics to avoid cache pollution', () async {
      const trackId = 'empty_track';
      const title = 'Silence';
      const artist = 'Nobody';

      final emptyLyrics = LyricsData(
        id: trackId,
        trackName: title,
        artistName: artist,
        plainLyrics: '',
        syncedLines: const [],
        instrumental: false,
        fetchedAt: DateTime.now(),
      );

      await cacheService.saveLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
        lyrics: emptyLyrics,
      );

      final loaded = await cacheService.getCachedLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
      );
      expect(loaded, isNull);
    });

    test('deletes cached lyrics on demand', () async {
      const trackId = 'delete_track';
      const title = 'Temporary';
      const artist = 'Artist';

      final lyrics = LyricsData(
        id: trackId,
        trackName: title,
        artistName: artist,
        plainLyrics: 'Some words',
        fetchedAt: DateTime.now(),
      );

      await cacheService.saveLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
        lyrics: lyrics,
      );

      expect(
        await cacheService.getCachedLyrics(
          trackId: trackId,
          title: title,
          artist: artist,
        ),
        isNotNull,
      );

      await cacheService.deleteCachedLyrics(
        trackId: trackId,
        title: title,
        artist: artist,
      );

      expect(
        await cacheService.getCachedLyrics(
          trackId: trackId,
          title: title,
          artist: artist,
        ),
        isNull,
      );
    });
  });

  group('Lyrics Service API & Validation Tests', () {
    late Directory tempDir;
    late LyricsCacheService cacheService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('lyrics_api_test_');
      cacheService = LyricsCacheService(
        customDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final testTrack = LocalTrack(
      id: 'song_1',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      album: 'After Hours',
      fileName: 'Blinding Lights.mp3',
      relativePath: 'Pop/The Weeknd/Blinding Lights.mp3',
      fileSizeBytes: 5000000,
      lastModified: DateTime.now(),
      duration: const Duration(seconds: 200),
      uri: 'content://music/1',
    );

    test('returns exact match successfully and caches it', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/api/get'));
        expect(
          request.url.queryParameters['track_name'],
          equals('Blinding Lights'),
        );
        expect(
          request.url.queryParameters['artist_name'],
          equals('The Weeknd'),
        );
        expect(request.headers['User-Agent'], contains('ShadowPlayer'));

        final body = jsonEncode({
          'id': 101,
          'trackName': 'Blinding Lights',
          'artistName': 'The Weeknd',
          'albumName': 'After Hours',
          'duration': 200,
          'instrumental': false,
          'syncedLyrics': '[00:10.00] I said, ooh, I\'m blinded by the lights',
          'plainLyrics': 'I said, ooh, I\'m blinded by the lights',
        });

        return http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = LyricsService(
        httpClient: mockClient,
        cacheService: cacheService,
      );

      final result = await service.getLyricsForTrack(testTrack);

      expect(result.status, equals(LyricsFetchStatus.success));
      expect(result.data, isNotNull);
      expect(result.data!.isSynced, isTrue);
      expect(
        result.data!.syncedLines.first.text,
        equals('I said, ooh, I\'m blinded by the lights'),
      );

      // Verify cached on disk
      final cached = await cacheService.getCachedLyrics(
        trackId: testTrack.id,
        title: testTrack.title,
        artist: testTrack.artist,
      );
      expect(cached, isNotNull);
    });

    test('falls back to search endpoint when exact match is 404', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/get') {
          return http.Response('{"error":"Not Found"}', 404);
        } else if (request.url.path == '/api/search') {
          final results = [
            {
              'id': 202,
              'trackName': 'Blinding Lights',
              'artistName': 'The Weeknd',
              'duration': 202, // Within 20s tolerance
              'instrumental': false,
              'syncedLyrics': '[00:15.00] Sin City\'s cold and empty',
              'plainLyrics': 'Sin City\'s cold and empty',
            },
          ];
          return http.Response(jsonEncode(results), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = LyricsService(
        httpClient: mockClient,
        cacheService: cacheService,
      );

      final result = await service.getLyricsForTrack(testTrack);

      expect(result.status, equals(LyricsFetchStatus.success));
      expect(result.data, isNotNull);
      expect(
        result.data!.syncedLines.first.text,
        equals('Sin City\'s cold and empty'),
      );
    });

    test(
      'discards candidate if duration difference exceeds tolerance threshold',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/get') {
            return http.Response('{"error":"Not Found"}', 404);
          } else if (request.url.path == '/api/search') {
            // Candidate with 10-minute live version (600s vs 200s track)
            final results = [
              {
                'id': 303,
                'trackName': 'Blinding Lights (Live 10 Minute Extended Jam)',
                'artistName': 'The Weeknd',
                'duration': 600,
                'syncedLyrics': '[01:00.00] Live lyrics',
              },
            ];
            return http.Response(jsonEncode(results), 200);
          }
          return http.Response('Not Found', 404);
        });

        final service = LyricsService(
          httpClient: mockClient,
          cacheService: cacheService,
        );

        final result = await service.getLyricsForTrack(testTrack);
        expect(result.status, equals(LyricsFetchStatus.notFound));
      },
    );

    test('handles 429 rate limit correctly', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Too many requests', 429);
      });

      final service = LyricsService(
        httpClient: mockClient,
        cacheService: cacheService,
      );

      final result = await service.getLyricsForTrack(testTrack);
      expect(result.status, equals(LyricsFetchStatus.rateLimited));
    });

    test('handles 500 server error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = LyricsService(
        httpClient: mockClient,
        cacheService: cacheService,
      );

      final result = await service.getLyricsForTrack(testTrack);
      expect(result.status, equals(LyricsFetchStatus.serverError));
    });
  });
}
