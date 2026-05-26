import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/wrapped/data/wrapped_stats.dart';
import 'package:mobile/features/wrapped/widgets/wrapped_chrome.dart';

/// Full-screen Spotify-Wrapped-style reveal of the user's culinary year.
///
/// Tap right/left half to advance/rewind; long-press to pause the
/// auto-advance; ✕ to close. The outro card offers "Share to Feed"
/// (creates a story) and "Done".
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key, required this.stats});

  final WrappedStats stats;

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen>
    with SingleTickerProviderStateMixin {
  static const _segmentDuration = Duration(milliseconds: 5500);

  late final PageController _page = PageController();
  late final AnimationController _seg = AnimationController(
    vsync: this,
    duration: _segmentDuration,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) _advance();
    });

  int _index = 0;
  bool _shared = false;

  List<Widget Function(GastroThemeConfig)> _cards(
      String displayName, String? avatarFallback) {
    final s = widget.stats;
    final out = <Widget Function(GastroThemeConfig)>[];

    // 1. Cover — always.
    out.add((c) => _CoverCard(config: c, displayName: displayName, year: s.year));
    // 2. Total bites — always (even 0 is a moment).
    out.add((c) => _BigStatCard(
          config: c,
          kicker: 'CHAPTER ONE',
          number: '${s.visitCount}',
          title: s.visitCount == 1 ? 'bite logged.' : 'bites logged.',
          scribble: 'every plate kept.',
        ));
    // 3. Countries.
    out.add((c) => _BigStatCard(
          config: c,
          kicker: 'PASSPORT PAGES',
          number: '${s.countriesCount}',
          title: s.countriesCount == 1
              ? 'country tasted.'
              : 'countries tasted.',
          scribble: 'borders are just spice routes.',
        ));
    // 4. Top region — if available.
    if (s.topRegion != null) {
      out.add((c) => _TopRegionCard(config: c, region: s.topRegion!));
    }
    // 5. Signature dish — if available.
    if (s.signatureDish != null) {
      out.add((c) => _SignatureDishCard(config: c, dish: s.signatureDish!));
    }
    // 6. Busiest month — if available.
    if (s.busiestMonth != null) {
      out.add((c) => _BusiestMonthCard(config: c, month: s.busiestMonth!));
    }
    // 7. Badges — only if any.
    if (s.badgesEarned > 0) {
      out.add((c) => _BigStatCard(
            config: c,
            kicker: 'STAMPED & SEALED',
            number: '${s.badgesEarned}',
            title:
                s.badgesEarned == 1 ? 'badge earned.' : 'badges earned.',
            scribble: 'each one a flavour mastered.',
          ));
    }
    // 8. Average rating — only if any visits had ratings.
    if (s.visitCount > 0) {
      out.add((c) => _AverageRatingCard(
            config: c,
            avg: s.averageRating,
          ));
    }
    // 9. Top country — if available.
    if (s.topCountry != null) {
      out.add((c) => _TopCountryCard(config: c, country: s.topCountry!));
    }
    // 10. Outro — always.
    out.add((c) => _OutroCard(
          config: c,
          stats: s,
          shared: _shared,
          onShare: () => _share(c, avatarFallback),
          onDone: () => Navigator.of(context).pop(),
        ));

    return out;
  }

  @override
  void initState() {
    super.initState();
    _seg.forward();
  }

  @override
  void dispose() {
    _seg.dispose();
    _page.dispose();
    super.dispose();
  }

  void _advance() {
    final count = _cards('', null).length;
    if (_index >= count - 1) {
      // On the outro: stop auto-advancing; let the user pick a CTA.
      _seg.stop();
      return;
    }
    _index += 1;
    _page.animateToPage(_index,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    _seg
      ..stop()
      ..reset()
      ..forward();
    setState(() {});
  }

  void _rewind() {
    if (_index == 0) {
      _seg
        ..stop()
        ..reset()
        ..forward();
      return;
    }
    _index -= 1;
    _page.animateToPage(_index,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    _seg
      ..stop()
      ..reset()
      ..forward();
    setState(() {});
  }

  void _pause() => _seg.stop();
  void _resume() {
    // Don't auto-resume on the outro card.
    final count = _cards('', null).length;
    if (_index >= count - 1) return;
    if (!_seg.isAnimating) _seg.forward();
  }

  Future<void> _share(GastroThemeConfig config, String? avatarFallback) async {
    if (_shared) return;
    final s = widget.stats;
    final photoUrl = s.signatureDish?.photoPath ?? avatarFallback;
    final scaffold = ScaffoldMessenger.maybeOf(context);

    if (photoUrl == null || photoUrl.isEmpty) {
      scaffold?.showSnackBar(SnackBar(
        content: const Text(
            'Add a photo to a visit (or set an avatar) to share your Wrapped.'),
        backgroundColor: config.surface,
      ));
      return;
    }

    final caption = '${s.year} culinary year — '
        '${s.countriesCount} countries, ${s.visitCount} bites, '
        '★${s.averageRating.toStringAsFixed(1)}';

    setState(() => _shared = true);
    try {
      await ref.read(apiClientProvider).createStory(
            photoUrl: photoUrl,
            caption: caption,
            countryId: null,
          );
      ref.invalidate(feedProvider);
      if (!mounted) return;
      scaffold?.showSnackBar(SnackBar(
        content: const Text('Shared to your feed ✓'),
        backgroundColor: config.accent,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _shared = false);
      scaffold?.showSnackBar(SnackBar(
        content: const Text('Could not share — try again.'),
        backgroundColor: config.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final displayName = ref.watch(authProvider).displayName ?? 'Traveller';
    final avatarUrl = ref.watch(profileProvider).valueOrNull?.avatarUrl;
    final cards = _cards(displayName, avatarUrl);

    // Lean each card a little differently against the accent for variety.
    double leanFor(int i) => 0.2 + ((i % 4) * 0.18);

    return Scaffold(
      backgroundColor: config.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx > w * 0.4) {
            _advance();
          } else {
            _rewind();
          }
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onLongPressCancel: _resume,
        child: Stack(
          children: [
            PageView.builder(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              itemBuilder: (_, i) => WrappedBackdrop(
                config: config,
                accentLean: leanFor(i),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(GS.s24, GS.s40, GS.s24, GS.s28),
                    child: cards[i](config),
                  ),
                ),
              ),
            ),

            // Progress bar (top).
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(GS.s16, GS.s10, GS.s16, 0),
                child: AnimatedBuilder(
                  animation: _seg,
                  builder: (_, __) => StoryProgressBar(
                    config: config,
                    totalSegments: cards.length,
                    activeIndex: _index,
                    progress: _seg.value,
                  ),
                ),
              ),
            ),

            // Close.
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              right: 12,
              child: _GlassButton(
                config: config,
                icon: LucideIcons.x,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card widgets ─────────────────────────────────────────────────────────────

class _CoverCard extends StatelessWidget {
  const _CoverCard(
      {required this.config, required this.displayName, required this.year});
  final GastroThemeConfig config;
  final String displayName;
  final int year;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.utensils, size: 56, color: config.accent)
            .animate()
            .scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.elasticOut),
        const SizedBox(height: GS.s20),
        WrappedKicker(text: 'CULINARY WRAPPED · $year', config: config),
        const SizedBox(height: GS.s12),
        WrappedTitle(
          text: '$displayName,\nhere\'s your\nculinary year.',
          config: config,
          fontSize: 38,
        )
            .animate()
            .fadeIn(duration: 700.ms, delay: 200.ms)
            .slideY(begin: 0.06, end: 0, duration: 700.ms, delay: 200.ms),
        const SizedBox(height: GS.s28),
        WrappedScribble(
          text: 'tap right to begin — long-press to linger.',
          config: config,
        ),
      ],
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.config,
    required this.kicker,
    required this.number,
    required this.title,
    required this.scribble,
  });
  final GastroThemeConfig config;
  final String kicker, number, title, scribble;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: kicker, config: config),
        const SizedBox(height: GS.s28),
        BigNumber(value: number, config: config, fontSize: 168)
            .animate()
            .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 700.ms,
                curve: Curves.easeOutBack)
            .fadeIn(duration: 500.ms),
        const SizedBox(height: GS.s20),
        WrappedTitle(text: title, config: config, fontSize: 30),
        const SizedBox(height: GS.s24),
        WrappedScribble(text: scribble, config: config),
      ],
    );
  }
}

