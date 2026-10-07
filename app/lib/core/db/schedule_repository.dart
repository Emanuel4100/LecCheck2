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
  /// [ifAbsent]: the server only takes fields it doesn't have yet, so an old
  /// copy (a backup, data joining an account) never overwrites newer edits.
  Future<void> record(
    String table,
    String rowId,
    Map<String, Object?> patch, {
    bool ifAbsent = false,
  });
}

/// How a backup is imported.
enum ImportMode {
  /// Only adds rows this device doesn't have; nothing existing changes.
  merge,

  /// Rows in the backup replace the ones here (and on synced devices).
  replace,
}

/// What a course editor loaded, so saving only writes what the user changed
/// and can't revert edits that synced in while the editor was open.
class CourseBase {
  const CourseBase({
    required this.course,
    required this.meetings,
    required this.requirements,
  });

  final CourseInfo course;
  final List<MeetingRule> meetings;
  final List<AttendanceRequirement> requirements;
}

/// A deleted semester or course that can still be restored.
class DeletedItem {
  const DeletedItem({
    required this.table,
    required this.id,
    required this.name,
    required this.deletedAt,
  });

  /// `semesters` or `courses`.
  final String table;
  final String id;
  final String name;
  final DateTime deletedAt;

  bool get isSemester => table == 'semesters';

  @override
  bool operator ==(Object other) =>
      other is DeletedItem &&
      other.table == table &&
      other.id == id &&
      other.name == name &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(table, id, name, deletedAt);
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
  const _Adapter(this.table, this.fromJson, [this.added = const {}]);
  final TableInfo<Table, D> table;
  final D Function(Map<String, dynamic> json) fromJson;

  /// Defaults of columns added after the first release. Rows written by
  /// older app versions (synced rows, backups, snapshots) don't have them,
  /// and must still load.
  final Map<String, Object?> added;
  String get name => table.actualTableName;

  /// A row from JSON, with [added] columns filled in when missing.
  D parse(Map<String, dynamic> json) => fromJson({...added, ...json});

