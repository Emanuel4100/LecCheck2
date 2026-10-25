import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/format.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/sync/sync_engine.dart';
import 'package:leccheck/core/sync/sync_recorder.dart';
import 'package:leccheck/features/settings/account_section.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _SignedIn extends AuthController {
  @override
  Future<Session?> build() async =>
      const Session(token: 't', userId: 'u1', email: 'me@example.com');
}

/// Never connects; "Sync now" answers when the test says.
class _Engine extends SyncEngine {
  _Engine(AppDatabase db, SharedPreferencesWithCache prefs)
    : super(
        db: db,
        repo: ScheduleRepository(db),
        recorder: SyncRecorder(db: db, prefs: prefs),
        session: const Session(token: 't', userId: 'u1'),
        watchLifecycle: false,
      );

  Completer<bool> answer = Completer();
  int asked = 0;

  @override
  Future<bool> syncNow({Duration timeout = const Duration(seconds: 10)}) {
    asked++;
    return answer.future;
  }
}

void main() {
  late _Engine engine;

  Future<void> pump(WidgetTester tester, {bool reduceMotion = false}) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    engine = _Engine(db, prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          syncConfiguredProvider.overrideWithValue(true),
          authProvider.overrideWith(_SignedIn.new),
          syncEngineProvider.overrideWithValue(engine),
          syncStateProvider.overrideWith(
            (_) => Stream.value(
              SyncState(SyncPhase.synced, lastSyncedAt: DateTime.now()),
            ),
          ),
          accountSummaryProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: FmtScope(fmt: Fmt('en', use24h: true), child: child!),
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: AccountSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder turning() => find.descendant(
    of: find.byType(SyncGlyph),
    matching: find.byType(RotationTransition),
  );

  testWidgets('Sync now spins, then says it is up to date', (tester) async {
    await pump(tester);
    expect(find.text('Synced just now'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pump();
    expect(engine.asked, 1);
    expect(find.text('Syncing…'), findsOneWidget);
    expect(turning(), findsOneWidget);
    // Pressing again while it runs does nothing.
    await tester.tap(find.text('Sync now'));
    expect(engine.asked, 1);

    // A quick answer still spins for a moment.
    engine.answer.complete(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Syncing…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Up to date'), findsOneWidget);
    expect(turning(), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Synced just now'), findsOneWidget);
  });

  testWidgets('no answer says so, and keeps the changes', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sync now'));
    engine.answer.complete(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text("Couldn't sync right now. Your changes are kept."),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion nothing turns', (tester) async {
    await pump(tester, reduceMotion: true);
    await tester.tap(find.text('Sync now'));
    await tester.pump();
    expect(find.text('Syncing…'), findsOneWidget);
    expect(turning(), findsNothing);
    engine.answer.complete(true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
