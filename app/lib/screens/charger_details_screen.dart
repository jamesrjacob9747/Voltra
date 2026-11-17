import 'package:flutter/material.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/charger_card.dart';
import '../widgets/charger_map.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/primary_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/stat_tile.dart';
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
  const ChargerDetailsScreen({super.key, required this.chargerId, required this.user, this.preview});

  final int chargerId;
  final AppUser user;

  /// What the list already knew about this charger. Shown at once, so the page opens with
  /// content while the full details (exact address after a confirmed booking) load.
  final Charger? preview;

  @override
  State<ChargerDetailsScreen> createState() => _ChargerDetailsScreenState();
}

class _ChargerDetailsScreenState extends State<ChargerDetailsScreen> {
  late Future<Charger> _charger = _load();

  Future<Charger> _load() => api.charger(widget.chargerId, userId: widget.user.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Charger>(
      future: _charger,
      builder: (context, snap) {
        void retry() => setState(() {
          _charger = _load();
        });
        final charger = snap.data ?? widget.preview;
        if (charger != null) {
          // Still showing the list's preview when the full details fail: say so, and offer a retry.
          return _Details(
            charger: charger,
            user: widget.user,
            error: snap.hasError && snap.data == null ? '${snap.error}' : null,
            onRetry: retry,
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Charger')),
          body: snap.hasError
              ? ErrorView(message: '${snap.error}', onRetry: retry)
              : const SkeletonList(item: ChargerCardSkeleton(), count: 3),
        );
      },
    );
  }
}

class _Details extends StatefulWidget {
  const _Details({required this.charger, required this.user, this.error, this.onRetry});

  final Charger charger;
  final AppUser user;

  /// Set when the latest details failed to load and [charger] is the list's preview.
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  final _scroll = ScrollController();

  /// The big name under the map is on screen until about here; past it, the bar shows the name.
  static const _titleAt = 190.0;
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > _titleAt;
      if (show != _showTitle) setState(() => _showTitle = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final c = widget.charger;
    final user = widget.user;
    final tag = priceTag(c);
    final canBook = c.online && user.canDrive;

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: vc.background,
            title: AnimatedOpacity(opacity: _showTitle ? 1 : 0, duration: Motion.fast, child: Text(c.name)),
            flexibleSpace: FlexibleSpaceBar(background: _MapHeader(charger: c)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
            sliver: SliverList.list(
              children: [
                if (widget.error != null) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.xs, Gap.sm),
                    decoration: BoxDecoration(color: vc.warningTint, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: vc.warning, size: 20),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              'Couldn’t load the latest details. Showing what we had.',
                              style: TextStyle(color: vc.ink, fontSize: 13, height: 1.3),
                            ),
                          ),
                        ),
                        TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                Entrance(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: vc.ink, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: Gap.xs),
                      Wrap(
                        spacing: Gap.md,
                        runSpacing: Gap.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Hosted by ${c.hostName}', style: TextStyle(color: vc.muted)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 18, color: vc.warning),
                              Text(
                                ' ${c.rating.toStringAsFixed(1)}',
                                style: TextStyle(color: vc.ink, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          if (c.verified)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 16, color: vc.brand),
                                Text(
                                  ' Verified',
                                  style: TextStyle(color: vc.brand, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Entrance(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          compact: true,
                          tone: StatTone.brand,
                          label: 'Price now',
                          value: Text(pricePerKwh(c.priceNowPaise)),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: StatTile(compact: true, label: 'Connector', value: Text(c.connectorLabel)),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: StatTile(compact: true, label: 'Max power', value: Text('${c.powerKw} kW')),
                      ),
                    ],
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(height: Gap.sm),
                  Text('$tag price. Usual price ${pricePerKwh(c.basePricePaise)}.', style: TextStyle(color: vc.muted)),
                ],
                const SizedBox(height: Gap.lg),
                Entrance(index: 2, child: _ConfidenceCard(charger: c)),
                const SizedBox(height: Gap.lg),
                Entrance(
                  index: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Availability & location',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc.ink),
                          ),
                          const SizedBox(height: Gap.md),
                          _InfoRow(
                            icon: Icons.schedule,
                            text:
                                'Open ${c.availableFrom}–${c.availableTo}'
                                '${c.autoApprove ? ' · instant booking' : ' · host approves each booking'}',
                          ),
                          const SizedBox(height: Gap.sm),
                          _InfoRow(
                            icon: c.exactLocation ? Icons.place_outlined : Icons.lock_outline,
                            text: c.exactLocation ? c.address ?? '' : 'Approximate location shown. The exact address unlocks once your booking is confirmed.',
                            soft: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: PrimaryBar(
        amount: pricePerKwh(c.priceNowPaise),
        amountCaption: !c.online ? 'offline right now' : (tag ?? 'right now').toLowerCase(),
        icon: Icons.event_available,
        label: 'Book this charger',
        onPressed: canBook ? () => showBookingSheet(context, charger: c, user: user) : null,
      ),
    );
  }
}

/// A still map of where the charger is, behind the collapsing title bar.
class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Stack(
      fit: StackFit.expand,
      children: [
        ChargerMapSnippet(charger: charger),
        // Fade the top so the back arrow and title stay readable over the map.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: const Alignment(0, 0.1),
                colors: [vc.background, vc.background.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.soft = false});

  final IconData icon;
  final String text;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: vc.muted),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(text, style: TextStyle(color: soft ? vc.muted : vc.ink, height: 1.4)),
        ),
      ],
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final conf = charger.confidence;
    final color = confidenceColor(conf.score, online: charger.online, palette: vc);
    final still = Motion.reduced(context);
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
                    'Charging Confidence',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc.ink),
                  ),
                ),
                ConfidenceBadge(confidence: conf, online: charger.online),
              ],
            ),
            const SizedBox(height: Gap.sm),
            CountUp(
              value: conf.score.toDouble(),
              format: (v) => '${v.round()}%',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            Text(
              charger.online
                  ? 'Live: heartbeat ${heartbeatAge(charger.lastHeartbeatS ?? 0)} · ${charger.successfulSessions} successful sessions'
                  : 'No heartbeat from this charger right now',
              style: TextStyle(color: vc.muted),
            ),
            const SizedBox(height: Gap.md),
            for (final (i, (key, label, max)) in _signals.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label, style: TextStyle(color: vc.ink)),
                    ),
                    SizedBox(
                      width: 90,
                      // Each bar fills from empty, one after another.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: still ? null : 0, end: (conf.breakdown[key] ?? 0) / max),
                        duration: still ? Duration.zero : Motion.count + Motion.stagger * i * 2,
                        curve: Motion.enter,
                        builder: (_, v, _) => LinearProgressIndicator(
                          value: v,
                          color: color,
                          backgroundColor: vc.raised,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${(conf.breakdown[key] ?? 0).round()}/$max',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: vc.muted, fontFeatures: const [FontFeature.tabularFigures()]),
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
