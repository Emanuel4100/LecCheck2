/// Build-time sync settings, passed with `--dart-define`:
///
/// ```sh
/// flutter run --dart-define=API_BASE_URL=https://leccheck-sync.YOU.workers.dev
/// flutter run --dart-define=API_BASE_URL=http://localhost:8787 --dart-define=DEV_AUTH=true
/// ```
abstract final class SyncConfig {
  static const apiBase = String.fromEnvironment('API_BASE_URL');

  /// Enables "dev sign-in" against a local `wrangler dev` server.
  static const devAuth = bool.fromEnvironment('DEV_AUTH');

  static bool get enabled => apiBase.isNotEmpty;

  static Uri api(String path) => Uri.parse('$apiBase$path');

  static Uri socket(String path) =>
      Uri.parse(apiBase.replaceFirst(RegExp('^http'), 'ws') + path);
}
