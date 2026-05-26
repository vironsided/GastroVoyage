import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/providers.dart';
import 'package:mobile/features/notifications/data/notification_model.dart';

// ─── Notifications Riverpod providers ────────────────────────────────────────
//
// Mirror the social providers — every read re-fetches when the signed-in user
// changes, so a logout / login swap never serves stale data from the previous
// account.

/// The signed-in user's notifications, newest-first. Server caps the page
/// size; we ask for 50 here, matching the inbox screen's window.
final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).notifications();
});

/// Count of the signed-in user's unread notifications. Used by the account
/// tile's pill badge and the inbox header subtitle.
final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authProvider.select((s) => s.userId));
  return ref.read(apiClientProvider).unreadCount();
});

/// Invalidates both notification providers — call after `markRead` or any
/// other inbox-mutating action so the list & badge re-fetch in one shot.
void invalidateNotificationsFromWidget(WidgetRef ref) {
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadCountProvider);
}
