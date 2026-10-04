import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/notification_controller.dart';
import 'app/providers.dart';
import 'app/widget_controller.dart';

/// Startup does only local work: read preferences, then show UI. The
/// database opens on its own isolate; notifications are set up after the
/// first frame; nothing waits on the network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  });
}
