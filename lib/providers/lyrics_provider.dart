import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/local_track.dart';
import '../data/models/lyrics_model.dart';
import '../data/services/lyrics_cache_service.dart';
import '../data/services/lyrics_service.dart';
import 'audio_player_provider.dart';

enum LyricsStatus {
  initial,
  loading,
  success,
  notFound,
  offline,
  rateLimited,
  error,
}

enum LyricsDisplayMode {
  dual,     // Original song lyrics + English translation subtitles underneath
  english,  // English translation subtitles only
  original, // Original song lyrics only (subtitles off)
}

class LyricsState {
  final LyricsStatus status;
  final LyricsData? data;
  final String? errorMessage;
  final String? trackId;
  final bool isRefreshing;
  final LyricsDisplayMode displayMode;
  final bool isTranslating;
  final String? translationError;

  const LyricsState({
    this.status = LyricsStatus.initial,
    this.data,
    this.errorMessage,
    this.trackId,
    this.isRefreshing = false,
    this.displayMode = LyricsDisplayMode.dual,
    this.isTranslating = false,
    this.translationError,
  });

  bool get isLoading => status == LyricsStatus.loading;
  bool get isSuccess => status == LyricsStatus.success && data != null;
  bool get isSynced => isSuccess && data!.isSynced;
  bool get hasPlainLyrics => isSuccess && data!.hasPlainLyrics;
  bool get isInstrumental => isSuccess && data!.instrumental;
  bool get hasLyrics => isSuccess && data!.hasAnyLyrics;
  bool get hasTranslation => isSuccess && data!.hasTranslation;
  bool get isSourceEnglish => isSuccess && data!.isSourceEnglish;
  List<LyricLine> get syncedLines => data?.syncedLines ?? const [];

  LyricsState copyWith({
    LyricsStatus? status,
    LyricsData? data,
    String? errorMessage,
    String? trackId,
    bool? isRefreshing,
    LyricsDisplayMode? displayMode,
    bool? isTranslating,
    String? translationError,
    bool clearData = false,
  }) {
    return LyricsState(
      status: status ?? this.status,
      data: clearData ? null : (data ?? this.data),
      errorMessage: errorMessage ?? this.errorMessage,
      trackId: trackId ?? this.trackId,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      displayMode: displayMode ?? this.displayMode,
      isTranslating: isTranslating ?? this.isTranslating,
      translationError: translationError ?? this.translationError,
    );
  }
}

final lyricsCacheServiceProvider = Provider<LyricsCacheService>((ref) {
  return LyricsCacheService();
});

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  final cacheService = ref.watch(lyricsCacheServiceProvider);
  return LyricsService(cacheService: cacheService);
});

final lyricsProvider = StateNotifierProvider<LyricsNotifier, LyricsState>((
  ref,
) {
  final service = ref.watch(lyricsServiceProvider);
  final notifier = LyricsNotifier(service, ref);
  return notifier;
});

class LyricsNotifier extends StateNotifier<LyricsState> {
  final LyricsService _service;
  final Ref _ref;
  String? _loadingTrackId;

  LyricsNotifier(this._service, this._ref) : super(const LyricsState()) {
    // Listen to track changes in audio player and auto-load lyrics
    _ref.listen<LocalTrack?>(
      audioPlaybackProvider.select((s) => s.currentTrack),
      (prev, next) {
        if (next?.id != prev?.id) {
          loadLyrics(next);
        }
      },
    );

    // Initial check for currently playing track
    final current = _ref.read(audioPlaybackProvider).currentTrack;
    if (current != null) {
      loadLyrics(current);
    }
  }

  /// Sets the lyrics display mode (dual, english, or original).
  void setDisplayMode(LyricsDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
  }

  /// Cycles between Dual -> English -> Original -> Dual.
  void cycleDisplayMode() {
    switch (state.displayMode) {
      case LyricsDisplayMode.dual:
        state = state.copyWith(displayMode: LyricsDisplayMode.english);
        break;
      case LyricsDisplayMode.english:
        state = state.copyWith(displayMode: LyricsDisplayMode.original);
        break;
      case LyricsDisplayMode.original:
        state = state.copyWith(displayMode: LyricsDisplayMode.dual);
        break;
    }
  }

