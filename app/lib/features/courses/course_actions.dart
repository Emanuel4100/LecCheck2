import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/providers.dart';
import '../../app/theme/colors.dart';
import '../../app/widgets/common.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

/// The course shown in the details pane of the wide Courses layout.
class SelectedCourseController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}

final selectedCourseProvider =
    NotifierProvider<SelectedCourseController, String?>(
      SelectedCourseController.new,
    );

/// Shows a course: selected beside the list on wide windows, its own page on
/// phones.
void openCourse(BuildContext context, WidgetRef ref, String courseId) {
  if (WindowSize.of(context).isWide) {
    ref.read(selectedCourseProvider.notifier).select(courseId);
    context.go('/courses');
  } else {
    context.go('/courses/$courseId');
  }
}

void addCourse(BuildContext context) => context.push('/course-editor');

/// Asks which course, then opens the editor on a new one-time session.
Future<void> addOneTimeSession(BuildContext context, WidgetRef ref) async {
  final courses = ref.read(coursesProvider).items;
  if (courses.isEmpty) {
    addCourse(context);
    return;
  }
  final l = AppLocalizations.of(context);
  final picked = await showAppSheet<CourseInfo>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          ListTile(
            title: Text(
              l.addOneTimeSession,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final c in courses)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: CourseColors.of(context)
                    .tone(c.colorKey)
                    .accent,
                radius: 8,
              ),
              title: Text(c.name),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) {
    context.push('/course-editor?id=${picked.id}&oneTime=1');
  }
}
