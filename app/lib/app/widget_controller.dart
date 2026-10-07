import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/home_widget/today_widget.dart';
import '../l10n/gen/app_localizations.dart';
import 'format.dart';
import 'providers.dart';

/// Keeps the Android home-screen widget's snapshot current while the app
/// runs (the widget itself only renders what was last written).
class WidgetController {
  WidgetController(this.container);

  /// The one `main` started (Settings → Developer refreshes with it).
  static WidgetController? current;

  final ProviderContainer container;
  Timer? _debounce;

  Future<void> start() async {
    if (!TodayWidget.supported) return;
    current = this;
    await TodayWidget.registerCallback();
    void refresh(Object? _, Object? _) => schedule();
    container
      ..listen(occurrenceIndexProvider, refresh)
      ..listen(semesterDataProvider, refresh)
      ..listen(userPrefsProvider, refresh)
      ..listen(appearanceProvider, refresh)
      ..listen(todayProvider, refresh);
    schedule();
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), _push);
  }

  /// Writes the widget's snapshot right away.
  Future<void> refreshNow() {
    _debounce?.cancel();
    return _push();
  }

  Future<void> _push() async {
    final data = container.read(semesterDataProvider).value;
    if (data == null) return;
    final code =
        container.read(appearanceProvider).localeCode ??
        PlatformDispatcher.instance.locale.languageCode;
    final l = lookupAppLocalizations(Locale(code == 'he' ? 'he' : 'en'));
    final prefs = container.read(userPrefsProvider).value;
    await TodayWidget.push(
      TodayWidget.snapshot(
        data: data,
        index: container.read(occurrenceIndexProvider),
        now: DateTime.now(),
        l: l,
        fmt: Fmt(
          l.localeName,
          use24h:
              prefs?.use24h ??
              PlatformDispatcher.instance.alwaysUse24HourFormat,
        ),
        numbers: prefs?.meetingNumbers ?? true,
      ),
    );
  }
}
