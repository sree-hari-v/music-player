import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/data/models/local_track.dart';
import 'package:music/data/models/music_folder.dart';
import 'package:music/data/repositories/music_library_repository.dart';
import 'package:music/data/services/audio_metadata_service.dart';
import 'package:music/data/services/saf_folder_service.dart';
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSafFolderService extends SafFolderService {
  bool hasPermission = true;
  bool exists = true;
  List<SafWalkEntry> filesToEmit = [];

  @override
  Future<bool> hasPersistedPermission(String uri) async => hasPermission;

  @override
  Future<bool> folderExists(String uri) async => exists;

  @override
  Stream<SafWalkEntry> discoverAudioFiles(String rootUri) async* {
    for (final entry in filesToEmit) {
      yield entry;
    }
  }

  @override
  Future<SafDocumentFile?> pickFolder() async {
    return const SafDocumentFile(
      uri: 'content://com.android.externalstorage.documents/tree/primary%3AMusic',
      name: 'Music',
      isDir: true,
      length: 0,
      lastModified: 1700000000000,
    );
  }

  @override
  Future<void> releasePermission(String uri) async {
    hasPermission = false;
  }
}

class MockAudioMetadataService extends AudioMetadataService {
  @override
  Future<LocalTrack> extractMetadata(SafWalkEntry entry) async {
    return LocalTrack(
      id: entry.file.uri,
      uri: entry.file.uri,
      fileName: entry.file.name,
      relativePath: entry.relativePath,
      title: 'Mock ${entry.file.name}',
      artist: 'Mock Artist',
      album: 'Mock Album',
      duration: const Duration(minutes: 3, seconds: 30),
      fileSizeBytes: entry.file.length,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        entry.file.lastModified,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSafFolderService mockSafService;
  late MockAudioMetadataService mockMetadataService;
  late MusicLibraryRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    mockSafService = MockSafFolderService();
    mockMetadataService = MockAudioMetadataService();
    repository = MusicLibraryRepositoryImpl(
      safService: mockSafService,
      metadataService: mockMetadataService,
      prefs: prefs,
    );
  });

  group('MusicLibraryRepository - Folder Persistence', () {
    test('returns null when no folder has been saved', () async {
      final saved = await repository.getSavedFolder();
      expect(saved, isNull);
    });

    test(
      'saves and retrieves folder accurately with active permission',
      () async {
        const folder = MusicFolder(
          uri: 'content://media/external/folder/1',
          name: 'My Tunes',
        );

        await repository.saveFolder(folder);
        final retrieved = await repository.getSavedFolder();

        expect(retrieved, isNotNull);
        expect(retrieved!.uri, equals(folder.uri));
        expect(retrieved.name, equals('My Tunes'));
        expect(retrieved.hasValidPermission, isTrue);
      },
    );

    test('detects revoked permission on startup', () async {
      const folder = MusicFolder(
        uri: 'content://media/external/folder/1',
        name: 'My Tunes',
      );

      await repository.saveFolder(folder);
      mockSafService.hasPermission = false;

      final retrieved = await repository.getSavedFolder();
      expect(retrieved, isNotNull);
      expect(retrieved!.hasValidPermission, isFalse);
    });

    test(
      'clearing saved folder removes prefs and releases permission',
      () async {
        const folder = MusicFolder(
          uri: 'content://media/external/folder/1',
          name: 'My Tunes',
        );

        await repository.saveFolder(folder);
        await repository.clearSavedFolder();

        final retrieved = await repository.getSavedFolder();
        expect(retrieved, isNull);
        expect(mockSafService.hasPermission, isFalse);
      },
    );
  });

  group('MusicLibraryRepository - Scanning and Deduplication', () {
    test(
      'scans folder and emits discovered tracks with deduplication',
      () async {
        mockSafService.filesToEmit = [
          const SafWalkEntry(
            file: SafDocumentFile(
              uri: 'content://media/external/audio/1',
              name: 'song1.mp3',
              isDir: false,
              length: 4096000,
              lastModified: 1700000000000,
            ),
            relativePath: 'song1.mp3',
          ),
          const SafWalkEntry(
            file: SafDocumentFile(
              uri: 'content://media/external/audio/2',
              name: 'song2.flac',
              isDir: false,
              length: 12000000,
              lastModified: 1700000010000,
            ),
            relativePath: 'Rock/song2.flac',
          ),
          // Duplicate URI should be deduplicated
          const SafWalkEntry(
            file: SafDocumentFile(
              uri: 'content://media/external/audio/1',
              name: 'song1.mp3',
              isDir: false,
              length: 4096000,
              lastModified: 1700000000000,
            ),
            relativePath: 'song1.mp3',
          ),
        ];

        final updates = await repository
            .scanFolder('content://folder')
            .toList();

        expect(updates.isNotEmpty, isTrue);
        final lastUpdate = updates.last;
        expect(lastUpdate.isComplete, isTrue);
        expect(lastUpdate.tracks.length, equals(2));
        expect(
          lastUpdate.tracks.map((t) => t.fileName),
          containsAll(['song1.mp3', 'song2.flac']),
        );
      },
    );

    test('reports error when permission is missing before scan', () async {
      mockSafService.hasPermission = false;

      final updates = await repository.scanFolder('content://folder').toList();
      expect(updates.length, equals(1));
      expect(updates.first.error, isNotNull);
      expect(
        updates.first.error!.message,
        contains('permission for this folder has been revoked'),
      );
    });
  });
}
