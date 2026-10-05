import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../courses/course_actions.dart';
import 'session_actions.dart';
import 'session_sheet.dart';
import 'status_buttons.dart';

enum _Extra { clear, details, link, course }

/// The first link a session offers: meeting links, then course links, then
/// the course website.
String? sessionLink(WidgetRef ref, Occurrence session) {
  final course = ref.read(courseProvider(session.courseId));
  final meeting = ref.read(meetingProvider(session.meetingId));
  final links = [
    ...?meeting?.links.map((l) => l.url),
    ...?course?.links.map((l) => l.url),
    if (course != null) course.website,
  ];
  return links.where((url) => url.isNotEmpty).firstOrNull;
}

/// Right-click menu for a session (pointer devices): mark, details, link,
/// course.
Future<void> showSessionMenu(
  BuildContext context,
  WidgetRef ref,
  Occurrence session,
  Offset globalPosition,
) async {
  final l = AppLocalizations.of(context);
  final colors = StatusColors.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final link = sessionLink(ref, session);
  final current = session.explicitStatus;

  PopupMenuItem<Object> item(
    Object value,
    IconData icon,
    String label, {
    Color? color,
    bool checked = false,
  }) => PopupMenuItem<Object>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (checked) const Icon(LecIcons.check, size: 18),
      ],
    ),
  );

  final choice = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final status in markableStatuses)
        item(
          status,
          status.icon,
          status.action(l),
          color: colors[status].accent,
          checked: status == current,
        ),
      if (current != null) item(_Extra.clear, LecIcons.pending, l.clearStatus),
      const PopupMenuDivider(),
      item(_Extra.details, LecIcons.info, l.details),
      if (link != null) item(_Extra.link, LecIcons.openLink, l.openLink),
      item(_Extra.course, LecIcons.courses, l.goToCourse),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case AttendanceStatus status:
      await markSession(context, ref, session, status);
    case _Extra.clear:
      await ref.read(repositoryProvider).setStatus(session, null);
    case _Extra.details:
      await showSessionSheet(context, session.id);
    case _Extra.link:
      await openUrl(link!);
    case _Extra.course:
      openCourse(context, ref, session.courseId);
  }
}
