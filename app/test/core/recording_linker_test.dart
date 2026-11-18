import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/recordings/panopto_connection.dart';
import 'package:leccheck/core/recordings/recording_linker.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/recording_match.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_panopto.dart';

class _Recorder implements ChangeRecorder {
  final changes = <(String, String, Map<String, Object?>)>[];

  @override
  Future<void> record(
    String table,
    String rowId,
    Map<String, Object?> patch, {
    bool ifAbsent = false,
  }) async => changes.add((table, rowId, patch));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ScheduleRepository repo;
  late _Recorder recorder;
  late FakePanopto panopto;
  late PanoptoConnection connection;
  late RecordingLinker linker;
  late DateTime now;

  final semester = SemesterInfo(
    id: 'sem',
    name: 'Semester A',
    start: LocalDate.parse('2026-10-11'),
    end: LocalDate.parse('2027-01-22'),
  );
  const course = CourseInfo(
    id: 'c80430',
    semesterId: 'sem',
    name: 'מבוא להסתברות',
    code: '80430',
  );
  MeetingRule meeting(
    String id,
    SessionType type,
    int weekday,
    int start,
    String room,
  ) => MeetingRule(
    id: id,
    courseId: course.id,
    type: type,
    kind: MeetingKind.weekly,
    weekday: weekday,
    startMin: start,
    endMin: start + 105,
    location: room,
  );
  final meetings = [
    meeting('tue10', SessionType.lecture, DateTime.tuesday, 600, 'קפלן'),
    meeting(
      'thuPractice',
      SessionType.practice,
      DateTime.thursday,
      600,
      'שפרינצק 27',
    ),
    meeting('thu12', SessionType.lecture, DateTime.thursday, 720, 'פלדמן ב'),
  ];

  Future<List<Occurrence>> sessions() async {
    final d = (await repo.loadSemesterData('sem'))!;
    return OccurrenceEngine.expand(
      semester: d.semester,
      meetings: d.meetings,
      overrides: d.overrides,
    ).all;
  }

  Future<Map<String, String?>> links() async => {
    for (final s in await sessions())
      if (s.recordingUrl != null)
        '${s.meetingId} ${s.date}${s.recordingAuto ? '' : ' (pasted)'}':
            s.recordingUrl,
  };

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    recorder = _Recorder();
    repo.recorder = recorder;
    await repo.saveSemester(semester);
    await repo.saveCourse(course, meetings: meetings, requirements: const []);
    panopto = FakePanopto();
    now = DateTime(2026, 11, 16, 20);
    connection = PanoptoConnection(
      lock: MemoryLock(),
      client: panopto.client,
      browser: panopto.browser,
      clock: () => now,
      redirectUrl: 'https://sync.example/v1/panopto/done',
      networkRetry: Duration.zero,
    );
    linker = RecordingLinker(
      repo: repo,
      connection: connection,
      prefs: await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      ),
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  test('not connected: nothing happens', () async {
    expect(await linker.run(force: true), isNull);
    expect(panopto.requests, isEmpty);
  });

  test('finds the folder by the course number and fills the links', () async {
    await connection.connect(FakePanopto.setup);
    final report = (await linker.run())!;
    expect(report.error, isNull);
    // Tuesday 10:00 ×4 and Thursday 12:00 ×5; the practice waits for an
    // answer.
    expect(report.written, 9);
    expect(report.questions.single.question.meetingId, 'thuPractice');
    expect(report.questions.single.courseId, course.id);
    expect((await repo.panoptoFolders())[course.id], const [
      PanoptoFolderRef(
        id: FakePanopto.folderId,
        name: '2026-27 -> 80430_1-מבוא להסתברות ולסטטיסטיקה',
      ),
    ]);
    // Written like any edit: they sync.
    final synced = [
      for (final (table, _, patch) in recorder.changes)
        if (table == 'session_overrides' && patch['recordingFound'] != null)
          patch,
    ];
    expect(synced, hasLength(9));
    expect(linker.report.written, 9);
  });

  test('answering the group question fills the practice', () async {
    await connection.connect(FakePanopto.setup);
    await linker.run();
    await repo.setPanoptoGroup('thuPractice', 'ו');
    final report = (await linker.run(force: true, courseId: course.id))!;
    expect(report.written, 5);
    expect(report.questions, isEmpty);
    final practice = (await links()).keys.where(
      (k) => k.startsWith('thuPractice'),
    );
    expect(practice, hasLength(5));
  });

