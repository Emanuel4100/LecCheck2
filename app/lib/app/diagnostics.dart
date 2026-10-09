import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/dev/dev_log.dart';
import '../core/dev/frame_stats.dart';
import '../core/notifications/android_device.dart';
import '../core/notifications/notification_service.dart';
import '../core/sync/sync_config.dart';
import 'adaptive.dart';
import 'providers.dart';
import 'sync_providers.dart';
import 'widgets/common.dart';

/// Device details, app state and the recent log, as plain text: Settings →
/// Developer → Copy diagnostics, and bug reports (which show it before
/// sending). The log can mention course names.
Future<String> collectDiagnostics(
  BuildContext context,
  WidgetRef ref, {
  int logLines = 80,
}) async {
  final media = MediaQuery.of(context);
  final layout = WindowSize.of(context).name;
  final localeCode = ref.read(appearanceProvider).localeCode;
  final state = ref.read(syncStateProvider).value;
  final now = DateTime.now();
  final notifications = await NotificationService.instance.status();
  final log = (await DevLog.read()).trimRight().split('\n');
  final android = AppIdiom.isAndroid ? await AndroidDevice.info() : null;
  if (!context.mounted) return '';
  final view = View.of(context);
  final frames = FrameStats.instance.summary(
    refreshRate: view.display.refreshRate,
  );
  final version = await PackageInfo.fromPlatform().then(
    (i) => '${i.version} (${i.buildNumber})',
    onError: (Object e) => '? ($e)',
  );
  return [
    'LecCheck $version',
    if (android != null)
      '${androidLine(android)}, battery optimization '
          '${android['batteryOptimized']}, background restricted '
          '${android['backgroundRestricted']}'
    else
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'Locale: ${Platform.localeName}, app: ${localeCode ?? 'system'}',
    'Time: $now ${now.timeZoneName} (UTC${utcOffset(now.timeZoneOffset)}), '
        'reminders use ${notifications.timeZone}',
    'Screen: ${media.size.width.round()}×${media.size.height.round()} '
        '@${media.devicePixelRatio}, text ×${media.textScaler.scale(10) / 10}',
    'Layout: $layout',
    'Frames: ${frames ?? 'not enough yet'}',
    'Notifications: ready ${notifications.ready}, allowed '
        '${notifications.health.allowed}, channels off '
        '${notifications.health.blockedChannels}, exact '
        '${notifications.health.exactAlarms}, '
        '${notifications.pending.length} scheduled, '
        '${notifications.armed ?? '?'} armed'
        '${notifications.error == null ? '' : ', error ${notifications.error}'}',
    'Sync: ${SyncConfig.enabled ? state?.phase.name ?? 'signed out' : 'off'}'
        '${state == null ? '' : ', ${state.pending} waiting, ${state.failed} refused'}',
    '',
    'Log (newest last):',
    ...log.skip(log.length > logLines ? log.length - logLines : 0),
  ].join('\n');
}

/// "Android 15 (SDK 35), samsung SM-S918B", from [AndroidDevice.info].
String androidLine(Map<String, Object?> info) =>
    'Android ${info['release']} (SDK ${info['sdk']}), '
    '${info['maker']} ${info['model']}';

/// "+03:00".
String utcOffset(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.isNegative ? '-' : '+'}${two(d.inHours.abs())}:'
      '${two(d.inMinutes.abs() % 60)}';
}
