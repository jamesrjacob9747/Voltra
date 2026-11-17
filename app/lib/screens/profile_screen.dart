import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'demo_controls_screen.dart';
import 'driver_shell.dart';
import 'host_shell.dart';
import 'impact_screen.dart';
import 'user_picker_screen.dart';

/// Who is signed in, and the ways out of the current mode: switch between driving and
/// hosting, switch user, and the demo controls.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user, required this.hosting});

  final AppUser user;

  /// True inside the host shell, false inside the driver shell.
  final bool hosting;

  void _replace(BuildContext context, Widget screen) =>
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final canSwitchMode = hosting ? user.canDrive : user.canHost;
    final role = switch (user.role) {
      'driver' => 'Driver',
      'host' => 'Host',
      _ => 'Driver and host',
    };

    final rows = <Widget>[
      if (canSwitchMode)
        _Row(
          icon: hosting ? Icons.electric_scooter : Icons.home_work_outlined,
          title: hosting ? 'Switch to driving' : 'Switch to hosting',
          subtitle: hosting ? 'Find and book a charger' : 'Requests, earnings and your chargers',
          highlight: true,
          onTap: () => _replace(context, hosting ? DriverShell(user: user) : HostShell(user: user)),
        ),
      if (hosting)
        _Row(
          icon: Icons.eco_outlined,
          title: 'Voltra impact',
          subtitle: 'Energy shared, petrol and CO₂ avoided',
          onTap: () => _push(context, const ImpactScreen()),
        ),
      _Row(
        icon: Icons.tune,
        title: 'Demo controls',
        subtitle: 'Switch chargers on or off, reset demo data',
        onTap: () => _push(context, const DemoControlsScreen()),
      ),
      _Row(
        icon: Icons.switch_account_outlined,
        title: 'Switch user',
        subtitle: 'Sign in as someone else',
        onTap: () => _replace(context, const UserPickerScreen()),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
        children: [
          Entrance(
            child: Container(
              padding: const EdgeInsets.all(Gap.xl),
              decoration: const BoxDecoration(color: VoltraColors.navy, borderRadius: Radii.card),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: VoltraColors.green,
                    foregroundColor: VoltraColors.navy,
                    child: Text(
                      user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.phone == null ? role : '$role · ${user.phone}',
                          style: const TextStyle(color: VoltraColors.onNavySoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          for (final (i, row) in rows.indexed) ...[Entrance(index: i + 1, child: row), const SizedBox(height: Gap.md)],
          Entrance(index: rows.length + 1, child: const _Appearance()),
          const SizedBox(height: Gap.xl),
          Center(
            child: Text('Voltra · hackathon build', style: TextStyle(color: vc.faint, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Light, dark, or whatever the phone is set to.
class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: vc.card,
        borderRadius: Radii.card,
        border: Border.all(color: vc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vc.ink),
          ),
          const SizedBox(height: Gap.md),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (context, mode, _) => SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => themeMode.value = s.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: highlight ? vc.brandTint : vc.card,
          borderRadius: Radii.card,
          border: Border.all(color: highlight ? Colors.transparent : vc.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: highlight ? vc.brand : vc.raised,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(icon, color: highlight ? vc.onBrand : vc.ink, size: 22),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: vc.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: vc.muted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: vc.faint),
          ],
        ),
      ),
    );
  }
}
