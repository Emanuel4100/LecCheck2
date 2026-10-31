import 'dart:convert';

import '../../app/theme/colors.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../db/schedule_repository.dart';

/// The shape [ParsedTimetable.parse] reads. Also the prompt's example, so a
/// test can keep the two in step.
const timetableExample = '''
{
  "format": "leccheck-timetable",
  "version": 1,
  "semester": {
    "name": "Semester A 2026/27",
    "start": "2026-10-18",
    "end": "2027-01-22",
    "weekStart": "sunday"
  },
  "courses": [
    {
      "name": "Calculus 1",
      "shortName": "Calc",
      "code": "104031",
      "lecturer": "Dr. Dana Levi",
      "meetings": [
        { "type": "lecture", "day": "sunday", "start": "10:00", "end": "12:00", "room": "Taub 2" },
        { "type": "practice", "day": "tuesday", "start": "14:00", "end": "15:30", "everyOtherWeek": true },
        { "type": "reception", "day": "wednesday", "start": "13:00", "end": "14:00" },
        { "type": "other", "date": "2026-12-01", "start": "09:00", "end": "11:00", "room": "Hall 1" }
      ]
    }
  ]
}''';

/// For the user's own chatbot, along with a screenshot or file of their
/// schedule.
const timetablePrompt =
    '''
You turn a student's weekly schedule into a JSON file for the LecCheck app.

The schedule is attached or pasted below: a screenshot, a PDF, a calendar export or plain text, from a university system, Google Calendar or anywhere else.

Follow these rules:
1. Reply with one JSON code block in exactly the format of the example. Add nothing else to the file.
2. Only use what the schedule shows. Never invent a course, time, room or date.
3. If something required is missing or you can't read it, such as the semester's start and end dates, ask me before writing the file. Leave out optional details you can't find.
4. Keep names and rooms exactly as written, in their original language. Talk to me in the language I use.

The format:
- semester: "name", "start" and "end" as YYYY-MM-DD are required. "weekStart" is "sunday" or "monday".
- courses: each has a "name" and its "meetings". "shortName", "code" and "lecturer" are optional.
- meetings: "type" is "lecture", "practice", "lab", "reception" (a lecturer's office hours) or "other". "start" and "end" use 24-hour HH:MM.
- A meeting that repeats has "day" (the English weekday in lowercase), plus "everyOtherWeek": true if it's held every second week. A one-time meeting, such as a makeup class, has "date" as YYYY-MM-DD instead of "day".
- "room" is optional.
- List one course once, with all its meetings, even if the schedule shows it on several days.

Example:
```json
$timetableExample
```
''';

const _weekdays = {
  'monday': 1,
  'tuesday': 2,
  'wednesday': 3,
  'thursday': 4,
  'friday': 5,
  'saturday': 6,
  'sunday': 7,
};

/// A timetable a chatbot wrote, read and checked, with nothing saved yet.
class ParsedTimetable {
  const ParsedTimetable(this.semester, this.courses);

  final SemesterInfo semester;
  final List<({CourseInfo course, List<MeetingRule> meetings})> courses;

  int get meetingCount => courses.fold(0, (n, c) => n + c.meetings.length);

  /// Throws [FormatException] saying what's wrong, to pass on to the chatbot.
  factory ParsedTimetable.parse(String text) {
    // Chatbots wrap the JSON in a code block and a sentence or two.
    final from = text.indexOf('{');
    final to = text.lastIndexOf('}');
    if (from < 0 || to < from) {
      throw const FormatException('No JSON found.');
    }
    try {
      final json = jsonDecode(text.substring(from, to + 1));
      return _read(json as Map<String, Object?>);
    } on TypeError {
      throw const FormatException('A value has the wrong type.');
    }
  }

