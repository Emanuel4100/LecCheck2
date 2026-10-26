import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/update_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/update/update_download.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import 'update_dialog.dart';
import 'update_steps.dart';

/// "LecCheck X is available", at the top of Settings and, until "Later", of
/// Today. Update downloads and installs it (Android, and the Flatpak through
/// its portal); otherwise Download opens it in the browser. Installs made by
/// install.sh get the move card instead (MoveCard).
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key, this.onToday = false});

  final bool onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final update = state.update;
    if (update == null ||
        state.via == UpdateVia.move ||
        (onToday && state.later)) {
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
    final size = state.size;
    final status = switch (state.phase) {
      UpdatePhase.idle
          when state.via == UpdateVia.browser && AppIdiom.isLinux =>
        l.updateLinuxHint,
      UpdatePhase.idle => size == null ? null : l.updateSize(formatBytes(size)),
      UpdatePhase.downloading =>
        progress == null
            ? l.updateDownloading
            : '${l.updateDownloading} ${percent.format(progress)}',
      UpdatePhase.verifying => l.updateChecking,
      UpdatePhase.downloaded => l.updateInstallHint,
      UpdatePhase.restart =>
        state.failure == UpdateFailure.restart
            ? l.updateRestartFailed
            : l.updateRestartHint,
      // The window has the command these need.
      UpdatePhase.failed => switch (state.failure) {
        UpdateFailure.flatpakDenied ||
        UpdateFailure.flatpakPermissions => l.updateFailedFlatpak,
        final failure => updateFailureText(l, failure),
      },
    };
    final whatsNew = TextButton(
      onPressed: () => openUrl(update.notesUrl),
      child: Text(l.updateWhatsNew),
    );
    final details = TextButton(
      onPressed: () => showUpdateDialog(context),
      child: Text(l.details),
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
                  case UpdatePhase.downloading || UpdatePhase.verifying)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: GlidingProgress(
                    value: state.phase == UpdatePhase.downloading
                        ? progress
                        : state.checkProgress,
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
                      if (state.via == UpdateVia.browser)
                        FilledButton(
                          onPressed: () async =>
                              openUrl(await controller.downloadUrl(update)),
                          child: Text(l.updateDownload),
                        )
                      else
                        FilledButton(
                          onPressed: () {
                            controller.install();
                            showUpdateDialog(context);
                          },
                          child: Text(l.updateInstall),
                        ),
                    ],
                    UpdatePhase.downloading => [
                      TextButton(
                        onPressed: controller.cancel,
                        child: Text(l.cancel),
                      ),
                      details,
                    ],
                    UpdatePhase.verifying => [details],
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
                      details,
                      if (state.via != UpdateVia.flatpak)
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
