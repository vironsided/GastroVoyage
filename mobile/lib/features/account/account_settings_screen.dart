import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/features/badges/achievements_screen.dart';
import 'package:mobile/features/notifications/data/notifications_providers.dart';
import 'package:mobile/features/notifications/notifications_screen.dart';
import 'package:mobile/features/onboarding/theme_selector_screen.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/showcase/showcase_screen.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/friends_screen.dart';
import 'package:mobile/features/social/stories_feed.dart';
import 'package:mobile/ui/ui.dart';

// ─── Mode-specific card top decoration ───────────────────────────────────────

class _ModeCardTop extends StatelessWidget {
  const _ModeCardTop({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return SizedBox(
          height: 9,
          child: ClipRect(
            child: CustomPaint(
              size: const Size(double.infinity, 9),
              painter: LacePainter(
                color: config.accent,
                dotRadius: 4.5,
                gap: 9,
                baseline: true,
              ),
            ),
          ),
        );
      case GastroThemeMode.couples:
        return SizedBox(
          height: 5,
          child: CustomPaint(
            size: const Size(double.infinity, 5),
            painter: StripePainter(
              color: config.accent.withOpacity(0.6),
              opacity: 1.0,
            ),
          ),
        );
      case GastroThemeMode.guys:
        return Container(height: 4, color: config.accent);
    }
  }
}

/// Decorative washi-tape strip pinning the top edge of a card to the "page".
/// A small flourish that reads as craft material, not chrome.
class _WashiStrip extends StatelessWidget {
  const _WashiStrip({
    required this.config,
    this.width = 64,
    this.rotation = -0.12,
  });

  final GastroThemeConfig config;
  final double width;
  final double rotation;

