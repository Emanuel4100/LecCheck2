import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../domain/reminder_plan.dart';
import 'android_device.dart';

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

/// A reminder the OS will show ([NotificationService.status]).
class PendingReminder {
  const PendingReminder(this.id, this.title, this.at);

  final int id;
  final String? title;
  final DateTime? at;
}

/// What Settings → Developer shows about notifications.
class NotificationStatus {
  const NotificationStatus({
    required this.ready,
    required this.error,
    required this.health,
    required this.timeZone,
    required this.pending,
    required this.armed,
  });

  final bool ready;

  /// Why notifications couldn't be set up, if they couldn't.
  final Object? error;
  final ReminderHealth health;
  final String timeZone;

  /// Soonest first, as the notifications plugin lists them.
  final List<PendingReminder> pending;

  /// Android: how many of [pending] still have their alarm in the system
  /// (null where it can't tell).
  final int? armed;
}

/// What can stop reminders from appearing on this device: Settings →
/// Reminders shows it, and Today warns when they're blocked.
@immutable
class ReminderHealth {
  const ReminderHealth({
    this.allowed,
    this.blockedChannels = const [],
    this.exactAlarms,
    this.batteryOptimized,
    this.backgroundRestricted,
    this.maker,
  });

  /// Whether the OS lets LecCheck show notifications; null when it can't
  /// tell (not checked yet, or the check failed).
  final bool? allowed;

  /// Reminder channels (`before_class`, `after_class`) turned off in the
  /// system settings (Android).
  final List<String> blockedChannels;

  /// Android: whether reminders fire on the minute.
  final bool? exactAlarms;

  /// Android: battery optimization can delay reminders.
  final bool? batteryOptimized;

  /// Android 9+: "restricted" background use stops alarms from starting the
  /// app, so reminders never appear.
  final bool? backgroundRestricted;

  /// Android: the phone's maker (some stop apps' alarms more than others).
  final String? maker;

  /// Reminders can't appear at all until the user allows them.
  bool get blocked => allowed == false || blockedChannels.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReminderHealth &&
      other.allowed == allowed &&
      listEquals(other.blockedChannels, blockedChannels) &&
      other.exactAlarms == exactAlarms &&
      other.batteryOptimized == batteryOptimized &&
      other.backgroundRestricted == backgroundRestricted &&
      other.maker == maker;

  @override
  int get hashCode => Object.hash(
    allowed,
    Object.hashAll(blockedChannels),
    exactAlarms,
    batteryOptimized,
    backgroundRestricted,
    maker,
  );
}

/// Thrown by [NotificationService.showTest] when the OS would drop the
/// notification without a word.
class RemindersBlocked implements Exception {
  const RemindersBlocked(this.health);

  final ReminderHealth health;

  @override
  String toString() => health.allowed == false
      ? 'notifications are turned off for LecCheck'
      : 'notification channel off: ${health.blockedChannels.join(', ')}';
}

/// What [NotificationService.apply] needs from the OS's scheduler, so tests
/// can fake it.
abstract interface class ReminderOs {
  /// Reminders the notifications plugin lists as scheduled (not yet shown),
  /// by id, with their signatures. Leaves out the Developer tests.
  Future<Map<int, String?>> pending();

  /// Which of [ids] still have their alarm in the system; null where it
  /// can't tell (then [pending] is the truth).
  Future<Set<int>?> armed(List<int> ids);

  /// Android: whether alarms may fire on the minute.
  Future<bool> canScheduleExact();

  Future<void> schedule(PlannedReminder r, {required bool exact});

  Future<void> cancel(int id);

  /// Forgets every scheduled reminder, for when [pending] can't be read.
  Future<void> clear();
}

/// Wraps flutter_local_notifications.
///
/// [apply] diffs the plan against what's already scheduled (each
/// notification's payload carries a signature), so frequent re-planning only
/// touches the reminders that actually changed (v1 cancelled and re-created
/// all 48 on every tap). The plugin's own list survives a force stop while
/// the system drops the alarms, so on Android [apply] also asks the system
/// which alarms are still there, once per process. Linux has no OS
/// scheduler, so reminders due in the next day are shown from in-app timers
/// while the app runs.
class NotificationService {
  NotificationService._() : _osSchedules = !kIsWeb && !Platform.isLinux {
    _os = _PluginOs(this);
  }

