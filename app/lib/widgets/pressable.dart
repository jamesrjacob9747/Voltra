import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';

/// Makes a card or tile feel tappable: it shrinks slightly under the finger and ticks on tap.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.haptic = true, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down && !still ? 0.97 : 1,
          duration: Motion.fast,
          curve: Motion.enter,
          child: widget.child,
        ),
      ),
    );
  }
}
