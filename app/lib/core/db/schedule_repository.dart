import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';

import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_data.dart';
import 'app_database.dart';
import 'mappers.dart';
import 'tables.dart';

/// Receives every local change so it can be synced. Installed by the sync
/// engine while signed in; called inside the write transaction.
abstract interface class ChangeRecorder {
  Future<void> record(String table, String rowId, Map<String, Object?> patch);
}

/// Settings that follow the account.
class UserPrefs {
  const UserPrefs({this.use24h, this.meetingNumbers = true});

  /// Null = follow the device setting.
  final bool? use24h;
  final bool meetingNumbers;

  @override
  bool operator ==(Object other) =>
      other is UserPrefs &&
      other.use24h == use24h &&
      other.meetingNumbers == meetingNumbers;

  @override
  int get hashCode => Object.hash(use24h, meetingNumbers);
}

/// Rows tombstoned by one delete, so the delete can be undone.
class DeletionReceipt {
  DeletionReceipt._();
  final List<(String table, String id)> _rows = [];
  bool get isEmpty => _rows.isEmpty;
}

class _Adapter<D extends DataClass> {
  const _Adapter(this.table, this.fromJson);
  final TableInfo<Table, D> table;
  final D Function(Map<String, dynamic> json) fromJson;
  String get name => table.actualTableName;

  /// Upserts a full row. Lives here so [D] is the real row type even when
  /// the adapter is reached through a `_Adapter<DataClass>` reference.
  Future<void> upsert(GeneratedDatabase db, Map<String, dynamic> json) {
    final row = fromJson(json) as Insertable<D>;
    // toColumns(false) keeps nulls as real values: a data class used directly
    // treats null as "absent", and the upsert would never clear a column.
    return db
        .into(table)
        .insertOnConflictUpdate(RawValuesInsertable<D>(row.toColumns(false)));
  }
}

/// The only way the app reads and writes schedule data.
///
/// Writes are local and transactional; each changed field is also handed to
/// the [recorder] (when sync is on) as a patch for the outbox.
class ScheduleRepository {
  ScheduleRepository(this.db);

  final AppDatabase db;
  ChangeRecorder? recorder;

  static const _uuid = Uuid();
  static const _settingsId = 'me';

  /// Time-ordered UUIDv7.
  static String newId() => _uuid.v7();

  late final _semesters = _Adapter<SemesterRow>(
    db.semesters,
    SemesterRow.fromJson,
  );
  late final _courses = _Adapter<CourseRow>(db.courses, CourseRow.fromJson);
  late final _meetings = _Adapter<MeetingRow>(db.meetings, MeetingRow.fromJson);
  late final _overrides = _Adapter<SessionOverrideRow>(
    db.sessionOverrides,
    SessionOverrideRow.fromJson,
  );
  late final _noClass = _Adapter<NoClassRangeRow>(
    db.noClassRanges,
    NoClassRangeRow.fromJson,
  );
  late final _requirements = _Adapter<RequirementRow>(
    db.requirements,
    RequirementRow.fromJson,
  );
  late final _settings = _Adapter<UserSettingsRow>(
    db.userSettings,
    UserSettingsRow.fromJson,
  );

  late final Map<String, _Adapter<DataClass>> _byName = {
    for (final a in <_Adapter<DataClass>>[
      _semesters,
      _courses,
      _meetings,
      _overrides,
      _noClass,
      _requirements,
      _settings,
    ])
      a.name: a,
  };

  // ---------------------------------------------------------------- reads --

  Stream<List<SemesterInfo>> watchSemesters() =>
      (db.select(db.semesters)
            ..where((s) => s.deleted.equals(false))
            ..orderBy([(s) => OrderingTerm.desc(s.startDate)]))
          .watch()
          .map((rows) => [for (final r in rows) r.toDomain()]);

  Future<List<SemesterInfo>> semesters() => watchSemesters().first;

