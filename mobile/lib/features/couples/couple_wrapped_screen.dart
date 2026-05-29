import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/ai/data/ai_models.dart';
import 'package:mobile/features/ai/data/ai_providers.dart';

/// "Couple Wrapped" — full-screen swipeable story Mobile renders from
/// the `/couples/wrapped` AI endpoint.
///
/// Each scene is one page in a PageView (Instagram-stories pattern). The
/// first page is the headline; the last is the closing line; in between
/// are 4-5 scenes with a stat tile + paragraph.
///
/// Tap right side → next scene. Tap left → previous. AppBar shows a
/// thin progress indicator at the top of each scene.
class CoupleWrappedScreen extends ConsumerWidget {
  const CoupleWrappedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    final wrappedAsync = ref.watch(coupleWrappedProvider);

    return Scaffold(
      backgroundColor: config.background,
      appBar: AppBar(
        backgroundColor: config.background,
        elevation: 0,
        iconTheme: IconThemeData(color: config.onSurface),
        title: Text(
          'Couple Wrapped',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: config.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Try another',
            icon: Icon(LucideIcons.refreshCw, color: config.onSurface),
            onPressed: () => ref.invalidate(coupleWrappedProvider),
          ),
        ],
      ),
      body: wrappedAsync.when(
        loading: () => _LoadingState(config: config),
        error: (e, _) => _ErrorState(error: e, config: config, ref: ref),
        data: (w) => _WrappedReader(wrapped: w, config: config),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GS.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.sparkles, size: 36, color: config.accent),
            const SizedBox(height: GS.s16),
            Text(
              'Unwrapping your story…',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
            const SizedBox(height: GS.s8),
            Text(
              'Claude is reading every joint plate and writing your recap. '
              'Give it 10-20 seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.caveat(
                fontSize: 18,
                color: config.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: GS.s24),
            CircularProgressIndicator(color: config.accent),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.config,
    required this.ref,
  });
  final Object error;
  final GastroThemeConfig config;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final s = error.toString();
    final friendly = s.contains('409')
        ? 'Log at least 3 joint visits before unwrapping a Wrapped — your story needs material to work from.'
        : s.contains('503')
            ? 'AI is not configured on this server yet.'
            : 'Could not generate your Wrapped. Try again in a moment.';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GS.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.heartCrack, size: 36, color: config.accent),
            const SizedBox(height: GS.s12),
            Text(
              friendly,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                height: 1.5,
                color: config.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: GS.s20),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(coupleWrappedProvider),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: config.onSurface,
                side: BorderSide(color: config.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GS.r16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrappedReader extends StatefulWidget {
  const _WrappedReader({required this.wrapped, required this.config});
  final CoupleWrapped wrapped;
  final GastroThemeConfig config;

  @override
  State<_WrappedReader> createState() => _WrappedReaderState();
}

class _WrappedReaderState extends State<_WrappedReader> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _pageCount =>
      widget.wrapped.scenes.length + 2; // headline + scenes + closing

  void _next() {
    if (_index < _pageCount - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _prev() {
    if (_index > 0) {
      _controller.previousPage(
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return SafeArea(
      child: Column(
        children: [
          // Story-style progress bar — one segment per page.
          Padding(
            padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s12, GS.s12),
            child: Row(
              children: List.generate(_pageCount, (i) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i <= _index
                          ? config.accent
                          : config.accent.withOpacity(0.15),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                final w = MediaQuery.of(context).size.width;
                if (d.localPosition.dx < w / 3) {
                  _prev();
                } else {
                  _next();
                }
              },
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pageCount,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _HeadlinePage(
                        headline: widget.wrapped.headline, config: config);
                  }
                  if (i == _pageCount - 1) {
                    return _ClosingPage(
                        closing: widget.wrapped.closing, config: config);
                  }
                  return _ScenePage(
                    scene: widget.wrapped.scenes[i - 1],
                    sceneNumber: i,
                    totalScenes: widget.wrapped.scenes.length,
                    config: config,
                  );
                },
              ),
            ),
          ),
          // Bottom hint
          Padding(
            padding: const EdgeInsets.fromLTRB(GS.s24, GS.s8, GS.s24, GS.s16),
            child: Text(
              _index == _pageCount - 1
                  ? 'Tap refresh to roll a new Wrapped.'
                  : 'Tap right to continue · left to go back',
              textAlign: TextAlign.center,
              style: GoogleFonts.caveat(
                fontSize: 15,
                color: config.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlinePage extends StatelessWidget {
  const _HeadlinePage({required this.headline, required this.config});
  final String headline;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GS.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(LucideIcons.heart, size: 40, color: config.accent),
          const SizedBox(height: GS.s16),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenePage extends StatelessWidget {
  const _ScenePage({
    required this.scene,
    required this.sceneNumber,
    required this.totalScenes,
    required this.config,
  });
  final CoupleWrappedScene scene;
  final int sceneNumber;
  final int totalScenes;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GS.s24, vertical: GS.s12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SCENE $sceneNumber / $totalScenes',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
                color: config.accent,
              ),
            ),
            const SizedBox(height: GS.s10),
            Text(
              scene.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
                height: 1.15,
              ),
            ),
            if (scene.statValue != null && scene.statValue!.isNotEmpty) ...[
              const SizedBox(height: GS.s16),
              Container(
                padding: const EdgeInsets.all(GS.s16),
                decoration: BoxDecoration(
                  color: config.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(GS.r16),
                  border: Border.all(color: config.accent.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (scene.statLabel != null &&
                              scene.statLabel!.isNotEmpty)
                            Text(
                              scene.statLabel!.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                                color: config.accent,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            scene.statValue!,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: config.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: GS.s16),
            Text(
              scene.body,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15,
                height: 1.6,
                color: config.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingPage extends StatelessWidget {
  const _ClosingPage({required this.closing, required this.config});
  final String closing;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GS.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            closing,
            textAlign: TextAlign.center,
            style: GoogleFonts.caveat(
              fontSize: 28,
              color: config.accent,
              height: 1.3,
            ),
          ),
          const SizedBox(height: GS.s16),
          Icon(LucideIcons.heart, size: 24, color: config.accent),
        ],
      ),
    );
  }
}
