import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import 'host_dashboard_screen.dart';
import 'demo_controls_screen.dart';
import 'impact_screen.dart';
import 'map_screen.dart';

/// Demo login: pick a seeded user. Phone OTP replaces this later.
class UserPickerScreen extends StatefulWidget {
  const UserPickerScreen({super.key});

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  late Future<List<AppUser>> _users = api.users();

  void _open(AppUser user) {
    final screen = user.canDrive ? MapScreen(user: user) : HostDashboardScreen(user: user);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status-bar icons on the navy background
      child: Scaffold(
        backgroundColor: VoltraColors.navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: VoltraColors.green, size: 44),
                    SizedBox(width: 8),
                    Text(
                      'Voltra',
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your neighbour's charger, your next charge.",
                  style: TextStyle(color: Color(0xFFB8C4D0), fontSize: 16),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VoltraColors.green,
                    side: const BorderSide(color: VoltraColors.green),
                  ),
                  icon: const Icon(Icons.eco_outlined),
                  label: const Text('See Voltra’s impact'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImpactScreen())),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Continue as', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFB8C4D0)),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Demo controls'),
                      onPressed: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DemoControlsScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<AppUser>>(
                    future: _users,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Card(
                          child: ErrorView(
                            message: '${snap.error}',
                            onRetry: () => setState(() {
                              _users = api.users();
                            }),
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator(color: VoltraColors.green));
                      }
                      return ListView.separated(
                        itemCount: snap.data!.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => _UserTile(user: snap.data![i], onTap: _open),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final AppUser user;
  final ValueChanged<AppUser> onTap;

  @override
  Widget build(BuildContext context) {
    final role = switch (user.role) {
      'driver' => 'Driver',
      'host' => 'Host',
      _ => 'Driver and host',
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: user.canDrive ? VoltraColors.green : VoltraColors.border,
          foregroundColor: VoltraColors.navy,
          child: Icon(user.canDrive ? Icons.electric_scooter : Icons.home_outlined),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(role),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onTap(user),
      ),
    );
  }
}
