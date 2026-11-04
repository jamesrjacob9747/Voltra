import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'format.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;

  /// Machine-readable code when the server sends one, e.g. CHARGER_OFFLINE (with ChargeSure data).
  final String? code;
  final Map<String, dynamic>? data;

  const ApiException(this.message, {this.code, this.data});

  @override
  String toString() => message;
}

class VoltraApi {
  VoltraApi({String baseUrl = apiBaseUrl, http.Client? client})
    : _base = Uri.parse(baseUrl),
      _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;
  static const _timeout = Duration(seconds: 8);

  String get baseUrl => _base.toString();

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = _base.replace(path: path, queryParameters: query);
    final request = http.Request(method, uri);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final resp = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
      final decoded = resp.body.isEmpty ? null : jsonDecode(utf8.decode(resp.bodyBytes));
      if (resp.statusCode >= 400) {
        final detail = decoded is Map ? decoded['detail'] : null;
        if (detail is Map<String, dynamic> && detail['code'] == 'CHARGER_OFFLINE') {
          throw ApiException('This charger is offline right now.', code: 'CHARGER_OFFLINE', data: detail);
        }
        throw ApiException(detail is String ? detail : 'Server error ${resp.statusCode}');
      }
      return decoded;
    } on SocketException {
      throw ApiException("Can't reach the Voltra server at $baseUrl");
    } on TimeoutException {
      throw ApiException('The Voltra server at $baseUrl took too long to answer');
    }
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);

  Duration? _clockOffset;

  /// The server's wall clock. Booking times are server-local, so a phone with a wrong clock
  /// still books the slot the driver sees.
  Future<DateTime> serverNow() async {
    if (_clockOffset == null) {
      final j = await _get('/health') as Map<String, dynamic>;
      _clockOffset = DateTime.parse(j['server_time'] as String).difference(DateTime.now());
    }
    return DateTime.now().add(_clockOffset!);
  }

  Future<List<AppUser>> users() async {
    final list = await _get('/users') as List<dynamic>;
    return list.map((j) => AppUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Charger>> chargers({required double lat, required double lng, double radiusKm = 5}) async {
    final list = await _get('/chargers', {'lat': '$lat', 'lng': '$lng', 'radius_km': '$radiusKm'}) as List<dynamic>;
    return list.map((j) => Charger.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Charger> charger(int id, {int? userId}) async {
    final j = await _get('/chargers/$id', userId == null ? null : {'user_id': '$userId'});
    return Charger.fromJson(j as Map<String, dynamic>);
  }

  Future<List<Vehicle>> vehicles(int userId) async {
    final list = await _get('/users/$userId/vehicles') as List<dynamic>;
    return list.map((j) => Vehicle.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<MatchResult>> match({
    required int vehicleId,
    required int currentPct,
    required int targetPct,
    required String readyBy, // "HH:MM", server-local
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final j = await _send(
      'POST',
      '/match',
      body: {
        'vehicle_id': vehicleId,
        'current_pct': currentPct,
        'target_pct': targetPct,
        'ready_by': readyBy,
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      },
    ) as Map<String, dynamic>;
    return (j['results'] as List<dynamic>).map((r) => MatchResult.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Booking> createBooking({
    required int driverId,
    required int chargerId,
    int? vehicleId,
    required DateTime start,
    required DateTime end,
  }) async {
    final j = await _send(
      'POST',
      '/bookings',
      body: {
        'driver_id': driverId,
        'charger_id': chargerId,
        'vehicle_id': vehicleId,
        'start_time': isoMinute(start),
        'end_time': isoMinute(end),
      },
    );
    return Booking.fromJson(j as Map<String, dynamic>);
  }

  Future<Booking> booking(int id) async => Booking.fromJson(await _get('/bookings/$id') as Map<String, dynamic>);

  Future<List<Booking>> driverBookings(int driverId) async {
    final list = await _get('/bookings', {'driver_id': '$driverId'}) as List<dynamic>;
    return list.map((j) => Booking.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// action: accept | decline | cancel | arrive
  Future<Booking> updateBooking(int id, String action, {required int actorId}) async {
    final j = await _send('PATCH', '/bookings/$id', body: {'action': action, 'actor_id': actorId});
    return Booking.fromJson(j as Map<String, dynamic>);
  }

  Future<HostDashboard> hostDashboard(int hostId) async =>
      HostDashboard.fromJson(await _get('/host/$hostId/dashboard') as Map<String, dynamic>);

  /// [qr] is the scanned payload, `voltra://charger/<device_id>`.
  Future<LiveSession> startSession(int bookingId, String qr) async => LiveSession.fromJson(
    await _send('POST', '/sessions/start', body: {'booking_id': bookingId, 'qr': qr}) as Map<String, dynamic>,
  );

  Future<LiveSession> liveSession(int sessionId) async =>
      LiveSession.fromJson(await _get('/sessions/$sessionId/live') as Map<String, dynamic>);

  Future<LiveSession> stopSession(int sessionId) async =>
      LiveSession.fromJson(await _send('POST', '/sessions/$sessionId/stop') as Map<String, dynamic>);

  Future<Bill> bill(int bookingId) async => Bill.fromJson(await _get('/payments/$bookingId') as Map<String, dynamic>);
}

const qrPrefix = 'voltra://charger/';

final api = VoltraApi();