  WashiPattern get _pattern {
    switch (config.mode) {
      case GastroThemeMode.girls:
        return WashiPattern.dots;
      case GastroThemeMode.couples:
        return WashiPattern.stripes;
      case GastroThemeMode.guys:
        return WashiPattern.solid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: width,
        height: 22,
        child: CustomPaint(
          painter: WashiTapePainter(
            color: config.accent.withOpacity(config.isDark ? 0.55 : 0.7),
            pattern: _pattern,
          ),
        ),
      ),
    );
  }
}

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  Future<void> _confirmSignOut(GastroThemeConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GS.r24)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: config.onSurface,
          ),
        ),
        content: Text(
          'You\'ll need to sign in again to access your culinary passport.',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: config.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: config.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: config.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GS.r12)),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      await ref.read(authProvider.notifier).logout();
      // Clear all cached backend data so next login starts fresh
      ref.invalidate(profileProvider);
      ref.invalidate(visitsProvider);
      ref.invalidate(badgesProvider);
      ref.invalidate(mapCountriesProvider);
      ref.invalidate(exploreCountriesProvider);
      ref.invalidate(privacyProvider);
      invalidateSocialFromWidget(ref);
    }
  }

  Future<void> _editProfile(GastroThemeConfig config) async {
    final auth = ref.read(authProvider);
    final currentAvatar = ref.read(profileProvider).valueOrNull?.avatarUrl;

    final nameCtrl = TextEditingController(text: auth.displayName ?? '');
    final emailCtrl = TextEditingController(text: auth.email ?? '');
    final cityCtrl = TextEditingController(text: auth.homeCity ?? '');

    // The sheet handles the avatar pick + upload itself (it has access to the
    // ApiClient) and hands back the resulting public URL via the result. ALL
    // provider/state mutation happens below — after the modal route is fully
    // gone — so a rebuild never races with the sheet teardown (that race tore
    // down an InheritedElement with live dependents → _dependents.isEmpty).
    final result = await showModalBottomSheet<_EditProfileResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        nameCtrl: nameCtrl,
        emailCtrl: emailCtrl,
        cityCtrl: cityCtrl,
        initialAvatarUrl: currentAvatar,
        initial: (auth.displayName ?? 'E').isNotEmpty
            ? (auth.displayName ?? 'E')[0].toUpperCase()
            : 'E',
        config: config,
      ),
    );

    if (result != null) {
      final displayName =
          nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim();
      final emailVal =
          emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
      final homeCity =
          cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim();
      // Only send the avatar when the user actually picked a new one.
      final avatarUrl = result.avatarUrl;

      await ref.read(authProvider.notifier).updateProfile(
            displayName: displayName,
            email: emailVal,
            homeCity: homeCity,
          );
      try {
        await ref.read(apiClientProvider).updateProfile(
              displayName: displayName,
              homeCity: homeCity,
              avatarUrl: avatarUrl,
            );
      } catch (_) {}
      if (mounted) ref.invalidate(profileProvider);
    }

    nameCtrl.dispose();
    emailCtrl.dispose();
    cityCtrl.dispose();
  }

  Future<void> _changeTheme() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, a, b) => const _ThemePickerPage(),
        transitionsBuilder: (ctx, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: GS.normal,
      ),
    );
  }

  void _openFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
  }

  void _openAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
    );
  }

  void _openStoriesFeed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StoriesFeedScreen()),
    );
  }

  /// Opens the inbox and re-pulls the unread count when the user returns —
  /// the inbox itself read-alls on open, so the badge clears on come-back.
  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    ref.invalidate(unreadCountProvider);
    ref.invalidate(notificationsProvider);
  }

  /// Opens the passport-privacy chooser sheet and persists the pick via
  /// `PATCH /social/privacy`, then invalidates [privacyProvider] so the tile
  /// subtitle refreshes.
  Future<void> _choosePrivacy(
    GastroThemeConfig config,
    PassportVisibility current,
  ) async {
    final picked = await showModalBottomSheet<PassportVisibility>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrivacySheet(config: config, current: current),
    );

    if (picked == null || picked == current || !mounted) return;

    HapticFeedback.selectionClick();
    try {
      await ref.read(apiClientProvider).setPrivacy(picked);
      if (mounted) ref.invalidate(privacyProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update privacy. Please try again.',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
          ),
          backgroundColor: config.error,
        ),
      );
    }
  }

  Future<void> _confirmDeleteAccount(GastroThemeConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => _DeleteAccountDialog(config: config),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();

    // Show a blocking progress overlay while the destructive call runs.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.all(GS.s24),
          decoration: BoxDecoration(
            color: config.surface,
            borderRadius: BorderRadius.circular(GS.r20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: config.error,
                ),
              ),
              const SizedBox(height: GS.s16),
              Text(
                'Erasing your passport…',
                style: GoogleFonts.caveat(
                  fontSize: 18,
                  color: config.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    bool ok = false;
    String? errorMessage;
    try {
      await ref.read(apiClientProvider).deleteAccount();
      ok = true;
    } catch (e) {
      errorMessage = 'We couldn\'t delete your account. Please try again.';
    }

    if (!mounted) return;
    // Dismiss the progress overlay.
    Navigator.of(context, rootNavigator: true).pop();

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'Something went wrong.',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
          ),
          backgroundColor: config.error,
        ),
      );
      return;
    }

    // Account is gone. Clear local tokens, drop cached backend data, and
    // route to login with no leftover routes so no stale screen rebuilds
    // against the now-invalid session.
    await ref.read(authProvider.notifier).logout();
    ref.invalidate(profileProvider);
    ref.invalidate(visitsProvider);
    ref.invalidate(badgesProvider);
    ref.invalidate(mapCountriesProvider);
    ref.invalidate(exploreCountriesProvider);
    ref.invalidate(privacyProvider);
    invalidateSocialFromWidget(ref);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final themeMode = ref.watch(gastroThemeProvider) ?? GastroThemeMode.girls;
    final config = GastroThemeConfig.forMode(themeMode);
    final profileAsync = ref.watch(profileProvider);
    final badgesAsync = ref.watch(badgesProvider);
    final visitsAsync = ref.watch(visitsProvider);
    final privacyAsync = ref.watch(privacyProvider);
    final privacy =
        privacyAsync.valueOrNull ?? PassportVisibility.private;
    final unreadAsync = ref.watch(unreadCountProvider);
    final unread = unreadAsync.valueOrNull ?? 0;

    final displayName = auth.displayName ?? 'Explorer';
    final email = auth.email ?? '';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E';

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.07,
        scratchCount: 7,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App bar ────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: config.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
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
              ),
              title: Text(
                'Account',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  GS.s20, GS.s8, GS.s20, GS.s40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  _ProfileHeroCard(
                    displayName: displayName,
                    email: email,
                    initial: initial,
                    avatarUrl: profileAsync.valueOrNull?.avatarUrl,
                    config: config,
                    onEdit: () => _editProfile(config),
                  )
                      .animate()
                      .fadeIn(duration: GS.slow, curve: GS.smooth)
                      .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: GS.slow,
                          curve: GS.smooth),
                  // Real lace ribbon — Girls theme only (returns
                  // SizedBox.shrink() for Couples/Guys).
                  LaceRibbon(
                    config: config,
                    height: 18,
                    color: config.accent.withOpacity(0.35),
                  ),
                  const SizedBox(height: GS.s20),

                  _SectionLabel(
                    label: 'Passport',
                    subtitle: 'Stamps collected so far',
                    config: config,
                    index: 0,
                  ),
                  const SizedBox(height: GS.s12),

                  _buildStatsRow(
                    profileAsync: profileAsync,
                    visitsAsync: visitsAsync,
                    badgesAsync: badgesAsync,
                    config: config,
                  ),
                  const SizedBox(height: GS.s28),

                  _SectionLabel(
                    label: 'Preferences',
                    subtitle: 'Make it yours',
                    config: config,
                    index: 1,
                  ),
                  const SizedBox(height: GS.s12),

                  _SectionCard(config: config, index: 1, children: [
                    _SettingsTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      subtitle: 'Name, email, home city',
                      config: config,
                      onTap: () => _editProfile(config),
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      label: 'App Theme',
                      subtitle: '${config.name} · ${config.tagline}',
                      config: config,
                      onTap: _changeTheme,
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: config.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: config.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: config.accent.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      label: 'Design Showcase',
                      subtitle: 'Preview every scrapbook component',
                      config: config,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShowcaseScreen(),
                        ),
                      ),
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      subtitle: unread > 0
                          ? '$unread new since you last looked'
                          : 'Follows, story views, milestones',
                      config: config,
                      onTap: _openNotifications,
                      trailing: unread > 0
                          ? _UnreadBadge(config: config, count: unread)
                          : null,
                    ),
                  ]),
                  const SizedBox(height: GS.s24),

                  // ── Social ──────────────────────────────────────────
                  _SectionLabel(
                    label: 'Social',
                    subtitle: 'Your travel circle',
                    config: config,
                    index: 2,
                  ),
                  const SizedBox(height: GS.s12),

                  _SectionCard(config: config, index: 2, children: [
                    _SettingsTile(
                      icon: Icons.group_outlined,
                      label: 'Friends & Followers',
                      subtitle: 'Find travellers, manage requests',
                      config: config,
                      onTap: _openFriends,
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Achievements',
                      subtitle: 'Stamps earned and still to collect',
                      config: config,
                      onTap: _openAchievements,
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.auto_stories_outlined,
                      label: 'Stories Feed',
                      subtitle: 'Tastings from travellers you follow',
                      config: config,
                      onTap: _openStoriesFeed,
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.visibility_outlined,
                      label: 'Passport Privacy',
                      subtitle: privacyAsync.hasError
                          ? 'Tap to set who can view your passport'
                          : privacy.description,
                      config: config,
                      onTap: () => _choosePrivacy(config, privacy),
                      trailing: _PrivacyTrailing(
                        config: config,
                        loading: privacyAsync.isLoading,
                        visibility: privacy,
                      ),
                    ),
                  ]),
                  const SizedBox(height: GS.s24),

                  _SectionLabel(
                    label: 'Community',
                    subtitle: 'Share the journey',
                    config: config,
                    index: 3,
                  ),
                  const SizedBox(height: GS.s12),

                  _SectionCard(config: config, index: 3, children: [
                    _SettingsTile(
                      icon: Icons.share_outlined,
                      label: 'Share Profile',
                      subtitle: 'Let friends see your passport',
                      config: config,
                      onTap: () {},
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.star_outline_rounded,
                      label: 'Rate the App',
                      subtitle: 'Enjoying GastroVoyage?',
                      config: config,
                      onTap: () {},
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      subtitle: 'FAQ, contact us',
                      config: config,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: GS.s24),

                  _SectionLabel(
                    label: 'About',
                    subtitle: 'The fine print',
                    config: config,
                    index: 4,
                  ),
                  const SizedBox(height: GS.s12),

                  _SectionCard(config: config, index: 4, children: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      label: 'About GastroVoyage',
                      subtitle: 'Version 2.1.0',
                      config: config,
                      onTap: () {},
                    ),
                    _Divider(config: config),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      subtitle: 'How we handle your data',
                      config: config,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: GS.s28),

                  _SignOutButton(
                    config: config,
                    onPressed: () => _confirmSignOut(config),
                  )
                      .animate()
                      .fadeIn(
                          duration: GS.normal,
                          delay: GS.stagger(4),
                          curve: GS.smooth),
                  const SizedBox(height: GS.s28),

                  _SectionLabel(
                    label: 'Danger Zone',
                    subtitle: 'No going back from here',
                    config: config,
                    index: 5,
                  ),
                  const SizedBox(height: GS.s12),

                  _DangerZoneCard(
                    config: config,
                    onDelete: () => _confirmDeleteAccount(config),
                  )
                      .animate()
                      .fadeIn(
                          duration: GS.normal,
                          delay: GS.stagger(5),
                          curve: GS.smooth)
                      .slideY(
                          begin: 0.05,
                          end: 0,
                          duration: GS.normal,
                          delay: GS.stagger(5),
                          curve: GS.smooth),
                  const SizedBox(height: GS.s12),

                  // Editorial sign-off — a small "made with care" footer.
                  Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 1,
                          child: ColoredBox(
                            color:
                                config.onSurfaceVariant.withOpacity(0.25),
                          ),
                        ),
                        const SizedBox(height: GS.s10),
                        Text(
                          'GastroVoyage · v2.1.0',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: config.onSurfaceVariant.withOpacity(0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: GS.s4),
                        Text(
                          'made for the hungry & curious',
                          style: GoogleFonts.caveat(
                            fontSize: 15,
                            color: config.onSurfaceVariant.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(
                        duration: GS.slow,
                        delay: GS.stagger(5),
                      ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required AsyncValue<UserProfile> profileAsync,
    required AsyncValue<List<Visit>> visitsAsync,
    required AsyncValue<List<CuisineBadge>> badgesAsync,
    required GastroThemeConfig config,
  }) {
    final visited = profileAsync.valueOrNull?.visitedCount ?? 0;
    final visits = visitsAsync.valueOrNull?.length ?? 0;
    final badges =
        badgesAsync.valueOrNull?.where((b) => b.earned).length ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$visited',
            label: visited == 1 ? 'Country' : 'Countries',
            icon: LucideIcons.globe,
            config: config,
            index: 0,
          ),
        ),
        const SizedBox(width: GS.s12),
        Expanded(
          child: _StatCard(
            value: '$visits',
            label: visits == 1 ? 'Entry' : 'Entries',
            icon: LucideIcons.bookOpen,
            config: config,
            index: 1,
          ),
        ),
        const SizedBox(width: GS.s12),
        Expanded(
          child: _StatCard(
            value: '$badges',
            label: badges == 1 ? 'Badge' : 'Badges',
            icon: LucideIcons.award,
            config: config,
            index: 2,
          ),
        ),
      ],
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

