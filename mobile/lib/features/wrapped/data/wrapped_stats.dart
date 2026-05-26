import 'package:mobile/features/shared/models.dart';

/// Aggregated stats powering the "Culinary Wrapped" reveal.
///
/// Pure data — built by [WrappedStats.compute] from the already-loaded
/// visits + badges lists. No Flutter, no network. Designed to degrade
/// gracefully when the user has sparse data: every "top" field is
/// nullable so the reveal screen can skip cards it cannot illustrate.
class WrappedStats {
  const WrappedStats({
    required this.year,
    required this.visitCount,
    required this.countriesCount,
    required this.cuisinesCount,
    required this.badgesEarned,
    required this.averageRating,
    this.topRegion,
    this.topCountry,
    this.signatureDish,
    this.busiestMonth,
    this.firstVisit,
    this.mostRecentVisit,
  });

  final int year;
  final int visitCount;
  final int countriesCount;
  final int cuisinesCount;
  final int badgesEarned;
  final double averageRating;

  final TopRegion? topRegion;
  final TopCountry? topCountry;
  final SignatureDish? signatureDish;
  final BusiestMonth? busiestMonth;
  final FirstVisit? firstVisit;
  final FirstVisit? mostRecentVisit;

  bool get hasAnyData => visitCount > 0;

