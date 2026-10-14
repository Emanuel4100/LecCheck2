import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/lec_icons.dart';
import '../adaptive.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../features/settings/account_section.dart';
import 'common.dart';

/// The app bar of every tab: collapsing (Material 3 medium) on touch
/// screens, a compact title bar on desktop. On phones it carries the
/// settings button; wider layouts have settings in the navigation rail, and
/// the large sidebar also shows the sync status.
class TabAppBar extends StatelessWidget {
  const TabAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.settingsKey,
  });

  final String title;
  final List<Widget> actions;

  /// On the phone's settings button, for the app tour (one tab only: keys
  /// are unique).
  final GlobalKey? settingsKey;

  @override
  Widget build(BuildContext context) {
    final size = WindowSize.of(context);
    final compact = size == WindowSize.compact;
    final buttons = [
      ...actions,
      if (size != WindowSize.large) const SyncIndicator(),
      if (compact)
        KeyedSubtree(
          key: settingsKey,
          child: IconButton(
            tooltip: AppLocalizations.of(context).settings,
            icon: const Icon(LecIcons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ),
      const SizedBox(width: 4),
    ];
    return AppIdiom.isDesktop
        ? DesktopAppBar(title: title, actions: buttons)
        : SliverAppBar.medium(title: Text(title), actions: buttons);
  }
}

/// A desktop title bar: one line, pinned, the title at toolbar size.
class DesktopAppBar extends StatelessWidget {
  const DesktopAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => SliverAppBar(
    pinned: true,
    toolbarHeight: 60,
    leading: leading,
    // Lined up with the content, unless a back button comes first.
    titleSpacing:
        leading == null &&
            !(ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
        ? 24
        : null,
    title: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
    actions: actions,
  );
}
