import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/core/auth/auth_service.dart';
import 'package:leccheck/core/auth/session.dart';

void main() {
  const session = Session(token: 't', userId: 'g:1');

  test('"sign out everywhere" only succeeds when the server did it', () async {
    AuthService answering(int status) =>
        AuthService(client: MockClient((_) async => http.Response('', status)));
    await answering(204).signOutEverywhere(session);
    // Revoked already: this device's session is gone either way.
    await answering(401).signOutEverywhere(session);
    expect(
      () => answering(503).signOutEverywhere(session),
      throwsA(isA<AuthException>()),
    );
  });
}
