import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';

class ThemeSelectorScreen extends ConsumerStatefulWidget {
  const ThemeSelectorScreen({super.key, this.onThemeSelected});

  final VoidCallback? onThemeSelected;

  @override
  ConsumerState<ThemeSelectorScreen> createState() =>
      _ThemeSelectorScreenState();
}

class _ThemeSelectorScreenState extends ConsumerState<ThemeSelectorScreen> {
  GastroThemeMode? _selected;
  bool _starting = false;

  Future<void> _start() async {
    if (_selected == null || _starting) return;
    setState(() => _starting = true);
    await ref.read(gastroThemeProvider.notifier).select(_selected!);
    widget.onThemeSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final selectedConfig =
        _selected != null ? GastroThemeConfig.forMode(_selected!) : null;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          // ── Background accent glow (follows selection) ─────────────────
          if (selectedConfig != null)
            Positioned(
              top: -120,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: GS.slow,
                curve: GS.smooth,
                height: 400,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.0,
                    colors: [
                      selectedConfig.accent.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: GS.s32),

                // ── Header ──────────────────────────────────────────────
                Column(
                  children: [
                    Text(
                      'GASTROVOYAGE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        color: Colors.white38,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: GS.slow)
                        .slideY(begin: -0.3, end: 0, duration: GS.slow, curve: GS.smooth),
                    const SizedBox(height: GS.s16),
                    Text(
                      'Your Style,',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: GS.slow, delay: 120.ms)
                        .slideY(begin: 0.2, end: 0, duration: GS.slow, delay: 120.ms, curve: GS.smooth),
                    Text(
                      'Your Journey.',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: selectedConfig?.accent ?? Colors.white54,
                        height: 1.1,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: GS.slow, delay: 200.ms)
                        .slideY(begin: 0.2, end: 0, duration: GS.slow, delay: 200.ms, curve: GS.smooth),
                    const SizedBox(height: GS.s12),
                    Text(
                      'Choose the aesthetic that speaks to you',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        color: Colors.white38,
                        letterSpacing: 0.2,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: GS.slow, delay: 280.ms),
                  ],
                ),

                const SizedBox(height: GS.s32),

                // ── Theme cards ─────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: GS.s20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ThemeCard(
                            mode: GastroThemeMode.girls,
                            config: GastroThemeConfig.girls,
                            isSelected: _selected == GastroThemeMode.girls,
                            delay: 350.ms,
                            onTap: () => setState(() => _selected = GastroThemeMode.girls),
                          ),
                        ),
                        const SizedBox(width: GS.s10),
                        Expanded(
                          child: _ThemeCard(
                            mode: GastroThemeMode.couples,
                            config: GastroThemeConfig.couples,
                            isSelected: _selected == GastroThemeMode.couples,
                            delay: 450.ms,
                            onTap: () => setState(() => _selected = GastroThemeMode.couples),
                          ),
                        ),
                        const SizedBox(width: GS.s10),
                        Expanded(
                          child: _ThemeCard(
                            mode: GastroThemeMode.guys,
                            config: GastroThemeConfig.guys,
                            isSelected: _selected == GastroThemeMode.guys,
                            delay: 550.ms,
                            onTap: () => setState(() => _selected = GastroThemeMode.guys),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── CTA button ──────────────────────────────────────────
                AnimatedOpacity(
                  opacity: _selected != null ? 1.0 : 0.0,
                  duration: GS.normal,
                  child: AnimatedSlide(
                    offset: _selected != null
                        ? Offset.zero
                        : const Offset(0, 0.3),
                    duration: GS.normal,
                    curve: GS.spring,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GS.s24, GS.s20, GS.s24, GS.s32),
                      child: _BeginButton(
                        config: selectedConfig,
                        isLoading: _starting,
                        onTap: _start,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Theme Card ───────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.mode,
    required this.config,
    required this.isSelected,
    required this.delay,
    required this.onTap,
  });

  final GastroThemeMode mode;
  final GastroThemeConfig config;
  final bool isSelected;
  final Duration delay;
  final VoidCallback onTap;

  static const _moodWords = {
    GastroThemeMode.girls: ['Elegant', 'Floral', 'Soft'],
    GastroThemeMode.couples: ['Refined', 'Classic', 'Intimate'],
    GastroThemeMode.guys: ['Bold', 'Dark', 'Raw'],
  };

  @override
  Widget build(BuildContext context) {
    final words = _moodWords[mode]!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
          scale: isSelected ? 1.04 : 1.0,
          duration: GS.fast,
          curve: GS.spring,
          child: AnimatedContainer(
            duration: GS.fast,
            curve: GS.smooth,
            // height: double.infinity ensures Column gets bounded constraints
            // so Expanded inside works correctly
            constraints: const BoxConstraints.expand(),
            decoration: BoxDecoration(
              color: config.selectorCardBg,
              borderRadius: BorderRadius.circular(GS.r24),
              border: Border.all(
                color: isSelected
                    ? config.selectorAccent.withOpacity(0.7)
                    : Colors.white.withOpacity(0.07),
                width: isSelected ? 1.5 : 0.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: config.selectorAccent.withOpacity(0.30),
                        blurRadius: 32,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: config.selectorAccent.withOpacity(0.12),
                        blurRadius: 64,
                        spreadRadius: 4,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(GS.r24),
              child: Padding(
                padding: const EdgeInsets.all(GS.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Icon area ─────────────────────────────────────
                    AnimatedContainer(
                      duration: GS.fast,
                      width: double.infinity,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? config.selectorAccent.withOpacity(0.12)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(GS.r16),
                      ),
                      child: Stack(
                        children: [
                          for (int i = 0;
                              i < config.selectorIcons.length && i < 4;
                              i++)
                            Positioned(
                              left: (i % 2) * 28.0 + 10,
                              top: (i ~/ 2) * 32.0 + 8,
                              child: AnimatedScale(
                                scale: isSelected ? 1.0 : 0.88,
                                duration: GS.fast,
                                curve: GS.spring,
                                child: Icon(
                                  config.selectorIcons[i],
                                  size: i == 0 ? 26 : 18,
                                  color: isSelected
                                      ? config.selectorAccent
                                      : Colors.white38,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Expanded(child: SizedBox()),

                    // ── Theme icon + name ─────────────────────────────
                    Row(
                      children: [
                        Icon(
                          config.themeIcon,
                          size: 16,
                          color: isSelected
                              ? config.selectorAccent
                              : Colors.white38,
                        ),
                        const SizedBox(width: GS.s6),
                        Expanded(
                          child: Text(
                            config.name.toUpperCase(),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? config.selectorAccent
                                  : Colors.white38,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GS.s8),

                    // ── Mood words ────────────────────────────────────
                    ...words.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            w,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.white24,
                              height: 1.5,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        )),

                    const SizedBox(height: GS.s10),

                    // ── Selection indicator ────────────────────────────
                    // NOTE: never animate a dimension to/from
                    // `double.infinity` — interpolating an unbounded value
                    // yields Infinity/NaN sizes for the in-between frames,
                    // which throws a layout error (red error widget flashes
                    // for one frame, then recovers). Animate a *finite*
                    // `widthFactor` (0.0 → 1.0) via AnimatedFractionallySizedBox
                    // instead, and let the parent supply the bounded width.
                    SizedBox(
                      height: 2,
                      width: double.infinity,
                      child: AnimatedFractionallySizedBox(
                        duration: GS.fast,
                        curve: GS.smooth,
                        alignment: Alignment.centerLeft,
                        widthFactor: isSelected ? 1.0 : 0.0,
                        heightFactor: 1.0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: config.selectorAccent,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: GS.slow, delay: delay)
          .slideY(begin: 0.3, end: 0, duration: GS.slow, delay: delay, curve: GS.spring);
  }
}

// ─── Begin Button ─────────────────────────────────────────────────────────────

class _BeginButton extends StatelessWidget {
  const _BeginButton({
    required this.config,
    required this.isLoading,
    required this.onTap,
  });

  final GastroThemeConfig? config;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = config?.accent ?? Colors.white;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(GS.r16),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.40),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 56,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'BEGIN JOURNEY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(width: GS.s12),
                  const Icon(LucideIcons.arrowRight,
                      size: 18, color: Colors.white),
                ],
              ),
      ),
    );
  }
}
