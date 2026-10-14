import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/adaptive.dart';
import '../../app/update_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';

/// The update window: what's new, then each step of Update as it happens
/// (download with size and speed, the SHA-256 check, install), then
/// Restart. Opens by itself once per launch while an update waits, and from
/// the update card.
Future<void> showUpdateDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const UpdateDialog());

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
        phase == UpdatePhase.downloading || phase == UpdatePhase.installing;
    void close() => Navigator.pop(context);
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
        if (state.file != null)
          FilledButton(
            onPressed: controller.install,
            child: Text(l.updateInstall),
          )
        else
          FilledButton(onPressed: inBrowser, child: Text(l.updateDownload)),
      ],
      UpdatePhase.downloading => [
        TextButton(onPressed: controller.cancel, child: Text(l.cancel)),
      ],
      UpdatePhase.installing => const <Widget>[],
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
        TextButton(onPressed: inBrowser, child: Text(l.updateInBrowser)),
        FilledButton(onPressed: controller.install, child: Text(l.retry)),
      ],
    };

    return PopScope(
      // Not closed by Esc or a click outside while it downloads or installs.
      canPop: !busy,
      child: AlertDialog(
        icon: const Icon(LecIcons.celebrate),
        title: Text(l.updateAvailable(update.version)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, minWidth: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _InstalledVersion(),
                const SizedBox(height: 16),
                if (phase == UpdatePhase.idle) ...[
                  if (update.notes.isNotEmpty)
                    _ReleaseNotes(update.notes)
                  else
                    Text(l.updateWhatsNew, style: theme.textTheme.titleSmall),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => openUrl(update.notesUrl),
                      icon: const Icon(LecIcons.openLink, size: 18),
                      label: Text(l.updateWhatsNew),
                    ),
                  ),
                  if (AppIdiom.isLinux && state.file == null)
                    Text(
                      l.updateLinuxHint,
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

enum _StepState { waiting, active, done, failed }

/// Download → check the file → install, each with what's happening.
class _Steps extends StatelessWidget {
  const _Steps({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phase = state.phase;
    final failed = phase == UpdatePhase.failed ? state.failedStep : null;

    _StepState of(UpdateStep step) {
      if (failed != null) {
        return step.index < failed.index
            ? _StepState.done
            : step == failed
            ? _StepState.failed
            : _StepState.waiting;
      }
      final current = switch (phase) {
        UpdatePhase.downloading => UpdateStep.download,
        UpdatePhase.installing || UpdatePhase.downloaded => UpdateStep.install,
        _ => null,
      };
      if (current == null) return _StepState.done; // restart
      return step.index < current.index
          ? _StepState.done
          : step == current
          ? _StepState.active
          : _StepState.waiting;
    }

    final total = state.total;
    final speed = state.bytesPerSecond;
    final downloaded = switch (of(UpdateStep.download)) {
      _StepState.active => [
        if (total != null)
          l.updateBytes(_size(state.received), _size(total))
        else
          _size(state.received),
        if (speed != null && speed > 0) '${_size(speed.round())}/s',
      ].join(' · '),
      _StepState.done when total != null => _size(total),
      _ => null,
    };
    final installDetail = switch (phase) {
      UpdatePhase.downloaded => l.updateInstallHint,
      UpdatePhase.installing => l.updateInstalling,
      UpdatePhase.restart => l.updateRestartHint,
      _ when failed == UpdateStep.install => l.updateFailed,
      _ when AppIdiom.isAndroid => l.updateOpensInstaller,
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepRow(
          state: of(UpdateStep.download),
          title: l.updateStepDownload,
          detail: failed == UpdateStep.download ? l.updateFailed : downloaded,
        ),
        if (phase == UpdatePhase.downloading)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 40, bottom: 8),
            child: LinearProgressIndicator(value: state.progress),
          ),
        _StepRow(
          state: of(UpdateStep.verify),
          title: l.updateStepVerify,
          detail: switch (of(UpdateStep.verify)) {
            _StepState.done => l.updateVerified,
            _StepState.failed => l.updateNotVerified,
            _ => null,
          },
        ),
        _StepRow(
          state: of(UpdateStep.install),
          title: l.updateStepInstall,
          detail: installDetail,
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.state, required this.title, this.detail});

  final _StepState state;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (state) {
      _StepState.waiting => Icon(
        LecIcons.pending,
        size: 22,
        color: scheme.outline,
      ),
      _StepState.active => const SizedBox.square(
        dimension: 22,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      _StepState.done => Icon(
        LecIcons.attended,
        size: 22,
        color: scheme.primary,
      ),
      _StepState.failed => Icon(LecIcons.missed, size: 22, color: scheme.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: state == _StepState.waiting
                        ? scheme.onSurfaceVariant
                        : null,
                  ),
                ),
                if (detail case final detail?)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: state == _StepState.failed
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The changelog section: `- ` items (continued on indented lines),
/// `### ` headings, `**bold**`.
class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes(this.markdown);

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocks = <(bool, String)>[]; // (is a heading, text)
    final items = <String>[];
    for (final line in markdown.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) {
        blocks.add((true, trimmed.replaceFirst(RegExp(r'^#+\s*'), '')));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add((false, trimmed.substring(2)));
        items.add(trimmed);
      } else if (blocks.isNotEmpty && !blocks.last.$1) {
        // A wrapped line of the item above.
        blocks.last = (false, '${blocks.last.$2} $trimmed');
      } else {
        blocks.add((false, trimmed));
      }
    }
    final bullets = items.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (heading, text) in blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: heading
                        ? Text(text, style: theme.textTheme.titleSmall)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (bullets) const Text('•  '),
                              Expanded(
                                child: Text.rich(
                                  _inline(text, theme.textTheme.bodyMedium),
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
    );
  }

  /// `**bold**` as bold; other Markdown marks are dropped.
  static TextSpan _inline(String text, TextStyle? style) {
    final parts = text.replaceAll('`', '').split('**');
    return TextSpan(
      style: style,
      children: [
        for (final (i, part) in parts.indexed)
          TextSpan(
            text: part,
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
      ],
    );
  }
}

/// 45.6 MB, 820 KB.
String _size(int bytes) => bytes >= 1000 * 1000
    ? '${(bytes / 1e6).toStringAsFixed(1)} MB'
    : '${(bytes / 1e3).round()} KB';
