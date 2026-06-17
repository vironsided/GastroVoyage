import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/passport/passport_screen.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/vault/widgets/journal_entry_card.dart';
import 'package:mobile/features/vault/widgets/vault_empty_state.dart';
import 'package:mobile/features/vault/widgets/vault_header.dart';
import 'package:mobile/features/vault/widgets/vault_loading.dart';
import 'package:mobile/ui/ui.dart';

void _openPassport(BuildContext context, List<Visit> visits, int index,
    {bool openImmediately = false}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 550),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      opaque: true,
      pageBuilder: (_, __, ___) => PassportScreen(
        visits: visits,
        initialVisitIndex: index,
        openImmediately: openImmediately,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scale = Tween<double>(begin: 0.88, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    ),
  );
}

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    final visitsAsync = ref.watch(visitsProvider);

    return Scaffold(
      backgroundColor: config.background,
      // Procedural paper texture turns the whole Vault into a scrapbook page.
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.05 : 0.05,
        scratchCount: 5,
        child: CustomScrollView(
          slivers: [
            // ── Masthead ──────────────────────────────────────────────────
            SliverSafeArea(
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GS.s24,
                    GS.s20,
                    GS.s24,
                    0,
                  ),
                  child: VaultHeader(
                    config: config,
                    entryCount: entryCountFrom(visitsAsync),
                    onOpenPassport: () {
                      final visits =
                          visitsAsync.valueOrNull ?? const <Visit>[];
                      if (visits.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Log a visit to start your passport.',
                              style: GoogleFonts.hankenGrotesk(),
                            ),
                          ),
                        );
                        return;
                      }
                      _openPassport(context, visits, 0);
                    },
                  ),
                ),
              ),
            ),

            // ── List / empty / loading ────────────────────────────────────
            visitsAsync.when(
              data: (visits) {
                if (visits.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: VaultEmptyState(config: config),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    GS.s20,
                    GS.s8,
                    GS.s20,
                    GS.navBuffer,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => JournalEntryCard(
                        visit: visits[i],
                        isFirst: i == 0,
                        isLast: i == visits.length - 1,
                        config: config,
                        index: i,
                        onTap: () =>
                            _openPassport(context, visits, i, openImmediately: true),
                        onDelete: () async {
                          await ref
                              .read(apiClientProvider)
                              .deleteVisit(visits[i].id);
                          ref.invalidate(visitsProvider);
                          ref.invalidate(profileProvider);
                          ref.invalidate(mapCountriesProvider);
                          ref.invalidate(exploreCountriesProvider);
                        },
                      ),
                      childCount: visits.length,
                    ),
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: VaultLoadingList(config: config),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GS.s32),
                    child: GastroErrorCard(
                      config: config,
                      message:
                          "Couldn't open your journal.\nCheck your connection and try again.",
                      icon: LucideIcons.bookX,
                      onRetry: () => ref.invalidate(visitsProvider),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
