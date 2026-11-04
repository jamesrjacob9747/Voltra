/// Field rules for adding a charger. They mirror the backend's `ChargerCreate` checks, so
/// mistakes show inline before anything is sent.
library;

String? validateChargerName(String? v) {
  final s = v?.trim() ?? '';
  if (s.length < 3) return 'At least 3 characters';
  if (s.length > 80) return 'At most 80 characters';
  return null;
}

String? validateAddress(String? v) {
  final s = v?.trim() ?? '';
  if (s.length < 5) return 'Enter the full address';
  if (s.length > 160) return 'At most 160 characters';
  return null;
}

String? validatePowerKw(String? v) {
  final kw = double.tryParse(v?.trim() ?? '');
  if (kw == null) return 'Enter a number, e.g. 3.3';
  if (kw < 0.5 || kw > 22) return 'Between 0.5 and 22 kW';
  return null;
}

String? validatePriceRupees(String? v) {
  final rs = double.tryParse(v?.trim() ?? '');
  if (rs == null) return 'Enter a price, e.g. 12';
  if (rs < 5 || rs > 50) return 'Between ₹5 and ₹50 per kWh';
  return null;
}

/// "HH:MM", which the backend expects.
String hhmm(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Zero-padded HH:MM strings compare correctly as text.
String? validateHours(String from, String to) => from.compareTo(to) < 0 ? null : 'Opening time must be before closing';

int rupeesToPaise(String v) => (double.parse(v.trim()) * 100).round();
