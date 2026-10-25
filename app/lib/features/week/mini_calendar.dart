import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/semester_calendar.dart';
import '../../l10n/gen/app_localizations.dart';
import 'week_page.dart';

/// A month in the desktop sidebar, like Google Calendar's. Clicking a day
/// shows its week in Week ([onShowDate]). The week Week shows is
/// highlighted, days with sessions have a dot, and no-class days are
/// dimmed, with their name on hover.
class MiniCalendar extends ConsumerStatefulWidget {
  const MiniCalendar({super.key, required this.onShowDate});

  final ValueChanged<LocalDate> onShowDate;

  /// Its height: the month's title, the weekdays, six weeks.
  static const height = 40.0 + 24 + 6 * _cell;
  static const _cell = 30.0;

  @override
  ConsumerState<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends ConsumerState<MiniCalendar> {
  /// The first of the month shown; follows Week until the arrows are used.
  LocalDate? _month;

  static LocalDate _firstOf(LocalDate d) => LocalDate(d.year, d.month, 1);

  void _step(int months) => setState(() {
    final m = _month ?? _firstOf(ref.read(todayProvider));
    final index = m.year * 12 + m.month - 1 + months;
    _month = LocalDate(index ~/ 12, index % 12 + 1, 1);
  });

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(calendarProvider);
    if (calendar == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final shownWeek = ref.watch(shownWeekProvider);
    final weekStart = calendar.semester.weekStart;
    // Follow Week to another month, unless the arrows chose one.
    ref.listen(shownWeekProvider, (_, week) {
      if (week != null) setState(() => _month = _firstOf(week));
    });
    final month = _month ?? _firstOf(shownWeek ?? today);
    final first = startOfWeek(month, weekStart);
    final index = ref.watch(occurrenceIndexProvider);
    final semester = calendar.semester;

    Widget day(LocalDate date) {
      final inMonth = date.month == month.month;
      final isToday = date == today;
      final inSemester = date.isWithin(semester.start, semester.end);
      final noClass = ref.watch(noClassLabelProvider(date));
      final hasClasses = index.onDay(date).any((s) => !s.isCanceled);
      final color = isToday
          ? scheme.onPrimary
          : !inMonth || !inSemester || noClass != null
          ? scheme.onSurfaceVariant.withValues(alpha: inMonth ? 0.6 : 0.35)
          : scheme.onSurface;
      Widget cell = InkResponse(
        radius: MiniCalendar._cell / 2,
        onTap: () => widget.onShowDate(date),
        child: SizedBox.square(
          dimension: MiniCalendar._cell,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isToday)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                '${date.day}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: isToday ? FontWeight.w700 : null,
                ),
              ),
              if (hasClasses && !isToday)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: inMonth ? scheme.primary : scheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      if (noClass != null && noClass.isNotEmpty) {
        cell = Tooltip(message: noClass, child: cell);
      }
      return cell;
    }

    return SizedBox(
      height: MiniCalendar.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fmt.monthYear(month),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: l.previousMonth,
                  onPressed: () => _step(-1),
                  icon: const Icon(LecIcons.chevronStart),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: l.nextMonth,
                  onPressed: () => _step(1),
                  icon: const Icon(LecIcons.chevronEnd),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 24,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        fmt.isoWeekdayNarrow(first.addDays(i).weekday),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var week = 0; week < 6; week++)
            Builder(
              builder: (context) {
                final start = first.addDays(week * 7);
                final shown = start == shownWeek;
                return Container(
                  height: MiniCalendar._cell,
                  decoration: shown
                      ? BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(
                            MiniCalendar._cell / 2,
                          ),
                        )
                      : null,
                  child: Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(child: Center(child: day(start.addDays(i)))),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
