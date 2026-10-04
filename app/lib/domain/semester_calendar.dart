import 'local_date.dart';
import 'schedule_types.dart';

/// First day of the week containing [date], for a week starting on the ISO
/// weekday [weekStart].
LocalDate startOfWeek(LocalDate date, int weekStart) =>
    date.addDays(-((date.weekday - weekStart + 7) % 7));

/// Week math for one semester. Week 1 is the week containing the start date.
class SemesterCalendar {
  const SemesterCalendar(this.semester);

  final SemesterInfo semester;

  LocalDate get firstWeekStart =>
      startOfWeek(semester.start, semester.weekStart);

  /// 1-based; 0 or negative before the semester, > [weekCount] after it.
  int weekNumberOf(LocalDate date) =>
      firstWeekStart.daysUntil(startOfWeek(date, semester.weekStart)) ~/ 7 + 1;

  int get weekCount => weekNumberOf(semester.end);

  LocalDate weekStartOf(int weekNumber) =>
      firstWeekStart.addDays((weekNumber - 1) * 7);

  /// The visible days of the week beginning at [weekStartDate], each with its
  /// real date. Hidden days are skipped without shifting the others (v1
  /// derived dates from the column index and showed wrong days).
  List<LocalDate> visibleDatesOfWeek(LocalDate weekStartDate) => [
    for (var i = 0; i < 7; i++)
      if (semester.visibleDays.contains(weekStartDate.addDays(i).weekday))
        weekStartDate.addDays(i),
  ];

  /// Fraction of the semester's days that have passed, clamped to 0..1.
  double progressAt(LocalDate today) {
    final total = semester.start.daysUntil(semester.end) + 1;
    if (total <= 0) return 0;
    final elapsed = semester.start.daysUntil(today) + 1;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}
