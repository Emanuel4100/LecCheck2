import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/window_frame.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final calls = <Object?>[];

  setUp(() {
    calls.clear();
    WindowFrameTheme.enabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowFrameTheme.channel, (call) async {
          expect(call.method, 'setDark');
          calls.add(call.arguments);
          return null;
        });
  });
  tearDown(() {
    WindowFrameTheme.enabled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowFrameTheme.channel, null);
  });

  Widget frame(Brightness brightness) =>
      WindowFrameTheme(brightness: brightness, child: const SizedBox());

  testWidgets('the title bar follows the theme, told once per change', (
    tester,
  ) async {
    await tester.pumpWidget(frame(Brightness.light));
    await tester.pumpWidget(frame(Brightness.light));
    await tester.pumpWidget(frame(Brightness.dark));
    await tester.pumpWidget(frame(Brightness.light));
    expect(calls, [false, true, false]);
  });

  testWidgets('no runner channel: the app carries on', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(WindowFrameTheme.channel, null);
    await tester.pumpWidget(frame(Brightness.dark));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('elsewhere nothing is sent', (tester) async {
    WindowFrameTheme.enabled = false;
    await tester.pumpWidget(frame(Brightness.dark));
    expect(calls, isEmpty);
  });
}
