import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/ui/painters/envelope_painter.dart';

/// Decorative envelope visual. Use as a message indicator, the cover of
/// "letter from your journey", or as accent in couples-mode share dialogs.
class EnvelopeCard extends StatelessWidget {
  const EnvelopeCard({
    super.key,
    required this.config,
    this.width = 180,
    this.height = 180,
    this.rotation = -0.05,
    this.envelopeColor,
    this.letterColor = const Color(0xFFFAFAFA),
  });

  final GastroThemeConfig config;
  final double width;
  final double height;
  final double rotation;
  final Color? envelopeColor;
  final Color letterColor;

  Color _defaultEnvelope() {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return const Color(0xFFFCE0EA);
      case GastroThemeMode.couples:
        return const Color(0xFFD7E7F4);
      case GastroThemeMode.guys:
        return const Color(0xFF2A2A2A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = envelopeColor ?? _defaultEnvelope();
    final letter = config.mode == GastroThemeMode.guys
        ? const Color(0xFFF2F2F2)
        : letterColor;

    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: EnvelopePainter(
            envelopeColor: env,
            letterColor: letter,
            accentColor: config.accent.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