/// Editorial section divider that animates in with a slight stagger.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.config,
    required this.index,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final GastroThemeConfig config;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(
      label: label,
      subtitle: subtitle,
      config: config,
    )
        .animate()
        .fadeIn(
            duration: GS.normal,
            delay: GS.stagger(index),
            curve: GS.smooth)
        .slideX(
            begin: -0.04,
            end: 0,
            duration: GS.normal,
            delay: GS.stagger(index),
            curve: GS.smooth);
  }
}

// ─── Profile Hero Card ────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.displayName,
    required this.email,
    required this.initial,
    required this.config,
    required this.onEdit,
    this.avatarUrl,
  });

  final String displayName;
  final String email;
  final String initial;
  final String? avatarUrl;
  final GastroThemeConfig config;
  final VoidCallback onEdit;

  Widget _heroInitial() {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(GS.s24),
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
              opacity: 0.35,
            ),
          ),
          child: Row(
            children: [
              // Avatar — framed like a passport portrait with a wax seal.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2.5,
                      ),
                    ),
                    child: ClipOval(
                      child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  _heroInitial(),
                              errorWidget: (_, __, ___) =>
                                  _heroInitial(),
                            )
                          : _heroInitial(),
                    ),
                  ),
                  // Tiny wax seal pinning the portrait — "verified traveller".
                  Positioned(
                    right: -10,
                    bottom: -8,
                    child: WaxSeal(
                      config: config,
                      size: 30,
                      rotation: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: GS.s20),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CULINARY PASSPORT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: GS.s4),
                    Text(
                      displayName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: GS.s4),
                      Text(
                        email,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: GS.s10),
                    _EditChip(onTap: onEdit),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Washi tape pinning the card to the page.
        Positioned(
          top: -8,
          right: 26,
          child: _WashiStrip(config: config, width: 58, rotation: 0.16),
        ),
      ],
    );
  }
}

