import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/update/update_download.dart';
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
const _file = UpdateFile('https://example.com/a.apk', 'hash', size: 31200000);

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

  testWidgets('Update when it installs here, with its size; else Download', (
    tester,
  ) async {
    await pump(
      tester,
      const UpdateState(update: _update, via: UpdateVia.apk, file: _file),
    );
    expect(find.text('LecCheck 2.0.0-beta.8 is available'), findsOneWidget);
    expect(find.text('31.2 MB download'), findsOneWidget);
    expect(button('Update'), findsOneWidget);
    expect(button('Download'), findsNothing);

    await pump(tester, const UpdateState(update: _update));
    expect(button('Download'), findsOneWidget);
    expect(button('Update'), findsNothing);

    // The Flatpak updates through its portal: no file, no size.
    await pump(
      tester,
      const UpdateState(update: _update, via: UpdateVia.flatpak),
    );
    expect(button('Update'), findsOneWidget);
    expect(find.textContaining('download'), findsNothing);
  });

  testWidgets('Linux builds that can\'t update point to the Flatpak', (
    tester,
  ) async {
    await pump(tester, const UpdateState(update: _update));
    expect(find.textContaining('comes as a Flatpak'), findsOneWidget);
    await pump(
      tester,
      const UpdateState(update: _update, via: UpdateVia.flatpak),
    );
    expect(find.textContaining('comes as a Flatpak'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('install.sh installs get the move card instead', (tester) async {
    await pump(tester, const UpdateState(update: _update, via: UpdateVia.move));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('each step shows its text and buttons', (tester) async {
    UpdateState at(UpdatePhase phase, {UpdateFailure? failure}) => UpdateState(
      update: _update,
      via: UpdateVia.apk,
      file: _file,
      phase: phase,
      received: 42,
      total: 100,
      checked: 50,
      failure: failure,
      failedStep: failure == null ? null : UpdateStep.download,
    );

    await pump(tester, at(UpdatePhase.downloading));
    expect(find.text('Downloading… 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(button('Cancel'), findsOneWidget);
    expect(button('Update'), findsNothing);

    await pump(tester, at(UpdatePhase.verifying));
    expect(find.text('Checking the file…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(button('Cancel'), findsNothing);

    await pump(tester, at(UpdatePhase.downloaded));
    expect(find.textContaining("Android's installer"), findsOneWidget);
    expect(button('Install'), findsOneWidget);

    await pump(tester, at(UpdatePhase.restart));
    expect(find.textContaining('Restart LecCheck'), findsOneWidget);
    expect(button('Restart'), findsOneWidget);

    await pump(tester, at(UpdatePhase.failed, failure: UpdateFailure.network));
    expect(find.textContaining('internet connection'), findsOneWidget);
    expect(button('Open in browser'), findsOneWidget);
    expect(button('Retry'), findsOneWidget);
  });

  testWidgets('Hebrew', (tester) async {
    await pump(
      tester,
      const UpdateState(
        update: _update,
        via: UpdateVia.apk,
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
      await tester.pump(const Duration(seconds: 1));
    }

    UpdateState at(
      UpdatePhase phase, {
      UpdateStep? failed,
      UpdateFailure? failure,
    }) => UpdateState(
      update: _update,
      via: UpdateVia.apk,
      file: _file,
      phase: phase,
      received: 4200000,
      total: 10000000,
      bytesPerSecond: 2100000,
      checked: 5000000,
      failedStep: failed,
      failure: failure,
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
                '- Faster sync, and `install.sh` is [gone](https://x).\n'
                '### Smaller things\n'
                '- A fix.',
          ),
          via: UpdateVia.apk,
          file: _file,
        ),
      );
      expect(find.text('You have 2.0.0-beta.7'), findsOneWidget);
      expect(find.text("What's new in 2.0.0-beta.8"), findsOneWidget);
      // Items joined across their wrapped lines, marks gone, links as text.
      expect(
        find.text(
          'Contacts for each course, with their email.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Faster sync, and install.sh is gone.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Smaller things'), findsOneWidget);
      expect(find.text('31.2 MB download'), findsOneWidget);
      for (final label in ['Skip this version', 'Later', 'Update']) {
        expect(button(label), findsOneWidget);
      }
    });

    test('notes: bold, code and links', () {
      final span = ReleaseNotes.inline(
        'Use **Undo** or `Ctrl+Z` ([help](https://x)).',
        null,
        const TextStyle(fontFamily: 'monospace'),
      );
      final parts = span.children!.cast<TextSpan>();
      expect(parts.map((p) => p.text).join(), 'Use Undo or Ctrl+Z (help).');
      expect(
        parts.firstWhere((p) => p.text == 'Undo').style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        parts.firstWhere((p) => p.text == 'Ctrl+Z').style?.fontFamily,
        'monospace',
      );
    });

    testWidgets('each step as it happens', (tester) async {
      await show(tester, at(UpdatePhase.downloading));
      expect(find.text('4.2 MB of 10.0 MB · 2.1 MB/s'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(button('Cancel'), findsOneWidget);

      await show(tester, at(UpdatePhase.verifying));
      expect(find.text('10.0 MB'), findsOneWidget);
      expect(find.text('5.0 MB of 10.0 MB'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);

      await show(tester, at(UpdatePhase.downloaded));
      expect(find.text('SHA-256 matches the signed release'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Install'), findsOneWidget);

      await show(tester, at(UpdatePhase.restart));
      expect(find.textContaining('Restart LecCheck'), findsOneWidget);
      expect(button('Restart'), findsOneWidget);

      // A failure with no step recorded says nothing was installed.
      await show(tester, at(UpdatePhase.failed));
      expect(find.text('SHA-256 matches the signed release'), findsNothing);
      expect(find.textContaining('Restart LecCheck'), findsNothing);

      await show(
        tester,
        at(
          UpdatePhase.failed,
          failed: UpdateStep.verify,
          failure: UpdateFailure.notVerified,
        ),
      );
      expect(
        find.textContaining("doesn't match the signed release"),
        findsOneWidget,
      );
      expect(button('Retry'), findsOneWidget);

      await show(
        tester,
        at(
          UpdatePhase.failed,
          failed: UpdateStep.download,
          failure: UpdateFailure.space,
        ),
      );
      expect(find.textContaining("isn't enough space"), findsOneWidget);
    });

    group('Flatpak', () {
      UpdateState flatpak(
        UpdatePhase phase, {
        double? progress,
        UpdateFailure? failure,
        String? error,
      }) => UpdateState(
        update: _update,
        via: UpdateVia.flatpak,
        phase: phase,
        portalProgress: progress,
        failedStep: failure == null ? null : UpdateStep.download,
        failure: failure,
        error: error,
      );

      testWidgets('the portal does the work; Flatpak verifies', (tester) async {
        await show(tester, flatpak(UpdatePhase.idle));
        expect(find.textContaining('Updates come through Flatpak'), findsOne);

        await show(tester, flatpak(UpdatePhase.downloading, progress: 0.4));
        expect(find.text('40%'), findsOneWidget);
        expect(find.text('Flatpak downloads and installs it'), findsOneWidget);

        await show(tester, flatpak(UpdatePhase.restart, progress: 1));
        expect(
          find.text('Verified by Flatpak: the repository is signed'),
          findsOneWidget,
        );
        expect(button('Restart'), findsOneWidget);
      });

      testWidgets('what to do when Flatpak won\'t install it', (tester) async {
        await show(
          tester,
          flatpak(UpdatePhase.failed, failure: UpdateFailure.flatpakDenied),
        );
        expect(find.textContaining('Deny was chosen'), findsOneWidget);
        const allow =
            'flatpak permission-set flatpak updates com.leccheck.app yes';
        expect(find.text(allow), findsOneWidget);
        // Nothing to download in the browser.
        expect(button('Open in browser'), findsNothing);

        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        await tester.tap(find.byTooltip('Copy command'));
        expect(copied, [allow]);

        await show(
          tester,
          flatpak(
            UpdatePhase.failed,
            failure: UpdateFailure.flatpakPermissions,
          ),
        );
        expect(find.text('flatpak update com.leccheck.app'), findsOneWidget);

        await show(
          tester,
          flatpak(
            UpdatePhase.failed,
            failure: UpdateFailure.flatpak,
            error: 'Remote "leccheck" not found',
          ),
        );
        expect(find.text("Flatpak couldn't install the update."), findsOne);
        expect(find.text('Remote "leccheck" not found'), findsOneWidget);
      });
    });
  });
}
