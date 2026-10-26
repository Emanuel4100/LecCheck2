import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/move_controller.dart';
import '../../app/sync_providers.dart';
import '../../app/update_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/update/tarball_install.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import 'update_steps.dart';

/// The window that moves an install.sh install to the Flatpak: why, how the
/// data comes along, then each step as it happens.
Future<void> showMoveDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const MoveDialog());

/// flatpak.org's instructions for each distribution.
const _flatpakSetup = 'https://flatpak.org/setup/';

/// Whether the data comes along through the account (signed in, nothing
/// waiting to sync) rather than a backup.
bool _signedIn(WidgetRef ref) =>
    ref.watch(authProvider).value != null &&
    ref.watch(attachedAccountProvider) != null;

class MoveDialog extends ConsumerWidget {
  const MoveDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moveProvider);
    final controller = ref.read(moveProvider.notifier);
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phase = state.phase;
    final signedIn = _signedIn(ref);
    void close() => Navigator.pop(context);
    final busy = switch (phase) {
      MovePhase.syncing || MovePhase.installing || MovePhase.removing => true,
      _ => false,
    };

    final actions = switch (phase) {
      MovePhase.idle => [
        TextButton(
          onPressed: () {
            controller.later();
            close();
          },
          child: Text(l.updateLater),
        ),
        FilledButton(onPressed: controller.start, child: Text(l.moveStart)),
      ],
      MovePhase.backup => [
        TextButton(onPressed: close, child: Text(l.close)),
        FilledButton(
          onPressed: controller.saveBackup,
          child: Text(l.moveSaveBackup),
        ),
      ],
      MovePhase.syncing || MovePhase.installing || MovePhase.removing => [
        // It goes on in the background; the card shows how far.
        TextButton(onPressed: close, child: Text(l.close)),
      ],
      MovePhase.ready => [
        TextButton(onPressed: close, child: Text(l.close)),
        FilledButton(onPressed: controller.open, child: Text(l.moveOpen)),
      ],
      MovePhase.failed => [
        TextButton(onPressed: close, child: Text(l.close)),
        if (state.failure == MoveFailure.noFlatpak)
          TextButton(
            onPressed: () => openUrl(_flatpakSetup),
            child: Text(l.moveHowToInstallFlatpak),
          ),
        FilledButton(
          onPressed: state.failedStep == MoveStep.data
              ? controller.saveBackup
              : controller.start,
          child: Text(l.retry),
        ),
      ],
    };

    final note = switch (phase) {
      MovePhase.idle => signedIn ? l.moveSignedInNote : l.moveGuestNote,
      MovePhase.ready =>
        state.backup != null
            ? l.moveReadyGuest
            : state.empty
            ? l.moveReadyEmpty
            : l.moveReadySignedIn,
      _ => null,
    };

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        icon: const Icon(LecIcons.moved),
        title: Text(l.moveTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (phase == MovePhase.idle) ...[
                  Text(l.moveIntro),
                  const SizedBox(height: 16),
                ],
                MoveSteps(state: state, signedIn: signedIn),
                if (note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    note,
                    style: phase == MovePhase.ready
                        ? theme.textTheme.bodyLarge
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: actions,
      ),
    );
  }
}

/// Your data → install the Flatpak → remove this version.
class MoveSteps extends StatelessWidget {
  const MoveSteps({super.key, required this.state, required this.signedIn});

  final MoveState state;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phase = state.phase;
    final failed = phase == MovePhase.failed ? state.failedStep : null;
    final current = switch (phase) {
      MovePhase.syncing || MovePhase.backup => MoveStep.data,
      MovePhase.installing => MoveStep.install,
      MovePhase.removing => MoveStep.remove,
      _ => null,
    };

    StepStatus of(MoveStep step) {
      if (failed != null) {
        return step.index < failed.index
            ? StepStatus.done
            : step == failed
            ? StepStatus.failed
            : StepStatus.waiting;
      }
      if (phase == MovePhase.ready) return StepStatus.done;
      if (current == null) return StepStatus.waiting;
      return step.index < current.index
          ? StepStatus.done
          : step == current
          ? StepStatus.active
          : StepStatus.waiting;
    }

