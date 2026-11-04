import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

Color confidenceColor(int score, {bool online = true}) {
  if (!online) return VoltraColors.grey;
  if (score >= 85) return VoltraColors.darkGreen;
  if (score >= 60) return VoltraColors.amber;
  return VoltraColors.grey;
}

/// Score + band in words, so colour never carries the meaning alone.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.confidence, required this.online});

  final Confidence confidence;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = confidenceColor(confidence.score, online: online);
    final label = online ? '${confidence.score}% · ${confidence.band}' : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.bolt : Icons.power_off, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
