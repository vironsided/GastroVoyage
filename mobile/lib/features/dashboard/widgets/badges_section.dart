import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/badges/achievements_screen.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/ui/ui.dart';

import 'scrapbook_bits.dart';

/// "Achievements" section — earned achievements are rendered as inked
/// passport stamps pressed onto the page; locked ones stay as faint chips.
class BadgesWall extends StatelessWidget {
  const BadgesWall({
    super.key,
    required this.badges,
    required this.config,
  });

  final List<CuisineBadge> badges;
  final GastroThemeConfig config;

  void _openAchievements(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openAchievements(context),
        child: _NoBadgesNote(config: config),
      );
    }

    // Earned stamps first (the "trophy wall"), then the locked chips.
    final earned = <CuisineBadge>[];
    final locked = <CuisineBadge>[];
    for (final b in badges) {
      (b.earned ? earned : locked).add(b);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openAchievements(context),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earned.isNotEmpty)
          Wrap(
            spacing: GS.s12,
            runSpacing: GS.s16,
            children: [
              for (var i = 0; i < earned.length; i++)
                _EarnedStamp(badge: earned[i], config: config, index: i)
                    .animate(delay: GS.stagger(i, ms: 60))
                    .fadeIn(duration: GS.normal, curve: GS.smooth)
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: GS.normal,
                      curve: GS.spring,
                    ),
            ],
          ),
        if (earned.isNotEmpty && locked.isNotEmpty) ...[
          const SizedBox(height: GS.s20),
          Row(
            children: [
              Text(
                'STILL TO COLLECT',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8,
                  letterSpacing: 1.6,
                  color: config.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: GS.s8),
              Expanded(child: StitchedDivider(config: config)),
            ],
          ),
          const SizedBox(height: GS.s12),
        ],
        if (locked.isNotEmpty)
          Wrap(
            spacing: GS.s8,
            runSpacing: GS.s8,
            children: [
              for (var i = 0; i < locked.length; i++)
                _LockedChip(badge: locked[i], config: config)
                    .animate(delay: GS.stagger(i, ms: 35))
                    .fadeIn(duration: GS.normal, curve: GS.smooth),
            ],
          ),
        const SizedBox(height: GS.s12),
        _ViewAllAffordance(config: config),
      ],
      ),
    );
  }
}

/// Subtle "View all stamps →" hint at the bottom of the dashboard's
/// achievements section. Indicates the whole section is tappable.
class _ViewAllAffordance extends StatelessWidget {
  const _ViewAllAffordance({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'VIEW ALL STAMPS',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: config.accent.withOpacity(0.85),
          ),
        ),
        const SizedBox(width: GS.s4),
        Icon(
          LucideIcons.arrowRight,
          size: 12,
          color: config.accent.withOpacity(0.85),
        ),
      ],
    );
  }
}

/// An earned achievement as a circular ink stamp pressed onto the page,
/// slightly crooked with a handwritten title beneath.
class _EarnedStamp extends StatelessWidget {
  const _EarnedStamp({
    required this.badge,
    required this.config,
    required this.index,
  });

  final CuisineBadge badge;
  final GastroThemeConfig config;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tilt = scrapbookTilt(index + 5, magnitude: 0.16);

    return Tooltip(
      message: badge.description,
      child: SizedBox(
        width: 86,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StampBadge(
              label: badge.title,
              config: config,
              size: 78,
              shape: StampShape.circle,
              icon: badge.iconData,
              color: config.gold,
              seed: index * 3 + 1,
              rotation: tilt,
            ),
            const SizedBox(height: GS.s4),
            MarginNote(
              text: badge.title,
              config: config,
              fontSize: 14,
              rotation: tilt * 0.5,
            ),
          ],
        ),
      ),
    );
  }
}

/// A not-yet-earned achievement — a faint, flat chip with a lock cue.
class _LockedChip extends StatelessWidget {
  const _LockedChip({required this.badge, required this.config});

  final CuisineBadge badge;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GS.s12, vertical: GS.s8),
        decoration: BoxDecoration(
          color: config.surfaceVariant.withOpacity(0.6),
          borderRadius: BorderRadius.circular(GS.rPill),
          border: Border.all(
            color: config.outlineVariant.withOpacity(0.6),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badge.iconData,
              size: 12,
              color: config.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(width: GS.s6),
            Text(
              badge.title,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: config.onSurfaceVariant.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBadgesNote extends StatelessWidget {
  const _NoBadgesNote({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GS.s20),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined,
              size: 18, color: config.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(width: GS.s8),
          Expanded(
            child: MarginNote(
              text: 'No stamps in the book yet — go taste the world!',
              config: config,
              fontSize: 16,
              rotation: -0.02,
            ),
          ),
        ],
      ),
    );
  }
}
