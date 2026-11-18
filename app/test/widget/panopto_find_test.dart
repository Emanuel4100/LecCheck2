import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/app/app.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/recordings_controller.dart';
import 'package:leccheck/app/router.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/recordings/panopto_connection.dart';
import 'package:leccheck/core/recordings/recording_linker.dart';
import 'package:leccheck/domain/local_date.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/recording_match.dart';
import 'package:leccheck/domain/schedule_types.dart';
import 'package:leccheck/features/session/session_sheet.dart';
import 'package:leccheck/features/today/today_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../core/fake_panopto.dart';

final _now = DateTime(2026, 10, 20, 13); // Tuesday, after the 10:00 lecture

/// Panopto's ids are GUIDs; [n] tells them apart.
PanoptoRecording _recording(int n, {String? group}) => PanoptoRecording(
  id: '0000000$n-1111-4222-8333-444455556666',
  name: 'Calculus $n',
  description: group == null ? '' : 'Calculus\nשעור $group',
  wallStart: (date: LocalDate.parse('2026-10-20'), minute: 600),
  durationSec: 6000,
  complete: true,
  viewerUrl:
      'https://example.panopto.eu/Panopto/Pages/Viewer.aspx?id='
      '0000000$n-1111-4222-8333-444455556666',
);

/// This device connected to Panopto (or not), without signing in: the
/// scripted linker answers for Panopto.
class _Connection extends PanoptoConnection {
  _Connection({required this.connected}) : super(lock: MemoryLock());

  final bool connected;

  @override
  Future<PanoptoStatus> status() async =>
      connected ? PanoptoStatus.connected : PanoptoStatus.off;

  @override
  Future<PanoptoInfo> info() async => connected
      ? const PanoptoInfo(PanoptoStatus.connected, site: FakePanopto.site)
      : PanoptoInfo.off;
}

/// A linker whose answer each test scripts; it never looks by itself.
class _ScriptedLinker extends RecordingLinker {
  _ScriptedLinker({
    required super.repo,
    required super.connection,
    required super.prefs,
  });

  Future<SessionCheck> Function(Occurrence session) answer = (_) async =>
      const SessionCheck(outcome: SessionOutcome.noRecording);

  List<GroupOption> groups = const [];

  @override
  Future<SessionCheck> check(Occurrence session) => answer(session);

  @override
  Future<List<GroupOption>> groupOptions(
    String courseId,
    String meetingId,
  ) async => groups;

  @override
  Future<LinkerReport?> run({bool force = false, String? courseId}) async =>
      null;
}

Future<(ProviderContainer, ScheduleRepository, _ScriptedLinker)> _start(
  WidgetTester tester, {
  bool connected = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  await prefs.setString('appearance.locale', 'en');
  // Seen once: no warning before the first look.
  await prefs.setBool(PanoptoController.warnedKey, true);
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = ScheduleRepository(db);
  final connection = _Connection(connected: connected);
  await tester.runAsync(() async {
    await repo.saveSemester(
      SemesterInfo(
        id: 'sem',
        name: 'Semester A',
        start: LocalDate.parse('2026-10-18'),
        end: LocalDate.parse('2027-01-22'),
      ),
    );
    await repo.saveCourse(
      const CourseInfo(id: 'c1', semesterId: 'sem', name: 'Calculus'),
      meetings: const [
        MeetingRule(
          id: 'm1',
          courseId: 'c1',
          type: SessionType.lecture,
          kind: MeetingKind.weekly,
          weekday: DateTime.tuesday,
          startMin: 600,
          endMin: 720,
        ),
      ],
      requirements: const [],
    );
  });
  final linker = _ScriptedLinker(
    repo: repo,
    connection: connection,
    prefs: prefs,
  );
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      minuteClockProvider.overrideWith((ref) => Stream.value(_now)),
      panoptoConnectionProvider.overrideWithValue(connection),
      recordingLinkerProvider.overrideWithValue(linker),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const LecCheckApp()),
  );
  await _settle(tester);
  return (container, repo, linker);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Today's session (Tuesday 10:00, over), with its sheet open.
Future<Occurrence> _openSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final session = container
      .read(occurrenceIndexProvider)
      .all
      .firstWhere((o) => o.date == LocalDate.parse('2026-10-20'));
  unawaited(
    showSessionSheet(tester.element(find.byType(TodayPage)), session.id),
  );
  await _settle(tester);
  return session;
}

Future<void> _tapFind(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('find-in-panopto'));
  await tester.ensureVisible(button.last);
  await _settle(tester);
  await tester.tap(button.last);
  await _settle(tester);
}

