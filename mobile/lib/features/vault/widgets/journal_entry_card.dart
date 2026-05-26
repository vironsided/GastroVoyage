import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/vault/widgets/washi_strip.dart';
import 'package:mobile/ui/ui.dart';

/// A single Vault entry rendered as a scrapbook clipping: a paper-textured
/// card pinned with a push-pin and washi tape, tilted a hair off-axis, with
/// an ink country stamp, hand-lettered notes and a torn-edge timeline.
///
/// Purely visual — wiring (tap / delete) is passed in from the screen.
class JournalEntryCard extends StatefulWidget {
  const JournalEntryCard({
    super.key,
    required this.visit,
    required this.isLast,
    required this.isFirst,
    required this.config,
    required this.index,
    required this.onDelete,
    required this.onTap,
  });

  final Visit visit;
  final bool isLast;
  final bool isFirst;
  final GastroThemeConfig config;
  final int index;
  final Future<void> Function() onDelete;
  final VoidCallback onTap;

  @override
  State<JournalEntryCard> createState() => _JournalEntryCardState();
}

class _JournalEntryCardState extends State<JournalEntryCard> {
  bool _pressed = false;

  /// Deterministic gentle tilt — alternates side so the column reads like a
  /// hand-pasted scrapbook rather than a rigid list.
  double get _tilt => widget.index.isEven ? -0.018 : 0.020;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final visit = widget.visit;
    final country = visit.country;
    final isoCode = country?.isoA2 ?? '??';
    final name = country?.name ?? 'Unknown';
    final region = country?.region ?? '';

    DateTime? dt;
    try {
      dt = DateTime.parse(visit.visitedOn);
    } catch (_) {}

    final month = dt != null ? DateFormat('MMM').format(dt).toUpperCase() : '';
    final day = dt != null ? DateFormat('d').format(dt) : '';
    final year = dt != null ? DateFormat('yyyy').format(dt) : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline date column ──────────────────────────────────────
          _TimelineColumn(
            config: config,
            month: month,
            day: day,
            year: year,
            isFirst: widget.isFirst,
            isLast: widget.isLast,
          ),
          const SizedBox(width: GS.s12),

