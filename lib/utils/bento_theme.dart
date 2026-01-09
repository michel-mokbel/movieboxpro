import 'package:flutter/material.dart';

class BentoTheme {
  static const Color background = Color(0xFF0B0F17);
  static const Color backgroundDeep = Color(0xFF070A12);
  static const Color surface = Color(0xFF141B2D);
  static const Color surfaceAlt = Color(0xFF101827);
  static const Color outline = Color(0x1AFFFFFF);
  static const Color accent = Color(0xFF4C8DFF);
  static const Color accentSoft = Color(0xFF6EE7F9);
  static const Color highlight = Color(0xFFF7B84B);
  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0xB3F5F7FF);
  static const Color textMuted = Color(0x80F5F7FF);

  static const double radiusLarge = 28;
  static const double radiusMedium = 20;
  static const double radiusSmall = 14;

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF11182A),
      Color(0xFF0B0F17),
      Color(0xFF070A12),
    ],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B2540),
      Color(0xFF131A2A),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4C8DFF),
      Color(0xFF22D3EE),
    ],
  );

  static const TextStyle display = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.6,
  );

  static const TextStyle title = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textMuted,
    letterSpacing: 0.2,
  );
}
