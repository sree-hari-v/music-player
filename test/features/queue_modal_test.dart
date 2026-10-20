import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/data/services/audio_player_service.dart';
import 'package:music/features/player/presentation/widgets/queue_modal.dart';
import 'package:music/providers/audio_player_provider.dart';

class TestAudioPlayerService extends AudioPlayerService {
  TestAudioPlayerService();

  @override
  Future<void> playTrack(
    LocalTrack track, {
    LocalTrack? prevTrack,
    LocalTrack? nextTrack,
  }) async {}

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
    fileSizeBytes: 2048,
    lastModified: DateTime.now(),
  );
}

void main() {
  testWidgets(
    'QueueModal renders Now Playing and Next Up tracks with drag handles',
    (tester) async {
      final mockService = TestAudioPlayerService();
      final container = ProviderContainer(
        overrides: [audioPlayerServiceProvider.overrideWithValue(mockService)],
      );

      final t1 = _createTrack('1', 'Bohemian Rhapsody');
      final t2 = _createTrack('2', 'Don\'t Stop Me Now');
      final t3 = _createTrack('3', 'Another One Bites the Dust');

      await container
          .read(audioPlaybackProvider.notifier)
          .playTrack(t1, queue: [t1, t2, t3]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: QueueModal())),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Queue title
      expect(find.text('Queue'), findsOneWidget);

      // Verify Now Playing section
      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Bohemian Rhapsody'), findsOneWidget);

      // Verify Next Up section and upcoming tracks
      expect(find.text('Next Up'), findsOneWidget);
      expect(find.text('2 tracks'), findsOneWidget);
      expect(find.text('Don\'t Stop Me Now'), findsOneWidget);
      expect(find.text('Another One Bites the Dust'), findsOneWidget);

      // Verify drag handle icons exist for upcoming tracks
      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    },
  );
}
