import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/lec_icons.dart';
import '../features/courses/course_actions.dart';
import '../features/settings/account_section.dart';
import '../features/tour/tour_controller.dart';
import '../features/tour/tour_overlay.dart';
import '../features/week/mini_calendar.dart';
import '../features/week/week_page.dart';
import '../l10n/gen/app_localizations.dart';
import 'adaptive.dart';
import 'shortcuts.dart';
import 'sync_providers.dart';
import 'theme/motion.dart';
import 'widgets/common.dart';
import 'widgets/lec_logo.dart';

/// Top-level navigation: bottom bar on phones, a rail with an Add button on
/// medium/expanded windows, an extended sidebar on large ones. Tabs keep their
/// state (scroll position, selected week) when switching. Also owns the
/// app-wide keyboard shortcuts.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  Map<ShortcutActivator, VoidCallback> _shortcuts(
    BuildContext context,
    WidgetRef ref,
  ) {
    final week = ref.read(weekCommandsProvider);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void onWeek(void Function() action) {
      if (shell.currentIndex == 1 && !isTyping) action();
    }

    void sync() => ref.read(manualSyncProvider.notifier).run();
    void help() => showShortcutsHelp(context);
    void zoomIn() => onWeek(() => week.zoom(1.15));
    void zoomOut() => onWeek(() => week.zoom(1 / 1.15));

    return {
      for (final (i, key) in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ].indexed)
        primaryKey(key): () => shell.goBranch(i),
      primaryKey(LogicalKeyboardKey.comma): () => context.push('/settings'),
      primaryKey(LogicalKeyboardKey.keyN): () => addCourse(context),
      primaryKey(LogicalKeyboardKey.keyN, shift: true): () =>
          addOneTimeSession(context, ref),
      primaryKey(LogicalKeyboardKey.keyF): () => context.go('/today/sessions'),
      primaryKey(LogicalKeyboardKey.keyR): sync,
      const SingleActivator(LogicalKeyboardKey.f5): sync,
      const SingleActivator(LogicalKeyboardKey.f1): help,
      primaryKey(LogicalKeyboardKey.slash): help,
      // Week view. Arrows follow the screen: in Hebrew, left is "next".
      const UnlessTyping(SingleActivator(LogicalKeyboardKey.arrowLeft)): () =>
          onWeek(() => week.step(rtl ? 1 : -1)),
      const UnlessTyping(SingleActivator(LogicalKeyboardKey.arrowRight)): () =>
          onWeek(() => week.step(rtl ? -1 : 1)),
      const UnlessTyping(SingleActivator(LogicalKeyboardKey.pageUp)): () =>
          onWeek(() => week.step(-1)),
      const UnlessTyping(SingleActivator(LogicalKeyboardKey.pageDown)): () =>
          onWeek(() => week.step(1)),
      const UnlessTyping(SingleActivator(LogicalKeyboardKey.keyT)): () =>
          onWeek(week.thisWeek),
      const UnlessTyping(SingleActivator(LogicalKeyboardKey.home)): () =>
          onWeek(week.thisWeek),
      primaryKey(LogicalKeyboardKey.equal): zoomIn,
      primaryKey(LogicalKeyboardKey.equal, shift: true): zoomIn,
      primaryKey(LogicalKeyboardKey.numpadAdd): zoomIn,
      primaryKey(LogicalKeyboardKey.minus): zoomOut,
      primaryKey(LogicalKeyboardKey.numpadSubtract): zoomOut,
      primaryKey(LogicalKeyboardKey.digit0): () => onWeek(() => week.zoom(0)),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final size = WindowSize.of(context);
    final destinations = [
      (LecIcons.today, LecIcons.todayFilled, l.navToday),
      (LecIcons.week, LecIcons.weekFilled, l.navWeek),
      (LecIcons.courses, LecIcons.coursesFilled, l.navCourses),
      (LecIcons.stats, LecIcons.statsFilled, l.navStats),
    ];
    final body = _FadeThroughStack(
      index: shell.currentIndex,
      children: children,
    );

    final Widget scaffold;
    if (size == WindowSize.compact) {
      scaffold = Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final (i, (icon, selected, label)) in destinations.indexed)
              NavigationDestination(
                icon: _tourTarget(i, Icon(icon)),
                selectedIcon: _tourTarget(i, Icon(selected)),
                label: label,
              ),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        body: Row(
          children: [
            AppRail(selectedIndex: shell.currentIndex, onSelected: _go),
            Expanded(child: body),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: _shortcuts(context, ref),
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            scaffold,
            Positioned.fill(child: TourOverlay(goBranch: shell.goBranch)),
          ],
        ),
      ),
    );
  }

  /// The tour points at navigation item [i]. Only the selected or the
  /// unselected icon is built at a time, so they can share the key.
  static Widget _tourTarget(int i, Widget icon) =>
      KeyedSubtree(key: TourTargets.destinations[i], child: icon);
}

/// The tabs' paths, in rail order.
const tabPaths = ['/today', '/week', '/courses', '/stats'];

