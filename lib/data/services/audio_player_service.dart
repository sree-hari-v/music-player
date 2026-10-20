import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_track.dart';
import 'saf_folder_service.dart';

enum PlayerRepeatMode { off, all, one }

/// Service wrapping just_audio for offline SAF audio playback.
class AudioPlayerService {
  static AudioPlayer? _sharedPlayer;
  static AudioPlayer get _playerInstance => _sharedPlayer ??= AudioPlayer();

  final AudioPlayer _player;
  final SafFolderService _safService;
  final bool _isCustomPlayer;

  AudioPlayerService({AudioPlayer? player, SafFolderService? safService})
    : _player = player ?? _playerInstance,
      _safService = safService ?? SafFolderService(),
      _isCustomPlayer = player != null;

  AudioPlayer get player => _player;

  final int _activeWindowIndex = 0;
  int get activeWindowIndex => _activeWindowIndex;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<double> get volumeStream => _player.volumeStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;
  double get volume => _player.volume;

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Resolves an audio track's playable filesystem path or URI.
  /// For SAF document URIs (content://...), bridges through a local playback cache
  /// using native SAF copy so ExoPlayer can decode and stream the audio reliably.
  Future<String> _resolvePlaybackPath(LocalTrack track) async {
    // If it's already a standard filesystem path
    if (!track.uri.startsWith('content://')) {
      if (track.uri.startsWith('file://')) {
        return Uri.parse(track.uri).toFilePath();
      }
      final directFile = File(track.uri);
      if (directFile.existsSync()) {
        return directFile.path;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/playback_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Preserve file extension so decoder can identify audio format
      final ext = track.fileName.contains('.')
          ? '.${track.fileName.split('.').last}'
          : '.mp3';
      final cleanId = track.id.hashCode.abs();
      final cachedFile = File('${cacheDir.path}/$cleanId$ext');

      // Reuse cached copy if non-empty and matching size
      if (await cachedFile.exists()) {
        final length = await cachedFile.length();
        if (length > 0 &&
            (track.fileSizeBytes <= 0 || length == track.fileSizeBytes)) {
          return cachedFile.path;
        } else {
          try {
            await cachedFile.delete();
          } catch (_) {}
        }
      }

      // Copy from SAF content URI to local playback cache
      await _safService.copyToLocalFile(track.uri, cachedFile.path);

      if (await cachedFile.exists() && await cachedFile.length() > 0) {
        _maintainCache(cacheDir);
        return cachedFile.path;
      }
    } catch (e) {
      debugPrint(
        'AudioPlayerService: Error preparing local cache for ${track.title}: $e',
      );
    }

    // Fallback: return the raw track URI
    return track.uri;
  }

  /// Prunes old cache files when cache exceeds 20 items to conserve storage.
  void _maintainCache(Directory cacheDir) {
    Future.microtask(() async {
      try {
        final files = cacheDir.listSync().whereType<File>().toList();
        if (files.length > 20) {
          files.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
          );
          for (var i = 0; i < files.length - 20; i++) {
            try {
              files[i].deleteSync();
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }

  /// Resolves the album art URI for Android notification and lock screen display.
  /// Writes embedded artwork bytes to a temporary cache file if available.
  Future<Uri?> _resolveArtUri(LocalTrack track) async {
    if (track.albumArtPath != null && File(track.albumArtPath!).existsSync()) {
      return Uri.file(track.albumArtPath!);
    }

    try {
      if (track.albumArtBytes != null && track.albumArtBytes!.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final artDir = Directory('${tempDir.path}/notification_art');
        if (!await artDir.exists()) {
          await artDir.create(recursive: true);
        }

        final cleanId = track.id.hashCode.abs();
        final artFile = File('${artDir.path}/$cleanId.jpg');
        if (!await artFile.exists() || (await artFile.length()) == 0) {
          await artFile.writeAsBytes(track.albumArtBytes!, flush: true);
        }
        return Uri.file(artFile.path);
      }
    } catch (e) {
      debugPrint(
        'AudioPlayerService: Error resolving artUri for ${track.title}: $e',
      );
    }
    return null;
  }

  /// Builds an AudioSource for local/SAF audio playback.
  Future<AudioSource> _createAudioSource(LocalTrack track) async {
    final resolvedPath = await _resolvePlaybackPath(track);

    final Uri audioUri =
        (resolvedPath.startsWith('content://') || resolvedPath.startsWith('http'))
            ? Uri.parse(resolvedPath)
            : Uri.file(resolvedPath);

    return AudioSource.uri(audioUri);
  }

  /// Silently pre-caches a track into the local playback cache.
  void preloadTrack(LocalTrack track) {
    _resolvePlaybackPath(track).catchError((_) => track.uri);
  }

  /// Loads and plays a local track with lock screen / notification media tag.
  Future<void> playTrack(
    LocalTrack track, {
    LocalTrack? prevTrack,
    LocalTrack? nextTrack,
  }) async {
    try {
      final currentSource = await _createAudioSource(track);

      // Pre-cache next track in background if available
      if (nextTrack != null) {
        preloadTrack(nextTrack);
      }

      await _player.setAudioSource(currentSource);
      await _player.play();
    } on PlayerInterruptedException {
      // Ignored: new track requested before previous completed loading
    } catch (e) {
      debugPrint('AudioPlayerService: Error playing ${track.title}: $e');
      rethrow;
    }
  }

  /// Loads and plays a content URI track directly.
  Future<void> playUri(String contentUri) async {
    try {
      final audioSource = AudioSource.uri(Uri.parse(contentUri));
      await _player.setAudioSource(audioSource);
      await _player.play();
    } catch (e) {
      debugPrint('AudioPlayerService: Error playing URI $contentUri: $e');
      rethrow;
    }
  }

  Future<void> play() async => await _player.play();
  Future<void> pause() async => await _player.pause();
  Future<void> stop() async => await _player.stop();
  Future<void> seek(Duration position) async => await _player.seek(position);

  Future<void> dispose() async {
    if (_isCustomPlayer) {
      await _player.dispose();
    }
  }
}
