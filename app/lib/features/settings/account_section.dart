import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/update_controller.dart';
import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/sync_providers.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../l10n/gen/app_localizations.dart';

/// Signs in (Google, or the dev account against `wrangler dev`). Asks before
/// replacing data that belongs to another account.
Future<bool> signIn(
  BuildContext context,
  WidgetRef ref, {
  String? devName,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref
        .read(authProvider.notifier)
        .signIn(
          devName: devName,
          confirmReplace: () => confirmDialog(
            context,
            title: l.replaceDataTitle,
            body: l.replaceDataBody,
            confirmLabel: l.replace,
            destructive: true,
          ),
        );
    return ref.read(authProvider).value != null;
  } on PlatformException catch (e) {
    // Closing the browser isn't an error worth reporting.
    if (e.code != 'CANCELED') {
      messenger?.showSnackBar(SnackBar(content: Text(l.signInFailed)));
    }
  } on Object {
    messenger?.showSnackBar(SnackBar(content: Text(l.signInFailed)));
  }
  return false;
}

String syncStatusText(SyncState state, AppLocalizations l, Fmt fmt) {
  final pending = state.pending > 0 ? ' · ${l.syncPending(state.pending)}' : '';
  if (state.upgradeRequired) return '${l.upgradeRequired}$pending';
  final held = state.heldUntil;
  if (held != null) {
    return '${l.syncPaused(fmt.time(held.hour * 60 + held.minute))}$pending';
  }
  return switch (state.phase) {
    SyncPhase.synced => l.syncSynced(_ago(state.lastSyncedAt, l, fmt)),
    SyncPhase.syncing => '${l.syncSyncing}$pending',
    SyncPhase.connecting => '${l.syncConnecting}$pending',
    SyncPhase.offline => '${l.syncOffline}$pending',
  };
}

String _ago(DateTime? at, AppLocalizations l, Fmt fmt) {
  if (at == null ||
      DateTime.now().difference(at) < const Duration(minutes: 1)) {
    return l.justNow;
  }
  return fmt.time(at.hour * 60 + at.minute);
}

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (!ref.watch(syncConfiguredProvider)) {
      return ListTile(
        leading: const Icon(LecIcons.syncOff),
        title: Text(l.guestMode),
        subtitle: Text('${l.guestModeSubtitle} ${l.syncNotConfigured}'),
      );
    }
    final session = ref.watch(authProvider).value;
    if (session == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(LecIcons.syncOff),
            title: Text(l.guestMode),
            subtitle: Text(l.syncHint),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: FilledButton.icon(
              onPressed: () => signIn(context, ref),
              icon: const Icon(LecIcons.account),
              label: Text(l.signInWithGoogle),
            ),
          ),
          if (SyncConfig.devAuth)
            TextButton(
              onPressed: () => signIn(context, ref, devName: 'dev'),
              child: Text(l.devSignIn),
            ),
        ],
      );
    }

    final state = ref.watch(syncStateProvider).value;
    final fmt = Fmt.of(context);
    final initial = (session.name ?? session.email ?? '?').characters.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(initial.toUpperCase()),
          ),
          title: Text(session.name ?? session.email ?? ''),
          subtitle: session.email == null ? null : Text(session.email!),
        ),
        if (state != null)
          ListTile(
            leading: SyncIndicator.icon(state, theme),
            title: Text(syncStatusText(state, l, fmt)),
            subtitle: state.heldUntil == null
                ? null
                : Text(l.syncPausedSubtitle),
            trailing: state.upgradeRequired
                ? TextButton(
                    onPressed: () =>
                        ref.read(updateProvider.notifier).check(force: true),
                    child: Text(l.checkForUpdates),
                  )
                : TextButton(
                    onPressed: () => ref.read(syncEngineProvider)?.syncNow(),
                    child: Text(l.syncNow),
                  ),
          ),
        if (state != null && state.failed > 0)
          ListTile(
            leading: Icon(LecIcons.warning, color: theme.colorScheme.error),
            title: Text(l.syncFailed(state.failed)),
            subtitle: Text(l.syncFailedSubtitle),
            trailing: TextButton(
              onPressed: () => ref.read(syncEngineProvider)?.retryRejected(),
              child: Text(l.retry),
            ),
          ),
        ListTile(
          leading: const Icon(LecIcons.close),
          title: Text(l.signOut),
          onTap: () => _signOut(context, ref),
        ),
        ListTile(
          leading: const Icon(LecIcons.syncOff),
          title: Text(l.signOutEverywhere),
          onTap: () => _signOutEverywhere(context, ref),
        ),
        ListTile(
          leading: Icon(LecIcons.delete, color: theme.colorScheme.error),
          title: Text(
            l.deleteCloudData,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          onTap: () => _deleteCloud(context, ref),
        ),
      ],
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final mode = await showChoiceDialog<SignOutMode?>(
      context,
      title: l.signOutTitle,
      body: l.signOutBody,
      choices: [
        DialogChoice(l.cancel, null),
        DialogChoice(l.removeData, SignOutMode.removeData, destructive: true),
        DialogChoice(l.keepData, SignOutMode.keepData, primary: true),
      ],
    );
    if (mode != null) await ref.read(authProvider.notifier).signOut(mode);
  }

  Future<void> _signOutEverywhere(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await confirmDialog(
      context,
      title: l.signOutEverywhereTitle,
      body: l.signOutEverywhereBody,
      confirmLabel: l.signOutEverywhere,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(authProvider.notifier).signOutEverywhere();
    } on Object catch (e) {
      debugPrint('Sign out everywhere failed: $e');
      messenger?.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    }
  }

  Future<void> _deleteCloud(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await confirmDialog(
      context,
      title: l.deleteCloudTitle,
      body: l.deleteCloudBody,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(authProvider.notifier).deleteCloudData();
    } on Object catch (e) {
      debugPrint('Delete cloud data failed: $e');
      messenger?.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    }
  }
}

/// Small cloud icon in the app bar showing sync health (hidden for guests).
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  static Widget icon(SyncState state, ThemeData theme) => switch (state.phase) {
    SyncPhase.synced => Icon(LecIcons.sync, color: theme.colorScheme.primary),
    SyncPhase.offline => Icon(
      LecIcons.syncOff,
      color: theme.colorScheme.onSurfaceVariant,
    ),
    _ => const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).value;
    if (state == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return IconButton(
      tooltip: syncStatusText(state, l, Fmt.of(context)),
      onPressed: () => context.push('/settings'),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(state.phase),
          child: icon(state, Theme.of(context)),
        ),
      ),
    );
  }
}
