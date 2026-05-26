import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/badges/achievements_screen.dart';
import 'package:mobile/features/couples/couples_journey_screen.dart';
import 'package:mobile/features/couples/my_couple_screen.dart';
import 'package:mobile/features/notifications/data/notification_model.dart';
import 'package:mobile/features/notifications/data/notifications_providers.dart';
import 'package:mobile/features/social/public_passport_screen.dart';
import 'package:mobile/features/social/widgets/relative_time.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';
import 'package:mobile/ui/ui.dart';

/// Instagram-style notifications inbox — follow requests, follow accepts,
/// story views, journey milestones, badge unlocks.
///
/// On open the screen fire-and-forgets `markRead(all: true)` so the unread
/// badge clears immediately. The list still renders the new rows with their
/// unread styling for one beat — the user gets visual feedback that those
/// rows were the fresh ones, without leaving them stuck unread forever.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Snapshot of the unread count at first frame — used for the "{n} new"
  /// header subtitle. Captured before the read-all fires so the user sees how
  /// many were waiting for them when they arrived.
  int? _initialUnread;

  /// True once the screen has fired the read-all call (and we should stop
  /// re-firing on every rebuild).
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    // Schedule for after first frame so we have a build context for the
    // ProviderScope, and so we don't kick off a network call from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    if (!mounted || _markedRead) return;
    _markedRead = true;
    // Capture the unread count once so the header subtitle remains stable.
    final unreadAsync = ref.read(unreadCountProvider);
    _initialUnread = unreadAsync.valueOrNull;
    // Fire-and-forget: a failure here just means the badge will refresh
    // the next time the inbox is opened.
    try {
      await ref.read(apiClientProvider).markRead(all: true);
      if (!mounted) return;
      ref.invalidate(unreadCountProvider);
      // Don't invalidate the list itself — let the user see the rows they
      // just read with their pre-read styling for this session. The next
      // navigation back will pick up the fresh state.
    } catch (_) {
      // Silent: nothing the user can do here.
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.selectionClick();
    invalidateNotificationsFromWidget(ref);
    // Allow the providers to settle so the RefreshIndicator stays on-screen
    // long enough to read as a deliberate user action.
    await ref.read(notificationsProvider.future);
  }

  void _openNotification(AppNotification n) {
    HapticFeedback.selectionClick();
    switch (n.type) {
      case NotificationType.followRequest:
      case NotificationType.followAccepted:
      case NotificationType.storyView:
      case NotificationType.storyReaction:
      case NotificationType.storyComment:
        final actorId = n.actor?.userId ?? '';
        if (actorId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicPassportScreen(
              userId: actorId,
              previewName: n.actor?.name,
            ),
          ),
        );
        break;
      case NotificationType.journeyWeek:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CouplesJourneyScreen()),
        );
        break;
      case NotificationType.badgeEarned:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AchievementsScreen()),
        );
        break;
      case NotificationType.coupleInvite:
      case NotificationType.coupleAccepted:
      case NotificationType.coupleEnded:
        // All three route to the My Couple screen, which already renders the
        // right state (pending invite / accepted card / unlinked CTA).
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyCoupleScreen()),
        );
        break;
      case NotificationType.unknown:
        // Unknown type — no action. The row still renders so the user knows
        // something happened; a fresh client release will hook it up.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final notifsAsync = ref.watch(notificationsProvider);
    // Live count from the provider until we capture our snapshot.
    final liveUnread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final unreadForHeader = _initialUnread ?? liveUnread;

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
              _Header(
                config: config,
                unreadCount: unreadForHeader,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: config.accent,
                  backgroundColor: config.surface,
                  onRefresh: _refresh,
                  child: notifsAsync.when(
                    loading: () => _LoadingList(config: config),
                    error: (e, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          GS.s20, GS.s8, GS.s20, GS.s40),
                      children: [
                        GastroErrorCard(
                          config: config,
                          message:
                              'Could not load notifications. Is the backend running?',
                          onRetry: _refresh,
                        ),
                      ],
                    ),
                    data: (items) {
                      if (items.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                              GS.s20, GS.s12, GS.s20, GS.s40),
                          children: [
                            GastroEmptyState(
                              config: config,
                              icon: LucideIcons.bell,
                              title: 'Inbox empty',
                              subtitle:
                                  "Nothing to catch up on — log a bite!",
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            GS.s16, GS.s12, GS.s16, GS.s40),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: GS.s8),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          return _NotificationRow(
                            config: config,
                            notification: n,
                            onTap: () => _openNotification(n),
                          )
                              .animate()
                              .fadeIn(
                                  duration: GS.normal,
                                  delay: GS.stagger(i.clamp(0, 6),
                                      ms: 30),
                                  curve: GS.smooth)
                              .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  duration: GS.normal,
                                  delay: GS.stagger(i.clamp(0, 6),
                                      ms: 30),
                                  curve: GS.smooth);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.config,
    required this.unreadCount,
    required this.onBack,
  });

  final GastroThemeConfig config;
  final int unreadCount;
  final VoidCallback onBack;

  String get _subtitle {
    if (unreadCount <= 0) return 'All caught up';
    if (unreadCount == 1) return '1 new';
    return '$unreadCount new';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s12, GS.s8, GS.s20, GS.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            onPressed: onBack,
          ),
          const SizedBox(width: GS.s4),
          Expanded(
            child: SectionHeader(
              label: 'Notifications',
              subtitle: _subtitle,
              config: config,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading list ────────────────────────────────────────────────────────────

class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(GS.s16, GS.s12, GS.s16, GS.s40),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: GS.s8),
      itemBuilder: (_, __) =>
          GastroShimmer(config: config, height: 76, radius: GS.r20),
    );
  }
}

