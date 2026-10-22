import 'package:flutter/material.dart';

/// Earthy palette. Warm neutrals carry the layout (utilitarian);
/// tan, clay and ochre feed the aurora glow and accents.
abstract final class AppColors {
  // Neutrals
  static const sand = Color(0xFFEBDDD0); // app background
  static const paper = Color(0xFFFAF4EC); // cards and fields
  static const bark = Color(0xFF2A2822); // primary text
  static const stone = Color(0xFF5E544C); // secondary text
  static const line = Color(0xFFD0BFAE); // borders and dividers

  // Accents
  static const tan = Color(0xFF8B6B47); // primary action (darker beige)
  static const tanDeep = Color(0xFF5E4630); // pressed / emphasis
  static const camel = Color(0xFFC2A27A); // soft fills
  static const clay = Color(0xFFB4623A); // file / warm accent
  static const ochre = Color(0xFFD6A03E); // aurora highlight
  static const error = Color(0xFF9E3B2A);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.tan,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.tan,
    onPrimary: Colors.white,
    surface: AppColors.paper,
    onSurface: AppColors.bark,
    outline: AppColors.line,
    error: AppColors.error,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.sand,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.bark,
      displayColor: AppColors.bark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.tan,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.line,
        disabledForegroundColor: AppColors.stone,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.tanDeep,
        side: const BorderSide(color: AppColors.tan, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.tan,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.tan, 2),
      errorBorder: border(AppColors.error),
      labelStyle: const TextStyle(color: AppColors.stone),
    ),
  );
}
