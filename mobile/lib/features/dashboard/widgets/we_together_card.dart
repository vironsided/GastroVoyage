import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/couples/data/couple_providers.dart';
import 'package:mobile/features/couples/my_couple_screen.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';

/// Dashboard hero card visible only to users with an active couple link.
///
/// Reads from [coupleStatsProvider] and self-hides when the response says
/// `active: false` (no link, or only a pending invite). Tapping opens the
/// MyCoupleScreen so the user can see perks, joint stats, and unlink.
class WeTogetherCard extends ConsumerWidget {
  const WeTogetherCard({super.key, required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(coupleStatsProvider);
    final stats = statsAsync.valueOrNull;
    if (stats == null || !stats.active || stats.partner == null) {
      // Hidden state — return an empty shrink so the parent Column collapses.
      return const SizedBox.shrink();
    }

    final partner = stats.partner!;
    final userInitial = (ref.read(authProvider).displayName ?? 'You')[0]
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: GS.s20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GS.r24),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MyCoupleScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(GS.s20, GS.s16, GS.s16, GS.s20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GS.r24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  config.accent.withOpacity(0.18),
                  config.accent.withOpacity(0.06),
                ],
              ),
              border: Border.all(color: config.accent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.heart, size: 14, color: config.accent),
                    const SizedBox(width: GS.s6),
                    Text(
                      'YOU & ${partner.name.toUpperCase()}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: config.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GS.s8),
                Row(
                  children: [
                    // Overlapping avatars — me on the left, partner on the right.
                    SizedBox(
                      width: 80,
                      height: 48,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SocialAvatar(
                            config: config,
                            initial: userInitial,
                            size: 48,
                            borderColor: config.accent,
                            borderWidth: 2,
                          ),
                          Positioned(
                            left: 32,
                            child: SocialAvatar(
                              config: config,
                              initial: partner.initial,
                              avatarUrl: partner.avatarUrl,
                              size: 48,
                              borderColor: config.accent,
                              borderWidth: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: GS.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We Together',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: config.onSurface,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _byline(stats.jointVisits),
                            style: GoogleFonts.caveat(
                              fontSize: 17,
                              color: config.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: config.onSurfaceVariant.withOpacity(0.7)),
                  ],
                ),
                const SizedBox(height: GS.s16),
                Row(
                  children: [
                    Expanded(child: _Stat(
                      label: 'joint bites',
                      value: '${stats.jointVisits}',
                      config: config,
                    )),
                    _VerticalRule(config: config),
                    Expanded(child: _Stat(
                      label: 'countries',
                      value: '${stats.jointCountries}',
                      config: config,
                    )),
                    _VerticalRule(config: config),
                    Expanded(child: _Stat(
                      label: 'cuisines',
                      value: '${stats.jointCuisines}',
                      config: config,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Friendly hand-drawn one-liner that nudges toward action when the count
  /// is low and celebrates the streak as it grows.
  static String _byline(int joint) {
    if (joint == 0) return "Tag your next bite as together to start the count.";
    if (joint == 1) return "One bite down, a whole world to share.";
    if (joint < 5) return "$joint plates eaten side by side.";
    if (joint < 12) return "Tasting the world together — keep going.";
    return "A serious joint streak. Look at you two.";
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.config,
  });

  final String label;
  final String value;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: config.onSurface,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            letterSpacing: 1.2,
            color: config.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: config.accent.withOpacity(0.25),
    );
  }
}
