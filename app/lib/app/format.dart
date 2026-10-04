import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/local_date.dart';
import '../l10n/gen/app_localizations.dart';

/// Date/time formatting for the current locale and 24h preference.
///
/// Created once per locale/preference change (see [FmtScope]); every
/// [DateFormat] is built lazily and reused — v1 created formatters on every
/// call inside build methods.
class Fmt {
  Fmt(this.locale, {required this.use24h});

  final String locale;
  final bool use24h;

  late final DateFormat _time = use24h
      ? DateFormat.Hm(locale)
      : DateFormat.jm(locale);
  late final DateFormat _dayMonth = DateFormat.MMMd(locale);
  late final DateFormat _weekdayDayMonth = DateFormat.MMMEd(locale);
  late final DateFormat _fullWeekday = DateFormat.EEEE(locale);
  late final DateFormat _shortWeekday = DateFormat.E(locale);
  late final DateFormat _numericDayMonth = DateFormat.Md(locale);
  late final DateFormat _yearMonthDay = DateFormat.yMMMd(locale);
  late final DateFormat _longDate = DateFormat.MMMMEEEEd(locale);

  String time(int minutes) =>
      _time.format(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

  /// e.g. "10:00–11:30". Wrapped in LTR isolates so it reads correctly
  /// inside Hebrew text.
  String timeRange(int start, int end) =>
      '\u2066${_unbreakable(time(start))}\u2060–\u2060${_unbreakable(time(end))}\u2069';

  /// Hour label for grid rows: "9 AM" / "09:00".
  String hourLabel(int hour) => use24h
      ? '${hour.toString().padLeft(2, '0')}:00'
      : _hour.format(DateTime(2000, 1, 1, hour));

  late final DateFormat _hour = DateFormat.j(locale);

  static String _unbreakable(String s) => s.replaceAll(' ', '\u00A0');

  String dayMonth(LocalDate d) => _dayMonth.format(_dt(d));
  String weekdayDayMonth(LocalDate d) => _weekdayDayMonth.format(_dt(d));
  String longDate(LocalDate d) => _longDate.format(_dt(d));
  String yearMonthDay(LocalDate d) => _yearMonthDay.format(_dt(d));
  String numericDayMonth(LocalDate d) => _numericDayMonth.format(_dt(d));
  String weekdayName(LocalDate d) => _fullWeekday.format(_dt(d));
  String weekdayShort(LocalDate d) => _shortWeekday.format(_dt(d));

  /// Short name of an ISO weekday (1 = Monday … 7 = Sunday).
  String isoWeekdayShort(int weekday) => _shortWeekday.format(
    DateTime(2024, 1, weekday),
  ); // 2024-01-01 is a Monday

  String isoWeekdayName(int weekday) =>
      _fullWeekday.format(DateTime(2024, 1, weekday));

  /// "Today", "Tomorrow", "Yesterday" or a weekday + date.
  String relativeDay(LocalDate d, LocalDate today, AppLocalizations l) {
    final diff = today.daysUntil(d);
    if (diff == 0) return l.today;
    if (diff == 1) return l.tomorrow;
    if (diff == -1) return l.yesterday;
    return weekdayDayMonth(d);
  }

  static DateTime _dt(LocalDate d) => DateTime(d.year, d.month, d.day);

  static Fmt of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FmtScope>()!.fmt;
}

String formatDuration(Duration d, AppLocalizations l) {
  final totalMinutes = d.inMinutes < 1 ? 1 : d.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return l.durationMinutes(minutes);
  if (minutes == 0) return l.durationHours(hours);
  return l.durationHoursMinutes(hours, minutes);
}

class FmtScope extends InheritedWidget {
  const FmtScope({super.key, required this.fmt, required super.child});

  final Fmt fmt;

  @override
  bool updateShouldNotify(FmtScope oldWidget) =>
      oldWidget.fmt.locale != fmt.locale || oldWidget.fmt.use24h != fmt.use24h;
}
