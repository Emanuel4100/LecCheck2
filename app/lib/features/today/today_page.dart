import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/tab_app_bar.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import '../settings/reminder_access.dart';
import '../settings/update_card.dart';
import '../session/session_menu.dart';
import '../session/session_sheet.dart';
import '../session/session_tile.dart';
import '../session/status_buttons.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final today = ref.watch(todayProvider);
    final hasCourses = ref.watch(
      coursesProvider.select((c) => c.items.isNotEmpty),
    );
    final loaded = ref.watch(semesterDataProvider.select((d) => d.hasValue));
    final allSessions = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: OutlinedButton.icon(
          onPressed: () => context.push('/today/sessions'),
          icon: const Icon(LecIcons.search),
          label: Text(l.allSessions),
        ),
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          TabAppBar(title: fmt.longDate(today)),
          if (!loaded)
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else if (!hasCourses)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: LecIcons.courses,
                title: l.noCoursesYet,
                subtitle: l.addCourseFirst,
                action: FilledButton.icon(
                  onPressed: () => context.push('/course-editor'),
                  icon: const Icon(LecIcons.add),
                  label: Text(l.addCourse),
                ),
              ),
            )
          else if (WindowSize.of(context).isWide)
            // Two columns: what to do now | the schedule.
            SliverCentered(
              maxWidth: 1400,
              sliver: SliverCrossAxisGroup(
                slivers: [
                  SliverCrossAxisExpanded(
                    flex: 5,
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        const SliverToBoxAdapter(child: RemindersBlockedCard()),
                        const SliverToBoxAdapter(
                          child: UpdateCard(onToday: true),
                        ),
                        const SliverToBoxAdapter(
                          child: UpdateCard(onToday: true),
                        ),
                        const SliverToBoxAdapter(child: _WeekProgress()),
                        const SliverToBoxAdapter(child: _NowNextCard()),
                        const _NeedsMarkingSection(),
                        allSessions,
                      ],
                    ),
                  ),
                  const SliverCrossAxisExpanded(
                    flex: 4,
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        _TodayTimeline(),
                        _ComingUp(),
                        SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            SliverCentered(
              maxWidth: 720,
              sliver: SliverMainAxisGroup(
                slivers: [
                  const SliverToBoxAdapter(child: RemindersBlockedCard()),
                  const SliverToBoxAdapter(child: _WeekProgress()),
                  const SliverToBoxAdapter(child: _NowNextCard()),
                  const _NeedsMarkingSection(),
                  const _TodayTimeline(),
                  const _ComingUp(),
                  allSessions,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekProgress extends ConsumerWidget {
  const _WeekProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(calendarProvider);
    if (calendar == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final week = calendar.weekNumberOf(today);
    final total = calendar.weekCount;
    final label = week < 1
        ? l.beforeSemester(fmt.dayMonth(calendar.semester.start))
        : week > total
        ? l.afterSemester
        : l.weekOfTotal(week, total);
    final progress = calendar.progressAt(today);
    final motion = AppMotion.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                calendar.semester.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: motion.slow,
            curve: motion.spatialSlow,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: value, minHeight: 8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero card: the session in progress or the next one, with a countdown.
class _NowNextCard extends ConsumerWidget {
  const _NowNextCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(nowNextProvider);
    final session = id == null ? null : ref.watch(sessionProvider(id));
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final motion = AppMotion.of(context);

    return AnimatedSwitcher(
      duration: motion.medium,
      switchInCurve: motion.spatial,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: session == null
          ? Padding(
              key: const ValueKey('none'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        LecIcons.celebrate,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l.noUpcoming,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _HeroSession(key: ValueKey(session.id), session: session),
    );
  }
}

class _HeroSession extends ConsumerWidget {
  const _HeroSession({super.key, required this.session});

  final Occurrence session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final course = ref.watch(courseProvider(session.courseId));
    final meeting = ref.watch(meetingProvider(session.meetingId));
    final numbers = ref.watch(
      userPrefsProvider.select((p) => p.value?.meetingNumbers ?? true),
    );
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final today = ref.watch(todayProvider);
    final tone = CourseColors.of(context).tone(course?.colorKey ?? 'ocean');
    final inProgress = session.isInProgress(now);
    final countdown = inProgress
        ? l.endsIn(formatDuration(session.end.difference(now), l))
        : l.startsIn(formatDuration(session.start.difference(now), l));
    final link =
        meeting?.links.firstOrNull?.url ?? course?.links.firstOrNull?.url;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: tone.container,
        child: InkWell(
          onTap: () => showSessionSheet(context, session.id),
          onSecondaryTapUp: (d) =>
              showSessionMenu(context, ref, session, d.globalPosition),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tone.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        inProgress ? l.nowLabel : l.nextLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        countdown,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: tone.onContainer,
                        ),
                      ),
                    ),
                    Icon(session.type.icon, color: tone.onContainer),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  course?.name ?? '',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: tone.onContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  joinDetails([
                    sessionTitle(session, l, numbers: numbers),
                    if (session.date != today)
                      fmt.relativeDay(session.date, today, l),
                    fmt.timeRange(session.startMin, session.endMin),
                    session.location,
                  ]),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: tone.onContainer,
                  ),
                ),
                if (inProgress || link != null) ...[
                  const SizedBox(height: 16),
                  if (inProgress)
                    StatusButtonGroup(
                      selected: session.explicitStatus,
                      statuses: const [
                        AttendanceStatus.attended,
                        AttendanceStatus.missed,
                        AttendanceStatus.watched,
                      ],
                      unselectedColor: tone.onContainer.withValues(alpha: 0.08),
                      onSelected: (s) => markSession(context, ref, session, s),
                    ),
                  if (link != null)
                    Padding(
                      padding: EdgeInsets.only(top: inProgress ? 8 : 0),
                      child: FilledButton.tonalIcon(
                        onPressed: () => openUrl(link),
                        icon: const Icon(LecIcons.openLink),
                        label: Text(l.openLink),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NeedsMarkingSection extends ConsumerStatefulWidget {
  const _NeedsMarkingSection();

  @override
  ConsumerState<_NeedsMarkingSection> createState() =>
      _NeedsMarkingSectionState();
}

class _NeedsMarkingSectionState extends ConsumerState<_NeedsMarkingSection> {
  /// Tiles swiped away but not yet confirmed by the database.
  final _hidden = <String>{};

  void _swiped(Occurrence session, AttendanceStatus status) {
    setState(() => _hidden.add(session.id));
    markSession(
      context,
      ref,
      session,
      status,
      onUndo: () => setState(() => _hidden.remove(session.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(needsMarkingProvider, (_, next) {
      final stale = _hidden.where((id) => !next.items.contains(id)).toList();
      if (stale.isNotEmpty) setState(() => _hidden.removeAll(stale));
    });
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ids = [
      for (final id in ref.watch(needsMarkingProvider).items)
        if (!_hidden.contains(id)) id,
    ];

    if (ids.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            color: StatusColors.of(
              context,
            )[AttendanceStatus.attended].container,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Icon(
                LecIcons.doneAll,
                color: StatusColors.of(
                  context,
                )[AttendanceStatus.attended].accent,
              ),
              title: Text(l.allCaughtUp),
              subtitle: Text(l.allCaughtUpSubtitle),
            ),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: l.needsMarking,
            subtitle: l.needsMarkingCount(ids.length),
            trailing: ids.length > 1
                ? TextButton.icon(
                    onPressed: () {
                      final index = ref.read(occurrenceIndexProvider);
                      final sessions = [for (final id in ids) ?index.byId[id]];
                      markSessions(
                        context,
                        ref,
                        sessions,
                        AttendanceStatus.attended,
                      );
                    },
                    icon: const Icon(LecIcons.doneAll),
                    label: Text(l.markAllAttended),
                  )
                : null,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => AppearIn(
              key: ValueKey(ids[i]),
              index: i,
              child: SessionTile(
                sessionId: ids[i],
                showDate: true,
                quickActions: true,
                onSwipeMarked: _swiped,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
            child: Text(
              AppIdiom.isDesktop ? l.rightClickHint : l.swipeHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayTimeline extends ConsumerWidget {
  const _TodayTimeline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final today = ref.watch(todayProvider);
    final ids = ref.watch(dayIdsProvider(today)).items;
    final nowNext = ref.watch(nowNextProvider);
    if (ids.isEmpty) {
      return SliverToBoxAdapter(
        child: SectionHeader(
          title: l.todaySchedule,
          subtitle: l.noClassesToday,
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(title: l.todaySchedule)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: ids.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                SessionTile(sessionId: ids[i], highlight: ids[i] == nowNext),
          ),
        ),
      ],
    );
  }
}

class _ComingUp extends ConsumerWidget {
  const _ComingUp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final days = <(LocalDate, List<String>)>[];
    for (var i = 1; i <= 6; i++) {
      final day = today.addDays(i);
      final ids = ref.watch(dayIdsProvider(day)).items;
      if (ids.isNotEmpty) days.add((day, ids));
    }
    if (days.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(title: l.comingUp)),
        for (final (day, ids) in days)
          SliverMainAxisGroup(
            slivers: [
              PinnedHeaderSliver(
                child: Container(
                  color: theme.colorScheme.surface,
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 8),
                  child: Text(
                    fmt.relativeDay(day, today, l),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: ids.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => SessionTile(sessionId: ids[i]),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
