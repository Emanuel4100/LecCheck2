import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backup/backup_service.dart';
import '../core/update/tarball_install.dart';
import '../domain/local_date.dart';
import 'providers.dart';
import 'sync_providers.dart';

/// The steps of moving to the Flatpak, as its window lists them.
enum MoveStep {
  /// Signed in: everything synced to the account, which the Flatpak gets
  /// back by signing in. Otherwise a backup to import there.
  data,
  install,

  /// This version's files (not its data).
  remove,
}

/// How far the move got.
enum MovePhase {
  /// Not started: the window explains the move.
  idle,

  /// Signed in: syncing the last changes.
  syncing,

  /// Waiting for "Save a backup…": signed out, or changes that didn't sync.
  backup,
  installing,
  removing,

  /// Moved: "Open LecCheck" starts the Flatpak.
  ready,
  failed,
}

/// What went wrong.
enum MoveFailure {
  /// The backup wasn't saved.
  backup,

  /// Flatpak isn't installed on this computer.
  noFlatpak,

  /// `flatpak install` failed ([MoveState.detail]: what it said).
  install,

  /// This version's files couldn't be removed.
  remove,
}

/// What the move window and card show.
@immutable
class MoveState {
  const MoveState({
    this.offered = false,
    this.later = false,
    this.phase = MovePhase.idle,
    this.synced = false,
    this.empty = false,
    this.backup,
    this.output,
    this.failure,
    this.failedStep,
    this.detail,
  });

  /// install.sh installed this app: it moves to the Flatpak.
  final bool offered;

  /// "Later" on Today: shown in Settings only.
  final bool later;

  final MovePhase phase;

  /// Signed in, and everything synced to the account.
  final bool synced;

  /// No semesters here: nothing to bring along.
  final bool empty;

  /// The saved backup's path.
  final String? backup;

  /// What `flatpak install` printed last.
  final String? output;

  final MoveFailure? failure;
  final MoveStep? failedStep;

  /// The error, for the window (flatpak's own words).
  final String? detail;

  /// The data step is done: nothing is left only on this computer.
  bool get dataReady => synced || empty || backup != null;

  MoveState copyWith({
    bool? offered,
    bool? later,
    MovePhase? phase,
    bool? synced,
    bool? empty,
    String? backup,
    String? output,
  }) => MoveState(
    offered: offered ?? this.offered,
    later: later ?? this.later,
    phase: phase ?? this.phase,
    synced: synced ?? this.synced,
    empty: empty ?? this.empty,
    backup: backup ?? this.backup,
    output: output ?? this.output,
    // A new phase forgets the last failure.
    failure: phase == null ? failure : null,
    failedStep: phase == null ? failedStep : null,
    detail: phase == null ? detail : null,
  );

  @override
  bool operator ==(Object other) =>
      other is MoveState &&
      other.offered == offered &&
      other.later == later &&
      other.phase == phase &&
      other.synced == synced &&
      other.empty == empty &&
      other.backup == backup &&
      other.output == output &&
      other.failure == failure &&
      other.failedStep == failedStep &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(
    offered,
    later,
    phase,
    synced,
    empty,
    backup,
    output,
    failure,
    failedStep,
    detail,
  );
}

/// Moves a Linux install made by install.sh to the Flatpak, which LecCheck
/// for Linux is since 2.0.0-beta.15 (2.0.0-beta.15 is the last tarball).
/// The Flatpak keeps its data in its own folder, so the data comes along
/// through the account (synced first, then signing in again there) or a
/// backup (saved here, imported on the Flatpak's welcome screen). Then it
/// installs the Flatpak for this user, removes this version's files (not
/// its data, which stays as one more backup) and opens the Flatpak.
class MoveController extends Notifier<MoveState> {
  static const _laterKey = 'move.later';

  /// The install.sh folder this app runs from, if any; replaced in tests.
  @visibleForTesting
  static Future<String?> Function() installDir = TarballInstall.installDir;

  /// Replaced in tests, like the ones below.
  @visibleForTesting
  static Future<String?> Function() flatpakVersion =
      TarballInstall.flatpakVersion;

  @visibleForTesting
  static Future<bool> Function() flatpakInstalled =
      TarballInstall.flatpakInstalled;

  @visibleForTesting
  static Future<void> Function({void Function(String line)? onOutput})
  installFlatpak = TarballInstall.installFlatpak;

  @visibleForTesting
  static Future<void> Function(String dir) uninstall = TarballInstall.uninstall;

  @visibleForTesting
  static Future<void> Function(List<String> command) startAfterExit =
      TarballInstall.startAfterExit;

  /// Asks where to save the backup: its path, or null when cancelled.
  @visibleForTesting
  static Future<String?> Function(String name, Uint8List bytes) saveFile =
      (name, bytes) async {
        final saved = await FilePicker.saveFile(
          fileName: name,
          bytes: bytes,
          mimeType: 'application/json',
          allowedExtensions: const ['json'],
        );
        if (saved == null) return null;
        return saved.scheme == 'file' ? saved.toFilePath() : '$saved';
      };

