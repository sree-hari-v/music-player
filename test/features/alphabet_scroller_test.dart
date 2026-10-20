import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/shared/widgets/alphabet_fast_scroller.dart';

LocalTrack _makeTrack(String id, String title) {
  return LocalTrack(
    id: id,
    uri: 'content://test/$id',
    fileName: '$title.mp3',
    relativePath: '$title.mp3',
    title: title,
    artist: 'Artist',
    album: 'Album',
    fileSizeBytes: 1024,
    lastModified: DateTime(2024, 1, 1),
  );
}

void main() {
  testWidgets('AlphabetFastScroller renders scroller and jumps on tap', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final tracks = List.generate(
      26,
      (i) => _makeTrack('$i', '${String.fromCharCode(65 + i)} Track'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: AlphabetFastScroller(
              scrollController: scrollController,
              tracks: tracks,
              itemHeight: 60.0,
              child: ListView.builder(
                controller: scrollController,
                itemCount: tracks.length,
                itemBuilder: (context, index) => SizedBox(
                  height: 60,
                  child: Text(tracks[index].title),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify alphabet letter bar is rendered
    expect(find.text('A'), findsWidgets);
    expect(find.text('Z'), findsWidgets);

    // Verify top and bottom jump buttons exist
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    // Tap Jump to Bottom
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(scrollController.offset, greaterThan(0));

    // Tap Jump to Top
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();

    expect(scrollController.offset, equals(0.0));
  });
}
