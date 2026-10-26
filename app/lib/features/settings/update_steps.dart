import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app/theme/motion.dart';
import '../../core/icons/lec_icons.dart';

/// Where a step of the update (or move) window is.
enum StepStatus { waiting, active, done, failed }

/// One step: its icon, title and what's happening, with [below] (a progress
/// bar, a command) under it.
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.state,
    required this.title,
    this.detail,
    this.below,
    this.checkDelay = Duration.zero,
  });

  final StepStatus state;
  final String title;
  final String? detail;
  final Widget? below;

  /// How long the check waits before it draws: steps that finish together
  /// check off one after another.
  final Duration checkDelay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepIcon(state, checkDelay: checkDelay),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: state == StepStatus.waiting
                        ? scheme.onSurfaceVariant
                        : null,
                  ),
                ),
                if (detail case final detail?)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: state == StepStatus.failed
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                if (below case final below?)
                  Padding(padding: const EdgeInsets.only(top: 8), child: below),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A step's icon. A step that finishes gets a check that draws itself; with
/// reduced motion the icons just change.
class StepIcon extends StatelessWidget {
  const StepIcon(this.state, {super.key, this.checkDelay = Duration.zero});

  final StepStatus state;
  final Duration checkDelay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = AppMotion.of(context);
    final icon = switch (state) {
      StepStatus.waiting => Icon(
        LecIcons.pending,
        key: const ValueKey(StepStatus.waiting),
        size: 22,
        color: scheme.outline,
      ),
      StepStatus.active => const Padding(
        key: ValueKey(StepStatus.active),
        padding: EdgeInsets.all(2),
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      StepStatus.done => DrawnCheck(
        key: const ValueKey(StepStatus.done),
        delay: checkDelay,
      ),
      StepStatus.failed => Icon(
        LecIcons.missed,
        key: const ValueKey(StepStatus.failed),
        size: 22,
        color: scheme.error,
      ),
    };
    return SizedBox.square(
      dimension: 22,
      child: AnimatedSwitcher(
        duration: motion.fast,
        switchInCurve: motion.effects,
        switchOutCurve: motion.effects,
        child: icon,
      ),
    );
  }
}

/// A filled circle that pops in over the waiting ring, then a check drawn
/// across it.
class DrawnCheck extends StatefulWidget {
  const DrawnCheck({super.key, this.size = 22, this.delay = Duration.zero});

  final double size;
  final Duration delay;

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck>
    with SingleTickerProviderStateMixin {
  static const _draw = Duration(milliseconds: 650);
  late final _controller = AnimationController(vsync: this);
  Curve _pop = Curves.linear;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = AppMotion.of(context);
    _pop = motion.spatialFast;
    if (_controller.value == 0 && !_controller.isAnimating) {
      // The delay is the start of the animation (no timer to outlive it).
      _controller.duration = motion.duration(widget.delay + _draw);
      if (_controller.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.delay + _draw;
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = start >= 1
            ? 1.0
            : ((_controller.value - start) / (1 - start)).clamp(0.0, 1.0);
        // The circle in the first half, with a little bounce; the check after.
        final circle = _pop.transform(math.min(1, t / 0.5));
        final check = Curves.easeOutCubic.transform(
          ((t - 0.35) / 0.65).clamp(0.0, 1.0),
        );
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _CheckPainter(
            circle: circle,
            check: check,
            ring: scheme.outline,
            fill: scheme.primary,
            mark: scheme.onPrimary,
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.circle,
    required this.check,
    required this.ring,
    required this.fill,
    required this.mark,
  });

  final double circle;
  final double check;
  final Color ring;
  final Color fill;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    if (circle < 1) {
      canvas.drawCircle(
        center,
        radius - 1.5,
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(center, radius * circle, Paint()..color = fill);
    if (check <= 0) return;
    final s = size.shortestSide;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.36);
    final metric = path.computeMetrics().single;
    canvas.drawPath(
      metric.extractPath(0, metric.length * check),
      Paint()
        ..color = mark
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.circle != circle ||
      old.check != check ||
      old.ring != ring ||
      old.fill != fill ||
      old.mark != mark;
}

/// A progress bar that glides to each new value (a jump with reduced
/// motion); [value] null: indeterminate.
class GlidingProgress extends StatelessWidget {
  const GlidingProgress({super.key, this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value == null) return const LinearProgressIndicator();
    final motion = AppMotion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0.0, 1.0)),
      duration: motion.duration(const Duration(milliseconds: 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => LinearProgressIndicator(value: value),
    );
  }
}

/// A shell command to copy, in a monospace box.
class CommandBox extends StatelessWidget {
  const CommandBox(
    this.command, {
    super.key,
    required this.copyLabel,
    required this.onCopy,
  });

  final String command;
  final String copyLabel;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: SelectableText(
                  command,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            IconButton(
              onPressed: onCopy,
              tooltip: copyLabel,
              icon: const Icon(LecIcons.copy, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// 45.6 MB, 820 KB.
String formatBytes(int bytes) => bytes >= 1000 * 1000
    ? '${(bytes / 1e6).toStringAsFixed(1)} MB'
    : '${(bytes / 1e3).round()} KB';
