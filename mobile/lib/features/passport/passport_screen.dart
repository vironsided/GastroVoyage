import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gs_design.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/explore/country_dishes.dart';
import 'package:mobile/features/passport/export/passport_export_service.dart';
import 'package:mobile/features/passport/pages/identity_page.dart';
import 'package:mobile/features/passport/passport_dimensions.dart';
import 'package:mobile/features/passport/passport_spread_view.dart';
import 'package:mobile/features/shared/models.dart';
import 'package:mobile/features/social/data/social_providers.dart';
import 'package:mobile/features/social/widgets/share_to_feed_sheet.dart';
import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/ui/painters/scrapbook_painters.dart';

/// Shared warm gold/parchment palette for the passport chrome.
const _kGold = Color(0xFFD4A843);
const _kParchment = Color(0xFFEBD9B5);

/// Full-screen gastro passport: horizontal open-book spread (9×13.5 per page).
class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({
    super.key,
    required this.visits,
    this.initialVisitIndex = 0,
  });

  final List<Visit> visits;
  final int initialVisitIndex;

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen>
    with SingleTickerProviderStateMixin {
  final _spreadKey = GlobalKey<PassportSpreadViewState>();
  late final AnimationController _openAnim;

  bool _showCover = true;
  late int _spreadIndex;

  /// Spread 0 is always the identity spread; visits start at index 1. Keeping
  /// this offset in one place avoids off-by-ones when translating between
  /// "visit index" (caller-facing) and "spread index" (book-internal).
  static const int _identitySpreadOffset = 1;

  @override
  void initState() {
    super.initState();
    // Open onto the identity page by default; if the caller passes a visit
    // index, jump to that visit's spread (offset by 1 for the identity page).
    final int visitIdx = widget.initialVisitIndex
        .clamp(0, math.max(0, widget.visits.length - 1))
        .toInt();
    _spreadIndex = widget.visits.isEmpty
        ? 0
        : visitIdx + _identitySpreadOffset;
    _openAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _openAnim.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Resolves the data needed for the identity spread from the providers.
  /// Returns null when the user is signed-out so the spread is skipped — the
  /// passport screen is normally gated behind `auth.isLoggedIn`, but we keep
  /// this defensive in case a test harness mounts it cold.
  IdentityCardData? _identityCardData() {
    final auth = ref.watch(authProvider);
    if (auth.userId == null) return null;
    final profileAsync = ref.watch(profileProvider);
    final avatarUrl = profileAsync.maybeWhen(
      data: (p) => p.avatarUrl,
      orElse: () => null,
    );
    return buildIdentityCardData(
      userId: auth.userId,
      displayName: auth.displayName,
      homeCity: auth.homeCity,
      avatarUrl: avatarUrl,
      visits: widget.visits,
    );
  }

  /// Visit spreads built from the user's logged visits. Used for both
  /// the visible book and the cover stats.
  List<VisitSpread> _visitSpreads() => widget.visits.map((v) {
        final iso = v.country?.isoA2 ?? '';
        final region = v.country?.region ?? '';
        final dish = dishFor(isoA2: iso, region: region);
        return VisitSpread(
          visit: v,
          stampPhotoUrl: v.photoPath,
          dishPhotoUrl: dish.imageUrl,
          dishName: dish.dish,
        );
      }).toList();

  /// Identity spread (when available) + every visit spread, in order.
  List<BookSpread> _spreads() {
    final identity = _identityCardData();
    final visits = _visitSpreads();
    return [
      if (identity != null) IdentitySpread(data: identity),
      ...visits,
    ];
  }

  /// Total spreads currently in the book (identity + visits).
  int get _totalSpreads {
    final id = ref.read(authProvider).userId == null ? 0 : 1;
    return id + widget.visits.length;
  }

  /// True iff [_spreadIndex] is on a visit spread (i.e. past the identity).
  bool get _isOnVisitSpread =>
      widget.visits.isNotEmpty && _spreadIndex >= _identitySpreadOffset;

  Future<void> _openPassport() async {
    if (!_showCover) return;
    await _openAnim.forward();
    setState(() => _showCover = false);
  }

  /// Builds the user's culinary passport as a multi-page PDF and hands it to
  /// the native share sheet (WhatsApp / Mail / Drive / Print). Always
  /// available from the top bar — works on both the cover and open-book
  /// views, so the user can grab the artefact at any time.
  Future<void> _exportPassport() async {
    HapticFeedback.selectionClick();
    await PassportExportService.exportAndShare(
      context,
      ref,
      visits: widget.visits,
    );
  }

  /// The visit currently shown in the open spread, if any. Returns null on
  /// the identity spread (spread 0) or when there are no visits at all.
  Visit? get _currentVisit {
    if (widget.visits.isEmpty || !_isOnVisitSpread) return null;
    final visitIdx = (_spreadIndex - _identitySpreadOffset)
        .clamp(0, widget.visits.length - 1);
    return widget.visits[visitIdx];
  }

  /// Publishes the current spread's visit photo to the social stories feed.
  /// Only reachable when the visit actually has a photo (the Share button is
  /// hidden otherwise).
  Future<void> _shareToFeed() async {
    final visit = _currentVisit;
    final photoUrl = visit?.photoPath;
    if (visit == null || photoUrl == null || photoUrl.isEmpty) return;

    HapticFeedback.selectionClick();
    final config = ref.read(gastroThemeConfigProvider);
    final countryName = visit.country?.name;

    final caption = await ShareToFeedSheet.show(
      context,
      config: config,
      photoUrl: photoUrl,
      countryName: countryName,
    );
    // `null` ⇒ the user dismissed the sheet without posting.
    if (caption == null || !mounted) return;

    try {
      await ref.read(apiClientProvider).createStory(
            photoUrl: photoUrl,
            caption: caption.isEmpty ? null : caption,
            countryId: visit.countryId.isEmpty ? null : visit.countryId,
          );
      if (!mounted) return;
      // Refresh the feed so the new story appears immediately.
      invalidateSocialFromWidget(ref);
      _showShareSnack(config, posted: true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is UnauthorizedException
          ? 'Your session expired. Please sign in again.'
          : 'Could not share to the feed. Please try again.';
      _showShareSnack(config, posted: false, message: msg);
    }
  }

  void _showShareSnack(
    GastroThemeConfig config, {
    required bool posted,
    String? message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: posted ? config.accent : config.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GS.r12),
        ),
        content: Row(
          children: [
            Icon(
              posted
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: GS.s10),
            Expanded(
              child: Text(
                message ??
                    'Shared to your stories feed — bon appétit!',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spreads = _spreads();
    final total = _totalSpreads;
    final auth = ref.watch(authProvider);
    // The profile provider is watched inside `_identityCardData()` so the
    // identity spread rebuilds when the avatar resolves.
    return Scaffold(
      backgroundColor: const Color(0xFF1A100A),
      body: Stack(
        children: [
          Positioned.fill(child: _WoodBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  spreadIndex: _spreadIndex,
                  spreadCount: total,
                  showCover: _showCover,
                  onClose: () => Navigator.of(context).pop(),
                  // Share is only offered once the book is open and the
                  // current spread's visit has a photo to publish.
                  canShare: !_showCover &&
                      (_currentVisit?.photoPath?.isNotEmpty ?? false),
                  onShare: _shareToFeed,
                  onExport: _exportPassport,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: PassportDimensions.spreadLogicalWidth,
                          height: PassportDimensions.spreadLogicalHeight,
                          child: _PassportFrame(
                            child: _showCover
                                ? _CoverPanel(
                                    visitCount: widget.visits.length,
                                    holderName: auth.displayName,
                                    holderId: auth.userId,
                                    onOpen: _openPassport,
                                  )
                                : PassportSpreadView(
                                    key: _spreadKey,
                                    spreads: spreads,
                                    initialSpreadIndex: _spreadIndex,
                                    onSpreadChanged: (i) =>
                                        setState(() => _spreadIndex = i),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_showCover)
                  _SpreadNav(
                    spreadIndex: _spreadIndex,
                    spreadCount: total,
                    onFlipTopDown: () =>
                        _spreadKey.currentState?.flipTopDown(),
                    onFlipBottomUp: () =>
                        _spreadKey.currentState?.flipBottomUp(),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.spreadIndex,
    required this.spreadCount,
    required this.showCover,
    required this.onClose,
    required this.canShare,
    required this.onShare,
    required this.onExport,
  });

  final int spreadIndex;
  final int spreadCount;
  final bool showCover;
  final VoidCallback onClose;

  /// Whether the current spread's visit can be shared to the feed.
  final bool canShare;
  final VoidCallback onShare;

  /// Always-on: exports the whole passport as a PDF and opens the native
  /// share sheet.
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    // Trailing actions: Export is always present; Share-to-feed appears only
    // when the current visit has a photo. Page index is conveyed by the
    // dot strip at the bottom, so we don't repeat it here.
    final trailing = <Widget>[
      Tooltip(
        message: 'Export passport PDF',
        child: _CircleBtn(icon: LucideIcons.download, onTap: onExport),
      ),
      if (canShare) ...[
        const SizedBox(width: GS.s6),
        Tooltip(
          message: 'Share to feed',
          child: _CircleBtn(icon: Icons.ios_share_rounded, onTap: onShare),
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s16, GS.s8, GS.s16, GS.s6),
      child: Column(
        children: [
          Row(
            children: [
              _CircleBtn(icon: Icons.close_rounded, onTap: onClose),
              const Spacer(),
              Column(
                children: [
                  Text(
                    'GASTRO VOYAGE',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: _kParchment.withOpacity(0.7),
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: GS.s2),
                  Text(
                    'PASSPORT',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kParchment,
                      letterSpacing: 5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Trailing slot — Export is always rendered, Share follows
              // when the current visit has a photo to publish.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: trailing,
              ),
            ],
          ),
          const SizedBox(height: GS.s8),
          // Hairline gold rule — editorial divider under the masthead.
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kGold.withOpacity(0.0),
                  _kGold.withOpacity(0.5),
                  _kGold.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpreadNav extends StatelessWidget {
  const _SpreadNav({
    required this.spreadIndex,
    required this.spreadCount,
    required this.onFlipTopDown,
    required this.onFlipBottomUp,
  });

  final int spreadIndex;
  final int spreadCount;
  final VoidCallback onFlipTopDown;
  final VoidCallback onFlipBottomUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GS.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'swipe or tap edges to turn pages',
            style: GoogleFonts.caveat(
              fontSize: 14,
              color: _kParchment.withOpacity(0.55),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: GS.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleBtn(
                icon: Icons.keyboard_arrow_left_rounded,
                onTap: onFlipBottomUp,
              ),
              const SizedBox(width: GS.s20),
              _PageDots(index: spreadIndex, count: spreadCount),
              const SizedBox(width: GS.s20),
              _CircleBtn(
                icon: Icons.keyboard_arrow_right_rounded,
                onTap: onFlipTopDown,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact dotted progress strip for the passport spreads. Collapses to a
/// numeric tally when there are too many spreads to show individual dots.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count > 9) {
      return Text(
        '${index + 1}  ·  $count',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: _kParchment.withOpacity(0.7),
          letterSpacing: 2,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: GS.fast,
            curve: GS.smooth,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 16 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == index ? _kGold : _kParchment.withOpacity(0.3),
              borderRadius: BorderRadius.circular(GS.r4),
            ),
          ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          shape: BoxShape.circle,
          border: Border.all(color: _kGold.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: _kParchment, size: 18),
      ),
    );
  }
}

class _PassportFrame extends StatelessWidget {
  const _PassportFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3D2818).withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

class _CoverPanel extends StatelessWidget {
  const _CoverPanel({
    required this.visitCount,
    required this.holderName,
    required this.holderId,
    required this.onOpen,
  });
  final int visitCount;
  final String? holderName;
  final String? holderId;
  final VoidCallback onOpen;

  /// Last 6 alphanumeric chars of the user id — what we deboss on the cover.
  String get _coverGastroId {
    if (holderId == null || holderId!.isEmpty) return 'XXXXXX';
    final clean = holderId!
        .replaceAll(RegExp('[^0-9a-fA-F]'), '')
        .toUpperCase();
    if (clean.length < 6) return clean.padRight(6, 'X');
    return clean.substring(clean.length - 6);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B1F1F), Color(0xFF3D0E0E), Color(0xFF200505)],
          ),
        ),
        child: Stack(
          children: [
            // Subtle embossed leather grain + corner sheen.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _LeatherGrainPainter()),
              ),
            ),

            // Inset double gold frame — like a real passport's debossed border.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(GS.s16),
                child: IgnorePointer(
                  child: CustomPaint(painter: _CoverFramePainter()),
                ),
              ),
            ),

            // Washi-tape flourish across the top corner.
            Positioned(
              left: -20,
              top: 30,
              child: Transform.rotate(
                angle: -0.62,
                child: SizedBox(
                  width: 86,
                  height: 18,
                  child: CustomPaint(
                    painter: WashiTapePainter(
                      color: const Color(0xFFD4A843),
                      pattern: WashiPattern.stripes,
                    ),
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'REPUBLIC OF GASTRONOMY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: _kGold,
                      letterSpacing: 3.5,
                    ),
                  ).animate().fadeIn(duration: GS.slow),
                  const SizedBox(height: GS.s24),
                  // Embossed crest emblem with concentric gold rings.
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.3),
                        colors: [
                          _kGold.withOpacity(0.18),
                          Colors.transparent,
                        ],
                      ),
                      border: Border.all(
                        color: _kGold.withOpacity(0.85),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(GS.s8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _kGold.withOpacity(0.4),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant_rounded,
                            size: 42,
                            color: _kGold,
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: GS.slow, delay: GS.micro)
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1, 1),
                        curve: GS.spring,
                        duration: GS.xslow,
                      ),
                  const SizedBox(height: GS.s24),
                  Text(
                    'PASSPORT',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: _kGold,
                      letterSpacing: 8,
                    ),
                  ).animate().fadeIn(duration: GS.slow, delay: GS.fast),
                  const SizedBox(height: GS.s4),
                  Container(
                    width: 50,
                    height: 1.2,
                    color: _kGold.withOpacity(0.6),
                  ),
                  const SizedBox(height: GS.s8),
                  Text(
                    '$visitCount ${visitCount == 1 ? 'country' : 'countries'} tasted',
                    style: GoogleFonts.caveat(
                      fontSize: 19,
                      color: _kParchment.withOpacity(0.75),
                    ),
                  ).animate().fadeIn(duration: GS.slow, delay: GS.normal),
                  const SizedBox(height: GS.s24),
                  // Embossed holder name — gold-on-leather, with a stacked
                  // darker shadow beneath simulating the debossed bevel.
                  _EmbossedText(
                    text: (holderName ?? 'GASTRO TRAVELLER').toUpperCase(),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kGold,
                      letterSpacing: 4,
                    ),
                  ).animate().fadeIn(duration: GS.slow, delay: GS.slow),
                  const SizedBox(height: GS.s4),
                  _EmbossedText(
                    text: 'GASTRO ID N° $_coverGastroId',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _kGold.withOpacity(0.9),
                      letterSpacing: 2.4,
                    ),
                  ).animate().fadeIn(duration: GS.slow, delay: GS.xslow),
                ],
              ),
            ),

            // Cover tagline anchored above the "tap to open" hint.
            Positioned(
              left: 0,
              right: 0,
              bottom: 78,
              child: Center(
                child: _EmbossedText(
                  text: 'ONE WORLD  ·  ONE TABLE',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: _kGold.withOpacity(0.85),
                    letterSpacing: 3.2,
                  ),
                ),
              ),
            ),

            // Botanical sprig tucked in the lower-right.
            Positioned(
              right: 26,
              bottom: 70,
              child: Transform.rotate(
                angle: 0.2,
                child: SizedBox(
                  width: 34,
                  height: 74,
                  child: CustomPaint(
                    painter: BotanicalSprigPainter(
                      color: _kGold.withOpacity(0.7),
                      seed: 9,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: GS.s28,
              child: Column(
                children: [
                  const Icon(Icons.touch_app_rounded,
                      color: _kGold, size: 22)
                      .animate(
                        onPlay: (c) => c.repeat(reverse: true),
                      )
                      .moveY(
                        begin: 0,
                        end: -5,
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: GS.s6),
                  Text(
                    'tap to open the book',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: _kGold,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gold-on-leather embossed text. A darker bevel layer is offset down-right
/// to simulate the debossed press, then the bright gold sits on top with a
/// soft inner shadow giving the letters depth without needing an SVG.
class _EmbossedText extends StatelessWidget {
  const _EmbossedText({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark bevel sitting just below + right of the gold — reads as deboss.
        Transform.translate(
          offset: const Offset(0.6, 0.8),
          child: Text(
            text,
            style: style.copyWith(
              color: Colors.black.withOpacity(0.55),
              shadows: const [
                Shadow(
                  color: Color(0x66000000),
                  blurRadius: 1.4,
                  offset: Offset(0.3, 0.5),
                ),
              ],
            ),
          ),
        ),
        // Top highlight rim catching the cover sheen.
        Transform.translate(
          offset: const Offset(-0.4, -0.6),
          child: Text(
            text,
            style: style.copyWith(
              color: const Color(0xFFFFE9B0).withOpacity(0.6),
            ),
          ),
        ),
        // Gold face on top.
        Text(text, style: style),
      ],
    );
  }
}

/// Debossed double-line gold frame around the leather cover.
class _CoverFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = Paint()
      ..color = _kGold.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final inner = Paint()
      ..color = _kGold.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(GS.r4)),
      outer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(6), const Radius.circular(GS.r4)),
      inner,
    );
    // Corner ornaments.
    final dot = Paint()..color = _kGold.withOpacity(0.6);
    for (final c in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final sx = c.dx < size.width / 2 ? 1 : -1;
      final sy = c.dy < size.height / 2 ? 1 : -1;
      canvas.drawCircle(
        Offset(c.dx + sx * 13, c.dy + sy * 13),
        2.2,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoverFramePainter oldDelegate) => false;
}

/// Soft diagonal leather-grain sheen for the passport cover.
class _LeatherGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Top-left light sheen.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.6, -0.7),
          radius: 1.1,
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    // Faint horizontal grain striations.
    final grain = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 0.7;
    final rand = math.Random(7);
    for (double y = 0; y < size.height; y += 5 + rand.nextDouble() * 4) {
      final off = math.sin(y * 0.05) * 3;
      canvas.drawLine(
        Offset(-2 + off, y),
        Offset(size.width + 2 + off, y),
        grain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LeatherGrainPainter oldDelegate) => false;
}

class _WoodBackdrop extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [Color(0xFF2A1A0F), Color(0xFF0D0805)],
        ),
      ),
    );
  }
}
