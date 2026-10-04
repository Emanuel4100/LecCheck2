import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/icons/lec_icons.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('empty semester shows the add-course call to action', (
    tester,
  ) async {
    await _start(tester, withCourse: false);
    expect(find.text('No courses yet'), findsOneWidget);
    expect(find.byIcon(LecIcons.add), findsWidgets);
  });
}
