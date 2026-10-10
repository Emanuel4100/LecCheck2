import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../sync/sync_config.dart';
import 'session.dart';

class AuthException implements Exception {
  const AuthException(this.code);
  final String code;

  @override
  String toString() => 'AuthException($code)';
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

  static const _key = 'leccheck.session';

  /// Loopback port for desktop sign-in (Linux/Windows have no custom URL
  /// schemes the browser can hand back to).
  static const _desktopPort = 43823;

  static bool get _usesLoopback =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  Future<Session?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  Future<void> save(Session session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: _key);

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
