import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/passport/painters/paper_texture_painter.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/ui/painters/scrapbook_painters.dart';

// Identity ink palette — pairs with the parchment/gold of the cover.
const _kInk = Color(0xFF1F1A14);
const _kInkBrown = Color(0xFF6B4A2C);
const _kGoldInk = Color(0xFFB98A3D);
const _kSeal = Color(0xFF6B2E2E);

/// Holder-identity data assembled by [PassportScreen] and passed to both halves
/// of the identity spread. Everything here is presentation-only; nothing is
/// persisted from this file.
class IdentityCardData {
  const IdentityCardData({
    required this.userId,
    required this.displayName,
    required this.homeCity,
    required this.avatarUrl,
    required this.visitCount,
    required this.issueDate,
  });

  final String userId;
  final String displayName;
  final String? homeCity;
  final String? avatarUrl;
  final int visitCount;
  final DateTime issueDate;

  /// `AN-XXXX-XXXX` — first 8 hex chars of the user id, uppercased and split.
  String get gastroId {
    final clean = userId
        .replaceAll(RegExp('[^0-9a-fA-F]'), '')
        .toUpperCase()
        .padRight(8, 'X')
        .substring(0, 8);
    final initials = _initials(displayName);
    return '$initials-${clean.substring(0, 4)}-${clean.substring(4, 8)}';
  }

  /// `P A 1 2 3 4 5 6` — last 6 hex chars of the user id, uppercased.
  String get passportNo {
    final clean = userId
        .replaceAll(RegExp('[^0-9a-fA-F]'), '')
        .toUpperCase()
        .padRight(6, 'X');
    return 'P${clean.substring(clean.length - 6).padLeft(6, 'X')}';
  }

  /// SURNAME extracted as last whitespace-separated token; GIVEN is the rest.
  String get surname {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return displayName.toUpperCase();
    return parts.last.toUpperCase();
  }

  String get givenNames {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return '—';
    return parts.sublist(0, parts.length - 1).join(' ').toUpperCase();
  }

