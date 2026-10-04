import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../core/db/schedule_repository.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_sheet.dart';
import '../settings/account_section.dart';
import '../session/session_tile.dart';
import '../session/status_buttons.dart';

/// First and last hour shown in the grid, fitted to the semester's sessions.
final hourRangeProvider = Provider<(int, int)>((ref) {
  final index = ref.watch(occurrenceIndexProvider);
  if (index.all.isEmpty) return (8, 18);
  var minStart = 24 * 60;
  var maxEnd = 0;
  for (final o in index.all) {
    minStart = math.min(minStart, o.startMin);
    maxEnd = math.max(maxEnd, o.endMin);
  }
  final start = (minStart ~/ 60).clamp(0, 23);
  final end = ((maxEnd + 59) ~/ 60).clamp(start + 1, 24);
  return (start, end);
});

class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({super.key});

  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  PageController? _controller;
  int _page = 0;
  double _hourHeight = 60;

  // Two-finger pinch tracked from raw pointers so it never competes with the
  // page swipe or the vertical scroll in the gesture arena.
  final _pointers = <int, Offset>{};
  double? _pinchStart;
  double _pinchHeight = 60;

  double get _pinchDistance {
    final p = _pointers.values.toList();
    return (p[0] - p[1]).distance;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _weekCount(SemesterCalendar calendar) {
    final last = ref.read(occurrenceIndexProvider).lastDate;
    final lastWeek = last == null ? 0 : calendar.weekNumberOf(last);
    return math.max(1, math.max(calendar.weekCount, lastWeek));
  }

  void _goToWeek(int week) {
    _controller?.animateToPage(
      week - 1,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(calendarProvider);
    ref.watch(occurrenceIndexProvider);
    if (calendar == null) return const Scaffold();
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final today = ref.watch(todayProvider);
    final weekCount = _weekCount(calendar);
    final currentWeek = calendar.weekNumberOf(today).clamp(1, weekCount);
    if (_controller == null) {
      _page = currentWeek - 1;
      _controller = PageController(initialPage: _page);
    }
    final shownWeek = _page + 1;
    final weekStart = calendar.weekStartOf(shownWeek);
    final compact = WindowSize.of(context) == WindowSize.compact;
    final motion = AppMotion.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: motion.medium,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(shownWeek),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.weekNumber(shownWeek)),
              Text(
                '${fmt.dayMonth(weekStart)} – ${fmt.dayMonth(weekStart.addDays(6))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          if (shownWeek != currentWeek)
            IconButton(
              tooltip: l.goToToday,
              icon: const Icon(LecIcons.today),
              onPressed: () => _goToWeek(currentWeek),
            ),
          IconButton(
            tooltip: l.jumpToDate,
            icon: const Icon(LecIcons.date),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(today.year, today.month, today.day),
                firstDate: DateTime(2020),
                lastDate: DateTime(2040),
              );
              if (picked == null) return;
              final week = calendar.weekNumberOf(
                LocalDate.fromDateTime(picked),
              );
              _goToWeek(week.clamp(1, weekCount));
            },
          ),
          const SyncIndicator(),
          if (compact)
            IconButton(
              tooltip: l.settings,
              icon: const Icon(LecIcons.settings),
              onPressed: () => context.push('/settings'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Listener(
        onPointerDown: (e) {
          _pointers[e.pointer] = e.position;
          if (_pointers.length == 2) {
            _pinchStart = _pinchDistance;
            _pinchHeight = _hourHeight;
          }
        },
        onPointerMove: (e) {
          if (!_pointers.containsKey(e.pointer)) return;
          _pointers[e.pointer] = e.position;
          final start = _pinchStart;
          if (_pointers.length == 2 && start != null && start > 0) {
            setState(
              () => _hourHeight = (_pinchHeight * _pinchDistance / start).clamp(
                36.0,
                140.0,
              ),
            );
          }
        },
        onPointerUp: (e) => _release(e.pointer),
        onPointerCancel: (e) => _release(e.pointer),
        child: PageView.builder(
          controller: _controller,
          itemCount: weekCount,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => _WeekGrid(
            weekStart: calendar.weekStartOf(i + 1),
            hourHeight: _hourHeight,
          ),
        ),
      ),
    );
  }

  void _release(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2) _pinchStart = null;
  }
}

const _timeColumnWidth = 48.0;
const _headerHeight = 56.0;

