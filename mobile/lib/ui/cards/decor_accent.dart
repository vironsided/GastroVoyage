import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';

/// Tiny themed decorative asset (candy / chrome exclamation / chrome music /
/// plumbob). Auto-selects nothing — caller picks which one to render.
///
/// Pure visual flourish: no interaction, just `Image.asset` with a slight
/// rotation and shadow.
enum DecorMotif {
  /// Pink wrapped candy — Girls only (photo 5).
  candy,

  /// Chrome metallic exclamation — Guys (photo 14).
  chromeExclamation,

  /// Chrome metallic music note — Guys (photo 15).
  chromeMusic,

  /// Sims-style green plumbob — Guys (photo 13).
  plumbob,
}

class DecorAccent extends StatelessWidget {
  const DecorAccent({
    super.key,
    required this.motif,
    this.size = 48,
    this.rotation = 0,
    this.dropShadow = true,
  });

  final DecorMotif motif;
  final double size;
  final double rotation;
  final bool dropShadow;

  /// Returns null if the motif doesn't match the active theme — caller can
  /// short-circuit. Keeps DecorAccent itself theme-agnostic so the same
  /// motif (e.g. plumbob) can be reused on a custom screen even outside
  /// Guys theme.
  static bool isAppropriateForMode(DecorMotif m, GastroThemeMode mode) {
    switch (m) {
      case DecorMotif.candy:
        return mode == GastroThemeMode.girls;
      case DecorMotif.chromeExclamation:
      case DecorMotif.chromeMusic:
      case DecorMotif.plumbob:
        return mode == GastroThemeMode.guys;
    }
  }

  String get _asset {
    switch (motif) {
      case DecorMotif.candy:
        return 'assets/components/girls/candy.png';
      case DecorMotif.chromeExclamation:
        return 'assets/components/guys/chrome_exclamation.png';
      case DecorMotif.chromeMusic:
        return 'assets/components/guys/chrome_music.png';
      case DecorMotif.plumbob:
        return 'assets/components/guys/plumbob.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );

    if (dropShadow) {
      content = Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: content,
      );
    }

    if (rotation != 0) {
      content = Transform.rotate(angle: rotation, child: content);
    }

    return SizedBox(width: size, height: size, child: content);
  }
}
