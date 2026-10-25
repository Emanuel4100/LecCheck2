import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/auth/session.dart';
import 'package:leccheck/core/db/app_database.dart';
import 'package:leccheck/core/db/schedule_repository.dart';
import 'package:leccheck/core/sync/sync_engine.dart';
import 'package:leccheck/core/sync/sync_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('"Sync now" with no server: false right away, not after the '
      'timeout', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final engine = SyncEngine(
      db: db,
      repo: ScheduleRepository(db),
      recorder: SyncRecorder(db: db, prefs: prefs),
      session: const Session(token: 't', userId: 'u1'),
      watchLifecycle: false,
      // Nothing listens on port 9.
      socketUri: Uri.parse('ws://127.0.0.1:9/v1/sync'),
    );
    addTearDown(engine.dispose);
    final watch = Stopwatch()..start();
    expect(await engine.syncNow(timeout: const Duration(seconds: 8)), isFalse);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(engine.state.phase, SyncPhase.offline);
  });
}