  test('links pasted into a meeting teach it its group', () async {
    await connection.connect(FakePanopto.setup);
    final all = await sessions();
    Occurrence on(String date) => all.firstWhere(
      (s) => s.meetingId == 'thuPractice' && s.date == LocalDate.parse(date),
    );
    // The fixture's ids: group ו's recordings of 2026-10-29 and 2026-11-05.
    String viewer(String name, String group) {
      final json = [
        for (final page in [0, 1])
          ...(jsonDecode(
                    File('test/fixtures/panopto/folder_sessions_p$page.json')
                        .readAsStringSync(),
                  )['Results']
                  as List)
              .cast<Map<String, Object?>>(),
      ];
      final hit = json.firstWhere(
        (j) =>
            j['Name'] == name &&
            (j['Description'] as String? ?? '').endsWith('תרגיל $group'),
      );
      return (hit['Urls']! as Map)['ViewerUrl'] as String;
    }

    await repo.setRecordingUrl(
      on('2026-10-29'),
      viewer('80430 2026-10-29 תרגיל ו', 'ו'),
    );
    await repo.setRecordingUrl(
      on('2026-11-05'),
      viewer('80430 2026-11-05 תרגיל ו', 'ו'),
    );
    final report = (await linker.run())!;
    expect(report.questions, isEmpty);
    expect(await repo.panoptoGroups(), {'thuPractice': 'ו'});
    // Tuesday 4 + Thursday lectures 5 + the other three practices.
    expect(report.written, 12);
  });

  test('at most every 3 hours unless asked', () async {
    await connection.connect(FakePanopto.setup);
    await linker.run();
    final before = panopto.apiRequests.length;
    now = now.add(const Duration(hours: 1));
    expect(await linker.run(), isNull);
    expect(panopto.apiRequests.length, before);
    now = now.add(const Duration(hours: 2, minutes: 1));
    expect(await linker.run(), isNotNull);
  });

  test('no connection: the next start looks again, without waiting', () async {
    await connection.connect(FakePanopto.setup);
    panopto.apiOffline = 2;
    expect((await linker.run())!.error, 'network');
    now = now.add(const Duration(minutes: 5));
    final report = (await linker.run())!;
    expect(report.error, isNull);
    expect(report.written, greaterThan(0));
    // And then the usual 3 hours.
    now = now.add(const Duration(minutes: 5));
    expect(await linker.run(), isNull);
  });

  test('links pasted or cleared by hand stay', () async {
    await connection.connect(FakePanopto.setup);
    final all = await sessions();
    Occurrence on(String meetingId, String date) => all.firstWhere(
      (s) => s.meetingId == meetingId && s.date == LocalDate.parse(date),
    );
    await repo.setRecordingUrl(on('thu12', '2026-10-15'), 'https://mine');
    await linker.run();
    // The user clears a found link.
    await repo.setRecordingUrl(on('thu12', '2026-10-22'), '');
    await linker.run(force: true);
    final found = await links();
    expect(found['thu12 2026-10-15 (pasted)'], 'https://mine');
    expect(found['thu12 2026-10-22 (pasted)'], '');
    expect(found.keys.where((k) => k.startsWith('thu12')), hasLength(5));
  });

  test('clearing an empty field doesn\'t block finding a link', () async {
    final first = (await sessions()).first;
    recorder.changes.clear();
    await repo.setRecordingUrl(first, '   ');
    expect(recorder.changes, isEmpty);
    expect((await sessions()).first.recordingUrl, isNull);
  });

  test('a link pasted elsewhere that syncs in later still wins', () async {
    await connection.connect(FakePanopto.setup);
    await linker.run();
    final found = (await sessions()).firstWhere((s) => s.recordingAuto);
    // Pasted on an offline phone before the look, it arrives afterwards:
    // sync keeps both fields, each from its own device.
    await repo.setRecordingUrl(found, 'https://from-the-phone');
    final after = (await sessions()).firstWhere((s) => s.id == found.id);
    expect(
      (after.recordingUrl, after.recordingAuto),
      ('https://from-the-phone', false),
    );
    // Removing the found links leaves it alone.
    await repo.clearFoundRecordings();
    final cleared = (await sessions()).firstWhere((s) => s.id == found.id);
    expect(cleared.recordingUrl, 'https://from-the-phone');
  });

  test('clearing a found link hides it for good', () async {
    await connection.connect(FakePanopto.setup);
    await linker.run();
    final found = (await sessions()).firstWhere((s) => s.recordingAuto);
    await repo.setRecordingUrl(found, '');
    await linker.run(force: true);
    final after = (await sessions()).firstWhere((s) => s.id == found.id);
    expect((after.recordingUrl, after.recordingAuto), ('', false));
  });

  test('removing the found links keeps the pasted ones', () async {
    await connection.connect(FakePanopto.setup);
    final first = (await sessions()).firstWhere((s) => s.meetingId == 'thu12');
    await repo.setRecordingUrl(first, 'https://mine');
    await linker.run();
    expect(await repo.clearFoundRecordings(), 8);
    expect(await links(), {'thu12 ${first.date} (pasted)': 'https://mine'});
  });

  test(
    'editing the course keeps its folders and the meeting\'s group',
    () async {
      await connection.connect(FakePanopto.setup);
      await linker.run();
      await repo.setPanoptoGroup('thuPractice', 'ו');
      final edited = [
        for (final m in meetings)
          m.id == 'thuPractice' ? m.movedTo(startMin: 615, endMin: 705) : m,
      ];
      await repo.saveCourse(
        const CourseInfo(
          id: 'c80430',
          semesterId: 'sem',
          name: 'Probability',
          code: '80430',
        ),
        meetings: edited,
        requirements: const [],
        base: CourseBase(
          course: course,
          meetings: meetings,
          requirements: const [],
        ),
      );
      expect((await repo.panoptoFolders())[course.id], hasLength(1));
      expect(await repo.panoptoGroups(), {'thuPractice': 'ו'});
    },
  );

