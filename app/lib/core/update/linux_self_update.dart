import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';

import 'update_download.dart';

/// Updates the Linux app that install.sh put in `$XDG_DATA_HOME/leccheck`,
/// with the next release's tarball and its own install.sh.
abstract final class LinuxSelfUpdate {
  /// The folder install.sh installed LecCheck in, when this app runs from
  /// there and may replace it. Null for other builds (flutter run, a distro
  /// package): their update card opens the browser instead.
  static Future<String?> installDir() async {
    if (!Platform.isLinux) return null;
    final env = Platform.environment;
    final home = env['HOME'];
    final xdg = env['XDG_DATA_HOME'];
    // Like install.sh's ${XDG_DATA_HOME:-$HOME/.local/share}.
    final data = xdg != null && xdg.isNotEmpty
        ? xdg
        : home == null
        ? null
        : '$home/.local/share';
    if (data == null) return null;
    final dir = '$data/leccheck';
    try {
      final installed = await File('$dir/leccheck').resolveSymbolicLinks();
      final running = await File(Platform.resolvedExecutable)
          .resolveSymbolicLinks();
      if (installed != running) return null;
      // install.sh swaps the folder, so its parent must be writable.
      final probe = File('$data/.leccheck-update-probe');
      await probe.writeAsString('');
      await probe.delete();
      return dir;
    } on FileSystemException {
      return null;
    }
  }

  /// Installs the verified [tarball]: extracts it next to itself and runs
  /// the install.sh inside (the new version's, which swaps the app's files).
  /// The running app keeps its old files until it quits. Throws
  /// [UpdateFailed] with the script's output.
  static Future<void> install(File tarball) async {
    final extract = Directory('${tarball.parent.path}/extract');
    try {
      if (await extract.exists()) await extract.delete(recursive: true);
      await extract.create(recursive: true);
      final tar = await Process.run('tar', [
        '-xzf',
        tarball.path,
        '-C',
        extract.path,
      ]);
      if (tar.exitCode != 0) throw UpdateFailed('tar: ${tar.stderr}');
      // One folder: LecCheck-<version>-linux-x64.
      final roots = await extract.list().where((e) => e is Directory).toList();
      final script = roots.length == 1
          ? File('${roots.single.path}/install.sh')
          : null;
      if (script == null || !await script.exists()) {
        throw const UpdateFailed('No install.sh in the tarball');
      }
      final run = await Process.run('bash', [script.path]);
      if (run.exitCode != 0) {
        throw UpdateFailed('install.sh: ${run.stdout}${run.stderr}');
      }
    } on ProcessException catch (e) {
      throw UpdateFailed('$e');
    } finally {
      try {
        if (await extract.exists()) await extract.delete(recursive: true);
      } on FileSystemException {
        // Removed with the other downloads once the app is up to date.
      }
    }
  }

  /// Quits, then starts the installed version from [dir]. LecCheck runs as
  /// a single instance: one started while this one still runs would hand
  /// over to it and exit, so a shell waits for this process to end first.
  static Future<void> restart(String dir) async {
    await Process.start('sh', [
      '-c',
      r'while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; exec "$2"',
      'sh',
      '$pid',
      '$dir/leccheck',
    ], mode: ProcessStartMode.detached);
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  }
}
