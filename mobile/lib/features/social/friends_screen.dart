import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/public_passport_screen.dart';
import 'package:mobile/features/social/widgets/follow_button.dart';
import 'package:mobile/features/social/widgets/social_user_tile.dart';
import 'package:mobile/ui/ui.dart';

/// Friends & Followers hub — manage the follow graph.
///
/// Two tabs:
///  • Followers — incoming. Pending requests (Accept / Decline) at the top,
///    accepted followers below.
///  • Following — outgoing. Each row carries a follow-state pill.
///
/// A debounced user-search field sits above both tabs; results route to the
/// public passport screen and offer a Follow / Requested / Following action.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  /// User ids with a follow mutation in flight — drives per-row spinners.
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(userSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    ref.read(userSearchQueryProvider.notifier).state = '';
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openPassport(SocialUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicPassportScreen(
          userId: user.userId,
          previewName: user.name,
        ),
      ),
    );
  }

  // ── Follow-graph mutations ────────────────────────────────────────────────

  Future<void> _runMutation(
    String userId,
    Future<void> Function(ApiClient api) action, {
    String? failureMessage,
  }) async {
    if (_busyIds.contains(userId)) return;
    setState(() => _busyIds.add(userId));
    HapticFeedback.selectionClick();
    try {
      await action(ref.read(apiClientProvider));
      if (!mounted) return;
      invalidateSocialFromWidget(ref);
    } catch (e) {
      if (!mounted) return;
      final msg = e is UnauthorizedException
          ? 'Your session expired. Please sign in again.'
          : (failureMessage ?? 'Something went wrong. Please try again.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(userId));
    }
  }

  Future<void> _toggleFollow(SocialUser user) {
    switch (user.followStatus) {
      case FollowStatus.none:
        return _runMutation(
          user.userId,
          (api) => api.followUser(user.userId),
          failureMessage: 'Could not send the follow request.',
        );
      case FollowStatus.pending:
        return _runMutation(
          user.userId,
          (api) => api.unfollowUser(user.userId),
          failureMessage: 'Could not cancel the request.',
        );
      case FollowStatus.accepted:
        return _runMutation(
          user.userId,
          (api) => api.unfollowUser(user.userId),
          failureMessage: 'Could not unfollow.',
        );
    }
  }

  Future<void> _accept(SocialUser user) => _runMutation(
        user.userId,
        (api) => api.acceptFollow(user.userId),
        failureMessage: 'Could not accept the request.',
      );

  Future<void> _decline(SocialUser user) => _runMutation(
        user.userId,
        (api) => api.declineFollow(user.userId),
        failureMessage: 'Could not decline the request.',
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final searchQuery = ref.watch(userSearchQueryProvider);
    final searching = searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: config.background,
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.07,
        scratchCount: 6,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(config: config),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GS.s20, GS.s4, GS.s20, GS.s12),
                child: _SearchField(
                  controller: _searchCtrl,
                  config: config,
                  active: searching,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
              ),
              if (searching)
                Expanded(child: _searchResults(config))
              else ...[
                _Tabs(controller: _tabs, config: config),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _followersTab(config),
                      _followingTab(config),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────────────

  Widget _searchResults(GastroThemeConfig config) {
    final resultsAsync = ref.watch(userSearchProvider);
    return resultsAsync.when(
      loading: () => _ListShimmer(config: config),
      error: (e, _) => _ErrorView(
        config: config,
        message: e is UnauthorizedException
            ? 'Your session expired. Please sign in again.'
            : 'Could not search right now.',
        onRetry: () => ref.invalidate(userSearchProvider),
      ),
      data: (users) {
        if (users.isEmpty) {
          return _EmptyView(
            config: config,
            icon: LucideIcons.searchX,
            title: 'No travellers found',
            subtitle:
                'No one matches that name yet — try a different search.',
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              GS.s12, GS.s8, GS.s12, GS.navBuffer),
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              _RowDivider(config: config),
          itemBuilder: (_, i) {
            final user = users[i];
            return SocialUserTile(
              config: config,
              user: user,
              onTap: () => _openPassport(user),
              trailing: FollowButton(
                config: config,
                status: user.followStatus,
                busy: _busyIds.contains(user.userId),
                onPressed: () => _toggleFollow(user),
              ),
            );
          },
        );
      },
    );
  }

  // ── Followers tab ─────────────────────────────────────────────────────────

  Widget _followersTab(GastroThemeConfig config) {
    final followersAsync = ref.watch(followersProvider);
    return RefreshIndicator(
      color: config.accent,
      backgroundColor: config.surface,
      onRefresh: () async => ref.invalidate(followersProvider),
      child: followersAsync.when(
        loading: () => _ListShimmer(config: config),
        error: (e, _) => _ScrollableError(
          config: config,
          message: e is UnauthorizedException
              ? 'Your session expired. Please sign in again.'
              : 'Could not load your followers.',
          onRetry: () => ref.invalidate(followersProvider),
        ),
        data: (all) {
          final pending = all
              .where((u) => u.followStatus == FollowStatus.pending)
              .toList();
          final accepted = all
              .where((u) => u.followStatus == FollowStatus.accepted)
              .toList();

          if (pending.isEmpty && accepted.isEmpty) {
            return _ScrollableEmpty(
              config: config,
              icon: LucideIcons.users,
              title: 'No followers yet',
              subtitle:
                  'When travellers follow you, they\'ll show up here.',
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(
                GS.s12, GS.s12, GS.s12, GS.navBuffer),
            children: [
              if (pending.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GS.s8, GS.s4, GS.s8, GS.s10),
                  child: SectionHeader(
                    label: 'Requests',
                    subtitle: '${pending.length} waiting for you',
                    config: config,
                  ),
                ),
                for (var i = 0; i < pending.length; i++) ...[
                  SocialUserTile(
                    config: config,
                    user: pending[i],
                    caption: 'Wants to follow your passport',
                    onTap: () => _openPassport(pending[i]),
                    trailing: RequestActions(
                      config: config,
                      busy: _busyIds.contains(pending[i].userId),
                      onAccept: () => _accept(pending[i]),
                      onDecline: () => _decline(pending[i]),
                    ),
                  ),
                  if (i != pending.length - 1)
                    _RowDivider(config: config),
                ],
                const SizedBox(height: GS.s20),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GS.s8, GS.s4, GS.s8, GS.s10),
                child: SectionHeader(
                  label: 'Followers',
                  subtitle: accepted.isEmpty
                      ? 'None yet'
                      : '${accepted.length} travelling with you',
                  config: config,
                ),
              ),
              if (accepted.isEmpty)
                _InlineEmpty(
                  config: config,
                  text: 'No accepted followers yet.',
                )
              else
                for (var i = 0; i < accepted.length; i++) ...[
                  SocialUserTile(
                    config: config,
                    user: accepted[i],
                    caption: 'Follows your passport',
                    onTap: () => _openPassport(accepted[i]),
                  ),
                  if (i != accepted.length - 1)
                    _RowDivider(config: config),
                ],
            ],
          );
        },
      ),
    );
  }

  // ── Following tab ─────────────────────────────────────────────────────────

  Widget _followingTab(GastroThemeConfig config) {
    final followingAsync = ref.watch(followingProvider);
    return RefreshIndicator(
      color: config.accent,
      backgroundColor: config.surface,
      onRefresh: () async => ref.invalidate(followingProvider),
      child: followingAsync.when(
        loading: () => _ListShimmer(config: config),
        error: (e, _) => _ScrollableError(
          config: config,
          message: e is UnauthorizedException
              ? 'Your session expired. Please sign in again.'
              : 'Could not load who you follow.',
          onRetry: () => ref.invalidate(followingProvider),
        ),
        data: (users) {
          if (users.isEmpty) {
            return _ScrollableEmpty(
              config: config,
              icon: LucideIcons.compass,
              title: 'Not following anyone',
              subtitle:
                  'Search for fellow travellers and follow their passports.',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(
                GS.s12, GS.s12, GS.s12, GS.navBuffer),
            itemCount: users.length,
            separatorBuilder: (_, __) => _RowDivider(config: config),
            itemBuilder: (_, i) {
              final user = users[i];
              return SocialUserTile(
                config: config,
                user: user,
                caption: user.followStatus == FollowStatus.pending
                    ? 'Request pending'
                    : 'You follow this passport',
                onTap: () => _openPassport(user),
                trailing: FollowButton(
                  config: config,
                  status: user.followStatus,
                  busy: _busyIds.contains(user.userId),
                  onPressed: () => _toggleFollow(user),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, GS.s4),
      child: Row(
        children: [
          IconButton(
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
          const SizedBox(width: GS.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRAVEL CIRCLE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w600,
                    color: config.accent,
                  ),
                ),
                Text(
                  'Friends & Followers',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
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

// ─── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.config,
    required this.active,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final GastroThemeConfig config;
  final bool active;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 15,
        color: config.onSurface,
      ),
      decoration: InputDecoration(
        hintText: 'Search travellers by name',
        hintStyle: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: config.onSurfaceVariant.withOpacity(0.7),
        ),
        prefixIcon: Icon(LucideIcons.search,
            size: 18, color: config.onSurfaceVariant),
        suffixIcon: active
            ? IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: config.onSurfaceVariant),
                onPressed: onClear,
              )
            : null,
        filled: true,
        fillColor: config.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: GS.s16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r16),
          borderSide: BorderSide(color: config.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GS.r16),
          borderSide: BorderSide(color: config.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────

class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller, required this.config});
  final TabController controller;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s20, 0, GS.s20, GS.s8),
      child: Container(
        decoration: BoxDecoration(
          color: config.surfaceVariant,
          borderRadius: BorderRadius.circular(GS.rPill),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: config.accent,
            borderRadius: BorderRadius.circular(GS.rPill),
            boxShadow: GS.shadow(
              color: config.accent,
              blur: 10,
              yOffset: 3,
              opacity: 0.3,
            ),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: config.onSurfaceVariant,
          labelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          unselectedLabelStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
          tabs: const [
            Tab(height: 40, text: 'FOLLOWERS'),
            Tab(height: 40, text: 'FOLLOWING'),
          ],
        ),
      ),
    );
  }
}

// ─── Shared state widgets ─────────────────────────────────────────────────────

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: config.outlineVariant.withOpacity(0.6),
      indent: GS.s20 + 46,
      endIndent: GS.s20,
    );
  }
}

