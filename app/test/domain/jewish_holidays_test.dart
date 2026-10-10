import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/holidays/jewish_holidays.dart';
import 'package:leccheck/domain/local_date.dart';

import 'helpers.dart';

/// Hebcal's titles for the days LecCheck generates. Hebcal is the reference:
/// `fixtures/hebcal_israel_2025_2030.json` comes from its API (Israel, major,
/// minor and modern holidays, minor fasts), 2025–2030.
String? _expected(String title) {
  if (title.startsWith('Rosh Hashana ') && !title.contains('LaBehemot')) {
    return 'roshHashana';
  }
  if (RegExp(r'^Chanukah: [2-8] Candles$').hasMatch(title) ||
      title == 'Chanukah: 8th Day') {
    return 'chanukah';
  }
  if (RegExp(r'^Sukkot I{1,3}V?I? \(CH’’M\)$').hasMatch(title) ||
      RegExp(r'^Sukkot (II|III|IV|V|VI) \(CH’’M\)$').hasMatch(title)) {
    return 'cholHamoedSukkot';
  }
  if (RegExp(r'^Pesach (II|III|IV|V|VI) \(CH’’M\)$').hasMatch(title)) {
    return 'cholHamoedPesach';
  }
  return switch (title) {
    'Erev Rosh Hashana' => 'erevRoshHashana',
    'Tzom Gedaliah' => 'fastOfGedaliah',
    'Erev Yom Kippur' => 'erevYomKippur',
    'Yom Kippur' => 'yomKippur',
    'Erev Sukkot' => 'erevSukkot',
    'Sukkot I' => 'sukkot',
    'Sukkot VII (Hoshana Raba)' => 'hoshanaRabba',
    'Shmini Atzeret' => 'sheminiAtzeretSimchatTorah',
    'Asara B’Tevet' => 'tenthOfTevet',
    'Ta’anit Esther' => 'fastOfEsther',
    'Purim' => 'purim',
    'Shushan Purim' => 'shushanPurim',
    'Erev Pesach' => 'erevPesach',
    'Pesach I' || 'Pesach VII' => 'pesach',
    'Yom HaShoah' => 'yomHaShoah',
    'Yom HaZikaron' => 'yomHaZikaron',
    'Yom HaAtzma’ut' => 'yomHaAtzmaut',
    'Lag BaOmer' => 'lagBaOmer',
    'Yom Yerushalayim' => 'yomYerushalayim',
    'Erev Shavuot' => 'erevShavuot',
    'Shavuot' => 'shavuot',
    'Tzom Tammuz' => 'seventeenTammuz',
    // Postponed from Shabbat: Hebcal lists the fast on Sunday as observed.
    'Tish’a B’Av' || 'Tish’a B’Av (observed)' => 'tishaBav',
    _ => null,
  };
}

