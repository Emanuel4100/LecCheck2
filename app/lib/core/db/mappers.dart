import 'dart:convert';

import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import 'app_database.dart';

/// ISO weekdays ↔ bitmask (bit `weekday - 1`).
int daysToMask(Set<int> days) =>
    days.fold(0, (mask, d) => d >= 1 && d <= 7 ? mask | (1 << (d - 1)) : mask);

Set<int> maskToDays(int mask) => {
  for (var d = 1; d <= 7; d++)
    if (mask & (1 << (d - 1)) != 0) d,
};

List<NamedLink> decodeLinks(String json) {
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) NamedLink.fromJson(item.cast<String, Object?>()),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeLinks(List<NamedLink> links) =>
    jsonEncode([for (final l in links) l.toJson()]);

int _now() => DateTime.now().millisecondsSinceEpoch;

extension SemesterRowMapping on SemesterRow {
  SemesterInfo toDomain() => SemesterInfo(
    id: id,
    name: name,
    start: LocalDate.parse(startDate),
    end: LocalDate.parse(endDate),
    weekStart: weekStart,
    visibleDays: maskToDays(visibleDays),
  );
}

extension SemesterInfoMapping on SemesterInfo {
  SemesterRow toRow() => SemesterRow(
    id: id,
    deleted: false,
    updatedAt: _now(),
    name: name,
    startDate: start.toIso(),
    endDate: end.toIso(),
    weekStart: weekStart,
    visibleDays: daysToMask(visibleDays),
  );
}

extension CourseRowMapping on CourseRow {
  CourseInfo toDomain() => CourseInfo(
    id: id,
    semesterId: semesterId,
    name: name,
    code: code,
    lecturer: lecturer,
    colorKey: colorKey,
    website: website,
    notes: notes,
    links: decodeLinks(links),
    sortOrder: sortOrder,
    shortName: shortName,
  );
}

extension CourseInfoMapping on CourseInfo {
  CourseRow toRow() => CourseRow(
    id: id,
    deleted: false,
    updatedAt: _now(),
    semesterId: semesterId,
    name: name,
    code: code,
    lecturer: lecturer,
    colorKey: colorKey,
    website: website,
    notes: notes,
    links: encodeLinks(links),
    sortOrder: sortOrder,
    shortName: shortName,
  );
}

extension MeetingRowMapping on MeetingRow {
  MeetingRule toDomain() => MeetingRule(
    id: id,
    courseId: courseId,
    type: SessionType.fromKey(type),
    kind: MeetingKind.fromKey(kind),
    weekday: weekday,
    date: LocalDate.tryParse(date),
    startMin: startMin,
    endMin: endMin,
    location: location,
    intervalWeeks: intervalWeeks,
    validFrom: LocalDate.tryParse(validFrom),
    validUntil: LocalDate.tryParse(validUntil),
    links: decodeLinks(links),
  );
}

extension MeetingRuleMapping on MeetingRule {
  MeetingRow toRow() => MeetingRow(
    id: id,
    deleted: false,
    updatedAt: _now(),
    courseId: courseId,
    type: type.key,
    kind: kind.key,
    weekday: kind == MeetingKind.weekly ? weekday : null,
    date: kind == MeetingKind.once ? date?.toIso() : null,
    startMin: startMin,
    endMin: endMin,
    location: location,
    intervalWeeks: intervalWeeks,
    validFrom: validFrom?.toIso(),
    validUntil: validUntil?.toIso(),
    links: encodeLinks(links),
  );
}

extension SessionOverrideRowMapping on SessionOverrideRow {
  SessionOverride toDomain() => SessionOverride(
    meetingId: meetingId,
    originalDate: LocalDate.parse(originalDate),
    status: AttendanceStatus.fromKey(status),
    notes: notes,
    recordingUrl: recordingUrl,
    movedDate: LocalDate.tryParse(movedDate),
    movedStartMin: movedStartMin,
    movedEndMin: movedEndMin,
    movedLocation: movedLocation,
  );
}

extension NoClassRangeRowMapping on NoClassRangeRow {
  NoClassRange toDomain() => NoClassRange(
    id: id,
    semesterId: semesterId,
    start: LocalDate.parse(startDate),
    end: LocalDate.parse(endDate),
    label: label,
  );
}

extension NoClassRangeMapping on NoClassRange {
  NoClassRangeRow toRow() => NoClassRangeRow(
    id: id,
    deleted: false,
    updatedAt: _now(),
    semesterId: semesterId,
    startDate: start.toIso(),
    endDate: end.toIso(),
    label: label,
  );
}

extension RequirementRowMapping on RequirementRow {
  AttendanceRequirement toDomain() => AttendanceRequirement(
    id: id,
    courseId: courseId,
    type: type == null ? null : SessionType.fromKey(type),
    minPercent: minPercent,
    recordingsCount: recordingsCount,
  );
}

extension AttendanceRequirementMapping on AttendanceRequirement {
  RequirementRow toRow() => RequirementRow(
    id: id,
    deleted: false,
    updatedAt: _now(),
    courseId: courseId,
    type: type?.key,
    minPercent: minPercent,
    recordingsCount: recordingsCount,
  );
}
