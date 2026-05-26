import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/ui/ui.dart';

import 'widgets/badges_section.dart';
import 'widgets/daily_dish_card.dart';
import 'widgets/dashboard_stories_strip.dart';
import 'widgets/editorial_header.dart';
import 'widgets/journey_feature_card.dart';
import 'widgets/next_bite_card.dart';
import 'widgets/passport_card.dart';
import 'widgets/we_together_card.dart';
import 'widgets/scrapbook_bits.dart';
import 'widgets/visit_card.dart';
import 'widgets/wrapped_card.dart';

// ─── Dashboard Screen ─────────────────────────────────────────────────────────
//
// A "culinary passport" scrapbook page: a paper-grain backdrop, a passport
// progress card sealed with wax, a carousel of polaroid visit clippings, and
// an achievements wall of inked stamps. Visual composition only — provider
// wiring and navigation are untouched.

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config       = ref.watch(gastroThemeConfigProvider);
    final auth         = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);
    final visitsAsync  = ref.watch(visitsProvider);
    final badgesAsync  = ref.watch(badgesProvider);
    final couplesAsync = ref.watch(couplesProgressProvider);

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.07,
        scratchCount: 8,
        child: RefreshIndicator(
          color: config.accent,
          backgroundColor: config.surface,
          displacement: 60,
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(visitsProvider);
            ref.invalidate(badgesProvider);
            ref.invalidate(couplesProgressProvider);
            // Refresh the dashboard stories strip + own-story view counts
            // ("SEEN BY N") so the badge stays in sync on pull-to-refresh.
            ref.invalidate(feedProvider);
            // The "Next bite to chase" card reads from the wishlist provider;
            // refetch so the dashboard mirrors any add/remove the user did
            // on the Explore tab since their last pull.
            ref.invalidate(wishlistProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Editorial header ──────────────────────────────────────
              EditorialHeaderSliver(
                profileAsync: profileAsync,
                config: config,
                authDisplayName: auth.displayName,
              ),

              // ── Stories strip — Instagram-style, full-bleed ───────────
              // Its own sliver (not a SliverList child) so it spans the full
              // width edge-to-edge; the strip carries its own GS.s20 lead
              // padding so the first bubble aligns with the content below.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: GS.s4, bottom: GS.s12),
                  child: SizedBox(
                    height: DashboardStoriesStrip.stripOuterHeight,
                    child: const DashboardStoriesStrip(),
                  ),
                ),
              ),

              // ── Content ───────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    GS.s20, 0, GS.s20, GS.navBuffer),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // "We Together" — couple hero card. Self-hides when the
                    // user has no active couple link (returns SizedBox.shrink).
                    WeTogetherCard(config: config),

                    // Passport card.
                    profileAsync.when(
                      data: (p) => PassportCard(profile: p, config: config)
                          .animate()
                          .fadeIn(duration: GS.slow, curve: GS.smooth)
                          .slideY(
                              begin: 0.06,
                              end: 0,
                              duration: GS.slow,
                              curve: GS.smooth),
                      loading: () =>
                          GastroShimmer(height: 188, config: config),
                      error: (_, __) => GastroErrorCard(config: config),
                    ),

                    const SizedBox(height: GS.s24),

                    // Featured: Couples' Culinary Journey entry point.
                    JourneyFeatureCard(
                      config: config,
                      completedWeeks: couplesAsync.asData?.value,
                    )
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(1),
                            curve: GS.smooth)
                        .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: GS.normal,
                            delay: GS.stagger(1),
                            curve: GS.smooth),

                    const SizedBox(height: GS.s20),

                    // Today's dish — curated daily rotation (deterministic
                    // by day-of-year so all users + friends see the same
                    // dish on the same day). Pure mobile data, no backend.
                    DailyDishCard(config: config)
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth)
                        .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth),

                    const SizedBox(height: GS.s20),

                    // Featured: Next bite to chase — surfaces the topmost
                    // wishlist country. Self-hides when the wishlist is
                    // empty, so the dashboard never carves out space for an
                    // empty featured card.
                    NextBiteCard(config: config)
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth)
                        .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth),

                    // Featured: Culinary Wrapped — Spotify-style year reveal.
                    // Self-hides when the user has < 5 logged visits, so the
                    // reveal feels earned.
                    WrappedCard(config: config)
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth)
                        .slideY(
                            begin: 0.06,
                            end: 0,
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth),

                    const SizedBox(height: GS.s24),

                    // Recently Tasted section.
                    SectionHeader(
                      label: 'Recently Tasted',
                      config: config,
                      subtitle: visitsAsync.when(
                        data: (v) => '${v.length} clippings',
                        loading: () => null,
                        error: (_, __) => null,
                      ),
                    )
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(1),
                            curve: GS.smooth)
                        .slideX(
                            begin: -0.04,
                            end: 0,
                            duration: GS.normal,
                            delay: GS.stagger(1)),

                    const SizedBox(height: GS.s8),

                    visitsAsync.when(
                      data: (visits) => visits.isEmpty
                          ? DashboardEmptyVisits(config: config)
                          : VisitsCarousel(
                              visits: visits.take(10).toList(),
                              config: config,
                            ),
                      loading: () => GastroShimmerCarousel(config: config),
                      error: (e, _) => GastroErrorCard(
                          message: e.toString(), config: config),
                    ),

                    const SizedBox(height: GS.s24),

                    StitchedDivider(config: config)
                        .animate()
                        .fadeIn(
                            duration: GS.normal, delay: GS.stagger(2)),

                    const SizedBox(height: GS.s24),

                    // Achievements section.
                    SectionHeader(
                      label: 'Achievements',
                      config: config,
                      subtitle: badgesAsync.when(
                        data: (b) {
                          final n = b.where((x) => x.earned).length;
                          return '$n ${n == 1 ? 'stamp' : 'stamps'} earned';
                        },
                        loading: () => null,
                        error: (_, __) => null,
                      ),
                    )
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(3),
                            curve: GS.smooth)
                        .slideX(
                            begin: -0.04,
                            end: 0,
                            duration: GS.normal,
                            delay: GS.stagger(3)),

                    const SizedBox(height: GS.s16),

                    badgesAsync.when(
                      data: (badges) =>
                          BadgesWall(badges: badges, config: config),
                      loading: () =>
                          GastroShimmer(height: 100, config: config),
                      error: (_, __) => GastroErrorCard(config: config),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
