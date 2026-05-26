// Pure PDF builder for the GastroVoyage Culinary Passport.
//
// This file is intentionally framework-pure: no Flutter widgets, no Riverpod,
// no BuildContext. The caller resolves all data from providers and hands it
// in, so the builder is easy to call from background isolates / tests.
//
// Output pages, in order:
//   1. Cover            — deep maroon, gold border, holder name + gastro id.
//   2. Identity         — cream parchment, "PERSONAL DATA" + MRZ footer.
//   3. TOC              — "STAMPED PASSAGES" — every visit, 2-col list.
//   4. Visit pages      — 1 per page for ≤10 visits, 2 per page otherwise.
//   5. Back cover       — closing artefact.
//
// All photo downloads time out at 4s and gracefully degrade (the page renders
// without the image if the network is flaky).

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:mobile/features/explore/country_dishes.dart';
import 'package:mobile/features/shared/models.dart';

// ── Palette ──────────────────────────────────────────────────────────────────

const PdfColor _kParchment = PdfColor.fromInt(0xFFFAF5E6);
const PdfColor _kParchmentDeep = PdfColor.fromInt(0xFFEBD9B5);
const PdfColor _kGold = PdfColor.fromInt(0xFFD4A843);
const PdfColor _kGoldDeep = PdfColor.fromInt(0xFFB8901A);
const PdfColor _kMaroon = PdfColor.fromInt(0xFF5D2E2E);
const PdfColor _kMaroonDeep = PdfColor.fromInt(0xFF3D0E0E);
const PdfColor _kMaroonInk = PdfColor.fromInt(0xFF6B1F1F);
const PdfColor _kInk = PdfColor.fromInt(0xFF2A1A0F);
const PdfColor _kInkSoft = PdfColor.fromInt(0xFF5A4332);

// ── Public API ───────────────────────────────────────────────────────────────

Future<Uint8List> buildPassportPdf({
  required String holderName,
  String? homeCity,
  String? avatarUrl,
  required int visitedCount,
  required int badgeCount,
  required List<Visit> visits,
  required DateTime issuedOn,
}) async {
  // Load all the fonts we want via PdfGoogleFonts (network-safe — printing
  // caches them after the first load).
  final fonts = await _loadFonts();

  // Fetch the avatar + each visit photo concurrently with a 4s budget. We
  // tolerate any failure by leaving the byte slot null.
  final avatarBytes = avatarUrl == null
      ? null
      : await _downloadBytes(avatarUrl, timeout: const Duration(seconds: 4));

  final photoBytesByVisitId = <String, Uint8List?>{};
  await Future.wait(
    visits.map((v) async {
      final url = v.photoPath;
      if (url == null || url.isEmpty) {
        photoBytesByVisitId[v.id] = null;
        return;
      }
      photoBytesByVisitId[v.id] =
          await _downloadBytes(url, timeout: const Duration(seconds: 4));
    }),
  );

  final doc = pw.Document(
    title: 'GastroVoyage — Culinary Passport',
    author: holderName,
    creator: 'GastroVoyage',
    subject: 'Culinary Passport',
  );

  final gastroId = _gastroIdFromName(holderName, issuedOn);
  final fmtDate = _fmtDate(issuedOn);

  // 1. Cover
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => _coverPage(
        fonts: fonts,
        holderName: holderName,
        gastroId: gastroId,
        visitedCount: visitedCount,
        issuedOn: issuedOn,
      ),
    ),
  );

  // 2. Identity
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => _identityPage(
        fonts: fonts,
        holderName: holderName,
        homeCity: homeCity,
        avatarBytes: avatarBytes,
        gastroId: gastroId,
        issuedOn: fmtDate,
        visitedCount: visitedCount,
        badgeCount: badgeCount,
      ),
    ),
  );

  // 3. TOC — only if there are any visits.
  if (visits.isNotEmpty) {
    doc.addPage(
      pw.MultiPage(
        pageTheme: _parchmentPageTheme(fonts),
        build: (ctx) => _tocChildren(fonts: fonts, visits: visits),
      ),
    );
  }

  // 4. Visit pages — one per visit for ≤10, two per page otherwise.
  final twoPerPage = visits.length > 10;
  if (twoPerPage) {
    for (var i = 0; i < visits.length; i += 2) {
      final a = visits[i];
      final b = (i + 1 < visits.length) ? visits[i + 1] : null;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => _twoVisitPage(
            fonts: fonts,
            top: a,
            topPhoto: photoBytesByVisitId[a.id],
            bottom: b,
            bottomPhoto: b == null ? null : photoBytesByVisitId[b.id],
          ),
        ),
      );
    }
  } else {
    for (final v in visits) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => _visitPage(
            fonts: fonts,
            visit: v,
            photo: photoBytesByVisitId[v.id],
          ),
        ),
      );
    }
  }

  // 5. Back cover.
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => _backCover(
        fonts: fonts,
        holderName: holderName,
        issuedOn: issuedOn,
      ),
    ),
  );

  return doc.save();
}

