import 'package:flutter/material.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/ui/ui.dart';

/// Loading placeholder for the Vault — shimmer rows laid out to echo the
/// timeline + clipping-card structure of the real list.
class VaultLoadingList extends StatelessWidget {
  const VaultLoadingList({super.key, required this.config});

  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s20, GS.s8, GS.s20, GS.s40),
      child: Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: GS.s20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date plaque placeholder.
                GastroShimmer(
                  config: config,
                  width: 54,
                  height: 64,
                  radius: GS.r8,
                ),
                const SizedBox(width: GS.s12),
                // Clipping-card placeholder.
                Expanded(
                  child: GastroShimmer(
                    config: config,
                    height: 110,
                    radius: GS.r16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
