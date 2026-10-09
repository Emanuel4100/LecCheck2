import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/android_device.dart';
import '../core/update/update_service.dart';
import 'adaptive.dart';
import 'providers.dart';

/// What the update notice shows.
@immutable
class UpdateState {
  const UpdateState({this.update, this.enabled = true, this.later = false});

  /// The newer release to offer (none: up to date, skipped, or unknown).
  final AppUpdate? update;

  /// Settings → About → Check for updates.
  final bool enabled;

  /// "Later" on Today: shown in Settings only, until the next version.
  final bool later;

  @override
  bool operator ==(Object other) =>
      other is UpdateState &&
      other.update == update &&
      other.enabled == enabled &&
      other.later == later;

  @override
  int get hashCode => Object.hash(update, enabled, later);
}

/// Tells Android and Linux users about new releases (no store does: the
/// APK and the tarball come from GitHub). Checks after the first frame and
/// when the app comes back, at most once a day; the last answer is kept, so
/// the notice survives restarts offline. iPhone updates come from AltStore.
class UpdateController extends Notifier<UpdateState> {
  static const _enabledKey = 'update.check';
  static const _checkedAtKey = 'update.checkedAt';
  static const _manifestKey = 'update.manifest';
  static const _skippedKey = 'update.skipBuild';
  static const _laterKey = 'update.laterBuild';

  /// Replaced in tests.
  @visibleForTesting
  static http.Client Function() client = http.Client.new;

  /// Android installs that Obtainium updates by itself.
  static const _obtainium = 'dev.imranr.obtainium';

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  static bool get supported => AppIdiom.isAndroid || AppIdiom.isLinux;

  @override
  UpdateState build() =>
      UpdateState(enabled: _prefs.getBool(_enabledKey) ?? true);

  Future<void> setEnabled(bool on) async {
    await _prefs.setBool(_enabledKey, on);
    state = UpdateState(enabled: on);
    if (on) await check();
  }

  /// Checks for a newer release: from the network at most once a day
  /// ([force]: now, even after "Skip this version"), otherwise from the last
  /// answer. Returns the newer release, if any. Never throws.
  Future<AppUpdate?> check({bool force = false, DateTime? now}) async {
    if (!supported || (!force && !state.enabled)) return null;
    final PackageInfo info;
    try {
      info = await PackageInfo.fromPlatform();
    } on Object {
      return null;
    }
    if (info.installerStore?.startsWith(_obtainium) ?? false) return null;

    now ??= DateTime.now();
    final checkedAt = _prefs.getInt(_checkedAtKey);
    final due =
        force ||
        checkedAt == null ||
        now.millisecondsSinceEpoch - checkedAt >=
            const Duration(days: 1).inMilliseconds;
    Object? manifest;
    if (due) {
      final http = client();
      try {
        manifest = await fetchUpdateManifest(http);
      } finally {
        http.close();
      }
      if (manifest != null) {
        await _prefs.setString(_manifestKey, jsonEncode(manifest));
        await _prefs.setInt(_checkedAtKey, now.millisecondsSinceEpoch);
      }
    }
    manifest ??= _cached();
    final update = pickUpdate(
      manifest,
      installedVersion: info.version,
      build: installedBuild(info.buildNumber),
    );
    final skipped = !force && update?.build == _prefs.getInt(_skippedKey);
    final offered = skipped ? null : update;
    if (ref.mounted) {
      state = UpdateState(
        update: offered,
        enabled: state.enabled,
        later: offered != null && _prefs.getInt(_laterKey) == offered.build,
      );
    }
    return update;
  }

  /// "Later" on Today: the notice stays in Settings.
  Future<void> later() async {
    final update = state.update;
    if (update == null) return;
    await _prefs.setInt(_laterKey, update.build);
    state = UpdateState(update: update, enabled: state.enabled, later: true);
  }

  /// "Skip this version": no notice until a newer one.
  Future<void> skip() async {
    final update = state.update;
    if (update == null) return;
    await _prefs.setInt(_skippedKey, update.build);
    state = UpdateState(enabled: state.enabled);
  }

  /// What Download opens on this device.
  Future<String> downloadUrl(AppUpdate update) async {
    final abis = (await AndroidDevice.info())?['abis'];
    return update.downloadUrl(
      android: AppIdiom.isAndroid,
      arm64: abis is List && abis.contains('arm64-v8a'),
    );
  }

  Object? _cached() {
    final json = _prefs.getString(_manifestKey);
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } on Object {
      return null;
    }
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);
