import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models.dart';
import 'confidence_badge.dart';

/// Turns the light OpenStreetMap tiles into a dark map: inverted, then tinted towards navy.
const _darkTiles = ColorFilter.matrix(<double>[
  -0.60, -0.25, -0.05, 0, 232, //
  -0.20, -0.62, -0.08, 0, 238, //
  -0.15, -0.30, -0.40, 0, 250, //
  0, 0, 0, 1, 0, //
]);

/// The map's base layer for every map in the app: OpenStreetMap tiles, darkened in the dark theme.
TileLayer voltraTiles(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.voltra.voltra_app',
    tileBuilder: dark ? (_, tile, _) => ColorFiltered(colorFilter: _darkTiles, child: tile) : null,
  );
}

/// The OpenStreetMap credit every map must show, in the bottom-right corner. Unlike
/// flutter_map's own attribution row, it shrinks to fit narrow maps and large text.
class MapCredit extends StatelessWidget {
  const MapCredit({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '© OpenStreetMap contributors',
            maxLines: 1,
            // Fixed size: a legal credit, not reading text; it must fit on any map.
            textScaler: TextScaler.noScaling,
            style: TextStyle(fontSize: 11, color: Color(0xFF1C2633)),
          ),
        ),
      ),
    );
  }
}

/// A still, non-interactive map centred on one charger. While the exact address is locked,
/// a circle shows that the pin is only approximate.
class ChargerMapSnippet extends StatelessWidget {
  const ChargerMapSnippet({super.key, required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final color = confidenceColor(charger.confidence.score, online: charger.online);
    return Semantics(
      label: charger.exactLocation ? 'Map of the charger’s location' : 'Map of the charger’s approximate location',
      child: IgnorePointer(
        child: FlutterMap(
          // A new map when the location is revealed, so it recentres on the exact spot.
          key: ValueKey('${charger.location}-${charger.exactLocation}'),
          options: MapOptions(
            initialCenter: charger.location,
            initialZoom: 15.5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            voltraTiles(context),
            if (!charger.exactLocation)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: charger.location,
                    radius: 46,
                    color: color.withValues(alpha: 0.2),
                    borderColor: color,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: charger.location,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Icon(charger.online ? Icons.ev_station : Icons.power_off, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const MapCredit(),
          ],
        ),
      ),
    );
  }
}
