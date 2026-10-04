import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db/app_database.dart';
import '../core/db/schedule_repository.dart';
import '../domain/attendance_stats.dart';
import '../domain/local_date.dart';
import '../domain/occurrence.dart';
import '../domain/occurrence_engine.dart';
import '../domain/requirements.dart';
import '../domain/schedule_types.dart';
import '../domain/semester_calendar.dart';
import '../domain/semester_data.dart';
import 'sync_providers.dart';
import 'theme/colors.dart';

/// A list with value equality, so providers returning lists only notify
/// listeners when the contents actually change.
@immutable
class EqList<T> {
  const EqList(this.items);
  final List<T> items;

  static const _eq = ListEquality<Object?>();

  @override
  bool operator ==(Object other) =>
      other is EqList<T> && _eq.equals(other.items, items);

  @override
  int get hashCode => _eq.hash(items);
}

// ---------------------------------------------------------------- storage --

/// Overridden in `main()` with the instance loaded before `runApp`.
final sharedPrefsProvider = Provider<SharedPreferencesWithCache>(
  (ref) => throw UnimplementedError('sharedPrefsProvider not overridden'),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<ScheduleRepository>((ref) {
  final repo = ScheduleRepository(ref.watch(databaseProvider));
  // Record changes for sync whenever an account is attached to this device.
  ref.listen(
    syncRecorderProvider,
    (_, recorder) => repo.recorder = recorder,
    fireImmediately: true,
  );
  return repo;
});

// ------------------------------------------------------------- appearance --

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.preset = ThemePreset.ocean,
    this.mode = ThemeMode.system,
    this.pureBlack = false,
    this.localeCode,
  });

  final ThemePreset preset;
  final ThemeMode mode;
  final bool pureBlack;

  /// `null` = follow the device.
  final String? localeCode;

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppearanceSettings copyWith({
    ThemePreset? preset,
    ThemeMode? mode,
    bool? pureBlack,
    String? Function()? localeCode,
  }) => AppearanceSettings(
    preset: preset ?? this.preset,
    mode: mode ?? this.mode,
    pureBlack: pureBlack ?? this.pureBlack,
    localeCode: localeCode == null ? this.localeCode : localeCode(),
  );

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.preset == preset &&
      other.mode == mode &&
      other.pureBlack == pureBlack &&
      other.localeCode == localeCode;

  @override
  int get hashCode => Object.hash(preset, mode, pureBlack, localeCode);
}

