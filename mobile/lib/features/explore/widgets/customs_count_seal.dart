import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/features/explore/widgets/customs_painters.dart';

/// A slightly crooked round ink-stamp "count seal" for the passport header,
/// e.g.  ON FILE / 195 / 12 tasted.
///
/// Drawn with the rough [CustomsStampPainter] ring; the big count number sits
/// in Playfair, with monospace customs lines above and below.
class CustomsCountSeal extends StatelessWidget {
  const CustomsCountSeal({
    super.key,
    required this.config,
    required this.total,
    required this.tasted,
    this.size = 92,
    this.rotation = 0.13,
  });

  final GastroThemeConfig config;
  final int total;
  final int tasted;
  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final ink = config.accent;

    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: CustomsStampPainter(
                color: ink,
                label: '',
                seed: 11,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ON FILE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: size * 0.10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: ink.withOpacity(0.78),
                  ),
                ),
                SizedBox(height: size * 0.01),
                Text(
                  '$total',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: ink,
                  ),
                ),
                SizedBox(height: size * 0.015),
                Text(
                  '$tasted TASTED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: size * 0.085,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: ink.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
