import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/ui/ui.dart';

import 'scrapbook_bits.dart';

/// The "Culinary Passport" hero card — a passport-page styled progress panel
/// with a mode accent strip, a progress ring, and a faux postmark.
class PassportCard extends StatelessWidget {
  const PassportCard({
    super.key,
    required this.profile,
    required this.config,
  });

  final UserProfile profile;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final progress = profile.totalCountries > 0
        ? profile.visitedCount / profile.totalCountries
        : 0.0;

    // Plain Container — no outer Stack and no top margin. The previous
    // wax-seal sticker needed the Stack (for the Positioned overlay) and the
    // GS.s20 top margin (for the seal to protrude). Both are gone now.
    return Container(
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant, width: 0.5),
        boxShadow: GS.shadow(
          color: config.accent,
          blur: 28,
          yOffset: 12,
          opacity: config.isDark ? 0.18 : 0.10,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GS.r24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeAccentBar(config: config),
            Padding(
              padding: const EdgeInsets.all(GS.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header line: label + faux entry no. ───────────
                      Row(
                        children: [
                          Icon(LucideIcons.bookOpen,
                              size: 11, color: config.accent),
                          const SizedBox(width: GS.s6),
                          Text(
                            'CULINARY PASSPORT',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              letterSpacing: 2.0,
                              color: config.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'NO. ${profile.visitedCount.toString().padLeft(3, '0')}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              letterSpacing: 1.0,
                              color: config.onSurfaceVariant
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: GS.s16),

                      Row(
                        children: [
                          // ── Progress ring ──────────────────────────────
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: GS.xslow,
                              curve: GS.smooth,
                              builder: (_, value, __) => CustomPaint(
                                painter: _ProgressRingPainter(
                                  progress: value,
                                  trackColor: config.outlineVariant,
                                  progressColor: config.accent,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${profile.visitedCount}',
                                        style: GoogleFonts.playfairDisplay(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: config.accent,
                                          height: 1.0,
                                        ),
                                      ),
                                      Text(
                                        'of ${profile.totalCountries}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 8,
                                          color: config.onSurfaceVariant,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: GS.s20),

                          // ── Stats column ──────────────────────────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(progress * 100).toStringAsFixed(1)}%',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: config.onSurface,
                                    height: 1.0,
                                  ),
                                ),
                                MarginNote(
                                  text: 'of the world tasted',
                                  config: config,
                                  fontSize: 16,
                                  rotation: -0.02,
                                ),
                                const SizedBox(height: GS.s12),
                                _MiniStat(
                                  icon: LucideIcons.award,
                                  label:
                                      '${profile.badges.length} ${profile.badges.length == 1 ? 'badge' : 'badges'} earned',
                                  config: config,
                                ),
                                if (profile.homeCity != null) ...[
                                  const SizedBox(height: GS.s4),
                                  _MiniStat(
                                    icon: LucideIcons.mapPin,
                                    label: profile.homeCity!,
                                    config: config,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: GS.s16),

                      // ── Progress bar ──────────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(GS.rPill),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0, end: progress.clamp(0.0, 1.0)),
                          duration: GS.xslow,
                          curve: GS.smooth,
                          builder: (_, value, __) =>
                              LinearProgressIndicator(
                            value: value,
                            backgroundColor: config.outlineVariant,
                            valueColor:
                                AlwaysStoppedAnimation(config.accent),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ModeAccentBar extends StatelessWidget {
  const _ModeAccentBar({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return SizedBox(
          height: 8,
          child: CustomPaint(
            size: const Size(double.infinity, 8),
            painter: LacePainter(color: config.accent),
          ),
        );
      case GastroThemeMode.couples:
        return SizedBox(
          height: 4,
          child: CustomPaint(
            size: const Size(double.infinity, 4),
            painter: StripePainter(color: config.accent),
          ),
        );
      case GastroThemeMode.guys:
        return Container(height: 3, color: config.accent);
    }
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.config,
  });

  final IconData icon;
  final String label;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: config.accent),
        const SizedBox(width: GS.s6),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              color: config.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Progress ring with a small rounded dot marking the leading edge.
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    final clamped = progress.clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    final sweep = 2 * math.pi * clamped;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Leading-edge dot.
    if (clamped > 0.01) {
      final angle = -math.pi / 2 + sweep;
      final dot = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(dot, 4.5, Paint()..color = progressColor);
      canvas.drawCircle(
          dot, 2.0, Paint()..color = Colors.white.withOpacity(0.9));
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}
