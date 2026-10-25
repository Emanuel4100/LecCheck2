import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show immutable, kIsWeb, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../dev/dev_log.dart';
import '../sync/sync_config.dart';
import 'session.dart';

class AuthException implements Exception {
  const AuthException(this.code);
  final String code;

  @override
  String toString() => 'AuthException($code)';
}

/// The saved sign-in couldn't be read: the system's secure storage (on Linux,
/// the keyring) didn't answer. It's still saved; nothing was signed out.
class SessionUnreadable implements Exception {
  const SessionUnreadable(this.error);
  final Object error;

  @override
  String toString() => 'SessionUnreadable($error)';
}

/// What an account holds, and what "Delete cloud data" left in its trash
/// (`GET /v1/account/summary`).
@immutable
class AccountSummary {
  const AccountSummary({
    required this.semesters,
    required this.courses,
    this.trashRows = 0,
    this.deletedAt,
  });

  /// Null unless [json] is the server's answer.
  static AccountSummary? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final semesters = json['semesters'];
    final courses = json['courses'];
    if (semesters is! int || courses is! int) return null;
    final trash = json['trash'];
    final rows = trash is Map<String, Object?> ? trash['rows'] : null;
    final at = trash is Map<String, Object?> ? trash['deletedAt'] : null;
    return AccountSummary(
      semesters: semesters,
      courses: courses,
      trashRows: rows is int ? rows : 0,
      deletedAt: at is int && rows is int && rows > 0
          ? DateTime.fromMillisecondsSinceEpoch(at)
          : null,
    );
  }

  final int semesters;
  final int courses;

  /// Rows "Delete cloud data" moved to the trash (kept 30 days).
  final int trashRows;

  /// When the cloud data was deleted; null when the trash is empty.
  final DateTime? deletedAt;
}

