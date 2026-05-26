import 'package:flutter/material.dart';

/// Procedural paper envelope with a triangular flap and a letter peeking out
/// of the top-left corner. Couples-theme accent. Reference photo 11.
class EnvelopePainter extends CustomPainter {
  const EnvelopePainter({
    required this.envelopeColor,
    required this.letterColor,
    this.flapColor,
    this.accentColor,
  });

  final Color envelopeColor;
  final Color letterColor;

  /// Slightly darker than envelopeColor for the inside of the flap.
  final Color? flapColor;

  /// Tiny detail color used for a faint pattern on the letter.
  final Color? accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final flap = flapColor ?? _darken(envelopeColor, 0.08);

    // ── Envelope back (below everything) ─────────────────────────────────────
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.02, h * 0.18, w * 0.96, h * 0.78),
      const Radius.circular(6),
    );
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(back.shift(const Offset(0, 4)), shadowPaint);
    canvas.drawRRect(back, Paint()..color = envelopeColor);

    // ── Letter (peeks out of top-left) ───────────────────────────────────────
    final letterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.06, w * 0.70, h * 0.78),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.translate(-w * 0.06, -h * 0.04);
    canvas.rotate(-0.08);
    canvas.drawRRect(letterRect, Paint()..color = letterColor);
    // Faint decorative pattern at top of letter (optional)
    if (accentColor != null) {
      final detail = Paint()
        ..color = accentColor!.withOpacity(0.35)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < 3; i++) {
        final y = h * 0.20 + i * 6;
        canvas.drawLine(
          Offset(w * 0.18, y),
          Offset(w * 0.42, y),
          detail,
        );
      }
    }
    canvas.restore();

    // ── Front V-flap of envelope ─────────────────────────────────────────────
    final flapPath = Path()
      ..moveTo(w * 0.02, h * 0.18)
      ..lineTo(w * 0.50, h * 0.62)
      ..lineTo(w * 0.98, h * 0.18)
      ..close();
    canvas.drawPath(
      flapPath,
      Paint()..color = flap,
    );

    // Inner crease shadow on the flap
    canvas.drawPath(
      flapPath,
      Paint()
        ..color = Colors.black.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Front body of envelope (covers bottom half of letter) ────────────────
    final front = Path()
      ..moveTo(w * 0.02, h * 0.18)
      ..lineTo(w * 0.50, h * 0.62)
      ..lineTo(w * 0.98, h * 0.18)
      ..lineTo(w * 0.98, h * 0.96)
      ..lineTo(w * 0.02, h * 0.96)
      ..close();
    // The body is the same color as the envelope back — but we redraw to make
    // the V seam crisp.
    canvas.drawPath(front, Paint()..color = envelopeColor);

    // Subtle horizontal highlight at top of body
    canvas.drawRect(
      Rect.fromLTWH(w * 0.02, h * 0.62, w * 0.96, 1.5),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
  }

  Color _darken(Color c, double amt) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(EnvelopePainter oldDelegate) =>
      oldDelegate.envelopeColor != envelopeColor ||
      oldDelegate.letterColor != letterColor ||
      oldDelegate.flapColor != flapColor ||
      oldDelegate.accentColor != accentColor;
}