// ── Fonts ────────────────────────────────────────────────────────────────────

class _Fonts {
  _Fonts({
    required this.display,
    required this.displayBold,
    required this.body,
    required this.bodyBold,
    required this.mono,
    required this.script,
  });
  final pw.Font display;
  final pw.Font displayBold;
  final pw.Font body;
  final pw.Font bodyBold;
  final pw.Font mono;
  final pw.Font script;
}

Future<_Fonts> _loadFonts() async {
  final results = await Future.wait([
    PdfGoogleFonts.playfairDisplayRegular(),
    PdfGoogleFonts.playfairDisplayBold(),
    PdfGoogleFonts.hankenGroteskRegular(),
    PdfGoogleFonts.hankenGroteskSemiBold(),
    PdfGoogleFonts.jetBrainsMonoRegular(),
    PdfGoogleFonts.caveatRegular(),
  ]);
  return _Fonts(
    display: results[0],
    displayBold: results[1],
    body: results[2],
    bodyBold: results[3],
    mono: results[4],
    script: results[5],
  );
}

// ── Networking ───────────────────────────────────────────────────────────────

/// Downloads an image with a hard timeout. Returns null on any failure
/// (timeout, non-200, exception) — callers must render a tasteful fallback.
Future<Uint8List?> _downloadBytes(
  String url, {
  required Duration timeout,
}) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final res = await http.get(uri).timeout(timeout);
    if (res.statusCode != 200) return null;
    if (res.bodyBytes.isEmpty) return null;
    return res.bodyBytes;
  } catch (_) {
    return null;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _gastroIdFromName(String name, DateTime issuedOn) {
  // Deterministic 6-char id derived from name + issue year. Two travellers
  // with the same name registered in the same year share an id — fine for a
  // novelty document. We only use 0-9 and uppercase letters.
  final src = '$name|${issuedOn.year}';
  var hash = 5381;
  for (final c in src.codeUnits) {
    hash = ((hash << 5) + hash + c) & 0x7fffffff;
  }
  const alphabet = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  final out = StringBuffer();
  for (var i = 0; i < 6; i++) {
    out.write(alphabet[hash % alphabet.length]);
    hash ~/= alphabet.length;
    if (hash == 0) hash = 5381 ^ i;
  }
  return out.toString();
}

String _fmtDate(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd ${months[d.month - 1]} ${d.year}';
}

/// Best-effort parse of the `visited_on` string (`yyyy-MM-dd` from the API).
DateTime? _parseVisitedOn(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

String _fmtVisitedOn(String raw) {
  final d = _parseVisitedOn(raw);
  return d == null ? raw : _fmtDate(d);
}

/// MRZ-style condensed identifier strip — uppercase, no spaces.
String _mrzLine(String text, int length) {
  final cleaned = text
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '<');
  if (cleaned.length >= length) return cleaned.substring(0, length);
  return cleaned + ('<' * (length - cleaned.length));
}

String _surname(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length <= 1) return fullName.toUpperCase();
  return parts.last.toUpperCase();
}

String _given(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length <= 1) return '—';
  return parts.sublist(0, parts.length - 1).join(' ').toUpperCase();
}

String _initial(String name) {
  final t = name.trim();
  if (t.isEmpty) return 'G';
  // Substring-based to avoid the `characters` extension (kept dependency-free).
  return t.substring(0, 1).toUpperCase();
}

// ── Page theme (parchment) ───────────────────────────────────────────────────

