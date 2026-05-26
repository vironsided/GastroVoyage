/// Hand-curated catalogue of every achievement the app currently surfaces.
///
/// The backend (`GET /badges`) only returns *earned* badges (plus a few
/// "in-flight" placeholders), so the **set of possible badges** is owned by
/// the client. The Achievements screen merges this catalogue with the
/// earned list to render both the "unlocked" stamps and the locked
/// silhouettes side by side.
///
/// Matching strategy: an earned [CuisineBadge] is considered to satisfy a
/// [BadgeDef] when one of these holds (in order):
///
///   1. `def.id == badge.code` (canonical case)
///   2. case-insensitive equality of `def.id` and `badge.code`
///   3. case-insensitive equality of `def.name` and `badge.title` (legacy
///      fallback for badges that pre-date the `code` field)
///
/// Helper [findEarned] encapsulates this so the screen does not need to
/// know about it.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/features/shared/models.dart';

/// Whether a badge has been earned, or remains locked behind a condition.
enum BadgeUnlockedStatus { unlocked, locked }

/// Top-level grouping used by the filter chips on the Achievements screen.
enum BadgeCategory {
  regional,
  streak,
  palate,
  social,
  journey,
}

extension BadgeCategoryX on BadgeCategory {
  /// Label rendered in the filter chip strip.
  String get label {
    switch (this) {
      case BadgeCategory.regional: return 'Regional';
      case BadgeCategory.streak:   return 'Streak';
      case BadgeCategory.palate:   return 'Palate';
      case BadgeCategory.social:   return 'Social';
      case BadgeCategory.journey:  return 'Journey';
    }
  }

  /// Small glyph used next to the category label.
  IconData get icon {
    switch (this) {
      case BadgeCategory.regional: return LucideIcons.globe;
      case BadgeCategory.streak:   return LucideIcons.flame;
      case BadgeCategory.palate:   return LucideIcons.utensilsCrossed;
      case BadgeCategory.social:   return LucideIcons.users;
      case BadgeCategory.journey:  return LucideIcons.compass;
    }
  }
}

/// A single possible achievement — the *definition*, not an earned instance.
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.name,
    required this.category,
    required this.cuisineCodeOrEmoji,
    required this.description,
    required this.unlocksAt,
  });

  /// Kebab-case stable identifier, e.g. `asia-explorer`. Used to match against
  /// the backend's `code` field on [CuisineBadge].
  final String id;

  /// Human-readable display name, e.g. `Asia Explorer`.
  final String name;

  /// Category bucket used for filtering.
  final BadgeCategory category;

  /// A flag emoji or symbolic glyph rendered inside the stamp.
  final String cuisineCodeOrEmoji;

  /// One-line unlock condition, written in player-facing language.
  final String description;

  /// Numeric threshold the player has to reach (e.g. 5 visits). Used by the
  /// "How to unlock" bottom sheet copy.
  final int unlocksAt;
}

