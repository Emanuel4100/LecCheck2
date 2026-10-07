import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/backup/backup_service.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/schedule_types.dart';

/// A backup exactly as LecCheck v1 (v2 JSON format) exported it.
final _v1Backup = jsonEncode({
  'v': 2,
  'savedAt': 1745400000000,
  'activeSemesterId': 'sem_1',
  'semesters': [
    {
      'id': 'sem_1',
      'name': 'סמסטר ב',
      'startDate': '2026-03-15T00:00:00.000',
      'endDate': '2026-06-26T00:00:00.000',
      'language': 'he',
      'weekStartsOn': 7,
      'visibleWeekdays': [7, 1, 2, 3, 4],
      'enableMeetingNumbers': true,
      'noClassDates': ['2026-04-01', '2026-04-02', '2026-04-03', '2026-05-12'],
      'use24HourTime': true,
      'courses': [
        {
          'id': 'c_1',
          'name': 'אלגוריתמים',
          'lecturer': 'Prof. Levi',
          'code': '234247',
          'link': 'https://moodle.example/algo',
          'notes': 'Exam: open book',
          'color': 0xFF2A7BCC,
          'extraLinks': [
            {'title': 'Syllabus', 'url': 'https://example/syllabus.pdf'},
          ],
          'meetings': [
            {
              'id': 'm_1',
              'weekday': 7,
              'start': '10:30',
              'end': '12:30',
              'room': 'Taub 2',
              'type': 'הרצאה',
              'links': [],
            },
            {
              'id': 'm_2',
              'weekday': 2,
              'start': '14:00',
              'end': '15:00',
              'room': 'Taub 4',
              'type': 'Practice',
              'links': [
                {'title': 'Zoom', 'url': 'https://zoom.us/j/9'},
              ],
            },
          ],
          'lectures': [
            {
              'courseId': 'c_1',
              'date': '2026-03-15T00:00:00.000',
              'start': '10:30',
              'end': '12:30',
              'type': 'הרצאה',
              'status': 'attended',
              'meetingId': 'm_1',
              'notes': 'Intro',
            },
            {
              'courseId': 'c_1',
              'date': '2026-03-17T00:00:00.000',
              'start': '14:00',
              'end': '15:00',
              'type': 'Practice',
              'status': 'watchedRecording',
              'recordingLink': 'https://rec/1',
            },
            {
              // v1 wrote holidays into the lecture itself.
              'courseId': 'c_1',
              'date': '2026-05-12T00:00:00.000',
              'start': '14:00',
              'end': '15:00',
              'type': 'Practice',
              'status': 'canceled',
              'meetingId': 'm_2',
            },
            {
              'courseId': 'c_1',
              'date': '2026-03-22T00:00:00.000',
              'start': '10:30',
              'end': '12:30',
              'type': 'הרצאה',
              'status': 'pending',
              'meetingId': 'm_1',
            },
          ],
        },
      ],
    },
  ],
});

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late ScheduleRepository repo;
  late BackupService backup;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    backup = BackupService(repo);
  });
  tearDown(() => db.close());

  test(
    'imports a v1 backup with marks, links, holidays and type labels',
    () async {
      expect(await backup.importJson(_v1Backup), 1);
      final data = (await repo.loadSemesterData('sem_1'))!;

      expect(data.semester.name, 'סמסטר ב');
      expect(data.semester.weekStart, DateTime.sunday);
      expect(data.semester.visibleDays, {7, 1, 2, 3, 4});

      final course = data.courses.single;
      expect(course.name, 'אלגוריתמים');
      expect(course.website, 'https://moodle.example/algo');
      expect(course.links.single.title, 'Syllabus');
      expect(course.colorKey, 'ocean');

      final types = {for (final m in data.meetings) m.id: m.type};
      expect(types, {'m_1': SessionType.lecture, 'm_2': SessionType.practice});
      expect(data.meetings.firstWhere((m) => m.id == 'm_1').startMin, 630);

      // Consecutive no-class dates merge into ranges.
      expect(data.noClassRanges.map((r) => (r.start.toIso(), r.end.toIso())), [
        ('2026-04-01', '2026-04-03'),
        ('2026-05-12', '2026-05-12'),
      ]);

      final index = OccurrenceEngine.expand(
        semester: data.semester,
        meetings: data.meetings,
        overrides: data.overrides,
        noClassRanges: data.noClassRanges,
      );
      final first = index.byId['m_1_20260315']!;
      expect(first.status, AttendanceStatus.attended);
      expect(first.notes, 'Intro');
      // Matched to m_2 by weekday + time even without a meetingId.
      final practice = index.byId['m_2_20260317']!;
      expect(practice.status, AttendanceStatus.watched);
      expect(practice.recordingUrl, 'https://rec/1');
      // The holiday comes from the no-class layer, not a stored "canceled".
      final holiday = index.byId['m_2_20260512']!;
      expect(holiday.canceledByNoClassDay, isTrue);
      expect(holiday.explicitStatus, isNull);
      // Pending lectures without notes don't create rows.
      expect(data.overrides, hasLength(2));
    },
  );

  test('v3 export and import round-trip', () async {
    await backup.importJson(_v1Backup);
    final exported = await backup.exportJson();
    final json = jsonDecode(exported) as Map<String, Object?>;
    expect(json['format'], 'leccheck');
    expect(json['version'], 3);

    final otherDb = AppDatabase(NativeDatabase.memory());
    addTearDown(otherDb.close);
    final otherRepo = ScheduleRepository(otherDb);
    expect(await BackupService(otherRepo).importJson(exported), 1);
    final a = (await repo.loadSemesterData('sem_1'))!;
    final b = (await otherRepo.loadSemesterData('sem_1'))!;
    expect(b.courses, a.courses);
    expect(b.meetings, a.meetings);
    expect(b.noClassRanges, a.noClassRanges);
    expect(b.overrides.map((o) => o.id), a.overrides.map((o) => o.id));
  });

  test('rejects files that are not LecCheck backups', () async {
    expect(() => backup.importJson('{"hello": 1}'), throwsFormatException);
    expect(() => backup.importJson('not json'), throwsFormatException);
  });
}
