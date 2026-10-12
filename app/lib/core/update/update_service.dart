import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A newer release, from `update.json` (written by the release workflow on the
/// altstore branch, next to the AltStore source).
@immutable
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.build,
    required this.notesUrl,
    this.androidArm64,
    this.androidUniversal,
    this.linux,
    this.sha256 = const {},
  });

  static const _files = ['androidArm64', 'androidUniversal', 'linux'];
  static final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Null when [json] isn't a valid entry. Every link must be https (they're
  /// opened as downloads); a missing or broken optional one is left out, and
  /// so is a hash that isn't 64 hex digits.
  static AppUpdate? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final version = json['version'];
    final build = json['build'];
    final notes = _https(json['notesUrl']);
    if (version is! String || build is! int || notes == null) return null;
    for (final key in _files) {
      if (json[key] != null && _https(json[key]) == null) return null;
    }
    final hashes = json['sha256'];
    final sha256 = <String, String>{
      if (hashes is Map<String, Object?>)
        for (final key in _files)
          if (hashes[key] case final String hash when _hex64.hasMatch(hash))
            key: hash.toLowerCase(),
    };
    return AppUpdate(
      version: version,
      build: build,
      notesUrl: notes,
      androidArm64: _https(json['androidArm64']),
      androidUniversal: _https(json['androidUniversal']),
      linux: _https(json['linux']),
      sha256: sha256,
    );
  }

  static String? _https(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? value
        : null;
  }

  /// E.g. `2.0.0-beta.5`.
  final String version;

  /// The pubspec build number (`+13`).
  final int build;

  /// The release page ("What's new").
  final String notesUrl;
  final String? androidArm64;
  final String? androidUniversal;
  final String? linux;

  /// The SHA-256 (hex) of each file, keyed like the links (`androidArm64`,
  /// …). Releases before 2.0.0-beta.8 have none.
  final Map<String, String> sha256;

  /// What Update installs from inside the app: the same APK as Download, or
  /// the Linux tarball. Null when that file has no hash (an older manifest):
  /// Download opens the browser instead. Never the universal APK in place of
  /// the arm64 one, whose version codes are higher (Android would refuse it).
  UpdateFile? installFile({required bool android, required bool arm64}) {
    final key = !android
        ? 'linux'
        : arm64 && androidArm64 != null
        ? 'androidArm64'
        : 'androidUniversal';
    final url = switch (key) {
      'androidArm64' => androidArm64,
      'androidUniversal' => androidUniversal,
      _ => linux,
    };
    final hash = sha256[key];
    return url == null || hash == null ? null : UpdateFile(url, hash);
  }

  /// What Download opens: the APK for this phone, or the release page (Linux
  /// installs from its tarball with `./install.sh`).
  String downloadUrl({required bool android, required bool arm64}) {
    if (android) {
      return (arm64 ? androidArm64 : null) ?? androidUniversal ?? notesUrl;
    }
    return notesUrl;
  }

  @override
  bool operator ==(Object other) =>
      other is AppUpdate &&
      other.version == version &&
      other.build == build &&
      other.notesUrl == notesUrl &&
      other.androidArm64 == androidArm64 &&
      other.androidUniversal == androidUniversal &&
      other.linux == linux &&
      mapEquals(other.sha256, sha256);

  @override
  int get hashCode => Object.hash(
    version,
    build,
    notesUrl,
    androidArm64,
    androidUniversal,
    linux,
    Object.hashAllUnordered(
      sha256.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// A file Update downloads and installs, with the SHA-256 it must match.
@immutable
class UpdateFile {
  const UpdateFile(this.url, this.sha256);

  final String url;
  final String sha256;

  @override
  bool operator ==(Object other) =>
      other is UpdateFile && other.url == url && other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(url, sha256);
}

/// The build number of the installed app. Android's per-ABI APKs report
/// 1000 × ABI + build (2012 for build 12 on arm64), the universal one the
/// build itself.
int installedBuild(String buildNumber) =>
    (int.tryParse(buildNumber) ?? 0) % 1000;

/// The update to offer from [manifest], if any: betas get the `beta` channel
/// (which also carries stable releases), stable versions `stable`.
AppUpdate? pickUpdate(
  Object? manifest, {
  required String installedVersion,
  required int build,
}) {
  if (manifest is! Map<String, Object?>) return null;
  final channel = installedVersion.contains('-') ? 'beta' : 'stable';
  final update = AppUpdate.tryParse(manifest[channel]);
  if (update == null || update.build <= build) return null;
  return update;
}

/// Where the apps check for updates (overridable for testing a manifest).
const updateManifestUrl = String.fromEnvironment(
  'UPDATE_URL',
  defaultValue: 'https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/update.json',
);

/// Downloads the manifest; null on any failure (offline, GitHub down, a
/// broken file): an update check never shows an error.
Future<Object?> fetchUpdateManifest(http.Client client) async {
  try {
    final response = await client
        .get(Uri.parse(updateManifestUrl))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body);
  } on Object catch (e) {
    debugPrint('Update check failed: $e');
    return null;
  }
}
