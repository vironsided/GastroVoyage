import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/account/account_settings_screen.dart';
import 'package:mobile/features/notifications/data/notifications_providers.dart';
import 'package:mobile/features/notifications/notifications_screen.dart';
import 'package:mobile/features/search/global_search_screen.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/ui/ui.dart';

import 'scrapbook_bits.dart';

/// Editorial scrapbook header — avatar "passport photo", a tilted GastroVoyage
/// luggage tag, an oversized handwritten/serif greeting, and a stamped stats
/// strip. Lives in a sliver via [EditorialHeaderSliver].
class EditorialHeaderSliver extends StatelessWidget {
  const EditorialHeaderSliver({
    super.key,
    required this.profileAsync,
    required this.config,
    this.authDisplayName,
  });

  final AsyncValue<UserProfile> profileAsync;
  final GastroThemeConfig config;
  final String? authDisplayName;

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, a, b) => const AccountSettingsScreen(),
        transitionsBuilder: (ctx, animation, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
              .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 340),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = authDisplayName ??
        profileAsync.valueOrNull?.displayName ??
        'Explorer';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';
    final profile = profileAsync.valueOrNull;
    final avatarUrl = profile?.avatarUrl;

    return SliverToBoxAdapter(
      child: Container(
        color: config.background,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                GS.s24, GS.s16, GS.s24, GS.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar: avatar + luggage tag ──────────────────────
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _AvatarButton(
                          initial: initial,
                          avatarUrl: avatarUrl,
                          config: config,
                          onTap: () => _openSettings(context),
                        ),
                        if (config.mode == GastroThemeMode.guys)
                          const Positioned(
                            top: -22,
                            right: -10,
                            child: AnimatedPlumbob(size: 30),
                          ),
                      ],
                    ),
                    const Spacer(),
                    _SearchButton(config: config),
                    const SizedBox(width: GS.s10),
                    _NotificationBell(config: config),
                    const SizedBox(width: GS.s10),
                    _LuggageTag(config: config),
                  ],
                )
                    .animate()
                    .fadeIn(duration: GS.slow, curve: GS.smooth)
                    .slideY(
                        begin: -0.1,
                        end: 0,
                        duration: GS.slow,
                        curve: GS.smooth),

                const SizedBox(height: GS.s28),

                // ── Editorial greeting ─────────────────────────────────
                MarginNote(
                  text: 'Bon Appétit,',
                  config: config,
                  fontSize: 22,
                  rotation: -0.04,
                )
                    .animate()
                    .fadeIn(
                        duration: GS.slow,
                        delay: const Duration(milliseconds: 80),
                        curve: GS.smooth),

                const SizedBox(height: GS.s2),

                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 46,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                    height: 1.0,
                  ),
                )
                    .animate()
                    .fadeIn(
                        duration: GS.xslow,
                        delay: const Duration(milliseconds: 120),
                        curve: GS.smooth)
                    .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: GS.xslow,
                        delay: const Duration(milliseconds: 120)),

                const SizedBox(height: GS.s20),

                // ── Stamped stats strip ────────────────────────────────
                if (profile != null)
                  _HeaderStats(profile: profile, config: config)
                      .animate()
                      .fadeIn(
                          duration: GS.slow,
                          delay: const Duration(milliseconds: 200))
                else
                  StitchedDivider(config: config)
                      .animate()
                      .fadeIn(
                          duration: GS.normal,
                          delay: const Duration(milliseconds: 200)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Passport photo" avatar — a white-bordered square instead of a plain
/// circle, evoking a stuck-down ID photo.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.initial,
    required this.config,
    required this.onTap,
    this.avatarUrl,
  });

  final String initial;
  final String? avatarUrl;
  final GastroThemeConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: -0.05,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: config.surface,
            borderRadius: BorderRadius.circular(GS.r8),
            border: Border.all(color: config.outlineVariant, width: 0.5),
            boxShadow: GS.shadow(
                color: Colors.black,
                blur: 12,
                yOffset: 4,
                opacity: config.isDark ? 0.4 : 0.14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GS.r4),
            child: Container(
              width: 42,
              height: 42,
              color: config.accentSoft,
              child: hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: config.accentSoft),
                      errorWidget: (_, __, ___) => _initialFallback(),
                    )
                  : _initialFallback(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _initialFallback() {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: config.accent,
        ),
      ),
    );
  }
}

