import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/notification_actions.dart';
import '../core/notifications/notification_service.dart';
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

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  @override
  ReminderSettings build() => ReminderSettings(
    before: _prefs.getBool(_before) ?? false,
    beforeMinutes: _prefs.getInt(_beforeMin) ?? 10,
    after: _prefs.getBool(_after) ?? false,
    afterMinutes: _prefs.getInt(_afterMin) ?? 5,
  );

  void update({
    bool? before,
    int? beforeMinutes,
    bool? after,
    int? afterMinutes,
  }) {
    state = ReminderSettings(
      before: before ?? state.before,
      beforeMinutes: beforeMinutes ?? state.beforeMinutes,
      after: after ?? state.after,
      afterMinutes: afterMinutes ?? state.afterMinutes,
    );
    _prefs
      ..setBool(_before, state.before)
      ..setInt(_beforeMin, state.beforeMinutes)
      ..setBool(_after, state.after)
      ..setInt(_afterMin, state.afterMinutes);
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsController, ReminderSettings>(
      ReminderSettingsController.new,
    );

class _Texts implements ReminderTexts {
  _Texts(this.l, this.fmt);
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
  NotificationController(this.container);

  final ProviderContainer container;
  Timer? _debounce;
  Timer? _hourly;

  AppLocalizations get _l {
    final code =
        container.read(appearanceProvider).localeCode ??
        PlatformDispatcher.instance.locale.languageCode;
    return lookupAppLocalizations(Locale(code == 'he' ? 'he' : 'en'));
  }

  Future<void> start() async {
    final l = _l;
    await NotificationService.instance.init(
      labels: NotificationLabels(
        channelBefore: l.channelBefore,
        channelAfter: l.channelAfter,
        attended: l.markAttended,
        missed: l.markMissed,
        watched: l.markWatched,
        openLink: l.openLink,
      ),
      onResponse: _onResponse,
    );
    void replan(Object? _, Object? _) => schedule();
    container
      ..listen(occurrenceIndexProvider, replan)
      ..listen(semesterDataProvider, replan)
      ..listen(reminderSettingsProvider, replan)
      ..listen(appearanceProvider, replan)
      ..listen(userPrefsProvider, replan);
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => schedule());
    schedule();
    final launch = await NotificationService.instance.launchResponse();
    if (launch != null) await _onResponse(launch);
  }

  void dispose() {
    _debounce?.cancel();
    _hourly?.cancel();
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _apply);
  }

  Future<void> _apply() async {
    final settings = container.read(reminderSettingsProvider);
    final data = container.read(semesterDataProvider).value;
    if (!settings.any || data == null) {
      await NotificationService.instance.cancelAll();
      return;
    }
    final l = _l;
    final use24h =
        container.read(userPrefsProvider).value?.use24h ??
        PlatformDispatcher.instance.alwaysUse24HourFormat;
    final plan = planReminders(
      index: container.read(occurrenceIndexProvider),
      courses: {for (final c in data.courses) c.id: c},
      meetings: {for (final m in data.meetings) m.id: m},
      settings: settings,
      texts: _Texts(l, Fmt(l.localeName, use24h: use24h)),
      now: DateTime.now(),
    );
    await NotificationService.instance.apply(plan);
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
