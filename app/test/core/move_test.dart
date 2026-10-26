import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/move_controller.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/backup/backup_service.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/update/tarball_install.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Signed in as [session] (or not), without a keyring.
class _Auth extends AuthController {
  _Auth(this.session);

  final Session? session;

  @override
  Future<Session?> build() async => session;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SharedPreferencesWithCache prefs;
  late AppDatabase db;
  late List<String> calls;
  late List<String> started;
  String? flatpak;
  var installed = false;
  ProcessException? installFails;
  String? savedTo;
  List<int>? savedBytes;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    db = AppDatabase(NativeDatabase.memory());
    calls = [];
    started = [];
    flatpak = 'Flatpak 1.18.4';
    installed = false;
    installFails = null;
    savedTo = '/home/me/leccheck-backup-2026-10-26.json';
    savedBytes = null;
    MoveController.installDir = () async => '/fake/leccheck';
    MoveController.flatpakVersion = () async => flatpak;
    MoveController.flatpakInstalled = () async => installed;
    MoveController.installFlatpak = ({onOutput}) async {
      calls.add('install');
      onOutput?.call('Installing app/com.leccheck.app/x86_64/stable');
      if (installFails case final error?) throw error;
    };
    MoveController.uninstall = (dir) async => calls.add('uninstall $dir');
    MoveController.startAfterExit = (command) async => started.addAll(command);
    MoveController.saveFile = (name, bytes) async {
      calls.add('save $name');
      savedBytes = bytes;
      return savedTo;
    };
  });

  tearDown(() async {
    await db.close();
    MoveController.installDir = TarballInstall.installDir;
    MoveController.flatpakVersion = TarballInstall.flatpakVersion;
    MoveController.flatpakInstalled = TarballInstall.flatpakInstalled;
    MoveController.installFlatpak = TarballInstall.installFlatpak;
    MoveController.uninstall = TarballInstall.uninstall;
    MoveController.startAfterExit = TarballInstall.startAfterExit;
  });

  Future<ProviderContainer> container({
    Session? session,
    int pending = 0,
  }) async {
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        syncConfiguredProvider.overrideWithValue(true),
        authProvider.overrideWith(() => _Auth(session)),
        syncEngineProvider.overrideWithValue(null),
        outboxCountsProvider.overrideWith(
          (ref) => Stream.value((pending: pending, refused: 0)),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    await c.read(moveProvider.notifier).init();
    return c;
  }

  Future<void> someData() => ScheduleRepository(db).saveSemester(
    SemesterInfo(
      id: 's1',
      name: 'Semester A',
      start: LocalDate.parse('2026-10-18'),
      end: LocalDate.parse('2027-01-15'),
    ),
  );

  const session = Session(token: 't', userId: 'g:1');

  test('only installs made by install.sh move', () async {
    MoveController.installDir = () async => null;
    final c = await container();
    expect(c.read(moveProvider).offered, isFalse);
    expect(c.read(moveProvider.notifier).takePrompt(), isFalse);
  });

  test('a guest saves a backup; then it installs, removes and opens', () async {
    await someData();
    final c = await container();
    final move = c.read(moveProvider.notifier);
    expect(c.read(moveProvider).offered, isTrue);

    await move.start();
    expect(c.read(moveProvider).phase, MovePhase.backup);
    expect(calls, isEmpty, reason: 'waits for Save a backup…');

    await move.saveBackup();
    final state = c.read(moveProvider);
    expect(state.phase, MovePhase.ready);
    expect(state.backup, savedTo);
    expect(state.output, 'Installing app/com.leccheck.app/x86_64/stable');
    expect(calls, [
      'save leccheck-backup-${LocalDate.today().toIso()}.json',
      'install',
      'uninstall /fake/leccheck',
    ]);
    // The backup holds the semester, ready to import.
    final backup = BackupService.parse(utf8.decode(savedBytes!));
    expect(backup.semesters, 1);

    await move.open();
    expect(started, ['flatpak', 'run', 'com.leccheck.app']);
  });

  test('cancelling the save dialog keeps waiting for a backup', () async {
    await someData();
    savedTo = null;
    final c = await container();
    final move = c.read(moveProvider.notifier);
    await move.start();
    await move.saveBackup();
    expect(c.read(moveProvider).phase, MovePhase.backup);
    expect(calls.where((call) => call == 'install'), isEmpty);
  });

  test('signed in, everything synced: the account brings it back', () async {
    await someData();
    await prefs.setString('sync.userId', 'g:1');
    final c = await container(session: session);
    await c.read(moveProvider.notifier).start();
    expect(c.read(moveProvider).phase, MovePhase.ready);
    expect(c.read(moveProvider).synced, isTrue);
    expect(calls, ['install', 'uninstall /fake/leccheck']);
  });

  test('signed in with changes that can\'t sync now: a backup', () async {
    await someData();
    await prefs.setString('sync.userId', 'g:1');
    final c = await container(session: session, pending: 3);
    await c.read(moveProvider.notifier).start();
    expect(c.read(moveProvider).phase, MovePhase.backup);
    expect(c.read(moveProvider).synced, isFalse);
  });

  test('nothing to bring along: straight to installing', () async {
    final c = await container();
    await c.read(moveProvider.notifier).start();
    expect(c.read(moveProvider).empty, isTrue);
    expect(c.read(moveProvider).phase, MovePhase.ready);
    expect(calls, ['install', 'uninstall /fake/leccheck']);
  });

  test('without Flatpak it says so; Retry goes on from there', () async {
    flatpak = null;
    final c = await container();
    final move = c.read(moveProvider.notifier);
    await move.start();
    expect(c.read(moveProvider).phase, MovePhase.failed);
    expect(c.read(moveProvider).failure, MoveFailure.noFlatpak);
    expect(c.read(moveProvider).failedStep, MoveStep.install);

    flatpak = 'Flatpak 1.18.4';
    await move.start();
    expect(c.read(moveProvider).phase, MovePhase.ready);
  });

  test('a failed flatpak install shows its words; nothing removed', () async {
    installFails = const ProcessException(
      'flatpak',
      ['install'],
      'error: Unable to load summary from remote leccheck',
      1,
    );
    final c = await container();
    await c.read(moveProvider.notifier).start();
    final state = c.read(moveProvider);
    expect(state.failure, MoveFailure.install);
    expect(state.detail, contains('Unable to load summary'));
    expect(calls, ['install']);
  });

  test('already installed: not installed again', () async {
    installed = true;
    final c = await container();
    await c.read(moveProvider.notifier).start();
    expect(c.read(moveProvider).phase, MovePhase.ready);
    expect(calls, ['uninstall /fake/leccheck']);
  });

  test('the window opens by itself once per launch; Later is kept', () async {
    final c = await container();
    final move = c.read(moveProvider.notifier);
    expect(move.takePrompt(), isTrue);
    expect(move.takePrompt(), isFalse);
    await move.later();

    final next = await container();
    expect(next.read(moveProvider).later, isTrue);
    expect(next.read(moveProvider.notifier).takePrompt(), isTrue);
  });
}
