import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/public_passport_screen.dart';
import 'package:mobile/features/social/widgets/relative_time.dart';
import 'package:mobile/features/social/widgets/story_comments_sheet.dart';
import 'package:mobile/features/social/widgets/story_viewers_sheet.dart';

/// Opens the full-screen [StoryViewer] for [stories], starting at [initialIndex].
///
/// Used by both the stories feed and the dashboard stories strip. Renders as a
/// fade-in over a black barrier, mirroring Instagram Stories.
void showStoryViewer(
  BuildContext context, {
  required GastroThemeConfig config,
  required List<Story> stories,
  int initialIndex = 0,
}) {
  if (stories.isEmpty) return;
  HapticFeedback.selectionClick();
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => StoryViewer(
        config: config,
        stories: stories,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      transitionDuration: GS.fast,
    ),
  );
}

/// Instagram-style full-screen story viewer rendered in the scrapbook
/// aesthetic. Each story is a large Instax/Polaroid card on a dark stage:
///  • a segmented progress bar at the top,
///  • tap right / left to advance / rewind,
///  • swipe down or the X to close,
///  • tap the author's name/avatar to open their public passport.
class StoryViewer extends ConsumerStatefulWidget {
  const StoryViewer({
    super.key,
    required this.config,
    required this.stories,
    required this.initialIndex,
  });

  final GastroThemeConfig config;
  final List<Story> stories;
  final int initialIndex;

