import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'push.dart';
import 'screens/user_picker_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars; each screen pads its own content with SafeArea.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const VoltraApp());
  Push.init(); // in the background, after the first frame is queued; a no-op until Firebase is configured
}

class VoltraApp extends StatelessWidget {
  const VoltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Voltra',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        scaffoldMessengerKey: messengerKey, // in-app banners for pushes that arrive while Voltra is open
        home: const UserPickerScreen(),
      ),
    );
  }
}
