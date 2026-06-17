import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/ui/ui.dart';

import 'widgets/achievements_link_card.dart';
import 'widgets/cuisine_recommendations_card.dart';
import 'widgets/daily_dish_card.dart';
import 'widgets/dashboard_stories_strip.dart';
import 'widgets/discover_baku_card.dart';
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
// A "culinary passport" scrapbook page. Phase 3 reorganises the old flat promo
// stack into labelled sections that lead with the user's own data and the
// flagship city (Baku), then group the Couples/AI flagship features under a
// single "Featured" header so they stay prominent without crowding the top.
//
//   Your Passport   →  couple hero + passport progress (your data leads)
//   Discover        →  Baku food map + today's dish (the hero, up top)
//   Featured        →  Couples journey + AI recs + next bite + wrapped
//   Recently Tasted →  visit clippings carousel
//   (footer)        →  compact Achievements link (full wall lives on You tab)

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
                    // ── SECTION: Your Passport ────────────────────────────
                    // Lead with the user's own data, not a promo stack.
                    SectionHeader(label: 'Your Passport', config: config)
                        .animate()
                        .fadeIn(duration: GS.normal, curve: GS.smooth)
                        .slideX(
                            begin: -0.04, end: 0, duration: GS.normal),

                    const SizedBox(height: GS.s12),

                    // "We Together" — couple hero card. Self-hides when the
                    // user has no active couple link (returns SizedBox.shrink).
                    WeTogetherCard(config: config),

                    // Passport progress card.
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

                    // ── SECTION: Discover ─────────────────────────────────
                    // The hero (Baku) up top + a daily discovery pick.
                    SectionHeader(
                      label: 'Discover',
                      config: config,
                      subtitle: "Baku & today's pick",
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

                    const SizedBox(height: GS.s12),

                    // Flagship city entry point → Map tab in Baku mode.
                    DiscoverBakuCard(config: config)
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

                    const SizedBox(height: GS.s16),

                    // Today's dish — curated daily rotation (deterministic by
                    // day-of-year so all users + friends see the same dish on
                    // the same day). Pure mobile data, no backend.
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

                    const SizedBox(height: GS.s24),

                    // ── SECTION: Featured (Couples & AI) ──────────────────
                    // Flagship features kept prominent, but grouped under one
                    // header instead of scattered down the page.
                    SectionHeader(
                      label: 'Featured',
                      config: config,
                      subtitle: 'Made for you',
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

                    const SizedBox(height: GS.s12),

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

                    // Featured: AI cuisine recommendations — lazy. Doesn't
                    // call the AI until the user taps the card, so dashboard
                    // load stays fast and free.
                    CuisineRecommendationsCard(config: config)
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
                    // wishlist country. Self-hides when the wishlist is empty.
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

                    const SizedBox(height: GS.s20),

                    // Featured: Culinary Wrapped — Spotify-style year reveal.
                    // Self-hides when the user has < 5 logged visits.
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

                    // ── SECTION: Recently Tasted ──────────────────────────
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

                    // Compact Achievements link — the full stamp wall now lives
                    // canonically on the You tab, so Home just taps through.
                    badgesAsync.when(
                      data: (badges) => AchievementsLinkCard(
                        config: config,
                        earnedCount:
                            badges.where((x) => x.earned).length,
                      ),
                      loading: () =>
                          GastroShimmer(height: 64, config: config),
                      error: (_, __) => const SizedBox.shrink(),
                    )
                        .animate()
                        .fadeIn(
                            duration: GS.normal,
                            delay: GS.stagger(2),
                            curve: GS.smooth),
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
