import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../app/theme/colors.dart';
import '../../app/widgets/common.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import 'session_actions.dart';
import 'status_buttons.dart';

/// Opens session details: a draggable bottom sheet on phones, a dialog on
/// wider windows and on desktop.
Future<void> showSessionSheet(BuildContext context, String sessionId) {
  if (AppIdiom.isDesktop || WindowSize.of(context) != WindowSize.compact) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
          child: SessionSheet(sessionId: sessionId),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          SessionSheet(sessionId: sessionId, scrollController: controller),
    ),
  );
}

class SessionSheet extends ConsumerStatefulWidget {
  const SessionSheet({
    super.key,
    required this.sessionId,
    this.scrollController,
    this.onClose,
  });

  final String sessionId;
  final ScrollController? scrollController;

  /// Closes the details (e.g. after removing the session). Defaults to
  /// popping the sheet or dialog; the week side panel deselects instead.
  final VoidCallback? onClose;

  @override
  ConsumerState<SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<SessionSheet> {
  final _notes = TextEditingController();
  final _recording = TextEditingController();
  final _notesFocus = FocusNode();
  final _recordingFocus = FocusNode();
  Timer? _notesTimer;
  Timer? _recordingTimer;
  Occurrence? _last;

  /// Captured up front: pending edits are flushed in dispose(), where `ref`
  /// may no longer be used.
  late final _repo = ref.read(repositoryProvider);

  @override
  void initState() {
    super.initState();
    _repo; // initialize while ref is valid
  }

  @override
  void dispose() {
    _flush();
    _notes.dispose();
    _recording.dispose();
    _notesFocus.dispose();
    _recordingFocus.dispose();
    super.dispose();
  }

  void _flush() {
    final session = _last;
    if (session == null) return;
    if (_notesTimer?.isActive ?? false) {
      _notesTimer!.cancel();
      _repo.setSessionNotes(session, _notes.text);
    }
    if (_recordingTimer?.isActive ?? false) {
      _recordingTimer!.cancel();
      _repo.setRecordingUrl(session, _recording.text);
    }
  }

  /// Keeps the text fields in sync with the database without clobbering what
  /// the user is typing.
  void _syncControllers(Occurrence session) {
    if (!_notesFocus.hasFocus && _notes.text != session.notes) {
      _notes.text = session.notes;
    }
    final url = session.recordingUrl ?? '';
    if (!_recordingFocus.hasFocus && _recording.text != url) {
      _recording.text = url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider(widget.sessionId));
    if (session == null) return const SizedBox.shrink();
    _last = session;
    _syncControllers(session);

    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final course = ref.watch(courseProvider(session.courseId));
    final meeting = ref.watch(meetingProvider(session.meetingId));
    final numbers = ref.watch(
      userPrefsProvider.select((p) => p.value?.meetingNumbers ?? true),
    );
    final tone = CourseColors.of(context).tone(course?.colorKey ?? 'ocean');
    final repo = ref.read(repositoryProvider);
    final today = ref.watch(todayProvider);
    final holiday = session.canceledByNoClassDay
        ? ref.watch(noClassLabelProvider(session.date))
        : null;

    final links = <NamedLink>[
      if (course != null && course.website.isNotEmpty)
        NamedLink(title: l.courseWebsite, url: course.website),
      ...?course?.links,
      ...?meeting?.links,
    ].where((link) => link.url.isNotEmpty).toList();

    void setStatus(AttendanceStatus status) => repo.setStatus(
      session,
      status == session.explicitStatus ? null : status,
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tone.container,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(session.type.icon, color: tone.onContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course?.name ?? '', style: theme.textTheme.titleLarge),
                  Text(
                    sessionTitle(session, l, numbers: numbers),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoRow(
          icon: LecIcons.date,
          text:
              '${fmt.relativeDay(session.date, today, l)} · ${fmt.timeRange(session.startMin, session.endMin)}',
        ),
        if (session.location.isNotEmpty)
          _InfoRow(icon: LecIcons.location, text: session.location),
        if (course != null && course.lecturer.isNotEmpty)
          _InfoRow(icon: LecIcons.lecturer, text: course.lecturer),
        if (session.isMoved)
          _InfoRow(
            icon: LecIcons.moved,
            text: l.movedLabel,
            color: theme.colorScheme.tertiary,
          ),
        if (session.canceledByNoClassDay)
          _InfoRow(
            icon: LecIcons.holiday,
            text: holiday == null || holiday.isEmpty
                ? l.canceledByHolidayHint
                : l.canceledForHoliday(holiday),
            color: theme.colorScheme.tertiary,
          ),
      ],
    );

    // Keys 1–5 mark the session (while not typing in the notes).
    return CallbackShortcuts(
      bindings: {
        for (final (i, status) in markableStatuses.indexed)
          SingleActivator(_digitKeys[i]): unlessTyping(() => setStatus(status)),
      },
      child: Focus(
        autofocus: true,
        child: ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Desktop: details can be selected and copied with the mouse.
            if (AppIdiom.isDesktop) SelectionArea(child: info) else info,
            const SizedBox(height: 20),
            Text(l.status, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            StatusButtonGroup(
              selected: session.explicitStatus,
              onSelected: setStatus,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notes,
              focusNode: _notesFocus,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.sessionNotes,
                hintText: l.sessionNotesHint,
                prefixIcon: const Icon(LecIcons.notes),
              ),
              onChanged: (text) {
                _notesTimer?.cancel();
                _notesTimer = Timer(
                  const Duration(milliseconds: 600),
                  () => repo.setSessionNotes(session, text),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recording,
              focusNode: _recordingFocus,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l.recordingLink,
                hintText: 'https://',
                prefixIcon: const Icon(LecIcons.recording),
                suffixIcon: _recording.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.openLink,
                        icon: const Icon(LecIcons.openLink),
                        onPressed: () => openUrl(_recording.text.trim()),
                      ),
              ),
              onChanged: (text) {
                setState(() {});
                _recordingTimer?.cancel();
                _recordingTimer = Timer(
                  const Duration(milliseconds: 600),
                  () => repo.setRecordingUrl(session, text),
                );
              },
            ),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.courseLinks, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final link in links)
                    ActionChip(
                      avatar: const Icon(LecIcons.link, size: 18),
                      label: Text(link.title.isEmpty ? link.url : link.title),
                      onPressed: () => openUrl(link.url),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text(l.thisWeekOnly, style: theme.textTheme.titleSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LecIcons.moved),
              title: Text(l.moveSession),
              onTap: () => showMoveSessionDialog(context, ref, session),
            ),
            if (session.isMoved)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LecIcons.undo),
                title: Text(l.resetChanges),
                onTap: () => repo.resetSessionMove(session),
              ),
            if (session.isOneOff)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LecIcons.delete, color: theme.colorScheme.error),
                title: Text(
                  l.removeOneTime,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final close = widget.onClose ?? () => Navigator.pop(context);
                  close();
                  final receipt = await repo.deleteMeeting(session.meetingId);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l.removeOneTime),
                      action: SnackBarAction(
                        label: l.undo,
                        onPressed: () => repo.undoDeletion(receipt),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

const _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
];

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user change date, time or room of one session.
Future<void> showMoveSessionDialog(
  BuildContext context,
  WidgetRef ref,
  Occurrence session,
) => showDialog<void>(
  context: context,
  builder: (_) => _MoveSessionDialog(session: session),
);

class _MoveSessionDialog extends ConsumerStatefulWidget {
  const _MoveSessionDialog({required this.session});
  final Occurrence session;

