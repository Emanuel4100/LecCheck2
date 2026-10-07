import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/adaptive.dart';
import 'app/app.dart';
import 'app/notification_controller.dart';
import 'app/providers.dart';
import 'app/widget_controller.dart';

/// Startup does only local work: read preferences, then show UI. The
/// database opens on its own isolate; notifications are set up after the
/// first frame; nothing waits on the network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppIdiom.isAndroid) {
    // Draw behind the status and navigation bars on every Android version
    // (15+ enforces it); the theme makes the bars transparent.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Rubik'], ofl);
  });
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  final container = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const LecCheckApp()),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationController(container).start();
    WidgetController(container).start();
    _dailySnapshots(container);
  });
}

/// Saves the day's automatic backup at startup, and when the app comes back
/// after a day in the background.
void _dailySnapshots(ProviderContainer container) {
  void take() => container
      .read(snapshotServiceProvider)
      .takeDailyIfDue()
      .catchError((Object e) => debugPrint('Daily snapshot failed: $e'));
  take();
  AppLifecycleListener(onResume: take);
}
