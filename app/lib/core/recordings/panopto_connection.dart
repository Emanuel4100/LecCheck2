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
  /// Not set up on this device.
  off,
  connected,

  /// Set up, but the sign-in expired or was refused: connect again.
  reconnect,
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
  DbRefreshLock(this.db);

  final AppDatabase db;
  static const _key = 'panopto.refreshLock';
  static const _lease = Duration(seconds: 30);
  static Future<void> _tail = Future.value();

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    final previous = _tail;
    final mine = Completer<void>();
    _tail = mine.future;
    await previous;
    final owner = _randomString(12);
    try {
      final giveUp = DateTime.now().add(_lease + const Duration(seconds: 5));
      while (!await _take(owner) && DateTime.now().isBefore(giveUp)) {
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
/// Panopto's refresh tokens work once: each refresh returns a new one, and
/// the new one is saved before anything else happens.
class PanoptoConnection {
  PanoptoConnection({
    required this._lock,
    FlutterSecureStorage? storage,
    http.Client? client,
    BrowserSignIn? browser,
    DateTime Function()? clock,
    String? redirectUrl,
  }) : _redirect = redirectUrl,
       _storage = storage ?? const FlutterSecureStorage(),
       _http = client ?? http.Client(),
       _browser = browser ?? _openBrowser,
       _clock = clock ?? DateTime.now;

  final RefreshLock _lock;
  final FlutterSecureStorage _storage;
  final http.Client _http;
  final BrowserSignIn _browser;
  final DateTime Function() _clock;
  final String? _redirect;

  static const _key = 'leccheck.panopto';
  static const scope = 'openid api offline_access';
  static const _desktopPort = 43823;

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

  Future<PanoptoState?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PanoptoState.fromJson(
        (jsonDecode(utf8.decode(base64Url.decode(raw))) as Map)
            .cast<String, Object?>(),
      );
    } on Object {
      return null;
    }
  }

  /// Base64url like the LecCheck sign-in: GNOME Keyring without a password
  /// loses values with backslashes.
  Future<void> _save(PanoptoState state) => _storage.write(
    key: _key,
    value: base64Url.encode(utf8.encode(jsonEncode(state.toJson()))),
  );

  Future<PanoptoStatus> status() async {
    final state = await load();
    if (state == null) return PanoptoStatus.off;
    return state.connected ? PanoptoStatus.connected : PanoptoStatus.reconnect;
  }

  /// Signs in to Panopto in the browser with [setup] and keeps the tokens.
  /// Throws [PanoptoException] (`client` when Panopto refused the Client ID
  /// or secret, `denied` when the sign-in was cancelled or refused).
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
    await _lock.run(() => _save(_stateFrom(setup, tokens, null)));
    DevLog.add('Panopto connected (${setup.site})');
  }

  /// A valid access token, refreshed when it's about to expire or when
  /// [refresh] (the API just refused it).
  Future<String> accessToken({bool refresh = false}) => _lock.run(() async {
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
    final state = await load();
    if (state == null || !state.connected) return null;
    return PanoptoApi(
      site: state.setup.site,
      client: _http,
      token: accessToken,
    );
  }

  /// Forgets the connection on this device, and asks Panopto to revoke its
  /// refresh token (best effort).
  Future<void> disconnect() async {
    final state = await load();
    final token = state?.refreshToken;
    if (state != null && token != null) {
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
    await _storage.delete(key: _key);
    DevLog.add('Panopto disconnected');
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
          .timeout(const Duration(seconds: 30));
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
