import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoAlertDialog, CupertinoDatePicker;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/features/courses/course_page.dart';
import 'package:leccheck/features/session/session_tile.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _now = DateTime(2026, 10, 20, 13, 0); // Tuesday, after the 10:00 lecture

const _desktop = Size(1440, 900);
const _phone = Size(412, 915);

Future<(ProviderContainer, AppDatabase)> _start(
  WidgetTester tester, {
  Size size = _desktop,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
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

Future<String?> _statusOf(WidgetTester tester, AppDatabase db) async {
  final rows = await tester.runAsync(
    () => db.select(db.sessionOverrides).get(),
  );
  return rows!.isEmpty ? null : rows.single.status;
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
}

final _linux = TargetPlatformVariant.only(TargetPlatform.linux);
final _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // ignore: invalid_use_of_visible_for_testing_member
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '2.0.0',
    buildNumber: '10',
    buildSignature: '',
  );

  group('desktop', () {
    testWidgets('sidebar with Add menu; keys switch tabs and weeks', (
      tester,
    ) async {
      await _start(tester);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.text('LecCheck'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await _settle(tester);
      expect(find.text('Add one-time session'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);

      await _ctrl(tester, LogicalKeyboardKey.digit2);
      expect(find.text('Week 1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('Week 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous week'));
      await _settle(tester);
      expect(find.text('Week 1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await _settle(tester);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
    }, variant: _linux);

    testWidgets('right-click a session to mark it; no swipe gestures', (
      tester,
    ) async {
      final (_, db) = await _start(tester);
      expect(find.byType(Dismissible), findsNothing);

      final tile = find.descendant(
        of: find.byType(SessionTile),
        matching: find.text('Calculus'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(tile.first),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await _settle(tester);
      expect(find.text('Go to course'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(PopupMenuItem<Object>),
          matching: find.text('Attended'),
        ),
      );
      await _settle(tester);
      expect(await _statusOf(tester, db), 'attended');
    }, variant: _linux);

    testWidgets('number keys mark the open session, but not while typing', (
      tester,
    ) async {
      final (_, db) = await _start(tester);
      await tester.tap(find.text('Calculus').last);
      await _settle(tester);
      expect(find.text('Details'), findsNothing); // dialog, not the panel

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await _settle(tester);
      expect(await _statusOf(tester, db), 'attended');

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await _settle(tester);
      expect(await _statusOf(tester, db), 'attended');
    }, variant: _linux);

    testWidgets('Courses side by side; Settings in two panes', (tester) async {
      final (container, _) = await _start(tester);
      container.read(routerProvider).go('/courses');
      await _settle(tester);
      // The list and, beside it, the selected course.
      expect(find.byType(CourseDetailView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CourseDetailView),
          matching: find.text('Weekly schedule'),
        ),
        findsOneWidget,
      );

      container.read(routerProvider).push('/settings');
      await _settle(tester);
      await tester.tap(find.text('This device'));
      await _settle(tester);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
    }, variant: _linux);
  });

  group('iPhone', () {
    testWidgets('native switches, dialogs and date picker', (tester) async {
      final (container, _) = await _start(tester, size: _phone);
      final router = container.read(routerProvider);

      // material_ui draws adaptive switches in the iOS style itself (no
      // CupertinoSwitch widget); the iPhone golden shows them.
      router.push('/settings');
      await _settle(tester);
      expect(find.text('Wallpaper'), findsNothing);
      router.pop();
      await _settle(tester);

      router.push('/semester?id=sem');
      await _settle(tester);
      await tester.tap(
        find.ancestor(
          of: find.text('Start date'),
          matching: find.byType(InkWell),
        ),
      );
      await _settle(tester);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('Done'));
      await _settle(tester);
      router.pop();
      await _settle(tester);

      router.push('/course-editor');
      await _settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Draft');
      await tester.pump();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      await _settle(tester);
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await _settle(tester);
      expect(find.text('New course'), findsOneWidget);
    }, variant: _iOS);
  });

  testWidgets('phone: swipe still marks', (tester) async {
    final (_, db) = await _start(tester, size: _phone);
    await tester.drag(find.byType(Dismissible).first, const Offset(300, 0));
    await _settle(tester);
    expect(await _statusOf(tester, db), 'attended');
  });
}
