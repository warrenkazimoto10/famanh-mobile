import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/adiake_colors.dart';
import 'app_card.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.lines = 3,
    this.height = 120,
    this.shimmer = true,
  });

  final int lines;
  final double height;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final base = AdiakeColors.outlineVariant.withValues(alpha: 0.35);
    final hi = AdiakeColors.outlineVariant.withValues(alpha: 0.12);

    final content = AppCard(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(w: 180, h: 14, c: base),
            const SizedBox(height: 10),
            for (int i = 0; i < lines; i++) ...[
              _Bar(w: i == lines - 1 ? 160 : double.infinity, h: 10, c: base),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );

    if (!shimmer) return content;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      child: content,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.w, required this.h, required this.c});
  final double w;
  final double h;
  final Color c;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: w == double.infinity ? 1 : null,
      child: Container(
        width: w == double.infinity ? null : w,
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