  /// How long a sync may take before a backup is asked for instead.
  @visibleForTesting
  static Duration syncTimeout = const Duration(seconds: 20);

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  String? _dir;
  bool _prompted = false;

  @override
  MoveState build() => const MoveState();

  /// Finds out whether install.sh installed this app (at startup).
  Future<void> init() async {
    final dir = _dir = await installDir();
    if (dir != null && ref.mounted) {
      state = state.copyWith(
        offered: true,
        later: _prefs.getBool(_laterKey) ?? false,
      );
    }
  }

  /// True once per launch while the move waits: its window then opens by
  /// itself.
  bool takePrompt() {
    if (_prompted || !state.offered || state.phase != MovePhase.idle) {
      return false;
    }
    _prompted = true;
    return true;
  }

  /// "Later" on Today: the card stays in Settings.
  Future<void> later() async {
    await _prefs.setBool(_laterKey, true);
    state = state.copyWith(later: true);
  }

  bool get _busy => switch (state.phase) {
    MovePhase.syncing ||
    MovePhase.installing ||
    MovePhase.removing ||
    MovePhase.ready => true,
    _ => false,
  };

  /// Move (and Retry): makes sure the data comes along, then installs.
  Future<void> start() async {
    final dir = _dir;
    if (dir == null || _busy) return;
    if (!state.dataReady) {
      final repo = ref.read(repositoryProvider);
      if ((await repo.semesters()).isEmpty) {
        state = state.copyWith(phase: MovePhase.installing, empty: true);
      } else if (ref.read(authProvider).value == null ||
          ref.read(attachedAccountProvider) == null) {
        state = state.copyWith(phase: MovePhase.backup);
        return;
      } else {
        state = state.copyWith(phase: MovePhase.syncing);
        if (!await _syncEverything()) {
          // Waits for "Save a backup…".
          if (ref.mounted) state = state.copyWith(phase: MovePhase.backup);
          return;
        }
        if (!ref.mounted) return;
        state = state.copyWith(synced: true);
      }
    }
    await _install(dir);
  }

  /// "Save a backup…": every semester to a file the Flatpak imports, then
  /// the move goes on.
  Future<void> saveBackup() async {
    final dir = _dir;
    if (dir == null || _busy) return;
    final String? path;
    try {
      final json = await BackupService(ref.read(repositoryProvider))
          .exportJson();
      path = await saveFile(
        'leccheck-backup-${LocalDate.today().toIso()}.json',
        utf8.encode(json),
      );
    } on Object catch (e) {
      debugPrint('Move: backup not saved: $e');
      _fail(MoveStep.data, MoveFailure.backup, '$e');
      return;
    }
    if (path == null || !ref.mounted) return; // Cancelled: still waiting.
    state = state.copyWith(backup: path);
    await _install(dir);
  }

  /// "Open LecCheck": quits, and the Flatpak starts.
  Future<void> open() async {
    if (state.phase != MovePhase.ready) return;
    await startAfterExit(['flatpak', 'run', TarballInstall.appId]);
  }

  /// Whether every change is on the server: syncs now when some wait.
  Future<bool> _syncEverything() async {
    if (await _allSynced()) return true;
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return false;
    final ok = await engine
        .syncNow(timeout: syncTimeout)
        .catchError((Object _) => false);
    return ok && await _allSynced();
  }

  Future<bool> _allSynced() async {
    // Listened to while read: Riverpod pauses a provider nobody listens to,
    // and its future would never come.
    final listening = ref.listen(outboxCountsProvider, (_, _) {});
    try {
      final counts = await ref.read(outboxCountsProvider.future);
      return counts.pending == 0 && counts.refused == 0;
    } finally {
      listening.close();
    }
  }

  Future<void> _install(String dir) async {
    if (!ref.mounted) return;
    state = state.copyWith(phase: MovePhase.installing);
    try {
      if (await flatpakVersion() == null) {
        _fail(MoveStep.install, MoveFailure.noFlatpak, null);
        return;
      }
      if (!await flatpakInstalled()) {
        await installFlatpak(
          onOutput: (line) {
            if (ref.mounted) state = state.copyWith(output: line);
          },
        );
      }
    } on ProcessException catch (e) {
      debugPrint('Move: flatpak install failed: $e');
      _fail(MoveStep.install, MoveFailure.install, e.message);
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(phase: MovePhase.removing);
    try {
      await uninstall(dir);
    } on Object catch (e) {
      debugPrint('Move: not removed: $e');
      _fail(
        MoveStep.remove,
        MoveFailure.remove,
        e is ProcessException ? e.message : '$e',
      );
      return;
    }
    if (ref.mounted) state = state.copyWith(phase: MovePhase.ready);
  }

  void _fail(MoveStep step, MoveFailure failure, String? detail) {
    if (!ref.mounted) return;
    state = MoveState(
      offered: state.offered,
      later: state.later,
      phase: MovePhase.failed,
      synced: state.synced,
      empty: state.empty,
      backup: state.backup,
      output: state.output,
      failure: failure,
      failedStep: step,
      detail: detail,
    );
  }
}

final moveProvider = NotifierProvider<MoveController, MoveState>(
  MoveController.new,
);
