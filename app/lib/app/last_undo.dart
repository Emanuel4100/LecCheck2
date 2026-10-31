import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The last change that offered Undo, for Ctrl+Z on Week. One step only.
class LastUndo {
  Future<void> Function()? _action;

  /// Makes [action] the one Ctrl+Z undoes. Returns what a snackbar's Undo
  /// calls: both share it, and it only runs once.
  Future<void> Function() remember(FutureOr<void> Function() action) {
    var done = false;
    late final Future<void> Function() once;
    once = () async {
      if (identical(_action, once)) _action = null;
      if (done) return;
      done = true;
      await action();
    };
    return _action = once;
  }

  /// Undoes the remembered change. False when there's none.
  Future<bool> undo() async {
    final action = _action;
    if (action == null) return false;
    await action();
    return true;
  }
}

final lastUndoProvider = Provider<LastUndo>((ref) => LastUndo());
