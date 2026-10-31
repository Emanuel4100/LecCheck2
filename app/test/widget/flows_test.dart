import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/update/update_service.dart';
import 'package:leccheck/core/icons/lec_icons.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _now = DateTime(2026, 10, 20, 13, 0); // Tuesday, after the 10:00 lecture

Future<(ProviderContainer, AppDatabase)> _start(
  WidgetTester tester, {
  bool withCourse = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await prefs.setString('appearance.locale', 'en');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = ScheduleRepository(db);
  await tester.runAsync(() async {
    await repo.saveSemester(
      SemesterInfo(
        id: 'sem',
        name: 'Semester A',
        start: LocalDate.parse('2026-10-18'),
        end: LocalDate.parse('2027-01-22'),
      ),
    );
    if (withCourse) {
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
    }
  });

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      minuteClockProvider.overrideWith((ref) => Stream.value(_now)),
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

Future<String?> _statusOf(WidgetTester tester, AppDatabase db) async {
  final rows = await tester.runAsync(
    () => db.select(db.sessionOverrides).get(),
  );
  return rows!.isEmpty ? null : rows.single.status;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // ignore: invalid_use_of_visible_for_testing_member
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '2.0.0',
    buildNumber: '12',
    buildSignature: '',
  );

  testWidgets('quick-mark a pending session, then undo', (tester) async {
    final (_, db) = await _start(tester);
    expect(find.text('Needs marking'), findsOneWidget);

    await tester.tap(find.byTooltip('Attended').first);
    await _settle(tester);
    expect(await _statusOf(tester, db), 'attended');
    expect(find.text("You're all caught up"), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(await _statusOf(tester, db), isNull);
    expect(find.text('Needs marking'), findsOneWidget);
  });

  testWidgets('a letter that is also a shortcut reaches a text field', (
    tester,
  ) async {
    final (container, _) = await _start(tester);
    container.read(routerProvider).go('/today/sessions');
    await _settle(tester);
    await tester.tap(find.byType(SearchBar));
    await tester.pump();

    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    expect(handled, isFalse, reason: 'the "this week" shortcut took the key');
  });

  testWidgets('course editor requires a name', (tester) async {
    final (container, db) = await _start(tester, withCourse: false);
    container.read(routerProvider).push('/course-editor');
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);
    expect(find.text('Enter a course name'), findsOneWidget);
    final courses = await tester.runAsync(() => db.select(db.courses).get());
    expect(courses, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'Physics');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);
    final saved = await tester.runAsync(() => db.select(db.courses).get());
    expect(saved!.single.name, 'Physics');
  });

  testWidgets('a long name gets a suggested short name', (tester) async {
    final (container, db) = await _start(tester, withCourse: false);
    container.read(routerProvider).push('/course-editor');
    await _settle(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'Introduction to Computer Science',
    );
    await tester.pump();
    await tester.tap(find.text('Use “Intr. Comp. Sci.”'));
    await tester.pump();
    expect(find.text('Use “Intr. Comp. Sci.”'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await _settle(tester);
    final saved = await tester.runAsync(() => db.select(db.courses).get());
    expect(saved!.single.shortName, 'Intr. Comp. Sci.');
  });

  testWidgets('leaving the editor with changes asks first', (tester) async {
    final (container, _) = await _start(tester, withCourse: false);
    container.read(routerProvider).push('/course-editor');
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Draft');
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    await navigator.maybePop();
    await _settle(tester);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    expect(find.text('New course'), findsOneWidget);
  });

  testWidgets('Stats explains how attendance is counted', (tester) async {
    final (container, _) = await _start(tester);
    container.read(routerProvider).go('/stats');
    await _settle(tester);
    expect(find.text('Attended or watched'), findsOneWidget);
    await tester.tap(find.byTooltip("How it's counted"));
    await _settle(tester);
    expect(
      find.textContaining('Skipped and canceled sessions'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await _settle(tester);
    expect(find.textContaining('Skipped and canceled sessions'), findsNothing);
  });

  testWidgets('empty semester shows the add-course call to action', (
    tester,
  ) async {
    await _start(tester, withCourse: false);
    expect(find.text('No courses yet'), findsOneWidget);
    expect(find.byIcon(LecIcons.add), findsWidgets);
  });

  testWidgets('tapping the version 7 times opens developer mode', (
    tester,
  ) async {
    final (container, _) = await _start(tester);
    container.read(routerProvider).push('/settings');
    await _settle(tester);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Version'),
      300,
      scrollable: list,
    );
    expect(find.text('Developer tools'), findsNothing);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('Version'));
      await tester.pump();
    }
    expect(find.text('1 more tap to turn on developer mode'), findsOneWidget);
    await tester.tap(find.text('Version'));
    await _settle(tester);
    expect(find.text('Developer mode is on'), findsOneWidget);
    expect(container.read(sharedPrefsProvider).getBool('dev.mode'), isTrue);

    await tester.scrollUntilVisible(
      find.text('Developer tools'),
      300,
      scrollable: list,
    );
    await tester.tap(find.text('Developer tools'));
    await _settle(tester);
    expect(find.text('Show a notification now'), findsOneWidget);
    expect(find.text('After-class reminder in 1 minute'), findsOneWidget);
  });

  testWidgets('after a sign-in brings semesters, asks which one to open', (
    tester,
  ) async {
    final (container, _) = await _start(tester);
    container.read(semesterChoiceProvider.notifier).ask();
    await _settle(tester);
    expect(find.text('Which semester?'), findsOneWidget);
    expect(find.text('Semester A'), findsOneWidget);
    expect(find.text('Start a new semester'), findsOneWidget);
    expect(container.read(semesterChoiceProvider), isFalse);

    await tester.tap(find.text('Semester A'));
    await _settle(tester);
    expect(find.text('Which semester?'), findsNothing);
    expect(container.read(activeSemesterChoiceProvider), 'sem');
    expect(find.text('Calculus'), findsWidgets);
  });

  group('Check now', () {
    Future<void> checkNow(WidgetTester tester, {required int offered}) async {
      PackageInfo.setMockInitialValues(
        appName: 'LecCheck',
        packageName: 'com.leccheck.app',
        version: '2.0.0-beta.7',
        buildNumber: '2015',
        buildSignature: '',
      );
      addTearDown(
        () => PackageInfo.setMockInitialValues(
          appName: 'LecCheck',
          packageName: 'com.leccheck.app',
          version: '2.0.0',
          buildNumber: '12',
          buildSignature: '',
        ),
      );
      final manifest = jsonEncode({
        'beta': {
          'version': '2.0.0-beta.$offered',
          'build': offered + 8,
          'notesUrl': 'https://example.com/notes',
        },
      });
      // Signed with a throwaway key standing in for the release workflow's.
      final realKey = updatePublicKey;
      final signature = await tester.runAsync(() async {
        final keys = await Ed25519().newKeyPair();
        updatePublicKey = base64.encode((await keys.extractPublicKey()).bytes);
        return base64.encode(
          (await Ed25519().sign(utf8.encode(manifest), keyPair: keys)).bytes,
        );
      });
      UpdateController.client = () => MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('.sig') ? signature! : manifest,
          200,
        ),
      );
      addTearDown(() {
        UpdateController.client = http.Client.new;
        updatePublicKey = realKey;
      });
      final (container, _) = await _start(tester);
      container.read(routerProvider).push('/settings');
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.text('Check now'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Check now'));
      await tester.pump();
      await tester.tap(find.text('Check now'));
      await tester.pump();
      // Asking GitHub can take a while: the row shows it's working.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await _settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    testWidgets('says when LecCheck is up to date', (tester) async {
      await checkNow(tester, offered: 7);
      expect(find.text('LecCheck is up to date'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a newer release shows here, not only at the top', (
      tester,
    ) async {
      await checkNow(tester, offered: 8);
      expect(find.text('LecCheck 2.0.0-beta.8 is available'), findsWidgets);
      // No hash in this manifest: the browser.
      expect(find.widgetWithText(SnackBarAction, 'Download'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
