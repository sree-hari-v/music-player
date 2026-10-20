import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/constants/app_constants.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/data/services/audio_player_service.dart';
import 'package:music/providers/audio_player_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioPlayerService extends AudioPlayerService {
  MockAudioPlayerService();

  LocalTrack? lastPlayedTrack;
  LocalTrack? lastPrevTrack;
  LocalTrack? lastNextTrack;

  @override
  Future<void> playTrack(
    LocalTrack track, {
    LocalTrack? prevTrack,
    LocalTrack? nextTrack,
  }) async {
    lastPlayedTrack = track;
    lastPrevTrack = prevTrack;
    lastNextTrack = nextTrack;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}
}

LocalTrack _createTrack(String id, String title) {
  return LocalTrack(
    id: id,
    uri: 'content://media/$id',
    fileName: '$id.mp3',
    relativePath: '$id.mp3',
    title: title,
    artist: 'Artist $id',
    album: 'Album $id',
    fileSizeBytes: 1024,
    lastModified: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAudioPlayerService mockService;
  late AudioPlaybackNotifier notifier;

  setUp(() {
    mockService = MockAudioPlayerService();
    notifier = AudioPlaybackNotifier(mockService);
  });

  tearDown(() {
    notifier.dispose();
  });

  group('AudioPlaybackNotifier - Queue & Reordering', () {
    test(
      'plays track and sets active queue with stable uniqueQueueId',
      () async {
        final t1 = _createTrack('1', 'Song 1');
        final t2 = _createTrack('2', 'Song 2');
        final t3 = _createTrack('3', 'Song 3');

        await notifier.playTrack(t1, queue: [t1, t2, t3]);

        expect(notifier.state.currentTrack?.id, equals('1'));
        expect(notifier.state.queueIndex, equals(0));
        expect(notifier.state.queue.length, equals(3));
        expect(notifier.state.upcomingTracks.length, equals(2));
        expect(notifier.state.upcomingTracks[0].title, equals('Song 2'));
        expect(notifier.state.upcomingTracks[1].title, equals('Song 3'));

        // Ensure stable unique queue keys were assigned
        expect(notifier.state.upcomingTracks[0].uniqueQueueId, isNotEmpty);
        expect(notifier.state.upcomingTracks[1].uniqueQueueId, isNotEmpty);
        expect(
          notifier.state.upcomingTracks[0].uniqueQueueId,
          isNot(equals(notifier.state.upcomingTracks[1].uniqueQueueId)),
        );
      },
    );

    test('reorders upcoming queue downwards correctly', () async {
      final t1 = _createTrack('1', 'Song 1');
      final t2 = _createTrack('2', 'Song 2');
      final t3 = _createTrack('3', 'Song 3');
      final t4 = _createTrack('4', 'Song 4');

      await notifier.playTrack(t1, queue: [t1, t2, t3, t4]);

      // Upcoming tracks are: Song 2 (0), Song 3 (1), Song 4 (2)
      // Drag Song 2 below Song 3 -> Flutter passes oldIndex: 0, newIndex: 2
      notifier.reorderQueue(0, 2);

      expect(notifier.state.upcomingTracks.length, equals(3));
      expect(notifier.state.upcomingTracks[0].title, equals('Song 3'));
      expect(notifier.state.upcomingTracks[1].title, equals('Song 2'));
      expect(notifier.state.upcomingTracks[2].title, equals('Song 4'));
    });

    test('reorders upcoming queue upwards correctly', () async {
      final t1 = _createTrack('1', 'Song 1');
      final t2 = _createTrack('2', 'Song 2');
      final t3 = _createTrack('3', 'Song 3');
      final t4 = _createTrack('4', 'Song 4');

      await notifier.playTrack(t1, queue: [t1, t2, t3, t4]);

      // Upcoming tracks are: Song 2 (0), Song 3 (1), Song 4 (2)
      // Drag Song 4 above Song 2 -> Flutter passes oldIndex: 2, newIndex: 0
      notifier.reorderQueue(2, 0);

      expect(notifier.state.upcomingTracks.length, equals(3));
      expect(notifier.state.upcomingTracks[0].title, equals('Song 4'));
      expect(notifier.state.upcomingTracks[1].title, equals('Song 2'));
      expect(notifier.state.upcomingTracks[2].title, equals('Song 3'));
    });

    test('removes track from upcoming queue', () async {
      final t1 = _createTrack('1', 'Song 1');
      final t2 = _createTrack('2', 'Song 2');
      final t3 = _createTrack('3', 'Song 3');

      await notifier.playTrack(t1, queue: [t1, t2, t3]);

      // Remove relative index 0 (Song 2)
      notifier.removeFromQueue(0);

      expect(notifier.state.upcomingTracks.length, equals(1));
      expect(notifier.state.upcomingTracks[0].title, equals('Song 3'));
    });

    test('clears upcoming tracks', () async {
      final t1 = _createTrack('1', 'Song 1');
      final t2 = _createTrack('2', 'Song 2');
      final t3 = _createTrack('3', 'Song 3');

      await notifier.playTrack(t1, queue: [t1, t2, t3]);
      notifier.clearUpcomingQueue();

      expect(notifier.state.currentTrack?.title, equals('Song 1'));
      expect(notifier.state.upcomingTracks, isEmpty);
      expect(notifier.state.queue.length, equals(1));
    });

    test(
      'playTrackAtIndex switches current track without resetting queue order',
      () async {
        final t1 = _createTrack('1', 'Song 1');
        final t2 = _createTrack('2', 'Song 2');
        final t3 = _createTrack('3', 'Song 3');

        await notifier.playTrack(t1, queue: [t1, t2, t3]);

        // Play queue index 2 (Song 3)
        await notifier.playTrackAtIndex(2);

        expect(notifier.state.currentTrack?.title, equals('Song 3'));
        expect(notifier.state.queueIndex, equals(2));
        expect(notifier.state.upcomingTracks, isEmpty);
      },
    );

    test(
      'passes previous and next track context for media notification controls',
      () async {
        final t1 = _createTrack('1', 'Song 1');
        final t2 = _createTrack('2', 'Song 2');
        final t3 = _createTrack('3', 'Song 3');

        await notifier.playTrack(t2, queue: [t1, t2, t3]);

        expect(mockService.lastPlayedTrack?.title, equals('Song 2'));
        expect(mockService.lastPrevTrack?.title, equals('Song 1'));
        expect(mockService.lastNextTrack?.title, equals('Song 3'));
      },
    );

    test('auto saves played track to SharedPreferences and restores on init', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifierWithPrefs = AudioPlaybackNotifier(mockService, prefs: prefs);

      final track = _createTrack('42', 'Saved Song');
      await notifierWithPrefs.playTrack(track);

      // Verify track was auto-saved to SharedPreferences
      final savedJson = prefs.getString(AppConstants.keyLastPlayedTrackJson);
      expect(savedJson, isNotNull);
      expect(savedJson, contains('Saved Song'));

      notifierWithPrefs.dispose();

      // Create a new notifier simulating app restart
      final restoredNotifier = AudioPlaybackNotifier(mockService, prefs: prefs);
      expect(restoredNotifier.state.currentTrack?.title, equals('Saved Song'));
      expect(restoredNotifier.state.currentTrack?.id, equals('42'));
      expect(restoredNotifier.state.isMiniPlayerVisible, isTrue);
      expect(restoredNotifier.state.isPlaying, isFalse);

      restoredNotifier.dispose();
    });

    test('loops back to first track when playNext is called at the end of queue', () async {
      final t1 = _createTrack('1', 'Song 1');
      final t2 = _createTrack('2', 'Song 2');
      final t3 = _createTrack('3', 'Song 3');

      await notifier.playTrack(t3, queue: [t1, t2, t3]);
      expect(notifier.state.queueIndex, equals(2));

      await notifier.playNext();
      // Should loop back to index 0 (first song)
      expect(notifier.state.queueIndex, equals(0));
      expect(notifier.state.currentTrack?.id, equals('1'));
    });

    test('stopAndCloseApp sets playing and miniplayer visibility to false', () async {
      final t1 = _createTrack('1', 'Song 1');
      await notifier.playTrack(t1);
      expect(notifier.state.isPlaying, isTrue);

      await notifier.stopAndCloseApp();
      expect(notifier.state.isPlaying, isFalse);
      expect(notifier.state.isMiniPlayerVisible, isFalse);
    });
  });
}
