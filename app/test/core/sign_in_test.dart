import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/core/auth/auth_service.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/backup/snapshot_service.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Signs in without a browser or server, with a fixed account summary.
class _FakeAuth extends AuthService {
  AccountSummary? summary;
  int restored = 0;
  int cleared = 0;

  @override
  Future<Session> signInDev(String name) async =>
      const Session(token: 't', userId: 'u1');

  @override
  Future<AccountSummary?> accountSummary(Session session) async => summary;

  @override
  Future<int> restoreDeleted(Session session) async => ++restored;

  @override
  Future<Session?> load() async => null;

  @override
  Future<void> save(Session session) async {}

  @override
  Future<void> clear(String reason) async => cleared++;
}

SemesterInfo _semester(String id, String start, String end) => SemesterInfo(
  id: id,
  name: 'Semester $id',
  start: LocalDate.parse(start),
  end: LocalDate.parse(end),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late _FakeAuth auth;
  late AppDatabase db;
  late ScheduleRepository repo;
  late Directory snapshots;
  late ProviderContainer c;
  // The first sync: the test decides when it ends and what it brought.
  late Completer<bool> firstSync;
  final asked = <(int, int)>[];
  JoinChoice? answer;
  var restoreAnswer = false;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    auth = _FakeAuth();
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    snapshots = await Directory.systemTemp.createTemp('sign_in_test');
    firstSync = Completer();
    asked.clear();
    answer = null;
    restoreAnswer = false;
    c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        syncConfiguredProvider.overrideWithValue(true),
        authServiceProvider.overrideWithValue(auth),
        syncEngineProvider.overrideWithValue(null),
        snapshotServiceProvider.overrideWithValue(
          SnapshotService(repo, () async => snapshots),
        ),
        firstSyncProvider.overrideWithValue((_) => firstSync.future),
      ],
    );
    await c.read(authProvider.future);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    await snapshots.delete(recursive: true);
  });

  Future<SignInResult> signIn() => c
      .read(authProvider.notifier)
      .signIn(
        devName: 'dev',
        confirmReplace: () async => true,
        chooseJoin: (account, local) async {
          asked.add((account.semesters, local));
          return answer;
        },
        offerRestore: (_) async => restoreAnswer,
      );

  Future<int> outbox() async => (await db.select(db.outbox).get()).length;

  /// Ends the first sync, after it brought [semesters].
  Future<void> sync([List<SemesterInfo> semesters = const []]) async {
    for (final s in semesters) {
      await repo.saveSemester(s);
    }
    firstSync.complete(true);
    await pumpEventQueue();
  }

  test('a new account on an empty device sets up a semester', () async {
    auth.summary = const AccountSummary(semesters: 0, courses: 0);
    expect(await signIn(), SignInResult.newAccount);
    expect(c.read(attachedAccountProvider), 'u1');
    expect(c.read(restoreProvider), RestorePhase.idle);
    await sync();
    expect(c.read(semesterChoiceProvider), isFalse);
  });

  test(
    'an account with data: waits for it, then asks which semester',
    () async {
      auth.summary = const AccountSummary(semesters: 2, courses: 5);
      expect(await signIn(), SignInResult.restoring);
      // Welcome shows progress, never the setup form (issue #2).
      expect(c.read(restoreProvider), RestorePhase.waiting);

      final today = LocalDate.today();
      final running = _semester(
        'now',
        today.addDays(-10).toIso(),
        today.addDays(60).toIso(),
      );
      await sync([_semester('old', '2020-10-01', '2021-01-31'), running]);
      expect(c.read(restoreProvider), RestorePhase.idle);
      expect(c.read(semesterChoiceProvider), isTrue);
      expect(c.read(activeSemesterChoiceProvider), 'now');
    },
  );

  test('an account that turns out empty, or no sync in time', () async {
    // The server couldn't say (offline): wait, then decide.
    expect(await signIn(), SignInResult.restoring);
    await sync();
    expect(c.read(restoreProvider), RestorePhase.empty);
    expect(c.read(semesterChoiceProvider), isFalse);

    c.read(restoreProvider.notifier).wait();
    firstSync = Completer()..complete(false);
    await c.read(authProvider.notifier).retryRestore();
    expect(c.read(restoreProvider), RestorePhase.failed);
  });

  group('data made while signed out', () {
    setUp(() async {
      await repo.saveSemester(_semester('guest', '2026-10-25', '2027-01-29'));
      auth.summary = const AccountSummary(semesters: 3, courses: 9);
    });

    test(
      '"Use my account\'s" keeps a backup, then only the account\'s',
      () async {
        answer = JoinChoice.useAccount;
        expect(await signIn(), SignInResult.restoring);
        expect(asked, [(3, 1)]);
        expect(await repo.semesters(), isEmpty);
        expect(await outbox(), 0); // nothing of this device's is uploaded
        expect(snapshots.listSync().map((f) => f.path), [
          endsWith('-signin.json.gz'),
        ]);
        expect(c.read(attachedAccountProvider), 'u1');
      },
    );

    test('"Keep both" uploads this device\'s data too', () async {
      answer = JoinChoice.keepBoth;
      expect(await signIn(), SignInResult.joined);
      expect((await repo.semesters()).single.id, 'guest');
      expect(await outbox(), greaterThan(0));
    });

    test('Cancel signs out and changes nothing', () async {
      expect(await signIn(), SignInResult.cancelled);
      expect(auth.cleared, 1);
      expect(c.read(attachedAccountProvider), isNull);
      expect((await repo.semesters()).single.id, 'guest');
      expect(await outbox(), 0);
    });

    test(
      'an empty account, or one the server can\'t tell: no question',
      () async {
        auth.summary = const AccountSummary(semesters: 0, courses: 0);
        expect(await signIn(), SignInResult.joined);
        expect(asked, isEmpty);
        expect(await outbox(), greaterThan(0));
      },
    );

    test('unknown (offline): joins, as before, so nothing is lost', () async {
      auth.summary = null;
      expect(await signIn(), SignInResult.joined);
      expect(asked, isEmpty);
      expect(await outbox(), greaterThan(0));
    });
  });

  test('an account whose data was deleted offers to bring it back', () async {
    auth.summary = AccountSummary(
      semesters: 0,
      courses: 0,
      trashRows: 12,
      deletedAt: DateTime(2026, 10, 1),
    );
    restoreAnswer = true;
    expect(await signIn(), SignInResult.restoring);
    expect(auth.restored, 1);

    // "Start fresh": a new account, nothing brought back.
    restoreAnswer = false;
    c.read(attachedAccountProvider.notifier).detach();
    c.read(restoreProvider.notifier).reset();
    expect(await signIn(), SignInResult.newAccount);
    expect(auth.restored, 1);
  });
}
