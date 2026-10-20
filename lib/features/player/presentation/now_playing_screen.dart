import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/audio_file_utils.dart';
import '../../../data/models/local_track.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../shared/widgets/album_art.dart';
import '../../library/presentation/widgets/track_options_bottom_sheet.dart';
import '../../lyrics/presentation/lyrics_screen.dart';
import 'widgets/queue_modal.dart';

/// Full-screen Spotify-identical Now Playing experience with rich canvas gestures
/// and fullscreen immersive artwork mode.
class NowPlayingScreen extends ConsumerStatefulWidget {
  final bool initialFullscreenCanvas;

  const NowPlayingScreen({super.key, this.initialFullscreenCanvas = false});

  /// Opens the Now Playing screen with a smooth Spotify-style slide-up transition.
  static void open(BuildContext context, {bool fullscreenCanvas = false}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NowPlayingScreen(initialFullscreenCanvas: fullscreenCanvas),
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
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _isDragging = false;
  double _dragPositionMs = 0.0;
  bool _showVolumeSlider = false;

  late bool _isFullscreenCanvas;
  bool _fitCanvas = false; // false = Cover (fill screen), true = Fit (contain)
  bool _showOverlayControls = true;

  @override
  void initState() {
    super.initState();
    _isFullscreenCanvas = widget.initialFullscreenCanvas;
  }

  void _handleHorizontalSwipe(double velocity) {
    if (velocity < -200) {
      // Swiped LEFT -> Next song
      ref.read(audioPlaybackProvider.notifier).playNext();
    } else if (velocity > 200) {
      // Swiped RIGHT -> Past / Previous song
      ref.read(audioPlaybackProvider.notifier).playPrevious();
    }
  }

  void _handleVerticalSwipe(double velocity) {
    if (velocity < -200) {
      // Swiped UP -> user specified: up = open queue
      QueueModal.show(context);
    } else if (velocity > 200) {
      // Swiped DOWN -> user specified: down = close the canvas
      if (_isFullscreenCanvas) {
        setState(() => _isFullscreenCanvas = false);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlaybackProvider);
    final notifier = ref.read(audioPlaybackProvider.notifier);
    final favorites = ref.watch(favoritesProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
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

    final isFav = favorites.contains(track.id);

    final totalDurationMs = playerState.duration.inMilliseconds.toDouble();
    final currentPosMs = _isDragging
        ? _dragPositionMs
        : playerState.position.inMilliseconds.toDouble();

    final clampedSliderValue = totalDurationMs > 0
        ? (currentPosMs / totalDurationMs).clamp(0.0, 1.0)
        : 0.0;

    final currentDisplayDuration = Duration(milliseconds: currentPosMs.toInt());
    final remainingDuration = playerState.duration > currentDisplayDuration
        ? playerState.duration - currentDisplayDuration
        : Duration.zero;

    if (_isFullscreenCanvas) {
      return _buildFullscreenCanvas(
        track,
        playerState,
        notifier,
        isFav,
        clampedSliderValue,
        currentDisplayDuration,
        remainingDuration,
        totalDurationMs,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          _handleVerticalSwipe(details.primaryVelocity ?? 0);
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.nowPlayingGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Top Bar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                        tooltip: 'Close Canvas',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'PLAYING FROM OFFLINE LIBRARY',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.power_settings_new_rounded,
                          size: 24,
                          color: Colors.white70,
                        ),
                        tooltip: 'Stop & Close App',
                        onPressed: () => notifier.stopAndCloseApp(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 24,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            TrackOptionsBottomSheet.show(context, track),
                      ),
                    ],
                  ),

                  if (!ref.watch(notificationsEnabledProvider))
                    GestureDetector(
                      onTap: () => ref
                          .read(notificationsEnabledProvider.notifier)
                          .requestPermissionOrOpenSettings(),
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_off_rounded,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Playback notification is off in device settings. Tap to enable lock screen controls.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Enable',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const Spacer(flex: 2),

                  // Square Artwork with Swipe (Up: Queue, Down: Close, Left: Prev, Right: Next)
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFullscreenCanvas = true;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        _handleHorizontalSwipe(details.primaryVelocity ?? 0);
                      },
                      onVerticalDragEnd: (details) {
                        _handleVerticalSwipe(details.primaryVelocity ?? 0);
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final artSize = (constraints.maxWidth * 0.92).clamp(
                            240.0,
                            360.0,
                          );
                          return Stack(
                            children: [
                              Container(
                                width: artSize,
                                height: artSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, 16),
                                    ),
                                    BoxShadow(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AlbumArt(
                                    artPath: track.albumArtPath,
                                    artworkBytes: track.albumArtBytes,
                                    size: artSize,
                                    format: track.format,
                                    showVinylGrooves: false,
                                  ),
                                ),
                              ),
                              // Fullscreen canvas expand button badge
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Title, Artist and Heart Icon Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 28,
                        ),
                        onPressed: () {
                          ref
                              .read(favoritesProvider.notifier)
                              .toggleFavorite(track.id);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Spotify Progress Scrubber Bar
                  _buildScrubber(
                    clampedSliderValue,
                    totalDurationMs,
                    currentDisplayDuration,
                    remainingDuration,
                    notifier,
                  ),

                  // Expandable Sound / Volume Control Bar
                  if (_showVolumeSlider) ...[
                    const SizedBox(height: 8),
                    _buildVolumeSlider(playerState, notifier),
                  ],

                  const SizedBox(height: 12),

                  // Playback Transport Controls Row
                  _buildPlaybackControls(playerState, notifier),

                  const Spacer(flex: 1),

                  // Bottom Accessories Row (Device indicator, Sound Button & Queue button)
                  _buildBottomAccessories(track),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fullscreen immersive Canvas view with aspect ratio options and tap-to-toggle overlay.
  Widget _buildFullscreenCanvas(
    LocalTrack track,
    AudioPlaybackState playerState,
    AudioPlaybackNotifier notifier,
    bool isFav,
    double clampedSliderValue,
    Duration currentDisplayDuration,
    Duration remainingDuration,
    double totalDurationMs,
  ) {
    final path = track.albumArtPath;
    final hasFile = path != null && path.isNotEmpty;
    final bytes = track.albumArtBytes;
    final hasArt = hasFile || (bytes != null && bytes.isNotEmpty);

    Widget buildCanvasImage({
      required BoxFit fit,
      int? cacheWidth,
      int? cacheHeight,
    }) {
      if (hasFile) {
        return Image.file(
          File(path),
          fit: fit,
          gaplessPlayback: true,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (_, _, _) {
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(
                bytes,
                fit: fit,
                gaplessPlayback: true,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                errorBuilder: (_, _, _) => _buildCanvasFallback(track),
              );
            }
            return _buildCanvasFallback(track);
          },
        );
      }
      return Image.memory(
        bytes!,
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (_, _, _) => _buildCanvasFallback(track),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _showOverlayControls = !_showOverlayControls;
          });
        },
        onHorizontalDragEnd: (details) {
          _handleHorizontalSwipe(details.primaryVelocity ?? 0);
        },
        onVerticalDragEnd: (details) {
          _handleVerticalSwipe(details.primaryVelocity ?? 0);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Canvas Image (Cover or Fit)
            if (hasArt) ...[
              if (_fitCanvas)
                Positioned.fill(
                  child: buildCanvasImage(
                    fit: BoxFit.cover,
                    cacheWidth: 120,
                    cacheHeight: 120,
                  ),
                ),
              if (_fitCanvas)
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.75)),
                ),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: buildCanvasImage(
                    fit: _fitCanvas ? BoxFit.contain : BoxFit.cover,
                  ),
                ),
              ),
            ] else ...[
              _buildCanvasFallback(track),
            ],

            // Top gradient scrim
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 160,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom gradient scrim
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 330,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Animated Overlay Controls
            AnimatedOpacity(
              opacity: _showOverlayControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showOverlayControls,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        // Top Bar in Fullscreen
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.fullscreen_exit_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                              tooltip: 'Exit Fullscreen',
                              onPressed: () {
                                setState(() => _isFullscreenCanvas = false);
                              },
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'CANVAS',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.album,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Canvas Display Mode: Fill Screen vs Fit Whole Image
                            IconButton(
                              icon: Icon(
                                _fitCanvas
                                    ? Icons.fullscreen_rounded
                                    : Icons.fit_screen_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: _fitCanvas
                                  ? 'Fill Screen (Cover)'
                                  : 'Fit Entire Image',
                              onPressed: () {
                                setState(() {
                                  _fitCanvas = !_fitCanvas;
                                });
                              },
                            ),
                            // Lyrics Button in Fullscreen Canvas
                            IconButton(
                              icon: const Icon(
                                Icons.lyrics_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Lyrics',
                              onPressed: () => LyricsScreen.open(context),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () =>
                                  TrackOptionsBottomSheet.show(context, track),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Title, Artist & Heart
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
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
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFav
                                    ? AppColors.accent
                                    : Colors.white70,
                                size: 28,
                              ),
                              onPressed: () => ref
                                  .read(favoritesProvider.notifier)
                                  .toggleFavorite(track.id),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Scrubber Slider
                        _buildScrubber(
                          clampedSliderValue,
                          totalDurationMs,
                          currentDisplayDuration,
                          remainingDuration,
                          notifier,
                        ),

                        const SizedBox(height: 8),

                        // Playback Transport Controls Row
                        _buildPlaybackControls(playerState, notifier),

                        const SizedBox(height: 6),

                        // Bottom accessories (Queue + Volume)
                        _buildBottomAccessories(track),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasFallback(LocalTrack track) {
    return Container(
      color: const Color(0xFF1B0B0E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 96,
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            Text(
              track.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrubber(
    double clampedSliderValue,
    double totalDurationMs,
    Duration currentDisplayDuration,
    Duration remainingDuration,
    AudioPlaybackNotifier notifier,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6,
              elevation: 2,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            trackShape: const RectangularSliderTrackShape(),
          ),
          child: Slider(
            value: clampedSliderValue,
            onChanged: (val) {
              setState(() {
                _isDragging = true;
                _dragPositionMs = val * totalDurationMs;
              });
            },
            onChangeEnd: (val) {
              final targetMs = (val * totalDurationMs).toInt();
              notifier.seek(Duration(milliseconds: targetMs));
              setState(() {
                _isDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentDisplayDuration == Duration.zero
                    ? '0:00'
                    : AudioFileUtils.formatDuration(currentDisplayDuration),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                remainingDuration == Duration.zero
                    ? '-0:00'
                    : '-${AudioFileUtils.formatDuration(remainingDuration)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeSlider(
    AudioPlaybackState playerState,
    AudioPlaybackNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            playerState.volume == 0
                ? Icons.volume_off_rounded
                : playerState.volume < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              ),
              child: Slider(
                value: playerState.volume,
                onChanged: (val) => notifier.setVolume(val),
              ),
            ),
          ),
          Text(
            '${(playerState.volume * 100).toInt()}%',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(
    AudioPlaybackState playerState,
    AudioPlaybackNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        IconButton(
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shuffle_rounded,
                color: playerState.isShuffle
                    ? AppColors.accent
                    : AppColors.textSecondary,
                size: 26,
              ),
              if (playerState.isShuffle)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          onPressed: () => notifier.toggleShuffle(),
        ),

        // Previous Track
        IconButton(
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 40,
          ),
          onPressed: () => notifier.playPrevious(),
        ),

        // Big Circular Play / Pause Button
        GestureDetector(
          onTap: () => notifier.togglePlayPause(),
          child: Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x66E50914),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                playerState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),

        // Next Track
        IconButton(
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 40,
          ),
          onPressed: () => notifier.playNext(),
        ),

        // Repeat
        IconButton(
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playerState.repeatMode == PlayerRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: playerState.repeatMode != PlayerRepeatMode.off
                    ? AppColors.accent
                    : AppColors.textSecondary,
                size: 26,
              ),
              if (playerState.repeatMode != PlayerRepeatMode.off)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          onPressed: () => notifier.toggleRepeat(),
        ),
      ],
    );
  }

  Widget _buildBottomAccessories(LocalTrack track) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.devices_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Shadow Offline Audio (${track.format})',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sound Control Button
              IconButton(
                icon: Icon(
                  _showVolumeSlider
                      ? Icons.volume_up_rounded
                      : Icons.volume_down_rounded,
                  size: 22,
                  color: _showVolumeSlider
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                tooltip: 'Sound Control',
                onPressed: () {
                  setState(() {
                    _showVolumeSlider = !_showVolumeSlider;
                  });
                },
              ),
              // Lyrics Button
              IconButton(
                icon: const Icon(
                  Icons.lyrics_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Lyrics',
                onPressed: () => LyricsScreen.open(context),
              ),
              // Queue Button
              IconButton(
                icon: const Icon(
                  Icons.queue_music_rounded,
                  size: 24,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Playback Queue (Swipe Up)',
                onPressed: () => QueueModal.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
