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
1. Before writing the file, ask me in one short message about anything you need and can't see or read, and wait for my answer. In particular:
   - the semester's name and its start and end dates, if the schedule doesn't show them;
   - which group or section is mine, when the schedule shows several groups of the same course (for example two practice groups at different times); list only mine;
   - each course's number (course code), if it isn't shown: I may skip this one;
   - meetings whose day or time you can't read, and which meetings are held every other week if that's unclear.
   If everything is clear, don't ask: write the file right away.
2. Then reply with one JSON code block in exactly the format of the example. Add nothing else to the file.
3. Only use what the schedule shows or what I told you. Never invent a course, time, room or date. Leave out optional details you can't find. If I didn't answer something required, write the file anyway and leave that field out: LecCheck will ask me for it.
4. Keep names and rooms exactly as written, in their original language. Talk to me in the language I use.

The format:
- semester: "name", "start" and "end" as YYYY-MM-DD are required. "weekStart" is "sunday" or "monday".
- courses: each has a "name" and its "meetings". "shortName", "code" (the course number) and "lecturer" are optional.
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

/// Something the file left out or got wrong that the user can fill in
/// before importing. [course] and [meeting] are indexes in the draft.
class TimetableGap {
  const TimetableGap(this.kind, this.message, {this.course, this.meeting});

  final TimetableGapKind kind;

  /// In English, for the chatbot (see [ParsedTimetable.parse]).
  final String message;
  final int? course;
  final int? meeting;
}

enum TimetableGapKind {
  semesterName,
  semesterStart,

  /// Missing, or before the start.
  semesterEnd,

  /// A repeating meeting without a valid day.
  meetingDay,

  /// A one-time meeting without a date, or outside the semester.
  meetingDate,
  meetingStart,

  /// Missing, or not after the start.
  meetingEnd,
}

/// A meeting as read, with what's missing left null.
class MeetingDraft {
  MeetingDraft({
    required this.type,
    required this.course,
    this.oneTime = false,
    this.weekday,
    this.date,
    this.startMin,
    this.endMin,
    this.room = '',
    this.everyOtherWeek = false,
  });

  final SessionType type;

  /// The course's name, for messages.
  final String course;

  /// Held once, on [date] (null until known); otherwise weekly on [weekday].
  final bool oneTime;
  int? weekday;
  LocalDate? date;
  int? startMin;
  int? endMin;
  String room;
  bool everyOtherWeek;
}

class CourseDraft {
  CourseDraft({
    required this.name,
    this.shortName = '',
    this.code = '',
    this.lecturer = '',
    required this.meetings,
  });

  final String name;
  final String shortName;

  /// The course number: optional, but Panopto finds folders by it.
  String code;
  final String lecturer;
  final List<MeetingDraft> meetings;
}

/// A timetable a chatbot wrote, read leniently: what's missing or doesn't
/// fit stays open for the user to fill in ([gaps]), then [build] makes the
/// semester. Nothing is saved.
class TimetableDraft {
  TimetableDraft({
    required this.semesterName,
    required this.start,
    required this.end,
    required this.weekStart,
    required this.courses,
  });

  String semesterName;
  LocalDate? start;
  LocalDate? end;
  final int weekStart;
  final List<CourseDraft> courses;

  int get meetingCount => courses.fold(0, (n, c) => n + c.meetings.length);

  /// Courses without a course number (optional to fill in).
  Iterable<int> get coursesWithoutCode => [
    for (final (i, c) in courses.indexed)
      if (c.code.isEmpty) i,
  ];

