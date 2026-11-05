import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../api.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/error_view.dart';
import 'charge_match_screen.dart';
import 'charger_details_screen.dart';
import 'host_dashboard_screen.dart';
import 'my_bookings_screen.dart';
import 'user_picker_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  late Future<List<Charger>> _chargers = _load();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<List<Charger>> _load() =>
      api.chargers(lat: demoLocation.latitude, lng: demoLocation.longitude, radiusKm: searchRadiusKm);

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _chargers = next;
    });
    await next;
  }

  Future<void> _openCharger(Charger c) async {
    _map.move(c.location, 16);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChargerDetailsScreen(chargerId: c.id, user: widget.user),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: VoltraColors.green),
            SizedBox(width: 6),
            Text('Voltra', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          Center(child: Text(widget.user.name, style: const TextStyle(fontSize: 15))),
          IconButton(
            tooltip: 'My bookings',
            icon: const Icon(Icons.receipt_long),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyBookingsScreen(user: widget.user)));
              if (mounted) _refresh();
            },
          ),
          if (widget.user.canHost)
            IconButton(
              tooltip: 'Host dashboard',
              icon: const Icon(Icons.home_work_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .pushReplacement(MaterialPageRoute(builder: (_) => HostDashboardScreen(user: widget.user))),
            ),
          IconButton(
            tooltip: 'Switch user',
            icon: const Icon(Icons.switch_account),
            onPressed: () =>
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const UserPickerScreen())),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 300), // sit on the map, above the list
        child: FloatingActionButton.extended(
          backgroundColor: VoltraColors.darkGreen,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.bolt),
          label: const Text('Find me a charge'),
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChargeMatchScreen(user: widget.user)));
            if (mounted) _refresh();
          },
        ),
      ),
      body: FutureBuilder<List<Charger>>(
        future: _chargers,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _refresh);
          final chargers = snap.data ?? const <Charger>[];
          return Column(
            children: [
              Expanded(child: _buildMap(chargers)),
              SizedBox(
                height: 300,
                child: snap.hasData
                    ? _ChargerList(chargers: chargers, onTap: _openCharger, onRefresh: _refresh)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(List<Charger> chargers) {
    return FlutterMap(
      mapController: _map,
      options: const MapOptions(initialCenter: demoLocation, initialZoom: 14.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.voltra.voltra_app',
        ),
        MarkerLayer(
          markers: [
            for (final c in chargers)
              Marker(
                point: c.location,
                width: 84,
                height: 34,
                child: _PricePin(charger: c, onTap: () => _openCharger(c)),
              ),
            const Marker(point: demoLocation, width: 22, height: 22, child: _YouDot()),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }
}

class _PricePin extends StatelessWidget {
  const _PricePin({required this.charger, required this.onTap});

  final Charger charger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = confidenceColor(charger.confidence.score, online: charger.online);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(charger.online ? Icons.bolt : Icons.power_off, size: 15, color: Colors.white),
            Text(
              rupees(charger.priceNowPaise),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _YouDot extends StatelessWidget {
  const _YouDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F6FED),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x332F6FED), blurRadius: 8, spreadRadius: 4)],
      ),
    );
  }
}

class _ChargerList extends StatelessWidget {
  const _ChargerList({required this.chargers, required this.onTap, required this.onRefresh});

  final List<Charger> chargers;
  final ValueChanged<Charger> onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VoltraColors.background,
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: chargers.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  '${chargers.length} chargers within ${searchRadiusKm.toInt()} km',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: VoltraColors.ink),
                ),
              );
            }
            final c = chargers[i - 1];
            return Card(
              child: ListTile(
                onTap: () => onTap(c),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${distance(c.distanceKm ?? 0)} · ${c.connectorLabel} · ${c.powerKw} kW'),
                      ConfidenceBadge(confidence: c.confidence, online: c.online),
                    ],
                  ),
                ),
                trailing: Text(
                  pricePerKwh(c.priceNowPaise),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: VoltraColors.ink),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
