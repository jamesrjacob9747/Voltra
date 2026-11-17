import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// "Nothing here yet": an icon, what's missing, and what to do about it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Inline version for a section of a longer page: no big icon disc, less padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final disc = Container(
      width: compact ? 44 : 84,
      height: compact ? 44 : 84,
      decoration: BoxDecoration(color: vc.brandTint, shape: BoxShape.circle),
      child: Icon(icon, size: compact ? 22 : 38, color: vc.brand),
    );
    final body = Padding(
      padding: EdgeInsets.all(compact ? Gap.lg : Gap.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          disc,
          SizedBox(height: compact ? Gap.md : Gap.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: compact ? 15 : 18, fontWeight: FontWeight.w800, color: vc.ink),
          ),
          if (hint != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: vc.muted, height: 1.4),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Gap.lg),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
    final centred = Center(child: SingleChildScrollView(child: body));
    if (Motion.reduced(context)) return centred;
    return centred.animate().fadeIn(duration: Motion.medium).moveY(begin: 12, end: 0, curve: Motion.enter);
  }
}
