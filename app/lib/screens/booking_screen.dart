import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/booking_status.dart';
import '../widgets/charger_map.dart';
import '../widgets/chargesure_panel.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/primary_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/snack.dart';
import 'bill_screen.dart';
import 'live_session_screen.dart';
import 'scan_screen.dart';

/// The stages a booking moves through, in order, as the progress tracker shows them.
const _stages = ['Booked', 'Confirmed', 'Arrived', 'Charging', 'Done'];

/// How many stages are complete for a booking status (the next one is "in progress").
int _stagesDone(String status) => switch (status) {
  'PENDING' => 1,
  'CONFIRMED' => 2,
  'ARRIVED' => 3,
  'CHARGING' => 4,
  'COMPLETED' => 5,
  _ => 0,
};

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
      HapticFeedback.mediumImpact();
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
        // A tick when the host says yes, so the driver notices even with the phone in hand.
        if (_booking?.status == 'PENDING' && booking.status == 'CONFIRMED') HapticFeedback.mediumImpact();
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
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.vc.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (ok == true) await _act('cancel');
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    return Scaffold(
      appBar: AppBar(title: Text('Booking #${widget.bookingId}')),
      body: b == null
          ? (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Shimmer(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.lg),
                      child: Column(
                        children: [
                          Skeleton(height: 130, radius: Radii.lg),
                          SizedBox(height: Gap.lg),
                          Skeleton(height: 280, radius: Radii.lg),
                        ],
                      ),
                    ),
                  ))
          : _buildBody(b, _charger),
      bottomNavigationBar: b == null ? null : _buildActions(b),
    );
  }

  Widget _buildBody(Booking b, Charger? c) {
    final vc = context.vc;
    final (headline, detail) = switch (b.status) {
      'PENDING' => (
        'Waiting for ${c?.hostName ?? 'the host'}',
        'This host approves each booking. This page updates as soon as they answer.',
      ),
      'CONFIRMED' => ('You’re booked', 'Head over for ${clock(b.start)}. The exact address is below.'),
      'ARRIVED' => ('You’re at the charger', 'Plug in, then scan the QR sticker to switch the power on.'),
      'CHARGING' => ('Charging', 'Power is flowing. Open the live view to watch it.'),
      'COMPLETED' => ('Session complete', 'Your bill is ready.'),
      _ => ('Booking cancelled', 'The slot was released. You were not charged.'),
    };
    final cancelled = b.status == 'CANCELLED';
    final (_, statusIcon, statusColor) = BookingStatusPill.describe(b.status, vc);
    final showChargeSure = _chargeSure != null && b.canStart;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusDisc(icon: statusIcon, color: statusColor, pulsing: b.status == 'PENDING'),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                        child: Column(
                          key: ValueKey(b.status),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headline,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: vc.ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(detail, style: TextStyle(color: vc.muted, height: 1.35)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!cancelled) ...[const SizedBox(height: Gap.xl), _Tracker(done: _stagesDone(b.status))],
              ],
            ),
          ),
        ),
        // ChargeSure slides in when the booked charger drops offline, and out when it's back.
        AnimatedSize(
          duration: Motion.slow,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: showChargeSure
              ? Padding(
                  padding: const EdgeInsets.only(top: Gap.lg),
                  child: Entrance(
                    child: ChargeSurePanel(
                      failedChargerName: b.chargerName,
                      options: _chargeSure!,
                      movingToId: _movingTo,
                      onMove: _moveTo,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: Gap.lg),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c != null && !cancelled) SizedBox(height: 150, child: ChargerMapSnippet(charger: c)),
              Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.chargerName,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: vc.ink),
                    ),
                    const SizedBox(height: Gap.xs),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 18, color: vc.muted),
                        const SizedBox(width: 6),
                        Text(
                          '${clock(b.start)} – ${clock(b.end)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vc.ink),
                        ),
                      ],
                    ),
                    if (c != null) ...[
                      const SizedBox(height: Gap.sm),
                      Text(
                        '${c.connectorLabel} · ${pricePerKwh(c.priceNowPaise)} · hosted by ${c.hostName}',
                        style: TextStyle(color: vc.muted),
                      ),
                      const Divider(height: Gap.xl),
                      // The address swaps in, in place, the moment the host confirms.
                      AnimatedSize(
                        duration: Motion.medium,
                        curve: Motion.enter,
                        alignment: Alignment.topLeft,
                        child: AnimatedSwitcher(
                          duration: Motion.medium,
                          child: Row(
                            key: ValueKey(c.exactLocation),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                c.exactLocation ? Icons.place : Icons.lock_outline,
                                color: c.exactLocation ? vc.brand : vc.faint,
                              ),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: Text(
                                  c.exactLocation ? c.address ?? '' : 'Exact address unlocks once the host confirms.',
                                  style: TextStyle(color: c.exactLocation ? vc.ink : vc.muted, height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (b.creditPaise > 0) ...[
                      const SizedBox(height: Gap.md),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
                        decoration: BoxDecoration(color: vc.brandTint, borderRadius: BorderRadius.circular(Radii.md)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: vc.brand),
                            const SizedBox(width: 6),
                            Text(
                              'ChargeSure credit: ${rupees(b.creditPaise)}',
                              style: TextStyle(color: vc.brand, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The one thing to do next for this booking's status, with quieter options beneath it.
  Widget? _buildActions(Booking b) {
    final vc = context.vc;
    final cancel = b.canCancel
        ? TextButton(
            style: TextButton.styleFrom(foregroundColor: vc.muted),
            onPressed: _busy ? null : _confirmCancel,
            child: const Text('Cancel booking'),
          )
        : null;
    final arrived = b.status == 'CONFIRMED'
        ? OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.place),
            label: const Text('I’ve arrived'),
            onPressed: _busy ? null : () => _act('arrive'),
          )
        : null;
    Widget? below() {
      if (arrived == null && cancel == null) return null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arrived != null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: arrived,
            ),
          ?cancel,
        ],
      );
    }

    if (b.canStart && _chargeSure == null) {
      return PrimaryBar(
        icon: Icons.qr_code_scanner,
        label: 'Scan QR to start charging',
        onPressed: _busy ? null : () => _open(ScanScreen(booking: b, user: widget.user)),
        secondary: below(),
      );
    }
    if (b.status == 'CHARGING' && b.sessionId != null) {
      return PrimaryBar(
        icon: Icons.bolt,
        label: 'View live charging',
        onPressed: () => _open(LiveSessionScreen(sessionId: b.sessionId!, user: widget.user)),
      );
    }
    if (b.status == 'COMPLETED' && b.sessionId != null) {
      return PrimaryBar(
        icon: Icons.receipt_long,
        label: 'View bill',
        onPressed: () => _open(BillScreen(bookingId: b.id, sessionId: b.sessionId!, user: widget.user)),
      );
    }
    // Pending, or offline with ChargeSure's own buttons above: only the quieter options remain.
    final rest = below();
    if (rest == null) return null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: vc.card,
        border: Border(top: BorderSide(color: vc.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm), child: rest),
      ),
    );
  }
}

