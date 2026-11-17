import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../design/tokens.dart';
import '../theme.dart';
import '../widgets/booking_status.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import '../widgets/stat_tile.dart';
import 'booking_screen.dart';
import 'charge_match_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.user, this.visit = 0});

  final AppUser user;

  /// Changes each time the Bookings tab is reopened; the list reloads when it does.
  final int visit;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Booking>> _bookings = api.driverBookings(widget.user.id);

  @override
  void didUpdateWidget(MyBookingsScreen old) {
    super.didUpdateWidget(old);
    if (old.visit != widget.visit) _refresh();
  }

  Future<void> _refresh() async {
    final next = api.driverBookings(widget.user.id);
    setState(() {
      _bookings = next;
    });
    try {
      await next;
    } on ApiException {
      // The FutureBuilder shows the error; pull-to-refresh just needs to finish.
    }
  }

  Future<void> _findCharge() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChargeMatchScreen(user: widget.user)));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _refresh);
          if (!snap.hasData) return const SkeletonList(item: BookingRowSkeleton());
          final bookings = snap.data!;
          if (bookings.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No bookings yet',
              hint: 'Tell us how much charge you need and we’ll match you with a charger nearby.',
              actionLabel: 'Find me a charge',
              onAction: _findCharge,
            );
          }
          const live = {'PENDING', 'CONFIRMED', 'ARRIVED', 'CHARGING'};
          final active = [
            for (final b in bookings)
              if (live.contains(b.status)) b,
          ];
          final past = [
            for (final b in bookings)
              if (!live.contains(b.status)) b,
          ];
          var row = 0;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xl),
              children: [
                if (active.isNotEmpty) ...[
                  SectionHeader('Active', count: active.length),
                  for (final b in active) Entrance(index: row++, child: _row(b, highlight: true)),
                ],
                if (past.isNotEmpty) ...[
                  SectionHeader('Past', count: past.length),
                  for (final b in past) Entrance(index: row++, child: _row(b)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openBooking(Booking b) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(bookingId: b.id, user: widget.user),
      ),
    );
    if (mounted) _refresh();
  }

  Widget _row(Booking b, {bool highlight = false}) {
    final vc = context.vc;
    final (_, icon, color) = BookingStatusPill.describe(b.status, vc);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Pressable(
        onTap: () => _openBooking(b),
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: vc.card,
            borderRadius: Radii.card,
            border: Border.all(color: highlight ? vc.brand : vc.border, width: highlight ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.chargerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc.ink),
                    ),
                    const SizedBox(height: 2),
                    Text('${clock(b.start)} – ${clock(b.end)}', style: TextStyle(color: vc.muted, fontSize: 13)),
                    const SizedBox(height: Gap.sm),
                    BookingStatusPill(status: b.status),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: vc.faint),
            ],
          ),
        ),
      ),
    );
  }
}
