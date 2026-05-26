import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/vault/widgets/washi_strip.dart';
import 'package:mobile/ui/ui.dart';

/// Scrapbook empty-state for the Vault: a blank tilted polaroid pinned with
/// washi tape, ringed by a postage-style stamp and an editorial caption —
/// "your first page is waiting".
class VaultEmptyState extends StatelessWidget {
  const VaultEmptyState({super.key, required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Blank polaroid pinned to the page ─────────────────────────
            SizedBox(
              height: 200,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Empty instax frame — the "first photo to be taken".
                  InstaxFrame(
                    config: config,
                    width: 150,
                    photoHeight: 122,
                    rotation: -0.05,
                    caption: 'first bite?',
                    placeholder: Container(
                      color: config.accentSoft.withOpacity(0.6),
                      child: Icon(
                        config.mode == GastroThemeMode.guys
                            ? LucideIcons.zap
                            : LucideIcons.utensilsCrossed,
                        size: 34,
                        color: config.accent.withOpacity(0.55),
                      ),
                    ),
                  ),
                  // Washi tape across the top.
                  Positioned(
                    top: 2,
                    child: WashiStrip(
                      config: config,
                      width: 88,
                      height: 26,
                      rotation: -0.08,
                    ),
                  ),
                  // A little ink stamp tucked behind the corner.
                  Positioned(
                    right: 24,
                    bottom: 6,
                    child: StampBadge(
                      label: 'NEW',
                      config: config,
                      size: 56,
                      shape: StampShape.circle,
                      rotation: 0.22,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: GS.slow, curve: GS.smooth)
                .scaleXY(begin: 0.88, end: 1.0, duration: GS.slow, curve: GS.spring),

            const SizedBox(height: GS.s32),

            // ── Editorial caption ─────────────────────────────────────────
            Text(
              'A BLANK PAGE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 3.0,
                color: config.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: GS.s8),
            Text(
              'No entries yet',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
            const SizedBox(height: GS.s12),
            Text(
              'Every culinary journey starts\nwith a single bite. Log one to\nbegin your scrapbook.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: config.onSurfaceVariant,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GS.s20),

            // ── Hairline divider with center dot ──────────────────────────
            SizedBox(
              width: 120,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: config.accent.withOpacity(0.22),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: GS.s8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: config.accent.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: config.accent.withOpacity(0.22),
                    ),
                  ),
                ],
              ),
            ),
          ]
              .animate(interval: 70.ms)
              .fadeIn(duration: GS.normal, curve: GS.smooth)
              .slideY(begin: 0.12, end: 0, duration: GS.normal, curve: GS.smooth),
        ),
      ),
    );
  }
}