class _ListShimmer extends StatelessWidget {
  const _ListShimmer({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(GS.s20, GS.s16, GS.s20, GS.navBuffer),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s12),
      itemBuilder: (_, __) => GastroShimmer(
        config: config,
        height: 64,
        radius: GS.r16,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.config,
    required this.message,
    required this.onRetry,
  });
  final GastroThemeConfig config;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GS.s20),
      child: GastroErrorCard(
        config: config,
        message: message,
        onRetry: onRetry,
      ),
    );
  }
}

/// Error view that still scrolls, so it can pair with a RefreshIndicator.
class _ScrollableError extends StatelessWidget {
  const _ScrollableError({
    required this.config,
    required this.message,
    required this.onRetry,
  });
  final GastroThemeConfig config;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(GS.s20),
      children: [
        const SizedBox(height: GS.s40),
        GastroErrorCard(
          config: config,
          message: message,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.config,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final GastroThemeConfig config;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GS.s20),
        child: GastroEmptyState(
          config: config,
          icon: icon,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}

/// Empty view that still scrolls, so pull-to-refresh keeps working.
class _ScrollableEmpty extends StatelessWidget {
  const _ScrollableEmpty({
    required this.config,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final GastroThemeConfig config;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      padding:
          const EdgeInsets.fromLTRB(GS.s20, GS.s40, GS.s20, GS.navBuffer),
      children: [
        GastroEmptyState(
          config: config,
          icon: icon,
          title: title,
          subtitle: subtitle,
        ).animate().fadeIn(duration: GS.normal, curve: GS.smooth),
      ],
    );
  }
}

/// Small inline "nothing here" notice used inside a populated list section.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.config, required this.text});
  final GastroThemeConfig config;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: GS.s12, vertical: GS.s16),
      child: Text(
        text,
        style: GoogleFonts.caveat(
          fontSize: 16,
          color: config.onSurfaceVariant,
        ),
      ),
    );
  }
}
