import 'package:latlong2/latlong.dart';

/// Backend address. The Android emulator reaches the laptop at 10.0.2.2.
/// On a real phone, run with `flutter run --dart-define=API_URL=http://LAPTOP_IP:8000`.
/// Release builds allow HTTPS only, so they need the hosted address (`API_URL=https://...`).
const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

/// Demo driver position (Koramangala, Bengaluru) until live GPS is added.
const demoLocation = LatLng(12.9365, 77.6250);

const searchRadiusKm = 5.0;
