import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:saf/saf.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/audio_file_utils.dart';

/// Service interfacing directly with Android Storage Access Framework (SAF).
class SafFolderService {
  final Saf _saf;

  SafFolderService({Saf? saf}) : _saf = saf ?? Saf();

  /// Normalizes a document tree URI to its bare tree form if it has a /document/ segment.
  /// Example:
  /// 'content://com.android.externalstorage.documents/tree/primary%3AMusic/document/primary%3AMusic'
  /// -> 'content://com.android.externalstorage.documents/tree/primary%3AMusic'
  static String normalizeTreeUri(String uri) {
    if (uri.contains('/document/')) {
      return uri.substring(0, uri.indexOf('/document/'));
    }
    return uri;
  }

  /// Prompts the system folder picker (`ACTION_OPEN_DOCUMENT_TREE`) with persisted permissions.
  /// Returns `null` if the user cancelled the picker.
  Future<SafDocumentFile?> pickFolder() async {
    try {
      final picked = await _saf.pickDirectory(
        writePermission: false,
        persistablePermission: true,
      );
      return picked;
    } catch (e) {
      debugPrint('SafFolderService: Error picking directory: $e');
      throw FolderPermissionException('Failed to open system folder picker', e);
    }
  }

  /// Checks if the app currently holds a persisted read permission for [uri] or has active access.
  /// Matches both normalized tree URIs (`tree/<id>`) and document URIs (`tree/<id>/document/<id>`).
  Future<bool> hasPersistedPermission(String uri) async {
    try {
      final normTarget = normalizeTreeUri(uri);
      final permissions = await _saf.persistedPermissions();

      for (final p in permissions) {
        if (!p.read) continue;
        final normP = normalizeTreeUri(p.uri);
        if (normP == normTarget ||
            p.uri == uri ||
            uri.startsWith(p.uri) ||
            normTarget.startsWith(normP)) {
          return true;
        }
      }

      // If not in the persisted list, verify by trying stat / existence:
      final exists = await folderExists(uri);
      if (exists) return true;

      if (normTarget != uri) {
        final normExists = await folderExists(normTarget);
        if (normExists) return true;
      }

      return false;
    } catch (e) {
      debugPrint('SafFolderService: Error checking persisted permissions: $e');
      try {
        return await folderExists(uri);
      } catch (_) {
        return false;
      }
    }
  }

  /// Releases a previously persisted permission for [uri].
  Future<void> releasePermission(String uri) async {
    try {
      await _saf.releasePersistedPermission(uri);
      final norm = normalizeTreeUri(uri);
      if (norm != uri) {
        await _saf.releasePersistedPermission(norm);
      }
    } catch (e) {
      debugPrint('SafFolderService: Error releasing permission for $uri: $e');
    }
  }

  /// Verifies that the folder document still exists and can be accessed.
  Future<bool> folderExists(String uri) async {
    try {
      return await _saf.exists(uri);
    } catch (e) {
      debugPrint('SafFolderService: Error checking folder existence: $e');
      return false;
    }
  }

  /// Obtains metadata for a document at [uri].
  Future<SafDocumentFile?> stat(String uri) async {
    try {
      return await _saf.stat(uri);
    } catch (e) {
      debugPrint('SafFolderService: Error stating document $uri: $e');
      return null;
    }
  }

  /// Recursively walks the given directory URI and yields audio files.
  /// Uses `saf.walk(uri)` with a robust fallback to recursive `list`
  /// if the provider does not support walk or yields 0 entries.
  Stream<SafWalkEntry> discoverAudioFiles(String rootUri) async* {
    var hasEmittedAny = false;
    try {
      await for (final entry in _saf.walk(rootUri)) {
        if (!entry.file.isDir &&
            AudioFileUtils.isSupportedAudio(entry.file.name)) {
          hasEmittedAny = true;
          yield entry;
        }
      }
    } catch (e) {
      debugPrint(
        'SafFolderService: saf.walk failed or unsupported ($e), trying recursive list fallback',
      );
    }

    // If walk emitted nothing (either unsupported, errored, or OEM incompatibility with tree URI),
    // always execute recursive list fallback:
    if (!hasEmittedAny) {
      debugPrint(
        'SafFolderService: Running recursive list traversal on $rootUri',
      );
      var listEmitted = false;
      await for (final entry in _recursiveListFallback(rootUri, '')) {
        listEmitted = true;
        yield entry;
      }

      // If still nothing, attempt with normalized tree URI
      final norm = normalizeTreeUri(rootUri);
      if (!listEmitted && norm != rootUri) {
        debugPrint(
          'SafFolderService: Running recursive list traversal on normalized $norm',
        );
        yield* _recursiveListFallback(norm, '');
      }
    }
  }

  /// Fallback recursive traversal using `saf.list`.
  Stream<SafWalkEntry> _recursiveListFallback(
    String dirUri,
    String currentRelativePath,
  ) async* {
    List<SafDocumentFile> children;
    try {
      children = await _saf.list(dirUri);
    } catch (e) {
      debugPrint('SafFolderService: failed to list directory $dirUri: $e');
      return;
    }

    for (final child in children) {
      final childRelPath = currentRelativePath.isEmpty
          ? child.name
          : '$currentRelativePath/${child.name}';

      if (child.isDir) {
        yield* _recursiveListFallback(child.uri, childRelPath);
      } else if (AudioFileUtils.isSupportedAudio(child.name)) {
        yield SafWalkEntry(file: child, relativePath: childRelPath);
      }
    }
  }

  /// Runs an action with an opened native file descriptor for [uri].
  Future<T> withFileDescriptor<T>(
    String uri,
    String mode,
    Future<T> Function(SafOpenFd) action,
  ) {
    return _saf.withFileDescriptor(uri, mode, action);
  }

  /// Loads a document thumbnail if supported by the document provider.
  Future<Uint8List?> getThumbnail(
    String uri, {
    int width = AppConstants.thumbnailWidth,
    int height = AppConstants.thumbnailHeight,
    int quality = AppConstants.thumbnailQuality,
  }) async {
    try {
      return await _saf.thumbnail(uri, width, height, quality);
    } catch (e) {
      return null;
    }
  }

  /// Copies a document to a local filesystem path (safe temporary cache bridge).
  Future<void> copyToLocalFile(String srcUri, String destPath) async {
    await _saf.copyToLocalFile(srcUri, destPath);
  }
}
