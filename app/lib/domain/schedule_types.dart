import 'package:collection/collection.dart';

import 'local_date.dart';

const _setEq = SetEquality<int>();
const _linksEq = ListEquality<NamedLink>();

/// Kind of class meeting. Persisted by [key] — never by a translated label
/// (v1 stored "Lecture"/"הרצאה" and silently corrupted types on language
/// switch).
enum SessionType {
  lecture('lecture'),
  practice('practice'),
  lab('lab'),
  other('other');

  const SessionType(this.key);
  final String key;

  static SessionType fromKey(String? key) => SessionType.values.firstWhere(
    (t) => t.key == key,
    orElse: () => SessionType.other,
  );
}

/// Attendance status of one session.
enum AttendanceStatus {
  pending('pending'),
  attended('attended'),
  watched('watched'),
  missed('missed'),
  skipped('skipped'),
  canceled('canceled');

  const AttendanceStatus(this.key);
  final String key;

  static AttendanceStatus? fromKey(String? key) {
    if (key == null) return null;
    for (final s in AttendanceStatus.values) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// Counts as "was there" for the progress percentage.
  bool get isPresent => this == attended || this == watched;

  /// A final decision that progress/streak math can use.
  bool get isDecided => this != pending && this != canceled;
}

enum MeetingKind {
  weekly('weekly'),
  once('once');

  const MeetingKind(this.key);
  final String key;

  static MeetingKind fromKey(String? key) =>
      key == once.key ? MeetingKind.once : MeetingKind.weekly;
}

class SemesterInfo {
  const SemesterInfo({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.weekStart = DateTime.sunday,
    this.visibleDays = const {1, 2, 3, 4, 5, 6, 7},
  });

  final String id;
  final String name;
  final LocalDate start;
  final LocalDate end;

  /// ISO weekday the week starts on (7 = Sunday).
  final int weekStart;

  /// ISO weekdays shown in the week grid. Display-only: hidden days never
  /// change which date a session falls on.
  final Set<int> visibleDays;

  @override
  bool operator ==(Object other) =>
      other is SemesterInfo &&
      other.id == id &&
      other.name == name &&
      other.start == start &&
      other.end == end &&
      other.weekStart == weekStart &&
      _setEq.equals(other.visibleDays, visibleDays);

  @override
  int get hashCode => Object.hash(id, name, start, end, weekStart);
}

class CourseInfo {
  const CourseInfo({
    required this.id,
    required this.semesterId,
    required this.name,
    this.code = '',
    this.lecturer = '',
    this.colorKey = 'ocean',
    this.website = '',
    this.notes = '',
    this.links = const [],
    this.sortOrder = 0,
    this.shortName = '',
  });

  final String id;
  final String semesterId;
  final String name;

  /// Optional; the week grid uses it when [name] doesn't fit.
  final String shortName;
  final String code;
  final String lecturer;
  final String colorKey;
  final String website;
  final String notes;
  final List<NamedLink> links;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is CourseInfo &&
      other.id == id &&
      other.semesterId == semesterId &&
      other.name == name &&
      other.shortName == shortName &&
      other.code == code &&
      other.lecturer == lecturer &&
      other.colorKey == colorKey &&
      other.website == website &&
      other.notes == notes &&
      other.sortOrder == sortOrder &&
      _linksEq.equals(other.links, links);

  @override
  int get hashCode =>
      Object.hash(id, name, shortName, code, lecturer, colorKey, sortOrder);
}

class NamedLink {
  const NamedLink({required this.title, required this.url});

  final String title;
  final String url;

  Map<String, Object?> toJson() => {'title': title, 'url': url};

  static NamedLink fromJson(Map<String, Object?> json) => NamedLink(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is NamedLink && other.title == title && other.url == url;

  @override
  int get hashCode => Object.hash(title, url);
}

/// A recurring (weekly / every-N-weeks) or one-off class slot.
class MeetingRule {
  const MeetingRule({
    required this.id,
    required this.courseId,
    required this.type,
    required this.kind,
    required this.startMin,
    required this.endMin,
    this.weekday,
    this.date,
    this.location = '',
    this.intervalWeeks = 1,
    this.validFrom,
    this.validUntil,
    this.links = const [],
  });

  final String id;
  final String courseId;
  final SessionType type;
  final MeetingKind kind;

  /// ISO weekday for [MeetingKind.weekly].
  final int? weekday;

  /// Date for [MeetingKind.once].
  final LocalDate? date;

  /// Minutes after midnight.
  final int startMin;
  final int endMin;
  final String location;

  /// 1 = every week, 2 = every other week (anchored at [validFrom] or the
  /// semester start).
  final int intervalWeeks;
  final LocalDate? validFrom;
  final LocalDate? validUntil;
  final List<NamedLink> links;

  @override
  bool operator ==(Object other) =>
      other is MeetingRule &&
      other.id == id &&
      other.courseId == courseId &&
      other.type == type &&
      other.kind == kind &&
      other.weekday == weekday &&
      other.date == date &&
      other.startMin == startMin &&
      other.endMin == endMin &&
      other.location == location &&
      other.intervalWeeks == intervalWeeks &&
      other.validFrom == validFrom &&
      other.validUntil == validUntil &&
      _linksEq.equals(other.links, links);

  @override
  int get hashCode =>
      Object.hash(id, type, kind, weekday, date, startMin, endMin, location);
}

/// Everything the user changed about one generated session. Keyed by the
/// meeting and the session's *original* date, so editing a meeting's time
/// keeps its history (v1 keyed by date+start+end and lost it).
class SessionOverride {
  const SessionOverride({
    required this.meetingId,
    required this.originalDate,
    this.status,
    this.notes = '',
    this.recordingUrl,
    this.movedDate,
    this.movedStartMin,
    this.movedEndMin,
    this.movedLocation,
  });

  final String meetingId;
  final LocalDate originalDate;
  final AttendanceStatus? status;
  final String notes;
  final String? recordingUrl;
  final LocalDate? movedDate;
  final int? movedStartMin;
  final int? movedEndMin;
  final String? movedLocation;

  String get id => sessionId(meetingId, originalDate);
}

/// Deterministic session id: two devices editing the same session write the
/// same row, so the sync merge combines their fields.
String sessionId(String meetingId, LocalDate originalDate) =>
    '${meetingId}_${originalDate.compactKey}';

class NoClassRange {
  const NoClassRange({
    required this.id,
    required this.semesterId,
    required this.start,
    required this.end,
    this.label = '',
  });

  final String id;
  final String semesterId;
  final LocalDate start;
  final LocalDate end;
  final String label;

  bool contains(LocalDate date) => date.isWithin(start, end);

  @override
  bool operator ==(Object other) =>
      other is NoClassRange &&
      other.id == id &&
      other.start == start &&
      other.end == end &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, start, end, label);
}

class AttendanceRequirement {
  const AttendanceRequirement({
    required this.id,
    required this.courseId,
    required this.minPercent,
    this.type,
    this.recordingsCount = false,
  });

  final String id;
  final String courseId;

  /// `null` = applies to every session type of the course.
  final SessionType? type;
  final int minPercent;

  /// Whether "watched recording" counts as attendance for this requirement.
  final bool recordingsCount;

  @override
  bool operator ==(Object other) =>
      other is AttendanceRequirement &&
      other.id == id &&
      other.courseId == courseId &&
      other.type == type &&
      other.minPercent == minPercent &&
      other.recordingsCount == recordingsCount;

  @override
  int get hashCode =>
      Object.hash(id, courseId, type, minPercent, recordingsCount);
}
