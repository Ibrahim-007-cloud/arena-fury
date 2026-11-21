import 'package:flutter/material.dart';

abstract final class AppColors {
  static const accent = Color(0xFFFF3D3D);
  static const gold = Color(0xFFFFC233);
  static const cyan = Color(0xFF3DE1FF);
  static const background = Color(0xFF0D0D1A);
  static const panel = Color(0xFF1A1A2E);
  static const p1 = Color(0xFF3D8BFF);
  static const cpu = Color(0xFFFF3D3D);
}

abstract final class AppTheme {
  static const titleStyle = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    letterSpacing: 4,
    color: Colors.white,
    shadows: [Shadow(color: AppColors.accent, blurRadius: 18)],
  );

  static const headingStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
    color: Colors.white,
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.panel,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        centerTitle: false,
        titleTextStyle: headingStyle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