  /// Reads a chatbot's reply. Throws [FormatException] only for what the
  /// user can't fix here (no JSON, another format, no courses…).
  factory TimetableDraft.read(String text) {
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

  static TimetableDraft _read(Map<String, Object?> json) {
    if (json['format'] != 'leccheck-timetable') {
      throw const FormatException('"format" isn\'t "leccheck-timetable".');
    }
    if (json['version'] != 1) {
      throw const FormatException('Only "version": 1 can be read.');
    }
    final s =
        (json['semester'] ?? const <String, Object?>{}) as Map<String, Object?>;
    final weekStart = _weekdays[s['weekStart'] ?? 'sunday'];
    if (weekStart != DateTime.sunday && weekStart != DateTime.monday) {
      throw const FormatException('"weekStart" must be sunday or monday.');
    }
    final rawCourses = json['courses'] as List<Object?>? ?? const [];
    if (rawCourses.isEmpty) throw const FormatException('No courses.');
    final courses = <CourseDraft>[];
    for (final (i, raw) in rawCourses.indexed) {
      final c = raw as Map<String, Object?>;
      final name = _text(c['name']);
      if (name.isEmpty) throw FormatException('Course ${i + 1} has no name.');
      final meetings = [
        for (final m in c['meetings'] as List<Object?>? ?? const [])
          _meeting(m as Map<String, Object?>, name),
      ];
      if (meetings.isEmpty) throw FormatException('"$name" has no meetings.');
      courses.add(
        CourseDraft(
          name: name,
          shortName: _text(c['shortName']),
          code: _text(c['code']),
          lecturer: _text(c['lecturer']),
          meetings: meetings,
        ),
      );
    }
    return TimetableDraft(
      semesterName: _text(s['name']),
      start: _date(s['start']),
      end: _date(s['end']),
      weekStart: weekStart!,
      courses: courses,
    );
  }

  static MeetingDraft _meeting(Map<String, Object?> m, String course) {
    final hasDate = m['date'] != null;
    return MeetingDraft(
      type: SessionType.fromKey(m['type'] as String?),
      course: course,
      oneTime: hasDate,
      weekday: hasDate ? null : _weekdays[m['day']],
      date: hasDate ? _date(m['date']) : null,
      startMin: _minutes(m['start']),
      endMin: _minutes(m['end']),
      room: _text(m['room']),
      everyOtherWeek: m['everyOtherWeek'] == true,
    );
  }

  /// What must be filled in before [build], in reading order.
  List<TimetableGap> get gaps {
    final start = this.start;
    final end = this.end;
    return [
      if (semesterName.trim().isEmpty)
        const TimetableGap(
          TimetableGapKind.semesterName,
          'The semester has no name.',
        ),
      if (start == null)
        const TimetableGap(
          TimetableGapKind.semesterStart,
          'The date of the semester start isn\'t YYYY-MM-DD.',
        ),
      if (end == null)
        const TimetableGap(
          TimetableGapKind.semesterEnd,
          'The date of the semester end isn\'t YYYY-MM-DD.',
        )
      else if (start != null && end.isBefore(start))
        const TimetableGap(
          TimetableGapKind.semesterEnd,
          'The semester ends before it starts.',
        ),
      for (final (ci, c) in courses.indexed)
        for (final (mi, m) in c.meetings.indexed) ...[
          if (m.oneTime ? !_inSemester(m.date, start, end) : m.weekday == null)
            TimetableGap(
              m.oneTime
                  ? TimetableGapKind.meetingDate
                  : TimetableGapKind.meetingDay,
              m.oneTime
                  ? 'A meeting of "${c.name}" has no date in the semester.'
                  : 'A meeting of "${c.name}" has no valid "day".',
              course: ci,
              meeting: mi,
            ),
          if (m.startMin == null)
            TimetableGap(
              TimetableGapKind.meetingStart,
              'A meeting of "${c.name}" has a bad time.',
              course: ci,
              meeting: mi,
            ),
          if (m.endMin == null)
            TimetableGap(
              TimetableGapKind.meetingEnd,
              'A meeting of "${c.name}" has a bad time.',
              course: ci,
              meeting: mi,
            )
          else if (m.startMin != null && m.endMin! <= m.startMin!)
            TimetableGap(
              TimetableGapKind.meetingEnd,
              'A meeting of "${c.name}" ends before it starts.',
              course: ci,
              meeting: mi,
            ),
        ],
    ];
  }

  /// A one-time meeting's date is known and, once the semester's dates
  /// are, within them.
  static bool _inSemester(LocalDate? date, LocalDate? start, LocalDate? end) =>
      date != null &&
      (start == null || !date.isBefore(start)) &&
      (end == null || !date.isAfter(end));

  /// The semester and its courses, with new ids. Throws [StateError] while
  /// [gaps] isn't empty.
  ParsedTimetable build() {
    if (gaps.isNotEmpty) throw StateError('Fill in the gaps first');
    final semesterId = ScheduleRepository.newId();
    final palette = coursePaletteSeeds.keys.toList();
    final days = weekStart == DateTime.sunday
        ? {7, 1, 2, 3, 4}
        : {1, 2, 3, 4, 5};
    final built = <({CourseInfo course, List<MeetingRule> meetings})>[];
    for (final (i, c) in courses.indexed) {
      final id = ScheduleRepository.newId();
      final meetings = [
        for (final m in c.meetings)
          MeetingRule(
            id: ScheduleRepository.newId(),
            courseId: id,
            type: m.type,
            kind: m.oneTime ? MeetingKind.once : MeetingKind.weekly,
            weekday: m.oneTime ? null : m.weekday,
            date: m.oneTime ? m.date : null,
            startMin: m.startMin!,
            endMin: m.endMin!,
            location: m.room,
            intervalWeeks: !m.oneTime && m.everyOtherWeek ? 2 : 1,
          ),
      ];
      for (final m in meetings) {
        days.add(m.weekday ?? m.date!.weekday);
      }
      built.add((
        course: CourseInfo(
          id: id,
          semesterId: semesterId,
          name: c.name,
          shortName: c.shortName,
          code: c.code.trim(),
          lecturer: c.lecturer,
          colorKey: palette[i % palette.length],
          sortOrder: i,
        ),
        meetings: meetings,
      ));
    }
    return ParsedTimetable(
      SemesterInfo(
        id: semesterId,
        name: semesterName.trim(),
        start: start!,
        end: end!,
        weekStart: weekStart,
        visibleDays: days,
      ),
      built,
    );
  }

  static String _text(Object? value) => (value as String? ?? '').trim();

  static LocalDate? _date(Object? value) {
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      try {
        return LocalDate.parse(value);
      } on FormatException {
        // No such date, like February 31.
      }
    }
    return null;
  }

  static int? _minutes(Object? value) {
    final match = value is String
        ? RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value)
        : null;
    final hours = int.tryParse(match?[1] ?? '');
    final minutes = int.tryParse(match?[2] ?? '');
    if (hours == null || minutes == null || hours > 23 || minutes > 59) {
      return null;
    }
    return hours * 60 + minutes;
  }
}

/// A timetable ready to save: a new semester and its courses.
class ParsedTimetable {
  const ParsedTimetable(this.semester, this.courses);

  final SemesterInfo semester;
  final List<({CourseInfo course, List<MeetingRule> meetings})> courses;

  int get meetingCount => courses.fold(0, (n, c) => n + c.meetings.length);

  /// Reads a complete file: throws [FormatException] saying what's wrong or
  /// missing (the app's import fills gaps in with [TimetableDraft]).
  factory ParsedTimetable.parse(String text) {
    final draft = TimetableDraft.read(text);
    final gaps = draft.gaps;
    if (gaps.isNotEmpty) throw FormatException(gaps.first.message);
    return draft.build();
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
