import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Selectable filter chip used in Explore region filter, Vault filters,
/// Baku cuisine filter. Drop-in replacement for `_RegionChip`, `_FilterChips`,
/// and inline pill widgets.
class GastroChip extends StatelessWidget {
  const GastroChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.config,
    this.icon,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final GastroThemeConfig config;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hPad = compact ? GS.s10 : GS.s12;
    final vPad = compact ? GS.s6 : GS.s8;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GS.fast,
        curve: GS.smooth,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: selected ? config.accent : config.surface,
          borderRadius: BorderRadius.circular(GS.rPill),
          border: Border.all(
            color: selected ? config.accent : config.outlineVariant,
            width: 1,
          ),
          boxShadow: selected
              ? GS.shadow(color: config.accent, blur: 12, yOffset: 4, opacity: 0.25)
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 13 : 14,
                color: selected ? config.onPrimary : config.onSurfaceVariant,
              ),
              const SizedBox(width: GS.s6),
            ],
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: selected ? config.onPrimary : config.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
