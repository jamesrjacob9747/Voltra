import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/booking_status.dart';
import '../widgets/chargesure_panel.dart';
import '../widgets/error_view.dart';
import '../widgets/snack.dart';
import 'bill_screen.dart';
import 'live_session_screen.dart';
import 'scan_screen.dart';

/// One booking from the driver's side. Polls while the host hasn't answered yet.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.bookingId, required this.user});

  final int bookingId;
  final AppUser user;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Booking? _booking;
  Charger? _charger;
  ChargeSureOptions? _chargeSure; // set while the booked charger is offline
  int? _movingTo;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      final b = _booking;
      if (b?.status == 'PENDING') {
        _load();
      } else if (b != null && b.canStart) {
        _checkHealth(b);
      }
    });
  }

  /// Watches the booked charger's heartbeat until the session starts, so ChargeSure
  /// can step in before the driver even arrives.
  Future<void> _checkHealth(Booking b) async {
    try {
      final health = await api.bookingHealth(b.id);
      if (mounted) setState(() => _chargeSure = health.online ? null : health);
    } on ApiException {
      // Keep the last known state; the next poll retries.
    }
  }

  Future<void> _moveTo(Charger target) async {
    setState(() => _movingTo = target.id);
    try {
      final moved = await api.transferBooking(widget.bookingId, target.id);
      if (!mounted) return;
      showSnack(context, 'Moved to ${target.name}. ${rupees(moved.creditPaise)} credit added.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingScreen(bookingId: moved.id, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _movingTo = null);
      showSnack(context, e.message);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final booking = await api.booking(widget.bookingId);
      // Re-read the charger: the exact address unlocks once the booking is confirmed.
      final charger = await api.charger(booking.chargerId, userId: widget.user.id);
      if (mounted) {
        setState(() {
          _booking = booking;
          _charger = charger;
          _error = null;
        });
      }
      if (booking.canStart) await _checkHealth(booking);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _act(String action) async {
    setState(() => _busy = true);
    try {
      final updated = await api.updateBooking(widget.bookingId, action, actorId: widget.user.id);
      if (!mounted) return;
      setState(() => _booking = updated);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Future<void> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: const Text('The slot will be released for other drivers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (ok == true) await _act('cancel');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Booking #${widget.bookingId}')),
      body: _error != null && _booking == null
          ? ErrorView(message: _error!, onRetry: _load)
          : _booking == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(_booking!, _charger),
    );
  }

  Widget _buildBody(Booking b, Charger? c) {
    final headline = switch (b.status) {
      'PENDING' => 'Waiting for ${c?.hostName ?? 'the host'} to accept',
      'CONFIRMED' => 'You’re booked',
      'ARRIVED' => 'You’re at the charger',
      'CHARGING' => 'Charging',
      'COMPLETED' => 'Session complete',
      _ => 'Booking cancelled',
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BookingStatusPill(status: b.status),
              const SizedBox(height: 8),
              Text(
                headline,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: VoltraColors.ink),
              ),
              if (b.status == 'PENDING') ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text(
                  'This host approves each booking. This page updates as soon as they answer.',
                  style: TextStyle(color: VoltraColors.muted),
                ),
              ],
              if (_chargeSure != null && b.canStart) ...[
                const SizedBox(height: 16),
                ChargeSurePanel(
                  failedChargerName: b.chargerName,
                  options: _chargeSure!,
                  movingToId: _movingTo,
                  onMove: _moveTo,
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.chargerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${clock(b.start)} – ${clock(b.end)}', style: const TextStyle(fontSize: 16)),
                      if (c != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${c.connectorLabel} · ${pricePerKwh(c.priceNowPaise)} · hosted by ${c.hostName}',
                          style: const TextStyle(color: VoltraColors.muted),
                        ),
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              c.exactLocation ? Icons.place : Icons.lock_outline,
                              color: c.exactLocation ? VoltraColors.darkGreen : VoltraColors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c.exactLocation ? c.address ?? '' : 'Exact address unlocks once the host confirms.',
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (b.creditPaise > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ChargeSure credit: ${rupees(b.creditPaise)}',
                          style: const TextStyle(color: VoltraColors.darkGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (b.canStart) ...[
                const SizedBox(height: 16),
                const Text(
                  'At the charger: plug in, then scan the QR sticker to switch the power on.',
                  style: TextStyle(color: VoltraColors.muted),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (b.canStart && _chargeSure == null) // offline: ChargeSure's buttons take over
                  FilledButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR to start charging'),
                    onPressed: _busy ? null : () => _open(ScanScreen(booking: b, user: widget.user)),
                  ),
                if (b.status == 'CONFIRMED') ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.place),
                    label: const Text('I’ve arrived'),
                    onPressed: _busy ? null : () => _act('arrive'),
                  ),
                ],
                if (b.status == 'CHARGING' && b.sessionId != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.bolt),
                    label: const Text('View live charging'),
                    onPressed: () => _open(LiveSessionScreen(sessionId: b.sessionId!, user: widget.user)),
                  ),
                if (b.status == 'COMPLETED' && b.sessionId != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View bill'),
                    onPressed: () => _open(BillScreen(bookingId: b.id, sessionId: b.sessionId!, user: widget.user)),
                  ),
                if (b.canCancel) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _confirmCancel,
                    child: const Text('Cancel booking', style: TextStyle(color: VoltraColors.muted)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
