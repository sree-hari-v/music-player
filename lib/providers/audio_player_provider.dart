import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/local_track.dart';
import '../data/services/audio_player_service.dart';
import '../data/services/device_volume_service.dart';
import '../data/services/notification_service.dart';
import 'music_library_provider.dart';

class AudioPlaybackState {
  final LocalTrack? currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final List<LocalTrack> queue;
  final int queueIndex;
  final bool isShuffle;
  final PlayerRepeatMode repeatMode;
  final String? errorMessage;
  final bool isMiniPlayerVisible;
  final double volume;

  const AudioPlaybackState({
    this.currentTrack,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.queueIndex = 0,
    this.isShuffle = false,
    this.repeatMode = PlayerRepeatMode.off,
    this.errorMessage,
    this.isMiniPlayerVisible = false,
    this.volume = 1.0,
  });

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    final val = position.inMilliseconds / duration.inMilliseconds;
    return val.clamp(0.0, 1.0);
  }

  /// Returns upcoming tracks that will play next in exact playback sequence.
  List<LocalTrack> get upcomingTracks {
    if (queue.isEmpty || queueIndex >= queue.length - 1) {
      return const [];
    }
    return queue.sublist(queueIndex + 1);
  }

  AudioPlaybackState copyWith({
    LocalTrack? currentTrack,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    List<LocalTrack>? queue,
    int? queueIndex,
    bool? isShuffle,
    PlayerRepeatMode? repeatMode,
    String? errorMessage,
    bool? isMiniPlayerVisible,
    double? volume,
    bool clearCurrentTrack = false,
  }) {
    return AudioPlaybackState(
      currentTrack: clearCurrentTrack
          ? null
          : (currentTrack ?? this.currentTrack),
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isShuffle: isShuffle ?? this.isShuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      errorMessage: errorMessage ?? this.errorMessage,
      isMiniPlayerVisible: isMiniPlayerVisible ?? this.isMiniPlayerVisible,
      volume: volume ?? this.volume,
    );
  }
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

final deviceVolumeServiceProvider = Provider<DeviceVolumeService>((ref) {
  final service = DeviceVolumeService();
  ref.onDispose(() => service.dispose());
  return service;
});

final audioPlaybackProvider =
    StateNotifierProvider<AudioPlaybackNotifier, AudioPlaybackState>((ref) {
      final service = ref.watch(audioPlayerServiceProvider);
      final volumeService = ref.watch(deviceVolumeServiceProvider);
      final prefs = ref.watch(sharedPreferencesProvider);
      return AudioPlaybackNotifier(
        service,
        volumeService: volumeService,
        prefs: prefs,
      );
    });

class AudioPlaybackNotifier extends StateNotifier<AudioPlaybackState> {
  final AudioPlayerService _service;
  final DeviceVolumeService _volumeService;
  final SharedPreferences? _prefs;
  final Random _random = Random();

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _volumeSub;
  bool _isChangingTrack = false;
  DateTime _lastSavedPositionTime = DateTime.fromMillisecondsSinceEpoch(0);

  AudioPlaybackNotifier(
    this._service, {
    DeviceVolumeService? volumeService,
    SharedPreferences? prefs,
  })  : _volumeService = volumeService ?? DeviceVolumeService(),
        // ignore: prefer_initializing_formals
        _prefs = prefs,
        super(const AudioPlaybackState()) {
    _initStreams();
    _initNotificationActions();
    _restoreLastPlayedTrack();
  }

  void _initNotificationActions() {
    NotificationService.registerActionHandler((action, extra) {
      if (!mounted) return;
      switch (action) {
        case 'playPause':
          togglePlayPause();
          break;
        case 'play':
          if (!state.isPlaying) togglePlayPause();
          break;
        case 'pause':
          if (state.isPlaying) togglePlayPause();
          break;
        case 'next':
          playNext();
          break;
        case 'prev':
          playPrevious();
          break;
        case 'seek':
          if (extra is num) {
            seek(Duration(milliseconds: extra.toInt()));
          }
          break;
        case 'shuffle':
          toggleShuffle();
          _syncNotification();
          break;
        case 'rewind':
          final newPos = state.position - const Duration(seconds: 10);
          seek(newPos < Duration.zero ? Duration.zero : newPos);
          break;
        case 'stop':
          stopPlayback();
          break;
      }
    });
  }

