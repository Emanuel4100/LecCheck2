import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/domain/local_date.dart';

void main() {
  test('parses and formats yyyy-MM-dd', () {
    final date = LocalDate.parse('2026-10-25');
    expect(date, const LocalDate(2026, 10, 25));
    expect(date.toIso(), '2026-10-25');
    expect(LocalDate.tryParse('nope'), isNull);
    expect(LocalDate.tryParse(null), isNull);
  });

  test('ISO weekdays', () {
    expect(LocalDate.parse('2026-10-18').weekday, DateTime.sunday);
    expect(LocalDate.parse('2026-10-19').weekday, DateTime.monday);
  });

  test('day stepping is immune to daylight-saving transitions', () {
    // Israel: fall-back on Sun 2026-10-25, spring-forward on Fri 2027-03-26.
    for (final start in ['2026-10-20', '2027-03-22']) {
      var day = LocalDate.parse(start);
      final seen = <String>{};
      for (var i = 0; i < 10; i++) {
        final next = day.addDays(1);
        expect(day.daysUntil(next), 1);
        expect(seen.add(next.toIso()), isTrue, reason: 'duplicate $next');
        day = next;
      }
    }
  });

  test('epoch day round-trips and orders dates', () {
    final date = LocalDate.parse('2027-01-01');
    expect(LocalDate.fromEpochDay(date.epochDay), date);
    expect(date.isAfter(LocalDate.parse('2026-12-31')), isTrue);
    expect(date.isWithin(LocalDate.parse('2027-01-01'), date), isTrue);
    expect(date.compactKey, 20270101);
  });

  test('at() builds the local wall-clock time', () {
    final dt = LocalDate.parse('2026-10-25').at(10 * 60 + 30);
    expect(
      (dt.year, dt.month, dt.day, dt.hour, dt.minute),
      (2026, 10, 25, 10, 30),
    );
  });
}
