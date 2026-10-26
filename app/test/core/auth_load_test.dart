import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/core/auth/auth_service.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A keyring that fails as often as told, then answers.
class _FlakyStorage extends FlutterSecureStorage {
  _FlakyStorage({this.failures = 0, this.value});

  int failures;
  String? value;
  int reads = 0;
  int deletes = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads++;
    if (failures > 0) {
      failures--;
      throw PlatformException(code: 'Libsecret error');
    }
    return value;
  }

  final writes = <String>[];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes.add(value!);
    this.value = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => deletes++;
}

/// Loads from [storage]; never renews (no server).
class _Auth extends AuthService {
  _Auth(FlutterSecureStorage storage) : super(storage: storage);

  @override
  Future<Session?> renewIfNeeded(Session session) async => session;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const saved = '{"token":"t","userId":"g:1"}';
  late SharedPreferencesWithCache prefs;
  late AppDatabase db;

  setUp(() async {
    AuthController.retryWaits = const [Duration.zero, Duration.zero];
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    // A device signed in before: it holds the account's data.
    await prefs.setString('sync.userId', 'g:1');
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  ProviderContainer container(_FlakyStorage storage) {
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        syncConfiguredProvider.overrideWithValue(true),
        authServiceProvider.overrideWithValue(_Auth(storage)),
        syncEngineProvider.overrideWithValue(null),
        firstSyncProvider.overrideWithValue((_) async => false),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a keyring that fails at first still signs in', () async {
    final storage = _FlakyStorage(failures: 2, value: saved);
    final session = await container(storage).read(authProvider.future);
    expect(session?.userId, 'g:1');
    expect(storage.reads, 3);
    expect(storage.deletes, 0);
  });

  test('one that keeps failing is an error, not a sign-out', () async {
    final storage = _FlakyStorage(failures: 99, value: saved);
    final c = container(storage);
    await expectLater(
      c.read(authProvider.future),
      throwsA(isA<SessionUnreadable>()),
    );
    expect(storage.reads, 3); // the first read and two more
    expect(storage.deletes, 0);

    // Retry, once the keyring answers.
    storage.failures = 0;
    c.invalidate(authProvider);
    expect((await c.read(authProvider.future))?.userId, 'g:1');
  });

  test('a missing sign-in on a device that holds an account is read '
      'twice', () async {
    final storage = _FlakyStorage();
    expect(await container(storage).read(authProvider.future), isNull);
    expect(storage.reads, 2);

    // A guest device reads once.
    await prefs.remove('sync.userId');
    final guest = _FlakyStorage();
    expect(await container(guest).read(authProvider.future), isNull);
    expect(guest.reads, 1);
  });

  group('a sign-in saved without this device\'s data', () {
    // The data folder is new or was removed, and the keyring kept the
    // sign-in: the Flatpak finds the one of the version it replaced.
    setUp(() => prefs.remove('sync.userId'));

    test('an empty device restores the account', () async {
      final storage = _FlakyStorage(value: saved);
      final c = container(storage);
      expect((await c.read(authProvider.future))?.userId, 'g:1');
      expect(c.read(attachedAccountProvider), 'g:1');
      expect(c.read(restoreProvider), RestorePhase.waiting);
      // Then the first sync (none here: no server) decides.
      await pumpEventQueue();
      expect(c.read(restoreProvider), RestorePhase.failed);
    });

    test('a device with data of its own stays signed out', () async {
      await ScheduleRepository(db).saveSemester(
        SemesterInfo(
          id: 's1',
          name: 'Guest semester',
          start: LocalDate.parse('2026-10-18'),
          end: LocalDate.parse('2027-01-15'),
        ),
      );
      final storage = _FlakyStorage(value: saved);
      final c = container(storage);
      expect(await c.read(authProvider.future), isNull);
      expect(c.read(attachedAccountProvider), isNull);
      // Kept: signing in replaces it.
      expect(storage.deletes, 0);
    });
  });

  test(
    'saved without backslashes; old plain JSON is read and re-saved',
    () async {
      // GNOME Keyring without a password emptied secrets with a backslash
      // when it re-read its file, and a JSON session nested in the plugin's
      // JSON is full of them.
      final storage = _FlakyStorage(value: saved);
      final auth = _Auth(storage);
      final session = await auth.load();
      expect(session?.userId, 'g:1');
      expect(storage.writes, hasLength(1));
      expect(storage.value, isNot(contains('{')));
      expect(
        jsonEncode({'leccheck.session': storage.value}),
        isNot(contains(r'\')),
      );

      // The new form reads back, and isn't saved again.
      expect((await auth.load())?.userId, 'g:1');
      expect(storage.writes, hasLength(1));

      // Nothing usable: no session (an emptied entry reads as "").
      storage.value = '';
      expect(await auth.load(), isNull);
    },
  );

  test('a local test server keeps its own sign-in', () {
    expect(
      AuthService.storageKey('https://leccheck-sync.example.workers.dev'),
      'leccheck.session',
    );
    expect(AuthService.storageKey(''), 'leccheck.session');
    expect(
      AuthService.storageKey('http://localhost:8787'),
      'leccheck.session@localhost:8787',
    );
  });
}
