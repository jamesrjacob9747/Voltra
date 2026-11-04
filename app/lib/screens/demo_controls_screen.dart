import 'package:flutter/material.dart';

import '../api.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
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
      setState(() => _chargers = _load());
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
    setState(() => _chargers = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo controls')),
      body: FutureBuilder<List<Charger>>(
        future: _chargers,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _chargers = _load()));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Switch a charger off to show ChargeSure. Smart plugs are simulated until the hardware arrives.',
                style: TextStyle(color: VoltraColors.muted),
              ),
              const SizedBox(height: 12),
              for (final c in snap.data!)
                Card(
                  child: SwitchListTile(
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${c.deviceId} · ${c.online ? 'online' : 'offline'}'),
                    value: c.online,
                    onChanged: _busy.contains(c.deviceId) ? null : (v) => _toggle(c, v),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
