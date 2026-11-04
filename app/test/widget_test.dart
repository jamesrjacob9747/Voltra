import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/format.dart';
import 'package:voltra_app/models.dart';

void main() {
  test('rupees formats paise like the backend bill', () {
    expect(rupees(2220), '₹22.20');
    expect(rupees(1200), '₹12');
    expect(rupees(333), '₹3.33');
    expect(pricePerKwh(1100), '₹11/kWh');
    expect(rupees(100, exact: true), '₹1.00');
  });

  test('distance switches from metres to km', () {
    expect(distance(0.37), '370 m');
    expect(distance(2.04), '2.0 km');
  });

  test('time helpers match what the backend expects and shows', () {
    final t = DateTime(2026, 11, 4, 16, 38);
    expect(clock(t), '4:38 PM');
    expect(clock(DateTime(2026, 11, 4, 0, 5)), '12:05 AM');
    expect(isoMinute(t), '2026-11-04T16:38');
    expect(minutes(147), '2 h 27 min');
    expect(minutes(45), '45 min');
  });

  test('ChargeSureOptions parses the CHARGER_OFFLINE detail (no "online" key)', () {
    final o = ChargeSureOptions.fromJson({'code': 'CHARGER_OFFLINE', 'alternatives': [], 'credit_paise': 2000});
    expect(o.online, isFalse);
    expect(o.alternatives, isEmpty);
    expect(rupees(o.creditPaise), '₹20');
  });

  test('elapsed shows a stopwatch', () {
    expect(elapsed(2538), '00:42:18');
    expect(elapsed(8880), '02:28:00');
  });

  test('LiveSession and Bill parse the PRD billing example', () {
    final s = LiveSession.fromJson({
      'session_id': 1,
      'booking_id': 1,
      'charger': {'id': 1, 'name': "Manoj's Home Charger"},
      'status': 'COMPLETED',
      'online': true,
      'voltage': null,
      'current': null,
      'power_kw': 0.0,
      'energy_kwh': 1.85,
      'duration_s': 8880,
      'price_per_kwh_paise': 1200,
      'cost_paise': 2220,
      'demo_speed': 30.0,
    });
    expect(s.completed, isTrue);
    expect(rupees(s.costPaise), '₹22.20');

    final b = Bill.fromJson({
      'booking_id': 1,
      'status': 'PENDING',
      'energy_kwh': 1.85,
      'total_paise': 2220,
      'platform_fee_paise': 333,
      'host_share_paise': 1887,
      'credit_paise': 0,
      'payable_paise': 2220,
    });
    expect(b.platformFeePaise + b.hostSharePaise, b.totalPaise);
  });

  test('Booking and MatchEstimate parse server payloads', () {
    final b = Booking.fromJson({
      'id': 3,
      'status': 'PENDING',
      'charger': {'id': 7, 'name': 'Ejipura Garage Socket', 'device_id': 'CHG007'},
      'driver': {'id': 5, 'name': 'Arjun'},
      'vehicle_id': 1,
      'start_time': '2026-11-04T14:05',
      'end_time': '2026-11-04T16:05',
      'credit_paise': 0,
      'transferred_from_booking_id': null,
      'session_id': null,
    });
    expect(b.start, DateTime(2026, 11, 4, 14, 5));
    expect(b.canCancel, isTrue);
    expect(b.isActive, isTrue);
    expect(b.canStart, isFalse); // pending: host hasn't confirmed yet

    final e = MatchEstimate.fromJson({
      'energy_kwh': 1.83,
      'power_kw': 0.75,
      'charge_minutes': 147,
      'arrive_at': '2026-11-04T12:10',
      'finish_at': '2026-11-04T14:37',
      'est_cost_paise': 2200,
    });
    expect(e.finishAt.difference(e.arriveAt).inMinutes, 147);
  });

  test('Charger parses the /chargers payload', () {
    final c = Charger.fromJson({
      'id': 1,
      'name': "Manoj's Home Charger",
      'host': {'id': 1, 'name': 'Manoj'},
      'rating': 4.8,
      'connector_type': '15A',
      'power_kw': 3.3,
      'base_price_per_kwh_paise': 1200,
      'price_now_per_kwh_paise': 1200,
      'available_from': '00:00',
      'available_to': '23:59',
      'auto_approve': true,
      'verified': true,
      'device_id': 'CHG001',
      'successful_sessions': 140,
      'online': true,
      'last_heartbeat_s': 0,
      'confidence': {
        'score': 99,
        'band': 'Highly reliable',
        'breakdown': {'iot_online': 30.0, 'host_confirmed': 20, 'successful_sessions': 19.6},
      },
      'location': {'lat': 12.938, 'lng': 77.6224, 'exact': false},
      'address': null,
      'distance_km': 0.15,
    });
    expect(c.confidence.score, 99);
    expect(c.confidence.breakdown['host_confirmed'], 20.0);
    expect(c.connectorLabel, '15A socket');
    expect(c.exactLocation, isFalse);
  });
}
