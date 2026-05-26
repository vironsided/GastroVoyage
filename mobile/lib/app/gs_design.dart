import 'package:flutter/material.dart';

// ─── GastroVoyage Unified Design System ──────────────────────────────────────
// Single source of truth. Import this everywhere.

abstract final class GS {
  // ── Spacing ──────────────────────────────────────────────────────────────
  static const double s2  = 2;
  static const double s4  = 4;
  static const double s6  = 6;
  static const double s8  = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s56 = 56;
  static const double s64 = 64;

  // ── Border Radii ─────────────────────────────────────────────────────────
  static const double r4   = 4;
  static const double r8   = 8;
  static const double r12  = 12;
  static const double r16  = 16;
  static const double r20  = 20;
  static const double r24  = 24;
  static const double r32  = 32;
  static const double rPill = 100;

  // ── Animation Durations ───────────────────────────────────────────────────
  static const Duration micro  = Duration(milliseconds: 150);
  static const Duration fast   = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow   = Duration(milliseconds: 500);
  static const Duration xslow  = Duration(milliseconds: 700);

  // ── Stagger helper ────────────────────────────────────────────────────────
  // i=0 → 120ms, i=1 → 190ms, i=2 → 260ms …
  static Duration stagger(int i, {int ms = 70}) =>
      Duration(milliseconds: 120 + i * ms);

  // ── Curves ────────────────────────────────────────────────────────────────
  static const Curve spring = Curves.easeOutBack;
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve snappy = Curves.easeInOutQuart;

  // ── Nav bar content height (pill part only) ───────────────────────────────
  static const double navBarH = 64.0;

  // ── Bottom buffer for scrollable content ──────────────────────────────────
  // Covers floating nav pill + safe area on any device
  static const double navBuffer = 104.0;

  // ── Premium dual-layer shadow ─────────────────────────────────────────────
  static List<BoxShadow> shadow({
    required Color color,
    double blur   = 24,
    double yOffset = 8,
    double opacity = 0.08,
  }) =>
      [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: blur,
          offset: Offset(0, yOffset),
        ),
        BoxShadow(
          color: color.withOpacity(opacity * 0.45),
          blurRadius: blur * 2.2,
          offset: Offset(0, yOffset * 2),
        ),
      ];

  // ── Glass decoration (use with BackdropFilter) ────────────────────────────
  static BoxDecoration glassDeco({
    required Color tint,
    double opacity = 0.80,
    double radius  = r24,
    Color?  borderColor,
    double  borderWidth = 0.5,
  }) =>
      BoxDecoration(
        color: tint.withOpacity(opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.12),
          width: borderWidth,
        ),
      );
}
