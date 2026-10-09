import 'package:leccheck/core/notifications/notification_service.dart';
import 'package:leccheck/domain/reminder_plan.dart';

/// The OS scheduler as [NotificationService.apply] sees it: the plugin's list
/// ([listed]) and the alarms the system really holds ([alarms]; null when it
/// can't tell, like iOS).
class FakeReminderOs implements ReminderOs {
  final listed = <int, String?>{};
  Set<int>? alarms = {};
  final scheduled = <int>[];
  final cancelled = <int>[];
  bool unreadable = false;
  bool cleared = false;

  /// Like a force stop on Android: the alarms go, the plugin's list stays.
  void forceStop() => alarms = {};

  @override
  Future<Map<int, String?>> pending() async {
    if (unreadable) throw StateError('corrupt list');
    return Map.of(listed);
  }

  @override
  Future<Set<int>?> armed(List<int> ids) async =>
      alarms?.intersection(ids.toSet());

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<void> schedule(PlannedReminder r, {required bool exact}) async {
    scheduled.add(r.id);
    listed[r.id] = r.signature;
    alarms?.add(r.id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    listed.remove(id);
    alarms?.remove(id);
  }

  @override
  Future<void> clear() async {
    cleared = true;
    unreadable = false;
    listed.clear();
  }
}
