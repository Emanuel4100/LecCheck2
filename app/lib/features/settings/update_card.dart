import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/update_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';

/// "LecCheck X is available", at the top of Settings and, until "Later", of
/// Today.
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
                subtitle: AppIdiom.isLinux
                    ? Text(l.updateLinuxHint, style: text)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
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
                    TextButton(
                      onPressed: () => openUrl(update.notesUrl),
                      child: Text(l.updateWhatsNew),
                    ),
                    FilledButton(
                      onPressed: () async =>
                          openUrl(await controller.downloadUrl(update)),
                      child: Text(l.updateDownload),
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
