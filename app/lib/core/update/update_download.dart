import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// An update that couldn't be downloaded, verified or installed. [message]
/// is for the log; the card shows its own text.
class UpdateFailed implements Exception {
  const UpdateFailed(this.message);

  final String message;

  @override
  String toString() => 'Update failed: $message';
}

/// A download that arrived whole but isn't the file the manifest names.
class UpdateNotVerified extends UpdateFailed {
  const UpdateNotVerified(super.message);
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

/// Downloads [url] to [dest], checking it against [sha256] (hex) as it
/// arrives. It's written to `dest.part` first, so [dest] only ever holds a
/// whole, verified file. [onProgress] gets the bytes received so far and
/// the total, when the server says it.
///
/// Throws [UpdateFailed], also when [client] is closed meanwhile (Cancel)
/// or nothing arrives for 30 seconds.
Future<void> downloadUpdate(
  http.Client client,
  Uri url,
  String sha256,
  File dest, {
  void Function(int received, int? total)? onProgress,
}) async {
  if (url.scheme != 'https') throw UpdateFailed('Not https: $url');
  const stalled = Duration(seconds: 30);
  final part = File('${dest.path}.part');
  IOSink? sink;
  try {
    await dest.parent.create(recursive: true);
    final response = await client
        .send(http.Request('GET', url))
        .timeout(stalled);
    if (response.statusCode != 200) {
      throw UpdateFailed('HTTP ${response.statusCode} for $url');
    }
    final total = switch (response.contentLength) {
      final int n when n > 0 => n,
      _ => null,
    };
    final digest = _DigestSink();
    final hasher = crypto.sha256.startChunkedConversion(digest);
    sink = part.openWrite();
    var received = 0;
    await for (final chunk in response.stream.timeout(stalled)) {
      hasher.add(chunk);
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    await sink.close();
    sink = null;
    hasher.close();
    if (digest.value.toString() != sha256.toLowerCase()) {
      throw UpdateNotVerified('SHA-256 mismatch for $url');
    }
    await part.rename(dest.path);
  } on Object catch (e) {
    await sink?.close().catchError((Object _) {});
    if (await part.exists()) await part.delete();
    if (e is UpdateFailed) rethrow;
    throw UpdateFailed('$e');
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
