import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/update_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import 'update_dialog.dart';

/// "LecCheck X is available", at the top of Settings and, until "Later", of
/// Today. Update downloads and installs it (Android, and Linux installed by
/// install.sh); otherwise Download opens it in the browser.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key, this.onToday = false});

  final bool onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final update = state.update;
    if (update == null || (onToday && state.later)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final controller = ref.read(updateProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final text = TextStyle(color: scheme.onPrimaryContainer);
    final progress = state.progress;
    final percent = NumberFormat.percentPattern(
      Localizations.localeOf(context).toString(),
    );
    final status = switch (state.phase) {
      UpdatePhase.idle =>
        AppIdiom.isLinux && state.file == null ? l.updateLinuxHint : null,
      UpdatePhase.downloading =>
        progress == null
            ? l.updateDownloading
            : '${l.updateDownloading} ${percent.format(progress)}',
      UpdatePhase.installing => l.updateInstalling,
      UpdatePhase.downloaded => l.updateInstallHint,
      UpdatePhase.restart => l.updateRestartHint,
      UpdatePhase.failed => l.updateFailed,
    };
    final whatsNew = TextButton(
      onPressed: () => openUrl(update.notesUrl),
      child: Text(l.updateWhatsNew),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(
                  LecIcons.celebrate,
                  color: scheme.onPrimaryContainer,
                ),
                title: Text(l.updateAvailable(update.version), style: text),
                subtitle: status == null ? null : Text(status, style: text),
              ),
              if (state.phase
                  case UpdatePhase.downloading || UpdatePhase.installing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LinearProgressIndicator(
                    value: state.phase == UpdatePhase.downloading
                        ? progress
                        : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: switch (state.phase) {
                    UpdatePhase.idle => [
                      if (onToday)
                        TextButton(
                          onPressed: controller.later,
                          child: Text(l.updateLater),
                        )
                      else
                        TextButton(
                          onPressed: controller.skip,
                          child: Text(l.updateSkip),
                        ),
                      whatsNew,
                      if (state.file != null)
                        FilledButton(
                          onPressed: () {
                            controller.install();
                            showUpdateDialog(context);
                          },
                          child: Text(l.updateInstall),
                        )
                      else
                        FilledButton(
                          onPressed: () async =>
                              openUrl(await controller.downloadUrl(update)),
                          child: Text(l.updateDownload),
                        ),
                    ],
                    UpdatePhase.downloading => [
                      TextButton(
                        onPressed: controller.cancel,
                        child: Text(l.cancel),
                      ),
                      TextButton(
                        onPressed: () => showUpdateDialog(context),
                        child: Text(l.details),
                      ),
                    ],
                    UpdatePhase.installing => [
                      TextButton(
                        onPressed: () => showUpdateDialog(context),
                        child: Text(l.details),
                      ),
                    ],
                    UpdatePhase.downloaded => [
                      whatsNew,
                      FilledButton(
                        onPressed: controller.install,
                        child: Text(l.updateInstallNow),
                      ),
                    ],
                    UpdatePhase.restart => [
                      FilledButton(
                        onPressed: controller.restart,
                        child: Text(l.updateRestart),
                      ),
                    ],
                    UpdatePhase.failed => [
                      TextButton(
                        onPressed: () async =>
                            openUrl(await controller.downloadUrl(update)),
                        child: Text(l.updateInBrowser),
                      ),
                      FilledButton(
                        onPressed: controller.install,
                        child: Text(l.retry),
                      ),
                    ],
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
