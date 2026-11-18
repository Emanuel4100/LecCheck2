import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Draws the Windows title bar dark or light with LecCheck's theme rather
/// than Windows' own app mode, so a dark LecCheck on a light Windows doesn't
/// get a white bar. Elsewhere it's just [child].
///
/// The runner answers `setDark` on `com.leccheck.app/window`
/// (windows/runner/flutter_window.cpp).
class WindowFrameTheme extends StatefulWidget {
  const WindowFrameTheme({
    super.key,
    required this.brightness,
    required this.child,
  });

  final Brightness brightness;
  final Widget child;

  static const channel = MethodChannel('com.leccheck.app/window');

  /// Only the Windows runner has the channel.
  @visibleForTesting
  static bool enabled = !kIsWeb && Platform.isWindows;

  @override
  State<WindowFrameTheme> createState() => _WindowFrameThemeState();
}

class _WindowFrameThemeState extends State<WindowFrameTheme> {
  Brightness? _sent;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void didUpdateWidget(WindowFrameTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    _send();
  }

  void _send() {
    final brightness = widget.brightness;
    if (!WindowFrameTheme.enabled || brightness == _sent) return;
    _sent = brightness;
    WindowFrameTheme.channel
        .invokeMethod<void>('setDark', brightness == Brightness.dark)
        .catchError((Object e) {
          // Only the bar's color: the window works either way.
          debugPrint('Title bar theme not set: $e');
        });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
