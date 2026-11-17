import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// A labelled figure: "1.85 kWh · Energy". One widget for every stat grid in the app.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = StatTone.plain,
    this.compact = false,
  });

  final String label;

  /// Usually a [Text] or a `CountUp`; styled by this tile.
  final Widget value;
  final IconData? icon;
  final StatTone tone;

  /// Smaller figure, for rows of three or four.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final (background, foreground, soft, border) = switch (tone) {
      StatTone.plain => (vc.card, vc.ink, vc.muted, vc.border),
      StatTone.brand => (vc.brandTint, vc.ink, vc.muted, Colors.transparent),
      StatTone.navy => (VoltraColors.navy, Colors.white, VoltraColors.onNavySoft, Colors.transparent),
      StatTone.onNavy => (VoltraColors.navyRaised, Colors.white, VoltraColors.onNavySoft, Colors.transparent),
    };
    return Container(
      padding: EdgeInsets.all(compact ? Gap.md : Gap.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: tone == StatTone.plain || tone == StatTone.brand ? vc.brand : VoltraColors.green,
            ),
            const SizedBox(height: Gap.sm),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: compact ? 17 : 22,
              fontWeight: FontWeight.w800,
              color: foreground,
              letterSpacing: -0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: soft, fontWeight: FontWeight.w500, height: 1.25),
          ),
        ],
      ),
    );
  }
}

/// Grid layout for a block of [StatTile]s. Each row is as tall as a tile needs at the current
/// text size (two-line labels included), instead of a fixed width-to-height ratio that runs
/// out of room on narrow phones or with the system font size turned up.
SliverGridDelegate statGridDelegate(BuildContext context, {bool compact = false, bool icon = false, int columns = 2}) {
  final scale = MediaQuery.textScalerOf(context).scale(1);
  final padding = compact ? Gap.md * 2 : Gap.lg * 2;
  final iconRow = icon ? 18 + Gap.sm : 0;
  // Generous line heights: a few spare pixels beat a clipped label on some phone's font.
  final value = (compact ? 17 : 22) * 1.5; // one line of the figure
  const label = 12 * 1.4 * 2; // up to two lines
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: Gap.md,
    crossAxisSpacing: Gap.md,
    mainAxisExtent: padding + iconRow + 4 + scale * (value + label),
  );
}

enum StatTone {
  /// Card surface with a border.
  plain,

  /// Soft brand wash: the figure to notice first.
  brand,

  /// Solid navy, for one highlighted tile on a light screen.
  navy,

  /// A raised tile on an always-navy screen (live session, impact).
  onNavy,
}

/// "Requests (2)" with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.count, this.trailing});

  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: vc.ink),
          ),
          if (count != null) ...[
            const SizedBox(width: Gap.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: vc.raised, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: vc.muted),
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
