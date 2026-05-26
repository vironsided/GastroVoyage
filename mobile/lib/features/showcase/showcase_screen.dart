// Visual showcase of every UI kit component.
//
// Acts as a living design-system page — switch themes via account settings
// and reopen this screen to see how each component morphs. Also useful as
// a regression check when extending the kit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/ui/ui.dart';

class ShowcaseScreen extends ConsumerWidget {
  const ShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.05 : 0.08,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    GS.s20, GS.s12, GS.s20, GS.navBuffer),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Header(config: config, onClose: () => Navigator.pop(context)),
                    const SizedBox(height: GS.s24),

                    _GroupHeading(label: 'CORE COMPONENTS', config: config),
                    _CoreShowcase(config: config),

                    const SizedBox(height: GS.s32),
                    _GroupHeading(label: 'SCRAPBOOK — UNIVERSAL', config: config),
                    _UniversalShowcase(config: config),

                    const SizedBox(height: GS.s32),
                    _GroupHeading(label: 'GIRLS THEME ACCENTS', config: config),
                    _GirlsShowcase(config: config),

                    const SizedBox(height: GS.s32),
                    _GroupHeading(label: 'COUPLES THEME ACCENTS', config: config),
                    _CouplesShowcase(config: config),

                    const SizedBox(height: GS.s32),
                    _GroupHeading(label: 'GUYS THEME ACCENTS', config: config),
                    _GuysShowcase(config: config),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.config, required this.onClose});
  final GastroThemeConfig config;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          icon: Icon(LucideIcons.arrowLeft, color: config.onSurface),
        ),
        const SizedBox(width: GS.s4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Design Showcase',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                config.name.toUpperCase() + ' · ' + config.tagline,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: config.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.label, required this.config});
  final String label;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GS.s12),
      child: SectionHeader(label: label, config: config),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.title,
    required this.child,
    required this.config,
    this.height = 140,
  });
  final String title;
  final Widget child;
  final GastroThemeConfig config;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GS.s12),
      margin: const EdgeInsets.only(bottom: GS.s12),
      decoration: BoxDecoration(
        color: config.surface.withOpacity(0.65),
        borderRadius: BorderRadius.circular(GS.r16),
        border: Border.all(color: config.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: config.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: GS.s8),
          SizedBox(
            height: height,
            width: double.infinity,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

// ─── Core components ─────────────────────────────────────────────────────────

class _CoreShowcase extends StatelessWidget {
  const _CoreShowcase({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ItemTile(
          title: 'GastroButton — filled / outlined / ghost',
          config: config,
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GastroButton(
                label: 'PRIMARY ACTION',
                onPressed: () {},
                config: config,
                icon: LucideIcons.arrowRight,
              ),
              const SizedBox(height: GS.s8),
              GastroButton(
                label: 'OUTLINED',
                onPressed: () {},
                config: config,
                variant: GastroButtonVariant.outlined,
              ),
              const SizedBox(height: GS.s8),
              _LoadingButtonDemo(config: config),
            ],
          ),
        ),
        _ItemTile(
          title: 'GastroChip — selected / unselected',
          config: config,
          height: 60,
          child: Wrap(
            spacing: GS.s8,
            children: [
              GastroChip(
                label: 'Asia',
                selected: true,
                onTap: () {},
                config: config,
              ),
              GastroChip(
                label: 'Europe',
                selected: false,
                onTap: () {},
                config: config,
              ),
              GastroChip(
                label: 'Verified',
                selected: false,
                onTap: () {},
                config: config,
                icon: LucideIcons.checkCircle,
              ),
            ],
          ),
        ),
        _ItemTile(
          title: 'GastroShimmer — loading state',
          config: config,
          height: 70,
          child: GastroShimmer(config: config, height: 60),
        ),
        _ItemTile(
          title: 'GastroErrorCard',
          config: config,
          height: 80,
          child: GastroErrorCard(
            config: config,
            message: 'Could not load. Tap retry to try again.',
            onRetry: () {},
          ),
        ),
        _ItemTile(
          title: 'SectionHeader',
          config: config,
          height: 50,
          child: SectionHeader(
            label: 'Recently Tasted',
            config: config,
            subtitle: '24 visits',
          ),
        ),
      ],
    );
  }
}

// ─── Universal scrapbook ─────────────────────────────────────────────────────

