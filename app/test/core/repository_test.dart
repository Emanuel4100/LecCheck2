import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/domain/semester_data.dart';

class _Recorder implements ChangeRecorder {
  final changes = <(String, String, Map<String, Object?>)>[];
  final ifAbsent = <(String, String)>[];

  @override
  Future<void> record(
    String table,
    String rowId,
    Map<String, Object?> patch, {
    bool ifAbsent = false,
  }) async {
    changes.add((table, rowId, patch));
    if (ifAbsent) this.ifAbsent.add((table, rowId));
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ScheduleRepository repo;
  late _Recorder recorder;

  final semester = SemesterInfo(
    id: 'sem',
    name: 'Semester A',
    start: LocalDate.parse('2026-10-18'),
    end: LocalDate.parse('2027-01-22'),
    visibleDays: const {7, 1, 2, 3, 4},
  );
  const course = CourseInfo(id: 'c1', semesterId: 'sem', name: 'Calculus');
  const lecture = MeetingRule(
    id: 'm1',
    courseId: 'c1',
    type: SessionType.lecture,
    kind: MeetingKind.weekly,
    weekday: DateTime.sunday,
    startMin: 600,
    endMin: 720,
    location: 'Room 101',
  );

  Future<SemesterData> data() async => (await repo.loadSemesterData('sem'))!;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    recorder = _Recorder();
    repo.recorder = recorder;
    await repo.saveSemester(semester);
    await repo.saveCourse(course, meetings: [lecture], requirements: const []);
  });

  tearDown(() => db.close());

  test('loads what was saved and expands it', () async {
    final d = await data();
    expect(d.semester, semester);
    expect(d.courses, [course]);
    expect(d.meetings, [lecture]);
    final index = OccurrenceEngine.expand(
      semester: d.semester,
      meetings: d.meetings,
    );
    expect(index.all, hasLength(14));
  });

  test('status writes create, then patch, the session override', () async {
    var index = OccurrenceEngine.expand(
      semester: semester,
      meetings: [lecture],
    );
    final first = index.all.first;
    recorder.changes.clear();

    await repo.setStatus(first, AttendanceStatus.attended);
    expect(recorder.changes.single.$1, 'session_overrides');
    expect(recorder.changes.single.$3['status'], 'attended');
    expect(
      recorder.changes.single.$3['meetingId'],
      'm1',
      reason: 'new row is sent in full',
    );
    expect(recorder.changes.single.$3.containsKey('updatedAt'), isFalse);

    await repo.setStatus(first, AttendanceStatus.missed);
    expect(recorder.changes.last.$3, {
      'status': 'missed',
    }, reason: 'only changed fields');

    await repo.setStatus(first, AttendanceStatus.missed);
    expect(
      recorder.changes,
      hasLength(2),
      reason: 'no-op writes record nothing',
    );

    final d = await data();
    index = OccurrenceEngine.expand(
      semester: d.semester,
      meetings: d.meetings,
      overrides: d.overrides,
    );
    expect(index.byId[first.id]!.status, AttendanceStatus.missed);
  });

  test(
    'clearing a field writes null (undo, remove recording, reset move)',
    () async {
      final first = OccurrenceEngine.expand(
        semester: semester,
        meetings: [lecture],
      ).all.first;
      await repo.setStatus(first, AttendanceStatus.attended);
      await repo.setRecordingUrl(first, 'https://rec');
      await repo.moveSession(
        first,
        date: first.date.addDays(1),
        startMin: 700,
        endMin: 800,
        location: 'Zoom',
      );
      await repo.setStatus(first, null);
      await repo.setRecordingUrl(first, '');
      await repo.resetSessionMove(first);

      final row = (await db.select(db.sessionOverrides).get()).single;
      expect(row.status, isNull);
      expect(row.recordingUrl, isNull);
      expect(row.movedDate, isNull);
      expect(row.movedStartMin, isNull);
    },
  );

  test('editing the meeting time keeps marked sessions', () async {
    final first = OccurrenceEngine.expand(
      semester: semester,
      meetings: [lecture],
    ).all.first;
    await repo.setStatus(first, AttendanceStatus.attended);
    await repo.setSessionNotes(first, 'Limits');

    const moved = MeetingRule(
      id: 'm1',
      courseId: 'c1',
      type: SessionType.lecture,
      kind: MeetingKind.weekly,
      weekday: DateTime.sunday,
      startMin: 660,
      endMin: 780,
      location: 'Room 101',
    );
    recorder.changes.clear();
    await repo.saveCourse(course, meetings: [moved], requirements: const []);
    expect(recorder.changes.single.$3, {'startMin': 660, 'endMin': 780});

    final d = await data();
    final session = OccurrenceEngine.expand(
      semester: d.semester,
      meetings: d.meetings,
      overrides: d.overrides,
    ).byId[first.id]!;
    expect(session.status, AttendanceStatus.attended);
    expect(session.notes, 'Limits');
    expect(session.start.hour, 11);
  });

  test('deleting a course tombstones its tree and undo restores it', () async {
    final first = OccurrenceEngine.expand(
      semester: semester,
      meetings: [lecture],
    ).all.first;
    await repo.setStatus(first, AttendanceStatus.attended);

    final receipt = await repo.deleteCourse('c1');
    var d = await data();
    expect(d.courses, isEmpty);
    expect(d.meetings, isEmpty);
    expect(d.overrides, isEmpty);
    expect(
      await db.select(db.courses).get(),
      hasLength(1),
      reason: 'tombstone, not hard delete',
    );

    await repo.undoDeletion(receipt);
    d = await data();
    expect(d.courses, [course]);
    expect(d.overrides.single.status, AttendanceStatus.attended);
  });

  test('removed meetings are deleted when the course is saved', () async {
    const practice = MeetingRule(
      id: 'p1',
      courseId: 'c1',
      type: SessionType.practice,
      kind: MeetingKind.weekly,
      weekday: DateTime.monday,
      startMin: 840,
      endMin: 930,
    );
    await repo.saveCourse(
      course,
      meetings: [lecture, practice],
      requirements: const [],
    );
    expect((await data()).meetings, hasLength(2));
    await repo.saveCourse(course, meetings: [practice], requirements: const []);
    expect((await data()).meetings.map((m) => m.id), ['p1']);
  });

  test('watchSemesterData emits after each write', () async {
    final emissions = <SemesterData?>[];
    final sub = repo.watchSemesterData('sem').listen(emissions.add);
    await pumpEventQueue();
    await repo.saveCourse(
      const CourseInfo(id: 'c2', semesterId: 'sem', name: 'Physics'),
      meetings: const [],
      requirements: const [],
    );
    await pumpEventQueue();
    await sub.cancel();
    expect(emissions.length, greaterThanOrEqualTo(2));
    expect(
      emissions.last!.courses.map((c) => c.name),
      containsAll(['Calculus', 'Physics']),
    );
  });

  test('user prefs default and update', () async {
    expect(await repo.watchUserPrefs().first, const UserPrefs());
    await repo.setUse24h(false);
    await repo.setMeetingNumbers(false);
    expect(
      await repo.watchUserPrefs().first,
      const UserPrefs(use24h: false, meetingNumbers: false),
    );
  });

  test('deleting a semester cascades', () async {
    await repo.saveNoClassRange(
      NoClassRange(
        id: 'h1',
        semesterId: 'sem',
        start: LocalDate.parse('2026-12-14'),
        end: LocalDate.parse('2026-12-21'),
      ),
    );
    await repo.deleteSemester('sem');
    expect(await repo.loadSemesterData('sem'), isNull);
    final live = await (db.select(
      db.courses,
    )..where((c) => c.deleted.equals(false))).get();
    expect(live, isEmpty);
  });
}