    final dataTitle = signedIn && state.backup == null
        ? l.moveStepSync
        : l.moveStepBackup;
    final dataDetail = switch (of(MoveStep.data)) {
      StepStatus.failed => l.moveBackupFailed,
      StepStatus.active when phase == MovePhase.syncing => l.moveSyncing,
      StepStatus.active when signedIn => l.moveNotSynced,
      StepStatus.done when state.empty => l.moveNothingToBring,
      StepStatus.done when state.backup != null => l.moveBackupSaved(
        state.backup!.split('/').last,
      ),
      StepStatus.done => l.moveSynced,
      _ => null,
    };
    final installDetail = switch (of(MoveStep.install)) {
      StepStatus.failed when state.failure == MoveFailure.noFlatpak =>
        l.moveNoFlatpak,
      StepStatus.failed => l.moveInstallFailed,
      StepStatus.active => l.moveInstalling,
      StepStatus.done => l.moveInstalled,
      _ => null,
    };
    final removeDetail = switch (of(MoveStep.remove)) {
      StepStatus.failed => l.moveRemoveFailed,
      StepStatus.active => l.moveRemoving,
      StepStatus.done => l.moveRemoveNote(TarballInstall.dataFolder()),
      _ => null,
    };
    final outputStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // What flatpak printed: progress while it installs, its error after.
    final output = switch (of(MoveStep.install)) {
      StepStatus.active => state.output,
      StepStatus.failed when state.failure == MoveFailure.install =>
        state.detail,
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepRow(state: of(MoveStep.data), title: dataTitle, detail: dataDetail),
        StepRow(
          state: of(MoveStep.install),
          title: l.moveStepInstall,
          detail: installDetail,
          below: of(MoveStep.install) == StepStatus.active || output != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (of(MoveStep.install) == StepStatus.active)
                      const GlidingProgress(),
                    if (output != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            output,
                            style: outputStyle,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                )
              : null,
        ),
        StepRow(
          state: of(MoveStep.remove),
          title: l.moveStepRemove,
          detail: state.failure == MoveFailure.remove && state.detail != null
              ? '$removeDetail ${state.detail}'
              : removeDetail,
        ),
      ],
    );
  }
}

/// "LecCheck is moving to Flatpak", at the top of Settings and, until
/// "Later", of Today, for install.sh installs; it stands in for the update
/// card, which they don't get.
class MoveCard extends ConsumerWidget {
  const MoveCard({super.key, this.onToday = false});

  final bool onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(moveProvider);
    if (!state.offered || (onToday && state.later)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = TextStyle(color: scheme.onPrimaryContainer);
    final update = ref.watch(updateProvider.select((s) => s.update));
    final status = switch (state.phase) {
      MovePhase.idle || MovePhase.backup =>
        update != null ? l.updateMoveHint : l.moveCardSubtitle,
      MovePhase.syncing => l.moveSyncing,
      MovePhase.installing => l.moveInstalling,
      MovePhase.removing => l.moveRemoving,
      MovePhase.ready =>
        state.backup != null
            ? l.moveReadyGuest
            : state.empty
            ? l.moveReadyEmpty
            : l.moveReadySignedIn,
      MovePhase.failed => switch (state.failure) {
        MoveFailure.noFlatpak => l.moveNoFlatpak,
        MoveFailure.backup => l.moveBackupFailed,
        MoveFailure.remove => l.moveRemoveFailed,
        _ => l.moveInstallFailed,
      },
    };
    final controller = ref.read(moveProvider.notifier);
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
                leading: Icon(LecIcons.moved, color: scheme.onPrimaryContainer),
                title: Text(l.moveTitle, style: text),
                subtitle: Text(status, style: text),
              ),
              if (state.phase
                  case MovePhase.syncing ||
                      MovePhase.installing ||
                      MovePhase.removing)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: LinearProgressIndicator(),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    if (onToday && state.phase == MovePhase.idle)
                      TextButton(
                        onPressed: controller.later,
                        child: Text(l.updateLater),
                      ),
                    if (state.phase == MovePhase.ready)
                      FilledButton(
                        onPressed: controller.open,
                        child: Text(l.moveOpen),
                      )
                    else
                      FilledButton(
                        onPressed: () => showMoveDialog(context),
                        child: Text(
                          state.phase == MovePhase.idle
                              ? l.updateMove
                              : l.details,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
