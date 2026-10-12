import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../l10n/gen/app_localizations.dart';

/// After a sign-in that brought semesters from the account: which one to
/// open, or a new one. Signing in used to land on the setup form, which
/// added an empty semester to the account (issue #2).
class SemesterChoicePage extends ConsumerWidget {
  const SemesterChoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final semesters = ref.watch(semestersProvider).value ?? const [];
    final current = ref.watch(currentSemesterIdProvider);
    final today = LocalDate.today();

    void open(String id) {
      ref.read(activeSemesterChoiceProvider.notifier).select(id);
      context.go('/today');
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.chooseSemesterTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  l.chooseSemesterSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final s in semesters)
                ListTile(
                  leading: Icon(
                    s.id == current ? LecIcons.check : LecIcons.semester,
                    color: s.id == current ? theme.colorScheme.primary : null,
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    '${fmt.yearMonthDay(s.start)} – ${fmt.yearMonthDay(s.end)}',
                  ),
                  trailing: today.isWithin(s.start, s.end)
                      ? _NowBadge(label: l.semesterNow)
                      : null,
                  onTap: () => open(s.id),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(LecIcons.add),
                title: Text(l.startNewSemester),
                onTap: () => context.push('/semester?new=1'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowBadge extends StatelessWidget {
  const _NowBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