  /// A service that is set up, over a fake scheduler.
  @visibleForTesting
  NotificationService.forTesting(ReminderOs os) : _osSchedules = true {
    _os = os;
    _ready = true;
  }

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  late final ReminderOs _os;
  final bool _osSchedules;
  NotificationLabels? _labels;
  bool _ready = false;
  Object? _initError;
  final _timers = <int, Timer>{};
  final _timerSignatures = <int, String>{};

  /// Reminders this process scheduled, or found armed in the system, with
  /// their signatures: [apply] trusts these without asking again.
  final _armedHere = <int, String>{};

  static const testId = 1;

  /// Test notifications from Settings → Developer.
  static const testLaterId = 2;
  static const testAfterId = 3;

  /// Ids [apply] leaves alone.
  static const _ownIds = {testId, testLaterId, testAfterId};
  static const _windowsGuid = '6f1c0f5e-3b7a-4d2e-9c51-8a2b7e4d0c13';
  static const _channels = {'before_class', 'after_class'};

  bool get ready => _ready;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Sets up the plugin. [onBackgroundResponse] (a top-level function) runs
  /// in a background isolate for buttons pressed while the app is closed;
  /// pass the same one everywhere, since the plugin remembers the last.
  Future<void> init({
    required NotificationLabels labels,
    required void Function(NotificationResponse) onResponse,
    required void Function(NotificationResponse) onBackgroundResponse,
  }) async {
    _labels = labels;
    if (kIsWeb) return;
    if (_ready) {
      await _createChannels();
      return;
    }
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (e) {
      // Reminders still fire on time (they're scheduled from local times),
      // but Settings → Developer shows UTC.
      debugPrint('Unknown time zone, reminders use UTC: $e');
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
    try {
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
        onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
      );
      _ready = true;
      _initError = null;
      await _createChannels();
    } on Object catch (e) {
      // E.g. the status-bar icon is missing from the build: then nothing can
      // be shown or scheduled. Settings → Developer shows why.
      _initError = e;
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Creates the reminder channels up front, so they're in the system
  /// settings (and can be checked) before the first reminder, and renames
  /// them when the app's language changes.
  Future<void> _createChannels() async {
    final android = _android;
    final labels = _labels;
    if (android == null || labels == null) return;
    try {
      for (final (id, name) in [
        ('before_class', labels.channelBefore),
        ('after_class', labels.channelAfter),
      ]) {
        await android.createNotificationChannel(
          AndroidNotificationChannel(id, name, importance: Importance.high),
        );
      }
    } on Object catch (e) {
      debugPrint('Could not create notification channels: $e');
    }
  }

  Future<NotificationResponse?> launchResponse() async {
    if (!_ready) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false
        ? details!.notificationResponse
        : null;
  }

  /// Asks the OS for permission (Android 13+, iOS, macOS). True if allowed.
  /// On Android the system stops asking after two refusals: then only
  /// [openSettings] helps.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        return await _android?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        return await _ios?.requestPermissions(alert: true, sound: true) ??
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
    } on Object catch (e) {
      debugPrint('Could not ask for notification permission: $e');
      return false;
    }
    return true;
  }

  /// Checks what could stop reminders (permission, channels, alarms,
  /// battery). Never throws: unknown parts stay null.
  Future<ReminderHealth> health() async {
    if (kIsWeb) return const ReminderHealth();
    try {
      final android = _android;
      if (android != null) {
        final info = await AndroidDevice.info();
        final channels = await android.getNotificationChannels() ?? const [];
        return ReminderHealth(
          allowed: await android.areNotificationsEnabled(),
          blockedChannels: [
            for (final c in channels)
              if (_channels.contains(c.id) && c.importance == Importance.none)
                c.id,
          ],
          exactAlarms: await android.canScheduleExactNotifications(),
          batteryOptimized: info?['batteryOptimized'] as bool?,
          backgroundRestricted: info?['backgroundRestricted'] as bool?,
          maker: info?['maker'] as String?,
        );
      }
      final ios = _ios;
      if (ios != null) {
        return ReminderHealth(
          allowed: (await ios.checkPermissions())?.isEnabled,
        );
      }
    } on Object catch (e) {
      debugPrint('Could not check notification permission: $e');
      return const ReminderHealth();
    }
    // Linux and Windows have no per-app switch.
    return const ReminderHealth(allowed: true);
  }

