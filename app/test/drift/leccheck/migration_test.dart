// Upgrades of the app's database, checked against the schemas saved in
// drift_schemas/ (after changing tables.dart, bump schemaVersion, run
// `dart run drift_dev make-migrations` and add a step in app_database.dart).
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/db/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  group('every upgrade ends with the current schema', () {
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('v$from to v$to', () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, to);
          await db.close();
        });
      }
    }
  });

  // What the upgraded database must hold: everything as before, courses
  // without a short name, unsynced changes still waiting.
  Future<void> expectKept(v3.DatabaseAtV3 db) async {
    expect(await db.select(db.semesters).get(), [
      const v3.SemestersData(
        id: 'sem',
        deleted: 0,
        updatedAt: 1,
        name: 'Semester A',
        startDate: '2026-10-18',
        endDate: '2027-01-22',
        weekStart: 7,
        visibleDays: 0x7F,
      ),
    ]);
    expect(await db.select(db.courses).get(), [
      const v3.CoursesData(
        id: 'c1',
        deleted: 0,
        updatedAt: 1,
        semesterId: 'sem',
        name: 'Calculus 1',
        code: '104031',
        lecturer: 'Dr. Cohen',
        colorKey: 'ocean',
        website: '',
        notes: 'Bring a calculator',
        links: '[]',
        sortOrder: 0,
        shortName: '',
      ),
    ]);
    expect(await db.select(db.outbox).get(), [
      const v3.OutboxData(
        seq: 1,
        tbl: 'courses',
        rowId: 'c1',
        patch: '{"notes":"Bring a calculator"}',
        hlc: '001760000000000:0000:device1',
        ifAbsent: 0,
      ),
    ]);
    expect(await db.select(db.syncMeta).get(), [
      const v3.SyncMetaData(key: 'lastVersion', value: '42'),
    ]);
  }

  test('data from v2.0.0-beta.2 (v1) survives the upgrade', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 3,
      createOld: v1.DatabaseAtV1.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, db) {
        batch
          ..insert(
            db.semesters,
            const v1.SemestersData(
              id: 'sem',
              deleted: 0,
              updatedAt: 1,
              name: 'Semester A',
              startDate: '2026-10-18',
              endDate: '2027-01-22',
              weekStart: 7,
              visibleDays: 0x7F,
            ),
          )
          ..insert(
            db.courses,
            const v1.CoursesData(
              id: 'c1',
              deleted: 0,
              updatedAt: 1,
              semesterId: 'sem',
              name: 'Calculus 1',
              code: '104031',
              lecturer: 'Dr. Cohen',
              colorKey: 'ocean',
              website: '',
              notes: 'Bring a calculator',
              links: '[]',
              sortOrder: 0,
            ),
          )
          ..insert(
            db.outbox,
            const v1.OutboxData(
              seq: 1,
              tbl: 'courses',
              rowId: 'c1',
              patch: '{"notes":"Bring a calculator"}',
              hlc: '001760000000000:0000:device1',
            ),
          )
          ..insert(
            db.syncMeta,
            const v1.SyncMetaData(key: 'lastVersion', value: '42'),
          );
      },
      validateItems: expectKept,
    );
  });

  test('data from v2.0.0-beta.3 (v2) survives the upgrade', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, db) {
        batch
          ..insert(
            db.semesters,
            const v2.SemestersData(
              id: 'sem',
              deleted: 0,
              updatedAt: 1,
              name: 'Semester A',
              startDate: '2026-10-18',
              endDate: '2027-01-22',
              weekStart: 7,
              visibleDays: 0x7F,
            ),
          )
          ..insert(
            db.courses,
            const v2.CoursesData(
              id: 'c1',
              deleted: 0,
              updatedAt: 1,
              semesterId: 'sem',
              name: 'Calculus 1',
              code: '104031',
              lecturer: 'Dr. Cohen',
              colorKey: 'ocean',
              website: '',
              notes: 'Bring a calculator',
              links: '[]',
              sortOrder: 0,
            ),
          )
          ..insert(
            db.outbox,
            const v2.OutboxData(
              seq: 1,
              tbl: 'courses',
              rowId: 'c1',
              patch: '{"notes":"Bring a calculator"}',
              hlc: '001760000000000:0000:device1',
              ifAbsent: 0,
            ),
          )
          ..insert(
            db.syncMeta,
            const v2.SyncMetaData(key: 'lastVersion', value: '42'),
          );
      },
      validateItems: expectKept,
    );
  });
}