void main() {
  testWidgets('not connected: no button', (tester) async {
    final (container, _, _) = await _start(tester, connected: false);
    await _openSheet(tester, container);
    expect(find.byKey(const ValueKey('find-in-panopto')), findsNothing);
  });

  testWidgets('found: fills the empty link', (tester) async {
    final (container, _, linker) = await _start(tester);
    final rec = _recording(1);
    linker.answer = (_) async =>
        SessionCheck(found: rec, outcome: SessionOutcome.found);
    final session = await _openSheet(tester, container);
    await _tapFind(tester);
    final now = container.read(sessionProvider(session.id))!;
    expect((now.recordingUrl, now.recordingAuto), (rec.viewerUrl, true));
    expect(find.text('Found in Panopto'), findsOneWidget);
  });

  testWidgets('a pasted link is replaced only when asked', (tester) async {
    final (container, repo, linker) = await _start(tester);
    final rec = _recording(1);
    linker.answer = (_) async =>
        SessionCheck(found: rec, outcome: SessionOutcome.found);
    var session = await _openSheet(tester, container);
    await tester.runAsync(
      () => repo.setRecordingUrl(session, 'https://example.com/mine'),
    );
    await _settle(tester);

    await _tapFind(tester);
    expect(find.text('Replace your link?'), findsOneWidget);
    await tester.tap(find.text('Keep mine'));
    await _settle(tester);
    session = container.read(sessionProvider(session.id))!;
    expect(session.recordingUrl, 'https://example.com/mine');

    await _tapFind(tester);
    await tester.tap(find.text('Replace'));
    await _settle(tester);
    session = container.read(sessionProvider(session.id))!;
    expect(
      (session.recordingUrl, session.recordingAuto),
      (rec.viewerUrl, true),
    );
  });

  testWidgets('a pasted link that is the same recording', (tester) async {
    final (container, repo, linker) = await _start(tester);
    final rec = _recording(1);
    linker.answer = (_) async =>
        SessionCheck(found: rec, outcome: SessionOutcome.found);
    final session = await _openSheet(tester, container);
    await tester.runAsync(() => repo.setRecordingUrl(session, rec.viewerUrl));
    await _settle(tester);
    await _tapFind(tester);
    expect(
      find.text("Your link is this class's recording in Panopto"),
      findsOneWidget,
    );
    expect(container.read(sessionProvider(session.id))!.recordingAuto, false);
  });

  testWidgets('several groups: asks, saves the group, fills the link', (
    tester,
  ) async {
    final (container, repo, linker) = await _start(tester);
    final mine = _recording(2, group: 'ב');
    linker.answer = (_) async => (await repo.panoptoGroups())['m1'] == 'ב'
        ? SessionCheck(found: mine, outcome: SessionOutcome.found)
        : const SessionCheck(
            outcome: SessionOutcome.askGroup,
            question: GroupQuestion(
              meetingId: 'm1',
              options: [
                GroupOption(group: 'א', room: 'Room 1'),
                GroupOption(group: 'ב', room: 'Room 2'),
              ],
            ),
          );
    final session = await _openSheet(tester, container);
    await _tapFind(tester);
    expect(find.text('Which group are you in?'), findsOneWidget);
    await tester.tap(find.text('Group ב · Room 2'));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    await _settle(tester);

    final groups = await tester.runAsync(repo.panoptoGroups);
    expect(groups!['m1'], 'ב');
    final now = container.read(sessionProvider(session.id))!;
    expect(now.recordingUrl, mine.viewerUrl);
  });

  testWidgets('nothing fits: says why, and a recording can be picked', (
    tester,
  ) async {
    final (container, _, linker) = await _start(tester);
    final other = _recording(3, group: 'ג');
    linker.answer = (_) async => SessionCheck(
      outcome: SessionOutcome.otherGroup,
      sameDay: [
        RecordingDetail(other, other.wallStart, RecordingOutcome.otherGroup),
      ],
    );
    final session = await _openSheet(tester, container);
    await _tapFind(tester);
    expect(find.text('No recording for this class'), findsOneWidget);
    expect(
      find.textContaining("Only another group's recording"),
      findsOneWidget,
    );
    await tester.tap(find.text('Pick a recording'));
    await _settle(tester);
    await tester.tap(find.text('Calculus 3'));
    await _settle(tester);
    final now = container.read(sessionProvider(session.id))!;
    // Picked by hand: the user's own link.
    expect((now.recordingUrl, now.recordingAuto), (other.viewerUrl, false));
  });

  testWidgets('course page: Change switches the meeting to another group', (
    tester,
  ) async {
    final (container, repo, linker) = await _start(tester);
    linker.groups = const [
      GroupOption(group: 'א', room: 'Room 1'),
      GroupOption(group: 'ב', room: 'Room 2'),
    ];
    await tester.runAsync(() => repo.setPanoptoGroup('m1', 'א'));
    container.read(routerProvider).push('/courses/c1');
    await _settle(tester);
    final change = find.text('Change').last;
    await tester.ensureVisible(change);
    await _settle(tester);
    await tester.tap(change);
    await _settle(tester);
    expect(find.text('Group א · Room 1'), findsOneWidget);
    await tester.tap(find.text('Group ב · Room 2'));
    await _settle(tester);
    await tester.tap(find.text('Save'));
    await _settle(tester);
    final groups = await tester.runAsync(repo.panoptoGroups);
    expect(groups!['m1'], 'ב');
  });
}
