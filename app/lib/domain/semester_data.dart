import 'schedule_types.dart';

/// Everything the occurrence engine and the UI need for one semester.
class SemesterData {
  const SemesterData({
    required this.semester,
    required this.courses,
    required this.meetings,
    required this.overrides,
    required this.noClassRanges,
    required this.requirements,
  });

  final SemesterInfo semester;
  final List<CourseInfo> courses;
  final List<MeetingRule> meetings;
  final List<SessionOverride> overrides;
  final List<NoClassRange> noClassRanges;
  final List<AttendanceRequirement> requirements;

  CourseInfo? course(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  MeetingRule? meeting(String id) {
    for (final m in meetings) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<MeetingRule> meetingsOf(String courseId) => [
    for (final m in meetings)
      if (m.courseId == courseId) m,
  ];

  List<AttendanceRequirement> requirementsOf(String courseId) => [
    for (final r in requirements)
      if (r.courseId == courseId) r,
  ];
}
