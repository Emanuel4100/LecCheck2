/// A calendar date without time or timezone.
///
/// All arithmetic runs on UTC midnights, so daylight-saving transitions can
/// never duplicate or skip a day (v1 stepped local midnights with
/// `add(Duration(days: 1))`, which broke on the October fall-back).
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate(dt.year, dt.month, dt.day);

  factory LocalDate.today([DateTime? now]) =>
      LocalDate.fromDateTime(now ?? DateTime.now());

  factory LocalDate.fromEpochDay(int epochDay) {
    final d = DateTime.fromMillisecondsSinceEpoch(
      epochDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return LocalDate(d.year, d.month, d.day);
  }

  /// Parses `yyyy-MM-dd`.
  factory LocalDate.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Expected yyyy-MM-dd', iso);
    }
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static LocalDate? tryParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return LocalDate.parse(iso);
    } on FormatException {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// Days since 1970-01-01. Stable integer key for maps and comparisons.
  int get epochDay =>
      _utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  /// `yyyymmdd` as an int, used in deterministic session ids.
  int get compactKey => year * 10000 + month * 100 + day;

  LocalDate addDays(int days) {
    final d = _utc.add(Duration(days: days));
    return LocalDate(d.year, d.month, d.day);
  }

  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  /// Local wall-clock time on this date, [minutes] after midnight.
  DateTime at(int minutes) =>
      DateTime(year, month, day, minutes ~/ 60, minutes % 60);

  bool isBefore(LocalDate other) => epochDay < other.epochDay;
  bool isAfter(LocalDate other) => epochDay > other.epochDay;

  /// Inclusive range check.
  bool isWithin(LocalDate start, LocalDate end) =>
      epochDay >= start.epochDay && epochDay <= end.epochDay;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => epochDay;

  @override
  String toString() => toIso();
}

LocalDate maxDate(LocalDate a, LocalDate b) => a.isAfter(b) ? a : b;
LocalDate minDate(LocalDate a, LocalDate b) => a.isBefore(b) ? a : b;
