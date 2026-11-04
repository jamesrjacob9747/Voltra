import 'package:flutter/material.dart';

import '../theme.dart';

/// Status pill: icon + words, so colour never carries the meaning alone.
class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.status});

  final String status;

  static (String, IconData, Color) describe(String status) => switch (status) {
    'PENDING' => ('Waiting for host', Icons.hourglass_top, VoltraColors.amber),
    'CONFIRMED' => ('Confirmed', Icons.check_circle, VoltraColors.darkGreen),
    'ARRIVED' => ('Arrived', Icons.place, VoltraColors.darkGreen),
    'CHARGING' => ('Charging', Icons.bolt, VoltraColors.darkGreen),
    'COMPLETED' => ('Completed', Icons.task_alt, VoltraColors.muted),
    'CANCELLED' => ('Cancelled', Icons.cancel, VoltraColors.grey),
    _ => (status, Icons.info_outline, VoltraColors.grey),
  };

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = describe(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
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