class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({required this.weekStart, required this.hourHeight});

  final LocalDate weekStart;
  final double hourHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(calendarProvider)!;
    final (startHour, endHour) = ref.watch(hourRangeProvider);
    final today = ref.watch(todayProvider);
    final dates = calendar.visibleDatesOfWeek(weekStart);
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final height = (endHour - startHour) * hourHeight;
    final todayIndex = dates.indexOf(today);

    return Column(
      children: [
        SizedBox(
          height: _headerHeight,
          child: Row(
            children: [
              const SizedBox(width: _timeColumnWidth),
              for (final date in dates)
                Expanded(
                  child: _DayHeader(date: date, isToday: date == today),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              height: height + 16,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _timeColumnWidth,
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var h = startHour; h < endHour; h++)
                            PositionedDirectional(
                              top: (h - startHour) * hourHeight - 7,
                              start: 0,
                              end: 6,
                              child: Text(
                                fmt.hourLabel(h),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _GridPainter(
                            hours: endHour - startHour,
                            hourHeight: hourHeight,
                            columns: dates.length,
                            todayColumn: todayIndex,
                            line: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                            todayTint: theme.colorScheme.primary.withValues(
                              alpha: 0.05,
                            ),
                            rtl:
                                Directionality.of(context) == TextDirection.rtl,
                          ),
                          child: Row(
                            children: [
                              for (final date in dates)
                                Expanded(
                                  child: _DayColumn(
                                    date: date,
                                    startHour: startHour,
                                    hourHeight: hourHeight,
                                    height: height,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader({required this.date, required this.isToday});

  final LocalDate date;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final noClass = ref.watch(
      semesterDataProvider.select(
        (d) => d.value?.noClassRanges.any((r) => r.contains(date)) ?? false,
      ),
    );
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showDayOptions(context, ref, date),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fmt.weekdayShort(date),
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? scheme.primary : null,
              shape: BoxShape.circle,
            ),
            child: noClass
                ? Icon(
                    LecIcons.holiday,
                    size: 16,
                    color: isToday ? scheme.onPrimary : scheme.tertiary,
                  )
                : Text(
                    '${date.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: isToday ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Placed {
  _Placed(this.session);
  final Occurrence session;
  int lane = 0;
  int lanes = 1;
}

/// Greedy interval layout: overlapping sessions share the column side by side.
List<_Placed> _layoutDay(List<Occurrence> sessions) {
  final sorted = [...sessions]
    ..sort((a, b) {
      final c = a.startMin.compareTo(b.startMin);
      return c != 0 ? c : b.endMin.compareTo(a.endMin);
    });
  final placed = <_Placed>[];
  var cluster = <_Placed>[];
  var laneEnds = <int>[];
  var clusterEnd = -1;

  void closeCluster() {
    for (final p in cluster) {
      p.lanes = laneEnds.length;
    }
    cluster = [];
    laneEnds = [];
  }

  for (final s in sorted) {
    if (s.startMin >= clusterEnd) {
      closeCluster();
      clusterEnd = s.endMin;
    } else {
      clusterEnd = math.max(clusterEnd, s.endMin);
    }
    final p = _Placed(s);
    final free = laneEnds.indexWhere((end) => end <= s.startMin);
    if (free == -1) {
      p.lane = laneEnds.length;
      laneEnds.add(s.endMin);
    } else {
      p.lane = free;
      laneEnds[free] = s.endMin;
    }
    cluster.add(p);
    placed.add(p);
  }
  closeCluster();
  return placed;
}

class _DayColumn extends ConsumerWidget {
  const _DayColumn({
    required this.date,
    required this.startHour,
    required this.hourHeight,
    required this.height,
  });

  final LocalDate date;
  final int startHour;
  final double hourHeight;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(dayIdsProvider(date)).items;
    final index = ref.read(occurrenceIndexProvider);
    final sessions = [for (final id in ids) ?index.byId[id]];
    final today = ref.watch(todayProvider);
    final placed = _layoutDay(sessions);
    double y(int minutes) => (minutes - startHour * 60) / 60 * hourHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final p in placed)
                PositionedDirectional(
                  key: ValueKey(p.session.id),
                  top: y(p.session.startMin).clamp(0, height - 20),
                  height: math.max(
                    22,
                    y(p.session.endMin) -
                        y(p.session.startMin).clamp(0, height) -
                        2,
                  ),
                  start: 2 + p.lane * (width - 4) / p.lanes,
                  width: (width - 4) / p.lanes - 2,
                  child: _GridTile(sessionId: p.session.id),
                ),
              if (date == today)
                _NowLine(startHour: startHour, hourHeight: hourHeight),
            ],
          ),
        );
      },
    );
  }
}

class _NowLine extends ConsumerWidget {
  const _NowLine({required this.startHour, required this.hourHeight});

  final int startHour;
  final double hourHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final minutes = now.hour * 60 + now.minute - startHour * 60;
    if (minutes < 0) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.error;
    return PositionedDirectional(
      top: minutes / 60 * hourHeight - 5,
      start: -5,
      end: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 2, color: color)),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends ConsumerWidget {
  const _GridTile({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId));
    if (session == null) return const SizedBox.shrink();
    final course = ref.watch(courseProvider(session.courseId));
    final theme = Theme.of(context);
    final fmt = Fmt.of(context);
    final tone = CourseColors.of(context).tone(course?.colorKey ?? 'ocean');
    final canceled = session.isCanceled;
    final decided = session.status != AttendanceStatus.pending;

    return Opacity(
      opacity: canceled ? 0.45 : 1,
      child: Material(
        color: tone.container,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showSessionSheet(context, session.id),
          onLongPress: () => showStatusPicker(context, ref, session),
          child: Container(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: tone.accent, width: 3),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 3, 3),
            child: LayoutBuilder(
              builder: (context, c) {
                final tall = c.maxHeight > 44;
                final roomy = c.maxHeight > 64;
                final name = course?.name ?? '';
                final badge = decided && !canceled;
                final nameStyle =
                    (c.maxWidth < 64
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)
                        ?.copyWith(
                          color: tone.onContainer,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          decoration: canceled
                              ? TextDecoration.lineThrough
                              : null,
                        );
                // Wrapping a word wider than the tile would split it
                // mid-word ("Data Str|uctures"); use one ellipsized line.
                final lines =
                    _wordsFit(
                      name,
                      nameStyle!,
                      c.maxWidth - (badge ? 14 : 0),
                      MediaQuery.textScalerOf(context),
                    )
                    ? (roomy ? 3 : (tall ? 2 : 1))
                    : 1;
                final detail = theme.textTheme.labelSmall?.copyWith(
                  color: tone.onContainer.withValues(alpha: 0.8),
                );
                return Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: badge ? 14 : 0,
                          ),
                          child: Text(
                            name,
                            maxLines: lines,
                            overflow: TextOverflow.ellipsis,
                            style: nameStyle,
                          ),
                        ),
                        if (tall)
                          Text(
                            fmt.time(session.startMin),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: detail,
                          ),
                        if (roomy && session.location.isNotEmpty)
                          Text(
                            session.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: detail,
                          ),
                      ],
                    ),
                    if (badge)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: StatusIndicator(
                          status: session.status,
                          size: 14,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

bool _wordsFit(
  String text,
  TextStyle style,
  double maxWidth,
  TextScaler scaler,
) {
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width > maxWidth) return false;
  }
  return true;
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.hours,
    required this.hourHeight,
    required this.columns,
    required this.todayColumn,
    required this.line,
    required this.todayTint,
    required this.rtl,
  });

  final int hours;
  final double hourHeight;
  final int columns;
  final int todayColumn;
  final Color line;
  final Color todayTint;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    final colWidth = size.width / columns;
    if (todayColumn >= 0) {
      final i = rtl ? columns - 1 - todayColumn : todayColumn;
      canvas.drawRect(
        Rect.fromLTWH(i * colWidth, 0, colWidth, hours * hourHeight),
        Paint()..color = todayTint,
      );
    }
    for (var h = 0; h <= hours; h++) {
      final y = h * hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var c = 1; c < columns; c++) {
      final x = c * colWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, hours * hourHeight), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.hours != hours ||
      old.hourHeight != hourHeight ||
      old.columns != columns ||
      old.todayColumn != todayColumn ||
      old.line != line ||
      old.todayTint != todayTint ||
      old.rtl != rtl;
}

