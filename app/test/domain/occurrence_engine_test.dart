import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/schedule_types.dart';

import 'helpers.dart';

void main() {
  group('every other week, continued from a later week', () {
    test('starts on the next week of the same cycle', () {
      final rule = weekly(intervalWeeks: 2);
      final sem = semester();
      // Classes in weeks 1, 3, 5… (from 2026-10-18).
      expect(
        OccurrenceEngine.nextWeekOnCycle(rule, sem, d('2026-10-25')),
        d('2026-11-01'),
      );
      expect(
        OccurrenceEngine.nextWeekOnCycle(rule, sem, d('2026-11-01')),
        d('2026-11-01'),
      );
      // "Second week": weeks 2, 4, 6…
      final second = weekly(intervalWeeks: 2, validFrom: '2026-10-25');
      expect(
        OccurrenceEngine.nextWeekOnCycle(second, sem, d('2026-11-01')),
        d('2026-11-08'),
      );
      // Every week: from the week asked for.
      expect(
        OccurrenceEngine.nextWeekOnCycle(weekly(), sem, d('2026-10-25')),
        d('2026-10-25'),
      );
    });
  });

  group('weekly meetings', () {
    test('one session per week across the October DST change', () {
      final index = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
      );
      final dates = index.all.map((o) => o.date.toIso()).toList();
      expect(dates.first, '2026-10-18');
      expect(dates.last, '2027-01-17');
      expect(dates, hasLength(14));
      expect(dates.toSet(), hasLength(14), reason: 'no duplicate days');
      for (var i = 1; i < index.all.length; i++) {
        expect(index.all[i - 1].date.daysUntil(index.all[i].date), 7);
      }
      // Wall-clock time stays 10:00 on both sides of the transition.
      for (final o in index.all) {
        expect((o.start.hour, o.start.minute), (10, 0));
        expect(o.date.weekday, DateTime.sunday);
      }
    });

    test('first session lands on the first matching weekday', () {
      final index = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly(weekday: DateTime.wednesday)],
      );
      expect(index.all.first.date.toIso(), '2026-10-21');
    });

    test('valid range bounds the recurrence', () {
      final index = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly(validFrom: '2026-11-01', validUntil: '2026-11-22')],
      );
      expect(index.all.map((o) => o.date.toIso()), [
        '2026-11-01',
        '2026-11-08',
        '2026-11-15',
        '2026-11-22',
      ]);
    });

    test('every other week, anchored at the semester or validFrom', () {
      final oddWeeks = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly(intervalWeeks: 2)],
      );
      expect(oddWeeks.all.take(3).map((o) => o.date.toIso()), [
        '2026-10-18',
        '2026-11-01',
        '2026-11-15',
      ]);

      final evenWeeks = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly(intervalWeeks: 2, validFrom: '2026-10-25')],
      );
      expect(evenWeeks.all.take(3).map((o) => o.date.toIso()), [
        '2026-10-25',
        '2026-11-08',
        '2026-11-22',
      ]);
    });

    test('hidden weekdays never change which dates sessions fall on', () {
      final hidden = OccurrenceEngine.expand(
        semester: semester(visibleDays: const {1, 2, 3}),
        meetings: [weekly()],
      );
      final shown = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
      );
      expect(hidden.all.map((o) => o.date), shown.all.map((o) => o.date));
    });
  });

  test('one-off meetings appear on their date, even after the semester', () {
    final index = OccurrenceEngine.expand(
      semester: semester(),
      meetings: [
        once(date: '2026-11-03'),
        once(id: 'o2', date: '2027-02-10'),
      ],
    );
    expect(index.all.map((o) => o.date.toIso()), ['2026-11-03', '2027-02-10']);
    expect(index.all.every((o) => o.isOneOff), isTrue);
  });

  group('overrides', () {
    test('changing a meeting time keeps the session history', () {
      final override = SessionOverride(
        meetingId: 'm1',
        originalDate: d('2026-10-25'),
        status: AttendanceStatus.attended,
        notes: 'Chapter 2',
      );
      final before = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
        overrides: [override],
      );
      final after = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly(startMin: 11 * 60, endMin: 13 * 60)],
        overrides: [override],
      );
      final id = override.id;
      expect(before.byId[id]!.status, AttendanceStatus.attended);
      expect(after.byId[id]!.status, AttendanceStatus.attended);
      expect(after.byId[id]!.notes, 'Chapter 2');
      expect(after.byId[id]!.start.hour, 11);
    });

    test('moving one session keeps its id and flags it', () {
      final index = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
        overrides: [
          SessionOverride(
            meetingId: 'm1',
            originalDate: d('2026-10-25'),
            movedDate: d('2026-10-27'),
            movedStartMin: 16 * 60,
            movedLocation: 'Zoom',
          ),
        ],
      );
      final moved = index.byId['m1_20261025']!;
      expect(moved.date.toIso(), '2026-10-27');
      expect(moved.start.hour, 16);
      expect(moved.location, 'Zoom');
      expect(moved.isMoved, isTrue);
      expect(index.onDay(d('2026-10-27')), [moved]);
      expect(index.onDay(d('2026-10-25')), isEmpty);
    });

    test('overrides for dates the rule no longer produces are ignored', () {
      final index = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly(weekday: DateTime.monday)],
        overrides: [
          SessionOverride(
            meetingId: 'm1',
            originalDate: d('2026-10-25'),
            status: AttendanceStatus.missed,
          ),
        ],
      );
      expect(index.byId.containsKey('m1_20261025'), isFalse);
      expect(index.all, hasLength(14));
    });
  });

  group('no-class days', () {
    final holiday = NoClassRange(
      id: 'h1',
      semesterId: 'sem',
      start: d('2026-10-25'),
      end: d('2026-10-26'),
      label: 'Holiday',
    );

    test('cancel sessions as a separate layer', () {
      final index = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
        noClassRanges: [holiday],
      );
      final session = index.byId['m1_20261025']!;
      expect(session.status, AttendanceStatus.canceled);
      expect(session.canceledByNoClassDay, isTrue);
      expect(session.number, isNull);
    });

    test('an explicit status wins over the holiday, and removing the holiday restores it', () {
      final override = SessionOverride(
        meetingId: 'm1',
        originalDate: d('2026-10-25'),
        status: AttendanceStatus.attended,
      );
      final withHoliday = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
        overrides: [override],
        noClassRanges: [holiday],
      );
      expect(withHoliday.byId[override.id]!.status, AttendanceStatus.attended);

      final restored = OccurrenceEngine.expand(
        semester: semester(),
        meetings: [weekly()],
        overrides: [override],
      );
      expect(restored.byId[override.id]!.status, AttendanceStatus.attended);
      expect(restored.byId['m1_20261101']!.status, AttendanceStatus.pending);
    });
  });

  test('numbers sessions per course and type, skipping canceled ones', () {
    final index = OccurrenceEngine.expand(
      semester: semester(end: '2026-11-07'),
      meetings: [
        weekly(),
        weekly(id: 'm2', weekday: DateTime.tuesday),
        weekly(id: 'p1', type: SessionType.practice, weekday: DateTime.monday),
      ],
      overrides: [
        SessionOverride(
          meetingId: 'm2',
          originalDate: d('2026-10-20'),
          status: AttendanceStatus.canceled,
        ),
      ],
    );
    final lectures = index.all.where((o) => o.type == SessionType.lecture);
    expect(lectures.map((o) => (o.date.toIso(), o.number)), [
      ('2026-10-18', 1),
      ('2026-10-20', null),
      ('2026-10-25', 2),
      ('2026-10-27', 3),
      ('2026-11-01', 4),
      ('2026-11-03', 5),
    ]);
    final practices = index.all.where((o) => o.type == SessionType.practice);
    expect(practices.map((o) => o.number), [1, 2, 3]);
  });

  test('index lookups by day and course', () {
    final index = OccurrenceEngine.expand(
      semester: semester(),
      meetings: [
        weekly(),
        weekly(id: 'x1', courseId: 'c2', startMin: 8 * 60, endMin: 9 * 60),
      ],
    );
    final day = index.onDay(d('2026-10-18'));
    expect(day.map((o) => o.courseId), ['c2', 'c1'], reason: 'sorted by time');
    expect(index.forCourse('c2'), hasLength(14));
    expect(index.between(d('2026-10-18'), d('2026-10-31')), hasLength(4));
  });
}
