import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';

/// The steps of the app tour (issue #1), in order.
enum TourStep { welcome, today, week, courses, stats, settings, add }

/// What the tour points at. Each key sits on one widget at a time: the
/// navigation items exist either in the bottom bar or in the rail, Settings
/// is the gear in Today's app bar (phones) or in the rail, and the Add
/// buttons differ by layout and by whether there are courses.
abstract final class TourTargets {
  static final today = GlobalKey(debugLabel: 'tour.today');
  static final week = GlobalKey(debugLabel: 'tour.week');
  static final courses = GlobalKey(debugLabel: 'tour.courses');
  static final stats = GlobalKey(debugLabel: 'tour.stats');
  static final settings = GlobalKey(debugLabel: 'tour.settings');

  /// Today's "Add course" while there are no courses.
  static final addFirst = GlobalKey(debugLabel: 'tour.addFirst');

  /// The rail's Add button (wider windows).
  static final addRail = GlobalKey(debugLabel: 'tour.addRail');

  /// The Courses tab's Add button (phones, once there are courses).
  static final addFab = GlobalKey(debugLabel: 'tour.addFab');

  static List<GlobalKey> get destinations => [today, week, courses, stats];
}

/// Shows the tour: once after the first semester is set up, and whenever
/// Settings → About asks. The step is null while no tour runs.
class TourController extends Notifier<TourStep?> {
  static const doneKey = 'tour.done';

  @override
  TourStep? build() => null;

  void start() => state = TourStep.values.first;

  /// After setting up the first semester: once per device.
  void startFirstTime() {
    if (!(ref.read(sharedPrefsProvider).getBool(doneKey) ?? false)) start();
  }

  void next() {
    final step = state;
    if (step == null) return;
    if (step == TourStep.values.last) return finish();
    state = TourStep.values[step.index + 1];
  }

  void back() {
    final step = state;
    if (step == null || step.index == 0) return;
    state = TourStep.values[step.index - 1];
  }

  /// Done or Skip: it doesn't start by itself again.
  void finish() {
    state = null;
    ref.read(sharedPrefsProvider).setBool(doneKey, true);
  }
}

final tourProvider = NotifierProvider<TourController, TourStep?>(
  TourController.new,
);
