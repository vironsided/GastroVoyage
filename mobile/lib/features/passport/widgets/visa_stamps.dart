import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile/ui/painters/scrapbook_painters.dart';

/// Set of port-of-entry visa stamps, varied per country so no two passport
/// pages stamp the same. Style is picked deterministically from the country's
/// ISO-A2 code so a given country always stamps the same way across rebuilds.
///
/// Each style is a ~stamp-sized widget (around 150–180 px wide) intended to be
/// dropped onto the [StampPage] inside a `Positioned`/`Transform.rotate`. All
/// styles share the rough-edged [StampBorderPainter] look + bled ink overlay
/// so they read as a single passport's worth of hand-pressed stamps.

enum VisaStampStyle { circleEntry, rectArrived, ovalPosted, diamondVerified }

/// Picks a deterministic stamp style for a given ISO code.
VisaStampStyle visaStyleFor(String isoA2) {
  // Hash on iso so the same country always picks the same style across builds.
  final h = isoA2.isEmpty ? 0 : isoA2.codeUnits.fold(0, (a, b) => a + b);
  return VisaStampStyle.values[h % VisaStampStyle.values.length];
}

/// Small deterministic rotation in radians from `-8°` to `+8°`.
double visaTiltFor(String isoA2) {
  final h = isoA2.isEmpty ? 0 : isoA2.codeUnits.fold(0, (a, b) => a + b);
  final pct = (h % 17) / 16.0; // 0..1
  return (pct - 0.5) * (math.pi / 180.0) * 16; // ±8°
}

/// Picks an "entry port" airport-style 3-letter code from the country name +
/// ISO. Pure presentation — no airport DB needed, just looks legitimate.
String entryPortFor({required String countryName, required String isoA2}) {
  final clean = countryName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  if (clean.length >= 3) {
    return '${clean[0]}${isoA2.isNotEmpty ? isoA2[0] : clean[1]}${clean[clean.length - 1]}';
  }
  return '${isoA2}X'.padRight(3, 'X').substring(0, 3);
}

/// Builds the country's visa stamp, dispatching to the right style.
class CountryVisaStamp extends StatelessWidget {
  const CountryVisaStamp({
    super.key,
    required this.countryName,
    required this.isoA2,
    required this.visitedOn,
    required this.seed,
  });

  final String countryName;
  final String isoA2;
  final DateTime? visitedOn;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final style = visaStyleFor(isoA2);
    final tilt = visaTiltFor(isoA2);
    final port = entryPortFor(countryName: countryName, isoA2: isoA2);
    final dateLong = visitedOn != null
        ? DateFormat('dd MMM yyyy').format(visitedOn!).toUpperCase()
        : '';
    final dateShort = visitedOn != null
        ? DateFormat('dd.MM.yy').format(visitedOn!)
        : '';

    Widget stamp;
    switch (style) {
      case VisaStampStyle.circleEntry:
        stamp = _CircleEntryStamp(
          isoA2: isoA2,
          date: dateLong,
          port: port,
          seed: seed,
        );
        break;
      case VisaStampStyle.rectArrived:
        stamp = _RectArrivedStamp(
          countryName: countryName,
          date: dateLong,
          seed: seed,
        );
        break;
      case VisaStampStyle.ovalPosted:
        stamp = _OvalPostedStamp(
          countryName: countryName,
          date: dateShort,
          seed: seed,
        );
        break;
      case VisaStampStyle.diamondVerified:
        stamp = _DiamondVerifiedStamp(isoA2: isoA2, seed: seed);
        break;
    }

    return Transform.rotate(angle: tilt, child: _InkBlot(child: stamp));
  }
}

/// A thin SRC_OVER opacity overlay that bleeds the ink slightly outside the
/// stamp's edges — the way a real rubber stamp's pad doesn't press perfectly.
class _InkBlot extends StatelessWidget {
  const _InkBlot({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(opacity: 0.94, child: child);
  }
}

// ─── Style A: Large red CIRCULAR "ENTRY" stamp with port code ────────────────
class _CircleEntryStamp extends StatelessWidget {
  const _CircleEntryStamp({
    required this.isoA2,
    required this.date,
    required this.port,
    required this.seed,
  });

  final String isoA2;
  final String date;
  final String port;
  final int seed;

