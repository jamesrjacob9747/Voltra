import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/format.dart';
import 'package:voltra_app/models.dart';

void main() {
  test('rupees formats paise like the backend bill', () {
    expect(rupees(2220), '₹22.20');
    expect(rupees(1200), '₹12');
    expect(rupees(333), '₹3.33');
    expect(pricePerKwh(1100), '₹11/kWh');
  });

  test('distance switches from metres to km', () {
    expect(distance(0.37), '370 m');
    expect(distance(2.04), '2.0 km');
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
