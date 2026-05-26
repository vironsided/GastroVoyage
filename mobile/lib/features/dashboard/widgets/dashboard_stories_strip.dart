import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/widgets/share_to_feed_sheet.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';
import 'package:mobile/features/social/widgets/story_bubble.dart';
import 'package:mobile/features/social/widgets/story_viewer.dart';
import 'package:mobile/ui/ui.dart';

/// Instagram-style horizontal stories strip for the dashboard.
///
/// Sits right under the editorial header. The first bubble is always the
/// current user's own avatar with a "+" badge — tapping it starts the
/// add-a-story flow. After it come one bubble per OTHER author who has a
/// story in [feedProvider], newest-author-first; tapping one opens that
/// author's stories in the full-screen viewer.
///
/// The strip never breaks the dashboard: while the feed loads it shows the
/// "+" bubble plus shimmer placeholders, and on error it falls back to just
/// the "+" bubble so the social feature stays discoverable.
class DashboardStoriesStrip extends ConsumerWidget {
  const DashboardStoriesStrip({super.key});

  /// Fixed strip height — bubble + label + a little breathing room.
  /// Exposed so the dashboard can size the bounding box that hosts it.
  static const double stripOuterHeight = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUserId = ref.watch(authProvider.select((s) => s.userId));

    final strip = SizedBox(
      height: stripOuterHeight,
      child: feedAsync.when(
        data: (stories) => _StripList(
          config: config,
          stories: stories,
          currentUserId: currentUserId,
        ),
        loading: () => _StripList(
          config: config,
          stories: const [],
          currentUserId: currentUserId,
          showShimmer: true,
        ),
        // On error, never break the dashboard — just show the "+" bubble.
        error: (_, __) => _StripList(
          config: config,
          stories: const [],
          currentUserId: currentUserId,
        ),
      ),
    );

    return strip
        .animate()
        .fadeIn(duration: GS.normal, curve: GS.smooth)
        .slideX(begin: -0.04, end: 0, duration: GS.normal, curve: GS.smooth);
  }
}

/// The horizontal list itself — kept separate so each [AsyncValue] branch can
/// reuse it with different inputs.
class _StripList extends ConsumerWidget {
  const _StripList({
    required this.config,
    required this.stories,
    required this.currentUserId,
    this.showShimmer = false,
  });

  final GastroThemeConfig config;
  final List<Story> stories;
  final String? currentUserId;
  final bool showShimmer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group stories by author, dropping the current user's own stories — the
    // "Your story" bubble already represents them. First appearance wins,
    // and the feed is newest-first, so author order is newest-first too.
    final authorOrder = <String>[];
    final firstIndexOf = <String, int>{};
    for (var i = 0; i < stories.length; i++) {
      final uid = stories[i].userId;
      if (uid.isEmpty || uid == currentUserId) continue;
      if (!firstIndexOf.containsKey(uid)) {
        firstIndexOf[uid] = i;
        authorOrder.add(uid);
      }
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: GS.s20),
      children: [
        // ── Bubble 0: the user's own "add a story" bubble ──────────────────
        _AddStoryBubble(config: config),

        // ── Loading: a couple of shimmer bubbles ───────────────────────────
        if (showShimmer)
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(width: GS.s12),
            _ShimmerBubble(config: config),
          ],

