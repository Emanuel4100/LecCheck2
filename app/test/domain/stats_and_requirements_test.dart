import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/attendance_stats.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/requirements.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/domain/semester_calendar.dart';

import 'helpers.dart';

const _a = AttendanceStatus.attended;
const _w = AttendanceStatus.watched;
const _m = AttendanceStatus.missed;
const _s = AttendanceStatus.skipped;
const _c = AttendanceStatus.canceled;
const _p = AttendanceStatus.pending;

void main() {
  final now = DateTime(2026, 11, 3, 11, 0); // Tuesday, 11:00

  group('StatusCounts', () {
    test('progress = present / (present + missed)', () {
      final counts = StatusCounts.of([
        occ(date: '2026-10-18', status: _a),
        occ(date: '2026-10-19', status: _w),
        occ(date: '2026-10-20', status: _m),
        occ(date: '2026-10-21', status: _s),
        occ(date: '2026-10-22', status: _c),
        occ(date: '2026-10-23'),
      ]);
      expect(counts.present, 2);
      expect(counts.decided, 3);
      expect(counts.progress, closeTo(2 / 3, 1e-9));
      expect(counts.total, 6);
      expect(StatusCounts().progress, isNull);
    });
  });

  test(
    'needs marking: started + pending, newest first, includes in progress',
    () {
      final sessions = [
        occ(date: '2026-11-01'),
        occ(date: '2026-11-02', status: _a),
        occ(date: '2026-11-03'), // 10:00–12:00, in progress at 11:00
        occ(date: '2026-11-04'), // future
        occ(date: '2026-10-25', status: _c),
      ]..sort((a, b) => a.date.compareTo(b.date));
      final queue = AttendanceStats.needsMarking(sessions, now);
      expect(queue.map((o) => o.date.toIso()), ['2026-11-03', '2026-11-01']);
    },
  );

  test(
    'streak counts consecutive present sessions; pending/canceled are ignored',
    () {
      final sessions = [
        occ(date: '2026-10-18', status: _a),
        occ(date: '2026-10-19', status: _a),
        occ(date: '2026-10-20', status: _a),
        occ(date: '2026-10-21', status: _m),
        occ(date: '2026-10-22', status: _w),
        occ(date: '2026-10-23', status: _c),
        occ(date: '2026-10-25'),
        occ(date: '2026-10-26', status: _a),
        occ(date: '2026-12-01', status: _m), // future: not counted
      ];
      final streak = AttendanceStats.streak(sessions, now);
      expect(streak.current, 2);
      expect(streak.best, 3);
    },
  );

  test('catch-up lists missed sessions with a recording', () {
    final sessions = [
      occ(date: '2026-10-18', status: _m, recordingUrl: 'https://rec/1'),
      occ(date: '2026-10-19', status: _m),
      occ(date: '2026-10-20', status: _w, recordingUrl: 'https://rec/2'),
    ];
    expect(AttendanceStats.catchUp(sessions), hasLength(1));
  });

  test('groups by week, course and type', () {
    final sessions = [
      occ(date: '2026-10-18', status: _a),
      occ(date: '2026-10-25', status: _m, courseId: 'c2'),
      occ(date: '2026-10-26', status: _a, type: SessionType.lab),
    ];
    final cal = SemesterCalendar(semester());
    final weeks = AttendanceStats.byWeek(sessions, cal, now);
    expect(weeks[1]!.present, 1);
    expect(weeks[2]!.decided, 2);
    expect(AttendanceStats.byCourse(sessions, now)['c2']![_m], 1);
    expect(AttendanceStats.byType(sessions, now)[SessionType.lab]!.present, 1);
  });

  group('requirements', () {
    AttendanceRequirement req({
      int pct = 80,
      SessionType? type,
      bool rec = false,
    }) => AttendanceRequirement(
      id: 'r1',
      courseId: 'c1',
      minPercent: pct,
      type: type,
      recordingsCount: rec,
    );

    List<Occurrence> sessionsWith(List<AttendanceStatus> statuses) => [
      for (var i = 0; i < statuses.length; i++)
        occ(
          date: '2026-11-${(i + 1).toString().padLeft(2, '0')}',
          status: statuses[i],
        ),
    ];

    test('slack = total - ceil(total × pct) - absences', () {
      // 10 sessions, 80% → 8 required, 2 absences allowed.
      final p = evaluateRequirement(
        req(),
        sessionsWith([_a, _a, _m, _p, _p, _p, _p, _p, _p, _p]),
      );
      expect((p.total, p.required, p.absences, p.remaining), (10, 8, 1, 7));
      expect(p.slack, 1);
      expect(p.state, RequirementState.warning);
    });

    test('states from on-track to failed and met', () {
      RequirementState state(List<AttendanceStatus> s) =>
          evaluateRequirement(req(), sessionsWith(s)).state;
      expect(
        state([_a, _p, _p, _p, _p, _p, _p, _p, _p, _p]),
        RequirementState.onTrack,
      );
      expect(
        state([_m, _s, _p, _p, _p, _p, _p, _p, _p, _p]),
        RequirementState.atRisk,
      );
      expect(
        state([_m, _s, _m, _p, _p, _p, _p, _p, _p, _p]),
        RequirementState.failed,
      );
      expect(
        state([_a, _a, _a, _a, _a, _a, _a, _a, _m, _a]),
        RequirementState.met,
      );
    });

    test(
      'canceled sessions are out of scope; recordings count only when enabled',
      () {
        final sessions = sessionsWith([_w, _w, _c, _a, _p]);
        final strict = evaluateRequirement(req(pct: 50), sessions);
        expect((strict.total, strict.absences, strict.attended), (4, 2, 1));
        final lenient = evaluateRequirement(req(pct: 50, rec: true), sessions);
        expect((lenient.absences, lenient.attended), (0, 3));
      },
    );

    test('type-scoped requirement ignores other types', () {
      final sessions = [
        occ(date: '2026-11-01', status: _m, type: SessionType.practice),
        occ(date: '2026-11-02', status: _m),
      ];
      final p = evaluateRequirement(req(type: SessionType.practice), sessions);
      expect((p.total, p.absences), (1, 1));
    });
  });
}
