import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IOSTheme {
  // System Colors
  static const Color systemBackground = Color(0xFF000000);
  static const Color systemGroupedBackground = Color(0xFF1C1C1E); // iOS Dark Mode Grouped Background
  static const Color secondarySystemBackground = Color(0xFF1C1C1E);
  static const Color tertiarySystemBackground = Color(0xFF2C2C2E);
  
  // Text Colors
  static const Color label = Color(0xFFFFFFFF);
  static const Color secondaryLabel = Color(0x99EBEBF5); // ~60% white
  static const Color tertiaryLabel = Color(0x4DEBEBF5); // ~30% white
  static const Color quaternaryLabel = Color(0x2BEBEBF5); // ~18% white

  // Action Colors
  static const Color systemRed = Color(0xFFFF453A); // iOS Dark Mode System Red
  static const Color systemBlue = Color(0xFF0A84FF); // iOS Dark Mode System Blue

  // Blur Effects
  static final BackdropFilter blurEffect = BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
    child: Container(
      color: const Color(0xCC1C1C1E), // Translucent dark background
    ),
  );
  
  // Typography - SF Pro Display style
  static const TextStyle largeTitle = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 34,
    fontWeight: FontWeight.bold,
    color: label,
    letterSpacing: 0.37,
  );

  static const TextStyle title1 = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: label,
    letterSpacing: 0.36,
  );

  static const TextStyle title2 = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: label,
    letterSpacing: 0.35,
  );
  
  static const TextStyle title3 = TextStyle(
    fontFamily: '.SF Pro Display',
    fontSize: 20,
    fontWeight: FontWeight.w600, // Semi-bold
    color: label,
    letterSpacing: 0.38,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: label,
    letterSpacing: -0.41,
  );

  static const TextStyle body = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 17,
    fontWeight: FontWeight.normal,
    color: label,
    letterSpacing: -0.41,
  );

  static const TextStyle callout = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: label,
    letterSpacing: -0.32,
  );

  static const TextStyle subhead = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: secondaryLabel,
    letterSpacing: -0.24,
  );

  static const TextStyle footnote = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: secondaryLabel,
    letterSpacing: -0.08,
  );

  static const TextStyle caption1 = TextStyle(
    fontFamily: '.SF Pro Text',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: secondaryLabel,
    letterSpacing: 0,
  );

  // Card Styles
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: secondarySystemBackground,
    borderRadius: BorderRadius.circular(12),
    // Subtle border for dark mode contrast
    border: Border.all(color: tertiarySystemBackground, width: 0.5),
  );

  // Theme Data
  static ThemeData get themeData => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: systemBackground,
    primaryColor: systemBlue,
    colorScheme: const ColorScheme.dark(
      primary: systemBlue,
      secondary: systemBlue,
      surface: secondarySystemBackground,
      background: systemBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: title3,
    ),
    // Use Cupertino page transitions globally
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(), // iOS feel on Android too
      },
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: systemBlue,
      scaffoldBackgroundColor: systemBackground,
      barBackgroundColor: Color(0xCC1C1C1E),
      textTheme: CupertinoTextThemeData(
        primaryColor: systemBlue,
        textStyle: body,
      ),
    ),
  );
}
