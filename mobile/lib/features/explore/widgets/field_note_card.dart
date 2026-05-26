import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/explore/country_dishes.dart';
import 'package:mobile/features/explore/widgets/customs_painters.dart';
import 'package:mobile/features/shared/models.dart';

/// A country rendered as a pinned Polaroid "field-note" in the customs hall.
///
///  • cream Polaroid paper body, with a small per-index rotation jitter
///  • a translucent hatched washi-tape strip pinning the photo at the top
///  • a black postage-style ISO ticket on the photo (notched left edge)
///  • a handwritten Caveat dish caption on the photo
///  • a crooked "TASTED" customs ink stamp on visited countries
///  • a caption strip: Playfair country name + monospace region + ink dot
///
/// Press straightens the card (rotation → 0) and lifts it with a deeper
/// shadow, like picking a photo up off the page.
class FieldNoteCard extends ConsumerStatefulWidget {
  const FieldNoteCard({
    super.key,
    required this.country,
    required this.config,
    required this.index,
    required this.onTap,
  });

  final Country country;
  final GastroThemeConfig config;

  /// Grid index — drives the deterministic rotation jitter.
  final int index;
  final VoidCallback onTap;

  @override
  ConsumerState<FieldNoteCard> createState() => _FieldNoteCardState();
}

class _FieldNoteCardState extends ConsumerState<FieldNoteCard> {
  bool _pressed = false;
  bool _wishlistBusy = false;

  /// Deterministic small tilt per card so the grid looks hand-pinned.
  double get _restAngle {
    const tilts = [-0.035, 0.028, -0.018, 0.04, -0.045, 0.022];
    return tilts[widget.index % tilts.length];
  }

