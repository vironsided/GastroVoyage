import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/couples/data/couples_itinerary.dart';
import 'package:mobile/features/couples/widgets/journey_route.dart';
import 'package:mobile/features/couples/widgets/week_card.dart';
import 'package:mobile/ui/ui.dart';

/// The "Weekly Couples' Culinary Journey" — a gamified, chronological roadmap.
///
/// A vintage travel-itinerary: a hand-drawn dotted route runs down the left
/// rail connecting eight week "stops". Completed weeks are ink-stamped, the
/// current week is highlighted and actionable, future weeks stay wax-sealed.
/// Completing the last week reveals a celebratory finale.
class CouplesJourneyScreen extends ConsumerStatefulWidget {
  const CouplesJourneyScreen({super.key});

  @override
  ConsumerState<CouplesJourneyScreen> createState() =>
      _CouplesJourneyScreenState();
}

class _CouplesJourneyScreenState extends ConsumerState<CouplesJourneyScreen> {
  /// True while a "mark complete" request is in flight.
  bool _completing = false;

  Future<void> _completeWeek(int currentCompleted) async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await ref
          .read(apiClientProvider)
          .setCouplesProgress(currentCompleted + 1);
      if (!mounted) return;
      ref.invalidate(couplesProgressProvider);
      final justFinished = currentCompleted + 1 >= kCouplesJourneyLength;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              justFinished
                  ? 'Journey complete — every week tasted together.'
                  : 'Week stamped. The next stop is unlocked.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save progress. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final progressAsync = ref.watch(couplesProgressProvider);

    return Scaffold(
      backgroundColor: config.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: config.onSurface,
        title: Text(
          'Journey for Two',
          style: GoogleFonts.playfairDisplay(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: config.onSurface,
          ),
        ),
      ),
      body: PaperBackdrop(
        baseColor: config.background,
        grainOpacity: config.isDark ? 0.04 : 0.07,
        scratchCount: 7,
        child: progressAsync.when(
          loading: () => _LoadingBody(config: config),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(GS.s20),
            child: GastroErrorCard(
              config: config,
              message: "Couldn't load your journey. Check your connection and try again.",
              onRetry: () => ref.invalidate(couplesProgressProvider),
            ),
          ),
          data: (raw) {
            // Defensively clamp the persisted count into a valid range.
            final completed = raw.clamp(0, kCouplesJourneyLength);
            return RefreshIndicator(
              color: config.accent,
              backgroundColor: config.surface,
              onRefresh: () async =>
                  ref.invalidate(couplesProgressProvider),
              child: _JourneyBody(
                config: config,
                completedWeeks: completed,
                completing: _completing,
                onComplete: () => _completeWeek(completed),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Loading ────────────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s8, GS.s20, GS.navBuffer),
      children: [
        GastroShimmer(height: 96, config: config),
        const SizedBox(height: GS.s20),
        GastroShimmer(height: 320, config: config),
        const SizedBox(height: GS.s16),
        GastroShimmer(height: 88, config: config, radius: GS.r20),
        const SizedBox(height: GS.s16),
        GastroShimmer(height: 88, config: config, radius: GS.r20),
      ],
    );
  }
}

// ── Journey body ───────────────────────────────────────────────────────────────

class _JourneyBody extends StatelessWidget {
  const _JourneyBody({
    required this.config,
    required this.completedWeeks,
    required this.completing,
    required this.onComplete,
  });

  final GastroThemeConfig config;
  final int completedWeeks;
  final bool completing;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final total = kCouplesJourneyLength;
    final finished = completedWeeks >= total;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s4, GS.s20, GS.navBuffer),
      children: [
        _JourneyHeader(
          config: config,
          completedWeeks: completedWeeks,
          total: total,
        ),
        const SizedBox(height: GS.s20),

        // The week timeline — each row is a stop on the route rail.
        for (var i = 0; i < kCouplesJourney.length; i++)
          _TimelineRow(
            week: kCouplesJourney[i],
            config: config,
            state: _stateFor(i, completedWeeks),
            isFirst: i == 0,
            isLast: i == kCouplesJourney.length - 1,
            completing: completing,
            onComplete: onComplete,
          ),

        if (finished) ...[
          const SizedBox(height: GS.s8),
          _FinaleCard(config: config),
        ],
      ],
    );
  }

  WeekState _stateFor(int index, int completed) {
    if (index < completed) return WeekState.completed;
    if (index == completed) return WeekState.current;
    return WeekState.locked;
  }
}

