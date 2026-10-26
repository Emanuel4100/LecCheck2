import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/adaptive.dart';
import '../../app/update_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/update/update_download.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import 'move_dialog.dart';
import 'update_steps.dart';

/// The update window: what's new, then each step of Update as it happens
/// (download with size and speed, the check of the file, install), then
/// Restart. Opens by itself once per launch while an update waits, and from
/// the update card and Check now.
Future<void> showUpdateDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const UpdateDialog());

/// What the window offers when Flatpak won't install the update itself.
const _allowUpdates =
    'flatpak permission-set flatpak updates com.leccheck.app yes';
const _updateByHand = 'flatpak update com.leccheck.app';

/// The text for [failure]; [UpdateDialog] and the card show it.
String updateFailureText(AppLocalizations l, UpdateFailure? failure) =>
    switch (failure) {
      UpdateFailure.network => l.updateFailedNetwork,
      UpdateFailure.notFound => l.updateFailedNotFound,
      UpdateFailure.space => l.updateFailedSpace,
      UpdateFailure.notVerified => l.updateNotVerified,
      UpdateFailure.installer => l.updateFailedInstaller,
      UpdateFailure.flatpakDenied => l.updateFailedFlatpakDenied,
      UpdateFailure.flatpakPermissions => l.updateFailedFlatpakPermissions,
      UpdateFailure.flatpakNotYet => l.updateFailedFlatpakNotYet,
      UpdateFailure.flatpak => l.updateFailedFlatpak,
      UpdateFailure.restart => l.updateRestartFailed,
      null => l.updateFailed,
    };

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final update = state.update;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(updateProvider.notifier);
    // Installed, skipped, or turned off meanwhile.
    if (update == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.maybePop(context);
      });
      return const SizedBox.shrink();
    }
    final phase = state.phase;
    final busy =
        phase == UpdatePhase.downloading || phase == UpdatePhase.verifying;
    final navigator = Navigator.of(context);
    void close() => navigator.pop();
    Future<void> inBrowser() async {
      openUrl(await controller.downloadUrl(update));
      if (context.mounted) close();
    }

    final actions = switch (phase) {
      UpdatePhase.idle => [
        TextButton(
          onPressed: () {
            controller.skip();
            close();
          },
          child: Text(l.updateSkip),
        ),
        TextButton(
          onPressed: () {
            controller.later();
            close();
          },
          child: Text(l.updateLater),
        ),
        switch (state.via) {
          UpdateVia.apk || UpdateVia.flatpak => FilledButton(
            onPressed: controller.install,
            child: Text(l.updateInstall),
          ),
          UpdateVia.move => FilledButton(
            onPressed: () {
              close();
              showMoveDialog(navigator.context);
            },
            child: Text(l.updateMove),
          ),
          UpdateVia.browser => FilledButton(
            onPressed: inBrowser,
            child: Text(l.updateDownload),
          ),
        },
      ],
      UpdatePhase.downloading => [
        TextButton(onPressed: controller.cancel, child: Text(l.cancel)),
      ],
      UpdatePhase.verifying => const <Widget>[],
      UpdatePhase.downloaded => [
        TextButton(onPressed: close, child: Text(l.close)),
        FilledButton(
          onPressed: controller.install,
          child: Text(l.updateInstallNow),
        ),
      ],
      UpdatePhase.restart => [
        TextButton(onPressed: close, child: Text(l.updateLater)),
        FilledButton(
          onPressed: controller.restart,
          child: Text(l.updateRestart),
        ),
      ],
      UpdatePhase.failed => [
        TextButton(onPressed: close, child: Text(l.close)),
        if (state.via != UpdateVia.flatpak)
          TextButton(onPressed: inBrowser, child: Text(l.updateInBrowser)),
        FilledButton(onPressed: controller.install, child: Text(l.retry)),
      ],
    };

    final hint = switch (state.via) {
      UpdateVia.flatpak => l.updateFlatpakHint,
      UpdateVia.move => l.updateMoveHint,
      UpdateVia.browser when AppIdiom.isLinux => l.updateLinuxHint,
      _ => null,
    };
    final size = state.size;

    return PopScope(
      // Not closed by Esc or a click outside while it downloads or checks.
      canPop: !busy,
      child: AlertDialog(
        icon: const Icon(LecIcons.celebrate),
        title: Text(l.updateAvailable(update.version)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _InstalledVersion(),
                const SizedBox(height: 16),
                if (phase == UpdatePhase.idle) ...[
                  if (update.notes.isNotEmpty) ...[
                    Text(
                      l.updateWhatsNewIn(update.version),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ReleaseNotes(update.notes),
                  ],
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => openUrl(update.notesUrl),
                        icon: const Icon(LecIcons.openLink, size: 18),
                        label: Text(l.updateWhatsNew),
                      ),
                      const Spacer(),
                      if (size != null)
                        Text(
                          l.updateSize(formatBytes(size)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ] else
                  _Steps(state: state),
              ],
            ),
          ),
        ),
        actions: actions,
      ),
    );
  }
}

