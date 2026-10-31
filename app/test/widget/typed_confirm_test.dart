import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/adaptive.dart';
import 'package:leccheck/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<List<bool>> open(WidgetTester tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(
              await confirmTypedDialog(
                context,
                title: 'Sure?',
                body: 'Really.',
                words: const ['DELETE'],
                confirmLabel: 'Delete',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  FilledButton button(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Delete'));

  testWidgets('confirms only once the word is typed', (tester) async {
    final answers = await open(tester);
    expect(button(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pump();
    expect(button(tester).onPressed, isNull, reason: 'exactly the word');

    await tester.enterText(find.byType(TextField), ' DELETE ');
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('Cancel is a no', (tester) async {
    final answers = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });
}
