import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/ai/data/ai_models.dart';
import 'package:mobile/features/couples/couple_wrapped_screen.dart';
import 'package:mobile/features/couples/data/couple_models.dart';
import 'package:mobile/features/couples/data/couple_providers.dart';
import 'package:mobile/features/notifications/data/notifications_providers.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';

/// "My Couple" screen — the single place users manage their partner link.
///
///  • If unlinked → big "Invite a partner" CTA + recent-followers shortcut.
///  • If incoming pending invite → Accept / Decline pair.
///  • If outgoing pending invite → "Waiting for {name}" + Cancel.
///  • If accepted → partner card (avatar, name, since-date) + Unlink button.
///
/// All state changes call the relevant ApiClient method then invalidate
/// `myCoupleProvider` so the card refreshes in place.
class MyCoupleScreen extends ConsumerStatefulWidget {
  const MyCoupleScreen({super.key});

  @override
  ConsumerState<MyCoupleScreen> createState() => _MyCoupleScreenState();
}

class _MyCoupleScreenState extends ConsumerState<MyCoupleScreen> {
  bool _busy = false;

  Future<void> _withSpinner(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(myCoupleProvider);
      ref.invalidate(coupleStatsProvider);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (mounted) {
        final config = ref.read(gastroThemeConfigProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage(e)),
            backgroundColor: config.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Map common backend codes to a short, scrapbook-toned line.
  String _errorMessage(Object e) {
    final s = e.toString();
    if (s.contains('409')) return 'One of you is already in another couple.';
    if (s.contains('404')) return 'Nothing to do here.';
    if (s.contains('403')) return 'Only the invitee can accept.';
    return 'Something went sideways. Try again in a moment.';
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final coupleAsync = ref.watch(myCoupleProvider);

    return Scaffold(
      backgroundColor: config.background,
      appBar: AppBar(
        backgroundColor: config.background,
        elevation: 0,
        title: Text(
          'My Couple',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: config.onSurface,
          ),
        ),
        iconTheme: IconThemeData(color: config.onSurface),
      ),
      body: coupleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBlock(message: _errorMessage(err), config: config),
        data: (couple) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(GS.s24, GS.s8, GS.s24, GS.s32),
            child: _content(couple, config),
          ),
        ),
      ),
    );
  }

  Widget _content(Couple? couple, GastroThemeConfig config) {
    if (couple == null) {
      return _UnlinkedView(
        config: config,
        busy: _busy,
        onInvite: () => _openInviteSheet(config),
      );
    }
    if (couple.status == CoupleStatus.accepted) {
      return _AcceptedView(
        config: config,
        couple: couple,
        busy: _busy,
        onUnlink: () => _withSpinner(
          () => ref.read(apiClientProvider).unlinkCouple(),
        ),
      );
    }
    if (couple.isIncomingPendingForViewer) {
      return _IncomingInviteView(
        config: config,
        couple: couple,
        busy: _busy,
        onAccept: () => _withSpinner(
          () => ref.read(apiClientProvider).acceptCouple(),
        ),
        onDecline: () => _withSpinner(
          () => ref.read(apiClientProvider).declineCouple(),
        ),
      );
    }
    // Outgoing pending.
    return _OutgoingInviteView(
      config: config,
      couple: couple,
      busy: _busy,
      onCancel: () => _withSpinner(
        () => ref.read(apiClientProvider).unlinkCouple(),
      ),
    );
  }

  Future<void> _openInviteSheet(GastroThemeConfig config) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvitePickerSheet(config: config),
    );
    if (picked == null) return;
    await _withSpinner(
      () => ref.read(apiClientProvider).invitePartner(picked),
    );
  }
}

// ─── Unlinked: prompt to invite ───────────────────────────────────────────────

class _UnlinkedView extends StatelessWidget {
  const _UnlinkedView({
    required this.config,
    required this.busy,
    required this.onInvite,
  });

