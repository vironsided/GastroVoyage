import 'package:mobile/features/shared/models.dart';

// ─── Passport visibility ──────────────────────────────────────────────────────

/// Who is allowed to view a user's culinary passport.
///   public    — anyone
///   followers — only accepted followers
///   private   — nobody but the owner
enum PassportVisibility { public, followers, private }

extension PassportVisibilityX on PassportVisibility {
  /// Wire value sent to / received from the backend.
  String get wire {
    switch (this) {
      case PassportVisibility.public:
        return 'public';
      case PassportVisibility.followers:
        return 'followers';
      case PassportVisibility.private:
        return 'private';
    }
  }

  /// Short, human-facing label for chips / tiles.
  String get label {
    switch (this) {
      case PassportVisibility.public:
        return 'Public';
      case PassportVisibility.followers:
        return 'Followers';
      case PassportVisibility.private:
        return 'Private';
    }
  }

  /// One-line description shown beneath the control.
  String get description {
    switch (this) {
      case PassportVisibility.public:
        return 'Anyone can browse your passport';
      case PassportVisibility.followers:
        return 'Only people you\'ve accepted can see it';
      case PassportVisibility.private:
        return 'Your passport stays for your eyes only';
    }
  }

  /// Parses a backend string; falls back to [PassportVisibility.private]
  /// (the safest default) for unknown / null input.
  static PassportVisibility fromWire(String? value) {
    switch (value) {
      case 'public':
        return PassportVisibility.public;
      case 'followers':
        return PassportVisibility.followers;
      case 'private':
        return PassportVisibility.private;
      default:
        return PassportVisibility.private;
    }
  }
}

// ─── Follow status ────────────────────────────────────────────────────────────

/// Relationship state between the current user and another user.
///   none     — no follow edge
///   pending  — request sent / received, awaiting acceptance
///   accepted — an active follow
enum FollowStatus { none, pending, accepted }

extension FollowStatusX on FollowStatus {
  String get wire {
    switch (this) {
      case FollowStatus.none:
        return 'none';
      case FollowStatus.pending:
        return 'pending';
      case FollowStatus.accepted:
        return 'accepted';
    }
  }

  static FollowStatus fromWire(String? value) {
    switch (value) {
      case 'pending':
        return FollowStatus.pending;
      case 'accepted':
        return FollowStatus.accepted;
      case 'none':
      default:
        return FollowStatus.none;
    }
  }
}

// ─── Social user ──────────────────────────────────────────────────────────────

