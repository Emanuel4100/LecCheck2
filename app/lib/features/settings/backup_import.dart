import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/providers.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/snapshot_service.dart';
import '../../core/db/schedule_repository.dart';
import '../../l10n/gen/app_localizations.dart';

/// Import backup (Settings → Data, and Welcome): reads the file, shows what
/// it would change, and imports it after an automatic backup. "Add missing"
/// never changes existing data.
Future<void> importBackup(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(repositoryProvider);
  final file = await FilePicker.pickFile(allowedExtensions: const ['json']);
  if (file == null || !context.mounted) return;
  final ParsedBackup backup;
  final ({int added, int changed, int skipped}) preview;
  try {
    backup = BackupService.parse(utf8.decode(await file.readAsBytes()));
    preview = await repo.previewImport(backup.tables);
  } on Object catch (e) {
    // Not JSON, or JSON of another shape (wrong types throw TypeError).
    debugPrint('Import refused: $e');
    messenger.showSnackBar(SnackBar(content: Text(l.importFailed)));
    return;
  }
  if (preview.added == 0 && preview.changed == 0) {
    messenger.showSnackBar(SnackBar(content: Text(l.importNothing)));
    return;
  }
  if (!context.mounted) return;
  final mode = await showChoiceDialog<ImportMode?>(
    context,
    title: l.importTitle,
    body: [
      l.importPreview(backup.semesters, preview.added, preview.changed),
      if (preview.skipped > 0) l.importSkipped(preview.skipped),
    ].join('\n\n'),
    choices: [
      DialogChoice(l.cancel, null),
      if (preview.changed > 0)
        DialogChoice(l.replace, ImportMode.replace, destructive: true),
      DialogChoice(l.importMerge, ImportMode.merge, primary: true),
    ],
  );
  if (mode == null) return;
  await ref.read(snapshotServiceProvider).take(SnapshotReason.beforeImport);
  final count = await BackupService(repo).importParsed(backup, mode: mode);
  messenger.showSnackBar(SnackBar(content: Text(l.importDone(count))));
}