class AppearanceController extends Notifier<AppearanceSettings> {
  static const _preset = 'appearance.preset';
  static const _mode = 'appearance.mode';
  static const _black = 'appearance.pureBlack';
  static const _locale = 'appearance.locale';

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppearanceSettings build() => AppearanceSettings(
    preset: ThemePreset.fromName(_prefs.getString(_preset)),
    mode: ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_mode),
      orElse: () => ThemeMode.system,
    ),
    pureBlack: _prefs.getBool(_black) ?? false,
    localeCode: _prefs.getString(_locale),
  );

  void setPreset(ThemePreset preset) {
    state = state.copyWith(preset: preset);
    _prefs.setString(_preset, preset.name);
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    _prefs.setString(_mode, mode.name);
  }

  void setPureBlack(bool value) {
    state = state.copyWith(pureBlack: value);
    _prefs.setBool(_black, value);
  }

  void setLocale(String? code) {
    state = state.copyWith(localeCode: () => code);
    if (code == null) {
      _prefs.remove(_locale);
    } else {
      _prefs.setString(_locale, code);
    }
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceSettings>(
      AppearanceController.new,
    );

// --------------------------------------------------------------- semester --

final semestersProvider = StreamProvider<List<SemesterInfo>>(
  (ref) => ref.watch(repositoryProvider).watchSemesters(),
);

/// The semester chosen on this device (persisted); may be stale.
class ActiveSemesterController extends Notifier<String?> {
  static const _key = 'semester.active';

  @override
  String? build() => ref.read(sharedPrefsProvider).getString(_key);

  void select(String id) {
    state = id;
    ref.read(sharedPrefsProvider).setString(_key, id);
  }
}

final activeSemesterChoiceProvider =
    NotifierProvider<ActiveSemesterController, String?>(
      ActiveSemesterController.new,
    );

/// The semester the app shows: the chosen one if it still exists, otherwise
/// the most recent.
final currentSemesterIdProvider = Provider<String?>((ref) {
  final chosen = ref.watch(activeSemesterChoiceProvider);
  final semesters = ref.watch(semestersProvider).value ?? const [];
  if (semesters.any((s) => s.id == chosen)) return chosen;
  return semesters.firstOrNull?.id;
});

final semesterDataProvider = StreamProvider<SemesterData?>((ref) {
  final id = ref.watch(currentSemesterIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(repositoryProvider).watchSemesterData(id);
});

final semesterProvider = Provider<SemesterInfo?>(
  (ref) => ref.watch(semesterDataProvider.select((d) => d.value?.semester)),
);

final calendarProvider = Provider<SemesterCalendar?>((ref) {
  final semester = ref.watch(semesterProvider);
  return semester == null ? null : SemesterCalendar(semester);
});

final coursesProvider = Provider<EqList<CourseInfo>>(
  (ref) => EqList(
    ref.watch(semesterDataProvider.select((d) => d.value?.courses)) ?? const [],
  ),
);

final courseProvider = Provider.family<CourseInfo?, String>(
  (ref, id) => ref.watch(
    coursesProvider.select((c) => c.items.firstWhereOrNull((x) => x.id == id)),
  ),
);

final meetingProvider = Provider.family<MeetingRule?, String>(
  (ref, id) =>
      ref.watch(semesterDataProvider.select((d) => d.value?.meeting(id))),
);

final occurrenceIndexProvider = Provider<OccurrenceIndex>((ref) {
  final data = ref.watch(semesterDataProvider).value;
  if (data == null) return OccurrenceIndex.empty;
  return OccurrenceEngine.expand(
    semester: data.semester,
    meetings: data.meetings,
    overrides: data.overrides,
    noClassRanges: data.noClassRanges,
  );
});

final sessionProvider = Provider.family<Occurrence?, String>(
  (ref, id) => ref.watch(occurrenceIndexProvider.select((i) => i.byId[id])),
);

final userPrefsProvider = StreamProvider<UserPrefs>(
  (ref) => ref.watch(repositoryProvider).watchUserPrefs(),
);

// ------------------------------------------------------------------ clock --

/// Wall clock truncated to the minute; ticks on every minute boundary.
final minuteClockProvider = StreamProvider<DateTime>((ref) {
  DateTime truncate(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);
  final controller = StreamController<DateTime>();
  Timer? timer;
  void schedule() {
    final now = DateTime.now();
    controller.add(truncate(now));
    final next = truncate(now).add(const Duration(minutes: 1));
    timer = Timer(next.difference(now), schedule);
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

DateTime _nowOf(Ref ref) =>
    ref.watch(minuteClockProvider).value ?? DateTime.now();

/// Changes once a day.
final todayProvider = Provider<LocalDate>(
  (ref) => LocalDate.fromDateTime(_nowOf(ref)),
);

// ------------------------------------------------------- derived slices --

/// Started sessions still pending, newest first.
final needsMarkingProvider = Provider<EqList<String>>((ref) {
  final index = ref.watch(occurrenceIndexProvider);
  final now = _nowOf(ref);
  return EqList([
    for (final o in AttendanceStats.needsMarking(index.all, now)) o.id,
  ]);
});

final dayIdsProvider = Provider.family<EqList<String>, LocalDate>(
  (ref, day) => EqList([
    for (final o in ref.watch(occurrenceIndexProvider).onDay(day)) o.id,
  ]),
);

/// The session in progress, or else the next one to start (today or later).
final nowNextProvider = Provider<String?>((ref) {
  final index = ref.watch(occurrenceIndexProvider);
  final now = _nowOf(ref);
  final today = LocalDate.fromDateTime(now);
  Occurrence? next;
  for (final o in index.between(today, today.addDays(14))) {
    if (o.isCanceled) continue;
    if (o.isInProgress(now)) return o.id;
    if (!o.hasStarted(now)) {
      next ??= o;
    }
  }
  return next?.id;
});

@immutable
class CourseSummary {
  const CourseSummary({
    required this.present,
    required this.decided,
    required this.nextSessionId,
    required this.requirements,
  });

  final int present;
  final int decided;
  final String? nextSessionId;
  final EqList<RequirementProgress> requirements;

  double? get progress => decided == 0 ? null : present / decided;

  /// The requirement closest to failing, if any.
  RequirementProgress? get worstRequirement => requirements.items.isEmpty
      ? null
      : requirements.items.reduce((a, b) => a.slack <= b.slack ? a : b);

  @override
  bool operator ==(Object other) =>
      other is CourseSummary &&
      other.present == present &&
      other.decided == decided &&
      other.nextSessionId == nextSessionId &&
      other.requirements == requirements;

  @override
  int get hashCode =>
      Object.hash(present, decided, nextSessionId, requirements);
}

final courseSummaryProvider = Provider.family<CourseSummary, String>((
  ref,
  courseId,
) {
  final index = ref.watch(occurrenceIndexProvider);
  final requirements = ref.watch(
    semesterDataProvider.select(
      (d) => EqList(d.value?.requirementsOf(courseId) ?? const []),
    ),
  );
  final now = _nowOf(ref);
  final sessions = index.forCourse(courseId);
  final counts = StatusCounts.of(AttendanceStats.started(sessions, now));
  final next = sessions.firstWhereOrNull(
    (o) => !o.hasStarted(now) && !o.isCanceled,
  );
  return CourseSummary(
    present: counts.present,
    decided: counts.decided,
    nextSessionId: next?.id,
    requirements: EqList([
      for (final r in requirements.items) evaluateRequirement(r, sessions),
    ]),
  );
});
