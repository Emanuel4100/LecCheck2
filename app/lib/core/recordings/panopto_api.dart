import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/local_date.dart';
import '../../domain/recording_match.dart';

/// Something Panopto refused or that couldn't reach it.
class PanoptoException implements Exception {
  const PanoptoException(this.code, [this.detail = '']);

  /// `reconnect`: the sign-in expired or was revoked (connect again).
  /// `client`: Panopto refused the Client ID or secret.
  /// `forbidden`, `not_found`, `http_<status>`, `network`, `bad_answer`.
  final String code;
  final String detail;

  bool get needsReconnect => code == 'reconnect';

  @override
  String toString() =>
      'PanoptoException($code${detail.isEmpty ? '' : ': $detail'})';
}

/// Read-only calls to Panopto's REST API (`/Panopto/api/v1`). LecCheck
/// never changes anything in Panopto.
class PanoptoApi {
  PanoptoApi({
    required this.site,
    required http.Client client,
    required this._token,
  }) : _http = client;

  /// The Panopto host, e.g. `huji.cloud.panopto.eu`.
  final String site;
  final http.Client _http;
  final Future<String> Function({bool refresh}) _token;

  /// Panopto lists 50 per page; reading stops at an empty page anyway.
  static const maxPages = 20;

  /// Folders whose name matches [query] (a course number finds the course's
  /// folder at HUJI: `2026-27 -> 80430_1-מבוא להסתברות…`).
  Future<List<PanoptoFolderRef>> searchFolders(String query) async {
    final found = <PanoptoFolderRef>[];
    for (var page = 0; page < 5; page++) {
      final results = await _results('folders/search', {
        'searchQuery': query,
        'pageNumber': '$page',
      });
      if (results.isEmpty) break;
      for (final f in results) {
        final id = f['Id'];
        if (id is! String) continue;
        found.add(
          PanoptoFolderRef(
            id: id.toLowerCase(),
            name: cleanName(f['Name'] as String? ?? ''),
          ),
        );
      }
    }
    return found;
  }

  /// One folder, or null when it doesn't exist or isn't visible.
  Future<PanoptoFolderRef?> folder(String id) async {
    try {
      final json = await _get('folders/$id');
      if (json is! Map || json['Id'] is! String) return null;
      return PanoptoFolderRef(
        id: (json['Id'] as String).toLowerCase(),
        name: cleanName(json['Name'] as String? ?? ''),
      );
    } on PanoptoException catch (e) {
      if (e.code == 'not_found' || e.code == 'forbidden') return null;
      rethrow;
    }
  }

  /// A folder's recordings, newest first, down to the ones that started
  /// before [since].
  Future<List<PanoptoRecording>> folderRecordings(
    String folderId, {
    LocalDate? since,
  }) async {
    final recordings = <PanoptoRecording>[];
    for (var page = 0; page < maxPages; page++) {
      final results = await _results('folders/$folderId/sessions', {
        'sortField': 'CreatedDate',
        'sortOrder': 'Desc',
        'pageNumber': '$page',
      });
      if (results.isEmpty) break;
      var older = 0;
      for (final json in results) {
        final r = recordingFromJson(json, site: site);
        if (r == null) continue;
        if (since != null && r.wallStart.date.isBefore(since)) {
          older++;
        } else {
          recordings.add(r);
        }
      }
      if (since != null && older == results.length) break;
    }
    return recordings;
  }

  Future<List<Map<String, Object?>>> _results(
    String path,
    Map<String, String> query,
  ) async {
    final json = await _get(path, query);
    final results = json is Map ? json['Results'] : null;
    if (results is! List) throw const PanoptoException('bad_answer');
    return [
      for (final r in results)
        if (r is Map) r.cast<String, Object?>(),
    ];
  }

  /// GETs [path], asking for a new access token once if Panopto says the
  /// current one isn't valid.
  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    final url = Uri.https(site, '/Panopto/api/v1/$path', query);
    for (var attempt = 0; ; attempt++) {
      final token = await _token(refresh: attempt > 0);
      final http.Response response;
      try {
        response = await _http
            .get(
              url,
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 30));
      } on Exception catch (e) {
        throw PanoptoException('network', '$e');
      }
      switch (response.statusCode) {
        case 200:
          try {
            return jsonDecode(utf8.decode(response.bodyBytes));
          } on FormatException {
            throw const PanoptoException('bad_answer');
          }
        case 401 when attempt == 0:
          continue;
        case 401:
          throw const PanoptoException('reconnect', 'API refused the token');
        case 403:
          throw const PanoptoException('forbidden');
        case 404:
          throw const PanoptoException('not_found');
        default:
          throw PanoptoException('http_${response.statusCode}');
      }
    }
  }

  /// A recording from the API, or null without an id or start time.
  static PanoptoRecording? recordingFromJson(
    Map<String, Object?> json, {
    required String site,
  }) {
    final id = json['Id'];
    final start = json['StartTime'];
    if (id is! String || start is! String) return null;
    final wall = wallClock(start);
    if (wall == null) return null;
    final urls = json['Urls'];
    final viewer = urls is Map ? urls['ViewerUrl'] : null;
    return PanoptoRecording(
      id: id.toLowerCase(),
      name: json['Name'] as String? ?? '',
      description: json['Description'] as String? ?? '',
      wallStart: wall,
      utcStart: realTime(start),
      durationSec: (json['Duration'] as num?)?.toDouble() ?? 0,
      complete: isComplete(json['Status']),
      viewerUrl: viewer is String && viewer.isNotEmpty
          ? viewer
          : 'https://$site/Panopto/Pages/Viewer.aspx?id=$id',
    );
  }

  /// Complete (4) or Archived (6), as a number or a name: the API documents
  /// names and sends numbers, the enum's index.
  static bool isComplete(Object? status) => switch (status) {
    4 || 6 || 'Complete' || 'Archived' => true,
    _ => false,
  };

  /// `StartTime`'s date and clock digits, whatever zone it claims.
  static RecordingTime? wallClock(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})')
        .firstMatch(text.trim());
    if (m == null) return null;
    int at(int i) => int.parse(m.group(i)!);
    return (date: LocalDate(at(1), at(2), at(3)), minute: at(4) * 60 + at(5));
  }

  /// `StartTime` as the real moment it claims, in the device's time zone;
  /// null when it names no zone.
  static RecordingTime? realTime(String text) {
    final trimmed = text.trim();
    if (!RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(trimmed)) return null;
    final parsed = DateTime.tryParse(
      trimmed.replaceFirstMapped(RegExp(r'(\.\d{6})\d+'), (m) => m.group(1)!),
    );
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return (
      date: LocalDate.fromDateTime(local),
      minute: local.hour * 60 + local.minute,
    );
  }

  /// A folder name as people should read it: HTML entities decoded and
  /// Moodle's language tags (`{mlang he}…{mlang}{mlang en}…{mlang}`)
  /// reduced to [language]'s text, or the first.
  static String cleanName(String raw, {String language = 'he'}) {
    var text = raw;
    final parts = RegExp(r'\{mlang\s+(\w+)\}(.*?)\{mlang\}')
        .allMatches(text)
        .toList();
    if (parts.isNotEmpty) {
      final chosen = parts.firstWhere(
        (m) => m.group(1) == language,
        orElse: () => parts.first,
      );
      text = text.replaceRange(
        parts.first.start,
        parts.last.end,
        chosen.group(2)!,
      );
    }
    return _unescape(text).trim();
  }

  static String _unescape(String text) => text
      .replaceAll('&gt;', '>')
      .replaceAll('&lt;', '<')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
