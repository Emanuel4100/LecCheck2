import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/features/session/session_tile.dart';
import 'package:leccheck/features/session/status_buttons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Today on a phone at [now], with "Calculus": lectures Tuesdays 10:00–12:00
/// in Taub 2 and practices Tuesdays 14:00–16:00, from Sunday 2026-10-18.
Future<(ProviderContainer, AppDatabase)> _start(
  WidgetTester tester, {
  required DateTime now,
  bool markFirstLecture = false,
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
          location: 'Taub 2',
        ),
        MeetingRule(
          id: 'm2',
          courseId: 'c1',
          type: SessionType.practice,
          kind: MeetingKind.weekly,
          weekday: DateTime.tuesday,
          startMin: 840,
          endMin: 960,
        ),
      ],
      requirements: const [],
    );
    for (final (meeting, date) in [
      ('m2', '2026-10-20'),
      if (markFirstLecture) ('m1', '2026-10-20'),
    ]) {
      await repo.setStatusFor(
        meetingId: meeting,
        originalDate: LocalDate.parse(date),
        status: AttendanceStatus.attended,
      );
    }
  });

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      minuteClockProvider.overrideWith((ref) => Stream.value(now)),
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

/// The "Needs marking" tiles.
final _toMark = find.byWidgetPredicate(
  (w) => w is SessionTile && w.quickActions,
);

/// Text containing [text], with the no-break spaces of session details read
/// as spaces.
Finder _text(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '')
          .replaceAll('\u00A0', ' ')
          .contains(text),
);

Finder _tileWith(String text) =>
    find.ancestor(of: _text(text), matching: find.byType(SessionTile));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  PackageInfo.setMockInitialValues(
    appName: 'LecCheck',
    packageName: 'com.leccheck.app',
    version: '2.0.0',
    buildNumber: '17',
    buildSignature: '',
  );

  testWidgets('the class in progress is marked from the Now card only', (
    tester,
  ) async {
    // Tuesday of week 2, during lecture #2; lecture #1 isn't marked.
    await _start(tester, now: DateTime(2026, 10, 27, 11));
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Needs marking'), findsOneWidget);
    expect(find.text('1 session'), findsOneWidget);
    expect(
      find.descendant(of: _toMark, matching: _text('Lecture #1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _toMark, matching: _text('Lecture #2')),
      findsNothing,
    );
  });

  testWidgets('nothing else to mark: no "caught up" under the Now card', (
    tester,
  ) async {
    await _start(
      tester,
      now: DateTime(2026, 10, 27, 11),
      markFirstLecture: true,
    );
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Needs marking'), findsNothing);
    expect(find.text("You're all caught up"), findsNothing);
  });

  testWidgets('the swipe hint goes away once you have swiped', (tester) async {
    // After lecture #2: two lectures to mark.
    final (c, _) = await _start(tester, now: DateTime(2026, 10, 27, 13));
    const hint = 'Swipe right for attended, left for missed';
    expect(find.text(hint), findsOneWidget);
    await tester.drag(_toMark.first, const Offset(300, 0));
    await _settle(tester);
    expect(find.text(hint), findsNothing);
    expect(c.read(sharedPrefsProvider).getBool(swipeHintKey), isTrue);
  });

  testWidgets('a class that has not started shows no "to mark" circle', (
    tester,
  ) async {
    // Lecture #2 is in the big card, Practice #2 comes later.
    await _start(tester, now: DateTime(2026, 10, 27, 8));
    await tester.scrollUntilVisible(
      _tileWith('Practice #2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final later = _tileWith('Practice #2').first;
    expect(
      find.descendant(of: later, matching: find.byType(StatusIndicator)),
      findsNothing,
    );
  });

  testWidgets('the session in the big card is not listed again', (
    tester,
  ) async {
    await _start(tester, now: DateTime(2026, 10, 27, 8));
    expect(_text('Lecture #2'), findsOneWidget);
    expect(_tileWith('Lecture #2'), findsNothing);
  });

  testWidgets('a past class waiting to be marked has the circle', (
    tester,
  ) async {
    await _start(tester, now: DateTime(2026, 10, 27, 13));
    final past = find.descendant(
      of: find.byWidgetPredicate((w) => w is SessionTile && !w.quickActions),
      matching: _text('Lecture #2'),
    );
    await tester.ensureVisible(past.first);
    expect(
      find.descendant(
        of: find.ancestor(of: past.first, matching: find.byType(SessionTile)),
        matching: find.byType(StatusIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('session details never end a line with a separator', (
    tester,
  ) async {
    await _start(tester, now: DateTime(2026, 10, 27, 13));
    final lines = [
      for (final e
          in find
              .descendant(of: _toMark, matching: find.byType(Text))
              .evaluate())
        switch (e.widget) {
          Text(:final data?) => data,
          Text(:final textSpan?) => textSpan.toPlainText(),
          _ => '',
        },
    ];
    expect(
      lines.map((t) => t.replaceAll('\u00A0', ' ')),
      contains('Lecture #1 · Tue, Oct 20'),
    );
    for (final line in lines) {
      expect(line.trimRight(), isNot(endsWith('·')));
    }
    // The room follows a pin.
    expect(
      find.descendant(
        of: _toMark,
        matching: find.textContaining('Taub 2', findRichText: true),
      ),
      findsNWidgets(2),
    );
  });
}
