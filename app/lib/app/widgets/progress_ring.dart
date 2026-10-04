import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/motion.dart';

/// Circular progress that springs to its value and re-animates on change.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.stroke = 6,
    this.color,
    this.trackColor,
    this.child,
  });

  /// 0..1, or null for "no data" (empty track).
  final double? value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = AppMotion.of(context);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value ?? 0),
        duration: motion.slow,
        curve: motion.spatial,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(
            value: v,
            stroke: stroke,
            color: color ?? scheme.primary,
            track: trackColor ?? scheme.surfaceContainerHighest,
          ),
          child: Center(child: child),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  final double value;
  final double stroke;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = track);
    final sweep = (value.clamp(0.0, 1.0)) * math.pi * 2;
    if (sweep > 0.001) {
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
