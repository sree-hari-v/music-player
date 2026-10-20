import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/app/app.dart';
import 'package:music/data/models/music_folder.dart';
import 'package:music/data/repositories/music_library_repository.dart';
import 'package:music/providers/music_library_provider.dart';

import 'package:music/data/models/local_track.dart';

class SmokeTestRepository extends MusicLibraryRepository {
  @override
  Future<MusicFolder?> getSavedFolder() async => null;

  @override
  Future<void> saveFolder(MusicFolder folder) async {}

  @override
  Future<void> clearSavedFolder() async {}

  @override
  Future<bool> checkPermissionValid(String folderUri) async => false;

  @override
  Stream<ScanProgressUpdate> scanFolder(
    String folderUri, {
    List<LocalTrack>? initialTracks,
  }) async* {}

  @override
  Future<MusicFolder?> pickFolder() async => null;
}

void main() {
  testWidgets('ShadowPlayerApp launches with onboarding folder picker view', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicLibraryRepositoryProvider.overrideWithValue(
            SmokeTestRepository(),
          ),
        ],
        child: const ShadowPlayerApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Shadow Player'), findsWidgets);
    expect(find.text('Choose Music Folder'), findsOneWidget);
  });
}
