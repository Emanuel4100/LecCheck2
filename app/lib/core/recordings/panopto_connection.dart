import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../db/app_database.dart';
import '../dev/dev_log.dart';
import '../sync/sync_config.dart';
import 'panopto_api.dart';
import 'panopto_vault.dart';

/// What the user copies from their Panopto API client, once.
class PanoptoSetup {
  const PanoptoSetup({
    required this.site,
    required this.clientId,
    required this.clientSecret,
  });

  factory PanoptoSetup.fromJson(Map<String, Object?> json) => PanoptoSetup(
    site: json['site'] as String? ?? '',
    clientId: json['clientId'] as String? ?? '',
    clientSecret: json['clientSecret'] as String? ?? '',
  );

  static const defaultSite = 'huji.cloud.panopto.eu';

  /// The Panopto host, e.g. `huji.cloud.panopto.eu`.
  final String site;
  final String clientId;
  final String clientSecret;

  Map<String, Object?> toJson() => {
    'site': site,
    'clientId': clientId,
    'clientSecret': clientSecret,
  };

  /// The host from whatever was typed: `https://x/Panopto/…` or `x`.
  static String siteFrom(String text) {
    final trimmed = text.trim();
    final uri = Uri.tryParse(
      trimmed.contains('://') ? trimmed : 'https://$trimmed',
    );
    return (uri?.host ?? '').toLowerCase();
  }
}

/// This device's Panopto connection, kept in secure storage. Never synced:
/// the refresh token opens the user's Panopto.
class PanoptoState {
  const PanoptoState({
    required this.setup,
    this.refreshToken,
    this.accessToken,
    this.accessExpiresAt = 0,
  });

  factory PanoptoState.fromJson(Map<String, Object?> json) => PanoptoState(
    setup: PanoptoSetup.fromJson(
      (json['setup'] as Map? ?? const {}).cast<String, Object?>(),
    ),
    refreshToken: json['refreshToken'] as String?,
    accessToken: json['accessToken'] as String?,
    accessExpiresAt: json['accessExpiresAt'] as int? ?? 0,
  );

  final PanoptoSetup setup;

  /// Null once Panopto refused it: the device must connect again.
  final String? refreshToken;
  final String? accessToken;

  /// Milliseconds since the epoch.
  final int accessExpiresAt;

  bool get connected => refreshToken != null;

  Map<String, Object?> toJson() => {
    'setup': setup.toJson(),
    'refreshToken': refreshToken,
    'accessToken': accessToken,
    'accessExpiresAt': accessExpiresAt,
  };
}

enum PanoptoStatus {
  /// Not set up on this device, nor in the account's vault.
  off,
  connected,

  /// Set up, but the sign-in expired or was refused: connect again.
  reconnect,

  /// Set up on another device of the account: pairing brings it here.
  elsewhere,
}

/// This device's Panopto connection, for Settings.
class PanoptoInfo {
  const PanoptoInfo(
    this.status, {
    this.site,
    this.device,
    this.shared = false,
    this.sharedElsewhere,
  });

  static const off = PanoptoInfo(PanoptoStatus.off);

  final PanoptoStatus status;
  final String? site;

  /// The device that saved the account's vault ([PanoptoStatus.elsewhere],
  /// or the one this device shares).
  final String? device;

  /// This device uses the account's vault.
  final bool shared;

  /// This device has its own connection, and the account's vault (from
  /// another device's setup) exists too: the device that saved it.
  final String? sharedElsewhere;
}

/// The account-wide look this device claimed (see
/// [PanoptoConnection.claimLook]).
class SharedLook {
  const SharedLook(this.at, this._cancel);

  /// When it was claimed (server time); null: a device looked in the last
  /// 3 hours.
  final int? at;
  final Future<void> Function()? _cancel;

  bool get ok => at != null;

  /// Gives the claim back (the look failed for a passing reason).
  Future<void> cancel() async => _cancel?.call();
}

/// Runs token refreshes one at a time, also across isolates (Android's
/// background task runs in the app's process, where file locks don't keep
/// isolates apart).
abstract interface class RefreshLock {
  Future<T> run<T>(Future<T> Function() body);
}

