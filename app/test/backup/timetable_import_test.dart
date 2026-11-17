import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/backup/timetable_import.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';

Map<String, dynamic> _example() =>
    jsonDecode(timetableExample) as Map<String, dynamic>;

void _refuses(void Function(Map<String, dynamic>) change, String reason) {
  final json = _example();
  change(json);
  expect(
    () => ParsedTimetable.parse(jsonEncode(json)),
    throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains(reason),
      ),
    ),
  );
}

Map<String, dynamic> _meeting(Map<String, dynamic> json) =>
    ((json['courses'] as List).first as Map<String, dynamic>)['meetings'][0]
        as Map<String, dynamic>;

void main() {
  test('the example in the prompt is read in full', () {
    expect(timetablePrompt, contains(timetableExample));
    final t = ParsedTimetable.parse(timetableExample);
    expect(t.semester.name, 'Semester A 2026/27');
    expect(t.semester.weekStart, DateTime.sunday);
    final course = t.courses.single;
    expect(course.course.lecturer, 'Dr. Dana Levi');
    expect(course.course.semesterId, t.semester.id);
    final [lecture, practice, reception, once] = course.meetings;
    expect(lecture.weekday, DateTime.sunday);
    expect(lecture.startMin, 600);
    expect(lecture.location, 'Taub 2');
    expect(practice.intervalWeeks, 2);
    expect(reception.type, SessionType.reception);
    expect(once.kind, MeetingKind.once);
    expect(once.weekday, isNull);
  });

  test('finds the JSON inside a chatbot reply', () {
    final t = ParsedTimetable.parse(
      'Sure! Here is your file:\n```json\n$timetableExample\n```\nEnjoy.',
    );
    expect(t.meetingCount, 4);
  });

  test('refuses what it cannot trust', () {
    expect(() => ParsedTimetable.parse('no json'), throwsFormatException);
    expect(() => ParsedTimetable.parse('{broken}'), throwsFormatException);
    _refuses((j) => j['format'] = 'leccheck', 'format');
    _refuses((j) => j['version'] = 2, 'version');
    _refuses((j) => j['courses'] = [], 'No courses');
    _refuses((j) => j['semester'] = 'A', 'wrong type');
    _refuses((j) => j['semester']['start'] = '18/10/2026', 'YYYY-MM-DD');
    _refuses((j) => j['semester']['start'] = '2026-02-31', 'YYYY-MM-DD');
    _refuses((j) => j['semester']['end'] = '2026-01-01', 'ends before');
    _refuses((j) => _meeting(j)['start'] = '25:00', 'bad time');
    _refuses((j) => _meeting(j)['end'] = '09:00', 'ends before');
    _refuses((j) => _meeting(j)['day'] = 'someday', 'valid "day"');
    _refuses((j) {
      _meeting(j)['date'] = '2030-01-01';
    }, 'no date in the semester');
  });

  test('a file with gaps is kept as a draft that says what is missing', () {
    final json = _example();
    (json['semester'] as Map).remove('end');
    (json['semester'] as Map)['name'] = '';
    final course = (json['courses'] as List).first as Map<String, dynamic>;
    course.remove('code');
    final [lecture, practice, _, once] = course['meetings'] as List;
    (lecture as Map).remove('end');
    (practice as Map)['day'] = 'someday';
    (once as Map)['date'] = 'December 1';

    final draft = TimetableDraft.read(jsonEncode(json));
    expect(draft.gaps.map((g) => g.kind), [
      TimetableGapKind.semesterName,
      TimetableGapKind.semesterEnd,
      TimetableGapKind.meetingEnd,
      TimetableGapKind.meetingDay,
      // A one-time class keeps asking for a date, not a weekday.
      TimetableGapKind.meetingDate,
    ]);
    expect(draft.coursesWithoutCode, [0]);
    expect(draft.build, throwsStateError);
    // The strict reading says the first one.
    expect(
      () => ParsedTimetable.parse(jsonEncode(json)),
      throwsA(isA<FormatException>()),
    );

    final meetings = draft.courses.single.meetings;
    draft
      ..semesterName = 'Semester A'
      ..end = LocalDate(2027, 1, 22);
    meetings[0].endMin = 12 * 60;
    meetings[1].weekday = DateTime.tuesday;
    meetings[3].date = LocalDate(2026, 12, 1);
    expect(draft.gaps, isEmpty);
    // The course number stays optional.
    final t = draft.build();
    expect(t.semester.name, 'Semester A');
    expect(t.courses.single.course.code, '');
    final [lectureRule, practiceRule, _, onceRule] = t.courses.single.meetings;
    expect(lectureRule.endMin, 720);
    expect(practiceRule.weekday, DateTime.tuesday);
    expect(practiceRule.intervalWeeks, 2);
    expect(onceRule.kind, MeetingKind.once);
    expect(onceRule.date, LocalDate(2026, 12, 1));
  });

  test(
    'the prompt asks before writing, and leaves out what I don\'t answer',
    () {
      expect(timetablePrompt, contains('which group or section is mine'));
      expect(timetablePrompt, contains('LecCheck will ask me for it'));
    },
  );
}
