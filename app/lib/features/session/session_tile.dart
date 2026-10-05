import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import 'session_actions.dart';
import 'session_menu.dart';
import 'session_sheet.dart';
import 'status_buttons.dart';

/// One session as a card. Touch: swipe right = attended, left = missed
/// (physical directions, also in RTL), long-press opens the status picker.
/// Mouse: hovering a started session shows ✓ / ✗, right-click opens a menu.
/// Tap opens details. Watches only its own session, so marking one tile
/// rebuilds only it.
class SessionTile extends ConsumerWidget {
  const SessionTile({
    super.key,
    required this.sessionId,
    this.showDate = false,
    this.quickActions = false,
    this.highlight = false,
    this.onSwipeMarked,
  });

  final String sessionId;
  final bool showDate;

  /// Shows ✓ / ✗ buttons for pending sessions.
  final bool quickActions;
  final bool highlight;

  /// When set, a swipe dismisses the tile and calls this instead of marking
  /// in place (used by the "needs marking" queue).
  final void Function(Occurrence session, AttendanceStatus status)?
  onSwipeMarked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(sessionId));
    if (session == null) return const SizedBox.shrink();
    final course = ref.watch(courseProvider(session.courseId));
    final numbers = ref.watch(
      userPrefsProvider.select((p) => p.value?.meetingNumbers ?? true),
    );
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final tone = CourseColors.of(context).tone(course?.colorKey ?? 'ocean');
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final attendedDirection = rtl
        ? DismissDirection.endToStart
        : DismissDirection.startToEnd;
    final canceled = session.isCanceled;

    final details = joinDetails([
      sessionTitle(session, l, numbers: numbers),
      if (showDate) fmt.relativeDay(session.date, ref.watch(todayProvider), l),
      fmt.timeRange(session.startMin, session.endMin),
      session.location,
    ]);

    Widget card(bool hovered) => Card(
      color: highlight
          ? tone.container
          : canceled
          ? theme.colorScheme.surfaceContainerLowest
          : null,
      child: InkWell(
        onTap: () => showSessionSheet(context, session.id),
        onLongPress: () => showStatusPicker(context, ref, session),
        onSecondaryTapUp: (d) =>
            showSessionMenu(context, ref, session, d.globalPosition),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 8, 12),
          child: Row(
            children: [
              ColorBar(color: tone.accent, height: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          session.type.icon,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            course?.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              decoration: canceled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (session.isMoved) ...[
                          const SizedBox(width: 6),
                          Icon(
                            LecIcons.moved,
                            size: 16,
                            color: theme.colorScheme.tertiary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (session.status == AttendanceStatus.pending &&
                  (quickActions ||
                      (hovered && session.hasStarted(DateTime.now()))))
                ..._quickButtons(context, ref, session, l)
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
                  child: Tooltip(
                    message: statusLabel(session, l),
                    child: StatusIndicator(status: session.status),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // A mouse drag is not a swipe: desktop marks through hover and menus.
    if (AppIdiom.isDesktop) {
      return HoverBuilder(builder: (context, hovered) => card(hovered));
    }

    return Dismissible(
      key: ValueKey('swipe-${session.id}'),
      direction: canceled ? DismissDirection.none : DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.3,
      },
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          HapticFeedback.selectionClick();
        }
      },
      confirmDismiss: (direction) async {
        final status = direction == attendedDirection
            ? AttendanceStatus.attended
            : AttendanceStatus.missed;
        if (onSwipeMarked != null) {
          onSwipeMarked!(session, status);
          return true;
        }
        await markSession(context, ref, session, status);
        return false;
      },
      background: _SwipeBackground(
        status: rtl ? AttendanceStatus.missed : AttendanceStatus.attended,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        status: rtl ? AttendanceStatus.attended : AttendanceStatus.missed,
        alignment: Alignment.centerRight,
      ),
      child: card(false),
    );
  }

  List<Widget> _quickButtons(
    BuildContext context,
    WidgetRef ref,
    Occurrence session,
    AppLocalizations l,
  ) {
    final status = StatusColors.of(context);
    Widget button(AttendanceStatus s) => IconButton.filledTonal(
      tooltip: s.action(l),
      style: IconButton.styleFrom(
        backgroundColor: status[s].container,
        foregroundColor: status[s].onContainer,
      ),
      onPressed: () => onSwipeMarked != null
          ? onSwipeMarked!(session, s)
          : markSession(context, ref, session, s),
      icon: Icon(s.icon),
    );
    return [
      const SizedBox(width: 4),
      button(AttendanceStatus.missed),
      button(AttendanceStatus.attended),
    ];
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.status, required this.alignment});

  final AttendanceStatus status;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final tones = StatusColors.of(context)[status];
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tones.container,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          Icon(status.icon, color: tones.accent),
          const SizedBox(width: 8),
          Text(
            status.action(l),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: tones.onContainer),
          ),
        ],
      ),
    );
  }
}

/// Every status as buttons, opened by long-press: a bottom sheet on phones,
/// a dialog on tablets.
Future<void> showStatusPicker(
  BuildContext context,
  WidgetRef ref,
  Occurrence session,
) {
  final l = AppLocalizations.of(context);
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.status, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 16),
            StatusButtonGroup(
              selected: session.explicitStatus,
              onSelected: (status) {
                Navigator.pop(sheetContext);
                markSession(context, ref, session, status);
              },
            ),
            if (session.explicitStatus != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  ref.read(repositoryProvider).setStatus(session, null);
                },
                icon: const Icon(LecIcons.pending),
                label: Text(l.clearStatus),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Fades and slides list items in the first time they appear.
class AppearIn extends StatelessWidget {
  const AppearIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.medium + Duration(milliseconds: 30 * index.clamp(0, 8)),
      curve: motion.spatial,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
