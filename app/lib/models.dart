import 'package:latlong2/latlong.dart';

double _d(dynamic v) => (v as num).toDouble();

class AppUser {
  final int id;
  final String name;
  final String role; // driver | host | both

  const AppUser({required this.id, required this.name, required this.role});

  bool get canDrive => role == 'driver' || role == 'both';
  bool get canHost => role == 'host' || role == 'both';

  factory AppUser.fromJson(Map<String, dynamic> j) =>
      AppUser(id: j['id'] as int, name: j['name'] as String, role: j['role'] as String);
}

class Confidence {
  final int score;
  final String band;
  final Map<String, double> breakdown;

  const Confidence({required this.score, required this.band, required this.breakdown});

  factory Confidence.fromJson(Map<String, dynamic> j) => Confidence(
        score: j['score'] as int,
        band: j['band'] as String,
        breakdown: (j['breakdown'] as Map<String, dynamic>).map((k, v) => MapEntry(k, _d(v))),
      );
}

class Charger {
  final int id;
  final String name;
  final String hostName;
  final double rating;
  final String connectorType;
  final double powerKw;
  final int basePricePaise;
  final int priceNowPaise;
  final String availableFrom;
  final String availableTo;
  final bool autoApprove;
  final bool verified;
  final String deviceId;
  final int successfulSessions;
  final bool online;
  final int? lastHeartbeatS;
  final Confidence confidence;
  final LatLng location;
  final bool exactLocation;
  final String? address;
  final double? distanceKm;

  const Charger({
    required this.id,
    required this.name,
    required this.hostName,
    required this.rating,
    required this.connectorType,
    required this.powerKw,
    required this.basePricePaise,
    required this.priceNowPaise,
    required this.availableFrom,
    required this.availableTo,
    required this.autoApprove,
    required this.verified,
    required this.deviceId,
    required this.successfulSessions,
    required this.online,
    required this.lastHeartbeatS,
    required this.confidence,
    required this.location,
    required this.exactLocation,
    required this.address,
    required this.distanceKm,
  });

  factory Charger.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] as Map<String, dynamic>;
    return Charger(
      id: j['id'] as int,
      name: j['name'] as String,
      hostName: (j['host'] as Map<String, dynamic>)['name'] as String,
      rating: _d(j['rating']),
      connectorType: j['connector_type'] as String,
      powerKw: _d(j['power_kw']),
      basePricePaise: j['base_price_per_kwh_paise'] as int,
      priceNowPaise: j['price_now_per_kwh_paise'] as int,
      availableFrom: j['available_from'] as String,
      availableTo: j['available_to'] as String,
      autoApprove: j['auto_approve'] as bool,
      verified: j['verified'] as bool,
      deviceId: j['device_id'] as String,
      successfulSessions: j['successful_sessions'] as int,
      online: j['online'] as bool,
      lastHeartbeatS: j['last_heartbeat_s'] as int?,
      confidence: Confidence.fromJson(j['confidence'] as Map<String, dynamic>),
      location: LatLng(_d(loc['lat']), _d(loc['lng'])),
      exactLocation: loc['exact'] as bool,
      address: j['address'] as String?,
      distanceKm: j['distance_km'] == null ? null : _d(j['distance_km']),
    );
  }

  String get connectorLabel => connectorType == '15A' ? '15A socket' : connectorType;
}
