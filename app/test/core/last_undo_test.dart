import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/last_undo.dart';

void main() {
  test('undoes the last change only, once', () async {
    final undo = LastUndo();
    final runs = <String>[];
    undo.remember(() => runs.add('first'));
    undo.remember(() => runs.add('second'));

    expect(await undo.undo(), isTrue);
    expect(await undo.undo(), isFalse);
    expect(runs, ['second']);
  });

  test('the snackbar and Ctrl+Z share one undo', () async {
    final undo = LastUndo();
    var runs = 0;
    final snackbar = undo.remember(() => runs++);

    await snackbar();
    expect(await undo.undo(), isFalse);
    expect(runs, 1);

    final late = undo.remember(() => runs++);
    await undo.undo();
    await late();
    expect(runs, 2);
  });

  test('an old snackbar leaves a newer change alone', () async {
    final undo = LastUndo();
    final runs = <String>[];
    final old = undo.remember(() => runs.add('old'));
    undo.remember(() => runs.add('new'));

    await old();
    expect(await undo.undo(), isTrue);
    expect(runs, ['old', 'new']);
  });
}
