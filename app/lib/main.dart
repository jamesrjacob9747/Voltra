import 'package:flutter/material.dart';

import 'screens/user_picker_screen.dart';
import 'theme.dart';

void main() => runApp(const VoltraApp());

class VoltraApp extends StatelessWidget {
  const VoltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voltra',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const UserPickerScreen(),
    );
  }
}
