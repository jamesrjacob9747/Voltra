import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// A grey block standing in for content that is still loading.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  const Skeleton.circle(double size, {super.key}) : width = size, height = size, radius = Radii.pill;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.vc.skeleton, borderRadius: BorderRadius.circular(radius)),
  );
}

/// Sweeps a soft highlight across its child's [Skeleton] blocks, and tells screen readers
/// that something is loading. With animations off, the blocks simply sit still.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final body = Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(child: child),
    );
    if (Motion.reduced(context)) return body;
    return body
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: const Duration(milliseconds: 1200), color: context.vc.skeletonShine);
  }
}

/// A charger row: name, a line of facts, a badge.
class ChargerCardSkeleton extends StatelessWidget {
  const ChargerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const _SkeletonCard(
    child: Row(
      children: [
        Skeleton(width: 48, height: 48, radius: Radii.md),
        SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 170, height: 16),
              SizedBox(height: Gap.sm),
              Skeleton(width: 120),
              SizedBox(height: Gap.md),
              Skeleton(width: 140, height: 22, radius: Radii.pill),
            ],
          ),
        ),
        SizedBox(width: Gap.md),
        Skeleton(width: 54, height: 20),
      ],
    ),
  );
}

/// A booking row: title, time, status pill.
class BookingRowSkeleton extends StatelessWidget {
  const BookingRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const _SkeletonCard(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 180, height: 16),
              SizedBox(height: Gap.sm),
              Skeleton(width: 130),
            ],
          ),
        ),
        Skeleton(width: 92, height: 24, radius: Radii.pill),
      ],
    ),
  );
}

/// A 2-column grid of stat tiles.
class StatGridSkeleton extends StatelessWidget {
  const StatGridSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: Gap.md,
    crossAxisSpacing: Gap.md,
    childAspectRatio: 1.9,
    children: [for (var i = 0; i < count; i++) const Skeleton(height: 84, radius: Radii.md)],
  );
}

/// [count] skeleton rows in a shimmering column: the standard list placeholder.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, required this.item, this.count = 4, this.padding = const EdgeInsets.all(Gap.lg)});

  final Widget item;
  final int count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Shimmer(
    child: ListView.separated(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
      itemBuilder: (_, _) => item,
    ),
  );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: context.vc.card,
      borderRadius: Radii.card,
      border: Border.all(color: context.vc.border),
    ),
    child: child,
  );
}
