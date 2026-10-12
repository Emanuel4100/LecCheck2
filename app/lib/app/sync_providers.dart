import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/auth/session.dart';
import '../core/backup/snapshot_service.dart';
import '../core/sync/sync_config.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_recorder.dart';
import '../domain/local_date.dart';
import '../domain/schedule_types.dart';
import 'providers.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Whether this build syncs at all ([SyncConfig.enabled], set at build
/// time); a provider so tests can turn it on.
final syncConfiguredProvider = Provider<bool>((ref) => SyncConfig.enabled);

/// The account whose data this device holds (persisted). While set, every
/// local change is recorded for sync — even when signed out with "keep on
/// this device", so those edits sync when the same account signs in again.
class AttachedAccountController extends Notifier<String?> {
  static const _key = SyncRecorder.attachedAccountKey;

  @override
  String? build() => ref.read(sharedPrefsProvider).getString(_key);

  void attach(String userId) {
    state = userId;
    ref.read(sharedPrefsProvider).setString(_key, userId);
  }

  void detach() {
    state = null;
    ref.read(sharedPrefsProvider).remove(_key);
  }
}

final attachedAccountProvider =
    NotifierProvider<AttachedAccountController, String?>(
      AttachedAccountController.new,
    );

final syncRecorderProvider = Provider<SyncRecorder?>((ref) {
  if (!ref.watch(syncConfiguredProvider) ||
      ref.watch(attachedAccountProvider) == null) {
    return null;
  }
  return SyncRecorder(
    db: ref.watch(databaseProvider),
    prefs: ref.watch(sharedPrefsProvider),
  );
});

enum SignOutMode { keepData, removeData }

/// Signing in on a device with data made while signed out, into an account
/// that has data too.
enum JoinChoice {
  /// Only the account's data: this device's goes to an automatic backup.
  useAccount,

  /// This device's data joins the account's.
  keepBoth,
}

/// How a sign-in went, for the page that started it.
enum SignInResult {
  cancelled,

  /// A new account and an empty device: set up a semester.
  newAccount,

  /// This device is empty and the account's data is on its way
  /// ([restoreProvider] says when it's here).
  restoring,

  /// This device keeps its data (and gets the account's).
  joined,
}

/// Waiting for an account's data after signing in on an empty device. Kept
/// here, not in the Welcome page, so it survives the page being rebuilt
/// (switching accounts empties the device and shows Welcome again).
enum RestorePhase {
  idle,
  waiting,

  /// The first sync brought no semesters: set one up.
  empty,

  /// No first sync within 30 seconds (offline, server busy).
  failed,
}

class RestoreController extends Notifier<RestorePhase> {
  @override
  RestorePhase build() => RestorePhase.idle;

  void wait() => state = RestorePhase.waiting;

  void reset() => state = RestorePhase.idle;

  /// The first sync finished (or timed out, when [synced] is false).
  void firstSync({required bool synced, required bool hasSemesters}) {
    if (state != RestorePhase.waiting) return;
    state = !synced
        ? RestorePhase.failed
        : hasSemesters
        ? RestorePhase.idle
        : RestorePhase.empty;
  }
}

final restoreProvider = NotifierProvider<RestoreController, RestorePhase>(
  RestoreController.new,
);

/// Set when a sign-in brought semesters from the account: the app then asks
/// which one to open (or to start a new one).
class SemesterChoiceController extends Notifier<bool> {
  @override
  bool build() => false;

  void ask() => state = true;

  void clear() => state = false;
}

final semesterChoiceProvider = NotifierProvider<SemesterChoiceController, bool>(
  SemesterChoiceController.new,
);

/// Waits for the sync engine's first sync: true once it's done, false after
/// [timeout] or without an engine. Replaced in tests.
final firstSyncProvider = Provider<Future<bool> Function(Duration timeout)>(
  (ref) => (timeout) async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return false;
    try {
      await engine.states
          .firstWhere((s) => s.phase == SyncPhase.synced)
          .timeout(timeout);
      return true;
    } on Object {
      return false;
    }
  },
);

/// The semester running on [today], otherwise the latest one ([semesters] is
/// sorted newest first).
SemesterInfo? pickSemester(List<SemesterInfo> semesters, LocalDate today) =>
    semesters.where((s) => today.isWithin(s.start, s.end)).firstOrNull ??
    semesters.firstOrNull;

