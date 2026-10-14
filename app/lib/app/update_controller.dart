import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/android_device.dart';
import '../core/update/linux_self_update.dart';
import '../core/update/update_download.dart';
import '../core/update/update_service.dart';
import 'adaptive.dart';
import 'providers.dart';

/// How far Update got.
enum UpdatePhase {
  /// Not started (or cancelled).
  idle,

  /// Downloading and checking the file ([UpdateState.progress]).
  downloading,

  /// Linux: install.sh is swapping the app's files.
  installing,

  /// Android: downloaded, and Android's installer was opened. Install opens
  /// it again (after Cancel in the system dialog, say).
  downloaded,

  /// Linux: installed; Restart starts the new version.
  restart,

  /// Something went wrong: Retry, or download it in the browser.
  failed,
}

/// What the update notice shows.
@immutable
class UpdateState {
  const UpdateState({
    this.update,
    this.enabled = true,
    this.later = false,
    this.file,
    this.phase = UpdatePhase.idle,
    this.received = 0,
    this.total,
    this.bytesPerSecond,
    this.failedStep,
  });

  /// The newer release to offer (none: up to date, skipped, or unknown).
  final AppUpdate? update;

  /// What Update installs on this device. Null when Download opens the
  /// browser instead: the manifest has no hash for it (releases before
  /// 2.0.0-beta.8), or a Linux build that install.sh didn't install.
  final UpdateFile? file;

  final UpdatePhase phase;

  /// Bytes downloaded so far, of [total] (null while the size isn't known).
  final int received;
  final int? total;

  /// Average download speed so far; null until something arrived.
  final double? bytesPerSecond;

  /// What went wrong, when [phase] is [UpdatePhase.failed].
  final UpdateStep? failedStep;

  /// 0–1 while downloading; null while the size isn't known.
  double? get progress {
    final total = this.total;
    return total == null ? null : received / total;
  }

  /// Settings → About → Check for updates.
  final bool enabled;

  /// "Later" on Today: shown in Settings only, until the next version.
  final bool later;

  UpdateState _with({
    UpdatePhase? phase,
    bool? later,
    int? received,
    int? total,
    double? bytesPerSecond,
    UpdateStep? failedStep,
  }) => UpdateState(
    update: update,
    enabled: enabled,
    later: later ?? this.later,
    file: file,
    phase: phase ?? this.phase,
    // The download's numbers stay for the steps after it.
    received: received ?? this.received,
    total: total ?? this.total,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    // Kept like the fields above, so a state change while [UpdatePhase.failed]
    // doesn't lose which step failed; a new phase ignores it.
    failedStep: failedStep ?? this.failedStep,
  );

  @override
  bool operator ==(Object other) =>
      other is UpdateState &&
      other.update == update &&
      other.enabled == enabled &&
      other.later == later &&
      other.file == file &&
      other.phase == phase &&
      other.received == received &&
      other.total == total &&
      other.bytesPerSecond == bytesPerSecond &&
      other.failedStep == failedStep;

  @override
  int get hashCode => Object.hash(
    update,
    enabled,
    later,
    file,
    phase,
    received,
    total,
    bytesPerSecond,
    failedStep,
  );
}

/// The steps of Update, as the update window lists them.
enum UpdateStep {
  download,

  /// The file's SHA-256 matches the signed manifest.
  verify,

  /// Linux: install.sh; Android: the system installer opens.
  install,
}

/// Tells Android and Linux users about new releases (no store does: the
/// APK and the tarball come from GitHub), and installs them on Update.
/// Checks after the first frame and when the app comes back, at most once a
/// day; the last answer is kept, so the notice survives restarts offline.
/// iPhone updates come from AltStore.
class UpdateController extends Notifier<UpdateState> {
  static const _enabledKey = 'update.check';
  static const _checkedAtKey = 'update.checkedAt';

  /// The manifest exactly as published, and its signature (checked again
  /// whenever it's read).
  static const _manifestKey = 'update.manifest';
  static const _signatureKey = 'update.signature';
  static const _skippedKey = 'update.skipBuild';
  static const _laterKey = 'update.laterBuild';