/// The navigation rail of medium and wider windows (a sidebar with the logo
/// on large ones): Add, the tabs, Settings at the bottom. Settings shows it
/// too ([inSettings]), so the window keeps its layout there.
class AppRail extends ConsumerWidget {
  const AppRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.inSettings = false,
  });

  /// The tab shown; null in Settings.
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final bool inSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final extended = WindowSize.of(context) == WindowSize.large;
    final destinations = [
      (LecIcons.today, LecIcons.todayFilled, l.navToday),
      (LecIcons.week, LecIcons.weekFilled, l.navWeek),
      (LecIcons.courses, LecIcons.coursesFilled, l.navCourses),
      (LecIcons.stats, LecIcons.statsFilled, l.navStats),
    ];
    // The tour's keys belong to the shell's rail (Settings' copy is shown
    // over it, and keys are unique).
    Widget target(GlobalKey key, Widget child) =>
        inSettings ? child : KeyedSubtree(key: key, child: child);
    void openSettings() {
      if (!inSettings) context.push('/settings');
    }

    final settingsIcon = Icon(
      inSettings ? LecIcons.settingsFilled : LecIcons.settings,
    );
    final settings = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 20),
      child: target(
        TourTargets.settings,
        extended
            ? (inSettings
                  ? FilledButton.tonalIcon(
                      onPressed: openSettings,
                      icon: settingsIcon,
                      label: Text(l.settings),
                    )
                  : TextButton.icon(
                      onPressed: openSettings,
                      icon: settingsIcon,
                      label: Text(l.settings),
                    ))
            : inSettings
            ? IconButton.filledTonal(
                tooltip: l.settings,
                icon: settingsIcon,
                onPressed: openSettings,
              )
            : IconButton(
                tooltip: l.settings,
                icon: settingsIcon,
                onPressed: openSettings,
              ),
      ),
    );
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 232,
      labelType: extended ? NavigationRailLabelType.none : null,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      groupAlignment: -1,
      leading: _RailHeader(extended: extended, tourKeys: !inSettings),
      destinations: [
        for (final (i, (icon, selected, label)) in destinations.indexed)
          NavigationRailDestination(
            icon: target(TourTargets.destinations[i], Icon(icon)),
            selectedIcon: target(TourTargets.destinations[i], Icon(selected)),
            label: Text(label),
          ),
      ],
      trailing: Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: extended
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              // The month, when the sidebar is wide and tall enough for it.
              if (extended && constraints.maxHeight > MiniCalendar.height + 96)
                SizedBox(
                  width: 232,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: MiniCalendar(
                      onShowDate: (date) {
                        ref.read(weekCommandsProvider).showDate(date);
                        onSelected(1);
                      },
                    ),
                  ),
                ),
              const Spacer(),
              settings,
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo (extended sidebar only) and the Create (desktop) or Add button.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended, required this.tourKeys});

  final bool extended;
  final bool tourKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final add = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: KeyedSubtree(
        key: tourKeys ? TourTargets.addRail : null,
        child: _AddMenuButton(extended: extended),
      ),
    );
    if (!extended) return add;
    return SizedBox(
      width: 232,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LecLogo(size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'LecCheck',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SyncIndicator(),
              ],
            ),
            add,
          ],
        ),
      ),
    );
  }
}

/// The button that opens a menu: new course / one-time session. On desktop
/// it's Google Calendar's raised "Create" pill (an icon on a narrow rail);
/// on tablets a floating Add button.
class _AddMenuButton extends ConsumerWidget {
  const _AddMenuButton({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LecIcons.courses),
          onPressed: () => addCourse(context),
          child: Text(l.addCourse),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LecIcons.date),
          onPressed: () => addOneTimeSession(context, ref),
          child: Text(l.addOneTimeSession),
        ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (AppIdiom.isDesktop) {
          return extended
              ? _CreatePill(onPressed: toggle)
              : IconButton.filledTonal(
                  tooltip: l.create,
                  onPressed: toggle,
                  icon: const Icon(LecIcons.add),
                );
        }
        return extended
            ? FloatingActionButton.extended(
                heroTag: 'rail-add',
                elevation: 0,
                onPressed: toggle,
                icon: const Icon(LecIcons.add),
                label: Text(l.add),
              )
            : FloatingActionButton(
                heroTag: 'rail-add',
                elevation: 0,
                tooltip: l.add,
                onPressed: toggle,
                child: const Icon(LecIcons.add),
              );
      },
    );
  }
}

/// IndexedStack whose newly selected child fades and scales in (Material
/// "fade through"). Every branch keeps the same widget structure, so tab state
/// survives switching; inactive tabs stop ticking.
class _FadeThroughStack extends StatelessWidget {
  const _FadeThroughStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (var i = 0; i < children.length; i++)
        Offstage(
          offstage: i != index,
          child: TickerMode(
            enabled: i == index,
            child: _BranchFade(active: i == index, child: children[i]),
          ),
        ),
    ],
  );
}

class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.active ? 1 : 0,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final _scale = Tween(begin: 0.97, end: 1.0).animate(_curve);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.of(context)
        .duration(const Duration(milliseconds: 280));
  }

  @override
  void didUpdateWidget(_BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

/// "+ Create ▾", raised above the sidebar like Google Calendar's.
class _CreatePill extends StatelessWidget {
  const _CreatePill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppIdiom.radius(26)),
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.4),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 16, 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LecIcons.add, size: 24, color: scheme.primary),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).create,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(LecIcons.expand, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
