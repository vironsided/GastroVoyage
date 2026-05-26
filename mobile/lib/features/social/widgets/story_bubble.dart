import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';

/// Instagram-style story "bubble" — a circular author avatar wrapped in a
/// dashed ink ring, with the author's first name beneath. One bubble per
/// author who has posted stories; tapping it opens the story viewer at that
/// author's first story.
class StoryBubble extends StatelessWidget {
  const StoryBubble({
    super.key,
    required this.config,
    required this.name,
    required this.initial,
    required this.onTap,
    this.avatarUrl,
    this.size = 66,
  });

  final GastroThemeConfig config;
  final String name;
  final String initial;
  final String? avatarUrl;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    // First word of the name keeps the strip compact.
    final shortName = name.trim().split(RegExp(r'\s+')).first;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              painter: _StoryRingPainter(color: config.accent),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: SocialAvatar(
                  config: config,
                  initial: initial,
                  avatarUrl: avatarUrl,
                  size: size - 8,
                  borderColor: config.surface,
                  borderWidth: 2,
                ),
              ),
            ),
            const SizedBox(height: GS.s6),
            Text(
              shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: config.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed circular ring drawn around a story bubble — reads as a hand-inked
/// stamp border rather than a flat UI ring.
class _StoryRingPainter extends CustomPainter {
  const _StoryRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // 24 short dashes around the circle.
    const dashes = 24;
    const sweep = 6.283185307179586 / dashes;
    const gap = sweep * 0.42;
    for (var i = 0; i < dashes; i++) {
      final start = i * sweep + gap / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StoryRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
