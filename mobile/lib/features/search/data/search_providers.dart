import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/providers.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/search/data/search_results.dart';

/// The active query string, written by the search screen's TextField as the
/// user types. Lives outside the widget so the result providers can react.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Per-cuisine entry derived from [kBakuRestaurants]: a label, the flag of
/// the first restaurant in that cuisine (close enough for an at-a-glance hint),
/// and the count of Baku restaurants we know about for that cuisine.
class _CuisineEntry {
  const _CuisineEntry(this.label, this.flag, this.count);
  final String label;
  final String flag;
  final int count;
}

/// Distinct cuisines from the Baku restaurant catalog. Computed once at
/// app start (provider-scoped singleton).
final cuisineCatalogProvider = Provider<List<_CuisineEntry>>((ref) {
  final byName = <String, _CuisineEntry>{};
  for (final r in kBakuRestaurants) {
    final existing = byName[r.cuisine];
    byName[r.cuisine] = _CuisineEntry(
      r.cuisine,
      existing?.flag ?? r.flag,
      (existing?.count ?? 0) + 1,
    );
  }
  return byName.values.toList()
    ..sort((a, b) => a.label.compareTo(b.label));
});

/// Local search across countries (from the explore cache), cuisines, and
/// Baku restaurants. Returns hits already ranked by [scoreMatch] and merged
/// across kinds. Country results that the user has already visited rank a
/// little higher so they feel re-discoverable.
final localHitsProvider = Provider<List<SearchHit>>((ref) {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return const [];

  final hits = <SearchHit>[];

  // Countries — uses the same cached list the Explore screen renders.
  final exploreAsync = ref.watch(exploreCountriesProvider);
  for (final c in exploreAsync.asData?.value ?? const []) {
    final s = scoreMatch(c.name, q);
    if (s > 0) {
      hits.add(CountryHit(
        country: c,
        score: s + (c.visited ? 25 : 0),
      ));
    }
  }

  // Cuisines.
  for (final e in ref.watch(cuisineCatalogProvider)) {
    final s = scoreMatch(e.label, q);
    if (s > 0) {
      hits.add(CuisineHit(
        cuisine: e.label,
        flag: e.flag,
        restaurantCount: e.count,
        score: s,
      ));
    }
  }

  // Restaurants — search across name, cuisine, neighborhood (so "old city"
  // surfaces Sultan Inn etc.).
  for (final r in kBakuRestaurants) {
    final nameScore = scoreMatch(r.name, q);
    final cuisineScore = scoreMatch(r.cuisine, q);
    final hoodScore = scoreMatch(r.neighborhood, q);
    final best = [nameScore, cuisineScore, hoodScore].reduce((a, b) => a > b ? a : b);
    if (best > 0) {
      hits.add(RestaurantHit(restaurant: r, score: best));
    }
  }

  hits.sort((a, b) => b.score.compareTo(a.score));
  return hits;
});

/// Friend search — hits the network through ApiClient.searchUsers. The query
/// is debounced inside the screen widget, not here, so this provider just
/// reads whatever the StateProvider currently holds.
final friendHitsProvider = FutureProvider<List<SearchHit>>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.length < 2) return const [];
  final users = await ref.read(apiClientProvider).searchUsers(q);
  return [
    for (final u in users)
      FriendHit(user: u, score: scoreMatch(u.name, q).clamp(50, 1000)),
  ];
});
