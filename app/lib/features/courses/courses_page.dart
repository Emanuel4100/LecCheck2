import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/progress_ring.dart';
import '../../app/widgets/tab_app_bar.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_tile.dart';
import 'course_actions.dart';
import 'course_page.dart';
import 'requirement_chip.dart';

/// Course list. Wide windows show the selected course beside the list; phones
/// open courses as pages and add through the expandable FAB (wider layouts
/// have Add in the navigation rail).
class CoursesPage extends ConsumerWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final courses = ref.watch(coursesProvider).items;
    final size = WindowSize.of(context);
    final chosen = ref.watch(selectedCourseProvider);
    final selected = !size.isWide || courses.isEmpty
        ? null
        : courses.any((c) => c.id == chosen)
        ? chosen!
        : courses.first.id;

    final list = CustomScrollView(
      slivers: [
        TabAppBar(title: l.coursesTitle),
        if (courses.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: LecIcons.courses,
              title: l.noCoursesYet,
              subtitle: l.noCoursesSubtitle,
              action: FilledButton.icon(
                onPressed: () => context.push('/course-editor'),
                icon: const Icon(LecIcons.add),
                label: Text(l.addCourse),
              ),
            ),
          )
        else
          SliverCentered(
            maxWidth: 720,
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                size == WindowSize.compact ? 120 : 32,
              ),
              sliver: SliverList.separated(
                itemCount: courses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => AppearIn(
                  index: i,
                  child: _CourseCard(
                    course: courses[i],
                    selected: courses[i].id == selected,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (selected == null) {
      return Scaffold(
        body: list,
        floatingActionButton: courses.isEmpty || size != WindowSize.compact
            ? null
            : const _AddFabMenu(),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 380, child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: CourseDetailView(
              key: ValueKey(selected),
              courseId: selected,
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, this.selected = false});

  final CourseInfo course;

  /// Shown in the details pane (wide layout).
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final tone = CourseColors.of(context).tone(course.colorKey);
    final summary = ref.watch(courseSummaryProvider(course.id));
    final next = summary.nextSessionId == null
        ? null
        : ref.watch(sessionProvider(summary.nextSessionId!));
    final today = ref.watch(todayProvider);
    final progress = summary.progress;
    final worst = summary.worstRequirement;
    final subtitle = [
      if (course.code.isNotEmpty) course.code,
      if (course.lecturer.isNotEmpty) course.lecturer,
    ].join(' · ');

    return Card(
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () => openCourse(context, ref, course.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.container,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  course.name.characters.firstOrNull?.toUpperCase() ?? '?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: tone.onContainer,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      next == null
                          ? l.noUpcomingSessions
                          : l.nextSession(
                              '${fmt.relativeDay(next.date, today, l)}, ${fmt.time(next.startMin)}',
                            ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (worst != null) ...[
                      const SizedBox(height: 8),
                      RequirementChip(progress: worst),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(
                value: progress,
                color: tone.accent,
                size: 52,
                child: Text(
                  progress == null ? '–' : '${(progress * 100).round()}%',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expressive FAB that unfolds into "Add course" / "Add one-time session".
class _AddFabMenu extends ConsumerStatefulWidget {
  const _AddFabMenu();

  @override
  ConsumerState<_AddFabMenu> createState() => _AddFabMenuState();
}

class _AddFabMenuState extends ConsumerState<_AddFabMenu> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final motion = AppMotion.of(context);
    final theme = Theme.of(context);

    Widget item(IconData icon, String label, VoidCallback onTap, int order) =>
        AnimatedSlide(
          offset: _open ? Offset.zero : const Offset(0, 0.4),
          duration: motion.medium + Duration(milliseconds: 40 * order),
          curve: motion.spatial,
          child: AnimatedOpacity(
            opacity: _open ? 1 : 0,
            duration: motion.fast,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: _open
                    ? () {
                        setState(() => _open = false);
                        onTap();
                      }
                    : null,
                icon: Icon(icon),
                label: Text(label),
              ),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IgnorePointer(
          ignoring: !_open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              item(
                LecIcons.date,
                l.addOneTimeSession,
                () => addOneTimeSession(context, ref),
                1,
              ),
              item(LecIcons.courses, l.addCourse, () => addCourse(context), 0),
            ],
          ),
        ),
        FloatingActionButton(
          tooltip: l.add,
          onPressed: () => setState(() => _open = !_open),
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: motion.medium,
            curve: motion.spatial,
            child: Icon(
              LecIcons.add,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
