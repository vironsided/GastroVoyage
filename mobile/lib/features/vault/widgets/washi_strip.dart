import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/ui/ui.dart';

/// A short decorative washi-tape strip with a slight tilt and soft drop
/// shadow — the craft flourish that "tapes" scrapbook elements to the page.
///
/// Theme-tuned: girls get a dotted pink tape, couples a striped blue tape,
/// guys a solid muted strip. Kept local to the Vault feature so the shared
/// UI kit stays untouched.
class WashiStrip extends StatelessWidget {
  const WashiStrip({
    super.key,
    required this.config,
    this.width = 64,
    this.height = 22,
    this.rotation = -0.18,
    this.color,
  });

  final GastroThemeConfig config;
  final double width;
  final double height;
  final double rotation;
  final Color? color;

  WashiPattern get _pattern {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return WashiPattern.dots;
      case GastroThemeMode.couples:
        return WashiPattern.stripes;
      case GastroThemeMode.guys:
        return WashiPattern.solid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tape = color ?? config.accent.withOpacity(0.62);
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(config.isDark ? 0.32 : 0.12),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CustomPaint(
          painter: WashiTapePainter(color: tape, pattern: _pattern),
        ),
      ),
    );
  }
}