/// Square scrapbook button that opens the global search screen.
/// Twins the bell visually so the top bar reads as a tidy trio.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GS.r12),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const GlobalSearchScreen(),
          ));
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: config.surface,
            borderRadius: BorderRadius.circular(GS.r12),
            border: Border.all(
              color: config.outlineVariant.withOpacity(0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            LucideIcons.search,
            size: 20,
            color: config.onSurface,
          ),
        ),
      ),
    );
  }
}

/// A scrapbook-style bell button with an unread badge. Watches
/// [unreadCountProvider]; tapping pushes the notifications inbox and
/// invalidates both notifications + count on return.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).asData?.value ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GS.r16),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ));
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: config.surface,
                borderRadius: BorderRadius.circular(GS.r12),
                border: Border.all(
                  color: config.outlineVariant.withOpacity(0.7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                LucideIcons.bell,
                size: 20,
                color: config.onSurface,
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: config.error,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: config.surface, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
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

/// A tilted luggage / parcel tag carrying the app wordmark.
class _LuggageTag extends StatelessWidget {
  const _LuggageTag({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.04,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            GS.s10, GS.s6, GS.s12, GS.s6),
        decoration: BoxDecoration(
          color: config.surfaceVariant,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(GS.r4),
            bottomLeft: Radius.circular(GS.r4),
            topRight: Radius.circular(GS.r12),
            bottomRight: Radius.circular(GS.r12),
          ),
          border: Border.all(color: config.outlineVariant, width: 0.5),
          boxShadow: GS.shadow(
              color: Colors.black,
              blur: 8,
              yOffset: 3,
              opacity: config.isDark ? 0.3 : 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tag eyelet.
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.background,
                border:
                    Border.all(color: config.outlineVariant, width: 1),
              ),
            ),
            const SizedBox(width: GS.s6),
            Icon(LucideIcons.compass, size: 12, color: config.accent),
            const SizedBox(width: GS.s6),
            Text(
              'GastroVoyage',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: config.onSurfaceVariant,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stamped stats strip — countries + badges framed by short ink rules.
class _HeaderStats extends StatelessWidget {
  const _HeaderStats({required this.profile, required this.config});
  final UserProfile profile;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 24, height: 1, color: config.accent.withOpacity(0.4)),
        const SizedBox(width: GS.s10),
        Icon(LucideIcons.globe2, size: 11, color: config.accent),
        const SizedBox(width: GS.s4),
        Text(
          '${profile.visitedCount} ${profile.visitedCount == 1 ? 'country' : 'countries'}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: config.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: GS.s8),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: config.accent.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Icon(LucideIcons.award, size: 11, color: config.accent),
        const SizedBox(width: GS.s4),
        Text(
          '${profile.badges.length} ${profile.badges.length == 1 ? 'badge' : 'badges'}',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: config.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        Container(
            width: 24, height: 1, color: config.accent.withOpacity(0.4)),
      ],
    );
  }
}

/// Scrapbook-styled empty state for the "Recently Tasted" carousel — a
/// taped blank polaroid with a handwritten prompt.
class DashboardEmptyVisits extends StatelessWidget {
  const DashboardEmptyVisits({super.key, required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GS.s24),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Transform.rotate(
              angle: -0.03,
              child: Container(
                width: 180,
                padding: const EdgeInsets.fromLTRB(
                    GS.s8, GS.s8, GS.s8, GS.s16),
                decoration: BoxDecoration(
                  color: config.surface,
                  borderRadius: BorderRadius.circular(GS.r4),
                  border: Border.all(
                      color: config.outlineVariant, width: 0.5),
                  boxShadow: GS.shadow(
                      color: Colors.black,
                      blur: 16,
                      yOffset: 6,
                      opacity: config.isDark ? 0.35 : 0.12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: config.surfaceVariant,
                        borderRadius: BorderRadius.circular(GS.r4),
                      ),
                      child: Icon(
                        LucideIcons.utensils,
                        size: 36,
                        color: config.onSurfaceVariant.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: GS.s10),
                    MarginNote(
                      text: 'your first bite goes here',
                      config: config,
                      fontSize: 16,
                      rotation: -0.02,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -6,
              child: WashiTape(
                config: config,
                width: 64,
                height: 22,
                rotation: 0.1,
                pattern: WashiPattern.dots,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: GS.slow, curve: GS.smooth);
  }
}