  /// Replaced in tests.
  @visibleForTesting
  static http.Client Function() client = http.Client.new;

  /// Where updates are downloaded; replaced in tests.
  @visibleForTesting
  static Future<Directory> Function() directory = updatesDirectory;

  /// Opens Android's installer; replaced in tests.
  @visibleForTesting
  static Future<bool> Function(String apk) installApk =
      AndroidDevice.installApk;

  /// The install.sh folder this Linux app runs from, if any; replaced in
  /// tests.
  @visibleForTesting
  static Future<String?> Function() linuxInstallDir =
      LinuxSelfUpdate.installDir;

  /// Installs a Linux tarball; replaced in tests.
  @visibleForTesting
  static Future<void> Function(File tarball) installTarball =
      LinuxSelfUpdate.install;

  /// Android installs that Obtainium updates by itself.
  static const _obtainium = 'dev.imranr.obtainium';

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  /// The running download; Cancel closes it.
  http.Client? _download;

  /// The downloaded APK, for Install.
  File? _apk;

  /// Asked once: see [linuxInstallDir].
  Future<String?>? _linuxDir;

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
    if (due) manifest = await _fetch(now);
    manifest ??= await _cached();
    // Nothing usable kept (e.g. an unsigned one from before 2.0.0-beta.11).
    if (manifest == null && !due) manifest = await _fetch(now);
    final update = pickUpdate(
      manifest,
      installedVersion: info.version,
      build: installedBuild(info.buildNumber),
    );
    final skipped = !force && update?.build == _prefs.getInt(_skippedKey);
    final offered = skipped ? null : update;
    final file = offered == null ? null : await _installFile(offered);
    if (update == null && _download == null) {
      // Up to date: an update downloaded earlier was installed.
      try {
        await clearUpdates(await directory());
      } on Object catch (e) {
        debugPrint('Old updates not deleted: $e');
      }
    }
    if (ref.mounted) {
      // The same release keeps its progress (checks run on every resume).
      final same = offered != null && offered == state.update;
      state = UpdateState(
        update: offered,
        enabled: state.enabled,
        later: offered != null && _prefs.getInt(_laterKey) == offered.build,
        file: file,
        phase: same ? state.phase : UpdatePhase.idle,
        received: same ? state.received : 0,
        total: same ? state.total : null,
        bytesPerSecond: same ? state.bytesPerSecond : null,
        failedStep: same ? state.failedStep : null,
      );
    }
    return update;
  }

  /// Whether the update window opened by itself this launch.
  bool _prompted = false;

  /// True once per launch while a release waits to be installed: the update
  /// window then opens by itself. "Later" asks again on the next launch.
  bool takePrompt() {
    if (_prompted || state.update == null) return false;
    if (state.phase != UpdatePhase.idle) return false;
    _prompted = true;
    return true;
  }

  /// "Later" on Today: the notice stays in Settings.
  Future<void> later() async {
    final update = state.update;
    if (update == null) return;
    await _prefs.setInt(_laterKey, update.build);
    state = state._with(later: true);
  }

  /// "Skip this version": no notice until a newer one.
  Future<void> skip() async {
    final update = state.update;
    if (update == null) return;
    await _prefs.setInt(_skippedKey, update.build);
    state = UpdateState(enabled: state.enabled);
  }

  /// What Download opens on this device.
  Future<String> downloadUrl(AppUpdate update) async =>
      update.downloadUrl(android: AppIdiom.isAndroid, arm64: await _arm64());

  /// Update: downloads this device's file and checks its hash, then opens
  /// Android's installer, or installs it on Linux (then Restart). On
  /// Android, after the download, it opens the installer again (Install).
  /// Never throws: a failure shows on the card, details in the log.
  Future<void> install() async {
    final file = state.file;
    if (file == null || _download != null) return;
    final apk = _apk;
    if (state.phase == UpdatePhase.downloaded &&
        apk != null &&
        await apk.exists()) {
      if (!await installApk(apk.path)) {
        _set(UpdatePhase.failed, failedStep: UpdateStep.install);
      }
      return;
    }
    final client = _download = UpdateController.client();
    if (ref.mounted) {
      state = state._with(phase: UpdatePhase.downloading, received: 0);
    }
    var step = UpdateStep.download;
    try {
      final dir = await directory();
      await clearUpdates(dir);
      final android = AppIdiom.isAndroid;
      final dest = File(
        '${dir.path}/${android ? 'update.apk' : 'update.tar.gz'}',
      );
      final clock = Stopwatch()..start();
      var shown = -1;
      await downloadUpdate(
        client,
        Uri.parse(file.url),
        file.sha256,
        dest,
        onProgress: (received, total) {
          // About ten rebuilds a second.
          final tick = clock.elapsedMilliseconds ~/ 100;
          if (tick == shown || !identical(_download, client)) return;
          shown = tick;
          final seconds = clock.elapsedMicroseconds / 1e6;
          if (ref.mounted) {
            state = state._with(
              phase: UpdatePhase.downloading,
              received: received,
              total: total,
              bytesPerSecond: seconds > 0 ? received / seconds : null,
            );
          }
        },
      );
      if (!identical(_download, client)) return;
      final size = await dest.length();
      if (ref.mounted) state = state._with(received: size, total: size);
      step = UpdateStep.install;
      if (android) {
        _apk = dest;
        _set(UpdatePhase.downloaded);
        if (!await installApk(dest.path)) {
          throw const UpdateFailed("Android's installer didn't open");
        }
      } else {
        _set(UpdatePhase.installing);
        await installTarball(dest);
        await clearUpdates(dir);
        _set(UpdatePhase.restart);
      }
    } on Object catch (e) {
      if (!identical(_download, client)) return; // Cancel
      debugPrint(e is UpdateFailed ? '$e' : 'Update failed: $e');
      _set(
        UpdatePhase.failed,
        failedStep: e is UpdateNotVerified ? UpdateStep.verify : step,
      );
    } finally {
      client.close();
      if (identical(_download, client)) _download = null;
    }
  }

  /// Cancel: stops the download.
  void cancel() {
    final client = _download;
    if (client == null || state.phase != UpdatePhase.downloading) return;
    _download = null;
    client.close();
    _set(UpdatePhase.idle);
  }

  /// Restart (Linux, after Update): quits and starts the new version.
  Future<void> restart() async {
    final dir = await (_linuxDir ??= linuxInstallDir());
    if (dir != null) await LinuxSelfUpdate.restart(dir);
  }

  void _set(UpdatePhase phase, {UpdateStep? failedStep}) {
    if (ref.mounted) state = state._with(phase: phase, failedStep: failedStep);
  }

  /// Fetches the manifest and keeps it when its signature checks out.
  Future<Object?> _fetch(DateTime now) async {
    final http = client();
    final SignedManifest? signed;
    try {
      signed = await fetchUpdateManifest(http);
    } finally {
      http.close();
    }
    final manifest = await signed?.verified();
    if (signed != null && manifest != null) {
      await _prefs.setString(_manifestKey, signed.text);
      await _prefs.setString(_signatureKey, signed.signature);
      await _prefs.setInt(_checkedAtKey, now.millisecondsSinceEpoch);
    }
    return manifest;
  }

  Future<bool> _arm64() async {
    final abis = (await AndroidDevice.info())?['abis'];
    return abis is List && abis.contains('arm64-v8a');
  }

  Future<UpdateFile?> _installFile(AppUpdate update) async {
    if (AppIdiom.isAndroid) {
      return update.installFile(android: true, arm64: await _arm64());
    }
    final dir = await (_linuxDir ??= linuxInstallDir());
    return dir == null
        ? null
        : update.installFile(android: false, arm64: false);
  }

  Future<Object?> _cached() async {
    final text = _prefs.getString(_manifestKey);
    final signature = _prefs.getString(_signatureKey);
    if (text == null || signature == null) return null;
    return SignedManifest(text, signature).verified();
  }
}

final updateProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);
