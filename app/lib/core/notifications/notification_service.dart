import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminder_plan.dart';
import 'notification_actions.dart';

/// Localized labels registered with the OS (channels, action buttons).
class NotificationLabels {
  const NotificationLabels({
    required this.channelBefore,
    required this.channelAfter,
    required this.attended,
    required this.missed,
    required this.watched,
    required this.openLink,
  });

  final String channelBefore;
  final String channelAfter;
  final String attended;
  final String missed;
  final String watched;
  final String openLink;
}

/// Wraps flutter_local_notifications.
///
/// [apply] diffs the plan against what the OS already has pending (stored in
/// each notification's payload), so frequent re-planning only touches the
/// reminders that actually changed (v1 cancelled and re-created all 48 on
/// every tap). Linux has no OS scheduler, so reminders due in the next day
/// are shown from in-app timers while the app runs.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  NotificationLabels? _labels;
  bool _ready = false;
  final _timers = <int, Timer>{};
  final _timerSignatures = <int, String>{};

  static const testId = 1;
  static const _windowsGuid = '6f1c0f5e-3b7a-4d2e-9c51-8a2b7e4d0c13';

  static bool get _osSchedules => !kIsWeb && !Platform.isLinux;

  bool get ready => _ready;

  Future<void> init({
    required NotificationLabels labels,
    required void Function(NotificationResponse) onResponse,
  }) async {
    _labels = labels;
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    final darwin = DarwinInitializationSettings(
      // Permission is requested only when reminders are switched on.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'after_class',
          actions: [
            DarwinNotificationAction.plain('attended', labels.attended),
            DarwinNotificationAction.plain('missed', labels.missed),
            DarwinNotificationAction.plain('watched', labels.watched),
          ],
        ),
        DarwinNotificationCategory(
          'before_class',
          actions: [
            DarwinNotificationAction.plain(
              'open_link',
              labels.openLink,
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_leccheck'),
        iOS: darwin,
        macOS: darwin,
        linux: const LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: const WindowsInitializationSettings(
          appName: 'LecCheck',
          appUserModelId: 'com.leccheck.app',
          guid: _windowsGuid,
        ),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse:
          onNotificationActionInBackground,
    );
    _ready = true;
  }

  Future<NotificationResponse?> launchResponse() async {
    if (!_ready) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false
        ? details!.notificationResponse
        : null;
  }

  /// Asks the OS for permission (Android 13+, iOS, macOS). True if allowed.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<void> apply(List<PlannedReminder> plan) async {
    if (!_ready) return;
    if (!_osSchedules) {
      _applyTimers(plan);
      return;
    }
    final wanted = {for (final r in plan) r.id: r};
    Map<int, String?> existing;
    try {
      existing = {
        for (final p in await _plugin.pendingNotificationRequests())
          if (p.id != testId) p.id: _signatureOf(p.payload),
      };
    } on Object {
      await _plugin.cancelAll();
      existing = {};
    }
    for (final id in existing.keys) {
      if (!wanted.containsKey(id)) await _plugin.cancel(id: id);
    }
    final mode = await _androidMode();
    for (final r in plan) {
      if (existing[r.id] == r.signature) continue;
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: _details(r.kind, link: r.link),
          androidScheduleMode: mode,
          title: r.title,
          body: r.body,
          payload: _payload(r),
        );
      } on Object catch (e) {
        debugPrint('Could not schedule reminder ${r.id}: $e');
      }
    }
  }

  Future<void> cancelAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _timerSignatures.clear();
    if (_ready) await _plugin.cancelAll();
  }

  Future<void> showTest(String title, String body) async {
    if (!_ready) return;
    await _plugin.show(
      id: testId,
      title: title,
      body: body,
      notificationDetails: _details(ReminderKind.before),
    );
  }

  void _applyTimers(List<PlannedReminder> plan) {
    final horizon = DateTime.now().add(const Duration(hours: 24));
    final wanted = {
      for (final r in plan)
        if (r.at.isBefore(horizon)) r.id: r,
    };
    for (final id in _timers.keys.toList()) {
      if (wanted[id]?.signature != _timerSignatures[id]) {
        _timers.remove(id)!.cancel();
        _timerSignatures.remove(id);
      }
    }
    for (final r in wanted.values) {
      if (_timers.containsKey(r.id)) continue;
      _timerSignatures[r.id] = r.signature;
      _timers[r.id] = Timer(r.at.difference(DateTime.now()), () {
        _timers.remove(r.id);
        _timerSignatures.remove(r.id);
        _plugin.show(
          id: r.id,
          title: r.title,
          body: r.body,
          notificationDetails: _details(r.kind, link: r.link),
          payload: _payload(r),
        );
      });
    }
  }

  Future<AndroidScheduleMode> _androidMode() async {
    if (kIsWeb || !Platform.isAndroid) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final exact = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();
    return exact ?? false
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  NotificationDetails _details(ReminderKind kind, {String? link}) {
    final labels = _labels!;
    final after = kind == ReminderKind.after;
    final statusActions = [
      ('attended', labels.attended),
      ('missed', labels.missed),
      ('watched', labels.watched),
    ];
    final actions = after
        ? statusActions
        : [if (link != null) ('open_link', labels.openLink)];
    return NotificationDetails(
      android: AndroidNotificationDetails(
        after ? 'after_class' : 'before_class',
        after ? labels.channelAfter : labels.channelBefore,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: [
          for (final (id, label) in actions)
            AndroidNotificationAction(
              id,
              label,
              showsUserInterface: id == 'open_link',
              cancelNotification: true,
            ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: after ? 'after_class' : 'before_class',
      ),
      macOS: DarwinNotificationDetails(
        categoryIdentifier: after ? 'after_class' : 'before_class',
      ),
      linux: LinuxNotificationDetails(
        actions: [
          for (final (id, label) in actions)
            LinuxNotificationAction(key: id, label: label),
        ],
      ),
      windows: WindowsNotificationDetails(
        actions: [
          for (final (id, label) in actions)
            WindowsAction(content: label, arguments: id),
        ],
      ),
    );
  }

  static String _payload(PlannedReminder r) => jsonEncode({
    'kind': r.kind.name,
    'session': r.session.id,
    'meeting': r.session.meetingId,
    'date': r.session.originalDate.toIso(),
    'link': r.link,
    'sig': r.signature,
  });

  static String? _signatureOf(String? payload) {
    if (payload == null) return null;
    try {
      return (jsonDecode(payload) as Map<String, Object?>)['sig'] as String?;
    } on Object {
      return null;
    }
  }
}
