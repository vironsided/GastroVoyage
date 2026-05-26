import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';

/// Photo-realistic embossed wax seal with a bow center. Used to mark verified
/// visits, sealed achievements, or "official" stamps.
///
/// The PNG asset is per-theme:
///   • Girls   → pink wax (assets/components/girls/wax_seal.png — ref photo 9)
///   • Couples → blue wax (assets/components/couples/wax_seal.png — ref photo 10)
///   • Guys    → falls back to procedural metallic disk (no chrome seal asset)
class WaxSeal extends StatelessWidget {
  const WaxSeal({
    super.key,
    required this.config,
    this.size = 64,
    this.rotation = -0.12,
    this.label,
  });

  final GastroThemeConfig config;
  final double size;

  /// Tilt in radians for a "stamped a bit crooked" look.
  final double rotation;

  /// Optional text rendered over the seal (kept short — initials work best).
  final String? label;

  String? _assetForMode() {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return 'assets/components/girls/wax_seal.png';
      case GastroThemeMode.couples:
        return 'assets/components/couples/wax_seal.png';
      case GastroThemeMode.guys:
        return null; // procedural fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _assetForMode();
    final inner = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (asset != null)
            Image.asset(asset, width: size, height: size, fit: BoxFit.contain)
          else
            _MetallicSeal(size: size, color: config.accent),
          if (label != null)
            Text(
              label!,
              style: GoogleFonts.playfairDisplay(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.85),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return Transform.rotate(angle: rotation, child: inner);
  }
}

/// Fallback for Guys theme — no pink/blue wax fits. Renders a metallic
/// disk with a soft highlight to feel like a brushed-steel emblem.
class _MetallicSeal extends StatelessWidget {
  const _MetallicSeal({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 0.95,
          colors: [
            const Color(0xFFE0E0E0),
            const Color(0xFF8C8C8C),
            const Color(0xFF3A3A3A),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
    );
  }
}
