import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.steps.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Semesters,
    Courses,
    Meetings,
    SessionOverrides,
    NoClassRanges,
    Requirements,
    UserSettings,
    Outbox,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 3;

  /// Runs on drift's background isolate. `shareAcrossIsolates` lets
  /// notification-action and home-widget callbacks (separate isolates) write
  /// to the same database with working stream updates.
  static QueryExecutor _open() => driftDatabase(
    name: 'leccheck',
    native: const DriftNativeOptions(
      shareAcrossIsolates: true,
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );

  /// Each step uses the schema as it was at that version
  /// (`app_database.steps.dart`, from `dart run drift_dev make-migrations`),
  /// and test/drift checks every upgrade path against the saved schemas.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.outbox, schema.outbox.ifAbsent);
        await m.addColumn(schema.outbox, schema.outbox.rejected);
      },
      from2To3: (m, schema) async {
        await m.addColumn(schema.courses, schema.courses.shortName);
      },
    ),
  );

  /// Every synced table, keyed by its SQL name (the `tbl` used in the outbox
  /// and the sync protocol).
  Map<String, TableInfo<Table, Object?>> get syncedTables => {
    semesters.actualTableName: semesters,
    courses.actualTableName: courses,
    meetings.actualTableName: meetings,
    sessionOverrides.actualTableName: sessionOverrides,
    noClassRanges.actualTableName: noClassRanges,
    requirements.actualTableName: requirements,
    userSettings.actualTableName: userSettings,
  };
}
