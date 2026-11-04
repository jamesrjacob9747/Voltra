/// Money is integer paise everywhere, matching the backend.
/// "₹12" for round prices; [exact] always shows paise ("₹1.00"), for amounts that count up.
String rupees(int paise, {bool exact = false}) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0 && !exact ? '₹$whole' : '₹$whole.${rest.toString().padLeft(2, '0')}';
}

String pricePerKwh(int paise) => '${rupees(paise)}/kWh';

String distance(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

/// "4:38 PM"
String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "2 h 27 min", "45 min"
String minutes(int total) {
  if (total < 60) return '$total min';
  final m = total % 60;
  return m == 0 ? '${total ~/ 60} h' : '${total ~/ 60} h $m min';
}

/// Naive wall-clock ISO to the minute, the format the backend expects ("2026-11-04T14:05").
String isoMinute(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}T${two(t.hour)}:${two(t.minute)}';
}

/// Stopwatch style: "00:42:18"
String elapsed(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(seconds ~/ 3600)}:${two(seconds % 3600 ~/ 60)}:${two(seconds % 60)}';
}

String heartbeatAge(int seconds) {
  if (seconds < 60) return '$seconds s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
