import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/features/onboarding/welcome_page.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Fixed extends RestoreController {
  _Fixed(this.phase);

  final RestorePhase phase;

  @override
  RestorePhase build() => phase;
}

void main() {
  Future<void> pump(WidgetTester tester, RestorePhase phase) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          restoreProvider.overrideWith(() => _Fixed(phase)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WelcomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('while the account\'s data comes, no way to make a semester', (
    tester,
  ) async {
    await pump(tester, RestorePhase.waiting);
    expect(find.text('Restoring your data…'), findsOneWidget);
    expect(find.text('Continue without an account'), findsNothing);
    expect(find.text('Set up a semester anyway'), findsNothing);
  });

  testWidgets('no data in time: try again, or set up anyway', (tester) async {
    await pump(tester, RestorePhase.failed);
    expect(find.textContaining("Couldn't load your data"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Set up a semester anyway'), findsOneWidget);
    expect(find.text('Continue without an account'), findsNothing);
  });

  testWidgets('first launch: guest or sign in', (tester) async {
    await pump(tester, RestorePhase.idle);
    expect(find.text('Continue without an account'), findsOneWidget);
    expect(find.text('Restoring your data…'), findsNothing);
  });
}
