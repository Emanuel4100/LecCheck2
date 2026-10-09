import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/notifications/notification_service.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/reminder_plan.dart';
import 'package:leccheck/domain/schedule_types.dart';

import '../domain/helpers.dart';
import 'fake_reminder_os.dart';

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
  const course = CourseInfo(id: 'c1', semesterId: 'sem', name: 'Calculus');
  final lecture = weekly(); // Sundays 10:00–12:00

  List<PlannedReminder> plan({int beforeMinutes = 10}) => planReminders(
    index: OccurrenceEngine.expand(semester: semester(), meetings: [lecture]),
    courses: {'c1': course},
    meetings: {'m1': lecture},
    settings: ReminderSettings(
      before: true,
      beforeMinutes: beforeMinutes,
      after: true,
    ),
    texts: _Texts(),
    now: DateTime(2026, 10, 18, 9, 0),
  );

  late FakeReminderOs os;
  late NotificationService service;

  setUp(() {
    os = FakeReminderOs();
    service = NotificationService.forTesting(os);
  });

  test('schedules the plan once, then only what changed', () async {
    final first = plan();
    await service.apply(first);
    expect(os.scheduled, [for (final r in first) r.id]);

    os.scheduled.clear();
    await service.apply(plan());
    expect(os.scheduled, isEmpty);

    // 15 minutes before instead of 10: the before-class reminders change.
    await service.apply(plan(beforeMinutes: 15));
    expect(os.scheduled, [
      for (final r in plan(beforeMinutes: 15))
        if (r.kind == ReminderKind.before) r.id,
    ]);
  });

  test('re-arms reminders whose alarm a force stop dropped', () async {
    await service.apply(plan());
    os.forceStop();
    os.scheduled.clear();

    // A new process: the plugin still lists everything as scheduled.
    final restarted = NotificationService.forTesting(os);
    await restarted.apply(plan());
    expect(os.scheduled, [for (final r in plan()) r.id]);

    // Checked once per process: the next pass trusts what it armed.
    os.scheduled.clear();
    await restarted.apply(plan());
    expect(os.scheduled, isEmpty);
  });

  test('trusts the plugin list where the system can\'t tell', () async {
    os.alarms = null; // iOS: the list is the system's own
    await service.apply(plan());
    os.scheduled.clear();
    await NotificationService.forTesting(os).apply(plan());
    expect(os.scheduled, isEmpty);
  });

  test('cancels reminders that left the plan', () async {
    final all = plan();
    await service.apply(all);
    final kept = all.take(3).toList();
    await service.apply(kept);
    expect(os.cancelled, [for (final r in all.skip(3)) r.id]);
    expect(os.listed.keys, [for (final r in kept) r.id]);
  });

  test('force reschedules everything', () async {
    await service.apply(plan());
    os.scheduled.clear();
    await service.apply(plan(), force: true);
    expect(os.scheduled, [for (final r in plan()) r.id]);
  });

  test('an unreadable list is started over, not looped on', () async {
    os.unreadable = true;
    await service.apply(plan());
    expect(os.cleared, isTrue);
    expect(os.scheduled, [for (final r in plan()) r.id]);
  });

  test('cancelReminders cancels scheduled reminders only', () async {
    await service.apply(plan());
    await service.cancelReminders();
    expect(os.listed, isEmpty);
    expect(os.cancelled, [for (final r in plan()) r.id]);

    // Scheduling again afterwards arms everything again.
    os.scheduled.clear();
    await service.apply(plan());
    expect(os.scheduled, [for (final r in plan()) r.id]);
  });

  test('cancelReminders survives an unreadable list', () async {
    os.unreadable = true;
    await service.cancelReminders();
    expect(os.cleared, isTrue);
  });

  group('ReminderHealth', () {
    test('blocked when the app or a reminder channel is off', () {
      expect(const ReminderHealth().blocked, isFalse);
      expect(const ReminderHealth(allowed: true).blocked, isFalse);
      expect(const ReminderHealth(allowed: false).blocked, isTrue);
      expect(
        const ReminderHealth(
          allowed: true,
          blockedChannels: ['after_class'],
        ).blocked,
        isTrue,
      );
    });

    test('compares by value', () {
      expect(
        const ReminderHealth(allowed: true, blockedChannels: ['before_class']),
        const ReminderHealth(allowed: true, blockedChannels: ['before_class']),
      );
      expect(
        const ReminderHealth(allowed: true),
        isNot(const ReminderHealth(allowed: false)),
      );
    });
  });
}
