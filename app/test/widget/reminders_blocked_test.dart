import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/notification_controller.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/core/notifications/notification_service.dart';
import 'package:leccheck/features/settings/reminder_access.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A fixed answer instead of asking the OS.
class _Health extends ReminderHealthController {
  _Health(this.health);

  final ReminderHealth health;

  @override
  ReminderHealth build() => health;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    ReminderHealth health, {
    bool remindersOn = true,
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await prefs.setBool('notify.after', remindersOn);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          reminderHealthProvider.overrideWith(() => _Health(health)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RemindersBlockedCard()),
        ),
      ),
    );
  }

  testWidgets('warns while the system blocks LecCheck', (tester) async {
    await pump(tester, const ReminderHealth(allowed: false));
    expect(find.text('Notifications are off for LecCheck'), findsOneWidget);
    expect(
      find.text("Reminders can't appear until you allow them."),
      findsOneWidget,
    );
    expect(find.text('Allow'), findsOneWidget);
  });

  testWidgets('names a reminder channel that is off', (tester) async {
    await pump(
      tester,
      const ReminderHealth(allowed: true, blockedChannels: ['after_class']),
    );
    expect(
      find.text(
        '“After class” notifications are turned off in the system settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('says nothing when allowed, unknown or reminders off', (
    tester,
  ) async {
    await pump(tester, const ReminderHealth(allowed: true));
    expect(find.byType(Card), findsNothing);
    await pump(tester, const ReminderHealth());
    expect(find.byType(Card), findsNothing);
    await pump(
      tester,
      const ReminderHealth(allowed: false),
      remindersOn: false,
    );
    expect(find.byType(Card), findsNothing);
  });
}