/// A person in the follow graph or in a search result.
///
/// Backend returns this shape from `/social/following`, `/social/followers`
/// (with a `status` field) and from `/social/users/search` (with a
/// `follow_status` field). Both map onto [followStatus].
class SocialUser {
  const SocialUser({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.followStatus = FollowStatus.none,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  /// For follow/followers lists this is the edge `status`; for search results
  /// it is the `follow_status` of the current user toward this person.
  final FollowStatus followStatus;

  /// Display name guaranteed non-empty for UI use.
  String get name {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Explorer' : n;
  }

  /// Single uppercase initial for the avatar fallback.
  String get initial => name[0].toUpperCase();

  SocialUser copyWith({FollowStatus? followStatus}) => SocialUser(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        followStatus: followStatus ?? this.followStatus,
      );

  factory SocialUser.fromJson(Map<String, dynamic> j) => SocialUser(
        userId: j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        // `/following` & `/followers` use `status`; search uses `follow_status`.
        followStatus: FollowStatusX.fromWire(
          (j['follow_status'] ?? j['status']) as String?,
        ),
      );
}

// ─── Public passport ──────────────────────────────────────────────────────────

/// Another user's passport as returned by `/social/passport/{user_id}`.
/// Reuses the shared [Country] type; carries a lightweight local visit type
/// since the social endpoint omits `user_id` on each visit.
class PublicPassport {
  const PublicPassport({
    required this.userId,
    required this.displayName,
    required this.passportVisibility,
    required this.visitedCount,
    required this.badgeCount,
    required this.countries,
    required this.visits,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final PassportVisibility passportVisibility;
  final int visitedCount;
  final int badgeCount;
  final List<Country> countries;
  final List<PassportVisit> visits;

  String get name {
    final n = displayName.trim();
    return n.isEmpty ? 'Explorer' : n;
  }

  String get initial => name[0].toUpperCase();

  factory PublicPassport.fromJson(Map<String, dynamic> j) => PublicPassport(
        userId: j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? 'Explorer',
        avatarUrl: j['avatar_url'] as String?,
        passportVisibility:
            PassportVisibilityX.fromWire(j['passport_visibility'] as String?),
        visitedCount: (j['visited_count'] as num?)?.toInt() ?? 0,
        badgeCount: (j['badge_count'] as num?)?.toInt() ?? 0,
        countries: ((j['countries'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Country.fromJson)
            .toList(),
        visits: ((j['visits'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PassportVisit.fromJson)
            .toList(),
      );
}

/// A single visit entry on someone else's public passport. Lighter than the
/// owner-facing [Visit]: the social endpoint already denormalises the country
/// name and omits the owner id.
class PassportVisit {
  const PassportVisit({
    required this.id,
    required this.countryId,
    required this.rating,
    required this.notes,
    required this.visitedOn,
    this.countryName,
    this.photoPath,
    this.restaurantName,
  });

  final String id;
  final String countryId;
  final int rating;
  final String notes;
  final String visitedOn;
  final String? countryName;
  final String? photoPath;
  final String? restaurantName;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  factory PassportVisit.fromJson(Map<String, dynamic> j) => PassportVisit(
        id: j['id'] as String? ?? '',
        countryId: j['country_id'] as String? ?? '',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        notes: j['notes'] as String? ?? '',
        visitedOn: j['visited_on'] as String? ?? '',
        countryName: j['country_name'] as String?,
        photoPath: j['photo_path'] as String?,
        restaurantName: j['restaurant_name'] as String?,
      );
}

// ─── Story ────────────────────────────────────────────────────────────────────

/// A culinary story (transient post) in the social feed. Round 1 only needs
/// the model + API plumbing; the feed UI is built by a later agent.
class Story {
  const Story({
    required this.id,
    required this.userId,
    required this.photoUrl,
    this.displayName,
    this.avatarUrl,
    this.caption,
    this.countryId,
    this.countryName,
    this.createdAt,
    this.viewCount = 0,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.myReaction,
  });

  final String id;
  final String userId;
  final String photoUrl;
  final String? displayName;
  final String? avatarUrl;
  final String? caption;
  final String? countryId;
  final String? countryName;
  final String? createdAt;

  /// How many distinct people have viewed this story. Only populated by the
  /// backend for stories the current user owns; for others' stories it is 0
  /// (the mobile UI only renders the "Seen by N" badge on the owner's stories).
  final int viewCount;

  /// How many distinct people have reacted to this story. Like [viewCount],
  /// only populated by the backend for stories the current user owns.
  final int reactionCount;

  /// How many comments the story has — visible to everyone (comments are open
  /// to all viewers). The "💬 N" pill is rendered on every story regardless of
  /// ownership; tapping it opens the comments sheet.
  final int commentCount;

  /// The current user's own reaction emoji on this story, or `null` when the
  /// viewer hasn't reacted (or this is the owner's own story). Powers the
  /// "highlight the chosen emoji" state in the reaction palette.
  final String? myReaction;

  String get authorName {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Explorer' : n;
  }

  /// Returns a copy with the reaction fields overridden — used by the story
  /// viewer to keep the palette and pill in sync without a full feed refetch
  /// after the user taps an emoji.
  Story copyWithReaction({
    String? myReaction = _kSentinelNone,
    int? reactionCount,
  }) {
    return Story(
      id: id,
      userId: userId,
      photoUrl: photoUrl,
      displayName: displayName,
      avatarUrl: avatarUrl,
      caption: caption,
      countryId: countryId,
      countryName: countryName,
      createdAt: createdAt,
      viewCount: viewCount,
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount,
      myReaction: identical(myReaction, _kSentinelNone)
          ? this.myReaction
          : myReaction,
    );
  }

  /// Returns a copy with the [commentCount] overridden — used by the story
  /// viewer to bump the "💬 N" pill instantly when a viewer posts a new
  /// comment, without waiting for a feed refetch.
  Story copyWithCommentCount(int newCount) {
    return Story(
      id: id,
      userId: userId,
      photoUrl: photoUrl,
      displayName: displayName,
      avatarUrl: avatarUrl,
      caption: caption,
      countryId: countryId,
      countryName: countryName,
      createdAt: createdAt,
      viewCount: viewCount,
      reactionCount: reactionCount,
      commentCount: newCount < 0 ? 0 : newCount,
      myReaction: myReaction,
    );
  }

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        photoUrl: j['photo_url'] as String? ?? '',
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        caption: j['caption'] as String?,
        countryId: j['country_id'] as String?,
        countryName: j['country_name'] as String?,
        createdAt: j['created_at'] as String?,
        viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
        reactionCount: (j['reaction_count'] as num?)?.toInt() ?? 0,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        myReaction: (j['my_reaction'] as String?)?.trim().isEmpty == true
            ? null
            : j['my_reaction'] as String?,
      );
}

// Sentinel used by `Story.copyWithReaction` so callers can distinguish
// "leave myReaction unchanged" from "set it to null" without exposing an
// internal flag in the public signature.
const String _kSentinelNone = '__story_reaction_sentinel__';

// ─── Story viewer entry ──────────────────────────────────────────────────────

/// A single row in the "Seen by" list for one of the current user's stories.
/// Returned by `/social/stories/{id}/viewers`, owner-only.
class StoryViewerEntry {
  const StoryViewerEntry({
    required this.userId,
    required this.viewedAt,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  /// ISO-8601 timestamp of when this viewer first saw the story.
  final String viewedAt;

  /// Display name guaranteed non-empty for UI use.
  String get name {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Explorer' : n;
  }

  String get initial => name[0].toUpperCase();

  factory StoryViewerEntry.fromJson(Map<String, dynamic> j) => StoryViewerEntry(
        userId: j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        viewedAt: j['viewed_at'] as String? ?? '',
      );
}

// ─── Story reaction ──────────────────────────────────────────────────────────

/// A single emoji reaction on a story. Returned by
/// `/social/stories/{id}/reactions`, owner-only.
///
/// Mirrors `StoryViewerEntry` in shape: the actor is denormalised onto the
/// row so the sheet can render an avatar + name without a second profile
/// lookup.
class StoryReaction {
  const StoryReaction({
    required this.actorUserId,
    required this.emoji,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
  });

  final String actorUserId;
  final String? displayName;
  final String? avatarUrl;

  /// The emoji glyph the actor reacted with. The backend stores any single
  /// grapheme; the mobile palette offers a curated food-themed set.
  final String emoji;

  /// ISO-8601 timestamp of when the reaction was first posted (or last
  /// updated — the backend overwrites on emoji change).
  final String createdAt;

  /// Display name guaranteed non-empty for UI use.
  String get name {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Explorer' : n;
  }

  String get initial => name[0].toUpperCase();

  factory StoryReaction.fromJson(Map<String, dynamic> j) {
    final actor = (j['actor'] as Map<String, dynamic>?) ?? const {};
    return StoryReaction(
      actorUserId: actor['user_id'] as String? ?? '',
      displayName: actor['display_name'] as String?,
      avatarUrl: actor['avatar_url'] as String?,
      emoji: j['emoji'] as String? ?? '',
      createdAt: j['created_at'] as String? ?? '',
    );
  }
}

// ─── Story comment ───────────────────────────────────────────────────────────

/// A single handwritten comment on a story. Returned by
/// `/social/stories/{id}/comments` and `POST .../comment`.
///
/// Shape mirrors [StoryReaction]: the actor profile is denormalised onto each
/// row so the sheet can render the avatar + name without a second lookup.
class StoryComment {
  const StoryComment({
    required this.id,
    required this.actorUserId,
    required this.text,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
  });

  /// Server-assigned UUID — also the URL segment for `DELETE /social/stories/
  /// comments/{id}`.
  final String id;

  final String actorUserId;
  final String? displayName;
  final String? avatarUrl;

  /// The comment text. Backend bounds it to 1..280 chars.
  final String text;

  /// ISO-8601 timestamp of the original post. Comments aren't editable, so
  /// this is the only timestamp the row carries.
  final String createdAt;

  /// Display name guaranteed non-empty for UI use.
  String get name {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Explorer' : n;
  }

  String get initial => name[0].toUpperCase();

  factory StoryComment.fromJson(Map<String, dynamic> j) {
    final actor = (j['actor'] as Map<String, dynamic>?) ?? const {};
    return StoryComment(
      id: j['id'] as String? ?? '',
      actorUserId: actor['user_id'] as String? ?? '',
      displayName: actor['display_name'] as String?,
      avatarUrl: actor['avatar_url'] as String?,
      text: j['text'] as String? ?? '',
      createdAt: j['created_at'] as String? ?? '',
    );
  }
}

// ─── Passport access exceptions ──────────────────────────────────────────────

/// Thrown by `viewPassport` when the backend returns 403 — the target user's
/// privacy setting blocks the current viewer.
class PassportPrivateException implements Exception {
  const PassportPrivateException(
      [this.message = 'This passport is private']);
  final String message;
  @override
  String toString() => 'PassportPrivateException: $message';
}

/// Thrown by `viewPassport` when the backend returns 404 — no such user.
class PassportNotFoundException implements Exception {
  const PassportNotFoundException(
      [this.message = 'This traveller could not be found']);
  final String message;
  @override
  String toString() => 'PassportNotFoundException: $message';
}
