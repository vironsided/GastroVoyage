import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/account/account_settings_screen.dart';
import 'package:mobile/features/badges/achievements_screen.dart';
import 'package:mobile/features/couples/my_couple_screen.dart';
import 'package:mobile/features/social/friends_screen.dart';
import 'package:mobile/features/social/stories_feed.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';

/// The "You" tab — a first-class home for identity plus the social / couple
/// features that used to be buried inside the 2,500-line Settings megascreen.
/// Settings itself is now reachable only via the gear here, slimmed to true
/// preferences.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(gastroThemeConfigProvider);
    final auth = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;

    final name = (auth.displayName?.trim().isNotEmpty == true)
        ? auth.displayName!.trim()
        : (profile?.displayName ?? 'Explorer');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    return Scaffold(
      backgroundColor: config.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding:
              const EdgeInsets.fromLTRB(GS.s20, GS.s12, GS.s20, GS.navBuffer),
          children: [
            // ── Title + settings gear ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'You',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AccountSettingsScreen()),
                  ),
                  icon: Icon(Icons.settings_outlined,
                      color: config.onSurfaceVariant),
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: GS.s8),

            // ── Identity ────────────────────────────────────────────────────
            Row(
              children: [
                SocialAvatar(
                  config: config,
                  initial: initial,
                  avatarUrl: profile?.avatarUrl,
                  size: 72,
                ),
                const SizedBox(width: GS.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: config.onSurface,
                        ),
                      ),
                      if (profile?.homeCity != null &&
                          profile!.homeCity!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: config.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              profile.homeCity!,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13,
                                color: config.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: GS.s16),

            // ── Stat strip ──────────────────────────────────────────────────
            if (profile != null)
              Row(
                children: [
                  _Stat(
                    config: config,
                    value: '${profile.visitedCount}',
                    label: 'Countries',
                  ),
                  const SizedBox(width: GS.s12),
                  _Stat(
                    config: config,
                    value: '${profile.badges.length}',
                    label: 'Stamps',
                  ),
                ],
              ),
            const SizedBox(height: GS.s24),

            // ── Navigation tiles (the de-buried features) ───────────────────
            _ProfileTile(
              config: config,
              icon: Icons.favorite_border,
              label: 'My Couple',
              subtitle: 'Your shared culinary journey',
              onTap: () => _push(context, const MyCoupleScreen()),
            ),
            _ProfileTile(
              config: config,
              icon: Icons.people_outline,
              label: 'Friends & Followers',
              subtitle: 'Find and follow other explorers',
              onTap: () => _push(context, const FriendsScreen()),
            ),
            _ProfileTile(
              config: config,
              icon: Icons.auto_stories_outlined,
              label: 'Stories',
              subtitle: 'Moments from your network',
              onTap: () => _push(context, const StoriesFeedScreen()),
            ),
            _ProfileTile(
              config: config,
              icon: Icons.emoji_events_outlined,
              label: 'Achievements',
              subtitle: "Stamps and milestones you've earned",
              onTap: () => _push(context, const AchievementsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.config, required this.value, required this.label});

  final GastroThemeConfig config;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: GS.s16),
        decoration: BoxDecoration(
          color: config.surfaceVariant,
          borderRadius: BorderRadius.circular(GS.r16),
          border: Border.all(color: config.outlineVariant, width: 0.5),
        ),
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
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: config.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.config,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GS.s12),
      child: Material(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(GS.r16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GS.r16),
          child: Padding(
            padding: const EdgeInsets.all(GS.s16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: config.accentSoft,
                    borderRadius: BorderRadius.circular(GS.r12),
                  ),
                  child: Icon(icon, size: 20, color: config.accent),
                ),
                const SizedBox(width: GS.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: config.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.5,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: config.onSurfaceVariant.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
