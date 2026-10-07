import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show GestureBinding, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
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
import '../session/session_menu.dart';
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

/// Lets keyboard shortcuts (handled by the app shell) drive the week view.
class WeekCommands {
  _WeekPageState? _page;

  void step(int weeks) => _page?._step(weeks);
  void thisWeek() => _page?._thisWeek();

  /// Multiplies the hour height by [factor]; 0 resets to the default.
  void zoom(double factor) => _page?._zoomBy(factor);
}

final weekCommandsProvider = Provider<WeekCommands>((ref) => WeekCommands());

/// The session shown in the details panel of the large-window layout.
class _SelectedSession extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final _selectedSessionProvider = NotifierProvider<_SelectedSession, String?>(
  _SelectedSession.new,
);

/// Tells grid tiles whether a tap selects into the side panel (large
/// windows) or opens the details dialog / sheet.
class _PanelScope extends InheritedWidget {
  const _PanelScope({required this.enabled, required super.child});

  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PanelScope>()?.enabled ??
      false;

  @override
  bool updateShouldNotify(_PanelScope old) => old.enabled != enabled;
}

class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({super.key});

  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  static const _zoomKey = 'week.hourHeight';
  static const _minHour = 36.0;
  static const _maxHour = 140.0;

  PageController? _controller;
  late final _commands = ref.read(weekCommandsProvider);
  int _page = 0;
  int _weekCountCache = 1;
  int _currentWeekCache = 1;

  /// Chosen zoom (persisted per device); null = automatic: fit the hours to
  /// the window on desktop, 60 per hour on phones.
  double? _hourHeight;
  double? _fitHeight;

  // Two-finger pinch tracked from raw pointers so it never competes with the
  // page swipe or the vertical scroll in the gesture arena.
  final _pointers = <int, Offset>{};
  double? _pinchStart;
  double _pinchHeight = 60;
  double _panZoomStart = 60;

  double get _effectiveHeight =>
      _hourHeight ?? (AppIdiom.isDesktop ? _fitHeight ?? 60 : 60);

  double get _pinchDistance {
    final p = _pointers.values.toList();
    return (p[0] - p[1]).distance;
  }

  @override
  void initState() {
    super.initState();
    _hourHeight = ref.read(sharedPrefsProvider).getDouble(_zoomKey);
    _commands._page = this;
  }

  @override
  void dispose() {
    if (_commands._page == this) _commands._page = null;
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

  void _step(int weeks) =>
      _goToWeek((_page + 1 + weeks).clamp(1, _weekCountCache));

  void _thisWeek() => _goToWeek(_currentWeekCache);

  void _setHourHeight(double? value, {bool persist = true}) {
    setState(() => _hourHeight = value?.clamp(_minHour, _maxHour));
    if (!persist) return;
    final prefs = ref.read(sharedPrefsProvider);
    if (_hourHeight == null) {
      prefs.remove(_zoomKey);
    } else {
      prefs.setDouble(_zoomKey, _hourHeight!);
    }
  }

  void _zoomBy(double factor) =>
      _setHourHeight(factor == 0 ? null : _effectiveHeight * factor);

  void _persistZoom() {
    if (_hourHeight != null) {
      ref.read(sharedPrefsProvider).setDouble(_zoomKey, _hourHeight!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(calendarProvider);
    ref.watch(occurrenceIndexProvider);
    if (calendar == null) return const Scaffold();
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final today = ref.watch(todayProvider);
    final (startHour, endHour) = ref.watch(hourRangeProvider);
    final weekCount = _weekCount(calendar);
    final currentWeek = calendar.weekNumberOf(today).clamp(1, weekCount);
    _weekCountCache = weekCount;
    _currentWeekCache = currentWeek;
    if (_controller == null) {
      _page = currentWeek - 1;
      _controller = PageController(initialPage: _page);
    }
    final shownWeek = _page + 1;
    final weekStart = calendar.weekStartOf(shownWeek);
    final size = WindowSize.of(context);
    final compact = size == WindowSize.compact;
    final panel = size == WindowSize.large;
    final arrows = !compact || AppIdiom.isDesktop;
    final motion = AppMotion.of(context);

    final grid = LayoutBuilder(
      builder: (context, constraints) {
        // Hours that fill the window (desktop default zoom).
        final available = constraints.maxHeight - _headerHeight - 49;
        _fitHeight = (available / (endHour - startHour)).clamp(
          _minHour,
          _maxHour,
        );
        final hourHeight = _effectiveHeight;
        return Listener(
          onPointerDown: (e) {
            _pointers[e.pointer] = e.position;
            if (_pointers.length == 2) {
              _pinchStart = _pinchDistance;
              _pinchHeight = hourHeight;
            }
          },
          onPointerMove: (e) {
            if (!_pointers.containsKey(e.pointer)) return;
            _pointers[e.pointer] = e.position;
            final start = _pinchStart;
            if (_pointers.length == 2 && start != null && start > 0) {
              _setHourHeight(
                _pinchHeight * _pinchDistance / start,
                persist: false,
              );
            }
          },
          onPointerUp: (e) => _release(e.pointer),
          onPointerCancel: (e) => _release(e.pointer),
          // Trackpad pinch (desktop).
          onPointerPanZoomStart: (_) => _panZoomStart = hourHeight,
          onPointerPanZoomUpdate: (e) {
            if (e.scale != 1) {
              _setHourHeight(_panZoomStart * e.scale, persist: false);
            }
          },
          onPointerPanZoomEnd: (_) => _persistZoom(),
          child: _PanelScope(
            enabled: panel,
            child: PageView.builder(
              controller: _controller,
              itemCount: weekCount,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _WeekGrid(
                weekStart: calendar.weekStartOf(i + 1),
                hourHeight: hourHeight,
                onZoom: _zoomBy,
              ),
            ),
          ),
        );
      },
    );

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
              onPressed: _thisWeek,
            ),
          if (arrows) ...[
            IconButton(
              tooltip: l.previousWeek,
              icon: const Icon(LecIcons.chevronStart),
              onPressed: shownWeek > 1 ? () => _step(-1) : null,
            ),
            IconButton(
              tooltip: l.nextWeek,
              icon: const Icon(LecIcons.chevronEnd),
              onPressed: shownWeek < weekCount ? () => _step(1) : null,
            ),
          ],
          IconButton(
            tooltip: l.jumpToDate,
            icon: const Icon(LecIcons.date),
            onPressed: () async {
              final picked = await pickDate(context, today);
              if (picked == null) return;
              _goToWeek(calendar.weekNumberOf(picked).clamp(1, weekCount));
            },
          ),
          if (size != WindowSize.large) const SyncIndicator(),
          if (compact)
            IconButton(
              tooltip: l.settings,
              icon: const Icon(LecIcons.settings),
              onPressed: () => context.push('/settings'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: panel
          ? Row(
              children: [
                Expanded(child: grid),
                const VerticalDivider(width: 1),
                const SizedBox(width: 380, child: _SessionPanel()),
              ],
            )
          : grid,
    );
  }

  void _release(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2 && _pinchStart != null) {
      _pinchStart = null;
      _persistZoom();
    }
  }
}

/// Details of the selected session beside the grid (large windows).
class _SessionPanel extends ConsumerWidget {
  const _SessionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final id = ref.watch(_selectedSessionProvider);
    final session = id == null ? null : ref.watch(sessionProvider(id));
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LecIcons.info,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                l.selectSessionHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(l.details, style: theme.textTheme.titleSmall),
              ),
              IconButton(
                tooltip: l.close,
                icon: const Icon(LecIcons.close),
                onPressed: () =>
                    ref.read(_selectedSessionProvider.notifier).select(null),
              ),
            ],
          ),
        ),
        Expanded(
          child: SessionSheet(
            key: ValueKey(session.id),
            sessionId: session.id,
            onClose: () =>
                ref.read(_selectedSessionProvider.notifier).select(null),
          ),
        ),
      ],
    );
  }
}

