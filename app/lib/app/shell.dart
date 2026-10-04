import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/lec_icons.dart';
import '../l10n/gen/app_localizations.dart';
import 'widgets/common.dart';

/// Top-level navigation: bottom bar on phones, rail on tablets/desktop.
/// Tabs keep their state (scroll position, selected week) when switching.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell, required this.children});

  final StatefulNavigationShell shell;
  final List<Widget> children;

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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

    if (WindowSize.of(context) == WindowSize.compact) {
      return Scaffold(
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
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            groupAlignment: -0.85,
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
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: IconButton(
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
