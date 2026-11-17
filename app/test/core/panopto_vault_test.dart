import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/recordings/panopto_api.dart';
import 'package:leccheck/core/recordings/panopto_connection.dart';
import 'package:leccheck/core/recordings/panopto_pairing.dart';
import 'package:leccheck/core/recordings/panopto_vault.dart';

import 'fake_panopto.dart';
import 'fake_vault.dart';

/// One of the user's devices: its own secure storage, the account's vault
/// and Panopto shared.
class _Device {
  _Device(this.vault, this.panopto, this.clock, {String userId = 'user-1'})
    : session = Session(token: FakeVault.token, userId: userId);

  final FakeVault vault;
  final FakePanopto panopto;
  final DateTime Function() clock;
  final storage = MemoryStorage();
  Session? session;

  late final connection = PanoptoConnection(
    lock: MemoryLock(),
    vault: VaultClient(
      session: () async => session,
      client: vault.client,
      base: Uri.parse('https://sync.test'),
    ),
    storage: storage,
    client: panopto.client,
    browser: panopto.browser,
    clock: clock,
    redirectUrl: 'https://sync.test/v1/panopto/done',
    networkRetry: Duration.zero,
    leaseRetry: const Duration(milliseconds: 1),
  );

  /// The key, as pairing would hand it over from [other].
  Future<void> pairWith(_Device other) async {
    final raw = other.storage.values['leccheck.panopto.key']!;
    final json = (jsonDecode(utf8.decode(base64Url.decode(raw))) as Map)
        .cast<String, Object?>();
    await connection.useKey(VaultKey.fromJson(json));
  }
}

