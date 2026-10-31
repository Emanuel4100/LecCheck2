import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/last_undo.dart';
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
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../courses/meeting_sheet.dart';

/// Week's quick add: a new meeting on [date], [startMin]–[endMin] (a tap or
/// a drag on the grid). A small card beside the slot ([anchor], in global
/// coordinates) like Google Calendar's, or a sheet on phones. Save adds the
/// meeting, to a new course when one is named here; More options opens the
/// course editor with what was chosen.
Future<void> showQuickAdd(
  BuildContext context,
  WidgetRef ref, {
  required LocalDate date,
  required int startMin,
  required int endMin,
  required Rect anchor,
}) {
  final sheet =
      AppIdiom.usesTouch && WindowSize.of(context) == WindowSize.compact;
  final form = _QuickAdd(
    date: date,
    startMin: startMin,
    endMin: endMin,
    sheet: sheet,
  );
  if (sheet) {
    return showAppSheet<void>(
      context: context,
      scrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: form,
        ),
      ),
    );
  }
  final motion = AppMotion.of(context);
  final radius = AppIdiom.radius(20);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: motion.fast,
    pageBuilder: (context, _, _) => CustomSingleChildLayout(
      delegate: _BesideSlot(anchor, Directionality.of(context)),
      child: Material(
        elevation: 6,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
          child: form,
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: motion.effects);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Places the card beside the slot: after it in reading order when there's
/// room, before it otherwise, and over it on narrow windows; level with its
/// top, inside the window.
class _BesideSlot extends SingleChildLayoutDelegate {
  _BesideSlot(this.anchor, this.direction);

  final Rect anchor;
  final TextDirection direction;

  static const _width = 340.0;
  static const _gap = 12.0;
  static const _margin = 16.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          math.min(_width, constraints.maxWidth - 2 * _margin),
          constraints.maxHeight - 2 * _margin,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final after = anchor.right + _gap;
    final before = anchor.left - _gap - child.width;
    final fitsAfter = after + child.width <= size.width - _margin;
    final fitsBefore = before >= _margin;
    final x = switch (direction) {
      TextDirection.ltr when fitsAfter => after,
      TextDirection.rtl when fitsBefore => before,
      _ when fitsAfter => after,
      _ when fitsBefore => before,
      _ => anchor.center.dx - child.width / 2,
    };
    final maxY = math.max(_margin, size.height - child.height - _margin);
    return Offset(
      x.clamp(_margin, math.max(_margin, size.width - child.width - _margin)),
      anchor.top.clamp(_margin, maxY),
    );
  }

  @override
  bool shouldRelayout(_BesideSlot old) =>
      old.anchor != anchor || old.direction != direction;
}

class _QuickAdd extends ConsumerStatefulWidget {
  const _QuickAdd({
    required this.date,
    required this.startMin,
    required this.endMin,
    required this.sheet,
  });

  final LocalDate date;
  final int startMin;
  final int endMin;

  /// A bottom sheet (phones): swiping it down cancels, so no Cancel button.
  final bool sheet;

