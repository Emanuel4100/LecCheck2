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
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/app/theme/colors.dart';
import 'package:leccheck/app/move_controller.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/icons/lec_icons.dart';
import 'package:leccheck/core/update/update_download.dart';
import 'package:leccheck/core/update/update_service.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/features/settings/move_dialog.dart';
import 'package:leccheck/features/settings/update_dialog.dart';
import 'package:leccheck/features/week/week_page.dart';
import 'package:leccheck/features/tour/tour_controller.dart';
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

/// [long]: long course names and no short names, as many users type them.
Future<void> _seed(
  ScheduleRepository repo, {
  required bool hebrew,
  bool long = false,
}) async {
  String name(String en, String he, String longEn, String longHe) =>
      hebrew ? (long ? longHe : he) : (long ? longEn : en);
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
            name: name(
              'Calculus 1',
              'חשבון אינפיניטסימלי 1',
              'Infinitesimal Calculus 1',
              'חשבון אינפיניטסימלי 1',
            ),
            shortName: hebrew && !long ? 'חדו״א 1' : '',
            code: '104031',
            lecturer: hebrew ? 'ד״ר כהן' : 'Dr. Cohen',
            contacts: [
              CourseContact(
                name: hebrew ? 'ד״ר כהן' : 'Dr. Cohen',
                email: 'cohen@technion.ac.il',
              ),
              CourseContact(
                name: hebrew ? 'נועה לוי' : 'Noa Levi',
                role: ContactRole.assistant,
                email: 'noa.levi@campus.technion.ac.il',
              ),
            ],
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
            name: name(
              'Physics 1M',
              'פיזיקה 1מ',
              'Physics for Engineers 1M',
              'פיזיקה להנדסה 1מ',
            ),
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
            name: name(
              'Data Structures',
              'מבני נתונים',
              'Data Structures and Algorithms',
              'מבני נתונים ואלגוריתמים',
            ),
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
            name: name(
              'Linear Algebra',
              'אלגברה ליניארית',
              'Linear Algebra for Computer Science',
              'אלגברה ליניארית למדעי המחשב',
            ),
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
  // One canceled class later today, to show how canceled looks.
  final canceled = index.all.firstWhere(
    (o) => o.start.isAfter(_now) && o.start.day == _now.day,
  );
  await repo.setStatus(canceled, AttendanceStatus.canceled);
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required String locale,
  required ThemeMode mode,
  ThemePreset preset = ThemePreset.ocean,
  Size size = const Size(412, 915),
  double pixelRatio = 2.6,
  bool longNames = false,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
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
    () =>
        _seed(ScheduleRepository(db), hebrew: locale == 'he', long: longNames),
  );

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      minuteClockProvider.overrideWith((ref) => Stream.value(_now)),
      ...overrides,
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

/// In the course editor: the sheet of its first meeting.
Future<void> _openFirstMeeting(WidgetTester tester) async {
  await tester.tap(find.byIcon(LecIcons.lecture).first);
  await _settle(tester);
}

