import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Procedural paper background — fine grain + a few faint scratches.
/// Cheap to paint (≈few thousand points), with `shouldRepaint == false` it
/// renders once per size and Flutter caches the result.
///
/// Designed for full-screen backgrounds; place inside a [CustomPaint] that
/// fills the available space.
class PaperTexturePainter extends CustomPainter {
  const PaperTexturePainter({
    required this.baseColor,
    this.grainColor,
    this.grainOpacity = 0.06,
    this.scratchOpacity = 0.04,
    this.scratchCount = 6,
    this.densityFactor = 900,
    this.seed = 42,
    this.vignette = true,
  });

  /// Paper base color — usually `config.background`.
  final Color baseColor;

  /// Color of the noise dots. Defaults to black for light papers, white for
  /// dark themes (auto-detected from luminance).
  final Color? grainColor;

  final double grainOpacity;
  final double scratchOpacity;
  final int scratchCount;

  /// Lower = denser grain. Default ~900 means roughly one dot per 900px².
  final double densityFactor;

  /// Fixed seed so the texture is deterministic and matches across reloads.
  final int seed;

  /// Soft radial darkening at the corners for an aged-paper effect.
  final bool vignette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = baseColor);

    final dark = baseColor.computeLuminance() < 0.5;
    final grain = grainColor ?? (dark ? Colors.white : Colors.black);

    final rng = math.Random(seed);

    // ── Grain ────────────────────────────────────────────────────────────────
    final grainPaint = Paint()..color = grain.withOpacity(grainOpacity);
    final dotCount = (size.width * size.height / densityFactor).round();
    for (int i = 0; i < dotCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.4, grainPaint);
    }

    // ── Faint scratches ──────────────────────────────────────────────────────
    final scratchPaint = Paint()
      ..color = grain.withOpacity(scratchOpacity)
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < scratchCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final dx = (rng.nextDouble() - 0.5) * 80;
      final dy = (rng.nextDouble() - 0.5) * 80;
      canvas.drawLine(Offset(x, y), Offset(x + dx, y + dy), scratchPaint);
    }

    // ── Vignette ─────────────────────────────────────────────────────────────
    if (vignette) {
      final vignettePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Colors.transparent,
            grain.withOpacity(0.05),
          ],
          stops: const [0.6, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, vignettePaint);
    }
  }

  @override
  bool shouldRepaint(PaperTexturePainter oldDelegate) =>
      oldDelegate.baseColor != baseColor ||
      oldDelegate.grainColor != grainColor ||
      oldDelegate.grainOpacity != grainOpacity ||
      oldDelegate.scratchCount != scratchCount ||
      oldDelegate.densityFactor != densityFactor ||
      oldDelegate.seed != seed ||
      oldDelegate.vignette != vignette;
}

/// Convenient wrapper: wraps `child` over a procedural paper texture filling
/// all available space. Use inside `Scaffold.body` for the scrapbook look.
class PaperBackdrop extends StatelessWidget {
  const PaperBackdrop({
    super.key,
    required this.child,
    required this.baseColor,
    this.grainOpacity = 0.06,
    this.scratchCount = 6,
    this.vignette = true,
  });

  final Widget child;
  final Color baseColor;
  final double grainOpacity;
  final int scratchCount;
  final bool vignette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PaperTexturePainter(
                baseColor: baseColor,
                grainOpacity: grainOpacity,
                scratchCount: scratchCount,
                vignette: vignette,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