/// One row of the timeline: the route rail (stop marker + connecting dots) on
/// the left, the week card on the right.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.week,
    required this.config,
    required this.state,
    required this.isFirst,
    required this.isLast,
    required this.completing,
    required this.onComplete,
  });

  final ItineraryWeek week;
  final GastroThemeConfig config;
  final WeekState state;
  final bool isFirst;
  final bool isLast;
  final bool completing;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final completed = state == WeekState.completed;
    final current = state == WeekState.current;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Route rail ──────────────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                const SizedBox(height: GS.s12),
                JourneyStopMarker(
                  config: config,
                  completed: completed,
                  current: current,
                  size: current ? 22 : 18,
                ),
                if (!isLast)
                  Expanded(
                    child: JourneyRouteSegment(
                      config: config,
                      // The segment to the next stop is "travelled" only
                      // when this week is already behind the couple.
                      completed: completed,
                      width: 36,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: GS.s8),

          // ── Week card ───────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : GS.s16,
              ),
              child: WeekCard(
                week: week,
                state: state,
                config: config,
                restaurant: restaurantForWeek(week),
                onComplete: current ? onComplete : null,
                isCompleting: current && completing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header — overall progress ──────────────────────────────────────────────────

class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({
    required this.config,
    required this.completedWeeks,
    required this.total,
  });

  final GastroThemeConfig config;
  final int completedWeeks;
  final int total;

  @override
  Widget build(BuildContext context) {
    final finished = completedWeeks >= total;
    final currentWeek = finished ? total : completedWeeks + 1;
    final progress = total > 0 ? completedWeeks / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(GS.s20),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.outlineVariant, width: 0.6),
        boxShadow: GS.shadow(
          color: config.accent,
          blur: 24,
          yOffset: 10,
          opacity: config.isDark ? 0.16 : 0.10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.compass, size: 12, color: config.accent),
              const SizedBox(width: GS.s6),
              Text(
                'A CULINARY ITINERARY FOR TWO',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                  color: config.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: GS.s10),
          Text(
            finished
                ? 'Journey complete'
                : 'Week $currentWeek of $total',
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: GS.s4),
          Text(
            finished
                ? 'Eight cuisines, eight evenings, tasted side by side.'
                : 'One cuisine a week — complete a stop to unlock the next.',
            style: GoogleFonts.caveat(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: config.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: GS.s16),

          // Stamp row — one mark per completed week.
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: GS.s6),
                Expanded(
                  child: _WeekPip(
                    config: config,
                    filled: i < completedWeeks,
                    current: i == completedWeeks && !finished,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: GS.s10),

          // Progress bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(GS.rPill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: GS.xslow,
              curve: GS.smooth,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                backgroundColor: config.outlineVariant,
                valueColor: AlwaysStoppedAnimation(config.accent),
                minHeight: 5,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: GS.normal, curve: GS.smooth)
        .slideY(begin: -0.04, end: 0, duration: GS.normal, curve: GS.smooth);
  }
}

/// One small progress pip in the header — a completed week, the current week,
/// or a week still ahead.
class _WeekPip extends StatelessWidget {
  const _WeekPip({
    required this.config,
    required this.filled,
    required this.current,
  });

  final GastroThemeConfig config;
  final bool filled;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: filled
            ? config.accent
            : current
                ? config.accent.withOpacity(0.35)
                : config.outlineVariant,
        borderRadius: BorderRadius.circular(GS.rPill),
      ),
    );
  }
}

// ── Finale ─────────────────────────────────────────────────────────────────────

class _FinaleCard extends StatelessWidget {
  const _FinaleCard({required this.config});
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GS.s20, vertical: GS.s28),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(GS.r24),
        border: Border.all(color: config.accent.withOpacity(0.5), width: 1.2),
        boxShadow: GS.shadow(
          color: config.accent,
          blur: 26,
          yOffset: 12,
          opacity: config.isDark ? 0.20 : 0.14,
        ),
      ),
      child: Column(
        children: [
          StampBadge(
            label: 'JOURNEY\nCOMPLETE',
            config: config,
            size: 108,
            shape: StampShape.circle,
            icon: LucideIcons.award,
            color: config.gold,
            seed: 99,
            rotation: -0.1,
          )
              .animate()
              .fadeIn(duration: GS.slow)
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: GS.slow,
                curve: GS.spring,
              ),
          const SizedBox(height: GS.s16),
          Text(
            'Bon Voyage, Together',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: config.onSurface,
            ),
          ),
          const SizedBox(height: GS.s8),
          Text(
            'You tasted your way across eight cuisines — '
            'from playful Spanish tapas to a candle-lit French finale. '
            'Every stamp is a night you shared.',
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              height: 1.5,
              color: config.onSurfaceVariant,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: GS.slow, curve: GS.smooth)
        .slideY(begin: 0.06, end: 0, duration: GS.slow, curve: GS.smooth);
  }
}
