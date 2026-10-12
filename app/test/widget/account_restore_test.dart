import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/format.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/sync_providers.dart';
import 'package:leccheck/core/auth/auth_service.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/features/settings/account_section.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Signed in, without a server.
class _SignedIn extends AuthController {
  int restores = 0;

  @override
  Future<Session?> build() async =>
      const Session(token: 't', userId: 'u1', email: 'me@example.com');

  @override
  Future<int> restoreDeleted() async {
    restores++;
    return 12;
  }
}

void main() {
  Future<_SignedIn> pump(WidgetTester tester, AccountSummary summary) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final auth = _SignedIn();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          syncConfiguredProvider.overrideWithValue(true),
          syncEngineProvider.overrideWithValue(null),
          authProvider.overrideWith(() => auth),
          accountSummaryProvider.overrideWith((_) async => summary),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              FmtScope(fmt: Fmt('en', use24h: true), child: child!),
          home: const Scaffold(
            body: SingleChildScrollView(child: AccountSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('deleted cloud data can be brought back from Account', (
    tester,
  ) async {
    final auth = await pump(
      tester,
      AccountSummary(
        semesters: 0,
        courses: 0,
        trashRows: 12,
        deletedAt: DateTime(2026, 10, 1),
      ),
    );
    expect(find.text('Bring back deleted cloud data'), findsOneWidget);
    expect(find.textContaining('kept until'), findsOneWidget);

    await tester.tap(find.text('Bring back deleted cloud data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bring back'));
    await tester.pumpAndSettle();
    expect(auth.restores, 1);
    expect(find.text('12 items brought back'), findsOneWidget);
  });

  testWidgets('nothing to bring back: no row', (tester) async {
    await pump(tester, const AccountSummary(semesters: 2, courses: 5));
    expect(find.text('Bring back deleted cloud data'), findsNothing);
  });
}
