import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// LecCheck for Windows as its setup installs it
/// (windows/installer/leccheck.iss): in %LOCALAPPDATA%\Programs\LecCheck, for
/// this user only. Update downloads the next setup and runs it: the setup
/// waits for LecCheck to close, installs over it and opens it again.
abstract final class WindowsInstall {
  /// The setup's log, in the updates folder: read and deleted on the next
  /// start ([reportSetupLog]).
  static const logName = 'setup.log';

  /// What the setup reaches when it installed everything.
  static const _succeeded = 'Installation process succeeded';

  /// The folder of a LecCheck the setup installed: its uninstaller sits
  /// next to leccheck.exe. Null for one run from anywhere else (flutter run,
  /// a copied folder), which the setup wouldn't replace: Download opens the
  /// release page there.
  static Future<String?> setupDir({String? executable}) async {
    if (executable == null && (kIsWeb || !Platform.isWindows)) return null;
    final dir = File(executable ?? Platform.resolvedExecutable).parent;
    final uninstaller = File(
      '${dir.path}${Platform.pathSeparator}unins000.exe',
    );
    try {
      return await uninstaller.exists() ? dir.path : null;
    } on FileSystemException {
      return null;
    }
  }

  /// How Update runs the setup: progress and errors show, its wizard pages
  /// don't; no restart of Windows; LecCheck opens again when it's done
  /// (`RELAUNCH`, read by the setup's script); a log in [log].
  static List<String> setupArguments(String log) => [
    '/SILENT',
    '/NORESTART',
    '/RELAUNCH=1',
    '/LOG=$log',
  ];

  /// Starts the [setup] on its own, so it outlives LecCheck, which quits
  /// next. Throws when Windows couldn't start it.
  static Future<void> runSetup(String setup, {required String log}) =>
      Process.start(
        windowsPath(setup),
        setupArguments(windowsPath(log)),
        mode: ProcessStartMode.detached,
      );

  /// [path] with backslashes only: the updates folder is joined with `/`,
  /// which Dart's files take on Windows but a started program's path and
  /// the setup's own arguments may not.
  static String windowsPath(String path) => path.replaceAll('/', r'\');

  /// After an update: puts the setup's outcome in the log (Settings →
  /// Developer), with the end of its log when it failed, then deletes it.
  /// Never throws.
  static Future<void> reportSetupLog(Directory updates) async {
    final file = File('${updates.path}${Platform.pathSeparator}$logName');
    try {
      if (!await file.exists()) return;
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      await file.delete();
      if (text.contains(_succeeded)) {
        debugPrint('Windows setup: the update was installed');
      } else {
        // The end of it says what went wrong.
        final lines = const LineSplitter().convert(text.trimRight());
        final tail = lines.skip(lines.length > 40 ? lines.length - 40 : 0);
        debugPrint('Windows setup did not finish:\n${tail.join('\n')}');
      }
    } on Object catch (e) {
      debugPrint('Windows setup log unreadable: $e');
    }
  }
}