void main() {
  late FakeVault vault;
  late FakePanopto panopto;
  late DateTime now;
  late _Device phone;
  late _Device laptop;

  setUp(() {
    vault = FakeVault();
    panopto = FakePanopto();
    now = DateTime(2026, 11, 17, 9);
    vault.clock = () => now;
    phone = _Device(vault, panopto, () => now);
    laptop = _Device(vault, panopto, () => now);
  });

  int tokenRequests() => panopto.requests
      .where((r) => r.url.path.endsWith('/connect/token'))
      .length;

  group('setting up while signed in', () {
    test('puts the setup in the vault, encrypted, and nothing else on the '
        'device', () async {
      await phone.connection.connect(FakePanopto.setup);
      expect(vault.vault!['v'], 1);
      expect(phone.storage.values.keys, ['leccheck.panopto.key']);
      // The server can't read the secret or the tokens.
      final stored = jsonEncode(vault.vault);
      expect(stored, isNot(contains(FakePanopto.clientSecret)));
      expect(stored, isNot(contains('refresh-1')));
      expect(stored, isNot(contains(FakePanopto.clientId)));
      final info = await phone.connection.info();
      expect(info.status, PanoptoStatus.connected);
      expect(info.shared, isTrue);
      expect(info.site, FakePanopto.site);
    });

    test('another device sees it, and uses it once paired: no setup, no '
        'browser', () async {
      await phone.connection.connect(FakePanopto.setup);
      final before = await laptop.connection.info();
      expect(before.status, PanoptoStatus.elsewhere);
      expect(before.device, isNotEmpty);

      await laptop.pairWith(phone);
      expect((await laptop.connection.info()).status, PanoptoStatus.connected);
      final browserSignIns = panopto.requests
          .where((r) => r.bodyFields['grant_type'] == 'authorization_code')
          .length;
      expect(await laptop.connection.accessToken(), 'access-1');
      expect(
        panopto.requests
            .where((r) => r.bodyFields['grant_type'] == 'authorization_code')
            .length,
        browserSignIns,
      );
      expect(
        await (await laptop.connection.api())!.searchFolders('80430'),
        hasLength(1),
      );
    });

    test('without a sign-in, it stays on the device as before', () async {
      phone.session = null;
      await phone.connection.connect(FakePanopto.setup);
      expect(vault.vault, isNull);
      expect(phone.storage.values.keys, ['leccheck.panopto']);
      expect((await phone.connection.info()).shared, isFalse);
    });

    test('with no answer from the server, it stays on the device and moves '
        'into the vault later', () async {
      vault.offline = true;
      await phone.connection.connect(FakePanopto.setup);
      expect(phone.storage.values.keys, ['leccheck.panopto']);
      vault.offline = false;
      // Checked at most every 10 minutes.
      now = now.add(const Duration(minutes: 11));
      expect(await phone.connection.accessToken(), 'access-1');
      expect(vault.vault, isNotNull);
      expect(phone.storage.values.keys, ['leccheck.panopto.key']);
    });

    test('a key for another account is never used', () async {
      await phone.connection.connect(FakePanopto.setup);
      phone.session = const Session(token: FakeVault.token, userId: 'user-2');
      expect(await phone.connection.status(), PanoptoStatus.off);
    });
  });

  group('one sign-in for every device', () {
    setUp(() async {
      await phone.connection.connect(FakePanopto.setup);
      await laptop.pairWith(phone);
    });

    test('a refresh on one device is used by the other', () async {
      now = now.add(const Duration(minutes: 59, seconds: 30));
      expect(await phone.connection.accessToken(), 'access-2');
      final requests = tokenRequests();
      // The laptop gets the new access token without refreshing.
      expect(await laptop.connection.accessToken(), 'access-2');
      expect(tokenRequests(), requests);
      // And refreshes with the rotated refresh token when it's its turn.
      now = now.add(const Duration(minutes: 59, seconds: 30));
      expect(await laptop.connection.accessToken(), 'access-3');
      expect(await phone.connection.accessToken(), 'access-3');
      expect(vault.vault!['refused'], isFalse);
    });

    test('the API refusing a token another device already replaced: no '
        'second refresh', () async {
      expect(await phone.connection.accessToken(), 'access-1');
      expect(await laptop.connection.accessToken(), 'access-1');
      expect(await phone.connection.accessToken(refresh: true), 'access-2');
      final requests = tokenRequests();
      // The laptop's access-1 was refused: access-2 is in the vault.
      expect(await laptop.connection.accessToken(refresh: true), 'access-2');
      expect(tokenRequests(), requests);
    });

    test('waits while another device holds the lease', () async {
      vault
        ..leaseOwner = 'someone'
        ..leaseUntil = now.add(const Duration(seconds: 30));
      final waiting = phone.connection.accessToken(refresh: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(tokenRequests(), 1); // Only the first sign-in.
      vault.leaseUntil = DateTime(2000);
      expect(await waiting, 'access-2');
    });

    test('a refreshed sign-in that didn\'t reach the vault is sent later, '
        'and heals a device that was refused meanwhile', () async {
      vault.dropPuts = true;
      expect(await phone.connection.accessToken(refresh: true), 'access-2');
      expect(phone.storage.values, contains('leccheck.panopto.pending'));
      expect(vault.vault!['v'], 1);
      vault.dropPuts = false;

      // The laptop tries the old token: Panopto refuses it.
      await expectLater(
        laptop.connection.accessToken(refresh: true),
        throwsA(
          isA<PanoptoException>().having((e) => e.code, 'code', 'reconnect'),
        ),
      );
      expect((await laptop.connection.info()).status, PanoptoStatus.reconnect);

      // The phone sends what it kept: everyone is fine again.
      expect(await phone.connection.accessToken(), 'access-2');
      expect(phone.storage.values, isNot(contains('leccheck.panopto.pending')));
      expect(vault.vault!['refused'], isFalse);
      expect((await laptop.connection.info()).status, PanoptoStatus.connected);
      expect(await laptop.connection.accessToken(), 'access-2');
    });

    test('a refused sign-in: every device says connect again, and connecting '
        'on one fixes it for all', () async {
      panopto
        ..refreshToken = 'revoked'
        ..expireAccess();
      await expectLater(
        phone.connection.accessToken(refresh: true),
        throwsA(
          isA<PanoptoException>().having((e) => e.needsReconnect, 'r', true),
        ),
      );
      expect((await laptop.connection.info()).status, PanoptoStatus.reconnect);

      final setup = await laptop.connection.setup();
      expect(setup!.clientSecret, FakePanopto.clientSecret);
      await laptop.connection.connect(setup);
      // Same key: the phone needn't pair again.
      expect((await phone.connection.info()).status, PanoptoStatus.connected);
      expect(await phone.connection.accessToken(), panopto.accessToken);
    });

    test('disconnecting only this device leaves the others', () async {
      await laptop.connection.disconnect();
      expect(panopto.revoked, isEmpty);
      expect((await laptop.connection.info()).status, PanoptoStatus.elsewhere);
      expect((await phone.connection.info()).status, PanoptoStatus.connected);
    });

    test('disconnecting everywhere revokes the sign-in and stops every '
        'device', () async {
      await laptop.connection.disconnect(everywhere: true);
      expect(panopto.revoked, ['refresh-1']);
      expect(vault.vault, isNull);
      expect((await phone.connection.info()).status, PanoptoStatus.off);
      expect(phone.storage.values, isEmpty);
    });

    test('disconnecting everywhere needs the server', () async {
      vault.offline = true;
      await expectLater(
        laptop.connection.disconnect(everywhere: true),
        throwsA(isA<PanoptoException>()),
      );
      vault.offline = false;
      expect(vault.vault, isNotNull);
    });

    test('looks count for the whole account', () async {
      expect((await phone.connection.claimLook(force: false))!.ok, isTrue);
      expect((await laptop.connection.claimLook(force: false))!.ok, isFalse);
      expect((await laptop.connection.claimLook(force: true))!.ok, isTrue);
      now = now.add(const Duration(hours: 3, minutes: 1));
      final claim = (await phone.connection.claimLook(force: false))!;
      expect(claim.ok, isTrue);
      // A look that failed gives it back.
      await claim.cancel();
      expect((await laptop.connection.claimLook(force: false))!.ok, isTrue);
    });

    test('offline, Settings still shows the connection', () async {
      vault.offline = true;
      final info = await laptop.connection.info();
      expect(info.status, PanoptoStatus.connected);
      expect(info.site, FakePanopto.site);
    });
  });

  group('a device connected before the vault', () {
    setUp(() async {
      // Beta.20: connected on the device itself.
      phone.session = null;
      await phone.connection.connect(FakePanopto.setup);
      phone.session = laptop.session;
    });

    test('moves its connection into the vault by itself', () async {
      final info = await phone.connection.info();
      expect(info.shared, isTrue);
      expect(vault.vault, isNotNull);
      expect(phone.storage.values.keys, ['leccheck.panopto.key']);
      // The same sign-in: nothing to do in the browser.
      expect(await phone.connection.accessToken(), 'access-1');
      expect(panopto.revoked, isEmpty);
    });

    test('keeps working on its own when the account already has a vault, '
        'until it\'s paired', () async {
      final other = _Device(vault, panopto, () => now);
      await other.connection.connect(FakePanopto.setup);
      final info = await phone.connection.info();
      expect(info.status, PanoptoStatus.connected);
      expect(info.shared, isFalse);
      expect(info.sharedElsewhere, isNotNull);

      await phone.pairWith(other);
      final after = await phone.connection.info();
      expect(after.shared, isTrue);
      expect(after.sharedElsewhere, isNull);
      // Its own sign-in was cancelled at Panopto.
      expect(panopto.revoked, ['refresh-1']);
    });
  });

  group('pairing', () {
    late PairingResponder responder;

    setUp(() async {
      await phone.connection.connect(FakePanopto.setup);
      responder = PairingResponder();
    });

    Future<List<PairingPrompt>> phoneChecks() =>
        responder.check(phone.connection.vaultClient!);

    test(
      'both devices show the same code, and Allow hands the key over',
      () async {
        final request = await PairingRequest.start(
          laptop.connection.vaultClient!,
        );
        expect(await request.poll('user-1'), isA<PairingWaiting>());
        // The phone answers by itself; nothing to ask yet.
        expect(await phoneChecks(), isEmpty);
        final shown = await request.poll('user-1');
        expect(shown, isA<PairingCode>());
        final prompts = await phoneChecks();
        expect(prompts, hasLength(1));
        expect(prompts.single.code, (shown as PairingCode).code);
        expect(prompts.single.device, isNotEmpty);
        // Asked about once.
        expect(await phoneChecks(), isEmpty);

        await responder.allow(
          phone.connection.vaultClient!,
          prompts.single,
          (await phone.connection.heldKey())!,
        );
        final done = await request.poll('user-1');
        expect(done, isA<PairingDone>());
        await laptop.connection.useKey((done as PairingDone).key);
        expect(
          (await laptop.connection.info()).status,
          PanoptoStatus.connected,
        );
        expect(await laptop.connection.accessToken(), 'access-1');
        // The request is gone, and the vault key never passed in the clear.
        expect(vault.pairs, isEmpty);
        final key = base64Url.encode((await phone.connection.heldKey())!.bytes);
        expect(vault.requests.map((r) => r.body).join(), isNot(contains(key)));
      },
    );

    test('Deny', () async {
      final request = await PairingRequest.start(
        laptop.connection.vaultClient!,
      );
      await phoneChecks();
      await request.poll('user-1');
      final prompt = (await phoneChecks()).single;
      await responder.deny(phone.connection.vaultClient!, prompt.id);
      expect(await request.poll('user-1'), isA<PairingDenied>());
    });

    test(
      'a key that doesn\'t match its commit is denied without asking',
      () async {
        final request = await PairingRequest.start(
          laptop.connection.vaultClient!,
        );
        await phoneChecks();
        await request.poll('user-1');
        // The server swaps in its own key after the commit.
        final (_, pub) = await PairingCrypto.keyPair();
        vault.pairs.values.single['bPub'] = pub;
        expect(await phoneChecks(), isEmpty);
        expect(vault.pairs.values.single['denied'], isTrue);
      },
    );

    test('a server that answers with its own key shows another code', () async {
      final request = await PairingRequest.start(
        laptop.connection.vaultClient!,
      );
      // The server answers instead of the phone...
      final (_, evil) = await PairingCrypto.keyPair();
      vault.pairs.values.single['aPub'] = evil;
      final onLaptop = (await request.poll('user-1')) as PairingCode;
      // ...and can't answer the phone with the laptop's key: the phone
      // sees a request already answered and never prompts.
      expect(await phoneChecks(), isEmpty);
      final id = vault.pairs.keys.single;
      final pair = vault.pairs[id]!;
      expect(
        onLaptop.code,
        PairingCrypto.code(
          id,
          evil,
          pair['bPub']! as String,
          pair['nonce']! as String,
        ),
      );
    });

    test('a request ends after 10 minutes', () async {
      final request = await PairingRequest.start(
        laptop.connection.vaultClient!,
      );
      now = now.add(const Duration(minutes: 11));
      expect(await request.poll('user-1'), isA<PairingGone>());
    });

    test('needs a vault', () async {
      await phone.connection.disconnect(everywhere: true);
      await expectLater(
        PairingRequest.start(laptop.connection.vaultClient!),
        throwsA(isA<PanoptoException>()),
      );
    });
  });
}