  final GastroThemeConfig config;
  final bool busy;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: GS.s16),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: config.accentSoft,
              border: Border.all(color: config.accent.withOpacity(0.4), width: 2),
            ),
            child: Icon(LucideIcons.heart, size: 40, color: config.accent),
          ),
        ),
        const SizedBox(height: GS.s20),
        Text(
          'Eat together. Stamp together.',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: config.onSurface,
            height: 1.15,
          ),
        ),
        const SizedBox(height: GS.s8),
        Text(
          'Invite the person you taste the world with. Shared visits get their own '
          'badge in your journal, your dashboard learns to count for two, and the '
          'weekly Couples Journey unlocks a synced itinerary you can plan together.',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            height: 1.55,
            color: config.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: GS.s28),
        FilledButton.icon(
          onPressed: busy ? null : onInvite,
          icon: const Icon(LucideIcons.userPlus, size: 18),
          label: const Text('Invite a partner'),
          style: FilledButton.styleFrom(
            backgroundColor: config.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: GS.s16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GS.r16),
            ),
            textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: GS.s12),
        Text(
          'They need a GastroVoyage account first. Send them the Share Profile link '
          'from Account → Share Profile so they can sign up.',
          textAlign: TextAlign.center,
          style: GoogleFonts.caveat(
            fontSize: 16,
            color: config.onSurfaceVariant.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}

// ─── Incoming pending: accept / decline ───────────────────────────────────────

class _IncomingInviteView extends StatelessWidget {
  const _IncomingInviteView({
    required this.config,
    required this.couple,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final GastroThemeConfig config;
  final Couple couple;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: GS.s24),
        Center(
          child: SocialAvatar(
            config: config,
            initial: couple.partner.initial,
            avatarUrl: couple.partner.avatarUrl,
            size: 96,
            borderColor: config.accent,
            borderWidth: 3,
          ),
        ),
        const SizedBox(height: GS.s20),
        Text(
          '${couple.partner.name}\nwants to be your couple.',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: config.onSurface,
            height: 1.25,
          ),
        ),
        const SizedBox(height: GS.s10),
        Text(
          'Accepting links your accounts as partners. You can unlink at any time '
          'from this screen.',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: config.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: GS.s28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onDecline,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: GS.s12),
                  side: BorderSide(color: config.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GS.r16),
                  ),
                ),
                child: Text(
                  'Decline',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: config.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: GS.s12),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onAccept,
                icon: const Icon(LucideIcons.heart, size: 16),
                label: const Text('Accept'),
                style: FilledButton.styleFrom(
                  backgroundColor: config.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: GS.s12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GS.r16),
                  ),
                  textStyle: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Outgoing pending: awaiting their answer ──────────────────────────────────

class _OutgoingInviteView extends StatelessWidget {
  const _OutgoingInviteView({
    required this.config,
    required this.couple,
    required this.busy,
    required this.onCancel,
  });

