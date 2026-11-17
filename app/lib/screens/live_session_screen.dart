import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/snack.dart';
import '../widgets/stat_tile.dart';
import 'bill_screen.dart';

/// Readings arrive every 2 s; the big figures roll from one to the next over most of that gap,
/// so the meter looks like it is running rather than jumping.
const _pollEvery = Duration(seconds: 2);
const _roll = Duration(milliseconds: 1800);

/// Live readings from the smart plug, polled every 2 s, with the running cost.
/// Always navy, in both themes.
class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({super.key, required this.sessionId, required this.user});

  final int sessionId;
  final AppUser user;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  LiveSession? _live;
  String? _error;
  bool _stopping = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollEvery, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final live = await api.liveSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _live = live;
        _error = null;
      });
      if (live.completed) _poll?.cancel();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop charging?'),
        content: const Text('Power switches off and your bill is calculated from the meter.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep charging')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.vc.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _stopping = true);
    _poll?.cancel();
    try {
      final done = await api.stopSession(widget.sessionId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _openBill(done);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _stopping = false);
      showSnack(context, e.message);
      _poll = Timer.periodic(_pollEvery, (_) => _load());
    }
  }

  void _openBill(LiveSession s) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => BillScreen(bookingId: s.bookingId, sessionId: s.sessionId, user: widget.user),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final live = _live;
    return Scaffold(
      backgroundColor: VoltraColors.navy,
      appBar: darkAppBar('Charging'),
      body: live == null
          ? (_error != null
                ? Theme(
                    data: buildTheme(Brightness.dark),
                    child: ErrorView(message: _error!, onRetry: _load),
                  )
                : const Center(child: CircularProgressIndicator(color: VoltraColors.green)))
          : _buildBody(live),
    );
  }

  Widget _buildBody(LiveSession s) {
    const soft = VoltraColors.onNavySoft;
    final charging = !s.completed && s.online;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.completed ? 'Session complete' : 'Charging at ${s.chargerName}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (s.demoSpeed != 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: VoltraColors.navyRaised,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        'Demo speed ×${s.demoSpeed.round()}',
                        style: const TextStyle(color: soft, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Gap.xl),
              Center(
                child: _ChargingRing(
                  spinning: charging,
                  done: s.completed,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        s.completed
                            ? Icons.task_alt
                            : s.online
                            ? Icons.bolt
                            : Icons.cloud_off,
                        color: s.online || s.completed ? VoltraColors.green : VoltraColors.onNavySoft,
                        size: 28,
                      ),
                      const SizedBox(height: Gap.xs),
                      CountUp(
                        value: s.energyKwh,
                        duration: _roll,
                        format: (v) => v.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -1.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Text(
                        'kWh delivered',
                        style: TextStyle(color: soft, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.xl),
              Center(
                child: Column(
                  children: [
                    const Text('Cost so far', style: TextStyle(color: soft)),
                    CountUp(
                      value: s.costPaise.toDouble(),
                      duration: _roll,
                      format: (v) => rupees(v.round(), exact: true),
                      style: const TextStyle(
                        color: VoltraColors.green,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (!s.online && !s.completed) ...[
                const SizedBox(height: Gap.lg),
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: VoltraPalette.dark.warningTint,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: VoltraPalette.dark.warning),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'No reading from the charger right now. Charging resumes reporting when it reconnects.',
                          style: TextStyle(color: VoltraPalette.dark.warning, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Gap.xl),
              GridView(
                gridDelegate: statGridDelegate(context, compact: true),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatTile(
                    tone: StatTone.onNavy,
                    compact: true,
                    label: 'Power',
                    value: Text('${s.powerKw.toStringAsFixed(2)} kW'),
                  ),
                  StatTile(tone: StatTone.onNavy, compact: true, label: 'Duration', value: Text(elapsed(s.durationS))),
                  StatTile(
                    tone: StatTone.onNavy,
                    compact: true,
                    label: 'Voltage',
                    value: Text(s.voltage == null ? '–' : '${s.voltage!.round()} V'),
                  ),
                  StatTile(
                    tone: StatTone.onNavy,
                    compact: true,
                    label: 'Current',
                    value: Text(s.current == null ? '–' : '${s.current} A'),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Text(
                'Rate ${pricePerKwh(s.pricePerKwhPaise)} · measured by the charger’s smart meter',
                textAlign: TextAlign.center,
                style: const TextStyle(color: soft, fontSize: 13),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.lg),
            child: s.completed
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: VoltraColors.green,
                      foregroundColor: VoltraColors.navy,
                    ),
                    onPressed: () => _openBill(s),
                    child: const Text('View bill'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD9382E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: VoltraColors.navyRaised,
                    ),
                    icon: _stopping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.stop_circle_outlined),
                    label: const Text('Stop charging'),
                    onPressed: _stopping ? null : _stop,
                  ),
          ),
        ),
      ],
    );
  }
}

/// A ring around the meter reading. While power flows, a bright arc travels round it;
/// when the session is done the ring closes.
class _ChargingRing extends StatefulWidget {
  const _ChargingRing({required this.child, required this.spinning, required this.done});

  final Widget child;
  final bool spinning;
  final bool done;

  @override
  State<_ChargingRing> createState() => _ChargingRingState();
}

class _ChargingRingState extends State<_ChargingRing> with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ChargingRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.spinning && !Motion.reduced(context);
    if (run && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!run && _turn.isAnimating) {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 250,
      child: AnimatedBuilder(
        animation: _turn,
        builder: (_, child) => CustomPaint(
          painter: _RingPainter(turn: _turn.value, spinning: widget.spinning, done: widget.done),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.turn, required this.spinning, required this.done});

  final double turn;
  final bool spinning;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = done ? VoltraColors.green : VoltraColors.navyRaised;
    canvas.drawArc(ring, 0, math.pi * 2, false, track);
    if (done || !spinning) return;
    final start = turn * math.pi * 2 - math.pi / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [VoltraColors.green.withValues(alpha: 0), VoltraColors.green],
        stops: const [0, 0.3],
        transform: GradientRotation(start),
      ).createShader(rect);
    canvas.drawArc(ring, start + 0.05, math.pi * 0.6, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.turn != turn || old.spinning != spinning || old.done != done;
}
