import 'package:flutter/material.dart';

/// Design tokens and Spotify-inspired Red & Black color palette for Shadow Player.
class AppColors {
  AppColors._();

  // Pure AMOLED Black & Deep Onyx Surfaces (Zero Grey, True Pitch Black)
  static const Color background = Color(0xFF000000); // Pure OLED Black #000000
  static const Color surface = Color(0xFF050505); // Ultra-deep pitch surface
  static const Color surfaceVariant = Color(
    0xFF0D0D0D,
  ); // Subtle elevated surface
  static const Color card = Color(0xFF080808); // Crisp pitch card
  static const Color cardHighlight = Color(0xFF141414);
  static const Color bottomNavBackground = Color(
    0xFF000000,
  ); // 100% pure black navigation

  // Sleek Glass Borders & Sheen
  static const Color border = Color(0x1FFFFFFF); // 12% white sheen
  static const Color borderSubtle = Color(0x12FFFFFF); // 7% white sheen
  static const Color divider = Color(0x18FFFFFF);

  // Vibrant Spotify Crimson & Neon Red Accents
  static const Color accent = Color(0xFFE50914); // Spotify Crimson Red
  static const Color accentSecondary = Color(
    0xFFFF2E4C,
  ); // Electric Vibrant Red
  static const Color accentPurple = Color(0xFFB81D24); // Deep Cherry Red
  static const Color accentGold = Color(0xFFFF5252); // Coral / Lossless Red
  static const Color accentRed = Color(0xFFE50914);

  // Red & Pure Black Gradients
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFE50914), Color(0xFFFF2E4C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFF334B), Color(0xFFB81D24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF121212), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient placeholderArtGradient = LinearGradient(
    colors: [Color(0xFF181818), Color(0xFF050505)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient vinylGrooveGradient = LinearGradient(
    colors: [Color(0xFF1C1C1C), Color(0xFF050505), Color(0xFF1C1C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Ambient Now Playing Pure Black Gradient
  static const LinearGradient nowPlayingGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF220509), // Subtle crimson aura at top
      Color(0xFF0F0204),
      Color(0xFF000000), // Pure OLED black
      Color(0xFF000000),
    ],
    stops: [0.0, 0.28, 0.65, 1.0],
  );

  // Typography - High Contrast Pure White & Crisp Slate
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3); // Crisp Subtitle
  static const Color textMuted = Color(0xFF757575);

  // Status Colors
  static const Color success = Color(0xFFE50914);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE50914);
}
