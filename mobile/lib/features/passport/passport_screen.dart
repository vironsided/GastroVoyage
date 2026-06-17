import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/explore/country_dishes.dart';
import 'package:mobile/features/passport/export/passport_export_service.dart';
import 'package:mobile/features/passport/pages/identity_page.dart' show buildIdentityCardData, IdentityCardData;
import 'package:mobile/features/shared/models.dart';

/// Full-screen culinary passport — modern, clean redesign.
///
/// Replaces the old skeuomorphic leather flip-book (which rendered the cover at
/// the open-spread landscape ratio, leaving big voids and overlapping text).
/// Now it's an on-brand experience using the app theme:
///
///   • a portrait COVER hero (identity + stats + recent flags), then
///   • tap "Open" → a horizontal PageView of clean per-visit pages.
///
/// PDF export is unchanged (delegates to [PassportExportService]).
class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({
    super.key,
    required this.visits,
    this.initialVisitIndex = 0,
    this.openImmediately = false,
  });

  final List<Visit> visits;
  final int initialVisitIndex;

  /// When true (a per-visit tap from the Passport tab), skip the cover and
  /// open straight to [initialVisitIndex]. The general "View passport" entry
  /// leaves this false so it still opens on the cover.
  final bool openImmediately;

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen> {
  late final PageController _pageController;
  bool _opened = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.visits.isEmpty
        ? 0
        : widget.initialVisitIndex.clamp(0, widget.visits.length - 1);
    _page = initial;
    _pageController = PageController(initialPage: initial);
    // A deliberate per-visit tap opens straight to that stamp; the general
    // entry (and the empty case) still lands on the cover.
    _opened = widget.openImmediately && widget.visits.isNotEmpty;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  IdentityCardData _identity() {
    final auth = ref.watch(authProvider);
    final avatarUrl = ref.watch(profileProvider).maybeWhen(
          data: (p) => p.avatarUrl,
          orElse: () => null,
        );
    return buildIdentityCardData(
      userId: auth.userId,
      displayName: auth.displayName,
      homeCity: auth.homeCity,
      avatarUrl: avatarUrl,
      visits: widget.visits,
    );
  }

  Future<void> _export() async {
    HapticFeedback.selectionClick();
    await PassportExportService.exportAndShare(
      context,
      ref,
      visits: widget.visits,
    );
  }

  void _open() {
    if (_opened) return;
    HapticFeedback.selectionClick();
    setState(() => _opened = true);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final identity = _identity();
    final earnedStamps = ref.watch(badgesProvider).maybeWhen(
          data: (b) => b.where((x) => x.earned).length,
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: config.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              config: config,
              opened: _opened,
              onLeading: () {
                if (_opened) {
                  setState(() => _opened = false);
                } else {
                  Navigator.of(context).pop();
                }
              },
              onExport: _export,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: GS.normal,
                switchInCurve: GS.smooth,
                switchOutCurve: GS.smooth,
                child: _opened
                    ? _PagesView(
                        key: const ValueKey('pages'),
                        visits: widget.visits,
                        controller: _pageController,
                        config: config,
                        page: _page,
                        onPageChanged: (i) => setState(() => _page = i),
                      )
                    : _CoverView(
                        key: const ValueKey('cover'),
                        config: config,
                        identity: identity,
                        visits: widget.visits,
                        earnedStamps: earnedStamps,
                        onOpen: _open,
                        onExport: _export,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.config,
    required this.opened,
    required this.onLeading,
    required this.onExport,
  });

  final GastroThemeConfig config;
  final bool opened;
  final VoidCallback onLeading;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s12, GS.s8),
      child: Row(
        children: [
          _CircleBtn(
            icon: opened ? Icons.arrow_back_rounded : Icons.close_rounded,
            config: config,
            onTap: onLeading,
            tooltip: opened ? 'Back to cover' : 'Close passport',
          ),
          Expanded(
            child: Text(
              'Passport',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
          ),
          _CircleBtn(
            icon: LucideIcons.download,
            config: config,
            onTap: onExport,
            tooltip: 'Export passport PDF',
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.config,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final GastroThemeConfig config;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: config.surfaceVariant,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, size: 20, color: config.onSurface),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ─── Cover ──────────────────────────────────────────────────────────────────

class _CoverView extends StatelessWidget {
  const _CoverView({
    super.key,
    required this.config,
    required this.identity,
    required this.visits,
    required this.earnedStamps,
    required this.onOpen,
    required this.onExport,
  });

  final GastroThemeConfig config;
  final IdentityCardData identity;
  final List<Visit> visits;
  final int earnedStamps;
  final VoidCallback onOpen;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final countries =
        visits.map((v) => v.countryId).where((id) => id.isNotEmpty).toSet().length;

    // Distinct country flags, in the order visits arrive (newest-first as passed).
    final flags = <String>[];
    final seen = <String>{};
    for (final v in visits) {
      final f = v.country?.flagEmoji ?? '';
      final id = v.countryId;
      if (f.isEmpty || id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      flags.add(f);
      if (flags.length >= 12) break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s8, GS.s20, GS.s24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: GS.s12),

          // Identity card.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(GS.s24),
            decoration: BoxDecoration(
              color: config.surface,
              borderRadius: BorderRadius.circular(GS.r24),
              border: Border.all(color: config.accent.withOpacity(0.25)),
              boxShadow: GS.shadow(
                color: config.accent,
                blur: 28,
                yOffset: 12,
                opacity: config.isDark ? 0.16 : 0.10,
              ),
            ),
            child: Column(
              children: [
                _Avatar(config: config, identity: identity),
                const SizedBox(height: GS.s16),
                Text(
                  identity.displayName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                    height: 1.1,
                  ),
                ),
                if (identity.homeCity != null &&
                    identity.homeCity!.trim().isNotEmpty) ...[
                  const SizedBox(height: GS.s4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.place_rounded,
                          size: 13, color: config.onSurfaceVariant),
                      const SizedBox(width: GS.s4),
                      Text(
                        identity.homeCity!,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: GS.s6),
                Text(
                  'GASTRO ID · ${identity.gastroId}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: config.accent,
                  ),
                ),

                const SizedBox(height: GS.s20),
                Divider(color: config.onSurface.withOpacity(0.08), height: 1),
                const SizedBox(height: GS.s20),

                // Stats.
                Row(
                  children: [
                    _Stat(
                        value: '$countries',
                        label: countries == 1 ? 'country' : 'countries',
                        config: config),
                    _StatDivider(config: config),
                    _Stat(
                        value: '${visits.length}',
                        label: visits.length == 1 ? 'visit' : 'visits',
                        config: config),
                    _StatDivider(config: config),
                    _Stat(
                        value: '$earnedStamps',
                        label: earnedStamps == 1 ? 'stamp' : 'stamps',
                        config: config),
                  ],
                ),

                if (flags.isNotEmpty) ...[
                  const SizedBox(height: GS.s20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'RECENTLY TASTED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: config.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: GS.s8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: GS.s8,
                      runSpacing: GS.s8,
                      children: [
                        for (final f in flags)
                          Text(f, style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
              .animate()
              .fadeIn(duration: GS.normal, curve: GS.smooth)
              .slideY(begin: 0.04, end: 0, duration: GS.normal, curve: GS.smooth),

          const SizedBox(height: GS.s24),

          // Primary + secondary actions.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(LucideIcons.bookOpen, size: 18),
              label: Text(
                visits.isEmpty ? 'Open passport' : 'Open the book',
                style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: config.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GS.r16)),
              ),
            ),
          ),
          const SizedBox(height: GS.s12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(LucideIcons.download, size: 18),
              label: Text(
                'Export PDF',
                style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: config.onSurface,
                side: BorderSide(color: config.onSurface.withOpacity(0.18)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GS.r16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.config, required this.identity});
  final GastroThemeConfig config;
  final IdentityCardData identity;

  String get _initials {
    final parts = identity.displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '🍽';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: config.accent.withOpacity(0.15),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: config.accent,
        ),
      ),
    );

    final url = identity.avatarUrl;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: config.accent.withOpacity(0.5), width: 2),
      ),
      child: ClipOval(
        child: (url == null || url.isEmpty)
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.config});
  final String value;
  final String label;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
            ),
          ),
          const SizedBox(height: GS.s2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.2,
              color: config.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.config});
  final GastroThemeConfig config;
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 34,
        color: config.onSurface.withOpacity(0.08),
      );
}