class _InstalledVersion extends StatelessWidget {
  const _InstalledVersion();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, info) => Text(
        info.hasData ? l.updateYouHave(info.data!.version) : '',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Download → check the file → install, each with what's happening. On
/// Flatpak the portal does all three; they check off together at the end.
class _Steps extends StatelessWidget {
  const _Steps({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phase = state.phase;
    final flatpak = state.via == UpdateVia.flatpak;
    final failed = phase == UpdatePhase.failed ? state.failedStep : null;

    StepStatus of(UpdateStep step) {
      if (failed != null) {
        return step.index < failed.index
            ? StepStatus.done
            : step == failed
            ? StepStatus.failed
            : StepStatus.waiting;
      }
      final current = switch (phase) {
        UpdatePhase.downloading => UpdateStep.download,
        UpdatePhase.verifying => UpdateStep.verify,
        UpdatePhase.downloaded => UpdateStep.install,
        _ => null,
      };
      // Restart: everything is done. A failure with no step recorded knows
      // of nothing that finished.
      if (current == null) {
        return phase == UpdatePhase.failed
            ? StepStatus.waiting
            : StepStatus.done;
      }
      return step.index < current.index
          ? StepStatus.done
          : step == current
          ? StepStatus.active
          : StepStatus.waiting;
    }

    String? failure(UpdateStep step) =>
        failed == step ? updateFailureText(l, state.failure) : null;

    final total = state.total;
    final speed = state.bytesPerSecond;
    final progress = state.progress;
    final downloaded = switch (of(UpdateStep.download)) {
      StepStatus.active when flatpak =>
        progress == null
            ? null
            : NumberFormat.percentPattern(
                Localizations.localeOf(context).toString(),
              ).format(progress),
      _ when flatpak => null,
      StepStatus.active => [
        if (total != null)
          l.updateBytes(formatBytes(state.received), formatBytes(total))
        else
          formatBytes(state.received),
        if (speed != null && speed > 0) '${formatBytes(speed.round())}/s',
      ].join(' · '),
      StepStatus.done when total != null => formatBytes(total),
      _ => null,
    };
    final installDetail = switch (phase) {
      UpdatePhase.downloaded => l.updateInstallHint,
      UpdatePhase.restart =>
        state.failure == UpdateFailure.restart
            ? l.updateRestartFailed
            : l.updateRestartHint,
      _ when flatpak && phase == UpdatePhase.downloading =>
        l.updateFlatpakInstalling,
      _ when AppIdiom.isAndroid && failed == null => l.updateOpensInstaller,
      _ => null,
    };
    // Flatpak checks off its three steps one after another.
    Duration delay(UpdateStep step) =>
        flatpak ? Duration(milliseconds: 250 * step.index) : Duration.zero;
    final command = switch (state.failure) {
      UpdateFailure.flatpakDenied when failed != null => _allowUpdates,
      UpdateFailure.flatpakPermissions when failed != null => _updateByHand,
      _ => null,
    };
    final error = state.failure == UpdateFailure.flatpak ? state.error : null;
    Widget? failureExtras(UpdateStep step) {
      if (failed != step || (command == null && error == null)) return null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (command != null)
            CommandBox(
              command,
              copyLabel: l.updateCopyCommand,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: command));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(l.updateCommandCopied)),
                  );
              },
            ),
          if (error != null)
            SelectableText(error, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepRow(
          state: of(UpdateStep.download),
          title: l.updateStepDownload,
          detail: failure(UpdateStep.download) ?? downloaded,
          checkDelay: delay(UpdateStep.download),
          below: phase == UpdatePhase.downloading
              ? GlidingProgress(value: progress)
              : failureExtras(UpdateStep.download),
        ),
        StepRow(
          state: of(UpdateStep.verify),
          title: l.updateStepVerify,
          detail:
              failure(UpdateStep.verify) ??
              switch (of(UpdateStep.verify)) {
                StepStatus.active when total != null => l.updateBytes(
                  formatBytes(state.checked),
                  formatBytes(total),
                ),
                StepStatus.active => l.updateChecking,
                StepStatus.done =>
                  flatpak ? l.updateVerifiedFlatpak : l.updateVerified,
                _ => null,
              },
          checkDelay: delay(UpdateStep.verify),
          below: phase == UpdatePhase.verifying
              ? GlidingProgress(value: state.checkProgress)
              : null,
        ),
        StepRow(
          state: of(UpdateStep.install),
          title: l.updateStepInstall,
          detail: failure(UpdateStep.install) ?? installDetail,
          checkDelay: delay(UpdateStep.install),
          below: failureExtras(UpdateStep.install),
        ),
      ],
    );
  }
}

