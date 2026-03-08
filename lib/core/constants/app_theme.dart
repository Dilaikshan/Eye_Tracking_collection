import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get highContrast {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        background: AppColors.background,
        surface: AppColors.surface,
        primary: AppColors.accent,
        secondary: AppColors.targetYellow,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: AppColors.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
