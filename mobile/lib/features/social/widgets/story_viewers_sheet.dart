import 'package:flutter/material.dart';
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

/// Which tab the [StoryViewersSheet] should open on.
enum StoryViewersSheetTab { viewers, reactions }

/// Bottom sheet listing every viewer and every reaction on one of the
/// current user's stories. Owner-only on the backend; non-owners can't open
/// it because the viewer only renders the "Seen by N · 🍴 ❤️" pill on the
/// caller's own stories.
///
/// Shape mirrors `ShareToFeedSheet` — floating card with a grab handle, soft
/// shadow, scrapbook palette via [GastroThemeConfig]. The body is a two-tab
/// segmented control: VIEWERS / REACTIONS.
class StoryViewersSheet extends ConsumerStatefulWidget {
  const StoryViewersSheet({
    super.key,
    required this.config,
    required this.storyId,
    this.ownerName,
    this.initialTab = StoryViewersSheetTab.viewers,
  });

  final GastroThemeConfig config;
  final String storyId;

  /// Owner's display name, used for the sheet subtitle ("on Maya's story").
  final String? ownerName;

  /// Which tab to open on. Tapping the reactions side of the owner-pill
  /// passes [StoryViewersSheetTab.reactions]; the eye taps default to
  /// [StoryViewersSheetTab.viewers].
  final StoryViewersSheetTab initialTab;

