import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// Something failed to load: say what, and offer the retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: vc.raised, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_rounded, size: 38, color: vc.muted),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              'Couldn’t load this',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: vc.ink),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: vc.muted, height: 1.4),
            ),
            const SizedBox(height: Gap.lg),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
