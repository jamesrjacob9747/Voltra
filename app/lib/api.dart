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

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool admin = false,
    bool isRetry = false,
  }) async {
    final uri = _base.replace(path: path, queryParameters: query);
    final request = http.Request(method, uri);
    if (admin && adminToken.isNotEmpty) request.headers['X-Admin-Token'] = adminToken;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final http.Response resp;
      try {
        resp = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
      } on http.ClientException {
        // Usually a kept-alive connection the server had already closed. A GET is safe to send
        // again; anything else is not (it could create a second booking), so it is reported.
        if (method == 'GET' && !isRetry) return await _send(method, path, query: query, admin: admin, isRetry: true);
        throw ApiException("Lost the connection to the Voltra server. Please try again.");
      }
      final decoded = resp.body.isEmpty ? null : jsonDecode(utf8.decode(resp.bodyBytes));
      if (resp.statusCode >= 400) {
        final detail = decoded is Map ? decoded['detail'] : null;
        if (detail is Map<String, dynamic> && detail['code'] == 'CHARGER_OFFLINE') {
          throw ApiException('This charger is offline right now.', code: 'CHARGER_OFFLINE', data: detail);
        }
        // FastAPI validation errors (422) arrive as a list: show the first message.
        if (detail is List && detail.isNotEmpty && detail.first is Map && detail.first['msg'] is String) {
          throw ApiException(detail.first['msg'] as String);
        }
        throw ApiException(detail is String ? detail : 'Server error ${resp.statusCode}');
      }
      return decoded;
    } on SocketException {
      throw ApiException("Can't reach the Voltra server at $baseUrl");
    } on HandshakeException {
      throw ApiException("Couldn't open a secure connection to $baseUrl");
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

  /// ChargeSure: is the booked charger online, and if not, where can the driver go instead?
  Future<ChargeSureOptions> bookingHealth(int bookingId) async =>
      ChargeSureOptions.fromJson(await _get('/bookings/$bookingId/health') as Map<String, dynamic>);

  /// Moves the booking to [toChargerId] and adds the ChargeSure credit. Returns the new booking.
  Future<Booking> transferBooking(int bookingId, int toChargerId) async => Booking.fromJson(
    await _send('POST', '/bookings/$bookingId/transfer', body: {'to_charger_id': toChargerId}) as Map<String, dynamic>,
  );

  /// A Razorpay test order, or mode "demo" when the server has no Razorpay keys or nothing is due.
  Future<PaymentOrder> createOrder(int bookingId) async =>
      PaymentOrder.fromJson(await _send('POST', '/payments/$bookingId/order') as Map<String, dynamic>);

  /// The server checks Razorpay's signature with the key secret, then marks the bill paid.
  Future<Bill> verifyPayment({
    required int bookingId,
    required String orderId,
    required String paymentId,
    required String signature,
  }) async => Bill.fromJson(
    await _send(
      'POST',
      '/payments/verify',
      body: {
        'booking_id': bookingId,
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      },
    ) as Map<String, dynamic>,
  );

  Future<Bill> demoPay(int bookingId) async =>
      Bill.fromJson(await _send('POST', '/payments/$bookingId/demo-pay', admin: true) as Map<String, dynamic>);

  Future<void> submitReview({
    required int bookingId,
    required int reviewerId,
    required int rating,
    List<String> tags = const [],
  }) => _send(
    'POST',
    '/reviews',
    body: {'booking_id': bookingId, 'reviewer_id': reviewerId, 'rating': rating, 'tags': tags},
  );

  /// Host adds a charger. The response carries the new code (e.g. CHG009) drivers type to start.
  Future<Charger> createCharger({
    required int hostId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required String connectorType,
    required double powerKw,
    required int pricePerKwhPaise,
    required String availableFrom,
    required String availableTo,
    required bool autoApprove,
  }) async => Charger.fromJson(
    await _send(
      'POST',
      '/chargers',
      body: {
        'host_id': hostId,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'connector_type': connectorType,
        'power_kw': powerKw,
        'base_price_per_kwh_paise': pricePerKwhPaise,
        'available_from': availableFrom,
        'available_to': availableTo,
        'auto_approve': autoApprove,
      },
    ) as Map<String, dynamic>,
  );

  Future<List<Charger>> hostChargers(int hostId) async {
    final list = await _get('/host/$hostId/chargers') as List<dynamic>;
    return list.map((j) => Charger.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Impact> impact() async => Impact.fromJson(await _get('/impact') as Map<String, dynamic>);

  // Stage demo controls.
  Future<void> setPlugOnline(String deviceId, bool online) =>
      _send('POST', '/admin/plugs/$deviceId/online', body: {'online': online}, admin: true);

  Future<void> resetDemo() => _send('POST', '/admin/reset', admin: true);
}

const qrPrefix = 'voltra://charger/';

final api = VoltraApi();
