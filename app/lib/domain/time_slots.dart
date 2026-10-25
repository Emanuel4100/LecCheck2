import 'dart:math' as math;

/// Times on the Week grid, from positions: [startHour] is the grid's first
/// hour, [endHour] its last, [hourHeight] the pixels per hour. Every time
/// snaps to [step] minutes.
class GridTimes {
  const GridTimes({
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    this.step = 15,
  });

  final int startHour;
  final int endHour;
  final double hourHeight;
  final int step;

  int get first => startHour * 60;
  int get last => endHour * 60;

  /// Minutes after midnight at [y] (pixels from the grid's top), unsnapped.
  double minutesAt(double y) => first + y / hourHeight * 60;

  /// [minutes] rounded to the nearest [step].
  int snap(double minutes) => (minutes / step).round() * step;

  /// The slot a tap at [y] stands for: from the [step] it falls in (at
  /// least half an hour of it), [length] minutes long, inside the grid.
  ({int start, int end}) tapped(double y, {int length = 60}) {
    final at = minutesAt(y).floor();
    final start = (at ~/ 30 * 30).clamp(first, last - step);
    return (start: start, end: math.min(start + length, last));
  }

  /// The slot dragged out between [y1] and [y2], either way round: at
  /// least one [step], inside the grid.
  ({int start, int end}) between(double y1, double y2) {
    final a = snap(minutesAt(math.min(y1, y2))).clamp(first, last - step);
    final b = snap(minutesAt(math.max(y1, y2))).clamp(first + step, last);
    return (start: a, end: math.max(b, a + step));
  }

  /// Where a session [length] minutes long lands when its top is at [y]:
  /// snapped, and kept inside the grid.
  ({int start, int end}) moved(double y, int length) {
    final start = snap(minutesAt(y))
        .clamp(first, math.max<int>(first, last - length));
    return (start: start, end: start + length);
  }

  /// The end a session starting at [start] gets when its bottom edge is
  /// dragged to [y]: at least one [step] long, inside the grid.
  int resized(int start, double y) =>
      snap(minutesAt(y)).clamp(start + step, last);
}