/// The status icon in a tinted disc; it breathes while the host hasn't answered.
class _StatusDisc extends StatelessWidget {
  const _StatusDisc({required this.icon, required this.color, required this.pulsing});

  final IconData icon;
  final Color color;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final disc = AnimatedContainer(
      duration: Motion.medium,
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
      child: AnimatedSwitcher(
        duration: Motion.medium,
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: Icon(icon, key: ValueKey(icon), color: color, size: 28),
      ),
    );
    if (!pulsing || Motion.reduced(context)) return disc;
    return disc
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.08, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut);
  }
}

/// Order-tracking style progress: a dot per stage, joined by a line that fills as stages complete.
class _Tracker extends StatelessWidget {
  const _Tracker({required this.done});

  /// Number of completed stages; the one after them is in progress.
  final int done;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final duration = Motion.reduced(context) ? Duration.zero : Motion.slow;
    final current = done < _stages.length ? _stages[done] : _stages.last;
    return Semantics(
      label: done >= _stages.length
          ? 'Progress: all stages done'
          : 'Progress: $done of ${_stages.length} done, next is $current',
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              children: [
                for (final i in Iterable<int>.generate(_stages.length)) ...[
                  if (i > 0)
                    Expanded(
                      child: Stack(
                        children: [
                          Container(height: 3, color: vc.raised),
                          AnimatedFractionallySizedBox(
                            duration: duration,
                            curve: Motion.enter,
                            widthFactor: i < done ? 1 : 0,
                            child: Container(height: 3, color: vc.brand),
                          ),
                        ],
                      ),
                    ),
                  AnimatedContainer(
                    duration: duration,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < done ? vc.brand : vc.card,
                      border: Border.all(color: i <= done ? vc.brand : vc.border, width: 2),
                    ),
                    child: i < done
                        ? Icon(Icons.check, size: 16, color: vc.onBrand)
                        : i == done
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: vc.brand, shape: BoxShape.circle),
                            ),
                          )
                        : null,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Gap.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Five equal columns, so the row always fits; a label too long for its
                // column (narrow phone, large text) shrinks rather than overflowing.
                for (final (i, stage) in _stages.indexed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: i == 0
                            ? Alignment.centerLeft
                            : i == _stages.length - 1
                            ? Alignment.centerRight
                            : Alignment.center,
                        child: Text(
                          stage,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i <= done ? FontWeight.w700 : FontWeight.w500,
                            color: i <= done ? vc.ink : vc.faint,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
