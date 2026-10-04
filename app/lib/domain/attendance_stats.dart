import 'occurrence.dart';
import 'schedule_types.dart';
import 'semester_calendar.dart';

/// Per-status counts with the derived progress percentage.
class StatusCounts {
  StatusCounts([Map<AttendanceStatus, int>? counts]) : _counts = counts ?? {};

  factory StatusCounts.of(Iterable<Occurrence> sessions) {
    final counts = <AttendanceStatus, int>{};
    for (final o in sessions) {
      counts.update(o.status, (n) => n + 1, ifAbsent: () => 1);
    }
    return StatusCounts(counts);
  }

  final Map<AttendanceStatus, int> _counts;

  int operator [](AttendanceStatus status) => _counts[status] ?? 0;

  int get present =>
      this[AttendanceStatus.attended] + this[AttendanceStatus.watched];

  /// Denominator of the progress percentage (same formula as v1):
  /// skipped and canceled sessions don't count either way.
  int get decided => present + this[AttendanceStatus.missed];

  int get total => _counts.values.fold(0, (a, b) => a + b);

  /// 0..1, or `null` before anything was decided.
  double? get progress => decided == 0 ? null : present / decided;
}

class Streak {
  const Streak(this.current, this.best);
  final int current;
  final int best;
}

abstract final class AttendanceStats {
  /// Sessions that have started by [now] — the only ones that can be marked
  /// for real.
  static Iterable<Occurrence> started(
    Iterable<Occurrence> sessions,
    DateTime now,
  ) => sessions.where((o) => o.hasStarted(now));

  /// Started sessions still waiting for a status, newest first (the class you
  /// just left is at the top). Includes sessions in progress.
  static List<Occurrence> needsMarking(
    Iterable<Occurrence> chronological,
    DateTime now,
  ) => started(chronological, now)
      .where((o) => o.status == AttendanceStatus.pending)
      .toList()
      .reversed
      .toList();

  /// Consecutive attended/watched sessions ending at the most recent decided
  /// one; missed and skipped break the run, pending and canceled are ignored.
  static Streak streak(Iterable<Occurrence> chronological, DateTime now) {
    var run = 0;
    var best = 0;
    for (final o in started(chronological, now)) {
      if (o.status.isPresent) {
        run++;
        if (run > best) best = run;
      } else if (o.status == AttendanceStatus.missed ||
          o.status == AttendanceStatus.skipped) {
        run = 0;
      }
    }
    return Streak(run, best);
  }

  /// Missed sessions that have a recording to catch up on.
  static List<Occurrence> catchUp(Iterable<Occurrence> chronological) => [
    for (final o in chronological)
      if (o.status == AttendanceStatus.missed &&
          (o.recordingUrl?.isNotEmpty ?? false))
        o,
  ];

  static Map<String, StatusCounts> byCourse(
    Iterable<Occurrence> sessions,
    DateTime now,
  ) => _groupCounts(started(sessions, now), (o) => o.courseId);

  static Map<SessionType, StatusCounts> byType(
    Iterable<Occurrence> sessions,
    DateTime now,
  ) => _groupCounts(started(sessions, now), (o) => o.type);

  /// Started sessions grouped by semester week number.
  static Map<int, StatusCounts> byWeek(
    Iterable<Occurrence> sessions,
    SemesterCalendar calendar,
    DateTime now,
  ) => _groupCounts(
    started(sessions, now),
    (o) => calendar.weekNumberOf(o.date),
  );

  static Map<K, StatusCounts> _groupCounts<K>(
    Iterable<Occurrence> sessions,
    K Function(Occurrence) key,
  ) {
    final groups = <K, List<Occurrence>>{};
    for (final o in sessions) {
      (groups[key(o)] ??= []).add(o);
    }
    return {for (final e in groups.entries) e.key: StatusCounts.of(e.value)};
  }
}
