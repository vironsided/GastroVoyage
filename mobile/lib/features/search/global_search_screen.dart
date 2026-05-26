import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/baku/baku_map_screen.dart';
import 'package:mobile/features/explore/dish_detail_screen.dart';
import 'package:mobile/features/search/data/search_providers.dart';
import 'package:mobile/features/search/data/search_results.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/public_passport_screen.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';

/// One global search bar over countries, cuisines, Baku restaurants, and
/// friends. Local sources (countries / cuisines / restaurants) hit the
/// in-memory caches and re-rank as the user types; the friends source hits
/// `/social/users/search` with a 220ms debounce to avoid hammering the API.
///
/// Each result kind routes to its native destination on tap — no detour
/// through a generic detail screen.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Pop the soft keyboard automatically — search is the only thing here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Local sources update synchronously — feels instant.
    // Friends search is debounced 220ms so a "Vusa" → "Vusal" type doesn't
    // fire 5 network calls in a row.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = value;
    });

    // Synchronous update too so local hits feel instant. Friends provider
    // re-reads the same notifier on the next frame.
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _clearQuery() {
    HapticFeedback.selectionClick();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final query = ref.watch(searchQueryProvider);
    final localHits = ref.watch(localHitsProvider);
    final friendsAsync = ref.watch(friendHitsProvider);

    final allHits = <SearchHit>[
      ...localHits,
      ...?friendsAsync.asData?.value,
    ]..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      backgroundColor: config.background,
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _controller,
              focusNode: _focusNode,
              config: config,
              onChanged: _onChanged,
              onBack: () => Navigator.of(context).pop(),
              onClear: _controller.text.isEmpty ? null : _clearQuery,
            ),
            Expanded(
              child: query.trim().isEmpty
                  ? _EmptyHint(config: config)
                  : _ResultsList(
                      hits: allHits,
                      friendsLoading: friendsAsync.isLoading &&
                          friendsAsync.asData == null &&
                          query.trim().length >= 2,
                      config: config,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.config,
    required this.onChanged,
    required this.onBack,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final GastroThemeConfig config;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s8, GS.s8, GS.s12, GS.s12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: config.onSurface),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: config.surface,
                borderRadius: BorderRadius.circular(GS.r16),
                border: Border.all(
                  color: config.outlineVariant.withOpacity(0.7),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: GS.s12),
              child: Row(
                children: [
                  Icon(LucideIcons.search, size: 18, color: config.onSurfaceVariant),
                  const SizedBox(width: GS.s10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        color: config.onSurface,
                      ),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Countries, cuisines, places, friends…',
                        hintStyle: GoogleFonts.hankenGrotesk(
                          fontSize: 15,
                          color: config.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  if (onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(LucideIcons.x, size: 18, color: config.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final tone = config.onSurfaceVariant.withOpacity(0.7);
    Widget row(IconData ic, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: GS.s8),
          child: Row(
            children: [
              Icon(ic, size: 18, color: tone),
              const SizedBox(width: GS.s12),
              Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  color: tone,
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s24, GS.s32, GS.s24, GS.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search across the journey',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
            ),
          ),
          const SizedBox(height: GS.s4),
          Text(
            'One bar over everything.',
            style: GoogleFonts.caveat(
              fontSize: 17,
              color: tone,
            ),
          ),
          const SizedBox(height: GS.s20),
          row(LucideIcons.globe, 'Countries — try "Italy" or "Japan"'),
          row(LucideIcons.utensils, 'Cuisines — try "Japanese" or "Indian"'),
          row(LucideIcons.mapPin, 'Baku restaurants — try "Sumaq" or "Old City"'),
          row(LucideIcons.users, 'Friends — try a name'),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.hits,
    required this.friendsLoading,
    required this.config,
  });

  final List<SearchHit> hits;
  final bool friendsLoading;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty && !friendsLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GS.s32),
          child: Text(
            'No matches yet.',
            style: GoogleFonts.caveat(
              fontSize: 20,
              color: config.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(GS.s16, 0, GS.s16, GS.s24),
      itemCount: hits.length + (friendsLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: GS.s8),
      itemBuilder: (context, i) {
        if (friendsLoading && i == hits.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: GS.s12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: config.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        final hit = hits[i];
        return _HitTile(hit: hit, config: config);
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.config});

  final SearchHit hit;
  final GastroThemeConfig config;

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    switch (hit) {
      case CountryHit(:final country):
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DishDetailScreen(country: country),
          ),
        );
      case CuisineHit():
        // Cuisines map onto Baku's restaurant catalog — jumping into the Baku
        // map is the most useful landing surface (the filter chip strip up
        // there mirrors our cuisine taxonomy).
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BakuMapScreen()),
        );
      case RestaurantHit():
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BakuMapScreen()),
        );
      case FriendHit(:final user):
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PublicPassportScreen(
              userId: user.userId,
              previewName: user.name,
            ),
          ),
        );
    }
  }

  Widget _leading() {
    switch (hit) {
      case CountryHit(:final country):
        return _FlagTile(emoji: country.flagEmoji, config: config);
      case CuisineHit(:final flag):
        return _FlagTile(emoji: flag, config: config);
      case RestaurantHit(:final restaurant):
        return _FlagTile(emoji: restaurant.flag, config: config);
      case FriendHit(:final user):
        return SocialAvatar(
          config: config,
          initial: user.initial,
          avatarUrl: user.avatarUrl,
          size: 40,
        );
    }
  }

  String _subtitle() {
    switch (hit) {
      case CountryHit(:final country):
        final parts = <String>[
          country.region,
          country.subregion,
          if (country.visited) 'tasted',
        ].where((s) => s.trim().isNotEmpty).toList();
        return parts.join(' · ');
      case CuisineHit(:final restaurantCount):
        final places = restaurantCount == 1 ? '1 place in Baku' : '$restaurantCount places in Baku';
        return 'Cuisine · $places';
      case RestaurantHit(:final restaurant):
        return '${restaurant.cuisine} · ${restaurant.neighborhood}';
      case FriendHit(:final user):
        switch (user.followStatus) {
          case FollowStatus.accepted:
            return 'Following';
          case FollowStatus.pending:
            return 'Request sent';
          case FollowStatus.none:
            return 'Traveller';
        }
    }
  }

  IconData _kindIcon() {
    switch (hit.kind) {
      case SearchHitKind.country:
        return LucideIcons.globe;
      case SearchHitKind.cuisine:
        return LucideIcons.utensils;
      case SearchHitKind.restaurant:
        return LucideIcons.mapPin;
      case SearchHitKind.friend:
        return LucideIcons.user;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: config.surface,
      borderRadius: BorderRadius.circular(GS.r16),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(GS.r16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: GS.s12, vertical: GS.s10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GS.r16),
            border: Border.all(
              color: config.outlineVariant.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _leading(),
              const SizedBox(width: GS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: config.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: config.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(_kindIcon(), size: 16, color: config.onSurfaceVariant.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.emoji, required this.config});
  final String emoji;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: config.accentSoft,
        borderRadius: BorderRadius.circular(GS.r12),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}
