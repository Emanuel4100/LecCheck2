// End-to-end sync between two simulated devices and a real Worker.
//
//   cd server && npx wrangler dev --port 8787     (with DEV_AUTH=1 in .dev.vars)
//   cd app && flutter test test_sync --dart-define=API_BASE_URL=http://localhost:8787
//
// Kept out of test/ because it needs the local server running.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/sync/sync_config.dart';
import 'package:leccheck/core/sync/sync_engine.dart';
import 'package:leccheck/core/sync/sync_recorder.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class Device {
  Device._(this.db, this.repo, this.recorder);

  final AppDatabase db;
  final ScheduleRepository repo;
  final SyncRecorder recorder;
  SyncEngine? engine;

  static Future<Device> create(String node) async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await prefs.setString('sync.node', node);
    await prefs.remove('sync.hlc');
    final db = AppDatabase(NativeDatabase.memory());
    final repo = ScheduleRepository(db);
    final recorder = SyncRecorder(db: db, prefs: prefs);
    repo.recorder = recorder;
    return Device._(db, repo, recorder);
  }

  void connect(Session session) {
    engine = SyncEngine(
      db: db,
      repo: repo,
      recorder: recorder,
      session: session,
      watchLifecycle: false,
    )..start();
  }

  Future<void> disconnect() async {
    await engine?.dispose();
    engine = null;
  }
}

Future<Session> devLogin(String name) async {
  final client = HttpClient();
  final request = await client.postUrl(SyncConfig.api('/v1/auth/dev'));
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'name': name}));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  client.close();
  expect(response.statusCode, 200, reason: body);
  return Session.fromJson(jsonDecode(body) as Map<String, Object?>);
}

/// Polls until [check] passes (real time, up to 5 s).
Future<void> eventually(Future<bool> Function() check, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for: $what');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  setUpAll(() {
    if (!SyncConfig.enabled) {
      fail('Run with --dart-define=API_BASE_URL=http://localhost:8787');
    }
  });

  test('two devices sync live and merge concurrent field edits', () async {
    final user = 'e2e-${DateTime.now().microsecondsSinceEpoch}';
    final session = await devLogin(user);
    final phone = await Device.create('phone00000000001');
    final laptop = await Device.create('laptop0000000001');
    addTearDown(() async {
      await phone.disconnect();
      await laptop.disconnect();
      await phone.db.close();
      await laptop.db.close();
    });

    // The phone creates the semester and a course while connected.
    phone.connect(session);
    final semester = SemesterInfo(
      id: 'sem',
      name: 'Semester A',
      start: LocalDate.parse('2026-10-18'),
      end: LocalDate.parse('2027-01-22'),
    );
    const meeting = MeetingRule(
      id: 'm1',
      courseId: 'c1',
      type: SessionType.lecture,
      kind: MeetingKind.weekly,
      weekday: DateTime.sunday,
      startMin: 600,
      endMin: 720,
    );
    await phone.repo.saveSemester(semester);
    await phone.repo.saveCourse(
      const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Calculus'),
      meetings: const [meeting],
      requirements: const [],
    );
    await eventually(
      () async => (await phone.db.select(phone.db.outbox).get()).isEmpty,
      'phone outbox drained',
    );

    // The laptop signs in later and catches up.
    laptop.connect(session);
    await eventually(
      () async => (await laptop.repo.loadSemesterData('sem'))?.courses.length == 1,
      'laptop received the course',
    );
    final first = OccurrenceEngine.expand(
      semester: semester,
      meetings: [meeting],
    ).all.first;

    // Live: a mark on the phone shows up on the laptop.
    final stopwatch = Stopwatch()..start();
    await phone.repo.setStatus(first, AttendanceStatus.attended);
    await eventually(() async {
      final d = await laptop.repo.loadSemesterData('sem');
      return d?.overrides.firstOrNull?.status == AttendanceStatus.attended;
    }, 'laptop sees the mark');
    // ignore: avoid_print
    print('phone → laptop propagation: ${stopwatch.elapsedMilliseconds} ms');

    // Offline edits of different fields of the same session both survive.
    await laptop.disconnect();
    await laptop.repo.setSessionNotes(first, 'Limits, chapter 2');
    await phone.repo.setStatus(first, AttendanceStatus.watched);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    laptop.connect(session);

    Future<bool> merged(Device d) async {
      final o = (await d.repo.loadSemesterData('sem'))?.overrides.firstOrNull;
      return o?.status == AttendanceStatus.watched &&
          o?.notes == 'Limits, chapter 2';
    }

    await eventually(() => merged(laptop), 'laptop has both edits');
    await eventually(() => merged(phone), 'phone has both edits');
    await eventually(
      () async => (await laptop.db.select(laptop.db.outbox).get()).isEmpty,
      'laptop outbox drained',
    );
  });

  test('a deletion syncs and undo restores it everywhere', () async {
    final session = await devLogin('e2e-del-${DateTime.now().microsecondsSinceEpoch}');
    final a = await Device.create('deviceA000000001');
    final b = await Device.create('deviceB000000001');
    addTearDown(() async {
      await a.disconnect();
      await b.disconnect();
      await a.db.close();
      await b.db.close();
    });
    a.connect(session);
    b.connect(session);
    await a.repo.saveSemester(
      SemesterInfo(
        id: 'sem',
        name: 'S',
        start: LocalDate.parse('2026-10-18'),
        end: LocalDate.parse('2027-01-22'),
      ),
    );
    await a.repo.saveCourse(
      const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Physics'),
      meetings: const [],
      requirements: const [],
    );
    await eventually(
      () async => (await b.repo.loadSemesterData('sem'))?.courses.length == 1,
      'b has the course',
    );
    final receipt = await a.repo.deleteCourse('c1');
    await eventually(
      () async => (await b.repo.loadSemesterData('sem'))?.courses.isEmpty ?? false,
      'b sees the deletion',
    );
    await a.repo.undoDeletion(receipt);
    await eventually(
      () async => (await b.repo.loadSemesterData('sem'))?.courses.length == 1,
      'b sees the undo',
    );
  });
}