  void _syncNotification({bool? isPlayingOverride}) {
    final track = state.currentTrack;
    if (track == null) {
      NotificationService.clearNotification();
      return;
    }

    final playing = isPlayingOverride ?? state.isPlaying;
    NotificationService.updateNotification(
      title: track.title,
      artist: track.artist,
      album: track.album,
      isPlaying: playing,
      positionMs: state.position.inMilliseconds,
      durationMs: (track.duration ?? state.duration).inMilliseconds,
      artPath: track.albumArtPath,
      artBytes: track.albumArtBytes,
      hasNext: state.queue.isNotEmpty,
      hasPrev: state.queue.isNotEmpty,
      isShuffle: state.isShuffle,
    );
  }

  void _restoreLastPlayedTrack() {
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final trackJson = prefs.getString(AppConstants.keyLastPlayedTrackJson);
      if (trackJson == null || trackJson.isEmpty) return;

      final trackMap = jsonDecode(trackJson) as Map<String, dynamic>;
      final track = LocalTrack.fromJson(trackMap);

      final posMs = prefs.getInt(AppConstants.keyLastPlayedPositionMs) ?? 0;
      final savedPos = Duration(milliseconds: posMs);

      List<LocalTrack> queue = [track];
      int queueIndex = 0;

      final queueJson = prefs.getString(AppConstants.keyLastPlayedQueue);
      if (queueJson != null && queueJson.isNotEmpty) {
        final list = jsonDecode(queueJson) as List<dynamic>;
        queue = list
            .map((e) => LocalTrack.fromJson(e as Map<String, dynamic>))
            .toList();
        queueIndex = prefs.getInt(AppConstants.keyLastPlayedQueueIndex) ?? 0;
        if (queueIndex < 0 || queueIndex >= queue.length) queueIndex = 0;
      }

      state = state.copyWith(
        currentTrack: track,
        position: savedPos,
        duration: track.duration ?? Duration.zero,
        queue: queue,
        queueIndex: queueIndex,
        isMiniPlayerVisible: true,
        isPlaying: false,
      );
    } catch (e) {
      debugPrint('AudioPlaybackNotifier: Error restoring last played track: $e');
    }
  }

  Future<void> _saveLastPlayedTrack(LocalTrack track) async {
    final prefs = _prefs;
    if (prefs == null || !mounted) return;

    final posMs = state.position.inMilliseconds;
    final queueIndex = state.queueIndex;
    final queueToSave = state.queue.isNotEmpty
        ? state.queue.take(50).map((t) => t.toJson()).toList()
        : null;

    try {
      await prefs.setString(
        AppConstants.keyLastPlayedTrackJson,
        jsonEncode(track.toJson()),
      );
      await prefs.setInt(AppConstants.keyLastPlayedPositionMs, posMs);
      await prefs.setInt(AppConstants.keyLastPlayedQueueIndex, queueIndex);

      if (queueToSave != null) {
        await prefs.setString(
          AppConstants.keyLastPlayedQueue,
          jsonEncode(queueToSave),
        );
      }
    } catch (e) {
      debugPrint('AudioPlaybackNotifier: Error saving last played track: $e');
    }
  }

  void _persistPosition(Duration pos) {
    final prefs = _prefs;
    if (prefs == null) return;
    final now = DateTime.now();
    if (now.difference(_lastSavedPositionTime).inSeconds >= 3) {
      _lastSavedPositionTime = now;
      prefs.setInt(AppConstants.keyLastPlayedPositionMs, pos.inMilliseconds);
    }
  }

  void _initStreams() {
    _playerStateSub = _service.playerStateStream.listen((playerState) {
      if (!mounted) return;
      final isPlaying = playerState.playing;
      final isBuffering =
          playerState.processingState == ProcessingState.buffering ||
          playerState.processingState == ProcessingState.loading;

      state = state.copyWith(isPlaying: isPlaying, isBuffering: isBuffering);
      _syncNotification(isPlayingOverride: isPlaying);

      if (!isPlaying) {
        _prefs?.setInt(
          AppConstants.keyLastPlayedPositionMs,
          state.position.inMilliseconds,
        );
      }

      // Handle track completion
      if (playerState.processingState == ProcessingState.completed) {
        if (!_isChangingTrack) {
          _onTrackCompleted();
        }
      }
    });

    _positionSub = _service.positionStream.listen((pos) {
      if (mounted) {
        state = state.copyWith(position: pos);
        _persistPosition(pos);
      }
    });

    _durationSub = _service.durationStream.listen((dur) {
      if (dur != null && mounted) {
        state = state.copyWith(duration: dur);
      }
    });

    // Device hardware volume subscription
    _volumeSub = _volumeService.volumeStream.listen((vol) {
      if (mounted) {
        state = state.copyWith(volume: vol);
      }
    });

    _volumeService.getVolume().then((vol) {
      if (mounted) {
        state = state.copyWith(volume: vol);
      }
    });
  }

  void _onTrackCompleted() {
    if (state.repeatMode == PlayerRepeatMode.one) {
      seek(Duration.zero);
      _service.play();
      return;
    }

    if (state.queue.isEmpty) return;

    if (state.queueIndex < state.queue.length - 1) {
      playNext();
    } else {
      // Loop back to the first song when last song in library/queue is finished
      playTrackAtIndex(0);
    }
  }

  int _queueCounter = 0;

  LocalTrack _withQueueKey(LocalTrack track) {
    if (track.queueKey != null && track.queueKey!.isNotEmpty) {
      return track;
    }
    _queueCounter++;
    return track.copyWith(
      queueKey:
          '${track.id}_${DateTime.now().microsecondsSinceEpoch}_$_queueCounter',
    );
  }

  /// Plays a specific track and sets the active playback queue.
  Future<void> playTrack(LocalTrack track, {List<LocalTrack>? queue}) async {
    // If clicking the track that is already loaded
    if (state.currentTrack?.id == track.id &&
        _service.player.audioSource != null) {
      if (!state.isPlaying) {
        await _service.play();
      }
      return;
    }

    final activeQueue =
        queue ?? (state.queue.isNotEmpty ? state.queue : [track]);
    final keyedQueue = activeQueue.map(_withQueueKey).toList();
    final index = keyedQueue.indexWhere((t) => t.id == track.id);
    final targetIndex = index >= 0 ? index : 0;

    List<LocalTrack> finalQueue = List<LocalTrack>.from(keyedQueue);

    // If shuffle is enabled, shuffle the upcoming tracks so the queue displays in that order
    if (state.isShuffle && finalQueue.length > targetIndex + 1) {
      final currentAndBefore = finalQueue.sublist(0, targetIndex + 1);
      final upcoming = List<LocalTrack>.from(
        finalQueue.sublist(targetIndex + 1),
      )..shuffle(_random);
      finalQueue = [...currentAndBefore, ...upcoming];
    }

    final targetTrack = finalQueue.isNotEmpty
        ? finalQueue[targetIndex]
        : _withQueueKey(track);

    state = state.copyWith(
      currentTrack: targetTrack,
      queue: finalQueue,
      queueIndex: targetIndex,
      isMiniPlayerVisible: true,
      errorMessage: null,
      position: Duration.zero,
      duration: targetTrack.duration ?? Duration.zero,
      isPlaying: true,
    );

    _saveLastPlayedTrack(targetTrack);
    _syncNotification(isPlayingOverride: true);

    LocalTrack? prevTrack;
    LocalTrack? nextTrack;
    if (targetIndex > 0) {
      prevTrack = finalQueue[targetIndex - 1];
    } else if (state.repeatMode == PlayerRepeatMode.all &&
        finalQueue.length > 1) {
      prevTrack = finalQueue.last;
    }
    if (targetIndex < finalQueue.length - 1) {
      nextTrack = finalQueue[targetIndex + 1];
    } else if (state.repeatMode == PlayerRepeatMode.all &&
        finalQueue.length > 1) {
      nextTrack = finalQueue.first;
    }

    _isChangingTrack = true;
    try {
      await _service.playTrack(
        targetTrack,
        prevTrack: prevTrack,
        nextTrack: nextTrack,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Playback error: $e',
        isPlaying: false,
      );
    } finally {
      _isChangingTrack = false;
    }
  }

  /// Plays a track directly at the specified queue index without changing queue order.
  Future<void> playTrackAtIndex(int index) async {
    if (state.queue.isEmpty || index < 0 || index >= state.queue.length) return;
    final track = state.queue[index];
    state = state.copyWith(
      currentTrack: track,
      queueIndex: index,
      position: Duration.zero,
      duration: track.duration ?? Duration.zero,
      isMiniPlayerVisible: true,
      errorMessage: null,
      isPlaying: true,
    );

    _saveLastPlayedTrack(track);
    _syncNotification(isPlayingOverride: true);

    LocalTrack? prevTrack;
    LocalTrack? nextTrack;
    if (index > 0) {
      prevTrack = state.queue[index - 1];
    } else if (state.repeatMode == PlayerRepeatMode.all &&
        state.queue.length > 1) {
      prevTrack = state.queue.last;
    }
    if (index < state.queue.length - 1) {
      nextTrack = state.queue[index + 1];
    } else if (state.repeatMode == PlayerRepeatMode.all &&
        state.queue.length > 1) {
      nextTrack = state.queue.first;
    }

    _isChangingTrack = true;
    try {
      await _service.playTrack(
        track,
        prevTrack: prevTrack,
        nextTrack: nextTrack,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Playback error: $e',
        isPlaying: false,
      );
    } finally {
      _isChangingTrack = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (state.currentTrack == null) {
      if (state.queue.isNotEmpty) {
        await playTrackAtIndex(0);
      }
      return;
    }

    try {
      if (_service.player.audioSource == null ||
          _service.player.playerState.processingState == ProcessingState.idle) {
        final resumePos = state.position;
        await playTrack(state.currentTrack!);
        if (resumePos > Duration.zero) {
          await seek(resumePos);
        }
        return;
      }

      if (_service.player.playerState.processingState ==
          ProcessingState.completed) {
        await _service.seek(Duration.zero);
        await _service.play();
        return;
      }

      if (state.isPlaying) {
        await _service.pause();
        _prefs?.setInt(
          AppConstants.keyLastPlayedPositionMs,
          state.position.inMilliseconds,
        );
      } else {
        await _service.play();
      }
    } catch (e) {
      try {
        await playTrack(state.currentTrack!);
      } catch (inner) {
        state = state.copyWith(
          errorMessage: 'Playback error: $inner',
          isPlaying: false,
        );
      }
    }
  }

  Future<void> seek(Duration position) async {
    await _service.seek(position);
  }

  Future<void> playNext() async {
    if (state.queue.isEmpty) return;

    final nextIndex = state.queueIndex + 1;
    if (nextIndex < state.queue.length) {
      await playTrackAtIndex(nextIndex);
    } else {
      // Loop back to the first song when next is pressed on the last song
      await playTrackAtIndex(0);
    }
  }

  Future<void> playPrevious() async {
    if (state.queue.isEmpty) return;

    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final prevIndex = state.queueIndex - 1;
    if (prevIndex >= 0) {
      await playTrackAtIndex(prevIndex);
    } else if (state.repeatMode == PlayerRepeatMode.all) {
      await playTrackAtIndex(state.queue.length - 1);
    } else {
      await seek(Duration.zero);
    }
  }

  /// Pauses playback and removes notification (e.g. from notification Close button).
  Future<void> stopPlayback() async {
    try {
      await _service.pause();
      await NotificationService.clearNotification();
    } catch (_) {}
    state = state.copyWith(
      isPlaying: false,
    );
  }

  /// Completely stops audio playback, removes notification, and cleanly closes the application.
  Future<void> stopAndCloseApp() async {
    try {
      await _service.stop();
      await NotificationService.clearNotification();
    } catch (_) {}
    state = state.copyWith(
      isPlaying: false,
      isMiniPlayerVisible: false,
    );
    await SystemNavigator.pop();
  }

  /// Adds a song to the end of the current queue.
  void addToQueue(LocalTrack track) {
    final keyedTrack = _withQueueKey(track);
    if (state.currentTrack == null) {
      playTrack(keyedTrack);
      return;
    }
    final newQueue = List<LocalTrack>.from(state.queue)..add(keyedTrack);
    state = state.copyWith(queue: newQueue);
  }

  /// Inserts a song as the immediate next song in queue.
  void playNextInQueue(LocalTrack track) {
    final keyedTrack = _withQueueKey(track);
    if (state.currentTrack == null) {
      playTrack(keyedTrack);
      return;
    }
    final newQueue = List<LocalTrack>.from(state.queue);
    final insertIndex = (state.queueIndex + 1).clamp(0, newQueue.length);
    newQueue.insert(insertIndex, keyedTrack);
    state = state.copyWith(queue: newQueue);
  }

  /// Drag-and-drop reorders the upcoming queue tracks.
  void reorderQueue(int oldRelativeIndex, int newRelativeIndex) {
    if (state.queue.isEmpty) return;
    final upcomingStart = state.queueIndex + 1;
    if (upcomingStart >= state.queue.length) return;

    final upcomingLength = state.queue.length - upcomingStart;
    if (oldRelativeIndex < 0 || oldRelativeIndex >= upcomingLength) return;

    var targetIndex = newRelativeIndex;
    if (oldRelativeIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0) targetIndex = 0;
    if (targetIndex >= upcomingLength) targetIndex = upcomingLength - 1;

    final newQueue = List<LocalTrack>.from(state.queue);
    final moved = newQueue.removeAt(upcomingStart + oldRelativeIndex);
    newQueue.insert(upcomingStart + targetIndex, moved);
    state = state.copyWith(queue: newQueue);
  }

  /// Removes a track from the upcoming queue.
  void removeFromQueue(int relativeIndex) {
    final absIndex = state.queueIndex + 1 + relativeIndex;
    if (absIndex < state.queue.length) {
      final newQueue = List<LocalTrack>.from(state.queue)..removeAt(absIndex);
      state = state.copyWith(queue: newQueue);
    }
  }

  /// Clears all upcoming tracks from the queue.
  void clearUpcomingQueue() {
    if (state.queueIndex < state.queue.length) {
      final newQueue = state.queue.sublist(0, state.queueIndex + 1);
      state = state.copyWith(queue: newQueue);
    }
  }

  /// Sets hardware device media volume (0.0 to 1.0).
  Future<void> setVolume(double vol) async {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _volumeService.setVolume(clamped);
  }

  void toggleShuffle() {
    final newShuffle = !state.isShuffle;
    if (newShuffle && state.queue.length > state.queueIndex + 1) {
      final before = state.queue.sublist(0, state.queueIndex + 1);
      final upcoming = List<LocalTrack>.from(
        state.queue.sublist(state.queueIndex + 1),
      )..shuffle(_random);
      state = state.copyWith(isShuffle: true, queue: [...before, ...upcoming]);
    } else {
      state = state.copyWith(isShuffle: newShuffle);
    }
  }

  void toggleRepeat() {
    final nextMode = switch (state.repeatMode) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    state = state.copyWith(repeatMode: nextMode);
  }

  void hideMiniPlayer() {
    state = state.copyWith(isMiniPlayerVisible: false);
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _volumeSub?.cancel();
    super.dispose();
  }
}
