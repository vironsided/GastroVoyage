import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/providers.dart';
import 'package:mobile/features/ai/data/ai_models.dart';

/// Cuisine recommendations — call sites typically render this on the
/// dashboard. Re-fetches whenever the auth user_id changes (login/logout).
final cuisineRecommendationsProvider =
    FutureProvider.autoDispose<AiCuisineRecommendations>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).aiCuisineRecommendations();
});

/// Couple Wrapped — generated on-demand (no auto-refresh). The screen
/// invalidates this provider to force a re-roll when the user taps "Try
/// another wrapped".
final coupleWrappedProvider =
    FutureProvider.autoDispose<CoupleWrapped>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).coupleWrapped();
});

/// Date Night AI — autodispose so each visit to the screen pays for a
/// fresh roll. Consumer can invalidate to "try another".
final aiDateNightProvider =
    FutureProvider.autoDispose<AiDateNight>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).aiDateNight();
});
