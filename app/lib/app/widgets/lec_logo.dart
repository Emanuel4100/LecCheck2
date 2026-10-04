import 'package:material_ui/material_ui.dart';

/// The LecCheck mark: a calendar page with binder rings and a bold check,
/// filled with the theme's primary→tertiary gradient. Same geometry as the
/// app icon in `design/app-icon/`.
class LecLogo extends StatelessWidget {
  const LecLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LogoPainter(
          start: scheme.primary,
          end: scheme.tertiary,
          ink: scheme.onPrimary,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.start, required this.end, required this.ink});

  final Color start;
  final Color end;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.08, s * 0.14, s * 0.84, s * 0.78),
      Radius.circular(s * 0.24),
    );
    canvas.drawRRect(
      page,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ).createShader(page.outerRect),
    );

    final ringPaint = Paint()..color = ink.withValues(alpha: 0.9);
    for (final x in [0.32, 0.68]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * x, s * 0.14),
            width: s * 0.09,
            height: s * 0.2,
          ),
          Radius.circular(s * 0.045),
        ),
        ringPaint,
      );
    }

    final check = Path()
      ..moveTo(s * 0.3, s * 0.55)
      ..lineTo(s * 0.45, s * 0.7)
      ..lineTo(s * 0.72, s * 0.41);
    canvas.drawPath(
      check,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.start != start || old.end != end || old.ink != ink;
}
