/// The part of desktop_webview_window 0.3.0's API that flutter_web_auth_2
/// uses, with no webview behind it (see pubspec.yaml). If flutter_web_auth_2
/// starts using more of it, the build fails here instead of the app.
library;

/// Never available, so flutter_web_auth_2 refuses webview sign-in, which
/// LecCheck never asks for.
abstract final class WebviewWindow {
  static Future<bool> isWebviewAvailable() async => false;

  static Future<Webview> create({CreateConfiguration? configuration}) =>
      Future.error(UnsupportedError('LecCheck has no webview'));
}

class CreateConfiguration {
  const CreateConfiguration({
    this.windowWidth = 1280,
    this.windowHeight = 720,
    this.windowPosX = 0,
    this.windowPosY = 0,
    this.title = '',
    this.titleBarHeight = 40,
    this.titleBarTopPadding = 0,
    this.userDataFolderWindows = 'webview_window_WebView2',
    this.useWindowPositionAndSize = false,
    this.openMaximized = false,
  });

  final int windowWidth;
  final int windowHeight;
  final int windowPosX;
  final int windowPosY;
  final String title;
  final int titleBarHeight;
  final int titleBarTopPadding;
  final String userDataFolderWindows;
  final bool useWindowPositionAndSize;
  final bool openMaximized;
}

typedef OnUrlRequestCallback = bool Function(String url);

abstract class Webview {
  Future<void> get onClose;

  void setOnUrlRequestCallback(OnUrlRequestCallback? callback);

  void launch(String url, {bool triggerOnUrlRequestEvent = true});

  void close();
}
