import 'package:flutter/material.dart';

/// Lace (semicircle pattern) used at the bottom of doily-style cards.
/// Replaces the duplicate `_LacePainter` that existed in dashboard,
/// baku_map_screen and account_settings_screen.
class LacePainter extends CustomPainter {
  const LacePainter({
    required this.color,
    this.dotRadius = 4.0,
    this.gap = 8.0,
    this.baseline = false,
  });

  final Color color;
  final double dotRadius;
  final double gap;

  /// When true, draws a faint horizontal line through the dot centers — used
  /// at the top of account-style cards.
  final bool baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (baseline) {
      final linePaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(0, size.height - 1),
        Offset(size.width, size.height - 1),
        linePaint,
      );
    }

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    double x = dotRadius;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, size.height - 1), dotRadius, dotPaint);
      x += gap;
    }
  }

  @override
  bool shouldRepaint(LacePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.gap != gap ||
      oldDelegate.baseline != baseline;
}

/// Vertical-bar stripe pattern used as background for "guys" style cards.
/// Replaces `_StripePainter` / `_StripedPainter` / `_StripeTopPainter`.
class StripePainter extends CustomPainter {
  const StripePainter({
    required this.color,
    this.barWidth = 3.0,
    this.gap = 6.0,
    this.opacity = 0.7,
  });

  final Color color;
  final double barWidth;
  final double gap;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withOpacity(opacity);
    double x = 0;
    while (x < size.width) {
      canvas.drawRect(Rect.fromLTWH(x, 0, barWidth, size.height), paint);
      x += gap;
    }
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.barWidth != barWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.opacity != opacity;
}
