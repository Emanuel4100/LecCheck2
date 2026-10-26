import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/android_device.dart';
import '../core/update/flatpak.dart';
import '../core/update/tarball_install.dart';
import '../core/update/update_download.dart';
import '../core/update/update_service.dart';
import 'adaptive.dart';
import 'providers.dart';

/// How Update installs a release on this device.
enum UpdateVia {
  /// Download opens the browser: the manifest has no hash for this phone's
  /// APK (releases before 2.0.0-beta.8), or it's a Linux build that neither
  /// Flatpak nor install.sh installed (flutter run, a distro package).
  browser,

  /// Android: downloads the APK, checks it, opens Android's installer.
  apk,

  /// The Flatpak: its portal downloads, verifies and installs the release,
  /// then Restart starts it.
  flatpak,

  /// Linux installed from the tarball by install.sh: releases come as a
  /// Flatpak since 2.0.0-beta.15, so Update moves it there
  /// ([moveProvider]).
  move,
}

/// How far Update got.
enum UpdatePhase {
  /// Not started (or cancelled).
  idle,

  /// Downloading ([UpdateState.progress]); on Flatpak, the portal's whole
  /// update.
  downloading,

  /// Checking the downloaded file against the signed manifest
  /// ([UpdateState.checkProgress]).
  verifying,

  /// Android: verified, and Android's installer was opened. Install opens
  /// it again (after Cancel in the system dialog, say).
  downloaded,

  /// Flatpak: installed; Restart starts the new version.
  restart,

  /// Something went wrong ([UpdateState.failure]): Retry, or download it in
  /// the browser.
  failed,
}

/// What the update notice shows.
@immutable
class UpdateState {
  const UpdateState({
    this.update,
    this.enabled = true,
    this.later = false,
    this.via = UpdateVia.browser,
    this.file,
    this.phase = UpdatePhase.idle,
    this.received = 0,
    this.total,
    this.bytesPerSecond,
    this.checked = 0,
    this.portalProgress,
    this.failedStep,
    this.failure,
    this.error,
  });

  /// The newer release to offer (none: up to date, skipped, or unknown).
  final AppUpdate? update;

  final UpdateVia via;

  /// The APK Update installs ([UpdateVia.apk]).
  final UpdateFile? file;

  final UpdatePhase phase;

  /// Bytes downloaded so far, of [total] (null while the size isn't known).
  final int received;
  final int? total;

  /// Average download speed so far; null until something arrived.
  final double? bytesPerSecond;

  /// Bytes of the downloaded file checked so far (of [total]).
  final int checked;

  /// Flatpak: 0–1 over the portal's whole update; null until it says.
  final double? portalProgress;

  /// What went wrong, when [phase] is [UpdatePhase.failed].
  final UpdateStep? failedStep;
  final UpdateFailure? failure;

  /// Flatpak's own words for a [UpdateFailure.flatpak], for the window.
  final String? error;

  /// 0–1 while downloading (or while the Flatpak portal updates); null while
  /// the size isn't known.
  double? get progress {
    if (via == UpdateVia.flatpak) return portalProgress;
    final total = this.total;
    return total == null ? null : received / total;
  }

  /// 0–1 while checking the file.
  double? get checkProgress {
    final total = this.total;
    return total == null || total == 0 ? null : checked / total;
  }

  /// The download's size, before it starts: from the manifest (releases
  /// from 2.0.0-beta.15 on).
  int? get size => file?.size;

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
    int? checked,
    double? portalProgress,
    UpdateStep? failedStep,
    UpdateFailure? failure,
    String? error,
  }) => UpdateState(
    update: update,
    enabled: enabled,
    later: later ?? this.later,
    via: via,
    file: file,
    phase: phase ?? this.phase,
    // The download's numbers stay for the steps after it.
    received: received ?? this.received,
    total: total ?? this.total,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    checked: checked ?? this.checked,
    portalProgress: portalProgress ?? this.portalProgress,
    // Kept like the fields above, so a state change while [UpdatePhase.failed]
    // doesn't lose which step failed; a new phase ignores them.
    failedStep: failedStep ?? this.failedStep,
    failure: failure ?? this.failure,
    error: error ?? this.error,
  );

  /// Back to the start of an update: nothing downloaded, nothing failed.
  UpdateState _restart(UpdatePhase phase) => UpdateState(
    update: update,
    enabled: enabled,
    later: later,
    via: via,
    file: file,
    phase: phase,
  );

  @override
  bool operator ==(Object other) =>
      other is UpdateState &&
      other.update == update &&
      other.enabled == enabled &&
      other.later == later &&
      other.via == via &&
      other.file == file &&
      other.phase == phase &&
      other.received == received &&
      other.total == total &&
      other.bytesPerSecond == bytesPerSecond &&
      other.checked == checked &&
      other.portalProgress == portalProgress &&
      other.failedStep == failedStep &&
      other.failure == failure &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    update,
    enabled,
    later,
    via,
    file,
    phase,
    received,
    total,
    bytesPerSecond,
    checked,
    portalProgress,
    failedStep,
    failure,
    error,
  );
}

