import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/domain/local_date.dart';

void main() {
  testWidgets('the clock catches up when the app comes back', (tester) async {
    var now = DateTime(2026, 11, 16, 23, 58, 30);
    final container = ProviderContainer(
      overrides: [wallClockProvider.overrideWithValue(() => now)],
    );
    final today = <LocalDate>[];
    container.listen(
      todayProvider,
      (_, next) => today.add(next),
      fireImmediately: true,
    );
    await tester.pump();
    expect(today.last, LocalDate(2026, 11, 16));

    // A night asleep: no timer fired, the wall clock moved on.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 11, 17, 7, 30, 10);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Riverpod hands the new value on after a zero-length timer.
    await tester.pump(const Duration(milliseconds: 1));

    expect(today.last, LocalDate(2026, 11, 17));
    expect(
      container.read(minuteClockProvider).value,
      DateTime(2026, 11, 17, 7, 30),
    );
    // Stops the minute timer before the test ends.
    container.dispose();
  });
}
