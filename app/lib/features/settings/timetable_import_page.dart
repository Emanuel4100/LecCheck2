import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../core/backup/snapshot_service.dart';
import '../../core/backup/timetable_import.dart';
import '../../core/icons/lec_icons.dart';
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
  ParsedTimetable? _parsed;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _read(String text) {
    setState(() {
      _parsed = null;
      _error = null;
      if (text.trim().isEmpty) return;
      try {
        _parsed = ParsedTimetable.parse(text);
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
        _parsed = null;
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
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final parsed = _parsed;
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
              if (parsed != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parsed.semester.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${fmt.dayMonth(parsed.semester.start)} – '
                          '${fmt.dayMonth(parsed.semester.end)}',
                        ),
                        const SizedBox(height: 8),
                        for (final c in parsed.courses)
                          Text(
                            '${c.course.name}: '
                            '${l.timetableMeetings(c.meetings.length)}',
                          ),
                        const SizedBox(height: 12),
                        Text(
                          l.timetableAddsSemester,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : () => _add(parsed),
                          child: Text(l.timetableAdd),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
