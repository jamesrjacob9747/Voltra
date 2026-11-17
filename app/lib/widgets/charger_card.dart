import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'confidence_badge.dart';

/// "Evening peak" / "Night off-peak" when time-of-day pricing is in effect, else null.
String? priceTag(Charger c) {
  if (c.priceNowPaise > c.basePricePaise) return 'Evening peak';
  if (c.priceNowPaise < c.basePricePaise) return 'Night off-peak';
  return null;
}

/// The content of a charger row: what it is, how far, how reliable, what it costs right now.
/// It has no tap handling or card frame of its own, so lists can wrap it as they need.
class ChargerSummary extends StatelessWidget {
  const ChargerSummary({super.key, required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final c = charger;
    final tone = confidenceColor(c.confidence.score, online: c.online, palette: vc);
    final tag = priceTag(c);
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(c.online ? Icons.ev_station : Icons.power_off, color: tone),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: vc.ink),
                      ),
                    ),
                    if (c.verified) ...[
                      const SizedBox(width: Gap.xs),
                      Icon(Icons.verified, size: 16, color: vc.brand, semanticLabel: 'Verified'),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${distance(c.distanceKm ?? 0)} · ${c.connectorLabel} · ${c.powerKw} kW',
                  style: TextStyle(color: vc.muted, fontSize: 13),
                ),
                const SizedBox(height: Gap.sm),
                ConfidenceBadge(confidence: c.confidence, online: c.online),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rupees(c.priceNowPaise),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: vc.ink, letterSpacing: -0.3),
              ),
              Text('per kWh', style: TextStyle(fontSize: 12, color: vc.muted)),
              if (tag != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.priceNowPaise > c.basePricePaise ? vc.warning : vc.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
