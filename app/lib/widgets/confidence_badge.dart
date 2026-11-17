import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../models.dart';
import '../theme.dart';

/// Green from 85, amber from 60, grey below or when offline.
/// Pass `context.vc` so the colour follows the theme; without it you get the light colours.
Color confidenceColor(int score, {bool online = true, VoltraPalette palette = VoltraPalette.light}) {
  if (!online) return palette.faint;
  if (score >= 85) return palette.success;
  if (score >= 60) return palette.warning;
  return palette.faint;
}

/// Score + band in words, so colour never carries the meaning alone.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.confidence, required this.online});

  final Confidence confidence;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = confidenceColor(confidence.score, online: online, palette: context.vc);
    final label = online ? '${confidence.score}% · ${confidence.band}' : 'Offline';
    return AnimatedContainer(
      duration: Motion.medium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.bolt : Icons.power_off, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
