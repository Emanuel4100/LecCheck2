import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dev/dev_log.dart';
import '../core/recordings/match_report.dart';
import '../core/recordings/panopto_api.dart';
import '../core/recordings/panopto_connection.dart';
import '../core/recordings/recording_linker.dart';
import '../domain/recording_match.dart';
import 'providers.dart';

/// Panopto recordings (experimental): this device's connection, and the
/// last look's report.
class PanoptoView {
  const PanoptoView({
    this.status = PanoptoStatus.off,
    this.site,
    this.busy = false,
    this.report = const LinkerReport(),
    this.looks = const [],
  });

  final PanoptoStatus status;

  /// The Panopto host this device is set up with.
  final String? site;

  /// Connecting or looking right now.
  final bool busy;
  final LinkerReport report;

  /// Each course's matching details from the latest looks in this run of
  /// the app (Developer mode).
  final List<CourseLook> looks;

  PanoptoView copyWith({
    PanoptoStatus? status,
    String? site,
    bool? busy,
    LinkerReport? report,
    List<CourseLook>? looks,
  }) => PanoptoView(
    status: status ?? this.status,
    site: site ?? this.site,
    busy: busy ?? this.busy,
    report: report ?? this.report,
    looks: looks ?? this.looks,
  );

  /// The open group questions of [courseId].
  List<GroupQuestion> questionsOf(String courseId) => [
    for (final q in report.questions)
      if (q.courseId == courseId) q.question,
  ];
}

/// The address users put in their Panopto API client (null: this build has
/// no server). A provider so screenshots can show it.
final panoptoRedirectProvider = Provider<String?>(
  (ref) => PanoptoConnection.defaultRedirectUrl,
);

final panoptoConnectionProvider = Provider<PanoptoConnection>(
  (ref) => PanoptoConnection(lock: DbRefreshLock(ref.watch(databaseProvider))),
);

final recordingLinkerProvider = Provider<RecordingLinker>(
  (ref) => RecordingLinker(
    repo: ref.watch(repositoryProvider),
    connection: ref.watch(panoptoConnectionProvider),
    prefs: ref.watch(sharedPrefsProvider),
  ),
);

/// Sessions with a link found in Panopto.
final foundRecordingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(repositoryProvider).watchFoundRecordingCount(),
  retry: (_, _) => null,
);

/// Panopto folders per course id (null: not chosen yet).
final panoptoFoldersProvider =
    StreamProvider<Map<String, List<PanoptoFolderRef>?>>(
      (ref) => ref.watch(repositoryProvider).watchPanoptoFolders(),
      retry: (_, _) => null,
    );

/// The Panopto group chosen per meeting id.
final panoptoGroupsProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(repositoryProvider).watchPanoptoGroups(),
  retry: (_, _) => null,
);

class PanoptoController extends Notifier<PanoptoView> {
  /// Shown once per device before the first connection.
  static const warnedKey = 'panopto.warned';

  PanoptoConnection get _connection => ref.read(panoptoConnectionProvider);
  RecordingLinker get _linker => ref.read(recordingLinkerProvider);

  @override
  PanoptoView build() {
    Future.microtask(reload);
    return PanoptoView(report: ref.read(recordingLinkerProvider).report);
  }

  /// Reads this device's connection again.
  Future<void> reload() async {
    try {
      final saved = await _connection.load();
      state = state.copyWith(
        status: await _connection.status(),
        site: saved?.setup.site,
        report: _linker.report,
      );
    } on Object catch (e) {
      DevLog.add('Panopto state unreadable: $e');
    }
  }

  bool get warned => ref.read(sharedPrefsProvider).getBool(warnedKey) ?? false;

  Future<void> markWarned() =>
      ref.read(sharedPrefsProvider).setBool(warnedKey, true);

