import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Empty-state widget for lists/grids that have no content yet.
/// Replaces `_EmptyState` from vault and `_PremiumEmptyState` from dashboard.
class GastroEmptyState extends StatelessWidget {
  const GastroEmptyState({
    super.key,
    required this.config,
    required this.icon,
    required this.title,
    this.subtitle,
    this.ctaLabel,
    this.onCtaTap,
  });

  final GastroThemeConfig config;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GS.s28),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: config.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: config.accent),
          ),
          const SizedBox(height: GS.s20),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: GS.s8),
            Text(
              subtitle!,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: config.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (ctaLabel != null && onCtaTap != null) ...[
            const SizedBox(height: GS.s20),
            TextButton(
              onPressed: onCtaTap,
              style: TextButton.styleFrom(
                foregroundColor: config.accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: GS.s20, vertical: GS.s12),
              ),
              child: Text(
                ctaLabel!,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
