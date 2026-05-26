import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Procedural aged-paper background. No assets required.
/// Layers: warm cream base + radial vignette + cluster fiber specks +
/// random freckles + faint horizontal grain + edge yellowing.
class PaperTexturePainter extends CustomPainter {
  PaperTexturePainter({
    this.seed = 42,
    this.baseColor = const Color(0xFFF6EDDC),
    this.darken = 1.0,
  });

  final int seed;
  final Color baseColor;
  final double darken;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rand = math.Random(seed);

    final base = Color.lerp(baseColor, const Color(0xFF8A6A47), 0.08 * darken)!;
    canvas.drawRect(rect, Paint()..color = base);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          const Color(0xFF6B4A2C).withOpacity(0.20 * darken),
          const Color(0xFF3E2A18).withOpacity(0.32 * darken),
        ],
        stops: const [0.55, 0.85, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    final hSpot = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 0.9,
        colors: [
          const Color(0xFFFFF6E0).withOpacity(0.25),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, hSpot);

    final fiber = Paint()
      ..color = const Color(0xFF8B6A3D).withOpacity(0.12)
      ..strokeWidth = 0.6;
    final fiberCount = (size.width * size.height / 240).round().clamp(80, 1200);
    for (int i = 0; i < fiberCount; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final l = 1.0 + rand.nextDouble() * 3.0;
      final a = rand.nextDouble() * math.pi * 2;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(a) * l, y + math.sin(a) * l),
        fiber,
      );
    }

    final freckle = Paint();
    final freckleCount = (size.width * size.height / 1800).round().clamp(20, 200);
    for (int i = 0; i < freckleCount; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = 0.4 + rand.nextDouble() * 1.4;
      freckle.color =
          const Color(0xFF6B4A2C).withOpacity(0.06 + rand.nextDouble() * 0.10);
      canvas.drawCircle(Offset(x, y), r, freckle);
    }

    final grain = Paint()..color = const Color(0xFF7A5A35).withOpacity(0.04);
    for (double y = 0; y < size.height; y += 2.0 + rand.nextDouble() * 1.5) {
      final off = math.sin(y * 0.06) * 1.5;
      canvas.drawLine(
        Offset(-2 + off, y),
        Offset(size.width + 2 + off, y),
        grain,
      );
    }

    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6B4A2C).withOpacity(0.18 * darken),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF6B4A2C).withOpacity(0.22 * darken),
        ],
        stops: const [0.0, 0.06, 0.94, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, edge);

    final hEdge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF6B4A2C).withOpacity(0.16 * darken),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF6B4A2C).withOpacity(0.20 * darken),
        ],
        stops: const [0.0, 0.05, 0.95, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, hEdge);

    final crease = Paint()
      ..color = const Color(0xFF6B4A2C).withOpacity(0.10)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 3; i++) {
      final y = size.height * (0.15 + rand.nextDouble() * 0.7);
      canvas.drawLine(
        Offset(0, y + rand.nextDouble() * 2),
        Offset(size.width, y + rand.nextDouble() * 2),
        crease,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PaperTexturePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.baseColor != baseColor || oldDelegate.darken != darken;
}

/// Thin ruled lines like a journal page.
class RuledLinesPainter extends CustomPainter {
  RuledLinesPainter({this.color = const Color(0xFFA98A5F), this.spacing = 32});
  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 0.6;
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant RuledLinesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}
