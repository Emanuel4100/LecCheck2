import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/adaptive.dart';
import '../../app/diagnostics.dart';
import '../../app/format.dart';
import '../../app/notification_controller.dart';
import '../../app/providers.dart';
import '../../app/sync_providers.dart';
import '../../app/widget_controller.dart';
import '../../app/widgets/common.dart';
import '../../core/dev/dev_log.dart';
import '../../core/dev/frame_stats.dart';
import '../../core/home_widget/today_widget.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/notifications/android_device.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/sync/sync_config.dart';
import '../../domain/reminder_plan.dart';
import '../../l10n/gen/app_localizations.dart';

/// Hidden developer mode (tap the version in Settings → About 7 times).
class DevModeController extends Notifier<bool> {
  static const _key = 'dev.mode';

  @override
  bool build() => ref.read(sharedPrefsProvider).getBool(_key) ?? false;

  void set(bool on) {
    state = on;
    ref.read(sharedPrefsProvider).setBool(_key, on);
  }
}

final devModeProvider = NotifierProvider<DevModeController, bool>(
  DevModeController.new,
);

/// Android details only the platform knows (MainActivity.kt).

/// Files and sync bookkeeping, read when the page opens.
class _Storage {
  const _Storage({
    required this.database,
    required this.backups,
    required this.backupBytes,
    required this.newestBackup,
    required this.syncMeta,
  });

  final int database;
  final int backups;
  final int backupBytes;
  final DateTime? newestBackup;
  final Map<String, String> syncMeta;
}

/// Tools for testing on a real phone: notifications (scheduled ones and
/// buttons pressed with the app closed), sync, backups, the widget, device
/// details and a log to copy. In English, like a debug menu: it's for
/// whoever tests the app.
class DeveloperPage extends ConsumerStatefulWidget {
  const DeveloperPage({super.key});

