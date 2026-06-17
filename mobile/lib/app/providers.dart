import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/shared/models.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────

class GastroThemeNotifier extends StateNotifier<GastroThemeMode?> {
  GastroThemeNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'gastro_theme';

  static GastroThemeMode? _load(SharedPreferences prefs) {
    final s = prefs.getString(_key);
    if (s == null) return null;
    return GastroThemeMode.values.firstWhere(
      (e) => e.name == s,
      orElse: () => GastroThemeMode.girls,
    );
  }

  Future<void> select(GastroThemeMode mode) async {
    await _prefs.setString(_key, mode.name);
    state = mode;
  }

  Future<void> reset() async {
    await _prefs.remove(_key);
    state = null;
  }
}

// This provider is overridden in main() with the real SharedPreferences instance
final gastroThemeProvider =
    StateNotifierProvider<GastroThemeNotifier, GastroThemeMode?>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final gastroThemeConfigProvider = Provider<GastroThemeConfig>((ref) {
  final mode = ref.watch(gastroThemeProvider) ?? GastroThemeMode.girls;
  return GastroThemeConfig.forMode(mode);
});

// ─── Auth ─────────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.userId,
    this.displayName,
    this.email,
    this.homeCity,
    this.accessToken,
    this.refreshToken,
    this.isEmailVerified = false,
    this.isLoggedIn = false,
  });

  final String? userId;
  final String? displayName;
  final String? email;
  final String? homeCity;
  final String? accessToken;
  final String? refreshToken;
  final bool isEmailVerified;
  final bool isLoggedIn;

  AuthState copyWith({
    String? userId,
    String? displayName,
    String? email,
    String? homeCity,
    String? accessToken,
    String? refreshToken,
    bool? isEmailVerified,
    bool? isLoggedIn,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      homeCity: homeCity ?? this.homeCity,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static AuthState _load(SharedPreferences prefs) {
    final userId = prefs.getString('auth_user_id');
    if (userId == null) return const AuthState();
    return AuthState(
      userId: userId,
      displayName: prefs.getString('auth_display_name'),
      email: prefs.getString('auth_email'),
      homeCity: prefs.getString('auth_home_city'),
      accessToken: prefs.getString('auth_access_token'),
      refreshToken: prefs.getString('auth_refresh_token'),
      isEmailVerified: prefs.getBool('auth_email_verified') ?? false,
      isLoggedIn: true,
    );
  }

  Future<void> setAuthenticated({
    required String userId,
    required String email,
    required String displayName,
    String? homeCity,
    String? accessToken,
    String? refreshToken,
    bool isEmailVerified = false,
  }) async {
    await _prefs.setString('auth_user_id', userId);
    await _prefs.setString('auth_display_name', displayName);
    await _prefs.setString('auth_email', email);
    if (homeCity != null) await _prefs.setString('auth_home_city', homeCity);
    if (accessToken != null) await _prefs.setString('auth_access_token', accessToken);
    if (refreshToken != null) await _prefs.setString('auth_refresh_token', refreshToken);
    await _prefs.setBool('auth_email_verified', isEmailVerified);
    state = AuthState(
      userId: userId,
      displayName: displayName,
      email: email,
      homeCity: homeCity,
      accessToken: accessToken,
      refreshToken: refreshToken,
      isEmailVerified: isEmailVerified,
      isLoggedIn: true,
    );
  }

  /// Persists a freshly-refreshed token pair. Called by the API client's
  /// interceptor after it transparently refreshes an expired access token.
  /// State updates synchronously so an in-flight request retry picks it up;
  /// the SharedPreferences writes are fire-and-forget.
  void updateTokens({required String accessToken, required String refreshToken}) {
    state = state.copyWith(accessToken: accessToken, refreshToken: refreshToken);
    _prefs.setString('auth_access_token', accessToken);
    _prefs.setString('auth_refresh_token', refreshToken);
  }

  Future<void> logout() async {
    await _prefs.remove('auth_user_id');
    await _prefs.remove('auth_display_name');
    await _prefs.remove('auth_email');
    await _prefs.remove('auth_home_city');
    await _prefs.remove('auth_access_token');
    await _prefs.remove('auth_refresh_token');
    await _prefs.remove('auth_email_verified');
    state = const AuthState();
  }

  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? homeCity,
  }) async {
    if (displayName != null) await _prefs.setString('auth_display_name', displayName);
    if (email != null) await _prefs.setString('auth_email', email);
    if (homeCity != null) await _prefs.setString('auth_home_city', homeCity);
    state = state.copyWith(
      displayName: displayName,
      email: email,
      homeCity: homeCity,
    );
  }
}

