import 'package:flutter/material.dart';

/// Glossy 3D push pin drawn procedurally so the color can match any theme
/// without shipping per-theme asset files. The pin tip sits at the bottom
/// center of the paint canvas, so the canvas size determines pin scale.
///
/// Visual breakdown (top → bottom):
///   • dome head        — bulbous ellipse with radial highlight
///   • collar           — narrower ellipse "pinched" under the dome
///   • metal needle     — thin tapered grey spike to the tip
///   • drop shadow      — soft ground shadow at the base
class PushPinPainter extends CustomPainter {
  const PushPinPainter({
    required this.color,
    this.shadowOpacity = 0.35,
    this.highlight = true,
  });

  final Color color;
  final double shadowOpacity;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Layout proportions (relative to canvas) ──────────────────────────────
    final domeW = w * 0.78;
    final domeH = h * 0.46;
    final domeRect = Rect.fromCenter(
      center: Offset(w / 2, domeH / 2 + h * 0.04),
      width: domeW,
      height: domeH,
    );

    final collarW = w * 0.46;
    final collarH = h * 0.16;
    final collarRect = Rect.fromCenter(
      center: Offset(w / 2, domeRect.bottom + collarH * 0.30),
      width: collarW,
      height: collarH,
    );

    final needleTopY = collarRect.bottom - collarH * 0.25;
    final tipY = h;
    final tipX = w / 2;

    // ── Ground shadow ────────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(shadowOpacity * 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(tipX + w * 0.04, tipY - 2),
        width: w * 0.42,
        height: h * 0.07,
      ),
      shadowPaint,
    );

    // ── Metal needle ─────────────────────────────────────────────────────────
    final needlePath = Path()
      ..moveTo(tipX - w * 0.04, needleTopY)
      ..lineTo(tipX + w * 0.04, needleTopY)
      ..lineTo(tipX + w * 0.012, tipY)
      ..lineTo(tipX - w * 0.012, tipY)
      ..close();
    final needlePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0E0E0), Color(0xFF8A8A8A)],
      ).createShader(needlePath.getBounds());
    canvas.drawPath(needlePath, needlePaint);

    // ── Collar (pinched neck) ────────────────────────────────────────────────
    final dark = _darken(color, 0.32);
    final collarPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(color, 0.08), dark],
      ).createShader(collarRect);
    canvas.drawOval(collarRect, collarPaint);

    // ── Dome head ────────────────────────────────────────────────────────────
    final domePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.55),
        radius: 0.95,
        colors: [
          _lighten(color, 0.55),
          color,
          _darken(color, 0.20),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(domeRect);
    canvas.drawOval(domeRect, domePaint);

    // Subtle outline for definition
    canvas.drawOval(
      domeRect,
      Paint()
        ..color = dark.withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // ── Specular highlight ───────────────────────────────────────────────────
    if (highlight) {
      final hlRect = Rect.fromCenter(
        center: Offset(domeRect.center.dx - domeW * 0.22,
            domeRect.center.dy - domeH * 0.32),
        width: domeW * 0.42,
        height: domeH * 0.34,
      );
      canvas.drawOval(
        hlRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withOpacity(0.85),
              Colors.white.withOpacity(0.0),
            ],
          ).createShader(hlRect),
      );

      // Tiny pinpoint highlight
      canvas.drawCircle(
        Offset(domeRect.center.dx - domeW * 0.18,
            domeRect.center.dy - domeH * 0.30),
        domeW * 0.04,
        Paint()..color = Colors.white.withOpacity(0.95),
      );
    }
  }

  Color _lighten(Color c, double amt) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amt).clamp(0.0, 1.0)).toColor();
  }

  Color _darken(Color c, double amt) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(PushPinPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shadowOpacity != shadowOpacity ||
      oldDelegate.highlight != highlight;
}
