import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../config.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/primary_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/snack.dart';
import 'booking_screen.dart';

/// ChargeMatch: the driver states a need; Voltra ranks the chargers that can meet it.
class ChargeMatchScreen extends StatefulWidget {
  const ChargeMatchScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ChargeMatchScreen> createState() => _ChargeMatchScreenState();
}

class _ChargeMatchScreenState extends State<ChargeMatchScreen> {
  final _resultsKey = GlobalKey();

  List<Vehicle>? _vehicles;
  Vehicle? _vehicle;
  double _current = 25;
  double _target = 80;
  TimeOfDay? _readyBy;
  double _radiusKm = 2;
  Duration _clockOffset = Duration.zero; // server time minus phone time; ready-by is server-local
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
    setState(() => _error = null);
    try {
      // Independent requests, fetched at once. Future.wait rethrows the original ApiException.
      final results = await Future.wait([api.vehicles(widget.user.id), api.serverNow()]);
      final vehicles = results[0] as List<Vehicle>;
      final now = results[1] as DateTime;
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _vehicle = vehicles.isEmpty ? null : vehicles.first;
        _clockOffset = now.difference(DateTime.now());
        final ready = now.add(const Duration(hours: 3));
        _readyBy = TimeOfDay(hour: ready.hour, minute: ready.minute - ready.minute % 15);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String get _readyByParam {
    final t = _readyBy!;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get _readyByLabel => readyByLabel(_readyBy!.hour, _readyBy!.minute, DateTime.now().add(_clockOffset));

  /// Energy the charge needs from the socket, the way the server works it out:
  /// the battery share, divided by 0.9 for charging losses.
  double get _neededKwh => (_target - _current) / 100 * _vehicle!.batteryKwh / 0.9;

  /// Any change to the need makes the shown results stale, so they are cleared until the next search.
  void _changeNeed(VoidCallback change) => setState(() {
    change();
    _results = null;
  });

  Future<void> _pickReadyBy() async {
    final picked = await showTimePicker(context: context, initialTime: _readyBy!);
    if (picked != null) _changeNeed(() => _readyBy = picked);
  }

  void _showResults() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final target = _resultsKey.currentContext;
    if (target != null && target.mounted) {
      Scrollable.ensureVisible(target, duration: Motion.slow, curve: Motion.enter, alignment: 0.02);
    }
  });

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _results = null;
    });
    _showResults();
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
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _results = results);
      _showResults();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// Reserves the match's slot, or the cheaper later slot when [later] is given.
  Future<void> _reserve(MatchResult r, {CheaperLater? later}) async {
    setState(() => _reservingId = r.charger.id);
    try {
      final booking = await api.createBooking(
        driverId: widget.user.id,
        chargerId: r.charger.id,
        vehicleId: _vehicle!.id,
        start: later?.startAt ?? r.estimate.arriveAt,
        end: later?.finishAt ?? r.estimate.finishAt,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingScreen(bookingId: booking.id, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.message);
      setState(() => _reservingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _vehicle != null;
    final Widget body;
    if (_error != null) {
      body = ErrorView(message: _error!, onRetry: _init);
    } else if (_vehicles == null) {
      body = const Shimmer(
        child: Padding(
          padding: EdgeInsets.all(Gap.lg),
          child: Column(
            children: [
              Skeleton(height: 150, radius: Radii.lg),
              SizedBox(height: Gap.lg),
              Skeleton(height: 260, radius: Radii.lg),
            ],
          ),
        ),
      );
    } else if (!ready) {
      body = const EmptyState(
        icon: Icons.electric_scooter,
        title: 'No vehicle on this account',
        hint: 'ChargeMatch needs your vehicle’s battery size to work out the charge.',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
        children: [
          Entrance(child: _buildNeed()),
          const SizedBox(height: Gap.lg),
          Entrance(index: 1, child: _buildForm()),
          SizedBox(key: _resultsKey, height: Gap.lg),
          if (_searching)
            const SkeletonList(item: ChargerCardSkeleton(), count: 3, padding: EdgeInsets.zero)
          else if (_results != null)
            ..._buildResults(_results!),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Find me a charge')),
      body: body,
      bottomNavigationBar: ready && _error == null
          ? PrimaryBar(
              icon: Icons.bolt,
              label: 'Find my charger',
              busy: _searching,
              onPressed: _reservingId == null ? _search : null,
            )
          : null,
    );
  }

  /// The need at a glance: a battery that fills as the sliders move, and the energy it takes.
  Widget _buildNeed() {
    final v = _vehicle!;
    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: const BoxDecoration(color: VoltraColors.navy, borderRadius: Radii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.electric_scooter, color: VoltraColors.green, size: 20),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  '${v.model} · ${v.batteryKwh} kWh',
                  style: const TextStyle(color: VoltraColors.onNavySoft, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          _BatteryBar(current: _current / 100, target: _target / 100),
          const SizedBox(height: Gap.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_current.round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Gap.sm),
                child: Icon(Icons.arrow_forward_rounded, color: VoltraColors.onNavySoft),
              ),
              Text(
                '${_target.round()}%',
                style: const TextStyle(color: VoltraColors.green, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_neededKwh.toStringAsFixed(1)} kWh',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Text('to add, about', style: TextStyle(color: VoltraColors.onNavySoft, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final vc = context.vc;
    final label = TextStyle(fontWeight: FontWeight.w700, color: vc.ink);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_vehicles!.length > 1) ...[
              DropdownButtonFormField<Vehicle>(
                initialValue: _vehicle,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: [for (final v in _vehicles!) DropdownMenuItem(value: v, child: Text(v.model))],
                onChanged: (v) => _changeNeed(() => _vehicle = v),
              ),
              const SizedBox(height: Gap.lg),
            ],
            _sliderRow('Battery now', _current, (v) {
              _changeNeed(() {
                _current = v;
                if (_target <= v) _target = (v + 5).clamp(0, 100);
              });
            }),
            _sliderRow('Charge to', _target, (v) => _changeNeed(() => _target = v < _current + 5 ? _current + 5 : v)),
            const Divider(height: Gap.xl),
            Row(
              children: [
                Expanded(child: Text('Ready by', style: label)),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule, size: 20),
                  label: Text(_readyByLabel),
                  onPressed: _pickReadyBy,
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(child: Text('Within', style: label)),
                SegmentedButton<double>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1 km')),
                    ButtonSegment(value: 2, label: Text('2 km')),
                    ButtonSegment(value: 5, label: Text('5 km')),
                  ],
                  selected: {_radiusKm},
                  onSelectionChanged: (s) => _changeNeed(() => _radiusKm = s.first),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(String label, double value, ValueChanged<double> onChanged) {
    final vc = context.vc;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: vc.ink),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${value.round()}%',
            semanticFormatterCallback: (v) => '${v.round()} percent',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${value.round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w700, color: vc.ink),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResults(List<MatchResult> results) {
    final vc = context.vc;
    if (results.isEmpty) {
      return [
        EmptyState(
          compact: true,
          icon: Icons.search_off,
          title: 'No charger fits this yet',
          hint:
              'Nothing can get you to ${_target.round()}% by $_readyByLabel within ${_radiusKm.toInt()} km. '
              'Try a later time or a bigger radius.',
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: Gap.md),
        child: Text(
          results.length == 1 ? '1 charger can do this' : '${results.length} chargers can do this',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: vc.ink),
        ),
      ),
      for (final (i, r) in results.indexed) ...[
        Entrance(
          index: i,
          child: _ResultCard(
            result: r,
            best: i == 0,
            reserving: _reservingId == r.charger.id,
            onReserve: _reservingId == null ? () => _reserve(r) : null,
            onReserveLater: _reservingId == null && r.estimate.cheaperLater != null
                ? () => _reserve(r, later: r.estimate.cheaperLater)
                : null,
          ),
        ),
        const SizedBox(height: Gap.md),
      ],
    ];
  }
}

/// A battery outline: solid green up to the charge it has now, a soft green up to the target.
class _BatteryBar extends StatelessWidget {
  const _BatteryBar({required this.current, required this.target});

  final double current;
  final double target;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.reduced(context) ? Duration.zero : Motion.medium;
    return Semantics(
      label: 'Battery from ${(current * 100).round()} to ${(target * 100).round()} percent',
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: Colors.white38, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm - 2),
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      AnimatedContainer(
                        duration: duration,
                        curve: Motion.enter,
                        width: box.maxWidth * target.clamp(0, 1),
                        color: VoltraColors.green.withValues(alpha: 0.3),
                      ),
                      AnimatedContainer(
                        duration: duration,
                        curve: Motion.enter,
                        width: box.maxWidth * current.clamp(0, 1),
                        color: VoltraColors.green,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The battery's terminal.
          Container(
            width: 5,
            height: 18,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.best,
    required this.reserving,
    required this.onReserve,
    required this.onReserveLater,
  });

  final MatchResult result;
  final bool best;
  final bool reserving;
  final VoidCallback? onReserve;
  final VoidCallback? onReserveLater;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final c = result.charger;
    final e = result.estimate;
    return Container(
      decoration: BoxDecoration(
        color: vc.card,
        borderRadius: Radii.card,
        border: Border.all(color: best ? vc.brand : vc.border, width: best ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (best)
            Container(
              color: vc.brand,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: vc.onBrand),
                  const SizedBox(width: 6),
                  Text(
                    'BEST MATCH',
                    style: TextStyle(color: vc.onBrand, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 12),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: vc.ink),
                      ),
                    ),
                    Semantics(
                      label: 'Match score ${result.score.round()} out of 100',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: vc.raised, borderRadius: BorderRadius.circular(Radii.pill)),
                        child: ExcludeSemantics(
                          child: Text(
                            '${result.score.round()}/100',
                            style: TextStyle(color: vc.muted, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${distance(c.distanceKm ?? 0)} · ${pricePerKwh(c.priceNowPaise)}',
                      style: TextStyle(color: vc.muted),
                    ),
                    ConfidenceBadge(confidence: c.confidence, online: c.online),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: Gap.md, horizontal: Gap.sm),
                  decoration: BoxDecoration(color: vc.raised, borderRadius: BorderRadius.circular(Radii.md)),
                  child: Row(
                    children: [
                      _Stat(label: 'Arrive', value: clock(e.arriveAt)),
                      _Stat(label: 'Ready', value: clock(e.finishAt)),
                      _Stat(label: 'Charging', value: minutes(e.chargeMinutes)),
                      _Stat(label: 'Est. cost', value: rupees(e.estCostPaise)),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  '${e.energyKwh} kWh at ${e.powerKw} kW (your vehicle’s charging limit)',
                  style: TextStyle(color: vc.muted, fontSize: 12),
                ),
                const SizedBox(height: Gap.md),
                FilledButton(
                  onPressed: onReserve,
                  child: reserving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: vc.brand),
                        )
                      : Text('Reserve ${clock(e.arriveAt)}–${clock(e.finishAt)}'),
                ),
                if (e.cheaperLater case final later?) ...[
                  const SizedBox(height: Gap.md),
                  _CheaperLaterOffer(later: later, arriveAt: e.arriveAt, onReserve: onReserveLater),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Charge later, save ₹X": the same charge in a cheaper (off-peak) slot that still meets ready-by.
class _CheaperLaterOffer extends StatelessWidget {
  const _CheaperLaterOffer({required this.later, required this.arriveAt, required this.onReserve});

  final CheaperLater later;
  final DateTime arriveAt;
  final VoidCallback? onReserve;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final nextDay = later.startAt.day != arriveAt.day;
    final start = '${clock(later.startAt)}${nextDay ? ' (tonight)' : ''}';
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(color: vc.brandTint, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nightlight_round, size: 18, color: vc.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Charge later, save ${rupees(later.savingPaise, exact: true)}',
                  style: TextStyle(color: vc.brand, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Start $start at ${pricePerKwh(later.pricePerKwhPaise)} and still be ready by ${clock(later.finishAt)}. '
            'Total ≈ ${rupees(later.estCostPaise)}. Off-peak charging also eases the grid.',
            style: TextStyle(color: vc.ink, height: 1.35),
          ),
          const SizedBox(height: Gap.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: vc.brand),
            ),
            onPressed: onReserve,
            child: Text('Reserve ${clock(later.startAt)}–${clock(later.finishAt)} instead'),
          ),
        ],
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
    final vc = context.vc;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w800, color: vc.ink, fontSize: 15),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: vc.muted)),
        ],
      ),
    );
  }
}
