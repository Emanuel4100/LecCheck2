import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/format.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final he = lookupAppLocalizations(const Locale('he'));

  test('a countdown has hours and minutes below a day, then days', () {
    String text(Duration d) => formatCountdown(d, en);
    expect(text(const Duration(minutes: 5)), '5m');
    expect(text(const Duration(hours: 23, minutes: 59)), '23h 59m');
    expect(text(const Duration(hours: 24)), '1d');
    expect(text(const Duration(hours: 30, minutes: 40)), '1d 6h');
    expect(text(const Duration(days: 3)), '3d');
  });

  test('in Hebrew too', () {
    expect(formatCountdown(const Duration(hours: 30), he), '1 י׳ 6 ש׳');
  });
}