  /// Upserts a full row. Lives here so [D] is the real row type even when
  /// the adapter is reached through a `_Adapter<DataClass>` reference.
  Future<void> upsert(GeneratedDatabase db, Map<String, dynamic> json) {
    final row = parse(json) as Insertable<D>;
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
  late final _courses = _Adapter<CourseRow>(
    db.courses,
    CourseRow.fromJson,
    const {'shortName': ''},
  );
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

  /// Saves a semester. With [base] (what the form loaded), only the fields
  /// the user changed are written.
  Future<void> saveSemester(SemesterInfo semester, {SemesterInfo? base}) =>
      db.transaction(
        () => _saveEdited(_semesters, semester.toRow(), base?.toRow()),
      );

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

  /// Saves a course with its full list of meetings and requirements.
  ///
  /// With [base] (what the editor loaded), only fields the user changed are
  /// written, and only meetings or requirements the user removed are deleted;
  /// changes that synced in meanwhile survive. Without it, meetings or
  /// requirements missing from the lists are deleted.
  Future<void> saveCourse(
    CourseInfo course, {
    required List<MeetingRule> meetings,
    required List<AttendanceRequirement> requirements,
    CourseBase? base,
  }) => db.transaction(() async {
    await _saveEdited(_courses, course.toRow(), base?.course.toRow());

    final baseMeetings = {
      for (final m in base?.meetings ?? const <MeetingRule>[]) m.id: m,
    };
    for (final m in meetings) {
      await _saveEdited(_meetings, m.toRow(), baseMeetings[m.id]?.toRow());
    }
    final keepMeetings = {for (final m in meetings) m.id};
    final oldMeetings = base != null
        ? baseMeetings.keys
        : await _ids(
            db.select(db.meetings)..where(
              (m) => m.courseId.equals(course.id) & m.deleted.equals(false),
            ),
          );
    final receipt = DeletionReceipt._();
    for (final id in oldMeetings) {
      if (!keepMeetings.contains(id)) await _deleteMeetingTree(id, receipt);
    }

    final baseReqs = {
      for (final r in base?.requirements ?? const <AttendanceRequirement>[])
        r.id: r,
    };
    for (final r in requirements) {
      await _saveEdited(_requirements, r.toRow(), baseReqs[r.id]?.toRow());
    }
    final keepReqs = {for (final r in requirements) r.id};
    final oldReqs = base != null
        ? baseReqs.keys
        : await _ids(
            db.select(db.requirements)..where(
              (r) => r.courseId.equals(course.id) & r.deleted.equals(false),
            ),
          );
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
  ///
  /// [ImportMode.merge] only adds rows that don't exist here, and asks the
  /// server to do the same, so an old backup can't overwrite newer data.
  Future<void> importRows(
    Map<String, List<Map<String, Object?>>> tables, {
    ImportMode mode = ImportMode.merge,
  }) => db.transaction(() async {
    for (final MapEntry(key: table, value: rows) in tables.entries) {
      final adapter = _byName[table];
      if (adapter == null) continue;
      for (final row in rows) {
        final next = _normalize(adapter, row);
        if (mode == ImportMode.replace) {
          await _upsert(adapter, adapter.parse({...next, 'updatedAt': 0}));
        } else if (await _find(adapter, next['id']! as String) == null) {
          await _write(adapter, next, next, ifAbsent: true);
        }
      }
    }
  });

  /// How many backup rows are new here, and how many differ from this
  /// device's copy (what [ImportMode.replace] would overwrite).
  Future<({int added, int changed})> previewImport(
    Map<String, List<Map<String, Object?>>> tables,
  ) async {
    var added = 0;
    var changed = 0;
    for (final MapEntry(key: table, value: rows) in tables.entries) {
      final adapter = _byName[table];
      if (adapter == null) continue;
      for (final row in rows) {
        final next = _normalize(adapter, row);
        final existing = await _find(adapter, next['id']! as String);
        if (existing == null) {
          added++;
        } else if (_changed(
          existing.toJson()..remove('updatedAt'),
          next,
        ).isNotEmpty) {
          changed++;
        }
      }
    }
    return (added: added, changed: changed);
  }

  /// Makes this device's data equal [tables] (a snapshot, tombstones
  /// included): rows are written back and rows created since are deleted.
  /// Recorded like any edit, so the restore reaches synced devices too.
  Future<void> restoreAll(Map<String, List<Map<String, Object?>>> tables) =>
      db.transaction(() async {
        for (final adapter in _byName.values) {
          final ids = <String>{};
          for (final row in tables[adapter.name] ?? const []) {
            final next = _normalize(adapter, row);
            ids.add(next['id']! as String);
            await _upsert(adapter, adapter.parse({...next, 'updatedAt': 0}));
          }
          final live = await (db.select(
            adapter.table,
          )..where((t) => (t as SyncedRow).deleted.equals(false))).get();
          for (final row in live) {
            final id = row.toJson()['id']! as String;
            if (!ids.contains(id)) await _patch(adapter, id, {'deleted': true});
          }
        }
      });

  /// A row from a file as this app version stores it.
  Map<String, Object?> _normalize<D extends DataClass>(
    _Adapter<D> a,
    Map<String, Object?> row,
  ) =>
      a.parse({'deleted': false, ...row, 'updatedAt': 0}).toJson()
        ..remove('updatedAt');

  // ------------------------------------------------------ recently deleted --

  /// How long deleted semesters and courses are listed for restoring.
  static const trashDays = 30;

  /// Semesters and courses deleted in the last [trashDays] days, newest
  /// first. Courses of a deleted semester come back with the semester.
  Stream<List<DeletedItem>> watchRecentlyDeleted() => db
      .customSelect('SELECT 1', readsFrom: {db.semesters, db.courses})
      .watch()
      .asyncMap((_) => recentlyDeleted());

  Future<List<DeletedItem>> recentlyDeleted() async {
    final cutoff = _now() - trashDays * Duration.millisecondsPerDay;
    final semesters = await db.select(db.semesters).get();
    final liveSemesters = {
      for (final s in semesters)
        if (!s.deleted) s.id,
    };
    final courses =
        await (db.select(db.courses)..where(
              (c) =>
                  c.deleted.equals(true) &
                  c.updatedAt.isBiggerOrEqualValue(cutoff),
            ))
            .get();
    DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);
    return [
      for (final s in semesters)
        if (s.deleted && s.updatedAt >= cutoff)
          DeletedItem(
            table: _semesters.name,
            id: s.id,
            name: s.name,
            deletedAt: at(s.updatedAt),
          ),
      for (final c in courses)
        if (liveSemesters.contains(c.semesterId))
          DeletedItem(
            table: _courses.name,
            id: c.id,
            name: c.name,
            deletedAt: at(c.updatedAt),
          ),
    ]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  }

  /// Restores a deleted semester or course with everything deleted along
  /// with it (rows deleted earlier on their own stay deleted).
  Future<void> restoreDeleted(DeletedItem item) => db.transaction(() async {
    if (item.isSemester) {
      final semester = await _find(_semesters, item.id);
      if (semester == null) return;
      final since = semester.updatedAt - _cascadeWindowMs;
      for (final c
          in await (db.select(db.courses)..where(
                (c) =>
                    c.semesterId.equals(item.id) &
                    c.deleted.equals(true) &
                    c.updatedAt.isBiggerOrEqualValue(since),
              ))
              .get()) {
        await _restoreCourseTree(c.id, since);
      }
      for (final r
          in await (db.select(db.noClassRanges)..where(
                (r) =>
                    r.semesterId.equals(item.id) &
                    r.deleted.equals(true) &
                    r.updatedAt.isBiggerOrEqualValue(since),
              ))
              .get()) {
        await _patch(_noClass, r.id, {'deleted': false});
      }
      await _patch(_semesters, item.id, {'deleted': false});
    } else {
      final course = await _find(_courses, item.id);
      if (course == null) return;
      await _restoreCourseTree(item.id, course.updatedAt - _cascadeWindowMs);
    }
  });

  /// Rows tombstoned by one delete get their time within this window.
  static const _cascadeWindowMs = 10 * 1000;

  Future<void> _restoreCourseTree(String courseId, int since) async {
    final meetings =
        await (db.select(db.meetings)..where(
              (m) =>
                  m.courseId.equals(courseId) &
                  m.deleted.equals(true) &
                  m.updatedAt.isBiggerOrEqualValue(since),
            ))
            .get();
    for (final m in meetings) {
      final overrides =
          await (db.select(db.sessionOverrides)..where(
                (o) =>
                    o.meetingId.equals(m.id) &
                    o.deleted.equals(true) &
                    o.updatedAt.isBiggerOrEqualValue(since),
              ))
              .get();
      for (final o in overrides) {
        await _patch(_overrides, o.id, {'deleted': false});
      }
      await _patch(_meetings, m.id, {'deleted': false});
    }
    final requirements =
        await (db.select(db.requirements)..where(
              (r) =>
                  r.courseId.equals(courseId) &
                  r.deleted.equals(true) &
                  r.updatedAt.isBiggerOrEqualValue(since),
            ))
            .get();
    for (final r in requirements) {
      await _patch(_requirements, r.id, {'deleted': false});
    }
    await _patch(_courses, courseId, {'deleted': false});
  }

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

  /// Every live row of every synced table, keyed by table name; with
  /// [includeDeleted], tombstones too (snapshots).
  Future<Map<String, List<Map<String, Object?>>>> exportRows({
    bool includeDeleted = false,
  }) async => {
    for (final a in _byName.values)
      a.name: [
        for (final row
            in await (db.select(a.table)..where(
                  (t) => includeDeleted
                      ? const Constant(true)
                      : (t as SyncedRow).deleted.equals(false),
                ))
                .get())
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
    Map<String, Object?> patch, {
    bool ifAbsent = false,
  }) async {
    await a.upsert(db, {...json, 'updatedAt': _now()});
    final r = recorder;
    if (r != null && patch.isNotEmpty) {
      await r.record(a.name, json['id']! as String, patch, ifAbsent: ifAbsent);
    }
  }

  /// Writes the fields that differ between [base] (what an editor loaded)
  /// and [next] onto the current row. Without a base, writes [next] whole.
  Future<void> _saveEdited<D extends DataClass>(
    _Adapter<D> a,
    D next,
    D? base,
  ) async {
    if (base == null) return _upsert(a, next);
    final nextJson = next.toJson()..remove('updatedAt');
    final id = nextJson['id']! as String;
    if (await _find(a, id) == null) {
      await _write(a, nextJson, nextJson);
      return;
    }
    await _patch(a, id, _changed(base.toJson()..remove('updatedAt'), nextJson));
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
