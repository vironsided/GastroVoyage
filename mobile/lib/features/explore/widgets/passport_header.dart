import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/explore/widgets/customs_count_seal.dart';
import 'package:mobile/features/explore/widgets/customs_painters.dart';

/// The passport inside-cover header for the Explore screen.
///
/// Layout (top → bottom):
///   • `CUSTOMS · DISCOVERY` monospace eyebrow + ink rule + `No. 014` doc no.
///   • a two-line Playfair title — `World` upright / `Cuisines` italic accent —
///     with a small handwritten Caveat aside, and a crooked round count seal.
///
/// The orchestrated screen-load motion is applied here so the header animates
/// as one piece. [total] / [tasted] drive the count seal; pass nulls while the
/// country list is still loading to show a quiet placeholder.
class PassportHeader extends StatelessWidget {
  const PassportHeader({
    super.key,
    required this.config,
    required this.total,
    required this.tasted,
  });

  final GastroThemeConfig config;
  final int? total;
  final int? tasted;

  @override
  Widget build(BuildContext context) {
    final mono = config.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Eyebrow row: CUSTOMS · DISCOVERY  ·····  No. 014 ──────────────
        Row(
          children: [
            Text(
              'CUSTOMS · DISCOVERY',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: config.accent,
                letterSpacing: 2.4,
              ),
            ),
            const Spacer(),
            Text(
              'No. 014',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: mono.withOpacity(0.7),
                letterSpacing: 1.4,
              ),
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 360.ms, curve: GS.smooth)
            .slideY(begin: -0.5, end: 0, duration: 360.ms, curve: GS.smooth),
        const SizedBox(height: GS.s6),
        // ── Ink rule under the eyebrow ────────────────────────────────────
        SizedBox(
          height: 5,
          width: double.infinity,
          child: CustomPaint(
            painter: InkRulePainter(color: mono.withOpacity(0.55)),
          ),
        )
            .animate()
            .fadeIn(duration: 320.ms, delay: 90.ms)
            .scaleX(
              begin: 0,
              end: 1,
              alignment: Alignment.centerLeft,
              duration: 420.ms,
              delay: 90.ms,
              curve: GS.smooth,
            ),
        const SizedBox(height: GS.s12),
        // ── Title block + count seal ──────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'World',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                      height: 0.98,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 460.ms, delay: 120.ms, curve: GS.smooth)
                      .slideX(
                        begin: -0.12,
                        end: 0,
                        duration: 460.ms,
                        delay: 120.ms,
                        curve: GS.smooth,
                      ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Cuisines',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 44,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          color: config.accent,
                          height: 1.0,
                        ),
                      )
                          .animate()
                          .fadeIn(
                              duration: 460.ms,
                              delay: 200.ms,
                              curve: GS.smooth)
                          .slideX(
                            begin: -0.16,
                            end: 0,
                            duration: 460.ms,
                            delay: 200.ms,
                            curve: GS.smooth,
                          ),
                      const SizedBox(width: GS.s8),
                      // Flex + FittedBox: the rotated Caveat aside claims
                      // its unrotated width for layout — when "Cuisines"
                      // eats most of the row, the aside used to overflow
                      // the Row by ~21 px. Now it scales down to fit.
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomLeft,
                            child: Transform.rotate(
                              angle: -0.12,
                              child: Text(
                                'every plate, a border',
                                style: GoogleFonts.caveat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: config.onSurfaceVariant.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 420.ms, delay: 360.ms),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s8),
            // count seal — pops in with easeOutBack
            if (total != null)
              CustomsCountSeal(
                config: config,
                total: total!,
                tasted: tasted ?? 0,
              )
                  .animate()
                  .fadeIn(duration: 360.ms, delay: 300.ms)
                  .scale(
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    duration: 520.ms,
                    delay: 300.ms,
                    curve: Curves.easeOutBack,
                  )
            else
              SizedBox(
                width: 92,
                height: 92,
                child: Center(
                  child: Text(
                    '···',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 20,
                      color: config.onSurfaceVariant.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
