import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/ai/data/ai_models.dart';
import 'package:mobile/features/ai/data/ai_providers.dart';

/// Dashboard card that calls Claude for 3 cuisine recommendations. The
/// card itself is collapsed by default — tapping "What to taste next" fires
/// the request lazily so we don't burn Claude tokens on every dashboard
/// load. State machine: collapsed → loading → data | error.
class CuisineRecommendationsCard extends ConsumerStatefulWidget {
  const CuisineRecommendationsCard({super.key, required this.config});
  final GastroThemeConfig config;

  @override
  ConsumerState<CuisineRecommendationsCard> createState() =>
      _CuisineRecommendationsCardState();
}

class _CuisineRecommendationsCardState
    extends ConsumerState<CuisineRecommendationsCard> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final asyncRecs = _opened
        ? ref.watch(cuisineRecommendationsProvider)
        : const AsyncValue<AiCuisineRecommendations>.loading();

    return Container(
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(color: config.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GS.r20),
              onTap: () {
                if (!_opened) {
                  setState(() => _opened = true);
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(GS.s16, GS.s14, GS.s16, GS.s14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: config.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(GS.r10),
                      ),
                      child: Icon(LucideIcons.compass, color: config.accent),
                    ),
                    const SizedBox(width: GS.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WHAT TO TASTE NEXT · AI',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                              color: config.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _opened
                                ? '3 cuisines picked for you'
                                : 'Tap to ask Claude for 3 picks',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: config.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_opened)
                      IconButton(
                        tooltip: 'Reroll',
                        icon: Icon(LucideIcons.refreshCw,
                            size: 18, color: config.onSurfaceVariant),
                        onPressed: () =>
                            ref.invalidate(cuisineRecommendationsProvider),
                      )
                    else
                      Icon(LucideIcons.sparkles,
                          color: config.accent, size: 18),
                  ],
                ),
              ),
            ),
          ),
          if (_opened) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GS.s14, GS.s12, GS.s14, GS.s14),
              child: asyncRecs.when(
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: GS.s12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: config.accent),
                      ),
                      const SizedBox(width: GS.s10),
                      Text(
                        'Claude is reading your visits…',
                        style: GoogleFonts.caveat(
                          fontSize: 16,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (e, _) => _errorView(e, config),
                data: (recs) {
                  if (recs.items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(GS.s12),
                      child: Text(
                        'Nothing to recommend yet.',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < recs.items.length; i++) ...[
                        _RecommendationTile(
                            rec: recs.items[i], config: config),
                        if (i < recs.items.length - 1)
                          const SizedBox(height: GS.s8),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorView(Object e, GastroThemeConfig config) {
    final s = e.toString();
    final msg = s.contains('409')
        ? 'Log a few visits first — there\'s nothing to recommend from yet.'
        : s.contains('404')
            ? 'You\'ve tasted every country on the map — astonishing.'
            : s.contains('503')
                ? 'AI is not configured on this server yet.'
                : 'Could not pick cuisines. Try again.';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GS.s8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                height: 1.5,
                color: config.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.invalidate(cuisineRecommendationsProvider),
            child: Text('Retry', style: TextStyle(color: config.accent)),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.rec, required this.config});
  final AiCuisineRecommendation rec;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final flag = rec.flagEmoji?.trim();
    return Container(
      padding: const EdgeInsets.all(GS.s12),
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.r12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flag != null && flag.isNotEmpty) ...[
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: GS.s10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.countryName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                    height: 1.1,
                  ),
                ),
                if (rec.signatureDish.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'start with ${rec.signatureDish}',
                    style: GoogleFonts.caveat(
                      fontSize: 16,
                      color: config.accent,
                    ),
                  ),
                ],
                if (rec.reasoning.isNotEmpty) ...[
                  const SizedBox(height: GS.s4),
                  Text(
                    rec.reasoning,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      height: 1.45,
                      color: config.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
