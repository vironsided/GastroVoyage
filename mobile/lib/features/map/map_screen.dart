import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/baku/baku_map_screen.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/shared/models.dart';

// Instax pin dimensions
const _kPinWidth = 82.0;
const _kPinFrameHeight = 108.0; // white instax frame
const _kPinNeedleHeight = 10.0;
const _kPinDotSize = 6.0;
const _kPinTotalHeight = _kPinFrameHeight + _kPinNeedleHeight + _kPinDotSize;

// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  int _tab = 0; // 0 = World, 1 = Baku, 2 = Globe

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final countriesAsync = ref.watch(mapCountriesProvider);
    final visitsAsync = ref.watch(visitsProvider);

    final worldVisited = countriesAsync.maybeWhen(
      data: (c) => c.where((x) => x.visited).length,
      orElse: () => 0,
    );
    final worldTotal = countriesAsync.maybeWhen(
      data: (c) => c.length,
      orElse: () => 0,
    );

    // Distinct Baku restaurants the user has logged a visit at.
    final bakuRestaurantNames = {for (final r in kBakuRestaurants) r.name};
    final bakuVisited = visitsAsync.maybeWhen(
      data: (visits) => visits
          .map((v) => v.restaurantName)
          .where((n) => n != null && bakuRestaurantNames.contains(n))
          .toSet()
          .length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: _tab == 2
          ? config.mapBackground
          : _tab == 0
              ? config.mapBackground
              : (config.isDark ? const Color(0xFF141414) : Colors.white),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Content ──────────────────────────────────────────────────────
            Positioned.fill(
              child: _tab == 0
                  ? _WorldMapContent(config: config)
                  // Chips clear the now two-line header.
                  : const BakuMapScreen(filterTopOffset: 92),
            ),

            // ── Unified header: title + count + toggle ────────────────────────
            Positioned(
              top: 10,
              left: 18,
              right: 14,
              child: _MapHeader(
                title: _tab == 0 ? 'WORLD CUISINE MAP' : 'BAKU FOOD MAP',
                visitedCount: _tab == 0 ? worldVisited : bakuVisited,
                totalCount: _tab == 0 ? worldTotal : kBakuRestaurantsCount,
                tab: _tab,
                config: config,
                onSelect: (i) => setState(() => _tab = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// World map content extracted so ConsumerStatefulWidget can watch providers
class _WorldMapContent extends ConsumerWidget {
  const _WorldMapContent({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countriesAsync = ref.watch(mapCountriesProvider);
    return countriesAsync.when(
      data: (countries) {
        final visited = countries.where((c) => c.visited).toList();
        return _SketchMapView(
          visitedCountries: visited,
          allCount: countries.length,
          themeConfig: config,
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 40, color: Color(0xFFE60012)),
            SizedBox(height: 12),
            CircularProgressIndicator(color: Color(0xFFE60012)),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Text(
          'BACKEND OFFLINE\nSTART SERVER AT :8000',
          textAlign: TextAlign.center,
          style: GoogleFonts.caveat(
            fontSize: 20,
            color: const Color(0xFFE60012),
          ),
        ),
      ),
    );
  }
}

// ─── Unified map header ───────────────────────────────────────────────────────

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.title,
    required this.visitedCount,
    required this.totalCount,
    required this.tab,
    required this.config,
    required this.onSelect,
  });

  final String title;
  final int visitedCount;
  final int totalCount;
  final int tab;
  final GastroThemeConfig config;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Two rows: the toggle pill gets its own line so the handwritten title
    // never has to share width with it (that squeeze truncated it to "WORL…").
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _TogglePill(selected: tab, config: config, onSelect: onSelect),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.caveat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: config.mapLabelColor,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$visitedCount / $totalCount',
              style: GoogleFonts.caveat(
                fontSize: 16,
                color: config.pinDotColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.selected,
    required this.config,
    required this.onSelect,
  });

  final int selected;
  final GastroThemeConfig config;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: config.surface.withOpacity(0.93),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: config.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(config.isDark ? 0.5 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(0, 'WORLD'),
          const SizedBox(width: 2),
          _pill(1, 'BAKU'),
        ],
      ),
    );
  }

  Widget _pill(int i, String label) {
    final active = selected == i;
    return GestureDetector(
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: active ? config.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? config.onPrimary : config.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── Map view ─────────────────────────────────────────────────────────────────

class _SketchMapView extends StatefulWidget {
  const _SketchMapView({
    required this.visitedCountries,
    required this.allCount,
    required this.themeConfig,
  });

  final List<Country> visitedCountries;
  final int allCount;
  final GastroThemeConfig themeConfig;

  @override
  State<_SketchMapView> createState() => _SketchMapViewState();
}

class _SketchMapViewState extends State<_SketchMapView> {
  Country? _selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Sketch map background — dismiss on tap
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selected = null),
              child: CustomPaint(
                size: size,
                painter: _SketchMapPainter(config: widget.themeConfig),
              ),
            ),

            // Instax pins — anchored at each country's true projected
            // location so a photo always sits exactly on its country.
            // Non-selected pins are painted first, then the selected pin
            // last so a tapped pin always jumps to the front of the stack.
            ...[
              ...widget.visitedCountries.where((c) => c != _selected),
              ...widget.visitedCountries.where((c) => c == _selected),
            ].map((c) {
              final pos = _project(c.centroidLat, c.centroidLng, size);
              // Pin's top edge is clamped below the unified header (~94 px)
              // so high-latitude visits (Poland, Sweden, Norway, Canada) don't
              // collide with the "WORLD CUISINE MAP · N/T" title strip.
              const _kHeaderSafeY = 110.0;
              final pinTop =
                  math.max(pos.dy - _kPinTotalHeight, _kHeaderSafeY);
              return Positioned(
                left: pos.dx - _kPinWidth / 2,
                top: pinTop,
                child: _InstaxPin(
                  country: c,
                  selected: _selected == c,
                  pinDotColor: widget.themeConfig.pinDotColor,
                  onTap: () => setState(
                    () => _selected = _selected == c ? null : c,
                  ),
                ),
              );
            }),

            // Country detail card at bottom
            if (_selected != null)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: _InstaxDetailCard(
                  country: _selected!,
                  onClose: () => setState(() => _selected = null),
                ),
              ),
          ],
        );
      },
    );
  }

}

