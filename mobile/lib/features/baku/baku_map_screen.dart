// Baku city restaurant map — Girls / Couples / Guys mode theming.
// Design refs:
//  Map style:  1 (route map), 2 (handdrawn), 3 (sketch + compass)
//  Girls:      4 (pink pin), 5 (candy), 6 (lace), 7 (stamp), 8 (polaroid clips), 9 (pink bow seal)
//  Couples:    10 (blue bow seal), 11 (envelope), 12 (striped frame)
//  Guys:       13 (plumbob), 14 (chrome !), 15 (chrome ♪), 16 (green pin), 17 (chrome aesthetic)

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// hide latlong2.Path so dart:ui.Path is unambiguous in CustomPainters
import 'package:latlong2/latlong.dart' hide Path;

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/baku/widgets/couples_card.dart';
import 'package:mobile/features/baku/widgets/girls_card.dart';
import 'package:mobile/features/baku/widgets/guys_card.dart';
import 'package:mobile/features/shared/models.dart';

// Restaurant data + ISO-mapping moved to data/baku_restaurant.dart.

// ─── Marker layout constants + projection helpers ─────────────────────────────

const double _kInitialZoom = 14.0;

const double _kTileSize = 256.0;

/// Web-Mercator world-pixel X for [lng] at [zoom] (256-px tiles).
double _worldX(double lng, double zoom) =>
    (lng + 180.0) / 360.0 * _kTileSize * math.pow(2.0, zoom).toDouble();

/// Web-Mercator world-pixel Y for [lat] at [zoom].
double _worldY(double lat, double zoom) {
  final s = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999).toDouble();
  final y = 0.5 - math.log((1.0 + s) / (1.0 - s)) / (4.0 * math.pi);
  return y * _kTileSize * math.pow(2.0, zoom).toDouble();
}

/// How a restaurant is drawn on the map: a plain red dot, or — when the user
/// has logged a visit AT THAT restaurant with a photo — an Instax frame.
enum _PinMode { dot, instax }

// ─── Main screen ──────────────────────────────────────────────────────────────

class BakuMapScreen extends ConsumerStatefulWidget {
  const BakuMapScreen({super.key, this.filterTopOffset = 54.0});

  /// Top offset for the cuisine filter chips row (cleared by MapScreen header).
  final double filterTopOffset;

  @override
  ConsumerState<BakuMapScreen> createState() => _BakuMapScreenState();
}

class _BakuMapScreenState extends ConsumerState<BakuMapScreen> {
  BakuRestaurant? _selected;
  String? _filterCuisine;

  /// Live map zoom. Marker collision depends only on zoom (not pan), so a
  /// pan never rebuilds — only a meaningful zoom delta does.
  double _zoom = _kInitialZoom;

  static const _allCuisines = [
    'All', 'Azerbaijani', 'Japanese', 'Italian', 'Indian',
    'Chinese', 'Turkish', 'Georgian', 'French', 'American',
    'Korean', 'Lebanese', 'Iranian', 'Thai', 'Spanish',
  ];

  List<BakuRestaurant> get _filtered =>
      _filterCuisine == null
          ? kBakuRestaurants
          : kBakuRestaurants.where((r) => r.cuisine == _filterCuisine).toList();

