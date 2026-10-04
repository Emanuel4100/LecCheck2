import 'occurrence.dart';
import 'schedule_types.dart';

enum RequirementState {
  /// Comfortable margin.
  onTrack,

  /// Only one more absence allowed.
  warning,

  /// Every remaining session must be attended.
  atRisk,

  /// Too many absences — the minimum can no longer be reached.
  failed,

  /// Semester over (nothing left to mark) and the minimum was reached.
  met,
}

class RequirementProgress {
  const RequirementProgress({
    required this.requirement,
    required this.total,
    required this.required,
    required this.attended,
    required this.absences,
    required this.remaining,
  });

  final AttendanceRequirement requirement;

  /// Non-canceled sessions in scope (past and future).
  final int total;

  /// Sessions that must be attended: ceil(total × minPercent).
  final int required;
  final int attended;
  final int absences;

  /// Sessions not decided yet (future or unmarked).
  final int remaining;

  @override
  bool operator ==(Object other) =>
      other is RequirementProgress &&
      other.requirement == requirement &&
      other.total == total &&
      other.required == required &&
      other.attended == attended &&
      other.absences == absences &&
      other.remaining == remaining;

  @override
  int get hashCode =>
      Object.hash(requirement, total, required, attended, absences, remaining);

  int get maxAbsences => total - required;

  /// "You can miss N more". Negative once the requirement failed.
  int get slack => maxAbsences - absences;

  RequirementState get state {
    if (slack < 0) return RequirementState.failed;
    if (remaining == 0) return RequirementState.met;
    if (slack == 0) return RequirementState.atRisk;
    if (slack == 1) return RequirementState.warning;
    return RequirementState.onTrack;
  }
}

/// Evaluates [requirement] against the sessions of its course.
///
/// Absences are missed + skipped sessions, plus watched recordings unless the
/// requirement says recordings count.
RequirementProgress evaluateRequirement(
  AttendanceRequirement requirement,
  Iterable<Occurrence> courseSessions,
) {
  var total = 0;
  var attended = 0;
  var absences = 0;
  var remaining = 0;
  for (final o in courseSessions) {
    if (o.courseId != requirement.courseId) continue;
    if (requirement.type != null && o.type != requirement.type) continue;
    switch (o.status) {
      case AttendanceStatus.canceled:
        continue;
      case AttendanceStatus.attended:
        attended++;
      case AttendanceStatus.watched:
        if (requirement.recordingsCount) {
          attended++;
        } else {
          absences++;
        }
      case AttendanceStatus.missed:
      case AttendanceStatus.skipped:
        absences++;
      case AttendanceStatus.pending:
        remaining++;
    }
    total++;
  }
  final pct = requirement.minPercent.clamp(0, 100);
  // Integer ceil(total * pct / 100) avoids floating-point surprises.
  final required = (total * pct + 99) ~/ 100;
  return RequirementProgress(
    requirement: requirement,
    total: total,
    required: required,
    attended: attended,
    absences: absences,
    remaining: remaining,
  );
}
