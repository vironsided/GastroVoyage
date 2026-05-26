import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/passport/painters/paper_texture_painter.dart';
import 'package:mobile/ui/painters/scrapbook_painters.dart';
import 'package:mobile/features/shared/models.dart';

// Journal ink palette — kept local for tonal consistency with the stamp page.
const _kInk = Color(0xFF2E2A27);
const _kInkBrown = Color(0xFF6B4A2C);
const _kGoldInk = Color(0xFFB98A3D);

class DetailsPage extends StatelessWidget {
  const DetailsPage({
    super.key,
    required this.visit,
    this.photoUrl,
    this.dishName,
  });

  final Visit visit;
  /// Food / national dish image (TheMealDB), not the country polaroid.
  final String? photoUrl;
  final String? dishName;

  @override
  Widget build(BuildContext context) {
    final country = visit.country;
    final countryName = country?.name ?? 'Unknown';
    DateTime? dt;
    try {
      dt = DateTime.parse(visit.visitedOn);
    } catch (_) {}
    final dateStr =
        dt != null ? DateFormat('d MMMM yyyy').format(dt) : visit.visitedOn;
    final region = country?.region ?? '';

    final tags = _extractTags(visit.notes, region);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: PaperTexturePainter(
              seed: visit.id.hashCode + 99,
              baseColor: const Color(0xFFFAF2E2),
              darken: 0.9,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: RuledLinesPainter(spacing: 28),
            ),
          ),
        ),
        // Spine-side gutter shadow (left edge) — pairs with the stamp page.
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.12),
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 70,
          right: 8,
          child: Transform.rotate(
            angle: 0.04,
            child: SizedBox(
              width: 36,
              height: 80,
              child: CustomPaint(
                painter: BotanicalSprigPainter(
                  color: const Color(0xFF9A6BB5),
                  seed: visit.id.hashCode + 5,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 20,
          right: 8,
          child: Transform.rotate(
            angle: 0.06,
            child: SizedBox(
              width: 64,
              height: 16,
              child: CustomPaint(
                painter: WashiTapePainter(
                  color: const Color(0xFFE0BF7A),
                  pattern: WashiPattern.stripes,
                ),
              ),
            ),
          ),
        ),

        // Paper-clipped corner accent on the upper-left margin.
        Positioned(
          top: -8,
          left: 24,
          child: SizedBox(
            width: 22,
            height: 50,
            child: CustomPaint(painter: PaperClipPainter()),
          ),
        ),

        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MemoryHeader(label: 'MEMORY CAPTURED', subtitle: dateStr),
                const SizedBox(height: GS.s8),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    countryName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      height: 1.0,
                    ),
                  ),
                ).animate().fadeIn(duration: GS.normal).slideX(
                      begin: -0.08,
                      end: 0,
                      curve: GS.smooth,
                      duration: GS.normal,
                    ),
                const SizedBox(height: GS.s4),
                // Tapered editorial rule under the country name.
                Container(
                  height: 2,
                  width: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _kGoldInk,
                        _kGoldInk.withOpacity(0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(GS.r4),
                  ),
                ),
                const SizedBox(height: GS.s8),

                // Visit photo glued in as a passport-style "visa photo" at the
                // upper-left, with the country fields reflowed to the right.
                _VisaPhotoRow(
                  visitPhotoUrl: visit.photoPath,
                  countryInitial: countryName.isNotEmpty
                      ? countryName[0].toUpperCase()
                      : '?',
                  seed: visit.id.hashCode,
                  fields: [
                    _FieldRow(label: 'COUNTRY', value: countryName),
                    _FieldRow(
                        label: 'REGION', value: region.isEmpty ? '—' : region),
                    if (dishName != null && dishName!.isNotEmpty)
                      _FieldRow(label: 'DISH TRIED', value: dishName!),
                    _FieldRow(label: 'DATE', value: dateStr),
                    _FieldRow(
                      label: 'RATING',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < visit.rating
                                ? Icons.star
                                : Icons.star_outline,
                            color: const Color(0xFFB98A3D),
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (photoUrl != null && photoUrl!.isNotEmpty)
                  SizedBox(
                    height: _DishPhotoCard.outerHeight,
                    width: double.infinity,
                    child: _DishPhotoCard(imageUrl: photoUrl!)
                        .animate()
                        .fadeIn(duration: GS.normal, delay: GS.fast)
                        .scale(
                          begin: const Offset(0.96, 0.96),
                          end: const Offset(1, 1),
                          curve: GS.smooth,
                          duration: GS.normal,
                          delay: GS.fast,
                        ),
                  )
                else
                  _NoPhotoCard(
                    label: dishName ?? countryName,
                    subtitle: 'dish photo',
                  ),

                const SizedBox(height: GS.s8),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('MY REVIEW'),
                        const SizedBox(height: GS.s8),
                        // Hanging quotation mark — magazine pull-quote feel.
                        Stack(
                          children: [
                            Positioned(
                              left: -4,
                              top: -14,
                              child: Text(
                                '“',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 44,
                                  color: _kGoldInk.withOpacity(0.3),
                                  height: 1,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: GS.s12),
                              child: Text(
                                visit.notes.trim().isEmpty
                                    ? 'A taste worth remembering. The flavors of $countryName lingered long after the last bite.'
                                    : visit.notes,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 17,
                                  color: _kInk,
                                  fontStyle: visit.notes.trim().isEmpty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: GS.s16),

                        const _SectionLabel('TAGS'),
                        const SizedBox(height: GS.s8),
                        Wrap(
                          spacing: GS.s6,
                          runSpacing: GS.s6,
                          children: tags.map((t) => _Tag(label: t)).toList(),
                        ),
                        const SizedBox(height: GS.s16),

                        Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              size: 13,
                              color: _kInkBrown,
                            ),
                            const SizedBox(width: GS.s4),
                            Expanded(
                              child: Text(
                                '$countryName${region.isNotEmpty ? ', $region' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _kInkBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: GS.s12),
                        Center(
                          child: Opacity(
                            opacity: 0.5,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'SWIPE TO NEXT COUNTRY',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 7.5,
                                    color: const Color(0xFF5C3A1E),
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                const SizedBox(height: GS.s4),
                                Text(
                                  '~ end of entry ~',
                                  style: GoogleFonts.caveat(
                                    fontSize: 15,
                                    color: const Color(0xFF5C3A1E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: GS.s8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          bottom: 28,
          right: 22,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.12,
              child: SizedBox(
                width: 70,
                height: 36,
                child: CustomPaint(
                  painter: StampBorderPainter(
                    color: const Color(0xFFA8472D),
                    shape: StampShape.roundedRect,
                    seed: visit.id.hashCode + 21,
                    strokeWidth: 1.6,
                  ),
                  child: Center(
                    child: Text(
                      'VISITED',
                      style: GoogleFonts.specialElite(
                        fontSize: 11,
                        color: const Color(0xFFA8472D),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: GS.fast, delay: GS.normal)
                .scale(
                  begin: const Offset(1.5, 1.5),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: GS.normal,
                  delay: GS.normal,
                ),
          ),
        ),
      ],
    );
  }

  List<String> _extractTags(String notes, String region) {
    final defaults = ['Authentic', 'Traditional', 'Cozy', 'Must Try'];
    if (notes.isEmpty) return defaults;
    final n = notes.toLowerCase();
    final hits = <String>[];
    if (n.contains('spicy')) hits.add('Spicy');
    if (n.contains('sweet')) hits.add('Sweet');
    if (n.contains('street')) hits.add('Street Food');
    if (n.contains('luxury') || n.contains('fine')) hits.add('Fine Dining');
    if (n.contains('cozy') || n.contains('warm')) hits.add('Cozy');
    if (n.contains('local')) hits.add('Local');
    if (n.contains('rich') || n.contains('flavor')) hits.add('Flavorful');
    if (hits.isEmpty) return defaults;
    if (region.isNotEmpty) hits.add(region);
    return hits.take(5).toList();
  }
}

class _MemoryHeader extends StatelessWidget {
  const _MemoryHeader({required this.label, required this.subtitle});
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 1.5,
          color: _kGoldInk,
        ),
        const SizedBox(width: GS.s8),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: _kGoldInk,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: GS.s6),
        Flexible(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: _kInkBrown.withOpacity(0.7),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Editorial section label — mono caps with a short tick rule beneath.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kInkBrown,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: GS.s6),
        Container(
          width: 26,
          height: 1.4,
          color: _kInkBrown.withOpacity(0.55),
        ),
      ],
    );
  }
}

/// Fixed-height dish snapshot so the photo is never clipped by the page edge.
class _DishPhotoCard extends StatelessWidget {
  const _DishPhotoCard({required this.imageUrl});
  final String imageUrl;

  static const _framePadding = 5.0;
  static const _imageHeight = 98.0;
  static const outerHeight = _framePadding * 2 + _imageHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: -0.02,
            child: Container(
              width: double.infinity,
              height: outerHeight,
              padding: const EdgeInsets.all(_framePadding),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF8EF),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    memCacheHeight: 280,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFE8E0D0)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFE8E0D0),
                      alignment: Alignment.center,
                      child: const Icon(Icons.restaurant,
                          size: 36, color: Color(0xFF8B6A3D)),
                    ),
                  ),
                  // Soft glossy-photo sheen.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.14),
                            Colors.transparent,
                            Colors.black.withOpacity(0.08),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Washi-tape strips pinning the snapshot to the journal.
          Positioned(
            top: 1,
            left: 14,
            child: Transform.rotate(
              angle: -0.32,
              child: SizedBox(
                width: 44,
                height: 13,
                child: CustomPaint(
                  painter: WashiTapePainter(
                    color: const Color(0xFFE8A0B4),
                    pattern: WashiPattern.solid,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 1,
            right: 14,
            child: Transform.rotate(
              angle: 0.32,
              child: SizedBox(
                width: 44,
                height: 13,
                child: CustomPaint(
                  painter: WashiTapePainter(
                    color: const Color(0xFFE8A0B4),
                    pattern: WashiPattern.solid,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, this.value, this.trailing})
      : assert(value != null || trailing != null);
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: _kInkBrown,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 0.8,
                    color: const Color(0xFF6B4A2C).withOpacity(0.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 2),
                  child: value != null
                      ? Text(
                          value!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.caveat(
                            fontSize: 18,
                            color: const Color(0xFF2E2A27),
                            height: 1.0,
                          ),
                        )
                      : trailing!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6B4A2C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(GS.rPill),
        border: Border.all(
          color: _kInkBrown.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: _kGoldInk.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: GS.s6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: _kInkBrown,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// Visa-style visit photo glued to the upper-left of the country fields. When
/// there is no visit photo, the fields take the full width and the photo slot
/// collapses gracefully — the layout reads the same with or without a photo.
class _VisaPhotoRow extends StatelessWidget {
  const _VisaPhotoRow({
    required this.visitPhotoUrl,
    required this.countryInitial,
    required this.seed,
    required this.fields,
  });

  final String? visitPhotoUrl;
  final String countryInitial;
  final int seed;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = visitPhotoUrl != null && visitPhotoUrl!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPhoto)
          _VisaVisitPhoto(
            imageUrl: visitPhotoUrl!,
            countryInitial: countryInitial,
            seed: seed,
          ),
        if (hasPhoto) const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields,
          ),
        ),
      ],
    );
  }
}

/// Small white-bordered 3:4 visa photo for the country details page. Sits in
/// the upper-left of the fields column with a slight tilt and a partial ink
/// stamp clipping its lower-right corner, so it reads as a stamp pressed
/// across the photo + page boundary.
class _VisaVisitPhoto extends StatelessWidget {
  const _VisaVisitPhoto({
    required this.imageUrl,
    required this.countryInitial,
    required this.seed,
  });

  final String imageUrl;
  final String countryInitial;
  final int seed;

  static const _w = 80.0;
  static const _h = 108.0; // 3:4 inside frame

  @override
  Widget build(BuildContext context) {
    // Deterministic tilt from -3° to +3°.
    final tilt = ((seed % 13) / 12.0 - 0.5) * (math.pi / 180.0) * 6;
    return SizedBox(
      width: _w + 6,
      height: _h + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.rotate(
            angle: tilt,
            child: Container(
              width: _w,
              height: _h,
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF8EF),
                border:
                    Border.all(color: const Color(0xFFD8C9A8), width: 0.6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(1, 3),
                  ),
                ],
              ),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheHeight: 220,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFE8DDBF)),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFE8DDBF),
                        alignment: Alignment.center,
                        child: Text(
                          countryInitial,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: _kInkBrown,
                          ),
                        ),
                      ),
                    ),
                    // Glossy visa-photo sheen.
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.16),
                              Colors.transparent,
                              Colors.black.withOpacity(0.10),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Partial circular ink stamp pressed across the photo's bottom-right
          // corner and the page beneath it.
          Positioned(
            right: -10,
            bottom: -8,
            child: Transform.rotate(
              angle: 0.22,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: StampBorderPainter(
                          color: const Color(0xFFA8472D),
                          shape: StampShape.circle,
                          seed: seed + 91,
                          strokeWidth: 1.4,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'STAMPED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFA8472D),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPhotoCard extends StatelessWidget {
  const _NoPhotoCard({required this.label, this.subtitle = 'photo'});
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: -0.015,
          child: Container(
            width: double.infinity,
            height: _DishPhotoCard.outerHeight,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF8EF),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE8E0D0),
                border: Border.all(
                  color: _kInkBrown.withOpacity(0.18),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.restaurant,
                        size: 30, color: Color(0xFF8B6A3D)),
                    const SizedBox(height: GS.s4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.caveat(
                        fontSize: 20,
                        color: _kInkBrown,
                      ),
                    ),
                    Text(
                      'no $subtitle yet',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        color: _kInkBrown.withOpacity(0.55),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Washi-tape strip pinning the empty frame to the page.
        Positioned(
          top: 2,
          left: 30,
          child: Transform.rotate(
            angle: -0.12,
            child: SizedBox(
              width: 52,
              height: 14,
              child: CustomPaint(
                painter: WashiTapePainter(
                  color: const Color(0xFFE0BF7A),
                  pattern: WashiPattern.dots,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