  static const _ink = Color(0xFFB54231);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      height: 138,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StampBorderPainter(
                color: _ink,
                shape: StampShape.circle,
                seed: seed,
                strokeWidth: 2.4,
              ),
            ),
          ),
          // Inner concentric ring with the rotating header text.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CustomPaint(
                painter: StampBorderPainter(
                  color: _ink.withOpacity(0.7),
                  shape: StampShape.circle,
                  seed: seed + 31,
                  strokeWidth: 1.2,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Icon(Icons.flight_takeoff_rounded,
                    size: 16, color: _ink.withOpacity(0.85)),
                Text(
                  'ENTRY',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: 3,
                  ),
                ),
                Container(
                  width: 28,
                  height: 0.9,
                  color: _ink.withOpacity(0.6),
                ),
                const SizedBox(height: 2),
                Text(
                  isoA2,
                  style: GoogleFonts.specialElite(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: 3.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  port,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: _ink.withOpacity(0.8),
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 7,
                    color: _ink,
                    letterSpacing: 0.6,
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

// ─── Style B: Blue RECTANGULAR "ARRIVED" immigration counter stamp ───────────
class _RectArrivedStamp extends StatelessWidget {
  const _RectArrivedStamp({
    required this.countryName,
    required this.date,
    required this.seed,
  });

  final String countryName;
  final String date;
  final int seed;

  static const _ink = Color(0xFF1B4D78);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StampBorderPainter(
                color: _ink,
                shape: StampShape.roundedRect,
                seed: seed,
                strokeWidth: 2.0,
              ),
            ),
          ),
          // Immigration-counter corner triangle.
          Positioned(
            top: 4,
            left: 4,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(
                painter: _CornerTrianglePainter(color: _ink),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ARRIVED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: 3.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  countryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.specialElite(
                    fontSize: countryName.length > 14 ? 12 : 14,
                    color: _ink,
                    letterSpacing: 1.6,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Container(width: 40, height: 0.8, color: _ink.withOpacity(0.6)),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    color: _ink.withOpacity(0.85),
                    letterSpacing: 1.4,
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

class _CornerTrianglePainter extends CustomPainter {
  _CornerTrianglePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.75)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CornerTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─── Style C: Black OVAL "POSTED" hand-pressed postal stamp ──────────────────
class _OvalPostedStamp extends StatelessWidget {
  const _OvalPostedStamp({
    required this.countryName,
    required this.date,
    required this.seed,
  });

  final String countryName;
  final String date;
  final int seed;

  // A near-black "iron-gall ink" tone.
  static const _ink = Color(0xFF1F1B17);

  @override
  Widget build(BuildContext context) {
    final rand = math.Random(seed);
    return SizedBox(
      width: 158,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: StampBorderPainter(
                color: _ink,
                shape: StampShape.oval,
                seed: seed,
                strokeWidth: 1.6,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'POSTED',
                  style: GoogleFonts.specialElite(
                    fontSize: 13,
                    color: _ink,
                    letterSpacing: 3,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  countryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.specialElite(
                    fontSize: countryName.length > 14 ? 11 : 13,
                    color: _ink.withOpacity(0.9),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 1),
                // Scattered "hand-pressed" date numerals.
                SizedBox(
                  width: 110,
                  height: 16,
                  child: Stack(
                    children: [
                      for (int i = 0; i < date.length; i++)
                        Positioned(
                          left: 10.0 + i * 8.0 + (rand.nextDouble() - 0.5) * 2,
                          top: (rand.nextDouble() - 0.5) * 4 + 2,
                          child: Transform.rotate(
                            angle:
                                (rand.nextDouble() - 0.5) * 0.22, // ±6° per char
                            child: Text(
                              date[i],
                              style: GoogleFonts.specialElite(
                                fontSize: 11,
                                color: _ink,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
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

// ─── Style D: Green DIAMOND "VERIFIED · GASTRO" cuisine clearance stamp ──────
class _DiamondVerifiedStamp extends StatelessWidget {
  const _DiamondVerifiedStamp({required this.isoA2, required this.seed});

  final String isoA2;
  final int seed;

  static const _ink = Color(0xFF3F6B3D);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: StampBorderPainter(
                  color: _ink,
                  shape: StampShape.roundedRect,
                  seed: seed,
                  strokeWidth: 2.0,
                ),
              ),
            ),
            Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 16, color: _ink.withOpacity(0.85)),
                    const SizedBox(height: 1),
                    Text(
                      'VERIFIED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: 1.6,
                      ),
                    ),
                    Text(
                      'GASTRO',
                      style: GoogleFonts.specialElite(
                        fontSize: 10,
                        color: _ink,
                        letterSpacing: 2,
                      ),
                    ),
                    Container(
                        width: 22, height: 0.7, color: _ink.withOpacity(0.7)),
                    Text(
                      isoA2,
                      style: GoogleFonts.specialElite(
                        fontSize: 12,
                        color: _ink,
                        letterSpacing: 3,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
