import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/skeleton.dart';
import '../widgets/snack.dart';
import '../widgets/stat_tile.dart';

/// Host home: booking requests to answer, what's coming up, today's earnings and the live session.
/// The host's chargers live in the Chargers tab (host_chargers_screen.dart).
class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  HostDashboard? _data;
  String? _error;
  final Set<int> _busy = {};

  /// Requests just answered, and how: their cards slide away before the list reloads.
  final Map<int, String> _answered = {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await api.hostDashboard(widget.user.id);
      if (mounted) {
        // A buzz when a new request comes in while the dashboard is open.
        final before = _data?.requests.length;
        if (before != null && data.requests.length > before) HapticFeedback.mediumImpact();
        setState(() {
          _data = data;
          _error = null;
          _answered.removeWhere((id, _) => !data.requests.any((b) => b.id == id));
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _answer(Booking b, String action) async {
    setState(() => _busy.add(b.id));
    try {
      await api.updateBooking(b.id, action, actorId: widget.user.id);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _answered[b.id] = action);
      showSnack(context, action == 'accept' ? 'Accepted ${b.driverName}’s booking' : 'Declined the booking');
      // Let the card finish sliding away before the list underneath changes.
      await Future<void>.delayed(Motion.reduced(context) ? Duration.zero : Motion.slow);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: Text('Hi, ${widget.user.name}')),
      body: d == null
          ? (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Shimmer(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.lg),
                      child: Column(
                        children: [
                          Skeleton(height: 150, radius: Radii.lg),
                          SizedBox(height: Gap.md),
                          StatGridSkeleton(count: 2),
                          SizedBox(height: Gap.xl),
                          Skeleton(height: 120, radius: Radii.lg),
                        ],
                      ),
                    ),
                  ))
          : RefreshIndicator(onRefresh: _load, child: _buildBody(d)),
    );
  }

  Widget _buildBody(HostDashboard d) {
    final vc = context.vc;
    final open = d.requests.where((b) => !_answered.containsKey(b.id)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      children: [
        Entrance(
          child: _EarningsCard(earnedPaise: d.earningsPaise, pendingPaise: d.pendingEarningsPaise),
        ),
        const SizedBox(height: Gap.md),
        Entrance(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.bolt,
                  label: 'Energy sold today',
                  value: CountUp(value: d.energySoldKwh, format: (v) => '${v.toStringAsFixed(1)} kWh'),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: StatTile(
                  icon: Icons.event_available,
                  label: 'Bookings today',
                  value: CountUp(value: d.todayBookings.toDouble(), format: (v) => '${v.round()}'),
                ),
              ),
            ],
          ),
        ),
        // The live session card drops in when a driver starts charging.
        AnimatedSize(
          duration: Motion.slow,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: d.liveSession == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Gap.md),
                  child: _LiveSessionCard(session: d.liveSession!),
                ),
        ),
        SectionHeader('Requests', count: open),
        if (d.requests.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.notifications_none,
            title: 'No requests right now',
            hint: 'New booking requests show up here, and you’ll get a notification.',
          )
        else
          for (final b in d.requests)
            _Leaving(
              key: ValueKey('request-${b.id}'),
              action: _answered[b.id],
              child: _RequestCard(booking: b, busy: _busy.contains(b.id), onAnswer: _answer),
            ),
        SectionHeader('Upcoming', count: d.upcoming.length),
        if (d.upcoming.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.event_outlined,
            title: 'Nothing confirmed yet',
            hint: 'Accepted bookings wait here until the driver arrives.',
          )
        else
          for (final (i, b) in d.upcoming.indexed)
            Entrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    color: vc.card,
                    borderRadius: Radii.card,
                    border: Border.all(color: vc.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: vc.brandTint,
                        foregroundColor: vc.brand,
                        child: Text(
                          b.driverName.isEmpty ? '?' : b.driverName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.driverName,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc.ink),
                            ),
                            Text(b.chargerName, style: TextStyle(color: vc.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      Text(
                        '${clock(b.start)}\n– ${clock(b.end)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontWeight: FontWeight.w700, color: vc.ink, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Today's money, as the headline of the dashboard.
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnedPaise, required this.pendingPaise});

  final int earnedPaise;
  final int pendingPaise;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: const BoxDecoration(color: VoltraColors.navy, borderRadius: Radii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: VoltraColors.green, size: 20),
              SizedBox(width: Gap.sm),
              Text(
                'Earned today',
                style: TextStyle(color: VoltraColors.onNavySoft, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          CountUp(
            value: earnedPaise.toDouble(),
            format: (v) => rupees(v.round()),
            style: const TextStyle(
              color: VoltraColors.green,
              fontSize: 46,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Gap.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
            decoration: BoxDecoration(color: VoltraColors.navyRaised, borderRadius: BorderRadius.circular(Radii.md)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top, size: 16, color: VoltraColors.onNavySoft),
                const SizedBox(width: 6),
                Text(
                  '${rupees(pendingPaise)} awaiting payment',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slides an answered request off to the side (right for accept, left for decline),
/// fading it and closing the gap it leaves.
class _Leaving extends StatelessWidget {
  const _Leaving({super.key, required this.action, required this.child});

  /// 'accept', 'decline', or null while the request is still waiting.
  final String? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gone = action != null;
    final duration = Motion.reduced(context) ? Duration.zero : Motion.slow;
    return AnimatedSize(
      duration: duration,
      curve: Motion.exit,
      alignment: Alignment.topCenter,
      child: gone
          ? AnimatedSlide(
              offset: Offset(action == 'accept' ? 1.2 : -1.2, 0),
              duration: duration,
              curve: Motion.exit,
              child: AnimatedOpacity(
                opacity: 0,
                duration: duration,
                child: SizedBox(
                  height: 0,
                  child: OverflowBox(maxHeight: double.infinity, child: child),
                ),
              ),
            )
          : AnimatedSlide(offset: Offset.zero, duration: duration, child: child),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.booking, required this.busy, required this.onAnswer});

  final Booking booking;
  final bool busy;
  final void Function(Booking, String) onAnswer;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final b = booking;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: vc.warningTint,
          borderRadius: Radii.card,
          border: Border.all(color: vc.warning, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: vc.warning),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    '${b.driverName} wants to charge',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: vc.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text('${b.chargerName} · ${clock(b.start)} – ${clock(b.end)}', style: TextStyle(color: vc.muted)),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(backgroundColor: vc.card),
                    onPressed: busy ? null : () => onAnswer(b, 'decline'),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: busy ? null : () => onAnswer(b, 'accept'),
                    child: busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: vc.brand),
                          )
                        : const Text('Accept'),
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

class _LiveSessionCard extends StatelessWidget {
  const _LiveSessionCard({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final charger = session['charger'] as Map<String, dynamic>;
    const bolt = Icon(Icons.bolt, color: VoltraColors.green);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: VoltraColors.navy,
        borderRadius: Radii.card,
        border: Border.all(color: VoltraColors.green, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The bolt pulses while power is flowing.
              if (Motion.reduced(context))
                bolt
              else
                bolt
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.35, end: 1, duration: const Duration(milliseconds: 800)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Charging now · ${charger['name']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              _liveStat('Power', '${session['power_kw']} kW'),
              _liveStat('Energy', '${session['energy_kwh']} kWh'),
              _liveStat('So far', rupees(session['cost_paise'] as int, exact: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveStat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: VoltraColors.onNavySoft)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
