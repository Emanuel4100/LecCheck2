import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/lec_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../features/settings/account_section.dart';
import 'common.dart';

/// Collapsing Material 3 app bar used by every tab. On phones it carries the
/// settings button; wider layouts have settings in the navigation rail.
class TabAppBar extends StatelessWidget {
  const TabAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final compact = WindowSize.of(context) == WindowSize.compact;
    return SliverAppBar.medium(
      title: Text(title),
      actions: [
        ...actions,
        const SyncIndicator(),
        if (compact)
          IconButton(
            tooltip: AppLocalizations.of(context).settings,
            icon: const Icon(LecIcons.settings),
            onPressed: () => context.push('/settings'),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}
