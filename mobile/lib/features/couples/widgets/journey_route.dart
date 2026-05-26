import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';

/// A hand-drawn dotted "travel route" segment drawn down the left rail of the
/// journey timeline, connecting one week "stop" to the next.
///
/// The segment is rendered as a column of small ink dots with a gentle
/// horizontal wobble, so the route reads like a route traced by hand on a
/// vintage map rather than a clean CAD line.
class JourneyRouteSegment extends StatelessWidget {
  const JourneyRouteSegment({
    super.key,
    required this.config,
    required this.completed,
    this.height = 56,
    this.width = 36,
  });

  final GastroThemeConfig config;

  /// A completed segment is inked solid in the accent colour; an upcoming
  /// segment is faint, like a route not yet travelled.
  final bool completed;

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DottedRoutePainter(
          color: completed
              ? config.accent
              : config.onSurfaceVariant.withOpacity(0.28),
          completed: completed,
        ),
      ),
    );
  }
}

class _DottedRoutePainter extends CustomPainter {
  const _DottedRoutePainter({required this.color, required this.completed});

  final Color color;
  final bool completed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    const dotGap = 9.0;
    final dotRadius = completed ? 2.4 : 1.8;

    double y = 4;
    var i = 0;
    while (y < size.height - 2) {
      // Gentle deterministic wobble so the route looks hand-traced.
      final wobble = (i.isEven ? 1 : -1) * (2.2 + (i % 3) * 1.1);
      canvas.drawCircle(Offset(cx + wobble, y), dotRadius, paint);
      y += dotGap;
      i++;
    }
  }

  @override
  bool shouldRepaint(_DottedRoutePainter old) =>
      old.color != color || old.completed != completed;
}

/// A small circular "stop marker" sitting on the route rail beside each week
/// card — filled when the week is reached, hollow when still ahead.
class JourneyStopMarker extends StatelessWidget {
  const JourneyStopMarker({
    super.key,
    required this.config,
    required this.completed,
    required this.current,
    this.size = 18,
  });

  final GastroThemeConfig config;
  final bool completed;
  final bool current;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color ring;
    if (completed) {
      fill = config.accent;
      ring = config.accent;
    } else if (current) {
      fill = config.surface;
      ring = config.accent;
    } else {
      fill = config.surface;
      ring = config.onSurfaceVariant.withOpacity(0.35);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: current ? 2.4 : 1.6),
        boxShadow: current
            ? [
                BoxShadow(
                  color: config.accent.withOpacity(0.30),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: completed
          ? Icon(Icons.check, size: size * 0.62, color: Colors.white)
          : current
              ? Center(
                  child: Container(
                    width: size * 0.36,
                    height: size * 0.36,
                    decoration: BoxDecoration(
                      color: config.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
    );
  }
}
