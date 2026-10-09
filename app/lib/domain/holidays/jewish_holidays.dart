import 'package:kosher_dart/kosher_dart.dart';

import '../local_date.dart';
import '../schedule_types.dart';

/// The no-class day of a generated holiday: one row per day, with an id every
/// device derives the same way, so applying the same holidays on two devices
/// writes the same rows (like the v1 importer's `_nc_` days).
String holidayRangeId(String semesterId, LocalDate date) =>
    '${holidayIdPrefix(semesterId)}${date.toIso()}';

String holidayIdPrefix(String semesterId) => '${semesterId}_hol_';

/// Whether [range] was added from the holidays sheet (not by hand).
bool isGeneratedHoliday(NoClassRange range) =>
    range.id.startsWith(holidayIdPrefix(range.semesterId));

/// Jewish and Israeli holidays a semester can skip, in calendar order. Each
/// is one choice in the holidays sheet.
enum JewishHoliday {
  roshHashana(preset: true),
  yomKippur(preset: true),
  sukkot(preset: true),
  chanukah(preset: false),
  purim(preset: true),
  shushanPurim(preset: false),
  pesach(preset: true),
  yomHaShoah(preset: false),
  yomHaZikaron(preset: false),
  yomHaAtzmaut(preset: true),
  lagBaOmer(preset: false),
  yomYerushalayim(preset: false),
  shavuot(preset: true),
  tishaBav(preset: false),

  /// Tzom Gedaliah, the 10th of Tevet, Ta'anit Esther and the 17th of Tammuz.
  fasts(preset: false);

  const JewishHoliday({required this.preset});

  /// Usually a day off at Israeli universities: ticked in the preset.
  final bool preset;
}

/// One day of a holiday.
class HolidayDay {
  const HolidayDay(this.date, this.holiday, this.name);

  final LocalDate date;
  final JewishHoliday holiday;

  /// What the day is called, as a key the UI localizes: e.g. `erevPesach`,
  /// `pesach`, `cholHamoedPesach`.
  final String name;

  @override
  String toString() => '$date $name';
}

/// The Jewish and Israeli holidays from [from] to [to] (both included), one
/// entry per day, soonest first. With [inIsrael], festivals last one day and
/// Israel's dates apply; otherwise two-day festivals, as abroad. Israeli
/// national days (Yom HaZikaron, Yom HaAtzmaut…) follow their postponement
/// rules.
List<HolidayDay> jewishHolidays(
  LocalDate from,
  LocalDate to, {
  bool inIsrael = true,
}) {
  final days = <HolidayDay>[];
  for (var date = from; !date.isAfter(to); date = date.addDays(1)) {
    final calendar =
        JewishCalendar.fromDateTime(DateTime(date.year, date.month, date.day))
          ..inIsrael = inIsrael
          ..setUseModernHolidays(true);
    final day = _dayOf(calendar, inIsrael: inIsrael);
    if (day == null) continue;
    // kosher_dart 2.0.20 also reports the 17th of Tammuz on Shabbat, when the
    // fast moves to Sunday (it checks Friday instead of Saturday).
    if (day.$2 == 'seventeenTammuz' && date.weekday == DateTime.saturday) {
      continue;
    }
    days.add(HolidayDay(date, day.$1, day.$2));
  }
  return days;
}

