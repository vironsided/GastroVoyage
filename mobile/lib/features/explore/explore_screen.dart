import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/explore/dish_detail_screen.dart';
import 'package:mobile/features/explore/widgets/customs_painters.dart';
import 'package:mobile/features/explore/widgets/declaration_search.dart';
import 'package:mobile/features/explore/widgets/field_note_card.dart';
import 'package:mobile/features/explore/widgets/passport_bookmark_tabs.dart';
import 'package:mobile/features/explore/widgets/passport_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/ui/ui.dart';

const _regions = [
  'All',
  'Tried',
  'Want to try',
  'Asia',
  'Europe',
  'Africa',
  'Americas',
  'Oceania',
];

/// Countries shown per batch while scrolling (2-column grid).
const _explorePageSize = 24;

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scrollController = ScrollController();
  int _visibleCount = _explorePageSize;
  String? _listKey;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 320) return;
    final total = _pendingTotal;
    if (total == null || _visibleCount >= total) return;
    setState(() {
      _visibleCount = (_visibleCount + _explorePageSize).clamp(0, total);
    });
  }

  int? _pendingTotal;

  void _syncListKey(String key) {
    if (_listKey == key) return;
    _listKey = key;
    _visibleCount = _explorePageSize;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final region = ref.watch(exploreRegionProvider);
    final triedOnly = ref.watch(exploreTriedOnlyProvider);
    final wantToTryOnly = ref.watch(exploreWantToTryOnlyProvider);
    final countriesAsync = ref.watch(exploreCountriesProvider);
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final searchQuery =
        ref.watch(countrySearchQueryProvider).trim().toLowerCase();
    final listKey = '$region|$triedOnly|$wantToTryOnly|$searchQuery';

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.05 : 0.07,
        scratchCount: 7,
        child: CustomScrollView(
          controller: _scrollController,
          cacheExtent: 280,
          slivers: [
            // ── Passport inside-cover header ─────────────────────────────
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GS.s20, GS.s20, GS.s20, GS.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          countriesAsync.when(
                            data: (all) => PassportHeader(
                              config: config,
                              total: all.length,
                              tasted:
                                  all.where((c) => c.visited).length,
                            ),
                            loading: () => PassportHeader(
                              config: config,
                              total: null,
                              tasted: null,
                            ),
                            error: (_, __) => PassportHeader(
                              config: config,
                              total: null,
                              tasted: null,
                            ),
                          ),
                          const SizedBox(height: GS.s20),
                          // declaration-slip search
                          DeclarationSearch(
                            config: config,
                            onChanged: (v) => ref
                                .read(countrySearchQueryProvider.notifier)
                                .state = v,
                          )
                              .animate()
                              .fadeIn(
                                  duration: 380.ms,
                                  delay: 420.ms,
                                  curve: GS.smooth)
                              .slideY(
                                begin: 0.18,
                                end: 0,
                                duration: 380.ms,
                                delay: 420.ms,
                                curve: GS.smooth,
                              ),
                          const SizedBox(height: GS.s12),
                          // passport bookmark-tab region filter
                          PassportBookmarkTabs(
                            config: config,
                            regions: _regions,
                            selectedRegion: region,
                            triedOnly: triedOnly,
                            wantToTryOnly: wantToTryOnly,
                            onSelect: (r) {
                              if (r == 'All') {
                                ref
                                    .read(exploreRegionProvider.notifier)
                                    .state = null;
                                ref
                                    .read(exploreTriedOnlyProvider.notifier)
                                    .state = false;
                                ref
                                    .read(exploreWantToTryOnlyProvider
                                        .notifier)
                                    .state = false;
                              } else if (r == 'Tried') {
                                // Toggle Tried; clear Want-to-try so the two
                                // bucket-list views never overlap.
                                final next =
                                    !ref.read(exploreTriedOnlyProvider);
                                ref
                                    .read(exploreTriedOnlyProvider.notifier)
                                    .state = next;
                                if (next) {
                                  ref
                                      .read(exploreWantToTryOnlyProvider
                                          .notifier)
                                      .state = false;
                                }
                              } else if (r == 'Want to try') {
                                // Toggle Want-to-try; clear Tried so the two
                                // bucket-list views never overlap.
                                final next =
                                    !ref.read(exploreWantToTryOnlyProvider);
                                ref
                                    .read(exploreWantToTryOnlyProvider
                                        .notifier)
                                    .state = next;
                                if (next) {
                                  ref
                                      .read(exploreTriedOnlyProvider.notifier)
                                      .state = false;
                                }
                              } else {
                                ref
                                    .read(exploreRegionProvider.notifier)
                                    .state = r;
                              }
                            },
                          )
                              .animate()
                              .fadeIn(
                                  duration: 380.ms,
                                  delay: 500.ms,
                                  curve: GS.smooth)
                              .slideY(
                                begin: 0.18,
                                end: 0,
                                duration: 380.ms,
                                delay: 500.ms,
                                curve: GS.smooth,
                              ),
                        ],
                      ),
                    ),
                    // hand-torn paper rule with dotted perforation
                    SizedBox(
                      height: 26,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: TornEdgePainter(
                          paperColor: config.isDark
                              ? const Color(0xFF161616)
                              : Colors.white.withOpacity(0.65),
                          dotColor: config.onSurfaceVariant,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 320.ms, delay: 560.ms)
                        .slideX(
                          begin: -0.3,
                          end: 0,
                          duration: 480.ms,
                          delay: 560.ms,
                          curve: GS.smooth,
                        ),
                    const SizedBox(height: GS.s12),
                  ],
                ),
              ),
            ),
            // ── Country grid / states ────────────────────────────────────
            countriesAsync.when(
              data: (all) {
                _syncListKey(listKey);
                var filtered = all;
                if (triedOnly) {
                  filtered =
                      filtered.where((c) => c.visited).toList(growable: false);
                }
                if (wantToTryOnly) {
                  filtered = filtered
                      .where((c) => wishlistIds.contains(c.id))
                      .toList(growable: false);
                }
                if (searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where((c) =>
                          c.name.toLowerCase().contains(searchQuery) ||
                          c.region.toLowerCase().contains(searchQuery))
                      .toList();
                }
                _pendingTotal = filtered.length;
                final visible = filtered.isEmpty
                    ? 0
                    : _visibleCount.clamp(0, filtered.length);
                final hasMore = visible < filtered.length;

                if (hasMore) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !_scrollController.hasClients) return;
                    if (_scrollController.position.maxScrollExtent > 80) {
                      return;
                    }
                    final total = _pendingTotal;
                    if (total == null || _visibleCount >= total) return;
                    setState(() {
                      _visibleCount =
                          (_visibleCount + _explorePageSize).clamp(0, total);
                    });
                  });
                }

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GS.s32, GS.s24, GS.s32, GS.navBuffer),
                      child: Center(
                        child: _EmptyPassportPage(config: config),
                      ),
                    ),
                  );
                }
                return SliverMainAxisGroup(
                  slivers: [
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(GS.s20, GS.s4, GS.s20, 0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.74,
                          crossAxisSpacing: GS.s16,
                          mainAxisSpacing: GS.s20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final country = filtered[i];
                            final card = FieldNoteCard(
                              country: country,
                              config: config,
                              index: i,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DishDetailScreen(country: country),
                                ),
                              ),
                            );
                            // Only the first batch "develops in" with a
                            // staggered delay — later pages appear instantly
                            // to avoid scroll jank.
                            if (i >= _explorePageSize) return card;
                            return card
                                .animate(
                                    delay: Duration(
                                        milliseconds: 600 + i * 45))
                                .fadeIn(duration: 460.ms, curve: GS.smooth)
                                .slideY(
                                  begin: 0.16,
                                  end: 0,
                                  duration: 460.ms,
                                  curve: GS.smooth,
                                )
                                .scale(
                                  begin: const Offset(0.9, 0.9),
                                  end: const Offset(1, 1),
                                  duration: 460.ms,
                                  curve: GS.smooth,
                                );
                          },
                          childCount: visible,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                        ),
                      ),
                    ),
                    if (hasMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: GS.s24),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: config.accent,
                                  ),
                                ),
                                const SizedBox(height: GS.s8),
                                Text(
                                  'STAMPING MORE PAGES…',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                    color: config.onSurfaceVariant
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                        child: SizedBox(height: GS.navBuffer)),
                  ],
                );
              },
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GS.s20, GS.s4, GS.s20, GS.navBuffer),
                  child: _ShimmerGrid(config: config),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GS.s24, GS.s24, GS.s24, GS.navBuffer),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "CAN'T REACH CUSTOMS",
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                            color: config.error,
                          ),
                        ),
                        const SizedBox(height: GS.s12),
                        GastroErrorCard(
                          config: config,
                          icon: LucideIcons.wifiOff,
                          message:
                              'The discovery desk is unreachable. '
                              'Check your connection and try again.',
                        ),
                      ],
                    ).animate().fadeIn(duration: 350.ms),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer loading grid ────────────────────────────────────────────────────

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final paper =
        config.isDark ? const Color(0xFF1C1A17) : const Color(0xFFFBF7EE);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.74,
        crossAxisSpacing: GS.s16,
        mainAxisSpacing: GS.s20,
      ),
      itemCount: 6,
      itemBuilder: (_, i) {
        const tilts = [-0.035, 0.028, -0.018, 0.04, -0.045, 0.022];
        return Transform.rotate(
          angle: tilts[i % tilts.length],
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(GS.s6, GS.s6, GS.s6, GS.s12),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(GS.r4),
              boxShadow: GS.shadow(color: Colors.black, opacity: 0.10),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: config.surfaceVariant,
                      borderRadius: BorderRadius.circular(GS.r4 - 2),
                    ),
                  ),
                ),
                const SizedBox(height: GS.s8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: config.surfaceVariant,
                    borderRadius: BorderRadius.circular(GS.r4),
                  ),
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1200.ms,
                color: config.outlineVariant.withOpacity(0.5),
              ),
        );
      },
    );
  }
}