// ─── Instax pin widget ────────────────────────────────────────────────────────

class _InstaxPin extends StatelessWidget {
  const _InstaxPin({
    required this.country,
    required this.selected,
    required this.pinDotColor,
    required this.onTap,
  });

  final Country country;
  final bool selected;
  final Color pinDotColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = country.photoUrl != null && country.photoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: _kPinWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Instax frame
              Container(
                width: _kPinWidth,
                height: _kPinFrameHeight,
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(selected ? 0.22 : 0.13),
                      blurRadius: selected ? 14 : 8,
                      spreadRadius: selected ? 1 : 0,
                      offset: Offset(selected ? 2 : 1, selected ? 5 : 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo square
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: ClipRect(
                          child: hasPhoto
                              ? CachedNetworkImage(
                                  imageUrl: country.photoUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _photoPlaceholder(loading: true),
                                  errorWidget: (_, __, ___) => _photoPlaceholder(),
                                )
                              : _photoPlaceholder(),
                        ),
                      ),
                    ),
                    // Caption
                    const SizedBox(height: 4),
                    Text(
                      country.name.toUpperCase(),
                      style: GoogleFonts.caveat(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF444748),
                        letterSpacing: 0.3,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Pin stem
              Container(
                width: 1.5,
                height: _kPinNeedleHeight,
                color: pinDotColor.withOpacity(0.4),
              ),
              // Pin dot
              Container(
                width: _kPinDotSize,
                height: _kPinDotSize,
                decoration: BoxDecoration(
                  color: pinDotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder({bool loading = false}) {
    return Container(
      color: const Color(0xFFF2F2F2),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFFE60012),
                ),
              )
            : Icon(Icons.add_a_photo_outlined, size: 18, color: Colors.grey.shade400),
      ),
    );
  }
}

// ─── Country detail card ──────────────────────────────────────────────────────

class _InstaxDetailCard extends StatelessWidget {
  const _InstaxDetailCard({required this.country, required this.onClose});