void main() {
  test('matches Hebcal in Israel, 2025–2030', () {
    final fixture = jsonDecode(
      File('test/domain/fixtures/hebcal_israel_2025_2030.json')
          .readAsStringSync(),
    ) as List<Object?>;
    final expected = <String, String>{};
    for (final item in fixture.cast<Map<String, Object?>>()) {
      final name = _expected(item['title']! as String);
      if (name != null) expected[item['date']! as String] = name;
    }
    final actual = {
      for (final day in jewishHolidays(d('2025-01-01'), d('2030-12-31')))
        day.date.toIso(): day.name,
    };
    expect(actual, expected);
  });

  test('two-day festivals abroad', () {
    final pesach = jewishHolidays(
      d('2027-04-20'),
      d('2027-05-01'),
      inIsrael: false,
    ).where((day) => day.holiday == JewishHoliday.pesach);
    final israel = jewishHolidays(
      d('2027-04-20'),
      d('2027-05-01'),
    ).where((day) => day.holiday == JewishHoliday.pesach);
    // Erev Pesach + 8 days abroad, + 7 in Israel.
    expect(pesach, hasLength(9));
    expect(israel, hasLength(8));
  });

  test('a semester in the fall: groups in calendar order', () {
    final days = jewishHolidays(d('2026-10-18'), d('2027-01-22'));
    expect(days.map((day) => day.holiday).toSet().toList(), [
      JewishHoliday.chanukah,
      JewishHoliday.fasts,
    ]);
  });

  test('the preset follows the usual days off at Israeli universities', () {
    expect(
      [
        for (final h in JewishHoliday.values)
          if (h.preset) h,
      ],
      [
        JewishHoliday.roshHashana,
        JewishHoliday.yomKippur,
        JewishHoliday.sukkot,
        JewishHoliday.purim,
        JewishHoliday.pesach,
        JewishHoliday.yomHaAtzmaut,
        JewishHoliday.shavuot,
      ],
    );
  });

  group('holidaysForNewRange', () {
    final oldStart = d('2026-10-18');
    final oldEnd = d('2027-01-22');
    // Chanukah ticked by hand, one of its days then restored on its own.
    final chanukah = [
      for (final day in jewishHolidays(oldStart, oldEnd))
        if (day.holiday == JewishHoliday.chanukah) day.date,
    ];
    final applied = {for (final date in chanukah) date: date != chanukah.first};

    test('moving the start earlier adds the preset for the new holidays', () {
      final added = holidaysForNewRange(
        oldStart: oldStart,
        oldEnd: oldEnd,
        newStart: d('2026-09-01'),
        newEnd: oldEnd,
        applied: applied,
      );
      expect(added.map((day) => day.holiday).toSet(), {
        JewishHoliday.roshHashana,
        JewishHoliday.yomKippur,
        JewishHoliday.sukkot,
      });
      // Not the fasts (in the old dates, never ticked), and Chanukah's
      // restored day stays restored.
      expect(added.any((day) => chanukah.contains(day.date)), isFalse);
    });

    test('a semester without holidays gets none', () {
      expect(
        holidaysForNewRange(
          oldStart: oldStart,
          oldEnd: oldEnd,
          newStart: d('2026-09-01'),
          newEnd: oldEnd,
          applied: const {},
        ),
        isEmpty,
      );
    });
  });

  group('holidayChanges', () {
    // The spring semester of 2027: Purim through Shavuot.
    final groups = groupHolidays(
      jewishHolidays(d('2027-03-07'), d('2027-06-25')),
    );
    String name(HolidayDay day) => day.name;
    Set<String> dates(Iterable<HolidayDay> days) =>
        days.map((day) => day.date.toIso()).toSet();
    Set<String> isos(Iterable<Object?> dates) =>
        dates.map((date) => date.toString()).toSet();
    Map<LocalDate, bool> appliedFrom(Map<LocalDate, String> added) =>
        added.map((date, _) => MapEntry(date, true));

    test('the first time, adds the preset', () {
      final ticks = initialHolidayTicks(groups, const {});
      final changes = holidayChanges(
        groups: groups,
        ticked: ticks,
        applied: const {},
        calendarChanged: false,
        name: name,
      );
      expect(isos(changes.add.keys), {
        for (final MapEntry(key: holiday, value: days) in groups.entries)
          if (holiday.preset) ...dates(days),
      });
      expect(changes.add[d('2027-04-21')], 'erevPesach');
      expect(changes.remove, isEmpty);
    });

    test('changes only the holidays whose tick changed', () {
      final first = holidayChanges(
        groups: groups,
        ticked: initialHolidayTicks(groups, const {}),
        applied: const {},
        calendarChanged: false,
        name: name,
      );
      final applied = appliedFrom(first.add);
      // A Pesach day restored on its own (Week → Restore classes).
      applied[d('2027-04-25')] = false;
      final ticks = initialHolidayTicks(groups, applied);
      expect(ticks[JewishHoliday.pesach], isTrue);

      // Nothing changed: nothing written, the restored day stays restored.
      final same = holidayChanges(
        groups: groups,
        ticked: ticks,
        applied: applied,
        calendarChanged: false,
        name: name,
      );
      expect(same.add, isEmpty);
      expect(same.remove, isEmpty);

      // Lag BaOmer on, Purim off.
      final edited = holidayChanges(
        groups: groups,
        ticked: {
          ...ticks,
          JewishHoliday.lagBaOmer: true,
          JewishHoliday.purim: false,
        },
        applied: applied,
        calendarChanged: false,
        name: name,
      );
      expect(isos(edited.add.keys), dates(groups[JewishHoliday.lagBaOmer]!));
      expect(isos(edited.remove), dates(groups[JewishHoliday.purim]!));
    });

    test('switching to abroad adds the second festival days', () {
      final applied = appliedFrom(
        holidayChanges(
          groups: groups,
          ticked: initialHolidayTicks(groups, const {}),
          applied: const {},
          calendarChanged: false,
          name: name,
        ).add,
      );
      final abroad = groupHolidays(
        jewishHolidays(d('2027-03-07'), d('2027-06-25'), inIsrael: false),
      );
      final changes = holidayChanges(
        groups: abroad,
        ticked: initialHolidayTicks(abroad, applied),
        applied: applied,
        calendarChanged: true,
        name: name,
      );
      // The 8th day of Pesach and the 2nd day of Shavuot.
      expect(isos(changes.add.keys).difference(isos(applied.keys)), {
        '2027-04-29',
        '2027-06-12',
      });
      expect(changes.remove, isEmpty);
    });
  });
}
