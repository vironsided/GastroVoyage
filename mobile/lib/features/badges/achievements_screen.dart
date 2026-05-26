/// The "Hall of Stamps" — every possible badge in the app rendered as a
/// scrapbook of inked passport stamps. Earned badges appear in full colour;
/// locked ones remain as faded silhouettes with their unlock condition
/// scribbled underneath like a margin note.
///
/// Driven by:
///   * [kBadgeCatalogue]  → the full set of possible badges (client-owned).
///   * [badgesProvider]   → the earned set from `GET /badges`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/badges/data/badges_catalogue.dart';
import 'package:mobile/features/dashboard/widgets/scrapbook_bits.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/social/widgets/relative_time.dart';
import 'package:mobile/ui/ui.dart';

/// Top-level Achievements screen — `Scaffold + PaperBackdrop` containing the
/// header, filter strip and badge grid.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  /// `null` means "All categories".
  BadgeCategory? _filter;

  void _setFilter(BadgeCategory? c) {
    if (_filter == c) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = c);
  }

  Future<void> _refresh() async {
    ref.invalidate(badgesProvider);
    await ref.read(badgesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final badgesAsync = ref.watch(badgesProvider);

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.07,
        scratchCount: 6,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: config.accent,
            backgroundColor: config.surface,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    config: config,
                    badgesAsync: badgesAsync,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FilterStrip(
                    config: config,
                    selected: _filter,
                    onSelect: _setFilter,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: GS.s20)),
                badgesAsync.when(
                  loading: () => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: GS.s20),
                      child: GastroShimmerGrid(
                        config: config,
                        crossAxisCount: 3,
                        itemCount: 9,
                        aspectRatio: 0.75,
                      ),
                    ),
                  ),
                  error: (_, __) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GS.s20, 0, GS.s20, GS.s24),
                      child: GastroErrorCard(
                        config: config,
                        message:
                            'Could not load your stamps. Is the backend running?',
                        onRetry: _refresh,
                      ),
                    ),
                  ),
                  data: (earned) => _BadgeGrid(
                    config: config,
                    earned: earned,
                    filter: _filter,
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: GS.navBuffer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.config,
    required this.badgesAsync,
    required this.onBack,
  });

  final GastroThemeConfig config;
  final AsyncValue<List<CuisineBadge>> badgesAsync;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final total = kBadgeCatalogue.length;
    final unlocked = badgesAsync.valueOrNull
            ?.where((b) => b.earned)
            .where((b) => kBadgeCatalogue
                .any((d) => findEarned(d, [b]) != null))
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, GS.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: config.onSurface),
                onPressed: onBack,
                tooltip: 'Back',
              ),
              const Spacer(),
              _StampsCounter(
                config: config,
                unlocked: unlocked,
                total: total,
              ),
            ],
          ),
          const SizedBox(height: GS.s4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GS.s8),
            child: SectionHeader(
              label: 'Achievements',
              config: config,
              subtitle: 'The hall of stamps',
            ),
          ),
          const SizedBox(height: GS.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GS.s8),
            child: Text(
              'Achievements',
              style: GoogleFonts.playfairDisplay(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: GS.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GS.s8),
            child: Text(
              '$unlocked of $total stamps collected',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: config.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: GS.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GS.s8),
            child: StitchedDivider(config: config),
          ),
          const SizedBox(height: GS.s16),
        ],
      ),
    );
  }
}

class _StampsCounter extends StatelessWidget {
  const _StampsCounter({
    required this.config,
    required this.unlocked,
    required this.total,
  });

