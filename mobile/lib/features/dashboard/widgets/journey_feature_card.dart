import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/couples/couples_journey_screen.dart';
import 'package:mobile/features/couples/data/couples_itinerary.dart';

/// Dashboard hero entry-point for the "Weekly Couples' Culinary Journey".
///
/// A featured scrapbook card — washi-tape framing, the current week's cuisine
/// preview, and a tap target opening [CouplesJourneyScreen]. When the journey
/// has not started or is finished it adapts its copy accordingly.
class JourneyFeatureCard extends StatelessWidget {
  const JourneyFeatureCard({
    super.key,
    required this.config,
    required this.completedWeeks,
  });

  final GastroThemeConfig config;

  /// Completed-week count from `couplesProgressProvider`; null while loading
  /// or on error — the card still shows, just with neutral copy.
  final int? completedWeeks;

  @override
  Widget build(BuildContext context) {
    final total = kCouplesJourneyLength;
    final done = (completedWeeks ?? 0).clamp(0, total);
    final finished = done >= total;
    final upcoming = finished ? kCouplesJourney.last : kCouplesJourney[done];

    final String kicker;
    final String headline;
    if (completedWeeks == null) {
      kicker = 'A JOURNEY FOR TWO';
      headline = 'Plan your weekly culinary date';
    } else if (finished) {
      kicker = 'JOURNEY COMPLETE';
      headline = 'All eight weeks tasted together';
    } else if (done == 0) {
      kicker = 'WEEK 01 AWAITS';
      headline = 'Start with ${upcoming.cuisine} — ${upcoming.title}';
    } else {
      kicker = 'WEEK ${(done + 1).toString().padLeft(2, '0')} OF $total';
      headline = 'Next: ${upcoming.cuisine} — ${upcoming.title}';
    }

    return Semantics(
      button: true,
      label: 'Open the couples culinary journey',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GS.r24),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CouplesJourneyScreen(),
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: config.surface,
              borderRadius: BorderRadius.circular(GS.r24),
              border:
                  Border.all(color: config.accent.withOpacity(0.45), width: 1.2),
              boxShadow: GS.shadow(
                color: config.accent,
                blur: 24,
                yOffset: 10,
                opacity: config.isDark ? 0.18 : 0.12,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GS.r24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 4, color: config.accent),
                  Padding(
                    padding: const EdgeInsets.all(GS.s20),
                    child: Row(
                      children: [
                        // Flag medallion for the featured/next cuisine.
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: config.accent.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: config.accent.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            finished ? '💌' : upcoming.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: GS.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(LucideIcons.heart,
                                      size: 11, color: config.accent),
                                  const SizedBox(width: GS.s6),
                                  Flexible(
                                    child: Text(
                                      kicker,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        letterSpacing: 1.6,
                                        fontWeight: FontWeight.w600,
                                        color: config.accent,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: GS.s6),
                              Text(
                                'Your Journey for Two',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: config.onSurface,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: GS.s4),
                              Text(
                                headline,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.5,
                                  color: config.onSurfaceVariant,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: GS.s8),
                        Icon(LucideIcons.chevronRight,
                            size: 20,
                            color: config.onSurfaceVariant.withOpacity(0.6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
