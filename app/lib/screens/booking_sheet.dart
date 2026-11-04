import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'booking_screen.dart';

/// Book a specific charger directly (ChargeMatch picks the slot for you instead).
Future<void> showBookingSheet(BuildContext context, {required Charger charger, required AppUser user}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BookingSheet(charger: charger, user: user, parent: context),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.charger, required this.user, required this.parent});

  final Charger charger;
  final AppUser user;
  final BuildContext parent;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  static const _startsIn = {0: 'Now', 30: 'In 30 min', 60: 'In 1 hour'};
  static const _lengths = {60: '1 h', 120: '2 h', 180: '3 h'};

  int _startInMin = 0;
  int _lengthMin = 120;
  bool _busy = false;

  Future<void> _book() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(widget.parent);
    final messenger = ScaffoldMessenger.of(widget.parent);
    try {
      // Independent requests, fetched at once. Future.wait rethrows the original ApiException.
      final results = await Future.wait([api.serverNow(), api.vehicles(widget.user.id)]);
      final now = results[0] as DateTime;
      final vehicles = results[1] as List<Vehicle>;
      // Round up to the next 5 minutes so the slot starts on a clean time.
      final base = now.add(Duration(minutes: 5 - now.minute % 5 + _startInMin));
      final start = DateTime(base.year, base.month, base.day, base.hour, base.minute);
      final booking = await api.createBooking(
        driverId: widget.user.id,
        chargerId: widget.charger.id,
        vehicleId: vehicles.isEmpty ? null : vehicles.first.id,
        start: start,
        end: start.add(Duration(minutes: _lengthMin)),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BookingScreen(bookingId: booking.id, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.charger;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book ${c.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${pricePerKwh(c.priceNowPaise)} · ${c.autoApprove ? 'confirmed instantly' : '${c.hostName} approves each booking'}',
              style: const TextStyle(color: VoltraColors.muted),
            ),
            const SizedBox(height: 16),
            const Text('Start', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _startsIn.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _startInMin == e.key,
                    onSelected: (_) => setState(() => _startInMin = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('For', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _lengths.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _lengthMin == e.key,
                    onSelected: (_) => setState(() => _lengthMin = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _book,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }
}
