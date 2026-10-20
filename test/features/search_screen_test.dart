import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/data/models/music_folder.dart';
import 'package:music/data/repositories/music_library_repository.dart';
import 'package:music/features/search/presentation/search_screen.dart';
import 'package:music/providers/music_library_provider.dart';

class SearchTestRepository extends MusicLibraryRepository {
  @override
  Future<MusicFolder?> getSavedFolder() async {
    return const MusicFolder(
      uri: 'content://music',
      name: 'Sample',
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
          fileName: 'bohemian_rhapsody.mp3',
          relativePath: 'Queen/bohemian_rhapsody.mp3',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          duration: const Duration(minutes: 5, seconds: 55),
          fileSizeBytes: 9000000,
          lastModified: DateTime(2023, 1, 1),
        ),
        LocalTrack(
          id: '2',
          uri: 'content://2',
          fileName: 'hotel_california.flac',
          relativePath: 'Eagles/hotel_california.flac',
          title: 'Hotel California',
          artist: 'Eagles',
          album: 'Hotel California',
          duration: const Duration(minutes: 6, seconds: 30),
          fileSizeBytes: 24000000,
          lastModified: DateTime(2023, 1, 2),
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
  testWidgets('SearchScreen filters tracks by query and handles empty cases', (
    tester,
  ) async {
    final searchRepo = SearchTestRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicLibraryRepositoryProvider.overrideWithValue(searchRepo),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    // Let the scan stream complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initially displays blank search prompt
    expect(find.text('Search Offline Library'), findsOneWidget);

    // Enter query 'queen' (case-insensitive artist search)
    await tester.enterText(find.byType(TextField), 'queen');
    await tester.pumpAndSettle();

    expect(find.text('Bohemian Rhapsody'), findsOneWidget);
    expect(find.text('Hotel California'), findsNothing);

    // Enter query 'hotel' (title / album search)
    await tester.enterText(find.byType(TextField), 'hotel');
    await tester.pumpAndSettle();

    expect(find.text('Hotel California'), findsOneWidget);
    expect(find.text('Bohemian Rhapsody'), findsNothing);

    // Enter non-matching query
    await tester.enterText(find.byType(TextField), 'nonexistent');
    await tester.pumpAndSettle();

    expect(find.text('No Matching Songs'), findsOneWidget);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Search Offline Library'), findsOneWidget);
  });
}
