import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/labels.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

/// Statuses offered as buttons, in order of how often they're used.
const markableStatuses = [
  AttendanceStatus.attended,
  AttendanceStatus.missed,
  AttendanceStatus.watched,
  AttendanceStatus.skipped,
  AttendanceStatus.canceled,
];

/// Material 3 Expressive connected button group: the selected button morphs
/// to a full pill and fills with its status color.
class StatusButtonGroup extends StatelessWidget {
  const StatusButtonGroup({
    super.key,
    required this.selected,
    required this.onSelected,
    this.statuses = markableStatuses,
    this.unselectedColor,
  });

  final AttendanceStatus? selected;
  final ValueChanged<AttendanceStatus> onSelected;
  final List<AttendanceStatus> statuses;

  /// Background of unselected buttons (e.g. a translucent tint on colored
  /// cards). Defaults to the surface container color.
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        for (var i = 0; i < statuses.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: _StatusButton(
              status: statuses[i],
              label: statuses[i].action(l),
              selected: selected == statuses[i],
              first: i == 0,
              last: i == statuses.length - 1,
              unselectedColor: unselectedColor,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(statuses[i]);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.label,
    required this.selected,
    required this.first,
    required this.last,
    required this.onTap,
    this.unselectedColor,
  });

  final AttendanceStatus status;
  final Color? unselectedColor;
  final String label;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = StatusColors.of(context)[status];
    final motion = AppMotion.of(context);
    const outer = Radius.circular(24);
    const inner = Radius.circular(8);
    final radius = selected
        ? const BorderRadius.all(outer)
        : BorderRadiusDirectional.horizontal(
            start: first ? outer : inner,
            end: last ? outer : inner,
          ).resolve(Directionality.of(context));
    final foreground = selected
        ? tones.onContainer
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: AnimatedContainer(
        duration: motion.medium,
        curve: motion.spatialFast,
        height: 64,
        decoration: BoxDecoration(
          color: selected
              ? tones.container
              : unselectedColor ?? theme.colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: selected ? 1.15 : 1,
                  duration: motion.medium,
                  curve: motion.spatial,
                  child: Icon(
                    status.icon,
                    size: 22,
                    color: selected ? tones.accent : foreground,
                  ),
                ),
                const SizedBox(height: 4),
                // A long label shrinks to fit instead of losing its ends.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marking one session, quietly: a neutral button for what's usually meant
/// (Attended) and a small arrow with every status. Once marked it shows the
/// status, in its color, and opens the same menu to change it.
class MarkButton extends StatelessWidget {
  const MarkButton({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onClear,
    this.compact = false,
    this.background,
    this.foreground,
  });

  final AttendanceStatus? selected;
  final ValueChanged<AttendanceStatus> onSelected;

  /// Offers "Clear status" in the menu while something is selected.
  final VoidCallback? onClear;

  /// Icon only, for a row in a list.
  final bool compact;

  /// Colors while unmarked (e.g. to sit on a colored card). Default to the
  /// surface container's.
  final Color? background;
  final Color? foreground;

  Future<void> _openMenu(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final colors = StatusColors.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final button = context.findRenderObject()! as RenderBox;
    final bottom = button.localToGlobal(
      button.size.bottomLeft(Offset.zero),
      ancestor: overlay,
    );
    final choice = await showMenu<AttendanceStatus>(
      context: context,
      position: RelativeRect.fromRect(
        bottom & Size(button.size.width, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final status in markableStatuses)
          PopupMenuItem(
            value: status,
            child: Row(
              children: [
                Icon(status.icon, size: 20, color: colors[status].accent),
                const SizedBox(width: 12),
                Expanded(child: Text(status.action(l))),
                if (status == selected) const Icon(LecIcons.check, size: 18),
              ],
            ),
          ),
        if (selected != null && onClear != null)
          PopupMenuItem(
            value: AttendanceStatus.pending,
            child: Row(
              children: [
                const Icon(LecIcons.pending, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(l.clearStatus)),
              ],
            ),
          ),
      ],
    );
    if (choice == null) return;
    HapticFeedback.selectionClick();
    if (choice == AttendanceStatus.pending) {
      onClear?.call();
    } else {
      onSelected(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final marked = selected;
    final tones = marked == null ? null : StatusColors.of(context)[marked];
    final fill =
        tones?.container ?? background ?? scheme.surfaceContainerHighest;
    final ink = tones?.onContainer ?? foreground ?? scheme.onSurfaceVariant;
    final shown = marked ?? AttendanceStatus.attended;
    final height = compact ? 40.0 : 44.0;

    Widget part({
      required VoidCallback onTap,
      required BorderRadiusGeometry radius,
      required Widget child,
    }) => Material(
      color: fill,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: height, child: child),
      ),
    );

    const outer = Radius.circular(20);
    const inner = Radius.circular(4);
    final main = part(
      radius: const BorderRadiusDirectional.horizontal(
        start: outer,
        end: inner,
      ),
      onTap: () {
        if (marked != null) {
          _openMenu(context);
          return;
        }
        HapticFeedback.selectionClick();
        onSelected(AttendanceStatus.attended);
      },
      child: compact
          ? SizedBox(
              width: 44,
              child: Icon(shown.icon, size: 22, color: tones?.accent ?? ink),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(shown.icon, size: 20, color: tones?.accent ?? ink),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    shown.action(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: ink),
                  ),
                ),
              ],
            ),
    );
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (compact)
            Tooltip(message: shown.action(l), child: main)
          else
            Expanded(child: main),
          const SizedBox(width: 2),
          Tooltip(
            message: l.moreOptions,
            child: part(
              radius: const BorderRadiusDirectional.horizontal(
                start: inner,
                end: outer,
              ),
              onTap: () => _openMenu(context),
              child: SizedBox(
                width: compact ? 28 : 40,
                child: Icon(LecIcons.expand, size: 20, color: ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small round status badge that animates between statuses.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.status, this.size = 28});

  final AttendanceStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = StatusColors.of(context)[status];
    final motion = AppMotion.of(context);
    return AnimatedSwitcher(
      duration: motion.medium,
      switchInCurve: motion.spatial,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(
        status.icon,
        key: ValueKey(status),
        size: size,
        color: status == AttendanceStatus.pending
            ? Theme.of(context).colorScheme.outline
            : tones.accent,
      ),
    );
  }
}
