import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

enum GastroButtonVariant { filled, outlined, ghost }

/// Themed primary button used across login, account, dish detail.
/// Drop-in replacement for the various private `_GastroButton`,
/// `_ActionButton`, `_SignOutButton`, `_BeginButton` widgets that used to
/// live inside individual screens.
class GastroButton extends StatelessWidget {
  const GastroButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.config,
    this.icon,
    this.isLoading = false,
    this.variant = GastroButtonVariant.filled,
    this.fullWidth = true,
    this.height = 52,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final GastroThemeConfig config;
  final IconData? icon;
  final bool isLoading;
  final GastroButtonVariant variant;
  final bool fullWidth;
  final double height;

  /// Override the accent. Defaults to `config.accent`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? config.accent;
    final enabled = onPressed != null && !isLoading;

    final Color background;
    final Color foreground;
    final BoxBorder? border;
    final List<BoxShadow> shadows;

    switch (variant) {
      case GastroButtonVariant.filled:
        background = enabled ? accent : accent.withOpacity(0.35);
        foreground = Colors.white;
        border = null;
        shadows = enabled
            ? GS.shadow(color: accent, blur: 24, yOffset: 10, opacity: 0.35)
            : const [];
      case GastroButtonVariant.outlined:
        background = Colors.transparent;
        foreground = accent;
        border = Border.all(color: accent.withOpacity(enabled ? 0.7 : 0.3), width: 1.5);
        shadows = const [];
      case GastroButtonVariant.ghost:
        background = Colors.transparent;
        foreground = config.onSurfaceVariant;
        border = null;
        shadows = const [];
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(GS.r16),
            border: border,
            boxShadow: shadows,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(GS.r16),
            splashColor: Colors.white.withOpacity(0.15),
            highlightColor: Colors.white.withOpacity(0.08),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: foreground,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: foreground),
                          const SizedBox(width: GS.s10),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: foreground,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
