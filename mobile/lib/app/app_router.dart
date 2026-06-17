import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/dashboard/dashboard_screen.dart';
import 'package:mobile/features/explore/explore_screen.dart';
import 'package:mobile/features/log/log_tasting_sheet.dart';
import 'package:mobile/features/map/map_screen.dart';
import 'package:mobile/features/social/public_passport_screen.dart';
import 'package:mobile/features/vault/vault_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const _ShellScreen(),
    ),
    // Deep-link to a user's public passport. The "Share Profile" button on
    // the Account screen generates URLs of the form
    // `https://gastro-voyage.vercel.app/u/{userId}` — Vercel's catch-all
    // rewrite serves index.html and GoRouter picks the link up here.
    // Recipient must be authenticated; an unauthenticated open routes back
    // to `/` (the auth-gate in main.dart will then show the login screen).
    GoRoute(
      path: '/u/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId'] ?? '';
        if (userId.isEmpty) return const _ShellScreen();
        return PublicPassportScreen(userId: userId);
      },
    ),
  ],
);

// ─── Shell ────────────────────────────────────────────────────────────────────

class _ShellScreen extends ConsumerStatefulWidget {
  const _ShellScreen();

  @override
  ConsumerState<_ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<_ShellScreen> {
  static const _pages = [
    DashboardScreen(),
    MapScreen(),
    ExploreScreen(),
    VaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    // Watch the global tab provider so deep widgets (e.g. the dashboard's
    // "Next bite to chase" card) can jump tabs by writing the provider.
    final rawIndex = ref.watch(bottomNavIndexProvider);
    final index = rawIndex.clamp(0, _pages.length - 1);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: config.isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        extendBody: true,
        backgroundColor: config.background,
        body: AnimatedSwitcher(
          duration: GS.normal,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey(index),
            child: _pages[index],
          ),
        ),
        bottomNavigationBar: _FloatingNav(
          config: config,
          selectedIndex: index,
          onTap: (i) =>
              ref.read(bottomNavIndexProvider.notifier).state = i,
        ),
        // Global "Log a tasting" entry — surfaces the app's core action from
        // every tab (it used to be reachable only deep inside a dish detail).
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showLogTastingSheet(context),
          backgroundColor: config.accent,
          foregroundColor: config.onPrimary,
          elevation: 3,
          icon: const Icon(LucideIcons.plus, size: 20),
          label: Text(
            'Log',
            style: GoogleFonts.hankenGrotesk(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Floating Glass Navigation ────────────────────────────────────────────────

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.config,
    required this.selectedIndex,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: LucideIcons.home,     label: 'Home'),
    (icon: LucideIcons.map,      label: 'Map'),
    (icon: LucideIcons.compass,  label: 'Explore'),
    (icon: LucideIcons.bookOpen, label: 'Journal'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        GS.s20, GS.s8, GS.s20, bottomPad > 0 ? bottomPad : GS.s16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GS.r32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: GS.navBarH,
            decoration: BoxDecoration(
              color: config.navBackground.withOpacity(config.isDark ? 0.84 : 0.92),
              borderRadius: BorderRadius.circular(GS.r32),
              border: Border.all(
                color: config.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(config.isDark ? 0.50 : 0.14),
                  blurRadius: 48,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(config.isDark ? 0.20 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                return _NavItem(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  isActive: i == selectedIndex,
                  config: config,
                  onTap: () => onTap(i),
                );
              }),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: GS.slow, delay: const Duration(milliseconds: 200))
        .slideY(begin: 0.4, end: 0, duration: GS.slow,
            delay: const Duration(milliseconds: 200), curve: GS.smooth);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.config,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final GastroThemeConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: GS.fast,
        curve: GS.smooth,
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: GS.s16, vertical: GS.s10)
            : const EdgeInsets.symmetric(horizontal: GS.s12, vertical: GS.s10),
        decoration: BoxDecoration(
          color: isActive ? config.navActivePill : Colors.transparent,
          borderRadius: BorderRadius.circular(GS.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.08 : 1.0,
              duration: GS.fast,
              curve: GS.spring,
              child: Icon(
                icon,
                size: 21,
                color: isActive ? config.navActiveIcon : config.navInactiveIcon,
              ),
            ),
            AnimatedSize(
              duration: GS.fast,
              curve: GS.smooth,
              child: isActive
                  ? Row(
                      children: [
                        const SizedBox(width: GS.s6),
                        Text(
                          label,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: config.navActiveIcon,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