  static ParsedTimetable _read(Map<String, Object?> json) {
    if (json['format'] != 'leccheck-timetable') {
      throw const FormatException('"format" isn\'t "leccheck-timetable".');
    }
    if (json['version'] != 1) {
      throw const FormatException('Only "version": 1 can be read.');
    }
    final s = json['semester'] as Map<String, Object?>;
    final start = _date(s['start'], 'semester start');
    final end = _date(s['end'], 'semester end');
    if (end.isBefore(start)) {
      throw const FormatException('The semester ends before it starts.');
    }
    final weekStart = _weekdays[s['weekStart'] ?? 'sunday'];
    if (weekStart != DateTime.sunday && weekStart != DateTime.monday) {
      throw const FormatException('"weekStart" must be sunday or monday.');
    }
    final semesterId = ScheduleRepository.newId();
    final rawCourses = json['courses'] as List<Object?>;
    if (rawCourses.isEmpty) throw const FormatException('No courses.');

    final palette = coursePaletteSeeds.keys.toList();
    final days = weekStart == DateTime.sunday
        ? {7, 1, 2, 3, 4}
        : {1, 2, 3, 4, 5};
    final courses = <({CourseInfo course, List<MeetingRule> meetings})>[];
    for (final (i, raw) in rawCourses.indexed) {
      final c = raw as Map<String, Object?>;
      final name = _text(c['name']);
      if (name.isEmpty) throw FormatException('Course ${i + 1} has no name.');
      final id = ScheduleRepository.newId();
      final meetings = <MeetingRule>[
        for (final m in c['meetings'] as List<Object?>)
          _meeting(m as Map<String, Object?>, id, name, start, end),
      ];
      if (meetings.isEmpty) throw FormatException('"$name" has no meetings.');
      for (final m in meetings) {
        days.add(m.weekday ?? m.date!.weekday);
      }
      courses.add((
        course: CourseInfo(
          id: id,
          semesterId: semesterId,
          name: name,
          shortName: _text(c['shortName']),
          code: _text(c['code']),
          lecturer: _text(c['lecturer']),
          colorKey: palette[i % palette.length],
          sortOrder: i,
        ),
        meetings: meetings,
      ));
    }
    final name = _text(s['name']);
    if (name.isEmpty) throw const FormatException('The semester has no name.');
    return ParsedTimetable(
      SemesterInfo(
        id: semesterId,
        name: name,
        start: start,
        end: end,
        weekStart: weekStart!,
        visibleDays: days,
      ),
      courses,
    );
  }

  static MeetingRule _meeting(
    Map<String, Object?> m,
    String courseId,
    String course,
    LocalDate semesterStart,
    LocalDate semesterEnd,
  ) {
    final startMin = _minutes(m['start'], course);
    final endMin = _minutes(m['end'], course);
    if (endMin <= startMin) {
      throw FormatException('A meeting of "$course" ends before it starts.');
    }
    final day = m['day'];
    final LocalDate? date;
    final int? weekday;
    if (m['date'] != null) {
      date = _date(m['date'], 'meeting of "$course"');
      weekday = null;
      if (date.isBefore(semesterStart) || date.isAfter(semesterEnd)) {
        throw FormatException(
          'A meeting of "$course" is outside the semester.',
        );
      }
    } else {
      date = null;
      weekday = _weekdays[day];
      if (weekday == null) {
        throw FormatException('A meeting of "$course" has no valid "day".');
      }
    }
    return MeetingRule(
      id: ScheduleRepository.newId(),
      courseId: courseId,
      type: SessionType.fromKey(m['type'] as String?),
      kind: date == null ? MeetingKind.weekly : MeetingKind.once,
      weekday: weekday,
      date: date,
      startMin: startMin,
      endMin: endMin,
      location: _text(m['room']),
      intervalWeeks: m['everyOtherWeek'] == true ? 2 : 1,
    );
  }

  static String _text(Object? value) => (value as String? ?? '').trim();

  static LocalDate _date(Object? value, String what) {
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      try {
        return LocalDate.parse(value);
      } on FormatException {
        // No such date, like February 31: the message below says it.
      }
    }
    throw FormatException('The date of the $what isn\'t YYYY-MM-DD.');
  }

  static int _minutes(Object? value, String course) {
    final match = value is String
        ? RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value)
        : null;
    final hours = int.tryParse(match?[1] ?? '');
    final minutes = int.tryParse(match?[2] ?? '');
    if (hours == null || minutes == null || hours > 23 || minutes > 59) {
      throw FormatException('A meeting of "$course" has a bad time.');
    }
    return hours * 60 + minutes;
  }

  /// Adds everything as a new semester: existing data isn't touched.
  Future<void> save(ScheduleRepository repo) => repo.db.transaction(() async {
    await repo.saveSemester(semester);
    for (final c in courses) {
      await repo.saveCourse(
        c.course,
        meetings: c.meetings,
        requirements: const [],
      );
    }
  });
}
