import 'dart:async';

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

  /// Signs in and attaches the account to this device.
  ///
  /// - Guest data (never synced) joins the account, without overwriting
  ///   anything the account already has.
  /// - The same account again: edits made while signed out sync normally.
  /// - Data from a *different* account is only replaced after
  ///   [confirmReplace] returns true (v1 silently pushed it into the new
  ///   account), and a snapshot of it is kept.
  Future<void> signIn({
    required Future<bool> Function() confirmReplace,
    String? devName,
  }) async {
    final session = devName == null
        ? await _auth.signInWithGoogle()
        : await _auth.signInDev(devName);
    final attached = ref.read(attachedAccountProvider);
    final repo = ref.read(repositoryProvider);
    final db = ref.read(databaseProvider);
    final accounts = ref.read(attachedAccountProvider.notifier);

    if (attached != null && attached != session.userId) {
      if (!await confirmReplace()) {
        await _auth.clear();
        return;
      }
      await ref
          .read(snapshotServiceProvider)
          .take(SnapshotReason.beforeAccountSwitch);
      accounts.detach();
      await repo.wipeAll();
      await SyncEngine.resetCursor(db);
      accounts.attach(session.userId);
    } else if (attached == null) {
      accounts.attach(session.userId);
      await ref.read(syncRecorderProvider)?.enqueueAll(repo);
    }
    final before = {for (final s in await repo.semesters()) s.id};
    state = AsyncData(session);
    unawaited(_showRestoredSemester(before));
  }

  /// After the first sync of a sign-in, switches to a semester the account
  /// brought in, so its data doesn't hide behind one made on this device
  /// while signed out.
  Future<void> _showRestoredSemester(Set<String> before) async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;
    try {
      await engine.states
          .firstWhere((s) => s.phase == SyncPhase.synced)
          .timeout(const Duration(seconds: 30));
    } on Object {
      return;
    }
    final restored = [
      for (final s in await ref.read(repositoryProvider).semesters())
        if (!before.contains(s.id)) s,
    ];
    final pick = pickSemester(restored, LocalDate.today());
    if (pick != null) {
      ref.read(activeSemesterChoiceProvider.notifier).select(pick.id);
    }
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
