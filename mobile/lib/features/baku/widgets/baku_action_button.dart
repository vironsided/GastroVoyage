import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact 36-pixel-tall action button used inside all three Baku theme
/// cards (Girls / Couples / Guys). Two variants: filled (default) and
/// outlined.
class BakuActionButton extends StatelessWidget {
  const BakuActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(10),
          border: outlined ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: outlined ? color : Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: outlined ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── URL helpers ─────────────────────────────────────────────────────────────

/// Opens the device's preferred maps app at the given coordinates. Falls back
/// to Google Maps web if no native geo handler is registered.
Future<void> openMaps(double lat, double lng, String name) async {
  final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
  if (await canLaunchUrl(geo)) {
    await launchUrl(geo, mode: LaunchMode.externalApplication);
    return;
  }
  await launchUrl(
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    mode: LaunchMode.externalApplication,
  );
}

/// Opens the user's Instagram profile, preferring the app if installed.
Future<void> openInstagram(String handle) async {
  final app = Uri.parse('instagram://user?username=$handle');
  final web = Uri.parse('https://instagram.com/$handle');
  if (await canLaunchUrl(app)) {
    await launchUrl(app, mode: LaunchMode.externalApplication);
  } else {
    await launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
