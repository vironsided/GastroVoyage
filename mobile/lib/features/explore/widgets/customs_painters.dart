import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ─── Customs-hall painters for the Explore "culinary passport" redesign ──────
///
/// Hand-torn paper rules, dotted perforations, ink rules, hatched washi tape
/// and a postage-ticket clipper. All deterministic (seeded) so they render
/// once and Flutter caches them.

/// A thin ink rule — a slightly rough horizontal hairline like a pen drawn
/// against a ruler. Used under the monospace customs eyebrow.
class InkRulePainter extends CustomPainter {
  const InkRulePainter({required this.color, this.seed = 7});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final mid = size.height / 2;
    Offset prev = Offset(0, mid + (rand.nextDouble() - 0.5) * 1.4);
    const step = 7.0;
    for (double x = step; x <= size.width; x += step) {
      final next = Offset(x, mid + (rand.nextDouble() - 0.5) * 1.6);
      canvas.drawLine(prev, next, paint);
      prev = next;
    }
    // a faint second pass for inked weight
    final faint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, mid + 1.1),
      Offset(size.width * 0.62, mid + 1.1),
      faint,
    );
  }

  @override
  bool shouldRepaint(InkRulePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

/// A hand-torn paper edge with a dotted perforation line just below it.
/// Separates the passport-header from the country grid. The torn fill is the
/// header's paper colour, sitting on the (transparent) page beneath.
class TornEdgePainter extends CustomPainter {
  const TornEdgePainter({
    required this.paperColor,
    required this.dotColor,
    this.seed = 17,
  });

  final Color paperColor;
  final Color dotColor;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final w = size.width;

    // ── Torn paper silhouette ────────────────────────────────────────────
    final torn = Path()..moveTo(0, 0);
    const step = 9.0;
    double y = size.height * 0.34;
    torn.lineTo(0, y);
    for (double x = 0; x <= w; x += step) {
      final ny = size.height * 0.30 +
          rand.nextDouble() * size.height * 0.34;
      torn.lineTo(x, ny);
      // tiny intermediate nick for a fibrous edge
      torn.lineTo(
        x + step * 0.5,
        ny + (rand.nextDouble() - 0.5) * 4,
      );
      y = ny;
    }
    torn.lineTo(w, y);
    torn.lineTo(w, 0);
    torn.close();

    // soft shadow cast by the torn lip onto the page below
    canvas.drawPath(
      torn.shift(const Offset(0, 2.5)),
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(torn, Paint()..color = paperColor);

    // a slightly darker fiber line tracing the rip
    final rip = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final ripPath = Path();
    bool first = true;
    final r2 = math.Random(seed + 1);
    for (double x = 0; x <= w; x += step) {
      final ny = size.height * 0.30 + r2.nextDouble() * size.height * 0.34;
      if (first) {
        ripPath.moveTo(x, ny);
        first = false;
      } else {
        ripPath.lineTo(x, ny);
      }
    }
    canvas.drawPath(ripPath, rip);

    // ── Dotted perforation line near the bottom ──────────────────────────
    final dotPaint = Paint()..color = dotColor.withOpacity(0.55);
    final perfY = size.height - 5;
    for (double x = 4; x < w; x += 11) {
      canvas.drawCircle(Offset(x, perfY), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(TornEdgePainter oldDelegate) =>
      oldDelegate.paperColor != paperColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.seed != seed;
}

/// Diagonal hatch fill for the translucent washi-tape strip that pins a
/// Polaroid photo. Drawn as repeating thin diagonal lines over a wash.
class HatchTapePainter extends CustomPainter {
  const HatchTapePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // translucent paper wash
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withOpacity(0.34),
    );
    // diagonal hatch
    final hatch = Paint()
      ..color = color.withOpacity(0.30)
      ..strokeWidth = 1.1;
    for (double x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        hatch,
      );
    }
    // crisp edges top & bottom
    final edge = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), edge);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      edge,
    );
  }

  @override
  bool shouldRepaint(HatchTapePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Clips a rectangle into a postage-ticket silhouette — a notched/perforated
/// left edge — for the black ISO code ticket on the country cards.
class TicketNotchClipper extends CustomClipper<Path> {
  const TicketNotchClipper({this.toothRadius = 2.4});

  final double toothRadius;

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, 0);
    final r = toothRadius;
    final teeth = (size.height / (r * 2)).floor().clamp(1, 40);
    final step = size.height / teeth;
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    // punch half-circles up the left edge
    for (int i = teeth - 1; i >= 0; i--) {
      final cy = i * step + step / 2;
      path.lineTo(0, cy + r);
      path.arcToPoint(
        Offset(0, cy - r),
        radius: Radius.circular(r),
        clockwise: false,
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TicketNotchClipper oldClipper) =>
      oldClipper.toothRadius != toothRadius;
}

/// A crooked round customs ink stamp reading e.g. "TASTED". Rough double ring,
/// inked text on a curve-ish stack, a couple of cancellation strokes. Drawn
/// at low opacity so it sits *on* the photo like a real rubber stamp.
class CustomsStampPainter extends CustomPainter {
  const CustomsStampPainter({
    required this.color,
    required this.label,
    this.subLabel,
    this.seed = 3,
  });

  final Color color;
  final String label;
  final String? subLabel;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final center = Offset(size.width / 2, size.height / 2);
    final dim = math.min(size.width, size.height);
    final r = dim / 2 - 2;

    final ring = Paint()
      ..color = color.withOpacity(0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // rough outer ring: arcs with gaps so the ink looks pressed
    for (int i = 0; i < 9; i++) {
      final start = (i / 9) * 2 * math.pi + rand.nextDouble() * 0.12;
      final sweep = (2 * math.pi / 9) * (0.62 + rand.nextDouble() * 0.3);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r + (rand.nextDouble() - .5) * 1.6),
        start,
        sweep,
        false,
        ring,
      );
    }
    // inner thin ring
    final innerRing = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, r * 0.72, innerRing);

    // ink patches
    final patch = Paint()..color = color.withOpacity(0.22);
    for (int i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
        0.6 + rand.nextDouble() * 1.5,
        patch,
      );
    }

    // centred label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: dim * 0.17,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: color.withOpacity(0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 -
          (subLabel != null ? dim * 0.07 : 0)),
    );

    if (subLabel != null) {
      final sp = TextPainter(
        text: TextSpan(
          text: subLabel,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: dim * 0.10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: color.withOpacity(0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      sp.paint(
        canvas,
        Offset(center.dx - sp.width / 2, center.dy + dim * 0.04),
      );
    }

    // two cancellation strokes
    final strike = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.30),
      Offset(size.width * 0.84, size.height * 0.36),
      strike,
    );
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.66),
      Offset(size.width * 0.84, size.height * 0.72),
      strike,
    );
  }

  @override
  bool shouldRepaint(CustomsStampPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.label != label ||
      oldDelegate.subLabel != subLabel ||
      oldDelegate.seed != seed;
}
