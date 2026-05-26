import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
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
