import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../core/icons/lec_icons.dart';
import '../../l10n/gen/app_localizations.dart';
import '../courses/course_actions.dart';
import 'tour_controller.dart';

/// What one step shows: the tab to open, what to point at, and the text.
typedef _Step = ({int? branch, GlobalKey? target, String title, String body});

/// The app tour (issue #1): dims the app except for the item a step is about
/// and explains it in a card, step by step, ending at the button that adds
/// the first course. Sits above the shell (navigation bar and rail
/// included); empty while no tour runs.
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key, required this.goBranch});

  /// Opens a tab, so its items can be shown.
  final void Function(int index) goBranch;

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'tour');

  /// Follows the target every frame while a tour runs: tabs fade in, phones
  /// rotate, windows resize.
  late final Ticker _ticker = createTicker((_) => _measure());

  /// Where the target is, in this overlay; null while it can't be found.
  Rect? _hole;
  GlobalKey? _target;
  TourStep? _opened;

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _measure() {
    final box = _target?.currentContext?.findRenderObject();
    final overlay = context.findRenderObject();
    Rect? rect;
    if (box is RenderBox &&
        box.attached &&
        box.hasSize &&
        overlay is RenderBox &&
        overlay.hasSize) {
      rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    }
    if (rect != _hole) setState(() => _hole = rect);
  }

  _Step _step(TourStep step, AppLocalizations l, bool compact, bool courses) {
    final destinations = TourTargets.destinations;
    return switch (step) {
      TourStep.welcome => (
        branch: null,
        target: null,
        title: l.tourWelcomeTitle,
        body: l.tourWelcomeBody,
      ),
      TourStep.today => (
        branch: 0,
        target: destinations[0],
        title: l.navToday,
        body: l.tourTodayBody,
      ),
      TourStep.week => (
        branch: 1,
        target: destinations[1],
        title: l.navWeek,
        body: l.tourWeekBody,
      ),
      TourStep.courses => (
        branch: 2,
        target: destinations[2],
        title: l.navCourses,
        body: l.tourCoursesBody,
      ),
      TourStep.stats => (
        branch: 3,
        target: destinations[3],
        title: l.navStats,
        body: l.tourStatsBody,
      ),
      // On phones the gear is in Today's app bar.
      TourStep.settings => (
        branch: compact ? 0 : null,
        target: TourTargets.settings,
        title: l.settings,
        body: l.tourSettingsBody,
      ),
      TourStep.add when !courses => (
        branch: 0,
        target: TourTargets.addFirst,
        title: l.tourAddTitle,
        body: l.tourAddBody,
      ),
      TourStep.add => (
        branch: compact ? 2 : null,
        target: compact ? TourTargets.addFab : TourTargets.addRail,
        title: l.tourAddMoreTitle,
        body: l.tourAddMoreBody,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(tourProvider);
    if (step == null) {
      if (_ticker.isActive) _ticker.stop();
      _hole = _target = _opened = null;
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final compact = WindowSize.of(context) == WindowSize.compact;
    final courses = ref.watch(coursesProvider).items.isNotEmpty;
    final spec = _step(step, l, compact, courses);
    _target = spec.target;
    if (_opened != step) {
      _opened = step;
      final branch = spec.branch;
      // Not while building: opening a tab rebuilds the shell.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (branch != null) widget.goBranch(branch);
        _focus.requestFocus();
      });
    }
    if (!_ticker.isActive) _ticker.start();

    final controller = ref.read(tourProvider.notifier);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final last = step == TourStep.values.last;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): controller.finish,
        const SingleActivator(LogicalKeyboardKey.enter): controller.next,
        const SingleActivator(LogicalKeyboardKey.arrowRight): rtl
            ? controller.back
            : controller.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): rtl
            ? controller.next
            : controller.back,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) => _Spotlight(
            hole: _hole,
            size: constraints.biggest,
            card: _TourCard(
              step: step,
              title: spec.title,
              body: spec.body,
              onSkip: controller.finish,
              onBack: step.index > 1 ? controller.back : null,
              onNext: controller.next,
              // The first course: straight to the editor.
              onAdd: last && !courses
                  ? () {
                      controller.finish();
                      addCourse(context);
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dims everything but [hole], and puts [card] beside it (above when the
/// hole is in the lower half, below otherwise, centered without a hole).
/// Takes every tap, so the tour moves on only from its card.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.hole,
    required this.size,
    required this.card,
  });

  final Rect? hole;
  final Size size;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = AppMotion.of(context);
    const gutter = 16.0;
    final width = math.min(size.width - 2 * gutter, 400.0);
    // Room around the target, so small icons get a comfortable circle.
    final target = hole?.inflate(8);
    final double left = target == null
        ? (size.width - width) / 2
        : (target.center.dx - width / 2)
              .clamp(gutter, math.max(gutter, size.width - width - gutter))
              .toDouble();
    final below = target != null && target.center.dy < size.height / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: TweenAnimationBuilder<Rect?>(
              // Without a target the hole closes to a point (all dimmed).
              tween: RectTween(
                end:
                    target ??
                    Rect.fromCenter(
                      center: size.center(Offset.zero),
                      width: 0,
                      height: 0,
                    ),
              ),
              duration: motion.medium,
              curve: motion.spatial,
              builder: (context, rect, _) => CustomPaint(
                painter: _SpotlightPainter(
                  hole: rect,
                  scrim: theme.colorScheme.scrim.withValues(alpha: 0.6),
                  ring: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: motion.medium,
          curve: motion.spatial,
          left: left,
          width: width,
          top: target == null
              ? null
              : below
              ? math.min(target.bottom + gutter, size.height - gutter)
              : null,
          bottom: target == null
              ? null
              : below
              ? null
              : math.max(size.height - target.top + gutter, gutter),
          child: target == null
              ? SizedBox(
                  height: size.height,
                  child: Center(child: card),
                )
              : card,
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.scrim,
    required this.ring,
  });

  final Rect? hole;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole == null || hole.isEmpty) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }
    final shape = RRect.fromRectAndRadius(
      hole,
      Radius.circular(math.min(hole.shortestSide / 2, 24)),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, Path()..addRRect(shape)),
      Paint()..color = scrim,
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.scrim != scrim || old.ring != ring;
}

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.step,
    required this.title,
    required this.body,
    required this.onSkip,
    required this.onNext,
    this.onBack,
    this.onAdd,
  });

  final TourStep step;
  final String title;
  final String body;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  /// "Add course" on the last step, while there are none.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = step == TourStep.values.first;
    final last = step == TourStep.values.last;
    // The welcome card isn't counted: "1 of 6" is Today.
    final total = TourStep.values.length - 1;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        // No shadow: the dimmed app around it sets it apart.
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8),
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                  ),
                  if (!first)
                    IconButton(
                      tooltip: last ? l.close : l.skip,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LecIcons.close),
                      onPressed: onSkip,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Text(body, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!first)
                    Semantics(
                      label: l.tourStepOf(step.index, total),
                      child: ExcludeSemantics(
                        child: _Dots(index: step.index - 1, count: total),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    // Stacks the buttons when they don't fit side by side
                    // (narrow phones, long Hebrew labels).
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 4,
                      children: [
                        if (first)
                          TextButton(onPressed: onSkip, child: Text(l.skip)),
                        if (onBack != null)
                          TextButton(onPressed: onBack, child: Text(l.back)),
                        if (onAdd != null)
                          FilledButton(
                            onPressed: onAdd,
                            child: Text(l.addCourse),
                          )
                        else
                          FilledButton(
                            onPressed: onNext,
                            child: Text(
                              first
                                  ? l.tourStart
                                  : last
                                  ? l.done
                                  : l.next,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = AppMotion.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: motion.fast,
            margin: const EdgeInsetsDirectional.only(end: 4),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
