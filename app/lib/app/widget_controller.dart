import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/home_widget/today_widget.dart';
import '../domain/local_date.dart';
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
  StreamSubscription<void>? _changes;

  Future<void> start() async {
    if (!TodayWidget.supported) return;
    current = this;
    await TodayWidget.registerCallback();
    void refresh(Object? _, Object? _) => schedule();
    // Any semester's data: the widget shows every semester running today.
    _changes = container
        .read(repositoryProvider)
        .watchAnyChange()
        .listen((_) => schedule());
    container
      ..listen(userPrefsProvider, refresh)
      ..listen(appearanceProvider, refresh)
      ..listen(todayProvider, refresh);
    schedule();
  }

  void dispose() {
    _debounce?.cancel();
    _changes?.cancel();
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
    final now = DateTime.now();
    final today = LocalDate.fromDateTime(now);
    final window = await container
        .read(repositoryProvider)
        .loadWindow(today, today.addDays(TodayWidget.days - 1));
    final code =
        container.read(appearanceProvider).localeCode ??
        PlatformDispatcher.instance.locale.languageCode;
    final l = lookupAppLocalizations(Locale(code == 'he' ? 'he' : 'en'));
    final prefs = container.read(userPrefsProvider).value;
    await TodayWidget.push(
      TodayWidget.snapshot(
        window: window,
        now: now,
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
