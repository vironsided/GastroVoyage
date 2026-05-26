import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/passport/painters/paper_texture_painter.dart';
import 'package:mobile/features/passport/widgets/visa_stamps.dart';
import 'package:mobile/ui/painters/scrapbook_painters.dart';
import 'package:mobile/features/shared/models.dart';

// Scrapbook ink palette — kept local so stamps stay tonally consistent.
const _kInkBrown = Color(0xFF6B4A2C);
const _kInkRed = Color(0xFFB54231);
const _kInkBlue = Color(0xFF1B4D78);

class StampPage extends StatelessWidget {
  const StampPage({super.key, required this.visit, this.photoUrl});

  final Visit visit;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final country = visit.country;
    final countryName = (country?.name ?? 'UNKNOWN').toUpperCase();
    final region = (country?.region ?? '').toUpperCase();
    final iso = country?.isoA2 ?? 'XX';
    DateTime? dt;
    try {
      dt = DateTime.parse(visit.visitedOn);
    } catch (_) {}
    final dateStr =
        dt != null ? DateFormat('d MMM yyyy').format(dt).toUpperCase() : '';
    final yearStr = dt != null ? DateFormat('yyyy').format(dt) : '';
    final serial =
        '${dt != null ? dt.year : 2024}-$iso-${visit.id.substring(0, math.min(4, visit.id.length)).toUpperCase()}';
    final rand = math.Random(visit.id.hashCode);

