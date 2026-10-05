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
  const SyncState(this.phase, {this.lastSyncedAt, this.pending = 0});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// Local changes not yet confirmed by the server.
  final int pending;

  @override
  bool operator ==(Object other) =>
      other is SyncState &&
      other.phase == phase &&
      other.lastSyncedAt == lastSyncedAt &&
      other.pending == pending;

  @override
  int get hashCode => Object.hash(phase, lastSyncedAt, pending);
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

  static const _cursorKey = 'lastVersion';

  final _states = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState(SyncPhase.connecting);
  DateTime? _lastSyncedAt;
  int _pending = 0;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  DateTime _lastHeard = DateTime.now();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _pushTimer;
  Timer? _ackTimer;
  Timer? _pauseTimer;
  StreamSubscription<int>? _outboxSub;
  AppLifecycleListener? _lifecycle;
  Future<void> _queue = Future.value();
  final _random = Random();

  int _attempt = 0;
  bool _caughtUp = false;
  bool _paused = false;
  bool _disposed = false;
  String? _inflight;
  int _inflightMaxSeq = 0;

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
          'SELECT COUNT(*) AS n FROM outbox',
          readsFrom: {db.outbox},
        )
        .watch()
        .map((rows) => rows.first.read<int>('n'))
        .listen((count) {
          _pending = count;
          _emit(_state.phase);
          if (count > 0) _schedulePush();
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
    ]) {
      timer?.cancel();
    }
    await _outboxSub?.cancel();
    await _socket?.close();
    await _states.close();
  }

  /// Push and pull right away ("Sync now").
  void syncNow() {
    if (_socket == null) {
      _reconnectTimer?.cancel();
      _attempt = 0;
      _connect();
    } else {
      _schedulePush(immediate: true);
    }
  }

  // --------------------------------------------------------- connection --

  Future<void> _connect() async {
    if (_disposed || _paused || _socket != null) return;
    _emit(SyncPhase.connecting);
    try {
      final socket = await WebSocket.connect(
        SyncConfig.socket('/v1/sync').toString(),
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
      socket.add(jsonEncode({'t': 'hello', 'since': await _cursor()}));
      _pingTimer = Timer.periodic(_pingEvery, (_) => _ping(socket));
    } on Object {
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
    if (_disposed || _paused) return;
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
        final catchUp = message['catchUp'] == true;
        final more = message['more'] == true;
        final upto = (message['upto'] as num?)?.toInt() ?? 0;
        // Broadcasts may arrive before our catch-up finished; only trust
        // their cursor once we're caught up, so no versions are skipped.
        await _applyRows(
          (message['rows'] as List? ?? const []).cast<Map<String, Object?>>(),
          cursor: catchUp || _caughtUp ? upto : null,
        );
        if (catchUp && !more) {
          _caughtUp = true;
          _schedulePush(immediate: true);
        }
        _markSyncedIfIdle();
      case 'ack':
        if (message['batchId'] != _inflight) return;
        _ackTimer?.cancel();
        recorder.receive(message['clock'] as String?);
        await (db.delete(
          db.outbox,
        )..where((o) => o.seq.isSmallerOrEqualValue(_inflightMaxSeq))).go();
        final rejected = message['rejected'] as List? ?? const [];
        if (rejected.isNotEmpty) debugPrint('Sync rejected: $rejected');
        _inflight = null;
        _schedulePush(immediate: true);
      case 'error':
        debugPrint('Sync error: ${message['code']} ${message['message']}');
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
    final entries =
        await (db.select(db.outbox)
              ..orderBy([(o) => OrderingTerm.asc(o.seq)])
              ..limit(500))
            .get();
    if (entries.isEmpty) {
      _markSyncedIfIdle();
      return;
    }
    _inflight = 'b${DateTime.now().microsecondsSinceEpoch}';
    _inflightMaxSeq = entries.last.seq;
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
  };

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
    );
    if (next == _state || _states.isClosed) return;
    _state = next;
    _states.add(next);
  }

  Future<int> _cursor() async {
    final row = await (db.select(
      db.syncMeta,
    )..where((m) => m.key.equals(_cursorKey))).getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  /// Forgets the server cursor (after wiping local data or switching account).
  static Future<void> resetCursor(AppDatabase db) =>
      (db.delete(db.syncMeta)..where((m) => m.key.equals(_cursorKey))).go();

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
        merged.addAll(Map<String, Object?>.from(jsonDecode(p.patch) as Map));
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
    final entries =
        await (db.select(db.outbox)
              ..orderBy([(o) => OrderingTerm.asc(o.seq)])
              ..limit(500))
            .get();
    final cursorRow = await (db.select(
      db.syncMeta,
    )..where((m) => m.key.equals(_cursorKey))).getSingleOrNull();
    var since = int.tryParse(cursorRow?.value ?? '') ?? 0;
    final response = await http
        .post(
          SyncConfig.api('/v1/sync'),
          headers: {
            'Authorization': 'Bearer ${session.token}',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'since': since,
            'changes': [for (final e in entries) _changeJson(e)],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return;
    final body = jsonDecode(response.body) as Map<String, Object?>;
    if (entries.isNotEmpty) {
      await (db.delete(
        db.outbox,
      )..where((o) => o.seq.isSmallerOrEqualValue(entries.last.seq))).go();
    }
    recorder.receive(body['clock'] as String?);
    await applyServerRows(
      db,
      repo,
      (body['rows'] as List? ?? const []).cast<Map<String, Object?>>(),
      cursor: (body['upto'] as num?)?.toInt() ?? since,
    );
  }
}
