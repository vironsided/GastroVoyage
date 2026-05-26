import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws the classic perforated zigzag edge of a postage stamp by punching
/// half-circles around a rectangular shape. Use as a `clipper` or as a
/// decorative outline that follows the same shape as the inner content.
class PostagePerforationPainter extends CustomPainter {
  const PostagePerforationPainter({
    required this.fill,
    this.toothRadius = 5.0,
    this.toothSpacing = 12.0,
    this.shadow = true,
  });

  final Color fill;
  final double toothRadius;
  final double toothSpacing;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    if (shadow) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawPath(path, Paint()..color = fill);
  }

  Path _buildPath(Size size) {
    final r = toothRadius;
    final step = toothSpacing;
    final path = Path();

    final horizCount = (size.width / step).floor();
    final vertCount = (size.height / step).floor();
    final hStep = size.width / horizCount;
    final vStep = size.height / vertCount;

    // Start at top-left, just past the first tooth.
    path.moveTo(r, r);

    // Top edge — punch half-circles cutting INTO the rectangle.
    for (int i = 0; i < horizCount; i++) {
      final x = i * hStep;
      path.lineTo(x + hStep / 2 - r * 0.6, r);
      path.arcToPoint(
        Offset(x + hStep / 2 + r * 0.6, r),
        radius: Radius.circular(r),
        clockwise: true,
      );
    }
    path.lineTo(size.width - r, r);

    // Right edge.
    for (int i = 0; i < vertCount; i++) {
      final y = i * vStep;
      path.lineTo(size.width - r, y + vStep / 2 - r * 0.6);
      path.arcToPoint(
        Offset(size.width - r, y + vStep / 2 + r * 0.6),
        radius: Radius.circular(r),
        clockwise: true,
      );
    }
    path.lineTo(size.width - r, size.height - r);

    // Bottom edge.
    for (int i = horizCount - 1; i >= 0; i--) {
      final x = i * hStep;
      path.lineTo(x + hStep / 2 + r * 0.6, size.height - r);
      path.arcToPoint(
        Offset(x + hStep / 2 - r * 0.6, size.height - r),
        radius: Radius.circular(r),
        clockwise: true,
      );
    }
    path.lineTo(r, size.height - r);

    // Left edge.
    for (int i = vertCount - 1; i >= 0; i--) {
      final y = i * vStep;
      path.lineTo(r, y + vStep / 2 + r * 0.6);
      path.arcToPoint(
        Offset(r, y + vStep / 2 - r * 0.6),
        radius: Radius.circular(r),
        clockwise: true,
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(PostagePerforationPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.toothRadius != toothRadius ||
      oldDelegate.toothSpacing != toothSpacing ||
      oldDelegate.shadow != shadow;
}

/// Faux postmark — partial circle of rough text with a few crossing lines.
class PostmarkPainter extends CustomPainter {
  const PostmarkPainter({required this.color, this.seed = 0});
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 2;

    final paint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Outer ring (rough).
    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, r * 0.78, paint..strokeWidth = 0.8);

    // A few short crossing strokes (the "cancellation" lines).
    final strokePaint = Paint()
      ..color = color.withOpacity(0.45)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final y = size.height * (0.35 + i * 0.08);
      final jitter = (rng.nextDouble() - 0.5) * 4;
      canvas.drawLine(
        Offset(2, y + jitter),
        Offset(size.width - 2, y - jitter * 0.5),
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(PostmarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}
