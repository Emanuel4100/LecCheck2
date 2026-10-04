import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../db/schedule_repository.dart';
import 'hlc.dart';

/// Turns every local change into an outbox entry stamped with a hybrid
/// logical clock. Installed on the repository whenever an account is attached
/// to this device, even before the network connects, so no edit is missed.
class SyncRecorder implements ChangeRecorder {
  SyncRecorder({required this.db, required this.prefs})
    : clock = HlcClock(node: _nodeId(prefs), last: _lastClock(prefs));

  final AppDatabase db;
  final SharedPreferencesWithCache prefs;
  final HlcClock clock;

  /// Preference holding the account whose data this device keeps.
  static const attachedAccountKey = 'sync.userId';

  static const _nodeKey = 'sync.node';
  static const _clockKey = 'sync.hlc';

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
    Map<String, Object?> patch,
  ) async {
    final stamp = clock.tick();
    prefs.setString(_clockKey, stamp.pack());
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            tbl: table,
            rowId: rowId,
            patch: jsonEncode(patch),
            hlc: stamp.pack(),
          ),
        );
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

  /// Queues every live local row in full — used when guest data joins an
  /// account for the first time.
  Future<void> enqueueAll(ScheduleRepository repo) async {
    final tables = await repo.exportRows();
    await db.transaction(() async {
      for (final MapEntry(key: table, value: rows) in tables.entries) {
        for (final row in rows) {
          await record(table, row['id']! as String, row);
        }
      }
    });
  }
}
