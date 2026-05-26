import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';

/// Real-lace ribbon decoration (photo 6). PNG asset rendered as a thin
/// strip, used as a top/bottom border on Girls-mode cards.
///
/// Falls back to procedural `LacePainter` for non-Girls themes (caller can
/// just hide this widget for those — it's an opt-in flourish).
class LaceRibbon extends StatelessWidget {
  const LaceRibbon({
    super.key,
    required this.config,
    this.height = 36,
    this.color,
    this.position = LaceRibbonPosition.bottom,
  });

  final GastroThemeConfig config;
  final double height;

  /// Optional tint applied via `colorBlendMode` — useful if the white lace
  /// looks too sterile on a colored background.
  final Color? color;

  final LaceRibbonPosition position;

  @override
  Widget build(BuildContext context) {
    // Real lace asset is white-on-transparent — only meaningful on
    // light/girls themes.
    if (config.mode != GastroThemeMode.girls) {
      return const SizedBox.shrink();
    }

    final ribbon = SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(
        'assets/components/girls/lace.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
        color: color,
        colorBlendMode: color != null ? BlendMode.modulate : BlendMode.dstIn,
      ),
    );

    switch (position) {
      case LaceRibbonPosition.top:
        return ribbon;
      case LaceRibbonPosition.bottom:
        // Flip vertically so the scallops face downward
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, -1.0),
          child: ribbon,
        );
    }
  }
}

enum LaceRibbonPosition { top, bottom }
