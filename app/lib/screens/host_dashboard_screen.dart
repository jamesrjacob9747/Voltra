import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/error_view.dart';
import '../widgets/snack.dart';
import 'add_charger_screen.dart';
import 'map_screen.dart';
import 'user_picker_screen.dart';

/// Host home: booking requests to answer, what's coming up, today's earnings and the live session.
class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  HostDashboard? _data;
  List<Charger> _chargers = const [];
  String? _error;
  final Set<int> _busy = {};
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
      // Independent requests, fetched at once. Future.wait rethrows the original ApiException.
      final results = await Future.wait([api.hostDashboard(widget.user.id), api.hostChargers(widget.user.id)]);
      if (mounted) {
        setState(() {
          _data = results[0] as HostDashboard;
          _chargers = results[1] as List<Charger>;
          _error = null;
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
      if (mounted) {
        showSnack(context, action == 'accept' ? 'Accepted ${b.driverName}’s booking' : 'Declined the booking');
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  Future<void> _addCharger() async {
    final added = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => AddChargerScreen(user: widget.user)));
    if (added == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VoltraColors.darkGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add charger'),
        onPressed: _addCharger,
      ),
      appBar: AppBar(
        title: Text('Host · ${widget.user.name}'),
        actions: [
          if (widget.user.canDrive)
            IconButton(
              tooltip: 'Find a charger',
              icon: const Icon(Icons.map_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacement(MaterialPageRoute(builder: (_) => MapScreen(user: widget.user))),
            ),
          IconButton(
            tooltip: 'Switch user',
            icon: const Icon(Icons.switch_account),
            onPressed: () =>
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const UserPickerScreen())),
          ),
        ],
      ),
      body: _data == null
          ? (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(onRefresh: _load, child: _buildBody(_data!)),
    );
  }

  Widget _buildBody(HostDashboard d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), // room above the Add charger button
      children: [
        const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: [
            _StatTile(label: 'Earned', value: rupees(d.earningsPaise), highlight: true),
            _StatTile(label: 'Awaiting payment', value: rupees(d.pendingEarningsPaise)),
            _StatTile(label: 'Energy sold', value: '${d.energySoldKwh} kWh'),
            _StatTile(label: 'Bookings', value: '${d.todayBookings}'),
          ],
        ),
        if (d.liveSession != null) ...[const SizedBox(height: 20), _LiveSessionCard(session: d.liveSession!)],
        const SizedBox(height: 20),
        _sectionTitle('Requests', d.requests.length),
        if (d.requests.isEmpty)
          const _Empty('No booking requests right now.')
        else
          for (final b in d.requests) _RequestCard(booking: b, busy: _busy.contains(b.id), onAnswer: _answer),
        const SizedBox(height: 20),
        _sectionTitle('Upcoming', d.upcoming.length),
        if (d.upcoming.isEmpty)
          const _Empty('Nothing confirmed yet.')
        else
          for (final b in d.upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.event_available, color: VoltraColors.darkGreen),
                  title: Text(b.driverName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${b.chargerName}\n${clock(b.start)} – ${clock(b.end)}'),
                  isThreeLine: true,
                ),
              ),
            ),
        const SizedBox(height: 20),
        _sectionTitle('My chargers', _chargers.length),
        if (_chargers.isEmpty)
          const _Empty('No chargers yet. Tap “Add charger” to list your first one.')
        else
          for (final c in _chargers) _MyChargerCard(charger: c),
      ],
    );
  }

  Widget _sectionTitle(String title, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('$title ($count)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
  );
}

class _MyChargerCard extends StatelessWidget {
  const _MyChargerCard({required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final c = charger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: VoltraColors.navy, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      c.deviceId,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${c.connectorLabel} · ${pricePerKwh(c.basePricePaise)} · open ${c.availableFrom}–${c.availableTo}',
                style: const TextStyle(color: VoltraColors.muted),
              ),
              const SizedBox(height: 8),
              ConfidenceBadge(confidence: c.confidence, online: c.online),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? VoltraColors.navy : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: highlight ? const Color(0xFFB8C4D0) : VoltraColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: highlight ? VoltraColors.green : VoltraColors.ink,
              ),
            ),
          ],
        ),
      ),
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
    final b = booking;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VoltraColors.amber, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: VoltraColors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${b.driverName} wants to charge',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${b.chargerName} · ${clock(b.start)} – ${clock(b.end)}',
                style: const TextStyle(color: VoltraColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : () => onAnswer(b, 'decline'),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                      onPressed: busy ? null : () => onAnswer(b, 'accept'),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    return Card(
      color: VoltraColors.navy,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: VoltraColors.green),
                const SizedBox(width: 6),
                Text(
                  'Charging now · ${charger['name']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _liveStat('Power', '${session['power_kw']} kW'),
                _liveStat('Energy', '${session['energy_kwh']} kWh'),
                _liveStat('So far', rupees(session['cost_paise'] as int, exact: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveStat(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFB8C4D0))),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: const TextStyle(color: VoltraColors.muted)),
  );
}
