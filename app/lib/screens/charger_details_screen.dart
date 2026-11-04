import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/error_view.dart';
import 'booking_sheet.dart';

/// Points available per Confidence signal (PRD Algorithms 3).
const _signals = [
  ('iot_online', 'Charger online', 30),
  ('host_confirmed', 'Host confirms bookings', 20),
  ('successful_sessions', 'Successful sessions', 20),
  ('cancellation_rate', 'Low host cancellations', 10),
  ('recent_activity', 'Charged in the last 7 days', 10),
  ('availability', 'Free in the next hour', 10),
];

class ChargerDetailsScreen extends StatefulWidget {
  const ChargerDetailsScreen({super.key, required this.chargerId, required this.user});

  final int chargerId;
  final AppUser user;

  @override
  State<ChargerDetailsScreen> createState() => _ChargerDetailsScreenState();
}

class _ChargerDetailsScreenState extends State<ChargerDetailsScreen> {
  late Future<Charger> _charger = _load();

  Future<Charger> _load() => api.charger(widget.chargerId, userId: widget.user.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charger')),
      body: FutureBuilder<Charger>(
        future: _charger,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _charger = _load()));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return _Details(charger: snap.data!, user: widget.user);
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.charger, required this.user});

  final Charger charger;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final c = charger;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                c.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: VoltraColors.ink),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Hosted by ${c.hostName}', style: const TextStyle(color: VoltraColors.muted)),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 16, color: VoltraColors.amber),
                  Text(' ${c.rating.toStringAsFixed(1)}', style: const TextStyle(color: VoltraColors.muted)),
                  if (c.verified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, size: 16, color: VoltraColors.darkGreen),
                    const Text(' Verified', style: TextStyle(color: VoltraColors.darkGreen)),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Fact(label: 'Price now', value: pricePerKwh(c.priceNowPaise)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Fact(label: 'Connector', value: c.connectorLabel),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Fact(label: 'Max power', value: '${c.powerKw} kW'),
                  ),
                ],
              ),
              if (c.priceNowPaise != c.basePricePaise) ...[
                const SizedBox(height: 8),
                Text(
                  c.priceNowPaise > c.basePricePaise
                      ? 'Evening peak price. Usual price ${pricePerKwh(c.basePricePaise)}.'
                      : 'Night off-peak price. Usual price ${pricePerKwh(c.basePricePaise)}.',
                  style: const TextStyle(color: VoltraColors.muted),
                ),
              ],
              const SizedBox(height: 16),
              _ConfidenceCard(charger: c),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Availability & location', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Open ${c.availableFrom}–${c.availableTo}'
                        '${c.autoApprove ? ' · instant booking' : ' · host approves each booking'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.exactLocation
                            ? c.address ?? ''
                            : 'Approximate location shown. The exact address unlocks once your booking is confirmed.',
                        style: const TextStyle(color: VoltraColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.event_available),
              label: const Text('Book this charger'),
              onPressed: c.online && user.canDrive ? () => showBookingSheet(context, charger: c, user: user) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: VoltraColors.muted)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: VoltraColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final conf = charger.confidence;
    final color = confidenceColor(conf.score, online: charger.online);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Charging Confidence', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                ConfidenceBadge(confidence: conf, online: charger.online),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${conf.score}%',
              style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              charger.online
                  ? 'Live: heartbeat ${heartbeatAge(charger.lastHeartbeatS ?? 0)} · ${charger.successfulSessions} successful sessions'
                  : 'No heartbeat from this charger right now',
              style: const TextStyle(color: VoltraColors.muted),
            ),
            const SizedBox(height: 12),
            for (final (key, label, max) in _signals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    SizedBox(
                      width: 90,
                      child: LinearProgressIndicator(
                        value: (conf.breakdown[key] ?? 0) / max,
                        color: color,
                        backgroundColor: VoltraColors.border,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${(conf.breakdown[key] ?? 0).round()}/$max',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: VoltraColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