/// Mark / restore a no-class day.
Future<void> showDayOptions(
  BuildContext context,
  WidgetRef ref,
  LocalDate date,
) {
  final l = AppLocalizations.of(context);
  final fmt = Fmt.of(context);
  final data = ref.read(semesterDataProvider).value;
  if (data == null) return Future.value();
  final ranges = data.noClassRanges.where((r) => r.contains(date)).toList();
  final reason = TextEditingController();
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(sheet).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fmt.longDate(date), style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (ranges.isNotEmpty)
            for (final r in ranges)
              Card(
                child: ListTile(
                  leading: const Icon(LecIcons.holiday),
                  title: Text(r.label.isEmpty ? l.markNoClassDay : r.label),
                  subtitle: r.start == r.end
                      ? null
                      : Text(
                          '${fmt.dayMonth(r.start)} – ${fmt.dayMonth(r.end)}',
                        ),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      final receipt = await repo.deleteNoClassRange(r.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l.restoreDay),
                          action: SnackBarAction(
                            label: l.undo,
                            onPressed: () => repo.undoDeletion(receipt),
                          ),
                        ),
                      );
                    },
                    child: Text(l.restoreDay),
                  ),
                ),
              )
          else ...[
            Text(
              l.markNoClassDaySubtitle,
              style: Theme.of(sheet).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              decoration: InputDecoration(
                labelText: l.noClassReason,
                hintText: l.noClassReasonHint,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                repo.saveNoClassRange(
                  NoClassRange(
                    id: ScheduleRepository.newId(),
                    semesterId: data.semester.id,
                    start: date,
                    end: date,
                    label: reason.text.trim(),
                  ),
                );
                Navigator.pop(sheet);
              },
              icon: const Icon(LecIcons.holiday),
              label: Text(l.markNoClassDay),
            ),
          ],
        ],
      ),
    ),
  ).whenComplete(reason.dispose);
}