/// The changelog section, in English as it's written: `### ` headings, `- `
/// items (continued on indented lines), `**bold**`, `code` and links
/// (their text). Scrolls inside a box at most 40% of the screen tall.
class ReleaseNotes extends StatefulWidget {
  const ReleaseNotes(this.markdown, {super.key});

  final String markdown;

  @override
  State<ReleaseNotes> createState() => _ReleaseNotesState();

  /// `**bold**` as bold, `code` tinted, `[text](url)` as its text.
  @visibleForTesting
  static TextSpan inline(String text, TextStyle? style, TextStyle? code) {
    final marks = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\([^)]*\)');
    final spans = <InlineSpan>[];
    var at = 0;
    for (final match in marks.allMatches(text)) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }
      if (match[1] case final bold?) {
        spans.add(
          TextSpan(
            text: bold.replaceAll('`', ''),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else if (match[2] case final mono?) {
        spans.add(TextSpan(text: mono, style: code));
      } else {
        spans.add(TextSpan(text: match[3]));
      }
      at = match.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

class _ReleaseNotesState extends State<ReleaseNotes> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <(bool, String)>[]; // (is a heading, text)
    var bullets = false;
    for (final line in widget.markdown.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) {
        blocks.add((true, trimmed.replaceFirst(RegExp(r'^#+\s*'), '')));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add((false, trimmed.substring(2)));
        bullets = true;
      } else if (blocks.isNotEmpty && !blocks.last.$1) {
        // A wrapped line of the item above.
        blocks.last = (false, '${blocks.last.$2} $trimmed');
      } else {
        blocks.add((false, trimmed));
      }
    }
    final body = theme.textTheme.bodyMedium;
    final code = body?.copyWith(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
    final height = math.min(320.0, MediaQuery.sizeOf(context).height * 0.4);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DecoratedBox(
        // An inset in the dialog (which is surfaceContainerHigh itself).
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, (heading, text)) in blocks.indexed)
                    Padding(
                      padding: EdgeInsets.only(
                        top: heading && i > 0 ? 10 : 0,
                        bottom: heading ? 6 : 8,
                      ),
                      child: heading
                          ? Text(
                              text,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (bullets)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: Text('•', style: body),
                                  ),
                                Expanded(
                                  child: Text.rich(
                                    ReleaseNotes.inline(text, body, code),
                                  ),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