/// The steps of Update, as the update window lists them.
enum UpdateStep {
  download,

  /// The file's SHA-256 matches the signed manifest (on Flatpak: the
  /// repository's GPG signature, checked by Flatpak).
  verify,

  /// Android: the system installer opens; Flatpak: the portal installs.
  install,
}

/// Tells Android and Linux users about new releases (no store does: the
/// APK and the Flatpak come from LecCheck's own GitHub), and installs them
/// on Update. Checks after the first frame and when the app comes back, at
/// most once a day; the last answer is kept, so the notice survives
/// restarts offline. iPhone updates come from AltStore.
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

  /// Whether this runs as a Flatpak; replaced in tests.
  @visibleForTesting
  static bool Function() isFlatpak = () => Flatpak.running;

  /// The Flatpak portal's update; replaced in tests.
  @visibleForTesting
  static Stream<FlatpakProgress> Function() flatpakUpdate =
      FlatpakPortal.update;

  /// Starts the newest installed Flatpak; replaced in tests.
  @visibleForTesting
  static Future<void> Function() startLatestFlatpak = FlatpakPortal.startLatest;

  /// Quits the app (after starting the new version); replaced in tests.
  @visibleForTesting
  static Future<void> Function() exitApp = () =>
      ServicesBinding.instance.exitApplication(AppExitType.required);

  /// The install.sh folder this Linux app runs from, if any; replaced in
  /// tests.
  @visibleForTesting
  static Future<String?> Function() linuxInstallDir = TarballInstall.installDir;

  /// The check step shows at least this long, however fast the file is
  /// hashed, so it can be seen; zero in tests.
  @visibleForTesting
  static Duration verifyAtLeast = const Duration(milliseconds: 900);

  /// Android installs that Obtainium updates by itself.
  static const _obtainium = 'dev.imranr.obtainium';

  SharedPreferencesWithCache get _prefs => ref.read(sharedPrefsProvider);

  /// The running download; Cancel closes it.
  http.Client? _download;

  /// The Flatpak portal's running update; Cancel stops it.
  StreamSubscription<FlatpakProgress>? _portal;

  /// Completes [_installFlatpak]'s future when the update ends or is
  /// cancelled.
  Completer<void>? _portalDone;

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
    final (via, file) = offered == null
        ? (UpdateVia.browser, null)
        : await _installer(offered);
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
      state = same
          ? UpdateState(
              update: offered,
              enabled: state.enabled,
              later: _prefs.getInt(_laterKey) == offered.build,
              via: via,
              file: file,
              phase: state.phase,
              received: state.received,
              total: state.total,
              bytesPerSecond: state.bytesPerSecond,
              checked: state.checked,
              portalProgress: state.portalProgress,
              failedStep: state.failedStep,
              failure: state.failure,
              error: state.error,
            )
          : UpdateState(
              update: offered,
              enabled: state.enabled,
              later:
                  offered != null && _prefs.getInt(_laterKey) == offered.build,
              via: via,
              file: file,
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

  /// Update: on Android, downloads the APK, checks it, then opens Android's
  /// installer (and again on Install); on Flatpak, the portal installs it
  /// (then Restart). Never throws: a failure shows on the card, details in
  /// the log.
  Future<void> install() => switch (state.via) {
    UpdateVia.apk => _installApk(),
    UpdateVia.flatpak => _installFlatpak(),
    // Download opens the browser, and Move its own window.
    UpdateVia.browser || UpdateVia.move => Future.value(),
  };

  Future<void> _installApk() async {
    final file = state.file;
    if (file == null || _download != null) return;
    final apk = _apk;
    if (state.phase == UpdatePhase.downloaded &&
        apk != null &&
        await apk.exists()) {
      if (!await installApk(apk.path)) {
        _fail(UpdateStep.install, UpdateFailure.installer);
      }
      return;
    }
    final client = _download = UpdateController.client();
    if (ref.mounted) state = state._restart(UpdatePhase.downloading);
    var step = UpdateStep.download;
    try {
      final dir = await directory();
      await clearUpdates(dir);
      final dest = File('${dir.path}/update.apk');
      final clock = Stopwatch()..start();
      var shown = -1;
      await downloadUpdate(
        client,
        Uri.parse(file.url),
        dest,
        onProgress: (received, total) {
          // About ten rebuilds a second.
          final tick = clock.elapsedMilliseconds ~/ 100;
          if (tick == shown || !identical(_download, client)) return;
          shown = tick;
          final seconds = clock.elapsedMicroseconds / 1e6;
          if (ref.mounted) {
            state = state._with(
              received: received,
              total: total,
              bytesPerSecond: seconds > 0 ? received / seconds : null,
            );
          }
        },
      );
      if (!identical(_download, client)) return;
      final size = await partOf(dest).length();
      step = UpdateStep.verify;
      if (ref.mounted) {
        state = state._with(
          phase: UpdatePhase.verifying,
          received: size,
          total: size,
          checked: 0,
        );
      }
      final checking = Stopwatch()..start();
      shown = -1;
      await verifyUpdate(
        dest,
        file.sha256,
        onProgress: (checked) {
          final tick = checking.elapsedMilliseconds ~/ 100;
          if (tick == shown || !ref.mounted) return;
          shown = tick;
          state = state._with(checked: checked);
        },
      );
      if (ref.mounted) state = state._with(checked: size);
      // Long enough to see, however fast the phone was.
      final left = verifyAtLeast - checking.elapsed;
      if (left > Duration.zero) await Future<void>.delayed(left);
      if (!identical(_download, client)) return;
      step = UpdateStep.install;
      _apk = dest;
      _set(UpdatePhase.downloaded);
      if (!await installApk(dest.path)) {
        throw const UpdateFailed(
          "Android's installer didn't open",
          UpdateFailure.installer,
        );
      }
    } on Object catch (e) {
      if (!identical(_download, client)) return; // Cancel
      debugPrint(e is UpdateFailed ? '$e' : 'Update failed: $e');
      _fail(
        e is UpdateNotVerified ? UpdateStep.verify : step,
        e is UpdateFailed ? e.failure : UpdateFailure.network,
      );
    } finally {
      client.close();
      if (identical(_download, client)) _download = null;
    }
  }

  /// The Flatpak portal installs the new version: it downloads it, checks
  /// the repository's GPG signature, and deploys it (Progress until it's
  /// done). The first time, the desktop asks whether LecCheck may update
  /// itself.
  Future<void> _installFlatpak() {
    if (_portal != null) return Future.value();
    if (ref.mounted) state = state._restart(UpdatePhase.downloading);
    final finished = _portalDone = Completer<void>();
    void end() {
      _portal = null;
      if (!finished.isCompleted) finished.complete();
    }

    late final StreamSubscription<FlatpakProgress> portal;
    portal = _portal = flatpakUpdate().listen(
      (progress) {
        if (!identical(_portal, portal) || !ref.mounted) return;
        switch (progress.status) {
          case FlatpakStatus.running:
            state = state._with(portalProgress: progress.fraction);
          case FlatpakStatus.done:
            state = state._with(phase: UpdatePhase.restart, portalProgress: 1);
          case FlatpakStatus.empty:
            debugPrint('Flatpak update: nothing to install yet');
            _fail(UpdateStep.download, UpdateFailure.flatpakNotYet);
          case FlatpakStatus.failed:
            debugPrint('Flatpak update failed: $progress');
            final failure = switch (progress.error) {
              'org.freedesktop.DBus.Error.AccessDenied' =>
                UpdateFailure.flatpakDenied,
              'org.freedesktop.DBus.Error.NotSupported' =>
                UpdateFailure.flatpakPermissions,
              _ => UpdateFailure.flatpak,
            };
            _fail(
              failure == UpdateFailure.flatpak &&
                      (state.portalProgress ?? 0) >= 1
                  ? UpdateStep.install
                  : UpdateStep.download,
              failure,
              error: progress.message ?? progress.error,
            );
        }
      },
      onError: (Object e) {
        if (identical(_portal, portal)) {
          debugPrint('Flatpak update failed: $e');
          _fail(UpdateStep.download, UpdateFailure.flatpak, error: '$e');
        }
        end();
      },
      onDone: end,
      cancelOnError: true,
    );
    return finished.future;
  }

  /// Cancel: stops the download (or the Flatpak's update).
  void cancel() {
    if (state.phase != UpdatePhase.downloading) return;
    final client = _download;
    final portal = _portal;
    _download = null;
    _portal = null;
    client?.close();
    // Closes the portal's update monitor, which stops its update.
    portal?.cancel();
    if (portal != null && !(_portalDone?.isCompleted ?? true)) {
      _portalDone!.complete();
    }
    _set(UpdatePhase.idle);
  }

  /// Restart (Flatpak, after Update): starts the new version, then quits.
  Future<void> restart() async {
    if (state.via != UpdateVia.flatpak) return;
    try {
      await startLatestFlatpak();
    } on Object catch (e) {
      // It's installed: closing and opening LecCheck again starts it.
      debugPrint('Restart failed: $e');
      if (ref.mounted) state = state._with(failure: UpdateFailure.restart);
      return;
    }
    await exitApp();
  }

  void _set(UpdatePhase phase) {
    if (ref.mounted) state = state._with(phase: phase);
  }

  void _fail(UpdateStep step, UpdateFailure failure, {String? error}) {
    if (!ref.mounted) return;
    state = state._with(
      phase: UpdatePhase.failed,
      failedStep: step,
      failure: failure,
      error: error,
    );
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

  /// How [update] installs here, and the file Update downloads (Android).
  Future<(UpdateVia, UpdateFile?)> _installer(AppUpdate update) async {
    if (AppIdiom.isAndroid) {
      final file = update.installFile(android: true, arm64: await _arm64());
      return (file == null ? UpdateVia.browser : UpdateVia.apk, file);
    }
    if (isFlatpak()) {
      return (update.flatpak ? UpdateVia.flatpak : UpdateVia.browser, null);
    }
    final dir = await (_linuxDir ??= linuxInstallDir());
    return (dir == null ? UpdateVia.browser : UpdateVia.move, null);
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