  @override
  ConsumerState<_MoveSessionDialog> createState() => _MoveSessionDialogState();
}

class _MoveSessionDialogState extends ConsumerState<_MoveSessionDialog> {
  late LocalDate _date = widget.session.date;
  late int _start = widget.session.startMin;
  late int _end = widget.session.endMin;
  late final _location = TextEditingController(text: widget.session.location);

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final minutes = await pickTime(context, start ? _start : _end);
    if (minutes == null) return;
    setState(() {
      if (start) {
        final length = _end - _start;
        _start = minutes;
        _end = (minutes + length).clamp(minutes + 5, 24 * 60 - 1);
      } else {
        _end = minutes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final valid = _end > _start;
    return AlertDialog(
      title: Text(l.moveSession),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LecIcons.date),
            title: Text(fmt.longDate(_date)),
            onTap: () async {
              final picked = await pickDate(context, _date);
              if (picked != null) setState(() => _date = picked);
            },
          ),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LecIcons.time),
                  title: Text(fmt.time(_start)),
                  subtitle: Text(l.startTime),
                  onTap: () => _pickTime(true),
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(fmt.time(_end)),
                  subtitle: Text(l.endTime),
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          if (!valid)
            Text(
              l.endAfterStartError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _location,
            decoration: InputDecoration(
              labelText: l.location,
              prefixIcon: const Icon(LecIcons.location),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () {
                  ref
                      .read(repositoryProvider)
                      .moveSession(
                        widget.session,
                        date: _date,
                        startMin: _start,
                        endMin: _end,
                        location: _location.text.trim(),
                      );
                  Navigator.pop(context);
                }
              : null,
          child: Text(l.save),
        ),
      ],
    );
  }
}
