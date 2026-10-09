import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/notification_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/notifications/notification_service.dart';
import '../../l10n/gen/app_localizations.dart';

/// Makes sure reminders can appear: asks for permission, and when the system
/// won't ask again (Android stops after two refusals) or a reminder channel
/// is off, offers its settings page. True once nothing blocks them.
Future<bool> allowReminders(BuildContext context, WidgetRef ref) async {
  final checks = ref.read(reminderHealthProvider.notifier);
  var health = await checks.refresh();
  if (health.allowed == false) {
    await NotificationService.instance.requestPermission();
    health = await checks.refresh();
  }
  if (!health.blocked) return true;
  if (!context.mounted) return false;
  final l = AppLocalizations.of(context);
  final channel = health.allowed == false ? null : health.blockedChannels.first;
  final open = await confirmDialog(
    context,
    title: l.notificationsOff,
    body: channel == null
        ? l.notificationsOffOpenSettings
        : l.reminderChannelOff(channelName(l, channel)),
    confirmLabel: l.openSettings,
  );
  if (open) await NotificationService.instance.openSettings(channel: channel);
  return false;
}

/// A reminder channel's name, as the system settings show it.
String channelName(AppLocalizations l, String channel) =>
    channel == 'after_class' ? l.channelAfter : l.channelBefore;

/// "Notifications are off for LecCheck", while reminders are switched on but
/// the system blocks them (on Today, beta.4 only warned inside Settings).
class RemindersBlockedCard extends ConsumerWidget {
  const RemindersBlockedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(reminderSettingsProvider.select((s) => s.any));
    final health = ref.watch(reminderHealthProvider);
    if (!on || !health.blocked) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = TextStyle(color: scheme.onErrorContainer);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(LecIcons.warning, color: scheme.onErrorContainer),
          title: Text(l.notificationsOff, style: text),
          subtitle: Text(
            health.allowed == false
                ? l.notificationsOffSubtitle
                : l.reminderChannelOff(
                    channelName(l, health.blockedChannels.first),
                  ),
            style: text,
          ),
          trailing: FilledButton(
            onPressed: () => allowReminders(context, ref),
            child: Text(l.allow),
          ),
        ),
      ),
    );
  }
}
