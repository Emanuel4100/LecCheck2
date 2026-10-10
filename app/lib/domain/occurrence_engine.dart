import 'dart:math' as math;

import 'local_date.dart';
import 'occurrence.dart';
import 'schedule_types.dart';
import 'semester_calendar.dart';

/// Turns meeting rules into concrete sessions.
///
/// Pure and deterministic: the same inputs always give the same output, so
/// providers can memoize it and tests can pin every edge case.
abstract final class OccurrenceEngine {
  static OccurrenceIndex expand({
    required SemesterInfo semester,
    required Iterable<MeetingRule> meetings,
    Iterable<SessionOverride> overrides = const [],
    Iterable<NoClassRange> noClassRanges = const [],
  }) {
    final overrideById = {for (final o in overrides) o.id: o};
    final ranges = noClassRanges.toList(growable: false);
    final sessions = <Occurrence>[];

    for (final meeting in meetings) {
      for (final originalDate in datesFor(meeting, semester)) {
        final id = sessionId(meeting.id, originalDate);
        final override = overrideById[id];
        final date = override?.movedDate ?? originalDate;
        final noClass = ranges.any((r) => r.contains(date));
        final explicit = override?.status;
        final status = explicit != null && explicit != AttendanceStatus.pending
            ? explicit
            : noClass
            ? AttendanceStatus.canceled
            : AttendanceStatus.pending;
        final startMin = override?.movedStartMin ?? meeting.startMin;
        final endMin = override?.movedEndMin ?? meeting.endMin;
        final location = override?.movedLocation ?? meeting.location;

        sessions.add(
          Occurrence(
            id: id,
            meetingId: meeting.id,
            courseId: meeting.courseId,
            type: meeting.type,
            originalDate: originalDate,
            date: date,
            startMin: startMin,
            endMin: endMin,
            location: location,
            status: status,
            explicitStatus: explicit,
            noClassDay: noClass,
            isMoved:
                date != originalDate ||
                startMin != meeting.startMin ||
                endMin != meeting.endMin ||
                location != meeting.location,
            isOneOff: meeting.kind == MeetingKind.once,
            number: null,
            notes: override?.notes ?? '',
            recordingUrl: override?.recordingUrl,
          ),
        );
      }
    }

    sessions.sort(compareChronological);
    return OccurrenceIndex(_numbered(sessions));
  }

  /// The first week from [week] (a week's first day) on in which [meeting]
  /// has a session. An every-other-week meeting that continues as a new
  /// rule ("from this week on") starts there, so its classes don't move to
  /// the other weeks.
  static LocalDate nextWeekOnCycle(
    MeetingRule meeting,
    SemesterInfo semester,
    LocalDate week,
  ) {
    final interval = math.max(1, meeting.intervalWeeks);
    if (interval == 1) return week;
    final anchor = startOfWeek(
      meeting.validFrom ?? semester.start,
      semester.weekStart,
    );
    final offset = (anchor.daysUntil(week) ~/ 7) % interval;
    return offset == 0 ? week : week.addDays(7 * (interval - offset));
  }

  /// Dates a meeting rule produces, before overrides. Weekly rules run from
  /// the later of semester start / [MeetingRule.validFrom] to the earlier of
  /// semester end / [MeetingRule.validUntil]; one-off meetings always appear
  /// on their date, even outside the semester.
  static Iterable<LocalDate> datesFor(
    MeetingRule meeting,
    SemesterInfo semester,
  ) sync* {
    switch (meeting.kind) {
      case MeetingKind.once:
        final date = meeting.date;
        if (date != null) yield date;
      case MeetingKind.weekly:
        final weekday = meeting.weekday;
        if (weekday == null || weekday < 1 || weekday > 7) return;
        final validFrom = meeting.validFrom;
        final validUntil = meeting.validUntil;
        final from = validFrom == null
            ? semester.start
            : maxDate(semester.start, validFrom);
        final until = validUntil == null
            ? semester.end
            : minDate(semester.end, validUntil);
        if (from.isAfter(until)) return;

        final interval = math.max(1, meeting.intervalWeeks);
        var first = from.addDays((weekday - from.weekday + 7) % 7);
        if (interval > 1) {
          final anchorWeek = startOfWeek(
            validFrom ?? semester.start,
            semester.weekStart,
          );
          final weeks =
              anchorWeek.daysUntil(startOfWeek(first, semester.weekStart)) ~/ 7;
          final offset = weeks % interval;
          if (offset != 0) first = first.addDays(7 * (interval - offset));
        }
        for (var d = first; !d.isAfter(until); d = d.addDays(7 * interval)) {
          yield d;
        }
    }
  }

  /// The order sessions are listed in (also when merging semesters).
  static int compareChronological(Occurrence a, Occurrence b) {
    var c = a.date.compareTo(b.date);
    if (c != 0) return c;
    c = a.startMin.compareTo(b.startMin);
    if (c != 0) return c;
    c = a.endMin.compareTo(b.endMin);
    if (c != 0) return c;
    c = a.courseId.compareTo(b.courseId);
    if (c != 0) return c;
    return a.meetingId.compareTo(b.meetingId);
  }

  /// Assigns #N per (course, type) in chronological order; canceled sessions
  /// didn't happen, so they get no number and don't advance the count.
  static List<Occurrence> _numbered(List<Occurrence> sorted) {
    final counters = <String, int>{};
    return [
      for (final o in sorted)
        if (o.isCanceled)
          o
        else
          _withNumber(
            o,
            counters.update(
              '${o.courseId}|${o.type.key}',
              (n) => n + 1,
              ifAbsent: () => 1,
            ),
          ),
    ];
  }

  static Occurrence _withNumber(Occurrence o, int number) => Occurrence(
    id: o.id,
    meetingId: o.meetingId,
    courseId: o.courseId,
    type: o.type,
    originalDate: o.originalDate,
    date: o.date,
    startMin: o.startMin,
    endMin: o.endMin,
    location: o.location,
    status: o.status,
    explicitStatus: o.explicitStatus,
    noClassDay: o.noClassDay,
    isMoved: o.isMoved,
    isOneOff: o.isOneOff,
    number: number,
    notes: o.notes,
    recordingUrl: o.recordingUrl,
  );
}