  @override
  ConsumerState<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends ConsumerState<StoryViewer>
    with SingleTickerProviderStateMixin {
  /// How long each story is shown before auto-advancing.
  static const _storyDuration = Duration(seconds: 6);

  /// Curated food-themed emoji palette. The order is the order they appear
  /// in the bottom strip. The backend accepts any single emoji; the palette
  /// is the mobile contract.
  static const List<String> _reactionEmojis = ['🍴', '❤️', '🔥', '🌶️', '🍷'];

  /// How long a reaction tap pauses auto-advance for, so the float animation
  /// finishes before the next story scrolls in.
  static const Duration _reactionPauseDuration = Duration(milliseconds: 1200);

  late final AnimationController _progress;
  late int _index;

  /// A mutable mirror of `_stories[_index]`. Lets us reflect the
  /// caller's just-tapped reaction in the palette + pill without bouncing
  /// through a feed refetch.
  late List<Story> _stories;

  /// Stories already marked viewed in this viewer session — keeps us from
  /// hammering POST /view on every progress restart / pause-resume cycle.
  final Set<String> _viewedThisSession = <String>{};

  /// Counter for the floating-emoji overlay keys. Each tap mints a new key
  /// so flutter_animate replays the animation from scratch — even if the
  /// user double-taps the same emoji quickly.
  int _floatSeq = 0;
  final List<_FloatingReaction> _floaters = <_FloatingReaction>[];

  /// Monotonic counter used to invalidate older reaction-pause timers when
  /// the user taps a second emoji before the first pause window elapses.
  /// Only the latest tick is allowed to resume `_progress`.
  int _reactionPauseTick = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _stories = List<Story>.of(widget.stories);
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _advance();
      });
    _startProgress();
    // The first story is already visible — record a view for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeMarkViewed());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progress
      ..reset()
      ..forward();
  }

  void _advance() {
    if (_index >= _stories.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _index++);
    _startProgress();
    _maybeMarkViewed();
  }

  void _rewind() {
    if (_index <= 0) {
      _startProgress();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _index--);
    _startProgress();
    _maybeMarkViewed();
  }

  /// Fire-and-forget: tell the backend the current user just saw the story at
  /// [_index]. Skipped when it's the caller's own story (the owner's own
  /// glance never counts in "Seen by N"), or when we've already marked it in
  /// this viewer session.
  void _maybeMarkViewed() {
    if (!mounted) return;
    final story = _stories[_index];
    if (story.id.isEmpty) return;
    if (_viewedThisSession.contains(story.id)) return;

    final currentUserId = ref.read(authProvider).userId;
    if (currentUserId == null || currentUserId.isEmpty) return;
    // Don't record the owner's own view.
    if (story.userId == currentUserId) {
      _viewedThisSession.add(story.id);
      return;
    }
    _viewedThisSession.add(story.id);
    // Unawaited — the API client swallows network errors internally.
    ref.read(apiClientProvider).markStoryViewed(story.id);
  }

  /// Opens the "Seen by" bottom sheet for one of the caller's own stories.
  /// Mirrors `_openAuthorPassport`: pause the timer while the sheet is up,
  /// resume on dismiss. [initialTab] controls whether the sheet opens on the
  /// VIEWERS or REACTIONS tab.
  void _openSeenBy(
    Story story, {
    StoryViewersSheetTab initialTab = StoryViewersSheetTab.viewers,
  }) {
    HapticFeedback.selectionClick();
    _progress.stop();
    showStoryViewersSheet(
      context,
      storyId: story.id,
      ownerName: story.authorName,
      initialTab: initialTab,
    ).then((_) {
      if (mounted) _progress.forward();
    });
  }

  /// Opens the comments thread for [story]. Open to everyone — the comments
  /// sheet has its own RLS-checked read path. While the sheet is up the
  /// auto-advance pauses; on dismiss we resume and trigger a quick refetch of
  /// the comments provider so the next open is fresh.
  void _openComments(Story story) {
    if (story.id.isEmpty) return;
    HapticFeedback.selectionClick();
    _progress.stop();
    showStoryCommentsSheet(
      context,
      storyId: story.id,
      storyOwnerId: story.userId,
      ownerName: story.authorName,
    ).then((_) {
      if (!mounted) return;
      _progress.forward();
      // Optimistic bump: if the user composed new comments inside the sheet,
      // the sheet itself invalidates `feedProvider` on dispose so the pill
      // refreshes the next time the feed is read. Locally we also nudge
      // the in-memory pill by re-reading from the freshly-invalidated feed
      // provider on next frame — but the simpler path is to just trust the
      // feed invalidation and let the user's next nav refresh the count.
    });
  }

  /// Briefly pauses auto-advance so the floating-emoji animation has time
  /// to play before the next story scrolls in. Calling it repeatedly during
  /// the pause window just resets the resume timer — the user can spam-tap
  /// reactions without the timer racing ahead.
  void _pauseForReaction() {
    _progress.stop();
    final tick = ++_reactionPauseTick;
    Future<void>.delayed(_reactionPauseDuration).then((_) {
      if (!mounted) return;
      // Only resume if no later tap has bumped the tick — otherwise the
      // newer pause window owns the timer.
      if (tick != _reactionPauseTick) return;
      _progress.forward();
    });
  }

  /// Locally mutates [story] to carry the new reaction without bouncing
  /// through a feed refetch. Keeps the palette + pill instantly in sync with
  /// the user's tap.
  void _patchStoryReaction(
    Story story, {
    required String? newReaction,
    required String? prevReaction,
  }) {
    final delta = (prevReaction == null && newReaction != null)
        ? 1
        : (prevReaction != null && newReaction == null)
            ? -1
            : 0;
    final nextCount = (story.reactionCount + delta);
    final updated = story.copyWithReaction(
      myReaction: newReaction,
      reactionCount: nextCount < 0 ? 0 : nextCount,
    );
    final idx = _stories.indexWhere((s) => s.id == story.id);
    if (idx < 0) return;
    setState(() => _stories[idx] = updated);
  }

  /// Handles a tap on one of the reaction-palette buttons. Three cases:
  ///   • Tapping the SAME emoji you already chose ⇒ delete (toggle off).
  ///   • Tapping a DIFFERENT emoji ⇒ upsert (change).
  ///   • Tapping any emoji on a story you haven't reacted to ⇒ insert.
  /// Optimistic UI: we update [_stories] immediately and roll back on any
  /// network failure. The float animation runs regardless so the tap feels
  /// instant even on a flaky connection.
  Future<void> _onReactionTapped(Story story, String emoji) async {
    if (story.id.isEmpty) return;
    HapticFeedback.selectionClick();

    final api = ref.read(apiClientProvider);
    final prev = story.myReaction;
    final isToggleOff = prev == emoji;

    // Pause + start the float before the network call lands so the tap
    // feels instant. The float still runs on the toggle-off case so the
    // user gets visual confirmation their reaction left.
    _pauseForReaction();
    _spawnFloatingEmoji(emoji);

    // Optimistic local mutation.
    _patchStoryReaction(
      story,
      newReaction: isToggleOff ? null : emoji,
      prevReaction: prev,
    );

    try {
      if (isToggleOff) {
        await api.unreactToStory(story.id);
      } else {
        await api.reactToStory(story.id, emoji);
      }
    } catch (_) {
      if (!mounted) return;
      // Roll back the local mutation so the palette reflects the real state.
      _patchStoryReaction(
        story,
        newReaction: prev,
        prevReaction: isToggleOff ? null : emoji,
      );
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Reaction failed — try again in a moment'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Mints a fresh floating-emoji overlay that animates from the palette up
  /// the screen and fades out. The list is pruned automatically when the
  /// animation reports done.
  void _spawnFloatingEmoji(String emoji) {
    final id = ++_floatSeq;
    setState(() {
      _floaters.add(_FloatingReaction(id: id, emoji: emoji));
    });
    // Cleanup ~1500ms after spawn (longer than the chained animation total).
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        _floaters.removeWhere((f) => f.id == id);
      });
    });
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    // Left third rewinds; the rest advances — mirrors Instagram Stories.
    if (details.globalPosition.dx < width / 3) {
      _rewind();
    } else {
      _advance();
    }
  }

  /// Opens the author's public passport, pausing the auto-advance while away.
  void _openAuthorPassport(Story story) {
    if (story.userId.isEmpty) return;
    HapticFeedback.selectionClick();
    _progress.stop();
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => PublicPassportScreen(
              userId: story.userId,
              previewName: story.authorName,
            ),
          ),
        )
        .then((_) {
      // Resume the story timer once the passport is dismissed.
      if (mounted) _progress.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
    final currentUserId = ref.watch(authProvider.select((s) => s.userId));
    final isOwnStory =
        currentUserId != null && currentUserId.isNotEmpty && story.userId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            // Tap to navigate between stories.
            onTapDown: _onTapDown,
            // Swipe down to dismiss.
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 240) {
                Navigator.of(context).maybePop();
              }
            },
            // Hold to pause the auto-advance, like Instagram.
            onLongPressStart: (_) => _progress.stop(),
            onLongPressEnd: (_) => _progress.forward(),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Segmented progress bar ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        GS.s12, GS.s10, GS.s12, GS.s4),
                    child: Row(
                      children: [
                        for (var i = 0; i < _stories.length; i++) ...[
                          Expanded(
                            child: _ProgressSegment(
                              config: widget.config,
                              state: i < _index
                                  ? _SegmentState.done
                                  : i == _index
                                      ? _SegmentState.active
                                      : _SegmentState.upcoming,
                              controller: _progress,
                            ),
                          ),
                          if (i != _stories.length - 1)
                            const SizedBox(width: 3),
                        ],
                      ],
                    ),
                  ),

                  // ── Author bar ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        GS.s12, GS.s6, GS.s8, GS.s4),
                    child: Row(
                      children: [
                        // Author name + avatar → tap to open their passport.
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openAuthorPassport(story),
                            child: Row(
                              children: [
                                _ViewerAvatar(story: story),
                                const SizedBox(width: GS.s10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        story.authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        relativeTime(story.createdAt),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9,
                                          color: Colors.white
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 24),
                          onPressed: () =>
                              Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),

                  // ── Instax story card ───────────────────────────────
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: GS.s24, vertical: GS.s12),
                        child: _ViewerInstax(
                          // Key on the story id so flutter_animate replays
                          // the entrance for each new story.
                          key: ValueKey(story.id),
                          config: widget.config,
                          story: story,
                        ),
                      ),
                    ),
                  ),

                  // ── Owner-only summary pill: 👁 N · 🍴3 ❤️2 ──────────
                  // Always paired with the universal "💬 N" comments pill so
                  // the bottom of the viewer has a single row of badges.
                  if (isOwnStory)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: GS.s8, bottom: GS.s4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _OwnerSummaryPill(
                            story: story,
                            onTapViewers: () => _openSeenBy(
                              story,
                              initialTab: StoryViewersSheetTab.viewers,
                            ),
                            onTapReactions: () => _openSeenBy(
                              story,
                              initialTab: StoryViewersSheetTab.reactions,
                            ),
                          ),
                          const SizedBox(width: GS.s8),
                          _CommentsPill(
                            count: story.commentCount,
                            onTap: () => _openComments(story),
                          ),
                        ],
                      ),
                    ),

                  // ── Reaction palette (friend-only) + comments pill ──
                  if (!isOwnStory)
                    Padding(
                      padding: const EdgeInsets.only(
                          top: GS.s8, bottom: GS.s4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ReactionPalette(
                            config: widget.config,
                            emojis: _reactionEmojis,
                            selectedEmoji: story.myReaction,
                            onTap: (emoji) =>
                                _onReactionTapped(story, emoji),
                          ),
                          const SizedBox(width: GS.s8),
                          _CommentsPill(
                            count: story.commentCount,
                            onTap: () => _openComments(story),
                          ),
                        ],
                      ),
                    ),

                  // ── Hint footer ─────────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: GS.s12, top: GS.s4),
                    child: Text(
                      isOwnStory
                          ? 'tap the eye, heart, or speech bubble for details'
                          : 'tap an emoji or 💬 to chime in · swipe down to close',
                      style: GoogleFonts.caveat(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating-emoji overlay ─────────────────────────────────────
          // Sits above the entire viewer so the emoji can drift up past
          // any other chrome. Each entry mounts a single chained animation
          // and is pruned by `_spawnFloatingEmoji`'s timer.
          IgnorePointer(
            ignoring: true,
            child: Stack(
              children: [
                for (final f in _floaters)
                  _FloatingReactionWidget(
                    key: ValueKey(f.id),
                    emoji: f.emoji,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Owner-only summary pill beneath the story card: 👁 N · 🍴 ❤️.
/// The eye half opens the VIEWERS tab of the bottom sheet; the heart half
/// opens the REACTIONS tab. Both halves share the same glass background so
/// it reads as one pill with a divider.
class _OwnerSummaryPill extends StatelessWidget {
  const _OwnerSummaryPill({
    required this.story,
    required this.onTapViewers,
    required this.onTapReactions,
  });

  final Story story;
  final VoidCallback onTapViewers;
  final VoidCallback onTapReactions;

  @override
  Widget build(BuildContext context) {
    final reactionCount = story.reactionCount;
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(GS.rPill),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Eye half: viewers tab ────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(GS.rPill),
                  bottomLeft: Radius.circular(GS.rPill),
                ),
                onTap: onTapViewers,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GS.s16, vertical: GS.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: GS.s8),
                      Text(
                        '${story.viewCount}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Vertical divider ─────────────────────────────────────
            Container(
              width: 0.5,
              height: 18,
              color: Colors.white.withOpacity(0.25),
            ),

            // ── Heart half: reactions tab ────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(GS.rPill),
                  bottomRight: Radius.circular(GS.rPill),
                ),
                onTap: onTapReactions,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GS.s16, vertical: GS.s8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '🍴',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: GS.s6),
                      Text(
                        '$reactionCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ],
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

/// Universal "💬 N" comments pill. Visible on every story regardless of
/// ownership — the comments thread is open to everyone. Renders as a glass
/// pill matching the viewers + reaction palette styling so the bottom of the
/// viewer reads as one cohesive row.
class _CommentsPill extends StatelessWidget {
  const _CommentsPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GS.rPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: GS.s16, vertical: GS.s8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(GS.rPill),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 13)),
              const SizedBox(width: GS.s8),
              Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-strip reaction palette for friend stories. A glass pill containing
/// five emoji buttons; the user's current reaction (if any) shows a halo so
/// re-tapping the same emoji toggles it off.
class _ReactionPalette extends StatelessWidget {
  const _ReactionPalette({
    required this.config,
    required this.emojis,
    required this.selectedEmoji,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final List<String> emojis;
  final String? selectedEmoji;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    // The palette has to read against the always-black story backdrop, so
    // we use a translucent white glass regardless of the rest of the app's
    // theme. We still consult `config.isDark` to choose between a slightly
    // darker (light theme) and lighter (dark theme) variant.
    final isDark = config.isDark;
    final pillColor =
        Colors.white.withOpacity(isDark ? 0.10 : 0.14);
    final borderColor =
        Colors.white.withOpacity(isDark ? 0.22 : 0.30);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GS.s8, vertical: GS.s6),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: BorderRadius.circular(GS.rPill),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in emojis)
              _PaletteButton(
                emoji: emoji,
                isSelected: selectedEmoji == emoji,
                onTap: () => onTap(emoji),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: AnimatedContainer(
          duration: GS.fast,
          curve: GS.smooth,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(GS.s8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? Colors.white.withOpacity(0.22)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.55)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}

/// Lightweight value object for an in-flight floating emoji animation.
class _FloatingReaction {
  const _FloatingReaction({required this.id, required this.emoji});
  final int id;
  final String emoji;
}

/// The animated emoji that drifts up from the palette on a successful tap.
/// Chained flutter_animate effects: fade-in, slide upward, scale up, then
/// fade out. Sized small enough to not steal the eye from the story photo.
class _FloatingReactionWidget extends StatelessWidget {
  const _FloatingReactionWidget({super.key, required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 44),
        )
            .animate()
            .fadeIn(duration: GS.fast, curve: GS.smooth)
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1.4, 1.4),
              duration: GS.normal,
              curve: GS.spring,
            )
            .slideY(
              begin: 0,
              end: -2.5,
              duration: GS.xslow,
              curve: GS.smooth,
            )
            .fadeOut(
              delay: const Duration(milliseconds: 600),
              duration: GS.slow,
              curve: GS.smooth,
            ),
      ),
    );
  }
}

enum _SegmentState { done, active, upcoming }

/// A single segment of the story progress bar. The active segment animates
/// with [controller]; done segments are full, upcoming ones empty.
class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.config,
    required this.state,
    required this.controller,
  });

  final GastroThemeConfig config;
  final _SegmentState state;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final track = Colors.white.withOpacity(0.25);
    const fill = Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: switch (state) {
          _SegmentState.done => const ColoredBox(color: fill),
          _SegmentState.upcoming => ColoredBox(color: track),
          _SegmentState.active => Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: track)),
                AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: controller.value,
                    child: const ColoredBox(color: fill),
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
}