  /// Loads lyrics for [track]. If [forceRefresh] is true, bypasses disk cache.
  Future<void> loadLyrics(
    LocalTrack? track, {
    bool forceRefresh = false,
  }) async {
    if (track == null) {
      state = const LyricsState();
      _loadingTrackId = null;
      return;
    }

    // If already loaded for this track and not forcing refresh, do nothing
    if (!forceRefresh &&
        state.trackId == track.id &&
        state.status == LyricsStatus.success &&
        state.data != null) {
      return;
    }

    _loadingTrackId = track.id;

    state = state.copyWith(
      status: LyricsStatus.loading,
      trackId: track.id,
      errorMessage: null,
      isRefreshing: forceRefresh,
      clearData: forceRefresh,
      isTranslating: false,
    );

    try {
      final result = await _service.getLyricsForTrack(
        track,
        forceRefresh: forceRefresh,
      );

      // Verify track has not changed while request was in-flight
      if (_loadingTrackId != track.id) {
        return;
      }

      switch (result.status) {
        case LyricsFetchStatus.success:
          final data = result.data!;
          state = state.copyWith(
            status: LyricsStatus.success,
            data: data,
            errorMessage: null,
            isRefreshing: false,
          );

          // Auto-translate non-English lyrics in background if translation not present
          if (!data.instrumental &&
              !data.hasTranslation &&
              !data.isSourceEnglish &&
              data.hasAnyLyrics) {
            _autoTranslate(data, track.id);
          }
          break;
        case LyricsFetchStatus.notFound:
          state = state.copyWith(
            status: LyricsStatus.notFound,
            errorMessage:
                result.errorMessage ?? 'No lyrics found for this track.',
            isRefreshing: false,
          );
          break;
        case LyricsFetchStatus.networkError:
          state = state.copyWith(
            status: LyricsStatus.offline,
            errorMessage: result.errorMessage ?? 'No internet connection.',
            isRefreshing: false,
          );
          break;
        case LyricsFetchStatus.rateLimited:
          state = state.copyWith(
            status: LyricsStatus.rateLimited,
            errorMessage: result.errorMessage ?? 'Service rate limit reached.',
            isRefreshing: false,
          );
          break;
        case LyricsFetchStatus.serverError:
        case LyricsFetchStatus.invalidResponse:
          state = state.copyWith(
            status: LyricsStatus.error,
            errorMessage: result.errorMessage ?? 'Error fetching lyrics.',
            isRefreshing: false,
          );
          break;
      }
    } catch (e) {
      if (_loadingTrackId == track.id) {
        state = state.copyWith(
          status: LyricsStatus.error,
          errorMessage: 'Failed to load lyrics: $e',
          isRefreshing: false,
        );
      }
    }
  }

  /// Background auto-translation
  Future<void> _autoTranslate(LyricsData data, String trackId) async {
    state = state.copyWith(isTranslating: true, translationError: null);
    try {
      final translated = await _service.translateLyrics(data, trackId: trackId);
      if (_loadingTrackId == trackId && mounted) {
        state = state.copyWith(
          data: translated,
          isTranslating: false,
        );
      }
    } catch (e) {
      if (_loadingTrackId == trackId && mounted) {
        state = state.copyWith(
          isTranslating: false,
          translationError: 'Translation failed: $e',
        );
      }
    }
  }

  /// Manually trigger or refresh translation to English.
  Future<void> translateCurrentLyrics() async {
    final data = state.data;
    final trackId = state.trackId;
    if (data == null || trackId == null || !data.hasAnyLyrics) return;

    state = state.copyWith(isTranslating: true, translationError: null);
    try {
      final translated = await _service.translateLyrics(data, trackId: trackId);
      if (_loadingTrackId == trackId && mounted) {
        state = state.copyWith(
          data: translated,
          isTranslating: false,
        );
      }
    } catch (e) {
      if (_loadingTrackId == trackId && mounted) {
        state = state.copyWith(
          isTranslating: false,
          translationError: 'Translation failed: $e',
        );
      }
    }
  }

  /// Manually retry or refresh lyrics for currently active track
  Future<void> retryOrRefresh({bool forceRefresh = false}) async {
    final track = _ref.read(audioPlaybackProvider).currentTrack;
    if (track != null) {
      await loadLyrics(track, forceRefresh: forceRefresh);
    }
  }
}
