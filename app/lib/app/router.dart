import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/courses/course_editor_page.dart';
import '../features/courses/course_page.dart';
import '../features/courses/courses_page.dart';
import '../features/developer/developer_page.dart';
import '../features/onboarding/welcome_page.dart';
import '../features/semester/semester_form_page.dart';
import '../features/sessions/all_sessions_page.dart';
import '../features/settings/report_page.dart';
import '../features/settings/settings_page.dart';
import '../features/stats/stats_page.dart';
import '../features/today/today_page.dart';
import '../features/week/week_page.dart';
import 'providers.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects when the semester list loads or changes.
  final refresh = ValueNotifier(0);
  ref.listen(semestersProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final semesters = ref.read(semestersProvider);
      if (!semesters.hasValue) return null;
      final location = state.matchedLocation;
      final onboarding =
          location == '/welcome' || location.startsWith('/semester');
      final hasSemester = semesters.value!.isNotEmpty;
      if (!hasSemester && !onboarding) return '/welcome';
      if (hasSemester && (location == '/' || location == '/welcome')) {
        return '/today';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/semester',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            SemesterFormPage(semesterId: state.uri.queryParameters['id']),
      ),
      StatefulShellRoute(
        builder: (_, _, shell) => shell,
        navigatorContainerBuilder: (_, shell, children) =>
            AppShell(shell: shell, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (_, _) => const TodayPage(),
                routes: [
                  GoRoute(
                    path: 'sessions',
                    builder: (_, _) => const AllSessionsPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/week', builder: (_, _) => const WeekPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/courses',
                builder: (_, _) => const CoursesPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        CoursePage(courseId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/stats', builder: (_, _) => const StatsPage()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SettingsPage(),
      ),
      GoRoute(
        path: '/report',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ReportPage(lastError: state.uri.queryParameters['error']),
      ),
      GoRoute(
        path: '/developer',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const DeveloperPage(),
      ),
      GoRoute(
        path: '/course-editor',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => CourseEditorPage(
          courseId: state.uri.queryParameters['id'],
          startWithOneTime: state.uri.queryParameters['oneTime'] == '1',
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
}
