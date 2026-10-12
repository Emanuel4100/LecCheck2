import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/update/update_service.dart';
import 'package:leccheck/features/settings/update_card.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A fixed state instead of checking GitHub.
class _Fixed extends UpdateController {
  _Fixed(this.fixed);

  final UpdateState fixed;

  @override
  UpdateState build() => fixed;
}

const _update = AppUpdate(
  version: '2.0.0-beta.8',
  build: 16,
  notesUrl: 'https://example.com/notes',
  androidUniversal: 'https://example.com/a.apk',
);
const _file = UpdateFile('https://example.com/a.apk', 'hash');

void main() {
  Future<void> pump(
    WidgetTester tester,
    UpdateState state, {
    Locale locale = const Locale('en'),
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await tester.pumpWidget(
      ProviderScope(
        // A new scope for each state (overrides are read once).
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          updateProvider.overrideWith(() => _Fixed(state)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: UpdateCard()),
        ),
      ),
    );
  }

  Finder button(String label) => find.text(label);

  testWidgets('Update when the file can be installed, else Download', (
    tester,
  ) async {
    await pump(tester, const UpdateState(update: _update, file: _file));
    expect(find.text('LecCheck 2.0.0-beta.8 is available'), findsOneWidget);
    expect(button('Update'), findsOneWidget);
    expect(button('Download'), findsNothing);

    await pump(tester, const UpdateState(update: _update));
    expect(button('Download'), findsOneWidget);
    expect(button('Update'), findsNothing);
  });

  testWidgets('Linux shows the install.sh hint only without Update', (
    tester,
  ) async {
    await pump(tester, const UpdateState(update: _update));
    expect(find.textContaining('install.sh'), findsOneWidget);
    await pump(tester, const UpdateState(update: _update, file: _file));
    expect(find.textContaining('install.sh'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('each step shows its text and buttons', (tester) async {
    UpdateState at(UpdatePhase phase, [double? progress]) => UpdateState(
      update: _update,
      file: _file,
      phase: phase,
      progress: progress,
    );

    await pump(tester, at(UpdatePhase.downloading, 0.42));
    expect(find.text('Downloading… 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(button('Cancel'), findsOneWidget);
    expect(button('Update'), findsNothing);

    await pump(tester, at(UpdatePhase.installing));
    expect(find.text('Installing…'), findsOneWidget);
    expect(button('Cancel'), findsNothing);

    await pump(tester, at(UpdatePhase.downloaded));
    expect(find.textContaining("Android's installer"), findsOneWidget);
    expect(button('Install'), findsOneWidget);

    await pump(tester, at(UpdatePhase.restart));
    expect(find.textContaining('Restart LecCheck'), findsOneWidget);
    expect(button('Restart'), findsOneWidget);

    await pump(tester, at(UpdatePhase.failed));
    expect(find.textContaining("Couldn't update"), findsOneWidget);
    expect(button('Open in browser'), findsOneWidget);
    expect(button('Retry'), findsOneWidget);
  });

  testWidgets('Hebrew', (tester) async {
    await pump(
      tester,
      const UpdateState(
        update: _update,
        file: _file,
        phase: UpdatePhase.downloading,
        progress: 0.5,
      ),
      locale: const Locale('he'),
    );
    expect(find.text('מתבצעת הורדה… 50%'), findsOneWidget);
    expect(button('ביטול'), findsOneWidget);
  });
}
