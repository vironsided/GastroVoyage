import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Roughens any path by jittering its sampled points — gives ink an organic
/// hand-stamped feel rather than perfect vector lines.
Path _roughenPath(Path original, math.Random rand,
    {double jitter = 0.8, double interval = 6.0}) {
  final metrics = original.computeMetrics().toList();
  final result = Path();
  for (final m in metrics) {
    bool first = true;
    for (double d = 0; d < m.length; d += interval) {
      final tangent = m.getTangentForOffset(d);
      if (tangent == null) continue;
      final p = tangent.position;
      final j = Offset(
        (rand.nextDouble() - 0.5) * jitter * 2,
        (rand.nextDouble() - 0.5) * jitter * 2,
      );
      if (first) {
        result.moveTo(p.dx + j.dx, p.dy + j.dy);
        first = false;
      } else {
        result.lineTo(p.dx + j.dx, p.dy + j.dy);
      }
    }
  }
  return result;
}

/// A rough-edged rectangular ink stamp border with patchy ink (looks pressed).
class StampBorderPainter extends CustomPainter {
  StampBorderPainter({
    required this.color,
    this.shape = StampShape.roundedRect,
    this.seed = 0,
    this.strokeWidth = 2.0,
  });

  final Color color;
  final StampShape shape;
  final int seed;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    Path base;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    switch (shape) {
      case StampShape.roundedRect:
        base = Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)));
        break;
      case StampShape.oval:
        base = Path()..addOval(rect);
        break;
      case StampShape.circle:
        final r = math.min(rect.width, rect.height) / 2;
        base = Path()
          ..addOval(Rect.fromCircle(
              center: rect.center, radius: r));
        break;
      case StampShape.hexagon:
        base = _hex(rect);
        break;
    }

    final outer = _roughenPath(base, rand, jitter: 1.6, interval: 4);
    final stroke = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(outer, stroke);

    if (shape == StampShape.roundedRect || shape == StampShape.oval) {
      final innerRect = rect.deflate(4);
      Path inner;
      if (shape == StampShape.oval) {
        inner = Path()..addOval(innerRect);
      } else {
        inner = Path()
          ..addRRect(RRect.fromRectAndRadius(
              innerRect, const Radius.circular(7)));
      }
      final inner2 = _roughenPath(inner, math.Random(seed + 7),
          jitter: 1.0, interval: 4);
      final stroke2 = Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.55
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(inner2, stroke2);
    }

    final patchPaint = Paint()..color = color.withOpacity(0.25);
    final patchCount = 14 + rand.nextInt(10);
    for (int i = 0; i < patchCount; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = 0.6 + rand.nextDouble() * 1.6;
      canvas.drawCircle(Offset(x, y), r, patchPaint);
    }
  }

  Path _hex(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final radius = math.min(r.width, r.height) / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i / 6) * 2 * math.pi - math.pi / 2;
      final p = Offset(cx + math.cos(a) * radius, cy + math.sin(a) * radius);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant StampBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shape != shape || oldDelegate.seed != seed;
}

enum StampShape { roundedRect, oval, circle, hexagon }

/// Big diagonal "APPROVED" or similar across stamp interior.
class StampInkLines extends CustomPainter {
  StampInkLines({required this.color, this.seed = 0, this.count = 3});
  final Color color;
  final int seed;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final p = Paint()
      ..color = color.withOpacity(0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final y1 = size.height * (0.2 + i * 0.3);
      final y2 = y1 + size.height * 0.05;
      final jitter = (rand.nextDouble() - 0.5) * 4;
      canvas.drawLine(
        Offset(8, y1 + jitter),
        Offset(size.width - 8, y2 - jitter),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StampInkLines oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed || oldDelegate.count != count;
}

/// Hand-drawn-style sprig (lavender / botanical decoration).
class BotanicalSprigPainter extends CustomPainter {
  BotanicalSprigPainter({this.color = const Color(0xFF7A5A8C), this.seed = 1});
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final stemPaint = Paint()
      ..color = const Color(0xFF6B7A4D)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final stem = Path()
      ..moveTo(size.width / 2, size.height)
      ..quadraticBezierTo(
          size.width / 2 + 6, size.height * 0.6, size.width / 2, size.height * 0.2);
    canvas.drawPath(stem, stemPaint);

    final petalPaint = Paint()..color = color.withOpacity(0.85);
    for (int i = 0; i < 16; i++) {
      final t = i / 15.0;
      final y = size.height * (0.15 + t * 0.45);
      final side = i.isEven ? -1.0 : 1.0;
      final offset = 4 + rand.nextDouble() * 6;
      final cx = size.width / 2 + side * offset * (1.2 - t);
      final cy = y + (rand.nextDouble() - 0.5) * 3;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 9),
        petalPaint,
      );
    }

    final leafPaint = Paint()..color = const Color(0xFF7E8E50);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width / 2 - 6, size.height * 0.78),
          width: 14,
          height: 6),
      leafPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(size.width / 2 + 6, size.height * 0.85),
          width: 12,
          height: 5),
      leafPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BotanicalSprigPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}

/// Realistic metal paper-clip silhouette.
class PaperClipPainter extends CustomPainter {
  PaperClipPainter({this.color = const Color(0xFF7C7C7C)});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.2;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.35, h * 0.08)
      ..lineTo(w * 0.35, h * 0.78)
      ..arcToPoint(
        Offset(w * 0.65, h * 0.78),
        radius: const Radius.circular(12),
        clockwise: false,
      )
      ..lineTo(w * 0.65, h * 0.22)
      ..arcToPoint(
        Offset(w * 0.45, h * 0.22),
        radius: const Radius.circular(10),
        clockwise: false,
      )
      ..lineTo(w * 0.45, h * 0.62);

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
    canvas.save();
    canvas.translate(1.5, 2);
    canvas.drawPath(path, shadow);
    canvas.restore();

    canvas.drawPath(path, p);

    final highlight = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;
    canvas.save();
    canvas.translate(-0.6, -0.6);
    canvas.drawPath(path, highlight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PaperClipPainter oldDelegate) => oldDelegate.color != color;
}

/// Washi-tape rectangle (decorative tape strip).
class WashiTapePainter extends CustomPainter {
  WashiTapePainter({required this.color, this.pattern = WashiPattern.dots});
  final Color color;
  final WashiPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = color.withOpacity(0.85);
    canvas.drawRect(Offset.zero & size, base);

    final detail = Paint()..color = Colors.white.withOpacity(0.35);
    switch (pattern) {
      case WashiPattern.dots:
        for (double x = 6; x < size.width; x += 10) {
          for (double y = 4; y < size.height; y += 8) {
            canvas.drawCircle(Offset(x, y), 1.2, detail);
          }
        }
        break;
      case WashiPattern.stripes:
        final p = Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..strokeWidth = 1.2;
        for (double x = -size.height; x < size.width; x += 6) {
          canvas.drawLine(
              Offset(x, 0), Offset(x + size.height, size.height), p);
        }
        break;
      case WashiPattern.solid:
        break;
    }

    final edge = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), edge);
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), edge);
  }

  @override
  bool shouldRepaint(covariant WashiTapePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pattern != pattern;
}

enum WashiPattern { dots, stripes, solid }
