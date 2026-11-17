import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../core/backup/snapshot_service.dart';
import '../../core/backup/timetable_import.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../l10n/gen/app_localizations.dart';

/// Import a timetable through the user's own chatbot: our prompt plus their
/// schedule gives a JSON file, checked and previewed here. It only ever adds
/// a new semester.
class TimetableImportPage extends ConsumerStatefulWidget {
  const TimetableImportPage({super.key});

  @override
  ConsumerState<TimetableImportPage> createState() =>
      _TimetableImportPageState();
}

class _TimetableImportPageState extends ConsumerState<TimetableImportPage> {
  final _text = TextEditingController();
  TimetableDraft? _draft;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _read(String text) {
    setState(() {
      _draft = null;
      _error = null;
      if (text.trim().isEmpty) return;
      try {
        _draft = TimetableDraft.read(text);
      } on FormatException catch (e) {
        _error = e.message;
      }
    });
  }

  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: timetablePrompt));
    messenger.showSnackBar(SnackBar(content: Text(l.timetablePromptCopied)));
  }

  Future<void> _download() async {
    await FilePicker.saveFile(
      fileName: 'leccheck-timetable-prompt.md',
      bytes: utf8.encode(timetablePrompt),
      allowedExtensions: const ['md'],
    );
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile();
    if (file == null) return;
    final String text;
    try {
      text = utf8.decode(await file.readAsBytes());
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _draft = null;
        _error = "The file isn't text.";
      });
      return;
    }
    _text.text = text;
    _read(text);
  }

  Future<void> _add(ParsedTimetable timetable) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(snapshotServiceProvider).take(SnapshotReason.beforeImport);
      await timetable.save(ref.read(repositoryProvider));
    } on Object catch (e) {
      debugPrint('Timetable import failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.timetableSaveFailed)));
      if (mounted) setState(() => _saving = false);
      return;
    }
    ref
        .read(activeSemesterChoiceProvider.notifier)
        .select(timetable.semester.id);
    messenger.showSnackBar(
      SnackBar(content: Text(l.timetableAdded(timetable.semester.name))),
    );
    router.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = _draft;
    Widget step(int n, String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n. $title', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.timetableImport)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              step(1, l.timetableStepPrompt, l.timetableStepPromptBody),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _copy,
                    icon: const Icon(LecIcons.copy),
                    label: Text(l.timetableCopyPrompt),
                  ),
                  OutlinedButton.icon(
                    onPressed: _download,
                    icon: const Icon(LecIcons.exportData),
                    label: Text(l.timetableSavePrompt),
                  ),
                ],
              ),
              step(2, l.timetableStepChatbot, l.timetableStepChatbotBody),
              step(3, l.timetableStepImport, l.timetableStepImportBody),
              TextField(
                controller: _text,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l.timetablePaste,
                  errorText: _error == null
                      ? null
                      : l.timetableInvalid(_error!),
                  errorMaxLines: 4,
                ),
                onChanged: _read,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _pick,
                  icon: const Icon(LecIcons.importData),
                  label: Text(l.timetableChooseFile),
                ),
              ),
              if (draft != null) ...[
                const SizedBox(height: 16),
                _Preview(
                  key: ObjectKey(draft),
                  draft: draft,
                  saving: _saving,
                  onChanged: () => setState(() {}),
                  onAdd: () => _add(draft.build()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the chatbot's file adds, with fields for whatever it left out.
class _Preview extends StatelessWidget {
  const _Preview({
    super.key,
    required this.draft,
    required this.saving,
    required this.onChanged,
    required this.onAdd,
  });

  final TimetableDraft draft;
  final bool saving;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final gaps = draft.gaps;
    final kinds = {for (final g in gaps) g.kind};
    final start = draft.start;
    final end = draft.end;
    final missingCodes = draft.coursesWithoutCode.toList();

    // Meetings with something to fill in, each once, in order.
    final meetings = <(int, int)>{
      for (final g in gaps)
        if (g.course != null) (g.course!, g.meeting!),
    }.toList();
    Set<TimetableGapKind> kindsOf((int, int) m) => {
      for (final g in gaps)
        if (g.course == m.$1 && g.meeting == m.$2) g.kind,
    };

    Future<void> chooseDate(
      LocalDate? current,
      void Function(LocalDate) set,
    ) async {
      final picked = await pickDate(
        context,
        current ?? draft.start ?? LocalDate.today(),
      );
      if (picked == null) return;
      set(picked);
      onChanged();
    }

    Future<void> chooseTime(int? current, void Function(int) set) async {
      final picked = await pickTime(context, current ?? 10 * 60);
      if (picked == null) return;
      set(picked);
      onChanged();
    }

    Widget field(
      String label,
      String value,
      VoidCallback onTap, {
      String? error,
    }) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            suffixIcon: const Icon(LecIcons.chevronEnd),
          ),
          child: Text(value.isEmpty ? l.timetableChoose : value),
        ),
      ),
    );

    // The semester's visible weekdays in its order, for the day menu.
    final weekdays = [
      for (var i = 0; i < 7; i++) (draft.weekStart - 1 + i) % 7 + 1,
    ];
    String dayName(int weekday) =>
        fmt.weekdayName(_aWeek.addDays((weekday - _aWeek.weekday) % 7));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (draft.semesterName.trim().isNotEmpty &&
                !kinds.contains(TimetableGapKind.semesterName))
              Text(draft.semesterName, style: theme.textTheme.titleMedium),
            if (start != null &&
                end != null &&
                !kinds.contains(TimetableGapKind.semesterEnd))
              Text('${fmt.dayMonth(start)} – ${fmt.dayMonth(end)}'),
            const SizedBox(height: 8),
            for (final c in draft.courses)
              Text('${c.name}: ${l.timetableMeetings(c.meetings.length)}'),
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.timetableMissingTitle, style: theme.textTheme.titleSmall),
              Text(l.timetableMissingBody, style: muted),
              if (kinds.contains(TimetableGapKind.semesterName) ||
                  draft.semesterName.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    initialValue: draft.semesterName,
                    decoration: InputDecoration(labelText: l.semesterName),
                    onChanged: (v) {
                      draft.semesterName = v;
                      onChanged();
                    },
                  ),
                ),
              if (kinds.contains(TimetableGapKind.semesterStart) ||
                  kinds.contains(TimetableGapKind.semesterEnd)) ...[
                field(
                  l.startDate,
                  start == null ? '' : fmt.dayMonth(start),
                  () => chooseDate(start, (d) => draft.start = d),
                ),
                field(
                  l.endDate,
                  end == null ? '' : fmt.dayMonth(end),
                  () => chooseDate(end, (d) => draft.end = d),
                  error: end != null && start != null && end.isBefore(start)
                      ? l.timetableEndsBeforeStart
                      : null,
                ),
              ],
              for (final m in meetings) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final meeting = draft.courses[m.$1].meetings[m.$2];
                    final need = kindsOf(m);
                    final date = meeting.date;
                    final from = meeting.startMin;
                    final to = meeting.endMin;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${meeting.course} · ${meeting.type.label(l)}',
                          style: theme.textTheme.labelLarge,
                        ),
                        if (need.contains(TimetableGapKind.meetingDay))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: DropdownButtonFormField<int>(
                              initialValue: meeting.weekday,
                              decoration: InputDecoration(labelText: l.weekday),
                              items: [
                                for (final d in weekdays)
                                  DropdownMenuItem(
                                    value: d,
                                    child: Text(dayName(d)),
                                  ),
                              ],
                              onChanged: (d) {
                                meeting.weekday = d;
                                onChanged();
                              },
                            ),
                          ),
                        if (need.contains(TimetableGapKind.meetingDate))
                          field(
                            l.date,
                            date == null ? '' : fmt.weekdayDayMonth(date),
                            () => chooseDate(date, (d) => meeting.date = d),
                            error: date == null
                                ? null
                                : l.timetableOutsideSemester,
                          ),
                        if (need.contains(TimetableGapKind.meetingStart) ||
                            need.contains(TimetableGapKind.meetingEnd)) ...[
                          field(
                            l.startTime,
                            from == null ? '' : fmt.time(from),
                            () => chooseTime(from, (t) => meeting.startMin = t),
                          ),
                          field(
                            l.endTime,
                            to == null ? '' : fmt.time(to),
                            // An hour after the start, as a first guess.
                            () => chooseTime(to ?? (from ?? 9 * 60) + 60, (t) {
                              meeting.endMin = t;
                            }),
                            error: from != null && to != null && to <= from
                                ? l.timetableEndsBeforeStart
                                : null,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ],
            if (missingCodes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.timetableCodesTitle, style: theme.textTheme.titleSmall),
              Text(l.timetableCodesBody, style: muted),
              for (final i in missingCodes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    key: ValueKey('code$i'),
                    initialValue: draft.courses[i].code,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: draft.courses[i].name,
                      hintText: l.courseCode,
                    ),
                    onChanged: (v) => draft.courses[i].code = v,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(l.timetableAddsSemester, style: muted),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving || gaps.isNotEmpty ? null : onAdd,
              child: Text(l.timetableAdd),
            ),
            if (gaps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.timetableFillIn, style: muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// A known Sunday, to name weekdays.
final _aWeek = LocalDate(2026, 11, 15);
