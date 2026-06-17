import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Inline error card with an optional retry action.
/// Drop-in replacement for the various `_ErrorCard` widgets across screens.
class GastroErrorCard extends StatelessWidget {
  const GastroErrorCard({
    super.key,
    required this.config,
    this.message,
    this.icon = LucideIcons.wifiOff,
    this.onRetry,
  });

  final GastroThemeConfig config;
  final String? message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GS.s20),
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(color: config.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: config.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(width: GS.s12),
          Expanded(
            child: Text(
              message ?? "Couldn't connect right now. Check your connection and try again.",
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: config.onSurfaceVariant,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: GS.s12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: config.accent,
                padding: const EdgeInsets.symmetric(horizontal: GS.s12),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
