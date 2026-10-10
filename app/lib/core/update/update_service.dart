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
  });

  /// Null when [json] isn't a valid entry. Every link must be https (they're
  /// opened as downloads); a missing or broken optional one is left out.
  static AppUpdate? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final version = json['version'];
    final build = json['build'];
    final notes = _https(json['notesUrl']);
    if (version is! String || build is! int || notes == null) return null;
    for (final key in const ['androidArm64', 'androidUniversal', 'linux']) {
      if (json[key] != null && _https(json[key]) == null) return null;
    }
    return AppUpdate(
      version: version,
      build: build,
      notesUrl: notes,
      androidArm64: _https(json['androidArm64']),
      androidUniversal: _https(json['androidUniversal']),
      linux: _https(json['linux']),
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
      other.linux == linux;

  @override
  int get hashCode => Object.hash(
    version,
    build,
    notesUrl,
    androidArm64,
    androidUniversal,
    linux,
  );
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