/// Pressable "Edit Profile" chip with a subtle scale feedback.
class _EditChip extends StatefulWidget {
  const _EditChip({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_EditChip> createState() => _EditChipState();
}

class _EditChipState extends State<_EditChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: GS.micro,
        curve: GS.smooth,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(GS.r20),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined,
                  color: Colors.white, size: 14),
              const SizedBox(width: GS.s6),
              Text(
                'Edit Profile',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.config,
    required this.index,
  });

  final String value;
  final String label;
  final IconData icon;
  final GastroThemeConfig config;
  final int index;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(GS.r20),
      child: Container(
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
          children: [
            _ModeCardTop(config: config),
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 18, horizontal: GS.s12),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: config.accent),
                  const SizedBox(height: GS.s6),
                  Text(
                    value,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: config.accent,
                    ),
                  ),
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      color: config.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(
            duration: GS.slow,
            delay: GS.stagger(index, ms: 60),
            curve: GS.smooth)
        .slideY(
            begin: 0.12,
            end: 0,
            duration: GS.slow,
            delay: GS.stagger(index, ms: 60),
            curve: GS.smooth);
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.config,
    required this.children,
    required this.index,
  });
  final GastroThemeConfig config;
  final List<Widget> children;
  final int index;

  @override
  Widget build(BuildContext context) {
    final card = Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(GS.r20),
          child: Container(
            decoration: BoxDecoration(
              color: config.surface,
              borderRadius: BorderRadius.circular(GS.r20),
              border: Border.all(color: config.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(config.isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModeCardTop(config: config),
                ...children,
              ],
            ),
          ),
        ),
        // Washi tape pinning the card — alternate side per section.
        Positioned(
          top: -7,
          left: index.isEven ? 24 : null,
          right: index.isEven ? null : 24,
          child: _WashiStrip(
            config: config,
            width: 52,
            rotation: index.isEven ? -0.14 : 0.14,
          ),
        ),
      ],
    );

    return card
        .animate()
        .fadeIn(
            duration: GS.normal,
            delay: GS.stagger(index, ms: 80),
            curve: GS.smooth)
        .slideY(
            begin: 0.05,
            end: 0,
            duration: GS.normal,
            delay: GS.stagger(index, ms: 80),
            curve: GS.smooth);
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: config.outlineVariant,
      indent: 56,
      endIndent: GS.s16,
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────

