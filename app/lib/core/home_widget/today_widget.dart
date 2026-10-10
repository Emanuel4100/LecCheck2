import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant, Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show ColorScheme;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/background_reminders.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/theme/colors.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_service.dart';
import '../db/app_database.dart';
import '../db/schedule_repository.dart';
import '../dev/dev_log.dart';
import '../sync/sync_config.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_recorder.dart';

/// The Android "Today" home-screen widget (Jetpack Glance, see
/// android/app/src/main/kotlin/com/leccheck/app/widget/). The app writes a
/// small JSON snapshot; the widget renders it and its ✓ / ✗ buttons call
/// [todayWidgetCallback] in the background.
abstract final class TodayWidget {
  static const _receiver = 'com.leccheck.app.widget.TodayWidgetReceiver';
  static const _key = 'today';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Whether the launcher lets the app add the widget (Android 8+, most
  /// launchers).
  static Future<bool> canPin() async {
    if (!supported) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } on Object {
      return false;
    }
  }

  /// Asks the launcher to add the widget to the home screen.
  static Future<void> requestPin() =>
      HomeWidget.requestPinWidget(qualifiedAndroidName: _receiver);

  /// How many days the snapshot holds, from today: the widget picks the
  /// current one when it redraws (every 30 minutes), so it moves on to the
  /// next day at midnight even if the app isn't opened.
  static const days = 7;

  /// What the widget shows: [days] days of sessions from every semester
  /// running then ([window]), and today's at the top level too.
  static Map<String, Object?> snapshot({
    required ScheduleWindow window,
    required DateTime now,
    required AppLocalizations l,
    required Fmt fmt,
    required bool numbers,
  }) {
    final today = LocalDate.fromDateTime(now);
    // Widgets aren't themed by the app; use the light course tones.
    final palette = CourseColors.build(
      ColorScheme.fromSeed(seedColor: ThemePreset.ocean.seed),
    );
    Map<String, Object?> session(Occurrence o) {
      final course = window.courses[o.courseId];
      return {
        'meeting': o.meetingId,
        'date': o.originalDate.toIso(),
        'course': course?.name ?? '',
        'color': palette.tone(course?.colorKey ?? 'ocean').accent.toARGB32(),
        'detail': joinDetails([
          sessionTitle(o, l, numbers: numbers),
          fmt.timeRange(o.startMin, o.endMin),
          o.location,
        ]),
        'status': o.status.key,
        'statusLabel': statusLabel(o, l),
        'start': o.start.millisecondsSinceEpoch,
      };
    }

    Map<String, Object?> day(LocalDate date) {
      final semester = window.semesterOn(date);
      final calendar = semester == null ? null : SemesterCalendar(semester);
      final week = calendar?.weekNumberOf(date) ?? 0;
      return {
        'title': fmt.longDate(date),
        'subtitle': calendar == null
            ? ''
            : week >= 1 && week <= calendar.weekCount
            ? l.weekOfTotal(week, calendar.weekCount)
            : semester!.name,
        'sessions': [for (final o in window.index.onDay(date)) session(o)],
      };
    }

    return {
      ...day(today),
      'empty': l.noClassesToday,
      'stale': l.widgetStale,
      'attended': l.markAttended,
      'missed': l.markMissed,
      'rtl': l.localeName == 'he',
      'days': {
        for (var i = 0; i < days; i++)
          today.addDays(i).toIso(): day(today.addDays(i)),
      },
    };
  }

  static Future<void> push(Map<String, Object?> snapshot) async {
    if (!supported) return;
    try {
      await HomeWidget.saveWidgetData<String>(_key, jsonEncode(snapshot));
      await HomeWidget.updateWidget(qualifiedAndroidName: _receiver);
    } on Object catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  static Future<void> registerCallback() async {
    if (!supported) return;
    await HomeWidget.registerInteractivityCallback(todayWidgetCallback);
  }
}

/// Runs in the background when a widget button is pressed:
/// `leccheck://mark?meeting=…&date=…&status=attended`.
@pragma('vm:entry-point')
Future<void> todayWidgetCallback(Uri? uri) async {
  if (uri == null || uri.host != 'mark') return;
  final meeting = uri.queryParameters['meeting'];
  final date = LocalDate.tryParse(uri.queryParameters['date']);
  final status = AttendanceStatus.fromKey(uri.queryParameters['status']);
  if (meeting == null || date == null || status == null) return;

  DartPluginRegistrant.ensureInitialized();
  DevLog.start();
  DevLog.add('Widget button "${status.key}"');
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
    await repo.setStatusFor(
      meetingId: meeting,
      originalDate: date,
      status: status,
    );
    await refreshTodayWidget(repo, prefs);
    DevLog.add('Saved');
    // A marked session needs no "How was class?" any more.
    DevLog.add('Reminders topped up: ${await topUpReminders(repo, prefs)}');
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
  } on Object catch (e) {
    debugPrint('Widget action failed: $e');
  } finally {
    await db.close();
    await DevLog.flush();
  }
}

/// Rebuilds the widget snapshot straight from the database (background use).
Future<void> refreshTodayWidget(
  ScheduleRepository repo,
  SharedPreferencesWithCache prefs,
) async {
  if (!TodayWidget.supported) return;
  final now = DateTime.now();
  final today = LocalDate.fromDateTime(now);
  final window = await repo.loadWindow(
    today,
    today.addDays(TodayWidget.days - 1),
  );
  final code =
      prefs.getString('appearance.locale') ??
      PlatformDispatcher.instance.locale.languageCode;
  final locale = code == 'he' ? 'he' : 'en';
  await initializeDateFormatting(locale);
  final l = lookupAppLocalizations(Locale(locale));
  final prefsSettings = await repo.watchUserPrefs().first;
  await TodayWidget.push(
    TodayWidget.snapshot(
      window: window,
      now: now,
      l: l,
      fmt: Fmt(
        locale,
        use24h:
            prefsSettings.use24h ??
            PlatformDispatcher.instance.alwaysUse24HourFormat,
      ),
      numbers: prefsSettings.meetingNumbers,
    ),
  );
}
