import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/shared/models.dart';

/// Dashboard featured card surfacing the topmost wishlist entry — the next
/// country the user has flagged as "want to try".
///
/// Self-hides while the wishlist is loading, on error, or when the list is
/// empty so the dashboard never shows a half-blank card. Tapping the card
/// jumps to the Explore tab with the Wishlist bookmark filter pre-selected.
///
/// Visual language: a slim "boarding pass / luggage tag" card — flag
/// medallion, Playfair title, Caveat handwritten subtitle, monospace kicker.
class NextBiteCard extends ConsumerWidget {
  const NextBiteCard({super.key, required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final countries = wishlistAsync.asData?.value ?? const <Country>[];
    if (countries.isEmpty) {
      // Hidden while loading, on error, or when empty — the dashboard must
      // never carve out vertical space for a card that has nothing to show.
      return const SizedBox.shrink();
    }

    final next = countries.first;
    final remaining = countries.length - 1;

    final subtitle = remaining <= 0
        ? 'one stop on the list — make it count'
        : remaining == 1
            ? 'and 1 more bite to chase'
            : 'and $remaining more bites to chase';

    return Semantics(
      button: true,
      label: 'Next bite to chase: ${next.name}. Open Explore.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GS.r24),
          onTap: () => _jumpToWishlist(ref),
          child: Ink(
            decoration: BoxDecoration(
              color: config.surface,
              borderRadius: BorderRadius.circular(GS.r24),
              border: Border.all(
                color: config.accent.withOpacity(0.45),
                width: 1.2,
              ),
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
                  // Top accent rule — mirrors the Journey card so the two
                  // featured cards read as a matched pair.
                  Container(height: 4, color: config.accent),
                  Padding(
                    padding: const EdgeInsets.all(GS.s20),
                    child: Row(
                      children: [
                        // Flag medallion.
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
                            next.flagEmoji,
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
                                  Icon(
                                    LucideIcons.bookmark,
                                    size: 11,
                                    color: config.accent,
                                  ),
                                  const SizedBox(width: GS.s6),
                                  Flexible(
                                    child: Text(
                                      'NEXT BITE TO CHASE',
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
                                next.name,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: config.onSurface,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: GS.s2),
                              if (next.region.isNotEmpty)
                                Text(
                                  next.region.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: config.onSurfaceVariant
                                        .withOpacity(0.75),
                                  ),
                                ),
                              const SizedBox(height: GS.s6),
                              Text(
                                subtitle,
                                style: GoogleFonts.caveat(
                                  fontSize: 17,
                                  color: config.onSurfaceVariant,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: GS.s8),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: config.onSurfaceVariant.withOpacity(0.6),
                        ),
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

  /// Jump to the Explore tab and pre-select the Wishlist filter so the
  /// landing view shows exactly the same list this card is summarising.
  void _jumpToWishlist(WidgetRef ref) {
    ref.read(exploreTriedOnlyProvider.notifier).state = false;
    ref.read(exploreRegionProvider.notifier).state = null;
    ref.read(exploreWantToTryOnlyProvider.notifier).state = true;
    ref.read(bottomNavIndexProvider.notifier).state = AppTab.explore;
  }
}
