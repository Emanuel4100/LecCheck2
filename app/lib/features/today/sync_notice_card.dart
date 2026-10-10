import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/sync_providers.dart';
import '../../core/icons/lec_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/account_section.dart';

/// "Not now" on the sync notice: hidden until the app restarts.
final _dismissedProvider = NotifierProvider<_Dismissed, bool>(_Dismissed.new);

class _Dismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// On Today, when changes can't sync and only Settings → Account would say
/// so: signed out while this device still holds the account's data (its
/// edits queue up), refused changes, or a server that needs a newer app.
class SyncNoticeCard extends ConsumerWidget {
  const SyncNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syncConfiguredProvider) || ref.watch(_dismissedProvider)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final attached = ref.watch(attachedAccountProvider) != null;
    final counts = ref.watch(outboxCountsProvider).value;
    final state = ref.watch(syncStateProvider).value;
    if (auth.isLoading || counts == null) return const SizedBox.shrink();
    final signedIn = auth.value != null;

    final (
      IconData icon,
      String title,
      String subtitle,
      Widget? action,
    ) = switch (()) {
      _ when !signedIn && attached && counts.pending > 0 => (
        LecIcons.syncOff,
        l.syncSignedOutTitle,
        l.syncSignedOutBody(counts.pending),
        FilledButton(
          onPressed: () => signIn(context, ref),
          child: Text(l.signInWithGoogle),
        ),
      ),
      _ when signedIn && (state?.upgradeRequired ?? false) => (
        LecIcons.warning,
        l.upgradeRequired,
        l.syncFailedSubtitle,
        null,
      ),
      _ when signedIn && counts.refused > 0 => (
        LecIcons.warning,
        l.syncFailed(counts.refused),
        l.syncFailedSubtitle,
        FilledButton(
          onPressed: () => ref.read(syncEngineProvider)?.retryRejected(),
          child: Text(l.retry),
        ),
      ),
      _ => (LecIcons.sync, '', '', null),
    };
    if (title.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(subtitle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: ref.read(_dismissedProvider.notifier).dismiss,
                      child: Text(l.notNow),
                    ),
                    ?action,
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
