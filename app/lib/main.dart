import 'package:flutter/material.dart';

import 'push.dart';
import 'screens/user_picker_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoltraApp());
  Push.init(); // in the background, after the first frame is queued; a no-op until Firebase is configured
}

class VoltraApp extends StatelessWidget {
  const VoltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voltra',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: messengerKey, // in-app banners for pushes that arrive while Voltra is open
      home: const UserPickerScreen(),
    );
  }
}
