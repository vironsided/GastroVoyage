import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Region filter rendered as passport "bookmark tabs" — paper index tabs with
/// one asymmetrically clipped corner. The selected tab fills with `accent`,
/// lifts slightly and squares its top corner; unselected tabs read like the
/// edge of an index card.
class PassportBookmarkTabs extends StatelessWidget {
  const PassportBookmarkTabs({
    super.key,
    required this.config,
    required this.regions,
    required this.selectedRegion,
    required this.triedOnly,
    required this.wantToTryOnly,
    required this.onSelect,
  });

  final GastroThemeConfig config;
  final List<String> regions;
  final String? selectedRegion;
  final bool triedOnly;
  final bool wantToTryOnly;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: GS.s2),
        itemCount: regions.length,
        separatorBuilder: (_, __) => const SizedBox(width: GS.s8),
        itemBuilder: (_, i) {
          final r = regions[i];
          final isSelected = r == 'All'
              ? selectedRegion == null && !triedOnly && !wantToTryOnly
              : r == 'Tried'
                  ? triedOnly
                  : r == 'Want to try'
                      ? wantToTryOnly
                      : r == selectedRegion;
          return _BookmarkTab(
            label: r,
            isSelected: isSelected,
            config: config,
            index: i,
            onTap: () => onSelect(r),
          );
        },
      ),
    );
  }
}

class _BookmarkTab extends StatefulWidget {
  const _BookmarkTab({
    required this.label,
    required this.isSelected,
    required this.config,
    required this.index,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final GastroThemeConfig config;
  final int index;
  final VoidCallback onTap;

  @override
  State<_BookmarkTab> createState() => _BookmarkTabState();
}

class _BookmarkTabState extends State<_BookmarkTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _ctrl.reverse();
    widget.onTap();
    if (mounted) await _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final selected = widget.isSelected;
    final isTried = widget.label == 'Tried';
    final isWantToTry = widget.label == 'Want to try';
    // alternate which corner is clipped for an organic index-card look
    final clipLeft = widget.index.isEven;

    final fg = selected
        ? (config.isDark ? Colors.white : config.onPrimary)
        : config.onSurfaceVariant;
    final bg = selected ? config.accent : config.surface;

    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _ctrl,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: GS.smooth,
          offset: selected ? const Offset(0, -0.06) : Offset.zero,
          child: ClipPath(
            clipper: _TabClipper(clipLeft: clipLeft, square: selected),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: GS.smooth,
              padding: const EdgeInsets.symmetric(
                  horizontal: GS.s16, vertical: GS.s8),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(
                  color: selected ? config.accent : config.outlineVariant,
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: config.accent.withOpacity(0.30),
                          blurRadius: 9,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(
                              config.isDark ? 0.3 : 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                              config.isDark ? 0.22 : 0.04),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTried) ...[
                    Icon(
                      _triedIcon(config.mode),
                      size: 11,
                      color: selected ? fg : config.accent,
                    ),
                    const SizedBox(width: GS.s4),
                  ] else if (isWantToTry) ...[
                    Icon(
                      LucideIcons.bookmark,
                      size: 11,
                      color: selected ? fg : config.accent,
                    ),
                    const SizedBox(width: GS.s4),
                  ],
                  Text(
                    isTried
                        ? 'TASTED'
                        : isWantToTry
                            ? 'WISHLIST'
                            : widget.label.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _triedIcon(GastroThemeMode mode) {
  switch (mode) {
    case GastroThemeMode.girls:
      return LucideIcons.heart;
    case GastroThemeMode.couples:
      return LucideIcons.check;
    case GastroThemeMode.guys:
      return LucideIcons.zap;
  }
}

/// Clips one corner of the tab for the asymmetric bookmark silhouette.
class _TabClipper extends CustomClipper<Path> {
  const _TabClipper({required this.clipLeft, required this.square});

  /// Which top corner is bevelled.
  final bool clipLeft;

  /// When selected the tab "seats" — its top corners go square.
  final bool square;

  @override
  Path getClip(Size size) {
    final cut = square ? 3.0 : 9.0;
    final path = Path();
    if (clipLeft) {
      path
        ..moveTo(cut, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, cut)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width - cut, 0)
        ..lineTo(size.width, cut)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(_TabClipper old) =>
      old.clipLeft != clipLeft || old.square != square;
}