/// The full catalogue. ~24 badges grouped into five categories.
const List<BadgeDef> kBadgeCatalogue = <BadgeDef>[
  // ── Regional ──────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'asia-explorer',
    name: 'Asia Explorer',
    category: BadgeCategory.regional,
    cuisineCodeOrEmoji: '🥢',
    description: 'Taste 5 dishes from Asia',
    unlocksAt: 5,
  ),
  BadgeDef(
    id: 'europe-voyager',
    name: 'Europe Voyager',
    category: BadgeCategory.regional,
    cuisineCodeOrEmoji: '🍷',
    description: 'Sample 10 European cuisines',
    unlocksAt: 10,
  ),
  BadgeDef(
    id: 'americas-trekker',
    name: 'Americas Trekker',
    category: BadgeCategory.regional,
    cuisineCodeOrEmoji: '🌽',
    description: 'Try 5 dishes from the Americas',
    unlocksAt: 5,
  ),
  BadgeDef(
    id: 'african-drifter',
    name: 'African Drifter',
    category: BadgeCategory.regional,
    cuisineCodeOrEmoji: '🥘',
    description: 'Taste 3 cuisines from Africa',
    unlocksAt: 3,
  ),
  BadgeDef(
    id: 'oceania-wanderer',
    name: 'Oceania Wanderer',
    category: BadgeCategory.regional,
    cuisineCodeOrEmoji: '🐟',
    description: 'Sample 2 cuisines from Oceania',
    unlocksAt: 2,
  ),
  BadgeDef(
    id: 'middle-east-mystic',
    name: 'Middle East Mystic',
    category: BadgeCategory.regional,
    cuisineCodeOrEmoji: '🫖',
    description: 'Taste 3 Middle Eastern cuisines',
    unlocksAt: 3,
  ),

  // ── Streak ────────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'first-bite',
    name: 'First Bite',
    category: BadgeCategory.streak,
    cuisineCodeOrEmoji: '🍽',
    description: 'Log your very first tasting',
    unlocksAt: 1,
  ),
  BadgeDef(
    id: 'five-plates',
    name: 'Five Plates',
    category: BadgeCategory.streak,
    cuisineCodeOrEmoji: '🍱',
    description: 'Log 5 tastings in the passport',
    unlocksAt: 5,
  ),
  BadgeDef(
    id: 'wanderer',
    name: 'Wanderer',
    category: BadgeCategory.streak,
    cuisineCodeOrEmoji: '🧭',
    description: 'Reach 15 tastings across the world',
    unlocksAt: 15,
  ),
  BadgeDef(
    id: 'globetrotter',
    name: 'Globetrotter',
    category: BadgeCategory.streak,
    cuisineCodeOrEmoji: '🌍',
    description: 'Log 30 tastings worldwide',
    unlocksAt: 30,
  ),
  BadgeDef(
    id: 'centurion',
    name: 'Centurion',
    category: BadgeCategory.streak,
    cuisineCodeOrEmoji: '💯',
    description: 'A full century of tastings — 100 plates',
    unlocksAt: 100,
  ),

  // ── Palate ────────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'sweet-tooth',
    name: 'Sweet Tooth',
    category: BadgeCategory.palate,
    cuisineCodeOrEmoji: '🍰',
    description: 'Log 3 dessert tastings',
    unlocksAt: 3,
  ),
  BadgeDef(
    id: 'spice-hunter',
    name: 'Spice Hunter',
    category: BadgeCategory.palate,
    cuisineCodeOrEmoji: '🌶',
    description: 'Brave 5 spicy dishes',
    unlocksAt: 5,
  ),
  BadgeDef(
    id: 'comfort-soul',
    name: 'Comfort Soul',
    category: BadgeCategory.palate,
    cuisineCodeOrEmoji: '🍲',
    description: 'Average 5★ across 5 cuisines',
    unlocksAt: 5,
  ),
  BadgeDef(
    id: 'adventurous',
    name: 'Adventurous',
    category: BadgeCategory.palate,
    cuisineCodeOrEmoji: '🎲',
    description: 'Try 8 distinct cuisines',
    unlocksAt: 8,
  ),
  BadgeDef(
    id: 'plant-devotee',
    name: 'Plant Devotee',
    category: BadgeCategory.palate,
    cuisineCodeOrEmoji: '🌿',
    description: 'Log 5 vegetarian tastings',
    unlocksAt: 5,
  ),

  // ── Social ────────────────────────────────────────────────────────────────
  BadgeDef(
    id: 'first-follower',
    name: 'First Follower',
    category: BadgeCategory.social,
    cuisineCodeOrEmoji: '👋',
    description: 'Welcome your first follower',
    unlocksAt: 1,
  ),
  BadgeDef(
    id: 'five-friends',
    name: 'Five Friends',
    category: BadgeCategory.social,
    cuisineCodeOrEmoji: '🤝',
    description: 'Get 5 follow requests accepted',
    unlocksAt: 5,
  ),
  BadgeDef(
    id: 'storyteller',
    name: 'Storyteller',
    category: BadgeCategory.social,
    cuisineCodeOrEmoji: '📖',
    description: 'Publish your first story',
    unlocksAt: 1,
  ),
  BadgeDef(
    id: 'cheerleader',
    name: 'Cheerleader',
    category: BadgeCategory.social,
    cuisineCodeOrEmoji: '🎉',
    description: 'Send 10 reactions to other travellers',
    unlocksAt: 10,
  ),
  BadgeDef(
    id: 'open-passport',
    name: 'Open Passport',
    category: BadgeCategory.social,
    cuisineCodeOrEmoji: '📬',
    description: 'Set your passport privacy to public',
    unlocksAt: 1,
  ),

  // ── Journey (Couples) ─────────────────────────────────────────────────────
  BadgeDef(
    id: 'couples-week-1',
    name: "Couple's Week 1",
    category: BadgeCategory.journey,
    cuisineCodeOrEmoji: '💞',
    description: 'Finish week 1 of the couples journey',
    unlocksAt: 1,
  ),
  BadgeDef(
    id: 'halfway-there',
    name: 'Halfway There',
    category: BadgeCategory.journey,
    cuisineCodeOrEmoji: '🌗',
    description: 'Reach week 4 of the couples journey',
    unlocksAt: 4,
  ),
  BadgeDef(
    id: 'journey-complete',
    name: 'Journey Complete',
    category: BadgeCategory.journey,
    cuisineCodeOrEmoji: '🏁',
    description: 'Finish the full 8-week couples journey',
    unlocksAt: 8,
  ),
];

/// Returns the matching earned [CuisineBadge] for [def], or `null` when the
/// player has not unlocked it yet. See the library doc-comment for the
/// matching strategy.
CuisineBadge? findEarned(BadgeDef def, List<CuisineBadge> earned) {
  // 1) Exact code match.
  for (final b in earned) {
    if (!b.earned) continue;
    if (b.code == def.id) return b;
  }
  // 2) Case-insensitive code match.
  final lowerId = def.id.toLowerCase();
  for (final b in earned) {
    if (!b.earned) continue;
    if (b.code.toLowerCase() == lowerId) return b;
  }
  // 3) Case-insensitive name/title match.
  final lowerName = def.name.toLowerCase();
  for (final b in earned) {
    if (!b.earned) continue;
    if (b.title.toLowerCase() == lowerName) return b;
  }
  return null;
}

/// Convenience: status for one definition against the user's earned list.
BadgeUnlockedStatus statusFor(BadgeDef def, List<CuisineBadge> earned) =>
    findEarned(def, earned) != null
        ? BadgeUnlockedStatus.unlocked
        : BadgeUnlockedStatus.locked;
