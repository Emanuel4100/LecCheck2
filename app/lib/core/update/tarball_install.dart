import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// LecCheck installed from the release tarball by install.sh, into
/// `$XDG_DATA_HOME/leccheck`. Since 2.0.0-beta.15 Linux releases are a
/// Flatpak, and such an install moves to it: [installFlatpak], [uninstall]
/// (the data stays), then [startAfterExit] opens the Flatpak.
abstract final class TarballInstall {
  static const appId = 'com.leccheck.app';

  /// LecCheck's Flatpak repository: installing this adds it as a remote.
  /// A test build can point elsewhere (`--dart-define=FLATPAK_REF=…`).
  static const flatpakRef = String.fromEnvironment(
    'FLATPAK_REF',
    defaultValue: 'https://emanuel4100.github.io/LecCheck2/leccheck.flatpakref',
  );

  /// The folder install.sh installed LecCheck in, when this app runs from
  /// there. Null for other builds (flutter run, a distro package, the
  /// Flatpak).
  static Future<String?> installDir() async {
    if (!Platform.isLinux) return null;
    final data = _dataHome();
    if (data == null) return null;
    final dir = '$data/leccheck';
    try {
      final installed = await File('$dir/leccheck').resolveSymbolicLinks();
      final running = await File(Platform.resolvedExecutable)
          .resolveSymbolicLinks();
      return installed == running ? dir : null;
    } on FileSystemException {
      return null;
    }
  }

  /// Where this version keeps its data, which stays after the move: `~`
  /// for the home folder.
  static String dataFolder() {
    final path = '${_dataHome() ?? '~/.local/share'}/$appId';
    final home = Platform.environment['HOME'];
    return home != null && path.startsWith('$home/')
        ? '~${path.substring(home.length)}'
        : path;
  }

  /// Like install.sh's `${XDG_DATA_HOME:-$HOME/.local/share}`.
  static String? _dataHome() {
    final env = Platform.environment;
    final xdg = env['XDG_DATA_HOME'];
    if (xdg != null && xdg.isNotEmpty) return xdg;
    final home = env['HOME'];
    return home == null ? null : '$home/.local/share';
  }

  /// Flatpak's version (`flatpak --version`), or null when it isn't
  /// installed.
  static Future<String?> flatpakVersion() async {
    try {
      final result = await Process.run('flatpak', ['--version']);
      return result.exitCode == 0 ? '${result.stdout}'.trim() : null;
    } on ProcessException {
      return null;
    }
  }

  /// Whether the Flatpak is installed already (for this user or the
  /// system).
  static Future<bool> flatpakInstalled() async {
    try {
      final result = await Process.run('flatpak', ['info', appId]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Installs the Flatpak for this user from [flatpakRef] (no password; its
  /// runtime comes from Flathub, which is added if needed). [onOutput]
  /// gets each line flatpak prints. Throws [ProcessException] with the
  /// last lines when it fails.
  static Future<void> installFlatpak({
    void Function(String line)? onOutput,
  }) async {
    final process = await Process.start('flatpak', [
      'install',
      '--user',
      '--noninteractive',
      '-y',
      '--from',
      flatpakRef,
    ]);
    final last = <String>[];
    void line(String text) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;
      last.add(trimmed);
      if (last.length > 5) last.removeAt(0);
      onOutput?.call(trimmed);
    }

    // Progress is redrawn on one line with \r.
    final lines = RegExp(r'[\r\n]');
    final out = process.stdout
        .transform(utf8.decoder)
        .expand((text) => text.split(lines))
        .forEach(line);
    final err = process.stderr
        .transform(utf8.decoder)
        .expand((text) => text.split(lines))
        .forEach(line);
    final code = await process.exitCode;
    await (out, err).wait;
    if (code != 0) {
      throw ProcessException('flatpak', ['install'], last.join('\n'), code);
    }
  }

  /// Removes what install.sh installed in [dir] and around it (launcher
  /// entry, icons, `~/.local/bin/leccheck`), like `install.sh uninstall`.
  /// The data in `$XDG_DATA_HOME/com.leccheck.app` stays. The running app
  /// keeps its files open until it quits.
  static Future<void> uninstall(
    String dir, {
    @visibleForTesting String? dataHome,
    @visibleForTesting String? home,
  }) async {
    final data = dataHome ?? _dataHome();
    home ??= Platform.environment['HOME'];
    Future<void> remove(FileSystemEntity entity) async {
      try {
        if (await entity.exists()) await entity.delete(recursive: true);
      } on FileSystemException catch (e) {
        throw ProcessException('rm', [entity.path], '$e', 1);
      }
    }

    // The command only when it's install.sh's link to this install.
    if (home != null) {
      final link = Link('$home/.local/bin/leccheck');
      if (await link.exists() && await link.target() == '$dir/leccheck') {
        await link.delete();
      }
    }
    // The launcher entry first: until it's gone, it hides the Flatpak's.
    if (data != null) {
      await remove(File('$data/applications/$appId.desktop'));
      await remove(File('$data/metainfo/$appId.metainfo.xml'));
      for (final size in [64, 128, 256, 512]) {
        await remove(File('$data/icons/hicolor/${size}x$size/apps/$appId.png'));
      }
    }
    for (final path in [dir, '$dir.new', '$dir.old']) {
      await remove(Directory(path));
    }
    if (data != null) {
      await _quietly('update-desktop-database', ['$data/applications']);
      if (await File('$data/icons/hicolor/index.theme').exists()) {
        await _quietly('gtk-update-icon-cache', ['-q', '$data/icons/hicolor']);
      }
    }
  }

  static Future<void> _quietly(String command, List<String> args) async {
    try {
      await Process.run(command, args);
    } on ProcessException {
      // Not installed: launchers notice the change by themselves.
    }
  }

  /// Quits, then runs [command]. LecCheck runs as a single instance (the
  /// Flatpak too, under the same app id): one started while this one still
  /// runs would hand over to it and exit, so a shell waits for this process
  /// to end first. Ended counts from when it's a zombie (state Z), which a
  /// parent may not reap for a while: `kill -0` still succeeds then.
  static Future<void> startAfterExit(List<String> command) async {
    await Process.start('sh', [
      '-c',
      r'alive() { s=$(sed "s/.*) //" "/proc/$1/stat" 2>/dev/null | cut -d" " -f1); '
          r'[ -n "$s" ] && [ "$s" != Z ]; }; '
          r'while alive "$1"; do sleep 0.2; done; shift; exec "$@"',
      'sh',
      '$pid',
      ...command,
    ], mode: ProcessStartMode.detached);
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  }
}