class _UniversalShowcase extends StatelessWidget {
  const _UniversalShowcase({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ItemTile(
          title: 'ThemedMapPin · theme-adaptive',
          config: config,
          height: 80,
          child: ThemedMapPin(config: config),
        ),
        _ItemTile(
          title: 'StampBadge — ink rough-edge stamp',
          config: config,
          height: 120,
          child: StampBadge(
            label: 'TRIED\nJAPAN',
            config: config,
            size: 100,
            icon: LucideIcons.utensils,
            rotation: -0.08,
          ),
        ),
        _ItemTile(
          title: 'PostageStamp — perforated travel relic',
          config: config,
          height: 240,
          child: PostageStamp(
            config: config,
            width: 180,
            height: 220,
            priceLabel: '150 cents',
            placeLabel: 'TOKYO',
            child: Container(
              color: config.accent.withOpacity(0.15),
              child: Center(
                child: Icon(LucideIcons.utensils,
                    size: 56, color: config.accent),
              ),
            ),
          ),
        ),
        _ItemTile(
          title: 'InstaxFrame — polaroid with binder clip',
          config: config,
          height: 180,
          child: InstaxFrame(
            config: config,
            photoHeight: 100,
            width: 120,
            caption: 'kyoto, may',
            showClip: true,
            placeholder: Container(
              color: config.accent.withOpacity(0.20),
              child: Center(
                child: Icon(LucideIcons.camera,
                    size: 32, color: config.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Per-theme ───────────────────────────────────────────────────────────────

class _GirlsShowcase extends StatelessWidget {
  const _GirlsShowcase({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ItemTile(
          title: 'LaceRibbon (girls-only, asset)',
          config: config,
          height: 80,
          child: LaceRibbon(config: config),
        ),
        _ItemTile(
          title: 'WaxSeal — pink with bow (photo 9)',
          config: config,
          height: 120,
          child: WaxSeal(
            config: config,
            size: 96,
            label: 'AZ',
          ),
        ),
        _ItemTile(
          title: 'DecorAccent.candy (girls only)',
          config: config,
          height: 100,
          child: const DecorAccent(
            motif: DecorMotif.candy,
            size: 80,
            rotation: 0.12,
          ),
        ),
      ],
    );
  }
}

class _CouplesShowcase extends StatelessWidget {
  const _CouplesShowcase({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ItemTile(
          title: 'WaxSeal — blue with bow (photo 10)',
          config: config,
          height: 120,
          child: WaxSeal(config: config, size: 96),
        ),
        _ItemTile(
          title: 'EnvelopeCard — paper envelope',
          config: config,
          height: 200,
          child: EnvelopeCard(config: config, width: 180, height: 180),
        ),
        _ItemTile(
          title: 'StripedFrame — pinstripe with cutout',
          config: config,
          height: 200,
          child: StripedFrame(
            config: config,
            cutoutRadius: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.heart, color: config.accent, size: 32),
                const SizedBox(height: GS.s4),
                Text(
                  'Together',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GuysShowcase extends StatelessWidget {
  const _GuysShowcase({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ItemTile(
          title: 'AnimatedPlumbob — Sims-style floating diamond',
          config: config,
          height: 80,
          child: const AnimatedPlumbob(size: 48),
        ),
        _ItemTile(
          title: 'Chrome accents (! · music)',
          config: config,
          height: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              DecorAccent(
                motif: DecorMotif.chromeExclamation,
                size: 72,
                rotation: -0.10,
              ),
              DecorAccent(
                motif: DecorMotif.chromeMusic,
                size: 72,
                rotation: 0.12,
              ),
            ],
          ),
        ),
        _ItemTile(
          title: 'WaxSeal — metal disk fallback (no chrome wax in refs)',
          config: config,
          height: 110,
          child: WaxSeal(config: config, size: 88, label: 'PRO'),
        ),
      ],
    );
  }
}

/// Showcase demo of [GastroButton]'s loading state. Tapping flips it into the
/// loading state for ~1.4 s, then settles back — the state is demonstrable
/// without a spinner being stuck on screen forever (it previously hard-coded
/// `isLoading: true`, which read as a frozen loader).
class _LoadingButtonDemo extends StatefulWidget {
  const _LoadingButtonDemo({required this.config});
  final GastroThemeConfig config;

  @override
  State<_LoadingButtonDemo> createState() => _LoadingButtonDemoState();
}

class _LoadingButtonDemoState extends State<_LoadingButtonDemo> {
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GastroButton(
      label: _loading ? 'LOADING…' : 'TAP TO LOAD',
      onPressed: _loading ? () {} : _run,
      config: widget.config,
      isLoading: _loading,
    );
  }
}
