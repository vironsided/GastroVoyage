import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';

/// Circular passport-portrait avatar. Loads [avatarUrl] via CachedNetworkImage
/// and falls back to a tinted initial-letter disc whenever the URL is missing,
/// loading, or fails. Bordered like a stamped portrait.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.config,
    required this.initial,
    this.avatarUrl,
    this.size = 48,
    this.borderColor,
    this.borderWidth = 2,
  });

  final GastroThemeConfig config;
  final String initial;
  final String? avatarUrl;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  Widget _fallback() {
    return Container(
      color: config.accentSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.playfairDisplay(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: config.accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: config.accentSoft,
        border: Border.all(
          color: borderColor ?? config.outlineVariant,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }
}
