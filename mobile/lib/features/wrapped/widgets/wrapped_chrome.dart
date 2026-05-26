import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Top progress indicator — one segment per card, Instagram-Stories style.
///
/// Each segment fills at a constant rate while [activeIndex] equals that
/// segment's index. Segments before the active one render filled; segments
/// after render empty. [progress] is the normalised 0–1 fill of the
/// currently-active segment.
class StoryProgressBar extends StatelessWidget {
  const StoryProgressBar({
    super.key,
    required this.config,
    required this.totalSegments,
    required this.activeIndex,
    required this.progress,
  });

  final GastroThemeConfig config;
  final int totalSegments;
  final int activeIndex;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final base = config.isDark
        ? Colors.white.withOpacity(0.20)
        : config.onSurface.withOpacity(0.18);
    final fill = config.isDark ? Colors.white : config.onSurface;

    return Row(
      children: List.generate(totalSegments, (i) {
        double pct;
        if (i < activeIndex) {
          pct = 1;
        } else if (i == activeIndex) {
          pct = progress.clamp(0, 1);
        } else {
          pct = 0;
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GS.r4),
              child: Stack(
                children: [
                  Container(height: 3, color: base),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(height: 3, color: fill),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Bold display number — used by counter animations and headline stats.
class BigNumber extends StatelessWidget {
  const BigNumber({
    super.key,
    required this.value,
    required this.config,
    this.fontSize = 120,
    this.color,
  });

  final String value;
  final GastroThemeConfig config;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.center,
      style: GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        height: 0.95,
        letterSpacing: -2,
        color: color ?? config.onSurface,
      ),
    );
  }
}

/// "JetBrains Mono kicker" — tiny letter-spaced uppercase label that sits
/// above every card's title.
class WrappedKicker extends StatelessWidget {
  const WrappedKicker({
    super.key,
    required this.text,
    required this.config,
    this.color,
  });

  final String text;
  final GastroThemeConfig config;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.6,
        color: color ?? config.accent,
      ),
    );
  }
}

/// Card title — Playfair Display, large, with optional emphasis colour.
class WrappedTitle extends StatelessWidget {
  const WrappedTitle({
    super.key,
    required this.text,
    required this.config,
    this.fontSize = 32,
    this.textAlign = TextAlign.center,
    this.maxLines = 6,
  });

  final String text;
  final GastroThemeConfig config;
  final double fontSize;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: config.onSurface,
      ),
    );
  }
}

/// Handwritten Caveat caption, used for scrapbook-style asides.
class WrappedScribble extends StatelessWidget {
  const WrappedScribble({
    super.key,
    required this.text,
    required this.config,
    this.fontSize = 20,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final GastroThemeConfig config;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: config.onSurfaceVariant,
      ),
    );
  }
}

/// A diagonal piece of washi tape decoration — for the scrapbook feel.
/// Pure presentation. Pass a [rotation] in radians and a [width].
class WashiTape extends StatelessWidget {
  const WashiTape({
    super.key,
    required this.config,
    this.width = 120,
    this.height = 24,
    this.rotation = 0,
    this.colorOverride,
  });

  final GastroThemeConfig config;
  final double width;
  final double height;
  final double rotation;
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    final base = (colorOverride ?? config.accent).withOpacity(0.55);
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: CustomPaint(painter: _TapeStripePainter(base: base)),
      ),
    );
  }
}

class _TapeStripePainter extends CustomPainter {
  _TapeStripePainter({required this.base});
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.2;
    for (var x = -size.height.toDouble();
        x < size.width + size.height;
        x += 6) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TapeStripePainter oldDelegate) =>
      oldDelegate.base != base;
}

/// Background backdrop used inside every Wrapped card — a warm gradient
/// from the active theme's accent into the surface tone, with a vignette
/// for depth. Works in all six theme combos.
class WrappedBackdrop extends StatelessWidget {
  const WrappedBackdrop({
    super.key,
    required this.config,
    required this.child,
    this.accentLean = 0.5,
  });

  final GastroThemeConfig config;
  final Widget child;

  /// 0 = mostly surface, 1 = mostly accent. Controls how warm the backdrop
  /// is for that particular card.
  final double accentLean;

  @override
  Widget build(BuildContext context) {
    final t = accentLean.clamp(0.0, 1.0);
    final topTint = Color.lerp(config.surface, config.accent, 0.18 + t * 0.20)!;
    final bottomTint =
        Color.lerp(config.background, config.accent, 0.04 + t * 0.10)!;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topTint, bottomTint],
            ),
          ),
        ),
        // Soft vignette to focus attention on the centre.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  Colors.transparent,
                  (config.isDark ? Colors.black : Colors.black)
                      .withOpacity(config.isDark ? 0.35 : 0.10),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