  final GastroThemeConfig config;
  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GS.s12, vertical: GS.s6),
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius: BorderRadius.circular(GS.r8),
          border: Border.all(color: config.accent.withOpacity(0.4), width: 1),
          boxShadow: GS.shadow(
            color: config.accent,
            blur: 14,
            yOffset: 4,
            opacity: 0.08,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.award, size: 14, color: config.accent),
            const SizedBox(width: GS.s6),
            Text(
              '$unlocked / $total',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: config.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter strip ────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.config,
    required this.selected,
    required this.onSelect,
  });

  final GastroThemeConfig config;
  final BadgeCategory? selected;
  final ValueChanged<BadgeCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: GS.s20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          GastroChip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelect(null),
            config: config,
            icon: LucideIcons.layers,
            compact: true,
          ),
          for (final c in BadgeCategory.values) ...[
            const SizedBox(width: GS.s8),
            GastroChip(
              label: c.label,
              selected: selected == c,
              onTap: () => onSelect(c),
              config: config,
              icon: c.icon,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Grid ────────────────────────────────────────────────────────────────────

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({
    required this.config,
    required this.earned,
    required this.filter,
  });

  final GastroThemeConfig config;
  final List<CuisineBadge> earned;
  final BadgeCategory? filter;

  @override
  Widget build(BuildContext context) {
    final defs = filter == null
        ? kBadgeCatalogue
        : kBadgeCatalogue.where((d) => d.category == filter).toList();

    if (defs.isEmpty) {
      // Defensive — every category has at least one badge, but if the catalogue
      // is ever trimmed we still want a graceful empty state.
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: GS.s20),
          child: GastroEmptyState(
            config: config,
            icon: LucideIcons.award,
            title: 'No badges here yet',
            subtitle: 'Pick a different category to keep exploring.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: GS.s16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: GS.s20,
          crossAxisSpacing: GS.s8,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final def = defs[i];
            final found = findEarned(def, earned);
            return _BadgeStamp(
              def: def,
              earned: found,
              config: config,
              index: i,
              onTap: () => _openSheet(context, def, found, config),
            )
                .animate()
                .fadeIn(
                  duration: GS.normal,
                  delay: GS.stagger(i.clamp(0, 8), ms: 35),
                  curve: GS.smooth,
                )
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: GS.normal,
                  delay: GS.stagger(i.clamp(0, 8), ms: 35),
                  curve: GS.spring,
                );
          },
          childCount: defs.length,
        ),
      ),
    );
  }

  void _openSheet(
    BuildContext context,
    BadgeDef def,
    CuisineBadge? earned,
    GastroThemeConfig config,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BadgeDetailSheet(
        def: def,
        earned: earned,
        config: config,
      ),
    );
  }
}

// ─── Stamp tile ──────────────────────────────────────────────────────────────

class _BadgeStamp extends StatelessWidget {
  const _BadgeStamp({
    required this.def,
    required this.earned,
    required this.config,
    required this.index,
    required this.onTap,
  });

  final BadgeDef def;
  final CuisineBadge? earned;
  final GastroThemeConfig config;
  final int index;
  final VoidCallback onTap;

  bool get _unlocked => earned != null;

