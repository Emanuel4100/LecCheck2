import 'package:material_ui/material_ui.dart';

import '../theme/motion.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 24, 12, 8),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motion = AppMotion.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: motion.slow,
              curve: motion.spatial,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Rounded vertical stripe in a course color.
class ColorBar extends StatelessWidget {
  const ColorBar({super.key, required this.color, this.height = 40});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// Width-based layout classes (Material window size classes). They decide the
/// layout; how the user interacts (touch, mouse, keyboard) is [AppIdiom].
enum WindowSize {
  compact,
  medium,
  expanded,
  large;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width < 600) return compact;
    if (width < 840) return medium;
    if (width < 1200) return expanded;
    return large;
  }

  /// Room for side-by-side panes (840 dp and up).
  bool get isWide => index >= expanded.index;
}

/// Centers a sliver at most [maxWidth] wide in whatever width it gets.
class SliverCentered extends StatelessWidget {
  const SliverCentered({
    super.key,
    required this.maxWidth,
    required this.sliver,
  });

  final double maxWidth;
  final Widget sliver;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final side = (constraints.crossAxisExtent - maxWidth) / 2;
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side > 0 ? side : 0),
        sliver: sliver,
      );
    },
  );
}

/// Box version of [SliverCentered].
class Centered extends StatelessWidget {
  const Centered({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Notes hold at most this many characters: one synced change may carry
/// 32 KB, and a longer note would be refused by the server every time.
const notesMaxLength = 10000;

/// The character count of a notes field, shown only near [notesMaxLength].
Widget? notesCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) => currentLength < notesMaxLength * 0.9
    ? null
    : Text('$currentLength / $maxLength');
