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
import 'package:leccheck/features/tour/tour_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _now = DateTime(2026, 10, 20, 13, 0);

/// The app on a phone (or [size]), with a semester and no courses unless
/// [withSemester] is false.
Future<ProviderContainer> _start(
  WidgetTester tester, {
  Size size = const Size(1080, 2340),
  double ratio = 2.6,
  String locale = 'en',
  bool withSemester = true,
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
  if (withSemester) {
    await tester.runAsync(
      () => ScheduleRepository(db).saveSemester(
        SemesterInfo(
          id: 'sem',
          name: 'Semester A',
          start: LocalDate.parse('2026-10-18'),
          end: LocalDate.parse('2027-01-22'),
        ),
      ),
    );
  }
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
  return container;
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
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '2.0.0',
    buildNumber: '16',
    buildSignature: '',
  );

  Future<void> next(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await _settle(tester);
  }

  testWidgets('walks through the app and ends at the first course', (
    tester,
  ) async {
    final c = await _start(tester);
    c.read(tourProvider.notifier).start();
    await _settle(tester);
    expect(find.text('Take a quick tour?'), findsOneWidget);

    await next(tester, 'Start');
    expect(find.textContaining("Today's classes"), findsOneWidget);
    // The card sits above the highlighted navigation bar.
    expect(
      tester.getRect(find.textContaining("Today's classes")).bottom,
      lessThan(tester.getRect(find.byType(NavigationBar)).top),
    );

    await next(tester, 'Next');
    expect(find.textContaining('Your timetable'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await next(tester, 'Next');
    expect(find.textContaining('Every course'), findsOneWidget);
    await next(tester, 'Next');
    expect(find.textContaining("How you're doing"), findsOneWidget);
    await next(tester, 'Next');
    expect(find.textContaining('Reminders, sync'), findsOneWidget);
    // The gear is in Today's app bar: the card goes below it.
    expect(
      tester.getRect(find.textContaining('Reminders, sync')).top,
      greaterThan(tester.getRect(find.byTooltip('Settings')).bottom),
    );

    await next(tester, 'Next');
    expect(find.text('Add your first course'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add course').last);
    await _settle(tester);
    expect(c.read(tourProvider), isNull);
    expect(c.read(sharedPrefsProvider).getBool(TourController.doneKey), isTrue);
    expect(c.read(routerProvider).state.matchedLocation, '/course-editor');
  });

  testWidgets('Back and Skip', (tester) async {
    final c = await _start(tester);
    c.read(tourProvider.notifier).start();
    await _settle(tester);
    await next(tester, 'Start');
    await next(tester, 'Next');
    await tester.tap(find.widgetWithText(TextButton, 'Back'));
    await _settle(tester);
    expect(c.read(tourProvider), TourStep.today);

    await tester.tap(find.byTooltip('Skip'));
    await _settle(tester);
    expect(c.read(tourProvider), isNull);
    expect(find.textContaining("Today's classes"), findsNothing);
    // It doesn't start by itself again.
    c.read(tourProvider.notifier).startFirstTime();
    expect(c.read(tourProvider), isNull);
  });

  testWidgets('wide windows point at the rail', (tester) async {
    final c = await _start(tester, size: const Size(1400, 900), ratio: 1);
    c.read(tourProvider.notifier).start();
    await _settle(tester);
    await next(tester, 'Start');
    expect(find.textContaining("Today's classes"), findsOneWidget);
    expect(
      tester.getRect(find.textContaining("Today's classes")).left,
      greaterThan(tester.getRect(find.byType(NavigationRail)).left),
    );
    for (var i = 0; i < 5; i++) {
      await next(tester, 'Next');
    }
    expect(find.text('Add your first course'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await _settle(tester);
    expect(c.read(tourProvider), isNull);
  });

  testWidgets('in Hebrew', (tester) async {
    final c = await _start(tester, locale: 'he');
    c.read(tourProvider.notifier).start();
    await _settle(tester);
    expect(find.text('סיור קצר באפליקציה?'), findsOneWidget);
    await next(tester, 'להתחיל');
    expect(find.textContaining('השיעורים של היום'), findsOneWidget);
  });

  testWidgets('starts after setting up the first semester', (tester) async {
    final c = await _start(tester, withSemester: false);
    await tester.tap(find.text('Continue without an account'));
    await _settle(tester);
    await tester.tap(find.text('Create semester'));
    await _settle(tester);
    expect(c.read(tourProvider), TourStep.welcome);
    expect(find.text('Take a quick tour?'), findsOneWidget);
  });
}
