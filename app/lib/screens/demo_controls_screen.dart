import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../design/tokens.dart';
import '../widgets/error_view.dart';
import '../widgets/skeleton.dart';
import '../widgets/snack.dart';

/// Stage controls for the pitch: take a charger offline to trigger ChargeSure,
/// bring it back, or reset all demo data between rehearsals.
class DemoControlsScreen extends StatefulWidget {
  const DemoControlsScreen({super.key});

  @override
  State<DemoControlsScreen> createState() => _DemoControlsScreenState();
}

class _DemoControlsScreenState extends State<DemoControlsScreen> {
  late Future<List<Charger>> _chargers = _load();
  final Set<String> _busy = {};

  Future<List<Charger>> _load() => api.chargers(lat: demoLocation.latitude, lng: demoLocation.longitude, radiusKm: 20);

  Future<void> _toggle(Charger c, bool online) async {
    setState(() => _busy.add(c.deviceId));
    try {
      await api.setPlugOnline(c.deviceId, online);
      if (!mounted) return;
      setState(() {
        _chargers = _load();
      });
      await _chargers;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(c.deviceId));
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text('All bookings, sessions and payments are deleted and the seed data is restored.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.resetDemo();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
      return;
    }
    if (!mounted) return;
    showSnack(context, 'Demo data reset');
    setState(() {
      _chargers = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo controls')),
      body: FutureBuilder<List<Charger>>(
        future: _chargers,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() {
                _chargers = _load();
              }),
            );
          }
          if (!snap.hasData) return const SkeletonList(item: BookingRowSkeleton(), count: 6);
          final vc = context.vc;
          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
            children: [
              Text(
                'Switch a charger off to show ChargeSure. Smart plugs are simulated in this build.',
                style: TextStyle(color: vc.muted, height: 1.35),
              ),
              const SizedBox(height: Gap.md),
              for (final c in snap.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.sm),
                  child: Card(
                    child: SwitchListTile(
                      secondary: Icon(
                        c.online ? Icons.ev_station : Icons.power_off,
                        color: c.online ? vc.success : vc.faint,
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${c.deviceId} · ${c.online ? 'online' : 'offline'}'),
                      value: c.online,
                      onChanged: _busy.contains(c.deviceId) ? null : (v) => _toggle(c, v),
                    ),
                  ),
                ),
              const SizedBox(height: Gap.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: vc.danger,
                  side: BorderSide(color: vc.danger.withValues(alpha: 0.5)),
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset all demo data'),
                onPressed: _reset,
              ),
            ],
          );
        },
      ),
    );
  }
}