          // ── Scrapbook card ────────────────────────────────────────────
          Expanded(
            child: Dismissible(
              key: Key(visit.id),
              direction: DismissDirection.endToStart,
              background: _DeleteBackground(config: config),
              confirmDismiss: (_) => _confirmDelete(context, name),
              onDismissed: (_) => widget.onDelete(),
              child: GestureDetector(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: GS.s20),
                  child: AnimatedScale(
                    scale: _pressed ? 0.97 : 1.0,
                    duration: GS.fast,
                    curve: GS.smooth,
                    child: Transform.rotate(
                      angle: _tilt,
                      child: _ClippingCard(
                        config: config,
                        isoCode: isoCode,
                        name: name,
                        region: region,
                        rating: visit.rating,
                        notes: visit.notes,
                        withPartner: visit.withPartner,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: GS.stagger(widget.index))
        .fadeIn(duration: GS.slow, curve: GS.smooth)
        .slideY(begin: 0.10, end: 0, duration: GS.slow, curve: GS.smooth)
        .scaleXY(begin: 0.96, end: 1.0, duration: GS.slow, curve: GS.smooth);
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    final config = widget.config;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GS.r20),
        ),
        title: Text(
          'Tear out this page?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: config.onSurface,
          ),
        ),
        content: Text(
          'This removes your visit to $name from the journal.',
          style: GoogleFonts.hankenGrotesk(color: config.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep it',
              style: GoogleFonts.hankenGrotesk(color: config.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: config.error),
            child: const Text('Tear out'),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline column ──────────────────────────────────────────────────────────

class _TimelineColumn extends StatelessWidget {
  const _TimelineColumn({
    required this.config,
    required this.month,
    required this.day,
    required this.year,
    required this.isFirst,
    required this.isLast,
  });

  final GastroThemeConfig config;
  final String month;
  final String day;
  final String year;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          // Push-pin marker — the timeline "node".
          SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: PushPinPainter(color: config.accent),
            ),
          ),
          const SizedBox(height: GS.s8),
          // Date plaque — a little aged-paper tag.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: GS.s4,
              vertical: GS.s6,
            ),
            decoration: BoxDecoration(
              color: config.accentSoft.withOpacity(config.isDark ? 0.5 : 0.7),
              borderRadius: BorderRadius.circular(GS.r8),
              border: Border.all(
                color: config.accent.withOpacity(0.20),
              ),
            ),
            child: Column(
              children: [
                Text(
                  month,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: config.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  day,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                    height: 1.0,
                  ),
                ),
                Text(
                  year,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: config.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Dashed thread connecting entries down the page.
          if (!isLast)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: GS.s4),
                child: CustomPaint(
                  size: const Size(2, double.infinity),
                  painter: _DashedThreadPainter(
                    color: config.accent.withOpacity(0.35),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A vertical hand-stitched-looking dashed thread for the timeline.
class _DashedThreadPainter extends CustomPainter {
  const _DashedThreadPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 5.0;
    final x = size.width / 2;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + dash).clamp(0, size.height)),
          paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedThreadPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─── The clipping card itself ─────────────────────────────────────────────────

class _ClippingCard extends StatelessWidget {
  const _ClippingCard({
    required this.config,
    required this.isoCode,
    required this.name,
    required this.region,
    required this.rating,
    required this.notes,
    required this.withPartner,
  });

  final GastroThemeConfig config;
  final String isoCode;
  final String name;
  final String region;
  final int rating;
  final String notes;

  /// Render a small "♥ with partner" chip under the title when this visit
  /// was tagged together with the current user's couple link.
  final bool withPartner;

  @override
  Widget build(BuildContext context) {
    // Paper tone — a touch warmer than the pure surface for a printed feel.
    final paper = config.isDark
        ? config.surface
        : Color.alphaBlend(
            config.accentSoft.withOpacity(0.22), config.surface);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Card body
        Container(
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(GS.r16),
            border: Border.all(color: config.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: config.accent
                    .withOpacity(config.isDark ? 0.12 : 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black
                    .withOpacity(config.isDark ? 0.22 : 0.05),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Faint paper grain behind the content.
              Positioned.fill(
                child: CustomPaint(
                  painter: PaperTexturePainter(
                    baseColor: paper,
                    grainOpacity: config.isDark ? 0.05 : 0.045,
                    scratchCount: 3,
                    vignette: false,
                  ),
                ),
              ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent spine.
                    Container(width: 4, color: config.accent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          GS.s16,
                          GS.s16,
                          GS.s16,
                          GS.s16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderRow(
                              config: config,
                              isoCode: isoCode,
                              name: name,
                              region: region,
                              rating: rating,
                            ),
                            if (withPartner)
                              Padding(
                                padding: const EdgeInsets.only(top: GS.s4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.favorite_rounded,
                                        size: 13, color: config.accent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'together with my partner',
                                      style: GoogleFonts.caveat(
                                        fontSize: 15,
                                        color: config.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (notes.isNotEmpty)
                              _NotesBlock(config: config, notes: notes),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Washi tape pinning the top-right corner of the clipping.
        Positioned(
          top: -8,
          right: GS.s24,
          child: WashiStrip(config: config),
        ),
      ],
    );
  }
}

// ─── Header row: country stamp + title + rating ───────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.config,
    required this.isoCode,
    required this.name,
    required this.region,
    required this.rating,
  });

  final GastroThemeConfig config;
  final String isoCode;
  final String name;
  final String region;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ink country stamp — slightly crooked like a real passport mark.
        StampBadge(
          label: isoCode,
          config: config,
          size: 48,
          shape: StampShape.roundedRect,
          seed: isoCode.hashCode,
          showInkLines: false,
          rotation: -0.06,
        ),
        const SizedBox(width: GS.s12),
        // Country + region.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                  height: 1.1,
                ),
              ),
              if (region.isNotEmpty) ...[
                const SizedBox(height: GS.s2),
                Text(
                  region.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: config.accent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: GS.s8),
        _RatingStars(config: config, rating: rating),
      ],
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.config, required this.rating});

  final GastroThemeConfig config;
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: i < rating ? config.gold : config.outlineVariant,
              ),
            ),
          ),
        ),
        const SizedBox(height: GS.s2),
        Text(
          '$rating/5',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            color: config.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Notes — torn paper note with handwritten font ────────────────────────────

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.config, required this.notes});

  final GastroThemeConfig config;
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: GS.s12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(GS.s12, GS.s10, GS.s12, GS.s10),
        decoration: BoxDecoration(
          color: config.gold.withOpacity(config.isDark ? 0.12 : 0.16),
          borderRadius: BorderRadius.circular(GS.r8),
          border: Border.all(
            color: config.gold.withOpacity(0.28),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.quote,
              size: 13,
              color: config.accent.withOpacity(0.6),
            ),
            const SizedBox(width: GS.s8),
            Expanded(
              child: Text(
                notes,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.caveat(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: config.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Swipe-to-delete background ───────────────────────────────────────────────

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: GS.s24, bottom: GS.s20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: GS.s16,
          vertical: GS.s10,
        ),
        decoration: BoxDecoration(
          color: config.error,
          borderRadius: BorderRadius.circular(GS.r12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.scissors,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: GS.s6),
            Text(
              'TEAR OUT',
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
