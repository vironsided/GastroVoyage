import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/ui/ui.dart';

/// Horizontally scrolling filter chips for the Vault.
///
/// Visual polish only — selection state is local and does not affect the
/// underlying data wiring (kept identical to the original screen).
class VaultFilterChips extends StatefulWidget {
  const VaultFilterChips({super.key, required this.config});

  final GastroThemeConfig config;

  @override
  State<VaultFilterChips> createState() => _VaultFilterChipsState();
}

class _VaultFilterChipsState extends State<VaultFilterChips> {
  int _selected = 0;
  static const _filters = ['All', 'Tried', 'Want to try', '5★', '4★+'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: GS.s8),
        itemBuilder: (_, i) {
          return GastroChip(
            label: _filters[i],
            selected: i == _selected,
            onTap: () => setState(() => _selected = i),
            config: widget.config,
            compact: true,
          )
              .animate(delay: GS.stagger(i, ms: 45))
              .fadeIn(duration: GS.normal, curve: GS.smooth)
              .slideX(begin: 0.18, end: 0, duration: GS.normal, curve: GS.smooth);
        },
      ),
    );
  }
}
