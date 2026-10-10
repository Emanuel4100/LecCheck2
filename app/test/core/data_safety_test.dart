// Guards against data being overwritten, dropped or lost: editor saves,
// backup imports, restores, the trash, snapshots, the sync outbox, rows from
// older app versions and notification buttons.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/backup/backup_service.dart';
import 'package:leccheck/core/backup/snapshot_service.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/mappers.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/notifications/notification_actions.dart';
import 'package:leccheck/core/sync/hlc.dart';
import 'package:leccheck/core/sync/sync_engine.dart';
import 'package:leccheck/core/sync/sync_recorder.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late ScheduleRepository repo;
  late SyncRecorder recorder;

  final semester = SemesterInfo(
    id: 'sem',
    name: 'Semester A',
    start: LocalDate.parse('2026-10-18'),
    end: LocalDate.parse('2027-01-22'),
  );
  const course = CourseInfo(
    id: 'c1',
    semesterId: 'sem',
    name: 'Calculus',
    lecturer: 'Dr. Cohen',
  );
  const lecture = MeetingRule(
    id: 'm1',
    courseId: 'c1',
    type: SessionType.lecture,
    kind: MeetingKind.weekly,
    weekday: DateTime.sunday,
    startMin: 600,
    endMin: 720,
  );
  const practice = MeetingRule(
    id: 'm2',
    courseId: 'c1',
    type: SessionType.practice,
    kind: MeetingKind.weekly,
    weekday: DateTime.monday,
    startMin: 840,
    endMin: 900,
  );

  Future<List<OutboxEntry>> outbox() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  Future<CourseRow> courseRow(String id) =>
      (db.select(db.courses)..where((c) => c.id.equals(id))).getSingle();

  Future<MeetingRow> meetingRow(String id) =>
      (db.select(db.meetings)..where((m) => m.id.equals(id))).getSingle();

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    recorder = SyncRecorder(db: db, prefs: prefs);
    repo.recorder = recorder;
    await repo.saveSemester(semester);
    await repo.saveCourse(course, meetings: [lecture], requirements: const []);
    await db.delete(db.outbox).go();
  });

  tearDown(() => db.close());

  group('editor saves', () {
    test('only write what the user changed; synced edits survive', () async {
      final base = CourseBase(
        course: course,
        meetings: const [lecture],
        requirements: const [],
      );
      // While the editor is open, another device changes the lecturer and
      // adds a meeting.
      await SyncEngine.applyServerRows(db, repo, [
        {
          'tbl': 'courses',
          'id': 'c1',
          'data': {...(await courseRow('c1')).toJson(), 'lecturer': 'Dr. Levi'},
        },
        {'tbl': 'meetings', 'id': 'm2', 'data': _row(practice.toRow())},
      ], cursor: null);

      // The user renames the course and saves the list they loaded.
      await repo.saveCourse(
        const CourseInfo(
          id: 'c1',
          semesterId: 'sem',
          name: 'Calculus 1',
          lecturer: 'Dr. Cohen',
        ),
        meetings: const [lecture],
        requirements: const [],
        base: base,
      );

      final row = await courseRow('c1');
      expect(row.name, 'Calculus 1');
      expect(row.lecturer, 'Dr. Levi');
      expect((await meetingRow('m2')).deleted, isFalse);
      final pushed = await outbox();
      expect(pushed, hasLength(1));
      expect(jsonDecode(pushed.single.patch), {'name': 'Calculus 1'});
    });

    test('a meeting the user removed is deleted', () async {
      await repo.saveCourse(
        course,
        meetings: const [lecture, practice],
        requirements: const [],
      );
      await repo.saveCourse(
        course,
        meetings: const [lecture],
        requirements: const [],
        base: const CourseBase(
          course: course,
          meetings: [lecture, practice],
          requirements: [],
        ),
      );
      expect((await meetingRow('m2')).deleted, isTrue);
      expect((await meetingRow('m1')).deleted, isFalse);
    });

    test('a semester form keeps fields changed elsewhere', () async {
      await SyncEngine.applyServerRows(db, repo, [
        {
          'tbl': 'semesters',
          'id': 'sem',
          'data': {'id': 'sem', 'endDate': '2027-02-05'},
        },
      ], cursor: null);
      await repo.saveSemester(
        SemesterInfo(
          id: 'sem',
          name: 'Fall',
          start: semester.start,
          end: semester.end,
        ),
        base: semester,
      );
      final row = await (db.select(db.semesters)).getSingle();
      expect(row.name, 'Fall');
      expect(row.endDate, '2027-02-05');
    });
  });

  group('import', () {
    Map<String, List<Map<String, Object?>>> backup() => {
      'courses': [
        {..._row(course.toRow()), 'lecturer': 'Old lecturer'},
        _row(
          const CourseInfo(
            id: 'c2',
            semesterId: 'sem',
            name: 'Physics',
          ).toRow(),
        ),
      ],
    };

    test('preview counts new and different rows', () async {
      expect(await repo.previewImport(backup()), (added: 1, changed: 1));
    });

    test('merge only adds, and asks the server to only add', () async {
      await repo.importRows(backup());
      expect((await courseRow('c1')).lecturer, 'Dr. Cohen');
      expect((await courseRow('c2')).name, 'Physics');
      final pushed = await outbox();
      expect([for (final e in pushed) (e.rowId, e.ifAbsent)], [('c2', true)]);
    });

    test('replace overwrites', () async {
      await repo.importRows(backup(), mode: ImportMode.replace);
      expect((await courseRow('c1')).lecturer, 'Old lecturer');
      expect((await outbox()).every((e) => !e.ifAbsent), isTrue);
    });

    test('importing a v1 file twice adds nothing the second time', () async {
      final v1 = jsonEncode({
        'semesters': [
          {
            'id': 's1',
            'name': 'Old',
            'startDate': '2025-10-19',
            'endDate': '2026-01-20',
            'noClassDates': ['2025-12-25'],
            'courses': [
              {
                'id': 'k1',
                'name': 'Algebra',
                'meetings': [
                  {'id': 'km', 'weekday': 1, 'start': '10:00', 'end': '12:00'},
                ],
              },
            ],
          },
        ],
      });
      final service = BackupService(repo);
      expect(await service.importJson(v1), 1);
      final parsed = BackupService.parse(v1);
      expect(await repo.previewImport(parsed.tables), (added: 0, changed: 0));
    });
  });

  group('restore and trash', () {
    test('restoreAll returns to the snapshot state', () async {
      final snapshot = await repo.exportRows(includeDeleted: true);
      await repo.saveCourse(
        const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Renamed'),
        meetings: const [lecture],
        requirements: const [],
      );
      await repo.saveCourse(
        const CourseInfo(id: 'c2', semesterId: 'sem', name: 'New'),
        meetings: const [],
        requirements: const [],
      );
      await repo.restoreAll(snapshot);
      expect((await courseRow('c1')).name, 'Calculus');
      expect((await courseRow('c2')).deleted, isTrue);
    });

    test('a deleted course comes back with what was deleted with it', () async {
      await repo.saveCourse(
        course,
        meetings: const [lecture, practice],
        requirements: const [],
      );
      // The practice was deleted on its own, a day earlier.
      await repo.deleteMeeting('m2');
      await (db.update(db.meetings)..where((m) => m.id.equals('m2'))).write(
        MeetingsCompanion(
          updatedAt: Value(
            DateTime.now().millisecondsSinceEpoch - Duration.millisecondsPerDay,
          ),
        ),
      );
      await repo.deleteCourse('c1');

      final deleted = await repo.recentlyDeleted();
      expect([for (final d in deleted) (d.table, d.id)], [('courses', 'c1')]);
      await repo.restoreDeleted(deleted.single);
      expect((await courseRow('c1')).deleted, isFalse);
      expect((await meetingRow('m1')).deleted, isFalse);
      expect((await meetingRow('m2')).deleted, isTrue);
      expect(await repo.recentlyDeleted(), isEmpty);
    });

    test('a deleted semester is listed instead of its courses', () async {
      await repo.deleteSemester('sem');
      final deleted = await repo.recentlyDeleted();
      expect([for (final d in deleted) d.id], ['sem']);
      await repo.restoreDeleted(deleted.single);
      expect((await repo.loadSemesterData('sem'))!.courses, hasLength(1));
    });
  });

  group('snapshots', () {
    late Directory dir;
    late SnapshotService snapshots;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('leccheck_snapshots');
      snapshots = SnapshotService(repo, () async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('keeps 7 daily, 4 weekly and 10 others', () async {
      final start = DateTime(2026, 6, 1, 9);
      for (var day = 0; day < 60; day++) {
        await snapshots.takeDailyIfDue(now: start.add(Duration(days: day)));
        await snapshots.takeDailyIfDue(
          now: start.add(Duration(days: day, hours: 2)),
        );
      }
      for (var i = 0; i < 12; i++) {
        await snapshots.take(
          SnapshotReason.beforeImport,
          now: start.add(Duration(days: 60, minutes: i)),
        );
      }
      final all = await snapshots.list();
      final daily = all.where((s) => s.reason == SnapshotReason.daily);
      expect(daily, hasLength(SnapshotService.keepDaily + 4));
      expect(daily.first.takenAt, start.add(const Duration(days: 59)));
      expect(all.length - daily.length, SnapshotService.keepEvents);
      expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
    });

    test('restore brings data back and can itself be undone', () async {
      final saved = (await snapshots.take(SnapshotReason.daily))!;
      expect((await saved.file.readAsBytes()).take(2), [0x1f, 0x8b]); // gzip
      await repo.deleteCourse('c1');
      await snapshots.restore(saved);
      expect((await courseRow('c1')).deleted, isFalse);
      final undo = (await snapshots.list()).firstWhere(
        (s) => s.reason == SnapshotReason.beforeRestore,
      );
      await snapshots.restore(undo);
      expect((await courseRow('c1')).deleted, isTrue);
    });

    test('an empty database is not snapshotted', () async {
      await repo.wipeAll();
      expect(await snapshots.take(SnapshotReason.beforeSignOut), isNull);
    });
  });

  group('sync outbox', () {
    test('refused changes stay parked; a wrong clock is corrected', () async {
      await repo.setMeetingNumbers(false);
      await repo.setUse24h(true);
      await repo.saveNoClassRange(
        NoClassRange(
          id: 'nc',
          semesterId: 'sem',
          start: semester.start,
          end: semester.start,
        ),
      );
      final sent = await outbox();
      expect(sent, hasLength(3));
      final serverNow = DateTime.now().millisecondsSinceEpoch - 3600 * 1000;
      await SyncEngine.settleBatch(
        db: db,
        repo: repo,
        recorder: recorder,
        seqs: [for (final e in sent) e.seq],
        reply: {
          'rejected': [
            {
              'i': 1,
              'tbl': 'user_settings',
              'id': 'me',
              'reason': 'clock_skew',
            },
            {'i': 2, 'tbl': 'no_class_ranges', 'id': 'nc', 'reason': 'bad_id'},
          ],
          'rows': const [],
          'now': serverNow,
        },
      );
      final left = await outbox();
      expect(
        [for (final e in left) (e.seq, e.rejected)],
        [(sent[1].seq, null), (sent[2].seq, 'bad_id')],
      );
      // Re-stamped with the server's time, so it is accepted next time.
      expect(
        Hlc.parse(left.first.hlc).millis,
        lessThanOrEqualTo(serverNow + 5 * 60 * 1000),
      );

      await recorder.retryRejected();
      expect((await outbox()).every((e) => e.rejected == null), isTrue);
    });

    test('a field that lost on the server is corrected here', () async {
      await repo.setMeetingNumbers(false);
      final sent = await outbox();
      await SyncEngine.settleBatch(
        db: db,
        repo: repo,
        recorder: recorder,
        seqs: [for (final e in sent) e.seq],
        reply: {
          'rejected': const [],
          'rows': [
            {
              'tbl': 'user_settings',
              'id': 'me',
              'data': {'id': 'me', 'meetingNumbers': true, 'deleted': false},
              'v': 9,
            },
          ],
        },
      );
      expect(await outbox(), isEmpty);
      expect((await repo.watchUserPrefs().first).meetingNumbers, isTrue);
    });

    test('Retry leaves fields edited since then to the newer edit', () async {
      await repo.setUse24h(false); // The settings row exists (synced).
      await db.delete(db.outbox).go();
      await repo.setMeetingNumbers(false);
      await repo.setUse24h(true);
      final first = await outbox();
      expect(first, hasLength(2));
      // Both refused, then the user changes meeting numbers again.
      await SyncEngine.settleBatch(
        db: db,
        repo: repo,
        recorder: recorder,
        seqs: [for (final e in first) e.seq],
        reply: {
          'rejected': [
            for (final (i, e) in first.indexed)
              {'i': i, 'tbl': e.tbl, 'id': e.rowId, 'reason': 'bad_id'},
          ],
          'rows': const [],
        },
      );
      await repo.setMeetingNumbers(true);
      final newest = (await outbox()).last;

      await recorder.retryRejected();
      final left = await outbox();
      // The old meetingNumbers change is gone (the newer one decides); the
      // use24h one goes out again, before the newer edit's clock no more.
      expect([for (final e in left) e.seq], [first[1].seq, newest.seq]);
      expect(jsonDecode(left.first.patch), {'use24h': true});
      expect(left.every((e) => e.rejected == null), isTrue);
      expect(
        Hlc.parse(left.first.hlc).compareTo(Hlc.parse(newest.hlc)),
        greaterThan(0),
      );
    });

    test('a batch stays under the server\'s message size', () async {
      final note = 'x' * 15000;
      for (var i = 0; i < 60; i++) {
        await recorder.record('courses', 'c$i', {'notes': note});
      }
      final batch = await SyncEngine.nextBatch(db);
      expect(batch.length, inInclusiveRange(30, 34));
      final size = jsonEncode([
        for (final e in batch)
          {
            'tbl': e.tbl,
            'id': e.rowId,
            'patch': jsonDecode(e.patch),
            'hlc': e.hlc,
          },
      ]).length;
      expect(size, lessThan(SyncEngine.maxBatchChars));
      // One huge change still goes on its own.
      await db.delete(db.outbox).go();
      await recorder.record('courses', 'big', {'notes': 'y' * 600000});
      expect(await SyncEngine.nextBatch(db), hasLength(1));
    });

    test('server rows beat pending add-only offers', () async {
      await recorder.enqueueAll(repo);
      await SyncEngine.applyServerRows(db, repo, [
        {
          'tbl': 'courses',
          'id': 'c1',
          'data': {'id': 'c1', 'name': 'Newer name', 'deleted': true},
        },
      ], cursor: null);
      final row = await courseRow('c1');
      expect(row.name, 'Newer name');
      expect(row.deleted, isTrue);
      expect(row.lecturer, 'Dr. Cohen');
    });
  });

  group('when the server is over its daily limit', () {
    late HttpServer server;
    late int connections;
    SyncEngine? engine;

    SyncEngine start() => engine = SyncEngine(
      db: db,
      repo: repo,
      recorder: recorder,
      session: const Session(token: 'token', userId: 'dev:test'),
      watchLifecycle: false,
      socketUri: Uri.parse('ws://127.0.0.1:${server.port}/v1/sync'),
    )..start();

    Future<SyncState> held(SyncEngine engine) => engine.states
        .firstWhere((s) => s.heldUntil != null)
        .timeout(const Duration(seconds: 5));

    setUp(() async {
      connections = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });
    tearDown(() async {
      await engine?.dispose();
      engine = null;
      await server.close(force: true);
    });

    test('changes stay queued until the time the server gives', () async {
      final retryAt = DateTime.now().add(const Duration(hours: 1));
      server.listen((request) async {
        connections++;
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((data) {
          final message = jsonDecode(data as String) as Map<String, Object?>;
          socket.add(
            jsonEncode(switch (message['t']) {
              'hello' => {
                't': 'changes',
                'rows': const [],
                'upto': 0,
                'more': false,
                'clock': null,
                'catchUp': true,
              },
              _ => {
                't': 'error',
                'code': 'quota',
                'message': 'Storage unavailable',
                'retryAt': retryAt.millisecondsSinceEpoch,
              },
            }),
          );
        });
      });
      await repo.setMeetingNumbers(false);

      final state = await held(start());
      expect(state.phase, SyncPhase.offline);
      expect(state.pending, 1);
      // At the reset, plus up to 5 minutes so devices don't all come back
      // at once.
      expect(
        state.heldUntil!.difference(retryAt).inSeconds,
        inInclusiveRange(-1, 5 * 60 + 1),
      );
      expect(await outbox(), hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(connections, 1);
    });

    test('a message that fails to apply doesn\'t stop sync', () async {
      final pushes = <Object?>[];
      server.listen((request) async {
        connections++;
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((data) {
          final message = jsonDecode(data as String) as Map<String, Object?>;
          switch (message['t']) {
            case 'hello':
              // The first catch-up carries a row this app can't read.
              socket.add(
                jsonEncode({
                  't': 'changes',
                  'rows': connections == 1
                      ? [
                          {'tbl': 'courses', 'id': 42, 'data': 'broken'},
                        ]
                      : const [],
                  'upto': 0,
                  'more': false,
                  'clock': null,
                  'catchUp': true,
                }),
              );
            case 'push':
              pushes.add(message['changes']);
              socket.add(
                jsonEncode({
                  't': 'ack',
                  'batchId': message['batchId'],
                  'rejected': const [],
                  'rows': const [],
                  'clock': null,
                }),
              );
          }
        });
      });
      await repo.setMeetingNumbers(false);
      final engine = start();
      await engine.states
          .firstWhere((s) => s.phase == SyncPhase.synced && s.pending == 0)
          .timeout(const Duration(seconds: 10));
      // It reconnected and caught up again, then pushed.
      expect(connections, 2);
      expect(pushes, hasLength(1));
      expect(await outbox(), isEmpty);
    });

    test('"Sync now" while connecting opens only one connection', () async {
      server.listen((request) async {
        connections++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) {});
      });
      final engine = start();
      engine.syncNow();
      engine.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(connections, 1);
    });

    test('a refused connection backs off instead of retrying', () async {
      server.listen((request) {
        connections++;
        request.response
          ..statusCode = HttpStatus.serviceUnavailable
          ..close();
      });
      final state = await held(start());
      final wait = state.heldUntil!.difference(DateTime.now());
      expect(wait.inSeconds, inInclusiveRange(55, 70));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(connections, 1);
    });
  });

  group('short names (database v3)', () {
    // A course as v2.0.0-beta.3 and older store and send it.
    Map<String, Object?> older(String id, String name) =>
        _row(CourseInfo(id: id, semesterId: 'sem', name: name).toRow())
          ..remove('shortName');

    test('courses saved by older app versions still load', () async {
      // Synced from a device that doesn't know short names yet,
      await SyncEngine.applyServerRows(db, repo, [
        {'tbl': 'courses', 'id': 'c2', 'data': older('c2', 'Physics')},
      ], cursor: null);
      // in a backup file,
      await repo.importRows({
        'courses': [older('c3', 'Chemistry')],
      });
      expect((await courseRow('c2')).shortName, '');
      expect((await courseRow('c3')).name, 'Chemistry');
      // and in an automatic backup taken before the update.
      final snapshot = await repo.exportRows(includeDeleted: true);
      await repo.saveCourse(
        const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Renamed'),
        meetings: const [lecture],
        requirements: const [],
      );
      await repo.restoreAll({
        ...snapshot,
        'courses': [
          for (final c in snapshot['courses']!) {...c}..remove('shortName'),
        ],
      });
      expect((await courseRow('c1')).name, 'Calculus');
    });

    test('a short name syncs like any other field', () async {
      await repo.saveCourse(
        const CourseInfo(
          id: 'c1',
          semesterId: 'sem',
          name: 'Calculus',
          lecturer: 'Dr. Cohen',
          shortName: 'Calc',
        ),
        meetings: const [lecture],
        requirements: const [],
        base: CourseBase(
          course: course,
          meetings: const [lecture],
          requirements: const [],
        ),
      );
      expect(
        [for (final e in await outbox()) jsonDecode(e.patch)],
        [
          {'shortName': 'Calc'},
        ],
      );
    });

    test('the editor keeps a short name set on another device', () async {
      final base = CourseBase(
        course: course,
        meetings: const [lecture],
        requirements: const [],
      );
      await SyncEngine.applyServerRows(db, repo, [
        {
          'tbl': 'courses',
          'id': 'c1',
          'data': {...(await courseRow('c1')).toJson(), 'shortName': 'Calc'},
        },
      ], cursor: null);
      await repo.saveCourse(
        const CourseInfo(
          id: 'c1',
          semesterId: 'sem',
          name: 'Calculus 1',
          lecturer: 'Dr. Cohen',
        ),
        meetings: const [lecture],
        requirements: const [],
        base: base,
      );
      final row = await courseRow('c1');
      expect(row.name, 'Calculus 1');
      expect(row.shortName, 'Calc');
    });
  });

  test('buttons of test notifications change nothing', () async {
    NotificationResponse press(Map<String, Object?> payload) =>
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'attended',
          payload: jsonEncode({
            'kind': 'after',
            'meeting': 'm1',
            'date': '2026-10-18',
            ...payload,
          }),
        );
    expect(await markFromNotification(press({'test': true}), repo), isFalse);
    expect(await db.select(db.sessionOverrides).get(), isEmpty);
    // The same button on a real reminder marks the session.
    expect(await markFromNotification(press({}), repo), isTrue);
    expect(
      (await db.select(db.sessionOverrides).get()).single.status,
      'attended',
    );
  });
}

Map<String, Object?> _row(DataClass row) => row.toJson()..remove('updatedAt');
