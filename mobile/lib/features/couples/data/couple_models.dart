/// Wire models for the partner-linking endpoints under `/couples` (backend
/// migration 014). One row per couple. Status flows:
///   pending  → accepted    (invitee accepted)
///   pending  → ended       (declined OR partner withdrew)
///   accepted → ended       (either partner unlinked)
enum CoupleStatus { pending, accepted, ended }

CoupleStatus _statusFromWire(String? s) {
  switch (s) {
    case 'pending':
      return CoupleStatus.pending;
    case 'accepted':
      return CoupleStatus.accepted;
    case 'ended':
      return CoupleStatus.ended;
    default:
      return CoupleStatus.ended;
  }
}

class CouplePartner {
  const CouplePartner({
    required this.userId,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;

  String get name {
    final n = displayName?.trim();
    return (n == null || n.isEmpty) ? 'Your partner' : n;
  }

  String get initial => name[0].toUpperCase();

  factory CouplePartner.fromJson(Map<String, dynamic> j) => CouplePartner(
        userId: j['user_id'] as String? ?? '',
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );
}

class Couple {
  const Couple({
    required this.id,
    required this.partnerAId,
    required this.partnerBId,
    required this.status,
    required this.viewerRole,
    required this.partner,
    this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String partnerAId;
  final String partnerBId;
  final CoupleStatus status;

  /// 'a' = current viewer is the inviter, 'b' = the invitee.
  final String viewerRole;

  /// The *other* user in the couple, populated by the backend.
  final CouplePartner partner;

  final String? createdAt;
  final String? acceptedAt;

  /// True when there's a pending invite waiting for the current viewer's
  /// response (i.e. viewer is partner_b and status is pending).
  bool get isIncomingPendingForViewer =>
      status == CoupleStatus.pending && viewerRole == 'b';

  /// True when the viewer sent a pending invite that's awaiting the other
  /// person's response.
  bool get isOutgoingPendingForViewer =>
      status == CoupleStatus.pending && viewerRole == 'a';

  factory Couple.fromJson(Map<String, dynamic> j) => Couple(
        id: j['id'] as String? ?? '',
        partnerAId: j['partner_a_id'] as String? ?? '',
        partnerBId: j['partner_b_id'] as String? ?? '',
        status: _statusFromWire(j['status'] as String?),
        viewerRole: j['viewer_role'] as String? ?? 'a',
        partner: CouplePartner.fromJson(
            (j['partner'] as Map<String, dynamic>?) ?? const {}),
        createdAt: j['created_at'] as String?,
        acceptedAt: j['accepted_at'] as String?,
      );
}

class CoupleFirstVisit {
  const CoupleFirstVisit({
    this.visitId,
    this.restaurantName,
    this.countryId,
    this.countryName,
    this.flagEmoji,
    this.createdAt,
  });

  final String? visitId;
  final String? restaurantName;
  final String? countryId;
  final String? countryName;
  final String? flagEmoji;
  final String? createdAt;

  factory CoupleFirstVisit.fromJson(Map<String, dynamic> j) =>
      CoupleFirstVisit(
        visitId: j['visit_id'] as String?,
        restaurantName: j['restaurant_name'] as String?,
        countryId: j['country_id'] as String?,
        countryName: j['country_name'] as String?,
        flagEmoji: j['flag_emoji'] as String?,
        createdAt: j['created_at'] as String?,
      );
}

class CoupleStats {
  const CoupleStats({
    required this.active,
    required this.jointVisits,
    required this.jointCountries,
    required this.jointCuisines,
    required this.daysTogether,
    required this.firstVisit,
    required this.since,
    required this.partner,
  });

  final bool active;
  final int jointVisits;
  final int jointCountries;
  final int jointCuisines;

  /// Whole days elapsed since `accepted_at`. Always >= 0.
  final int daysTogether;

  /// The oldest joint visit (with_partner=true) on either partner's account,
  /// rendered as a "First plate together" memory card on MyCoupleScreen.
  /// Null until the couple actually logs their first joint visit.
  final CoupleFirstVisit? firstVisit;

  final String? since;
  final CouplePartner? partner;

  factory CoupleStats.fromJson(Map<String, dynamic> j) => CoupleStats(
        active: j['active'] as bool? ?? false,
        jointVisits: (j['joint_visits'] as num?)?.toInt() ?? 0,
        jointCountries: (j['joint_countries'] as num?)?.toInt() ?? 0,
        jointCuisines: (j['joint_cuisines'] as num?)?.toInt() ?? 0,
        daysTogether: (j['days_together'] as num?)?.toInt() ?? 0,
        firstVisit: j['first_visit'] is Map<String, dynamic>
            ? CoupleFirstVisit.fromJson(j['first_visit'] as Map<String, dynamic>)
            : null,
        since: j['since'] as String?,
        partner: j['partner'] is Map<String, dynamic>
            ? CouplePartner.fromJson(j['partner'] as Map<String, dynamic>)
            : null,
      );
}

/// Result of `/couples/date-night` — a single random country pick for the
/// couple's next joint meal, drawn from their combined wishlists (preferred)
/// or anywhere they haven't tasted together yet (fallback).
class DateNightPick {
  const DateNightPick({
    required this.countryId,
    required this.countryName,
    this.flagEmoji,
    this.cuisine,
    required this.source,
  });

  final String countryId;
  final String countryName;
  final String? flagEmoji;
  final String? cuisine;

  /// 'wishlist' = drawn from either partner's wishlist.
  /// 'anywhere' = nothing wishlisted, picked from all-untasted-jointly.
  final String source;

  bool get fromWishlist => source == 'wishlist';

  static DateNightPick? fromResponse(Map<String, dynamic>? j) {
    if (j == null) return null;
    final s = j['suggestion'];
    if (s is! Map<String, dynamic>) return null;
    final id = s['country_id'] as String?;
    final name = s['country_name'] as String?;
    if (id == null || name == null) return null;
    return DateNightPick(
      countryId: id,
      countryName: name,
      flagEmoji: s['flag_emoji'] as String?,
      cuisine: s['cuisine'] as String?,
      source: (s['source'] as String?) ?? 'anywhere',
    );
  }
}
