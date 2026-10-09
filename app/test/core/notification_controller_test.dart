import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leccheck/app/notification_controller.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/notifications/notification_service.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_reminder_os.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('en'));

  late AppDatabase db;
  late ScheduleRepository repo;
  late SharedPreferencesWithCache prefs;
  late FakeReminderOs os;
  late NotificationService service;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await prefs.setString(AppearanceController.localeKey, 'en');
    await prefs.setBool('notify.before', true);
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db);
    os = FakeReminderOs();
    service = NotificationService.forTesting(os);
  });

  tearDown(() => db.close());

  Future<void> addSemester() async {
    final start = LocalDate.fromDateTime(DateTime.now());
    await repo.saveSemester(
      SemesterInfo(
        id: 'sem',
        name: 'Semester A',
        start: start,
        end: start.addDays(120),
      ),
    );
    await repo.saveCourse(
      const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Calculus'),
      meetings: [
        for (var day = 1; day <= 7; day++)
          MeetingRule(
            id: 'm$day',
            courseId: 'c1',
            type: SessionType.lecture,
            kind: MeetingKind.weekly,
            weekday: day,
            startMin: 23 * 60,
            endMin: 23 * 60 + 30,
          ),
      ],
      requirements: const [],
    );
  }

  /// Listened to like NotificationController.start does (Riverpod pauses
  /// providers nobody listens to).
  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(c.dispose);
    c
      ..listen(semestersProvider, (_, _) {})
      ..listen(semesterDataProvider, (_, _) {})
      ..listen(occurrenceIndexProvider, (_, _) {})
      ..listen(userPrefsProvider, (_, _) {});
    return c;
  }

  /// Waits until the shown semester's data is there.
  Future<void> loaded(ProviderContainer c) async {
    while (c.read(semesterDataProvider).value == null) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('keeps scheduled reminders while the semester loads', () async {
    await addSemester();
    os.listed[42] = 'from before the app was closed';
    final c = container();
    final controller = NotificationController(c, service: service);

    // At startup the data isn't there yet: nothing is cancelled (beta.4
    // cancelled everything here, and dismissed what was on screen).
    expect(await controller.rescheduleNow(), 0);
    expect(os.cancelled, isEmpty);

    // Once it's loaded, the plan replaces what's stale.
    await loaded(c);
    expect(await controller.rescheduleNow(), greaterThan(0));
    expect(os.cancelled, [42]);
    expect(os.scheduled, isNotEmpty);
  });

  test('cancels reminders when there is no semester', () async {
    os.listed[42] = 'stale';
    final c = container();
    while (!c.read(semestersProvider).hasValue) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await NotificationController(c, service: service).rescheduleNow();
    expect(os.cancelled, [42]);
  });

  test('cancels reminders when they are turned off', () async {
    await addSemester();
    final c = container();
    final controller = NotificationController(c, service: service);
    await loaded(c);
    await controller.rescheduleNow();
    final scheduled = os.listed.keys.toList();
    expect(scheduled, isNotEmpty);

    c.read(reminderSettingsProvider.notifier).update(before: false);
    await controller.rescheduleNow();
    expect(os.cancelled, scheduled);
    expect(os.listed, isEmpty);
  });

  test('schedules further ahead on Android than on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = reminderWindow();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = reminderWindow();
    debugDefaultTargetPlatformOverride = null;
    expect(ios.limit, lessThan(64)); // iOS keeps at most 64 pending
    expect(android.limit, greaterThan(ios.limit));
    expect(android.horizonDays, greaterThan(ios.horizonDays));
  });
}