class _SettingsTile extends StatefulWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.config,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final GastroThemeConfig config;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (v) => setState(() => _pressed = v),
      borderRadius: BorderRadius.circular(GS.r20),
      splashColor: config.surfaceVariant,
      highlightColor: config.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: GS.s16, vertical: 14),
        child: Row(
          children: [
            // Icon "stamp" — tints up while pressed for tactile feedback.
            AnimatedContainer(
              duration: GS.micro,
              curve: GS.smooth,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _pressed
                    ? config.accent.withOpacity(0.18)
                    : config.surfaceVariant,
                borderRadius: BorderRadius.circular(GS.r12),
              ),
              child: Icon(widget.icon, size: 20, color: config.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: config.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: config.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: GS.s8),
              widget.trailing!,
            ] else
              AnimatedSlide(
                offset: Offset(_pressed ? 0.18 : 0, 0),
                duration: GS.micro,
                curve: GS.smooth,
                child: Icon(Icons.chevron_right_rounded,
                    color: config.onSurfaceVariant, size: 22),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sign Out Button ──────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.config, required this.onPressed});
  final GastroThemeConfig config;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          'Sign Out',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: config.error,
          side: BorderSide(color: config.error.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GS.r16),
          ),
        ),
      ),
    );
  }
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────

/// Result handed back when the Edit Profile sheet is saved. [avatarUrl] is the
/// freshly-uploaded public URL, or null when the user didn't change the avatar.
class _EditProfileResult {
  const _EditProfileResult({this.avatarUrl});
  final String? avatarUrl;
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.cityCtrl,
    required this.config,
    required this.initial,
    this.initialAvatarUrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController cityCtrl;
  final GastroThemeConfig config;

  /// Initial-letter fallback shown before any avatar exists.
  final String initial;

  /// The user's existing avatar URL, shown until they pick a new one.
  final String? initialAvatarUrl;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  bool _saving = false;

