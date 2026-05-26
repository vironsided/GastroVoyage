import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/ui/painters/push_pin_painter.dart';

/// Themed 3D push-pin map marker. Replaces the old _SimplePin teardrop.
///
/// Color comes from the active theme by default:
///   • Girls → soft pink
///   • Couples → muted blue
///   • Guys → translucent green
///
/// The pin tip is anchored to the bottom center of the widget — pass this
/// to `Marker(alignment: Alignment.bottomCenter)` so the tip sits exactly on
/// the geographic point.
class ThemedMapPin extends StatelessWidget {
  const ThemedMapPin({
    super.key,
    required this.config,
    this.selected = false,
    this.color,
    this.width = 36,
    this.height = 52,
  });

  final GastroThemeConfig config;
  final bool selected;

  /// Override the pin head color. Defaults to a theme-tuned tint of `accent`.
  final Color? color;

  final double width;
  final double height;

  /// Default per-theme pin color, tuned to match the design references
  /// (4.png pink, 16.png green; blue derived for couples).
  Color _defaultColor() {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return const Color(0xFFF7A3C2);
      case GastroThemeMode.couples:
        return const Color(0xFF7BA8D3);
      case GastroThemeMode.guys:
        return const Color(0xFF4FCB47);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = color ?? _defaultColor();
    return AnimatedScale(
      scale: selected ? 1.30 : 1.0,
      duration: GS.fast,
      curve: GS.spring,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: PushPinPainter(color: pinColor),
        ),
      ),
    );
  }
}