  final Country country;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = country.photoUrl != null && country.photoUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPhoto)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              child: SizedBox(
                height: 150,
                child: CachedNetworkImage(
                  imageUrl: country.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFF0F0F0),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE60012),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    country.isoA2,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        country.name.toUpperCase(),
                        style: GoogleFonts.caveat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '${country.region} · ${country.subregion}'.toUpperCase(),
                        style: GoogleFonts.caveat(
                          fontSize: 13,
                          color: Colors.black.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      '✕',
                      style: GoogleFonts.caveat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
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

// ─── Equirectangular projection ───────────────────────────────────────────────

Offset _project(double lat, double lng, Size size) {
  const padX = 0.05;
  const padY = 0.08;
  final x = padX + (lng + 180) / 360 * (1 - padX * 2);
  final y = padY + (90 - lat) / 180 * (1 - padY * 2);
  return Offset(x * size.width, y * size.height);
}

// ─── Sketch map painter (continents + grid, no markers) ──────────────────────

class _SketchMapPainter extends CustomPainter {
  const _SketchMapPainter({required this.config});
  final GastroThemeConfig config;

  static final _rng = math.Random(1337);

  static const _northAmerica = [
    [71.0,-142.0],[60.0,-141.0],[57.0,-153.0],[55.0,-160.0],[60.0,-165.0],
    [64.0,-166.0],[68.0,-163.0],[70.0,-157.0],[72.0,-100.0],[70.0,-80.0],
    [60.0,-65.0],[50.0,-55.0],[47.0,-65.0],[44.0,-66.0],[42.0,-70.0],
    [35.0,-76.0],[30.0,-81.0],[25.0,-80.0],[20.0,-87.0],[15.0,-85.0],
    [9.0,-77.0],[10.0,-75.0],[12.0,-72.0],[20.0,-74.0],[25.0,-77.0],
    [25.0,-80.0],[29.0,-95.0],[26.0,-97.0],[23.0,-105.0],[20.0,-105.0],
    [15.0,-92.0],[10.0,-84.0],[9.0,-77.0],[10.0,-75.0],[15.0,-92.0],
    [20.0,-105.0],[23.0,-110.0],[28.0,-110.0],[32.0,-117.0],[34.0,-120.0],
    [37.0,-122.0],[40.0,-124.0],[45.0,-124.0],[49.0,-123.0],[55.0,-130.0],
    [60.0,-141.0],[71.0,-142.0],
  ];

  static const _southAmerica = [
    [9.0,-77.0],[5.0,-77.0],[1.0,-80.0],[-5.0,-81.0],[-10.0,-75.0],
    [-15.0,-75.0],[-18.0,-70.0],[-22.0,-68.0],[-27.0,-68.0],[-30.0,-71.0],
    [-33.0,-72.0],[-38.0,-73.0],[-42.0,-73.0],[-46.0,-75.0],[-52.0,-68.0],
    [-55.0,-66.0],[-56.0,-68.0],[-55.0,-64.0],[-53.0,-58.0],[-48.0,-65.0],
    [-44.0,-65.0],[-38.0,-57.0],[-34.0,-53.0],[-30.0,-50.0],[-25.0,-48.0],
    [-23.0,-43.0],[-20.0,-40.0],[-15.0,-39.0],[-10.0,-37.0],[-5.0,-35.0],
    [-3.0,-41.0],[0.0,-50.0],[3.0,-51.0],[5.0,-53.0],[8.0,-60.0],
    [11.0,-63.0],[10.0,-62.0],[11.0,-64.0],[10.0,-65.0],[12.0,-69.0],
    [11.0,-73.0],[10.0,-75.0],[9.0,-77.0],
  ];

  static const _europe = [
    [70.0,20.0],[65.0,14.0],[58.0,5.0],[51.0,2.0],[50.0,3.0],[43.0,-9.0],
    [36.0,-9.0],[36.0,-5.0],[37.0,-3.0],[37.0,-1.0],[38.0,0.0],[40.0,3.0],
    [42.0,3.0],[43.0,5.0],[43.0,7.0],[44.0,8.0],[44.0,10.0],[43.0,13.0],
    [42.0,14.0],[40.0,15.0],[38.0,15.0],[37.0,13.0],[38.0,12.0],[37.0,16.0],
    [40.0,18.0],[41.0,20.0],[40.0,23.0],[38.0,24.0],[36.0,28.0],[37.0,27.0],
    [38.0,26.0],[40.0,27.0],[41.0,29.0],[43.0,28.0],[45.0,30.0],[46.0,33.0],
    [48.0,38.0],[46.0,38.0],[45.0,37.0],[46.0,40.0],[43.0,40.0],[43.0,44.0],
    [43.0,50.0],[47.0,47.0],[48.0,44.0],[50.0,40.0],[50.0,35.0],[52.0,32.0],
    [55.0,28.0],[54.0,24.0],[57.0,21.0],[59.0,22.0],[60.0,25.0],[63.0,26.0],
    [65.0,26.0],[67.0,24.0],[69.0,28.0],[70.0,30.0],[71.0,28.0],[70.0,20.0],
  ];

  static const _africa = [
    [37.0,-6.0],[35.0,-6.0],[30.0,-10.0],[20.0,-17.0],[15.0,-17.0],
    [10.0,-16.0],[5.0,-15.0],[4.0,-9.0],[4.0,-2.0],[5.0,1.0],[4.0,9.0],
    [6.0,10.0],[4.0,10.0],[4.0,15.0],[7.0,13.0],[12.0,14.0],[17.0,14.0],
    [19.0,12.0],[22.0,14.0],[22.0,10.0],[24.0,8.0],[22.0,5.0],[18.0,4.0],
    [12.0,4.0],[9.0,2.0],[4.0,9.0],[2.0,10.0],[0.0,10.0],[-5.0,14.0],
    [-9.0,16.0],[-15.0,12.0],[-17.0,11.0],[-22.0,17.0],[-25.0,15.0],
    [-29.0,17.0],[-32.0,18.0],[-34.0,18.0],[-34.0,26.0],[-30.0,30.0],
    [-26.0,33.0],[-24.0,36.0],[-20.0,35.0],[-13.0,40.0],[-5.0,40.0],
    [0.0,42.0],[5.0,42.0],[11.0,43.0],[12.0,43.0],[13.0,42.0],[18.0,42.0],
    [20.0,38.0],[22.0,37.0],[25.0,34.0],[28.0,33.0],[30.0,32.0],[32.0,28.0],
    [34.0,27.0],[36.0,27.0],[37.0,28.0],[37.0,26.0],[35.0,25.0],[35.0,22.0],
    [33.0,20.0],[30.0,22.0],[24.0,24.0],[23.0,20.0],[20.0,20.0],[20.0,12.0],
    [37.0,-6.0],
  ];

  static const _asia = [
    [70.0,30.0],[70.0,50.0],[68.0,60.0],[65.0,60.0],[62.0,70.0],[58.0,68.0],
    [55.0,68.0],[52.0,68.0],[50.0,65.0],[48.0,62.0],[47.0,60.0],[47.0,55.0],
    [45.0,55.0],[44.0,53.0],[42.0,52.0],[40.0,50.0],[38.0,50.0],[37.0,45.0],
    [35.0,45.0],[32.0,47.0],[30.0,50.0],[28.0,50.0],[25.0,50.0],[22.0,59.0],
    [20.0,58.0],[15.0,52.0],[12.0,45.0],[11.0,49.0],[13.0,42.0],[18.0,42.0],
    [20.0,38.0],[22.0,37.0],[25.0,34.0],[28.0,33.0],[30.0,32.0],[32.0,34.0],
    [33.0,36.0],[36.0,36.0],[37.0,38.0],[38.0,42.0],[39.0,44.0],[40.0,50.0],
    [38.0,50.0],[37.0,45.0],[36.0,45.0],[37.0,40.0],[37.0,36.0],[40.0,27.0],
    [41.0,29.0],[43.0,28.0],[45.0,30.0],[46.0,33.0],[48.0,38.0],[46.0,40.0],
    [43.0,40.0],[43.0,44.0],[43.0,50.0],[46.0,50.0],[47.0,47.0],[48.0,44.0],
    [50.0,40.0],[50.0,35.0],[52.0,32.0],[55.0,28.0],[57.0,21.0],[60.0,25.0],
    [63.0,26.0],[65.0,26.0],[67.0,24.0],[69.0,28.0],[70.0,30.0],
    [55.0,160.0],[50.0,155.0],[45.0,150.0],[43.0,142.0],[40.0,140.0],
    [37.0,138.0],[35.0,136.0],[33.0,130.0],[30.0,122.0],[25.0,120.0],
    [22.0,114.0],[20.0,110.0],[18.0,108.0],[15.0,110.0],[12.0,108.0],
    [10.0,105.0],[8.0,103.0],[5.0,100.0],[2.0,102.0],[1.0,104.0],
    [0.0,104.0],[-1.0,104.0],[-2.0,106.0],[-5.0,110.0],[-8.0,112.0],
    [-8.0,115.0],[-5.0,115.0],[-2.0,110.0],[0.0,104.0],[2.0,100.0],
    [5.0,100.0],[8.0,103.0],[10.0,105.0],[12.0,108.0],[15.0,110.0],
    [18.0,108.0],[20.0,110.0],[25.0,120.0],[30.0,122.0],[35.0,136.0],
    [37.0,138.0],[40.0,140.0],[43.0,142.0],[45.0,150.0],[50.0,155.0],
    [55.0,160.0],[62.0,168.0],[65.0,170.0],[68.0,170.0],[70.0,170.0],
    [70.0,140.0],[70.0,100.0],[72.0,85.0],[73.0,80.0],[74.0,73.0],
    [71.0,75.0],[68.0,73.0],[66.0,72.0],[62.0,72.0],[62.0,68.0],
    [60.0,68.0],[57.0,68.0],[55.0,68.0],[52.0,68.0],[50.0,65.0],
    [48.0,62.0],[47.0,60.0],[47.0,55.0],[45.0,55.0],[70.0,30.0],
  ];

  static const _australia = [
    [-16.0,136.0],[-14.0,130.0],[-14.0,128.0],[-16.0,124.0],[-20.0,122.0],
    [-22.0,114.0],[-25.0,113.0],[-27.0,113.0],[-29.0,115.0],[-30.0,116.0],
    [-32.0,116.0],[-34.0,116.0],[-35.0,118.0],[-35.0,120.0],[-34.0,122.0],
    [-34.0,126.0],[-33.0,128.0],[-35.0,130.0],[-35.0,138.0],[-38.0,140.0],
    [-38.0,142.0],[-38.0,146.0],[-37.0,148.0],[-36.0,150.0],[-34.0,151.0],
    [-32.0,152.0],[-29.0,153.0],[-26.0,153.0],[-24.0,152.0],[-20.0,148.0],
    [-18.0,146.0],[-16.0,145.0],[-14.0,144.0],[-12.0,136.0],[-14.0,130.0],
    [-16.0,136.0],
  ];

  static const _greenland = [
    [83.0,-42.0],[80.0,-17.0],[76.0,-18.0],[72.0,-22.0],[68.0,-26.0],
    [65.0,-37.0],[60.0,-44.0],[60.0,-46.0],[62.0,-50.0],[64.0,-52.0],
    [68.0,-53.0],[70.0,-53.0],[72.0,-55.0],[74.0,-57.0],[76.0,-58.0],
    [78.0,-57.0],[80.0,-52.0],[83.0,-42.0],
  ];

  Offset _p(double lat, double lng, Size size) =>
      _project(lat, lng, size);

  Path _sketchPath(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final cx = (p1.dx + p2.dx) / 2 + (_rng.nextDouble() - 0.5) * 5.0;
      final cy = (p1.dy + p2.dy) / 2 + (_rng.nextDouble() - 0.5) * 5.0;
      path.quadraticBezierTo(cx, cy, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawContinent(
    Canvas canvas,
    Paint inkPaint,
    List<List<double>> data,
    Size size,
  ) {
    final pts = data.map((ll) => _p(ll[0], ll[1], size)).toList();
    final path = _sketchPath(pts)..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = config.mapContinentFill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(path, inkPaint);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.caveat(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background from theme
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = config.mapBackground,
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = config.mapGridColor
      ..strokeWidth = 0.5;
    for (int lat = -60; lat <= 90; lat += 30) {
      final y = _p(lat.toDouble(), 0, size).dy;
      canvas.drawLine(
        Offset(0, y + (_rng.nextDouble() - 0.5) * 2),
        Offset(size.width, y + (_rng.nextDouble() - 0.5) * 2),
        gridPaint,
      );
    }
    for (int lng = -180; lng <= 180; lng += 60) {
      final x = _p(0, lng.toDouble(), size).dx;
      canvas.drawLine(
        Offset(x + (_rng.nextDouble() - 0.5) * 2, 0),
        Offset(x + (_rng.nextDouble() - 0.5) * 2, size.height),
        gridPaint,
      );
    }

    // Equator label
    final eqY = _p(0, 0, size).dy;
    _drawLabel(
      canvas, 'EQUATOR',
      Offset(size.width * 0.06, eqY - 8),
      8, config.mapLabelColor.withOpacity(0.3),
    );

    // Continent outlines
    final inkPaint = Paint()
      ..color = config.mapContinentStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawContinent(canvas, inkPaint, _northAmerica, size);
    _drawContinent(canvas, inkPaint, _southAmerica, size);
    _drawContinent(canvas, inkPaint, _europe, size);
    _drawContinent(canvas, inkPaint, _africa, size);
    _drawContinent(canvas, inkPaint, _asia, size);
    _drawContinent(canvas, inkPaint, _australia, size);
    _drawContinent(canvas, inkPaint, _greenland, size);

    // Continent labels
    final labelColor = config.mapLabelColor.withOpacity(0.5);
    _drawLabel(canvas, 'NORTH AMERICA', _p(45, -100, size), 9, labelColor);
    _drawLabel(canvas, 'SOUTH AMERICA', _p(-20, -55, size), 9, labelColor);
    _drawLabel(canvas, 'EUROPE', _p(52, 15, size), 8, labelColor);
    _drawLabel(canvas, 'AFRICA', _p(-5, 22, size), 10, labelColor);
    _drawLabel(canvas, 'ASIA', _p(50, 95, size), 12, labelColor);
    _drawLabel(canvas, 'AUSTRALIA', _p(-28, 135, size), 8, labelColor);
  }

  @override
  bool shouldRepaint(_SketchMapPainter old) => old.config != config;
}