  @override
  ConsumerState<StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends ConsumerState<StoryViewersSheet> {
  late StoryViewersSheetTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final viewersAsync = ref.watch(storyViewersProvider(widget.storyId));
    final reactionsAsync = ref.watch(storyReactionsProvider(widget.storyId));
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.75;

    return Container(
      margin: EdgeInsets.only(
        left: GS.s12,
        right: GS.s12,
        bottom: GS.s12 + media.viewInsets.bottom,
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s12, GS.s20, GS.s20),
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

          // Header row: title + the live count of the active tab.
          Row(
            children: [
              Icon(
                _tab == StoryViewersSheetTab.viewers
                    ? LucideIcons.eye
                    : LucideIcons.heart,
                size: 18,
                color: config.accent,
              ),
              const SizedBox(width: GS.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tab == StoryViewersSheetTab.viewers
                          ? 'Seen by'
                          : 'Reactions',
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
                count: _tab == StoryViewersSheetTab.viewers
                    ? viewersAsync.maybeWhen(
                        data: (r) => r.length, orElse: () => null)
                    : reactionsAsync.maybeWhen(
                        data: (r) => r.length, orElse: () => null),
              ),
            ],
          ),

          const SizedBox(height: GS.s12),

          // Segmented tabs: VIEWERS / REACTIONS.
          _TabBar(
            config: config,
            active: _tab,
            onChanged: (next) => setState(() => _tab = next),
          ),

          const SizedBox(height: GS.s16),

          // Body: routes to the right list based on the active tab.
          Flexible(
            child: switch (_tab) {
              StoryViewersSheetTab.viewers => _ViewersList(
                  config: config,
                  storyId: widget.storyId,
                  asyncValue: viewersAsync,
                ),
              StoryViewersSheetTab.reactions => _ReactionsList(
                  config: config,
                  storyId: widget.storyId,
                  asyncValue: reactionsAsync,
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ─── Segmented tab bar ───────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.config,
    required this.active,
    required this.onChanged,
  });

  final GastroThemeConfig config;
  final StoryViewersSheetTab active;
  final ValueChanged<StoryViewersSheetTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.rPill),
        border: Border.all(color: config.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabBarButton(
              config: config,
              label: 'VIEWERS',
              icon: LucideIcons.eye,
              isActive: active == StoryViewersSheetTab.viewers,
              onTap: () => onChanged(StoryViewersSheetTab.viewers),
            ),
          ),
          Expanded(
            child: _TabBarButton(
              config: config,
              label: 'REACTIONS',
              icon: LucideIcons.heart,
              isActive: active == StoryViewersSheetTab.reactions,
              onTap: () => onChanged(StoryViewersSheetTab.reactions),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarButton extends StatelessWidget {
  const _TabBarButton({
    required this.config,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GS.rPill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: GS.fast,
          curve: GS.smooth,
          padding:
              const EdgeInsets.symmetric(vertical: GS.s8, horizontal: GS.s10),
          decoration: BoxDecoration(
            color: isActive ? config.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(GS.rPill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color:
                    isActive ? config.onPrimary : config.onSurfaceVariant,
              ),
              const SizedBox(width: GS.s6),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color:
                      isActive ? config.onPrimary : config.onSurfaceVariant,
                ),
              ),
            ],
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

// ─── Viewers list (existing behaviour, refactored to a child widget) ─────────

class _ViewersList extends ConsumerWidget {
  const _ViewersList({
    required this.config,
    required this.storyId,
    required this.asyncValue,
  });

  final GastroThemeConfig config;
  final String storyId;
  final AsyncValue<List<StoryViewerEntry>> asyncValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      loading: () => _LoadingList(config: config),
      error: (_, __) => GastroErrorCard(
        config: config,
        message: 'Could not load viewers',
        onRetry: () => ref.invalidate(storyViewersProvider(storyId)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return GastroEmptyState(
            config: config,
            icon: LucideIcons.eye,
            title: 'No one\'s peeked yet',
            subtitle:
                'When someone opens your story, they\'ll show up here.',
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
          itemBuilder: (_, i) => _ViewerRow(
            config: config,
            entry: rows[i],
          ),
        );
      },
    );
  }
}

// ─── Reactions list ──────────────────────────────────────────────────────────

class _ReactionsList extends ConsumerWidget {
  const _ReactionsList({
    required this.config,
    required this.storyId,
    required this.asyncValue,
  });

  final GastroThemeConfig config;
  final String storyId;
  final AsyncValue<List<StoryReaction>> asyncValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncValue.when(
      loading: () => _LoadingList(config: config),
      error: (_, __) => GastroErrorCard(
        config: config,
        message: 'Could not load reactions',
        onRetry: () => ref.invalidate(storyReactionsProvider(storyId)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return GastroEmptyState(
            config: config,
            icon: LucideIcons.heart,
            title: 'No reactions yet',
            subtitle:
                'When someone reacts to your story, you\'ll see it here.',
          );
        }

        // Compute a tiny summary strip: top emoji + counts. Surfaces at the
        // top of the list as a scrapbook-style "tally".
        final tally = <String, int>{};
        for (final r in rows) {
          if (r.emoji.isEmpty) continue;
          tally[r.emoji] = (tally[r.emoji] ?? 0) + 1;
        }
        final summary = tally.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          shrinkWrap: true,
          children: [
            if (summary.isNotEmpty)
              _ReactionTallyStrip(config: config, tally: summary),
            for (var i = 0; i < rows.length; i++) ...[
              _ReactionRow(config: config, entry: rows[i]),
              if (i != rows.length - 1)
                Divider(
                  height: GS.s16,
                  thickness: 0.5,
                  color: config.outlineVariant,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ReactionTallyStrip extends StatelessWidget {
  const _ReactionTallyStrip({required this.config, required this.tally});

  final GastroThemeConfig config;
  final List<MapEntry<String, int>> tally;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GS.s12),
      child: Wrap(
        spacing: GS.s8,
        runSpacing: GS.s8,
        children: [
          for (final e in tally.take(6))
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: GS.s12, vertical: GS.s6),
              decoration: BoxDecoration(
                color: config.surfaceVariant,
                borderRadius: BorderRadius.circular(GS.rPill),
                border:
                    Border.all(color: config.outlineVariant, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: GS.s6),
                  Text(
                    '${e.value}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
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

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({required this.config, required this.entry});

  final GastroThemeConfig config;
  final StoryReaction entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SocialAvatar(
          config: config,
          initial: entry.initial,
          avatarUrl: entry.avatarUrl,
          size: 40,
        ),
        const SizedBox(width: GS.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relativeTime(entry.createdAt),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  color: config.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: GS.s8),
        Text(
          entry.emoji,
          style: const TextStyle(fontSize: 26),
        ),
      ],
    );
  }
}

// ─── Shared list scaffolding ─────────────────────────────────────────────────

/// Shimmer placeholder for a few rows of viewers / reactions while the
/// network call lands.
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
              children: [
                GastroShimmer(
                  config: config,
                  height: 40,
                  width: 40,
                  radius: 20,
                ),
                const SizedBox(width: GS.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GastroShimmer(
                          config: config, height: 12, width: 140, radius: 6),
                      const SizedBox(height: GS.s6),
                      GastroShimmer(
                          config: config, height: 10, width: 80, radius: 6),
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

/// One row in the "Seen by" list: avatar + name + relative timestamp.
class _ViewerRow extends StatelessWidget {
  const _ViewerRow({required this.config, required this.entry});

  final GastroThemeConfig config;
  final StoryViewerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SocialAvatar(
          config: config,
          initial: entry.initial,
          avatarUrl: entry.avatarUrl,
          size: 40,
        ),
        const SizedBox(width: GS.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relativeTime(entry.viewedAt),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  color: config.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens [StoryViewersSheet] for [storyId]. Resolves the active
/// [GastroThemeConfig] from the ambient Riverpod scope so callers don't have
/// to thread it through. Returns when the sheet is dismissed.
Future<void> showStoryViewersSheet(
  BuildContext context, {
  required String storyId,
  String? ownerName,
  StoryViewersSheetTab initialTab = StoryViewersSheetTab.viewers,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final config = container.read(gastroThemeConfigProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StoryViewersSheet(
      config: config,
      storyId: storyId,
      ownerName: ownerName,
      initialTab: initialTab,
    ),
  );
}