  final GastroThemeConfig config;
  final Couple couple;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: GS.s24),
        Center(
          child: SocialAvatar(
            config: config,
            initial: couple.partner.initial,
            avatarUrl: couple.partner.avatarUrl,
            size: 96,
            borderColor: config.onSurfaceVariant.withOpacity(0.4),
            borderWidth: 2,
          ),
        ),
        const SizedBox(height: GS.s16),
        Text(
          'Waiting on ${couple.partner.name}…',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: config.onSurface,
          ),
        ),
        const SizedBox(height: GS.s8),
        Text(
          'They\'ll see your invite in their notifications. As soon as they accept, '
          'your dashboards link up.',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: config.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: GS.s28),
        OutlinedButton(
          onPressed: busy ? null : onCancel,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: GS.s12),
            side: BorderSide(color: config.error.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GS.r16),
            ),
          ),
          child: Text(
            'Cancel invite',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: config.error,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Accepted: live couple card + unlink ──────────────────────────────────────

class _AcceptedView extends ConsumerWidget {
  const _AcceptedView({
    required this.config,
    required this.couple,
    required this.busy,
    required this.onUnlink,
  });

  final GastroThemeConfig config;
  final Couple couple;
  final bool busy;
  final VoidCallback onUnlink;

  /// Annual stretch goal — try N distinct cuisines together this calendar
  /// year. Lives only on the client; we don't persist it server-side.
  static const int _annualCuisineGoal = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(coupleStatsProvider);
    final since = couple.acceptedAt ?? couple.createdAt;
    final sinceLabel = _formatSince(since);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: GS.s16),
        Container(
          padding: const EdgeInsets.all(GS.s20),
          decoration: BoxDecoration(
            color: config.accentSoft,
            borderRadius: BorderRadius.circular(GS.r24),
            border: Border.all(color: config.accent.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              SocialAvatar(
                config: config,
                initial: couple.partner.initial,
                avatarUrl: couple.partner.avatarUrl,
                size: 88,
                borderColor: config.accent,
                borderWidth: 3,
              ),
              const SizedBox(height: GS.s12),
              Text(
                'You & ${couple.partner.name}',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                ),
              ),
              const SizedBox(height: GS.s4),
              Text(
                sinceLabel != null ? 'Together on GastroVoyage $sinceLabel' : 'Together on GastroVoyage',
                textAlign: TextAlign.center,
                style: GoogleFonts.caveat(
                  fontSize: 17,
                  color: config.onSurfaceVariant,
                ),
              ),
              // "X days strong" pill — appears as soon as stats resolve.
              stats.maybeWhen(
                data: (s) => s.daysTogether > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: GS.s10),
                        child: _DaysTogetherPill(
                            days: s.daysTogether, config: config),
                      )
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: GS.s20),
              stats.when(
                loading: () => const SizedBox(
                    height: 56, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(height: 56),
                data: (s) => Row(
                  children: [
                    Expanded(child: _StatTile(
                      label: 'joint bites',
                      value: '${s.jointVisits}',
                      config: config,
                    )),
                    const SizedBox(width: GS.s10),
                    Expanded(child: _StatTile(
                      label: 'countries',
                      value: '${s.jointCountries}',
                      config: config,
                    )),
                    const SizedBox(width: GS.s10),
                    Expanded(child: _StatTile(
                      label: 'cuisines',
                      value: '${s.jointCuisines}',
                      config: config,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── First plate memory (only when there's a logged joint visit) ──────
        stats.maybeWhen(
          data: (s) => (s.firstVisit != null)
              ? Padding(
                  padding: const EdgeInsets.only(top: GS.s16),
                  child: _FirstPlateCard(
                      firstVisit: s.firstVisit!, config: config),
                )
              : const SizedBox.shrink(),
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Date Night picker — surfaces a country to chase next ─────────────
        const SizedBox(height: GS.s16),
        _DateNightCard(config: config),

        // ── Annual goal — % progress toward 12 cuisines this year ────────────
        stats.maybeWhen(
          data: (s) => Padding(
            padding: const EdgeInsets.only(top: GS.s16),
            child: _AnnualGoalCard(
              jointCuisines: s.jointCuisines,
              goal: _annualCuisineGoal,
              config: config,
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Couple Wrapped CTA — full-card link to the AI-generated recap ────
        const SizedBox(height: GS.s16),
        _CoupleWrappedCta(config: config),

        const SizedBox(height: GS.s24),
        Text(
          'WHAT BEING A COUPLE UNLOCKS',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.4,
            color: config.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: GS.s12),
        _Perk(
          icon: LucideIcons.heart,
          title: 'Tag your partner in any visit',
          body: 'When you log a bite together, hit the "We were together" toggle. '
              'It shows up in both your journals with a heart and counts toward '
              'your joint stats.',
          config: config,
        ),
        const SizedBox(height: GS.s10),
        _Perk(
          icon: LucideIcons.calendar,
          title: 'Synced 8-week Couples Journey',
          body: 'The weekly curated itinerary now ticks for both of you. Plan '
              'Spanish night, Greek night, Italian night — together.',
          config: config,
        ),
        const SizedBox(height: GS.s10),
        _Perk(
          icon: LucideIcons.layoutDashboard,
          title: '"We Together" card on the dashboard',
          body: 'A live count of how many plates, countries, and cuisines you\'ve '
              'tasted side-by-side sits right at the top of Home.',
          config: config,
        ),
        const SizedBox(height: GS.s32),
        OutlinedButton(
          onPressed: busy ? null : () => _confirmUnlink(context, onUnlink),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: GS.s12),
            side: BorderSide(color: config.error.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GS.r16),
            ),
          ),
          child: Text(
            'Unlink couple',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: config.error,
            ),
          ),
        ),
      ],
    );
  }

  static String? _formatSince(String? raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw).toLocal();
      // "since May 2026" reads naturally regardless of locale.
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return 'since ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmUnlink(BuildContext context, VoidCallback onUnlink) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.surface,
        title: Text('Unlink couple?',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text(
          'Your existing visits stay in your journal, but joint stats reset to '
          'zero. ${couple.partner.name} will be notified.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep linked',
                style: TextStyle(color: config.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: config.error),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (ok == true) onUnlink();
  }
}

// ─── Small reusable bits ──────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.config,
  });

  final String label;
  final String value;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: GS.s10),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r12),
        border: Border.all(color: config.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: config.accent,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              letterSpacing: 1.2,
              color: config.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({
    required this.icon,
    required this.title,
    required this.body,
    required this.config,
  });

  final IconData icon;
  final String title;
  final String body;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GS.s12),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r16),
        border: Border.all(color: config.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: config.accentSoft,
              borderRadius: BorderRadius.circular(GS.r8),
            ),
            child: Icon(icon, size: 18, color: config.accent),
          ),
          const SizedBox(width: GS.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: config.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    height: 1.45,
                    color: config.onSurfaceVariant,
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

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.config});
  final String message;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GS.s24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: config.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Invite picker — search bar over /social/users/search ─────────────────────