// Overridden in main() with the real SharedPreferences instance
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => throw UnimplementedError('overridden in main'),
);

// ─── API client ──────────────────────────────────────────────────────────────
//
// The token is read on every request via the closure below — there's no need
// to rebuild `ApiClient` when the auth state changes, the interceptor picks
// up the new token immediately. This keeps Dio's connection pool warm.

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    getToken: () => ref.read(authProvider).accessToken,
    getRefreshToken: () => ref.read(authProvider).refreshToken,
    onTokensRefreshed: (accessToken, refreshToken) {
      ref.read(authProvider.notifier).updateTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
    },
  );
});

// ─── Data providers ───────────────────────────────────────────────────────────
//
// All providers below assume the user is authenticated. `main.dart` gates
// these screens behind `auth.isLoggedIn`, so reaching them without a token
// is a programming bug — let the API return 401 in that case.

final profileProvider = FutureProvider<UserProfile>((ref) async {
  // Re-fetch whenever the user logs in/out
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).profile();
});

final visitsProvider = FutureProvider<List<Visit>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).visits();
});

final badgesProvider = FutureProvider<List<CuisineBadge>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).badges();
});

final mapCountriesProvider = FutureProvider<List<Country>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).mapCountries();
});

final exploreRegionProvider = StateProvider<String?>((ref) => null);

/// When true, Explore grid shows only countries the user has visited.
final exploreTriedOnlyProvider = StateProvider<bool>((ref) => false);

/// When true, Explore grid shows only countries on the wishlist. Mutually
/// exclusive with [exploreTriedOnlyProvider] at the UI level — the bookmark
/// tab strip toggles one off when the other is enabled.
final exploreWantToTryOnlyProvider = StateProvider<bool>((ref) => false);

final exploreCountriesProvider = FutureProvider<List<Country>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  final region = ref.watch(exploreRegionProvider);
  return ref.read(apiClientProvider).countries(region: region);
});

final countrySearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Wishlist ("Want to try") ─────────────────────────────────────────────────
//
// The newest-first wishlist for the current user, joined with the country
// catalog. Re-fetches whenever the user logs in/out. Invalidate after any
// add/remove call so the per-card pin state and the dashboard's "Next bite
// to chase" card both pick up the fresh list.

final wishlistProvider = FutureProvider<List<Country>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).wishlist();
});

/// Fast-lookup set of country ids on the wishlist — derived from
/// [wishlistProvider]. The per-card pin uses this to decide between the
/// filled / outline icon without rebuilding the whole list.
final wishlistIdsProvider = Provider<Set<String>>((ref) {
  final async = ref.watch(wishlistProvider);
  return async.maybeWhen(
    data: (countries) => {for (final c in countries) c.id},
    orElse: () => const <String>{},
  );
});

// ─── Bottom-nav tab switch ───────────────────────────────────────────────────
//
// A 0..3 index matching `_ShellScreen._pages`. The shell watches this and
// updates its `_index` so screens nested deep in the dashboard can request a
// jump to Explore / Map / Vault without dragging a callback through every
// constructor.

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// Indices matching the order of `_ShellScreen._pages` in `app_router.dart`.
/// Kept here so callers don't have to import the private shell screen.
class AppTab {
  AppTab._();
  static const int dashboard = 0;
  static const int map = 1;
  static const int explore = 2;
  static const int vault = 3;
}

/// World (0) vs Baku (1) mode for the Map tab. Lifted out of `MapScreen`'s
/// local state so the dashboard's "Discover Baku" card can deep-link straight
/// into the Baku food map (set this to 1, then jump to `AppTab.map`). The Map
/// tab's segmented toggle also writes here, so the chosen mode persists across
/// tab switches.
final mapModeProvider = StateProvider<int>((ref) => 0);

// ─── Couples' Culinary Journey ─────────────────────────────────────────────────
//
// How many weeks of the curated couples' journey the user has completed.
// Re-fetches whenever the user logs in/out. Invalidate after marking a week
// complete to pull the fresh count.

final couplesProgressProvider = FutureProvider<int>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).getCouplesProgress();
});
