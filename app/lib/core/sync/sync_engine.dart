import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:http/http.dart' as http;

import '../auth/session.dart';
import '../db/app_database.dart';
import '../db/schedule_repository.dart';
import 'sync_config.dart';
import 'sync_recorder.dart';

enum SyncPhase { connecting, syncing, synced, offline }

@immutable
class SyncState {
  const SyncState(
    this.phase, {
    this.lastSyncedAt,
    this.pending = 0,
    this.failed = 0,
    this.heldUntil,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// Set while the server asked this device to wait (e.g. its daily limit
  /// is used up). Changes stay on the device and sync after this time.
  final DateTime? heldUntil;

  /// Local changes not yet confirmed by the server.
  final int pending;

  /// Local changes the server refused; kept on this device until retried.
  final int failed;

  @override
  bool operator ==(Object other) =>
      other is SyncState &&
      other.phase == phase &&
      other.lastSyncedAt == lastSyncedAt &&
      other.pending == pending &&
      other.failed == failed &&
      other.heldUntil == heldUntil;

  @override
  int get hashCode =>
      Object.hash(phase, lastSyncedAt, pending, failed, heldUntil);
}

/// Keeps this device's database in sync with the user's Durable Object.
///
/// Local writes never wait for it: they land in SQLite and the outbox, and
/// the engine pushes them in the background. Server rows are applied as the
/// new base state with any still-pending local patches re-applied on top.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.repo,
    required this.recorder,
    required this._session,
    this.onSessionRevoked,
    this.watchLifecycle = true,
    bool? pauseWhenHidden,
    this._socketUri,
  }) : pauseWhenHidden =
           pauseWhenHidden ?? (Platform.isAndroid || Platform.isIOS);

  final AppDatabase db;
  final ScheduleRepository repo;
  final SyncRecorder recorder;
  final VoidCallback? onSessionRevoked;
  final bool watchLifecycle;

  /// Phones drop the connection 30 s after the app goes to the background to
  /// save battery. Desktops keep it: a hidden window (another workspace, or
  /// minimized) should still receive changes live.
  final bool pauseWhenHidden;
  Session _session;

  /// Where to connect, if not the configured server (tests).
  final Uri? _socketUri;

  static const _cursorKey = 'lastVersion';
  static const _datasetKey = 'dataset';

  final _states = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState(SyncPhase.connecting);
  DateTime? _lastSyncedAt;
  int _pending = 0;
  int _failed = 0;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  DateTime _lastHeard = DateTime.now();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _pushTimer;
  Timer? _ackTimer;
  Timer? _pauseTimer;
  Timer? _holdTimer;
  StreamSubscription<(int, int)>? _outboxSub;
  AppLifecycleListener? _lifecycle;
  Future<void> _queue = Future.value();
  final _random = Random();

  int _attempt = 0;
  bool _caughtUp = false;
  bool _paused = false;
  bool _disposed = false;
  String? _inflight;
  List<int> _inflightSeqs = const [];

  /// The server's data was reset or restored: offer ours once caught up.
  bool _reoffer = false;

  /// See [SyncState.heldUntil]; [_holds] counts holds in a row.
  DateTime? _heldUntil;
  int _holds = 0;

  bool get _held => _heldUntil != null && DateTime.now().isBefore(_heldUntil!);

  SyncState get state => _state;

  /// Current state first, then every change.
  Stream<SyncState> get states => Stream.multi((controller) {
    controller.add(_state);
    final sub = _states.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });

  set session(Session value) => _session = value;

  void start() {
    _outboxSub = db
        .customSelect(
          'SELECT COUNT(*) - COUNT(rejected) AS n, COUNT(rejected) AS failed '
          'FROM outbox',
          readsFrom: {db.outbox},
        )
        .watch()
        .map(
          (rows) => (rows.first.read<int>('n'), rows.first.read<int>('failed')),
        )
        .listen((counts) {
          _pending = counts.$1;
          _failed = counts.$2;
          _emit(_state.phase);
          if (_pending > 0) _schedulePush();
        });
    if (watchLifecycle) {
      _lifecycle = AppLifecycleListener(
        onPause: _onPause,
        onHide: _onPause,
        onResume: _onResume,
        onShow: _onResume,
      );
    }
    _connect();
  }

  Future<void> dispose() async {
    _disposed = true;
    _lifecycle?.dispose();
    for (final timer in [
      _pingTimer,
      _reconnectTimer,
      _pushTimer,
      _ackTimer,
      _pauseTimer,
      _holdTimer,
    ]) {
      timer?.cancel();
    }
    await _outboxSub?.cancel();
    await _socket?.close();
    await _states.close();
  }

  /// Queues the changes the server refused again ("Retry").
  Future<void> retryRejected() async {
    await recorder.retryRejected();
    syncNow();
  }

  /// Push and pull right away ("Sync now"), even while held.
  void syncNow() {
    _holdTimer?.cancel();
    _heldUntil = null;
    if (_socket == null) {
      _reconnectTimer?.cancel();
      _attempt = 0;
      _connect();
    } else {
      _schedulePush(immediate: true);
    }
  }

  /// Settings → Developer: acts as if the server asked this device to wait
  /// [duration] (Account then shows "Sync paused until …").
  void simulateBusyServer(Duration duration) => _hold(
    retryAt:
        DateTime.now().millisecondsSinceEpoch +
        recorder.clock.offsetMs +
        duration.inMilliseconds,
  );

  // --------------------------------------------------------- connection --

  Future<void> _connect() async {
    if (_disposed || _paused || _socket != null || _held) return;
    _emit(SyncPhase.connecting);
    try {
      final socket = await WebSocket.connect(
        (_socketUri ?? SyncConfig.socket('/v1/sync')).toString(),
        headers: {'Authorization': 'Bearer ${_session.token}'},
      ).timeout(const Duration(seconds: 15));
      if (_disposed || _paused) {
        await socket.close();
        return;
      }
      _socket = socket;
      _attempt = 0;
      _caughtUp = false;
      _inflight = null;
      _lastHeard = DateTime.now();
      _socketSub = socket.listen(
        (data) {
          _lastHeard = DateTime.now();
          _queue = _queue.then((_) => _onMessage(data));
        },
        onDone: () => _onClosed(socket.closeCode),
        onError: (_) => _onClosed(null),
        cancelOnError: true,
      );
      socket.add(
        jsonEncode({
          't': 'hello',
          'since': await _cursor(),
          'dataset': await _meta(db, _datasetKey),
        }),
      );
      _pingTimer = Timer.periodic(_pingEvery, (_) => _ping(socket));
    } on Object catch (e) {
      final status = e is WebSocketException ? e.httpStatusCode : null;
      if (status == 503 || status == 429) {
        // The server (or Cloudflare, for its free plan's request limit) is
        // over capacity: don't spend more requests retrying every minute.
        _hold();
        return;
      }
      _emit(SyncPhase.offline);
      _scheduleReconnect();
      if (_attempt == 3) unawaited(_checkSession());
    }
  }

  static const _pingEvery = Duration(seconds: 30);

  /// Pings keep the connection alive; the server answers each with a pong.
  /// After a laptop wakes from sleep the socket can be dead without any error,
  /// so silence for more than two pings means: drop it and reconnect.
  void _ping(WebSocket socket) {
    if (_socket != socket) return;
    if (DateTime.now().difference(_lastHeard) > _pingEvery * 2.5) {
      unawaited(_socketSub?.cancel());
      unawaited(socket.close().catchError((Object _) {}));
      _onClosed(null);
      return;
    }
    socket.add('{"t":"ping"}');
  }

  void _onClosed(int? code) {
    _socketSub = null;
    _pingTimer?.cancel();
    _ackTimer?.cancel();
    _socket = null;
    _inflight = null;
    _caughtUp = false;
    if (_disposed) return;
    if (code == 4001) {
      onSessionRevoked?.call();
      return;
    }
    _emit(SyncPhase.offline);
    if (!_paused) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _paused || _held) return;
    _reconnectTimer?.cancel();
    _attempt++;
    final seconds = min(60, pow(2, _attempt - 1).toInt());
    final jitter = _random.nextInt(1000);
    _reconnectTimer = Timer(
      Duration(milliseconds: seconds * 1000 + jitter),
      _connect,
    );
  }

  /// After repeated failures, distinguishes "offline" from "revoked".
  Future<void> _checkSession() async {
    try {
      final response = await http
          .post(
            SyncConfig.api('/v1/auth/renew'),
            headers: {'Authorization': 'Bearer ${_session.token}'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) onSessionRevoked?.call();
    } on Object {
      // Still offline.
    }
  }

  /// The server can't save right now: every change stays in the outbox, and
  /// sync resumes at [retryAt] (server time, ms; 00:00 UTC when the free
  /// plan's daily limit is used up), or later if it keeps happening.
  void _hold({int? retryAt}) {
    _holds++;
    final backoff = Duration(seconds: min(3600, 30 << min(_holds, 7)));
    final now = DateTime.now().millisecondsSinceEpoch;
    final asked = Duration(
      milliseconds: max(0, (retryAt ?? 0) - now - recorder.clock.offsetMs),
    );
    var wait = asked > backoff ? asked : backoff;
    // Spread devices out, so they don't all come back at once.
    wait += Duration(
      milliseconds: _random.nextInt(min(300000, wait.inMilliseconds ~/ 10) + 1),
    );
    _heldUntil = DateTime.now().add(wait);
    _holdTimer?.cancel();
    _holdTimer = Timer(wait, () {
      _heldUntil = null;
      _attempt = 0;
      _emit(_state.phase);
      _connect();
    });
    final socket = _socket;
    if (socket != null) {
      unawaited(_socketSub?.cancel());
      unawaited(socket.close().catchError((Object _) {}));
      _onClosed(null);
    } else {
      _emit(SyncPhase.offline);
    }
  }

  void _onPause() {
    if (!pauseWhenHidden) return;
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(seconds: 30), () {
      _paused = true;
      _reconnectTimer?.cancel();
      _socket?.close();
    });
  }

  void _onResume() {
    _pauseTimer?.cancel();
    // Back in front while offline: retry now instead of waiting out the
    // backoff (up to a minute).
    if (!_paused && (_socket != null || _disposed)) return;
    _paused = false;
    _reconnectTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  // ----------------------------------------------------------- messages --

  Future<void> _onMessage(dynamic data) async {
    if (data is! String || _disposed) return;
    final Map<String, Object?> message;
    try {
      message = jsonDecode(data) as Map<String, Object?>;
    } on FormatException {
      return;
    }
    switch (message['t']) {
      case 'changes':
        recorder.receive(message['clock'] as String?);
        recorder.syncTime((message['now'] as num?)?.toInt());
        final catchUp = message['catchUp'] == true;
        final more = message['more'] == true;
        final upto = (message['upto'] as num?)?.toInt() ?? 0;
        if (catchUp && await _datasetChanged(db, message['dataset'])) {
          _reoffer = true;
        }
        // Broadcasts may arrive before our catch-up finished; only trust
        // their cursor once we're caught up, so no versions are skipped.
        await _applyRows(
          (message['rows'] as List? ?? const []).cast<Map<String, Object?>>(),
          cursor: catchUp || _caughtUp ? upto : null,
        );
        if (catchUp && !more) {
          _caughtUp = true;
          if (_pending == 0) _holds = 0;
          if (_reoffer) {
            _reoffer = false;
            await recorder.enqueueAll(repo);
          }
          _schedulePush(immediate: true);
        }
        _markSyncedIfIdle();
      case 'ack':
        if (message['batchId'] != _inflight) return;
        _ackTimer?.cancel();
        _holds = 0;
        await settleBatch(
          db: db,
          repo: repo,
          recorder: recorder,
          seqs: _inflightSeqs,
          reply: message,
        );
        _inflight = null;
        _schedulePush(immediate: true);
      case 'error':
        debugPrint('Sync error: ${message['code']} ${message['message']}');
        final retryAt = message['retryAt'];
        if (retryAt is num) _hold(retryAt: retryAt.toInt());
    }
  }

  Future<void> _applyRows(
    List<Map<String, Object?>> rows, {
    required int? cursor,
  }) => applyServerRows(db, repo, rows, cursor: cursor);

  // --------------------------------------------------------------- push --

  void _schedulePush({bool immediate = false}) {
    _pushTimer?.cancel();
    _pushTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 150),
      () => _queue = _queue.then((_) => _pushPending()),
    );
  }

  Future<void> _pushPending() async {
    final socket = _socket;
    if (socket == null || !_caughtUp || _inflight != null || _disposed) return;
    final entries = await _nextBatch(db);
    if (entries.isEmpty) {
      _markSyncedIfIdle();
      return;
    }
    _inflight = 'b${DateTime.now().microsecondsSinceEpoch}';
    _inflightSeqs = [for (final e in entries) e.seq];
    _emit(SyncPhase.syncing);
    socket.add(
      jsonEncode({
        't': 'push',
        'batchId': _inflight,
        'changes': [for (final e in entries) _changeJson(e)],
      }),
    );
    // A missing ack means the connection is stuck: reconnect and resend.
    _ackTimer?.cancel();
    _ackTimer = Timer(const Duration(seconds: 20), () => socket.close());
  }

  static Map<String, Object?> _changeJson(OutboxEntry e) => {
    'tbl': e.tbl,
    'id': e.rowId,
    'patch': jsonDecode(e.patch),
    'hlc': e.hlc,
    if (e.ifAbsent) 'ifAbsent': true,
  };

  /// The oldest changes not refused by the server.
  static Future<List<OutboxEntry>> _nextBatch(AppDatabase db) =>
      (db.select(db.outbox)
            ..where((o) => o.rejected.isNull())
            ..orderBy([(o) => OrderingTerm.asc(o.seq)])
            ..limit(500))
          .get();

  /// Handles the server's reply to a pushed batch ([seqs], in push order).
  ///
  /// Accepted changes leave the outbox. Refused ones stay, parked with the
  /// reason, so the edit is never lost; a wrong device clock is corrected
  /// and those changes go out again with a new clock. Rows where a pushed
  /// field lost to a newer edit come back corrected.
  @visibleForTesting
  static Future<void> settleBatch({
    required AppDatabase db,
    required ScheduleRepository repo,
    required SyncRecorder recorder,
    required List<int> seqs,
    required Map<String, Object?> reply,
  }) async {
    recorder.receive(reply['clock'] as String?);
    final serverNow = (reply['now'] as num?)?.toInt();
    recorder.syncTime(serverNow);
    final refused = <int, String>{};
    for (final r in (reply['rejected'] as List? ?? const []).whereType<Map>()) {
      final i = r['i'];
      if (i is int && i >= 0 && i < seqs.length) {
        refused[seqs[i]] = r['reason']?.toString() ?? 'rejected';
      }
    }
    if (refused.isNotEmpty) debugPrint('Sync refused: $refused');
    await db.transaction(() async {
      await (db.delete(db.outbox)..where(
            (o) => o.seq.isIn([
              for (final seq in seqs)
                if (!refused.containsKey(seq)) seq,
            ]),
          ))
          .go();
      for (final MapEntry(key: seq, value: reason) in refused.entries) {
        await (db.update(db.outbox)..where((o) => o.seq.equals(seq))).write(
          OutboxCompanion(rejected: Value(reason)),
        );
      }
    });
    // The clock was just corrected from the server's time.
    final skewed = [
      for (final MapEntry(key: seq, value: reason) in refused.entries)
        if (reason == 'clock_skew' && serverNow != null) seq,
    ];
    if (skewed.isNotEmpty) await recorder.restamp(skewed);
    final corrections = reply['rows'] ?? reply['corrections'];
    if (corrections is List && corrections.isNotEmpty) {
      await applyServerRows(
        db,
        repo,
        corrections.cast<Map<String, Object?>>(),
        cursor: null,
      );
    }
  }

  /// Saves the server's dataset id and says whether it differs from the
  /// one this device synced with before (the server's data was reset or
  /// restored).
  static Future<bool> _datasetChanged(AppDatabase db, Object? dataset) async {
    if (dataset is! String) return false;
    final known = await _meta(db, _datasetKey);
    if (known == dataset) return false;
    await db
        .into(db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(key: _datasetKey, value: dataset),
        );
    return known != null;
  }

  static Future<String?> _meta(AppDatabase db, String key) async =>
      (await (db.select(
        db.syncMeta,
      )..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  // -------------------------------------------------------------- state --

  void _markSyncedIfIdle() {
    if (_caughtUp && _inflight == null && _pending == 0) {
      _lastSyncedAt = DateTime.now();
      _emit(SyncPhase.synced);
    } else if (_socket != null) {
      _emit(SyncPhase.syncing);
    }
  }

  void _emit(SyncPhase phase) {
    final next = SyncState(
      phase,
      lastSyncedAt: _lastSyncedAt,
      pending: _pending,
      failed: _failed,
      heldUntil: _held ? _heldUntil : null,
    );
    if (next == _state || _states.isClosed) return;
    _state = next;
    _states.add(next);
  }

  Future<int> _cursor() async =>
      int.tryParse(await _meta(db, _cursorKey) ?? '') ?? 0;

  /// Forgets the server cursor and dataset (after wiping local data or
  /// leaving the account).
  static Future<void> resetCursor(AppDatabase db) => (db.delete(
    db.syncMeta,
  )..where((m) => m.key.isIn([_cursorKey, _datasetKey]))).go();

  // ---------------------------------------------------------- utilities --

  /// Applies server rows as the new base state, re-applying pending local
  /// patches on top, and saves [cursor] in the same transaction.
  static Future<void> applyServerRows(
    AppDatabase db,
    ScheduleRepository repo,
    List<Map<String, Object?>> rows, {
    required int? cursor,
  }) => db.transaction(() async {
    for (final row in rows) {
      final table = row['tbl']! as String;
      final id = row['id']! as String;
      final merged = Map<String, Object?>.from(row['data']! as Map);
      final pending =
          await (db.select(db.outbox)
                ..where((o) => o.tbl.equals(table) & o.rowId.equals(id))
                ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
              .get();
      for (final p in pending) {
        final patch = Map<String, Object?>.from(jsonDecode(p.patch) as Map);
        if (p.ifAbsent) {
          // The server keeps what it has; only missing fields come from us.
          for (final e in patch.entries) {
            merged.putIfAbsent(e.key, () => e.value);
          }
        } else {
          merged.addAll(patch);
        }
      }
      await repo.applyRemoteRow(table, merged);
    }
    if (cursor != null) {
      await db
          .into(db.syncMeta)
          .insertOnConflictUpdate(
            SyncMetaCompanion.insert(key: _cursorKey, value: '$cursor'),
          );
    }
  });

  /// One-shot sync over HTTP, for background isolates (notification actions,
  /// home-screen widget) that can't keep a socket open.
  static Future<void> syncOverHttp({
    required AppDatabase db,
    required ScheduleRepository repo,
    required SyncRecorder recorder,
    required Session session,
  }) async {
    final entries = await _nextBatch(db);
    var since = int.tryParse(await _meta(db, _cursorKey) ?? '') ?? 0;
    final response = await http
        .post(
          SyncConfig.api('/v1/sync'),
          headers: {
            'Authorization': 'Bearer ${session.token}',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'since': since,
            'dataset': await _meta(db, _datasetKey),
            'changes': [for (final e in entries) _changeJson(e)],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return;
    final body = jsonDecode(response.body) as Map<String, Object?>;
    await settleBatch(
      db: db,
      repo: repo,
      recorder: recorder,
      seqs: [for (final e in entries) e.seq],
      reply: body,
    );
    final reoffer = await _datasetChanged(db, body['dataset']);
    await applyServerRows(
      db,
      repo,
      (body['rows'] as List? ?? const []).cast<Map<String, Object?>>(),
      cursor: (body['upto'] as num?)?.toInt() ?? since,
    );
    // Pushed on the next sync.
    if (reoffer) await recorder.enqueueAll(repo);
  }
}
