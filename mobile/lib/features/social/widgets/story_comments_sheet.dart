import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/widgets/relative_time.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';
import 'package:mobile/ui/ui.dart';

/// The handwritten-comments thread for one story. Opens as a draggable
/// scrapbook bottom sheet — Playfair header, Caveat sub-line, list of comment
/// rows, and a sticky input row at the bottom.
///
/// Shape mirrors [StoryViewersSheet]: floating card with a grab handle, soft
/// shadow, palette from [GastroThemeConfig]. Optimistic-append on send so the
/// row appears the instant the user taps the paper-plane.
class StoryCommentsSheet extends ConsumerStatefulWidget {
  const StoryCommentsSheet({
    super.key,
    required this.config,
    required this.storyId,
    required this.storyOwnerId,
    this.ownerName,
  });

  final GastroThemeConfig config;
  final String storyId;

  /// The story owner's id — used to flag rows where the owner can also delete
  /// (alongside the commenter themselves) so the trailing icon shows up.
  final String storyOwnerId;

  /// Owner's display name, used for the sheet subtitle ("on Maya's story").
  final String? ownerName;

  @override
  ConsumerState<StoryCommentsSheet> createState() =>
      _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends ConsumerState<StoryCommentsSheet> {
  /// Server-side cap on comment length. Surfaced as the input counter and as
  /// the `maxLength` on the [TextField] itself.
  static const int _maxCommentLength = 280;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Optimistic local pile — rows we've appended on send but haven't yet
  /// confirmed with the server. They're merged on top of the provider's list
  /// in render; on confirmation we invalidate the provider so the merged
  /// view collapses back to a single source of truth.
  final List<StoryComment> _pendingAppends = <StoryComment>[];

  /// Ids we've optimistically removed (delete-pending). Filtered out of the
  /// merged list at render time; cleared once the server confirms.
  final Set<String> _pendingDeletes = <String>{};

  /// True while a send is in flight. Disables the send button and the input
  /// to prevent a double-submit if the user double-taps the paper-plane.
  bool _sending = false;

  @override
  void dispose() {
    // Invalidate the feed so the per-story comment-count pill picks up any
    // new rows the user just added (or removed). Cheap — the feed is small
    // and the next read is rate-limited by Riverpod.
    Future.microtask(() {
      if (!mounted) return;
      ref.invalidate(feedProvider);
    });
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _sending) return;
    if (raw.length > _maxCommentLength) return;

    HapticFeedback.selectionClick();
    setState(() => _sending = true);

    // Synthesise an optimistic row using the signed-in user's profile so the
    // append feels instant. The id is a transient marker — on confirmation we
    // drop the optimistic row and the server one takes over via the provider
    // invalidate below. AuthState doesn't carry an avatar url today, so the
    // optimistic row falls back to the initial-letter disc; once the server
    // confirms, the real avatar threads in.
    final me = ref.read(authProvider);
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = StoryComment(
      id: tempId,
      actorUserId: me.userId ?? '',
      displayName: me.displayName,
      text: raw,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    setState(() {
      _pendingAppends.add(optimistic);
      _controller.clear();
    });

    try {
      await ref.read(apiClientProvider).commentOnStory(widget.storyId, raw);
      if (!mounted) return;
      // Drop the optimistic row and pull a fresh list — the real row is now
      // canonical and carries the server id needed for delete.
      setState(() {
        _pendingAppends.removeWhere((c) => c.id == tempId);
      });
      ref.invalidate(storyCommentsProvider(widget.storyId));
    } catch (e) {
      if (!mounted) return;
      // Roll back the optimistic row and restore the input so the user can
      // retry. Show a themed snack on the same surface as the sheet.
      setState(() {
        _pendingAppends.removeWhere((c) => c.id == tempId);
        _controller.text = raw;
      });
      // Heuristic surface for the "table missing" case: the backend turns a
      // missing `story_comments` table into a 503; everything else (network
      // glitches, validation, etc.) gets the generic retry copy.
      final message = e.toString().contains('503')
          ? "Comments aren't enabled yet — try again later"
          : "Couldn't post — try again in a moment";
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(StoryComment c) async {
    if (c.id.isEmpty || c.id.startsWith('pending-')) return;
    HapticFeedback.selectionClick();

    setState(() => _pendingDeletes.add(c.id));

    try {
      await ref.read(apiClientProvider).deleteStoryComment(c.id);
      if (!mounted) return;
      // The server confirmed; pull a fresh thread to drop the row for good.
      setState(() => _pendingDeletes.remove(c.id));
      ref.invalidate(storyCommentsProvider(widget.storyId));
    } catch (_) {
      if (!mounted) return;
      // Restore the row — the delete failed, so the user should see it again.
      setState(() => _pendingDeletes.remove(c.id));
      _showSnack('Couldn\'t delete — try again in a moment');
    }
  }

  void _showSnack(String message) {
    final config = widget.config;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: config.onSurface,
          content: Text(
            message,
            style: GoogleFonts.hankenGrotesk(
              color: config.surface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  /// Merges the provider's snapshot with the optimistic pile and removes any
  /// pending-delete ids, returning the list as it should render right now.
  List<StoryComment> _mergeRows(List<StoryComment> serverRows) {
    final merged = <StoryComment>[];
    for (final row in serverRows) {
      if (_pendingDeletes.contains(row.id)) continue;
      merged.add(row);
    }
    merged.addAll(_pendingAppends);
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final commentsAsync =
        ref.watch(storyCommentsProvider(widget.storyId));
    final me = ref.watch(authProvider.select((s) => s.userId)) ?? '';
    final media = MediaQuery.of(context);
    // The sheet is taller than the viewers sheet because of the input row.
    final maxHeight = media.size.height * 0.82;

    return Container(
      margin: EdgeInsets.only(
        left: GS.s12,
        right: GS.s12,
        bottom: GS.s12 + media.viewInsets.bottom,
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s12, GS.s20, GS.s16),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grab handle.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: GS.s12),
              decoration: BoxDecoration(
                color: config.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row: title + the live comment count.
          Row(
            children: [
              Icon(
                LucideIcons.messageCircle,
                size: 18,
                color: config.accent,
              ),
              const SizedBox(width: GS.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface,
                      ),
                    ),
                    if (widget.ownerName != null &&
                        widget.ownerName!.trim().isNotEmpty)
                      Text(
                        'on ${widget.ownerName}\'s story',
                        style: GoogleFonts.caveat(
                          fontSize: 16,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              _CountPill(
                config: config,
                count: commentsAsync.maybeWhen(
                  data: (r) => _mergeRows(r).length,
                  orElse: () => null,
                ),
              ),
            ],
          ),

          const SizedBox(height: GS.s12),

          // Body: scrollable list.
          Flexible(
            child: commentsAsync.when(
              loading: () => _LoadingList(config: config),
              error: (_, __) => GastroErrorCard(
                config: config,
                message: 'Could not load comments',
                onRetry: () =>
                    ref.invalidate(storyCommentsProvider(widget.storyId)),
              ),
              data: (serverRows) {
                final rows = _mergeRows(serverRows);
                if (rows.isEmpty) {
                  return GastroEmptyState(
                    config: config,
                    icon: LucideIcons.messageCircle,
                    title: 'No comments yet',
                    subtitle:
                        'Be the first to leave a handwritten note on this story.',
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => Divider(
                    height: GS.s16,
                    thickness: 0.5,
                    color: config.outlineVariant,
                  ),
                  itemBuilder: (_, i) {
                    final c = rows[i];
                    // The signed-in user can delete their OWN row OR any row
                    // on a story they own. Pending optimistic rows have a
                    // sentinel id and can't be deleted until the server
                    // confirms.
                    final canDelete = c.id.startsWith('pending-')
                        ? false
                        : (c.actorUserId == me || widget.storyOwnerId == me);
                    return _CommentRow(
                      config: config,
                      comment: c,
                      canDelete: canDelete,
                      onDelete: () => _delete(c),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: GS.s12),
          Divider(
            height: 1,
            thickness: 0.5,
            color: config.outlineVariant,
          ),
          const SizedBox(height: GS.s12),

          // ── Sticky input row ─────────────────────────────────────────
          _ComposerRow(
            config: config,
            controller: _controller,
            focusNode: _focusNode,
            sending: _sending,
            maxLength: _maxCommentLength,
            onSubmit: _send,
          ),
        ],
      ),
    );
  }
}

// ─── Composer ────────────────────────────────────────────────────────────────

class _ComposerRow extends StatefulWidget {
  const _ComposerRow({
    required this.config,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.maxLength,
    required this.onSubmit,
  });

  final GastroThemeConfig config;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final int maxLength;
  final Future<void> Function() onSubmit;

  @override
  State<_ComposerRow> createState() => _ComposerRowState();
}

class _ComposerRowState extends State<_ComposerRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final text = widget.controller.text;
    final length = text.length;
    final hasContent = text.trim().isNotEmpty;
    final overLimit = length > widget.maxLength;
    final canSend = hasContent && !overLimit && !widget.sending;

    // Caveat-styled handwritten input. The TextField sits in a soft pill so it
    // reads as a scrapbook note slipped under the thread. Counter sits below
    // when the user is close to the cap (>= 240) — keeps the row uncluttered
    // for short comments.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: GS.s12, vertical: GS.s4),
                decoration: BoxDecoration(
                  color: config.surfaceVariant,
                  borderRadius: BorderRadius.circular(GS.r20),
                  border: Border.all(
                    color: overLimit
                        ? config.error.withOpacity(0.6)
                        : config.outlineVariant,
                    width: overLimit ? 1.2 : 0.5,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  // Hard cap at the server limit — the server still validates,
                  // this is just a friendly client clamp.
                  maxLength: widget.maxLength,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (canSend) widget.onSubmit();
                  },
                  style: GoogleFonts.caveat(
                    fontSize: 20,
                    color: config.onSurface,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'leave a handwritten note…',
                    hintStyle: GoogleFonts.caveat(
                      fontSize: 19,
                      color: config.onSurfaceVariant.withOpacity(0.7),
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: GS.s10),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ),
            const SizedBox(width: GS.s8),
            _SendButton(
              config: config,
              enabled: canSend,
              sending: widget.sending,
              onTap: () {
                if (canSend) widget.onSubmit();
              },
            ),
          ],
        ),
        // Counter — appears once the user is in the last quarter of the cap.
        if (length >= widget.maxLength - 40)
          Padding(
            padding: const EdgeInsets.only(top: GS.s6, right: GS.s4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$length / ${widget.maxLength}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: overLimit
                      ? config.error
                      : config.onSurfaceVariant.withOpacity(0.85),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.config,
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final bool enabled;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = enabled
        ? config.accent
        : config.surfaceVariant.withOpacity(config.isDark ? 0.5 : 0.8);
    final fg = enabled ? config.onPrimary : config.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 28,
        child: AnimatedContainer(
          duration: GS.fast,
          curve: GS.smooth,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: config.outlineVariant, width: 0.5),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: config.accent.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: sending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fg),
                  ),
                )
              : Icon(LucideIcons.send, size: 18, color: fg),
        ),
      ),
    );
  }
}

// ─── Comment row ─────────────────────────────────────────────────────────────

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.config,
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final GastroThemeConfig config;
  final StoryComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPending = comment.id.startsWith('pending-');
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SocialAvatar(
          config: config,
          initial: comment.initial,
          avatarUrl: comment.avatarUrl,
          size: 36,
        ),
        const SizedBox(width: GS.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: GS.s8),
                  Text(
                    isPending ? 'posting…' : relativeTime(comment.createdAt),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      letterSpacing: 1.0,
                      color: config.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GS.s4),
              Text(
                comment.text,
                style: GoogleFonts.caveat(
                  fontSize: 19,
                  color: config.onSurface,
                  height: 1.15,
                  fontStyle:
                      isPending ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
        if (canDelete)
          Padding(
            padding: const EdgeInsets.only(left: GS.s8),
            child: _DeleteButton(config: config, onTap: onDelete),
          ),
      ],
    );

    if (isPending) {
      // Soft fade-in for the optimistic row so the append feels deliberate.
      // Apply animate() directly on the Row itself — no Expanded/Flexible
      // wrapper here, so this is safe.
      return body
          .animate()
          .fadeIn(duration: GS.fast, curve: GS.smooth)
          .slideY(
              begin: 0.05, end: 0, duration: GS.fast, curve: GS.smooth);
    }
    return body;
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.config, required this.onTap});

  final GastroThemeConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: config.surfaceVariant,
            border: Border.all(color: config.outlineVariant, width: 0.5),
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.trash2,
            size: 14,
            color: config.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Count pill ──────────────────────────────────────────────────────────────

class _CountPill extends StatelessWidget {
  const _CountPill({required this.config, required this.count});

  final GastroThemeConfig config;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (count == null) return const SizedBox.shrink();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: GS.s10, vertical: GS.s4),
      decoration: BoxDecoration(
        color: config.accentSoft,
        borderRadius: BorderRadius.circular(GS.rPill),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: config.accent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Loading skeleton ────────────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: GS.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GastroShimmer(
                  config: config,
                  height: 36,
                  width: 36,
                  radius: 18,
                ),
                const SizedBox(width: GS.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GastroShimmer(
                          config: config,
                          height: 12,
                          width: 120,
                          radius: 6),
                      const SizedBox(height: GS.s6),
                      GastroShimmer(
                          config: config,
                          height: 14,
                          width: 220,
                          radius: 6),
                      const SizedBox(height: GS.s4),
                      GastroShimmer(
                          config: config,
                          height: 14,
                          width: 160,
                          radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Entry point ─────────────────────────────────────────────────────────────

/// Opens [StoryCommentsSheet] for [storyId]. Resolves the active
/// [GastroThemeConfig] from the ambient Riverpod scope so callers don't have
/// to thread it through. Returns when the sheet is dismissed.
Future<void> showStoryCommentsSheet(
  BuildContext context, {
  required String storyId,
  required String storyOwnerId,
  String? ownerName,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final config = container.read(gastroThemeConfigProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Lift the sheet above the keyboard automatically; the inner widget
    // already pads for `media.viewInsets.bottom`.
    builder: (_) => StoryCommentsSheet(
      config: config,
      storyId: storyId,
      storyOwnerId: storyOwnerId,
      ownerName: ownerName,
    ),
  );
}
