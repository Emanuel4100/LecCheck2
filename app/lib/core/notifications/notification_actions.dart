import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../db/schedule_repository.dart';
import '../dev/dev_log.dart';

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