class _InvitePickerSheet extends ConsumerStatefulWidget {
  const _InvitePickerSheet({required this.config});
  final GastroThemeConfig config;

  @override
  ConsumerState<_InvitePickerSheet> createState() => _InvitePickerSheetState();
}

class _InvitePickerSheetState extends ConsumerState<_InvitePickerSheet> {
  final _queryCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    // Push the typed term into the shared StateProvider — userSearchProvider
    // reads from there. We do it in build (not onChanged) so the AsyncValue
    // stays in sync with the controller without setState races.
    if (ref.read(userSearchQueryProvider) != _query.trim()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(userSearchQueryProvider.notifier).state = _query.trim();
      });
    }
    final results = _query.trim().length >= 2
        ? ref.watch(userSearchProvider)
        : const AsyncValue<List<SocialUser>>.data([]);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.all(GS.s12),
        decoration: BoxDecoration(
          color: config.surface,
          borderRadius: BorderRadius.circular(GS.r24),
          border: Border.all(color: config.outlineVariant),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(GS.s24, GS.s20, GS.s24, GS.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Invite a partner',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: config.onSurface,
                ),
              ),
              const SizedBox(height: GS.s4),
              Text(
                'Search by display name. They\'ll get a notification — they need '
                'to accept on their end before the link is live.',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  color: config.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: GS.s16),
              TextField(
                controller: _queryCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Type a name…',
                  prefixIcon: Icon(LucideIcons.search,
                      size: 18, color: config.onSurfaceVariant),
                  filled: true,
                  fillColor: config.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(GS.r12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: GS.s16),
              SizedBox(
                height: 240,
                child: results.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Text('Search failed. Try again.',
                        style: GoogleFonts.hankenGrotesk(
                            fontSize: 13, color: config.onSurfaceVariant)),
                  ),
                  data: (users) {
                    if (_query.trim().length < 2) {
                      return Center(
                        child: Text(
                          'Type at least two letters.',
                          style: GoogleFonts.caveat(
                            fontSize: 17,
                            color: config.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      );
                    }
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'Nobody by that name on GastroVoyage yet.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            color: config.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: GS.s8),
                      itemBuilder: (_, i) {
                        final u = users[i];
                        return Material(
                          color: config.surfaceVariant,
                          borderRadius: BorderRadius.circular(GS.r12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(GS.r12),
                            onTap: () => Navigator.of(context).pop(u.userId),
                            child: Padding(
                              padding: const EdgeInsets.all(GS.s10),
                              child: Row(
                                children: [
                                  SocialAvatar(
                                    config: config,
                                    initial: u.initial,
                                    avatarUrl: u.avatarUrl,
                                    size: 40,
                                  ),
                                  const SizedBox(width: GS.s12),
                                  Expanded(
                                    child: Text(
                                      u.name,
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: config.onSurface,
                                      ),
                                    ),
                                  ),
                                  Icon(LucideIcons.userPlus,
                                      size: 18, color: config.accent),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Days together pill — small badge under the partner card ─────────────────

class _DaysTogetherPill extends StatelessWidget {
  const _DaysTogetherPill({required this.days, required this.config});

  final int days;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final label = days == 1 ? '1 day strong' : '$days days strong';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GS.s10, vertical: GS.s4),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r12),
        border: Border.all(color: config.accent.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.heart, size: 12, color: config.accent),
          const SizedBox(width: GS.s6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: config.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── First Plate memory — pinned card of the couple's oldest joint visit ────

class _FirstPlateCard extends StatelessWidget {
  const _FirstPlateCard({
    required this.firstVisit,
    required this.config,
  });

  final CoupleFirstVisit firstVisit;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final restaurant = firstVisit.restaurantName?.trim();
    final country = firstVisit.countryName?.trim();
    final flag = firstVisit.flagEmoji?.trim();
    final dateLabel = _formatPlateDate(firstVisit.createdAt);

    // Title prefers the country (the cuisine signal); restaurant becomes the
    // subtitle. When a country is missing we fall back to the restaurant; when
    // both are missing we just say "A bite together".
    final title = (country != null && country.isNotEmpty)
        ? country
        : ((restaurant != null && restaurant.isNotEmpty)
            ? restaurant
            : 'A bite together');
    final subtitle = (country != null &&
            country.isNotEmpty &&
            restaurant != null &&
            restaurant.isNotEmpty)
        ? restaurant
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s16, GS.s14, GS.s16, GS.s16),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(color: config.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.bookmark, size: 14, color: config.accent),
              const SizedBox(width: GS.s6),
              Text(
                'OUR FIRST PLATE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: config.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: GS.s8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (flag != null && flag.isNotEmpty) ...[
                Text(flag, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: GS.s10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'at $subtitle',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (dateLabel != null) ...[
                      const SizedBox(height: GS.s6),
                      Text(
                        dateLabel,
                        style: GoogleFonts.caveat(
                          fontSize: 17,
                          color: config.accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _formatPlateDate(String? raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return 'where it all began · ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return null;
    }
  }
}

// ─── Date Night picker — random next country to chase together ──────────────

class _DateNightCard extends ConsumerStatefulWidget {
  const _DateNightCard({required this.config});
  final GastroThemeConfig config;

  @override
  ConsumerState<_DateNightCard> createState() => _DateNightCardState();
}

class _DateNightCardState extends ConsumerState<_DateNightCard> {
  AiDateNight? _pick;
  bool _busy = false;
  String? _error;

  Future<void> _surprise() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pick = await ref.read(apiClientProvider).aiDateNight();
      setState(() => _pick = pick);
    } catch (e) {
      setState(() {
        final s = e.toString();
        if (s.contains('409')) {
          _error = 'Link a partner first to unlock Date Night.';
        } else if (s.contains('404')) {
          _error = "You've tasted everything together — bold move.";
        } else if (s.contains('503')) {
          _error = 'AI is not configured on this server yet.';
        } else {
          _error = 'Could not cook up a suggestion. Try again.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s16, GS.s14, GS.s16, GS.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            config.accent.withOpacity(0.10),
            config.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(color: config.accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.zap, size: 14, color: config.accent),
              const SizedBox(width: GS.s6),
              Text(
                'DATE NIGHT · AI',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: config.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: GS.s8),
          if (_pick == null && _error == null)
            Text(
              "Can't decide what to cook? Let Claude pick a country and a "
              "specific dish for tonight, with a 5-step prep outline — pulled "
              "from your shared wishlists.",
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                height: 1.45,
                color: config.onSurfaceVariant,
              ),
            )
          else if (_pick != null)
            _AiPickPreview(pick: _pick!, config: config)
          else
            Text(
              _error!,
              style: GoogleFonts.caveat(
                fontSize: 17,
                color: config.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: GS.s12),
          FilledButton.icon(
            onPressed: _busy ? null : _surprise,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(LucideIcons.sparkles, size: 16),
            label: Text(
              _busy
                  ? 'Cooking up an idea…'
                  : _pick == null
                      ? 'Surprise us'
                      : 'Try another',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: config.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: GS.s12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GS.r12),
              ),
              textStyle: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a full AI Date Night card: flag + dish title + headline tagline,
/// "why tonight" reason in scrapbook prose, then a numbered prep checklist.
class _AiPickPreview extends StatelessWidget {
  const _AiPickPreview({required this.pick, required this.config});
  final AiDateNight pick;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final flag = pick.flagEmoji?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (flag != null && flag.isNotEmpty) ...[
              Text(flag, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: GS.s10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pick.dishName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pick.countryName}${pick.cuisine != null && pick.cuisine!.isNotEmpty ? ' · ${pick.cuisine}' : ''}',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: config.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (pick.headline.isNotEmpty) ...[
          const SizedBox(height: GS.s10),
          Text(
            pick.headline,
            style: GoogleFonts.caveat(
              fontSize: 18,
              color: config.accent,
              height: 1.25,
            ),
          ),
        ],
        if (pick.whyTonight.isNotEmpty) ...[
          const SizedBox(height: GS.s8),
          Text(
            pick.whyTonight,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              height: 1.5,
              color: config.onSurfaceVariant,
            ),
          ),
        ],
        if (pick.prepSteps.isNotEmpty) ...[
          const SizedBox(height: GS.s12),
          Text(
            'PREP IN 5 BEATS',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: config.accent,
            ),
          ),
          const SizedBox(height: GS.s6),
          for (int i = 0; i < pick.prepSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: GS.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}.',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: config.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      pick.prepSteps[i],
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        height: 1.4,
                        color: config.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}


// ─── Annual goal — N cuisines this year together ────────────────────────────

class _AnnualGoalCard extends StatelessWidget {
  const _AnnualGoalCard({
    required this.jointCuisines,
    required this.goal,
    required this.config,
  });

  final int jointCuisines;
  final int goal;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    final progress = (goal == 0) ? 0.0 : (jointCuisines / goal).clamp(0.0, 1.0);
    final done = jointCuisines >= goal;
    final year = DateTime.now().year;

    return Container(
      padding: const EdgeInsets.fromLTRB(GS.s16, GS.s14, GS.s16, GS.s16),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r20),
        border: Border.all(color: config.outlineVariant.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.flag, size: 14, color: config.accent),
              const SizedBox(width: GS.s6),
              Text(
                'COUPLE GOAL · $year',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: config.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: GS.s8),
          Text(
            done
                ? '$goal cuisines together — done. Set a wilder bar next year.'
                : 'Try $goal distinct cuisines together this year.',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: GS.s10),
          ClipRRect(
            borderRadius: BorderRadius.circular(GS.r8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: config.accent.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(config.accent),
            ),
          ),
          const SizedBox(height: GS.s6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$jointCuisines / $goal cuisines',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: config.onSurfaceVariant,
                ),
              ),
              Text(
                done ? '🎉 goal hit' : '${(progress * 100).round()}%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: config.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Couple Wrapped CTA — full-card link to the AI-generated recap ──────────

class _CoupleWrappedCta extends StatelessWidget {
  const _CoupleWrappedCta({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GS.r20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const CoupleWrappedScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(GS.s16, GS.s14, GS.s16, GS.s16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GS.r20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                config.accent.withOpacity(0.25),
                config.accent.withOpacity(0.08),
              ],
            ),
            border: Border.all(color: config.accent.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: config.surface,
                  borderRadius: BorderRadius.circular(GS.r12),
                  border: Border.all(color: config.accent.withOpacity(0.5)),
                ),
                child: Icon(LucideIcons.sparkles, color: config.accent),
              ),
              const SizedBox(width: GS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COUPLE WRAPPED · AI',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: config.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unwrap your journey',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: config.onSurface,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A 4-scene story Claude writes from your joint visits.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: config.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: config.onSurfaceVariant.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
