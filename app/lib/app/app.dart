import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/gen/app_localizations.dart';
import 'format.dart';
import 'providers.dart';
import 'router.dart';
import 'sync_providers.dart';
import 'theme/app_theme.dart';

class LecCheckApp extends ConsumerWidget {
  const LecCheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    // Keeps the sync engine alive while signed in.
    ref.watch(syncEngineProvider);
    final router = ref.watch(routerProvider);
    final use24h = ref.watch(userPrefsProvider.select((p) => p.value?.use24h));

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: 'LecCheck',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppTheme.build(
          preset: appearance.preset,
          brightness: Brightness.light,
          wallpaperScheme: lightDynamic?.harmonized(),
        ),
        darkTheme: AppTheme.build(
          preset: appearance.preset,
          brightness: Brightness.dark,
          wallpaperScheme: darkDynamic?.harmonized(),
          pureBlack: appearance.pureBlack,
        ),
        themeMode: appearance.mode,
        themeAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        ),
        locale: appearance.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: (context, child) => FmtScope(
          fmt: Fmt(
            Localizations.localeOf(context).toLanguageTag(),
            use24h: use24h ?? MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          // fl_chart still uses package:flutter/material; the bridge lets its
          // widgets resolve our material_ui theme until it migrates.
          // ignore: deprecated_member_use
          child: MaterialUiCompatibilityBridge(child: child!),
        ),
      ),
    );
  }
}
