import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// Status pill: icon + words, so colour never carries the meaning alone.
class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.status});

  final String status;

  static (String, IconData, Color) describe(String status, VoltraPalette vc) => switch (status) {
    'PENDING' => ('Waiting for host', Icons.hourglass_top, vc.warning),
    'CONFIRMED' => ('Confirmed', Icons.check_circle, vc.success),
    'ARRIVED' => ('Arrived', Icons.place, vc.success),
    'CHARGING' => ('Charging', Icons.bolt, vc.success),
    'COMPLETED' => ('Completed', Icons.task_alt, vc.muted),
    'CANCELLED' => ('Cancelled', Icons.cancel, vc.faint),
    _ => (status, Icons.info_outline, vc.faint),
  };

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = describe(status, context.vc);
    // The pill's colour and words glide to the new status instead of snapping.
    return AnimatedContainer(
      duration: Motion.medium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.pill)),
      child: AnimatedSwitcher(
        duration: Motion.fast,
        child: Row(
          key: ValueKey(status),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
