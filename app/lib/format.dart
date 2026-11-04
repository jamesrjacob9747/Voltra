/// Money is integer paise everywhere, matching the backend.
String rupees(int paise) {
  final whole = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0 ? '₹$whole' : '₹$whole.${rest.toString().padLeft(2, '0')}';
}

String pricePerKwh(int paise) => '${rupees(paise)}/kWh';

String distance(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

String heartbeatAge(int seconds) {
  if (seconds < 60) return '$seconds s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
