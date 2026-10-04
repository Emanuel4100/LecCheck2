import 'local_date.dart';
import 'occurrence.dart';
import 'schedule_types.dart';

enum ReminderKind { before, after }

class ReminderSettings {
  const ReminderSettings({
    this.before = false,
    this.beforeMinutes = 10,
    this.after = false,
    this.afterMinutes = 5,
  });

  final bool before;
  final int beforeMinutes;
  final bool after;
  final int afterMinutes;

  bool get any => before || after;

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.before == before &&
      other.beforeMinutes == beforeMinutes &&
      other.after == after &&
      other.afterMinutes == afterMinutes;

  @override
  int get hashCode => Object.hash(before, beforeMinutes, after, afterMinutes);
}

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.session,
    required this.title,
    required this.body,
    this.link,
  });

  /// Stable across runs for the same session and kind.
  final int id;
  final ReminderKind kind;
  final DateTime at;
  final Occurrence session;
  final String title;
  final String body;
  final String? link;

  /// Changes whenever the notification would look or fire differently.
  String get signature =>
      '${kind.name}|${at.millisecondsSinceEpoch}|$title|$body|${link ?? ''}';
}

/// Texts for reminders, supplied by the UI layer (localized).
abstract interface class ReminderTexts {
  String beforeTitle(Occurrence session, CourseInfo course, int minutes);
  String beforeBody(Occurrence session, CourseInfo course);
  String afterTitle(Occurrence session, CourseInfo course);
  String afterBody(Occurrence session, CourseInfo course);
}

/// 32-bit FNV-1a — String.hashCode isn't guaranteed stable across runs, and
/// notification ids must be, so a reschedule replaces rather than duplicates.
int reminderId(String sessionId, ReminderKind kind) {
  var hash = 0x811c9dc5;
  for (final unit in '$sessionId|${kind.name}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// The next reminders to schedule, soonest first.
///
/// Canceled sessions get none; "how was class" reminders only for sessions
/// still pending. [limit] stays under iOS's cap of 64 pending notifications.
List<PlannedReminder> planReminders({
  required OccurrenceIndex index,
  required Map<String, CourseInfo> courses,
  required Map<String, MeetingRule> meetings,
  required ReminderSettings settings,
  required ReminderTexts texts,
  required DateTime now,
  int limit = 60,
  int horizonDays = 14,
}) {
  if (!settings.any) return const [];
  final today = LocalDate.fromDateTime(now);
  final plan = <PlannedReminder>[];
  for (final session in index.between(today, today.addDays(horizonDays))) {
    if (session.isCanceled) continue;
    final course = courses[session.courseId];
    if (course == null) continue;
    if (settings.before) {
      final at = session.start.subtract(
        Duration(minutes: settings.beforeMinutes),
      );
      if (at.isAfter(now)) {
        final meeting = meetings[session.meetingId];
        final link =
            meeting?.links.firstOrNull?.url ??
            course.links.firstOrNull?.url ??
            (course.website.isEmpty ? null : course.website);
        plan.add(
          PlannedReminder(
            id: reminderId(session.id, ReminderKind.before),
            kind: ReminderKind.before,
            at: at,
            session: session,
            title: texts.beforeTitle(session, course, settings.beforeMinutes),
            body: texts.beforeBody(session, course),
            link: link,
          ),
        );
      }
    }
    if (settings.after && session.status == AttendanceStatus.pending) {
      final at = session.end.add(Duration(minutes: settings.afterMinutes));
      if (at.isAfter(now)) {
        plan.add(
          PlannedReminder(
            id: reminderId(session.id, ReminderKind.after),
            kind: ReminderKind.after,
            at: at,
            session: session,
            title: texts.afterTitle(session, course),
            body: texts.afterBody(session, course),
          ),
        );
      }
    }
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan.length > limit ? plan.sublist(0, limit) : plan;
}
