import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/labels.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
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
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
