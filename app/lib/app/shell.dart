import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/lec_icons.dart';
import '../features/courses/course_actions.dart';
import '../features/settings/account_section.dart';
import '../features/week/week_page.dart';
import '../l10n/gen/app_localizations.dart';
import 'shortcuts.dart';
import 'sync_providers.dart';
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

    void sync() => ref.read(syncEngineProvider)?.syncNow();
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
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          onWeek(() => week.step(rtl ? 1 : -1)),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          onWeek(() => week.step(rtl ? -1 : 1)),
      const SingleActivator(LogicalKeyboardKey.pageUp): () =>
          onWeek(() => week.step(-1)),
      const SingleActivator(LogicalKeyboardKey.pageDown): () =>
          onWeek(() => week.step(1)),
      const SingleActivator(LogicalKeyboardKey.keyT): () =>
          onWeek(week.thisWeek),
      const SingleActivator(LogicalKeyboardKey.home): () =>
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
            for (final (icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    } else {
      final extended = size == WindowSize.large;
      scaffold = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 232,
              labelType: extended ? NavigationRailLabelType.none : null,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              groupAlignment: -1,
              leading: _RailHeader(extended: extended),
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: extended
                      ? AlignmentDirectional.bottomStart
                      : Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      12,
                      0,
                      12,
                      20,
                    ),
                    child: extended
                        ? TextButton.icon(
                            onPressed: () => context.push('/settings'),
                            icon: const Icon(LecIcons.settings),
                            label: Text(l.settings),
                          )
                        : IconButton(
                            tooltip: l.settings,
                            icon: const Icon(LecIcons.settings),
                            onPressed: () => context.push('/settings'),
                          ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: _shortcuts(context, ref),
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}

/// Logo (extended sidebar only) and the Add button.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final add = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: _AddMenuButton(extended: extended),
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

/// "Add" button that opens a menu: new course / one-time session.
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
