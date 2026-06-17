import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/badges/achievements_screen.dart';

/// Compact Home affordance for Achievements.
///
/// The full stamp wall is now canonically on the You tab, so Home shows a
/// one-line summary that taps through instead of duplicating the wall.
class AchievementsLinkCard extends StatelessWidget {
  const AchievementsLinkCard({
    super.key,
    required this.config,
    required this.earnedCount,
  });

  final GastroThemeConfig config;
  final int earnedCount;

  @override
  Widget build(BuildContext context) {
    final label =
        earnedCount == 1 ? '1 stamp earned' : '$earnedCount stamps earned';
    return Semantics(
      button: true,
      label: 'View all achievements',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GS.r16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AchievementsScreen()),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: config.surface,
              borderRadius: BorderRadius.circular(GS.r16),
              border: Border.all(color: config.onSurface.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: GS.s16, vertical: GS.s14),
              child: Row(
                children: [
                  const Text('🏅', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: GS.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Achievements',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: config.onSurface,
                          ),
                        ),
                        Text(
                          label,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: config.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight,
                      size: 18,
                      color: config.onSurfaceVariant.withOpacity(0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
