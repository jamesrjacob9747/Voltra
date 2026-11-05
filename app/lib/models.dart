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

class Vehicle {
  final int id;
  final String model;
  final double batteryKwh;
  final double chargerKw;
  final String connectorType;

  const Vehicle({
    required this.id,
    required this.model,
    required this.batteryKwh,
    required this.chargerKw,
    required this.connectorType,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
    id: j['id'] as int,
    model: j['model'] as String,
    batteryKwh: _d(j['battery_kwh']),
    chargerKw: _d(j['charger_kw']),
    connectorType: j['connector_type'] as String,
  );
}

/// Server timestamps are naive wall-clock strings ("2026-11-04T14:05"), parsed as local.
DateTime _time(dynamic v) => DateTime.parse(v as String);

class MatchEstimate {
  final double energyKwh;
  final double powerKw;
  final int chargeMinutes;
  final DateTime arriveAt;
  final DateTime finishAt;
  final int estCostPaise;

  /// A cheaper start (off-peak or after the evening peak) that still finishes by ready-by.
  final CheaperLater? cheaperLater;

  const MatchEstimate({
    required this.energyKwh,
    required this.powerKw,
    required this.chargeMinutes,
    required this.arriveAt,
    required this.finishAt,
    required this.estCostPaise,
    this.cheaperLater,
  });

  factory MatchEstimate.fromJson(Map<String, dynamic> j) => MatchEstimate(
    energyKwh: _d(j['energy_kwh']),
    powerKw: _d(j['power_kw']),
    chargeMinutes: j['charge_minutes'] as int,
    arriveAt: _time(j['arrive_at']),
    finishAt: _time(j['finish_at']),
    estCostPaise: j['est_cost_paise'] as int,
    cheaperLater: j['cheaper_later'] == null ? null : CheaperLater.fromJson(j['cheaper_later'] as Map<String, dynamic>),
  );
}

class CheaperLater {
  final DateTime startAt;
  final DateTime finishAt;
  final int pricePerKwhPaise;
  final int estCostPaise;
  final int savingPaise;

  const CheaperLater({
    required this.startAt,
    required this.finishAt,
    required this.pricePerKwhPaise,
    required this.estCostPaise,
    required this.savingPaise,
  });

  factory CheaperLater.fromJson(Map<String, dynamic> j) => CheaperLater(
    startAt: _time(j['start_at']),
    finishAt: _time(j['finish_at']),
    pricePerKwhPaise: j['price_per_kwh_paise'] as int,
    estCostPaise: j['est_cost_paise'] as int,
    savingPaise: j['saving_paise'] as int,
  );
}

class MatchResult {
  final Charger charger;
  final double score;
  final MatchEstimate estimate;

  const MatchResult({required this.charger, required this.score, required this.estimate});

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
    charger: Charger.fromJson(j),
    score: _d(j['match_score']),
    estimate: MatchEstimate.fromJson(j['estimate'] as Map<String, dynamic>),
  );
}

class Booking {
  final int id;
  final String status; // PENDING CONFIRMED ARRIVED CHARGING COMPLETED CANCELLED
  final int chargerId;
  final String chargerName;
  final String deviceId;
  final int driverId;
  final String driverName;
  final int? vehicleId;
  final DateTime start;
  final DateTime end;
  final int creditPaise;
  final int? transferredFromId;
  final int? sessionId;

  const Booking({
    required this.id,
    required this.status,
    required this.chargerId,
    required this.chargerName,
    required this.deviceId,
    required this.driverId,
    required this.driverName,
    required this.vehicleId,
    required this.start,
    required this.end,
    required this.creditPaise,
    required this.transferredFromId,
    required this.sessionId,
  });

  factory Booking.fromJson(Map<String, dynamic> j) {
    final charger = j['charger'] as Map<String, dynamic>;
    final driver = j['driver'] as Map<String, dynamic>;
    return Booking(
      id: j['id'] as int,
      status: j['status'] as String,
      chargerId: charger['id'] as int,
      chargerName: charger['name'] as String,
      deviceId: charger['device_id'] as String,
      driverId: driver['id'] as int,
      driverName: driver['name'] as String,
      vehicleId: j['vehicle_id'] as int?,
      start: _time(j['start_time']),
      end: _time(j['end_time']),
      creditPaise: j['credit_paise'] as int,
      transferredFromId: j['transferred_from_booking_id'] as int?,
      sessionId: j['session_id'] as int?,
    );
  }

  bool get canCancel => const {'PENDING', 'CONFIRMED', 'ARRIVED'}.contains(status);
  bool get canStart => status == 'CONFIRMED' || status == 'ARRIVED';
}

/// GET /sessions/{id}/live: one reading from the smart plug plus the running bill.
class LiveSession {
  final int sessionId;
  final int bookingId;
  final String chargerName;
  final String status; // CHARGING | COMPLETED
  final bool online;
  final double? voltage;
  final double? current;
  final double powerKw;
  final double energyKwh;
  final int durationS;
  final int pricePerKwhPaise;
  final int costPaise;
  final double demoSpeed;

  const LiveSession({
    required this.sessionId,
    required this.bookingId,
    required this.chargerName,
    required this.status,
    required this.online,
    required this.voltage,
    required this.current,
    required this.powerKw,
    required this.energyKwh,
    required this.durationS,
    required this.pricePerKwhPaise,
    required this.costPaise,
    required this.demoSpeed,
  });

