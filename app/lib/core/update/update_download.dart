import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Why Update failed: what the update window says about it.
enum UpdateFailure {
  /// No connection, GitHub didn't answer, or the download broke off.
  network,

  /// GitHub doesn't have the file (yet).
  notFound,

  /// Not enough space for the download.
  space,

  /// The file isn't the one the signed manifest names.
  notVerified,

  /// Android's installer didn't open.
  installer,

  /// Flatpak: "Deny" when the desktop asked whether LecCheck may update
  /// itself (remembered by Flatpak).
  flatpakDenied,

  /// Flatpak: the new version needs permissions this one doesn't have, so
  /// only the system's tools may install it.
  flatpakPermissions,

  /// Flatpak: the repository doesn't have the new version yet.
  flatpakNotYet,

  /// Flatpak: anything else ([UpdateFailed.message] says what).
  flatpak,

  /// The new version didn't start.
  restart,
}

/// An update that couldn't be downloaded, verified or installed. [message]
/// is for the log; the window says what [failure] means.
class UpdateFailed implements Exception {
  const UpdateFailed(this.message, [this.failure = UpdateFailure.network]);

  final String message;
  final UpdateFailure failure;

  @override
  String toString() => 'Update failed: $message';
}

/// A download that arrived whole but isn't the file the manifest names.
class UpdateNotVerified extends UpdateFailed {
  const UpdateNotVerified(String message)
    : super(message, UpdateFailure.notVerified);
}

/// Where updates are downloaded: `cache/updates`, the folder Android's
/// FileProvider shares with the installer (res/xml/update_paths.xml).
Future<Directory> updatesDirectory() async =>
    Directory('${(await getApplicationCacheDirectory()).path}/updates');

/// Deletes the downloaded updates in [dir] (before a new download, and once
/// the app is up to date). Never throws.
Future<void> clearUpdates(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } on Object catch (e) {
    debugPrint('Old updates not deleted: $e');
  }
}

/// The unverified download of [dest]: [verifyUpdate] turns it into [dest].
File partOf(File dest) => File('${dest.path}.part');

/// Downloads [url] to `dest.part` ([partOf]); [verifyUpdate] then checks it
/// and names it [dest], so [dest] only ever holds a whole, verified file.
/// [onProgress] gets the bytes received so far and the total, when the
/// server says it.
///
/// Throws [UpdateFailed], also when [client] is closed meanwhile (Cancel)
/// or nothing arrives for 30 seconds.
Future<void> downloadUpdate(
  http.Client client,
  Uri url,
  File dest, {
  void Function(int received, int? total)? onProgress,
}) async {
  if (url.scheme != 'https') throw UpdateFailed('Not https: $url');
  const stalled = Duration(seconds: 30);
  final part = partOf(dest);
  IOSink? sink;
  try {
    await dest.parent.create(recursive: true);
    final response = await client
        .send(http.Request('GET', url))
        .timeout(stalled);
    if (response.statusCode != 200) {
      throw UpdateFailed(
        'HTTP ${response.statusCode} for $url',
        response.statusCode == 404 || response.statusCode == 410
            ? UpdateFailure.notFound
            : UpdateFailure.network,
      );
    }
    final total = switch (response.contentLength) {
      final int n when n > 0 => n,
      _ => null,
    };
    sink = part.openWrite();
    var received = 0;
    await for (final chunk in response.stream.timeout(stalled)) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    await sink.close();
    sink = null;
    if (total != null && received != total) {
      throw UpdateFailed('Got $received of $total bytes from $url');
    }
  } on Object catch (e) {
    await sink?.close().catchError((Object _) {});
    if (await part.exists()) await part.delete();
    if (e is UpdateFailed) rethrow;
    throw UpdateFailed(
      '$e',
      _noSpace(e) ? UpdateFailure.space : UpdateFailure.network,
    );
  }
}

/// Checks the downloaded `dest.part` against [sha256] (hex), reading it back
/// from disk ([onProgress]: bytes checked so far), and names it [dest] when
/// it matches. Otherwise it's deleted and [UpdateNotVerified] is thrown.
Future<void> verifyUpdate(
  File dest,
  String sha256, {
  void Function(int checked)? onProgress,
}) async {
  final part = partOf(dest);
  try {
    final digest = _DigestSink();
    final hasher = crypto.sha256.startChunkedConversion(digest);
    var checked = 0;
    await for (final chunk in part.openRead()) {
      hasher.add(chunk);
      checked += chunk.length;
      onProgress?.call(checked);
    }
    hasher.close();
    if (digest.value.toString() != sha256.toLowerCase()) {
      throw UpdateNotVerified('SHA-256 mismatch for ${dest.path}');
    }
    await part.rename(dest.path);
  } on Object catch (e) {
    if (await part.exists()) await part.delete();
    if (e is UpdateFailed) rethrow;
    throw UpdateFailed(
      '$e',
      _noSpace(e) ? UpdateFailure.space : UpdateFailure.network,
    );
  }
}

/// ENOSPC: the disk is full.
bool _noSpace(Object e) =>
    e is FileSystemException && e.osError?.errorCode == 28;

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
