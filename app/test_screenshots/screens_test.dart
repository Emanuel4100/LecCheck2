// Renders the real app offscreen with demo data and saves PNG screenshots.
//
//   flutter test test_screenshots --update-goldens
//
// Kept out of test/ because golden images differ slightly between machines.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/app/theme/colors.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Tuesday of week 4, during the Data Structures lecture.
final _now = DateTime(2026, 11, 10, 11, 15);

Future<void> _loadFonts() async {
  final rubik = FontLoader('Rubik');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    rubik.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Rubik-$w.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await rubik.load();
  var dir = File(Platform.resolvedExecutable).parent;
  late File icons;
  while (true) {
    icons = File(
      '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync() || dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
  await loader.load();
  final lec = FontLoader('LecIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/LecIcons.ttf').readAsBytesSync(),
        ),
      ),
    );
  await lec.load();
}

MeetingRule _weekly(
  String id,
  String course,
  SessionType type,
  int weekday,
  int start,
  int end,
  String room, {
  int interval = 1,
}) => MeetingRule(
  id: id,
  courseId: course,
  type: type,
  kind: MeetingKind.weekly,
  weekday: weekday,
  startMin: start,
  endMin: end,
  location: room,
  intervalWeeks: interval,
);

Future<void> _seed(ScheduleRepository repo, {required bool hebrew}) async {
  final semester = SemesterInfo(
    id: 'sem',
    name: hebrew ? 'סמסטר א׳ תשפ״ז' : 'Semester A 2026/27',
    start: LocalDate.parse('2026-10-18'),
    end: LocalDate.parse('2027-01-22'),
    weekStart: DateTime.sunday,
    visibleDays: const {7, 1, 2, 3, 4},
  );
  await repo.saveSemester(semester);
  final courses =
      <(CourseInfo, List<MeetingRule>, List<AttendanceRequirement>)>[
        (
          CourseInfo(
            id: 'calc',
            semesterId: 'sem',
            name: hebrew ? 'חשבון אינפיניטסימלי 1' : 'Calculus 1',
            code: '104031',
            lecturer: hebrew ? 'ד״ר כהן' : 'Dr. Cohen',
            colorKey: 'ocean',
          ),
          [
            _weekly('calc-l', 'calc', SessionType.lecture, 7, 600, 720, '201'),
            _weekly('calc-p', 'calc', SessionType.practice, 2, 840, 930, '7'),
          ],
          [
            const AttendanceRequirement(
              id: 'calc-r',
              courseId: 'calc',
              type: SessionType.practice,
              minPercent: 80,
            ),
          ],
        ),
        (
          CourseInfo(
            id: 'phys',
            semesterId: 'sem',
            name: hebrew ? 'פיזיקה 1מ' : 'Physics 1M',
            colorKey: 'sun',
          ),
          [
            _weekly(
              'phys-l',
              'phys',
              SessionType.lecture,
              1,
              720,
              840,
              'Ullmann 1',
            ),
            _weekly(
              'phys-lab',
              'phys',
              SessionType.lab,
              3,
              540,
              720,
              'Lab 3',
              interval: 2,
            ),
          ],
          const <AttendanceRequirement>[],
        ),
        (
          CourseInfo(
            id: 'ds',
            semesterId: 'sem',
            name: hebrew ? 'מבני נתונים' : 'Data Structures',
            colorKey: 'grape',
          ),
          [
            _weekly('ds-l', 'ds', SessionType.lecture, 2, 630, 750, 'Taub 2'),
            _weekly('ds-p', 'ds', SessionType.practice, 4, 960, 1020, 'Taub 4'),
          ],
          const <AttendanceRequirement>[],
        ),
        (
          CourseInfo(
            id: 'la',
            semesterId: 'sem',
            name: hebrew ? 'אלגברה ליניארית' : 'Linear Algebra',
            colorKey: 'mint',
          ),
          [
            _weekly('la-l', 'la', SessionType.lecture, 4, 600, 720, '301'),
            _weekly('la-p', 'la', SessionType.practice, 7, 840, 900, '12'),
          ],
          const <AttendanceRequirement>[],
        ),
      ];
  for (final (c, meetings, reqs) in courses) {
    await repo.saveCourse(c, meetings: meetings, requirements: reqs);
  }

  // Mark history: mostly attended, some missed/watched, a few left pending.
  final index = OccurrenceEngine.expand(
    semester: semester,
    meetings: [for (final c in courses) ...c.$2],
  );
  var i = 0;
  for (final o in index.all) {
    if (!o.end.isBefore(_now.subtract(const Duration(hours: 20)))) continue;
    final status = switch (i++ % 9) {
      3 => AttendanceStatus.missed,
      6 => AttendanceStatus.watched,
      8 => null,
      _ => AttendanceStatus.attended,
    };
    if (status != null) await repo.setStatus(o, status);
  }
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required String locale,
  required ThemeMode mode,
  ThemePreset preset = ThemePreset.ocean,
}) async {
  tester.view.physicalSize = const Size(412 * 2.6, 915 * 2.6);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await prefs.setString('appearance.locale', locale);
  await prefs.setString('appearance.mode', mode.name);
  await prefs.setString('appearance.preset', preset.name);

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.runAsync(
    () => _seed(ScheduleRepository(db), hebrew: locale == 'he'),
  );

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

/// Lets drift (real async) and animations (fake time) both finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _go(
  WidgetTester tester,
  ProviderContainer c,
  String location,
) async {
  c.read(routerProvider).go(location);
  await _settle(tester);
}

Future<void> _shot(WidgetTester tester, String name) => expectLater(
  find.byType(LecCheckApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // ignore: invalid_use_of_visible_for_testing_member
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '0.1.0',
    buildNumber: '1',
    buildSignature: '',
  );

  setUpAll(_loadFonts);

  testWidgets('English · light', (tester) async {
    final c = await _pumpApp(tester, locale: 'en', mode: ThemeMode.light);
    await _shot(tester, 'en_light_today');
    await tester.tap(find.text('Data Structures').first);
    await _settle(tester);
    await _shot(tester, 'en_light_session');
    await tester.tapAt(const Offset(200, 40));
    await _settle(tester);
    await _go(tester, c, '/week');
    await _shot(tester, 'en_light_week');
    await _go(tester, c, '/courses');
    await _shot(tester, 'en_light_courses');
    await _go(tester, c, '/courses/calc');
    await _shot(tester, 'en_light_course');
    await _go(tester, c, '/stats');
    await _shot(tester, 'en_light_stats');
    await _go(tester, c, '/settings');
    await _shot(tester, 'en_light_settings');
    await _go(tester, c, '/course-editor?id=calc');
    await _shot(tester, 'en_light_editor');
  });

  testWidgets('Hebrew · dark', (tester) async {
    final c = await _pumpApp(
      tester,
      locale: 'he',
      mode: ThemeMode.dark,
      preset: ThemePreset.grape,
    );
    await _shot(tester, 'he_dark_today');
    await _go(tester, c, '/week');
    await _shot(tester, 'he_dark_week');
    await _go(tester, c, '/stats');
    await _shot(tester, 'he_dark_stats');
  });

  testWidgets('Onboarding', (tester) async {
    tester.view.physicalSize = const Size(412 * 2.6, 915 * 2.6);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await prefs.setString('appearance.locale', 'en');
    await prefs.setString('appearance.mode', 'light');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        minuteClockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LecCheckApp(),
      ),
    );
    await _settle(tester);
    await _shot(tester, 'en_light_welcome');
    await _go(tester, container, '/semester');
    await _shot(tester, 'en_light_semester_form');
  });
}
