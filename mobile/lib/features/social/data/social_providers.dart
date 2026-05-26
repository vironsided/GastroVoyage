import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/providers.dart';
import 'package:mobile/features/social/data/social_models.dart';

// ─── Social Riverpod providers ────────────────────────────────────────────────
//
// All providers below assume an authenticated user — every screen that reads
// them lives behind the `auth.isLoggedIn` gate in `main.dart`. Each re-fetches
// whenever the signed-in user changes, mirroring the existing data providers
// in `app/providers.dart`.

/// People the current user follows (outgoing edges, `accepted` or `pending`).
final followingProvider = FutureProvider<List<SocialUser>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).following();
});

/// People who follow the current user. The list mixes accepted followers and
/// still-pending incoming requests — UI splits them on `followStatus`.
final followersProvider = FutureProvider<List<SocialUser>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).followers();
});

/// The current user's social feed (stories from followed users).
final feedProvider = FutureProvider<List<Story>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).socialFeed();
});

/// The current user's passport-visibility setting. Mutations go through
/// `ApiClient.setPrivacy` followed by `ref.invalidate(privacyProvider)`.
final privacyProvider = FutureProvider<PassportVisibility>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).getPrivacy();
});

/// Current user-search term for the Friends screen. Empty string ⇒ no search.
final userSearchQueryProvider = StateProvider<String>((ref) => '');

/// Results for [userSearchQueryProvider]. An empty term resolves to `[]`
/// without a network call (see `ApiClient.searchUsers`).
final userSearchProvider = FutureProvider<List<SocialUser>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  final query = ref.watch(userSearchQueryProvider);
  if (query.trim().isEmpty) return const [];
  return ref.read(apiClientProvider).searchUsers(query);
});

/// Another user's public passport, keyed by their user id. Auto-disposed when
/// the passport screen is popped.
final publicPassportProvider =
    FutureProvider.family<PublicPassport, String>((ref, userId) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).viewPassport(userId);
});

/// Viewers of one of the current user's stories (owner-only on the backend).
/// Keyed by story id; auto-disposed when the "Seen by" bottom sheet is closed.
final storyViewersProvider =
    FutureProvider.family<List<StoryViewerEntry>, String>(
  (ref, storyId) async {
    ref.watch(authProvider.select((s) => s.userId));
    return ref.read(apiClientProvider).storyViewers(storyId);
  },
);

/// Reactions on one of the current user's stories (owner-only on the backend).
/// Keyed by story id; auto-disposed when the reactions tab of the viewers
/// sheet is closed.
final storyReactionsProvider =
    FutureProvider.family<List<StoryReaction>, String>(
  (ref, storyId) async {
    ref.watch(authProvider.select((s) => s.userId));
    return ref.read(apiClientProvider).storyReactions(storyId);
  },
);

/// Comments on a story, oldest-first. Open to any authenticated viewer (the
/// backend's RLS policy is world-read for the thread). Keyed by story id;
/// auto-disposed when the comments sheet is closed.
final storyCommentsProvider =
    FutureProvider.family<List<StoryComment>, String>(
  (ref, storyId) async {
    ref.watch(authProvider.select((s) => s.userId));
    return ref.read(apiClientProvider).storyComments(storyId);
  },
);

/// Invalidates every social provider — call after follow/unfollow/accept/
/// decline so the follow graph and feed re-fetch in one shot.
void invalidateSocial(Ref ref) {
  ref.invalidate(followingProvider);
  ref.invalidate(followersProvider);
  ref.invalidate(feedProvider);
  ref.invalidate(userSearchProvider);
}

/// `WidgetRef` overload of [invalidateSocial] for use from widgets.
void invalidateSocialFromWidget(WidgetRef ref) {
  ref.invalidate(followingProvider);
  ref.invalidate(followersProvider);
  ref.invalidate(feedProvider);
  ref.invalidate(userSearchProvider);
}
