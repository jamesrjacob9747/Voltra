import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/charger_form.dart';

// The same limits the backend enforces in ChargerCreate.
void main() {
  test('name and address lengths', () {
    expect(validateChargerName('A'), isNotNull);
    expect(validateChargerName('  Manoj’s Socket  '), isNull);
    expect(validateChargerName('x' * 81), isNotNull);
    expect(validateAddress('Blr'), isNotNull);
    expect(validateAddress('80 Feet Road, Koramangala'), isNull);
  });

  test('power and price ranges', () {
    expect(validatePowerKw('0'), isNotNull);
    expect(validatePowerKw('3.3'), isNull);
    expect(validatePowerKw('23'), isNotNull);
    expect(validatePowerKw('abc'), isNotNull);
    expect(validatePriceRupees('4'), isNotNull);
    expect(validatePriceRupees('12.5'), isNull);
    expect(validatePriceRupees('51'), isNotNull);
  });

  test('opening hours must be in order', () {
    expect(hhmm(8, 5), '08:05');
    expect(validateHours('08:00', '22:00'), isNull);
    expect(validateHours('22:00', '08:00'), isNotNull);
    expect(validateHours('09:00', '09:00'), isNotNull);
  });

  test('rupees convert to paise without float drift', () {
    expect(rupeesToPaise('12'), 1200);
    expect(rupeesToPaise('12.35'), 1235);
    expect(rupeesToPaise(' 9.99 '), 999);
  });
}