  /// Locally-picked file, shown immediately while still on disk.
  File? _pickedFile;

  /// Public URL after a successful upload — what gets persisted.
  String? _uploadedUrl;

  bool _pickingAvatar = false;
  bool _avatarError = false;

  Future<void> _pickAvatar() async {
    if (_pickingAvatar || _saving) return;
    setState(() {
      _pickingAvatar = true;
      _avatarError = false;
    });
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) {
        // User cancelled — nothing changes.
        if (mounted) setState(() => _pickingAvatar = false);
        return;
      }
      HapticFeedback.selectionClick();
      final file = File(picked.path);
      // Show the local file straight away for instant feedback.
      if (mounted) setState(() => _pickedFile = file);
      // Upload in the background; the resulting URL is what we persist.
      final url = await ref.read(apiClientProvider).uploadPhoto(file);
      if (mounted) {
        setState(() {
          _uploadedUrl = url;
          _pickingAvatar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickingAvatar = false;
          _avatarError = true;
          _pickedFile = null;
        });
      }
    }
  }

  Future<void> _save() async {
    // Block save while an avatar upload is still in flight, so we never
    // persist a missing URL for a picture the user clearly chose.
    if (_pickingAvatar) return;
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_EditProfileResult(avatarUrl: _uploadedUrl));
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(
          left: GS.s12, right: GS.s12, bottom: GS.s12 + bottom),
      padding: const EdgeInsets.fromLTRB(GS.s24, GS.s20, GS.s24, GS.s24),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: config.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: GS.s20),
            Text(
              'EDIT PROFILE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
                color: config.accent,
              ),
            ),
            const SizedBox(height: GS.s4),
            Text(
              'Your passport details',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
            const SizedBox(height: GS.s20),

            // ── Avatar picker — Instax/Polaroid portrait ──────────────────
            Center(
              child: _AvatarPicker(
                config: config,
                initial: widget.initial,
                pickedFile: _pickedFile,
                existingUrl: widget.initialAvatarUrl,
                busy: _pickingAvatar,
                onTap: _pickAvatar,
              ),
            ),
            const SizedBox(height: GS.s6),
            Center(
              child: Text(
                _avatarError
                    ? 'Couldn\'t use that photo — tap to retry'
                    : 'Tap the photo to choose from your gallery',
                style: GoogleFonts.caveat(
                  fontSize: 15,
                  color: _avatarError
                      ? config.error
                      : config.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: GS.s20),

            _SheetField(
              controller: widget.nameCtrl,
              label: 'Display Name',
              icon: Icons.person_outline_rounded,
              config: config,
            ),
            const SizedBox(height: 14),

            _SheetField(
              controller: widget.emailCtrl,
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              config: config,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),

            _SheetField(
              controller: widget.cityCtrl,
              label: 'Home City',
              icon: Icons.location_city_outlined,
              config: config,
            ),
            const SizedBox(height: GS.s24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_saving || _pickingAvatar) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: config.accent.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GS.r16),
                  ),
                ),
                child: (_saving || _pickingAvatar)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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