pw.PageTheme _parchmentPageTheme(_Fonts fonts) {
  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 56),
    theme: pw.ThemeData.withFont(
      base: fonts.body,
      bold: fonts.bodyBold,
      italic: fonts.body,
    ),
    buildBackground: (ctx) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Container(color: _kParchment),
    ),
  );
}

// ── 1. Cover ─────────────────────────────────────────────────────────────────

pw.Widget _coverPage({
  required _Fonts fonts,
  required String holderName,
  required String gastroId,
  required int visitedCount,
  required DateTime issuedOn,
}) {
  return pw.Container(
    color: _kMaroonDeep,
    width: double.infinity,
    height: double.infinity,
    child: pw.Stack(
      children: [
        // Gold double border.
        pw.Positioned.fill(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kGold, width: 1.8),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColor(_kGold.red, _kGold.green, _kGold.blue,
                          0.45),
                      width: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Centre stack.
        pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'REPUBLIC OF GASTRONOMY',
                style: pw.TextStyle(
                  font: fonts.mono,
                  fontSize: 11,
                  color: _kGold,
                  letterSpacing: 4.2,
                ),
              ),
              pw.SizedBox(height: 28),

              // Crest emblem — concentric gold rings + fork/knife glyph.
              pw.Container(
                width: 130,
                height: 130,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _kGold, width: 1.6),
                ),
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(
                        color: PdfColor(_kGold.red, _kGold.green, _kGold.blue,
                            0.5),
                        width: 0.8,
                      ),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '\u{1F374}',
                        style: pw.TextStyle(
                          font: fonts.display,
                          fontSize: 56,
                          color: _kGold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              pw.SizedBox(height: 28),
              pw.Text(
                'PASSPORT',
                style: pw.TextStyle(
                  font: fonts.displayBold,
                  fontSize: 54,
                  color: _kGold,
                  letterSpacing: 10,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(width: 64, height: 1.2, color: _kGold),
              pw.SizedBox(height: 12),
              pw.Text(
                '$visitedCount '
                '${visitedCount == 1 ? 'country' : 'countries'} tasted',
                style: pw.TextStyle(
                  font: fonts.script,
                  fontSize: 22,
                  color: _kParchmentDeep,
                ),
              ),
              pw.SizedBox(height: 56),
              pw.Text(
                (holderName.isEmpty ? 'GASTRO TRAVELLER' : holderName)
                    .toUpperCase(),
                style: pw.TextStyle(
                  font: fonts.displayBold,
                  fontSize: 18,
                  color: _kGold,
                  letterSpacing: 5,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'GASTRO ID  N°  $gastroId',
                style: pw.TextStyle(
                  font: fonts.mono,
                  fontSize: 10,
                  color: PdfColor(_kGold.red, _kGold.green, _kGold.blue, 0.9),
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),

        // Footer tagline.
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 50,
          child: pw.Center(
            child: pw.Text(
              'ONE WORLD   ·   ONE TABLE',
              style: pw.TextStyle(
                font: fonts.mono,
                fontSize: 9,
                color: PdfColor(_kGold.red, _kGold.green, _kGold.blue, 0.85),
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── 2. Identity ──────────────────────────────────────────────────────────────

pw.Widget _identityPage({
  required _Fonts fonts,
  required String holderName,
  String? homeCity,
  Uint8List? avatarBytes,
  required String gastroId,
  required String issuedOn,
  required int visitedCount,
  required int badgeCount,
}) {
  final surname = _surname(holderName);
  final given = _given(holderName);
  final nationality = (homeCity == null || homeCity.isEmpty)
      ? 'GASTRO NOMAD'
      : homeCity.toUpperCase();

  final mrz1 = _mrzLine('P<GAS<$surname<<$given', 44);
  final mrz2 = _mrzLine('$gastroId<<<${issuedOn.replaceAll(' ', '')}', 44);

  return pw.Container(
    color: _kParchment,
    width: double.infinity,
    height: double.infinity,
    child: pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header row.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PERSONAL DATA',
                      style: pw.TextStyle(
                        font: fonts.mono,
                        fontSize: 10,
                        color: _kMaroon,
                        letterSpacing: 4,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Identité du voyageur',
                      style: pw.TextStyle(
                        font: fonts.script,
                        fontSize: 18,
                        color: _kInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _kMaroon, width: 1.4),
                ),
                child: pw.Text(
                  'TYPE  P',
                  style: pw.TextStyle(
                    font: fonts.mono,
                    fontSize: 9,
                    color: _kMaroon,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 1, color: _kGold),
          pw.SizedBox(height: 24),

          // Photo + data column.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _holderPhoto(fonts: fonts, bytes: avatarBytes, name: holderName),
              pw.SizedBox(width: 26),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _idRow(fonts, 'SURNAME', surname),
                    _idRow(fonts, 'GIVEN NAMES', given),
                    _idRow(fonts, 'NATIONALITY', nationality),
                    _idRow(fonts, 'GASTRO ID', gastroId),
                    _idRow(fonts, 'DATE OF ISSUE', issuedOn),
                    _idRow(fonts, 'DATE OF EXPIRY', 'NEVER'),
                    _idRow(fonts, 'COUNTRIES TASTED',
                        visitedCount.toString().padLeft(3, '0')),
                    _idRow(fonts, 'BADGES EARNED',
                        badgeCount.toString().padLeft(3, '0')),
                  ],
                ),
              ),
            ],
          ),

          pw.Spacer(),

          // Signature line — slightly tilted handwriting on a baseline.
          pw.Text(
            'HOLDER’S SIGNATURE',
            style: pw.TextStyle(
              font: fonts.mono,
              fontSize: 8,
              color: _kInkSoft,
              letterSpacing: 2.5,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            width: 280,
            height: 1,
            color: _kInkSoft,
          ),
          pw.Transform.translate(
            offset: const PdfPoint(4, -28),
            child: pw.Transform.rotate(
              angle: -0.04,
              child: pw.Text(
                holderName.isEmpty ? 'Gastro Traveller' : holderName,
                style: pw.TextStyle(
                  font: fonts.script,
                  fontSize: 26,
                  color: _kMaroon,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // MRZ strip — two mono lines on a soft grey ribbon.
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
                vertical: 8, horizontal: 10),
            decoration: const pw.BoxDecoration(
              color: PdfColor(0, 0, 0, 0.04),
              border: pw.Border(
                top: pw.BorderSide(color: _kInk, width: 0.4),
                bottom: pw.BorderSide(color: _kInk, width: 0.4),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  mrz1,
                  style: pw.TextStyle(
                    font: fonts.mono,
                    fontSize: 11,
                    color: _kInk,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  mrz2,
                  style: pw.TextStyle(
                    font: fonts.mono,
                    fontSize: 11,
                    color: _kInk,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _holderPhoto({
  required _Fonts fonts,
  required Uint8List? bytes,
  required String name,
}) {
  // 35×45mm-ish portrait frame with a soft gold border, like a real id photo.
  const w = 110.0;
  const h = 140.0;
  return pw.Container(
    width: w,
    height: h,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _kMaroon, width: 1.4),
      color: const PdfColor(0, 0, 0, 0.04),
    ),
    child: pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: bytes != null
          ? pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover)
          : pw.Container(
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                  colors: [_kMaroon, _kMaroonInk],
                ),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                _initial(name),
                style: pw.TextStyle(
                  font: fonts.displayBold,
                  fontSize: 56,
                  color: _kGold,
                ),
              ),
            ),
    ),
  );
}

pw.Widget _idRow(_Fonts fonts, String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fonts.mono,
            fontSize: 8,
            color: _kInkSoft,
            letterSpacing: 2.4,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fonts.displayBold,
            fontSize: 14,
            color: _kInk,
          ),
        ),
      ],
    ),
  );
}

// ── 3. TOC ───────────────────────────────────────────────────────────────────

List<pw.Widget> _tocChildren({
  required _Fonts fonts,
  required List<Visit> visits,
}) {
  // Pair entries up into a two-column grid.
  final pairs = <List<Visit>>[];
  for (var i = 0; i < visits.length; i += 2) {
    pairs.add([
      visits[i],
      if (i + 1 < visits.length) visits[i + 1],
    ]);
  }

  return [
    pw.Text(
      'STAMPED PASSAGES',
      style: pw.TextStyle(
        font: fonts.mono,
        fontSize: 10,
        color: _kMaroon,
        letterSpacing: 4,
      ),
    ),
    pw.SizedBox(height: 6),
    pw.Text(
      'A table of journeys',
      style: pw.TextStyle(
        font: fonts.script,
        fontSize: 22,
        color: _kInk,
      ),
    ),
    pw.SizedBox(height: 6),
    pw.Container(width: double.infinity, height: 1, color: _kGold),
    pw.SizedBox(height: 18),
    for (final pair in pairs)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _tocEntry(fonts, pair[0])),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pair.length > 1
                  ? _tocEntry(fonts, pair[1])
                  : pw.SizedBox(),
            ),
          ],
        ),
      ),
  ];
}