(JewishHoliday, String)? _dayOf(JewishCalendar c, {required bool inIsrael}) {
  // Before the index: a Chanukah day can also be Rosh Chodesh.
  if (c.isChanukah()) return (JewishHoliday.chanukah, 'chanukah');
  return switch (c.getYomTovIndex()) {
    JewishCalendar.EREV_ROSH_HASHANA => (
      JewishHoliday.roshHashana,
      'erevRoshHashana',
    ),
    JewishCalendar.ROSH_HASHANA => (JewishHoliday.roshHashana, 'roshHashana'),
    JewishCalendar.FAST_OF_GEDALYAH => (JewishHoliday.fasts, 'fastOfGedaliah'),
    JewishCalendar.EREV_YOM_KIPPUR => (
      JewishHoliday.yomKippur,
      'erevYomKippur',
    ),
    JewishCalendar.YOM_KIPPUR => (JewishHoliday.yomKippur, 'yomKippur'),
    JewishCalendar.EREV_SUCCOS => (JewishHoliday.sukkot, 'erevSukkot'),
    JewishCalendar.SUCCOS => (JewishHoliday.sukkot, 'sukkot'),
    JewishCalendar.CHOL_HAMOED_SUCCOS => (
      JewishHoliday.sukkot,
      'cholHamoedSukkot',
    ),
    JewishCalendar.HOSHANA_RABBA => (JewishHoliday.sukkot, 'hoshanaRabba'),
    // In Israel both fall on one day.
    JewishCalendar.SHEMINI_ATZERES => (
      JewishHoliday.sukkot,
      inIsrael ? 'sheminiAtzeretSimchatTorah' : 'sheminiAtzeret',
    ),
    JewishCalendar.SIMCHAS_TORAH => (
      JewishHoliday.sukkot,
      inIsrael ? 'sheminiAtzeretSimchatTorah' : 'simchatTorah',
    ),
    JewishCalendar.TENTH_OF_TEVES => (JewishHoliday.fasts, 'tenthOfTevet'),
    JewishCalendar.FAST_OF_ESTHER => (JewishHoliday.fasts, 'fastOfEsther'),
    JewishCalendar.PURIM => (JewishHoliday.purim, 'purim'),
    JewishCalendar.SHUSHAN_PURIM => (
      JewishHoliday.shushanPurim,
      'shushanPurim',
    ),
    JewishCalendar.EREV_PESACH => (JewishHoliday.pesach, 'erevPesach'),
    JewishCalendar.PESACH => (JewishHoliday.pesach, 'pesach'),
    JewishCalendar.CHOL_HAMOED_PESACH => (
      JewishHoliday.pesach,
      'cholHamoedPesach',
    ),
    JewishCalendar.YOM_HASHOAH => (JewishHoliday.yomHaShoah, 'yomHaShoah'),
    JewishCalendar.YOM_HAZIKARON => (
      JewishHoliday.yomHaZikaron,
      'yomHaZikaron',
    ),
    JewishCalendar.YOM_HAATZMAUT => (
      JewishHoliday.yomHaAtzmaut,
      'yomHaAtzmaut',
    ),
    JewishCalendar.LAG_BAOMER => (JewishHoliday.lagBaOmer, 'lagBaOmer'),
    JewishCalendar.YOM_YERUSHALAYIM => (
      JewishHoliday.yomYerushalayim,
      'yomYerushalayim',
    ),
    JewishCalendar.EREV_SHAVUOS => (JewishHoliday.shavuot, 'erevShavuot'),
    JewishCalendar.SHAVUOS => (JewishHoliday.shavuot, 'shavuot'),
    JewishCalendar.SEVENTEEN_OF_TAMMUZ => (
      JewishHoliday.fasts,
      'seventeenTammuz',
    ),
    JewishCalendar.TISHA_BEAV => (JewishHoliday.tishaBav, 'tishaBav'),
    _ => null,
  };
}

/// Each holiday's days, in calendar order.
Map<JewishHoliday, List<HolidayDay>> groupHolidays(List<HolidayDay> days) {
  final groups = <JewishHoliday, List<HolidayDay>>{};
  for (final day in days) {
    (groups[day.holiday] ??= []).add(day);
  }
  return groups;
}

/// The ticks the holidays sheet starts with: the preset when holidays were
/// never applied ([applied] is empty), otherwise what's applied now.
Map<JewishHoliday, bool> initialHolidayTicks(
  Map<JewishHoliday, List<HolidayDay>> groups,
  Map<LocalDate, bool> applied,
) => {
  for (final MapEntry(key: holiday, value: days) in groups.entries)
    holiday: applied.isEmpty ? holiday.preset : _anyOn(days, applied),
};

bool _anyOn(List<HolidayDay> days, Map<LocalDate, bool> applied) =>
    days.any((day) => applied[day.date] ?? false);

/// What applying the holidays sheet writes: the days to add (with their
/// names) and the days to remove.
///
/// Only holidays whose tick changed are touched, so a day removed on its own
/// (Week → Restore classes) stays removed. A [calendarChanged] (Israel ↔
/// abroad) rewrites the ticked holidays, and drops days only the other
/// calendar had. [applied] holds the generated days so far: true while
/// applied, false once removed.
({Map<LocalDate, String> add, Set<LocalDate> remove}) holidayChanges({
  required Map<JewishHoliday, List<HolidayDay>> groups,
  required Map<JewishHoliday, bool> ticked,
  required Map<LocalDate, bool> applied,
  required bool calendarChanged,
  required String Function(HolidayDay day) name,
}) {
  final add = <LocalDate, String>{};
  final remove = <LocalDate>{};
  for (final MapEntry(key: holiday, value: days) in groups.entries) {
    final was = _anyOn(days, applied);
    final on = ticked[holiday] ?? false;
    if (on && (!was || calendarChanged)) {
      for (final day in days) {
        add[day.date] = name(day);
      }
    } else if (!on && was) {
      remove.addAll(days.map((day) => day.date));
    }
  }
  if (calendarChanged) {
    final wanted = {
      for (final MapEntry(key: holiday, value: days) in groups.entries)
        if (ticked[holiday] ?? false) ...days.map((day) => day.date),
    };
    remove.addAll([
      for (final MapEntry(key: date, value: on) in applied.entries)
        if (on && !wanted.contains(date)) date,
    ]);
  }
  remove.removeAll(add.keys);
  return (add: add, remove: remove);
}
