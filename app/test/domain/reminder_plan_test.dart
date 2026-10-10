import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/reminder_plan.dart';
import 'package:leccheck/domain/schedule_types.dart';

import 'helpers.dart';

class _Texts implements ReminderTexts {
  @override
  String beforeTitle(Occurrence s, CourseInfo c, int m) => '${c.name} in $m';
  @override
  String beforeBody(Occurrence s, CourseInfo c) => s.location;
  @override
  String afterTitle(Occurrence s, CourseInfo c) => 'How was ${c.name}?';
  @override
  String afterBody(Occurrence s, CourseInfo c) => s.type.key;
}

void main() {
  const course = CourseInfo(
    id: 'c1',
    semesterId: 'sem',
    name: 'Calculus',
    links: [NamedLink(title: 'Zoom', url: 'https://zoom.us/j/1')],
  );
  final lecture = weekly(); // Sundays 10:00–12:00
  final practice = weekly(
    id: 'p1',
    type: SessionType.practice,
    weekday: DateTime.monday,
    startMin: 14 * 60,
    endMin: 15 * 60,
  );

  List<PlannedReminder> plan(
    ReminderSettings settings, {
    DateTime? now,
    List<SessionOverride> overrides = const [],
    int limit = 60,
  }) => planReminders(
    index: OccurrenceEngine.expand(
      semester: semester(),
      meetings: [lecture, practice],
      overrides: overrides,
    ),
    courses: {'c1': course},
    meetings: {'m1': lecture, 'p1': practice},
    settings: settings,
    texts: _Texts(),
    now: now ?? DateTime(2026, 10, 18, 9, 0),
    limit: limit,
  );

  test('nothing when reminders are off', () {
    expect(plan(const ReminderSettings()), isEmpty);
  });

  test('nothing for a muted course', () {
    expect(
      plan(
        const ReminderSettings(before: true, after: true, mutedCourses: {'c1'}),
      ),
      isEmpty,
    );
    expect(
      const ReminderSettings(mutedCourses: {'c1'}),
      const ReminderSettings(mutedCourses: {'c1'}),
    );
  });

  test('before-class reminders, soonest first, with the course link', () {
    final reminders = plan(const ReminderSettings(before: true));
    expect(reminders.first.at, DateTime(2026, 10, 18, 9, 50));
    expect(reminders.first.title, 'Calculus in 10');
    expect(reminders.first.link, 'https://zoom.us/j/1');
    expect(reminders[1].at, DateTime(2026, 10, 19, 13, 50));
    for (var i = 1; i < reminders.length; i++) {
      expect(reminders[i].at.isAfter(reminders[i - 1].at), isTrue);
    }
  });

  test('after-class reminders only for sessions still pending', () {
    final reminders = plan(
      const ReminderSettings(after: true),
      overrides: [
        SessionOverride(
          meetingId: 'm1',
          originalDate: d('2026-10-18'),
          status: AttendanceStatus.attended,
        ),
      ],
    );
    expect(reminders.first.at, DateTime(2026, 10, 19, 15, 5));
    expect(reminders.first.title, 'How was Calculus?');
  });

  test('skips past times and canceled sessions', () {
    final reminders = plan(
      const ReminderSettings(before: true),
      now: DateTime(2026, 10, 18, 9, 55),
      overrides: [
        SessionOverride(
          meetingId: 'p1',
          originalDate: d('2026-10-19'),
          status: AttendanceStatus.canceled,
        ),
      ],
    );
    expect(reminders.first.at, DateTime(2026, 10, 25, 9, 50));
  });

  test('ids are stable and distinct per kind; limit caps the plan', () {
    expect(
      reminderId('m1_20261018', ReminderKind.before),
      reminderId('m1_20261018', ReminderKind.before),
    );
    expect(
      reminderId('m1_20261018', ReminderKind.before),
      isNot(reminderId('m1_20261018', ReminderKind.after)),
    );
    final capped = plan(
      const ReminderSettings(before: true, after: true),
      limit: 5,
    );
    expect(capped, hasLength(5));
    expect(capped.map((r) => r.id).toSet(), hasLength(5));
  });
}
