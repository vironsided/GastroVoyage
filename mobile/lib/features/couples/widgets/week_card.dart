import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/couples/data/couples_itinerary.dart';
import 'package:mobile/ui/ui.dart';

/// The visual state of a week on the couples' journey roadmap.
enum WeekState { completed, current, locked }

/// A single "stop" card on the couples' culinary journey timeline.
///
///  • [WeekState.completed] — dimmed but proud, ink-stamped "TASTED TOGETHER".
///  • [WeekState.current]   — highlighted & expanded: full narrative, signature
///                            dishes, the recommended Baku restaurant, and a
///                            primary "Mark this week complete" action.
///  • [WeekState.locked]    — wax-sealed and dimmed; narrative kept hidden.
class WeekCard extends StatelessWidget {
  const WeekCard({
    super.key,
    required this.week,
    required this.state,
    required this.config,
    required this.restaurant,
    this.onComplete,
    this.isCompleting = false,
  });

  final ItineraryWeek week;
  final WeekState state;
  final GastroThemeConfig config;

  /// The headline Baku restaurant recommendation (null if none matches).
  final BakuRestaurant? restaurant;

  /// Called when the couple marks the current week complete. Only wired for
  /// the current week.
  final VoidCallback? onComplete;

  /// True while the "mark complete" call is in flight — drives the button.
  final bool isCompleting;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case WeekState.current:
        return _CurrentWeekCard(
          week: week,
          config: config,
          restaurant: restaurant,
          onComplete: onComplete,
          isCompleting: isCompleting,
        );
      case WeekState.completed:
        return _CompletedWeekCard(week: week, config: config);
      case WeekState.locked:
        return _LockedWeekCard(week: week, config: config);
    }
  }
}

// ── Shared bits ────────────────────────────────────────────────────────────────

class _WeekKicker extends StatelessWidget {
  const _WeekKicker({required this.week, required this.config, this.dim = false});

  final ItineraryWeek week;
  final GastroThemeConfig config;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = dim
        ? config.onSurfaceVariant.withOpacity(0.55)
        : config.accent;
    return Text(
      'WEEK ${week.weekNumber.toString().padLeft(2, '0')}  ·  ${week.cuisine.toUpperCase()}',
      style: GoogleFonts.jetBrainsMono(
        fontSize: 9,
        letterSpacing: 1.8,
        fontWeight: FontWeight.w600,
        color: c,
      ),
    );
  }
}

// ── Current week — the highlighted, expanded card ──────────────────────────────

class _CurrentWeekCard extends StatelessWidget {
  const _CurrentWeekCard({
    required this.week,
    required this.config,
    required this.restaurant,
    required this.onComplete,
    required this.isCompleting,
  });

  final ItineraryWeek week;
  final GastroThemeConfig config;
  final BakuRestaurant? restaurant;
  final VoidCallback? onComplete;
  final bool isCompleting;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.accent.withOpacity(0.55), width: 1.4),
        boxShadow: GS.shadow(
          color: config.accent,
          blur: 26,
          yOffset: 12,
          opacity: config.isDark ? 0.22 : 0.16,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GS.r24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent strip — marks this as "you are here".
            Container(height: 4, color: config.accent),
            Padding(
              padding: const EdgeInsets.all(GS.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 12, color: config.accent),
                      const SizedBox(width: GS.s6),
                      Expanded(child: _WeekKicker(week: week, config: config)),
                      _ThisWeekTag(config: config),
                    ],
                  ),
                  const SizedBox(height: GS.s12),

                  // Flag + title.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(week.flag,
                          style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: GS.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              week.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: config.onSurface,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: GS.s4),
                            Row(
                              children: [
                                Icon(LucideIcons.heart,
                                    size: 11, color: config.accent),
                                const SizedBox(width: GS.s4),
                                Text(
                                  week.mood,
                                  style: GoogleFonts.caveat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: config.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GS.s16),

                  // Narrative.
                  Text(
                    week.narrative,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.5,
                      height: 1.55,
                      color: config.onSurface.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: GS.s16),

                  // Signature dishes.
                  _SectionLabel(
                      label: 'TO SHARE THIS WEEK', config: config),
                  const SizedBox(height: GS.s8),
                  Wrap(
                    spacing: GS.s8,
                    runSpacing: GS.s8,
                    children: [
                      for (final dish in week.signatureDishes)
                        _DishChip(label: dish, config: config),
                    ],
                  ),
                  const SizedBox(height: GS.s16),

                  // Recommended Baku restaurant.
                  _SectionLabel(
                      label: 'YOUR TABLE IN BAKU', config: config),
                  const SizedBox(height: GS.s8),
                  _RestaurantStub(restaurant: restaurant, config: config),
                  const SizedBox(height: GS.s20),

                  // Mark-complete action.
                  GastroButton(
                    label:
                        isCompleting ? 'STAMPING…' : 'MARK THIS WEEK COMPLETE',
                    icon: LucideIcons.stamp,
                    isLoading: isCompleting,
                    onPressed: onComplete,
                    config: config,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: GS.slow, curve: GS.smooth)
        .slideY(begin: 0.05, end: 0, duration: GS.slow, curve: GS.smooth);
  }
}

