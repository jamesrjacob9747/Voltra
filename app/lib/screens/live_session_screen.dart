import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import '../widgets/snack.dart';
import 'bill_screen.dart';

/// Live readings from the smart plug, polled every 2 s, with the running cost.
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
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _load());
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
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _stopping = true);
    _poll?.cancel();
    try {
      final done = await api.stopSession(widget.sessionId);
      if (!mounted) return;
      _openBill(done);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _stopping = false);
      showSnack(context, e.message);
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _load());
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
      appBar: AppBar(title: const Text('Charging')),
      body: live == null
          ? (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator(color: VoltraColors.green)))
          : _buildBody(live),
    );
  }

  Widget _buildBody(LiveSession s) {
    const soft = Color(0xFFB8C4D0);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(s.completed ? Icons.task_alt : Icons.bolt, color: VoltraColors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.completed ? 'Session complete' : 'Charging at ${s.chargerName}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (s.demoSpeed != 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: soft),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Demo speed ×${s.demoSpeed.round()}',
                        style: const TextStyle(color: soft, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!s.completed)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    color: VoltraColors.green,
                    backgroundColor: Colors.white12,
                    value: s.online ? null : 0,
                  ),
                ),
              if (!s.online && !s.completed) ...[
                const SizedBox(height: 12),
                const Text(
                  'No reading from the charger right now. Charging resumes reporting when it reconnects.',
                  style: TextStyle(color: Color(0xFFE8C547)),
                ),
              ],
              const SizedBox(height: 28),
              const Text('Energy delivered', style: TextStyle(color: soft)),
              Text(
                '${s.energyKwh.toStringAsFixed(2)} kWh',
                style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text('Cost so far', style: TextStyle(color: soft)),
              Text(
                rupees(s.costPaise, exact: true),
                style: const TextStyle(color: VoltraColors.green, fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 28),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _Reading(label: 'Power', value: '${s.powerKw.toStringAsFixed(2)} kW'),
                  _Reading(label: 'Duration', value: elapsed(s.durationS)),
                  _Reading(label: 'Voltage', value: s.voltage == null ? '–' : '${s.voltage!.round()} V'),
                  _Reading(label: 'Current', value: s.current == null ? '–' : '${s.current} A'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Rate ${pricePerKwh(s.pricePerKwhPaise)} · measured by the charger’s smart meter',
                style: const TextStyle(color: soft),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: s.completed
                ? FilledButton(onPressed: () => _openBill(s), child: const Text('View bill'))
                : FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
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

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF17283E), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFB8C4D0), fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
