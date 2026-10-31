import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/adaptive.dart';
import 'app/app.dart';
import 'app/background_reminders.dart';
import 'app/move_controller.dart';
import 'app/notification_controller.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/update_controller.dart';
import 'app/widget_controller.dart';
import 'core/dev/dev_log.dart';
import 'core/dev/frame_stats.dart';
import 'core/report/report_sender.dart';
import 'features/settings/move_dialog.dart';
import 'features/settings/report_page.dart';
import 'features/settings/update_dialog.dart';

/// Startup does only local work: read preferences, then show UI. The
/// database opens on its own isolate; notifications are set up after the
/// first frame; nothing waits on the network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DevLog.start();
  FrameStats.instance.start();
  if (AppIdiom.isAndroid) {
    // Draw behind the status and navigation bars on every Android version
    // (15+ enforces it); the theme makes the bars transparent.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['LecCheck'], _license);
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
    scheduleDailyTopUp();
    WidgetController(container).start();
    _dailySnapshots(container);
    _updateChecks(container);
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

/// Looks for a new release (at every start, and at most once a day when the
/// app comes back), and sends bug reports that waited for a connection. Offers
/// to report an error the previous session ended with. Linux installs made
/// by install.sh are asked to move to the Flatpak instead.
void _updateChecks(ProviderContainer container) {
  final moving = container.read(moveProvider.notifier).init();
  void check({bool startup = false}) {
    final updates = container.read(updateProvider.notifier);
    final move = container.read(moveProvider.notifier);
    (updates.check(startup: startup), moving).wait.then((_) async {
      // Once per launch: the move window, or while an update waits, the
      // update window.
      final router = container.read(routerProvider);
      await _pastSplash(router);
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      if (container.read(moveProvider).offered) {
        if (move.takePrompt()) showMoveDialog(context);
      } else if (updates.takePrompt()) {
        showUpdateDialog(context);
      }
    });
    if (ReportSender.available) {
      container.read(reportSenderProvider).flush().catchError((Object e) {
        debugPrint('Queued reports not sent: $e');
        return 0;
      });
    }
  }

  check(startup: true);
  AppLifecycleListener(onResume: check);
  container.read(lastErrorProvider.notifier).load();
}

/// Waits (up to 15 s) until the router has left the splash route for Today
/// or Welcome: a window opened on the splash went away with it.
Future<void> _pastSplash(GoRouter router) async {
  bool past() => router.routerDelegate.currentConfiguration.uri.path != '/';
  if (!past()) {
    final left = Completer<void>();
    void check() {
      if (past() && !left.isCompleted) left.complete();
    }

    router.routerDelegate.addListener(check);
    try {
      await left.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    } finally {
      router.routerDelegate.removeListener(check);
    }
  }
  await SchedulerBinding.instance.endOfFrame;
}

/// The app's own license notice (full text: LICENSE in the repository).
const _license = '''Copyright (C) 2026 Emanuel

LecCheck is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

LecCheck is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with LecCheck. If not, see <https://www.gnu.org/licenses/>.''';
