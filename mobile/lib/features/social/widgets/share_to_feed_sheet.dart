import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/ui/ui.dart';

/// Scrapbook-styled bottom sheet for publishing a passport visit photo to the
/// social feed. Shows the photo in a tilted Instax frame and lets the user pen
/// an optional handwritten caption.
///
/// Returns the trimmed caption string when the user confirms (empty string if
/// they left it blank), or `null` if they dismiss the sheet.
class ShareToFeedSheet extends StatefulWidget {
  const ShareToFeedSheet({
    super.key,
    required this.config,
    required this.photoUrl,
    this.countryName,
  });

  final GastroThemeConfig config;
  final String photoUrl;
  final String? countryName;

  /// Opens the sheet and resolves to the caption (possibly empty) or `null`.
  static Future<String?> show(
    BuildContext context, {
    required GastroThemeConfig config,
    required String photoUrl,
    String? countryName,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareToFeedSheet(
        config: config,
        photoUrl: photoUrl,
        countryName: countryName,
      ),
    );
  }

  @override
  State<ShareToFeedSheet> createState() => _ShareToFeedSheetState();
}

class _ShareToFeedSheetState extends State<ShareToFeedSheet> {
  final TextEditingController _captionCtrl = TextEditingController();

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  void _publish() {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_captionCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(
          left: GS.s12, right: GS.s12, bottom: GS.s12 + bottom),
      padding: const EdgeInsets.fromLTRB(GS.s24, GS.s16, GS.s24, GS.s24),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: config.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: GS.s20),
            Text(
              'SHARE TO FEED',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
                color: config.accent,
              ),
            ),
            const SizedBox(height: GS.s4),
            Text(
              'Post this tasting',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
            const SizedBox(height: GS.s20),

            // Instax preview of the photo, tilted like a pinned snapshot.
            Center(
              child: InstaxFrame(
                config: config,
                photoUrl: widget.photoUrl,
                caption: widget.countryName,
                width: 180,
                photoHeight: 180,
                bottomPadding: 30,
                rotation: -0.04,
                showClip: true,
              ),
            ),
            const SizedBox(height: GS.s24),

            Text(
              'Add a handwritten note',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: config.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: GS.s8),

            // Caption field — Caveat font so it reads as ink on paper.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: GS.s16, vertical: GS.s4),
              decoration: BoxDecoration(
                color: config.surfaceVariant,
                borderRadius: BorderRadius.circular(GS.r16),
                border: Border.all(color: config.outlineVariant),
              ),
              child: TextField(
                controller: _captionCtrl,
                maxLines: 3,
                minLines: 1,
                maxLength: 180,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: config.accent,
                style: GoogleFonts.caveat(
                  fontSize: 20,
                  color: config.onSurface,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: config.onSurfaceVariant.withOpacity(0.6),
                  ),
                  hintText: 'a taste worth remembering…',
                  hintStyle: GoogleFonts.caveat(
                    fontSize: 20,
                    color: config.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: GS.s16),

            GastroButton(
              label: 'POST TO FEED',
              icon: Icons.send_rounded,
              config: config,
              onPressed: _publish,
            ),
            const SizedBox(height: GS.s8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Not now',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: config.onSurfaceVariant,
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