  @override
  Widget build(BuildContext context) {
    final tilt = scrapbookTilt(index * 11 + 3, magnitude: 0.10);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_unlocked)
            _UnlockedCrest(def: def, config: config, tilt: tilt)
          else
            _LockedCrest(def: def, config: config, tilt: tilt * 0.4),
          const SizedBox(height: GS.s6),
          if (_unlocked)
            MarginNote(
              text: def.name,
              config: config,
              fontSize: 14,
              rotation: tilt * 0.4,
            )
          else
            Text(
              def.name.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: config.onSurfaceVariant.withOpacity(0.55),
                height: 1.1,
              ),
            ),
          if (!_unlocked) ...[
            const SizedBox(height: GS.s2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GS.s4),
              child: Text(
                def.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.caveat(
                  fontSize: 12,
                  color: config.onSurfaceVariant.withOpacity(0.55),
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlockedCrest extends StatelessWidget {
  const _UnlockedCrest({
    required this.def,
    required this.config,
    required this.tilt,
  });

  final BadgeDef def;
  final GastroThemeConfig config;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final color = _categoryAccent(def.category, config);

    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Backing wax-seal blob for a "pressed" look.
          Transform.rotate(
            angle: tilt,
            child: StampBadge(
              label: '',
              config: config,
              size: 86,
              shape: StampShape.circle,
              color: color,
              seed: def.id.hashCode,
              showInkLines: true,
            ),
          ),
          // The emoji / cuisine glyph in the middle of the stamp.
          Transform.rotate(
            angle: tilt,
            child: Text(
              def.cuisineCodeOrEmoji,
              style: const TextStyle(fontSize: 30, height: 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCrest extends StatelessWidget {
  const _LockedCrest({
    required this.def,
    required this.config,
    required this.tilt,
  });

  final BadgeDef def;
  final GastroThemeConfig config;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: config.surfaceVariant.withOpacity(0.55),
          border: Border.all(
            color: config.outlineVariant.withOpacity(0.55),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Faded silhouette of the symbol.
            Opacity(
              opacity: 0.28,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
                child: Text(
                  def.cuisineCodeOrEmoji,
                  style: const TextStyle(fontSize: 28, height: 1.0),
                ),
              ),
            ),
            // Lock badge bottom-right.
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: config.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: config.outlineVariant.withOpacity(0.7),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  LucideIcons.lock,
                  size: 10,
                  color: config.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail bottom sheet ────────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({
    required this.def,
    required this.earned,
    required this.config,
  });

  final BadgeDef def;
  final CuisineBadge? earned;
  final GastroThemeConfig config;

  bool get _unlocked => earned != null;

  @override
  Widget build(BuildContext context) {
    final color = _categoryAccent(def.category, config);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(GS.s16),
        padding: const EdgeInsets.fromLTRB(GS.s24, GS.s20, GS.s24, GS.s24),
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius: BorderRadius.circular(GS.r24),
          border: Border.all(color: config.outlineVariant, width: 0.5),
          boxShadow: GS.shadow(
            color: config.onSurface,
            blur: 24,
            yOffset: 12,
            opacity: 0.12,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle.
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: config.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: GS.s16),

            // Crest at the top.
            if (_unlocked)
              _UnlockedCrest(def: def, config: config, tilt: -0.04)
            else
              _LockedCrest(def: def, config: config, tilt: 0),
            const SizedBox(height: GS.s12),

            // Category pill.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: GS.s10, vertical: GS.s4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(GS.rPill),
              ),
              child: Text(
                def.category.label.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: GS.s12),

            // Name.
            Text(
              def.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
                height: 1.1,
              ),
            ),
            const SizedBox(height: GS.s6),

            // Earned-at line for unlocked badges.
            if (_unlocked && (earned?.earnedAt ?? '').isNotEmpty)
              Text(
                'Earned ${relativeTime(earned!.earnedAt)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.caveat(
                  fontSize: 18,
                  color: config.accent,
                  height: 1.0,
                ),
              )
            else if (_unlocked)
              Text(
                'Earned',
                textAlign: TextAlign.center,
                style: GoogleFonts.caveat(
                  fontSize: 18,
                  color: config.accent,
                  height: 1.0,
                ),
              ),
            const SizedBox(height: GS.s16),

            // Body / how to unlock.
            Text(
              def.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: config.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (!_unlocked) ...[
              const SizedBox(height: GS.s16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: GS.s12, vertical: GS.s10),
                decoration: BoxDecoration(
                  color: config.surfaceVariant.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(GS.r12),
                  border: Border.all(
                    color: config.outlineVariant.withOpacity(0.6),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.key,
                      size: 14,
                      color: config.onSurfaceVariant,
                    ),
                    const SizedBox(width: GS.s8),
                    Expanded(
                      child: Text(
                        'How to unlock: ${def.description.toLowerCase()}.',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          color: config.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: GS.s20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(
                  foregroundColor: config.accent,
                  padding:
                      const EdgeInsets.symmetric(vertical: GS.s12),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
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

// ─── Helpers ────────────────────────────────────────────────────────────────

Color _categoryAccent(BadgeCategory c, GastroThemeConfig config) {
  switch (c) {
    case BadgeCategory.regional: return config.accent;
    case BadgeCategory.streak:   return config.gold;
    case BadgeCategory.palate:   return config.primary;
    case BadgeCategory.social:   return config.accent;
    case BadgeCategory.journey:  return config.gold;
  }
}