pw.Widget _tocEntry(_Fonts fonts, Visit v) {
  final flag = v.country?.flagEmoji ?? '\u{1F30D}';
  final name = v.country?.name ?? 'Unknown';
  final date = _fmtVisitedOn(v.visitedOn);
  final stars = _stars(v.rating);

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(
          color: PdfColor(_kInkSoft.red, _kInkSoft.green, _kInkSoft.blue, 0.3),
          width: 0.5,
          style: pw.BorderStyle.dotted,
        ),
      ),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          flag,
          style: pw.TextStyle(font: fonts.body, fontSize: 13),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            name,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              font: fonts.displayBold,
              fontSize: 11,
              color: _kInk,
            ),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          date,
          style: pw.TextStyle(
            font: fonts.mono,
            fontSize: 8,
            color: _kInkSoft,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          stars,
          style: pw.TextStyle(
            font: fonts.body,
            fontSize: 9,
            color: _kGoldDeep,
          ),
        ),
      ],
    ),
  );
}

String _stars(int rating) {
  final r = rating.clamp(0, 5);
  // Use unicode filled / empty stars for crisp glyphs in the embedded font.
  return ('★' * r) + ('☆' * (5 - r));
}

// ── 4. Per-visit pages ───────────────────────────────────────────────────────

pw.Widget _visitPage({
  required _Fonts fonts,
  required Visit visit,
  Uint8List? photo,
}) {
  return pw.Container(
    color: _kParchment,
    width: double.infinity,
    height: double.infinity,
    child: pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(48, 52, 48, 48),
      child: _visitBody(
        fonts: fonts,
        visit: visit,
        photo: photo,
        compact: false,
      ),
    ),
  );
}

