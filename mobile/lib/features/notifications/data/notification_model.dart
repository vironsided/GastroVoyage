// ─── Notification wire types ────────────────────────────────────────────────
//
// One row per delivered alert in the user's inbox. Mirrors the backend
// `notifications` table from migration 007. Models are null-safe — every
// field defends against a missing or mistyped server payload.

/// The kind of event a notification represents. The wire string mirrors the
/// CHECK constraint in migration 007; [unknown] is the safe fall-through for
/// any future / unrecognised type so the UI never crashes on a new server.
enum NotificationType {
  followRequest,
  followAccepted,
  storyView,
  storyReaction,
  storyComment,
  journeyWeek,
  badgeEarned,
  unknown,
}

extension NotificationTypeX on NotificationType {
  /// Wire value sent to / received from the backend.
  String get wire {
    switch (this) {
      case NotificationType.followRequest:
        return 'follow_request';
      case NotificationType.followAccepted:
        return 'follow_accepted';
      case NotificationType.storyView:
        return 'story_view';
      case NotificationType.storyReaction:
        return 'story_reaction';
      case NotificationType.storyComment:
        return 'story_comment';
      case NotificationType.journeyWeek:
        return 'journey_week';
      case NotificationType.badgeEarned:
        return 'badge_earned';
      case NotificationType.unknown:
        return 'unknown';
    }
  }

  /// Parses a backend string; falls back to [NotificationType.unknown] so the
  /// UI can render a sensible row even when the server adds a new type the
  /// client doesn't yet know about.
  static NotificationType fromWire(String? value) {
    switch (value) {
      case 'follow_request':
        return NotificationType.followRequest;
      case 'follow_accepted':
        return NotificationType.followAccepted;
      case 'story_view':
        return NotificationType.storyView;
      case 'story_reaction':
        return NotificationType.storyReaction;
      case 'story_comment':
        return NotificationType.storyComment;
      case 'journey_week':
        return NotificationType.journeyWeek;
      case 'badge_earned':
        return NotificationType.badgeEarned;
      default:
        return NotificationType.unknown;
    }
  }
}

/// The user who triggered the notification (follower, viewer, etc.).
/// Null on system-emitted events (journey milestones, badge unlocks).
class NotificationActor {
  const NotificationActor({
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  /// Display name guaranteed non-empty for UI use.
  String get name {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Someone' : n;
  }

  /// Single uppercase initial for avatar fallback. Always safe to read.
  String get initial => name[0].toUpperCase();

  factory NotificationActor.fromJson(Map<String, dynamic> j) =>
      NotificationActor(
        userId: (j['user_id'] as String?) ?? '',
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );
}

/// A single notification row in the user's inbox.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.read,
    required this.createdAt,
    this.actor,
  });

  final String id;
  final NotificationType type;
  final NotificationActor? actor;

  /// Type-specific event payload. The shape varies per [type]:
  ///   story_view   → {story_id}
  ///   journey_week → {week_index}
  ///   badge_earned → {badge_id, badge_title?}
  /// Empty for follow_request / follow_accepted.
  final Map<String, dynamic> payload;

  final bool read;

  /// ISO-8601 timestamp string. Pass to `relativeTime()` for the time-ago label.
  final String? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> payload = const {};
    final raw = j['payload'];
    if (raw is Map<String, dynamic>) {
      payload = raw;
    } else if (raw is Map) {
      // The Dio JSON decoder produces Map<String, dynamic>, but be defensive
      // against any future intermediate (e.g. a custom decoder) so we never
      // throw on a perfectly valid payload.
      payload = raw.map((k, v) => MapEntry(k.toString(), v));
    }

    NotificationActor? actor;
    final actorRaw = j['actor'];
    if (actorRaw is Map<String, dynamic>) {
      actor = NotificationActor.fromJson(actorRaw);
    }

    return AppNotification(
      id: (j['id'] as String?) ?? '',
      type: NotificationTypeX.fromWire(j['type'] as String?),
      actor: actor,
      payload: payload,
      read: (j['read'] as bool?) ?? false,
      createdAt: j['created_at'] as String?,
    );
  }
}
