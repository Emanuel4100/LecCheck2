import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/update/windows_install.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('windows_install_test');
  });
  tearDown(() => dir.delete(recursive: true));

  test('only a LecCheck the setup installed updates itself', () async {
    final exe = '${dir.path}/leccheck.exe';
    File(exe).writeAsStringSync('');
    // A copied folder or flutter run: no uninstaller beside the app.
    expect(await WindowsInstall.setupDir(executable: exe), isNull);
    File('${dir.path}/unins000.exe').writeAsStringSync('');
    expect(await WindowsInstall.setupDir(executable: exe), dir.path);
  });

  test('the setup runs without its wizard and opens LecCheck again', () {
    final log = WindowsInstall.windowsPath(
      r'C:\Users\Dana Levi\AppData\Local\LecCheck/updates/setup.log',
    );
    expect(log, r'C:\Users\Dana Levi\AppData\Local\LecCheck\updates\setup.log');
    expect(WindowsInstall.setupArguments(log), [
      '/SILENT',
      '/NORESTART',
      '/RELAUNCH=1',
      '/LOG=$log',
    ]);
  });

  group('the setup log, on the next start', () {
    final printed = <String>[];
    final realPrint = debugPrint;

    setUp(() {
      printed.clear();
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    });
    tearDown(() => debugPrint = realPrint);

    File log() => File('${dir.path}/${WindowsInstall.logName}');

    test('a finished update is noted and its log deleted', () async {
      log().writeAsStringSync(
        '2026-11-18 10:00:01.000   Setup version: Inno Setup 6\n'
        '2026-11-18 10:00:09.000   Installation process succeeded.\n',
      );
      await WindowsInstall.reportSetupLog(dir);
      expect(printed, ['Windows setup: the update was installed']);
      expect(log().existsSync(), isFalse);
    });

    test('a failed one keeps the end of its log for Developer', () async {
      log().writeAsStringSync(
        [
          for (var i = 0; i < 60; i++) 'line $i',
          'Fatal exception during installation process: access denied',
        ].join('\n'),
      );
      await WindowsInstall.reportSetupLog(dir);
      expect(printed.single, startsWith('Windows setup did not finish:'));
      expect(printed.single, contains('access denied'));
      expect(printed.single, isNot(contains('line 0\n')));
      expect(log().existsSync(), isFalse);
    });

    test('no log, nothing to say', () async {
      await WindowsInstall.reportSetupLog(dir);
      expect(printed, isEmpty);
    });
  });
}
