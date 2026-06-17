import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/explore/dish_detail_screen.dart';

/// Global "Log a tasting" entry point.
///
/// The core action of a culinary passport used to be reachable only by drilling
/// into a dish in Explore. This sheet surfaces it everywhere: pick the country
/// you tasted, then jump straight into the existing dish-detail log form
/// (opened directly via [DishDetailScreen.openLogOnStart]).
Future<void> showLogTastingSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LogTastingSheet(),
  );
}

class _LogTastingSheet extends ConsumerStatefulWidget {
  const _LogTastingSheet();

  @override
  ConsumerState<_LogTastingSheet> createState() => _LogTastingSheetState();
}

class _LogTastingSheetState extends ConsumerState<_LogTastingSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final countriesAsync = ref.watch(mapCountriesProvider);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.82,
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(GS.r24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: GS.s12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: config.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(GS.r4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(GS.s20, GS.s16, GS.s20, GS.s4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Log a tasting',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(GS.s20, 0, GS.s20, GS.s12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Which cuisine did you taste?',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: config.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GS.s20),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
                style: GoogleFonts.hankenGrotesk(color: config.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search a country or region…',
                  hintStyle:
                      GoogleFonts.hankenGrotesk(color: config.onSurfaceVariant),
                  prefixIcon: Icon(LucideIcons.search,
                      size: 18, color: config.onSurfaceVariant),
                  filled: true,
                  fillColor: config.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(vertical: GS.s12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GS.r12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: GS.s8),
            Expanded(
              child: countriesAsync.when(
                loading: () =>
                    Center(child: CircularProgressIndicator(color: config.accent)),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(GS.s24),
                  child: Center(
                    child: Text(
                      "Couldn't load countries. Check your connection and try again.",
                      textAlign: TextAlign.center,
                      style:
                          GoogleFonts.hankenGrotesk(color: config.onSurfaceVariant),
                    ),
                  ),
                ),
                data: (countries) {
                  final list = (_query.isEmpty
                      ? [...countries]
                      : countries
                          .where((c) =>
                              c.name.toLowerCase().contains(_query) ||
                              c.subregion.toLowerCase().contains(_query) ||
                              c.region.toLowerCase().contains(_query))
                          .toList())
                    ..sort((a, b) => a.name.compareTo(b.name));

                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No matches.',
                        style: GoogleFonts.hankenGrotesk(
                            color: config.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: GS.s32),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        leading:
                            Text(c.flagEmoji, style: const TextStyle(fontSize: 26)),
                        title: Text(
                          c.name,
                          style: GoogleFonts.hankenGrotesk(
                            fontWeight: FontWeight.w600,
                            color: config.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          c.subregion,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            color: config.onSurfaceVariant,
                          ),
                        ),
                        trailing: c.visited
                            ? Icon(LucideIcons.check,
                                size: 16, color: config.accent)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DishDetailScreen(
                                  country: c, openLogOnStart: true),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
