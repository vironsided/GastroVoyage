import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Editorial section label: small uppercase monospace title + an optional
/// inline subtitle, with a short underline accent. This is the canonical
/// "newspaper" header used across dashboard, vault, account.
///
/// For larger hero titles use `DisplayHeader` (below).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    required this.config,
    this.subtitle,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final GastroThemeConfig config;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 2.0,
                color: config.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(width: GS.s8),
              Expanded(
                child: Text(
                  subtitle!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: config.onSurfaceVariant.withOpacity(0.7),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: GS.s6),
        Container(
          width: 28,
          height: 1,
          color: config.accent.withOpacity(0.35),
        ),
      ],
    );
  }
}

/// Large editorial title with Playfair Display. Use for hero sections and
/// screen titles, not for in-page section dividers.
class DisplayHeader extends StatelessWidget {
  const DisplayHeader({
    super.key,
    required this.title,
    required this.config,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final GastroThemeConfig config;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                  height: 1.1,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: GS.s6),
          Text(
            subtitle!,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              color: config.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );
  }
}