class AuthController extends AsyncNotifier<Session?> {
  AuthService get _auth => ref.read(authServiceProvider);

  @override
  Future<Session?> build() async {
    if (!ref.watch(syncConfiguredProvider)) return null;
    final session = await _auth.load();
    if (session == null) return null;
    final renewed = await _auth
        .renewIfNeeded(session)
        .timeout(const Duration(seconds: 10), onTimeout: () => session);
    if (renewed == null) {
      await _auth.clear();
      return null;
    }
    return renewed;
  }

  /// Signs in and attaches the account to this device. Asks first, through
  /// the callbacks, whenever data could be mixed or replaced:
  ///
  /// - Data from a *different* account is only replaced after
  ///   [confirmReplace] (v1 silently pushed it into the new account), and a
  ///   snapshot of it is kept.
  /// - Data made while signed out, when the account has data too:
  ///   [chooseJoin] picks the account's only (this device's goes to a
  ///   snapshot) or both. Without that question every new device added its
  ///   setup semester to the account (issue #2).
  /// - An empty account whose data was deleted in the last 30 days:
  ///   [offerRestore] can bring it back.
  /// - The same account again: edits made while signed out sync normally.
  ///
  /// When the server can't say what the account holds (offline, an older
  /// server), the device's data joins the account, as before: nothing is
  /// lost.
  Future<SignInResult> signIn({
    required Future<bool> Function() confirmReplace,
    required Future<JoinChoice?> Function(AccountSummary account, int local)
    chooseJoin,
    required Future<bool> Function(DateTime deletedAt) offerRestore,
    String? devName,
  }) async {
    final session = devName == null
        ? await _auth.signInWithGoogle()
        : await _auth.signInDev(devName);
    final summary = await _auth.accountSummary(session);
    final attached = ref.read(attachedAccountProvider);
    final repo = ref.read(repositoryProvider);
    final db = ref.read(databaseProvider);
    final accounts = ref.read(attachedAccountProvider.notifier);
    final snapshots = ref.read(snapshotServiceProvider);
    final local = await repo.semesters();
    var bringBack = false;

    Future<SignInResult> cancel() async {
      await _auth.clear();
      return SignInResult.cancelled;
    }

    if (attached != null && attached != session.userId) {
      if (!await confirmReplace()) return cancel();
      await snapshots.take(SnapshotReason.beforeAccountSwitch);
      accounts.detach();
      await repo.wipeAll();
      await SyncEngine.resetCursor(db);
      accounts.attach(session.userId);
    } else if (attached == null) {
      if (summary != null && summary.semesters > 0 && local.isNotEmpty) {
        switch (await chooseJoin(summary, local.length)) {
          case null:
            return cancel();
          case JoinChoice.useAccount:
            await snapshots.take(SnapshotReason.beforeSignIn);
            await repo.wipeAll();
            await SyncEngine.resetCursor(db);
            accounts.attach(session.userId);
          case JoinChoice.keepBoth:
            accounts.attach(session.userId);
            await ref.read(syncRecorderProvider)?.enqueueAll(repo);
        }
      } else {
        final deletedAt = summary?.deletedAt;
        if (summary != null && summary.semesters == 0 && deletedAt != null) {
          bringBack = await offerRestore(deletedAt);
        }
        accounts.attach(session.userId);
        await ref.read(syncRecorderProvider)?.enqueueAll(repo);
      }
    }

    final before = {for (final s in await repo.semesters()) s.id};
    final expectData = summary == null || summary.semesters > 0 || bringBack;
    final result = before.isNotEmpty
        ? SignInResult.joined
        : expectData
        ? SignInResult.restoring
        : SignInResult.newAccount;
    if (result == SignInResult.restoring) {
      ref.read(restoreProvider.notifier).wait();
    }
    state = AsyncData(session);
    if (bringBack) {
      try {
        await _auth.restoreDeleted(session);
      } on Object catch (e) {
        debugPrint('Bringing back deleted data failed: $e');
      }
    }
    unawaited(_afterFirstSync(before));
    return result;
  }

