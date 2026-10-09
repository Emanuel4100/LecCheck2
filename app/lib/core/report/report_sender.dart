import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../sync/sync_config.dart';

/// What happened to a bug report.
enum ReportResult {
  /// Filed.
  sent,

  /// Kept on the device; sent again at the next start or return to the app.
  queued,

  /// Not accepted (too many today, or reports are off on the server).
  refused,
}

/// Sends bug reports to the sync server (`POST /v1/reports`, no sign-in),
/// keeping the ones that can't go yet in a file.
class ReportSender {
  ReportSender({
    http.Client Function()? client,
    Future<Directory> Function()? directory,
    @visibleForTesting Uri? endpoint,
  }) : _client = client ?? http.Client.new,
       _directory = directory ?? getApplicationSupportDirectory,
       _endpoint =
           endpoint ??
           (SyncConfig.enabled ? SyncConfig.api('/v1/reports') : null);

  static const fileName = 'pending_reports.json';

  final http.Client Function() _client;
  final Future<Directory> Function() _directory;
  final Uri? _endpoint;

  /// Whether this build can send reports at all.
  static bool get available => SyncConfig.enabled;

  Future<ReportResult> send(Map<String, Object?> report) async {
    final result = await _post(report);
    if (result == ReportResult.queued) {
      await _save([...await _pending(), report]);
    }
    return result;
  }

  /// Sends the queued reports; keeps the ones that still can't go. Returns
  /// how many were sent.
  Future<int> flush() async {
    final pending = await _pending();
    if (pending.isEmpty) return 0;
    final left = <Map<String, Object?>>[];
    var sent = 0;
    for (final report in pending) {
      switch (await _post(report)) {
        case ReportResult.sent:
          sent++;
        case ReportResult.queued:
          left.add(report);
        case ReportResult.refused:
          break; // Dropped: sending it again wouldn't help.
      }
    }
    await _save(left);
    return sent;
  }

  Future<ReportResult> _post(Map<String, Object?> report) async {
    final endpoint = _endpoint;
    if (endpoint == null) return ReportResult.refused;
    final client = _client();
    try {
      final response = await client
          .post(
            endpoint,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(report),
          )
          .timeout(const Duration(seconds: 20));
      return switch (response.statusCode) {
        201 => ReportResult.sent,
        // Too many today, or not a report: sending it again won't help.
        429 || 400 || 413 => ReportResult.refused,
        // Reports are off on this server.
        503 when response.body.contains('reports_unavailable') =>
          ReportResult.refused,
        // GitHub or the server is down: later.
        _ => ReportResult.queued,
      };
    } on Object catch (e) {
      debugPrint('Report not sent yet: $e');
      return ReportResult.queued;
    } finally {
      client.close();
    }
  }

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<List<Map<String, Object?>>> _pending() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      return (jsonDecode(await file.readAsString()) as List<Object?>)
          .cast<Map<String, Object?>>();
    } on Object {
      return [];
    }
  }

  Future<void> _save(List<Map<String, Object?>> reports) async {
    final file = await _file();
    if (reports.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    // At most a few: older ones go first.
    final kept = reports.length > 5
        ? reports.sublist(reports.length - 5)
        : reports;
    await file.writeAsString(jsonEncode(kept));
  }
}