  /// Re-emits whenever any schedule table changes (once per transaction).
  Stream<SemesterData?> watchSemesterData(String semesterId) => db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.semesters,
          db.courses,
          db.meetings,
          db.sessionOverrides,
          db.noClassRanges,
          db.requirements,
        },
      )
      .watch()
      .asyncMap((_) => loadSemesterData(semesterId));

  Future<SemesterData?> loadSemesterData(String semesterId) async {
    final semester =
        await (db.select(db.semesters)
              ..where((s) => s.id.equals(semesterId) & s.deleted.equals(false)))
            .getSingleOrNull();
    if (semester == null) return null;

    final courses =
        await (db.select(db.courses)
              ..where(
                (c) =>
                    c.semesterId.equals(semesterId) & c.deleted.equals(false),
              )
              ..orderBy([
                (c) => OrderingTerm.asc(c.sortOrder),
                (c) => OrderingTerm.asc(c.name),
              ]))
            .get();
    final courseIds = [for (final c in courses) c.id];
    final meetings = courseIds.isEmpty
        ? const <MeetingRow>[]
        : await (db.select(db.meetings)..where(
                (m) => m.courseId.isIn(courseIds) & m.deleted.equals(false),
              ))
              .get();
    final meetingIds = [for (final m in meetings) m.id];
    final overrides = meetingIds.isEmpty
        ? const <SessionOverrideRow>[]
        : await (db.select(db.sessionOverrides)..where(
                (o) => o.meetingId.isIn(meetingIds) & o.deleted.equals(false),
              ))
              .get();
    final ranges =
        await (db.select(db.noClassRanges)
              ..where(
                (r) =>
                    r.semesterId.equals(semesterId) & r.deleted.equals(false),
              )
              ..orderBy([(r) => OrderingTerm.asc(r.startDate)]))
            .get();
    final requirements = courseIds.isEmpty
        ? const <RequirementRow>[]
        : await (db.select(db.requirements)..where(
                (r) => r.courseId.isIn(courseIds) & r.deleted.equals(false),
              ))
              .get();

    return SemesterData(
      semester: semester.toDomain(),
      courses: [for (final r in courses) r.toDomain()],
      meetings: [for (final r in meetings) r.toDomain()],
      overrides: [for (final r in overrides) r.toDomain()],
      noClassRanges: [for (final r in ranges) r.toDomain()],
      requirements: [for (final r in requirements) r.toDomain()],
    );
  }

  Stream<UserPrefs> watchUserPrefs() =>
      (db.select(
        db.userSettings,
      )..where((u) => u.id.equals(_settingsId))).watchSingleOrNull().map(
        (r) => r == null || r.deleted
            ? const UserPrefs()
            : UserPrefs(use24h: r.use24h, meetingNumbers: r.meetingNumbers),
      );

  // --------------------------------------------------------------- writes --

  Future<void> saveSemester(SemesterInfo semester) =>
      db.transaction(() => _upsert(_semesters, semester.toRow()));

  /// Tombstones the semester with all its courses, meetings, sessions,
  /// requirements and no-class ranges.
  Future<DeletionReceipt> deleteSemester(String semesterId) =>
      db.transaction(() async {
        final receipt = DeletionReceipt._();
        final courseIds = await _ids(
          db.select(db.courses)..where(
            (c) => c.semesterId.equals(semesterId) & c.deleted.equals(false),
          ),
        );
        for (final id in courseIds) {
          await _deleteCourseTree(id, receipt);
        }
        final rangeIds = await _ids(
          db.select(db.noClassRanges)..where(
            (r) => r.semesterId.equals(semesterId) & r.deleted.equals(false),
          ),
        );
        for (final id in rangeIds) {
          await _tombstone(_noClass, id, receipt);
        }
        await _tombstone(_semesters, semesterId, receipt);
        return receipt;
      });

  /// Saves a course with its full list of meetings and requirements; meetings
  /// or requirements missing from the lists are deleted.
  Future<void> saveCourse(
    CourseInfo course, {
    required List<MeetingRule> meetings,
    required List<AttendanceRequirement> requirements,
  }) => db.transaction(() async {
    await _upsert(_courses, course.toRow());

    final keepMeetings = {for (final m in meetings) m.id};
    final oldMeetings = await _ids(
      db.select(db.meetings)
        ..where((m) => m.courseId.equals(course.id) & m.deleted.equals(false)),
    );
    for (final m in meetings) {
      await _upsert(_meetings, m.toRow());
    }
    final receipt = DeletionReceipt._();
    for (final id in oldMeetings) {
      if (!keepMeetings.contains(id)) await _deleteMeetingTree(id, receipt);
    }

    final keepReqs = {for (final r in requirements) r.id};
    final oldReqs = await _ids(
      db.select(db.requirements)
        ..where((r) => r.courseId.equals(course.id) & r.deleted.equals(false)),
    );
    for (final r in requirements) {
      await _upsert(_requirements, r.toRow());
    }
    for (final id in oldReqs) {
      if (!keepReqs.contains(id)) await _tombstone(_requirements, id, receipt);
    }
  });

  Future<DeletionReceipt> deleteCourse(String courseId) =>
      db.transaction(() async {
        final receipt = DeletionReceipt._();
        await _deleteCourseTree(courseId, receipt);
        return receipt;
      });

  Future<DeletionReceipt> deleteMeeting(String meetingId) =>
      db.transaction(() async {
        final receipt = DeletionReceipt._();
        await _deleteMeetingTree(meetingId, receipt);
        return receipt;
      });

  /// Restores everything a delete tombstoned.
  Future<void> undoDeletion(DeletionReceipt receipt) =>
      db.transaction(() async {
        for (final (table, id) in receipt._rows.reversed) {
          await _patch(_byName[table]!, id, {'deleted': false});
        }
      });

  /// Sets (or clears, with `null`) the explicit status of one session.
  Future<void> setStatus(Occurrence session, AttendanceStatus? status) =>
      db.transaction(() => _patchOverride(session, {'status': status?.key}));

  /// Sets a status knowing only the meeting and date (notification actions,
  /// home-screen widget).
  Future<void> setStatusFor({
    required String meetingId,
    required LocalDate originalDate,
    required AttendanceStatus? status,
  }) => db.transaction(
    () => _patchOverrideFor(meetingId, originalDate, {'status': status?.key}),
  );

  Future<void> setStatuses(
    Iterable<Occurrence> sessions,
    AttendanceStatus status,
  ) => db.transaction(() async {
    for (final s in sessions) {
      await _patchOverride(s, {'status': status.key});
    }
  });

  Future<void> setSessionNotes(Occurrence session, String notes) =>
      db.transaction(() => _patchOverride(session, {'notes': notes}));

  Future<void> setRecordingUrl(Occurrence session, String? url) {
    final trimmed = url?.trim();
    return db.transaction(
      () => _patchOverride(session, {
        'recordingUrl': trimmed == null || trimmed.isEmpty ? null : trimmed,
      }),
    );
  }

  /// "This week only" change of date, time or room.
  Future<void> moveSession(
    Occurrence session, {
    required LocalDate date,
    required int startMin,
    required int endMin,
    required String location,
  }) => db.transaction(
    () => _patchOverride(session, {
      'movedDate': date == session.originalDate ? null : date.toIso(),
      'movedStartMin': startMin,
      'movedEndMin': endMin,
      'movedLocation': location,
    }),
  );

  Future<void> resetSessionMove(Occurrence session) => db.transaction(
    () => _patchOverride(session, {
      'movedDate': null,
      'movedStartMin': null,
      'movedEndMin': null,
      'movedLocation': null,
    }),
  );

  Future<void> saveNoClassRange(NoClassRange range) =>
      db.transaction(() => _upsert(_noClass, range.toRow()));

  Future<DeletionReceipt> deleteNoClassRange(String id) =>
      db.transaction(() async {
        final receipt = DeletionReceipt._();
        await _tombstone(_noClass, id, receipt);
        return receipt;
      });

  /// Writes full rows (backup import). Unknown tables are ignored.
  Future<void> importRows(Map<String, List<Map<String, Object?>>> tables) =>
      db.transaction(() async {
        for (final MapEntry(key: table, value: rows) in tables.entries) {
          final adapter = _byName[table];
          if (adapter == null) continue;
          for (final row in rows) {
            await _upsert(adapter, adapter.fromJson({...row, 'updatedAt': 0}));
          }
        }
      });

  /// Writes a complete session override (backup import).
  Future<void> saveOverride(SessionOverride o) => db.transaction(
    () => _upsert(
      _overrides,
      SessionOverrideRow(
        id: o.id,
        deleted: false,
        updatedAt: 0,
        meetingId: o.meetingId,
        originalDate: o.originalDate.toIso(),
        status: o.status?.key,
        notes: o.notes,
        recordingUrl: o.recordingUrl,
        movedDate: o.movedDate?.toIso(),
        movedStartMin: o.movedStartMin,
        movedEndMin: o.movedEndMin,
        movedLocation: o.movedLocation,
      ),
    ),
  );

  /// Writes a row received from the sync server (already merged with any
  /// pending local patches). Not recorded, so it isn't sent back.
  Future<void> applyRemoteRow(String table, Map<String, Object?> row) async {
    final adapter = _byName[table];
    final id = row['id'];
    if (adapter == null || id is! String) return;
    final existing = await _find(adapter, id);
    final merged = {...?existing?.toJson(), ...row}..remove('updatedAt');
    try {
      await adapter.upsert(db, {...merged, 'updatedAt': _now()});
    } on Object catch (e) {
      // A row from a newer app version may miss columns this version needs.
      debugPrint('Skipping remote $table/$id: $e');
    }
  }

  /// Deletes all local data (used when switching to a different account).
  Future<void> wipeAll() => db.transaction(() async {
    for (final adapter in _byName.values) {
      await db.delete(adapter.table).go();
    }
    await db.delete(db.outbox).go();
  });

  /// Every live row of every synced table, keyed by table name.
  Future<Map<String, List<Map<String, Object?>>>> exportRows() async => {
    for (final a in _byName.values)
      a.name: [
        for (final row in await (db.select(
          a.table,
        )..where((t) => (t as SyncedRow).deleted.equals(false))).get())
          row.toJson()..remove('updatedAt'),
      ],
  };

  Future<void> setUse24h(bool? value) =>
      db.transaction(() => _patchSettings({'use24h': value}));

  Future<void> setMeetingNumbers(bool value) =>
      db.transaction(() => _patchSettings({'meetingNumbers': value}));

  // ------------------------------------------------------------ internals --

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<List<String>> _ids<T extends HasResultSet, D extends DataClass>(
    SimpleSelectStatement<T, D> query,
  ) async => [
    for (final row in await query.get()) row.toJson()['id']! as String,
  ];

  Future<D?> _find<D extends DataClass>(_Adapter<D> a, String id) => (db.select(
    a.table,
  )..where((t) => (t as SyncedRow).id.equals(id))).getSingleOrNull();

  /// Stores [json] as the full row and records [patch] for sync.
  Future<void> _write<D extends DataClass>(
    _Adapter<D> a,
    Map<String, Object?> json,
    Map<String, Object?> patch,
  ) async {
    await a.upsert(db, {...json, 'updatedAt': _now()});
    final r = recorder;
    if (r != null && patch.isNotEmpty) {
      await r.record(a.name, json['id']! as String, patch);
    }
  }

  Future<void> _upsert<D extends DataClass>(_Adapter<D> a, D row) async {
    final next = row.toJson()..remove('updatedAt');
    final existing = await _find(a, next['id']! as String);
    if (existing == null) {
      await _write(a, next, next);
      return;
    }
    final current = existing.toJson()..remove('updatedAt');
    final changed = _changed(current, next);
    if (changed.isNotEmpty) await _write(a, {...current, ...changed}, changed);
  }

  Future<void> _patch<D extends DataClass>(
    _Adapter<D> a,
    String id,
    Map<String, Object?> patch,
  ) async {
    final existing = await _find(a, id);
    if (existing == null) return;
    final current = existing.toJson()..remove('updatedAt');
    final changed = _changed(current, patch);
    if (changed.isNotEmpty) await _write(a, {...current, ...changed}, changed);
  }

  Map<String, Object?> _changed(
    Map<String, Object?> current,
    Map<String, Object?> next,
  ) => {
    for (final e in next.entries)
      if (current[e.key] != e.value) e.key: e.value,
  };

  Future<void> _tombstone<D extends DataClass>(
    _Adapter<D> a,
    String id,
    DeletionReceipt receipt,
  ) async {
    await _patch(a, id, {'deleted': true});
    receipt._rows.add((a.name, id));
  }

  Future<void> _patchOverride(Occurrence session, Map<String, Object?> patch) =>
      _patchOverrideFor(session.meetingId, session.originalDate, patch);

  Future<void> _patchOverrideFor(
    String meetingId,
    LocalDate originalDate,
    Map<String, Object?> patch,
  ) async {
    final id = sessionId(meetingId, originalDate);
    if (await _find(_overrides, id) != null) {
      await _patch(_overrides, id, patch);
      return;
    }
    final fresh = SessionOverrideRow(
      id: id,
      deleted: false,
      updatedAt: 0,
      meetingId: meetingId,
      originalDate: originalDate.toIso(),
      notes: '',
    ).toJson()..remove('updatedAt');
    final full = {...fresh, ...patch};
    await _write(_overrides, full, full);
  }

  Future<void> _patchSettings(Map<String, Object?> patch) async {
    if (await _find(_settings, _settingsId) != null) {
      await _patch(_settings, _settingsId, patch);
      return;
    }
    final fresh = const UserSettingsRow(
      id: _settingsId,
      deleted: false,
      updatedAt: 0,
      meetingNumbers: true,
    ).toJson()..remove('updatedAt');
    final full = {...fresh, ...patch};
    await _write(_settings, full, full);
  }

  Future<void> _deleteCourseTree(
    String courseId,
    DeletionReceipt receipt,
  ) async {
    final meetingIds = await _ids(
      db.select(db.meetings)
        ..where((m) => m.courseId.equals(courseId) & m.deleted.equals(false)),
    );
    for (final id in meetingIds) {
      await _deleteMeetingTree(id, receipt);
    }
    final reqIds = await _ids(
      db.select(db.requirements)
        ..where((r) => r.courseId.equals(courseId) & r.deleted.equals(false)),
    );
    for (final id in reqIds) {
      await _tombstone(_requirements, id, receipt);
    }
    await _tombstone(_courses, courseId, receipt);
  }

  Future<void> _deleteMeetingTree(
    String meetingId,
    DeletionReceipt receipt,
  ) async {
    final overrideIds = await _ids(
      db.select(db.sessionOverrides)
        ..where((o) => o.meetingId.equals(meetingId) & o.deleted.equals(false)),
    );
    for (final id in overrideIds) {
      await _tombstone(_overrides, id, receipt);
    }
    await _tombstone(_meetings, meetingId, receipt);
  }
}
