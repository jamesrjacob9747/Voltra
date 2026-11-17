import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../design/tokens.dart';
import '../theme.dart';

/// Fades and lifts a list item into place; [index] staggers a list top to bottom.
/// Only the first few items are delayed, so a long list never keeps the user waiting.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return child
        .animate(delay: Motion.stagger * math.min(index, 8))
        .fadeIn(duration: Motion.medium, curve: Motion.enter)
        .moveY(begin: 14, end: 0, duration: Motion.slow, curve: Motion.enter);
  }
}

/// A number that rolls to its new value instead of jumping: `CountUp(value: paise, format: ...)`.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.format, this.style, this.duration = Motion.count});

  final double value;

  /// Turns the in-between value into text, for example `(v) => rupees(v.round(), exact: true)`.
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      // `begin` only applies the first time; later changes roll on from the figure on screen.
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Motion.enter,
      // Announce only the final value, not every frame on the way there.
      builder: (_, v, _) => Text(format(v), style: style, semanticsLabel: format(value)),
    );
  }
}

/// A tick that draws itself inside a circle that pops in: payment done, booking confirmed.
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({super.key, this.size = 72, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? context.vc.success;
    final still = Motion.reduced(context);
    return Semantics(
      label: 'Done',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (_, t, _) {
          final pop = Curves.easeOutBack.transform((t / 0.55).clamp(0, 1));
          final draw = Curves.easeOut.transform(((t - 0.4) / 0.6).clamp(0, 1));
          return Transform.scale(
            scale: pop,
            child: CustomPaint(
              size: Size.square(size),
              painter: _CheckPainter(fill: fill, tick: context.vc.onBrand, progress: draw),
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.fill, required this.tick, required this.progress});

  final Color fill;
  final Color tick;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawCircle(Offset(s / 2, s / 2), s / 2, Paint()..color = fill);
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress || old.fill != fill || old.tick != tick;
}