/// A 30-second lease in the local `sync_meta` table: drift serves every
/// isolate from one database isolate, so its transactions decide who holds
/// it.
class DbRefreshLock implements RefreshLock {
  DbRefreshLock(this.db, {Duration? giveUpAfter})
    : _giveUpAfter = giveUpAfter ?? _lease + const Duration(seconds: 5);

  final AppDatabase db;
  final Duration _giveUpAfter;
  static const _key = 'panopto.refreshLock';

  /// Longer than a token request can take (its timeout), so a slow refresh
  /// never loses the lease to another isolate that would refresh with the
  /// same, already used, token.
  static const _lease = Duration(seconds: 60);
  static Future<void> _tail = Future.value();

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    final previous = _tail;
    final mine = Completer<void>();
    _tail = mine.future;
    await previous;
    final owner = _randomString(12);
    try {
      final giveUp = DateTime.now().add(_giveUpAfter);
      while (!await _take(owner)) {
        // Never run without the lease: two refreshes with one token lose
        // the sign-in. Another try comes with the next look.
        if (!DateTime.now().isBefore(giveUp)) {
          throw const PanoptoException('network', 'refresh lock busy');
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return await body();
    } finally {
      try {
        await (db.delete(
          db.syncMeta,
        )..where((m) => m.key.equals(_key) & m.value.like('%:$owner'))).go();
      } on Object catch (e) {
        debugPrint('Panopto lock not released: $e');
      }
      mine.complete();
    }
  }

  Future<bool> _take(String owner) => db.transaction(() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = await (db.select(
      db.syncMeta,
    )..where((m) => m.key.equals(_key))).getSingleOrNull();
    if (row != null) {
      final at = int.tryParse(row.value.split(':').first) ?? 0;
      if (now - at < _lease.inMilliseconds) return false;
    }
    await db
        .into(db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(key: _key, value: '$now:$owner'),
        );
    return true;
  });
}

/// Opens [url] in the browser and returns the address it came back to.
typedef BrowserSignIn = Future<String> Function(
  Uri url,
  String callbackUrlScheme,
);

/// Connects this device to the user's Panopto API client and keeps its
/// tokens fresh.
///
/// Signed in to LecCheck, the setup and sign-in live in the account's vault
/// (see panopto_vault.dart), shared by every device holding its key: one
/// Panopto sign-in for all. Otherwise they stay on this device.
///
/// Panopto's refresh tokens work once: each refresh returns a new one, and
/// the new one is saved before anything else happens. In the vault, one
/// device at a time refreshes (the server's lease).
class PanoptoConnection {
  PanoptoConnection({
    required this._lock,
    this._vault,
    FlutterSecureStorage? storage,
    http.Client? client,
    BrowserSignIn? browser,
    DateTime Function()? clock,
    String? redirectUrl,
    this._networkRetry = const Duration(seconds: 3),
    this._leaseRetry = const Duration(seconds: 1),
  }) : _redirect = redirectUrl,
       _storage = storage ?? const FlutterSecureStorage(),
       _http = client ?? http.Client(),
       _browser = browser ?? _openBrowser,
       _clock = clock ?? DateTime.now;

  final RefreshLock _lock;
  final VaultClient? _vault;
  final FlutterSecureStorage _storage;
  final http.Client _http;
  final BrowserSignIn _browser;
  final DateTime Function() _clock;
  final String? _redirect;
  final Duration _networkRetry;
  final Duration _leaseRetry;

  /// This device's own connection (without the vault).
  static const _key = 'leccheck.panopto';

  /// The vault's key, with the site it opens (shown offline).
  static const _vaultKeyKey = 'leccheck.panopto.key';

  /// A refreshed sign-in the vault didn't get yet: sent first next time.
  static const _pendingKey = 'leccheck.panopto.pending';

  static const scope = 'openid api offline_access';
  static const _desktopPort = 43823;

  /// Well inside [DbRefreshLock]'s lease.
  static const tokenTimeout = Duration(seconds: 20);

  /// The vault's contents as last read, and when.
  ({int v, PanoptoState state, DateTime at})? _cache;

  /// The access token last handed out, to tell "the API refused it" from
  /// "another device refreshed meanwhile".
  String? _given;

