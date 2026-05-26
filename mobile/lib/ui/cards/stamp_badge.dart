import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/ui/painters/scrapbook_painters.dart';

/// Reusable ink stamp: rough-edged border + ink lines + a centered label.
/// Use for earned achievement badges, "VERIFIED" marks, country stamps in
/// the journal, etc.
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.label,
    required this.config,
    this.size = 84,
    this.shape = StampShape.roundedRect,
    this.icon,
    this.color,
    this.seed = 0,
    this.showInkLines = true,
    this.subLabel,
    this.rotation = 0,
  });

  final String label;
  final String? subLabel;
  final IconData? icon;
  final GastroThemeConfig config;
  final double size;
  final StampShape shape;
  final Color? color;
  final int seed;
  final bool showInkLines;

  /// Rotation in radians for a "slightly crooked" stamp look.
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final c = color ?? config.accent;

    Widget content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: StampBorderPainter(color: c, shape: shape, seed: seed),
          ),
          if (showInkLines)
            CustomPaint(
              size: Size(size * 0.74, size * 0.74),
              painter: StampInkLines(color: c, seed: seed + 3, count: 3),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: size * 0.28, color: c),
                  const SizedBox(height: 2),
                ],
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: size * 0.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: c,
                    height: 1.1,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: size * 0.09,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: c.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (rotation != 0) {
      content = Transform.rotate(angle: rotation, child: content);
    }
    return content;
  }
}
