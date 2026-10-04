import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/sync_providers.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/lec_logo.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/account_section.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  /// Signed in; waiting for the first sync to bring the account's data.
  bool _restoring = false;

  Future<void> _signIn({String? devName}) async {
    if (await signIn(context, ref, devName: devName) && mounted) {
      setState(() => _restoring = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A new account has nothing to restore: continue to semester setup. An
    // account with data gets semesters, and the router moves on to Today.
    ref.listen(syncStateProvider, (_, next) {
      if (!_restoring || next.value?.phase != SyncPhase.synced) return;
      if (ref.read(semestersProvider).value?.isEmpty ?? true) {
        setState(() => _restoring = false);
        context.push('/semester');
      }
    });
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final motion = AppMotion.of(context);
    final locale = ref.watch(appearanceProvider.select((a) => a.localeCode));
    final current = locale ?? Localizations.localeOf(context).languageCode;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'he', label: Text('עברית')),
                    ],
                    selected: {current == 'he' ? 'he' : 'en'},
                    onSelectionChanged: (s) => ref
                        .read(appearanceProvider.notifier)
                        .setLocale(s.first),
                  ),
                ),
                const SizedBox(height: 32),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: motion.slow,
                  curve: motion.spatial,
                  builder: (context, t, child) => Transform.scale(
                    scale: 0.6 + 0.4 * t,
                    child: Opacity(opacity: t.clamp(0, 1), child: child),
                  ),
                  child: const Center(child: LecLogo(size: 112)),
                ),
                const SizedBox(height: 32),
                Text(
                  l.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  l.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () => context.push('/semester'),
                  icon: const Icon(LecIcons.check),
                  label: Text(l.continueAsGuest),
                ),
                const SizedBox(height: 8),
                Text(
                  l.guestNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (_restoring)
                  Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(l.restoringData, textAlign: TextAlign.center),
                    ],
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: SyncConfig.enabled ? _signIn : null,
                    icon: const Icon(LecIcons.account),
                    label: Text(l.signInWithGoogle),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    SyncConfig.enabled ? l.syncHint : l.syncNotConfigured,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (SyncConfig.devAuth)
                    TextButton(
                      onPressed: () => _signIn(devName: 'dev'),
                      child: Text(l.devSignIn),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
