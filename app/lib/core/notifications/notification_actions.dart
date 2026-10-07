import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../auth/auth_service.dart';
import '../db/app_database.dart';
import '../db/schedule_repository.dart';
import '../dev/dev_log.dart';
import '../sync/sync_config.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_recorder.dart';

/// What a notification refers to.
class ReminderPayload {
  const ReminderPayload({
    required this.kind,
    required this.meetingId,
    required this.originalDate,
    this.link,
    this.test = false,
  });

  static ReminderPayload? parse(String? json) {
    if (json == null) return null;
    try {
      final map = jsonDecode(json) as Map<String, Object?>;
      return ReminderPayload(
        kind: map['kind']! as String,
        meetingId: map['meeting']! as String,
        originalDate: LocalDate.parse(map['date']! as String),
        link: map['link'] as String?,
        test: map['test'] == true,
      );
    } on Object {
      return null;
    }
  }

  final String kind;
  final String meetingId;
  final LocalDate originalDate;
  final String? link;

  /// From Settings → Developer: the buttons only log.
  final bool test;
}

AttendanceStatus? statusForAction(String? actionId) => switch (actionId) {
  'attended' => AttendanceStatus.attended,
  'missed' => AttendanceStatus.missed,
  'watched' => AttendanceStatus.watched,
  _ => null,
};

/// Applies an "Attended / Missed / Watched" action. True if one was applied.
Future<bool> markFromNotification(
  NotificationResponse response,
  ScheduleRepository repo,
) async {
  final status = statusForAction(response.actionId);
  final payload = ReminderPayload.parse(response.payload);
  if (status == null || payload == null) return false;
  if (payload.test) {
    DevLog.add('Test notification: "${status.key}" pressed (nothing changed)');
    return false;
  }
  await repo.setStatusFor(
    meetingId: payload.meetingId,
    originalDate: payload.originalDate,
    status: status,
  );
  return true;
}

/// Runs in a background isolate when a notification button is pressed while
/// the app isn't running: records the status (shared database), then tries
/// a quick HTTP sync so other devices see it right away.
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
    if (recorder == null) return;
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
  } on Object catch (e) {
    debugPrint('Notification action failed: $e');
  } finally {
    await db.close();
    await DevLog.flush();
  }
}
