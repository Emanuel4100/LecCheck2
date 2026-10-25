import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

/// A session dragged on Week to [date], [startMin]–[endMin] (desktop). A
/// weekly meeting asks first, at [position]: this week only (like "Change
/// date, time or room") or every week (the meeting itself changes, its
/// sessions' marks moving along). A one-time session just moves. Either
/// way a snackbar offers Undo for a few seconds.
Future<void> moveSessionTo(
  BuildContext context,
  WidgetRef ref,
  Occurrence session, {
  required LocalDate date,
  required int startMin,
  required int endMin,
  required Offset position,
}) async {
  if (date == session.date &&
      startMin == session.startMin &&
      endMin == session.endMin) {
    return;
  }
  final data = ref.read(semesterDataProvider).value;
  final meeting = data?.meeting(session.meetingId);
  if (data == null || meeting == null) return;
  final l = AppLocalizations.of(context);
  final fmt = Fmt.of(context);
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);

  var everyWeek = false;
  if (meeting.kind == MeetingKind.weekly) {
    final theme = Theme.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<bool>(
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
        PopupMenuItem(value: false, child: Text(l.thisWeekOnly)),
        PopupMenuItem(value: true, child: Text(l.everyWeek)),
      ],
    );
    if (choice == null) return;
    everyWeek = choice;
  }

  // What Undo puts back.
  final wasMoved = session.isMoved;
  Future<void> restoreMove() => wasMoved
      ? repo.moveSession(
          session,
          date: session.date,
          startMin: session.startMin,
          endMin: session.endMin,
          location: session.location,
        )
      : repo.resetSessionMove(session);

  final Future<void> Function() undo;
  if (everyWeek) {
    final weekStart = data.semester.weekStart;
    final next = meeting.movedTo(
      weekday: date.weekday,
      startMin: startMin,
      endMin: endMin,
    );
    // This week's own move goes first: from now on it follows the meeting.
    if (wasMoved) await repo.resetSessionMove(session);
    await repo.moveMeeting(meeting, next, weekStart: weekStart);
    undo = () async {
      await repo.moveMeeting(next, meeting, weekStart: weekStart);
      if (wasMoved) await restoreMove();
    };
  } else {
    await repo.moveSession(
      session,
      date: date,
      startMin: startMin,
      endMin: endMin,
      location: session.location,
    );
    undo = restoreMove;
  }
  HapticFeedback.selectionClick();
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(everyWeek ? l.movedEveryWeek : l.movedThisWeek),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: l.undo, onPressed: undo),
      ),
    );
}
