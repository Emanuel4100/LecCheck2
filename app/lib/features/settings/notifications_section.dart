import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/notification_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/notifications/notification_service.dart';
import '../../l10n/gen/app_localizations.dart';

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({super.key});

  static const _beforeOptions = [5, 10, 15, 30];
  static const _afterOptions = [0, 5, 10, 15, 30];

  /// Enabling a reminder is the moment to ask for permission (not at launch).
  Future<bool> _allowed(BuildContext context) async {
    final ok = await NotificationService.instance.requestPermission();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).notificationsBlocked),
        ),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(reminderSettingsProvider);
    final controller = ref.read(reminderSettingsProvider.notifier);

    Widget minutes(
      List<int> options,
      int selected,
      ValueChanged<int> onSelected,
    ) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final m in options)
            ChoiceChip(
              label: Text(l.minutesShort(m)),
              selected: selected == m,
              onSelected: (_) => onSelected(m),
            ),
        ],
      ),
    );

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(LecIcons.time),
          title: Text(l.beforeClass),
          subtitle: Text(l.beforeClassSubtitle),
          value: settings.before,
          onChanged: (on) async {
            if (on && !await _allowed(context)) return;
            controller.update(before: on);
          },
        ),
        if (settings.before)
          minutes(
            _beforeOptions,
            settings.beforeMinutes,
            (m) => controller.update(beforeMinutes: m),
          ),
        SwitchListTile(
          secondary: const Icon(LecIcons.attended),
          title: Text(l.afterClass),
          subtitle: Text(l.afterClassSubtitle),
          value: settings.after,
          onChanged: (on) async {
            if (on && !await _allowed(context)) return;
            controller.update(after: on);
          },
        ),
        if (settings.after)
          minutes(
            _afterOptions,
            settings.afterMinutes,
            (m) => controller.update(afterMinutes: m),
          ),
        if (settings.any)
          ListTile(
            leading: const Icon(LecIcons.celebrate),
            title: Text(l.testNotification),
            onTap: () => NotificationService.instance.showTest(
              l.notifyTestTitle,
              l.notifyTestBody,
            ),
          ),
      ],
    );
  }
}
