import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/folder_picker/presentation/folder_selection_screen.dart';
import 'package:music/providers/music_library_provider.dart';
import 'package:music/data/repositories/music_library_repository.dart';
import 'package:music/data/models/music_folder.dart';

import 'package:music/data/models/local_track.dart';

class FakeMusicLibraryRepository extends MusicLibraryRepository {
  bool pickCalled = false;
  MusicFolder? folderToReturn;

  @override
  Future<MusicFolder?> getSavedFolder() async => null;

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
  }) async* {}

  @override
  Future<MusicFolder?> pickFolder() async {
    pickCalled = true;
    return folderToReturn; // null simulates cancellation
  }
}

void main() {
  testWidgets('FolderSelectionScreen displays branding and picker trigger', (
    tester,
  ) async {
    final fakeRepo = FakeMusicLibraryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [musicLibraryRepositoryProvider.overrideWithValue(fakeRepo)],
        child: const MaterialApp(home: FolderSelectionScreen()),
      ),
    );

    // Verify Title and Subtitle
    expect(find.text('Shadow Player'), findsOneWidget);
    expect(find.text('Premium Offline Music Experience'), findsOneWidget);

    // Verify Action button
    final chooseButton = find.text('Choose Music Folder');
    expect(chooseButton, findsOneWidget);

    // Tap action button with cancellation (picker returns null)
    await tester.tap(chooseButton);
    await tester.pumpAndSettle();

    expect(fakeRepo.pickCalled, isTrue);
    // Should still display screen without crash
    expect(find.text('Shadow Player'), findsOneWidget);
  });
}
