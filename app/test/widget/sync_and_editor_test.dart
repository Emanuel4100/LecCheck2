import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/sync/sync_recorder.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Signed in, without a network: records "sign out everywhere".
class _SignedIn extends AuthController {
  static var signOuts = 0;

  @override
  Future<Session?> build() async => const Session(token: 't', userId: 'g:1');

  @override
  Future<void> signOutEverywhere() async => signOuts++;
}

Future<(ProviderContainer, AppDatabase)> _start(
  WidgetTester tester, {
  required DateTime now,
  bool attached = false,
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await prefs.setString('appearance.locale', 'en');
  if (attached) await prefs.setString(SyncRecorder.attachedAccountKey, 'g:1');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.runAsync(() async {
    final repo = ScheduleRepository(db);
    await repo.saveSemester(
      SemesterInfo(
        id: 'sem',
        name: 'Semester A',
        start: LocalDate.parse('2026-10-18'),
        end: LocalDate.parse('2027-01-22'),
      ),
    );
    await repo.saveCourse(
      const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Calculus'),
      meetings: const [
        MeetingRule(
          id: 'm1',
          courseId: 'c1',
          type: SessionType.lecture,
          kind: MeetingKind.weekly,
          weekday: DateTime.tuesday,
          startMin: 600,
          endMin: 720,
        ),
      ],
      requirements: const [],
    );
  });
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      minuteClockProvider.overrideWith((ref) => Stream.value(now)),
      syncConfiguredProvider.overrideWithValue(true),
      // No network in tests.
      syncEngineProvider.overrideWithValue(null),
      if (signedIn) authProvider.overrideWith(_SignedIn.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LecCheckApp()),
  );
  await _settle(tester);
  return (container, db);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // ignore: invalid_use_of_visible_for_testing_member
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '2.0.0',
    buildNumber: '15',
    buildSignature: '',
  );

  testWidgets('Today says when edits wait for a sign-in', (tester) async {
    final (container, _) = await _start(
      tester,
      now: DateTime(2026, 10, 20, 13),
      attached: true,
    );
    expect(find.text("You're signed out"), findsNothing);
    // An edit while signed out: recorded for the account.
    await tester.runAsync(
      () => container
          .read(repositoryProvider)
          .setStatusFor(
            meetingId: 'm1',
            originalDate: LocalDate.parse('2026-10-20'),
            status: AttendanceStatus.attended,
          ),
    );
    await _settle(tester);
    expect(find.text("You're signed out"), findsOneWidget);
    expect(
      find.text('1 change on this device will sync when you sign in.'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await _settle(tester);
    expect(find.text("You're signed out"), findsNothing);
  });

  testWidgets('"Sign out on all devices" asks first', (tester) async {
    _SignedIn.signOuts = 0;
    final (container, _) = await _start(
      tester,
      now: DateTime(2026, 10, 20, 13),
      signedIn: true,
    );
    container.read(routerProvider).push('/settings');
    await _settle(tester);
    await tester.tap(find.text('Sign out on all devices'));
    await _settle(tester);
    expect(find.text('Sign out on all devices?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(_SignedIn.signOuts, 0);

    await tester.tap(find.text('Sign out on all devices'));
    await _settle(tester);
    await tester.tap(find.text('Sign out on all devices').last);
    await _settle(tester);
    expect(_SignedIn.signOuts, 1);
  });

  testWidgets('removing a meeting with marked sessions can end it instead', (
    tester,
  ) async {
    final (container, db) = await _start(
      tester,
      now: DateTime(2026, 11, 3, 13), // Tuesday of week 3
    );
    await tester.runAsync(
      () => container
          .read(repositoryProvider)
          .setStatusFor(
            meetingId: 'm1',
            originalDate: LocalDate.parse('2026-10-20'),
            status: AttendanceStatus.attended,
          ),
    );
    container.read(routerProvider).push('/course-editor?id=c1');
    await _settle(tester);
    await tester.tap(find.byTooltip('Remove meeting'));
    await _settle(tester);
    expect(find.text('Remove this meeting?'), findsOneWidget);
    expect(find.textContaining('1 of its sessions is marked.'), findsOneWidget);
    await tester.tap(find.text('End it this week'));
    await _settle(tester);
    // Still listed, ending last week.
    expect(find.textContaining('Until'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await _settle(tester);
    final meeting = await tester.runAsync(
      () => (db.select(db.meetings)).getSingle(),
    );
    expect((meeting!.deleted, meeting.validUntil), (false, '2026-10-31'));
  });
}
