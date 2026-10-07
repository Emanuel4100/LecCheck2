import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A small log kept on the device, for testing on real phones without a
/// cable (Settings → Developer → Log): errors, and what background tasks did.
///
/// It lives in a file, so notification and widget buttons pressed while the
/// app was closed (handled in another isolate) show up too. It stays on the
/// device (not in Android's backup) unless the user copies it.
abstract final class DevLog {
  static const fileName = 'dev_log.txt';
  static const _maxBytes = 64 * 1024;

  static Future<File?>? _file;
  static Future<void> _writes = Future.value();
  static bool _inFlutterError = false;

  /// Starts logging: every `debugPrint` and uncaught error from now on, and
  /// [add]. Doesn't wait for the file, so startup isn't delayed.
  static void start() {
    if (_file != null) return;
    _file = _open();
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      print(message, wrapWidth: wrapWidth);
      // Flutter prints each error it reports; the short form is logged below.
      if (message != null && !_inFlutterError) add(message);
    };
    final flutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      add('Error: ${details.exceptionAsString()}${_brief(details.stack)}');
      _inFlutterError = true;
      try {
        flutterError?.call(details);
      } finally {
        _inFlutterError = false;
      }
    };
    final platformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      add('Uncaught: $error${_brief(stack)}');
      return platformError?.call(error, stack) ?? false;
    };
  }

  static Future<File?> _open() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$fileName');
    } on Object {
      return null;
    }
  }

  /// Appends a line (no-op until [start]).
  static void add(String message) {
    final file = _file;
    if (file == null) return;
    final line = '${_stamp(DateTime.now())} ${message.trimRight()}\n';
    _writes = _writes
        .then((_) async {
          final f = await file;
          if (f == null) return;
          await f.writeAsString(line, mode: FileMode.append);
          if (await f.length() > _maxBytes) await _trim(f);
        })
        .catchError((Object _) {});
  }

  /// Waits until every line so far is written (before a background isolate
  /// ends).
  static Future<void> flush() => _writes;

  /// The whole log, oldest line first.
  static Future<String> read() async {
    await flush();
    final f = await (_file ?? _open());
    try {
      return f != null && await f.exists() ? await f.readAsString() : '';
    } on Object {
      return '';
    }
  }

  static Future<void> clear() async {
    await flush();
    final f = await (_file ?? _open());
    try {
      if (f != null && await f.exists()) await f.delete();
    } on Object {
      // Nothing to clear.
    }
  }

  /// Keeps the newest lines (up to 16K characters, under half the limit
  /// even in Hebrew).
  static Future<void> _trim(File f) async {
    final text = await f.readAsString();
    final cut = text.indexOf('\n', math.max(0, text.length - 16 * 1024));
    await f.writeAsString(cut == -1 ? '' : text.substring(cut + 1));
  }

  static String _brief(StackTrace? stack) {
    if (stack == null) return '';
    final lines = stack.toString().trimRight().split('\n').take(4);
    return '\n  ${lines.join('\n  ')}';
  }

  static String _stamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
