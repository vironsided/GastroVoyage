import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/wrapped/data/wrapped_stats.dart';
import 'package:mobile/features/wrapped/wrapped_screen.dart';

/// Festive dashboard entry that opens the Culinary Wrapped reveal.
///
/// Hidden unless the user has logged enough visits to make the reveal
/// feel earned (≥ 5). Composes its own stats lazily on tap so the
/// reveal screen never starts on stale data.
class WrappedCard extends ConsumerWidget {
  const WrappedCard({super.key, required this.config});

  final GastroThemeConfig config;

  static const _minVisits = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsProvider);
    final visits = visitsAsync.asData?.value ?? const [];
    if (visits.length < _minVisits) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final v = ref.read(visitsProvider).asData?.value ?? const [];
          final b = ref.read(badgesProvider).asData?.value ?? const [];
          final stats = WrappedStats.compute(v, b);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WrappedScreen(stats: stats),
            fullscreenDialog: true,
          ));
        },
        borderRadius: BorderRadius.circular(GS.r20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(config.accent, config.surface, 0.10)!,
                Color.lerp(config.accent, config.onSurface, 0.20)!,
              ],
            ),
            borderRadius: BorderRadius.circular(GS.r20),
            boxShadow: [
              BoxShadow(
                color: config.accent.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(GS.s20, GS.s16, GS.s16, GS.s16),
          child: Row(
            children: [
              // Confetti / sparkle icon column.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(GS.r12),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: GS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CULINARY WRAPPED · ${DateTime.now().year}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your culinary year',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'tap to relive it',
                      style: GoogleFonts.caveat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.86),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight,
                  color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
