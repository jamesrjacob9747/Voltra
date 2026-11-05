import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';

/// What the network has delivered so far: chargers unlocked, energy shared, petrol and CO₂ avoided.
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  late Future<Impact> _impact = api.impact();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoltraColors.navy,
      appBar: AppBar(title: const Text('Voltra impact')),
      body: FutureBuilder<Impact>(
        future: _impact,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() {
                _impact = api.impact();
              }),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: VoltraColors.green));
          return _buildBody(snap.data!);
        },
      ),
    );
  }

  Widget _buildBody(Impact i) {
    const soft = Color(0xFFB8C4D0);
    final f = i.factors;
    return RefreshIndicator(
      onRefresh: () async {
        final next = api.impact();
        setState(() {
          _impact = next;
        });
        await next;
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Chargers that already existed, now shared.',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${i.chargers} chargers from ${i.hosts} neighbours · ${i.verifiedChargers} verified',
            style: const TextStyle(color: soft),
          ),
          const SizedBox(height: 20),
          _Hero(value: '${_whole(i.kwhShared)} kWh', label: 'clean energy shared between neighbours'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _Tile(
                icon: Icons.local_gas_station_outlined,
                value: '${_whole(i.petrolLitresAvoided)} L',
                label: 'petrol not burned',
              ),
              _Tile(
                icon: Icons.eco_outlined,
                value: '${_whole(i.co2KgAvoided)} kg',
                label: 'CO₂ avoided (net of grid)',
              ),
              _Tile(icon: Icons.bolt, value: '${i.sessionsCompleted}', label: 'charging sessions'),
              _Tile(
                icon: Icons.payments_outlined,
                value: '₹${_whole(i.hostEarningsPaise / 100)}',
                label: 'earned by hosts',
              ),
              _Tile(
                icon: Icons.shield_outlined,
                value: '${i.chargesureRescues}',
                label: 'drivers rescued by ChargeSure',
              ),
              _Tile(icon: Icons.ev_station_outlined, value: '${i.chargers}', label: 'chargers unlocked, zero built'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Estimates. ${i.estimatedSessions} of ${i.sessionsCompleted} sessions come from chargers’ track records, '
            'counted at ${f['kwh_per_session_estimate']} kWh each; the rest are metered. Petrol: '
            '${_whole(f['km_per_kwh'] ?? 0)} km per kWh for an e-scooter vs ${_whole(f['petrol_scooter_km_per_litre'] ?? 0)} km '
            'per litre. CO₂: ${f['co2_kg_per_litre_petrol']} kg per litre of petrol minus India’s grid at about '
            '${f['grid_co2_kg_per_kwh']} kg per kWh.',
            style: const TextStyle(color: soft, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 703.8 → "704", 4521.4 → "4,521"
String _whole(double v) {
  final digits = v.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

class _Hero extends StatelessWidget {
  const _Hero({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: VoltraColors.green, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(color: VoltraColors.navy, fontSize: 44, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: VoltraColors.navy, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF17283E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: VoltraColors.green, size: 22),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(label, style: const TextStyle(color: Color(0xFFB8C4D0), fontSize: 12)),
        ],
      ),
    );
  }
}
