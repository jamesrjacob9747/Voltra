import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../config.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/charger_card.dart';
import '../widgets/charger_map.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/skeleton.dart';
import 'charge_match_screen.dart';
import 'charger_details_screen.dart';

enum _Sort { nearest, fastest, cheapest }

/// How much of the screen the charger sheet covers: peeking, resting, fully open.
const _sheetMin = 0.14;
const _sheetRest = 0.42;
const _sheetMax = 0.9;

/// Driver home: a full-screen map of nearby chargers under a search bar, with the same
/// chargers as cards in a sheet that drags up from the bottom.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.user, this.visit = 0});

  final AppUser user;

  /// Changes each time the Home tab is reopened; the chargers reload when it does.
  final int visit;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _cardKeys = <int, GlobalKey>{};
  AnimationController? _fly;

  List<Charger>? _chargers;
  String? _error;
  bool _loading = false;

  bool _onlineOnly = false;
  bool _verifiedOnly = false;
  _Sort _sort = _Sort.nearest;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    if (old.visit != widget.visit) _refresh();
  }

  @override
  void dispose() {
    _fly?.dispose();
    _sheet.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Reloads the chargers. What is on screen stays there until the new list arrives.
  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final chargers = await api.chargers(
        lat: demoLocation.latitude,
        lng: demoLocation.longitude,
        radiusKm: searchRadiusKm,
      );
      if (!mounted) return;
      setState(() {
        _chargers = chargers;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Charger> get _visible {
    final list = [
      for (final c in _chargers ?? const <Charger>[])
        if ((!_onlineOnly || c.online) && (!_verifiedOnly || c.verified)) c,
    ];
    switch (_sort) {
      case _Sort.nearest:
        list.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
      case _Sort.fastest:
        list.sort((a, b) => b.powerKw.compareTo(a.powerKw));
      case _Sort.cheapest:
        list.sort((a, b) => a.priceNowPaise.compareTo(b.priceNowPaise));
    }
    return list;
  }

  bool get _filtered => _onlineOnly || _verifiedOnly || _sort != _Sort.nearest;

  void _clearFilters() => setState(() {
    _onlineOnly = false;
    _verifiedOnly = false;
    _sort = _Sort.nearest;
  });

  /// Glides the map to [target], keeping it in the part of the map the sheet doesn't cover.
  void _flyTo(LatLng target, double zoom) {
    final lift = Offset(0, -MediaQuery.sizeOf(context).height * 0.16);
    if (Motion.reduced(context)) {
      _map.move(target, zoom, offset: lift);
      return;
    }
    final from = _map.camera;
    final lat = Tween(begin: from.center.latitude, end: target.latitude);
    final lng = Tween(begin: from.center.longitude, end: target.longitude);
    final z = Tween(begin: from.zoom, end: zoom);
    _fly?.dispose();
    final controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    final t = CurvedAnimation(parent: controller, curve: Motion.emphasized);
    controller.addListener(() => _map.move(LatLng(lat.evaluate(t), lng.evaluate(t)), z.evaluate(t), offset: lift));
    _fly = controller..forward();
  }

  /// A pin was tapped: centre it, highlight its card and bring that card into view.
  void _select(Charger c) {
    HapticFeedback.selectionClick();
    setState(() => _selectedId = c.id);
    _flyTo(c.location, 16);
    if (_sheet.isAttached && _sheet.size < _sheetRest) {
      _sheet.animateTo(_sheetRest, duration: Motion.slow, curve: Motion.enter);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _cardKeys[c.id]?.currentContext;
      if (card != null && card.mounted) {
        Scrollable.ensureVisible(card, duration: Motion.slow, curve: Motion.enter, alignment: 0.1);
      }
    });
  }

  Future<void> _findCharge() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChargeMatchScreen(user: widget.user)));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chargers = _visible;
    return AnnotatedRegion(
      value: overlayFor(Theme.of(context).brightness),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap(chargers, dark)),
            // A soft fade under the status bar so its icons stay readable over the map.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top + 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [vc.background.withValues(alpha: 0.9), vc.background.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
                    child: _SearchBar(name: widget.user.name, onTap: _findCharge),
                  ),
                  const SizedBox(height: Gap.sm),
                  _buildFilters(),
                ],
              ),
            ),
            DraggableScrollableSheet(
              controller: _sheet,
              initialChildSize: _sheetRest,
              minChildSize: _sheetMin,
              maxChildSize: _sheetMax,
              snap: true,
              snapSizes: const [_sheetRest],
              builder: (context, scroll) => _buildSheet(scroll, chargers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, IconData icon, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: Gap.sm),
      child: FilterChip(
        avatar: selected ? null : Icon(icon, size: 16, color: context.vc.muted),
        label: Text(label),
        selected: selected,
        elevation: 2,
        shadowColor: Colors.black38,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
    void sortBy(_Sort s) => setState(() => _sort = _sort == s ? _Sort.nearest : s);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Row(
        children: [
          chip('Online now', Icons.bolt, _onlineOnly, () => setState(() => _onlineOnly = !_onlineOnly)),
          chip(
            'Verified',
            Icons.verified_outlined,
            _verifiedOnly,
            () => setState(() => _verifiedOnly = !_verifiedOnly),
          ),
          chip('Fastest', Icons.speed, _sort == _Sort.fastest, () => sortBy(_Sort.fastest)),
          chip('Cheapest', Icons.currency_rupee, _sort == _Sort.cheapest, () => sortBy(_Sort.cheapest)),
        ],
      ),
    );
  }

  Widget _buildMap(List<Charger> chargers, bool dark) {
    // The sheet hides the bottom of the map, so the attribution sits just above its peek height.
    final attributionLift = MediaQuery.sizeOf(context).height * _sheetMin;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: demoLocation,
        initialZoom: 14.5,
        onTap: (_, _) => setState(() => _selectedId = null),
      ),
      children: [
        voltraTiles(context),
        MarkerLayer(
          markers: [
            const Marker(point: demoLocation, width: 56, height: 56, child: _YouDot()),
            for (final c in chargers)
              Marker(
                point: c.location,
                width: 96,
                height: 44,
                child: _PricePin(charger: c, selected: c.id == _selectedId, onTap: () => _select(c)),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(bottom: attributionLift),
          child: const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
        ),
      ],
    );
  }

  Widget _buildSheet(ScrollController scroll, List<Charger> chargers) {
    final vc = context.vc;
    final total = _chargers?.length ?? 0;
    final Widget body;
    if (_chargers == null && _error != null) {
      body = SizedBox(
        height: 320,
        child: ErrorView(message: _error!, onRetry: _refresh),
      );
    } else if (_chargers == null) {
      body = const SkeletonList(item: ChargerCardSkeleton(), padding: EdgeInsets.zero);
    } else if (chargers.isEmpty) {
      body = EmptyState(
        compact: true,
        icon: Icons.ev_station_outlined,
        title: total == 0 ? 'No chargers within ${searchRadiusKm.toInt()} km' : 'No chargers match these filters',
        hint: total == 0 ? 'Check back soon: hosts are joining every week.' : null,
        actionLabel: total == 0 ? null : 'Clear filters',
        onAction: total == 0 ? null : _clearFilters,
      );
    } else {
      body = Column(
        children: [
          for (final (i, c) in chargers.indexed)
            Padding(
              key: _cardKeys.putIfAbsent(c.id, GlobalKey.new),
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Entrance(
                index: i,
                child: _ChargerCard(charger: c, user: widget.user, selected: c.id == _selectedId, onClosed: _refresh),
              ),
            ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: vc.background,
        borderRadius: Radii.sheet,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: ClipRRect(
        borderRadius: Radii.sheet,
        child: SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: Gap.md),
                  decoration: BoxDecoration(color: vc.border, borderRadius: BorderRadius.circular(Radii.pill)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chargers near you',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: vc.ink),
                        ),
                        Text(
                          _chargers == null
                              ? 'Looking around Koramangala…'
                              : _filtered
                              ? '${chargers.length} of $total within ${searchRadiusKm.toInt()} km'
                              : '$total chargers within ${searchRadiusKm.toInt()} km',
                          style: TextStyle(color: vc.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _refresh,
                    icon: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: vc.brand),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              AnimatedSwitcher(duration: Motion.medium, child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top bar, styled as a search field: one tap starts ChargeMatch.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Find me a charge',
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.lg, Gap.md),
        decoration: BoxDecoration(
          color: vc.card,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: vc.brand, borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(Icons.bolt, color: vc.onBrand, size: 26),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find me a charge',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: vc.ink),
                  ),
                  Text(
                    'Hi $name, tell us your battery and we’ll match you',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: vc.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: vc.muted),
          ],
        ),
      ),
    );
  }
}