pw.Widget _twoVisitPage({
  required _Fonts fonts,
  required Visit top,
  Uint8List? topPhoto,
  Visit? bottom,
  Uint8List? bottomPhoto,
}) {
  return pw.Container(
    color: _kParchment,
    width: double.infinity,
    height: double.infinity,
    child: pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(40, 44, 40, 44),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: _visitBody(
              fonts: fonts,
              visit: top,
              photo: topPhoto,
              compact: true,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1, color: _kGold),
          pw.SizedBox(height: 12),
          pw.Expanded(
            child: bottom == null
                ? pw.SizedBox()
                : _visitBody(
                    fonts: fonts,
                    visit: bottom,
                    photo: bottomPhoto,
                    compact: true,
                  ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _visitBody({
  required _Fonts fonts,
  required Visit visit,
  required Uint8List? photo,
  required bool compact,
}) {
  final iso = visit.country?.isoA2 ?? '';
  final region = visit.country?.region ?? '';
  final dish = dishFor(isoA2: iso, region: region).dish;
  final countryName = visit.country?.name ?? 'Unknown Country';
  final flag = visit.country?.flagEmoji ?? '\u{1F30D}';
  final dateStr = _fmtVisitedOn(visit.visitedOn);

  return pw.Stack(
    children: [
      // Main column.
      pw.Padding(
        padding: pw.EdgeInsets.only(right: compact ? 0 : 140),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  flag,
                  style: pw.TextStyle(
                      font: fonts.body, fontSize: compact ? 22 : 30),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    countryName,
                    maxLines: 2,
                    style: pw.TextStyle(
                      font: fonts.displayBold,
                      fontSize: compact ? 22 : 32,
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(width: 60, height: 1.2, color: _kGold),
            pw.SizedBox(height: compact ? 10 : 16),

            _visitRow(fonts, 'DISH TRIED', dish),
            if (region.isNotEmpty) _visitRow(fonts, 'REGION', region),
            _visitRow(fonts, 'DATE', dateStr),
            if ((visit.restaurantName ?? '').isNotEmpty)
              _visitRow(fonts, 'RESTAURANT', visit.restaurantName!),
            _visitRow(fonts, 'RATING', _stars(visit.rating)),

            if (visit.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: compact ? 8 : 14),
              pw.Text(
                'NOTES',
                style: pw.TextStyle(
                  font: fonts.mono,
                  fontSize: 8,
                  color: _kInkSoft,
                  letterSpacing: 2.4,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                visit.notes,
                maxLines: compact ? 3 : 8,
                style: pw.TextStyle(
                  font: fonts.script,
                  fontSize: compact ? 14 : 17,
                  color: _kMaroon,
                  lineSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),

      // Polaroid in the upper-right corner (only when there's a photo).
      if (photo != null)
        pw.Positioned(
          right: 0,
          top: compact ? 0 : 6,
          child: pw.Transform.rotate(
            angle: 0.045,
            child: _polaroid(
              fonts: fonts,
              bytes: photo,
              caption: dateStr,
              size: compact ? 110 : 150,
            ),
          ),
        ),

      // Inked "VISITED" stamp tilted near the bottom right of the body.
      pw.Positioned(
        right: compact ? 8 : 24,
        bottom: compact ? 4 : 24,
        child: pw.Transform.rotate(
          angle: -0.12,
          child: _visitedStamp(fonts: fonts, date: dateStr),
        ),
      ),
    ],
  );
}

pw.Widget _visitRow(_Fonts fonts, String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 84,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: fonts.mono,
              fontSize: 8,
              color: _kInkSoft,
              letterSpacing: 2.4,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: fonts.displayBold,
              fontSize: 12,
              color: _kInk,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _polaroid({
  required _Fonts fonts,
  required Uint8List bytes,
  required String caption,
  required double size,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(6, 6, 6, 18),
    decoration: const pw.BoxDecoration(
      color: PdfColors.white,
      boxShadow: [
        pw.BoxShadow(
          color: PdfColor(0, 0, 0, 0.18),
          blurRadius: 4,
          offset: PdfPoint(2, 3),
        ),
      ],
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: size,
          height: size,
          color: const PdfColor(0, 0, 0, 0.06),
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          caption,
          style: pw.TextStyle(
            font: fonts.script,
            fontSize: 12,
            color: _kInkSoft,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _visitedStamp({required _Fonts fonts, required String date}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _kMaroon, width: 1.6),
    ),
    child: pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'VISITED',
          style: pw.TextStyle(
            font: fonts.displayBold,
            fontSize: 18,
            color: _kMaroon,
            letterSpacing: 5,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          date,
          style: pw.TextStyle(
            font: fonts.mono,
            fontSize: 8,
            color: _kMaroon,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

// ── 5. Back cover ────────────────────────────────────────────────────────────

pw.Widget _backCover({
  required _Fonts fonts,
  required String holderName,
  required DateTime issuedOn,
}) {
  return pw.Container(
    color: _kMaroonDeep,
    width: double.infinity,
    height: double.infinity,
    child: pw.Stack(
      children: [
        pw.Positioned.fill(
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kGold, width: 1.4),
              ),
            ),
          ),
        ),
        pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'END OF PASSPORT',
                style: pw.TextStyle(
                  font: fonts.mono,
                  fontSize: 11,
                  color: _kGold,
                  letterSpacing: 5,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                issuedOn.year.toString(),
                style: pw.TextStyle(
                  font: fonts.displayBold,
                  fontSize: 64,
                  color: _kGold,
                  letterSpacing: 6,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Container(width: 80, height: 1, color: _kGold),
              pw.SizedBox(height: 32),
              pw.Text(
                holderName.isEmpty ? 'Gastro Traveller' : holderName,
                style: pw.TextStyle(
                  font: fonts.script,
                  fontSize: 28,
                  color: _kParchmentDeep,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(width: 200, height: 0.6, color: _kParchmentDeep),
            ],
          ),
        ),
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 50,
          child: pw.Center(
            child: pw.Text(
              'Issued by yourself — keep travelling.',
              style: pw.TextStyle(
                font: fonts.script,
                fontSize: 18,
                color: PdfColor(
                    _kParchmentDeep.red,
                    _kParchmentDeep.green,
                    _kParchmentDeep.blue,
                    0.85),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
