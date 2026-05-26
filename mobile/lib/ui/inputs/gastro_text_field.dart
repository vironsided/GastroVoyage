import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Themed text field used across login, account, dish detail (visit form).
/// Adapts to dark/light themes via `config.isDark`.
class GastroTextField extends StatelessWidget {
  const GastroTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.config,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.maxLines = 1,
    this.minLines,
  });

  final TextEditingController controller;
  final String label;
  final GastroThemeConfig config;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final int maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    final dark = config.isDark;
    final textColor = dark ? Colors.white : config.onSurface;
    final hint = dark ? Colors.white38 : config.onSurfaceVariant.withOpacity(0.7);
    final fill = dark ? const Color(0xFF1C1C1C) : config.surface;
    final border = dark ? Colors.white.withOpacity(0.07) : config.outlineVariant;

    OutlineInputBorder buildBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r16),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      style: GoogleFonts.hankenGrotesk(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hankenGrotesk(color: hint, fontSize: 14),
        prefixIcon: icon != null ? Icon(icon, color: hint, size: 20) : null,
        suffixIcon: suffixIcon != null
            ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon)
            : null,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: buildBorder(Colors.transparent),
        enabledBorder: buildBorder(border),
        focusedBorder: buildBorder(config.accent, 1.5),
        errorBorder: buildBorder(config.error),
        focusedErrorBorder: buildBorder(config.error.withOpacity(0.85), 1.5),
        errorStyle: GoogleFonts.hankenGrotesk(fontSize: 12, color: config.error),
      ),
    );
  }
}