  String get nationality =>
      (homeCity == null || homeCity!.trim().isEmpty)
          ? 'GASTRONOMIC'
          : homeCity!.toUpperCase();

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'GV';
    if (parts.length == 1) {
      final p = parts.first.toUpperCase();
      return p.length >= 2 ? p.substring(0, 2) : '${p}X';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ─── Public entry points ─────────────────────────────────────────────────────

/// Left page of the identity spread — multilingual "WELCOME" page that mirrors
/// real passports' inside-cover greeting.
class IdentityWelcomePage extends StatelessWidget {
  const IdentityWelcomePage({super.key, required this.data});
  final IdentityCardData data;

  @override
  Widget build(BuildContext context) {
    return _IdentityPaperShell(
      seed: data.userId.hashCode,
      gutterSide: GutterSide.right,
      child: _WelcomeContent(data: data),
    );
  }
}

/// Right page of the identity spread — the actual personal data + MRZ.
class IdentityCardPage extends StatelessWidget {
  const IdentityCardPage({super.key, required this.data});
  final IdentityCardData data;

  @override
  Widget build(BuildContext context) {
    return _IdentityPaperShell(
      seed: data.userId.hashCode + 7,
      gutterSide: GutterSide.left,
      child: _IdentityContent(data: data),
    );
  }
}

// ─── Shared shell ────────────────────────────────────────────────────────────

enum GutterSide { left, right }

/// Parchment background + faint security guilloche pattern + a low-alpha
/// government-rosette seal. Mirrors [`StampPage`]'s `_PaperPage` so the
/// identity spread sits inside the same physical book without seams.
class _IdentityPaperShell extends StatelessWidget {
  const _IdentityPaperShell({
    required this.child,
    required this.seed,
    required this.gutterSide,
  });

  final Widget child;
  final int seed;
  final GutterSide gutterSide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: PaperTexturePainter(
              seed: seed,
              baseColor: const Color(0xFFF3E8CE),
              darken: 0.95,
            ),
          ),
        ),
        // Security guilloche — fine repeating wavy lines, low alpha.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GuillochePainter(seed: seed),
            ),
          ),
        ),
        // Faint embossed national-rosette seal anchored in the center.
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(painter: _RosetteSealPainter()),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
        // Gutter shadow — pairs with the stamp/details pages' gutter shadows.
        Positioned(
          top: 0,
          bottom: 0,
          left: gutterSide == GutterSide.left ? 0 : null,
          right: gutterSide == GutterSide.right ? 0 : null,
          width: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: gutterSide == GutterSide.left
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  end: gutterSide == GutterSide.left
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
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

// ─── Welcome (left) page ─────────────────────────────────────────────────────

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.data});
  final IdentityCardData data;

  static const _greetings = [
    ['WELCOME', 'English'],
    ['BIENVENIDOS', 'Español'],
    ['BIENVENUE', 'Français'],
    ['BENVENUTI', 'Italiano'],
    ['ようこそ', '日本語'],
    ['欢迎', '中文'],
    ['خوش‌آمدید', 'فارسی'],
    ['ХОШ ГӘЛДИН', 'Azərbaycan'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 26, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 1.4, color: _kGoldInk),
              const SizedBox(width: GS.s8),
              Text(
                'REPUBLIC OF GASTRONOMY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: _kGoldInk,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: GS.s12),
          // Forks-and-knife crest, monochrome, embossed feel.
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kGoldInk.withOpacity(0.7), width: 1.4),
              ),
              child: const Center(
                child: Icon(Icons.restaurant_rounded,
                    color: _kGoldInk, size: 28),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: GS.normal)
              .scale(begin: const Offset(0.85, 0.85), curve: GS.spring),
          const SizedBox(height: GS.s12),
          Center(
            child: Text(
              'WELCOME, TRAVELLER',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: GS.s8),
          Center(
            child: SizedBox(
              width: 160,
              child: Text(
                'The bearer of this passport travels under the sovereignty of taste. May every border crossed bring a meal worth remembering.',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 9.5,
                  color: _kInk.withOpacity(0.75),
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: GS.s12),
          Container(
            height: 0.7,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kGoldInk.withOpacity(0),
                  _kGoldInk.withOpacity(0.5),
                  _kGoldInk.withOpacity(0),
                ],
              ),
            ),
          ),
          const SizedBox(height: GS.s8),
          // Multilingual greetings — two columns, fixed width to keep mono-cap
          // alignment immaculate.
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final g in _greetings)
                  SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g[0],
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          g[1].toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 7,
                            color: _kInkBrown.withOpacity(0.7),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Center(
            child: Text(
              'ONE WORLD  ·  ONE TABLE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                color: _kGoldInk.withOpacity(0.85),
                letterSpacing: 2.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Identity (right) page ───────────────────────────────────────────────────

class _IdentityContent extends StatelessWidget {
  const _IdentityContent({required this.data});
  final IdentityCardData data;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final issue = dateFmt.format(data.issueDate).toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            label: 'GASTRONOMIC PASSPORT',
            trailing: 'PERSONAL DATA',
          ),
          const SizedBox(height: GS.s10),
          // Photo + fields row.
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VisaIdPhoto(
                  avatarUrl: data.avatarUrl,
                  initial: data.displayName.isNotEmpty
                      ? data.displayName[0].toUpperCase()
                      : 'G',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IdField(label: 'SURNAME', value: data.surname),
                      _IdField(label: 'GIVEN', value: data.givenNames),
                      _IdField(label: 'NATIONALITY', value: data.nationality),
                      _IdField(label: 'PASSPORT N°', value: data.passportNo, mono: true),
                      _IdField(label: 'GASTRO ID', value: data.gastroId, mono: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GS.s8),
          Row(
            children: [
              Expanded(
                child:
                    _IdField(label: 'ISSUED', value: issue, mono: true),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _IdField(label: 'EXPIRES', value: 'NEVER', mono: true),
              ),
            ],
          ),
          const SizedBox(height: GS.s4),
          _IdField(
            label: 'COUNTRIES TASTED',
            value: '${data.visitCount} of 195',
            mono: true,
          ),
          const SizedBox(height: GS.s8),
          // Signature line.
          _Signature(name: data.displayName),
          const SizedBox(height: GS.s8),
          // MRZ — the machine-readable zone strip every real passport has.
          _MachineReadableZone(data: data),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.verified_rounded,
                  size: 12, color: _kGoldInk.withOpacity(0.85)),
              const SizedBox(width: 4),
              Text(
                'CERTIFIED CULINARY TRAVELLER',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 7.5,
                  color: _kGoldInk.withOpacity(0.85),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reusable identity widgets ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.trailing});
  final String label;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 22, height: 1.4, color: _kGoldInk),
        const SizedBox(width: GS.s6),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: _kGoldInk,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            color: _kInkBrown.withOpacity(0.7),
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

