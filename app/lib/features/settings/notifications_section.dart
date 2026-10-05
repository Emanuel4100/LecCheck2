import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/notification_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/notifications/notification_service.dart';
import '../../l10n/gen/app_localizations.dart';

class NotificationsSection extends ConsumerStatefulWidget {
  const NotificationsSection({super.key});

  @override
  ConsumerState<NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<NotificationsSection> {
  static const _beforeOptions = [5, 10, 15, 30];
  static const _afterOptions = [0, 5, 10, 15, 30];

  /// Whether the OS lets LecCheck notify. Checked again when the app comes
  /// back from the system settings.
  bool _osAllowed = true;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final allowed = await NotificationService.instance.enabled();
    if (mounted && allowed != _osAllowed) setState(() => _osAllowed = allowed);
  }

  /// Enabling a reminder is the moment to ask for permission (not at launch).
  Future<bool> _allowed() async {
    final ok = await NotificationService.instance.requestPermission();
    await _check();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).notificationsBlocked),
        ),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings.any && !_osAllowed)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  LecIcons.warning,
                  color: theme.colorScheme.onErrorContainer,
                ),
                title: Text(
                  l.notificationsOff,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                subtitle: Text(
                  l.notificationsOffSubtitle,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: FilledButton(
                  onPressed: _allowed,
                  child: Text(l.allow),
                ),
              ),
            ),
          ),
        SwitchListTile.adaptive(
          secondary: const Icon(LecIcons.time),
          title: Text(l.beforeClass),
          subtitle: Text(l.beforeClassSubtitle),
          value: settings.before,
          onChanged: (on) async {
            if (on && !await _allowed()) return;
            controller.update(before: on);
          },
        ),
        if (settings.before)
          minutes(
            _beforeOptions,
            settings.beforeMinutes,
            (m) => controller.update(beforeMinutes: m),
          ),
        SwitchListTile.adaptive(
          secondary: const Icon(LecIcons.attended),
          title: Text(l.afterClass),
          subtitle: Text(l.afterClassSubtitle),
          value: settings.after,
          onChanged: (on) async {
            if (on && !await _allowed()) return;
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
        // Linux has no OS scheduler for notifications: the app fires them.
        if (settings.any && AppIdiom.isLinux)
          ListTile(
            leading: const Icon(LecIcons.info),
            subtitle: Text(l.remindersWhileOpen),
          ),
      ],
    );
  }
}
