import 'dart:convert';

import 'package:cryptography/cryptography.dart';
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
    this.size = const {},
    this.flatpakRef,
    this.notes = '',
  });

  static const _files = ['androidArm64', 'androidUniversal', 'linux'];
  static final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Null when [json] isn't a valid entry. Every link must be https (they're
  /// opened as downloads); a missing or broken optional one is left out, and
  /// so is a hash that isn't 64 hex digits or a size that isn't a positive
  /// number.
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
    final sizes = json['size'];
    final size = <String, int>{
      if (sizes is Map<String, Object?>)
        for (final key in _files)
          if (sizes[key] case final int bytes when bytes > 0) key: bytes,
    };
    return AppUpdate(
      version: version,
      build: build,
      notesUrl: notes,
      androidArm64: _https(json['androidArm64']),
      androidUniversal: _https(json['androidUniversal']),
      linux: _https(json['linux']),
      sha256: sha256,
      size: size,
      flatpakRef: _https(json['flatpakref']),
      notes: json['notes'] is String ? json['notes']! as String : '',
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

  /// What's new, from the changelog (Markdown: `- ` items, `**bold**`).
  /// Empty for releases before 2.0.0-beta.11.
  final String notes;
  final String? androidArm64;
  final String? androidUniversal;
  final String? linux;

  /// The SHA-256 (hex) of each file, keyed like the links (`androidArm64`,
  /// …). Releases before 2.0.0-beta.8 have none.
  final Map<String, String> sha256;

  /// Each file's size in bytes, keyed like the links, so the window can say
  /// how big the download is. Releases before 2.0.0-beta.15 have none.
  final Map<String, int> size;

  /// The Flatpak's `.flatpakref` (LecCheck's own repository), for releases
  /// published as a Flatpak (2.0.0-beta.15 on): the Flatpak updates to it.
  final String? flatpakRef;

  /// Published as a Flatpak too.
  bool get flatpak => flatpakRef != null;

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
    return url == null || hash == null
        ? null
        : UpdateFile(url, hash, size: size[key]);
  }

  /// What Download opens: the APK for this phone, or the release page (it
  /// says how to install the Flatpak on Linux).
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
      other.flatpakRef == flatpakRef &&
      other.notes == notes &&
      mapEquals(other.sha256, sha256) &&
      mapEquals(other.size, size);

  @override
  int get hashCode => Object.hash(
    version,
    build,
    notesUrl,
    androidArm64,
    androidUniversal,
    linux,
    flatpakRef,
    notes,
    Object.hashAllUnordered(
      sha256.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      size.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// A file Update downloads and installs, with the SHA-256 it must match.
@immutable
class UpdateFile {
  const UpdateFile(this.url, this.sha256, {this.size});

  final String url;
  final String sha256;

  /// In bytes, when the manifest says (2.0.0-beta.15 on).
  final int? size;

  @override
  bool operator ==(Object other) =>
      other is UpdateFile &&
      other.url == url &&
      other.sha256 == sha256 &&
      other.size == size;

  @override
  int get hashCode => Object.hash(url, sha256, size);
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

/// The manifest as published, with its signature: `update.json` and
/// `update.json.sig` (Ed25519 over the file's exact bytes, base64), made by
/// the release workflow with the key whose public half is
/// [updatePublicKey].
@immutable
class SignedManifest {
  const SignedManifest(this.text, this.signature);

  final String text;
  final String signature;

  /// The manifest, or null when the signature doesn't match: it wasn't made
  /// by LecCheck's release workflow (or got damaged), so nothing in it is
  /// offered.
  Future<Object?> verified() async {
    try {
      final ok = await Ed25519().verify(
        utf8.encode(text),
        signature: Signature(
          base64.decode(signature.trim()),
          publicKey: SimplePublicKey(
            base64.decode(updatePublicKey),
            type: KeyPairType.ed25519,
          ),
        ),
      );
      if (!ok) {
        debugPrint('Update manifest: signature mismatch');
        return null;
      }
      return jsonDecode(text);
    } on Object catch (e) {
      debugPrint('Update manifest not readable: $e');
      return null;
    }
  }
}

/// The release workflow's update signing key (public half, raw, base64);
/// replaced in tests. A test build can trust its own key instead
/// (`--dart-define=UPDATE_PUBLIC_KEY=…`) to try a manifest signed with it,
/// see docs/DEVELOPMENT.md "Update notice"; release builds never set it.
@visibleForTesting
String updatePublicKey = const String.fromEnvironment(
  'UPDATE_PUBLIC_KEY',
  defaultValue: 'QWUdxjAue0DGsma4sZYPduMePmsHDQwXjq+LwisWn1U=',
);

/// Downloads the manifest and its signature; null on any failure (offline,
/// GitHub down): an update check never shows an error.
Future<SignedManifest?> fetchUpdateManifest(http.Client client) async {
  Future<String?> get(String url) async {
    final response = await client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    // The exact bytes (as UTF-8, which round-trips them): what was signed.
    return response.statusCode == 200 ? utf8.decode(response.bodyBytes) : null;
  }

  try {
    final (text, signature) = await (
      get(updateManifestUrl),
      get('$updateManifestUrl.sig'),
    ).wait;
    if (text == null || signature == null) return null;
    return SignedManifest(text, signature);
  } on Object catch (e) {
    debugPrint('Update check failed: $e');
    return null;
  }
}
