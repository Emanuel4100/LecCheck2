import 'dart:convert';
import 'dart:io';

import '../db/schedule_repository.dart';
import 'backup_service.dart';

/// Why a snapshot was taken. The key is part of the file name.
enum SnapshotReason {
  daily('daily'),
  beforeImport('import'),
  beforeRestore('restore'),
  beforeSignOut('signout'),
  beforeAccountSwitch('switch');

  const SnapshotReason(this.key);
  final String key;

  static SnapshotReason? fromKey(String key) =>
      values.where((r) => r.key == key).firstOrNull;
}

class Snapshot {
  const Snapshot(this.file, this.takenAt, this.reason);

  final File file;
  final DateTime takenAt;
  final SnapshotReason reason;
}

/// Automatic local backups: a daily one, and one before anything that
/// replaces or removes data (imports, restores, signing out with "remove",
/// switching accounts). Each is a v3 backup with deleted rows included, so a
/// restore brings back exactly that state. Files are gzipped (about a tenth
/// of the size), which keeps the folder well inside Android's 25 MB backup
/// allowance per app as the years of data grow.
///
/// Kept: the last [keepDaily] daily snapshots, one per week for
/// [keepWeekly] weeks before that, and the last [keepEvents] others.
class SnapshotService {
  SnapshotService(this.repo, this._directory);

  final ScheduleRepository repo;
  final Future<Directory> Function() _directory;

  static const keepDaily = 7;
  static const keepWeekly = 4;
  static const keepEvents = 10;

  static final _name = RegExp(r'^snapshot-(\d{8}T\d{6})-([a-z]+)\.json\.gz$');

  /// Saves the current data. Returns null when there's nothing to save.
  Future<Snapshot?> take(SnapshotReason reason, {DateTime? now}) async {
    final tables = await repo.exportRows(includeDeleted: true);
    if (tables.values.every((rows) => rows.isEmpty)) return null;
    final at = now ?? DateTime.now();
    final dir = await _directory();
    await dir.create(recursive: true);
    final file = File(
      '${dir.path}/snapshot-${_stamp(at)}-${reason.key}.json.gz',
    );
    final json = await BackupService(repo).exportJson(includeDeleted: true);
    // Write then rename, so a crash never leaves a half-written snapshot.
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(gzip.encode(utf8.encode(json)), flush: true);
    await partial.rename(file.path);
    await _prune();
    return Snapshot(file, at, reason);
  }

  /// Takes the daily snapshot unless today's exists.
  Future<void> takeDailyIfDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final today = _stamp(at).substring(0, 8);
    final taken = (await list()).any(
      (s) =>
          s.reason == SnapshotReason.daily &&
          _stamp(s.takenAt).startsWith(today),
    );
    if (!taken) await take(SnapshotReason.daily, now: at);
  }

  /// Newest first.
  Future<List<Snapshot>> list() async {
    final dir = await _directory();
    if (!await dir.exists()) return const [];
    final snapshots = <Snapshot>[];
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      final match = _name.firstMatch(entry.uri.pathSegments.last);
      final reason = SnapshotReason.fromKey(match?.group(2) ?? '');
      final at = match == null ? null : _parseStamp(match.group(1)!);
      if (reason == null || at == null) continue;
      snapshots.add(Snapshot(entry, at, reason));
    }
    return snapshots..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  }

  /// Makes the data what it was in [snapshot], after saving the current
  /// state as a snapshot of its own (so the restore can be undone).
  Future<void> restore(Snapshot snapshot) async {
    final backup = BackupService.parse(
      utf8.decode(gzip.decode(await snapshot.file.readAsBytes())),
    );
    await take(SnapshotReason.beforeRestore);
    await repo.restoreAll(backup.tables);
  }

  Future<void> _prune() async {
    final all = await list();
    final daily = [
      for (final s in all)
        if (s.reason == SnapshotReason.daily) s,
    ];
    final keep = <Snapshot>{...daily.take(keepDaily)};
    final weeks = <DateTime>{};
    for (final s in daily.skip(keepDaily)) {
      final day = DateTime(s.takenAt.year, s.takenAt.month, s.takenAt.day);
      final week = day.subtract(Duration(days: day.weekday - 1));
      if (weeks.length < keepWeekly && weeks.add(week)) keep.add(s);
    }
    keep.addAll(
      all.where((s) => s.reason != SnapshotReason.daily).take(keepEvents),
    );
    for (final s in all) {
      if (!keep.contains(s)) await s.file.delete();
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _stamp(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}${_two(t.month)}${_two(t.day)}'
      'T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

  static DateTime? _parseStamp(String s) => DateTime.tryParse(s);
}
