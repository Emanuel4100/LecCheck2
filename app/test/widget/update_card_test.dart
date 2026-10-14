import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/update/update_service.dart';
import 'package:leccheck/features/settings/update_card.dart';
import 'package:leccheck/features/settings/update_dialog.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    Widget home = const Scaffold(body: UpdateCard()),
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
          home: home,
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
    UpdateState at(UpdatePhase phase, [int? received]) => UpdateState(
      update: _update,
      file: _file,
      phase: phase,
      received: received ?? 0,
      total: received == null ? null : 100,
    );

    await pump(tester, at(UpdatePhase.downloading, 42));
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
        received: 50,
        total: 100,
      ),
      locale: const Locale('he'),
    );
    expect(find.text('מתבצעת הורדה… 50%'), findsOneWidget);
    expect(button('ביטול'), findsOneWidget);
  });

  group('update window', () {
    setUp(
      () => PackageInfo.setMockInitialValues(
        appName: 'LecCheck',
        packageName: 'com.leccheck.app',
        version: '2.0.0-beta.7',
        buildNumber: '15',
        buildSignature: '',
      ),
    );

    Future<void> show(WidgetTester tester, UpdateState state) async {
      await pump(tester, state, home: const Scaffold(body: UpdateDialog()));
      // Not pumpAndSettle: the active step's spinner never stops.
      await tester.pump();
      await tester.pump();
    }

    UpdateState at(UpdatePhase phase, {UpdateStep? failed}) => UpdateState(
      update: _update,
      file: _file,
      phase: phase,
      received: 4200000,
      total: 10000000,
      bytesPerSecond: 2100000,
      failedStep: failed,
    );

    testWidgets("what's new, then Later, Skip or Update", (tester) async {
      await show(
        tester,
        const UpdateState(
          update: AppUpdate(
            version: '2.0.0-beta.8',
            build: 16,
            notesUrl: 'https://example.com/notes',
            notes:
                '- **Contacts** for each course, with\n  their email.\n'
                '- Faster sync.',
          ),
          file: _file,
        ),
      );
      expect(find.text('You have 2.0.0-beta.7'), findsOneWidget);
      // Items joined across their wrapped lines, ** marks gone.
      expect(
        find.text(
          'Contacts for each course, with their email.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Faster sync.', findRichText: true), findsOneWidget);
      for (final label in ['Skip this version', 'Later', 'Update']) {
        expect(button(label), findsOneWidget);
      }
    });

    testWidgets('each step as it happens', (tester) async {
      await show(tester, at(UpdatePhase.downloading));
      expect(find.text('4.2 MB of 10.0 MB · 2.1 MB/s'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(button('Cancel'), findsOneWidget);

      await show(tester, at(UpdatePhase.installing));
      expect(find.text('10.0 MB'), findsOneWidget);
      expect(find.text('SHA-256 matches the signed release'), findsOneWidget);
      expect(find.text('Installing…'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);

      await show(tester, at(UpdatePhase.restart));
      expect(find.textContaining('Restart LecCheck'), findsOneWidget);
      expect(button('Restart'), findsOneWidget);

      // A failure with no step recorded says nothing was installed.
      await show(tester, at(UpdatePhase.failed));
      expect(find.text('SHA-256 matches the signed release'), findsNothing);
      expect(find.textContaining('Restart LecCheck'), findsNothing);

      await show(tester, at(UpdatePhase.failed, failed: UpdateStep.verify));
      expect(
        find.text(
          "The file doesn't match the release, so nothing was installed.",
        ),
        findsOneWidget,
      );
      expect(button('Retry'), findsOneWidget);
    });
  });
}