  /// After the first sync of a sign-in: tells a waiting Welcome page whether
  /// the account had semesters, and asks which semester to open when the
  /// account brought some. Until then, the one running today is shown.
  Future<void> _afterFirstSync(Set<String> before) async {
    final synced = await ref.read(firstSyncProvider)(
      const Duration(seconds: 30),
    );
    // A fresh query: the semester list provider may not have caught up with
    // the rows the sync just wrote (it used to send accounts with data to
    // the setup form).
    final semesters = await ref.read(repositoryProvider).semesters();
    final restored = [
      for (final s in semesters)
        if (!before.contains(s.id)) s,
    ];
    final pick = pickSemester(restored, LocalDate.today());
    if (pick != null) {
      ref.read(activeSemesterChoiceProvider.notifier).select(pick.id);
      ref.read(semesterChoiceProvider.notifier).ask();
    }
    ref
        .read(restoreProvider.notifier)
        .firstSync(synced: synced, hasSemesters: semesters.isNotEmpty);
  }

  /// Try again (Welcome), when the account's data didn't arrive in time.
  Future<void> retryRestore() async {
    ref.read(restoreProvider.notifier).wait();
    ref.read(syncEngineProvider)?.syncNow();
    await _afterFirstSync(const {});
  }

  /// Signs out. With [SignOutMode.keepData] the device stays attached to the
  /// account: edits keep queueing (nothing unsynced is dropped) and sync when
  /// the account signs in again. [SignOutMode.removeData] saves a snapshot
  /// first, then removes the data.
  Future<void> signOut(SignOutMode mode) async {
    if (mode == SignOutMode.removeData) {
      await ref
          .read(snapshotServiceProvider)
          .take(SnapshotReason.beforeSignOut);
    }
    await _auth.clear();
    state = const AsyncData(null);
    if (mode == SignOutMode.removeData) {
      await _detach();
      await ref.read(repositoryProvider).wipeAll();
    }
  }

  /// Leaves the account; the data here becomes guest data.
  Future<void> _detach() async {
    final db = ref.read(databaseProvider);
    ref.read(attachedAccountProvider.notifier).detach();
    await SyncEngine.resetCursor(db);
    await db.delete(db.outbox).go();
  }

  Future<void> signOutEverywhere() async {
    final session = state.value;
    if (session == null) return;
    await _auth.signOutEverywhere(session);
    await signOut(SignOutMode.keepData);
  }

  /// Deletes the cloud copy (the server keeps it restorable for 30 days);
  /// local data stays as guest data.
  Future<void> deleteCloudData() async {
    final session = state.value;
    if (session == null) return;
    await _auth.deleteAccount(session);
    await signOut(SignOutMode.keepData);
    await _detach();
  }

  /// Renews the token if it's a week old (the sync engine asks before each
  /// connection). Null if the server revoked the session.
  Future<Session?> renew(Session session) async {
    final renewed = await _auth.renewIfNeeded(session);
    if (renewed != null &&
        renewed.token != session.token &&
        state.value?.userId == renewed.userId) {
      state = AsyncData(renewed);
    }
    return renewed;
  }

  /// The server revoked this session (e.g. "sign out everywhere" elsewhere).
  void sessionRevoked() {
    unawaited(_auth.clear());
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);

/// Runs while signed in; null otherwise. Rebuilt when the account changes,
/// not when its token is renewed (the engine renews it itself).
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.value?.userId));
  final session = ref.read(authProvider).value;
  final recorder = ref.watch(syncRecorderProvider);
  if (userId == null || session == null || recorder == null) return null;
  final engine = SyncEngine(
    db: ref.watch(databaseProvider),
    repo: ref.watch(repositoryProvider),
    recorder: recorder,
    session: session,
    onSessionRevoked: () => ref.read(authProvider.notifier).sessionRevoked(),
    renew: (s) => ref.read(authProvider.notifier).renew(s),
  )..start();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Changes waiting to sync, and refused ones, straight from the outbox:
/// also while signed out, when there's no engine (or sync state) at all.
final outboxCountsProvider = StreamProvider<({int pending, int refused})>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT COUNT(*) - COUNT(rejected) AS pending, COUNT(rejected) AS '
        'refused FROM outbox',
        readsFrom: {db.outbox},
      )
      .watch()
      .map(
        (rows) => (
          pending: rows.first.read<int>('pending'),
          refused: rows.first.read<int>('refused'),
        ),
      );
});

final syncStateProvider = StreamProvider<SyncState?>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine == null ? Stream.value(null) : engine.states;
});
