import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/semester_calendar.dart';

import 'helpers.dart';

void main() {
  test('week numbers for a Sunday-start week', () {
    final cal = SemesterCalendar(semester());
    expect(cal.weekNumberOf(d('2026-10-18')), 1);
    expect(cal.weekNumberOf(d('2026-10-24')), 1);
    expect(cal.weekNumberOf(d('2026-10-25')), 2);
    expect(cal.weekNumberOf(d('2026-10-17')), 0);
    expect(cal.weekCount, 14);
    expect(cal.weekStartOf(2), d('2026-10-25'));
  });

  test('week numbers for a Monday-start week', () {
    final cal = SemesterCalendar(semester(weekStart: DateTime.monday));
    expect(cal.firstWeekStart, d('2026-10-12'));
    expect(cal.weekNumberOf(d('2026-10-18')), 1);
    expect(cal.weekNumberOf(d('2026-10-19')), 2);
  });

  test('visible days keep their real dates when some days are hidden', () {
    // v1 bug: with Sunday hidden, the "Mon" column showed Sunday's date.
    final cal = SemesterCalendar(semester(visibleDays: const {1, 2, 3, 4, 5}));
    final dates = cal.visibleDatesOfWeek(d('2026-10-18'));
    expect(dates.first, d('2026-10-19'));
    expect(dates.first.weekday, DateTime.monday);
    expect(dates.map((x) => x.weekday), [1, 2, 3, 4, 5]);
  });

  test('semester progress is clamped', () {
    final cal = SemesterCalendar(semester());
    expect(cal.progressAt(d('2026-09-01')), 0);
    expect(cal.progressAt(d('2027-06-01')), 1);
    expect(cal.progressAt(d('2026-12-05')), closeTo(0.51, 0.02));
  });
}