  /// restaurant name → photo URL, built from the user's logged visits.
  ///
  /// A restaurant earns an Instax frame ONLY when a visit was explicitly
  /// attached to it (`Visit.restaurantName`) AND that visit carries a photo.
  /// When the same restaurant has several photographed visits, the most
  /// recent one wins. Visit photos are stored as full public URLs in
  /// `photo_path` (see backend `uploads.py` / `map.py`), so we use that
  /// value directly — the same approach the world map uses for `photo_url`.
  Map<String, String> _buildVisitedByRestaurant(List<Visit> visits) {
    final sorted = [...visits]
      ..sort((a, b) => b.visitedOn.compareTo(a.visitedOn));
    final result = <String, String>{};
    for (final v in sorted) {
      final name = v.restaurantName;
      final photo = v.photoPath;
      if (name == null || name.isEmpty) continue;
      if (photo == null || photo.isEmpty) continue;
      result.putIfAbsent(name, () => photo);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final visits = ref.watch(visitsProvider).asData?.value ?? const <Visit>[];
    final visitedByRestaurant = _buildVisitedByRestaurant(visits);

    final tileUrl = config.isDark
        ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
        : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png';

    return Stack(
      children: [
        // ── FlutterMap ────────────────────────────────────────────────────────
        FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(40.3760, 49.8480),
            initialZoom: _kInitialZoom,
            maxZoom: 18,
            onTap: (_, __) => setState(() => _selected = null),
            onPositionChanged: (camera, _) {
              if ((camera.zoom - _zoom).abs() > 0.04) {
                setState(() => _zoom = camera.zoom);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.gastrovoyage.mobile',
              maxZoom: 19,
            ),
            MarkerLayer(markers: _buildMarkers(config, visitedByRestaurant)),
            const SimpleAttributionWidget(
              source: Text(
                '© OpenStreetMap · © CARTO',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ],
        ),

        // ── Cuisine filter chips ──────────────────────────────────────────────
        Positioned(
          top: widget.filterTopOffset,
          left: 0,
          right: 0,
          child: _CuisineFilter(
            cuisines: _allCuisines,
            selected: _filterCuisine ?? 'All',
            config: config,
            onSelect: (c) => setState(() {
              _filterCuisine = c == 'All' ? null : c;
              _selected = null;
            }),
          ),
        ),

        // ── Compass rose (photo 3 reference) ──────────────────────────────────
        Positioned(
          bottom: _selected != null ? 190 : 20,
          right: 16,
          child: AnimatedOpacity(
            opacity: _selected != null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: _CompassRose(color: config.accent),
          ),
        ),

        // ── Detail card (slides up) ───────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _selected != null ? 20 : -200,
          left: 16,
          right: 16,
          child: _selected != null
              ? _buildCard(config, _selected!)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCard(GastroThemeConfig config, BakuRestaurant r) => switch (config.mode) {
    GastroThemeMode.girls   => GirlsCard(restaurant: r, onClose: () => setState(() => _selected = null)),
    GastroThemeMode.couples => CouplesCard(restaurant: r, onClose: () => setState(() => _selected = null)),
    GastroThemeMode.guys    => GuysCard(restaurant: r, onClose: () => setState(() => _selected = null)),
  };

  // ── Marker layout ─────────────────────────────────────────────────────────
  //
  // Every restaurant is a small red dot. A restaurant the user has logged a
  // visit AT — with a photo attached — is upgraded to an Instax frame.
  // Instax frames are large, so overlapping ones fall back to a dot — zoom in
  // and the rest fit. Dots never block anything.

  List<Marker> _buildMarkers(
    GastroThemeConfig config,
    Map<String, String> visitedByRestaurant,
  ) {
    final restaurants = _filtered;
    if (restaurants.isEmpty) return const <Marker>[];

    Rect instaxRect(BakuRestaurant r) {
      final x = _worldX(r.lng, _zoom);
      final y = _worldY(r.lat, _zoom);
      return Rect.fromLTWH(x - 41, y - 124, 82, 124);
    }

    // Restaurants with a photographed visit compete for Instax frames; the
    // selected one is resolved first so it always keeps its photo.
    final tried = restaurants
        .where((r) => visitedByRestaurant[r.name] != null)
        .toList()
      ..sort((a, b) =>
          (a == _selected ? 0 : 1).compareTo(b == _selected ? 0 : 1));

    final placedInstax = <Rect>[];
    final asInstax = <BakuRestaurant>{};
    for (final r in tried) {
      final rect = instaxRect(r);
      if (r == _selected || placedInstax.every((p) => !p.overlaps(rect))) {
        asInstax.add(r);
        placedInstax.add(rect);
      }
    }

    _PinMode modeOf(BakuRestaurant r) =>
        asInstax.contains(r) ? _PinMode.instax : _PinMode.dot;

    // Dots first, then Instax, then the selected marker — last paints on top.
    final markers = <Marker>[];
    for (final r in restaurants) {
      if (r != _selected && !asInstax.contains(r)) {
        markers.add(_marker(r, _PinMode.dot, config, visitedByRestaurant));
      }
    }
    for (final r in restaurants) {
      if (r != _selected && asInstax.contains(r)) {
        markers.add(_marker(r, _PinMode.instax, config, visitedByRestaurant));
      }
    }
    final sel = _selected;
    if (sel != null && restaurants.contains(sel)) {
      markers.add(_marker(sel, modeOf(sel), config, visitedByRestaurant));
    }
    return markers;
  }

  Marker _marker(
    BakuRestaurant r,
    _PinMode mode,
    GastroThemeConfig config,
    Map<String, String> visitedByRestaurant,
  ) {
    final isSelected = r == _selected;
    void onTap() => setState(() => _selected = isSelected ? null : r);

    switch (mode) {
      case _PinMode.instax:
        return Marker(
          point: LatLng(r.lat, r.lng),
          width: 82,
          height: 124,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: onTap,
            child: _BakuInstaxPin(
              photoUrl: visitedByRestaurant[r.name],
              cuisineName: r.name,
              selected: isSelected,
              pinDotColor: config.pinDotColor,
            ),
          ),
        );
      case _PinMode.dot:
        return Marker(
          point: LatLng(r.lat, r.lng),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: onTap,
            child: _MiniDot(color: config.accent),
          ),
        );
    }
  }
}

// ─── Cuisine filter ───────────────────────────────────────────────────────────

class _CuisineFilter extends StatelessWidget {
  const _CuisineFilter({
    required this.cuisines,
    required this.selected,
    required this.config,
    required this.onSelect,
  });

  final List<String> cuisines;
  final String selected;
  final GastroThemeConfig config;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cuisines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = cuisines[i];
          final isActive = c == selected;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? config.accent : config.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? config.accent : config.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                c,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? config.onPrimary : config.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Instax pin (mirrors world-map pin exactly) ───────────────────────────────

class _BakuInstaxPin extends StatelessWidget {
  const _BakuInstaxPin({
    required this.photoUrl,
    required this.cuisineName,
    required this.selected,
    required this.pinDotColor,
  });

  final String? photoUrl;
  final String cuisineName;
  final bool selected;
  final Color pinDotColor;

  // Same dimensions as the world map _InstaxPin
  static const double _w         = 82.0;
  static const double _frameH    = 108.0;
  static const double _needleH   = 10.0;
  static const double _dotSize   = 6.0;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return AnimatedScale(
      scale: selected ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: _w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Instax frame ───────────────────────────────────────────────
            Container(
              width: _w,
              height: _frameH,
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
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: ClipRect(
                        child: hasPhoto
                            ? CachedNetworkImage(
                                imageUrl: photoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _photoPlaceholder(loading: true),
                                errorWidget: (_, __, ___) => _photoPlaceholder(),
                              )
                            : _photoPlaceholder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cuisineName.toUpperCase(),
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
            // ── Needle ─────────────────────────────────────────────────────
            Container(
              width: 1.5,
              height: _needleH,
              color: pinDotColor.withOpacity(0.4),
            ),
            // ── Dot ────────────────────────────────────────────────────────
            Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: pinDotColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
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
            : Icon(Icons.add_a_photo_outlined,
                size: 18, color: Colors.grey.shade400),
      ),
    );
  }
}

// ─── Mini dot (decluttered fallback marker) ───────────────────────────────────

/// Compact themed dot shown when a restaurant marker would otherwise overlap a
/// richer neighbour. Still tappable — opens the same detail card.
class _MiniDot extends StatelessWidget {
  const _MiniDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// URL helpers (openMaps, openInstagram) moved to widgets/baku_action_button.dart.

// ─── Compass rose (photo 3) ───────────────────────────────────────────────────

class _CompassRose extends StatelessWidget {
  const _CompassRose({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: CustomPaint(painter: _CompassPainter(color: color)),
    );
  }
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    // Circle bg
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final arrowPaint = Paint()..color = color..style = PaintingStyle.fill;
    final greyPaint  = Paint()..color = Colors.grey.shade400..style = PaintingStyle.fill;

    // N arrow (colored)
    final nPath = Path()
      ..moveTo(cx, cy - r * 0.7)
      ..lineTo(cx - r * 0.18, cy)
      ..lineTo(cx + r * 0.18, cy)
      ..close();
    canvas.drawPath(nPath, arrowPaint);

    // S arrow (grey)
    final sPath = Path()
      ..moveTo(cx, cy + r * 0.7)
      ..lineTo(cx - r * 0.18, cy)
      ..lineTo(cx + r * 0.18, cy)
      ..close();
    canvas.drawPath(sPath, greyPaint);

    // N label
    final tp = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - r * 0.72 - tp.height - 1));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.color != color;
}


// _ActionButton moved to widgets/baku_action_button.dart (as BakuActionButton).

// Theme cards (_GirlsCard / _CouplesCard / _GuysCard) moved to widgets/

