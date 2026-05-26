import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// A paper "declaration slip" search field for the customs-hall Explore screen.
///
/// Reads like a form line off an immigration card: a small `DECLARE` monospace
/// caption, a dotted-underline write-in field with a search glyph, and a faint
/// paper body with a torn-ish double shadow. Behaviour is unchanged — it still
/// just forwards [onChanged].
class DeclarationSearch extends StatelessWidget {
  const DeclarationSearch({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final GastroThemeConfig config;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s10, GS.s12, GS.s12),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r8),
        border: Border.all(
          color: config.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(config.isDark ? 0.32 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(config.isDark ? 0.14 : 0.03),
            blurRadius: 26,
            offset: const Offset(-2, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // form caption line
          Row(
            children: [
              Text(
                'DECLARE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: config.accent,
                ),
              ),
              const SizedBox(width: GS.s6),
              Expanded(
                child: Text(
                  'a country or region of interest',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                    color: config.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GS.s2),
          // write-in line with a dotted underline
          Row(
            children: [
              Icon(
                LucideIcons.search,
                size: 17,
                color: config.onSurfaceVariant.withOpacity(0.7),
              ),
              const SizedBox(width: GS.s8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: config.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: TextField(
                    onChanged: onChanged,
                    cursorColor: config.accent,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: config.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'write here…',
                      hintStyle: GoogleFonts.caveat(
                        fontSize: 18,
                        color: config.onSurfaceVariant.withOpacity(0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.only(bottom: GS.s6, top: GS.s2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
