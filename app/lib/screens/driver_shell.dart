import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/tab_shell.dart';
import 'impact_screen.dart';
import 'map_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';

/// Home for someone looking for a charge: map, their bookings, Voltra's impact, profile.
class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return TabShell(
      tabs: [
        ShellTab(
          label: 'Home',
          icon: Icons.map_outlined,
          selectedIcon: Icons.map,
          builder: (_, visit) => MapScreen(user: user, visit: visit),
        ),
        ShellTab(
          label: 'Bookings',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          builder: (_, visit) => MyBookingsScreen(user: user, visit: visit),
        ),
        ShellTab(
          label: 'Impact',
          icon: Icons.eco_outlined,
          selectedIcon: Icons.eco,
          builder: (_, visit) => ImpactScreen(visit: visit),
        ),
        ShellTab(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          builder: (_, _) => ProfileScreen(user: user, hosting: false),
        ),
      ],
    );
  }
}
