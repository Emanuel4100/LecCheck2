import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// LecCheck installed as a Flatpak: what its sandbox says about itself.
abstract final class Flatpak {
  /// Whether this app runs in a Flatpak sandbox.
  static bool get running => info != null;

  /// The sandbox's /.flatpak-info as `group.key` → value (e.g.
  /// `Application.name`, `Instance.app-commit`); null outside Flatpak.
  static final Map<String, String>? info = _read();

  static Map<String, String>? _read() {
    if (!Platform.isLinux) return null;
    try {
      return parseInfo(File('/.flatpak-info').readAsStringSync());
    } on FileSystemException {
      return null;
    }
  }

  /// The keys of a GKeyFile like /.flatpak-info.
  @visibleForTesting
  static Map<String, String> parseInfo(String text) {
    final keys = <String, String>{};
    var group = '';
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        group = line.substring(1, line.length - 1);
      } else if (line.indexOf('=') case final at when at > 0) {
        keys['$group.${line.substring(0, at).trim()}'] = line
            .substring(at + 1)
            .trim();
      }
    }
    return keys;
  }
}

/// How the Flatpak portal's update is going.
enum FlatpakStatus {
  running,

  /// Nothing to install: the repository has no newer version (yet).
  empty,
  done,
  failed,
}

/// One `Progress` signal of the portal's update monitor.
@immutable
class FlatpakProgress {
  const FlatpakProgress(
    this.status, {
    this.op = 0,
    this.ops = 0,
    this.percent = 0,
    this.error,
    this.message,
  });

  /// From the signal's `a{sv}`: `status`, and while it runs `op` (0-based),
  /// `n_ops` and `progress` (0–100, 100 once an operation is done); `error`
  /// and `error_message` when it failed.
  factory FlatpakProgress.fromDBus(Map<String, DBusValue> info) {
    int number(String key) => switch (info[key]) {
      DBusUint32(:final value) || DBusInt32(:final value) => value,
      _ => 0,
    };
    String? text(String key) => switch (info[key]) {
      DBusString(:final value) when value.isNotEmpty => value,
      _ => null,
    };
    final status = number('status');
    return FlatpakProgress(
      status < FlatpakStatus.values.length
          ? FlatpakStatus.values[status]
          : FlatpakStatus.failed,
      op: number('op'),
      ops: number('n_ops'),
      percent: number('progress'),
      error: text('error'),
      message: text('error_message'),
    );
  }

  final FlatpakStatus status;
  final int op;
  final int ops;
  final int percent;

  /// The D-Bus error's name, e.g. `org.freedesktop.DBus.Error.AccessDenied`
  /// (LecCheck may not update itself) or `…NotSupported` (the new version
  /// needs new permissions).
  final String? error;
  final String? message;

  /// 0–1 over all operations; null until the portal knows how many.
  double? get fraction {
    if (status == FlatpakStatus.done) return 1;
    if (ops <= 0) return null;
    return ((op.clamp(0, ops - 1) + percent.clamp(0, 100) / 100) / ops).clamp(
      0.0,
      1.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FlatpakProgress &&
      other.status == status &&
      other.op == op &&
      other.ops == ops &&
      other.percent == percent &&
      other.error == error &&
      other.message == message;

  @override
  int get hashCode => Object.hash(status, op, ops, percent, error, message);

  @override
  String toString() =>
      'FlatpakProgress($status, op $op of $ops, $percent%'
      '${error == null ? '' : ', $error: $message'})';
}

/// org.freedesktop.portal.Flatpak, through which a Flatpak app updates and
/// restarts itself. Every sandbox may call it.
abstract final class FlatpakPortal {
  static const _name = 'org.freedesktop.portal.Flatpak';
  static const _interface = 'org.freedesktop.portal.Flatpak';
  static const _monitor = 'org.freedesktop.portal.Flatpak.UpdateMonitor';

  /// Spawn's FLATPAK_SPAWN_FLAGS_LATEST_VERSION: the newest installed
  /// version, not this one.
  static const _latestVersion = 2;

  /// Installs the newest version from the repository LecCheck came from:
  /// the portal downloads it, checks its signature (the repository is
  /// GPG-signed), and deploys it. The first time, the desktop asks whether
  /// LecCheck may update itself. Ends with [FlatpakStatus.done],
  /// [FlatpakStatus.empty] or [FlatpakStatus.failed]; cancelling the
  /// subscription stops the update.
  static Stream<FlatpakProgress> update() async* {
    final client = DBusClient.session();
    DBusRemoteObject? monitor;
    try {
      final portal = DBusRemoteObject(
        client,
        name: _name,
        path: DBusObjectPath('/org/freedesktop/portal/Flatpak'),
      );
      final created = await portal.callMethod(
        _interface,
        'CreateUpdateMonitor',
        [DBusDict.stringVariant({})],
        replySignature: DBusSignature('o'),
      );
      monitor = DBusRemoteObject(
        client,
        name: _name,
        path: created.returnValues.single.asObjectPath(),
      );
      final signals = StreamController<FlatpakProgress>();
      final subscription =
          DBusRemoteObjectSignalStream(
                object: monitor,
                interface: _monitor,
                name: 'Progress',
                signature: DBusSignature('a{sv}'),
              )
              .map(
                (s) => FlatpakProgress.fromDBus(
                  s.values.single.asStringVariantDict(),
                ),
              )
              .listen(signals.add, onError: signals.addError);
      try {
        // A round trip through the bus after subscribing: the bus has the
        // match rule for Progress by then, so no signal can come before it.
        await portal.getProperty(_interface, 'version');
        // Returns at once; the rest comes as Progress signals.
        await monitor.callMethod(_monitor, 'Update', [
          const DBusString(''),
          DBusDict.stringVariant({}),
        ], replySignature: DBusSignature(''));
        await for (final progress in signals.stream) {
          yield progress;
          if (progress.status != FlatpakStatus.running) break;
        }
      } finally {
        await subscription.cancel();
      }
    } finally {
      // Ends the monitor, and with it an update still running (Cancel).
      try {
        await monitor?.callMethod(
          _monitor,
          'Close',
          const [],
          replySignature: DBusSignature(''),
        );
      } on Object catch (e) {
        debugPrint('Flatpak update monitor not closed: $e');
      }
      await client.close();
    }
  }

  /// Starts the newest installed version of LecCheck in a new sandbox,
  /// with `--after-update`: the runner then waits for this one to quit
  /// before it registers, since LecCheck runs as a single instance.
  static Future<void> startLatest() async {
    DBusArray bytes(String text) => DBusArray.byte([...utf8.encode(text), 0]);
    final client = DBusClient.session();
    try {
      await DBusRemoteObject(
        client,
        name: _name,
        path: DBusObjectPath('/org/freedesktop/portal/Flatpak'),
      ).callMethod(_interface, 'Spawn', [
        bytes(''), // the portal's working directory
        // argv[0] is the command in the sandbox (flatpak run --command=).
        DBusArray(DBusSignature('ay'), [
          bytes('leccheck'),
          bytes('--after-update'),
        ]),
        DBusDict(DBusSignature('u'), DBusSignature('h')),
        DBusDict(DBusSignature('s'), DBusSignature('s')),
        const DBusUint32(_latestVersion),
        DBusDict.stringVariant({}),
      ], replySignature: DBusSignature('u'));
    } finally {
      await client.close();
    }
  }
}
