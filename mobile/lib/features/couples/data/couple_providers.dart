import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/providers.dart';
import 'package:mobile/features/couples/data/couple_models.dart';

/// The current user's active couple (or null). Re-fetches whenever the user
/// logs in or out — both flows toggle the auth user_id, which we watch here.
final myCoupleProvider = FutureProvider<Couple?>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).myCouple();
});

/// Combined visit/country/cuisine stats for the active couple. Returns
/// `active: false` whenever there's no accepted link — the dashboard card
/// uses that to hide itself.
final coupleStatsProvider = FutureProvider<CoupleStats>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).coupleStats();
});
