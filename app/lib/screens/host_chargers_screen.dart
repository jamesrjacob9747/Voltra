import 'package:flutter/material.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/skeleton.dart';
import 'add_charger_screen.dart';

/// The host's own chargers, each with the code drivers type to start a session.
class HostChargersScreen extends StatefulWidget {
  const HostChargersScreen({super.key, required this.user, this.visit = 0});

  final AppUser user;

  /// Changes each time the tab is reopened; the list reloads when it does.
  final int visit;

  @override
  State<HostChargersScreen> createState() => _HostChargersScreenState();
}

class _HostChargersScreenState extends State<HostChargersScreen> {
  late Future<List<Charger>> _chargers = api.hostChargers(widget.user.id);

  @override
  void didUpdateWidget(HostChargersScreen old) {
    super.didUpdateWidget(old);
    if (old.visit != widget.visit) _refresh();
  }

  Future<void> _refresh() async {
    final next = api.hostChargers(widget.user.id);
    setState(() {
      _chargers = next;
    });
    try {
      await next;
    } on ApiException {
      // The FutureBuilder shows the error; pull-to-refresh just needs to finish.
    }
  }

  Future<void> _addCharger() async {
    final added = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => AddChargerScreen(user: widget.user)));
    if (added == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My chargers')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add charger'),
        onPressed: _addCharger,
      ),
      body: FutureBuilder<List<Charger>>(
        future: _chargers,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _refresh);
          if (!snap.hasData) return const SkeletonList(item: ChargerCardSkeleton(), count: 3);
          final chargers = snap.data!;
          if (chargers.isEmpty) {
            return EmptyState(
              icon: Icons.ev_station_outlined,
              title: 'No chargers yet',
              hint: 'List a charger or a 15A socket you already own and start earning from it.',
              actionLabel: 'Add charger',
              onAction: _addCharger,
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 96), // room above the Add charger button
              itemCount: chargers.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
              itemBuilder: (context, i) => Entrance(
                index: i,
                child: _MyChargerCard(charger: chargers[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MyChargerCard extends StatelessWidget {
  const _MyChargerCard({required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final c = charger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: vc.ink),
                  ),
                ),
                Semantics(
                  label: 'Charger code ${c.deviceId}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: VoltraColors.navy, borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Text(
                      c.deviceId,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              '${c.connectorLabel} · ${pricePerKwh(c.basePricePaise)} · open ${c.availableFrom}–${c.availableTo}',
              style: TextStyle(color: vc.muted),
            ),
            const SizedBox(height: Gap.md),
            ConfidenceBadge(confidence: c.confidence, online: c.online),
          ],
        ),
      ),
    );
  }
}
