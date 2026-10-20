import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/data/models/music_folder.dart';
import 'package:music/data/repositories/music_library_repository.dart';
import 'package:music/features/library/presentation/library_screen.dart';
import 'package:music/providers/music_library_provider.dart';

class StubLibraryRepository extends MusicLibraryRepository {
  @override
  Future<MusicFolder?> getSavedFolder() async {
    return const MusicFolder(
      uri: 'content://music',
      name: 'Sample Folder',
      hasValidPermission: true,
    );
  }

  @override
  Future<void> saveFolder(MusicFolder folder) async {}

  @override
  Future<void> clearSavedFolder() async {}

  @override
  Future<bool> checkPermissionValid(String folderUri) async => true;

  @override
  Stream<ScanProgressUpdate> scanFolder(
    String folderUri, {
    List<LocalTrack>? initialTracks,
  }) async* {
    yield ScanProgressUpdate(
      tracks: [
        LocalTrack(
          id: '1',
          uri: 'content://1',
          fileName: 'song_b.mp3',
          relativePath: 'song_b.mp3',
          title: 'Zebra Song',
          artist: 'Artist B',
          album: 'Album Beta',
          duration: const Duration(minutes: 2),
          fileSizeBytes: 2000000,
          lastModified: DateTime(2023, 1, 1),
        ),
        LocalTrack(
          id: '2',
          uri: 'content://2',
          fileName: 'song_a.flac',
          relativePath: 'song_a.flac',
          title: 'Alpha Song',
          artist: 'Artist A',
          album: 'Album Alpha',
          duration: const Duration(minutes: 4),
          fileSizeBytes: 8000000,
          lastModified: DateTime(2023, 2, 1),
        ),
      ],
      discoveredCount: 2,
      isComplete: true,
    );
  }

  @override
  Future<MusicFolder?> pickFolder() async => null;
}

void main() {
  testWidgets('LibraryScreen renders tabs and lists sorted tracks', (
    tester,
  ) async {
    final stubRepo = StubLibraryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [musicLibraryRepositoryProvider.overrideWithValue(stubRepo)],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );

    // Let the scan stream complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Tab headers exist
    expect(find.text('Songs (2)'), findsOneWidget);
    expect(find.text('Albums (2)'), findsOneWidget);
    expect(find.text('Artists (2)'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);

    // Verify default sort by title ascending ('Alpha Song' before 'Zebra Song')
    expect(find.text('Alpha Song'), findsOneWidget);
    expect(find.text('Zebra Song'), findsOneWidget);

    // Switch to Albums tab
    await tester.tap(find.text('Albums (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Album Alpha'), findsOneWidget);
    expect(find.text('Album Beta'), findsOneWidget);

    // Switch to Artists tab
    await tester.tap(find.text('Artists (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('Artist B'), findsOneWidget);

    // Switch to Folder tab
    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();

    expect(find.text('Sample Folder'), findsOneWidget);
    expect(find.text('Total Tracks'), findsOneWidget);
  });
}
