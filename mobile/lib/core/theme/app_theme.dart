import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFFF7F9F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEEF2E8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F5EC);
  static const surfaceContainer = Color(0xFFEAEEE3);

  static const primary = Color(0xFF1B3D2B);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFBBE5CA);

  static const secondary = Color(0xFF4A6358);
  static const onSecondary = Color(0xFFFFFFFF);

  static const spice = Color(0xFFE0722A);
  static const onSpice = Color(0xFFFFFFFF);
  static const spiceContainer = Color(0xFFFFDCC8);

  static const gold = Color(0xFFD4A843);
  static const goldContainer = Color(0xFFFFF3CD);

  static const onSurface = Color(0xFF141E14);
  static const onSurfaceVariant = Color(0xFF4A6358);
  static const outline = Color(0xFF8FAF9A);
  static const outlineVariant = Color(0xFFCFDFD4);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        error: AppColors.error,
        onError: AppColors.onError,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.hankenGroteskTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 57, fontWeight: FontWeight.w700, color: AppColors.onSurface,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        titleLarge: GoogleFonts.hankenGrotesk(
          fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        titleMedium: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        titleSmall: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        bodyLarge: GoogleFonts.hankenGrotesk(
          fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onSurface,
        ),
        bodyMedium: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurface,
        ),
        bodySmall: GoogleFonts.hankenGrotesk(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.hankenGrotesk(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface,
        ),
        labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
