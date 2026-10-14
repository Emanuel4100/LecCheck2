import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/notification_controller.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../app/theme/colors.dart';
import '../../app/widgets/common.dart';
import '../../app/widgets/tab_app_bar.dart';
import '../../app/widgets/progress_ring.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/attendance_stats.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';
import '../session/session_tile.dart';
import 'meeting_summary.dart';
import 'requirement_chip.dart';

/// A course on its own page (phones, or opened directly).
class CoursePage extends ConsumerWidget {
  const CoursePage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(courseProvider(courseId)) == null) return const Scaffold();
    return PageShortcuts(
      child: Scaffold(body: CourseDetailView(courseId: courseId)),
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
    final semester = ref.watch(
      semesterDataProvider.select((d) => d.value?.semester),
    );
    final progress = summary.progress;
    final reminders = ref.watch(reminderSettingsProvider);

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
        : AppIdiom.isDesktop
        ? DesktopAppBar(
            title: course.name,
            actions: [
              IconButton(
                tooltip: l.addOneTimeSession,
                icon: const Icon(LecIcons.addDate),
                onPressed: () =>
                    context.push('/course-editor?id=$courseId&oneTime=1'),
              ),
              IconButton(
                tooltip: l.edit,
                icon: const Icon(LecIcons.edit),
                onPressed: () => context.push('/course-editor?id=$courseId'),
              ),
              const SizedBox(width: 4),
            ],
          )
        : SliverAppBar.large(
            title: Text(course.name),
            actions: [
              IconButton(
                tooltip: l.addOneTimeSession,
                icon: const Icon(LecIcons.addDate),
                onPressed: () =>
                    context.push('/course-editor?id=$courseId&oneTime=1'),
              ),
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
              title: Text(meetingTitle(m, l, fmt)),
              subtitle: Text(meetingDetails(m, semester, l, fmt)),
            ),
        ],
      ),
      if (reminders.any)
        SliverToBoxAdapter(
          child: SwitchListTile.adaptive(
            secondary: const Icon(LecIcons.notifications),
            title: Text(l.courseReminders),
            subtitle: Text(l.courseRemindersSubtitle),
            value: !reminders.isMuted(courseId),
            onChanged: (on) => ref
                .read(reminderSettingsProvider.notifier)
                .setMuted(courseId, !on),
          ),
        ),
      if (course.contacts.isNotEmpty) ...[
        SliverToBoxAdapter(child: SectionHeader(title: l.contactsSection)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 0),
            child: Column(
              children: [
                for (final contact in course.contacts)
                  _ContactLine(contact: contact),
              ],
            ),
          ),
        ),
      ],
      if ((course.contacts.isEmpty && course.lecturer.isNotEmpty) ||
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
                // Synced from a version before contacts: just the name.
                if (course.contacts.isEmpty && course.lecturer.isNotEmpty)
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.separated(
          itemCount: sessions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => SessionTile(
            sessionId: sessions[i].id,
            showDate: true,
            showCourse: false,
          ),
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

/// Name and role, with buttons to email or copy the address.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.contact});

  final CourseContact contact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = contact.email;
    final name = contact.name.isEmpty ? email : contact.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            LecIcons.lecturer,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodyMedium),
                SelectableText(
                  [
                    contact.role.label(l),
                    if (email.isNotEmpty && email != name) email,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (email.isNotEmpty) ...[
            IconButton(
              tooltip: l.copyEmail,
              color: theme.colorScheme.onSurfaceVariant,
              icon: const Icon(LecIcons.copy, size: 18),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: email));
                messenger.showSnackBar(SnackBar(content: Text(l.emailCopied)));
              },
            ),
            IconButton(
              tooltip: l.sendEmail,
              color: theme.colorScheme.primary,
              icon: const Icon(LecIcons.email, size: 20),
              onPressed: () => openUrl('mailto:$email', context: context),
            ),
          ],
        ],
      ),
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