  @override
  ConsumerState<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends ConsumerState<_QuickAdd> {
  final _name = TextEditingController();
  final _room = TextEditingController();
  final _nameFocus = FocusNode();
  late final List<CourseInfo> _courses = ref.read(coursesProvider).items;
  late bool _newCourse = _courses.isEmpty;
  String? _courseId;
  bool _weekly = true;
  SessionType _type = SessionType.lecture;
  bool _typeChosen = false;
  bool _showErrors = false;

  CourseInfo? get _course =>
      _courses.where((c) => c.id == _courseId).firstOrNull;

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _pickCourse(CourseInfo? course) => setState(() {
    _newCourse = course == null;
    _courseId = course?.id;
    // Like the course editor: a course's first meeting is a lecture, the
    // next ones practices.
    if (!_typeChosen) {
      final data = ref.read(semesterDataProvider).value;
      final has = course != null && data != null;
      _type = has && data.meetingsOf(course.id).isNotEmpty
          ? SessionType.practice
          : SessionType.lecture;
    }
    if (_newCourse) _nameFocus.requestFocus();
  });

  MeetingSeed get _seed => MeetingSeed(
    weekday: _weekly ? widget.date.weekday : null,
    date: _weekly ? null : widget.date,
    startMin: widget.startMin,
    endMin: widget.endMin,
    type: _type,
    location: _room.text.trim(),
  );

  void _moreOptions() {
    final router = GoRouter.of(context);
    final name = _name.text.trim();
    final query = [
      if (!_newCourse && _courseId != null) 'id=$_courseId',
      _seed.query,
      if (_newCourse && name.isNotEmpty)
        'name=${Uri.encodeQueryComponent(name)}',
    ].join('&');
    Navigator.pop(context);
    router.push('/course-editor?$query');
  }

  Future<void> _save() async {
    final data = ref.read(semesterDataProvider).value;
    if (data == null) return;
    final name = _name.text.trim();
    if (_newCourse ? name.isEmpty : _course == null) {
      setState(() => _showErrors = true);
      if (_newCourse) _nameFocus.requestFocus();
      return;
    }
    final l = AppLocalizations.of(context);
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final courseId = _newCourse ? ScheduleRepository.newId() : _course!.id;
    final meeting = MeetingRule(
      id: ScheduleRepository.newId(),
      courseId: courseId,
      type: _type,
      kind: _weekly ? MeetingKind.weekly : MeetingKind.once,
      weekday: _weekly ? widget.date.weekday : null,
      date: _weekly ? null : widget.date,
      startMin: widget.startMin,
      endMin: widget.endMin,
      location: _room.text.trim(),
    );
    final String message;
    final Future<void> Function() undo;
    if (_newCourse) {
      final used = {for (final c in data.courses) c.colorKey};
      await repo.saveCourse(
        CourseInfo(
          id: courseId,
          semesterId: data.semester.id,
          name: name,
          colorKey: coursePaletteSeeds.keys.firstWhere(
            (k) => !used.contains(k),
            orElse: () => coursePaletteSeeds.keys.first,
          ),
          sortOrder: data.courses.length,
        ),
        meetings: [meeting],
        requirements: const [],
      );
      message = l.courseCreated(name);
      undo = () => repo.deleteCourse(courseId);
    } else {
      await repo.addMeeting(meeting);
      message = l.addedToCourse(_course!.name);
      undo = () => repo.deleteMeeting(meeting.id);
    }
    final undoOnce = ref.read(lastUndoProvider).remember(undo);
    HapticFeedback.lightImpact();
    navigator.pop();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(label: l.undo, onPressed: undoOnce),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final colors = CourseColors.of(context);
    final course = _course;
    final missingCourse = _showErrors && !_newCourse && course == null;

    Widget dot(String colorKey) =>
        CircleAvatar(radius: 7, backgroundColor: colors.tone(colorKey).accent);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _save(),
          ),
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${fmt.weekdayDayMonth(widget.date)} · '
              '${fmt.timeRange(widget.startMin, widget.endMin)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            MenuAnchor(
              menuChildren: [
                for (final c in _courses)
                  MenuItemButton(
                    leadingIcon: dot(c.colorKey),
                    onPressed: () => _pickCourse(c),
                    child: Text(c.name),
                  ),
                MenuItemButton(
                  leadingIcon: const Icon(LecIcons.add),
                  onPressed: () => _pickCourse(null),
                  child: Text(l.newCourse),
                ),
              ],
              builder: (context, controller, _) => OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  side: missingCourse
                      ? BorderSide(color: theme.colorScheme.error)
                      : null,
                ),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                child: Row(
                  children: [
                    if (_newCourse)
                      const Icon(LecIcons.add, size: 18)
                    else if (course != null)
                      dot(course.colorKey)
                    else
                      const Icon(LecIcons.courses, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _newCourse
                            ? l.newCourse
                            : course?.name ?? l.chooseCourse,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(LecIcons.expand, size: 18),
                  ],
                ),
              ),
            ),
            if (_newCourse) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                focusNode: _nameFocus,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.courseName,
                  errorText: _showErrors && _name.text.trim().isEmpty
                      ? l.courseNameRequired
                      : null,
                ),
                onSubmitted: (_) => _save(),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: true, label: Text(l.weekly)),
                    ButtonSegment(value: false, label: Text(l.oneTime)),
                  ],
                  selected: {_weekly},
                  onSelectionChanged: (s) => setState(() => _weekly = s.first),
                ),
                MenuChipButton<SessionType>(
                  icon: _type.icon,
                  label: _type.label(l),
                  values: SessionType.values,
                  itemIcon: (t) => t.icon,
                  itemLabel: (t) => t.label(l),
                  onSelected: (t) => setState(() {
                    _type = t;
                    _typeChosen = true;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _room,
              decoration: InputDecoration(
                labelText: l.location,
                prefixIcon: const Icon(LecIcons.location),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: _moreOptions,
                    child: Text(l.moreOptions, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const Spacer(),
                if (!widget.sheet) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 4),
                ],
                FilledButton(onPressed: _save, child: Text(l.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
