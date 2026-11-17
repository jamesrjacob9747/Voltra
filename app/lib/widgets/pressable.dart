import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// Makes a card or tile feel tappable: it shrinks slightly under the finger and ticks on tap.
/// It also works from a keyboard: Tab focuses it (with a visible outline) and Enter or Space
/// activates it. Disabled (null [onTap]) means it can't be focused or activated.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic = true,
    this.semanticLabel,
    this.focusRadius = Radii.card,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;
  final String? semanticLabel;

  /// Corner radius of the keyboard-focus outline; match the child's shape.
  final BorderRadius focusRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  void _set(bool down) {
    if (widget.onTap == null || _down == down) return;
    setState(() => _down = down);
  }

  void _activate() {
    if (widget.onTap == null) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        // Default shortcuts map Enter and Space to ActivateIntent.
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _activate())},
        onShowFocusHighlight: (show) => setState(() => _focused = show),
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: enabled ? _activate : null,
          child: AnimatedScale(
            scale: _down && !still ? 0.97 : 1,
            duration: Motion.fast,
            curve: Motion.enter,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: widget.focusRadius,
                border: _focused && enabled ? Border.all(color: context.vc.brand, width: 2.5) : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