  /// The setup saved on this device (for "Connect again"); null also when
  /// secure storage doesn't answer (a locked keyring).
  Future<PanoptoSetup?> savedSetup() async {
    try {
      return (await _connection.load())?.setup;
    } on Object catch (e) {
      DevLog.add('Panopto setup unreadable: $e');
      return null;
    }
  }

  /// Signs in and looks right away. Throws [PanoptoException].
  Future<void> connect(PanoptoSetup setup) async {
    state = state.copyWith(busy: true);
    try {
      await _connection.connect(setup);
      await reload();
    } finally {
      state = state.copyWith(busy: false);
    }
    await lookNow();
  }

  /// Forgets the connection on this device; [removeLinks] also empties the
  /// links it found (on every device, through sync).
  Future<int> disconnect({required bool removeLinks}) async {
    state = state.copyWith(busy: true);
    var removed = 0;
    try {
      await _connection.disconnect();
      await _linker.clearReport();
      if (removeLinks) {
        removed = await ref.read(repositoryProvider).clearFoundRecordings();
      }
    } finally {
      state = const PanoptoView();
      await reload();
    }
    return removed;
  }

  /// Looks unless a look ran in the last 3 hours (app start and resume).
  Future<void> lookIfDue() => _look(force: false);

  /// Looks now: all courses, or only [courseId].
  Future<void> lookNow({String? courseId}) =>
      _look(force: true, courseId: courseId);

  Future<void> _look({required bool force, String? courseId}) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final report = await _linker.run(force: force, courseId: courseId);
      if (report != null) {
        final fresh = {for (final c in report.courses) c.courseId};
        state = state.copyWith(
          looks: [
            for (final c in state.looks)
              if (!fresh.contains(c.courseId)) c,
            ...report.courses,
          ],
        );
      }
    } on Object catch (e) {
      debugPrint('Panopto look failed: $e');
    } finally {
      state = state.copyWith(busy: false);
      await reload();
    }
  }

  /// The user picked [group]'s recordings for [meetingId]: links found for
  /// the meeting before are found again with it.
  Future<void> answer({
    required String courseId,
    required String meetingId,
    required String group,
  }) async {
    final repo = ref.read(repositoryProvider);
    await repo.setPanoptoGroup(meetingId, group);
    await repo.clearFoundRecordings(meetingId: meetingId);
    await lookNow(courseId: courseId);
  }

  /// Asks again which group is the meeting's.
  Future<void> forgetGroup({
    required String courseId,
    required String meetingId,
  }) => answer(courseId: courseId, meetingId: meetingId, group: '');

  /// Sets a course's folders (null: find them by the course number) and
  /// finds its links again.
  Future<void> setFolders(
    String courseId,
    List<PanoptoFolderRef>? folders,
  ) async {
    final repo = ref.read(repositoryProvider);
    await repo.setPanoptoFolders(courseId, folders);
    await repo.clearFoundRecordings(courseId: courseId);
    await lookNow(courseId: courseId);
  }

  /// Folders whose name has [query], for the folder picker.
  Future<List<PanoptoFolderRef>> searchFolders(String query) async {
    final api = await _connection.api();
    if (api == null) return const [];
    return api.searchFolders(query);
  }

  /// The folder a pasted Panopto link points to (`…folderID="<guid>"`).
  Future<PanoptoFolderRef?> folderFromLink(String link) async {
    final id = folderIdOf(link);
    if (id == null) return null;
    final api = await _connection.api();
    return api?.folder(id);
  }

  /// The folder id in a Panopto folder link, e.g.
  /// `…/Sessions/List.aspx#folderID="ab040e1e-…"` (quotes may be encoded).
  static String? folderIdOf(String link) {
    final decoded = Uri.decodeFull(link.trim());
    final match = RegExp(
      r'folderID=\W*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
      caseSensitive: false,
    ).firstMatch(decoded);
    return match?.group(1)?.toLowerCase();
  }
}

final panoptoProvider = NotifierProvider<PanoptoController, PanoptoView>(
  PanoptoController.new,
);
