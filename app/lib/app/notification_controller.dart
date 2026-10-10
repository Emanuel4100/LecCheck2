import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/schedule_repository.dart';
import '../core/notifications/notification_actions.dart';
import '../core/notifications/notification_service.dart';
import 'adaptive.dart';
import 'background_reminders.dart';
import '../domain/local_date.dart';
import '../domain/occurrence.dart';
import '../domain/reminder_plan.dart';
import '../domain/schedule_types.dart';
import '../features/session/session_actions.dart';
import '../l10n/gen/app_localizations.dart';
import 'format.dart';
import 'labels.dart';
import 'providers.dart';
import 'router.dart';

/// Reminder preferences (per device).
class ReminderSettingsController extends Notifier<ReminderSettings> {
  static const _before = 'notify.before';
  static const _beforeMin = 'notify.beforeMin';
  static const _after = 'notify.after';
  static const _afterMin = 'notify.afterMin';
  static const _muted = 'notify.muted';

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  /// The saved settings, also for background work without providers.
  static ReminderSettings read(SharedPreferencesWithCache prefs) =>
      ReminderSettings(
        before: prefs.getBool(_before) ?? false,
        beforeMinutes: prefs.getInt(_beforeMin) ?? 10,
        after: prefs.getBool(_after) ?? false,
        afterMinutes: prefs.getInt(_afterMin) ?? 5,
        mutedCourses: {...?prefs.getStringList(_muted)},
      );

  @override
  ReminderSettings build() => read(_prefs);

  void update({
    bool? before,
    int? beforeMinutes,
    bool? after,
    int? afterMinutes,
    Set<String>? mutedCourses,
  }) {
    state = ReminderSettings(
      before: before ?? state.before,
      beforeMinutes: beforeMinutes ?? state.beforeMinutes,
      after: after ?? state.after,
      afterMinutes: afterMinutes ?? state.afterMinutes,
      mutedCourses: mutedCourses ?? state.mutedCourses,
    );
    _prefs
      ..setBool(_before, state.before)
      ..setInt(_beforeMin, state.beforeMinutes)
      ..setBool(_after, state.after)
      ..setInt(_afterMin, state.afterMinutes)
      ..setStringList(_muted, state.mutedCourses.toList()..sort());
  }

  /// Turns reminders off (or back on) for one course.
  void setMuted(String courseId, bool muted) => update(
    mutedCourses: muted
        ? {...state.mutedCourses, courseId}
        : ({...state.mutedCourses}..remove(courseId)),
  );
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsController, ReminderSettings>(
      ReminderSettingsController.new,
    );

/// What can stop reminders on this device ([NotificationService.health]),
/// checked once notifications are set up (after the first frame) and
/// whenever the app comes back (e.g. from the system settings). Unknown until
/// then.
class ReminderHealthController extends Notifier<ReminderHealth> {
  @override
  ReminderHealth build() {
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(lifecycle.dispose);
    return const ReminderHealth();
  }

  Future<ReminderHealth> refresh() async {
    final health = await NotificationService.instance.health();
    if (ref.mounted) state = health;
    return health;
  }
}

final reminderHealthProvider =
    NotifierProvider<ReminderHealthController, ReminderHealth>(
      ReminderHealthController.new,
    );

/// How far ahead reminders are scheduled. iOS keeps at most 64 pending
/// notifications. Android has no such cap, but the notifications plugin
/// rewrites its whole list for each one, so about 100 (10 days of a full
/// timetable with both reminders); the daily background top-up keeps them
/// coming.
({int limit, int horizonDays}) reminderWindow() => AppIdiom.isAndroid
    ? (limit: 100, horizonDays: 21)
    : (limit: 60, horizonDays: 14);

/// The channel names and buttons in [l]'s language.
NotificationLabels notificationLabels(AppLocalizations l) => NotificationLabels(
  channelBefore: l.channelBefore,
  channelAfter: l.channelAfter,
  attended: l.markAttended,
  missed: l.markMissed,
  watched: l.markWatched,
  openLink: l.openLink,
);

/// Reminder texts in the app's language.
class LocalizedReminderTexts implements ReminderTexts {
  LocalizedReminderTexts(this.l, this.fmt);
  final AppLocalizations l;
  final Fmt fmt;

  @override
  String beforeTitle(Occurrence s, CourseInfo c, int minutes) =>
      l.notifyBeforeTitle(c.name, s.type.label(l), minutes);

  @override
  String beforeBody(Occurrence s, CourseInfo c) =>
      joinDetails([fmt.timeRange(s.startMin, s.endMin), s.location]);

