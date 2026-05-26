import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';

/// Single shimmer box. Replaces `_ShimmerCard` from dashboard and `_LoadingList`
/// rows from vault.
class GastroShimmer extends StatelessWidget {
  const GastroShimmer({
    super.key,
    required this.config,
    this.height = 160,
    this.width = double.infinity,
    this.radius = GS.r24,
    this.margin = EdgeInsets.zero,
  });

  final GastroThemeConfig config;
  final double height;
  final double width;
  final double radius;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: config.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: config.outlineVariant.withOpacity(0.6),
        );
  }
}

/// Horizontal shimmer list — for the "Recently Tasted" carousel during load.
/// Replaces dashboard's `_HorizontalShimmerList`.
class GastroShimmerCarousel extends StatelessWidget {
  const GastroShimmerCarousel({
    super.key,
    required this.config,
    this.height = 230,
    this.itemWidth = 160,
    this.itemCount = 4,
    this.spacing = GS.s12,
    this.radius = GS.r20,
  });

  final GastroThemeConfig config;
  final double height;
  final double itemWidth;
  final int itemCount;
  final double spacing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (_, __) => GastroShimmer(
          config: config,
          height: height,
          width: itemWidth,
          radius: radius,
        ),
      ),
    );
  }
}

/// Grid of shimmer cards — used by Explore screen while countries load.
class GastroShimmerGrid extends StatelessWidget {
  const GastroShimmerGrid({
    super.key,
    required this.config,
    this.crossAxisCount = 2,
    this.itemCount = 6,
    this.aspectRatio = 0.85,
    this.spacing = GS.s12,
    this.radius = GS.r20,
  });

  final GastroThemeConfig config;
  final int crossAxisCount;
  final int itemCount;
  final double aspectRatio;
  final double spacing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => GastroShimmer(config: config, radius: radius),
    );
  }
}
