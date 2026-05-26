import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/social/data/social_models.dart';

/// Compact follow-state pill used on every user row.
///
/// Renders by [status]:
///   none     → filled "Follow"      (tap = follow)
///   pending  → outlined "Requested" (tap = cancel request)
///   accepted → ghost "Following"    (tap = unfollow)
///
/// While [busy] the pill shows a spinner and ignores taps.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.config,
    required this.status,
    required this.onPressed,
    this.busy = false,
  });

  final GastroThemeConfig config;
  final FollowStatus status;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    final Color background;
    final Color foreground;
    final Color border;

    switch (status) {
      case FollowStatus.none:
        label = 'Follow';
        icon = LucideIcons.userPlus;
        background = config.accent;
        foreground = Colors.white;
        border = config.accent;
      case FollowStatus.pending:
        label = 'Requested';
        icon = LucideIcons.clock;
        background = Colors.transparent;
        foreground = config.onSurfaceVariant;
        border = config.outlineVariant;
      case FollowStatus.accepted:
        label = 'Following';
        icon = LucideIcons.check;
        background = config.accentSoft;
        foreground = config.accent;
        border = config.accentSoft;
    }

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onPressed,
        child: AnimatedContainer(
          duration: GS.fast,
          curve: GS.smooth,
          height: 34,
          constraints: const BoxConstraints(minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: GS.s12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(GS.rPill),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: foreground),
                      const SizedBox(width: GS.s6),
                      Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