// ─── Pages ──────────────────────────────────────────────────────────────────

class _PagesView extends StatelessWidget {
  const _PagesView({
    super.key,
    required this.visits,
    required this.controller,
    required this.config,
    required this.page,
    required this.onPageChanged,
  });

  final List<Visit> visits;
  final PageController controller;
  final GastroThemeConfig config;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(GS.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.compass,
                  size: 40, color: config.onSurfaceVariant),
              const SizedBox(height: GS.s16),
              Text(
                'No stamps yet',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                ),
              ),
              const SizedBox(height: GS.s8),
              Text(
                'Log your first tasting and it will appear here as a passport stamp.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  color: config.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: visits.length,
            itemBuilder: (_, i) =>
                _VisitPage(visit: visits[i], config: config),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(GS.s16, GS.s8, GS.s16, GS.s12),
          child: _PageIndicator(
              index: page, count: visits.length, config: config),
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator(
      {required this.index, required this.count, required this.config});
  final int index;
  final int count;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    if (count > 12) {
      return Text(
        '${index + 1}  ·  $count',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          letterSpacing: 2,
          color: config.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: GS.fast,
            curve: GS.smooth,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color:
                  i == index ? config.accent : config.onSurface.withOpacity(0.18),
              borderRadius: BorderRadius.circular(GS.r4),
            ),
          ),
      ],
    );
  }
}

