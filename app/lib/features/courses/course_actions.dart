import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/widgets/common.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import 'meeting_sheet.dart';

/// The course shown in the details pane of the wide Courses layout.
class SelectedCourseController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedCourseProvider =
    NotifierProvider<SelectedCourseController, String?>(
      SelectedCourseController.new,
    );

/// Shows a course: selected beside the list on wide windows, its own page on
/// phones.
void openCourse(BuildContext context, WidgetRef ref, String courseId) {
  if (WindowSize.of(context).isWide) {
    ref.read(selectedCourseProvider.notifier).select(courseId);
    context.go('/courses');
  } else {
    context.go('/courses/$courseId');
  }
}

void addCourse(BuildContext context) => context.push('/course-editor');

/// Asks which course, then opens the editor on a new one-time session.
Future<void> addOneTimeSession(BuildContext context, WidgetRef ref) async {
  final courses = ref.read(coursesProvider).items;
  if (courses.isEmpty) {
    addCourse(context);
    return;
  }
  final picked = await pickCourse(
    context,
    ref,
    title: AppLocalizations.of(context).addOneTimeSession,
  );
  if (picked != null && context.mounted) {
    context.push('/course-editor?id=${picked.id}&oneTime=1');
  }
}

/// A list of the semester's courses under [title]; null when dismissed.
Future<CourseInfo?> pickCourse(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) {
  final courses = ref.read(coursesProvider).items;
  return showAppSheet<CourseInfo>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          ListTile(
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final c in courses)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: CourseColors.of(context)
                    .tone(c.colorKey)
                    .accent,
                radius: 8,
              ),
              title: Text(c.name),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    ),
  );
}

enum _SlotAction { newCourse, addMeeting, oneTime }

/// The menu for an empty slot of the Week grid ([date], [startMin] to
/// [endMin]) at [position]: a new course meeting there weekly, a weekly
/// meeting of a course, or a one-time session on that date.
Future<void> addAtSlot(
  BuildContext context,
  WidgetRef ref, {
  required LocalDate date,
  required int startMin,
  required int endMin,
  required Offset position,
}) async {
  final l = AppLocalizations.of(context);
  final fmt = Fmt.of(context);
  final theme = Theme.of(context);
  final hasCourses = ref.read(coursesProvider).items.isNotEmpty;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  PopupMenuItem<_SlotAction> item(
    _SlotAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    ),
  );

  final action = await showMenu<_SlotAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        enabled: false,
        height: 36,
        child: Text(
          '${fmt.weekdayDayMonth(date)} · ${fmt.timeRange(startMin, endMin)}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      item(_SlotAction.newCourse, LecIcons.courses, l.newCourseHere),
      if (hasCourses) ...[
        item(_SlotAction.addMeeting, LecIcons.add, l.addToCourse),
        item(_SlotAction.oneTime, LecIcons.date, l.oneTimeSessionHere),
      ],
    ],
  );
  if (action == null || !context.mounted) return;
  final weekly = MeetingSeed(
    weekday: date.weekday,
    startMin: startMin,
    endMin: endMin,
  );
  switch (action) {
    case _SlotAction.newCourse:
      context.push('/course-editor?${weekly.query}');
    case _SlotAction.addMeeting || _SlotAction.oneTime:
      final picked = await pickCourse(
        context,
        ref,
        title: action == _SlotAction.oneTime
            ? l.addOneTimeSession
            : l.addMeeting,
      );
      if (picked == null || !context.mounted) return;
      final seed = action == _SlotAction.oneTime
          ? MeetingSeed(date: date, startMin: startMin, endMin: endMin)
          : weekly;
      context.push('/course-editor?id=${picked.id}&${seed.query}');
  }
}
