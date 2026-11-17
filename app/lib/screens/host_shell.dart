import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/tab_shell.dart';
import 'host_chargers_screen.dart';
import 'host_dashboard_screen.dart';
import 'profile_screen.dart';

/// Home for someone sharing a charger: today's requests and earnings, their chargers, profile.
class HostShell extends StatelessWidget {
  const HostShell({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return TabShell(
      tabs: [
        ShellTab(
          label: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard,
          builder: (_, _) => HostDashboardScreen(user: user),
        ),
        ShellTab(
          label: 'Chargers',
          icon: Icons.ev_station_outlined,
          selectedIcon: Icons.ev_station,
          builder: (_, visit) => HostChargersScreen(user: user, visit: visit),
        ),
        ShellTab(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          builder: (_, _) => ProfileScreen(user: user, hosting: true),
        ),
      ],
    );
  }
}