  @override
  ConsumerState<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends ConsumerState<DeveloperPage> {
  late Future<NotificationStatus> _notifications = NotificationService.instance
      .status();
  late Future<_Storage> _storage = _readStorage();
  late Future<String> _log = DevLog.read();
  final _version = PackageInfo.fromPlatform().then(
    (i) => '${i.version} (${i.buildNumber})',
    onError: (Object e) => '? ($e)',
  );
  late Future<Map<String, Object?>?> _android = _readAndroid();

  void _refresh() => setState(() {
    _android = _readAndroid();
    _notifications = NotificationService.instance.status();
    _storage = _readStorage();
    _log = DevLog.read();
  });

  static Future<Map<String, Object?>?> _readAndroid() async {
    if (!AppIdiom.isAndroid) return null;
    return AndroidDevice.info();
  }

  Future<_Storage> _readStorage() async {
    final dir = await getApplicationSupportDirectory();
    var database = 0;
    for (final suffix in ['', '-wal']) {
      final file = File('${dir.path}/leccheck.sqlite$suffix');
      if (await file.exists()) database += await file.length();
    }
    final snapshots = await ref.read(snapshotServiceProvider).list();
    var bytes = 0;
    for (final s in snapshots) {
      bytes += await s.file.length();
    }
    final db = ref.read(databaseProvider);
    return _Storage(
      database: database,
      backups: snapshots.length,
      backupBytes: bytes,
      newestBackup: snapshots.firstOrNull?.takenAt,
      syncMeta: {
        for (final m in await db.select(db.syncMeta).get()) m.key: m.value,
      },
    );
  }

  /// Runs [action], shows its result and logs it.
  Future<void> _run(String what, Future<String> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    String result;
    try {
      result = await action();
    } on Object catch (e) {
      result = '$what failed: $e';
    }
    DevLog.add('Developer: $result');
    messenger.showSnackBar(SnackBar(content: Text(result)));
    if (mounted) _refresh();
  }

  // ------------------------------------------------------- notifications --

  Future<String> _showNow() async {
    final l = AppLocalizations.of(context);
    await NotificationService.instance.showTest(
      l.notifyTestTitle,
      l.notifyTestBody,
    );
    return 'Shown';
  }

  /// A plain notification in a minute: checks the OS scheduler (exact
  /// alarms, time zone) with the app closed.
  Future<String> _inAMinute() async {
    final l = AppLocalizations.of(context);
    final session = ref.read(occurrenceIndexProvider).all.firstOrNull;
    if (session == null) return 'Add a course with a meeting first';
    final at = DateTime.now().add(const Duration(minutes: 1));
    await NotificationService.instance.scheduleTest(
      PlannedReminder(
        id: NotificationService.testLaterId,
        kind: ReminderKind.before,
        at: at,
        session: session,
        title: l.notifyTestTitle,
        body: l.notifyTestBody,
      ),
      test: true,
    );
    return 'Scheduled for ${_clock(at)}. Go to the home screen and wait.';
  }

  /// An after-class reminder with real buttons, for the latest session that
  /// still needs marking (pressing one marks it). Without one, the buttons
  /// only log.
  Future<String> _afterClass() async {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final index = ref.read(occurrenceIndexProvider);
    final pendingId = ref.read(needsMarkingProvider).items.firstOrNull;
    final session = pendingId == null
        ? index.all.firstOrNull
        : index.byId[pendingId];
    if (session == null) return 'Add a course with a meeting first';
    final course = ref.read(courseProvider(session.courseId));
    if (course == null) return 'The session has no course';
    final texts = LocalizedReminderTexts(l, fmt);
    final at = DateTime.now().add(const Duration(minutes: 1));
    await NotificationService.instance.scheduleTest(
      PlannedReminder(
        id: NotificationService.testAfterId,
        kind: ReminderKind.after,
        at: at,
        session: session,
        title: texts.afterTitle(session, course),
        body: texts.afterBody(session, course),
      ),
      test: pendingId == null,
    );
    return pendingId == null
        ? 'At ${_clock(at)}; nothing needs marking, so its buttons only log'
        : 'At ${_clock(at)}; a button marks ${course.name} on '
              '${session.date.toIso()}. Close the app first to test it in '
              'the background.';
  }

  Future<String> _reschedule() async {
    final controller = NotificationController.current;
    if (controller == null) return 'Reminders aren\'t running';
    return 'Planned ${await controller.rescheduleNow()} reminders';
  }

  Widget _notificationTools() => FutureBuilder(
    future: _notifications,
    builder: (context, snapshot) {
      final s = snapshot.data;
      final next = s?.pending.firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s != null) ...[
            _info(
              'Set up',
              s.ready ? 'Yes' : 'No: ${s.error ?? 'not started yet'}',
              warn: !s.ready,
            ),
            _info('Allowed by the system', switch (s.health.allowed) {
              true => 'Yes',
              false => 'No: nothing can appear',
              null => 'Unknown',
            }, warn: s.health.allowed != true),
            if (s.health.blockedChannels.isNotEmpty)
              _info(
                'Channels turned off',
                s.health.blockedChannels.join(', '),
                warn: true,
              ),
            if (s.health.exactAlarms != null)
              _info(
                'Exact alarms',
                s.health.exactAlarms! ? 'Yes' : 'No: reminders may come late',
                warn: !s.health.exactAlarms!,
              ),
            _info('Time zone', s.timeZone),
            _info(
              'Scheduled',
              next == null
                  ? 'None'
                  : '${s.pending.length}; next: ${next.title ?? '?'} at '
                        '${next.at == null ? '?' : _clock(next.at!)}',
            ),
            if (s.armed != null)
              _info(
                'Armed in the system',
                s.armed == s.pending.length
                    ? 'All ${s.armed}'
                    : '${s.armed} of ${s.pending.length}: tap "Reschedule all '
                          'reminders"',
                warn: s.armed != s.pending.length,
              ),
          ],
          _action(
            LecIcons.notifications,
            'Show a notification now',
            () => _run('Showing', _showNow),
          ),
          _action(
            LecIcons.time,
            'Notification in 1 minute',
            () => _run('Scheduling', _inAMinute),
            subtitle:
                'Go to the home screen while waiting: checks the OS '
                'scheduler (swiping LecCheck away force-stops it on some '
                'phones, which drops its alarms)',
          ),
          _action(
            LecIcons.attended,
            'After-class reminder in 1 minute',
            () => _run('Scheduling', _afterClass),
            subtitle:
                'With Attended / Missed / Watched buttons. Close the app, '
                'press one, then check the session and the log',
          ),
          _action(
            LecIcons.refresh,
            'Reschedule all reminders',
            () => _run('Rescheduling', _reschedule),
          ),
        ],
      );
    },
  );

  // --------------------------------------------------------------- sync --

  Widget _syncTools() {
    final engine = ref.watch(syncEngineProvider);
    final state = ref.watch(syncStateProvider).value;
    final account = ref.watch(attachedAccountProvider);
    final offset = ref.watch(syncRecorderProvider)?.clock.offsetMs;
    return FutureBuilder(
      future: _storage,
      builder: (context, snapshot) {
        final meta = snapshot.data?.syncMeta ?? const {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _info(
              'Server',
              SyncConfig.enabled ? SyncConfig.apiBase : 'None (offline build)',
            ),
            _info(
              'Account on this device',
              account == null ? 'None' : '${account.substring(0, 6)}…',
            ),
            _info(
              'State',
              state == null
                  ? 'Not running (signed out)'
                  : [
                      state.phase.name,
                      '${state.pending} waiting',
                      if (state.failed > 0) '${state.failed} refused',
                      if (state.heldUntil != null)
                        'paused until ${_clock(state.heldUntil!)}',
                      if (state.lastSyncedAt != null)
                        'last synced ${_clock(state.lastSyncedAt!)}',
                    ].join(', '),
            ),
            _info(
              'Cursor / dataset',
              '${meta['lastVersion'] ?? '-'} / ${meta['dataset'] ?? '-'}',
            ),
            if (offset != null) _info('Clock correction', '$offset ms'),
            _action(
              LecIcons.sync,
              'Sync now',
              engine == null
                  ? null
                  : () => _run('Sync', () async {
                      engine.syncNow();
                      return 'Syncing';
                    }),
            ),
            _action(
              LecIcons.syncOff,
              'Pretend the server is busy for 2 minutes',
              engine == null
                  ? null
                  : () => _run('Pausing', () async {
                      engine.simulateBusyServer(const Duration(minutes: 2));
                      return 'Sync paused; Settings → Account shows until '
                          'when';
                    }),
              subtitle: 'As when the free plan\'s daily limit is used up',
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------- data --

  Widget _dataTools() => FutureBuilder(
    future: _storage,
    builder: (context, snapshot) {
      final s = snapshot.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s != null) ...[
            _info('Database', _size(s.database)),
            _info(
              'Automatic backups',
              '${s.backups}, ${_size(s.backupBytes)}'
                  '${s.newestBackup == null ? '' : ', newest ${_clock(s.newestBackup!)}'}'
                  ' (Android backs up 25 MB per app)',
            ),
          ],
          _action(
            LecIcons.doneAll,
            'Check the database',
            () => _run('Check', () async {
              final rows = await ref
                  .read(databaseProvider)
                  .customSelect('PRAGMA quick_check')
                  .get();
              return 'Database check: '
                  '${rows.map((r) => r.data.values.first).join('; ')}';
            }),
          ),
        ],
      );
    },
  );

  // ------------------------------------------------------------- device --

  /// How smooth the app is here: the display's rate, and the frames since
  /// start (or since Reset). Scroll or swipe the Week view, then refresh.
  Widget _renderingTools() {
    final view = View.of(context);
    final rate = view.display.refreshRate;
    final summary = FrameStats.instance.summary(refreshRate: rate);
    final fps = summary?.fps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _info(
          'Display',
          '${rate.round()} Hz, ${view.devicePixelRatio}× pixels',
        ),
        _info(
          'While animating',
          fps == null
              ? 'Nothing measured yet: swipe the Week view, then refresh'
              : '${fps.round()} fps (a frame every '
                    '${(summary!.interval!.inMicroseconds / 1000).toStringAsFixed(1)} ms)',
          // Flutter's Linux engine draws at 60 fps whatever the display.
          warn: fps != null && fps < rate * 0.9,
        ),
        if (summary != null) ...[
          _info('Build', '${summary.build}'),
          _info('Raster', '${summary.raster}'),
          _info(
            'Over budget',
            '${(summary.overBudget * 100).toStringAsFixed(1)}% of '
                '${summary.frames} frames took longer than one refresh',
            warn: summary.overBudget > 0.05,
          ),
        ],
        _action(LecIcons.refresh, 'Reset the frame counts', () {
          FrameStats.instance.reset();
          _refresh();
        }),
      ],
    );
  }

  Widget _deviceTools() {
    final media = MediaQuery.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder(
          future: _version,
          builder: (context, snapshot) =>
              _info('App version', snapshot.data ?? ''),
        ),
        if (AppIdiom.isAndroid)
          FutureBuilder(
            future: _android,
            builder: (context, snapshot) {
              final info = snapshot.data;
              if (info == null) return const SizedBox.shrink();
              final optimized = info['batteryOptimized'] == true;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _info('System', androidLine(info)),
                  _info(
                    'Battery optimization',
                    optimized ? 'On: reminders can come late' : 'Off',
                    warn: optimized,
                  ),
                ],
              );
            },
          )
        else
          _info(
            'System',
            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          ),
        _info(
          'Time zone',
          '${now.timeZoneName} (UTC${utcOffset(now.timeZoneOffset)})',
        ),
        _info(
          'Screen',
          '${media.size.width.round()}×${media.size.height.round()} dp '
              '@${media.devicePixelRatio}x, text ×'
              '${media.textScaler.scale(10) / 10}, '
              '24-hour ${PlatformDispatcher.instance.alwaysUse24HourFormat}',
        ),
        if (AppIdiom.isAndroid)
          _action(
            LecIcons.settings,
            'Open LecCheck\'s system settings',
            () => _run('Opening', () async {
              await AndroidDevice.openAppSettings();
              return 'Tap refresh when you come back';
            }),
            subtitle: 'Notifications, alarms & reminders, battery',
          ),
        _action(
          LecIcons.exportData,
          'Copy diagnostics',
          () => _run('Copy', () async {
            await Clipboard.setData(
              ClipboardData(text: await collectDiagnostics(context, ref)),
            );
            return 'Copied: device details, status and the log';
          }),
        ),
      ],
    );
  }

  Widget _logView() => FutureBuilder(
    future: _log,
    builder: (context, snapshot) {
      final theme = Theme.of(context);
      final lines = (snapshot.data ?? '').trimRight().split('\n');
      final recent = lines.reversed.take(60).join('\n');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  recent.isEmpty ? 'Nothing yet.' : recent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          _action(LecIcons.delete, 'Clear the log', () async {
            await DevLog.clear();
            _refresh();
          }),
        ],
      );
    },
  );

  // ------------------------------------------------------------ helpers --

  Widget _info(String label, String value, {bool warn = false}) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(label),
      subtitle: SelectableText(
        value,
        style: warn ? TextStyle(color: theme.colorScheme.error) : null,
      ),
    );
  }

  Widget _action(
    IconData icon,
    String title,
    VoidCallback? onTap, {
    String? subtitle,
  }) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    enabled: onTap != null,
    onTap: onTap,
  );

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _clock(DateTime t) =>
      '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Developer tools'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(LecIcons.refresh),
              onPressed: _refresh,
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                SwitchListTile.adaptive(
                  secondary: const Icon(LecIcons.developer),
                  title: const Text('Developer mode'),
                  value: true,
                  onChanged: (_) {
                    ref.read(devModeProvider.notifier).set(false);
                    context.pop();
                  },
                ),
                const SectionHeader(title: 'Notifications'),
                _notificationTools(),
                const SectionHeader(title: 'Sync'),
                _syncTools(),
                const SectionHeader(title: 'Data'),
                _dataTools(),
                if (TodayWidget.supported) ...[
                  const SectionHeader(title: 'Home-screen widget'),
                  _action(
                    LecIcons.widget,
                    'Update the widget now',
                    () => _run('Update', () async {
                      final controller = WidgetController.current;
                      if (controller == null) return 'Not running';
                      await controller.refreshNow();
                      return 'Widget updated';
                    }),
                  ),
                ],
                const SectionHeader(title: 'Rendering'),
                _renderingTools(),
                const SectionHeader(title: 'This device'),
                _deviceTools(),
                const SectionHeader(title: 'Log (newest first)'),
                _logView(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
