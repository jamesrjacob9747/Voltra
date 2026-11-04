import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'user_picker_screen.dart';

/// Placeholder until the host dashboard lands on Day 2.
class HostHomeScreen extends StatelessWidget {
  const HostHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Host · ${user.name}'),
        actions: [
          IconButton(
            tooltip: 'Switch user',
            icon: const Icon(Icons.switch_account),
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => const UserPickerScreen())),
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Host dashboard: bookings to accept, live sessions and earnings. Coming next.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: VoltraColors.muted),
          ),
        ),
      ),
    );
  }
}
