import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/ui/painters/postage_perforation_painter.dart';

/// Postage stamp card: perforated zigzag white border, photo/flag content,
/// price tag, optional faux postmark. Modelled after reference photo 7
/// ("LOVELY · LONDON · 150 cents") but theme-tunable.
///
/// Use for vault entries, achievement reveals, "letter from your journey"
/// moments — anywhere a country visit should feel like a real travel relic.
class PostageStamp extends StatelessWidget {
  const PostageStamp({
    super.key,
    required this.config,
    required this.child,
    this.width = 180,
    this.height = 220,
    this.priceLabel,
    this.placeLabel,
    this.showPostmark = true,
    this.rotation = -0.06,
  });

  final GastroThemeConfig config;
  final Widget child;
  final double width;
  final double height;

  /// Top-left price chip — like "150 cents" on a real stamp.
  final String? priceLabel;

  /// Right-side vertical text — like "LONDON".
  final String? placeLabel;

  /// Whether to overlay the round "cancelled" postmark.
  final bool showPostmark;

  /// Slight tilt for the snapshot-on-a-page look.
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final stamp = SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Perforated white background
          Positioned.fill(
            child: CustomPaint(
              painter: const PostagePerforationPainter(
                fill: Color(0xFFFCFAF5),
              ),
            ),
          ),

          // Inset photo / illustration area
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: child,
            ),
          ),

          // Price tag (top-left)
          if (priceLabel != null)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: const Color(0xFFFCFAF5),
                child: Text(
                  priceLabel!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                    height: 1.0,
                  ),
                ),
              ),
            ),

          // Vertical place label (right edge)
          if (placeLabel != null)
            Positioned(
              top: 16,
              right: 6,
              bottom: 16,
              child: RotatedBox(
                quarterTurns: 1,
                child: Container(
                  alignment: Alignment.centerRight,
                  child: Text(
                    placeLabel!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ),

          // Postmark
          if (showPostmark)
            Positioned(
              right: 10,
              bottom: 10,
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: PostmarkPainter(color: config.accent),
                ),
              ),
            ),
        ],
      ),
    );

    return Transform.rotate(angle: rotation, child: stamp);
  }
}
