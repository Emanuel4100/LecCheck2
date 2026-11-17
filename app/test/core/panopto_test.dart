import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/recordings/panopto_api.dart';
import 'package:leccheck/core/recordings/panopto_connection.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/recording_match.dart';

import 'fake_panopto.dart';

void main() {
  late FakePanopto panopto;
  late DateTime now;

  PanoptoConnection connection() => PanoptoConnection(
    lock: MemoryLock(),
    client: panopto.client,
    browser: panopto.browser,
    clock: () => now,
    redirectUrl: 'https://sync.example/v1/panopto/done',
    networkRetry: Duration.zero,
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    panopto = FakePanopto();
    now = DateTime(2026, 11, 16, 20);
  });

  group('connecting', () {
    test('signs in and keeps the tokens on the device', () async {
      final c = connection();
      expect(await c.status(), PanoptoStatus.off);
      await c.connect(FakePanopto.setup);
      expect(await c.status(), PanoptoStatus.connected);
      final state = (await c.load())!;
      expect(state.refreshToken, panopto.refreshToken);
      expect(state.setup.clientSecret, FakePanopto.clientSecret);

      final exchange = panopto.requests.single;
      expect(exchange.bodyFields['grant_type'], 'authorization_code');
      expect(
        exchange.bodyFields['redirect_uri'],
        'https://sync.example/v1/panopto/done',
      );
      expect(exchange.bodyFields['code_verifier'], hasLength(64));
    });

    test('the secret goes as it is, not URL-encoded', () async {
      // FakePanopto refuses anything but the raw secret, like HUJI's site.
      await connection().connect(FakePanopto.setup);
      final header = panopto.requests.single.headers['Authorization']!;
      expect(header, isNot(contains('%2F')));
    });

    test('a wrong secret is a client error', () async {
      final wrong = PanoptoSetup(
        site: FakePanopto.site,
        clientId: FakePanopto.clientId,
        clientSecret: 'nope',
      );
      await expectLater(
        connection().connect(wrong),
        throwsA(
          isA<PanoptoException>().having((e) => e.code, 'code', 'client'),
        ),
      );
      expect(await connection().status(), PanoptoStatus.off);
    });

    test('the state tells the server page where to send the browser', () async {
      Uri? opened;
      final c = PanoptoConnection(
        lock: MemoryLock(),
        client: panopto.client,
        browser: (url, scheme) {
          opened = url;
          return panopto.browser(url, scheme);
        },
        redirectUrl: 'https://sync.example/v1/panopto/done',
      );
      await c.connect(FakePanopto.setup);
      final q = opened!.queryParameters;
      expect(q['state'], matches(RegExp(r'^[\w\-.~]{24}\.[dm]$')));
      expect(q['scope'], 'openid api offline_access');
      expect(q['code_challenge_method'], 'S256');
    });
  });

  group('tokens', () {
    test('an expired access token is refreshed, and the new refresh token '
        'saved', () async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      expect(await c.accessToken(), 'access-1');
      now = now.add(const Duration(minutes: 59, seconds: 30));
      expect(await c.accessToken(), 'access-2');
      expect((await c.load())!.refreshToken, 'refresh-2');
      // Panopto took the old one back: only the saved one works.
      expect(panopto.refreshToken, 'refresh-2');
    });

    test('a refused refresh token means connect again', () async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      panopto.refreshToken = 'revoked';
      await expectLater(
        c.accessToken(refresh: true),
        throwsA(
          isA<PanoptoException>().having(
            (e) => e.needsReconnect,
            'reconnect',
            true,
          ),
        ),
      );
      expect(await c.status(), PanoptoStatus.reconnect);
      // The setup stays for connecting again.
      expect((await c.load())!.setup.clientId, FakePanopto.clientId);
    });

    test('refreshes wait for each other', () async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      final tokens = await [
        c.accessToken(refresh: true),
        c.accessToken(refresh: true),
      ].wait;
      // Both refreshes used the token saved by the one before.
      expect(tokens, ['access-2', 'access-3']);
      expect(await c.status(), PanoptoStatus.connected);
    });

    test(
      'the API refused the token: one refresh, then the call again',
      () async {
        final c = connection();
        await c.connect(FakePanopto.setup);
        panopto.expireAccess();
        final api = (await c.api())!;
        final folders = await api.searchFolders('80430');
        expect(folders, hasLength(1));
        expect(
          [
            for (final r in panopto.apiRequests.take(2))
              r.headers['Authorization'],
          ],
          ['Bearer access-1', 'Bearer access-2'],
        );
      },
    );

    test(
      'a refused token that was replaced meanwhile isn\'t forgotten',
      () async {
        // Another isolate refreshed while this one's request was on its way:
        // Panopto refuses the old token, but the saved one still works.
        final storage = _SwapOnRefresh(panopto);
        final c = PanoptoConnection(
          lock: MemoryLock(),
          storage: storage,
          client: panopto.client,
          browser: panopto.browser,
          clock: () => now,
          redirectUrl: 'https://sync.example/v1/panopto/done',
        );
        await c.connect(FakePanopto.setup);
        storage.swap = true;
        await expectLater(
          c.accessToken(refresh: true),
          throwsA(
            isA<PanoptoException>().having((e) => e.code, 'code', 'network'),
          ),
        );
        expect(await c.status(), PanoptoStatus.connected);
        expect((await c.load())!.refreshToken, 'elsewhere');
      },
    );

    test('no connection for a moment: the API is read again', () async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      panopto.apiOffline = 1;
      expect(await (await c.api())!.searchFolders('80430'), hasLength(1));
      // No refresh for a network error.
      expect(
        panopto.requests.where((r) => r.url.path.endsWith('/token')),
        hasLength(1),
      );
    });

    test('still no connection: a network error', () async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      panopto.apiOffline = 2;
      await expectLater(
        (await c.api())!.searchFolders('80430'),
        throwsA(
          isA<PanoptoException>()
              .having((e) => e.code, 'code', 'network')
              .having((e) => e.isPassing, 'passing', true),
        ),
      );
      expect(await c.status(), PanoptoStatus.connected);
    });

    test('disconnecting revokes the refresh token and forgets it', () async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      await c.disconnect();
      expect(panopto.revoked, ['refresh-1']);
      expect(await c.status(), PanoptoStatus.off);
    });
  });

  group('the database lock', () {
    test('runs one body at a time, also from separate lock objects', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var inside = 0;
      var most = 0;
      Future<void> body() async {
        inside++;
        most = most < inside ? inside : most;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        inside--;
      }

      await [
        DbRefreshLock(db).run(body),
        DbRefreshLock(db).run(body),
        DbRefreshLock(db).run(body),
      ].wait;
      expect(most, 1);
      // Released: nothing left in sync_meta.
      expect(await db.select(db.syncMeta).get(), isEmpty);
    });

    test('a lease left by a stopped isolate expires', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final old = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch;
      await db
          .into(db.syncMeta)
          .insert(
            SyncMetaCompanion.insert(
              key: 'panopto.refreshLock',
              value: '$old:gone',
            ),
          );
      expect(await DbRefreshLock(db).run(() async => 'ran'), 'ran');
    });

    test('a lease that\'s still held is never ignored', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // Held for good by another isolate (renewed every time it's read).
      Future<void> hold() => db
          .into(db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion.insert(
              key: 'panopto.refreshLock',
              value: '${DateTime.now().millisecondsSinceEpoch + 3600000}:other',
            ),
          );
      await hold();
      var ran = false;
      await expectLater(
        DbRefreshLock(
          db,
          giveUpAfter: const Duration(milliseconds: 600),
        ).run(() async => ran = true),
        throwsA(isA<PanoptoException>()),
      );
      expect(ran, isFalse);
      // The other isolate's lease stays.
      expect(await db.select(db.syncMeta).get(), hasLength(1));
    });
  });

  group('reading the API', () {
    late PanoptoApi api;

    setUp(() async {
      final c = connection();
      await c.connect(FakePanopto.setup);
      api = (await c.api())!;
    });

    test('folder names are cleaned up', () async {
      expect(await api.searchFolders('80430'), [
        const PanoptoFolderRef(
          id: FakePanopto.folderId,
          name: '2026-27 -> 80430_1-מבוא להסתברות ולסטטיסטיקה',
        ),
      ]);
    });

    test('a folder is read page by page until an empty one', () async {
      final all = await api.folderRecordings(FakePanopto.folderId);
      expect(all, hasLength(58));
      expect(panopto.apiRequests, hasLength(3));
    });

    test(
      'reading stops at a page that is all older than the semester',
      () async {
        final recent = await api.folderRecordings(
          FakePanopto.folderId,
          since: const LocalDate(2026, 11, 1),
        );
        expect(
          recent.every(
            (r) => !r.wallStart.date.isBefore(const LocalDate(2026, 11, 1)),
          ),
          isTrue,
        );
        // Page 1 was all older: page 2 isn't asked for.
        expect(panopto.apiRequests, hasLength(2));
      },
    );
  });

  group('parsing', () {
    test('Moodle language tags and HTML entities', () {
      expect(
        PanoptoApi.cleanName(
          '2025-26 -&gt; 80177-{mlang he}חשבון אינפיניטסימלי{mlang}{mlang en}Calculus{mlang}',
        ),
        '2025-26 -> 80177-חשבון אינפיניטסימלי',
      );
      expect(
        PanoptoApi.cleanName(
          '{mlang he}חשמל{mlang}{mlang en}Electricity{mlang}',
          language: 'en',
        ),
        'Electricity',
      );
    });

    test('start times: wall clock and real time', () {
      const text = '2026-11-16T12:00:01.1017824Z';
      expect(PanoptoApi.wallClock(text), (
        date: const LocalDate(2026, 11, 16),
        minute: 12 * 60,
      ));
      // TZ=Asia/Jerusalem (see CLAUDE.md): UTC+2 in November.
      expect(PanoptoApi.realTime(text), (
        date: const LocalDate(2026, 11, 16),
        minute: 14 * 60,
      ));
      expect(PanoptoApi.realTime('2026-11-16T12:00:00'), isNull);
    });

    test('status: the API sends numbers', () {
      expect(PanoptoApi.isComplete(4), isTrue);
      expect(PanoptoApi.isComplete('Complete'), isTrue);
      expect(PanoptoApi.isComplete(2), isFalse); // Recording
      expect(PanoptoApi.isComplete(3), isFalse); // Processing
    });
  });
}

/// Secure storage where, during the next refresh, another isolate saves a
/// newer token (and Panopto has already taken back the one being used).
class _SwapOnRefresh extends FlutterSecureStorage {
  _SwapOnRefresh(this.panopto);

  final FakePanopto panopto;
  bool swap = false;
  String? _value;

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
    final value = _value;
    if (swap && value != null) {
      // The first read (inside the lock) gets the old token; then the
      // other isolate's refresh lands.
      swap = false;
      final state = PanoptoState.fromJson(
        (jsonDecode(utf8.decode(base64Url.decode(value))) as Map)
            .cast<String, Object?>(),
      );
      panopto.refreshToken = 'elsewhere';
      _value = base64Url.encode(
        utf8.encode(
          jsonEncode(
            PanoptoState(
              setup: state.setup,
              refreshToken: 'elsewhere',
            ).toJson(),
          ),
        ),
      );
    }
    return value;
  }

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
  }) async => _value = value;
}
