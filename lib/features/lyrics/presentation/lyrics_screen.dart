import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/audio_file_utils.dart';
import '../../../data/models/local_track.dart';
import '../../../data/models/lyrics_model.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/lyrics_provider.dart';
import '../../../shared/widgets/album_art.dart';

/// Premium AMOLED dark full-screen lyrics view featuring:
/// - Real-time auto-scrolling synchronization with audio engine
/// - Active line highlighting with [AppColors.accent]
/// - Tap-to-seek on any timestamped line
/// - Plain lyrics fallback with explicit synchronization indicator
/// - Loading, not-found, rate-limited, error, and offline states with manual retry
/// - Floating "Sync to active line" chip when user manually scrolls
/// - Bottom transport bar to control playback while reading lyrics
class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  /// Opens the Lyrics screen with a smooth Spotify-style slide-up transition.
  static void open(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LyricsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lineKeys = [];

  String? _currentTrackId;
  int _lastActiveIndex = -1;
  bool _userIsScrolling = false;
  Timer? _userScrollDebounce;

  @override
  void dispose() {
    _userScrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onUserScrolled() {
    if (!_userIsScrolling) {
      setState(() => _userIsScrolling = true);
    }
    _userScrollDebounce?.cancel();
    _userScrollDebounce = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _userIsScrolling = false);
      }
    });
  }

  void _scrollToActiveLine(int index) {
    if (index < 0 || index >= _lineKeys.length) return;
    final key = _lineKeys[index];
    final ctx = key.currentContext;
    if (ctx != null && ctx.mounted) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _syncKeysWithLines(int count) {
    if (_lineKeys.length != count) {
      _lineKeys.clear();
      for (var i = 0; i < count; i++) {
        _lineKeys.add(GlobalKey());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlaybackProvider);
    final track = playerState.currentTrack;
    final lyricsState = ref.watch(lyricsProvider);
    final playerNotifier = ref.read(audioPlaybackProvider.notifier);

    // Track changed -> reset active index and keys
    if (track?.id != _currentTrackId) {
      _currentTrackId = track?.id;
      _lastActiveIndex = -1;
      _userIsScrolling = false;
      _userScrollDebounce?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No track playing',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nowPlayingGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header Bar
              _buildTopBar(context, track, lyricsState),

              // Interactive Dual / English / Original Subtitle Toggle Bar
              if (lyricsState.isSuccess &&
                  lyricsState.hasLyrics &&
                  !lyricsState.isInstrumental)
                _buildSubtitleToggleBar(context, lyricsState),

              // Main Body: Synced Lyrics, Plain Lyrics, Loading, or Error
              Expanded(
                child: Stack(
                  children: [
                    _buildContent(
                      context,
                      lyricsState,
                      playerState,
                      track,
                      playerNotifier,
                    ),

                    // Floating "Sync to active lyric" button when user scrolls away
                    if (_userIsScrolling &&
                        lyricsState.isSynced &&
                        _lastActiveIndex >= 0 &&
                        _lastActiveIndex < lyricsState.syncedLines.length)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _userIsScrolling = false);
                              _scrollToActiveLine(_lastActiveIndex);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sync to playback',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Mini Transport Bar
              _buildBottomControls(track, playerState, playerNotifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    LocalTrack track,
    LyricsState lyricsState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: Colors.white,
            ),
            tooltip: 'Close Lyrics',
            onPressed: () => Navigator.of(context).pop(),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 36,
              height: 36,
              child: AlbumArt(
                artPath: track.albumArtPath,
                artworkBytes: track.albumArtBytes,
                size: 36,
                format: track.format,
                showVinylGrooves: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          // Refresh lyrics action
          IconButton(
            icon: lyricsState.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
            tooltip: 'Refresh Lyrics from LRCLIB',
            onPressed: lyricsState.isLoading || lyricsState.isRefreshing
                ? null
                : () {
                    ref
                        .read(lyricsProvider.notifier)
                        .retryOrRefresh(forceRefresh: true);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LyricsState lyricsState,
    AudioPlaybackState playerState,
    LocalTrack track,
    AudioPlaybackNotifier playerNotifier,
  ) {
    if (lyricsState.isLoading && !lyricsState.isRefreshing) {
      return _buildLoadingState(track);
    }

    if (lyricsState.isInstrumental) {
      return _buildInstrumentalState(track);
    }

    if (lyricsState.status == LyricsStatus.notFound) {
      return _buildNotFoundState(track);
    }

    if (lyricsState.status == LyricsStatus.offline) {
      return _buildOfflineState(lyricsState.errorMessage);
    }

    if (lyricsState.status == LyricsStatus.rateLimited) {
      return _buildRateLimitedState();
    }

    if (lyricsState.status == LyricsStatus.error) {
      return _buildErrorState(lyricsState.errorMessage);
    }

    if (lyricsState.isSynced) {
      return _buildSyncedLyricsList(
        lyricsState.syncedLines,
        playerState.position,
        playerNotifier,
        lyricsState,
      );
    }

    if (lyricsState.hasPlainLyrics) {
      return _buildPlainLyricsView(
        lyricsState.data!.plainLyrics!,
        lyricsState.data?.plainLyricsTranslation,
        lyricsState.displayMode,
      );
    }

    return _buildNotFoundState(track);
  }

  Widget _buildSubtitleToggleBar(
    BuildContext context,
    LyricsState lyricsState,
  ) {
    final currentMode = lyricsState.displayMode;
    final notifier = ref.read(lyricsProvider.notifier);
    final isTranslating = lyricsState.isTranslating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          // Mode Selector: Dual | English | Original
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeOption(
                  label: 'Dual',
                  icon: Icons.subtitles_rounded,
                  isSelected: currentMode == LyricsDisplayMode.dual,
                  onTap: () => notifier.setDisplayMode(LyricsDisplayMode.dual),
                ),
                _buildModeOption(
                  label: 'English',
                  icon: Icons.translate_rounded,
                  isSelected: currentMode == LyricsDisplayMode.english,
                  onTap: () => notifier.setDisplayMode(LyricsDisplayMode.english),
                ),
                _buildModeOption(
                  label: 'Original',
                  icon: Icons.music_note_rounded,
                  isSelected: currentMode == LyricsDisplayMode.original,
                  onTap: () => notifier.setDisplayMode(LyricsDisplayMode.original),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Translation Status / Manual Trigger
          if (isTranslating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Translating...',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else if (lyricsState.isSourceEnglish)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'English Track',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (!lyricsState.hasTranslation)
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
              ),
              icon: const Icon(Icons.translate_rounded, size: 14),
              label: const Text(
                'Translate to EN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              onPressed: () => notifier.translateCurrentLyrics(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lyricsState.data?.sourceLanguage != null
                        ? '${lyricsState.data!.sourceLanguage!.toUpperCase()} → EN'
                        : 'Subtitles Ready',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncedLyricsList(
    List<LyricLine> lines,
    Duration currentPosition,
    AudioPlaybackNotifier playerNotifier,
    LyricsState lyricsState,
  ) {
    _syncKeysWithLines(lines.length);

    // Calculate active line from actual audio engine position
    final activeIndex = LrcParser.findActiveIndex(lines, currentPosition);

    // Trigger auto-scroll on line transition if user is not actively dragging
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      if (!_userIsScrolling && activeIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_userIsScrolling) {
            _scrollToActiveLine(activeIndex);
          }
        });
      }
    }

    final mode = lyricsState.displayMode;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _onUserScrolled();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isActive = index == activeIndex;
          final isPast = index < activeIndex;

          final Color textColor = isActive
              ? AppColors.textPrimary
              : isPast
              ? Colors.white.withValues(alpha: 0.38)
              : Colors.white.withValues(alpha: 0.22);

          final double fontSize = isActive ? 23 : 18;
          final FontWeight fontWeight = isActive
              ? FontWeight.w800
              : FontWeight.w600;

          final hasTranslation = line.translation != null &&
              line.translation!.trim().isNotEmpty &&
              line.translation!.trim() != line.text.trim();

          String primaryText = line.text;
          String? subtitleText;

          if (mode == LyricsDisplayMode.english && hasTranslation) {
            primaryText = line.translation!;
          } else if (mode == LyricsDisplayMode.dual && hasTranslation) {
            primaryText = line.text;
            subtitleText = line.translation;
          } else {
            primaryText = line.text;
          }

          return GestureDetector(
            key: _lineKeys[index],
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Tap to seek audio engine directly to lyric timestamp
              playerNotifier.seek(line.timestamp);
              setState(() => _userIsScrolling = false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isActive)
                    Container(
                      width: 4,
                      height: subtitleText != null ? 40 : 26,
                      margin: const EdgeInsets.only(right: 12, top: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66E50914),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryText.isEmpty ? '♪ ♪ ♪' : primaryText,
                          style: TextStyle(
                            color: textColor,
                            fontSize: fontSize,
                            fontWeight: fontWeight,
                            height: 1.35,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitleText != null && subtitleText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.accent.withValues(alpha: 0.95)
                                  : isPast
                                  ? Colors.white.withValues(alpha: 0.34)
                                  : Colors.white.withValues(alpha: 0.2),
                              fontSize: isActive ? 15 : 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              height: 1.25,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlainLyricsView(
    String plainLyrics,
    String? plainTranslation,
    LyricsDisplayMode mode,
  ) {
    String textToShow = plainLyrics;
    if (mode == LyricsDisplayMode.english &&
        plainTranslation != null &&
        plainTranslation.isNotEmpty) {
      textToShow = plainTranslation;
    }

    return Column(
      children: [
        // Subtle indicator that sync is not available for this song
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subtitles_off_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'Plain lyrics • Timestamp sync unavailable',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: mode == LyricsDisplayMode.dual &&
                    plainTranslation != null &&
                    plainTranslation.isNotEmpty
                ? _buildDualPlainLyrics(plainLyrics, plainTranslation)
                : SelectableText(
                    textToShow,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      height: 1.7,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDualPlainLyrics(String original, String translation) {
    final origLines = original.split('\n');
    final transLines = translation.split('\n');
    final count = origLines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(count, (i) {
        final orig = origLines[i];
        final trans = (i < transLines.length) ? transLines[i] : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                orig,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (trans != null && trans.isNotEmpty && trans != orig) ...[
                const SizedBox(height: 2),
                Text(
                  trans,
                  style: TextStyle(
                    color: AppColors.accent.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState(LocalTrack track) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Searching lyrics on LRCLIB...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${track.title} • ${track.artist}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstrumentalState(LocalTrack track) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_note_rounded,
                size: 48,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Instrumental Track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This track is confirmed instrumental with no vocal lyrics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundState(LocalTrack track) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lyrics_outlined,
                size: 44,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Lyrics Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Couldn\'t find lyrics for "${track.title}".',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              icon: Icons.refresh_rounded,
              label: 'Search Again',
              onPressed: () {
                ref
                    .read(lyricsProvider.notifier)
                    .retryOrRefresh(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 44,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect to Wi-Fi or mobile data to search online lyrics. Lyrics cached offline remain available anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              icon: Icons.refresh_rounded,
              label: 'Retry Connection',
              onPressed: () {
                ref
                    .read(lyricsProvider.notifier)
                    .retryOrRefresh(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateLimitedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 44,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Provider Busy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Too many requests to LRCLIB. Please wait a brief moment before retrying.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              icon: Icons.refresh_rounded,
              label: 'Retry Now',
              onPressed: () {
                ref
                    .read(lyricsProvider.notifier)
                    .retryOrRefresh(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Something Went Wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'An error occurred while fetching lyrics.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              icon: Icons.refresh_rounded,
              label: 'Try Again',
              onPressed: () {
                ref
                    .read(lyricsProvider.notifier)
                    .retryOrRefresh(forceRefresh: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceVariant,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onPressed: onPressed,
    );
  }

  Widget _buildBottomControls(
    LocalTrack track,
    AudioPlaybackState playerState,
    AudioPlaybackNotifier playerNotifier,
  ) {
    final posMs = playerState.position.inMilliseconds.toDouble();
    final durMs = playerState.duration.inMilliseconds.toDouble();
    final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin scrub progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: progress,
              onChanged: (val) {
                final targetMs = (val * durMs).round();
                playerNotifier.seek(Duration(milliseconds: targetMs));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AudioFileUtils.formatDuration(playerState.position),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  AudioFileUtils.formatDuration(playerState.duration),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Transport controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => playerNotifier.playPrevious(),
              ),
              GestureDetector(
                onTap: () => playerNotifier.togglePlayPause(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      playerState.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => playerNotifier.playNext(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
