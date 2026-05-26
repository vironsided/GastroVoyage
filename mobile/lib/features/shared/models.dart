import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class Country {
  const Country({
    required this.id,
    required this.isoA2,
    required this.name,
    required this.flagEmoji,
    required this.region,
    required this.subregion,
    required this.centroidLat,
    required this.centroidLng,
    this.visited = false,
    this.photoUrl,
  });

  final String id;
  final String isoA2;
  final String name;
  final String flagEmoji;
  final String region;
  final String subregion;
  final double centroidLat;
  final double centroidLng;
  final bool visited;
  final String? photoUrl;

  factory Country.fromJson(Map<String, dynamic> j) => Country(
        id: j['id'] as String? ?? '',
        isoA2: j['iso_a2'] as String? ?? '',
        name: j['name'] as String? ?? '',
        flagEmoji: j['flag_emoji'] as String? ?? '🌍',
        region: j['region'] as String? ?? '',
        subregion: j['subregion'] as String? ?? '',
        centroidLat: (j['centroid_lat'] as num?)?.toDouble() ?? 0,
        centroidLng: (j['centroid_lng'] as num?)?.toDouble() ?? 0,
        visited: j['visited'] as bool? ?? false,
        photoUrl: j['photo_url'] as String?,
      );
}

class Visit {
  const Visit({
    required this.id,
    required this.userId,
    required this.countryId,
    required this.rating,
    required this.notes,
    required this.visitedOn,
    this.country,
    this.photoPath,
    this.restaurantName,
    this.atmosphereRating,
    this.serviceRating,
    this.valueRating,
    this.dishRating,
  });

  final String id;
  final String userId;
  final String countryId;
  final int rating;
  final String notes;
  final String visitedOn;
  final Country? country;
  final String? photoPath;

  /// Name of the specific Baku restaurant this visit was logged at, if the
  /// user picked one in the Explore flow. Null for visits without a restaurant.
  final String? restaurantName;

  /// Four optional micro-ratings (1–5). All null on legacy visits and on
  /// quick-logs that skipped the detail form. Treat null as "not rated".
  final int? atmosphereRating;
  final int? serviceRating;
  final int? valueRating;
  final int? dishRating;

  /// True when at least one sub-rating is filled in — the UI uses this to
  /// decide whether to show the four-pip strip on cards.
  bool get hasSubRatings =>
      atmosphereRating != null ||
      serviceRating != null ||
      valueRating != null ||
      dishRating != null;

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        countryId: j['country_id'] as String? ?? '',
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        notes: j['notes'] as String? ?? '',
        visitedOn: j['visited_on'] as String? ?? '',
        photoPath: j['photo_path'] as String?,
        restaurantName: j['restaurant_name'] as String?,
        atmosphereRating: (j['atmosphere_rating'] as num?)?.toInt(),
        serviceRating: (j['service_rating'] as num?)?.toInt(),
        valueRating: (j['value_rating'] as num?)?.toInt(),
        dishRating: (j['dish_rating'] as num?)?.toInt(),
        country: j['countries'] != null
            ? Country.fromJson(j['countries'] as Map<String, dynamic>)
            : null,
      );
}

class CuisineBadge {
  const CuisineBadge({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    this.region,
    this.threshold,
    this.earned = false,
    this.earnedAt,
  });

  final String code;
  final String title;
  final String description;
  final String icon;
  final String? region;
  final int? threshold;
  final bool earned;
  final String? earnedAt;

  factory CuisineBadge.fromJson(Map<String, dynamic> j) => CuisineBadge(
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        icon: j['icon'] as String? ?? 'sparkles',
        region: j['region'] as String?,
        threshold: (j['threshold'] as num?)?.toInt(),
        earned: j['earned'] as bool? ?? false,
        earnedAt: j['earned_at'] as String?,
      );

  IconData get iconData {
    switch (icon) {
      case 'sparkles': return LucideIcons.star;
      case 'lantern':  return LucideIcons.lamp;
      case 'castle':   return LucideIcons.landmark;
      case 'baobab':   return LucideIcons.leaf;
      case 'compass':  return LucideIcons.compass;
      case 'wave':     return LucideIcons.activity;
      case 'olive':    return LucideIcons.leaf;
      case 'globe':    return LucideIcons.globe;
      case 'crown':    return LucideIcons.crown;
      default:         return LucideIcons.award;
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.visitedCount,
    required this.totalCountries,
    required this.badges,
    this.avatarUrl,
    this.homeCity,
    this.bio,
  });

  final String id;
  final String displayName;
  final int visitedCount;
  final int totalCountries;
  final List<dynamic> badges;
  final String? avatarUrl;
  final String? homeCity;
  final String? bio;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? 'Explorer',
        visitedCount: (j['visited_count'] as num?)?.toInt() ?? 0,
        totalCountries: (j['total_countries'] as num?)?.toInt() ?? 194,
        badges: (j['badges'] as List<dynamic>?) ?? [],
        avatarUrl: j['avatar_url'] as String?,
        homeCity: j['home_city'] as String?,
        bio: j['bio'] as String?,
      );
}