  @override
  String afterTitle(Occurrence s, CourseInfo c) => l.notifyAfterTitle(c.name);

  @override
  String afterBody(Occurrence s, CourseInfo c) => joinDetails([
    sessionTitle(s, l, numbers: true),
    fmt.timeRange(s.startMin, s.endMin),
  ]);
}

/// Keeps scheduled reminders in step with the data, and handles taps and
/// action buttons while the app is running. Started after the first frame,
/// so notification setup never delays startup.
class NotificationController {
  NotificationController(this.container, {NotificationService? service})
    : service = service ?? NotificationService.instance;

  /// The one `main` started (Settings → Developer reschedules with it).
  static NotificationController? current;

  final ProviderContainer container;
  final NotificationService service;
  Timer? _debounce;
  Timer? _hourly;
  AppLifecycleListener? _lifecycle;
  StreamSubscription<void>? _changes;

  AppLocalizations get _l {
    final code =
        container.read(appearanceProvider).localeCode ??
        PlatformDispatcher.instance.locale.languageCode;
    return lookupAppLocalizations(Locale(code == 'he' ? 'he' : 'en'));
  }

  Future<void> start() async {
    current = this;
    await service.init(
      labels: notificationLabels(_l),
      onResponse: _onResponse,
      onBackgroundResponse: onNotificationActionInBackground,
    );
    unawaited(container.read(reminderHealthProvider.notifier).refresh());
    void replan(Object? _, Object? _) => schedule();
    // Any semester's data (reminders cover every semester running soon, not
    // only the one shown), from this device or synced.
    _changes = container
        .read(repositoryProvider)
        .watchAnyChange()
        .listen((_) => schedule());
    container
      ..listen(reminderSettingsProvider, replan)
      ..listen(userPrefsProvider, replan)
      ..listen(appearanceProvider, (_, _) {
        // New language: rename the channels, then re-plan the texts.
        service.init(
          labels: notificationLabels(_l),
          onResponse: _onResponse,
          onBackgroundResponse: onNotificationActionInBackground,
        );
        schedule();
      });
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => schedule());
    // Coming back after a while: the day moved on, or the alarms are gone.
    _lifecycle = AppLifecycleListener(onResume: schedule);
    schedule();
    final launch = await service.launchResponse();
    if (launch != null) await _onResponse(launch);
  }

  void dispose() {
    _debounce?.cancel();
    _hourly?.cancel();
    _lifecycle?.dispose();
    _changes?.cancel();
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _apply);
  }

  /// Plans and reschedules every reminder right away (Settings →
  /// Developer). Returns how many.
  Future<int> rescheduleNow() {
    _debounce?.cancel();
    return _apply(force: true);
  }

  /// Plans from the database: every semester running in the next
  /// [reminderWindow] days, whichever one the app shows (looking at last
  /// semester's stats mustn't stop this semester's reminders).
  Future<int> _apply({bool force = false}) async {
    final settings = container.read(reminderSettingsProvider);
    if (!settings.any) {
      await service.cancelReminders();
      return 0;
    }
    final now = DateTime.now();
    final today = LocalDate.fromDateTime(now);
    final window = reminderWindow();
    final ScheduleWindow schedule;
    try {
      schedule = await container
          .read(repositoryProvider)
          .loadWindow(today, today.addDays(window.horizonDays));
    } on Object catch (e) {
      // Keep what's scheduled; the next change or hour tries again.
      debugPrint('Reminders not planned: $e');
      return 0;
    }
    final l = _l;
    final use24h =
        container.read(userPrefsProvider).value?.use24h ??
        PlatformDispatcher.instance.alwaysUse24HourFormat;
    final plan = planReminders(
      index: schedule.index,
      courses: schedule.courses,
      meetings: schedule.meetings,
      settings: settings,
      texts: LocalizedReminderTexts(l, Fmt(l.localeName, use24h: use24h)),
      now: now,
      limit: window.limit,
      horizonDays: window.horizonDays,
    );
    // No semester running soon: an empty plan cancels what's left.
    await service.apply(plan, force: force);
    return plan.length;
  }

  Future<void> _onResponse(NotificationResponse response) async {
    final payload = ReminderPayload.parse(response.payload);
    if (response.actionId == 'open_link' && payload?.link != null) {
      await openUrl(payload!.link!);
      return;
    }
    if (await markFromNotification(
      response,
      container.read(repositoryProvider),
    )) {
      return;
    }
    // A plain tap: show today's sessions.
    container.read(routerProvider).go('/today');
  }
}