class _TopRegionCard extends StatelessWidget {
  const _TopRegionCard({required this.config, required this.region});
  final GastroThemeConfig config;
  final TopRegion region;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: 'YOUR HEART LIVES IN', config: config),
        const SizedBox(height: GS.s20),
        WrappedTitle(
          text: region.name.toUpperCase(),
          config: config,
          fontSize: 56,
        )
            .animate()
            .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.easeOutBack)
            .fadeIn(duration: 500.ms),
        const SizedBox(height: GS.s20),
        WrappedScribble(
          text: '${region.count} visits and counting.',
          config: config,
        ),
      ],
    );
  }
}

class _SignatureDishCard extends StatelessWidget {
  const _SignatureDishCard({required this.config, required this.dish});
  final GastroThemeConfig config;
  final SignatureDish dish;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: 'YOUR MASTERPIECE', config: config),
        const SizedBox(height: GS.s16),
        if (dish.photoPath != null && dish.photoPath!.isNotEmpty)
          _InstaxPhoto(url: dish.photoPath!, config: config)
              .animate()
              .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.easeOutBack)
              .fadeIn(duration: 500.ms),
        const SizedBox(height: GS.s20),
        WrappedTitle(
          text: dish.dish,
          config: config,
          fontSize: 30,
        ),
        const SizedBox(height: GS.s8),
        WrappedScribble(
          text: '${dish.flag} ${dish.country} · '
              '${'★' * dish.rating}${'☆' * (5 - dish.rating)}',
          config: config,
        ),
      ],
    );
  }
}