    return _PaperPage(
      seed: visit.id.hashCode,
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          // Diagonal washi-tape strip anchoring the corner of the page.
          Positioned(
            left: -24,
            top: 64,
            child: Transform.rotate(
              angle: -0.7,
              child: SizedBox(
                width: 96,
                height: 17,
                child: CustomPaint(
                  painter: WashiTapePainter(
                    color: const Color(0xFFE0BF7A),
                    pattern: WashiPattern.stripes,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 18,
            right: 18,
            child: _ChapterTab(label: yearStr, region: region),
          ),

          // Hero port-of-entry stamp — varies in shape, ink colour, and text
          // per country so no two passport pages look alike.
          _StampDrop(
            left: 22,
            top: 26,
            order: 0,
            child: CountryVisaStamp(
              countryName: countryName,
              isoA2: iso,
              visitedOn: dt,
              seed: visit.id.hashCode,
            ),
          ),

          _StampDrop(
            left: 26,
            top: 145,
            order: 1,
            child: Transform.rotate(
              angle: -0.06,
              child: SizedBox(
                width: 86,
                height: 86,
                child: CustomPaint(
                  painter: StampBorderPainter(
                    color: _kInkBlue,
                    shape: StampShape.circle,
                    seed: visit.id.hashCode + 3,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 14),
                        Text(
                          'No. $serial',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 7.5,
                            color: _kInkBlue,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          iso,
                          style: GoogleFonts.specialElite(
                            fontSize: 18,
                            color: _kInkBlue,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 6,
                            color: _kInkBlue,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          _StampDrop(
            left: 124,
            top: 155,
            order: 2,
            child: Transform.rotate(
              angle: 0.04,
              child: _DiamondStamp(
                label: 'FOOD OF $countryName',
                color: const Color(0xFF6B4A7E),
                seed: visit.id.hashCode + 5,
              ),
            ),
          ),

          _StampDrop(
            left: 30,
            top: 245,
            order: 3,
            child: Transform.rotate(
              angle: 0.08,
              child: _OvalStamp(
                lines: const ['MEDITERRANEAN', 'SEA'],
                tagline: 'TASTE THE WORLD',
                color: const Color(0xFF6E7E4F),
                seed: visit.id.hashCode + 7,
              ),
            ),
          ),

          _StampDrop(
            left: 138,
            top: 250,
            order: 4,
            child: Transform.rotate(
              angle: -0.05,
              child: _RectStamp(
                lines: ['THE REPUBLIC OF', countryName],
                accent: dateStr,
                color: _kInkRed,
                seed: visit.id.hashCode + 11,
                width: 130,
                height: 78,
              ),
            ),
          ),

          _StampDrop(
            left: 60,
            top: 350,
            order: 5,
            child: Transform.rotate(
              angle: -0.04,
              child: _HexagonStamp(
                lines: ['INT\'L', countryName],
                color: const Color(0xFF2E3A8A),
                seed: visit.id.hashCode + 13,
              ),
            ),
          ),

          _StampDrop(
            left: 175,
            top: 365,
            order: 6,
            child: Transform.rotate(
              angle: 0.06,
              child: _RectStamp(
                lines: const ['TRAVEL', 'MORE'],
                accent: 'EXPLORE $yearStr',
                color: const Color(0xFFA8472D),
                seed: visit.id.hashCode + 17,
                width: 88,
                height: 64,
              ),
            ),
          ),

          Positioned(
            right: -8,
            top: 95,
            child: Transform.rotate(
              angle: 0.07,
              child: _Polaroid(
                imageUrl: photoUrl,
                caption: '${(country?.name ?? "Memories")} ♡',
                rand: rand,
              ),
            ).animate().fadeIn(duration: GS.normal, delay: GS.fast).slideY(
                  begin: -0.12,
                  end: 0,
                  curve: GS.smooth,
                  duration: GS.slow,
                ),
          ),

          // Handwritten margin note — adds a personal scrapbook touch.
          Positioned(
            left: 18,
            bottom: 58,
            child: Transform.rotate(
              angle: -0.05,
              child: Text(
                'collected ♡',
                style: GoogleFonts.caveat(
                  fontSize: 20,
                  color: _kInkRed.withOpacity(0.7),
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Center(
              child: Opacity(
                opacity: 0.5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SWIPE TO PREVIOUS COUNTRY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8,
                        color: const Color(0xFF5C3A1E),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: GS.s2),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        color: const Color(0xFF5C3A1E).withOpacity(0.6),
                        size: 20),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              'N° $serial',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                color: _kInkBrown.withOpacity(0.55),
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Places a stamp at a fixed position and gives it a soft "pressed onto the
/// page" entrance — a quick fade + settle, staggered by [order].
class _StampDrop extends StatelessWidget {
  const _StampDrop({
    required this.left,
    required this.top,
    required this.order,
    required this.child,
  });

  final double left;
  final double top;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: child
          .animate()
          .fadeIn(
            duration: GS.fast,
            delay: GS.stagger(order, ms: 55),
          )
          .scale(
            begin: const Offset(1.14, 1.14),
            end: const Offset(1, 1),
            curve: Curves.easeOutCubic,
            duration: GS.normal,
            delay: GS.stagger(order, ms: 55),
          ),
    );
  }
}

class _OvalStamp extends StatelessWidget {
  const _OvalStamp({
    required this.lines,
    required this.tagline,
    required this.color,
    required this.seed,
  });
  final List<String> lines;
  final String tagline;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 78,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StampBorderPainter(
                color: color,
                shape: StampShape.oval,
                seed: seed,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_menu, color: color, size: 14),
                ...lines.map((l) => Text(
                      l,
                      style: GoogleFonts.specialElite(
                        fontSize: 11,
                        color: color,
                        letterSpacing: 1,
                      ),
                    )),
                Text(
                  tagline,
                  style: GoogleFonts.specialElite(
                    fontSize: 7.5,
                    color: color.withOpacity(0.8),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RectStamp extends StatelessWidget {
  const _RectStamp({
    required this.lines,
    required this.accent,
    required this.color,
    required this.seed,
    this.width = 130,
    this.height = 78,
  });
  final List<String> lines;
  final String accent;
  final Color color;
  final int seed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StampBorderPainter(
                color: color,
                shape: StampShape.roundedRect,
                seed: seed,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...lines.map((l) => Text(
                        l,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.specialElite(
                          fontSize: l.length > 16 ? 10 : 13,
                          color: color,
                          letterSpacing: 1.2,
                          height: 1.1,
                        ),
                      )),
                  const SizedBox(height: 2),
                  Container(
                    width: 30,
                    height: 0.8,
                    color: color.withOpacity(0.6),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    accent,
                    style: GoogleFonts.specialElite(
                      fontSize: 7.5,
                      color: color.withOpacity(0.85),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonStamp extends StatelessWidget {
  const _HexagonStamp(
      {required this.lines, required this.color, required this.seed});
  final List<String> lines;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StampBorderPainter(
                color: color,
                shape: StampShape.hexagon,
                seed: seed,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: lines
                  .map((l) => Text(
                        l,
                        style: GoogleFonts.specialElite(
                          fontSize: l.length > 8 ? 10 : 12,
                          color: color,
                          letterSpacing: 1.2,
                          height: 1.1,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondStamp extends StatelessWidget {
  const _DiamondStamp({
    required this.label,
    required this.color,
    required this.seed,
  });
  final String label;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: StampBorderPainter(
                  color: color,
                  shape: StampShape.roundedRect,
                  seed: seed,
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.specialElite(
                      fontSize: 8.5,
                      color: color,
                      letterSpacing: 1.0,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTab extends StatelessWidget {
  const _ChapterTab({required this.label, required this.region});
  final String label;
  final String region;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7D5733), Color(0xFF5C3F23)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(GS.r4),
          bottomLeft: Radius.circular(GS.r4),
          topRight: Radius.circular(GS.r4),
          bottomRight: Radius.circular(GS.r12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 5,
            offset: const Offset(1, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF6EDDC),
              letterSpacing: 1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            region.isEmpty ? 'JOURNAL' : region,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 6.5,
              color: const Color(0xFFF6EDDC).withOpacity(0.7),
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.imageUrl,
    required this.caption,
    required this.rand,
  });

  final String? imageUrl;
  final String caption;
  final math.Random rand;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 170,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
          decoration: BoxDecoration(
            color: const Color(0xFFFCF8EF),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(2, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: 154,
                height: 154,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null && imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFE8E0D0),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFE8E0D0),
                              alignment: Alignment.center,
                              child: const Icon(Icons.restaurant,
                                  size: 30, color: Color(0xFF8B6A3D)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFE8E0D0),
                            alignment: Alignment.center,
                            child: const Icon(Icons.restaurant,
                                size: 30, color: Color(0xFF8B6A3D)),
                          ),
                    // Vintage photo-corner sheen.
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
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GS.s8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    caption,
                    style: GoogleFonts.caveat(
                      fontSize: 19,
                      color: const Color(0xFF2E2A27),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: -22,
          left: 32,
          child: SizedBox(
            width: 28,
            height: 60,
            child: CustomPaint(painter: PaperClipPainter()),
          ),
        ),

        // Botanical sprig peeking out behind the photo's lower-left.
        Positioned(
          bottom: -10,
          left: -6,
          child: Transform.rotate(
            angle: -0.5,
            child: SizedBox(
              width: 28,
              height: 56,
              child: CustomPaint(
                painter: BotanicalSprigPainter(
                  color: const Color(0xFF9A6BB5),
                  seed: rand.nextInt(99),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -16,
          right: 16,
          child: Transform.rotate(
            angle: 0.18,
            child: Container(
              width: 60,
              height: 18,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: WashiTapePainter(
                  color: const Color(0xFFE8A0B4),
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

class _PaperPage extends StatelessWidget {
  const _PaperPage({required this.child, required this.seed});
  final Widget child;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: PaperTexturePainter(seed: seed),
          ),
        ),
        Positioned.fill(child: child),
        // Spine-side gutter shadow (right edge) for a bound-book feel.
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