        // ── One bubble per other author with stories ───────────────────────
        for (final uid in authorOrder) ...[
          const SizedBox(width: GS.s12),
          Builder(
            builder: (context) {
              final story = stories[firstIndexOf[uid]!];
              // That author's stories, in feed (newest-first) order.
              final authorStories =
                  stories.where((s) => s.userId == uid).toList();
              return StoryBubble(
                config: config,
                name: story.authorName,
                initial: story.authorName[0].toUpperCase(),
                avatarUrl: story.avatarUrl,
                onTap: () => showStoryViewer(
                  context,
                  config: config,
                  stories: authorStories,
                  initialIndex: 0,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// The current user's own bubble — their avatar wrapped in a dashed ink ring
/// with a small accent "+" badge. Tapping it runs the add-a-story flow.
class _AddStoryBubble extends ConsumerStatefulWidget {
  const _AddStoryBubble({required this.config});
  final GastroThemeConfig config;

  @override
  ConsumerState<_AddStoryBubble> createState() => _AddStoryBubbleState();
}

class _AddStoryBubbleState extends ConsumerState<_AddStoryBubble> {
  static const double _size = 66;
  bool _busy = false;

  /// Pick a photo → upload → caption sheet → create story → refresh feed.
  Future<void> _addStory() async {
    if (_busy) return;
    HapticFeedback.selectionClick();

    final messenger = ScaffoldMessenger.of(context);
    final config = widget.config;

    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      // Picker unavailable / permission denied — fail quietly with a note.
      _snack(messenger, config, 'Could not open your photos.', isError: true);
      return;
    }
    // User cancelled the picker — nothing to do.
    if (picked == null) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);

      // 1) Upload the picked photo to get a hosted URL. Pass the XFile
      // directly so the upload works on both native and web (where
      // `File.fromUri(blob:...)` is not supported).
      final photoUrl = await api.uploadPhoto(picked);
      if (!mounted) return;

      // 2) Caption sheet — null means the user dismissed it.
      final caption = await ShareToFeedSheet.show(
        context,
        config: config,
        photoUrl: photoUrl,
      );
      if (caption == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;

      // 3) Publish the story.
      await api.createStory(
        photoUrl: photoUrl,
        caption: caption.isEmpty ? null : caption,
        countryId: null,
      );
      if (!mounted) return;

      // 4) Refresh the feed so the new story surfaces immediately.
      ref.invalidate(feedProvider);
      _snack(messenger, config, 'Your story is live on the feed.');
    } on UnauthorizedException {
      _snack(messenger, config, 'Your session expired. Please sign in again.',
          isError: true);
    } catch (_) {
      _snack(messenger, config, 'Could not share your story. Try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Themed scrapbook-style SnackBar.
  void _snack(
    ScaffoldMessengerState messenger,
    GastroThemeConfig config,
    String message, {
    bool isError = false,
  }) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? config.error : config.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GS.r12),
          ),
          content: Text(
            message,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final auth = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);

    final displayName = (auth.displayName?.trim().isNotEmpty ?? false)
        ? auth.displayName!.trim()
        : 'You';
    final initial = displayName[0].toUpperCase();
    final avatarUrl = profileAsync.asData?.value.avatarUrl;

    return GestureDetector(
      onTap: _addStory,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _size + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _size,
              height: _size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Avatar in a dashed ring, dimmed while the flow runs.
                  Opacity(
                    opacity: _busy ? 0.5 : 1,
                    child: CustomPaint(
                      painter: _AddRingPainter(color: config.accent),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: SocialAvatar(
                          config: config,
                          initial: initial,
                          avatarUrl: avatarUrl,
                          size: _size - 8,
                          borderColor: config.surface,
                          borderWidth: 2,
                        ),
                      ),
                    ),
                  ),
                  // Spinner while uploading / posting.
                  if (_busy)
                    Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: config.accent,
                          ),
                        ),
                      ),
                    ),
                  // "+" badge, bottom-right.
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: config.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: config.surface, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GS.s6),
            Text(
              'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: config.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed circular ring around the "Your story" bubble — same hand-inked
/// stamp look as [StoryBubble]'s ring so the strip reads as one set.
class _AddRingPainter extends CustomPainter {
  const _AddRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashes = 24;
    const sweep = 6.283185307179586 / dashes;
    const gap = sweep * 0.42;
    for (var i = 0; i < dashes; i++) {
      final start = i * sweep + gap / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AddRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Placeholder bubble shown while [feedProvider] is loading.
class _ShimmerBubble extends StatelessWidget {
  const _ShimmerBubble({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    const size = 66.0;
    return SizedBox(
      width: size + 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GastroShimmer(
              config: config, width: size, height: size, radius: size / 2),
          const SizedBox(height: GS.s6),
          GastroShimmer(
              config: config, width: 40, height: 9, radius: GS.r4),
        ],
      ),
    );
  }
}
