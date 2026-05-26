import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/dashboard/data/daily_dishes.dart';

/// "Today's Dish" — a dashboard nudge that surfaces a curated dish-of-the-day
/// from `kDailyDishes`. The rotation is deterministic (day-of-year), so every
/// user sees the same dish on the same day. Where a matching Baku restaurant
/// exists in `kBakuRestaurants`, the card suggests it as the place to try.
class DailyDishCard extends StatelessWidget {
  const DailyDishCard({super.key, required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final dish = dailyDishForToday();
    // Prefer the explicitly-hinted restaurant when it's actually in the
    // catalogue; otherwise the first restaurant of the matching cuisine.
    final restaurant = _findRestaurant(dish);

    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s16, GS.s20, GS.s16),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(
          color: config.accent.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(config.isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kicker row: flag + "TODAY'S DISH" + cuisine ─────────────
          Row(
            children: [
              Text(dish.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: GS.s8),
              Expanded(
                child: Text(
                  "TODAY'S DISH · ${dish.cuisine.toUpperCase()}",
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w700,
                    color: config.accent,
                  ),
                ),
              ),
              Icon(
                LucideIcons.utensils,
                size: 14,
                color: config.onSurfaceVariant,
              ),
            ],
          ),

          const SizedBox(height: GS.s10),

          // ── Dish name (Playfair) ─────────────────────────────────────
          Text(
            dish.dish,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
              height: 1.1,
            ),
          ),

          const SizedBox(height: GS.s8),

          // ── Blurb (Caveat) — the human-feeling sell ─────────────────
          Text(
            dish.blurb,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.caveat(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: config.onSurfaceVariant,
              height: 1.2,
            ),
          ),

          // ── Recommended Baku spot ────────────────────────────────────
          if (restaurant != null) ...[
            const SizedBox(height: GS.s12),
            Container(
              padding: const EdgeInsets.fromLTRB(
                  GS.s12, GS.s8, GS.s12, GS.s8),
              decoration: BoxDecoration(
                color: config.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(GS.r12),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.mapPin, size: 14, color: config.accent),
                  const SizedBox(width: GS.s6),
                  Expanded(
                    child: Text(
                      'Try it in Baku · ${restaurant.name}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: config.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    restaurant.neighborhood,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: config.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  BakuRestaurant? _findRestaurant(DailyDish dish) {
    // Exact-name hint first.
    final byHint = kBakuRestaurants
        .where((r) =>
            r.name.toLowerCase() == dish.restaurantHint.toLowerCase())
        .toList();
    if (byHint.isNotEmpty) return byHint.first;
    // Fallback: first restaurant of the matching cuisine.
    final byCuisine = kBakuRestaurants
        .where((r) =>
            r.cuisine.toLowerCase() == dish.cuisine.toLowerCase())
        .toList();
    if (byCuisine.isNotEmpty) return byCuisine.first;
    return null;
  }
}
