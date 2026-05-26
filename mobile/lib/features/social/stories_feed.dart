import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/widgets/relative_time.dart';
import 'package:mobile/features/social/widgets/story_bubble.dart';
import 'package:mobile/features/social/widgets/story_viewer.dart';
import 'package:mobile/ui/ui.dart';

/// Instagram-style stories feed for the GastroVoyage social circle.
///
/// Top: a horizontal strip of circular author "bubbles", newest author first.
/// Below: a vertical scroll of every story as a pinned Instax/Polaroid card.
/// Tapping any bubble or card opens a full-screen [_StoryViewer] that walks
/// through the stories like Instagram Stories, in the scrapbook aesthetic.
class StoriesFeedScreen extends ConsumerWidget {
  const StoriesFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.07,
        scratchCount: 6,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(config: config),
              Expanded(
                child: RefreshIndicator(
                  color: config.accent,
                  backgroundColor: config.surface,
                  onRefresh: () async {
                    ref.invalidate(feedProvider);
                    await ref.read(feedProvider.future);
                  },
                  child: feedAsync.when(
                    loading: () => _FeedShimmer(config: config),
                    error: (e, _) => _ScrollableError(
                      config: config,
                      message: e is UnauthorizedException
                          ? 'Your session expired. Please sign in again.'
                          : 'Could not load the stories feed.',
                      onRetry: () => ref.invalidate(feedProvider),
                    ),
                    data: (stories) => _FeedBody(
                      config: config,
                      stories: stories,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, GS.s8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: config.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: config.onSurface),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: GS.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRAVEL CIRCLE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w600,
                    color: config.accent,
                  ),
                ),
                Text(
                  'Stories Feed',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Feed body ──────────────────────────────────────────────────────────────

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.config, required this.stories});
  final GastroThemeConfig config;
  final List<Story> stories;

  /// Opens the full-screen viewer at [startIndex] within [stories].
  void _openViewer(BuildContext context, int startIndex) {
    showStoryViewer(
      context,
      config: config,
      stories: stories,
      initialIndex: startIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(
            GS.s20, GS.s40, GS.s20, GS.navBuffer),
        children: [
          GastroEmptyState(
            config: config,
            icon: LucideIcons.image,
            title: 'No stories yet',
            subtitle:
                'Follow friends to see their tastings, or share one of '
                'your own from your passport.',
          ).animate().fadeIn(duration: GS.normal, curve: GS.smooth),
        ],
      );
    }

    // One bubble per author (first appearance wins — feed is newest-first).
    final authorOrder = <String>[];
    final firstIndexOf = <String, int>{};
    for (var i = 0; i < stories.length; i++) {
      final uid = stories[i].userId;
      if (!firstIndexOf.containsKey(uid)) {
        firstIndexOf[uid] = i;
        authorOrder.add(uid);
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(bottom: GS.navBuffer),
      children: [
        // ── Author bubble strip ───────────────────────────────────────────
        const SizedBox(height: GS.s8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: GS.s16),
            itemCount: authorOrder.length,
            separatorBuilder: (_, __) => const SizedBox(width: GS.s8),
            itemBuilder: (_, i) {
              final story = stories[firstIndexOf[authorOrder[i]]!];
              return StoryBubble(
                config: config,
                name: story.authorName,
                initial: story.authorName[0].toUpperCase(),
                avatarUrl: story.avatarUrl,
                onTap: () =>
                    _openViewer(context, firstIndexOf[authorOrder[i]]!),
              );
            },
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.fromLTRB(GS.s20, GS.s4, GS.s20, GS.s12),
          child: Divider(
            height: 1,
            thickness: 1,
            color: config.outlineVariant.withOpacity(0.6),
          ),
        ),

        // ── Story cards ───────────────────────────────────────────────────
        for (var i = 0; i < stories.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GS.s20, GS.s4, GS.s20, GS.s24),
            child: _StoryCard(
              config: config,
              story: stories[i],
              index: i,
              onTap: () => _openViewer(context, i),
            ),
          ),
      ],
    );
  }
}

