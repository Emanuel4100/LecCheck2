import 'dart:convert';

import 'package:material_color_utilities/material_color_utilities.dart';

import '../../app/theme/colors.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../db/schedule_repository.dart';

/// Backup files: JSON v3 (this app) and v1/v2 exports from the old LecCheck.
class BackupService {
  BackupService(this.repo);

  final ScheduleRepository repo;

  static const format = 'leccheck';
  static const version = 3;

  Future<String> exportJson() async {
    final tables = await repo.exportRows();
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    });
  }

  /// Imports a backup and returns how many semesters it contained.
  /// Throws [FormatException] for anything that isn't a LecCheck backup.
  Future<int> importJson(String text) async {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      rethrow;
    }
    if (json is! Map<String, Object?>) {
      throw const FormatException('Not a LecCheck backup');
    }
    if (json['format'] == format && json['tables'] is Map) {
      return _importV3(json);
    }
    if (json['semesters'] is List) {
      final semesters = (json['semesters']! as List).whereType<Map>();
      for (final s in semesters) {
        await _importLegacySemester(s.cast<String, Object?>());
      }
      return semesters.length;
    }
    if (json['courses'] is List && json['startDate'] is String) {
      await _importLegacySemester({
        ...json,
        'id': json['id'] ?? 'semester_1',
        'name': json['name'] ?? 'Semester',
      });
      return 1;
    }
    throw const FormatException('Not a LecCheck backup');
  }

  Future<int> _importV3(Map<String, Object?> json) async {
    final tables = <String, List<Map<String, Object?>>>{
      for (final e in (json['tables']! as Map).entries)
        if (e.value is List)
          e.key as String: [
            for (final row in e.value as List)
              if (row is Map) row.cast<String, Object?>(),
          ],
    };
    await repo.importRows(tables);
    return tables['semesters']?.length ?? 0;
  }

  // ------------------------------------------------------------- legacy --

  /// One v1/v2 semester: meetings become rules; lectures with a status,
  /// notes or recording become session overrides; no-class dates become
  /// ranges.
  Future<void> _importLegacySemester(Map<String, Object?> s) async {
    final semesterId = s['id']?.toString() ?? ScheduleRepository.newId();
    final start = _date(s['startDate']) ?? LocalDate.today();
    final end = _date(s['endDate']) ?? start.addDays(13 * 7);
    final visible = (s['visibleWeekdays'] as List?)?.whereType<int>().toSet();
    await repo.saveSemester(
      SemesterInfo(
        id: semesterId,
        name: (s['name'] as String?)?.trim().isNotEmpty ?? false
            ? s['name']! as String
            : 'Semester',
        start: start,
        end: end,
        weekStart: (s['weekStartsOn'] as int?)?.clamp(1, 7) ?? 7,
        visibleDays: visible == null || visible.isEmpty
            ? const {1, 2, 3, 4, 5, 6, 7}
            : visible,
      ),
    );
    if (s['use24HourTime'] is bool) {
      await repo.setUse24h(s['use24HourTime']! as bool);
    }
    if (s['enableMeetingNumbers'] is bool) {
      await repo.setMeetingNumbers(s['enableMeetingNumbers']! as bool);
    }

    final noClass = <LocalDate>{
      for (final d in (s['noClassDates'] as List?) ?? const []) ?_date(d),
    };
    for (final range in _mergeDates(noClass)) {
      await repo.saveNoClassRange(
        NoClassRange(
          id: ScheduleRepository.newId(),
          semesterId: semesterId,
          start: range.$1,
          end: range.$2,
        ),
      );
    }

    var order = 0;
    for (final raw in (s['courses'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final c = raw.cast<String, Object?>();
      final courseId = c['id']?.toString() ?? ScheduleRepository.newId();
      final meetings = <MeetingRule>[];
      for (final rawMeeting in (c['meetings'] as List?) ?? const []) {
        if (rawMeeting is! Map) continue;
        final m = rawMeeting.cast<String, Object?>();
        final once = _date(m['specificDate']);
        meetings.add(
          MeetingRule(
            id: m['id']?.toString() ?? ScheduleRepository.newId(),
            courseId: courseId,
            type: _legacyType(m['type']),
            kind: once == null ? MeetingKind.weekly : MeetingKind.once,
            weekday: once == null ? (m['weekday'] as int?) ?? 7 : null,
            date: once,
            startMin: _minutes(m['start']) ?? 600,
            endMin: _minutes(m['end']) ?? 660,
            location: m['room']?.toString() ?? '',
            links: _links(m['links']),
          ),
        );
      }
      await repo.saveCourse(
        CourseInfo(
          id: courseId,
          semesterId: semesterId,
          name: c['name']?.toString() ?? '',
          code: c['code']?.toString() ?? '',
          lecturer: c['lecturer']?.toString() ?? '',
          website: c['link']?.toString() ?? '',
          notes: c['notes']?.toString() ?? '',
          links: _links(c['extraLinks']),
          colorKey: _nearestPaletteKey(c['color']),
          sortOrder: order++,
        ),
        meetings: meetings,
        requirements: const [],
      );

      for (final rawLecture in (c['lectures'] as List?) ?? const []) {
        if (rawLecture is! Map) continue;
        final lecture = rawLecture.cast<String, Object?>();
        final date = _date(lecture['date']);
        if (date == null) continue;
        var status = _legacyStatus(lecture['status']);
        // v1 wrote holidays into every lecture; the no-class layer covers it.
        if (status == AttendanceStatus.canceled && noClass.contains(date)) {
          status = null;
        }
        final notes = lecture['notes']?.toString() ?? '';
        final recording = lecture['recordingLink']?.toString();
        if (status == null && notes.isEmpty && (recording?.isEmpty ?? true)) {
          continue;
        }
        final meetingId =
            lecture['meetingId']?.toString() ??
            _matchMeeting(meetings, date, lecture)?.id;
        if (meetingId == null) continue;
        await repo.saveOverride(
          SessionOverride(
            meetingId: meetingId,
            originalDate: date,
            status: status,
            notes: notes,
            recordingUrl: recording?.isEmpty ?? true ? null : recording,
          ),
        );
      }
    }
  }

  static LocalDate? _date(Object? value) {
    if (value is! String || value.length < 10) return null;
    return LocalDate.tryParse(value.substring(0, 10));
  }

  static int? _minutes(Object? hhmm) {
    if (hhmm is! String) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  static List<NamedLink> _links(Object? raw) => [
    for (final l in (raw as List?) ?? const [])
      if (l is Map && (l['url']?.toString().isNotEmpty ?? false))
        NamedLink(
          title: l['title']?.toString() ?? '',
          url: l['url'].toString(),
        ),
  ];

  /// v1 stored the type as the label in the UI language at the time.
  static SessionType _legacyType(Object? label) =>
      switch (label?.toString().trim()) {
        'Lecture' || 'הרצאה' => SessionType.lecture,
        'Practice' || 'תרגול' => SessionType.practice,
        'Lab' || 'מעבדה' => SessionType.lab,
        _ => SessionType.other,
      };

  static AttendanceStatus? _legacyStatus(Object? key) => switch (key) {
    'attended' => AttendanceStatus.attended,
    'missed' => AttendanceStatus.missed,
    'skipped' => AttendanceStatus.skipped,
    'canceled' => AttendanceStatus.canceled,
    'watchedRecording' => AttendanceStatus.watched,
    _ => null,
  };

  static MeetingRule? _matchMeeting(
    List<MeetingRule> meetings,
    LocalDate date,
    Map<String, Object?> lecture,
  ) {
    final start = _minutes(lecture['start']);
    final end = _minutes(lecture['end']);
    for (final m in meetings) {
      final sameDay = m.kind == MeetingKind.once
          ? m.date == date
          : m.weekday == date.weekday;
      if (sameDay && m.startMin == start && m.endMin == end) return m;
    }
    return null;
  }

  /// Consecutive dates → inclusive ranges.
  static List<(LocalDate, LocalDate)> _mergeDates(Set<LocalDate> dates) {
    final sorted = dates.toList()..sort();
    final ranges = <(LocalDate, LocalDate)>[];
    for (final d in sorted) {
      if (ranges.isNotEmpty && ranges.last.$2.daysUntil(d) == 1) {
        ranges[ranges.length - 1] = (ranges.last.$1, d);
      } else {
        ranges.add((d, d));
      }
    }
    return ranges;
  }

  /// Closest curated course color by hue.
  static String _nearestPaletteKey(Object? argb) {
    if (argb is! int) return 'ocean';
    final hue = Hct.fromInt(argb).hue;
    String best = 'ocean';
    var bestDistance = double.infinity;
    for (final e in coursePaletteSeeds.entries) {
      final diff = (Hct.fromInt(e.value).hue - hue).abs();
      final distance = diff > 180 ? 360 - diff : diff;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = e.key;
      }
    }
    return best;
  }
}