/// Week with this Wednesday off, for one screenshot.
Future<void> _dayOff(
  WidgetTester tester,
  ProviderContainer c,
  String label,
  String shot,
) async {
  final repo = c.read(repositoryProvider);
  final range = NoClassRange(
    id: 'off',
    semesterId: 'sem',
    start: LocalDate.parse('2026-11-11'),
    end: LocalDate.parse('2026-11-11'),
    label: label,
  );
  await tester.runAsync(() => repo.saveNoClassRange(range));
  await _settle(tester);
  await _shot(tester, shot);
  await tester.runAsync(() => repo.deleteNoClassRange(range.id));
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

  testWidgets('a marked session', (tester) async {
    await _pumpApp(tester, locale: 'en', mode: ThemeMode.light);
    await tester.tap(find.text('Attended').first);
    await _settle(tester);
    await _shot(tester, 'en_light_today_marked');
  });

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
    c.read(weekCommandsProvider).step(1);
    await _settle(tester);
    await _shot(tester, 'en_light_week_next');
    c.read(weekCommandsProvider).thisWeek();
    await _settle(tester);
    await _dayOff(tester, c, 'Hanukkah', 'en_light_week_off');
    // An empty slot: Thursday 13:10 (the grid starts at 8:00, 60 px an
    // hour).
    final thursday = tester.getRect(
      find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_DayColumn')
          .at(4),
    );
    await tester.tapAt(Offset(thursday.center.dx, thursday.top + 5 * 60 + 10));
    await _settle(tester);
    await _shot(tester, 'en_light_week_add');
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);
    await _go(tester, c, '/courses');
    await _shot(tester, 'en_light_courses');
    await _go(tester, c, '/courses/calc');
    await _shot(tester, 'en_light_course');
    await _go(tester, c, '/stats');
    await _shot(tester, 'en_light_stats');
    await tester.scrollUntilVisible(
      find.text('More details'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('More details'));
    await _settle(tester);
    await _shot(tester, 'en_light_stats_details');
    await _go(tester, c, '/settings');
    await _shot(tester, 'en_light_settings');
    await tester.tap(find.text('Appearance'));
    await _settle(tester);
    await _shot(tester, 'en_light_settings_appearance');
    await tester.pageBack();
    await _settle(tester);
    await _go(tester, c, '/course-editor?id=calc');
    await _shot(tester, 'en_light_editor');
    await _openFirstMeeting(tester);
    await _shot(tester, 'en_light_meeting_sheet');
    await tester.tap(find.text('Done'));
    await _settle(tester);
    await _go(tester, c, '/today');
    await _go(tester, c, '/course-editor');
    await _shot(tester, 'en_light_editor_new');
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
    c.read(weekCommandsProvider).step(1);
    await _settle(tester);
    await _shot(tester, 'he_dark_week_next');
    c.read(weekCommandsProvider).thisWeek();
    await _settle(tester);
    await _dayOff(tester, c, 'חנוכה', 'he_dark_week_off');
    await _go(tester, c, '/stats');
    await _shot(tester, 'he_dark_stats');
    await _go(tester, c, '/settings');
    await _shot(tester, 'he_dark_settings');
    await _go(tester, c, '/course-editor?id=calc');
    await _shot(tester, 'he_dark_editor');
    await _openFirstMeeting(tester);
    await _shot(tester, 'he_dark_meeting_sheet');
  });

  testWidgets('Desktop · English · light', (tester) async {
    final c = await _pumpApp(
      tester,
      locale: 'en',
      mode: ThemeMode.light,
      size: const Size(1440, 900),
      pixelRatio: 1,
    );
    await _shot(tester, 'desktop_today');
    await _go(tester, c, '/week');
    await tester.tap(find.text('Data Structures').first);
    await _settle(tester);
    await _shot(tester, 'desktop_week');
    await _go(tester, c, '/courses');
    await _shot(tester, 'desktop_courses');
    await _go(tester, c, '/stats');
    await _shot(tester, 'desktop_stats');
    await _go(tester, c, '/settings');
    await _shot(tester, 'desktop_settings');
    await _go(tester, c, '/course-editor?id=calc');
    await _shot(tester, 'desktop_editor');
    await _openFirstMeeting(tester);
    await _shot(tester, 'desktop_meeting_dialog');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  // An update: what's new, then each step (Flatpak on Linux, the APK on
  // Android).
  const update = AppUpdate(
    version: '2.0.0-beta.15',
    build: 23,
    notesUrl: 'https://example.com/notes',
    androidUniversal: 'https://example.com/a.apk',
    flatpakRef: 'https://example.com/leccheck.flatpakref',
    notes:
        '- **Linux comes as a Flatpak** from LecCheck\'s own repository:\n'
        '  updates arrive through Flatpak, step by step in this window.\n'
        '- **A clearer update window**: the size before you download, a\n'
        '  visible check of the file, and what to do when something fails.\n'
        '- Install it once with `flatpak install --user …`; it updates\n'
        '  itself after that.\n'
        '\n'
        '### Smaller things\n'
        '- **Import backup** on the welcome screen.\n'
        '- Linux no longer needs WebKitGTK.',
  );
  const flatpak = UpdateState(update: update, via: UpdateVia.flatpak);

  Future<void> updateShot(
    WidgetTester tester,
    UpdateState state,
    String name, {
    bool phone = false,
  }) async {
    final c = await _pumpApp(
      tester,
      locale: 'en',
      mode: ThemeMode.light,
      size: phone ? const Size(412, 915) : const Size(1440, 900),
      pixelRatio: phone ? 2.6 : 1,
      overrides: [updateProvider.overrideWith(() => _FixedUpdate(state))],
    );
    showUpdateDialog(
      c.read(routerProvider).routerDelegate.navigatorKey.currentContext!,
    );
    await _settle(tester);
    await _shot(tester, name);
  }

  testWidgets(
    'Update window · available',
    (tester) => updateShot(tester, flatpak, 'desktop_update_available'),
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Update window · the Flatpak portal installs it',
    (tester) => updateShot(
      tester,
      const UpdateState(
        update: update,
        via: UpdateVia.flatpak,
        phase: UpdatePhase.downloading,
        portalProgress: 0.45,
      ),
      'desktop_update_progress',
    ),
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Update window · verified by Flatpak, Restart',
    (tester) => updateShot(
      tester,
      const UpdateState(
        update: update,
        via: UpdateVia.flatpak,
        phase: UpdatePhase.restart,
        portalProgress: 1,
      ),
      'desktop_update_restart',
    ),
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Update window · Flatpak may not update LecCheck',
    (tester) => updateShot(
      tester,
      const UpdateState(
        update: update,
        via: UpdateVia.flatpak,
        phase: UpdatePhase.failed,
        failedStep: UpdateStep.download,
        failure: UpdateFailure.flatpakDenied,
      ),
      'desktop_update_denied',
    ),
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Update window · checking the file (Android)',
    (tester) => updateShot(
      tester,
      const UpdateState(
        update: update,
        via: UpdateVia.apk,
        file: UpdateFile('https://example.com/a.apk', 'hash', size: 31200000),
        phase: UpdatePhase.verifying,
        received: 31200000,
        total: 31200000,
        bytesPerSecond: 4300000,
        checked: 19000000,
      ),
      'en_light_update_check',
      phone: true,
    ),
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  Future<void> moveShot(
    WidgetTester tester,
    MoveState state,
    String name,
  ) async {
    final c = await _pumpApp(
      tester,
      locale: 'en',
      mode: ThemeMode.light,
      size: const Size(1440, 900),
      pixelRatio: 1,
      overrides: [moveProvider.overrideWith(() => _FixedMove(state))],
    );
    showMoveDialog(
      c.read(routerProvider).routerDelegate.navigatorKey.currentContext!,
    );
    await _settle(tester);
    await _shot(tester, name);
  }

  testWidgets(
    'Move to the Flatpak · why and how',
    (tester) =>
        moveShot(tester, const MoveState(offered: true), 'desktop_move'),
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'Move to the Flatpak · installing',
    (tester) => moveShot(
      tester,
      const MoveState(
        offered: true,
        phase: MovePhase.installing,
        backup: '/home/me/leccheck-backup-2026-11-10.json',
        output: 'Installing 2/3… runtime/org.freedesktop.Platform/x86_64/26.08',
      ),
      'desktop_move_installing',
    ),
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('iPhone · English · light', (tester) async {
    final c = await _pumpApp(tester, locale: 'en', mode: ThemeMode.light);
    await _go(tester, c, '/settings');
    await _shot(tester, 'ios_settings');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  /// Starts the tour and moves on [steps] steps (as Next does).
  Future<void> tour(WidgetTester tester, ProviderContainer c, int steps) async {
    final controller = c.read(tourProvider.notifier);
    if (c.read(tourProvider) == null) controller.start();
    for (var i = 0; i < steps; i++) {
      controller.next();
    }
    await _settle(tester);
  }

  testWidgets('Tour', (tester) async {
    final c = await _pumpApp(tester, locale: 'en', mode: ThemeMode.light);
    await tour(tester, c, 0);
    await _shot(tester, 'en_light_tour_welcome');
    await tour(tester, c, 2);
    await _shot(tester, 'en_light_tour_week');
    await tour(tester, c, 3);
    await _shot(tester, 'en_light_tour_settings');
    await tour(tester, c, 1);
    await _shot(tester, 'en_light_tour_add');
  });

  testWidgets('Tour · Hebrew · dark', (tester) async {
    final c = await _pumpApp(
      tester,
      locale: 'he',
      mode: ThemeMode.dark,
      preset: ThemePreset.grape,
    );
    await tour(tester, c, 1);
    await _shot(tester, 'he_dark_tour_today');
  });

  testWidgets('Tour · Desktop', (tester) async {
    final c = await _pumpApp(
      tester,
      locale: 'en',
      mode: ThemeMode.light,
      size: const Size(1440, 900),
      pixelRatio: 1,
    );
    await tour(tester, c, 5);
    await _shot(tester, 'desktop_tour_settings');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final (locale, mode) in [
    ('en', ThemeMode.light),
    ('he', ThemeMode.dark),
  ]) {
    testWidgets('Week · long names · $locale', (tester) async {
      final c = await _pumpApp(
        tester,
        locale: locale,
        mode: mode,
        longNames: true,
      );
      await _go(tester, c, '/week');
      await _shot(tester, '${locale}_${mode.name}_week_long_names');
    });
  }

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

/// A fixed move instead of looking for install.sh's folder.
class _FixedMove extends MoveController {
  _FixedMove(this.fixed);

  final MoveState fixed;

  @override
  MoveState build() => fixed;
}

/// A fixed update state instead of checking GitHub.
class _FixedUpdate extends UpdateController {
  _FixedUpdate(this.fixed);

  final UpdateState fixed;

  @override
  UpdateState build() => fixed;
}
