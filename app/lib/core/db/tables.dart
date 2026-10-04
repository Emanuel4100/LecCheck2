import 'package:drift/drift.dart';

/// Columns shared by every table that syncs between devices.
///
/// Rows are never hard-deleted: [deleted] is a tombstone so the deletion can
/// sync. Dates are `yyyy-MM-dd` text, times are minutes after midnight, enums
/// are stable keys (see `domain/schedule_types.dart`).
mixin SyncedRow on Table {
  /// UUIDv7, or a deterministic id for session overrides.
  TextColumn get id => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Local wall-clock ms of the last change. Diagnostics only; sync ordering
  /// uses hybrid logical clocks in the outbox.
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SemesterRow')
class Semesters extends Table with SyncedRow {
  TextColumn get name => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  IntColumn get weekStart => integer().withDefault(const Constant(7))();

  /// Bit (weekday - 1) set for every visible ISO weekday.
  IntColumn get visibleDays => integer().withDefault(const Constant(0x7F))();
}

@DataClassName('CourseRow')
@TableIndex(name: 'courses_semester', columns: {#semesterId})
class Courses extends Table with SyncedRow {
  TextColumn get semesterId => text()();
  TextColumn get name => text()();
  TextColumn get code => text().withDefault(const Constant(''))();
  TextColumn get lecturer => text().withDefault(const Constant(''))();
  TextColumn get colorKey => text().withDefault(const Constant('ocean'))();
  TextColumn get website => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// JSON list of `{title, url}`.
  TextColumn get links => text().withDefault(const Constant('[]'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('MeetingRow')
@TableIndex(name: 'meetings_course', columns: {#courseId})
class Meetings extends Table with SyncedRow {
  TextColumn get courseId => text()();
  TextColumn get type => text().withDefault(const Constant('lecture'))();
  TextColumn get kind => text().withDefault(const Constant('weekly'))();
  IntColumn get weekday => integer().nullable()();
  TextColumn get date => text().nullable()();
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
  TextColumn get location => text().withDefault(const Constant(''))();
  IntColumn get intervalWeeks => integer().withDefault(const Constant(1))();
  TextColumn get validFrom => text().nullable()();
  TextColumn get validUntil => text().nullable()();
  TextColumn get links => text().withDefault(const Constant('[]'))();
}

/// Per-session state, id = `{meetingId}_{yyyymmdd}` of the original date.
@DataClassName('SessionOverrideRow')
@TableIndex(name: 'overrides_meeting', columns: {#meetingId})
class SessionOverrides extends Table with SyncedRow {
  TextColumn get meetingId => text()();
  TextColumn get originalDate => text()();
  TextColumn get status => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get recordingUrl => text().nullable()();
  TextColumn get movedDate => text().nullable()();
  IntColumn get movedStartMin => integer().nullable()();
  IntColumn get movedEndMin => integer().nullable()();
  TextColumn get movedLocation => text().nullable()();
}

@DataClassName('NoClassRangeRow')
@TableIndex(name: 'noclass_semester', columns: {#semesterId})
class NoClassRanges extends Table with SyncedRow {
  TextColumn get semesterId => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  TextColumn get label => text().withDefault(const Constant(''))();
}

@DataClassName('RequirementRow')
@TableIndex(name: 'requirements_course', columns: {#courseId})
class Requirements extends Table with SyncedRow {
  TextColumn get courseId => text()();

  /// Session type key, or null for "all types".
  TextColumn get type => text().nullable()();
  IntColumn get minPercent => integer()();
  BoolColumn get recordingsCount =>
      boolean().withDefault(const Constant(false))();
}

/// Single row (id `me`) of settings that follow the account.
@DataClassName('UserSettingsRow')
class UserSettings extends Table with SyncedRow {
  /// Null = follow the device's 24-hour setting.
  BoolColumn get use24h => boolean().nullable()();
  BoolColumn get meetingNumbers =>
      boolean().withDefault(const Constant(true))();
}

/// Local changes waiting to be pushed (only written while sync is enabled).
@DataClassName('OutboxEntry')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get tbl => text()();
  TextColumn get rowId => text()();

  /// JSON object with only the changed fields.
  TextColumn get patch => text()();
  TextColumn get hlc => text()();
}

@DataClassName('SyncMetaEntry')
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
