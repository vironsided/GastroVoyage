import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';

/// Polaroid / Instax photo frame. Re-usable across map pins, vault entries,
/// dashboard journal.
///
/// Optional binder clip on top — themed per mode (Girls: pink, Couples:
/// muted blue, Guys: chrome). Reference photo 8.
class InstaxFrame extends StatelessWidget {
  const InstaxFrame({
    super.key,
    required this.config,
    this.photoUrl,
    this.caption,
    this.width = 96,
    this.photoHeight = 96,
    this.bottomPadding = 26,
    this.rotation = 0,
    this.showClip = false,
    this.clipColor,
    this.shadowOpacity = 0.25,
    this.placeholder,
  });

  final GastroThemeConfig config;
  final String? photoUrl;
  final String? caption;
  final double width;
  final double photoHeight;

  /// Extra white space below the photo — the polaroid "thick bottom".
  final double bottomPadding;

  /// Tilt in radians for a scrapbook feel. Use small values (±0.06).
  final double rotation;

  /// Draws a themed binder clip overlapping the top edge.
  final bool showClip;

  /// Override clip color (defaults to a per-theme tone).
  final Color? clipColor;

  final double shadowOpacity;

  /// Widget shown while the network image loads or when [photoUrl] is null.
  final Widget? placeholder;

  Color _defaultClipColor() {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return const Color(0xFFE2A0B8);
      case GastroThemeMode.couples:
        return const Color(0xFF7BA8D3);
      case GastroThemeMode.guys:
        return const Color(0xFFB8B8B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalH = photoHeight + bottomPadding + 8; // 8 = top inset
    final card = SizedBox(
      width: width,
      height: totalH + (showClip ? 18 : 0),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Polaroid body
          Positioned(
            top: showClip ? 12 : 0,
            child: Container(
              width: width,
              padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(shadowOpacity),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: width - 8,
                    height: photoHeight,
                    child: _photoOrPlaceholder(),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.caveat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Binder clip (overlaps the top)
          if (showClip)
            Positioned(
              top: 0,
              child: _BinderClip(
                color: clipColor ?? _defaultClipColor(),
                width: width * 0.30,
              ),
            ),
        ],
      ),
    );

    return Transform.rotate(angle: rotation, child: card);
  }

  Widget _photoOrPlaceholder() {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return placeholder ??
          Container(
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.image_outlined,
                color: Color(0xFFBDBDBD)),
          );
    }
    return CachedNetworkImage(
      imageUrl: photoUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
      errorWidget: (_, __, ___) =>
          Container(color: const Color(0xFFEEEEEE),
              child: const Icon(Icons.broken_image_outlined,
                  color: Color(0xFFBDBDBD))),
    );
  }
}

/// Small metal-look binder clip with a colored body, used to clip an Instax
/// to a background. Procedural so the color can match any theme.
class _BinderClip extends StatelessWidget {
  const _BinderClip({required this.color, this.width = 32});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.7;
    return SizedBox(
      width: width,
      height: h + 4,
      child: CustomPaint(painter: _BinderClipPainter(color: color)),
    );
  }
}

class _BinderClipPainter extends CustomPainter {
  const _BinderClipPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Drop shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, h * 0.30 + 1, w - 4, h * 0.50),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      shadowRect,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Main clip body — rounded rectangle with vertical gradient
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.30, w, h * 0.50),
      const Radius.circular(3),
    );
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          HSLColor.fromColor(color)
              .withLightness(
                  (HSLColor.fromColor(color).lightness + 0.12).clamp(0.0, 1.0))
              .toColor(),
          color,
          HSLColor.fromColor(color)
              .withLightness(
                  (HSLColor.fromColor(color).lightness - 0.18).clamp(0.0, 1.0))
              .toColor(),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    // Top loop (metal ring)
    final loopPaint = Paint()
      ..color = const Color(0xFFB8B8B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.35, 0, w * 0.30, h * 0.40),
      loopPaint,
    );

    // Specular highlight on body
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.34, w * 0.84, h * 0.06),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
  }

  @override
  bool shouldRepaint(_BinderClipPainter oldDelegate) =>
      oldDelegate.color != color;
}
