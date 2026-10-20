import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/local_track.dart';

/// Wraps a scrollable track list with:
/// 1. A-Z vertical fast-scroller on the right edge.
/// 2. Floating Jump-to-Top and Jump-to-Bottom quick navigation buttons.
/// 3. Floating letter badge showing currently selected letter during drag/tap.
class AlphabetFastScroller extends StatefulWidget {
  final ScrollController scrollController;
  final List<LocalTrack> tracks;
  final Widget child;
  final double itemHeight;
  final String Function(LocalTrack track)? letterSelector;

  const AlphabetFastScroller({
    super.key,
    required this.scrollController,
    required this.tracks,
    required this.child,
    this.itemHeight = 65.0,
    this.letterSelector,
  });

  @override
  State<AlphabetFastScroller> createState() => _AlphabetFastScrollerState();
}

class _AlphabetFastScrollerState extends State<AlphabetFastScroller> {
  static const List<String> _alphabet = [
    '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  String? _currentLetter;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onLetterSelected(String letter) {
    int targetIndex = -1;
    if (letter == '#') {
      targetIndex = widget.tracks.indexWhere((t) {
        final text = widget.letterSelector != null
            ? widget.letterSelector!(t)
            : t.title;
        if (text.isEmpty) return true;
        final first = text.trimLeft()[0].toUpperCase();
        return !RegExp(r'[A-Z]').hasMatch(first);
      });
    } else {
      targetIndex = widget.tracks.indexWhere((t) {
        final text = widget.letterSelector != null
            ? widget.letterSelector!(t)
            : t.title;
        if (text.isEmpty) return false;
        final first = text.trimLeft()[0].toUpperCase();
        return first == letter;
      });
    }

    if (targetIndex != -1 && widget.scrollController.hasClients) {
      final offset = (targetIndex * widget.itemHeight)
          .clamp(0.0, widget.scrollController.position.maxScrollExtent);
      widget.scrollController.jumpTo(offset);
    }

    setState(() {
      _currentLetter = letter;
    });

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _currentLetter = null);
      }
    });
  }

  void _handleDrag(double localY, double singleLetterHeight) {
    if (singleLetterHeight <= 0) return;
    final index = (localY / singleLetterHeight).floor().clamp(0, _alphabet.length - 1);
    _onLetterSelected(_alphabet[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Alphabet index bar on right side
        if (widget.tracks.length > 8)
          Positioned(
            right: 1,
            top: 8,
            bottom: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                final singleHeight = availableHeight / _alphabet.length;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragDown: (details) =>
                      _handleDrag(details.localPosition.dy, singleHeight),
                  onVerticalDragUpdate: (details) =>
                      _handleDrag(details.localPosition.dy, singleHeight),
                  onTapDown: (details) =>
                      _handleDrag(details.localPosition.dy, singleHeight),
                  child: Container(
                    width: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _alphabet.map((char) {
                        final isSelected = _currentLetter == char;
                        return Text(
                          char,
                          style: TextStyle(
                            color: isSelected ? AppColors.accent : Colors.white60,
                            fontSize: 9,
                            fontWeight:
                                isSelected ? FontWeight.w900 : FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),

        // Small Back to Top & Back to Bottom quick navigation buttons
        Positioned(
          right: widget.tracks.length > 8 ? 26 : 12,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Jump to Top
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.scrollController.hasClients) {
                      widget.scrollController.animateTo(
                        0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xDD181818),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Jump to Bottom
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.scrollController.hasClients) {
                      widget.scrollController.animateTo(
                        widget.scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xDD181818),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x33FFFFFF),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Large Floating Letter Bubble
        if (_currentLetter != null)
          Center(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _currentLetter != null ? 1.0 : 0.0,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _currentLetter!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