// ─── Empty state — a blank, un-stamped passport page ─────────────────────────

class _EmptyPassportPage extends StatelessWidget {
  const _EmptyPassportPage({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final paper =
        config.isDark ? const Color(0xFF1C1A17) : const Color(0xFFFBF7EE);
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(GS.s24, GS.s28, GS.s24, GS.s28),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(GS.r8),
        border: Border.all(
          color: config.isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: GS.shadow(color: Colors.black, opacity: 0.14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // an empty round stamp outline — nothing on file
          SizedBox(
            width: 76,
            height: 76,
            child: CustomPaint(
              painter: CustomsStampPainter(
                color: config.onSurfaceVariant.withOpacity(0.35),
                label: '',
                seed: 9,
              ),
            ),
          ),
          const SizedBox(height: GS.s16),
          Text(
            'No entries on this page',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
            ),
          ),
          const SizedBox(height: GS.s6),
          Text(
            'amend your declaration or\nchange the bookmark tab',
            textAlign: TextAlign.center,
            style: GoogleFonts.caveat(
              fontSize: 17,
              color: config.onSurfaceVariant,
              height: 1.2,
            ),
          ),
          const SizedBox(height: GS.s16),
          SizedBox(
            height: 4,
            width: 120,
            child: CustomPaint(
              painter: InkRulePainter(
                color: config.onSurfaceVariant.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 360.ms).scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 360.ms,
          curve: GS.smooth,
        );
  }
}