/// Sign-in and session storage. The Google flow runs in the system browser
/// and is brokered by our Worker, so the app never holds an OAuth secret;
/// PKCE ties the returned one-time code to this app instance.
class AuthService {
  AuthService({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _http = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _http;

  /// Where the session is kept. A local test server (`wrangler dev`, plain
  /// http) gets its own: on Linux a debug build shares the installed app's
  /// keyring entry, and its sign-in could replace or remove the real one.
  static final _key = storageKey(SyncConfig.apiBase);

  @visibleForTesting
  static String storageKey(String apiBase) {
    final api = Uri.tryParse(apiBase);
    return api == null || api.scheme == 'https' || api.host.isEmpty
        ? 'leccheck.session'
        : 'leccheck.session@${api.host}:${api.port}';
  }

  /// Loopback port for desktop sign-in (Linux/Windows have no custom URL
  /// schemes the browser can hand back to).
  static const _desktopPort = 43823;

  static bool get _usesLoopback =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// The saved session, or null when there's none. Throws
  /// [SessionUnreadable] when the storage didn't answer.
  Future<Session?> load() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _key);
    } on Object catch (e) {
      throw SessionUnreadable(e);
    }
    if (raw == null || raw.isEmpty) return null;
    // Saved as plain JSON before 2.0.0-beta.13: read it, and save it again
    // the new way before a keyring reload can empty it (see [save]).
    final legacy = raw.startsWith('{');
    final Session session;
    try {
      final json = legacy ? raw : utf8.decode(base64Url.decode(raw));
      session = Session.fromJson(jsonDecode(json) as Map<String, Object?>);
    } on Object {
      return null;
    }
    if (legacy) {
      try {
        await save(session);
      } on Object catch (e) {
        DevLog.add('Sign-in not re-saved: $e');
      }
    }
    return session;
  }

  /// Saves [session] base64url-encoded: no backslashes. On Linux the plugin
  /// keeps every value inside one JSON document in one keyring entry, so a
  /// JSON session became escaped JSON full of `\"`, and GNOME Keyring's
  /// keyrings without a password (a plain text file) lose any secret with a
  /// backslash when they read the file again: the sign-in came back empty.
  Future<void> save(Session session) => _storage.write(
    key: _key,
    value: base64Url.encode(utf8.encode(jsonEncode(session.toJson()))),
  );

  /// Removes the saved session; [reason] goes to the log, so a sign-out
  /// nobody asked for can be traced.
  Future<void> clear(String reason) {
    DevLog.add('Sign-in removed: $reason');
    return _storage.delete(key: _key);
  }

  Future<Session> signInWithGoogle() async {
    final verifier = _random(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _random(24);
    final redirect = _usesLoopback
        ? 'http://localhost:$_desktopPort/auth'
        : 'leccheck://auth';
    final start = SyncConfig.api('/v1/auth/google/start').replace(
      queryParameters: {
        'redirect_uri': redirect,
        'state': state,
        'code_challenge': challenge,
      },
    );

    final result = await FlutterWebAuth2.authenticate(
      url: start.toString(),
      callbackUrlScheme: _usesLoopback
          ? 'http://localhost:$_desktopPort'
          : 'leccheck',
      options: const FlutterWebAuth2Options(useWebview: false),
    );
    final returned = Uri.parse(result);
    if (returned.queryParameters['state'] != state) {
      throw const AuthException('state_mismatch');
    }
    final error = returned.queryParameters['error'];
    if (error != null) throw AuthException(error);
    final code = returned.queryParameters['code'];
    if (code == null) throw const AuthException('no_code');

    final response = await _http.post(
      SyncConfig.api('/v1/auth/token'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'code': code, 'code_verifier': verifier}),
    );
    return _sessionFrom(response);
  }

  /// Local testing against `wrangler dev` with DEV_AUTH=1.
  Future<Session> signInDev(String name) async {
    final response = await _http.post(
      SyncConfig.api('/v1/auth/dev'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    return _sessionFrom(response);
  }

  Future<Session> _sessionFrom(http.Response response) async {
    if (response.statusCode != 200) {
      throw AuthException('http_${response.statusCode}');
    }
    final session = Session.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
    await save(session);
    return session;
  }

  /// Renews tokens older than a week (they're valid for 60 days). Returns
  /// null if the server says the session was revoked.
  Future<Session?> renewIfNeeded(Session session) async {
    final issued = session.issuedAt;
    if (issued != null &&
        DateTime.now().toUtc().difference(issued) < const Duration(days: 7)) {
      return session;
    }
    try {
      final response = await _http.post(
        SyncConfig.api('/v1/auth/renew'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );
      if (response.statusCode == 401) return null;
      if (response.statusCode != 200) return session;
      final token =
          (jsonDecode(response.body) as Map<String, Object?>)['token']!
              as String;
      final renewed = session.withToken(token);
      await save(renewed);
      return renewed;
    } on Object {
      return session; // offline: keep using the current token
    }
  }

  /// Revokes every session of the account. Throws when the server couldn't
  /// do it (offline, an error), so the caller doesn't sign out thinking the
  /// other devices were. A 401 means this session was revoked already.
  Future<void> signOutEverywhere(Session session) async {
    final response = await _http.post(
      SyncConfig.api('/v1/auth/signout-everywhere'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (response.statusCode >= 300 && response.statusCode != 401) {
      throw AuthException('http_${response.statusCode}');
    }
  }

  Future<void> deleteAccount(Session session) async {
    final response = await _http.delete(
      SyncConfig.api('/v1/account'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (response.statusCode >= 300) {
      throw AuthException('http_${response.statusCode}');
    }
  }

  /// What the account holds. Null when that can't be told (offline, a
  /// server from before 2.0.0-beta.9): sign-in then merges, which loses
  /// nothing.
  Future<AccountSummary?> accountSummary(Session session) async {
    try {
      final response = await _http
          .get(
            SyncConfig.api('/v1/account/summary'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return AccountSummary.tryParse(jsonDecode(response.body));
    } on Object {
      return null;
    }
  }

  /// Brings back what "Delete cloud data" removed (within 30 days); the rows
  /// then arrive through sync. Returns how many came back.
  Future<int> restoreDeleted(Session session) async {
    final response = await _http.post(
      SyncConfig.api('/v1/account/restore'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    if (response.statusCode != 200) {
      throw AuthException('http_${response.statusCode}');
    }
    final restored =
        (jsonDecode(response.body) as Map<String, Object?>)['restored'];
    return restored is int ? restored : 0;
  }

  static String _random(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
