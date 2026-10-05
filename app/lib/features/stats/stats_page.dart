import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/progress_ring.dart';
import '../../app/widgets/tab_app_bar.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/attendance_stats.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../courses/course_actions.dart';
import '../courses/requirement_chip.dart';
import '../session/session_tile.dart';

class _Stats {
  _Stats({
    required this.overall,
    required this.streak,
    required this.toMark,
    required this.byCourse,
    required this.byType,
    required this.byWeek,
    required this.catchUp,
  });

  final StatusCounts overall;
  final Streak streak;
  final int toMark;
  final Map<String, StatusCounts> byCourse;
  final Map<SessionType, StatusCounts> byType;
  final Map<int, StatusCounts> byWeek;
  final List<Occurrence> catchUp;
}

final _statsProvider = Provider<_Stats>((ref) {
  final index = ref.watch(occurrenceIndexProvider);
  final calendar = ref.watch(calendarProvider);
  final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
  final started = AttendanceStats.started(index.all, now).toList();
  return _Stats(
    overall: StatusCounts.of(started),
    streak: AttendanceStats.streak(index.all, now),
    toMark: ref.watch(needsMarkingProvider).items.length,
    byCourse: AttendanceStats.byCourse(index.all, now),
    byType: AttendanceStats.byType(index.all, now),
    byWeek: calendar == null
        ? const {}
        : AttendanceStats.byWeek(index.all, calendar, now),
    catchUp: AttendanceStats.catchUp(started),
  );
});

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stats = ref.watch(_statsProvider);
    final hasData = stats.overall.total > 0;
    final catchUp = [
      SliverToBoxAdapter(child: SectionHeader(title: l.catchUp)),
      if (stats.catchUp.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(l.catchUpEmpty),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: stats.catchUp.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                SessionTile(sessionId: stats.catchUp[i].id, showDate: true),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          TabAppBar(title: l.statsTitle),
          if (!hasData)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(icon: LecIcons.stats, title: l.noDataYet),
            )
          else if (WindowSize.of(context).isWide)
            // Dashboard: overview and lists | charts.
            SliverCentered(
              maxWidth: 1400,
              sliver: SliverCrossAxisGroup(
                slivers: [
                  SliverCrossAxisExpanded(
                    flex: 1,
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(child: _Hero(stats: stats)),
                        SliverToBoxAdapter(child: _Metrics(stats: stats)),
                        const SliverToBoxAdapter(
                          child: _RequirementsOverview(),
                        ),
                        SliverToBoxAdapter(child: _ByCourse(stats: stats)),
                        ...catchUp,
                      ],
                    ),
                  ),
                  SliverCrossAxisExpanded(
                    flex: 1,
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(child: _ByType(stats: stats)),
                        SliverToBoxAdapter(child: _WeeklyTrend(stats: stats)),
                        SliverToBoxAdapter(
                          child: _StatusMix(counts: stats.overall),
                        ),
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
                  SliverToBoxAdapter(child: _Hero(stats: stats)),
                  SliverToBoxAdapter(child: _Metrics(stats: stats)),
                  const SliverToBoxAdapter(child: _RequirementsOverview()),
                  SliverToBoxAdapter(child: _ByCourse(stats: stats)),
                  SliverToBoxAdapter(child: _ByType(stats: stats)),
                  SliverToBoxAdapter(child: _WeeklyTrend(stats: stats)),
                  SliverToBoxAdapter(child: _StatusMix(counts: stats.overall)),
                  ...catchUp,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final calendar = ref.watch(calendarProvider);
    final today = ref.watch(todayProvider);
    final progress = stats.overall.progress;
    final semesterProgress = calendar?.progressAt(today) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              ProgressRing(
                value: progress,
                size: 120,
                stroke: 12,
                trackColor: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  progress == null ? '–' : '${(progress * 100).round()}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.attendance,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.attendanceSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.semesterProgress,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: semesterProgress,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget tile(
      IconData icon,
      Color color,
      String label,
      String value,
      String? sub,
      VoidCallback? onTap,
    ) => Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                Text(value, style: theme.textTheme.headlineSmall),
                Text(label, style: theme.textTheme.labelLarge),
                if (sub != null)
                  Text(
                    sub,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            tile(
              LecIcons.streak,
              Colors.deepOrange,
              l.streak,
              l.streakValue(stats.streak.current),
              l.bestStreak(stats.streak.best),
              null,
            ),
            const SizedBox(width: 12),
            tile(
              LecIcons.pending,
              theme.colorScheme.error,
              l.toMark,
              '${stats.toMark}',
              null,
              () => context.go('/today'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementsOverview extends ConsumerWidget {
  const _RequirementsOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final courses = ref.watch(coursesProvider).items;
    final rows = [
      for (final c in courses)
        if (ref.watch(courseSummaryProvider(c.id)).requirements.items
            case final reqs when reqs.isNotEmpty)
          (c, reqs),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.requirementsOverview),
        for (final (course, reqs) in rows)
          ListTile(
            title: Text(course.name),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in reqs)
                    RequirementChip(progress: r, showType: true),
                ],
              ),
            ),
            onTap: () => openCourse(context, ref, course.id),
          ),
      ],
    );
  }
}