  /// When this device last checked whether its own connection can move
  /// into the vault.
  DateTime? _movedCheckedAt;

  /// The redirect address the user puts in their Panopto API client: the
  /// sync server's page that hands the browser back to the app. Null when
  /// this build has no server.
  static String? get defaultRedirectUrl =>
      SyncConfig.enabled ? SyncConfig.api('/v1/panopto/done').toString() : null;

  String? get redirectUrl => _redirect ?? defaultRedirectUrl;

  static bool get _usesLoopback =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  static Future<String> _openBrowser(Uri url, String scheme) =>
      FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: scheme,
        options: const FlutterWebAuth2Options(useWebview: false),
      );

  static Map<String, Object?> _decode(String raw) =>
      (jsonDecode(utf8.decode(base64Url.decode(raw))) as Map)
          .cast<String, Object?>();

  static String _encode(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json)));

  /// This device's own connection (null when it uses the vault).
  Future<PanoptoState?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PanoptoState.fromJson(_decode(raw));
    } on Object {
      return null;
    }
  }

  /// Base64url like the LecCheck sign-in: GNOME Keyring without a password
  /// loses values with backslashes.
  Future<void> _save(PanoptoState state) =>
      _storage.write(key: _key, value: _encode(state.toJson()));

  // ------------------------------------------------------------ vault --

  /// The vault key this device holds for the signed-in account, with the
  /// site it opens; null without a vault client, a sign-in or a key.
  Future<(VaultKey, String)?> _heldKey() async {
    final vault = _vault;
    if (vault == null) return null;
    final session = await vault.session();
    if (session == null) return null;
    final raw = await _storage.read(key: _vaultKeyKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = _decode(raw);
      final key = VaultKey.fromJson(json);
      if (key.userId != session.userId) return null;
      return (key, json['site'] as String? ?? '');
    } on Object {
      return null;
    }
  }

  /// The account's vault on the server (null in builds without one).
  VaultClient? get vaultClient => _vault;

  /// The vault key this device holds for the signed-in account (to pair
  /// another device).
  Future<VaultKey?> heldKey() async => (await _heldKey())?.$1;

  Future<void> _keepKey(VaultKey key, String site) => _storage.write(
    key: _vaultKeyKey,
    value: _encode({...key.toJson(), 'site': site}),
  );

  Future<void> _forgetKey() async {
    await _storage.delete(key: _vaultKeyKey);
    await _storage.delete(key: _pendingKey);
    _cache = null;
  }

  /// Saves [key] handed over by pairing, and opens the vault with it.
  /// Throws [PanoptoException] when it doesn't open the account's vault.
  Future<void> useKey(VaultKey key) async {
    final read = await _vault!.read();
    final box = read.vault;
    if (box == null || box.kid != key.kid) {
      throw const PanoptoException('vault_unreadable', 'another key');
    }
    final state = PanoptoState.fromJson(await VaultCrypto.open(key, box));
    await _keepKey(key, state.setup.site);
    _cache = (v: box.v, state: state, at: _clock());
    // This device's own connection isn't needed any more.
    final own = await load();
    if (own != null) {
      await _revoke(own);
      await _storage.delete(key: _key);
    }
    DevLog.add('Panopto: using the account\'s vault');
  }

  /// The vault key in use, moving this device's own connection into the
  /// vault first when the account has none (a device connected before the
  /// vault existed).
  Future<VaultKey?> _resolve() async {
    final held = await _heldKey();
    if (held != null) return held.$1;
    final vault = _vault;
    if (vault == null) return null;
    final now = _clock();
    final checked = _movedCheckedAt;
    if (checked != null && now.difference(checked).inMinutes < 10) {
      return null;
    }
    final own = await load();
    if (own == null || !own.connected) return null;
    final session = await vault.session();
    if (session == null) return null;
    _movedCheckedAt = now;
    try {
      final read = await vault.read();
      if (read.vault != null) return null;
      final key = VaultKey.random(session.userId);
      final sealed = await VaultCrypto.seal(key, own.toJson());
      final v = await vault.put(
        expect: 0,
        kid: key.kid,
        nonce: sealed.nonce,
        ct: sealed.ct,
      );
      await _keepKey(key, own.setup.site);
      await _storage.delete(key: _key);
      _cache = (v: v, state: own, at: _clock());
      DevLog.add('Panopto: this device\'s connection moved into the vault');
      return key;
    } on PanoptoException catch (e) {
      DevLog.add('Panopto connection not moved into the vault: $e');
      return null;
    }
  }

  /// The vault's contents (from a read in the last minute unless [fresh]).
  /// Throws `reconnect` when it's gone or has another key (the key is then
  /// forgotten), `vault_unreadable`.
  Future<({int v, PanoptoState state, bool refused})> _current(
    VaultKey key, {
    bool fresh = false,
  }) async {
    final cache = _cache;
    if (!fresh &&
        cache != null &&
        _clock().difference(cache.at) < const Duration(minutes: 1)) {
      return (v: cache.v, state: cache.state, refused: false);
    }
    final box = (await _vault!.read()).vault;
    return _opened(key, box);
  }

  Future<({int v, PanoptoState state, bool refused})> _opened(
    VaultKey key,
    VaultBox? box,
  ) async {
    if (box == null || box.kid != key.kid) {
      // Disconnected everywhere, or set up again on another device.
      await _forgetKey();
      DevLog.add('Panopto: the account\'s vault is gone or has a new key');
      throw const PanoptoException('reconnect', 'vault gone');
    }
    final state = PanoptoState.fromJson(await VaultCrypto.open(key, box));
    _cache = (v: box.v, state: state, at: _clock());
    return (v: box.v, state: state, refused: box.refused);
  }

  /// Sends a refreshed sign-in the vault didn't get. Keeps it while the
  /// server can't be reached.
  Future<void> _sendPending(VaultKey key) async {
    final raw = await _storage.read(key: _pendingKey);
    if (raw == null || raw.isEmpty) return;
    final json = _decode(raw);
    final expect = (json['expect'] as num).toInt();
    final state = PanoptoState.fromJson(
      (json['state'] as Map).cast<String, Object?>(),
    );
    final sealed = await VaultCrypto.seal(key, state.toJson());
    try {
      final v = await _vault!.put(
        expect: expect,
        kid: key.kid,
        nonce: sealed.nonce,
        ct: sealed.ct,
      );
      _cache = (v: v, state: state, at: _clock());
      DevLog.add('Panopto: a refreshed sign-in reached the vault late');
    } on VaultConflict catch (e) {
      // Still that version: another device holds the lease. Try later.
      if (e.vault?.v == expect) return;
      DevLog.add('Panopto: a late sign-in was replaced by a newer one');
    }
    await _storage.delete(key: _pendingKey);
  }

  Future<String> _vaultAccess(VaultKey key, {required bool refresh}) async {
    final vault = _vault!;
    await _sendPending(key);
    final now = _clock().millisecondsSinceEpoch;
    // [refresh]: the token handed out last was refused. One another device
    // saved since is fine; with none handed out yet, refresh anyway.
    bool usable(PanoptoState s) =>
        s.accessToken != null &&
        now < s.accessExpiresAt - 60000 &&
        !(refresh && (_given == null || s.accessToken == _given));

    var current = await _current(key, fresh: refresh);
    if (current.refused) throw const PanoptoException('reconnect');
    if (usable(current.state)) return current.state.accessToken!;

    // One device at a time: wait while another one refreshes.
    final owner = _randomString(16);
    final giveUp = _clock().add(const Duration(seconds: 70));
    VaultBox box;
    while (true) {
      try {
        box = await vault.lease(owner);
        break;
      } on PanoptoException catch (e) {
        if (e.code == 'no_vault') {
          await _forgetKey();
          throw const PanoptoException('reconnect', 'vault gone');
        }
        if (e.code != 'busy' || _clock().isAfter(giveUp)) {
          throw PanoptoException('network', 'vault: ${e.code}');
        }
        await Future<void>.delayed(_leaseRetry);
      }
    }
    var saved = false;
    try {
      current = await _opened(key, box);
      if (current.refused) throw const PanoptoException('reconnect');
      // Another device refreshed while this one waited.
      if (usable(current.state)) return current.state.accessToken!;
      final refreshToken = current.state.refreshToken;
      if (refreshToken == null) throw const PanoptoException('reconnect');
      final Map<String, Object?> tokens;
      try {
        tokens = await _tokenRequest(current.state.setup, {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        });
      } on PanoptoException catch (e) {
        if (e.needsReconnect) {
          DevLog.add('Panopto sign-in expired: connect again');
          try {
            await vault.refused(current.v);
          } on PanoptoException catch (e) {
            DevLog.add('Panopto: the vault wasn\'t told ($e)');
          }
        }
        rethrow;
      }
      final next = _stateFrom(current.state.setup, tokens, refreshToken);
      // Kept on the device before anything else: Panopto took the old one.
      await _storage.write(
        key: _pendingKey,
        value: _encode({'expect': current.v, 'state': next.toJson()}),
      );
      final sealed = await VaultCrypto.seal(key, next.toJson());
      try {
        final v = await vault.put(
          expect: current.v,
          owner: owner,
          kid: key.kid,
          nonce: sealed.nonce,
          ct: sealed.ct,
        );
        saved = true;
        await _storage.delete(key: _pendingKey);
        _cache = (v: v, state: next, at: _clock());
      } on PanoptoException catch (e) {
        DevLog.add(
          'Panopto: the refreshed sign-in waits to reach the vault ($e)',
        );
      }
      return next.accessToken!;
    } finally {
      if (!saved) {
        try {
          await vault.release(owner);
        } on Object catch (e) {
          debugPrint('Panopto lease not released: $e');
        }
      }
    }
  }

  /// The account-wide look when this device uses the vault (null: it
  /// doesn't, and keeps its own time). [force] claims it anyway.
  Future<SharedLook?> claimLook({required bool force}) async {
    final vault = _vault;
    if (vault == null || await _resolve() == null) return null;
    final at = await vault.claimLook(force: force);
    return SharedLook(at, at == null ? null : () => vault.unclaimLook(at));
  }

  // --------------------------------------------------------- the rest --

  /// This device's connection, for Settings. Asks the server when signed
  /// in; offline, says what it knows.
  Future<PanoptoInfo> info() async {
    final key = await _resolve();
    if (key != null) {
      try {
        final current = await _current(key, fresh: true);
        return PanoptoInfo(
          current.refused ? PanoptoStatus.reconnect : PanoptoStatus.connected,
          site: current.state.setup.site,
          shared: true,
        );
      } on PanoptoException catch (e) {
        if (e.code != 'reconnect') {
          final site = (await _heldKey())?.$2;
          return PanoptoInfo(PanoptoStatus.connected, site: site, shared: true);
        }
        // The vault is gone: fall through.
      }
    }
    final own = await load();
    final box = await _accountVault();
    if (own != null) {
      return PanoptoInfo(
        own.connected ? PanoptoStatus.connected : PanoptoStatus.reconnect,
        site: own.setup.site,
        sharedElsewhere: box?.device,
      );
    }
    if (box != null) {
      return PanoptoInfo(PanoptoStatus.elsewhere, device: box.device);
    }
    return PanoptoInfo.off;
  }

  /// The account's vault, if this device can ask.
  Future<VaultBox?> _accountVault() async {
    final vault = _vault;
    if (vault == null || await vault.session() == null) return null;
    try {
      return (await vault.read()).vault;
    } on PanoptoException {
      return null;
    }
  }

  Future<PanoptoStatus> status() async {
    final held = await _heldKey();
    if (held != null) return PanoptoStatus.connected;
    final state = await load();
    if (state == null) return PanoptoStatus.off;
    return state.connected ? PanoptoStatus.connected : PanoptoStatus.reconnect;
  }

  /// The setup in use (for "Connect again"), from the vault or this device.
  Future<PanoptoSetup?> setup() async {
    final key = await _resolve();
    if (key != null) {
      try {
        return (await _current(key)).state.setup;
      } on PanoptoException {
        // Fall back to this device's own.
      }
    }
    return (await load())?.setup;
  }

  /// Signs in to Panopto in the browser with [setup] and keeps the tokens:
  /// in the account's vault when signed in (replacing the setup there), or
  /// on this device. Throws [PanoptoException] (`client` when Panopto
  /// refused the Client ID or secret, `denied` when the sign-in was
  /// cancelled or refused).
  Future<void> connect(PanoptoSetup setup) async {
    final redirect = redirectUrl;
    if (redirect == null) throw const PanoptoException('no_server');
    final verifier = _randomString(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    // The server's page reads where to send the browser from the state's
    // ending: `.d` a desktop loopback port, `.m` the app's own scheme.
    final state = '${_randomString(24)}.${_usesLoopback ? 'd' : 'm'}';
    final url = Uri.https(setup.site, '/Panopto/oauth2/connect/authorize', {
      'client_id': setup.clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': scope,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });
    final String result;
    try {
      result = await _browser(
        url,
        _usesLoopback ? 'http://localhost:$_desktopPort' : 'leccheck',
      );
    } on PlatformException catch (e) {
      throw PanoptoException('denied', e.code);
    }
    final back = Uri.parse(result).queryParameters;
    if (back['state'] != state) throw const PanoptoException('denied', 'state');
    final error = back['error'];
    if (error != null) throw PanoptoException('denied', error);
    final code = back['code'];
    if (code == null) throw const PanoptoException('denied', 'no code');

    final tokens = await _tokenRequest(setup, {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirect,
      'code_verifier': verifier,
    });
    final connected = _stateFrom(setup, tokens, null);
    await _lock.run(() async {
      if (await _saveInVault(connected)) {
        DevLog.add('Panopto connected in the vault (${setup.site})');
        return;
      }
      await _save(connected);
      DevLog.add('Panopto connected (${setup.site})');
    });
  }

  /// Saves a new sign-in in the account's vault: with the key this device
  /// holds when the vault still has it, otherwise a new key (the vault from
  /// another setup is replaced). False when there's no account or no
  /// answer: the device keeps it, and moves it into the vault later.
  Future<bool> _saveInVault(PanoptoState state) async {
    final vault = _vault;
    if (vault == null) return false;
    final session = await vault.session();
    if (session == null) return false;
    try {
      var box = (await vault.read()).vault;
      final held = (await _heldKey())?.$1;
      final key = held != null && box?.kid == held.kid
          ? held
          : VaultKey.random(session.userId);
      final sealed = await VaultCrypto.seal(key, state.toJson());
      int v;
      try {
        v = await vault.put(
          expect: box?.v ?? 0,
          kid: key.kid,
          nonce: sealed.nonce,
          ct: sealed.ct,
        );
      } on VaultConflict catch (e) {
        // Saved meanwhile (a refresh elsewhere): this sign-in is newer.
        box = e.vault;
        v = await vault.put(
          expect: box?.v ?? 0,
          kid: key.kid,
          nonce: sealed.nonce,
          ct: sealed.ct,
        );
      }
      await _keepKey(key, state.setup.site);
      await _storage.delete(key: _pendingKey);
      await _storage.delete(key: _key);
      _cache = (v: v, state: state, at: _clock());
      return true;
    } on PanoptoException catch (e) {
      DevLog.add('Panopto sign-in kept on this device: $e');
      return false;
    }
  }

  /// A valid access token, refreshed when it's about to expire or when
  /// [refresh] (the API just refused it).
  Future<String> accessToken({bool refresh = false}) => _lock.run(() async {
    final key = await _resolve();
    if (key != null) {
      final token = await _vaultAccess(key, refresh: refresh);
      _given = token;
      return token;
    }
    // Read again inside the lock: another isolate may have refreshed.
    final state = await load();
    if (state == null) throw const PanoptoException('reconnect', 'not set up');
    final refreshToken = state.refreshToken;
    if (refreshToken == null) throw const PanoptoException('reconnect');
    final now = _clock().millisecondsSinceEpoch;
    final access = state.accessToken;
    if (!refresh && access != null && now < state.accessExpiresAt - 60000) {
      return access;
    }
    final Map<String, Object?> tokens;
    try {
      tokens = await _tokenRequest(state.setup, {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      });
    } on PanoptoException catch (e) {
      if (e.needsReconnect) {
        // Forget only the token Panopto refused: one saved meanwhile (by a
        // refresh that got past the lock) still works.
        if ((await load())?.refreshToken != refreshToken) {
          throw const PanoptoException('network', 'token changed meanwhile');
        }
        await _save(PanoptoState(setup: state.setup));
        DevLog.add('Panopto sign-in expired: connect again');
      }
      rethrow;
    }
    final next = _stateFrom(state.setup, tokens, refreshToken);
    await _save(next);
    return next.accessToken!;
  });

  /// The API with this device's tokens.
  Future<PanoptoApi?> api() async {
    String? site;
    final key = await _resolve();
    if (key != null) {
      site = (await _current(key)).state.setup.site;
    } else {
      final state = await load();
      if (state == null || !state.connected) return null;
      site = state.setup.site;
    }
    return PanoptoApi(
      site: site,
      client: _http,
      token: accessToken,
      networkRetry: _networkRetry,
    );
  }

  /// Stops using Panopto on this device. [everywhere] also asks Panopto to
  /// revoke the account's sign-in and deletes the vault, so every device
  /// stops (best effort with Panopto; throws when the server can't be
  /// reached). This device's own connection is always revoked.
  Future<void> disconnect({bool everywhere = false}) async {
    final held = await _heldKey();
    if (held != null) {
      if (everywhere) {
        try {
          final box = (await _vault!.read()).vault;
          if (box != null && box.kid == held.$1.kid) {
            await _revoke(
              PanoptoState.fromJson(await VaultCrypto.open(held.$1, box)),
            );
          }
        } on PanoptoException catch (e) {
          if (e.code == 'network') rethrow;
        }
        await _vault!.delete();
      }
      await _forgetKey();
    }
    final own = await load();
    if (own != null) await _revoke(own);
    await _storage.delete(key: _key);
    DevLog.add('Panopto disconnected${everywhere ? ' everywhere' : ''}');
  }

  Future<void> _revoke(PanoptoState state) async {
    final token = state.refreshToken;
    if (token == null) return;
    try {
      await _http
          .post(
            Uri.https(state.setup.site, '/Panopto/oauth2/connect/revocation'),
            headers: _basic(state.setup),
            body: {'token': token, 'token_type_hint': 'refresh_token'},
          )
          .timeout(const Duration(seconds: 10));
    } on Object catch (e) {
      DevLog.add('Panopto token not revoked: $e');
    }
  }

  PanoptoState _stateFrom(
    PanoptoSetup setup,
    Map<String, Object?> tokens,
    String? previousRefresh,
  ) {
    final expiresIn = (tokens['expires_in'] as num?)?.toInt() ?? 3600;
    return PanoptoState(
      setup: setup,
      refreshToken: tokens['refresh_token'] as String? ?? previousRefresh,
      accessToken: tokens['access_token'] as String?,
      accessExpiresAt:
          _clock().millisecondsSinceEpoch +
          expiresIn * Duration.millisecondsPerSecond,
    );
  }

  /// The id and secret go as they are: Panopto doesn't URL-decode Basic
  /// credentials (RFC 6749 says to encode them), and secrets have `/`, `=`.
  static Map<String, String> _basic(PanoptoSetup setup) => {
    'Authorization':
        'Basic ${base64.encode(utf8.encode('${setup.clientId}:${setup.clientSecret}'))}',
  };

  Future<Map<String, Object?>> _tokenRequest(
    PanoptoSetup setup,
    Map<String, String> form,
  ) async {
    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.https(setup.site, '/Panopto/oauth2/connect/token'),
            headers: _basic(setup),
            body: form,
          )
          .timeout(tokenTimeout);
    } on Exception catch (e) {
      throw PanoptoException('network', '$e');
    }
    Map<String, Object?> json;
    try {
      json = (jsonDecode(response.body) as Map).cast<String, Object?>();
    } on Object {
      json = const {};
    }
    if (response.statusCode == 200 && json['access_token'] is String) {
      return json;
    }
    final error = json['error'] as String? ?? 'http_${response.statusCode}';
    if (error == 'invalid_client' || error == 'unauthorized_client') {
      throw PanoptoException('client', error);
    }
    if (error == 'invalid_grant' && form['grant_type'] == 'refresh_token') {
      throw const PanoptoException('reconnect', 'invalid_grant');
    }
    throw PanoptoException(
      response.statusCode >= 500 ? 'http_${response.statusCode}' : 'denied',
      error,
    );
  }
}

String _randomString(int length) {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}
