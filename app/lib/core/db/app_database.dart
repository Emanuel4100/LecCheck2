import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

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
  int get schemaVersion => 2;

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

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(outbox, outbox.ifAbsent);
        await m.addColumn(outbox, outbox.rejected);
      }
    },
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
