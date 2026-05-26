import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/ui/ui.dart';

/// ─── Dashboard-only scrapbook flourishes ────────────────────────────────────
///
/// Small private-to-dashboard widgets that compose UI-kit painters into the
/// "Pinterest scrapbook" look. They are intentionally NOT promoted into
/// `lib/ui/` because they encode dashboard-specific framing decisions.

/// A short strip of decorative washi tape — semi-transparent, slightly tilted.
/// Uses the UI-kit [WashiTapePainter]. Great for "pinning" a card to the page.
class WashiTape extends StatelessWidget {
  const WashiTape({
    super.key,
    required this.config,
    this.width = 64,
    this.height = 22,
    this.rotation = 0,
    this.pattern = WashiPattern.stripes,
    this.color,
  });

  final GastroThemeConfig config;
  final double width;
  final double height;
  final double rotation;
  final WashiPattern pattern;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: WashiTapePainter(
            color: color ?? config.accent.withOpacity(0.55),
            pattern: pattern,
          ),
        ),
      ),
    );
  }
}

/// A tiny editorial caption rendered in a handwritten font, like a margin
/// note jotted next to a scrapbook clipping.
class MarginNote extends StatelessWidget {
  const MarginNote({
    super.key,
    required this.text,
    required this.config,
    this.rotation = -0.05,
    this.fontSize = 17,
  });

  final String text;
  final GastroThemeConfig config;
  final double rotation;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Text(
        text,
        style: GoogleFonts.caveat(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: config.onSurfaceVariant,
          height: 1.0,
        ),
      ),
    );
  }
}

/// A dotted "stitched" divider line — like thread sewn through paper.
class StitchedDivider extends StatelessWidget {
  const StitchedDivider({
    super.key,
    required this.config,
    this.dashWidth = 5,
    this.gap = 4,
    this.thickness = 1.4,
  });

  final GastroThemeConfig config;
  final double dashWidth;
  final double gap;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      child: CustomPaint(
        size: const Size(double.infinity, 0),
        painter: _DashedLinePainter(
          color: config.outlineVariant,
          dashWidth: dashWidth,
          gap: gap,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gap,
    required this.thickness,
  });

  final Color color;
  final double dashWidth;
  final double gap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color ||
      old.dashWidth != dashWidth ||
      old.gap != gap ||
      old.thickness != thickness;
}

/// Five small star glyphs — a hand-inked rating row for scrapbook cards.
class InkStars extends StatelessWidget {
  const InkStars({
    super.key,
    required this.rating,
    this.size = 12,
    this.filledColor = const Color(0xFFFFD166),
    this.emptyColor = Colors.white38,
  });

  final int rating;
  final double size;
  final Color filledColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < rating ? filledColor : emptyColor,
        ),
      ),
    );
  }
}

/// Deterministic small tilt for a given index — keeps the scrapbook feeling
/// "hand-placed" without being random across rebuilds.
double scrapbookTilt(int index, {double magnitude = 0.05}) {
  final r = math.Random(index * 7919 + 13);
  return (r.nextDouble() - 0.5) * 2 * magnitude;
}
