import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/gestures.dart'
    show
        DragGestureRecognizer,
        DragStartBehavior,
        GestureBinding,
        PanGestureRecognizer,
        PointerDeviceKind,
        PointerScrollEvent,
        PointerSignalEvent,
        VerticalDragGestureRecognizer;
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
import '../../domain/short_name.dart';
import '../../domain/time_slots.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_menu.dart';
import '../session/session_sheet.dart';
import '../settings/account_section.dart';
import '../session/session_tile.dart';
import '../session/status_buttons.dart';
import 'quick_add.dart';
import 'week_moves.dart';

/// First and last hour shown in the grid: at least 8:00–18:00, so there's
/// room to tap and add a class, and more when the semester's sessions need
/// it.
final hourRangeProvider = Provider<(int, int)>((ref) {
  final index = ref.watch(occurrenceIndexProvider);
  var minStart = 8 * 60;
  var maxEnd = 18 * 60;
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

  /// The week shown, for the app bar: swiping changes only it, not the grid
  /// (a rebuild of both visible weeks halfway through each swipe).
  final _shown = ValueNotifier<int>(0);
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
    _shown.dispose();
    super.dispose();
  }

  int _weekCount(SemesterCalendar calendar) {
    final last = ref.read(occurrenceIndexProvider).lastDate;
    final lastWeek = last == null ? 0 : calendar.weekNumberOf(last);
    return math.max(1, math.max(calendar.weekCount, lastWeek));
  }

  void _goToWeek(int week) {
    // Reduced motion: no page turn (it can't take a zero duration).
    if (AppMotion.of(context).reduced) {
      _controller?.jumpToPage(week - 1);
      return;
    }
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
      _shown.value = _page;
      _controller = PageController(initialPage: _page);
    }
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
              onPageChanged: (i) => _shown.value = _page = i,
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
        title: ValueListenableBuilder(
          valueListenable: _shown,
          builder: (context, page, _) {
            final weekStart = calendar.weekStartOf(page + 1);
            return AnimatedSwitcher(
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
                key: ValueKey(page + 1),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.weekNumber(page + 1)),
                  Text(
                    '${fmt.dayMonth(weekStart)} – ${fmt.dayMonth(weekStart.addDays(6))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: _shown,
            builder: (context, page, _) => page + 1 == currentWeek
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l.goToToday,
                    icon: const Icon(LecIcons.today),
                    onPressed: _thisWeek,
                  ),
          ),
          if (arrows) ...[
            ValueListenableBuilder(
              valueListenable: _shown,
              builder: (context, page, _) => IconButton(
                tooltip: l.previousWeek,
                icon: const Icon(LecIcons.chevronStart),
                onPressed: page > 0 ? () => _step(-1) : null,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _shown,
              builder: (context, page, _) => IconButton(
                tooltip: l.nextWeek,
                icon: const Icon(LecIcons.chevronEnd),
                onPressed: page + 1 < weekCount ? () => _step(1) : null,
              ),
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

/// A slot drawn over the grid while it's being dragged out, moved or
/// resized, and while the quick add or the move question about it is open.
class _Ghost {
  const _Ghost(this.date, this.start, this.end, {this.colorKey});

  final LocalDate date;
  final int start;
  final int end;

  /// The course of a session being moved; null for a new slot.
  final String? colorKey;
}

/// Drags on one week's grid: a new slot dragged out, or a session moved or
/// resized. Columns draw [ghost]; the grid turns pointer positions into a
/// day and a time, and scrolls when the pointer nears an edge.
class _GridDrag {
  _GridDrag(this._grid);

  final _WeekGridState _grid;
  final ghost = ValueNotifier<_Ghost?>(null);

  /// The session being moved or resized (shown faded meanwhile).
  final dragging = ValueNotifier<String?>(null);

  void Function(Offset global)? _onMove;
  Offset? _last;
  Timer? _scrolling;
  double _speed = 0;

  Offset? get last => _last;

  void begin(Offset global, void Function(Offset global) onMove) {
    _onMove = onMove;
    update(global);
  }

  void update(Offset global) {
    _last = global;
    _onMove?.call(global);
    _autoScroll(global);
  }

  void finish() {
    _onMove = null;
    _scrolling?.cancel();
    _scrolling = null;
    dragging.value = null;
  }

  void _autoScroll(Offset global) {
    final box = _grid._viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const zone = 40.0;
    _speed = global.dy < top + zone
        ? -8
        : global.dy > bottom - zone
        ? 8
        : 0;
    if (_speed == 0) {
      _scrolling?.cancel();
      _scrolling = null;
      return;
    }
    _scrolling ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final scroll = _grid._scroll;
      if (!scroll.hasClients || _onMove == null) return;
      final position = scroll.position;
      final next = (position.pixels + _speed).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return;
      position.jumpTo(next);
      if (_last case final last?) _onMove?.call(last);
    });
  }

  void dispose() {
    finish();
    ghost.dispose();
    dragging.dispose();
  }
}

/// Gives a week's columns and tiles its [_GridDrag].
class _GridScope extends InheritedWidget {
  const _GridScope({required this.grid, required super.child});

  final _WeekGridState grid;

  static _WeekGridState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GridScope>()!.grid;

  @override
  bool updateShouldNotify(_GridScope old) => old.grid != grid;
}

class _WeekGrid extends ConsumerStatefulWidget {
  const _WeekGrid({
    required this.weekStart,
    required this.hourHeight,
    required this.onZoom,
  });

  final LocalDate weekStart;
  final double hourHeight;
  final ValueChanged<double> onZoom;

  @override
  ConsumerState<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends ConsumerState<_WeekGrid> {
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  final _columnsKey = GlobalKey();
  late final drag = _GridDrag(this);
  List<LocalDate> _dates = const [];

  GridTimes get times {
    final (startHour, endHour) = ref.read(hourRangeProvider);
    return GridTimes(
      startHour: startHour,
      endHour: endHour,
      hourHeight: widget.hourHeight,
    );
  }

  @override
  void dispose() {
    drag.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The day and the height in the grid (from its first hour) under
  /// [global]; outside the columns, the nearest day.
  ({LocalDate date, double y})? cellAt(Offset global) {
    final box = _columnsKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || _dates.isEmpty) return null;
    final local = box.globalToLocal(global);
    final width = box.size.width / _dates.length;
    var column = (local.dx / width).floor().clamp(0, _dates.length - 1);
    // The columns are a Row: in Hebrew the first day is on the right.
    if (Directionality.of(context) == TextDirection.rtl) {
      column = _dates.length - 1 - column;
    }
    return (date: _dates[column], y: local.dy);
  }

  /// Moving a session (desktop): grabbed at [global], it follows the
  /// pointer to any day of the week, keeping its length; dropped, it asks
  /// how to apply the move.
  void startMove(Occurrence session, Offset global) {
    final start = cellAt(global);
    if (start == null) return;
    final grid = times;
    final length = session.endMin - session.startMin;
    // Where in the session it was grabbed, in pixels from its top.
    final grab =
        start.y - (session.startMin - grid.first) / 60 * widget.hourHeight;
    final colorKey = ref.read(courseProvider(session.courseId))?.colorKey;
    dragging.value = session.id;
    drag.begin(global, (g) {
      final cell = cellAt(g);
      if (cell == null) return;
      final slot = grid.moved(cell.y - grab, length);
      drag.ghost.value = _Ghost(
        cell.date,
        slot.start,
        slot.end,
        colorKey: colorKey,
      );
    });
  }

  /// Resizing a session (desktop): its bottom edge follows the pointer.
  void startResize(Occurrence session, Offset global) {
    final grid = times;
    final colorKey = ref.read(courseProvider(session.courseId))?.colorKey;
    dragging.value = session.id;
    drag.begin(global, (g) {
      final cell = cellAt(g);
      if (cell == null) return;
      drag.ghost.value = _Ghost(
        session.date,
        session.startMin,
        grid.resized(session.startMin, cell.y),
        colorKey: colorKey,
      );
    });
  }

  ValueNotifier<String?> get dragging => drag.dragging;

  /// The end of a move or resize: asks how to apply it, then clears the
  /// ghost.
  Future<void> drop(Occurrence session) async {
    final ghost = drag.ghost.value;
    final at = drag.last;
    drag.finish();
    if (ghost != null && at != null && mounted) {
      await moveSessionTo(
        context,
        ref,
        session,
        date: ghost.date,
        startMin: ghost.start,
        endMin: ghost.end,
        position: at,
      );
    }
    drag.ghost.value = null;
  }

  void cancel() {
    drag.finish();
    drag.ghost.value = null;
  }

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
      widget.onZoom(math.exp(-dy / 240));
    });
  }

  @override
  Widget build(BuildContext context) {
    final hourHeight = widget.hourHeight;
    final weekStart = widget.weekStart;
    final calendar = ref.watch(calendarProvider)!;
    final (startHour, endHour) = ref.watch(hourRangeProvider);
    final today = ref.watch(todayProvider);
    final dates = _dates = calendar.visibleDatesOfWeek(weekStart);
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
            key: _viewportKey,
            controller: _scroll,
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
                            child: _GridScope(
                              grid: this,
                              child: Row(
                                key: _columnsKey,
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
    final noClassLabel = ref.watch(noClassLabelProvider(date));
    final noClass = noClassLabel != null;
    final scheme = theme.colorScheme;
    final header = InkWell(
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
    // The holiday's name, on hover or a long press.
    return noClassLabel == null || noClassLabel.isEmpty
        ? header
        : Tooltip(message: noClassLabel, child: header);
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

class _DayColumn extends ConsumerStatefulWidget {
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
  ConsumerState<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends ConsumerState<_DayColumn> {
  /// Where a drag on empty space started, in pixels from the grid's top.
  double? _anchor;

  /// A long press moved: the slot follows the finger (until then it's the
  /// hour pressed).
  bool _stretched = false;

  RenderBox get _box => context.findRenderObject()! as RenderBox;

  double _y(Offset global) => _box.globalToLocal(global).dy;

  /// The slot between where a drag started and [global], on this day.
  void _follow(Offset global) {
    final grid = _GridScope.of(context).drag;
    final times = _GridScope.of(context).times;
    final y = _y(global);
    final anchor = _anchor!;
    if (!_stretched && (y - anchor).abs() > 8) _stretched = true;
    final slot = _stretched ? times.between(anchor, y) : times.tapped(anchor);
    grid.ghost.value = _Ghost(widget.date, slot.start, slot.end);
  }

  void _startSlot(Offset global, {required bool stretched}) {
    _anchor = _y(global);
    _stretched = stretched;
    _GridScope.of(context).drag.begin(global, _follow);
  }

  void _endSlot() {
    final grid = _GridScope.of(context).drag;
    grid.finish();
    _anchor = null;
    final ghost = grid.ghost.value;
    if (ghost != null) unawaited(_quickAdd(ghost.start, ghost.end));
  }

  /// A tap on empty space: the hour from the half hour tapped.
  void _onTapEmpty(TapUpDetails details) {
    final slot = _GridScope.of(context).times.tapped(details.localPosition.dy);
    _GridScope.of(context).drag.ghost.value = _Ghost(
      widget.date,
      slot.start,
      slot.end,
    );
    unawaited(_quickAdd(slot.start, slot.end));
  }

  /// Opens quick add beside the slot, which stays marked meanwhile.
  Future<void> _quickAdd(int start, int end) async {
    final ghost = _GridScope.of(context).drag.ghost;
    double y(int minutes) =>
        (minutes - widget.startHour * 60) / 60 * widget.hourHeight;
    final topLeft = _box.localToGlobal(Offset(0, y(start)));
    await showQuickAdd(
      context,
      ref,
      date: widget.date,
      startMin: start,
      endMin: end,
      anchor: topLeft & Size(_box.size.width, y(end) - y(start)),
    );
    if (ghost.value?.date == widget.date) ghost.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final height = widget.height;
    final ids = ref.watch(dayIdsProvider(date)).items;
    final index = ref.read(occurrenceIndexProvider);
    final sessions = [for (final id in ids) ?index.byId[id]];
    final today = ref.watch(todayProvider);
    final placed = _layoutDay(sessions);
    final grid = _GridScope.of(context);
    final desktop = AppIdiom.isDesktop;
    double y(int minutes) =>
        (minutes - widget.startHour * 60) / 60 * widget.hourHeight;

    // Its own layer: a hover or splash on a tile repaints this day, not the
    // whole week.
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Behind the tiles: only presses on empty space reach it.
                // A tap adds an hour there; a long press (phones) or a
                // mouse drag (desktop) drags out the time.
                Positioned.fill(
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      VerticalDragGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            VerticalDragGestureRecognizer
                          >(
                            () => VerticalDragGestureRecognizer(
                              supportedDevices: {PointerDeviceKind.mouse},
                            )..dragStartBehavior = DragStartBehavior.down,
                            (r) {
                              r
                                ..onStart = ((d) => _startSlot(
                                  d.globalPosition,
                                  stretched: true,
                                ))
                                ..onUpdate = ((d) =>
                                    grid.drag.update(d.globalPosition))
                                ..onEnd = ((_) => _endSlot())
                                ..onCancel = grid.cancel;
                            },
                          ),
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _onTapEmpty,
                      onLongPressStart: (d) {
                        HapticFeedback.selectionClick();
                        _startSlot(d.globalPosition, stretched: false);
                      },
                      onLongPressMoveUpdate: (d) =>
                          grid.drag.update(d.globalPosition),
                      onLongPressEnd: (_) => _endSlot(),
                      onLongPressCancel: grid.cancel,
                    ),
                  ),
                ),
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
                    child: desktop
                        ? _Movable(
                            session: p.session,
                            child: _GridTile(sessionId: p.session.id),
                          )
                        : _GridTile(sessionId: p.session.id),
                  ),
                if (date == today)
                  _NowLine(
                    startHour: widget.startHour,
                    hourHeight: widget.hourHeight,
                  ),
                ValueListenableBuilder(
                  valueListenable: grid.drag.ghost,
                  builder: (context, ghost, _) => ghost?.date != date
                      ? const SizedBox.shrink()
                      : PositionedDirectional(
                          top: y(ghost!.start),
                          height: math.max(
                            20,
                            y(ghost.end) - y(ghost.start) - 2,
                          ),
                          start: 2,
                          end: 2,
                          child: IgnorePointer(child: _GhostBox(ghost)),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The slot being added or the place a session is moving to, with its time.
class _GhostBox extends StatelessWidget {
  const _GhostBox(this.ghost);

  final _Ghost ghost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colorKey = ghost.colorKey;
    final accent = colorKey == null
        ? scheme.primary
        : CourseColors.of(context).tone(colorKey).accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        border: Border.all(color: accent, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 3, 4, 0),
        child: Text(
          Fmt.of(context).timeRange(ghost.start, ghost.end),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A session tile that can be moved with the mouse (desktop): drag it to
/// another time or day, or its bottom edge to change when it ends. It fades
/// while it's being dragged.
class _Movable extends StatelessWidget {
  const _Movable({required this.session, required this.child});

  final Occurrence session;
  final Widget child;

  static Map<Type, GestureRecognizerFactory>
  _mouse<T extends DragGestureRecognizer>(
    T Function() create,
    void Function(Offset global) onStart,
    void Function(Offset global) onUpdate,
    VoidCallback onEnd,
    VoidCallback onCancel,
  ) => {
    T: GestureRecognizerFactoryWithHandlers<T>(create, (r) {
      // From where the button went down, not where the drag was noticed.
      r
        ..dragStartBehavior = DragStartBehavior.down
        ..onStart = ((d) => onStart(d.globalPosition))
        ..onUpdate = ((d) => onUpdate(d.globalPosition))
        ..onEnd = ((_) => onEnd())
        ..onCancel = onCancel;
    }),
  };

  @override
  Widget build(BuildContext context) {
    final grid = _GridScope.of(context);
    const mouse = {PointerDeviceKind.mouse};
    return ValueListenableBuilder(
      valueListenable: grid.dragging,
      builder: (context, dragging, child) =>
          Opacity(opacity: dragging == session.id ? 0.35 : 1, child: child),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RawGestureDetector(
            gestures: _mouse(
              () => PanGestureRecognizer(supportedDevices: mouse),
              (g) => grid.startMove(session, g),
              grid.drag.update,
              () => grid.drop(session),
              grid.cancel,
            ),
            child: child,
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            height: 6,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: _mouse(
                  () => VerticalDragGestureRecognizer(supportedDevices: mouse),
                  (g) => grid.startResize(session, g),
                  grid.drag.update,
                  () => grid.drop(session),
                  grid.cancel,
                ),
              ),
            ),
          ),
        ],
      ),
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

    final tile = Material(
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
        child: CustomPaint(
          painter: canceled
              ? CanceledStripes(tone.accent.withValues(alpha: 0.16))
              : null,
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
                // Canceled shows its badge too: with the stripes it says why.
                final badge = decided;
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
        if (session.excluded && !session.isCanceled) l.notCountedLabel,
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
/// still doesn't fit, the course's short name is shown, if it has one, or
/// else a shortened form of the name ([autoShortNames]). Then
/// come the room and the start time; the time is dropped first, since the
/// grid already shows when a session starts. The status icon goes after the
/// name's first line, into free space at the bottom, or after the last line.
/// Tile layouts already measured: a week's tiles are rebuilt when the page
/// or the data changes, but their text and size rarely do.
final _tileLayouts = <Object, TileLayout>{};

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
  final key = (
    name,
    shortName,
    time,
    room,
    badge,
    nameStyle,
    detailStyle,
    size,
    scaler,
    direction,
  );
  final known = _tileLayouts[key];
  if (known != null) return known;
  // Zooming measures every tile at each new size.
  if (_tileLayouts.length > 600) _tileLayouts.clear();
  return _tileLayouts[key] = _measureTile(
    name: name,
    shortName: shortName,
    time: time,
    room: room,
    badge: badge,
    nameStyle: nameStyle,
    detailStyle: detailStyle,
    size: size,
    scaler: scaler,
    direction: direction,
  );
}

TileLayout _measureTile({
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
  if (!chosen.fits) {
    // The course's own short name, else the least shortened form of the
    // name that fits (or the shortest, cut off).
    for (final text
        in shortName.isNotEmpty ? [shortName] : autoShortNames(name)) {
      chosen = fit(text);
      if (chosen.fits) break;
    }
  }

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
