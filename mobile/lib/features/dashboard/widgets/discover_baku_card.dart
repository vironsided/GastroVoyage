import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';

/// Home hero entry-point for the Baku food guide — the app's flagship city.
///
/// Baku was previously only reachable by toggling inside the Map tab, so this
/// surfaces it directly on Home. Tapping deep-links to the Map tab in Baku
/// mode via [mapModeProvider] + [bottomNavIndexProvider] (no fragile standalone
/// push of `BakuMapScreen`, which renders without a Scaffold).
class DiscoverBakuCard extends ConsumerWidget {
  const DiscoverBakuCard({super.key, required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Open the Baku food map',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GS.r24),
          onTap: () {
            // Deep-link: Map tab, Baku mode.
            ref.read(mapModeProvider.notifier).state = 1;
            ref.read(bottomNavIndexProvider.notifier).state = AppTab.map;
          },
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
                        // Azerbaijan flag medallion.
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
                          child: const Text('🇦🇿', style: TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: GS.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(LucideIcons.map,
                                      size: 11, color: config.accent),
                                  const SizedBox(width: GS.s6),
                                  Flexible(
                                    child: Text(
                                      'BAKU FOOD MAP',
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
                                'Discover Baku',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: config.onSurface,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: GS.s4),
                              Text(
                                '$kBakuRestaurantsCount spots across the city — '
                                'explore the live map',
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
