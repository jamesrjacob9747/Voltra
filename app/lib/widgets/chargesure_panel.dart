import 'package:flutter/material.dart';

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
    final alts = options.alternatives;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: VoltraColors.amber, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: VoltraColors.darkGreen),
                SizedBox(width: 6),
                Text(
                  'ChargeSure',
                  style: TextStyle(fontWeight: FontWeight.w800, color: VoltraColors.darkGreen, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$failedChargerName is offline right now.',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              alts.isEmpty
                  ? 'No other charger nearby can take your slot yet. We’ll keep checking.'
                  : 'Don’t worry, we found ${alts.length} nearby. Move your booking in one tap '
                        'and get ${rupees(options.creditPaise)} off this charge.',
              style: const TextStyle(color: VoltraColors.muted),
            ),
            for (final (i, c) in alts.take(3).indexed) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (i == 0)
                          const Text(
                            'BEST OPTION',
                            style: TextStyle(
                              color: VoltraColors.darkGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('${distance(c.distanceKm ?? 0)} away · ${pricePerKwh(c.priceNowPaise)}'),
                            ConfidenceBadge(confidence: c.confidence, online: c.online),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                onPressed: movingToId == null ? () => onMove(c) : null,
                child: movingToId == c.id
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Move my booking here (+${rupees(options.creditPaise)} credit)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
