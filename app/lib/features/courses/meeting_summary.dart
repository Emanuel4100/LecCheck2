import '../../app/format.dart';
import '../../app/labels.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../l10n/gen/app_localizations.dart';

/// "Lecture · Sunday", or "Lecture · Tuesday, November 3" for a one-time
/// meeting.
String meetingTitle(MeetingRule m, AppLocalizations l, Fmt fmt) {
  final type = m.type.label(l);
  return switch (m) {
    MeetingRule(kind: MeetingKind.weekly, :final weekday?) =>
      '$type · ${fmt.isoWeekdayName(weekday)}',
    MeetingRule(:final date?) => '$type · ${fmt.longDate(date)}',
    _ => type,
  };
}

/// "10:00–12:00 · Room 7 · Every other week, from week 2 · Until Dec 1".
String meetingDetails(
  MeetingRule m,
  SemesterInfo? semester,
  AppLocalizations l,
  Fmt fmt,
) {
  final week2 = semester == null ? null : secondWeekStart(semester);
  // Every other week from week 2 is stored as starting in week 2; any other
  // start comes from changing the day mid-semester.
  final fromWeek2 =
      m.intervalWeeks == 2 && week2 != null && m.validFrom == week2;
  final from = fromWeek2 ? null : m.validFrom;
  return [
    fmt.timeRange(m.startMin, m.endMin),
    if (m.location.isNotEmpty) m.location,
    if (m.intervalWeeks == 2)
      fromWeek2 ? l.everyOtherWeekFrom(2) : l.everyOtherWeek,
    switch ((from, m.validUntil)) {
      (final from?, final until?) => l.meetingBetween(
        fmt.dayMonth(from),
        fmt.dayMonth(until),
      ),
      (_, final until?) => l.meetingUntil(fmt.dayMonth(until)),
      (final from?, _) => l.meetingFrom(fmt.dayMonth(from)),
      _ => '',
    },
  ].where((p) => p.isNotEmpty).join(' · ');
}

/// The first day of the semester's second week: where "every other week,
/// from week 2" starts.
LocalDate secondWeekStart(SemesterInfo semester) =>
    startOfWeek(semester.start, semester.weekStart).addDays(7);
