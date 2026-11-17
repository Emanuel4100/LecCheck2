import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/core/recordings/panopto_connection.dart';

/// Panopto as HUJI's site behaved on 2026-11-16: refresh tokens work once,
/// Basic credentials are compared as sent (not URL-decoded), folder lists
/// come 50 to a page, and an unknown token gets 401.
class FakePanopto {
  FakePanopto({this.folderPages = 3});

  static const site = 'example.cloud.panopto.eu';
  static const clientId = 'a6b0c7e2-1111-4222-8333-444455556666';

  /// Has `/` and `=` like real secrets.
  static const clientSecret = 'k3y/with+symbols=';
  static const folderId = '11111111-2222-4333-8444-555555555555';

  static const setup = PanoptoSetup(
    site: site,
    clientId: clientId,
    clientSecret: clientSecret,
  );

  /// Pages served from `test/fixtures/panopto/folder_sessions_p<N>.json`.
  final int folderPages;

  final requests = <http.Request>[];
  var _issued = 0;
  String? accessToken;
  String? refreshToken;
  final revoked = <String>[];

  /// The code the browser brings back.
  static const code = 'one-time-code';

  /// How many of the next API requests fail with no connection.
  var apiOffline = 0;

  late final client = MockClient((request) async {
    requests.add(request);
    if (apiOffline > 0 && request.url.path.startsWith('/Panopto/api/')) {
      apiOffline--;
      throw http.ClientException('Failed host lookup');
    }
    final path = request.url.path;
    if (request.method == 'POST' && path == '/Panopto/oauth2/connect/token') {
      return _token(request);
    }
    if (request.method == 'POST' &&
        path == '/Panopto/oauth2/connect/revocation') {
      revoked.add(request.bodyFields['token'] ?? '');
      return http.Response('', 200);
    }
    if (request.headers['Authorization'] != 'Bearer $accessToken' ||
        accessToken == null) {
      return http.Response('', 401);
    }
    if (path == '/Panopto/api/v1/folders/search') {
      final page = request.url.queryParameters['pageNumber'];
      return page == '0'
          ? _fixture('folders_search.json')
          : _json({'Results': []});
    }
    if (path == '/Panopto/api/v1/folders/$folderId/sessions') {
      final page = int.parse(request.url.queryParameters['pageNumber']!);
      return page < folderPages
          ? _fixture('folder_sessions_p$page.json')
          : _json({'Results': []});
    }
    return http.Response('{"Error":"not found"}', 404);
  });

  /// Requests to the API (not the token endpoint).
  List<http.Request> get apiRequests => [
    for (final r in requests)
      if (r.url.path.startsWith('/Panopto/api/')) r,
  ];

  /// Makes Panopto forget the current access token (as when it expires).
  void expireAccess() => accessToken = 'expired-${accessToken ?? ''}';

  http.Response _token(http.Request request) {
    final expected =
        'Basic ${base64.encode(utf8.encode('$clientId:$clientSecret'))}';
    if (request.headers['Authorization'] != expected) {
      return _json({'error': 'invalid_client'}, 400);
    }
    final form = request.bodyFields;
    switch (form['grant_type']) {
      case 'authorization_code' when form['code'] == code:
        return _issue();
      case 'refresh_token'
          when form['refresh_token'] != null &&
              form['refresh_token'] == refreshToken:
        return _issue();
      default:
        return _json({'error': 'invalid_grant'}, 400);
    }
  }

  http.Response _issue() {
    _issued++;
    accessToken = 'access-$_issued';
    refreshToken = 'refresh-$_issued';
    return _json({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': 3600,
      'token_type': 'Bearer',
      'id_token': 'x.y.z',
    });
  }

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static http.Response _fixture(String name) => http.Response.bytes(
    File('test/fixtures/panopto/$name').readAsBytesSync(),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// A browser that signs in and comes back like the server's page does.
  Future<String> browser(Uri url, String scheme) async {
    final q = url.queryParameters;
    if (q['client_id'] != clientId) {
      throw StateError('unknown client');
    }
    return Uri(
      scheme: 'leccheck',
      host: 'panopto',
      queryParameters: {'code': code, 'state': q['state']!},
    ).toString();
  }
}

/// Runs bodies one at a time in this isolate.
class MemoryLock implements RefreshLock {
  Future<void> _tail = Future.value();

  @override
  Future<T> run<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