  test('a sign-in that expired is reported, and links stay', () async {
    await connection.connect(FakePanopto.setup);
    await linker.run();
    panopto
      ..refreshToken = 'revoked'
      ..expireAccess();
    final report = (await linker.run(force: true))!;
    expect(report.error, 'reconnect');
    expect(await connection.status(), PanoptoStatus.reconnect);
    expect((await links()).length, 9);
  });

  test('academic years', () {
    expect(
      RecordingLinker.academicYear(LocalDate.parse('2026-10-11')),
      '2026-27',
    );
    expect(
      RecordingLinker.academicYear(LocalDate.parse('2027-03-01')),
      '2026-27',
    );
    expect(
      RecordingLinker.academicYear(LocalDate.parse('2099-10-01')),
      '2099-00',
    );
  });

  group('Find in Panopto for one session', () {
    Future<Occurrence> session(String meetingId, {int index = 0}) async {
      final all = [
        for (final s in await sessions())
          if (s.meetingId == meetingId && s.hasEnded(now)) s,
      ];
      return all[index];
    }

    List<(String, String, Map<String, Object?>)> foundWrites() => [
      for (final c in recorder.changes)
        if (c.$3['recordingFound'] != null) c,
    ];

    test('finds the recording the look would, and writes nothing', () async {
      await connection.connect(FakePanopto.setup);
      final s = await session('tue10', index: 1);
      final check = await linker.check(s);
      expect(check.outcome, SessionOutcome.found);
      expect(check.found, isNotNull);
      expect(foundWrites(), isEmpty);
      // Not the account's look: the report and the 3 hours stay.
      expect(linker.report.at, isNull);

      await linker.run();
      expect((await links())['tue10 ${s.date}'], check.found!.viewerUrl);
    });

    test('leaves a pasted or removed link out, to compare with it', () async {
      await connection.connect(FakePanopto.setup);
      final s = await session('tue10', index: 1);
      await repo.setRecordingUrl(s, 'https://example.com/mine');
      final pasted = await linker.check(
        (await sessions()).firstWhere((o) => o.id == s.id),
      );
      expect(pasted.found, isNotNull);

      await repo.setRecordingUrl(s, '');
      final removed = await linker.check(
        (await sessions()).firstWhere((o) => o.id == s.id),
      );
      expect(removed.found?.id, pasted.found!.id);
      expect(foundWrites(), isEmpty);
    });

    test('parallel groups: asks, then finds the chosen group', () async {
      await connection.connect(FakePanopto.setup);
      final s = await session('thuPractice', index: 2);
      final ask = await linker.check(s);
      expect(ask.found, isNull);
      expect(ask.outcome, SessionOutcome.askGroup);
      expect(
        ask.question!.options.map((o) => o.group),
        containsAll(['ד', 'ו']),
      );
      // Both groups' recordings that day, to pick from.
      expect(
        ask.sameDay.map((r) => r.recording.group).toSet(),
        containsAll(['ד', 'ו']),
      );

      await repo.setPanoptoGroup('thuPractice', 'ו');
      final found = await linker.check(s);
      expect(found.found!.group, 'ו');
      expect(found.question, isNull);
    });

    test('says why when nothing fits', () async {
      await connection.connect(FakePanopto.setup);
      final future = (await sessions()).firstWhere(
        (s) => s.meetingId == 'tue10' && !s.hasEnded(now),
      );
      final check = await linker.check(future);
      expect(check.found, isNull);
      expect(check.outcome, SessionOutcome.notOver);

      await repo.setPanoptoFolders(course.id, const []);
      final none = await linker.check(await session('tue10'));
      expect(none.noFolder, isTrue);
      expect(none.found, isNull);
    });

    test('the groups recorded at a meeting, whatever is chosen', () async {
      await connection.connect(FakePanopto.setup);
      final before = await linker.groupOptions(course.id, 'thuPractice');
      expect(before.map((o) => o.group), containsAll(['ד', 'ו']));
      await repo.setPanoptoGroup('thuPractice', 'ו');
      final after = await linker.groupOptions(course.id, 'thuPractice');
      expect(after.map((o) => o.group), before.map((o) => o.group));
    });

    test('using the found recording replaces a pasted link', () async {
      await connection.connect(FakePanopto.setup);
      final s = await session('tue10', index: 1);
      await repo.setRecordingUrl(s, 'https://example.com/mine');
      final check = await linker.check(s);
      await repo.useFoundRecording(s, check.found!.viewerUrl);
      expect((await links())['tue10 ${s.date}'], check.found!.viewerUrl);
      expect((await links()).containsKey('tue10 ${s.date} (pasted)'), isFalse);
      // A later look keeps it.
      await linker.run(force: true);
      expect((await links())['tue10 ${s.date}'], check.found!.viewerUrl);
    });
  });
}
