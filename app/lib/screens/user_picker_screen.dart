import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../models.dart';
import '../push.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'demo_controls_screen.dart';
import 'driver_shell.dart';
import 'host_shell.dart';
import 'impact_screen.dart';

/// Welcome and demo login: pick a seeded user. Phone OTP replaces this later.
/// Always navy, in both themes: it is the app's front door.
class UserPickerScreen extends StatefulWidget {
  const UserPickerScreen({super.key});

  @override
  State<UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<UserPickerScreen> {
  late Future<List<AppUser>> _users = api.users();

  void _open(AppUser user) {
    unawaited(Push.signedIn(user.id)); // in the background: login never waits for Firebase
    final home = user.canDrive ? DriverShell(user: user) : HostShell(user: user);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => home));
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    Widget enter(Widget child, int step) => still
        ? child
        : child
              .animate(delay: Motion.stagger * step * 2)
              .fadeIn(duration: Motion.slow, curve: Motion.enter)
              .moveY(begin: 16, end: 0, duration: Motion.slow, curve: Motion.enter);

    final logo = Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: VoltraColors.green, borderRadius: BorderRadius.circular(Radii.lg)),
          child: const Icon(Icons.bolt, color: VoltraColors.navy, size: 38),
        ),
        const SizedBox(width: Gap.md),
        const Text(
          'Voltra',
          style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
      ],
    );

    return AnnotatedRegion(
      value: overlayFor(Brightness.dark), // white status-bar icons on the navy background
      child: Scaffold(
        backgroundColor: VoltraColors.navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 40, Gap.xl, Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                still
                    ? logo
                    : logo
                          .animate()
                          .fadeIn(duration: Motion.slow)
                          .scaleXY(
                            begin: 0.85,
                            end: 1,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutBack,
                          ),
                const SizedBox(height: Gap.lg),
                enter(
                  const Text(
                    'Your neighbour’s charger,\nyour next charge.',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.25),
                  ),
                  1,
                ),
                const SizedBox(height: Gap.sm),
                enter(
                  const Text(
                    'Find a verified charger nearby, book it, and pay by UPI.',
                    style: TextStyle(color: VoltraColors.onNavySoft, fontSize: 15, height: 1.4),
                  ),
                  2,
                ),
                const SizedBox(height: Gap.xl),
                enter(
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Continue as',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: VoltraColors.onNavySoft),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Demo controls'),
                        onPressed: () => _push(const DemoControlsScreen()),
                      ),
                    ],
                  ),
                  3,
                ),
                const SizedBox(height: Gap.sm),
                Expanded(
                  child: FutureBuilder<List<AppUser>>(
                    future: _users,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _LoadError(
                          message: '${snap.error}',
                          onRetry: () => setState(() {
                            _users = api.users();
                          }),
                        );
                      }
                      if (!snap.hasData) return const _UsersLoading();
                      final users = snap.data!;
                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: Gap.sm),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                        itemBuilder: (context, i) => Entrance(
                          index: i,
                          child: _UserTile(user: users[i], onTap: _open),
                        ),
                      );
                    },
                  ),
                ),
                enter(
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: VoltraColors.green),
                      icon: const Icon(Icons.eco_outlined, size: 18),
                      label: const Text('See Voltra’s impact'),
                      onPressed: () => _push(const ImpactScreen()),
                    ),
                  ),
                  4,
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
    return Pressable(
      onTap: () => onTap(user),
      semanticLabel: 'Continue as ${user.name}, $role',
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: VoltraColors.navyRaised,
          borderRadius: Radii.card,
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: user.canDrive ? VoltraColors.green : Colors.white12,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(
                user.canDrive ? Icons.electric_scooter : Icons.home_outlined,
                color: user.canDrive ? VoltraColors.navy : Colors.white,
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(role, style: const TextStyle(color: VoltraColors.onNavySoft, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: VoltraColors.onNavySoft),
          ],
        ),
      ),
    );
  }
}

/// Placeholder tiles on navy while the users load.
class _UsersLoading extends StatelessWidget {
  const _UsersLoading();

  @override
  Widget build(BuildContext context) {
    final tiles = Column(
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: Gap.md),
            decoration: const BoxDecoration(color: VoltraColors.navyRaised, borderRadius: Radii.card),
          ),
      ],
    );
    final body = Semantics(label: 'Loading users', child: tiles);
    if (Motion.reduced(context)) return body;
    return body
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: const Duration(milliseconds: 1200), color: Colors.white10);
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: VoltraColors.onNavySoft),
            const SizedBox(height: Gap.md),
            const Text(
              'Couldn’t reach Voltra',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoltraColors.onNavySoft, height: 1.4),
            ),
            const SizedBox(height: Gap.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
