import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum GastroThemeMode { girls, couples, guys }

class GastroThemeConfig {
  const GastroThemeConfig({
    required this.mode,
    required this.name,
    required this.tagline,
    required this.themeIcon,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.gold,
    required this.goldSoft,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
    required this.error,
    required this.navBackground,
    required this.navActivePill,
    required this.navActiveIcon,
    required this.navInactiveIcon,
    required this.pinDotColor,
    required this.mapBackground,
    required this.mapContinentFill,
    required this.mapContinentStroke,
    required this.mapGridColor,
    required this.mapLabelColor,
    required this.isDark,
    required this.selectorCardBg,
    required this.selectorAccent,
    required this.selectorIcons,
  });

  final GastroThemeMode mode;
  final String name;
  final String tagline;
  final IconData themeIcon;

  // Core colors
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color accent;      // was "spice"
  final Color accentSoft;  // was "spiceContainer"
  final Color gold;
  final Color goldSoft;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;
  final Color error;

  // Nav bar
  final Color navBackground;
  final Color navActivePill;
  final Color navActiveIcon;
  final Color navInactiveIcon;

  // Map
  final Color pinDotColor;
  final Color mapBackground;
  final Color mapContinentFill;
  final Color mapContinentStroke;
  final Color mapGridColor;
  final Color mapLabelColor;

  final bool isDark;

  // Theme selector card visuals
  final Color selectorCardBg;
  final Color selectorAccent;
  final List<IconData> selectorIcons;

  // ── Presets ────────────────────────────────────────────────────────────────

  static const girls = GastroThemeConfig(
    mode: GastroThemeMode.girls,
    name: 'Girls',
    tagline: 'Soft · Diary · Feminine',
    themeIcon: LucideIcons.heart,
    background: Color(0xFFFFF0F5),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFFFE4EE),
    primary: Color(0xFFB5476A),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE07A9A),
    accentSoft: Color(0xFFFFD6E4),
    gold: Color(0xFFE8A0B4),
    goldSoft: Color(0xFFFFEDF3),
    onSurface: Color(0xFF2D1020),
    onSurfaceVariant: Color(0xFF7A4A5A),
    outlineVariant: Color(0xFFF0C8D8),
    error: Color(0xFFBA1A1A),
    navBackground: Color(0xFFFFFFFF),
    navActivePill: Color(0xFFB5476A),
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xFFCCA0B0),
    pinDotColor: Color(0xFFE07A9A),
    mapBackground: Color(0xFFFFF8FA),
    mapContinentFill: Color(0xFFFFE8F0),
    mapContinentStroke: Color(0xFFB5476A),
    mapGridColor: Color(0xFFF5C8D8),
    mapLabelColor: Color(0xFFB5476A),
    isDark: false,
    selectorCardBg: Color(0xFFFFE4EE),
    selectorAccent: Color(0xFFB5476A),
    selectorIcons: [LucideIcons.heart, LucideIcons.star, LucideIcons.leaf, LucideIcons.coffee, LucideIcons.award],
  );

  static const couples = GastroThemeConfig(
    mode: GastroThemeMode.couples,
    name: 'Couples',
    tagline: 'Clean · Warm · Together',
    themeIcon: LucideIcons.mail,
    background: Color(0xFFF5F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE8F0F8),
    primary: Color(0xFF2D5280),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF4A7FB5),
    accentSoft: Color(0xFFD0E4F5),
    gold: Color(0xFF6B9EC8),
    goldSoft: Color(0xFFE0EEF8),
    onSurface: Color(0xFF0D1E2E),
    onSurfaceVariant: Color(0xFF4A6070),
    outlineVariant: Color(0xFFCADCEA),
    error: Color(0xFFBA1A1A),
    navBackground: Color(0xFFFFFFFF),
    navActivePill: Color(0xFF2D5280),
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xFFA0B8CC),
    pinDotColor: Color(0xFF4A7FB5),
    mapBackground: Color(0xFFF8FBFE),
    mapContinentFill: Color(0xFFE0EEF8),
    mapContinentStroke: Color(0xFF2D5280),
    mapGridColor: Color(0xFFCCDEEE),
    mapLabelColor: Color(0xFF2D5280),
    isDark: false,
    selectorCardBg: Color(0xFFE8F0F8),
    selectorAccent: Color(0xFF2D5280),
    selectorIcons: [LucideIcons.mail, LucideIcons.globe, LucideIcons.map, LucideIcons.star, LucideIcons.flame],
  );

  static const guys = GastroThemeConfig(
    mode: GastroThemeMode.guys,
    name: 'Guys',
    tagline: 'Dark · Raw · Bold',
    themeIcon: LucideIcons.zap,
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceVariant: Color(0xFF1E1E1E),
    primary: Color(0xFF1E1E1E),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFCC0000),
    accentSoft: Color(0xFF2A0808),
    gold: Color(0xFFB0B0B0),
    goldSoft: Color(0xFF222222),
    onSurface: Color(0xFFEEEEEE),
    onSurfaceVariant: Color(0xFF909090),
    outlineVariant: Color(0xFF303030),
    error: Color(0xFFFF4444),
    navBackground: Color(0xFF111111),
    navActivePill: Color(0xFFCC0000),
    navActiveIcon: Color(0xFFFFFFFF),
    navInactiveIcon: Color(0xFF666666),
    pinDotColor: Color(0xFFCC0000),
    mapBackground: Color(0xFF141414),
    mapContinentFill: Color(0xFF1E1E1E),
    mapContinentStroke: Color(0xFF555555),
    mapGridColor: Color(0xFF252525),
    mapLabelColor: Color(0xFF888888),
    isDark: true,
    selectorCardBg: Color(0xFF1A1A1A),
    selectorAccent: Color(0xFFCC0000),
    selectorIcons: [LucideIcons.zap, LucideIcons.flag, LucideIcons.wrench, LucideIcons.flame, LucideIcons.award],
  );

  static GastroThemeConfig forMode(GastroThemeMode mode) {
    switch (mode) {
      case GastroThemeMode.girls:  return girls;
      case GastroThemeMode.couples: return couples;
      case GastroThemeMode.guys:   return guys;
    }
  }

  // ── Build Flutter ThemeData ────────────────────────────────────────────────

  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: accent,
      onSecondary: onPrimary,
      error: error,
      onError: const Color(0xFFFFFFFF),
      surface: surface,
      onSurface: onSurface,
    ),
    scaffoldBackgroundColor: background,
    cardColor: surface,
    dividerColor: outlineVariant,
    textTheme: GoogleFonts.hankenGroteskTextTheme().copyWith(
      displayLarge: GoogleFonts.playfairDisplay(
        fontSize: 48, fontWeight: FontWeight.w700, color: onSurface,
      ),
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 32, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 28, fontWeight: FontWeight.w600, color: onSurface,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 24, fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleLarge: GoogleFonts.hankenGrotesk(
        fontSize: 22, fontWeight: FontWeight.w600, color: onSurface,
      ),
      bodyLarge: GoogleFonts.hankenGrotesk(
        fontSize: 16, color: onSurface,
      ),
      bodyMedium: GoogleFonts.hankenGrotesk(
        fontSize: 14, color: onSurface,
      ),
      bodySmall: GoogleFonts.hankenGrotesk(
        fontSize: 12, color: onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 10, fontWeight: FontWeight.w500, color: onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceVariant,
      selectedColor: primary,
      labelStyle: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
