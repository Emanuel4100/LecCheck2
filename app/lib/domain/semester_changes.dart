import 'occurrence_engine.dart';
import 'schedule_types.dart';
import 'semester_data.dart';

/// How many marked sessions of [data] the semester [changed] (new dates or
/// week start) would no longer produce. Their records are kept and come back
/// if the change is undone, but they leave the stats meanwhile: the semester
/// form asks first.
///
/// Comparing the sessions themselves, not just their dates, also catches
/// every-other-week meetings anchored on the semester's start, whose weeks
/// flip when it moves by a week.
int markedSessionsLost(SemesterData data, SemesterInfo changed) {
  final now = OccurrenceEngine.expand(
    semester: changed,
    meetings: data.meetings,
    overrides: data.overrides,
    noClassRanges: data.noClassRanges,
  ).byId;
  return OccurrenceEngine.expand(
    semester: data.semester,
    meetings: data.meetings,
    overrides: data.overrides,
    noClassRanges: data.noClassRanges,
  ).all.where((o) {
    final status = o.explicitStatus;
    return status != null && status.isDecided && !now.containsKey(o.id);
  }).length;
}
