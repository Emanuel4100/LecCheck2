import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant, Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart' show ColorScheme;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/theme/colors.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/occurrence_engine.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../domain/semester_data.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/auth_service.dart';
import '../db/app_database.dart';
import '../db/schedule_repository.dart';
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

  static Map<String, Object?> snapshot({
    required SemesterData data,
    required OccurrenceIndex index,
    required DateTime now,
    required AppLocalizations l,
    required Fmt fmt,
    required bool numbers,
  }) {
    final today = LocalDate.fromDateTime(now);
    final calendar = SemesterCalendar(data.semester);
    final week = calendar.weekNumberOf(today);
    final courses = {for (final c in data.courses) c.id: c};
    // Widgets aren't themed by the app; use the light course tones.
    final palette = CourseColors.build(
      ColorScheme.fromSeed(seedColor: ThemePreset.ocean.seed),
    );
    Map<String, Object?> session(Occurrence o) {
      final course = courses[o.courseId];
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

    return {
      'title': fmt.longDate(today),
      'subtitle': week >= 1 && week <= calendar.weekCount
          ? l.weekOfTotal(week, calendar.weekCount)
          : data.semester.name,
      'empty': l.noClassesToday,
      'attended': l.markAttended,
      'missed': l.markMissed,
      'rtl': l.localeName == 'he',
      'sessions': [for (final o in index.onDay(today)) session(o)],
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
    if (recorder != null) {
      final session = await AuthService().load();
      if (session != null) {
        await SyncEngine.syncOverHttp(
          db: db,
          repo: repo,
          recorder: recorder,
          session: session,
        );
      }
    }
  } on Object catch (e) {
    debugPrint('Widget action failed: $e');
  } finally {
    await db.close();
  }
}

/// Rebuilds the widget snapshot straight from the database (background use).
Future<void> refreshTodayWidget(
  ScheduleRepository repo,
  SharedPreferencesWithCache prefs,
) async {
  final semesters = await repo.semesters();
  if (semesters.isEmpty) return;
  final chosen = prefs.getString('semester.active');
  final semester = semesters.firstWhere(
    (s) => s.id == chosen,
    orElse: () => semesters.first,
  );
  final data = await repo.loadSemesterData(semester.id);
  if (data == null) return;
  final code =
      prefs.getString('appearance.locale') ??
      PlatformDispatcher.instance.locale.languageCode;
  final locale = code == 'he' ? 'he' : 'en';
  await initializeDateFormatting(locale);
  final l = lookupAppLocalizations(Locale(locale));
  final prefsSettings = await repo.watchUserPrefs().first;
  await TodayWidget.push(
    TodayWidget.snapshot(
      data: data,
      index: OccurrenceEngine.expand(
        semester: data.semester,
        meetings: data.meetings,
        overrides: data.overrides,
        noClassRanges: data.noClassRanges,
      ),
      now: DateTime.now(),
      l: l,
      fmt: Fmt(locale, use24h: prefsSettings.use24h ?? true),
      numbers: prefsSettings.meetingNumbers,
    ),
  );
}
