import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// LecCheck's own Android channel (MainActivity): device details and the
/// system settings pages plugins don't cover. Every call fails soft (null or
/// nothing) where the channel isn't there: other platforms, background
/// isolates, tests.
abstract final class AndroidDevice {
  static const _channel = MethodChannel('com.leccheck.app/device');

  /// Release, sdk, maker, model, batteryOptimized and, on Android 9+,
  /// backgroundRestricted and standbyBucket.
  static Future<Map<String, Object?>?> info() =>
      _call(() => _channel.invokeMapMethod<String, Object?>('info'));

  /// LecCheck's page in the system settings.
  static Future<void> openAppSettings() =>
      _call(() => _channel.invokeMethod<void>('openSettings'));

  /// LecCheck's notification settings, or those of one [channel].
  static Future<void> openNotificationSettings({String? channel}) => _call(
    () => _channel.invokeMethod<void>('openNotificationSettings', {
      'channel': channel,
    }),
  );

  /// The system dialog that turns battery optimization off for LecCheck.
  static Future<void> requestIgnoreBatteryOptimizations() => _call(
    () => _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations'),
  );

  /// Which of [ids] still have their alarm in the system (a force stop drops
  /// them, while the plugin's list keeps them); null when it can't tell.
  static Future<Set<int>?> armedReminders(Iterable<int> ids) async {
    final armed = await _call(
      () => _channel.invokeListMethod<int>('armedReminders', {
        'ids': ids.toList(),
      }),
    );
    return armed?.toSet();
  }

  /// Empties the plugin's list of scheduled reminders, when it can't be read.
  static Future<void> clearReminderCache() =>
      _call(() => _channel.invokeMethod<void>('clearReminderCache'));

  static Future<T?> _call<T>(Future<T?> Function() call) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await call();
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Device channel: $e');
      return null;
    }
  }
}
