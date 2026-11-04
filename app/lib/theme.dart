import 'package:flutter/material.dart';

class VoltraColors {
  static const navy = Color(0xFF0E1A2B);
  static const green = Color(0xFF2FD27F);
  static const darkGreen = Color(0xFF0B7A45);
  static const amber = Color(0xFFB57A00);
  static const grey = Color(0xFF6B7480);
  static const background = Color(0xFFF5F6F1);
  static const card = Color(0xFFFCFCFA);
  static const border = Color(0xFFDDE1DA);
  static const ink = Color(0xFF1C2633);
  static const muted = Color(0xFF4A5563);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VoltraColors.darkGreen,
    primary: VoltraColors.darkGreen,
    surface: VoltraColors.background,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: VoltraColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: VoltraColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: VoltraColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: VoltraColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VoltraColors.darkGreen,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
