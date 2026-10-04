import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/schedule_types.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

/// Israeli-style semester: Sunday 2026-10-18 → Friday 2027-01-22, weeks start
/// on Sunday. Spans the 2026-10-25 daylight-saving fall-back.
SemesterInfo semester({
  String start = '2026-10-18',
  String end = '2027-01-22',
  int weekStart = DateTime.sunday,
  Set<int> visibleDays = const {7, 1, 2, 3, 4},
}) => SemesterInfo(
  id: 'sem',
  name: 'Semester A',
  start: d(start),
  end: d(end),
  weekStart: weekStart,
  visibleDays: visibleDays,
);

MeetingRule weekly({
  String id = 'm1',
  String courseId = 'c1',
  SessionType type = SessionType.lecture,
  int weekday = DateTime.sunday,
  int startMin = 10 * 60,
  int endMin = 12 * 60,
  int intervalWeeks = 1,
  String? validFrom,
  String? validUntil,
  String location = 'Room 101',
}) => MeetingRule(
  id: id,
  courseId: courseId,
  type: type,
  kind: MeetingKind.weekly,
  weekday: weekday,
  startMin: startMin,
  endMin: endMin,
  intervalWeeks: intervalWeeks,
  validFrom: validFrom == null ? null : d(validFrom),
  validUntil: validUntil == null ? null : d(validUntil),
  location: location,
);

MeetingRule once({
  String id = 'o1',
  String courseId = 'c1',
  SessionType type = SessionType.lecture,
  required String date,
  int startMin = 14 * 60,
  int endMin = 15 * 60,
}) => MeetingRule(
  id: id,
  courseId: courseId,
  type: type,
  kind: MeetingKind.once,
  date: d(date),
  startMin: startMin,
  endMin: endMin,
);

/// A hand-built session for stats/requirement tests.
Occurrence occ({
  required String date,
  AttendanceStatus status = AttendanceStatus.pending,
  String courseId = 'c1',
  SessionType type = SessionType.lecture,
  int startMin = 10 * 60,
  int endMin = 12 * 60,
  String? recordingUrl,
  String meetingId = 'm1',
}) => Occurrence(
  id: sessionId(meetingId, d(date)),
  meetingId: meetingId,
  courseId: courseId,
  type: type,
  originalDate: d(date),
  date: d(date),
  startMin: startMin,
  endMin: endMin,
  location: '',
  status: status,
  explicitStatus: status == AttendanceStatus.pending ? null : status,
  noClassDay: false,
  isMoved: false,
  isOneOff: false,
  number: null,
  notes: '',
  recordingUrl: recordingUrl,
);