class _InstaxPhoto extends StatelessWidget {
  const _InstaxPhoto({required this.url, required this.config});
  final String url;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.04,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            width: 220,
            height: 220,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: config.surfaceVariant),
              errorWidget: (_, __, ___) =>
                  Container(color: config.surfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusiestMonthCard extends StatelessWidget {
  const _BusiestMonthCard({required this.config, required this.month});
  final GastroThemeConfig config;
  final BusiestMonth month;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: 'HUNGRIEST MONTH', config: config),
        const SizedBox(height: GS.s24),
        WrappedTitle(
          text: month.monthName.toUpperCase(),
          config: config,
          fontSize: 64,
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.04, end: 0, duration: 600.ms),
        const SizedBox(height: GS.s16),
        WrappedScribble(
          text:
              '${month.count} bite${month.count == 1 ? '' : 's'} — your appetite peaked.',
          config: config,
        ),
      ],
    );
  }
}

class _AverageRatingCard extends StatelessWidget {
  const _AverageRatingCard({required this.config, required this.avg});
  final GastroThemeConfig config;
  final double avg;

  @override
  Widget build(BuildContext context) {
    final stars = avg.round().clamp(0, 5);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: 'YOUR TASTE-O-METER', config: config),
        const SizedBox(height: GS.s28),
        BigNumber(value: avg.toStringAsFixed(1), config: config, fontSize: 148)
            .animate()
            .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 700.ms,
                curve: Curves.easeOutBack)
            .fadeIn(duration: 500.ms),
        const SizedBox(height: GS.s12),
        Text(
          '${'★' * stars}${'☆' * (5 - stars)}',
          style: GoogleFonts.playfairDisplay(
            fontSize: 36,
            color: config.accent,
          ),
        ),
        const SizedBox(height: GS.s20),
        WrappedScribble(
          text: 'out of five — a generous palate.',
          config: config,
        ),
      ],
    );
  }
}

class _TopCountryCard extends StatelessWidget {
  const _TopCountryCard({required this.config, required this.country});
  final GastroThemeConfig config;
  final TopCountry country;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: 'MOST-TASTED COUNTRY', config: config),
        const SizedBox(height: GS.s24),
        Text(
          country.flag.isEmpty ? '🍽' : country.flag,
          style: const TextStyle(fontSize: 96),
        )
            .animate()
            .scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 700.ms,
                curve: Curves.elasticOut),
        const SizedBox(height: GS.s12),
        WrappedTitle(text: country.name, config: config, fontSize: 44),
        const SizedBox(height: GS.s16),
        WrappedScribble(
          text:
              '${country.count} visit${country.count == 1 ? '' : 's'} — your second home.',
          config: config,
        ),
      ],
    );
  }
}

class _OutroCard extends StatelessWidget {
  const _OutroCard({
    required this.config,
    required this.stats,
    required this.shared,
    required this.onShare,
    required this.onDone,
  });
  final GastroThemeConfig config;
  final WrappedStats stats;
  final bool shared;
  final VoidCallback onShare;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        WrappedKicker(text: 'TO NEXT YEAR\'S APPETITE', config: config),
        const SizedBox(height: GS.s20),
        WrappedTitle(
          text: 'Here\'s to\nthe next bite.',
          config: config,
          fontSize: 44,
        ),
        const SizedBox(height: GS.s16),
        WrappedScribble(
          text:
              '${stats.countriesCount} countries · ${stats.visitCount} bites · ★${stats.averageRating.toStringAsFixed(1)}',
          config: config,
        ),
        const SizedBox(height: GS.s32),
        _PrimaryCta(
          config: config,
          label: shared ? 'Shared to feed ✓' : 'Share to feed',
          icon: shared ? LucideIcons.check : LucideIcons.share2,
          enabled: !shared,
          onTap: onShare,
        ),
        const SizedBox(height: GS.s12),
        _SecondaryCta(
          config: config,
          label: 'Done',
          onTap: onDone,
        ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.config,
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final GastroThemeConfig config;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: config.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: GS.s16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GS.r16),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatelessWidget {
  const _SecondaryCta(
      {required this.config, required this.label, required this.onTap});
  final GastroThemeConfig config;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: GS.s12),
          side: BorderSide(color: config.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GS.r16),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: config.onSurface,
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton(
      {required this.config, required this.icon, required this.onTap});
  final GastroThemeConfig config;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: (config.isDark ? Colors.white : Colors.black).withOpacity(0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: config.onSurface),
        ),
      ),
    );
  }
}