  factory LiveSession.fromJson(Map<String, dynamic> j) => LiveSession(
    sessionId: j['session_id'] as int,
    bookingId: j['booking_id'] as int,
    chargerName: (j['charger'] as Map<String, dynamic>)['name'] as String,
    status: j['status'] as String,
    online: j['online'] as bool,
    voltage: j['voltage'] == null ? null : _d(j['voltage']),
    current: j['current'] == null ? null : _d(j['current']),
    powerKw: _d(j['power_kw']),
    energyKwh: _d(j['energy_kwh']),
    durationS: j['duration_s'] as int,
    pricePerKwhPaise: j['price_per_kwh_paise'] as int,
    costPaise: j['cost_paise'] as int,
    demoSpeed: _d(j['demo_speed']),
  );

  bool get completed => status == 'COMPLETED';
}

/// GET /impact: what the Voltra network has delivered so far (track record partly estimated).
class Impact {
  final int chargers;
  final int verifiedChargers;
  final int hosts;
  final int sessionsCompleted;
  final double kwhShared;
  final int hostEarningsPaise;
  final int chargesureRescues;
  final double petrolLitresAvoided;
  final double co2KgAvoided;
  final int estimatedSessions;
  final Map<String, double> factors;

  const Impact({
    required this.chargers,
    required this.verifiedChargers,
    required this.hosts,
    required this.sessionsCompleted,
    required this.kwhShared,
    required this.hostEarningsPaise,
    required this.chargesureRescues,
    required this.petrolLitresAvoided,
    required this.co2KgAvoided,
    required this.estimatedSessions,
    required this.factors,
  });

  factory Impact.fromJson(Map<String, dynamic> j) => Impact(
    chargers: j['chargers'] as int,
    verifiedChargers: j['verified_chargers'] as int,
    hosts: j['hosts'] as int,
    sessionsCompleted: j['sessions_completed'] as int,
    kwhShared: _d(j['kwh_shared']),
    hostEarningsPaise: j['host_earnings_paise'] as int,
    chargesureRescues: j['chargesure_rescues'] as int,
    petrolLitresAvoided: _d(j['petrol_litres_avoided']),
    co2KgAvoided: _d(j['co2_kg_avoided']),
    estimatedSessions: j['estimated_sessions'] as int,
    factors: (j['factors'] as Map<String, dynamic>).map((k, v) => MapEntry(k, _d(v))),
  );
}

/// GET /bookings/{id}/health, or the CHARGER_OFFLINE detail from /sessions/start.
class ChargeSureOptions {
  final bool online;
  final List<Charger> alternatives; // ranked best first; distance is from the failed charger
  final int creditPaise;

  const ChargeSureOptions({required this.online, required this.alternatives, required this.creditPaise});

  factory ChargeSureOptions.fromJson(Map<String, dynamic> j) => ChargeSureOptions(
    online: j['online'] as bool? ?? false,
    alternatives: (j['alternatives'] as List<dynamic>).map((c) => Charger.fromJson(c as Map<String, dynamic>)).toList(),
    creditPaise: j['credit_paise'] as int,
  );
}

/// GET /payments/{booking_id}: the bill for a finished session.
class Bill {
  final int bookingId;
  final String status; // PENDING | PAID
  final double energyKwh;
  final int totalPaise;
  final int platformFeePaise;
  final int hostSharePaise;
  final int creditPaise;
  final int payablePaise;

  const Bill({
    required this.bookingId,
    required this.status,
    required this.energyKwh,
    required this.totalPaise,
    required this.platformFeePaise,
    required this.hostSharePaise,
    required this.creditPaise,
    required this.payablePaise,
  });

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    bookingId: j['booking_id'] as int,
    status: j['status'] as String,
    energyKwh: _d(j['energy_kwh']),
    totalPaise: j['total_paise'] as int,
    platformFeePaise: j['platform_fee_paise'] as int,
    hostSharePaise: j['host_share_paise'] as int,
    creditPaise: j['credit_paise'] as int,
    payablePaise: j['payable_paise'] as int,
  );
}

class HostDashboard {
  final int todayBookings;
  final double energySoldKwh;
  final int earningsPaise;
  final int pendingEarningsPaise;
  final List<Booking> requests;
  final List<Booking> upcoming;
  final Map<String, dynamic>? liveSession;

  const HostDashboard({
    required this.todayBookings,
    required this.energySoldKwh,
    required this.earningsPaise,
    required this.pendingEarningsPaise,
    required this.requests,
    required this.upcoming,
    required this.liveSession,
  });

  factory HostDashboard.fromJson(Map<String, dynamic> j) {
    final today = j['today'] as Map<String, dynamic>;
    List<Booking> bookings(String key) =>
        (j[key] as List<dynamic>).map((b) => Booking.fromJson(b as Map<String, dynamic>)).toList();
    return HostDashboard(
      todayBookings: today['bookings'] as int,
      energySoldKwh: _d(today['energy_sold_kwh']),
      earningsPaise: today['earnings_paise'] as int,
      pendingEarningsPaise: today['pending_earnings_paise'] as int,
      requests: bookings('requests'),
      upcoming: bookings('upcoming'),
      liveSession: j['live_session'] as Map<String, dynamic>?,
    );
  }
}
