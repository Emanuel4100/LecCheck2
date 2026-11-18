import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session.dart';
import '../core/dev/dev_log.dart';
import '../core/recordings/match_report.dart';
import '../core/recordings/panopto_api.dart';
import '../core/recordings/panopto_connection.dart';
import '../core/recordings/panopto_pairing.dart';
import '../core/recordings/panopto_vault.dart';
import '../core/recordings/recording_linker.dart';
import '../domain/occurrence.dart';
import '../domain/recording_match.dart';
import '../core/sync/sync_config.dart';
import 'providers.dart';
import 'sync_providers.dart';

/// Panopto recordings (experimental): this device's connection, and the
/// last look's report.
class PanoptoView {
  const PanoptoView({
    this.status = PanoptoStatus.off,
    this.site,
    this.device,
    this.shared = false,
    this.sharedElsewhere,
    this.busy = false,
    this.report = const LinkerReport(),
    this.looks = const [],
  });

  final PanoptoStatus status;

  /// The Panopto host this device is set up with.
  final String? site;

  /// The device that set Panopto up for the account
  /// ([PanoptoStatus.elsewhere]).
  final String? device;

  /// This device uses the account's shared setup (the vault).
  final bool shared;

  /// This device has its own connection while the account's shared one
  /// exists too (set up on this device name).
  final String? sharedElsewhere;

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
    device: device,
    shared: shared,
    sharedElsewhere: sharedElsewhere,
    busy: busy ?? this.busy,
    report: report ?? this.report,
    looks: looks ?? this.looks,
  );

  /// What [info] says about this device's connection; the rest stays.
  PanoptoView withInfo(PanoptoInfo info, LinkerReport report) => PanoptoView(
    status: info.status,
    site: info.site,
    device: info.device,
    shared: info.shared,
    sharedElsewhere: info.sharedElsewhere,
    busy: busy,
    report: report,
    looks: looks,
  );

  /// The open group questions of [courseId].
  List<GroupQuestion> questionsOf(String courseId) => [
    for (final q in report.questions)
      if (q.courseId == courseId) q.question,
  ];
}

/// Panopto recordings as a whole.
abstract final class PanoptoFeature {
  /// While true: the "Experimental" badges, the warning before connecting,
  /// and the tour offering Panopto as an option ("Next" first). Set to
  /// false once it has proved itself: the tour then leads with "Set it up".
  static const experimental = true;
}

/// The address users put in their Panopto API client (null: this build has
/// no server). A provider so screenshots can show it.
final panoptoRedirectProvider = Provider<String?>(
  (ref) => PanoptoConnection.defaultRedirectUrl,
);

final panoptoConnectionProvider = Provider<PanoptoConnection>(
  (ref) => PanoptoConnection(
    lock: DbRefreshLock(ref.watch(databaseProvider)),
    vault: SyncConfig.enabled
        ? VaultClient(session: () => _currentSession(ref))
        : null,
  ),
);

/// The signed-in account, waiting while the saved sign-in loads. Listens
/// while reading: Riverpod pauses a provider nobody listens to.
Future<Session?> _currentSession(Ref ref) async {
  final now = ref.read(authProvider);
  if (!now.isLoading) return now.value;
  final sub = ref.listen(authProvider, (_, _) {});
  try {
    return await ref
        .read(authProvider.future)
        .timeout(const Duration(seconds: 15));
  } on Object {
    return null;
  } finally {
    sub.close();
  }
}

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
      final info = await _connection.info();
      state = state.withInfo(info, _linker.report);
    } on Object catch (e) {
      DevLog.add('Panopto state unreadable: $e');
    }
  }

  bool get warned => ref.read(sharedPrefsProvider).getBool(warnedKey) ?? false;

  // ---------------------------------------------------------- pairing --

  final _responder = PairingResponder();

  /// Requests from the account's new devices this device can allow (it
  /// holds the vault key): answered, and returned once each, ready to
  /// show their code. Never throws.
  Future<List<PairingPrompt>> pairPrompts() async {
    final client = _connection.vaultClient;
    try {
      if (client == null || await _connection.heldKey() == null) {
        return const [];
      }
      return await _responder.check(client);
    } on Object catch (e) {
      DevLog.add('Panopto pairing requests not read: $e');
      return const [];
    }
  }

  /// Hands the vault key to [prompt]'s device. Throws [PanoptoException].
  Future<void> allow(PairingPrompt prompt) async {
    final key = await _connection.heldKey();
    if (key == null) throw const PanoptoException('pair_gone');
    await _responder.allow(_connection.vaultClient!, prompt, key);
  }

  Future<void> deny(PairingPrompt prompt) async {
    try {
      await _responder.deny(_connection.vaultClient!, prompt.id);
    } on PanoptoException catch (e) {
      DevLog.add('Panopto pairing not denied: $e');
    }
  }

  /// Asks the account's devices for the vault key (this device is B).
  /// Throws [PanoptoException].
  Future<PairingRequest> requestPairing() =>
      PairingRequest.start(_connection.vaultClient!);

  /// Where [request] stands; uses the key once it arrives.
  Future<PairingStep> pollPairing(PairingRequest request) async {
    final session = await _currentSession(ref);
    if (session == null) throw const PanoptoException('network', 'signed out');
    final step = await request.poll(session.userId);
    if (step is PairingDone) {
      await _connection.useKey(step.key);
      await reload();
    }
    return step;
  }

  Future<void> markWarned() =>
      ref.read(sharedPrefsProvider).setBool(warnedKey, true);

  /// The setup saved on this device (for "Connect again"); null also when
  /// secure storage doesn't answer (a locked keyring).
  Future<PanoptoSetup?> savedSetup() async {
    try {
      return await _connection.setup();
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

  /// Forgets the connection on this device ([everywhere]: on every device
  /// of the account); [removeLinks] also empties the links it found (on
  /// every device, through sync). Throws [PanoptoException] when
  /// [everywhere] and the server can't be reached.
  Future<int> disconnect({
    required bool removeLinks,
    bool everywhere = false,
  }) async {
    state = state.copyWith(busy: true);
    var removed = 0;
    try {
      await _connection.disconnect(everywhere: everywhere);
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

  /// What Panopto has for [session] ("Find in Panopto" in its sheet).
  /// Throws [PanoptoException].
  Future<SessionCheck> checkSession(Occurrence session) =>
      _busyWhile(() => _linker.check(session));

  /// The groups recorded at [meetingId]'s times, for changing its group.
  /// Throws [PanoptoException].
  Future<List<GroupOption>> groupOptions(String courseId, String meetingId) =>
      _busyWhile(() => _linker.groupOptions(courseId, meetingId));

  Future<T> _busyWhile<T>(Future<T> Function() work) async {
    state = state.copyWith(busy: true);
    try {
      return await work();
    } finally {
      state = state.copyWith(busy: false);
    }
  }

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
