import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';

SemesterInfo semester(String id, LocalDate start, LocalDate end) =>
    SemesterInfo(id: id, name: id, start: start, end: end);

void main() {
  // Newest first, like ScheduleRepository.watchSemesters.
  final spring = semester(
    'spring',
    LocalDate(2027, 3, 7),
    LocalDate(2027, 6, 25),
  );
  final autumn = semester(
    'autumn',
    LocalDate(2026, 10, 11),
    LocalDate(2027, 1, 15),
  );

  test('prefers the semester running today', () {
    expect(pickSemester([spring, autumn], LocalDate(2026, 11, 2)), autumn);
  });

  test('falls back to the latest semester', () {
    expect(pickSemester([spring, autumn], LocalDate(2026, 8, 1)), spring);
  });

  test('nothing restored, nothing picked', () {
    expect(pickSemester(const [], LocalDate(2026, 11, 2)), isNull);
  });
}