/// Circular avatar used in the viewer's author bar.
class _ViewerAvatar extends StatelessWidget {
  const _ViewerAvatar({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    final hasUrl = story.avatarUrl != null && story.avatarUrl!.isNotEmpty;

    Widget fallback() => Container(
          color: const Color(0xFF6B4A2C),
          alignment: Alignment.center,
          child: Text(
            story.authorName[0].toUpperCase(),
            style: GoogleFonts.playfairDisplay(
              fontSize: size * 0.44,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
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

/// The hero Instax/Polaroid card for one story in the full-screen viewer.
/// A large white frame with the photo and a handwritten caption on the lip.
class _ViewerInstax extends StatelessWidget {
  const _ViewerInstax({
    super.key,
    required this.config,
    required this.story,
  });

  final GastroThemeConfig config;
  final Story story;

  @override
  Widget build(BuildContext context) {
    final caption = story.caption?.trim() ?? '';
    final place = story.countryName?.trim() ?? '';

    final card = Container(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s12, GS.s12, GS.s20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GS.r4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      size: 40, color: Color(0xFF8B6A3D)),
                ),
              ),
            ),
          ),
          const SizedBox(height: GS.s16),

          // Handwritten caption on the white lip.
          Text(
            caption.isNotEmpty ? caption : 'a taste worth remembering',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.caveat(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              fontStyle:
                  caption.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: const Color(0xFF2E2A27),
              height: 1.15,
            ),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: GS.s8),
            Text(
              place.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B6A3D),
              ),
            ),
          ],
        ],
      ),
    );

    return Transform.rotate(
      angle: -0.02,
      child: card,
    )
        .animate()
        .fadeIn(duration: GS.fast, curve: GS.smooth)
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: GS.normal,
          curve: GS.smooth,
        );
  }
}