// ─── Feed story card ──────────────────────────────────────────────────────────

/// One story rendered as a pinned Instax snapshot in the vertical feed.
class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.config,
    required this.story,
    required this.index,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final Story story;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Alternate the tilt slightly so the feed reads as a scrapbook page.
    final rotation = index.isEven ? -0.018 : 0.018;
    final caption = story.caption?.trim() ?? '';

    final card = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
              GS.s10, GS.s10, GS.s10, GS.s16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GS.r4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo.
              ClipRRect(
                borderRadius: BorderRadius.circular(GS.r4),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: story.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFE8E0D0)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFE8E0D0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined,
                          color: Color(0xFF8B6A3D)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: GS.s12),

              // Handwritten caption on the white lip.
              if (caption.isNotEmpty)
                Text(
                  caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.caveat(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E2A27),
                    height: 1.15,
                  ),
                ),
              if (caption.isNotEmpty) const SizedBox(height: GS.s8),

              // Author + place + time row.
              Row(
                children: [
                  _MiniAvatar(config: config, story: story),
                  const SizedBox(width: GS.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E2A27),
                          ),
                        ),
                        if ((story.countryName ?? '').isNotEmpty)
                          Text(
                            story.countryName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              letterSpacing: 0.6,
                              color: const Color(0xFF8B6A3D),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    relativeTime(story.createdAt),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: const Color(0xFF8B6A3D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(
            duration: GS.normal,
            delay: GS.stagger(index.clamp(0, 6)),
            curve: GS.smooth)
        .slideY(
            begin: 0.06,
            end: 0,
            duration: GS.normal,
            delay: GS.stagger(index.clamp(0, 6)),
            curve: GS.smooth);
  }
}

/// Small circular avatar used on a white Instax lip — uses paper-toned
/// fallbacks rather than themed ones so it sits well on the white card.
class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.config, required this.story});
  final GastroThemeConfig config;
  final Story story;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    final hasUrl = story.avatarUrl != null && story.avatarUrl!.isNotEmpty;

    Widget fallback() => Container(
          color: const Color(0xFFEAD9B5),
          alignment: Alignment.center,
          child: Text(
            story.authorName[0].toUpperCase(),
            style: GoogleFonts.playfairDisplay(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B4A2C),
            ),
          ),
        );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDDD2BC), width: 1.5),
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: story.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback(),
                errorWidget: (_, __, ___) => fallback(),
              )
            : fallback(),
      ),
    );
  }
}

// ─── Loading / error states ───────────────────────────────────────────────────

class _FeedShimmer extends StatelessWidget {
  const _FeedShimmer({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          GS.s20, GS.s12, GS.s20, GS.navBuffer),
      children: [
        // Bubble strip placeholder.
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: GS.s16),
            itemBuilder: (_, __) => Column(
              children: [
                GastroShimmer(
                    config: config, width: 60, height: 60, radius: 30),
                const SizedBox(height: GS.s6),
                GastroShimmer(
                    config: config, width: 40, height: 8, radius: GS.r4),
              ],
            ),
          ),
        ),
        const SizedBox(height: GS.s20),
        for (var i = 0; i < 3; i++)
          GastroShimmer(
            config: config,
            height: 320,
            radius: GS.r4,
            margin: const EdgeInsets.only(bottom: GS.s24),
          ),
      ],
    );
  }
}

/// Error view that still scrolls, so it can pair with the RefreshIndicator.
class _ScrollableError extends StatelessWidget {
  const _ScrollableError({
    required this.config,
    required this.message,
    required this.onRetry,
  });
  final GastroThemeConfig config;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s40, GS.s20, GS.s40),
      children: [
        GastroErrorCard(
          config: config,
          message: message,
          onRetry: onRetry,
        ),
      ],
    );
  }
}
