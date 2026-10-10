import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/features/session/session_actions.dart';

void main() {
  test('web, mail and phone links open', () {
    expect(
      openableLink('https://zoom.us/j/1')?.toString(),
      'https://zoom.us/j/1',
    );
    expect(
      openableLink(' moodle.example.ac.il/course ')?.toString(),
      'https://moodle.example.ac.il/course',
    );
    expect(
      openableLink('example.com:8080/x')?.toString(),
      'https://example.com:8080/x',
    );
    expect(openableLink('mailto:lecturer@example.ac.il')?.scheme, 'mailto');
    expect(openableLink('tel:+972501234567')?.scheme, 'tel');
    expect(openableLink('HTTP://EXAMPLE.COM')?.host, 'example.com');
  });

  test('links to local files or other apps are refused', () {
    for (final link in [
      'file:///home/me/.ssh/id_ed25519',
      'content://com.android.contacts/contacts',
      'intent://scan/#Intent;scheme=zxing;end',
      'javascript:alert(1)',
      'data:text/html,<script>alert(1)</script>',
      'smb://server/share',
      '',
    ]) {
      expect(openableLink(link), isNull, reason: link);
    }
  });
}
