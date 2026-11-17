import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../design/tokens.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/stat_tile.dart';

/// What the network has delivered so far: chargers unlocked, energy shared, petrol and CO₂ avoided.
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key, this.visit = 0});

  /// Changes each time the Impact tab is reopened; the figures reload when it does.
  final int visit;

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  late Future<Impact> _impact = api.impact();

  @override
  void didUpdateWidget(ImpactScreen old) {
    super.didUpdateWidget(old);
    if (old.visit != widget.visit) {
      setState(() {
        _impact = api.impact();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoltraColors.navy,
      appBar: darkAppBar('Voltra impact'),
      body: FutureBuilder<Impact>(
        future: _impact,
        builder: (context, snap) {
          if (snap.hasError) {
            // This screen is navy in both themes, so the error uses the dark colours.
            return Theme(
              data: buildTheme(Brightness.dark),
              child: ErrorView(
                message: '${snap.error}',
                onRetry: () => setState(() {
                  _impact = api.impact();
                }),
              ),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: VoltraColors.green));
          return _buildBody(snap.data!);
        },
      ),
    );
  }

  Widget _buildBody(Impact i) {
    const soft = VoltraColors.onNavySoft;
    final f = i.factors;
    Widget tile(int index, IconData icon, double value, String Function(double) format, String label) => Entrance(
      index: index,
      child: StatTile(
        tone: StatTone.onNavy,
        icon: icon,
        label: label,
        value: CountUp(value: value, format: format, duration: const Duration(milliseconds: 900)),
      ),
    );
    return RefreshIndicator(
      onRefresh: () async {
        final next = api.impact();
        setState(() {
          _impact = next;
        });
        try {
          await next;
        } on ApiException {
          // The FutureBuilder shows the error; pull-to-refresh just needs to finish.
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
        children: [
          const Entrance(
            child: Text(
              'Chargers that already existed, now shared.',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            '${i.chargers} chargers from ${i.hosts} neighbours · ${i.verifiedChargers} verified',
            style: const TextStyle(color: soft),
          ),
          const SizedBox(height: Gap.xl),
          Entrance(
            index: 1,
            child: Container(
              padding: const EdgeInsets.all(Gap.xl),
              decoration: const BoxDecoration(color: VoltraColors.green, borderRadius: Radii.card),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountUp(
                    value: i.kwhShared,
                    duration: const Duration(milliseconds: 900),
                    format: (v) => '${_whole(v)} kWh',
                    style: const TextStyle(
                      color: VoltraColors.navy,
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      height: 1.1,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text(
                    'clean energy shared between neighbours',
                    style: TextStyle(color: VoltraColors.navy, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          GridView(
            gridDelegate: statGridDelegate(context, icon: true),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              tile(
                2,
                Icons.local_gas_station_outlined,
                i.petrolLitresAvoided,
                (v) => '${_whole(v)} L',
                'petrol not burned',
              ),
              tile(3, Icons.eco_outlined, i.co2KgAvoided, (v) => '${_whole(v)} kg', 'CO₂ avoided (net of grid)'),
              tile(4, Icons.bolt, i.sessionsCompleted.toDouble(), _whole, 'charging sessions'),
              tile(5, Icons.payments_outlined, i.hostEarningsPaise / 100, (v) => '₹${_whole(v)}', 'earned by hosts'),
              tile(6, Icons.shield_outlined, i.chargesureRescues.toDouble(), _whole, 'drivers rescued by ChargeSure'),
              tile(7, Icons.ev_station_outlined, i.chargers.toDouble(), _whole, 'chargers unlocked, zero built'),
            ],
          ),
          const SizedBox(height: Gap.xl),
          Text(
            'Estimates. ${i.estimatedSessions} of ${i.sessionsCompleted} sessions come from chargers’ track records, '
            'counted at ${f['kwh_per_session_estimate']} kWh each; the rest are metered. Petrol: '
            '${_whole(f['km_per_kwh'] ?? 0)} km per kWh for an e-scooter vs ${_whole(f['petrol_scooter_km_per_litre'] ?? 0)} km '
            'per litre. CO₂: ${f['co2_kg_per_litre_petrol']} kg per litre of petrol minus India’s grid at about '
            '${f['grid_co2_kg_per_kwh']} kg per kWh.',
            style: const TextStyle(color: soft, fontSize: 12, height: 1.4),
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
