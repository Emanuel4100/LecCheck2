import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../db/schedule_repository.dart';
import 'hlc.dart';

/// Turns every local change into an outbox entry stamped with a hybrid
/// logical clock. Installed on the repository whenever an account is attached
/// to this device, even before the network connects, so no edit is missed.
class SyncRecorder implements ChangeRecorder {
  SyncRecorder({required this.db, required this.prefs})
    : clock = HlcClock(node: _nodeId(prefs), last: _lastClock(prefs))
        ..offsetMs = prefs.getInt(_offsetKey) ?? 0;

  final AppDatabase db;
  final SharedPreferencesWithCache prefs;
  final HlcClock clock;

  /// Preference holding the account whose data this device keeps.
  static const attachedAccountKey = 'sync.userId';

  static const _nodeKey = 'sync.node';
  static const _clockKey = 'sync.hlc';
  static const _offsetKey = 'sync.clockOffset';

  static String _nodeId(SharedPreferencesWithCache prefs) {
    final existing = prefs.getString(_nodeKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final node = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    prefs.setString(_nodeKey, node);
    return node;
  }

  static Hlc? _lastClock(SharedPreferencesWithCache prefs) {
    final packed = prefs.getString(_clockKey);
    if (packed == null) return null;
    try {
      return Hlc.parse(packed);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> record(
    String table,
    String rowId,
    Map<String, Object?> patch, {
    bool ifAbsent = false,
  }) async {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            tbl: table,
            rowId: rowId,
            patch: jsonEncode(patch),
            hlc: _stamp(),
            ifAbsent: Value(ifAbsent),
          ),
        );
  }

  String _stamp() {
    final stamp = clock.tick().pack();
    prefs.setString(_clockKey, stamp);
    return stamp;
  }

  /// Adopts the server's time (see [HlcClock.correct]).
  void syncTime(int? serverNow) {
    if (serverNow == null) return;
    clock.correct(serverNow);
    prefs.setInt(_offsetKey, clock.offsetMs);
    prefs.setString(_clockKey, clock.last.pack());
  }

  /// Gives outbox entries a new clock and queues them again (after the
  /// server refused them, e.g. for a wrong device clock).
  Future<void> restamp(Iterable<int> seqs) => db.transaction(() async {
    for (final seq in seqs) {
      await (db.update(db.outbox)..where((o) => o.seq.equals(seq))).write(
        OutboxCompanion(hlc: Value(_stamp()), rejected: const Value(null)),
      );
    }
  });

  /// Retries every change the server refused.
  Future<void> retryRejected() async {
    final parked = await (db.select(
      db.outbox,
    )..where((o) => o.rejected.isNotNull())).get();
    await restamp([for (final e in parked) e.seq]);
  }

  /// Moves this device's clock past a clock seen from the server.
  void receive(String? packed) {
    if (packed == null) return;
    try {
      clock.receive(Hlc.parse(packed));
      prefs.setString(_clockKey, clock.last.pack());
    } on FormatException {
      // Ignore malformed clocks.
    }
  }

  /// Offers every live local row to the account — used when guest data joins
  /// an account, or the server's copy was reset. Only fills what the server
  /// doesn't have, so this device's copy never overwrites newer edits or
  /// brings back rows deleted elsewhere.
  Future<void> enqueueAll(ScheduleRepository repo) async {
    final tables = await repo.exportRows();
    await db.transaction(() async {
      for (final MapEntry(key: table, value: rows) in tables.entries) {
        for (final row in rows) {
          await record(table, row['id']! as String, row, ifAbsent: true);
        }
      }
    });
  }
}
