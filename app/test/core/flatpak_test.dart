import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/update/flatpak.dart';

void main() {
  test('/.flatpak-info is read as group.key', () {
    final info = Flatpak.parseInfo('''
[Application]
name=com.leccheck.app
runtime=runtime/org.freedesktop.Platform/x86_64/26.08

[Instance]
# a comment
app-commit = 1a2b3c
''');
    expect(info['Application.name'], 'com.leccheck.app');
    expect(
      info['Application.runtime'],
      'runtime/org.freedesktop.Platform/x86_64/26.08',
    );
    expect(info['Instance.app-commit'], '1a2b3c');
  });

  group('Progress signals', () {
    FlatpakProgress parse(Map<String, DBusValue> info) =>
        FlatpakProgress.fromDBus(info);

    test('while it runs: 0-based op of n_ops, each 0–100', () {
      final progress = parse({
        'n_ops': const DBusUint32(2),
        'op': const DBusUint32(1),
        'progress': const DBusUint32(40),
        'status': const DBusUint32(0),
      });
      expect(progress.status, FlatpakStatus.running);
      expect(progress.fraction, closeTo(0.7, 1e-9));
      // Before the portal knows how many operations: no fraction.
      expect(
        parse({'status': const DBusUint32(0)}).fraction,
        isNull,
      );
    });

    test('the end: done, nothing to install, or failed with why', () {
      expect(parse({'status': const DBusUint32(2)}).fraction, 1);
      expect(
        parse({'status': const DBusUint32(1)}).status,
        FlatpakStatus.empty,
      );
      final failed = parse({
        'status': const DBusUint32(3),
        'error': const DBusString('org.freedesktop.DBus.Error.NotSupported'),
        'error_message': const DBusString(
          'Self update not supported, new version requires new permissions',
        ),
      });
      expect(failed.status, FlatpakStatus.failed);
      expect(failed.error, 'org.freedesktop.DBus.Error.NotSupported');
      expect(failed.message, startsWith('Self update not supported'));
      // A status this version doesn't know counts as failed.
      expect(
        parse({'status': const DBusUint32(9)}).status,
        FlatpakStatus.failed,
      );
    });
  });
}