/// A charger card that grows into the charger's page when tapped.
class _ChargerCard extends StatelessWidget {
  const _ChargerCard({required this.charger, required this.user, required this.selected, required this.onClosed});

  final Charger charger;
  final AppUser user;
  final bool selected;
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return OpenContainer<void>(
      transitionDuration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 400),
      transitionType: ContainerTransitionType.fadeThrough,
      closedElevation: 0,
      openElevation: 0,
      closedColor: vc.card,
      openColor: vc.background,
      middleColor: vc.background,
      closedShape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: selected ? vc.brand : vc.border, width: selected ? 2 : 1),
      ),
      onClosed: (_) => onClosed(),
      openBuilder: (_, _) => ChargerDetailsScreen(chargerId: charger.id, user: user, preview: charger),
      // OpenContainer draws its own surface, which doesn't know the app theme. This Material
      // puts the theme's text style (and ink ripples) back for the card's content.
      closedBuilder: (_, open) => Material(
        type: MaterialType.transparency,
        textStyle: Theme.of(context).textTheme.bodyMedium,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            open();
          },
          child: ChargerSummary(charger: charger),
        ),
      ),
    );
  }
}

class _PricePin extends StatelessWidget {
  const _PricePin({required this.charger, required this.selected, required this.onTap});

  final Charger charger;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Pins sit on map tiles, which are light-coloured in both themes' designs, so they keep
    // the stronger light-theme colours for contrast.
    final color = confidenceColor(charger.confidence.score, online: charger.online);
    return Semantics(
      button: true,
      label: '${charger.name}, ${pricePerKwh(charger.priceNowPaise)}${charger.online ? '' : ', offline'}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1.18 : 1,
            duration: Motion.medium,
            curve: Curves.easeOutBack,
            child: AnimatedContainer(
              duration: Motion.medium,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? VoltraColors.navy : color,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: selected ? 0.35 : 0.2),
                    blurRadius: selected ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    charger.online ? Icons.bolt : Icons.power_off,
                    size: 15,
                    color: selected ? VoltraColors.green : Colors.white,
                  ),
                  Text(
                    rupees(charger.priceNowPaise),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "You are here", with a slow pulse so it reads as live.
class _YouDot extends StatelessWidget {
  const _YouDot();

  @override
  Widget build(BuildContext context) {
    final info = context.vc.info;
    final dot = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
      ),
    );
    final halo = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: info.withValues(alpha: 0.25), shape: BoxShape.circle),
    );
    return Semantics(
      label: 'Your location',
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (Motion.reduced(context))
            Opacity(opacity: 0.6, child: halo)
          else
            halo
                .animate(onPlay: (c) => c.repeat())
                .scaleXY(begin: 0.35, end: 1, duration: const Duration(milliseconds: 1800), curve: Curves.easeOut)
                .fadeOut(duration: const Duration(milliseconds: 1800), curve: Curves.easeIn),
          dot,
        ],
      ),
    );
  }
}
