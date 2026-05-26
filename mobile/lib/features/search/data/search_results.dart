import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/social/data/social_models.dart';

/// Categorical hit kind — drives section grouping in the result list.
enum SearchHitKind { country, cuisine, restaurant, friend }

/// Common shape for every hit. Subclasses carry the typed payload used
/// by the result list to route taps to the right screen.
sealed class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.score,
  });

  /// Stable identity inside a list (Country.id, restaurant name, user_id...).
  final String id;

  /// Primary line shown to the user.
  final String title;

  /// Smaller helper line (region, neighborhood, cuisine, follow-status).
  final String subtitle;

  final SearchHitKind kind;

  /// Match strength — higher is better. Used purely to sort the merged
  /// result list across all four sources. The sort is then stable per kind.
  final int score;
}

class CountryHit extends SearchHit {
  CountryHit({
    required this.country,
    required int score,
  }) : super(
          id: country.id,
          title: country.name,
          subtitle: '',
          kind: SearchHitKind.country,
          score: score,
        );

  final Country country;
}

class CuisineHit extends SearchHit {
  const CuisineHit({
    required this.cuisine,
    required this.flag,
    required this.restaurantCount,
    required int score,
  }) : super(
          id: cuisine,
          title: cuisine,
          subtitle: '',
          kind: SearchHitKind.cuisine,
          score: score,
        );

  final String cuisine;
  final String flag;
  final int restaurantCount;
}

class RestaurantHit extends SearchHit {
  RestaurantHit({
    required this.restaurant,
    required int score,
  }) : super(
          id: restaurant.name,
          title: restaurant.name,
          subtitle: '',
          kind: SearchHitKind.restaurant,
          score: score,
        );

  final BakuRestaurant restaurant;
}

class FriendHit extends SearchHit {
  FriendHit({
    required this.user,
    required int score,
  }) : super(
          id: user.userId,
          title: user.name,
          subtitle: '',
          kind: SearchHitKind.friend,
          score: score,
        );

  final SocialUser user;
}

/// Local fuzzy-match score: returns the best of substring / prefix / token
/// match, or 0 when no signal at all. Higher is better. Designed so that
/// "ita" → "Italy" (prefix) ranks above "ita" → "Mumbai Palace · India"
/// (substring deep in the string).
int scoreMatch(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  final h = haystack.toLowerCase();
  final n = needle.toLowerCase();
  if (h == n) return 1000;
  if (h.startsWith(n)) return 800 - (h.length - n.length).clamp(0, 200);
  // Token-prefix: "new yo" matches "New York" via the "yo" → "York" token.
  for (final tok in h.split(RegExp(r'\s+'))) {
    if (tok.startsWith(n)) return 600;
  }
  final idx = h.indexOf(n);
  if (idx >= 0) return 400 - idx.clamp(0, 200);
  return 0;
}
