import 'dart:ui' show DartPluginRegistrant, Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../core/auth/auth_service.dart';
import '../core/db/app_database.dart';
import '../core/db/schedule_repository.dart';
import '../core/dev/dev_log.dart';
import '../core/notifications/notification_actions.dart';
import '../core/notifications/notification_service.dart';
import '../core/sync/sync_config.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_recorder.dart';
import '../domain/occurrence_engine.dart';
import '../domain/reminder_plan.dart';
import '../l10n/gen/app_localizations.dart';
import 'adaptive.dart';
import 'format.dart';
import 'notification_controller.dart';
import 'providers.dart';

/// Reminders are scheduled ahead (about 10 days on Android), and re-planned
/// while the app runs. Without the app, they would run out: so they're also
/// topped up here, in background isolates, after a notification button and
/// once a day from WorkManager.

const _topUpTask = 'reminderTopUp';

/// Plans and schedules reminders straight from the database, without
/// providers or UI. Returns how many are planned.
Future<int> topUpReminders(
  ScheduleRepository repo,
  SharedPreferencesWithCache prefs,
) async {
  final settings = ReminderSettingsController.read(prefs);
  if (!settings.any) return 0;
  final data = await repo.loadShownSemester(
    prefs.getString(ActiveSemesterController.key),
  );
  if (data == null) return 0;
  final code =
      prefs.getString(AppearanceController.localeKey) ??
      PlatformDispatcher.instance.locale.languageCode;
  final locale = code == 'he' ? 'he' : 'en';
  await initializeDateFormatting(locale);
  final l = lookupAppLocalizations(Locale(locale));
  final service = NotificationService.instance;
  await service.init(
    labels: notificationLabels(l),
    onResponse: (_) {},
    onBackgroundResponse: onNotificationActionInBackground,
  );
  final userPrefs = await repo.watchUserPrefs().first;
  final window = reminderWindow();
  final plan = planReminders(
    index: OccurrenceEngine.expand(
      semester: data.semester,
      meetings: data.meetings,
      overrides: data.overrides,
      noClassRanges: data.noClassRanges,
    ),
    courses: {for (final c in data.courses) c.id: c},
    meetings: {for (final m in data.meetings) m.id: m},
    settings: settings,
    texts: LocalizedReminderTexts(
      l,
      Fmt(
        locale,
        use24h:
            userPrefs.use24h ??
            PlatformDispatcher.instance.alwaysUse24HourFormat,
      ),
    ),
    now: DateTime.now(),
    limit: window.limit,
    horizonDays: window.horizonDays,
  );
  await service.apply(plan);
  return plan.length;
}

/// Runs in a background isolate when a notification button is pressed while
/// the app isn't running: records the status (shared database), tries a
/// quick HTTP sync so other devices see it right away, then tops up the
/// reminders.
@pragma('vm:entry-point')
Future<void> onNotificationActionInBackground(
  NotificationResponse response,
) async {
  if (statusForAction(response.actionId) == null) return;
  DartPluginRegistrant.ensureInitialized();
  DevLog.start();
  DevLog.add('Notification button "${response.actionId}" (app closed)');
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  final db = AppDatabase();
  try {
    final repo = ScheduleRepository(db);
    final attached = prefs.getString(SyncRecorder.attachedAccountKey) != null;
    final recorder = SyncConfig.enabled && attached
        ? SyncRecorder(db: db, prefs: prefs)
        : null;
    repo.recorder = recorder;
    if (!await markFromNotification(response, repo)) return;
    DevLog.add('Saved');
    if (recorder != null) {
      final session = await AuthService().load();
      if (session != null) {
        await SyncEngine.syncOverHttp(
          db: db,
          repo: repo,
          recorder: recorder,
          session: session,
        );
        DevLog.add('Synced');
      }
    }
    DevLog.add('Reminders topped up: ${await topUpReminders(repo, prefs)}');
  } on Object catch (e) {
    debugPrint('Notification action failed: $e');
  } finally {
    await db.close();
    await DevLog.flush();
  }
}

/// WorkManager's entry point (its own isolate): the daily top-up.
@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, _) async {
    DartPluginRegistrant.ensureInitialized();
    DevLog.start();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final db = AppDatabase();
    try {
      final count = await topUpReminders(ScheduleRepository(db), prefs);
      DevLog.add('Daily top-up: $count reminders planned');
      return true;
    } on Object catch (e) {
      debugPrint('Daily top-up failed: $e');
      return false;
    } finally {
      await db.close();
      await DevLog.flush();
    }
  });
}

/// Registers the daily top-up (Android) at each start; WorkManager keeps it
/// across reboots and app updates, and runs it when the phone allows.
Future<void> scheduleDailyTopUp() async {
  if (!AppIdiom.isAndroid) return;
  try {
    await Workmanager().initialize(backgroundTaskDispatcher);
    await Workmanager().registerPeriodicTask(
      _topUpTask,
      _topUpTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } on Object catch (e) {
    debugPrint('Could not schedule the daily reminder top-up: $e');
  }
}
