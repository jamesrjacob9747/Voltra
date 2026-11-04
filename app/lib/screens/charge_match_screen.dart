import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/confidence_badge.dart';
import 'booking_screen.dart';

/// ChargeMatch: the driver states a need; Voltra ranks the chargers that can meet it.
class ChargeMatchScreen extends StatefulWidget {
  const ChargeMatchScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ChargeMatchScreen> createState() => _ChargeMatchScreenState();
}

class _ChargeMatchScreenState extends State<ChargeMatchScreen> {
  List<Vehicle>? _vehicles;
  Vehicle? _vehicle;
  double _current = 25;
  double _target = 80;
  TimeOfDay? _readyBy;
  double _radiusKm = 2;
  String? _error;

  bool _searching = false;
  List<MatchResult>? _results;
  int? _reservingId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final vehicles = await api.vehicles(widget.user.id);
      final now = await api.serverNow();
      setState(() {
        _vehicles = vehicles;
        _vehicle = vehicles.isEmpty ? null : vehicles.first;
        final ready = now.add(const Duration(hours: 3));
        _readyBy = TimeOfDay(hour: ready.hour, minute: ready.minute - ready.minute % 15);
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  String get _readyByParam {
    final t = _readyBy!;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get _readyByLabel => clock(DateTime(2000, 1, 1, _readyBy!.hour, _readyBy!.minute));

  Future<void> _pickReadyBy() async {
    final picked = await showTimePicker(context: context, initialTime: _readyBy!);
    if (picked != null) setState(() => _readyBy = picked);
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _results = null;
    });
    try {
      final results = await api.match(
        vehicleId: _vehicle!.id,
        currentPct: _current.round(),
        targetPct: _target.round(),
        readyBy: _readyByParam,
        lat: demoLocation.latitude,
        lng: demoLocation.longitude,
        radiusKm: _radiusKm,
      );
      setState(() => _results = results);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _reserve(MatchResult r) async {
    setState(() => _reservingId = r.charger.id);
    try {
      final booking = await api.createBooking(
        driverId: widget.user.id,
        chargerId: r.charger.id,
        vehicleId: _vehicle!.id,
        start: r.estimate.arriveAt,
        end: r.estimate.finishAt,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingScreen(bookingId: booking.id, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _reservingId = null);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find me a charge')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _vehicles == null
          ? const Center(child: CircularProgressIndicator())
          : _vehicle == null
          ? const Center(child: Text('Add a vehicle to use ChargeMatch.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildForm(),
                const SizedBox(height: 16),
                if (_searching) const Center(child: CircularProgressIndicator()),
                if (_results != null) ..._buildResults(_results!),
              ],
            ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vehicles!.length > 1)
              DropdownButtonFormField<Vehicle>(
                initialValue: _vehicle,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: [for (final v in _vehicles!) DropdownMenuItem(value: v, child: Text(v.model))],
                onChanged: (v) => setState(() => _vehicle = v),
              )
            else
              Row(
                children: [
                  const Icon(Icons.electric_scooter, color: VoltraColors.darkGreen),
                  const SizedBox(width: 8),
                  Text(_vehicle!.model, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(width: 8),
                  Text('${_vehicle!.batteryKwh} kWh', style: const TextStyle(color: VoltraColors.muted)),
                ],
              ),
            const SizedBox(height: 16),
            _sliderRow('Battery now', _current, (v) {
              setState(() {
                _current = v;
                if (_target <= v) _target = (v + 5).clamp(0, 100);
              });
            }),
            _sliderRow('Charge to', _target, (v) => setState(() => _target = v < _current + 5 ? _current + 5 : v)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Ready by', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(_readyByLabel),
                  onPressed: _pickReadyBy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text('Within', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1 km')),
                    ButtonSegment(value: 2, label: Text('2 km')),
                    ButtonSegment(value: 5, label: Text('5 km')),
                  ],
                  selected: {_radiusKm},
                  onSelectionChanged: (s) => setState(() => _radiusKm = s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.bolt),
              label: const Text('Find my charger'),
              onPressed: _searching ? null : _search,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${value.round()}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text('${value.round()}%', textAlign: TextAlign.right)),
      ],
    );
  }

  List<Widget> _buildResults(List<MatchResult> results) {
    if (results.isEmpty) {
      return [
        Text(
          'No charger can get you to ${_target.round()}% by $_readyByLabel within ${_radiusKm.toInt()} km. '
          'Try a later time or a bigger radius.',
          style: const TextStyle(color: VoltraColors.muted),
        ),
      ];
    }
    return [
      for (final (i, r) in results.indexed) ...[
        _ResultCard(
          result: r,
          best: i == 0,
          reserving: _reservingId == r.charger.id,
          onReserve: _reservingId == null ? () => _reserve(r) : null,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.best, required this.reserving, required this.onReserve});

  final MatchResult result;
  final bool best;
  final bool reserving;
  final VoidCallback? onReserve;

  @override
  Widget build(BuildContext context) {
    final c = result.charger;
    final e = result.estimate;
    return Card(
      shape: best
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: VoltraColors.darkGreen, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (best)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'BEST MATCH',
                  style: TextStyle(color: VoltraColors.darkGreen, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Text('${result.score.round()}/100', style: const TextStyle(color: VoltraColors.muted)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${distance(c.distanceKm ?? 0)} · ${pricePerKwh(c.priceNowPaise)}'),
                ConfidenceBadge(confidence: c.confidence, online: c.online),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _Stat(label: 'Arrive', value: clock(e.arriveAt)),
                _Stat(label: 'Ready', value: clock(e.finishAt)),
                _Stat(label: 'Charging', value: minutes(e.chargeMinutes)),
                _Stat(label: 'Est. cost', value: rupees(e.estCostPaise)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${e.energyKwh} kWh at ${e.powerKw} kW (your vehicle’s charging limit)',
              style: const TextStyle(color: VoltraColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onReserve,
              child: reserving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Reserve ${clock(e.arriveAt)}–${clock(e.finishAt)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: VoltraColors.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
