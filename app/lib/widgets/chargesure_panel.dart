import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'confidence_badge.dart';

/// ChargeSure: the booked charger is offline, so offer the best nearby ones,
/// each one tap away, with the platform-funded credit shown up front.
class ChargeSurePanel extends StatelessWidget {
  const ChargeSurePanel({
    super.key,
    required this.failedChargerName,
    required this.options,
    required this.onMove,
    this.movingToId,
  });

  final String failedChargerName;
  final ChargeSureOptions options;
  final ValueChanged<Charger> onMove;
  final int? movingToId;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final alts = options.alternatives;
    return Container(
      decoration: BoxDecoration(
        color: vc.warningTint,
        borderRadius: Radii.card,
        border: Border.all(color: vc.warning, width: 1.5),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: vc.brand),
              const SizedBox(width: 6),
              Text(
                'ChargeSure',
                style: TextStyle(fontWeight: FontWeight.w800, color: vc.brand, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            '$failedChargerName is offline right now.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: vc.ink),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            alts.isEmpty
                ? 'No other charger nearby can take your slot yet. We’ll keep checking.'
                : 'Don’t worry, we found ${alts.length} nearby. Move your booking in one tap '
                      'and get ${rupees(options.creditPaise)} off this charge.',
            style: TextStyle(color: vc.muted, height: 1.4),
          ),
          for (final (i, c) in alts.take(3).indexed) ...[
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.md),
              decoration: BoxDecoration(color: vc.card, borderRadius: BorderRadius.circular(Radii.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (i == 0)
                    Text(
                      'BEST OPTION',
                      style: TextStyle(color: vc.brand, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
                    ),
                  Text(
                    c.name,
                    style: TextStyle(fontWeight: FontWeight.w700, color: vc.ink, fontSize: 15),
                  ),
                  const SizedBox(height: Gap.xs),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${distance(c.distanceKm ?? 0)} away · ${pricePerKwh(c.priceNowPaise)}',
                        style: TextStyle(color: vc.muted),
                      ),
                      ConfidenceBadge(confidence: c.confidence, online: c.online),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
                    ),
                    onPressed: movingToId == null ? () => onMove(c) : null,
                    child: movingToId == c.id
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: vc.brand),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Move my booking here'),
                              Text(
                                '+${rupees(options.creditPaise)} credit',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
