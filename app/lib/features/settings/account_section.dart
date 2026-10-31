import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/update_controller.dart';
import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/sync_providers.dart';
import '../../app/theme/motion.dart';
import '../../core/auth/auth_service.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../domain/local_date.dart';
import '../../l10n/gen/app_localizations.dart';

/// Signs in (Google, or the dev account against `wrangler dev`). Asks before
/// replacing data that belongs to another account, before mixing data made
/// while signed out into an account that has data, and offers to bring back
/// an account's deleted data.
Future<SignInResult> signIn(
  BuildContext context,
  WidgetRef ref, {
  String? devName,
}) async {
  final l = AppLocalizations.of(context);
  final fmt = Fmt.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    return await ref
        .read(authProvider.notifier)
        .signIn(
          devName: devName,
          confirmReplace: () async =>
              context.mounted &&
              await confirmDialog(
                context,
                title: l.replaceDataTitle,
                body: l.replaceDataBody,
                confirmLabel: l.replace,
                destructive: true,
              ),
          chooseJoin: (account, local) async {
            if (!context.mounted) return null;
            return showChoiceDialog<JoinChoice?>(
              context,
              title: l.joinTitle,
              body:
                  '${l.joinAccountSemesters(account.semesters)} '
                  '${l.joinLocalSemesters(local)}\n\n${l.joinQuestion}',
              choices: [
                DialogChoice(l.cancel, null),
                DialogChoice(l.joinKeepBoth, JoinChoice.keepBoth),
                DialogChoice(
                  l.joinUseAccount,
                  JoinChoice.useAccount,
                  primary: true,
                ),
              ],
            );
          },
          offerRestore: (deletedAt) async {
            if (!context.mounted) return false;
            final date = fmt.yearMonthDay(LocalDate.fromDateTime(deletedAt));
            return await showChoiceDialog<bool>(
                  context,
                  title: l.restoreDeletedTitle,
                  body: l.restoreDeletedBody(date),
                  choices: [
                    DialogChoice(l.startFresh, false),
                    DialogChoice(l.bringBack, true, primary: true),
                  ],
                ) ??
                false;
          },
        );
  } on PlatformException catch (e) {
    // Closing the browser isn't an error worth reporting.
    if (e.code != 'CANCELED') {
      messenger?.showSnackBar(SnackBar(content: Text(l.signInFailed)));
    }
  } on Object {
    messenger?.showSnackBar(SnackBar(content: Text(l.signInFailed)));
  }
  return SignInResult.cancelled;
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
    final auth = ref.watch(authProvider);
    if (auth.error is SessionUnreadable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(LecIcons.warning, color: theme.colorScheme.error),
            title: Text(l.signInUnreadableTitle),
            subtitle: Text(l.signInUnreadableBody),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => signIn(context, ref),
                  child: Text(l.signInAgain),
                ),
                FilledButton(
                  onPressed: () => ref.invalidate(authProvider),
                  child: Text(l.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final session = auth.value;
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
    final manual = ref.watch(manualSyncProvider);
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
            leading: SyncGlyph(state),
            title: Semantics(
              liveRegion: true,
              child: Text(manualSyncText(manual, state, l, fmt)),
            ),
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
                    onPressed: manual == ManualSync.running
                        ? null
                        : () => ref.read(manualSyncProvider.notifier).run(),
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
        // "Delete cloud data" keeps the data on the server for 30 days.
        if (ref.watch(accountSummaryProvider).value?.deletedAt
            case final deletedAt?)
          ListTile(
            leading: const Icon(LecIcons.restore),
            title: Text(l.restoreDeletedRow),
            subtitle: Text(
              l.restoreDeletedRowSubtitle(
                fmt.yearMonthDay(LocalDate.fromDateTime(deletedAt)),
                fmt.yearMonthDay(LocalDate.fromDateTime(deletedAt).addDays(30)),
              ),
            ),
            onTap: () => _restoreDeleted(context, ref, deletedAt),
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

  Future<void> _restoreDeleted(
    BuildContext context,
    WidgetRef ref,
    DateTime deletedAt,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await confirmDialog(
      context,
      title: l.restoreDeletedTitle,
      body: l.restoreDeletedBody(
        Fmt.of(context).yearMonthDay(LocalDate.fromDateTime(deletedAt)),
      ),
      confirmLabel: l.bringBack,
    );
    if (!ok) return;
    try {
      final restored = await ref.read(authProvider.notifier).restoreDeleted();
      messenger?.showSnackBar(
        SnackBar(content: Text(l.restoredCount(restored))),
      );
    } on Object catch (e) {
      debugPrint('Bringing back deleted data failed: $e');
      messenger?.showSnackBar(SnackBar(content: Text(l.accountActionFailed)));
    }
    ref.invalidate(accountSummaryProvider);
  }

  Future<void> _deleteCloud(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await confirmTypedDialog(
      context,
      title: l.deleteCloudTitle,
      body: l.deleteCloudBody,
      // In Hebrew too: the English word works without switching keyboards back.
      words: [l.deleteCloudWord, 'DELETE'],
      confirmLabel: l.delete,
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
/// Clicking it syncs now; right-click or long-press opens Settings.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).value;
    if (state == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final manual = ref.watch(manualSyncProvider);
    void openSettings() => context.push('/settings');
    return GestureDetector(
      onSecondaryTap: openSettings,
      onLongPress: openSettings,
      child: Tooltip(
        message: manualSyncText(manual, state, l, Fmt.of(context)),
        // Long-press opens Settings on touch screens.
        triggerMode: AppIdiom.usesTouch ? TooltipTriggerMode.manual : null,
        child: IconButton(
          onPressed: manual == ManualSync.running
              ? null
              : () => ref.read(manualSyncProvider.notifier).run(),
          icon: SyncGlyph(state),
        ),
      ),
    );
  }
}

/// The status line, with "Sync now"'s progress and result while they show.
String manualSyncText(
  ManualSync manual,
  SyncState state,
  AppLocalizations l,
  Fmt fmt,
) => switch (manual) {
  ManualSync.running => l.syncSyncing,
  ManualSync.done => l.syncUpToDate,
  ManualSync.failed => l.syncNowFailed,
  ManualSync.idle => syncStatusText(state, l, fmt),
};

/// The sync icon. It turns while syncing; after "Sync now" the cloud with
/// its check pops in, or the offline one. With reduced motion nothing turns
/// or bounces: the icons just change.
class SyncGlyph extends ConsumerWidget {
  const SyncGlyph(this.state, {super.key});

  final SyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final motion = AppMotion.of(context);
    const turning = Icon(LecIcons.syncing);
    final busy = motion.reduced ? turning : const _Turning(child: turning);
    final cloud = Icon(LecIcons.sync, color: colors.primary);
    final (String key, Widget icon) = switch (ref.watch(manualSyncProvider)) {
      ManualSync.running => ('busy', busy),
      ManualSync.done => ('cloud', cloud),
      ManualSync.failed => (
        'failed',
        Icon(LecIcons.syncOff, color: colors.error),
      ),
      ManualSync.idle => switch (state.phase) {
        SyncPhase.synced => ('cloud', cloud),
        SyncPhase.offline => (
          'offline',
          Icon(LecIcons.syncOff, color: colors.onSurfaceVariant),
        ),
        SyncPhase.connecting || SyncPhase.syncing => ('busy', busy),
      },
    };
    return AnimatedSwitcher(
      duration: motion.duration(const Duration(milliseconds: 350)),
      switchInCurve: motion.spatialFast,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(key), child: icon),
    );
  }
}

/// Keeps turning its child while shown.
class _Turning extends StatefulWidget {
  const _Turning({required this.child});

  final Widget child;

  @override
  State<_Turning> createState() => _TurningState();
}

class _TurningState extends State<_Turning>
    with SingleTickerProviderStateMixin {
  late final _turns = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _turns, child: widget.child);
}
