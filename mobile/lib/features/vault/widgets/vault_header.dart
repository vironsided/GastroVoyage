import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/vault/widgets/vault_filter_chips.dart';

/// Editorial masthead for the Vault — a "journal" kicker, a Playfair hero
/// title, an entry-count ticket, the open-passport CTA, and the filter row.
class VaultHeader extends StatelessWidget {
  const VaultHeader({
    super.key,
    required this.config,
    required this.entryCount,
    required this.onOpenPassport,
  });

  final GastroThemeConfig config;

  /// Null while loading / on error — hides the count ticket.
  final int? entryCount;

  final VoidCallback onOpenPassport;

  IconData _passportIcon() {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return LucideIcons.heart;
      case GastroThemeMode.couples:
        return LucideIcons.mail;
      case GastroThemeMode.guys:
        return LucideIcons.zap;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Masthead row ────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.bookMarked,
                        size: 12,
                        color: config.accent,
                      ),
                      const SizedBox(width: GS.s6),
                      Text(
                        'THE JOURNAL',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          letterSpacing: 2.4,
                          color: config.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GS.s6),
                  Text(
                    'Your Bites',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: GS.s2),
                  Text(
                    'a scrapbook of everywhere you have tasted',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: config.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _OpenPassportButton(
                  config: config,
                  icon: _passportIcon(),
                  onTap: onOpenPassport,
                ),
                if (entryCount != null) ...[
                  const SizedBox(height: GS.s8),
                  _EntryTicket(config: config, count: entryCount!),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: GS.s16),

        // ── Decorative editorial rule ───────────────────────────────────
        _StitchedRule(config: config),
        const SizedBox(height: GS.s16),

        // ── Filter chips ────────────────────────────────────────────────
        VaultFilterChips(config: config),
        const SizedBox(height: GS.s8),
      ],
    )
        .animate()
        .fadeIn(duration: GS.xslow, curve: GS.smooth)
        .slideY(begin: -0.06, end: 0, duration: GS.xslow, curve: GS.smooth);
  }
}

// ─── Open Passport CTA ────────────────────────────────────────────────────────

class _OpenPassportButton extends StatefulWidget {
  const _OpenPassportButton({
    required this.config,
    required this.icon,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_OpenPassportButton> createState() => _OpenPassportButtonState();
}

class _OpenPassportButtonState extends State<_OpenPassportButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: GS.fast,
        curve: GS.smooth,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GS.s12,
            vertical: GS.s10,
          ),
          decoration: BoxDecoration(
            color: config.primary,
            borderRadius: BorderRadius.circular(GS.r16),
            boxShadow: GS.shadow(
              color: config.primary,
              blur: 16,
              yOffset: 6,
              opacity: 0.30,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.bookOpen, color: config.onPrimary, size: 15),
              const SizedBox(width: GS.s6),
              Text(
                'Open Passport',
                style: GoogleFonts.hankenGrotesk(
                  color: config.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: GS.s6),
              Icon(
                widget.icon,
                size: 11,
                color: config.onPrimary.withOpacity(0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Entry-count ticket ───────────────────────────────────────────────────────

class _EntryTicket extends StatelessWidget {
  const _EntryTicket({required this.config, required this.count});

  final GastroThemeConfig config;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GS.s8,
        vertical: GS.s4,
      ),
      decoration: BoxDecoration(
        color: config.accentSoft.withOpacity(config.isDark ? 0.5 : 0.8),
        borderRadius: BorderRadius.circular(GS.r4),
        border: Border.all(
          color: config.accent.withOpacity(0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.stamp,
            size: 10,
            color: config.accent,
          ),
          const SizedBox(width: GS.s4),
          Text(
            '$count ${count == 1 ? 'entry' : 'entries'}',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: config.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stitched divider rule ────────────────────────────────────────────────────

class _StitchedRule extends StatelessWidget {
  const _StitchedRule({required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: CustomPaint(
        size: const Size(double.infinity, 4),
        painter: _StitchPainter(color: config.accent.withOpacity(0.40)),
      ),
    );
  }
}

/// A dashed "machine-stitch" line for the masthead divider.
class _StitchPainter extends CustomPainter {
  const _StitchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    const gap = 5.0;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_StitchPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Helper to derive the entry-count label from a visits async value, kept
/// here so the screen body stays terse.
int? entryCountFrom(AsyncValue<List<Visit>> visits) => visits.valueOrNull?.length;
