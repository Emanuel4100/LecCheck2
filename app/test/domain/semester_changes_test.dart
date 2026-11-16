import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/domain/semester_changes.dart';
import 'package:leccheck/domain/semester_data.dart';

import 'helpers.dart';

void main() {
  SessionOverride marked(String meetingId, String date) => SessionOverride(
    meetingId: meetingId,
    originalDate: d(date),
    status: AttendanceStatus.attended,
  );

  SemesterData data(List<MeetingRule> meetings, List<SessionOverride> marks) =>
      SemesterData(
        semester: semester(),
        courses: const [],
        meetings: meetings,
        overrides: marks,
        noClassRanges: const [],
        requirements: const [],
      );

  test('counts marked sessions outside the new dates', () {
    final lecture = weekly();
    final before = data(
      [lecture],
      [marked('m1', '2026-10-18'), marked('m1', '2026-10-25')],
    );
    expect(markedSessionsLost(before, semester(start: '2026-10-25')), 1);
    expect(markedSessionsLost(before, semester(end: '2027-01-29')), 0);
  });

  test('counts an every-other-week meeting whose weeks flip', () {
    // Every other Sunday from the semester start: 18 Oct, 1 Nov, …
    final biweekly = weekly(intervalWeeks: 2);
    final before = data([biweekly], [marked('m1', '2026-11-01')]);
    // Starting a week later, its Sundays are 25 Oct, 8 Nov, …: 1 Nov is gone,
    // although it's inside the new dates.
    expect(markedSessionsLost(before, semester(start: '2026-10-25')), 1);
  });

  test('one-time sessions and unmarked ones never count', () {
    final before = data(
      [weekly(), once(date: '2026-10-20')],
      [
        marked('o1', '2026-10-20'),
        // Only a note: nothing counted in the stats.
        SessionOverride(
          meetingId: 'm1',
          originalDate: d('2026-10-18'),
          notes: 'Chapter 1',
        ),
      ],
    );
    expect(markedSessionsLost(before, semester(start: '2026-11-01')), 0);
  });
}