/// Horizontal bar: present share in [color], missed share in the missed tone.
class _AttendanceBar extends StatelessWidget {
  const _AttendanceBar({
    required this.label,
    required this.counts,
    required this.color,
    this.onTap,
  });

  final String label;
  final StatusCounts counts;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missed = StatusColors.of(context)[AttendanceStatus.missed];
    final motion = AppMotion.of(context);
    final decided = counts.decided;
    final present = decided == 0 ? 0.0 : counts.present / decided;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Text(
                  decided == 0
                      ? '–'
                      : '${(present * 100).round()}% · ${counts.present}/$decided',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: present),
                  duration: motion.slow,
                  curve: motion.spatial,
                  builder: (context, v, _) => Row(
                    children: [
                      Expanded(
                        flex: (v * 1000).round(),
                        child: Container(color: color),
                      ),
                      Expanded(
                        flex: decided == 0 ? 1000 : ((1 - v) * 1000).round(),
                        child: Container(
                          color: decided == 0
                              ? theme.colorScheme.surfaceContainerHighest
                              : missed.container,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ByCourse extends ConsumerWidget {
  const _ByCourse({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final courses = ref.watch(coursesProvider).items;
    final colors = CourseColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.byCourse),
        for (final c in courses)
          _AttendanceBar(
            label: c.name,
            counts: stats.byCourse[c.id] ?? StatusCounts(),
            color: colors.tone(c.colorKey).accent,
            onTap: () => openCourse(context, ref, c.id),
          ),
      ],
    );
  }
}

class _ByType extends StatelessWidget {
  const _ByType({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final types = [
      for (final t in SessionType.values)
        if ((stats.byType[t]?.total ?? 0) > 0) t,
    ];
    if (types.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.byType),
        for (final t in types)
          _AttendanceBar(
            label: t.label(l),
            counts: stats.byType[t]!,
            color: primary,
          ),
      ],
    );
  }
}

class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final weeks = stats.byWeek.keys.where((w) => w >= 1).toList()..sort();
    if (weeks.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.weeklyTrend),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: 100,
                minY: 0,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.outlineVariant,
                    strokeWidth: 1,
                    dashArray: const [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${value.toInt()}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${l.weekNumber(group.x)}\n${rod.toY.round()}%',
                      TextStyle(color: theme.colorScheme.onInverseSurface),
                    ),
                  ),
                ),
                barGroups: [
                  for (final w in weeks)
                    BarChartGroupData(
                      x: w,
                      barRods: [
                        BarChartRodData(
                          toY: (stats.byWeek[w]!.progress ?? 0) * 100,
                          width: 14,
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusMix extends StatelessWidget {
  const _StatusMix({required this.counts});

  final StatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final statuses = [
      for (final s in AttendanceStatus.values)
        if (counts[s] > 0) s,
    ];
    final total = counts.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.statusMix),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  for (final s in statuses)
                    Expanded(
                      flex: counts[s],
                      child: Container(
                        color: s == AttendanceStatus.pending
                            ? theme.colorScheme.outlineVariant
                            : colors[s].accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final s in statuses)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.icon,
                      size: 16,
                      color: s == AttendanceStatus.pending
                          ? theme.colorScheme.outline
                          : colors[s].accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label(l)} ${counts[s]} (${(counts[s] * 100 / total).round()}%)',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
