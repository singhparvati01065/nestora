import 'package:flutter/material.dart';

/// Central place for the app's brand colours and theme.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF6C4AB6);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F6FB),
      appBarTheme: const AppBarTheme(centerTitle: true),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Height 52 without forcing infinite width — full-width buttons get
          // their width from a stretch/tight parent, while buttons placed in a
          // Row size to their content instead of overflowing.
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
