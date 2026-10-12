import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/features/session/session_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _now = DateTime(2026, 10, 20, 13, 0); // Tuesday of week 1

/// The app with a semester starting Sunday 2026-10-18 and "Calculus" (c1),
/// lectures on Tuesdays 10:00–12:00, on a phone unless [size] says
/// otherwise.
Future<(ProviderContainer, AppDatabase)> _start(
  WidgetTester tester, {
  Size size = const Size(1080, 2340),
  double ratio = 2.6,
  String locale = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await prefs.setString('appearance.locale', locale);
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

Future<void> _open(ProviderContainer c, WidgetTester tester, String uri) async {
  c.read(routerProvider).push(uri);
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.widgetWithText(FilledButton, 'Save'));

Future<List<MeetingRow>> _meetings(WidgetTester tester, AppDatabase db) async {
  final rows = await tester.runAsync(() => db.select(db.meetings).get());
  return [
    for (final r in rows!)
      if (!r.deleted) r,
  ]..sort((a, b) => (a.weekday ?? 0).compareTo(b.weekday ?? 0));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '2.0.0',
    buildNumber: '17',
    buildSignature: '',
  );

  testWidgets('a new course: meetings are added in a sheet, on several days', (
    tester,
  ) async {
    final (c, db) = await _start(tester);
    await _open(c, tester, '/course-editor');
    expect(
      find.text('Add the lectures, practices and labs of this course.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'Physics');

    await _tap(tester, find.text('Add meeting'));
    expect(find.text('New meeting'), findsOneWidget);
    // The type and the repeat are menus.
    await _tap(tester, find.text('Lecture'));
    await _tap(tester, find.text('Lab'));
    await _tap(tester, find.text('Weekly'));
    await _tap(tester, find.text('Every other week, from week 2'));
    // Sunday is chosen; Tuesday too.
    expect(find.text('Pick one or more days'), findsOneWidget);
    await _tap(tester, find.text('Tue'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Room / location'),
      'Room 7',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Add'));

    expect(find.text('New meeting'), findsNothing);
    expect(find.text('Lab · Sunday'), findsOneWidget);
    expect(find.text('Lab · Tuesday'), findsOneWidget);
    expect(
      find.textContaining('Room 7 · Every other week, from week 2'),
      findsNWidgets(2),
    );

    await _save(tester);
    final meetings = (await _meetings(
      tester,
      db,
    )).where((m) => m.courseId != 'c1').toList();
    expect([for (final m in meetings) m.weekday], [DateTime.tuesday, 7]);
    for (final m in meetings) {
      expect(
        (m.type, m.intervalWeeks, m.validFrom, m.location),
        ('lab', 2, '2026-10-25', 'Room 7'),
      );
    }
    expect(meetings[0].id, isNot(meetings[1].id));
  });

  testWidgets('dismissing a new meeting adds nothing', (tester) async {
    final (c, _) = await _start(tester);
    await _open(c, tester, '/course-editor?id=c1');
    await _tap(tester, find.text('Add meeting'));
    expect(find.text('New meeting'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);
    expect(find.text('New meeting'), findsNothing);
    expect(find.textContaining(' · '), findsOneWidget);

    // Nothing changed: leaving doesn't ask.
    await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    await _settle(tester);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Edit course'), findsNothing);
  });

  testWidgets('an existing meeting changes as you edit it', (tester) async {
    final (c, db) = await _start(tester);
    await _open(c, tester, '/course-editor?id=c1');
    await _tap(tester, find.text('Lecture · Tuesday'));
    expect(find.text('Edit meeting'), findsOneWidget);
    await _tap(tester, find.text('Lecture').last);
    await _tap(tester, find.text('Practice').last);
    await _tap(tester, find.text('Wed'));
    // One day only: Wednesday replaces Tuesday.
    expect(find.text('Pick one or more days'), findsNothing);
    await _tap(tester, find.widgetWithText(FilledButton, 'Done'));
    expect(find.text('Practice · Wednesday'), findsOneWidget);

    await _save(tester);
    final [m] = await _meetings(tester, db);
    expect((m.id, m.type, m.weekday), ('m1', 'practice', DateTime.wednesday));
  });

  testWidgets('one-time meetings: from the button and from the course page', (
    tester,
  ) async {
    final (c, db) = await _start(tester);
    await _open(c, tester, '/course-editor?id=c1&oneTime=1');
    expect(find.text('New meeting'), findsOneWidget);
    expect(find.text('One-time'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Add'));
    expect(find.text('Practice · Tuesday'), findsNothing);
    expect(find.textContaining('Practice · '), findsOneWidget);
    await _save(tester);
    final meetings = await _meetings(tester, db);
    final once = meetings.singleWhere((m) => m.kind == 'once');
    expect(once.date, isNotNull);
  });

  testWidgets('a time from the Week grid fills in the new meeting', (
    tester,
  ) async {
    final (c, db) = await _start(tester);
    // An existing course: straight into the sheet.
    await _open(c, tester, '/course-editor?id=c1&day=4&start=840&end=960');
    expect(find.text('New meeting'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Thu'))
          .selected,
      isTrue,
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Add'));
    expect(find.text('Practice · Thursday'), findsOneWidget);
    await _save(tester);
    final added = (await _meetings(
      tester,
      db,
    )).singleWhere((m) => m.id != 'm1');
    expect((added.weekday, added.startMin, added.endMin), (4, 840, 960));

    // A new course: the meeting is listed and the name comes first.
    await _open(c, tester, '/course-editor?day=1&start=600&end=720');
    expect(find.text('New meeting'), findsNothing);
    expect(find.text('Lecture · Monday'), findsOneWidget);
    final name = tester.widget<TextField>(find.byType(TextField).first);
    expect(name.focusNode?.hasFocus ?? name.autofocus, isTrue);
  });

  testWidgets('optional fields wait behind "+" chips', (tester) async {
    final (c, db) = await _start(tester);
    await _open(c, tester, '/course-editor');
    expect(find.widgetWithText(TextField, 'Course code'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Lecturer'), findsOneWidget);

    await _tap(tester, find.widgetWithText(ActionChip, 'Course code'));
    expect(find.widgetWithText(ActionChip, 'Course code'), findsNothing);
    final code = find.widgetWithText(TextField, 'Course code');
    expect(code, findsOneWidget);
    await tester.enterText(code, '104031');
    await tester.enterText(find.byType(TextField).first, 'Algebra');
    await _save(tester);
    final courses = await tester.runAsync(() => db.select(db.courses).get());
    expect(courses!.singleWhere((x) => x.name == 'Algebra').code, '104031');

    // A course with a code shows the field.
    await _open(c, tester, '/course-editor?id=${courses.last.id}');
    expect(find.widgetWithText(TextField, 'Course code'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Course code'), findsNothing);
  });

  testWidgets('the color dot opens the palette', (tester) async {
    final (c, db) = await _start(tester);
    await _open(c, tester, '/course-editor?id=c1');
    await _tap(tester, find.byTooltip('Color'));
    expect(find.byKey(const ValueKey('color-mint')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('color-mint')));
    expect(find.byKey(const ValueKey('color-mint')), findsNothing);
    await _save(tester);
    final course = await tester.runAsync(
      () => db.select(db.courses).getSingle(),
    );
    expect(course!.colorKey, 'mint');
  });

  testWidgets('requirement, notes and links fold into rows', (tester) async {
    final (c, db) = await _start(tester);
    await _open(c, tester, '/course-editor?id=c1');
    expect(
      find.textContaining('Set a minimum attendance and LecCheck tells you'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Attendance requirement'));
    await _tap(tester, find.text('Add requirement'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Done'));
    expect(find.text('80% · All sessions'), findsOneWidget);

    await _tap(tester, find.text('Notes & links'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Notes'),
      'Bring a calculator\nand a pen',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Course website'),
      'https://example.com',
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Done'));
    expect(find.text('Bring a calculator · 1 link'), findsOneWidget);

    await _save(tester);
    final course = await tester.runAsync(
      () => db.select(db.courses).getSingle(),
    );
    expect(
      (course!.notes, course.website),
      ('Bring a calculator\nand a pen', 'https://example.com'),
    );
    final reqs = await tester.runAsync(() => db.select(db.requirements).get());
    expect(reqs!.single.minPercent, 80);
  });

  testWidgets('wide windows: two columns, meetings in a dialog', (
    tester,
  ) async {
    final (c, _) = await _start(tester, size: const Size(1400, 900), ratio: 1);
    await _open(c, tester, '/course-editor?id=c1');
    expect(
      tester.getRect(find.text('Weekly schedule')).left,
      greaterThan(
        tester.getRect(find.widgetWithText(TextField, 'Course name')).right,
      ),
    );
    await _tap(tester, find.text('Lecture · Tuesday'));
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Edit meeting'), findsOneWidget);
  });

  testWidgets('the course page: sessions by type, one-time from the app bar', (
    tester,
  ) async {
    final (c, _) = await _start(tester);
    await _open(c, tester, '/courses/c1');
    final firstTile = find.byType(SessionTile).first;
    expect(
      find.descendant(of: firstTile, matching: find.text('Lecture #1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstTile, matching: find.text('Calculus')),
      findsNothing,
    );
    expect(find.byType(FloatingActionButton), findsNothing);

    await _tap(tester, find.byTooltip('Add one-time session'));
    expect(find.text('New meeting'), findsOneWidget);
    expect(find.text('One-time'), findsOneWidget);
  });

  testWidgets('in Hebrew', (tester) async {
    final (c, _) = await _start(tester, locale: 'he');
    await _open(c, tester, '/course-editor?id=c1');
    await _tap(tester, find.text('הרצאה · יום שלישי'));
    expect(find.text('עריכת מפגש'), findsOneWidget);
    await _tap(tester, find.text('שבועי'));
    expect(find.text('פעם בשבועיים, החל משבוע 2'), findsOneWidget);
  });
}
