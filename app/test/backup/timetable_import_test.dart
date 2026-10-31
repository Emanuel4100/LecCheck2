import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/backup/timetable_import.dart';
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
    }, 'outside the semester');
  });
}