  /// Builds [WrappedStats] from the in-memory providers. When [year] is null
  /// the current calendar year is used.
  ///
  /// Visits with an unparseable [Visit.visitedOn] are silently skipped —
  /// the field is a free-form ISO string and the backend has occasionally
  /// emitted partial dates during migrations; better to under-count than
  /// crash the reveal.
  static WrappedStats compute(
    List<Visit> visits,
    List<CuisineBadge> badges, {
    int? year,
  }) {
    final targetYear = year ?? DateTime.now().year;

    // ── 1. Filter to the target year ───────────────────────────────────────
    final yearVisits = <_DatedVisit>[];
    for (final v in visits) {
      final dt = _parseDate(v.visitedOn);
      if (dt == null) continue;
      if (dt.year != targetYear) continue;
      yearVisits.add(_DatedVisit(v, dt));
    }

    if (yearVisits.isEmpty) {
      return WrappedStats(
        year: targetYear,
        visitCount: 0,
        countriesCount: 0,
        cuisinesCount: 0,
        badgesEarned: _countBadgesForYear(badges, targetYear),
        averageRating: 0,
      );
    }

    // ── 2. Counts ──────────────────────────────────────────────────────────
    final countryIds = <String>{};
    final regions = <String>{};
    for (final dv in yearVisits) {
      if (dv.visit.countryId.isNotEmpty) countryIds.add(dv.visit.countryId);
      final r = dv.visit.country?.region;
      if (r != null && r.isNotEmpty) regions.add(r);
    }

    // ── 3. Top region ──────────────────────────────────────────────────────
    final regionTally = <String, int>{};
    for (final dv in yearVisits) {
      final r = dv.visit.country?.region;
      if (r == null || r.isEmpty) continue;
      regionTally[r] = (regionTally[r] ?? 0) + 1;
    }
    TopRegion? topRegion;
    if (regionTally.isNotEmpty) {
      final entry =
          regionTally.entries.reduce((a, b) => a.value >= b.value ? a : b);
      topRegion = TopRegion(name: entry.key, count: entry.value);
    }

    // ── 4. Top country (by visit count) ────────────────────────────────────
    final countryTally = <String, _CountryAgg>{};
    for (final dv in yearVisits) {
      final c = dv.visit.country;
      if (c == null) continue;
      final agg = countryTally.putIfAbsent(
        c.id,
        () => _CountryAgg(name: c.name, flag: c.flagEmoji),
      );
      agg.count += 1;
    }
    TopCountry? topCountry;
    if (countryTally.isNotEmpty) {
      final entry =
          countryTally.entries.reduce((a, b) => a.value.count >= b.value.count ? a : b);
      topCountry = TopCountry(
        name: entry.value.name,
        flag: entry.value.flag,
        count: entry.value.count,
      );
    }

    // ── 5. Signature dish (highest rating; ties → most recent) ─────────────
    SignatureDish? signatureDish;
    _DatedVisit? best;
    for (final dv in yearVisits) {
      if (dv.visit.rating <= 0) continue;
      if (best == null) {
        best = dv;
        continue;
      }
      if (dv.visit.rating > best.visit.rating) {
        best = dv;
      } else if (dv.visit.rating == best.visit.rating &&
          dv.date.isAfter(best.date)) {
        best = dv;
      }
    }
    if (best != null) {
      final v = best.visit;
      // Prefer the user's hand-typed restaurant name; fall back to the first
      // non-empty line of their notes (often the dish), then to a generic
      // "Local favourite" so the card always has copy to render.
      final dishLabel = _firstNonEmptyLine(v.restaurantName) ??
          _firstNonEmptyLine(v.notes) ??
          'Local favourite';
      signatureDish = SignatureDish(
        dish: dishLabel,
        country: v.country?.name ?? 'Somewhere delicious',
        flag: v.country?.flagEmoji ?? '🍽️',
        rating: v.rating,
        photoPath: (v.photoPath?.isNotEmpty ?? false) ? v.photoPath : null,
      );
    }

    // ── 6. Busiest month ───────────────────────────────────────────────────
    final monthTally = List<int>.filled(12, 0);
    for (final dv in yearVisits) {
      monthTally[dv.date.month - 1] += 1;
    }
    int busiestIdx = 0;
    for (var i = 1; i < 12; i++) {
      if (monthTally[i] > monthTally[busiestIdx]) busiestIdx = i;
    }
    final busiestCount = monthTally[busiestIdx];
    final busiestMonth = busiestCount == 0
        ? null
        : BusiestMonth(
            month: busiestIdx + 1,
            monthName: _monthName(busiestIdx + 1),
            count: busiestCount,
          );

    // ── 7. Average rating (ignore unrated 0s) ──────────────────────────────
    final rated = yearVisits.where((dv) => dv.visit.rating > 0).toList();
    final averageRating = rated.isEmpty
        ? 0.0
        : rated.map((dv) => dv.visit.rating).reduce((a, b) => a + b) /
            rated.length;

    // ── 8. First / most-recent visit ───────────────────────────────────────
    yearVisits.sort((a, b) => a.date.compareTo(b.date));
    final first = yearVisits.first;
    final last = yearVisits.last;
    final firstVisit = FirstVisit(
      date: first.date,
      country: first.visit.country?.name ?? 'Somewhere',
      flag: first.visit.country?.flagEmoji ?? '🌍',
    );
    final mostRecentVisit = FirstVisit(
      date: last.date,
      country: last.visit.country?.name ?? 'Somewhere',
      flag: last.visit.country?.flagEmoji ?? '🌍',
    );

    return WrappedStats(
      year: targetYear,
      visitCount: yearVisits.length,
      countriesCount: countryIds.length,
      cuisinesCount: regions.isEmpty ? countryIds.length : regions.length,
      badgesEarned: _countBadgesForYear(badges, targetYear),
      averageRating: averageRating,
      topRegion: topRegion,
      topCountry: topCountry,
      signatureDish: signatureDish,
      busiestMonth: busiestMonth,
      firstVisit: firstVisit,
      mostRecentVisit: mostRecentVisit,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static int _countBadgesForYear(List<CuisineBadge> badges, int year) {
    var n = 0;
    for (final b in badges) {
      if (!b.earned) continue;
      final raw = b.earnedAt;
      if (raw == null || raw.isEmpty) {
        // Earned with no timestamp — count it. Better to over-celebrate than
        // hide an earned badge from the Wrapped story.
        n += 1;
        continue;
      }
      final dt = DateTime.tryParse(raw);
      if (dt == null) {
        n += 1;
        continue;
      }
      if (dt.year == year) n += 1;
    }
    return n;
  }

  static String? _firstNonEmptyLine(String? raw) {
    if (raw == null) return null;
    for (final line in raw.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  static const _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _monthName(int month) =>
      _monthNames[(month - 1).clamp(0, 11)];
}

class TopRegion {
  const TopRegion({required this.name, required this.count});
  final String name;
  final int count;
}

class TopCountry {
  const TopCountry({
    required this.name,
    required this.flag,
    required this.count,
  });
  final String name;
  final String flag;
  final int count;
}

class SignatureDish {
  const SignatureDish({
    required this.dish,
    required this.country,
    required this.flag,
    required this.rating,
    this.photoPath,
  });
  final String dish;
  final String country;
  final String flag;
  final int rating;
  final String? photoPath;
}

class BusiestMonth {
  const BusiestMonth({
    required this.month,
    required this.monthName,
    required this.count,
  });
  final int month; // 1–12
  final String monthName;
  final int count;
}

class FirstVisit {
  const FirstVisit({
    required this.date,
    required this.country,
    required this.flag,
  });
  final DateTime date;
  final String country;
  final String flag;
}

class _DatedVisit {
  _DatedVisit(this.visit, this.date);
  final Visit visit;
  final DateTime date;
}

class _CountryAgg {
  _CountryAgg({required this.name, required this.flag});
  final String name;
  final String flag;
  int count = 0;
}
