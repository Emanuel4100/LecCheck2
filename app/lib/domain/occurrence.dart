import 'local_date.dart';
import 'schedule_types.dart';

/// One concrete session (e.g. "Calculus lecture on 2026-10-25"), generated
/// from a [MeetingRule] plus its optional [SessionOverride]. Never stored.
class Occurrence {
  const Occurrence({
    required this.id,
    required this.meetingId,
    required this.courseId,
    required this.type,
    required this.originalDate,
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.location,
    required this.status,
    required this.explicitStatus,
    required this.noClassDay,
    required this.isMoved,
    required this.isOneOff,
    required this.number,
    required this.notes,
    required this.recordingUrl,
  });

  final String id;
  final String meetingId;
  final String courseId;
  final SessionType type;

  /// Date the meeting rule produced; part of [id].
  final LocalDate originalDate;

  /// Effective date (differs from [originalDate] when moved "this week only").
  final LocalDate date;
  final int startMin;
  final int endMin;
  final String location;

  /// Effective status after the no-class layer.
  final AttendanceStatus status;

  /// What the user set, if anything.
  final AttendanceStatus? explicitStatus;

  /// Falls inside a no-class range.
  final bool noClassDay;
  final bool isMoved;
  final bool isOneOff;

  /// Running number within (course, type); `null` for canceled sessions.
  final int? number;
  final String notes;
  final String? recordingUrl;

  DateTime get start => date.at(startMin);
  DateTime get end => date.at(endMin);

  bool get isCanceled => status == AttendanceStatus.canceled;

  /// Canceled only because of a holiday — removing the holiday restores it.
  bool get canceledByNoClassDay =>
      noClassDay && isCanceled && explicitStatus != AttendanceStatus.canceled;

  bool hasStarted(DateTime now) => !start.isAfter(now);
  bool hasEnded(DateTime now) => !end.isAfter(now);
  bool isInProgress(DateTime now) => hasStarted(now) && !hasEnded(now);

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.id == id &&
      other.courseId == courseId &&
      other.type == type &&
      other.date == date &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.location == location &&
      other.status == status &&
      other.explicitStatus == explicitStatus &&
      other.noClassDay == noClassDay &&
      other.isMoved == isMoved &&
      other.number == number &&
      other.notes == notes &&
      other.recordingUrl == recordingUrl;

  @override
  int get hashCode => Object.hash(
    id,
    date,
    startMin,
    endMin,
    location,
    status,
    explicitStatus,
    noClassDay,
    number,
    notes,
    recordingUrl,
  );

  @override
  String toString() => 'Occurrence($id, $date ${status.key})';
}

/// Sorted occurrences with O(1) lookups by id, day and course.
class OccurrenceIndex {
  OccurrenceIndex(this.all)
    : byId = {for (final o in all) o.id: o},
      _byDay = _group(all, (o) => o.date.epochDay),
      _byCourse = _group(all, (o) => o.courseId);

  static final empty = OccurrenceIndex(const []);

  /// Chronological.
  final List<Occurrence> all;
  final Map<String, Occurrence> byId;
  final Map<int, List<Occurrence>> _byDay;
  final Map<String, List<Occurrence>> _byCourse;

  List<Occurrence> onDay(LocalDate date) => _byDay[date.epochDay] ?? const [];

  List<Occurrence> forCourse(String courseId) =>
      _byCourse[courseId] ?? const [];

  /// Inclusive date range, chronological.
  List<Occurrence> between(LocalDate from, LocalDate to) => [
    for (var d = from; !d.isAfter(to); d = d.addDays(1)) ...onDay(d),
  ];

  LocalDate? get firstDate => all.isEmpty ? null : all.first.date;
  LocalDate? get lastDate => all.isEmpty ? null : all.last.date;

  static Map<K, List<Occurrence>> _group<K>(
    List<Occurrence> items,
    K Function(Occurrence) key,
  ) {
    final map = <K, List<Occurrence>>{};
    for (final o in items) {
      (map[key(o)] ??= []).add(o);
    }
    return map;
  }
}
