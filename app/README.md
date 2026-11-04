# Voltra app

Flutter (Android) client for Voltra: driver mode (map, ChargeMatch, booking, QR start, live charging, bill, payment) and host mode (dashboard, accept/decline).

How to run it, test it and point it at the backend: see the [root README](../README.md#app-run-it). Stage instructions: [DEMO.md](../DEMO.md).

```
lib/
  main.dart      app entry, theme
  api.dart       Voltra API client (all HTTP lives here)
  models.dart    JSON models matching the API
  config.dart    API_URL, demo location
  format.dart    money, time and distance formatting
  theme.dart     colours and Material theme
  screens/       one file per screen
  widgets/       shared widgets
```