class _VisitPage extends StatelessWidget {
  const _VisitPage({required this.visit, required this.config});
  final Visit visit;
  final GastroThemeConfig config;

  String _formattedDate() {
    try {
      return DateFormat.yMMMMd().format(DateTime.parse(visit.visitedOn));
    } catch (_) {
      return visit.visitedOn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = visit.country;
    final name = country?.name ?? 'Somewhere delicious';
    final flag = country?.flagEmoji ?? '🍽';
    final iso = country?.isoA2 ?? '';
    final region = country?.region ?? '';
    final subregion = country?.subregion ?? '';
    final dish = dishFor(isoA2: iso, region: region);
    final photo = (visit.photoPath != null && visit.photoPath!.isNotEmpty)
        ? visit.photoPath!
        : dish.imageUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s4, GS.s20, GS.s24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo hero with the country stamp overlaid.
          ClipRRect(
            borderRadius: BorderRadius.circular(GS.r24),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: config.surfaceVariant),
                    errorWidget: (_, __, ___) => Container(
                      color: config.surfaceVariant,
                      alignment: Alignment.center,
                      child: Text(flag,
                          style: const TextStyle(fontSize: 48)),
                    ),
                  ),
                ),
                Positioned(
                  top: GS.s12,
                  right: GS.s12,
                  child: _CountryStamp(
                      iso: iso, date: _formattedDate(), config: config),
                ),
              ],
            ),
          ),

          const SizedBox(height: GS.s16),

          // Flag + country.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(flag, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: GS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface,
                        height: 1.05,
                      ),
                    ),
                    if (subregion.isNotEmpty || region.isNotEmpty)
                      Text(
                        [subregion, region]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          letterSpacing: 1,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: GS.s16),

          // Meta rows.
          _MetaRow(
            icon: Icons.event_rounded,
            text: _formattedDate(),
            config: config,
          ),
          if (visit.restaurantName != null &&
              visit.restaurantName!.trim().isNotEmpty) ...[
            const SizedBox(height: GS.s8),
            _MetaRow(
              icon: Icons.place_rounded,
              text: visit.restaurantName!,
              config: config,
            ),
          ],
          const SizedBox(height: GS.s8),
          _MetaRow(
            icon: Icons.restaurant_rounded,
            text: 'Signature dish · ${dish.dish}',
            config: config,
          ),

          const SizedBox(height: GS.s16),
          _Stars(rating: visit.rating, config: config),

          if (visit.notes.trim().isNotEmpty) ...[
            const SizedBox(height: GS.s16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(GS.s16),
              decoration: BoxDecoration(
                color: config.surfaceVariant,
                borderRadius: BorderRadius.circular(GS.r16),
              ),
              child: Text(
                '“${visit.notes.trim()}”',
                style: GoogleFonts.caveat(
                  fontSize: 18,
                  color: config.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate(key: ValueKey(visit.id))
        .fadeIn(duration: GS.normal, curve: GS.smooth);
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(
      {required this.icon, required this.text, required this.config});
  final IconData icon;
  final String text;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: config.accent),
        const SizedBox(width: GS.s8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.5,
              color: config.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.config});
  final int rating;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0, 5);
    return Row(
      children: [
        for (int i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i <= r ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: i <= r ? config.accent : config.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
      ],
    );
  }
}

/// A small circular "entry stamp" — country code + date, lightly rotated, in
/// the accent colour. A modern nod to a passport stamp without the skeuomorphic
/// rubber-ink texture.
class _CountryStamp extends StatelessWidget {
  const _CountryStamp(
      {required this.iso, required this.date, required this.config});
  final String iso;
  final String date;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final code = iso.isEmpty ? 'GV' : iso.toUpperCase();
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: GS.s10, vertical: GS.s6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(GS.r10),
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            Text(
              'TASTED',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 6.5,
                letterSpacing: 1.5,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
