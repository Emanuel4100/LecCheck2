import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/app/theme/colors.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<SharedPreferencesWithCache> _prefs() async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await prefs.setString('appearance.locale', 'en');
  return prefs;
}

/// The app on a phone, on Settings → Appearance.
Future<ProviderContainer> _appearance(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final prefs = await _prefs();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
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
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      minuteClockProvider.overrideWith(
        (ref) => Stream.value(DateTime(2026, 10, 20, 13)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LecCheckApp()),
  );
  await _settle(tester);
  container.read(routerProvider).push('/settings');
  await _settle(tester);
  await tester.tap(find.text('Appearance'));
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

Future<void> _openCustom(WidgetTester tester) async {
  final tile = find.byKey(const ValueKey('preset-custom'));
  await tester.scrollUntilVisible(tile, 200, scrollable: _presets);
  await tester.tap(tile);
  await _settle(tester);
  expect(find.text('Your color'), findsOneWidget);
}

/// The theme tiles' horizontal list.
final _presets = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
);

/// The app's primary color, as the Appearance page has it.
Color _primary(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).last)).colorScheme.primary;

void main() {
  testWidgets('the new presets are offered', (tester) async {
    await _appearance(tester);
    for (final name in ['Teal', 'Amber', 'Indigo']) {
      await tester.scrollUntilVisible(
        find.text(name),
        200,
        scrollable: _presets,
      );
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('Custom: Save picks the color, Cancel changes nothing', (
    tester,
  ) async {
    final container = await _appearance(tester);
    final ocean = _primary(tester);

    await _openCustom(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(container.read(appearanceProvider).preset, ThemePreset.ocean);
    expect(container.read(appearanceProvider).customSeed, isNull);

    await _openCustom(tester);
    // Ocean is blue; the slider's start is red.
    await tester.drag(find.byType(Slider), const Offset(-400, 0));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final appearance = container.read(appearanceProvider);
    expect(appearance.preset, ThemePreset.custom);
    expect(appearance.customSeed, isNotNull);
    expect(_primary(tester), isNot(ocean));
  });

  test('the custom color and preset are saved', () async {
    final prefs = await _prefs();
    final first = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    first.read(appearanceProvider.notifier).setCustom(const Color(0xFF33AA55));
    // Another preset keeps the custom color for later.
    first.read(appearanceProvider.notifier).setPreset(ThemePreset.teal);
    first.dispose();

    final again = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    final appearance = again.read(appearanceProvider);
    expect(appearance.preset, ThemePreset.teal);
    expect(appearance.customSeed, 0xFF33AA55);
  });
}
