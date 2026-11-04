import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/booking_status.dart';
import '../widgets/error_view.dart';
import 'booking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Booking>> _bookings = api.driverBookings(widget.user.id);

  Future<void> _refresh() async {
    final next = api.driverBookings(widget.user.id);
    setState(() => _bookings = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: FutureBuilder<List<Booking>>(
        future: _bookings,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _refresh);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final bookings = snap.data!;
          if (bookings.isEmpty) {
            return const Center(
              child: Text(
                'No bookings yet. Use “Find me a charge” on the map.',
                style: TextStyle(color: VoltraColors.muted),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final b = bookings[i];
                return Card(
                  child: ListTile(
                    title: Text(b.chargerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('${clock(b.start)} – ${clock(b.end)}'),
                          BookingStatusPill(status: b.status),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(bookingId: b.id, user: widget.user),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
