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
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;

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
  // without a short name, contacts or Panopto folders, unsynced changes still waiting.
  Future<void> expectKept(v6.DatabaseAtV6 db) async {
    expect(await db.select(db.semesters).get(), [
      const v6.SemestersData(
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
      const v6.CoursesData(
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
        contacts: '[]',
        panoptoFolders: '',
      ),
    ]);
    expect(await db.select(db.outbox).get(), [
      const v6.OutboxData(
        seq: 1,
        tbl: 'courses',
        rowId: 'c1',
        patch: '{"notes":"Bring a calculator"}',
        hlc: '001760000000000:0000:device1',
        ifAbsent: 0,
      ),
    ]);
    expect(await db.select(db.syncMeta).get(), [
      const v6.SyncMetaData(key: 'lastVersion', value: '42'),
    ]);
  }

  test('data from v2.0.0-beta.2 (v1) survives the upgrade', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 6,
      createOld: v1.DatabaseAtV1.new,
      createNew: v6.DatabaseAtV6.new,
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
      newVersion: 6,
      createOld: v2.DatabaseAtV2.new,
      createNew: v6.DatabaseAtV6.new,
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

  test('data from v2.0.0-beta.10 (v3) survives the upgrade', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 6,
      createOld: v3.DatabaseAtV3.new,
      createNew: v6.DatabaseAtV6.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, db) {
        batch
          ..insert(
            db.semesters,
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
          )
          ..insert(
            db.courses,
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
          )
          ..insert(
            db.sessionOverrides,
            const v3.SessionOverridesData(
              id: 'm1_20261018',
              deleted: 0,
              updatedAt: 1,
              meetingId: 'm1',
              originalDate: '2026-10-18',
              status: 'attended',
              notes: '',
            ),
          )
          ..insert(
            db.outbox,
            const v3.OutboxData(
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
            const v3.SyncMetaData(key: 'lastVersion', value: '42'),
          );
      },
      validateItems: (db) async {
        await expectKept(db);
        // Marked sessions still count.
        expect(await db.select(db.sessionOverrides).get(), [
          const v6.SessionOverridesData(
            id: 'm1_20261018',
            deleted: 0,
            updatedAt: 1,
            meetingId: 'm1',
            originalDate: '2026-10-18',
            status: 'attended',
            notes: '',
            excluded: 0,
          ),
        ]);
      },
    );
  });

  test('data from v2.0.0-beta.19 (v5) survives the upgrade', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 5,
      newVersion: 6,
      createOld: v5.DatabaseAtV5.new,
      createNew: v6.DatabaseAtV6.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, db) {
        batch
          ..insert(
            db.meetings,
            const v5.MeetingsData(
              id: 'm1',
              deleted: 0,
              updatedAt: 1,
              courseId: 'c1',
              type: 'practice',
              kind: 'weekly',
              weekday: 4,
              startMin: 600,
              endMin: 705,
              location: 'Sprinzak 27',
              intervalWeeks: 1,
              links: '[]',
            ),
          )
          ..insert(
            db.sessionOverrides,
            const v5.SessionOverridesData(
              id: 'm1_20261105',
              deleted: 0,
              updatedAt: 1,
              meetingId: 'm1',
              originalDate: '2026-11-05',
              status: 'watched',
              notes: '',
              recordingUrl:
                  'https://example.panopto.eu/Panopto/Pages/Viewer.aspx?id=1',
              excluded: 0,
            ),
          );
      },
      validateItems: (db) async {
        // Links pasted before stay the user's; nothing found yet, no group
        // chosen yet.
        expect(await db.select(db.meetings).get(), [
          const v6.MeetingsData(
            id: 'm1',
            deleted: 0,
            updatedAt: 1,
            courseId: 'c1',
            type: 'practice',
            kind: 'weekly',
            weekday: 4,
            startMin: 600,
            endMin: 705,
            location: 'Sprinzak 27',
            intervalWeeks: 1,
            links: '[]',
            panoptoGroup: '',
          ),
        ]);
        expect(await db.select(db.sessionOverrides).get(), [
          const v6.SessionOverridesData(
            id: 'm1_20261105',
            deleted: 0,
            updatedAt: 1,
            meetingId: 'm1',
            originalDate: '2026-11-05',
            status: 'watched',
            notes: '',
            recordingUrl:
                'https://example.panopto.eu/Panopto/Pages/Viewer.aspx?id=1',
            excluded: 0,
          ),
        ]);
      },
    );
  });
}
