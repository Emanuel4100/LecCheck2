import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/notification_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/notifications/android_device.dart';
import '../../core/notifications/notification_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import 'reminder_access.dart';

class NotificationsSection extends ConsumerStatefulWidget {
  const NotificationsSection({super.key});

  @override
  ConsumerState<NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<NotificationsSection> {
  static const _beforeOptions = [5, 10, 15, 30];
  static const _afterOptions = [0, 5, 10, 15, 30];

  /// Makers whose phones stop apps (and their alarms) unless they're allowed
  /// to start automatically: dontkillmyapp.com explains each one.
  static const _autostartMakers = {
    'xiaomi',
    'huawei',
    'honor',
    'oppo',
    'vivo',
    'oneplus',
    'realme',
  };

  /// Says why when nothing could be shown (v2.0.0-beta.3 on Android showed
  /// nothing at all, silently; beta.4 said nothing while Android blocked it).
  Future<void> _sendTest() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await allowReminders(context, ref)) return;
    try {
      await NotificationService.instance.showTest(
        l.notifyTestTitle,
        l.notifyTestBody,
      );
    } on RemindersBlocked {
      if (mounted) await allowReminders(context, ref);
    } on Object catch (e) {
      debugPrint('Test notification failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l.notificationFailed('$e'))),
      );
    }
  }

  /// What else can stop reminders on this phone, each with its fix.
  List<Widget> _checks(AppLocalizations l, ReminderHealth health) {
    final checks = ref.read(reminderHealthProvider.notifier);
    final maker = health.maker?.toLowerCase() ?? '';
    Widget check(
      String title,
      String subtitle,
      String action,
      Future<void> Function() fix,
    ) => ListTile(
      leading: const Icon(LecIcons.warning),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: () async {
          await fix();
          await checks.refresh();
        },
        child: Text(action),
      ),
    );
    return [
      if (health.exactAlarms == false)
        check(
          l.exactAlarmsOff,
          l.exactAlarmsOffSubtitle,
          l.allow,
          NotificationService.instance.requestExactAlarms,
        ),
      if (health.backgroundRestricted ?? false)
        check(
          l.backgroundRestricted,
          l.backgroundRestrictedSubtitle,
          l.openSettings,
          AndroidDevice.openAppSettings,
        ),
      if (health.batteryOptimized ?? false)
        check(
          l.batteryOptimized,
          maker == 'samsung'
              ? l.batteryOptimizedSamsung
              : l.batteryOptimizedSubtitle,
          l.turnOff,
          AndroidDevice.requestIgnoreBatteryOptimizations,
        ),
      if (_autostartMakers.contains(maker))
        ListTile(
          leading: const Icon(LecIcons.info),
          subtitle: Text(l.autostartHint(health.maker!)),
          trailing: TextButton(
            onPressed: () => openUrl('https://dontkillmyapp.com/$maker'),
            child: Text(l.howTo),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.watch(reminderSettingsProvider);
    final health = ref.watch(reminderHealthProvider);
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
        const RemindersBlockedCard(),
        SwitchListTile.adaptive(
          secondary: const Icon(LecIcons.time),
          title: Text(l.beforeClass),
          subtitle: Text(l.beforeClassSubtitle),
          value: settings.before,
          onChanged: (on) async {
            if (on && !await allowReminders(context, ref)) return;
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
            if (on && !await allowReminders(context, ref)) return;
            controller.update(after: on);
          },
        ),
        if (settings.after)
          minutes(
            _afterOptions,
            settings.afterMinutes,
            (m) => controller.update(afterMinutes: m),
          ),
        if (settings.any && AppIdiom.isAndroid) ..._checks(l, health),
        if (settings.any)
          ListTile(
            leading: const Icon(LecIcons.celebrate),
            title: Text(l.testNotification),
            onTap: _sendTest,
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