/// Visa-style holder photo: 3:4 white-bordered card, slight tilt, drop shadow,
/// partial "VERIFIED" ink stamp clipping the lower-right.
class _VisaIdPhoto extends StatelessWidget {
  const _VisaIdPhoto({required this.avatarUrl, required this.initial});

  final String? avatarUrl;
  final String initial;

  static const _w = 88.0;
  static const _h = 112.0; // ~3:4

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: -0.04,
          child: Container(
            width: _w,
            height: _h,
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFCF8EF),
              border: Border.all(color: const Color(0xFFD8C9A8), width: 0.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(1, 3),
                ),
              ],
            ),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (avatarUrl != null && avatarUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFFE8DDBF)),
                      errorWidget: (_, __, ___) => _AvatarFallback(initial),
                    )
                  else
                    _AvatarFallback(initial),
                  // Greyscale tonal cast — passport photos read official, not snapshot.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.transparent,
                            const Color(0xFF1F1A14).withOpacity(0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Caption strip under the photo, like an ID card's label.
        Positioned(
          left: 4,
          bottom: 2,
          right: 6,
          child: Transform.rotate(
            angle: -0.04,
            child: Text(
              'HOLDER  •  3.5 × 4.5 CM',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 6,
                color: _kInkBrown.withOpacity(0.7),
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
        // Partial circular "VERIFIED" ink stamp clipping the photo's corner —
        // looks like a stamp was pressed across the photo + page boundary.
        Positioned(
          right: -10,
          bottom: -8,
          child: Transform.rotate(
            angle: -0.22,
            child: SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: StampBorderPainter(
                        color: _kSeal,
                        shape: StampShape.circle,
                        seed: 11,
                        strokeWidth: 1.4,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      'VERIFIED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: _kSeal,
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
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback(this.initial);
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8DDBF),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.playfairDisplay(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: _kInkBrown,
        ),
      ),
    );
  }
}

/// Government-form field: mono-caps label above, serif/mono value beneath an
/// inked baseline.
class _IdField extends StatelessWidget {
  const _IdField({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 6.5,
              fontWeight: FontWeight.w700,
              color: _kInkBrown.withOpacity(0.75),
              letterSpacing: 1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 1),
          Container(
            padding: const EdgeInsets.only(bottom: 1.5),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _kInkBrown.withOpacity(0.4),
                  width: 0.6,
                ),
              ),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      letterSpacing: 0.8,
                      height: 1.1,
                    )
                  : GoogleFonts.playfairDisplay(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                      height: 1.1,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cursive signature scribbled above an inked baseline, with a tiny mono cap
/// "SIGNATURE OF BEARER" label.
class _Signature extends StatelessWidget {
  const _Signature({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIGNATURE OF BEARER',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 6.5,
            fontWeight: FontWeight.w700,
            color: _kInkBrown.withOpacity(0.75),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.only(left: 4, bottom: 1),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _kInkBrown.withOpacity(0.55),
                width: 0.8,
              ),
            ),
          ),
          child: Transform.rotate(
            angle: -0.04,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.caveat(
                fontSize: 22,
                color: const Color(0xFF1B3A78), // signature ink blue
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The two-line MRZ strip at the bottom of a real passport's identity page.
/// Format is purely cosmetic — we mimic ICAO 9303 character placement so the
/// strip reads correctly even without a real machine.
class _MachineReadableZone extends StatelessWidget {
  const _MachineReadableZone({required this.data});
  final IdentityCardData data;

  @override
  Widget build(BuildContext context) {
    final surname = _sanitise(data.surname);
    final given = _sanitise(data.givenNames);
    // Line 1: P<GST<SURNAME<<GIVEN<<<...  (44 chars)
    final line1Body = 'P<GST<$surname<<$given';
    final line1 = line1Body.padRight(44, '<').substring(0, 44);

    // Line 2: passport number(9) + checkdigit + GST(nationality) + DOB(6) + check + sex + expiry(6) + check + personalNo + <<<<<<
    final passport = data.passportNo
        .replaceAll(RegExp('[^A-Z0-9]'), '')
        .padRight(9, '<')
        .substring(0, 9);
    final issue = DateFormat('yyMMdd').format(data.issueDate);
    final natShort = _sanitise(data.nationality)
        .substring(0, math.min(6, data.nationality.length))
        .padRight(6, '<');
    final line2 = '${passport}0GST${natShort}0M${issue}0$passport<<'
        .padRight(44, '<')
        .substring(0, 44);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _kInkBrown.withOpacity(0.5), width: 0.6),
          bottom: BorderSide(color: _kInkBrown.withOpacity(0.5), width: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line1,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: _kInk,
              letterSpacing: 1.4,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            line2,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              color: _kInk,
              letterSpacing: 1.4,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  String _sanitise(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '<');
}

// ─── Painters ────────────────────────────────────────────────────────────────

/// Fine repeating wavy guilloche — anti-counterfeit pattern in low alpha.
class _GuillochePainter extends CustomPainter {
  _GuillochePainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB98A3D).withOpacity(0.10)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final rand = math.Random(seed);
    final phase = rand.nextDouble() * math.pi;

    for (double y = 4; y < size.height; y += 7) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 4) {
        final yy = y + math.sin(x * 0.07 + phase + y * 0.01) * 2.6;
        path.lineTo(x, yy);
      }
      canvas.drawPath(path, paint);
    }

    // Cross-grain diagonal — adds the lattice feel.
    final cross = Paint()
      ..color = const Color(0xFFB98A3D).withOpacity(0.06)
      ..strokeWidth = 0.4;
    for (double x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        cross,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GuillochePainter oldDelegate) =>
      oldDelegate.seed != seed;
}

/// Faint government-passport-style rosette/seal, drawn as concentric inked
/// rings + radial spokes + a central star.
class _RosetteSealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(size.width, size.height) / 2 - 4;

    final ring = Paint()
      ..color = _kGoldInk.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final f in [1.0, 0.86, 0.7, 0.55, 0.36]) {
      canvas.drawCircle(Offset(cx, cy), maxR * f, ring);
    }

    // Radial spokes.
    final spoke = Paint()
      ..color = _kGoldInk.withOpacity(0.10)
      ..strokeWidth = 0.6;
    const spokes = 24;
    for (int i = 0; i < spokes; i++) {
      final a = (i / spokes) * math.pi * 2;
      canvas.drawLine(
        Offset(cx + math.cos(a) * maxR * 0.36,
            cy + math.sin(a) * maxR * 0.36),
        Offset(cx + math.cos(a) * maxR, cy + math.sin(a) * maxR),
        spoke,
      );
    }

    // Central 8-point star.
    final star = Paint()
      ..color = _kGoldInk.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path();
    const points = 8;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? maxR * 0.22 : maxR * 0.10;
      final a = (i / (points * 2)) * math.pi * 2 - math.pi / 2;
      final p = Offset(cx + math.cos(a) * r, cy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, star);

    // Small fork/knife crest in the center, debossed.
    final crest = Paint()
      ..color = _kGoldInk.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(cx - 7, cy - 8),
      Offset(cx - 7, cy + 8),
      crest,
    );
    canvas.drawLine(
      Offset(cx + 7, cy - 8),
      Offset(cx + 7, cy + 8),
      crest,
    );
    canvas.drawCircle(Offset(cx - 7, cy - 7), 1.6, crest);
    canvas.drawCircle(Offset(cx + 7, cy - 7), 1.6, crest);
  }

  @override
  bool shouldRepaint(covariant _RosetteSealPainter oldDelegate) => false;
}

/// Helper to derive an [IdentityCardData] from auth + profile + visits.
/// Public so [PassportScreen] doesn't have to know the formatting rules.
IdentityCardData buildIdentityCardData({
  required String? userId,
  required String? displayName,
  required String? homeCity,
  required String? avatarUrl,
  required List<Visit> visits,
}) {
  DateTime earliest = DateTime.now();
  for (final v in visits) {
    try {
      final dt = DateTime.parse(v.visitedOn);
      if (dt.isBefore(earliest)) earliest = dt;
    } catch (_) {}
  }
  // If there are no visits or all parses fail, just stamp issue date as today.
  if (visits.isEmpty) earliest = DateTime.now();

  return IdentityCardData(
    userId: userId ?? 'gv-anonymous',
    displayName: (displayName == null || displayName.trim().isEmpty)
        ? 'Gastro Explorer'
        : displayName,
    homeCity: homeCity,
    avatarUrl: avatarUrl,
    visitCount: visits.length,
    issueDate: earliest,
  );
}