// ─── Row ─────────────────────────────────────────────────────────────────────

class _NotificationRow extends StatefulWidget {
  const _NotificationRow({
    required this.config,
    required this.notification,
    required this.onTap,
  });

  final GastroThemeConfig config;
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow> {
  bool _pressed = false;

  String get _title {
    final n = widget.notification;
    final actorName = n.actor?.name ?? 'Someone';
    switch (n.type) {
      case NotificationType.followRequest:
        return '$actorName requested to follow you';
      case NotificationType.followAccepted:
        return '$actorName accepted your follow';
      case NotificationType.storyView:
        return '$actorName viewed your story';
      case NotificationType.storyReaction:
        final emoji = (n.payload['emoji'] as String?)?.trim();
        if (emoji != null && emoji.isNotEmpty) {
          return '$actorName reacted $emoji to your story';
        }
        return '$actorName reacted to your story';
      case NotificationType.storyComment:
        return '$actorName commented on your story';
      case NotificationType.journeyWeek:
        final week = (n.payload['week_index'] as num?)?.toInt();
        if (week == null) return 'A new week unlocked';
        return 'Week $week unlocked';
      case NotificationType.badgeEarned:
        final title = (n.payload['badge_title'] as String?)?.trim();
        if (title != null && title.isNotEmpty) {
          return 'Badge earned: $title';
        }
        return 'A new badge is yours';
      case NotificationType.coupleInvite:
        return '$actorName wants to be your couple';
      case NotificationType.coupleAccepted:
        return '$actorName accepted your couple invite';
      case NotificationType.coupleEnded:
        return '$actorName unlinked your couple';
      case NotificationType.unknown:
        return 'Something happened';
    }
  }

  String get _scribble {
    final n = widget.notification;
    switch (n.type) {
      case NotificationType.followRequest:
        return 'tap to peek at their passport';
      case NotificationType.followAccepted:
        return "you're in — see what they're tasting";
      case NotificationType.storyView:
        return 'a quiet little visit';
      case NotificationType.storyReaction:
        return 'tap to see your stories';
      case NotificationType.storyComment:
        // Surface the comment text in the scrapbook sub-line. The backend
        // already trims to ~80 chars; we cap at 40 here to keep the inbox row
        // tidy and add an ellipsis when we had to clip.
        final raw = (n.payload['text'] as String?)?.trim() ?? '';
        if (raw.isEmpty) return 'tap to read the comment';
        if (raw.length <= 40) return '"$raw"';
        return '"${raw.substring(0, 40)}…"';
      case NotificationType.journeyWeek:
        return 'another stamp in the book';
      case NotificationType.badgeEarned:
        return 'pin it to your passport';
      case NotificationType.coupleInvite:
        return 'tap to accept or decline';
      case NotificationType.coupleAccepted:
        return 'you two are official';
      case NotificationType.coupleEnded:
        return 'your joint stats reset';
      case NotificationType.unknown:
        return 'tap for details';
    }
  }

  /// Stamp-style emblem used for non-actor notifications (journey / badge /
  /// unknown). Composed in a tinted circle for visual parity with [SocialAvatar].
  Widget _emblem() {
    final config = widget.config;
    IconData icon;
    switch (widget.notification.type) {
      case NotificationType.journeyWeek:
        icon = LucideIcons.mapPin;
        break;
      case NotificationType.badgeEarned:
        icon = LucideIcons.award;
        break;
      case NotificationType.followRequest:
      case NotificationType.followAccepted:
        icon = LucideIcons.userPlus;
        break;
      case NotificationType.storyView:
        icon = LucideIcons.eye;
        break;
      case NotificationType.storyReaction:
        icon = LucideIcons.heart;
        break;
      case NotificationType.storyComment:
        icon = LucideIcons.messageCircle;
        break;
      case NotificationType.coupleInvite:
      case NotificationType.coupleAccepted:
      case NotificationType.coupleEnded:
        icon = LucideIcons.heart;
        break;
      case NotificationType.unknown:
        icon = LucideIcons.bell;
        break;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: config.accentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: config.outlineVariant, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: config.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final n = widget.notification;
    final isUnread = !n.read;
    final actor = n.actor;
    final hasActor = actor != null && actor.userId.isNotEmpty;

    final bgColor = isUnread
        ? config.accentSoft.withOpacity(config.isDark ? 0.35 : 0.55)
        : config.surface;

    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (v) => setState(() => _pressed = v),
      borderRadius: BorderRadius.circular(GS.r20),
      splashColor: config.accentSoft,
      highlightColor: config.accentSoft.withOpacity(0.5),
      child: AnimatedContainer(
        duration: GS.micro,
        curve: GS.smooth,
        padding: const EdgeInsets.symmetric(
            horizontal: GS.s12, vertical: GS.s12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(GS.r20),
          border: Border.all(
            color: isUnread
                ? config.accent.withOpacity(0.45)
                : config.outlineVariant,
            width: isUnread ? 1.2 : 1,
          ),
          boxShadow: _pressed
              ? null
              : [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(config.isDark ? 0.18 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasActor)
              SocialAvatar(
                config: config,
                initial: actor.initial,
                avatarUrl: actor.avatarUrl,
                size: 44,
                borderColor: isUnread ? config.accent : config.outlineVariant,
              )
            else
              _emblem(),
            const SizedBox(width: GS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14.5,
                      fontWeight:
                          isUnread ? FontWeight.w700 : FontWeight.w600,
                      color: config.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _scribble,
                    style: GoogleFonts.caveat(
                      fontSize: 15,
                      color: config.onSurfaceVariant,
                      height: 1.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: GS.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  relativeTime(n.createdAt),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: config.onSurfaceVariant.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: GS.s6),
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: config.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: config.accent.withOpacity(0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 8, height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
