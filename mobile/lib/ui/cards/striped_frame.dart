import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Card with a vertical pinstripe border and a clean oval / pill cutout in
/// the middle that hosts content. Couples-theme decorative wrapper.
/// Reference: design photo 12.
///
/// Pattern is procedural so the stripe color follows `config.accent`.
class StripedFrame extends StatelessWidget {
  const StripedFrame({
    super.key,
    required this.child,
    required this.config,
    this.stripeColor,
    this.background = Colors.white,
    this.borderRadius = 18,
    this.cutoutPadding = 22,
    this.cutoutRadius = 90,
  });

  final Widget child;
  final GastroThemeConfig config;
  final Color? stripeColor;
  final Color background;
  final double borderRadius;

  /// Padding from outer edge to the cutout — controls how thick the stripe
  /// border looks.
  final double cutoutPadding;

  /// Corner radius of the inner cutout area. Use ~half of the height for a
  /// stadium/pill shape.
  final double cutoutRadius;

  @override
  Widget build(BuildContext context) {
    final stripe = stripeColor ?? config.accent.withOpacity(0.55);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: GS.shadow(
          color: Colors.black,
          blur: 16,
          yOffset: 6,
          opacity: 0.08,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          painter: _PinstripePainter(color: stripe),
          child: Padding(
            padding: EdgeInsets.all(cutoutPadding),
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(cutoutRadius),
                border: Border.all(
                  color: stripe.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(GS.s16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinstripePainter extends CustomPainter {
  const _PinstripePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const stripeW = 4.0;
    const gap = 8.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeW, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PinstripePainter oldDelegate) =>
      oldDelegate.color != color;
}