const _timeColumnWidth = 48.0;
const _headerHeight = 56.0;

class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({
    required this.weekStart,
    required this.hourHeight,
    required this.onZoom,
  });

  final LocalDate weekStart;
  final double hourHeight;
  final ValueChanged<double> onZoom;

  /// Ctrl/⌘ + wheel zooms instead of scrolling. This listener sits inside the
  /// scroll view, so it claims the signal before the scroll view does.
  void _onSignal(PointerSignalEvent event) {
    final keys = HardwareKeyboard.instance;
    if (event is! PointerScrollEvent ||
        !(keys.isControlPressed || keys.isMetaPressed)) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final dy = (e as PointerScrollEvent).scrollDelta.dy;
      onZoom(math.exp(-dy / 240));
    });
  }

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
            child: Listener(
              onPointerSignal: _onSignal,
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
                                  Directionality.of(context) ==
                                  TextDirection.rtl,
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
      onSecondaryTap: () => showDayOptions(context, ref, date),
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
    final panel = _PanelScope.of(context);
    final selected =
        panel &&
        ref.watch(_selectedSessionProvider.select((id) => id == sessionId));

    final tile = Opacity(
      opacity: canceled ? 0.45 : 1,
      child: Material(
        color: tone.container,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => panel
              ? ref.read(_selectedSessionProvider.notifier).select(session.id)
              : showSessionSheet(context, session.id),
          onLongPress: () => showStatusPicker(context, ref, session),
          onSecondaryTapUp: (d) =>
              showSessionMenu(context, ref, session, d.globalPosition),
          child: Container(
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: tone.accent, width: 3),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(5, 3, 3, 3),
            child: LayoutBuilder(
              builder: (context, c) {
                final nameStyle =
                    (c.maxWidth < 64
                            ? theme.textTheme.labelSmall
                            : theme.textTheme.labelMedium)!
                        .copyWith(
                          color: tone.onContainer,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          decoration: canceled
                              ? TextDecoration.lineThrough
                              : null,
                        );
                final detailStyle = theme.textTheme.labelSmall!.copyWith(
                  color: tone.onContainer.withValues(alpha: 0.8),
                );
                final time = fmt.time(session.startMin);
                final badge = decided && !canceled;
                final layout = layoutTile(
                  name: course?.name ?? '',
                  shortName: course?.shortName ?? '',
                  time: time,
                  room: session.location,
                  badge: badge,
                  nameStyle: nameStyle,
                  detailStyle: detailStyle,
                  size: c.biggest,
                  scaler: MediaQuery.textScalerOf(context),
                  direction: Directionality.of(context),
                );
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: AlignmentDirectional.topStart,
                          maxHeight: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.only(
                                  end: layout.nameInset,
                                ),
                                child: Text(
                                  layout.name,
                                  maxLines: layout.nameLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: layout.nameStyle,
                                ),
                              ),
                              if (layout.showTime)
                                Text(
                                  time,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: detailStyle,
                                ),
                              if (layout.showRoom)
                                Text(
                                  session.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: detailStyle,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (layout.badgeTop case final top?)
                      PositionedDirectional(
                        top: top,
                        end: 0,
                        child: StatusIndicator(
                          status: session.status,
                          size: tileBadgeSize,
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
    if (!AppIdiom.isDesktop) return tile;
    // Small tiles cut text off; the full details show on hover.
    final l = AppLocalizations.of(context);
    return Tooltip(
      waitDuration: const Duration(milliseconds: 500),
      message: [
        course?.name ?? '',
        '${sessionTitle(session, l, numbers: false)} · '
            '${fmt.timeRange(session.startMin, session.endMin)}',
        if (session.location.isNotEmpty) session.location,
        statusLabel(session, l),
      ].join('\n'),
      child: tile,
    );
  }
}

/// Size of the status icon in a week tile.
const tileBadgeSize = 14.0;

/// What a week tile shows ([layoutTile]).
@immutable
class TileLayout {
  const TileLayout({
    required this.name,
    required this.nameStyle,
    required this.nameLines,
    required this.showTime,
    required this.showRoom,
    this.nameInset = 0,
    this.badgeTop,
  });

  /// The course name, or its short name when the full one doesn't fit.
  final String name;
  final TextStyle nameStyle;
  final int nameLines;
  final bool showTime;
  final bool showRoom;

  /// Space kept at the end of the name's lines for the status icon (only in
  /// tiles too small to put it anywhere else).
  final double nameInset;

  /// Where the status icon goes, from the top; null for none.
  final double? badgeTop;
}

/// Widest word of a name per style. It doesn't depend on the tile's size,
/// so pinch zoom doesn't measure it again on every frame.
final _widestWords = <(String, TextStyle, TextScaler), double>{};

/// Lays out a week tile so the course name is as readable as possible.
///
/// The name comes first: it gets the whole width and as many lines as fit,
/// and a word too wide for the tile shrinks the text a little. When the name
/// still doesn't fit, the course's short name is shown, if it has one. Then
/// come the room and the start time; the time is dropped first, since the
/// grid already shows when a session starts. The status icon goes after the
/// name's first line, into free space at the bottom, or after the last line.
TileLayout layoutTile({
  required String name,
  required String shortName,
  required String time,
  required String room,
  required bool badge,
  required TextStyle nameStyle,
  required TextStyle detailStyle,
  required Size size,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  final width = size.width;
  final height = size.height;

  TextPainter painter(
    String text,
    TextStyle style, {
    int? maxLines,
    double maxWidth = double.infinity,
  }) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '\u2026',
  )..layout(maxWidth: maxWidth);

  double widthOf(String text, TextStyle style) {
    final p = painter(text, style, maxLines: 1);
    final result = p.width;
    p.dispose();
    return result;
  }

  double widestWord(String text, TextStyle style) {
    if (_widestWords.length > 400) _widestWords.clear();
    return _widestWords.putIfAbsent((text, style, scaler), () {
      var widest = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        if (word.isNotEmpty) widest = math.max(widest, widthOf(word, style));
      }
      return widest;
    });
  }

  // The name as it would be shown, and whether all of it fits.
  ({String text, TextStyle style, int lines, bool fits}) fit(String text) {
    // A word wider than the tile first loses its letter spacing, then
    // shrinks by up to 1.5 px. Wrapping it mid-way ("Data Structure|s") is
    // the last resort.
    final smallest = nameStyle.fontSize! - 1.5;
    var style = nameStyle;
    var wordsFit = widestWord(text, style) <= width;
    if (!wordsFit) style = style.copyWith(letterSpacing: 0);
    while (!(wordsFit = widestWord(text, style) <= width) &&
        style.fontSize! > smallest) {
      style = style.copyWith(fontSize: style.fontSize! - 0.25);
    }
    final p = painter(text, style, maxWidth: width);
    final needed = math.max(1, p.computeLineMetrics().length);
    final available = math.max(1, (height / p.preferredLineHeight).floor());
    p.dispose();
    return (
      text: text,
      style: style,
      lines: math.min(needed, available),
      fits: wordsFit && needed <= available,
    );
  }

  var chosen = fit(name);
  if (!chosen.fits && shortName.isNotEmpty) chosen = fit(shortName);

  final namePainter = painter(
    chosen.text,
    chosen.style,
    maxLines: chosen.lines,
    maxWidth: width,
  );
  final lines = namePainter.computeLineMetrics();
  final nameHeight = namePainter.height;
  namePainter.dispose();
  final detailPainter = painter('0', detailStyle);
  final detailHeight = detailPainter.preferredLineHeight;
  detailPainter.dispose();

  var free = height - nameHeight;
  final showRoom = room.isNotEmpty && free >= detailHeight;
  if (showRoom) free -= detailHeight;
  var showTime = free >= detailHeight;
  if (showTime) free -= detailHeight;

  TileLayout result({double? badgeTop, double nameInset = 0}) => TileLayout(
    name: chosen.text,
    nameStyle: chosen.style,
    nameLines: chosen.lines,
    showTime: showTime,
    showRoom: showRoom,
    nameInset: nameInset,
    badgeTop: badgeTop,
  );

  if (!badge) return result();
  bool fitsAfter(double lineWidth) => lineWidth + 2 + tileBadgeSize <= width;
  double centeredOn(double top, double lineHeight) =>
      top + (lineHeight - tileBadgeSize) / 2;
  final first = lines.firstOrNull;
  final last = lines.lastOrNull;

  // After the name's first line, as on wide tiles.
  if (fitsAfter(first?.width ?? 0)) {
    return result(badgeTop: centeredOn(0, first?.height ?? nameHeight));
  }
  // Free space at the bottom.
  if (free >= tileBadgeSize) return result(badgeTop: height - tileBadgeSize);
  // After a line short enough: the time, the room or the name's last line.
  var top = nameHeight;
  if (showTime) {
    if (fitsAfter(widthOf(time, detailStyle))) {
      return result(badgeTop: centeredOn(top, detailHeight));
    }
    top += detailHeight;
  }
  if (showRoom && fitsAfter(widthOf(room, detailStyle))) {
    return result(badgeTop: centeredOn(top, detailHeight));
  }
  if (last != null && fitsAfter(last.width)) {
    return result(badgeTop: centeredOn(nameHeight - last.height, last.height));
  }
  // Make room at the bottom by dropping the time.
  if (showTime) {
    showTime = false;
    return result(badgeTop: height - tileBadgeSize);
  }
  // A small tile: keep space for the icon beside the name.
  return result(badgeTop: 0, nameInset: tileBadgeSize);
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

  return showAppSheet<void>(
    context: context,
    scrollControlled: true,
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
