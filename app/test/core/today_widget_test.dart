import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leccheck/app/format.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/home_widget/today_widget.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/l10n/gen/app_localizations_en.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  late AppDatabase db;
  late ScheduleRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
  });
  tearDown(() => db.close());

  Future<void> semester(String id, String start, String end, String day) async {
    await repo.saveSemester(
      SemesterInfo(
        id: id,
        name: 'Semester $id',
        start: LocalDate.parse(start),
        end: LocalDate.parse(end),
      ),
    );
    await repo.saveCourse(
      CourseInfo(id: 'c$id', semesterId: id, name: 'Course $id'),
      meetings: [
        MeetingRule(
          id: 'm$id',
          courseId: 'c$id',
          type: SessionType.lecture,
          kind: MeetingKind.weekly,
          weekday: LocalDate.parse(day).weekday,
          startMin: 600,
          endMin: 720,
        ),
      ],
      requirements: const [],
    );
  }

  test('a week of days from every semester running then', () async {
    // A semester ending on Monday, and the next one starting on Thursday.
    await semester('a', '2026-07-05', '2026-10-19', '2026-10-19');
    await semester('b', '2026-10-22', '2027-01-22', '2026-10-22');
    final today = LocalDate.parse('2026-10-18');
    final window = await repo.loadWindow(today, today.addDays(6));
    final snapshot = TodayWidget.snapshot(
      window: window,
      now: DateTime(2026, 10, 18, 8),
      l: AppLocalizationsEn(),
      fmt: Fmt('en', use24h: true),
      numbers: true,
    );
    final days = snapshot['days']! as Map<String, Object?>;
    expect(days.keys, hasLength(TodayWidget.days));
    expect(days.keys.first, '2026-10-18');
    List<Object?> sessionsOn(String iso) =>
        (days[iso]! as Map<String, Object?>)['sessions']! as List<Object?>;
    expect(sessionsOn('2026-10-19'), hasLength(1)); // semester a
    expect(sessionsOn('2026-10-20'), isEmpty);
    expect(sessionsOn('2026-10-22'), hasLength(1)); // semester b
    expect(
      (days['2026-10-22']! as Map<String, Object?>)['subtitle'],
      'Week 1 of 14',
    );
    // Between semesters: no week line.
    expect((days['2026-10-20']! as Map<String, Object?>)['subtitle'], '');
    // Today's day is also at the top level (for an older widget).
    expect(snapshot['title'], (days['2026-10-18']! as Map)['title']);
  });
}
