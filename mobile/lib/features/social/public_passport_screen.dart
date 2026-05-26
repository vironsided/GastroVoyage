import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';
import 'package:mobile/ui/ui.dart';

/// Read-only inspection of another traveller's culinary passport.
///
/// Renders the person's portrait, their visited-country & badge counts, an ink
/// stamp grid of countries, and an Instax wall of their photographed visits.
/// 403 and 404 from the backend are caught upstream (`ApiClient.viewPassport`)
/// and surfaced here as themed, non-crashing messages.
class PublicPassportScreen extends ConsumerWidget {
  const PublicPassportScreen({
    super.key,
    required this.userId,
    this.previewName,
  });

  final String userId;

  /// Name shown in the app bar while the passport loads — avoids a flash of
  /// "Passport" before the network response lands.
  final String? previewName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    final passportAsync = ref.watch(publicPassportProvider(userId));

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.08,
        scratchCount: 7,
        child: SafeArea(
          child: passportAsync.when(
            loading: () => _Loading(config: config, name: previewName),
            error: (e, _) => _PassportError(
              config: config,
              error: e,
              onRetry: () => ref.invalidate(publicPassportProvider(userId)),
            ),
            data: (passport) => _PassportView(
              config: config,
              passport: passport,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Back button ──────────────────────────────────────────────────────────────

class _BackChip extends StatelessWidget {
  const _BackChip({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: config.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 16, color: config.onSurface),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading({required this.config, this.name});
  final GastroThemeConfig config;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, 0),
          child: Row(
            children: [
              _BackChip(config: config),
              const SizedBox(width: GS.s4),
              Expanded(
                child: Text(
                  name ?? 'Passport',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GS.s12),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                GS.s20, 0, GS.s20, GS.navBuffer),
            children: [
              GastroShimmer(config: config, height: 150, radius: GS.r24),
              const SizedBox(height: GS.s20),
              GastroShimmer(config: config, height: 90, radius: GS.r20),
              const SizedBox(height: GS.s20),
              GastroShimmer(config: config, height: 200, radius: GS.r20),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error / private / not-found ──────────────────────────────────────────────

class _PassportError extends StatelessWidget {
  const _PassportError({
    required this.config,
    required this.error,
    required this.onRetry,
  });

  final GastroThemeConfig config;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool isPrivate = error is PassportPrivateException;
    final bool isNotFound = error is PassportNotFoundException;
    final bool isAuth = error is UnauthorizedException;

    final IconData icon;
    final String title;
    final String subtitle;
    final String stamp;

    if (isPrivate) {
      icon = LucideIcons.lock;
      title = 'This passport is private';
      subtitle =
          'This traveller keeps their journey to themselves. Follow them — '
          'they may open it up to followers.';
      stamp = 'SEALED';
    } else if (isNotFound) {
      icon = LucideIcons.userX;
      title = 'Traveller not found';
      subtitle =
          'We couldn\'t find this passport. The account may have been removed.';
      stamp = 'NOT FOUND';
    } else if (isAuth) {
      icon = LucideIcons.wifiOff;
      title = 'Session expired';
      subtitle = 'Please sign in again to keep exploring.';
      stamp = 'EXPIRED';
    } else {
      icon = LucideIcons.wifiOff;
      title = 'Couldn\'t open this passport';
      subtitle =
          'Something went wrong on the way. Check your connection and retry.';
      stamp = 'ERROR';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, 0),
          child: _BackChip(config: config),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(GS.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // An ink stamp conveying the access state, in keeping with
                  // the passport metaphor.
                  StampBadge(
                    label: stamp,
                    config: config,
                    size: 108,
                    shape: StampShape.circle,
                    icon: icon,
                    color: isPrivate
                        ? config.onSurfaceVariant
                        : config.error,
                    rotation: -0.12,
                  ),
                  const SizedBox(height: GS.s24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                    ),
                  ),
                  const SizedBox(height: GS.s8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      height: 1.5,
                      color: config.onSurfaceVariant,
                    ),
                  ),
                  if (!isPrivate && !isNotFound) ...[
                    const SizedBox(height: GS.s24),
                    SizedBox(
                      width: 200,
                      child: GastroButton(
                        label: 'TRY AGAIN',
                        icon: LucideIcons.refreshCw,
                        config: config,
                        onPressed: onRetry,
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn(duration: GS.normal, curve: GS.smooth),
          ),
        ),
      ],
    );
  }
}

// ─── Passport view ────────────────────────────────────────────────────────────

class _PassportView extends StatelessWidget {
  const _PassportView({required this.config, required this.passport});
  final GastroThemeConfig config;
  final PublicPassport passport;

  @override
  Widget build(BuildContext context) {
    final visitsWithPhoto =
        passport.visits.where((v) => v.hasPhoto).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, 0),
            child: Row(
              children: [
                _BackChip(config: config),
                const SizedBox(width: GS.s4),
                Text(
                  'PASSPORT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w600,
                    color: config.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              GS.s20, GS.s12, GS.s20, GS.navBuffer),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _IdentityCard(config: config, passport: passport)
                  .animate()
                  .fadeIn(duration: GS.slow, curve: GS.smooth)
                  .slideY(begin: 0.06, end: 0, duration: GS.slow),
              const SizedBox(height: GS.s20),

              // ── Countries ────────────────────────────────────────────
              SectionHeader(
                label: 'Stamps',
                subtitle:
                    '${passport.countries.length} countries collected',
                config: config,
              ),
              const SizedBox(height: GS.s16),
              if (passport.countries.isEmpty)
                _QuietNotice(
                  config: config,
                  text: 'No country stamps in this passport yet.',
                )
              else
                _CountryStampGrid(
                  config: config,
                  countries: passport.countries,
                ),
              const SizedBox(height: GS.s28),

              // ── Visits / Instax wall ─────────────────────────────────
              SectionHeader(
                label: 'Field Notes',
                subtitle: passport.visits.isEmpty
                    ? 'No entries yet'
                    : '${passport.visits.length} tasting entries',
                config: config,
              ),
              const SizedBox(height: GS.s16),
              if (passport.visits.isEmpty)
                _QuietNotice(
                  config: config,
                  text:
                      'This traveller hasn\'t written any field notes yet.',
                )
              else ...[
                if (visitsWithPhoto.isNotEmpty) ...[
                  _InstaxWall(
                    config: config,
                    visits: visitsWithPhoto,
                  ),
                  const SizedBox(height: GS.s20),
                ],
                for (var i = 0; i < passport.visits.length; i++) ...[
                  _VisitEntryCard(
                    config: config,
                    visit: passport.visits[i],
                    index: i,
                  ),
                  if (i != passport.visits.length - 1)
                    const SizedBox(height: GS.s12),
                ],
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Identity card ────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.config, required this.passport});
  final GastroThemeConfig config;
  final PublicPassport passport;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(GS.s20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [config.primary, config.accent],
            ),
            borderRadius: BorderRadius.circular(GS.r24),
            boxShadow: GS.shadow(
              color: config.primary,
              blur: 24,
              yOffset: 10,
              opacity: 0.32,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SocialAvatar(
                    config: config,
                    initial: passport.initial,
                    avatarUrl: passport.avatarUrl,
                    size: 64,
                    borderColor: Colors.white.withOpacity(0.55),
                    borderWidth: 2.5,
                  ),
                  const SizedBox(width: GS.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CULINARY PASSPORT',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: GS.s4),
                        Text(
                          passport.name,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: GS.s6),
                        _VisibilityChip(
                            visibility: passport.passportVisibility),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GS.s16),
              Row(
                children: [
                  Expanded(
                    child: _CountStat(
                      value: passport.visitedCount,
                      label: 'Countries',
                      icon: LucideIcons.globe,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: Colors.white.withOpacity(0.25),
                  ),
                  Expanded(
                    child: _CountStat(
                      value: passport.badgeCount,
                      label: 'Badges',
                      icon: LucideIcons.award,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: -6,
          bottom: -10,
          child: WaxSeal(config: config, size: 44, rotation: -0.25),
        ),
      ],
    );
  }
}

class _CountStat extends StatelessWidget {
  const _CountStat({
    required this.value,
    required this.label,
    required this.icon,
  });
  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.85)),
        const SizedBox(height: GS.s4),
        Text(
          '$value',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 8,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});
  final PassportVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (visibility) {
      case PassportVisibility.public:
        icon = LucideIcons.globe;
      case PassportVisibility.followers:
        icon = LucideIcons.users;
      case PassportVisibility.private:
        icon = LucideIcons.lock;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: GS.s8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(GS.rPill),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: GS.s4),
          Text(
            visibility.label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Country stamp grid ───────────────────────────────────────────────────────

class _CountryStampGrid extends StatelessWidget {
  const _CountryStampGrid({required this.config, required this.countries});
  final GastroThemeConfig config;
  final List<Country> countries;

  @override
  Widget build(BuildContext context) {
    // Crooked-stamp look — alternate small rotations per item.
    const rotations = [-0.06, 0.05, -0.03, 0.07, -0.05, 0.04];
    return Wrap(
      spacing: GS.s12,
      runSpacing: GS.s12,
      children: [
        for (var i = 0; i < countries.length; i++)
          _CountryStamp(
            config: config,
            country: countries[i],
            rotation: rotations[i % rotations.length],
            index: i,
          ),
      ],
    );
  }
}

class _CountryStamp extends StatelessWidget {
  const _CountryStamp({
    required this.config,
    required this.country,
    required this.rotation,
    required this.index,
  });

  final GastroThemeConfig config;
  final Country country;
  final double rotation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final label = country.isoA2.isNotEmpty
        ? country.isoA2.toUpperCase()
        : country.name.toUpperCase();

    return Transform.rotate(
      angle: rotation,
      child: Column(
        children: [
          StampBadge(
            label: label,
            subLabel: country.flagEmoji,
            config: config,
            size: 80,
            shape: StampShape.values[index % StampShape.values.length],
            seed: index,
          ),
          const SizedBox(height: GS.s4),
          SizedBox(
            width: 80,
            child: Text(
              country.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.caveat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: GS.normal,
          delay: GS.stagger(index, ms: 50),
          curve: GS.smooth,
        )
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: GS.normal,
          delay: GS.stagger(index, ms: 50),
          curve: GS.spring,
        );
  }
}

// ─── Instax wall ──────────────────────────────────────────────────────────────

class _InstaxWall extends StatelessWidget {
  const _InstaxWall({required this.config, required this.visits});
  final GastroThemeConfig config;
  final List<PassportVisit> visits;

  @override
  Widget build(BuildContext context) {
    const rotations = [-0.05, 0.04, -0.03, 0.05];
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: visits.length,
        separatorBuilder: (_, __) => const SizedBox(width: GS.s12),
        itemBuilder: (_, i) {
          final v = visits[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: GS.s8),
            child: InstaxFrame(
              config: config,
              photoUrl: v.photoPath,
              caption: v.countryName ?? v.restaurantName,
              width: 130,
              photoHeight: 118,
              rotation: rotations[i % rotations.length],
              showClip: true,
            )
                .animate()
                .fadeIn(
                  duration: GS.normal,
                  delay: GS.stagger(i, ms: 60),
                  curve: GS.smooth,
                ),
          );
        },
      ),
    );
  }
}

// ─── Visit entry card ─────────────────────────────────────────────────────────

class _VisitEntryCard extends StatelessWidget {
  const _VisitEntryCard({
    required this.config,
    required this.visit,
    required this.index,
  });

  final GastroThemeConfig config;
  final PassportVisit visit;
  final int index;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(GS.s16),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(color: config.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(config.isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.countryName ?? 'A tasting entry',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface,
                      ),
                    ),
                    if (visit.restaurantName != null &&
                        visit.restaurantName!.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Icon(LucideIcons.utensils,
                              size: 11,
                              color: config.onSurfaceVariant),
                          const SizedBox(width: GS.s4),
                          Flexible(
                            child: Text(
                              visit.restaurantName!,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12,
                                color: config.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: GS.s8),
              _RatingPips(config: config, rating: visit.rating),
            ],
          ),
          if (visit.notes.isNotEmpty) ...[
            const SizedBox(height: GS.s10),
            Text(
              visit.notes,
              style: GoogleFonts.caveat(
                fontSize: 17,
                height: 1.3,
                color: config.onSurface,
              ),
            ),
          ],
          if (visit.visitedOn.isNotEmpty) ...[
            const SizedBox(height: GS.s10),
            Text(
              visit.visitedOn.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.4,
                color: config.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );

    return card.animate().fadeIn(
          duration: GS.normal,
          delay: GS.stagger(index, ms: 40),
          curve: GS.smooth,
        );
  }
}

class _RatingPips extends StatelessWidget {
  const _RatingPips({required this.config, required this.rating});
  final GastroThemeConfig config;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final clamped = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(
              i < clamped
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 14,
              color: i < clamped
                  ? config.accent
                  : config.onSurfaceVariant.withOpacity(0.4),
            ),
          ),
      ],
    );
  }
}

// ─── Quiet notice ─────────────────────────────────────────────────────────────

class _QuietNotice extends StatelessWidget {
  const _QuietNotice({required this.config, required this.text});
  final GastroThemeConfig config;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GS.s16),
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.r16),
        border: Border.all(color: config.outlineVariant, width: 0.5),
      ),
      child: Text(
        text,
        style: GoogleFonts.caveat(
          fontSize: 17,
          color: config.onSurfaceVariant,
        ),
      ),
    );
  }
}
