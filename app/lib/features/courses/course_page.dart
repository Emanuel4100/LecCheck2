import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../app/theme/colors.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/progress_ring.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/attendance_stats.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import '../session/session_tile.dart';
import 'requirement_chip.dart';

/// A course on its own page (phones, or opened directly).
class CoursePage extends ConsumerWidget {
  const CoursePage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(courseProvider(courseId)) == null) return const Scaffold();
    final l = AppLocalizations.of(context);
    return PageShortcuts(
      child: Scaffold(
        body: CourseDetailView(courseId: courseId),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              context.push('/course-editor?id=$courseId&oneTime=1'),
          icon: const Icon(LecIcons.add),
          label: Text(l.addOneTimeSession),
        ),
      ),
    );
  }
}

/// A course's attendance, meetings, notes and session history. [embedded]:
/// shown beside the course list (wide Courses tab) with a compact header
/// instead of a large app bar. Splits into two columns when it has room.
class CourseDetailView extends ConsumerWidget {
  const CourseDetailView({
    super.key,
    required this.courseId,
    this.embedded = false,
  });

  final String courseId;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider(courseId));
    if (course == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final tone = CourseColors.of(context).tone(course.colorKey);
    final summary = ref.watch(courseSummaryProvider(courseId));
    final index = ref.watch(occurrenceIndexProvider);
    final sessions = index.forCourse(courseId);
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final byType = AttendanceStats.byType(sessions, now);
    final meetings = ref.watch(
      semesterDataProvider.select(
        (d) => EqList(d.value?.meetingsOf(courseId) ?? const <MeetingRule>[]),
      ),
    );
    final progress = summary.progress;

    final links = <NamedLink>[
      if (course.website.isNotEmpty)
        NamedLink(title: l.courseWebsite, url: course.website),
      ...course.links,
    ];

    final header = embedded
        ? SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l.edit,
                    icon: const Icon(LecIcons.edit),
                    onPressed: () =>
                        context.push('/course-editor?id=$courseId'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        context.push('/course-editor?id=$courseId&oneTime=1'),
                    icon: const Icon(LecIcons.add),
                    label: Text(l.addOneTimeSession),
                  ),
                ],
              ),
            ),
          )
        : SliverAppBar.large(
            title: Text(course.name),
            actions: [
              IconButton(
                tooltip: l.edit,
                icon: const Icon(LecIcons.edit),
                onPressed: () => context.push('/course-editor?id=$courseId'),
              ),
              const SizedBox(width: 4),
            ],
          );

    final overview = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: tone.container,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ProgressRing(
                    value: progress,
                    size: 88,
                    stroke: 10,
                    color: tone.accent,
                    trackColor: tone.onContainer.withValues(alpha: 0.12),
                    child: Text(
                      progress == null ? '–' : '${(progress * 100).round()}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: tone.onContainer,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: tone.onContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final type in SessionType.values)
                          if (byType[type] case final counts?
                              when counts.decided > 0)
                            Text(
                              '${type.label(l)}: ${counts.present}/${counts.decided}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: tone.onContainer,
                              ),
                            ),
                        for (final r in summary.requirements.items) ...[
                          const SizedBox(height: 8),
                          RequirementChip(progress: r, showType: true),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: SectionHeader(title: l.meetingsSection)),
      SliverList.list(
        children: [
          for (final m in meetings.items)
            ListTile(
              leading: Icon(m.type.icon, color: tone.accent),
              title: Text(
                m.kind == MeetingKind.weekly
                    ? '${m.type.label(l)} · ${fmt.isoWeekdayName(m.weekday!)}'
                    : '${m.type.label(l)} · ${fmt.longDate(m.date!)}',
              ),
              subtitle: Text(
                [
                  fmt.timeRange(m.startMin, m.endMin),
                  if (m.location.isNotEmpty) m.location,
                  if (m.intervalWeeks == 2) l.everyOtherWeek,
                ].join(' · '),
              ),
            ),
        ],
      ),
      if (course.lecturer.isNotEmpty ||
          course.code.isNotEmpty ||
          links.isNotEmpty ||
          course.notes.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader(title: l.courseNotes)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (course.lecturer.isNotEmpty)
                  _Line(icon: LecIcons.lecturer, text: course.lecturer),
                if (course.code.isNotEmpty)
                  _Line(icon: LecIcons.numbers, text: course.code),
                if (course.notes.isNotEmpty)
                  _Line(icon: LecIcons.notes, text: course.notes),
                if (links.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final link in links)
                        ActionChip(
                          avatar: const Icon(LecIcons.link, size: 18),
                          label: Text(
                            link.title.isEmpty ? link.url : link.title,
                          ),
                          onPressed: () => openUrl(link.url, context: context),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ];
    final history = <Widget>[
      SliverToBoxAdapter(child: SectionHeader(title: l.sessionsHistory)),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, embedded ? 32 : 96),
        sliver: SliverList.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) =>
              SessionTile(sessionId: sessions[i].id, showDate: true),
        ),
      ),
    ];

    return CustomScrollView(
      slivers: [
        header,
        SliverLayoutBuilder(
          builder: (context, constraints) => constraints.crossAxisExtent >= 760
              ? SliverCrossAxisGroup(
                  slivers: [
                    SliverCrossAxisExpanded(
                      flex: 1,
                      sliver: SliverMainAxisGroup(slivers: overview),
                    ),
                    SliverCrossAxisExpanded(
                      flex: 1,
                      sliver: SliverMainAxisGroup(slivers: history),
                    ),
                  ],
                )
              : SliverMainAxisGroup(slivers: [...overview, ...history]),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
