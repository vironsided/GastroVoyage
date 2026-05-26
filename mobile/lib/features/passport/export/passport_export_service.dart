// Orchestrates the "Export passport" user flow:
//   1. Reads holder + visit data from providers.
//   2. Shows a parchment-themed loader while the PDF is built.
//   3. Hands the bytes to the native share sheet via `printing`.
//
// All errors are caught and surfaced through a themed SnackBar — the user
// never sees a raw stack trace, but the loader is always dismissed.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/passport/export/passport_pdf.dart';
import 'package:mobile/features/shared/models.dart';

const Color _kParchment = Color(0xFFFAF5E6);
const Color _kParchmentDeep = Color(0xFFEBD9B5);
const Color _kGold = Color(0xFFD4A843);
const Color _kMaroon = Color(0xFF5D2E2E);

class PassportExportService {
  PassportExportService._();

  /// Builds the user's passport PDF and presents the native share sheet.
  /// The supplied [visits] are used as-is — callers should pass the same list
  /// the passport screen is rendering, so the PDF matches what the user sees.
  static Future<void> exportAndShare(
    BuildContext context,
    WidgetRef ref, {
    required List<Visit> visits,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    final auth = ref.read(authProvider);
    final holderName = (auth.displayName ?? '').trim().isEmpty
        ? 'Gastro Traveller'
        : auth.displayName!.trim();
    final homeCity = auth.homeCity;

    // Profile is a FutureProvider — read whatever's currently resolved.
    final profile = ref.read(profileProvider).maybeWhen(
          data: (p) => p,
          orElse: () => null,
        );
    final avatarUrl = profile?.avatarUrl;
    final visitedCount =
        profile?.visitedCount ?? visits.length;
    final badgeCount = profile == null
        ? 0
        : profile.badges.where(_isEarnedBadge).length;

    // Show the loader — non-dismissible so the user can't tap-spam it.
    bool dialogOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ExportLoadingDialog(),
    ).whenComplete(() => dialogOpen = false));

    Future<void> closeLoader() async {
      if (dialogOpen && navigator.canPop()) {
        navigator.pop();
        dialogOpen = false;
      }
    }

    try {
      final Uint8List bytes = await buildPassportPdf(
        holderName: holderName,
        homeCity: homeCity,
        avatarUrl: avatarUrl,
        visitedCount: visitedCount,
        badgeCount: badgeCount,
        visits: visits,
        issuedOn: DateTime.now(),
      );

      await closeLoader();

      final filename = 'gastrovoyage-passport-${DateTime.now().year}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      await closeLoader();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: _kMaroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GS.r12),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: _kGold, size: 18),
              const SizedBox(width: GS.s10),
              Expanded(
                child: Text(
                  'Could not export your passport. Please try again.',
                  style: GoogleFonts.hankenGrotesk(
                    color: _kParchment,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// A badge entry may be a raw `CuisineBadge` or the JSON map the API
  /// returns — handle both so we don't crash on either shape.
  static bool _isEarnedBadge(dynamic b) {
    if (b is CuisineBadge) return b.earned;
    if (b is Map) return b['earned'] == true;
    return false;
  }
}

class _ExportLoadingDialog extends StatelessWidget {
  const _ExportLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      child: Container(
        padding: const EdgeInsets.fromLTRB(GS.s24, GS.s24, GS.s24, GS.s20),
        decoration: BoxDecoration(
          color: _kParchment,
          borderRadius: BorderRadius.circular(GS.r16),
          border: Border.all(color: _kGold.withOpacity(0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(_kGold),
                backgroundColor: _kParchmentDeep,
              ),
            ),
            const SizedBox(height: GS.s16),
            Text(
              'STAMPING YOUR PASSPORT',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: _kMaroon,
                letterSpacing: 3.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: GS.s4),
            Text(
              'binding the pages…',
              textAlign: TextAlign.center,
              style: GoogleFonts.caveat(
                fontSize: 18,
                color: _kMaroon.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
