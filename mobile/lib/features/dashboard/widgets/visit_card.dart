import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/ui/ui.dart';

import 'scrapbook_bits.dart';

/// Horizontal carousel of "Recently Tasted" visit clippings — each visit is
/// styled as a polaroid pinned to the scrapbook page with washi tape and a
/// push-pin, gently tilted for a hand-placed feel.
class VisitsCarousel extends StatelessWidget {
  const VisitsCarousel({
    super.key,
    required this.visits,
    required this.config,
  });

  final List<Visit> visits;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    // Extra top room for the push-pin / tape that overhang the polaroid,
    // and side room so the rotated corners are not clipped.
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: GS.s12),
        itemCount: visits.length,
        separatorBuilder: (_, __) => const SizedBox(width: GS.s16),
        itemBuilder: (_, i) => VisitClipping(
          visit: visits[i],
          config: config,
          index: i,
        )
            .animate(delay: GS.stagger(i))
            .fadeIn(duration: GS.slow, curve: GS.smooth)
            .slideX(begin: 0.14, end: 0, duration: GS.slow, curve: GS.smooth)
            .slideY(begin: -0.05, end: 0, duration: GS.slow, curve: GS.spring),
      ),
    );
  }
}

/// A single visit rendered as a polaroid clipping. Photo on top, a paper
/// caption strip below with the country name (handwritten), ISO stamp,
/// inked star rating and the date — pinned with a push-pin.
class VisitClipping extends StatelessWidget {
  const VisitClipping({
    super.key,
    required this.visit,
    required this.config,
    required this.index,
  });

  final Visit visit;
  final GastroThemeConfig config;
  final int index;

  @override
  Widget build(BuildContext context) {
    final country = visit.country;
    final isoCode = country?.isoA2 ?? '??';
    final countryName = country?.name ?? 'Unknown';
    final region = country?.region ?? '';
    // The polaroid shows the visit's own uploaded photo. `country.photoUrl`
    // is never populated on the /visits payload, so read the visit directly.
    final photo = visit.photoPath;
    final hasPhoto = photo != null && photo.isNotEmpty;

    DateTime? dt;
    try {
      dt = DateTime.parse(visit.visitedOn);
    } catch (_) {}
    final dateStr = dt != null ? DateFormat('MMM d').format(dt) : '';

    final tilt = scrapbookTilt(index, magnitude: 0.045);

    const cardW = 168.0;
    const photoH = 158.0;

    final polaroid = Container(
      width: cardW,
      padding: const EdgeInsets.fromLTRB(GS.s8, GS.s8, GS.s8, GS.s10),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r4),
        border: Border.all(color: config.outlineVariant, width: 0.5),
        boxShadow: GS.shadow(
          color: Colors.black,
          blur: 18,
          yOffset: 8,
          opacity: config.isDark ? 0.40 : 0.16,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo window ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(GS.r4),
            child: SizedBox(
              width: cardW - GS.s16,
              height: photoH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhoto)
                    CachedNetworkImage(
                      imageUrl: photo!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _PhotoPlaceholder(
                          isoCode: isoCode, config: config),
                      errorWidget: (_, __, ___) => _PhotoPlaceholder(
                          isoCode: isoCode, config: config),
                    )
                  else
                    _PhotoPlaceholder(isoCode: isoCode, config: config),

                  // Soft bottom scrim so the ISO stamp stays legible.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.42),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ISO country stamp — bottom-left of the photo.
                  Positioned(
                    left: GS.s6,
                    bottom: GS.s6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: GS.s6, vertical: GS.s2),
                      decoration: BoxDecoration(
                        color: config.accent,
                        borderRadius: BorderRadius.circular(GS.r4),
                      ),
                      child: Text(
                        isoCode,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Date chip — top-right of the photo.
                  if (dateStr.isNotEmpty)
                    Positioned(
                      top: GS.s6,
                      right: GS.s6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: GS.s6, vertical: GS.s2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(GS.rPill),
                        ),
                        child: Text(
                          dateStr.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: GS.s8),

          // ── Caption strip (the polaroid's thick bottom) ─────────────────
          Text(
            countryName,
            style: GoogleFonts.caveat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
              height: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: GS.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  region.toUpperCase(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7.5,
                    color: config.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkStars(rating: visit.rating, size: 11),
            ],
          ),
        ],
      ),
    );

    // Pin / tape decoration overhanging the top of the polaroid. Alternating
    // by index keeps the page lively. The Stack lets the decoration overhang
    // without affecting layout height (extra room reserved by the carousel).
    final useTape = index.isEven;

    return Transform.rotate(
      angle: tilt,
      child: SizedBox(
        width: cardW + 24,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: GS.s10),
              child: polaroid,
            ),
            if (useTape)
              Positioned(
                top: -2,
                child: WashiTape(
                  config: config,
                  width: 58,
                  height: 20,
                  rotation: -0.12,
                  pattern: WashiPattern.stripes,
                ),
              )
            else
              Positioned(
                top: -8,
                child: SizedBox(
                  width: 26,
                  height: 30,
                  child: CustomPaint(
                    painter: PushPinPainter(color: config.accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.isoCode, required this.config});
  final String isoCode;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [config.accentSoft, config.surfaceVariant],
        ),
      ),
      child: Center(
        child: Text(
          isoCode,
          style: GoogleFonts.playfairDisplay(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: config.accent.withOpacity(0.30),
          ),
        ),
      ),
    );
  }
}