  /// Toggle this country on the wishlist with an optimistic UI update.
  ///
  /// We refetch [wishlistProvider] on success (and on error) so the derived
  /// [wishlistIdsProvider] picks up the canonical state — that's the source
  /// of truth for both the pin and the "Want to try" filter. A short busy
  /// flag prevents double-fires from rapid taps before the refetch lands.
  Future<void> _toggleWishlist({required bool currentlyOn}) async {
    if (_wishlistBusy) return;
    setState(() => _wishlistBusy = true);
    final api = ref.read(apiClientProvider);
    try {
      if (currentlyOn) {
        await api.removeFromWishlist(widget.country.id);
      } else {
        await api.addToWishlist(widget.country.id);
      }
      if (!mounted) return;
      ref.invalidate(wishlistProvider);
    } catch (e) {
      if (!mounted) return;
      // Roll back any optimistic state by re-reading the truth from the
      // backend and let the user retry.
      ref.invalidate(wishlistProvider);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyOn
                ? 'Could not remove from wishlist'
                : 'Could not add to wishlist',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _wishlistBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final country = widget.country;
    final dish = dishFor(isoA2: country.isoA2, region: country.region);
    final hasPhoto = dish.imageUrl.isNotEmpty;
    final paper = config.isDark ? const Color(0xFF1C1A17) : const Color(0xFFFBF7EE);
    final angle = _pressed ? 0.0 : _restAngle;
    final onWishlist = ref.watch(wishlistIdsProvider).contains(country.id);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedRotation(
        turns: angle / (2 * 3.14159265),
        duration: GS.fast,
        curve: GS.smooth,
        child: AnimatedScale(
          scale: _pressed ? 1.035 : 1.0,
          duration: GS.fast,
          curve: GS.smooth,
          child: AnimatedContainer(
            duration: GS.fast,
            curve: GS.smooth,
            padding: const EdgeInsets.fromLTRB(GS.s6, GS.s6, GS.s6, 0),
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(GS.r4),
              border: Border.all(
                color: country.visited
                    ? config.accent.withOpacity(0.55)
                    : (config.isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05)),
                width: country.visited ? 1.5 : 1,
              ),
              boxShadow: [
                // tight contact shadow
                BoxShadow(
                  color: Colors.black
                      .withOpacity(config.isDark ? 0.42 : 0.16),
                  blurRadius: _pressed ? 22 : 10,
                  offset: Offset(0, _pressed ? 14 : 5),
                ),
                // soft ambient lift
                BoxShadow(
                  color: Colors.black
                      .withOpacity(config.isDark ? 0.22 : 0.07),
                  blurRadius: _pressed ? 42 : 26,
                  offset: Offset(0, _pressed ? 26 : 14),
                ),
                if (country.visited)
                  BoxShadow(
                    color: config.accent.withOpacity(0.16),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Photo area with tape, ticket, caption, stamp ─────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(GS.r4 - 2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasPhoto)
                          _Photo(dish: dish, country: country, config: config)
                        else
                          _Photoless(country: country, config: config),

                        // film-tint gradient
                        const _FilmTint(),

                        // hatched washi-tape strip pinning the photo
                        Positioned(
                          top: -7,
                          left: 14,
                          right: 14,
                          child: Transform.rotate(
                            angle: widget.index.isEven ? -0.04 : 0.05,
                            child: SizedBox(
                              height: 18,
                              child: CustomPaint(
                                painter: HatchTapePainter(
                                  color: config.isDark
                                      ? config.accent
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // black postage ISO ticket — top-left
                        Positioned(
                          top: GS.s8,
                          left: GS.s8,
                          child: ClipPath(
                            clipper: const TicketNotchClipper(),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                  GS.s8, 3, GS.s6, 3),
                              color: const Color(0xFF14110E),
                              child: Text(
                                country.isoA2,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFF3ECDD),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // crooked TASTED customs stamp on visited countries
                        if (country.visited)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: CustomPaint(
                                painter: CustomsStampPainter(
                                  color: config.accent,
                                  label: 'TASTED',
                                  seed: widget.index + 5,
                                ),
                              ),
                            ),
                          ),

                        // handwritten Caveat dish caption — leaves room on
                        // the right so the wishlist pin can sit alongside.
                        Positioned(
                          left: GS.s8,
                          right: 36,
                          bottom: GS.s6,
                          child: Text(
                            dish.dish,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.caveat(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.0,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),

                        // Wishlist bookmark pin — bottom-right of the photo,
                        // out of the way of the TASTED stamp (top-right) and
                        // the dish caption (bottom-left). Tap toggles
                        // wishlist with an optimistic update.
                        Positioned(
                          right: GS.s4,
                          bottom: GS.s4,
                          child: _WishlistPin(
                            onWishlist: onWishlist,
                            accent: config.accent,
                            busy: _wishlistBusy,
                            onTap: () =>
                                _toggleWishlist(currentlyOn: onWishlist),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Polaroid caption strip ────────────────────────────────
                _CaptionStrip(country: country, config: config),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Photo / placeholder ─────────────────────────────────────────────────────

class _Photo extends StatelessWidget {
  const _Photo({
    required this.dish,
    required this.country,
    required this.config,
  });

  final DishData dish;
  final Country country;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: dish.imageUrl,
      fit: BoxFit.cover,
      memCacheHeight: 280,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, __) => Container(color: config.accentSoft),
      errorWidget: (_, __, ___) =>
          _Photoless(country: country, config: config),
    );
  }
}

class _Photoless extends StatelessWidget {
  const _Photoless({required this.country, required this.config});

  final Country country;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: config.accentSoft),
        Center(
          child: Text(
            country.isoA2,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: config.accent.withOpacity(0.26),
              letterSpacing: 2,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22,
          child: Text(
            'no photo on file',
            textAlign: TextAlign.center,
            style: GoogleFonts.caveat(
              fontSize: 14,
              color: config.accent.withOpacity(0.55),
            ),
          ),
        ),
      ],
    );
  }
}

/// Subtle warm film-tint over photos so they read like aged passport prints.
class _FilmTint extends StatelessWidget {
  const _FilmTint();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x33000000),
            Color(0x0D5A3A1A),
            Color(0xB3000000),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

// ── Polaroid caption strip ──────────────────────────────────────────────────

class _CaptionStrip extends StatelessWidget {
  const _CaptionStrip({required this.country, required this.config});

  final Country country;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s6, GS.s4, GS.s8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  country.region.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: config.onSurfaceVariant.withOpacity(0.8),
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GS.s6),
          // ink status dot
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: country.visited
                  ? config.accent
                  : Colors.transparent,
              border: Border.all(
                color: country.visited
                    ? config.accent
                    : config.onSurfaceVariant.withOpacity(0.45),
                width: 1.3,
              ),
              boxShadow: country.visited
                  ? [
                      BoxShadow(
                        color: config.accent.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wishlist pin ────────────────────────────────────────────────────────────

/// Small bookmark "+" button that toggles the country on the wishlist.
///
/// Sits in the bottom-right of the photo area. The filled-bookmark state
/// reads as "saved", the outline+plus reads as "tap to chase". The icon
/// swap is a 160ms cross-fade so the toggle feels tactile but not jumpy.
class _WishlistPin extends StatelessWidget {
  const _WishlistPin({
    required this.onWishlist,
    required this.accent,
    required this.busy,
    required this.onTap,
  });

  final bool onWishlist;
  final Color accent;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = onWishlist;
    return Semantics(
      button: true,
      label: filled ? 'Remove from wishlist' : 'Add to wishlist',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? accent : Colors.black.withOpacity(0.42),
            border: Border.all(
              color: filled
                  ? accent
                  : Colors.white.withOpacity(0.85),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              if (filled)
                BoxShadow(
                  color: accent.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              filled
                  ? LucideIcons.bookmark
                  : LucideIcons.plus,
              key: ValueKey<bool>(filled),
              size: 15,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