/// Tappable Instax/Polaroid portrait used to pick an avatar from the gallery.
/// White border with a wider bottom lip, a slight skew, and a soft shadow.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.config,
    required this.initial,
    required this.onTap,
    required this.busy,
    this.pickedFile,
    this.existingUrl,
  });

  final GastroThemeConfig config;
  final String initial;
  final VoidCallback onTap;
  final bool busy;
  final File? pickedFile;
  final String? existingUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: -0.045,
        child: Container(
          // Instax frame: white card, wider bottom lip.
          padding: const EdgeInsets.fromLTRB(GS.s8, GS.s8, GS.s8, GS.s24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GS.r4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(GS.r4),
                  child: _photo(),
                ),
              ),
              const SizedBox(height: GS.s6),
              Text(
                'me, lately',
                style: GoogleFonts.caveat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo() {
    final Widget base;
    if (pickedFile != null) {
      base = Image.file(pickedFile!, fit: BoxFit.cover);
    } else if (existingUrl != null && existingUrl!.isNotEmpty) {
      base = CachedNetworkImage(
        imageUrl: existingUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialBox(),
        errorWidget: (_, __, ___) => _initialBox(),
      );
    } else {
      base = _initialBox();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        // Camera affordance + busy spinner overlay.
        Positioned.fill(
          child: Container(
            color: busy
                ? Colors.black.withOpacity(0.35)
                : Colors.transparent,
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(GS.s6),
                      child: Container(
                        padding: const EdgeInsets.all(GS.s6),
                        decoration: BoxDecoration(
                          color: config.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.photo_camera_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _initialBox() {
    return Container(
      color: config.accentSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.playfairDisplay(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: config.accent,
        ),
      ),
    );
  }
}

// ─── Danger Zone ──────────────────────────────────────────────────────────────

/// A visually distinct destructive-action card. Red-tinted surface, an ink
/// stamp warning icon, and a single Delete Account row.
class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({required this.config, required this.onDelete});
  final GastroThemeConfig config;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GS.r20),
      child: Container(
        decoration: BoxDecoration(
          color: config.error.withOpacity(config.isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(GS.r20),
          border: Border.all(color: config.error.withOpacity(0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: config.error),
            _DangerTile(config: config, onTap: onDelete),
          ],
        ),
      ),
    );
  }
}

class _DangerTile extends StatefulWidget {
  const _DangerTile({required this.config, required this.onTap});
  final GastroThemeConfig config;
  final VoidCallback onTap;

  @override
  State<_DangerTile> createState() => _DangerTileState();
}

class _DangerTileState extends State<_DangerTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (v) => setState(() => _pressed = v),
      splashColor: config.error.withOpacity(0.12),
      highlightColor: config.error.withOpacity(0.08),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: GS.s16, vertical: 14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: GS.micro,
              curve: GS.smooth,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _pressed
                    ? config.error.withOpacity(0.28)
                    : config.error.withOpacity(0.14),
                borderRadius: BorderRadius.circular(GS.r12),
              ),
              child: Icon(Icons.delete_forever_rounded,
                  size: 20, color: config.error),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Account',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: config.error,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Permanently erase your passport & all entries',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: config.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AnimatedSlide(
              offset: Offset(_pressed ? 0.18 : 0, 0),
              duration: GS.micro,
              curve: GS.smooth,
              child: Icon(Icons.chevron_right_rounded,
                  color: config.error.withOpacity(0.7), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Delete Account Dialog ────────────────────────────────────────────────────

/// High-priority destructive confirmation. The confirm button stays disabled
/// until the user types the exact phrase `delete my account` (case-sensitive).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.config});
  final GastroThemeConfig config;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const _phrase = 'delete my account';
  final TextEditingController _ctrl = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final next = _ctrl.text.trim() == _phrase;
      if (next != _matches) setState(() => _matches = next);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(GS.s24, GS.s24, GS.s24, GS.s24 + bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(GS.s24, GS.s24, GS.s24, GS.s20),
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius: BorderRadius.circular(GS.r24),
          border: Border.all(color: config.error.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: config.error.withOpacity(0.25),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ink-stamp style warning crest.
            Center(
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GS.s12, vertical: GS.s6),
                  decoration: BoxDecoration(
                    border: Border.all(color: config.error, width: 2),
                    borderRadius: BorderRadius.circular(GS.r4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: config.error),
                      const SizedBox(width: GS.s6),
                      Text(
                        'POINT OF NO RETURN',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                          color: config.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: GS.s16),
            Text(
              'Delete your account?',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: config.onSurface,
              ),
            ),
            const SizedBox(height: GS.s8),
            Text(
              'This permanently erases your passport, every tasting entry, '
              'and all earned badges. This cannot be undone.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                height: 1.5,
                color: config.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: GS.s16),
            Text.rich(
              TextSpan(
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  color: config.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'Type '),
                  TextSpan(
                    text: _phrase,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                    ),
                  ),
                  const TextSpan(text: ' to confirm.'),
                ],
              ),
            ),
            const SizedBox(height: GS.s10),
            TextField(
              controller: _ctrl,
              autocorrect: false,
              enableSuggestions: false,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: config.onSurface,
              ),
              decoration: InputDecoration(
                hintText: _phrase,
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: config.onSurfaceVariant.withOpacity(0.4),
                ),
                filled: true,
                fillColor: config.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: GS.s16, vertical: GS.s12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GS.r12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GS.r12),
                  borderSide:
                      BorderSide(color: config.outlineVariant, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(GS.r12),
                  borderSide: BorderSide(
                      color: _matches ? config.error : config.accent,
                      width: 1.5),
                ),
                suffixIcon: _matches
                    ? Icon(Icons.check_circle_rounded,
                        color: config.error, size: 20)
                    : null,
              ),
            ),
            const SizedBox(height: GS.s20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: config.onSurfaceVariant,
                        side: BorderSide(color: config.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GS.r12),
                        ),
                      ),
                      child: Text(
                        'Keep It',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GS.s12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _matches
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: config.error,
                        disabledBackgroundColor:
                            config.error.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GS.r12),
                        ),
                      ),
                      child: Text(
                        'Delete Forever',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.config,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final GastroThemeConfig config;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 15,
        color: config.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: config.onSurfaceVariant,
        ),
        prefixIcon: Icon(icon, color: config.onSurfaceVariant, size: 20),
        filled: true,
        fillColor: config.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r12),
          borderSide: BorderSide(color: config.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r12),
          borderSide: BorderSide(color: config.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Theme Picker Page ────────────────────────────────────────────────────────

class _ThemePickerPage extends ConsumerWidget {
  const _ThemePickerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(GS.s20, GS.s16, GS.s20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Change Theme',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ThemeSelectorScreen(
                onThemeSelected: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Unread badge ─────────────────────────────────────────────────────────────

/// Small circular pill showing the unread notifications count. Matches the
/// "stamp" aesthetic of the other tile trailings — accent-tinted, jetBrainsMono
/// digits, capped at "99+" so the pill never blows up the row.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.config, required this.count});

  final GastroThemeConfig config;
  final int count;

  String get _label => count > 99 ? '99+' : '$count';

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: config.accent,
        borderRadius: BorderRadius.circular(GS.rPill),
        boxShadow: [
          BoxShadow(
            color: config.accent.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─── Passport Privacy ─────────────────────────────────────────────────────────

/// Compact trailing widget for the Passport Privacy tile — a small stamp-style
/// chip showing the current visibility (or a spinner while it loads).
class _PrivacyTrailing extends StatelessWidget {
  const _PrivacyTrailing({
    required this.config,
    required this.loading,
    required this.visibility,
  });

  final GastroThemeConfig config;
  final bool loading;
  final PassportVisibility visibility;

  IconData get _icon {
    switch (visibility) {
      case PassportVisibility.public:
        return Icons.public_rounded;
      case PassportVisibility.followers:
        return Icons.group_rounded;
      case PassportVisibility.private:
        return Icons.lock_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: config.accent,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GS.s8, vertical: 4),
      decoration: BoxDecoration(
        color: config.accentSoft,
        borderRadius: BorderRadius.circular(GS.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: config.accent),
          const SizedBox(width: GS.s4),
          Text(
            visibility.label.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: config.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet chooser for passport visibility. Returns the selected
/// [PassportVisibility] (or null when dismissed without a change).
class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet({required this.config, required this.current});
  final GastroThemeConfig config;
  final PassportVisibility current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(GS.s12),
      padding: const EdgeInsets.fromLTRB(GS.s24, GS.s20, GS.s24, GS.s24),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: config.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: GS.s20),
          Text(
            'PASSPORT PRIVACY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              color: config.accent,
            ),
          ),
          const SizedBox(height: GS.s4),
          Text(
            'Who can view your passport?',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
            ),
          ),
          const SizedBox(height: GS.s20),
          for (final v in PassportVisibility.values) ...[
            _PrivacyOption(
              config: config,
              visibility: v,
              selected: v == current,
              onTap: () => Navigator.pop(context, v),
            ),
            if (v != PassportVisibility.values.last)
              const SizedBox(height: GS.s10),
          ],
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  const _PrivacyOption({
    required this.config,
    required this.visibility,
    required this.selected,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final PassportVisibility visibility;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (visibility) {
      case PassportVisibility.public:
        return Icons.public_rounded;
      case PassportVisibility.followers:
        return Icons.group_rounded;
      case PassportVisibility.private:
        return Icons.lock_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(GS.r16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? config.accentSoft : config.surfaceVariant,
          borderRadius: BorderRadius.circular(GS.r16),
          border: Border.all(
            color: selected ? config.accent : config.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? config.accent
                    : config.surface,
                borderRadius: BorderRadius.circular(GS.r12),
              ),
              child: Icon(
                _icon,
                size: 20,
                color: selected ? Colors.white : config.accent,
              ),
            ),
            const SizedBox(width: GS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibility.label,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    visibility.description,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: config.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 22,
              color: selected
                  ? config.accent
                  : config.onSurfaceVariant.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