class _ThisWeekTag extends StatelessWidget {
  const _ThisWeekTag({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: GS.s8, vertical: GS.s4),
      decoration: BoxDecoration(
        color: config.accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(GS.rPill),
        border: Border.all(color: config.accent.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        'YOU ARE HERE',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 8,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: config.accent,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.config});
  final String label;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8.5,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: config.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: GS.s8),
        Expanded(
          child: Container(
            height: 0.8,
            color: config.outlineVariant,
          ),
        ),
      ],
    );
  }
}

class _DishChip extends StatelessWidget {
  const _DishChip({required this.label, required this.config});
  final String label;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: GS.s10, vertical: GS.s6),
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.r8),
        border: Border.all(color: config.outlineVariant, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.utensils, size: 11, color: config.accent),
          const SizedBox(width: GS.s6),
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantStub extends StatelessWidget {
  const _RestaurantStub({required this.restaurant, required this.config});
  final BakuRestaurant? restaurant;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    if (r == null) {
      return Text(
        'A venue for this cuisine is coming soon to the Baku map.',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          color: config.onSurfaceVariant,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(GS.s12),
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.r16),
        border: Border.all(color: config.outlineVariant, width: 0.6),
      ),
      child: Row(
        children: [
          Text(r.flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: GS.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                ),
                const SizedBox(height: GS.s2),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin,
                        size: 11, color: config.onSurfaceVariant),
                    const SizedBox(width: GS.s4),
                    Flexible(
                      child: Text(
                        r.neighborhood,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          color: config.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: GS.s4),
                  Text(
                    r.description,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: config.onSurfaceVariant.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: GS.s8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GS.s8, vertical: GS.s4),
            decoration: BoxDecoration(
              color: config.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(GS.r8),
            ),
            child: Text(
              r.priceRange,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: config.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completed week — dimmed but proud, ink-stamped ─────────────────────────────

class _CompletedWeekCard extends StatelessWidget {
  const _CompletedWeekCard({required this.week, required this.config});

  final ItineraryWeek week;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.82,
      child: Container(
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius: BorderRadius.circular(GS.r20),
          border: Border.all(color: config.outlineVariant, width: 0.6),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(GS.s16, GS.s16, GS.s12, GS.s16),
          child: Row(
            children: [
              Text(week.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: GS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WeekKicker(week: week, config: config, dim: true),
                    const SizedBox(height: GS.s4),
                    Text(
                      week.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GS.s8),
              StampBadge(
                label: 'TASTED\nTOGETHER',
                config: config,
                size: 64,
                shape: StampShape.circle,
                color: config.gold,
                seed: week.weekNumber * 3,
                rotation: -0.16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Locked week — wax-sealed, narrative hidden ─────────────────────────────────

class _LockedWeekCard extends StatelessWidget {
  const _LockedWeekCard({required this.week, required this.config});

  final ItineraryWeek week;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: config.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(
          color: config.outlineVariant.withOpacity(0.7),
          width: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(GS.s16, GS.s16, GS.s12, GS.s16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.lock,
                          size: 11,
                          color: config.onSurfaceVariant.withOpacity(0.5)),
                      const SizedBox(width: GS.s6),
                      Text(
                        'WEEK ${week.weekNumber.toString().padLeft(2, '0')}  ·  LOCKED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w600,
                          color: config.onSurfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GS.s6),
                  Text(
                    'Complete the weeks before to unlock this stop.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: config.onSurfaceVariant.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s8),
            WaxSeal(
              config: config,
              size: 46,
              rotation: 0.12,
              label: week.weekNumber.toString(),
            ),
          ],
        ),
      ),
    );
  }
}
