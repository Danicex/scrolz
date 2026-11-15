import 'package:flutter/material.dart';

/// Central color palette for the app, matching the dark + lime-green design.
class AppColors {
  AppColors._();

  static const Color background    = Color(0xFF0C0C0B);
  static const Color surface       = Color(0xFF171716);
  static const Color surfaceLight  = Color(0xFF232320);
  static const Color card          = Color(0xFF1D1D1B);
  static const Color accent        = Color.fromARGB(255, 65, 0, 228); // lime green
  static const Color accentDim     = Color.fromARGB(255, 162, 231, 0); // olive (selected chips)
  static const Color textPrimary   = Color(0xFFF2F2EC);
  static const Color textSecondary = Color(0xFF9B9B92);
  static const Color divider       = Color(0xFF2B2B28);
}

/// App-wide [ThemeData]. Dark, Material 3.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.accent,
        onPrimary: Colors.black,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Roboto',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: AppColors.divider,
    );
  }
}