  /// Android 12+: the system page that lets reminders fire on the minute
  /// ("Alarms & reminders").
  Future<void> requestExactAlarms() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } on Object catch (e) {
      debugPrint('Could not open the alarms setting: $e');
    }
  }

  /// The system page where LecCheck's notifications (or one [channel]) can
  /// be turned back on.
  Future<void> openSettings({String? channel}) async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await AndroidDevice.openNotificationSettings(channel: channel);
    } else if (Platform.isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
    }
  }

  /// Schedules [plan] and cancels reminders that aren't in it any more. Only
  /// changed reminders are rescheduled, plus (on Android) any whose alarm the
  /// system dropped. With [force], everything is rescheduled.
  Future<void> apply(List<PlannedReminder> plan, {bool force = false}) async {
    if (!_ready) {
      debugPrint(
        'Reminders not scheduled: notifications aren\'t set up '
        '(${_initError ?? 'not started'})',
      );
      return;
    }
    if (!_osSchedules) {
      _applyTimers(plan);
      return;
    }
    final wanted = {for (final r in plan) r.id: r};
    _armedHere.removeWhere((id, _) => !wanted.containsKey(id));
    Map<int, String?> listed;
    try {
      listed = await _os.pending();
    } on Object catch (e) {
      // Unreadable (and cancelling everything would read it too): start the
      // list over and schedule the whole plan.
      debugPrint('Reminder list unreadable, starting over: $e');
      await _os.clear();
      listed = const {};
      _armedHere.clear();
      force = true;
    }
    var cancelled = 0;
    for (final id in listed.keys) {
      if (!wanted.containsKey(id)) {
        await _os.cancel(id);
        cancelled++;
      }
    }
    // Listed but not armed by this process: check with the system once (a
    // force stop drops the alarms but not the plugin's list).
    final unverified = [
      for (final r in plan)
        if (!force &&
            listed[r.id] == r.signature &&
            _armedHere[r.id] != r.signature)
          r.id,
    ];
    final armed = unverified.isEmpty ? null : await _os.armed(unverified);
    final exact = await _os.canScheduleExact();
    var scheduled = 0;
    var lost = 0;
    for (final r in plan) {
      final current = !force && listed[r.id] == r.signature;
      final alive =
          _armedHere[r.id] == r.signature || (armed?.contains(r.id) ?? true);
      if (current && alive) {
        _armedHere[r.id] = r.signature;
        continue;
      }
      if (current) lost++;
      try {
        await _os.schedule(r, exact: exact);
        _armedHere[r.id] = r.signature;
        scheduled++;
      } on Object catch (e) {
        _armedHere.remove(r.id);
        debugPrint('Could not schedule reminder ${r.id}: $e');
      }
    }
    if (scheduled + cancelled > 0) {
      debugPrint(
        'Reminders: ${plan.length} planned, $scheduled (re)scheduled'
        '${lost > 0 ? ' ($lost had lost their alarm)' : ''}, '
        '$cancelled cancelled${exact ? '' : ', not exact: may come late'}',
      );
    }
  }

  /// Cancels every scheduled reminder (reminders turned off, or no semester).
  /// Notifications already on screen and the Developer tests stay.
  Future<void> cancelReminders() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _timerSignatures.clear();
    _armedHere.clear();
    if (!_ready || !_osSchedules) return;
    try {
      final ids = (await _os.pending()).keys.toList();
      for (final id in ids) {
        await _os.cancel(id);
      }
      if (ids.isNotEmpty) debugPrint('Reminders: ${ids.length} cancelled');
    } on Object catch (e) {
      debugPrint('Reminder list unreadable, clearing it: $e');
      await _os.clear();
    }
  }

  /// Shows a notification now. Throws when notifications couldn't be set
  /// up, or [RemindersBlocked] when the OS would drop it, so the caller can
  /// say why (beta.4's test button said nothing while Android dropped it).
  Future<void> showTest(String title, String body) async {
    _checkReady();
    final health = await this.health();
    if (health.blocked) throw RemindersBlocked(health);
    await _plugin.show(
      id: testId,
      title: title,
      body: body,
      notificationDetails: _details(ReminderKind.before),
    );
  }

  /// Schedules one reminder the way [apply] does (Settings → Developer).
  /// With [test], its buttons only log, and change nothing.
  Future<void> scheduleTest(PlannedReminder r, {bool test = false}) async {
    _checkReady();
    if (!_osSchedules) {
      _timers.remove(r.id)?.cancel();
      _timers[r.id] = Timer(r.at.difference(DateTime.now()), () {
        _timers.remove(r.id);
        _plugin.show(
          id: r.id,
          title: r.title,
          body: r.body,
          notificationDetails: _details(r.kind, link: r.link),
          payload: _payload(r, test: test),
        );
      });
      return;
    }
    await _plugin.zonedSchedule(
      id: r.id,
      scheduledDate: tz.TZDateTime.from(r.at, tz.local),
      notificationDetails: _details(r.kind, link: r.link),
      androidScheduleMode: _scheduleMode(exact: await _os.canScheduleExact()),
      title: r.title,
      body: r.body,
      payload: _payload(r, test: test),
    );
  }

  Future<NotificationStatus> status() async {
    final pending = <PendingReminder>[];
    if (_ready && _osSchedules) {
      try {
        for (final p in await _plugin.pendingNotificationRequests()) {
          final at = int.tryParse(
            _signatureOf(p.payload)?.split('|').elementAtOrNull(1) ?? '',
          );
          pending.add(
            PendingReminder(
              p.id,
              p.title,
              at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
            ),
          );
        }
      } on Object catch (e) {
        debugPrint('Could not list reminders: $e');
      }
    }
    pending.sort(
      (a, b) => (a.at ?? DateTime(9999)).compareTo(b.at ?? DateTime(9999)),
    );
    final armed = pending.isEmpty
        ? null
        : await _os.armed([for (final p in pending) p.id]);
    return NotificationStatus(
      ready: _ready,
      error: _initError,
      health: await health(),
      timeZone: _ready ? tz.local.name : '?',
      pending: pending,
      armed: armed?.length,
    );
  }

  void _checkReady() {
    if (!_ready) {
      throw StateError('notifications are not set up (${_initError ?? '-'})');
    }
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

  static AndroidScheduleMode _scheduleMode({required bool exact}) => exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

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

  static String _payload(PlannedReminder r, {bool test = false}) => jsonEncode({
    'kind': r.kind.name,
    'session': r.session.id,
    'meeting': r.session.meetingId,
    'date': r.session.originalDate.toIso(),
    'link': r.link,
    'sig': r.signature,
    if (test) 'test': true,
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

/// The real scheduler: flutter_local_notifications, plus LecCheck's Android
/// channel for what the plugin can't tell.
class _PluginOs implements ReminderOs {
  _PluginOs(this.service);

  final NotificationService service;

  FlutterLocalNotificationsPlugin get _plugin => service._plugin;

  @override
  Future<Map<int, String?>> pending() async => {
    for (final p in await _plugin.pendingNotificationRequests())
      if (!NotificationService._ownIds.contains(p.id))
        p.id: NotificationService._signatureOf(p.payload),
  };

  @override
  Future<Set<int>?> armed(List<int> ids) => AndroidDevice.armedReminders(ids);

  @override
  Future<bool> canScheduleExact() async {
    final android = service._android;
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> schedule(PlannedReminder r, {required bool exact}) =>
      _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: service._details(r.kind, link: r.link),
        androidScheduleMode: NotificationService._scheduleMode(exact: exact),
        title: r.title,
        body: r.body,
        payload: NotificationService._payload(r),
      );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> clear() async {
    if (service._android != null) {
      await AndroidDevice.clearReminderCache();
    } else {
      await _plugin.cancelAllPendingNotifications();
    }
  }
}
