import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// The one main action of a screen, pinned to the bottom. Optionally shows what it will cost
/// on the left ("₹12/kWh · now"), the way a food app shows the cart total beside "Place order".
class PrimaryBar extends StatelessWidget {
  const PrimaryBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.amount,
    this.amountCaption,
    this.secondary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner in place of the label and blocks further taps.
  final bool busy;
  final String? amount;
  final String? amountCaption;

  /// A quieter action shown under the main one (for example "Cancel booking").
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final button = FilledButton(
      onPressed: busy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: Motion.fast,
        child: busy
            ? SizedBox(
                key: const ValueKey('busy'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: vc.brand),
              )
            : Row(
                key: ValueKey(label),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: Gap.sm)],
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                ],
              ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: vc.card,
        border: Border(top: BorderSide(color: vc.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (amount == null)
                button
              else
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          amount!,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: vc.ink),
                        ),
                        if (amountCaption != null)
                          Text(amountCaption!, style: TextStyle(fontSize: 12, color: vc.muted)),
                      ],
                    ),
                    const SizedBox(width: Gap.lg),
                    Expanded(child: button),
                  ],
                ),
              if (secondary != null) ...[const SizedBox(height: Gap.xs), secondary!],
            ],
          ),
        ),
      ),
    );
  }
}
