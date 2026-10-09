import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/core/report/report_sender.dart';
import 'package:leccheck/features/settings/report_page.dart';

void main() {
  late Directory dir;
  late List<Map<String, Object?>> received;
  late http.Response Function() answer;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('reports');
    addTearDown(() => dir.deleteSync(recursive: true));
    received = [];
    answer = () => http.Response('{"ok":true}', 201);
  });

  ReportSender sender() => ReportSender(
    endpoint: Uri.parse('https://sync.test/v1/reports'),
    directory: () async => dir,
    client: () => MockClient((request) async {
      received.add(jsonDecode(request.body) as Map<String, Object?>);
      return answer();
    }),
  );

  File queue() => File('${dir.path}/${ReportSender.fileName}');

  const report = {'description': 'Reminders stopped', 'platform': 'android'};

  test('sends a report', () async {
    expect(await sender().send(report), ReportResult.sent);
    expect(received, [report]);
    expect(queue().existsSync(), isFalse);
  });

  test(
    'keeps it when the server or GitHub is down, and sends it later',
    () async {
      answer = () => http.Response('{"error":"unavailable"}', 503);
      expect(await sender().send(report), ReportResult.queued);
      expect(queue().existsSync(), isTrue);

      answer = () => http.Response('{"ok":true}', 201);
      expect(await sender().flush(), 1);
      expect(queue().existsSync(), isFalse);
      expect(received, [report, report]);
    },
  );

  test('keeps it while offline', () async {
    final offline = ReportSender(
      endpoint: Uri.parse('https://sync.test/v1/reports'),
      directory: () async => dir,
      client: () =>
          MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(await offline.send(report), ReportResult.queued);
    expect(await offline.flush(), 0);
    expect(queue().existsSync(), isTrue);
  });

  test(
    'drops what the server refuses: sending it again would not help',
    () async {
      answer = () => http.Response('{"error":"rate_limited"}', 429);
      expect(await sender().send(report), ReportResult.refused);
      answer = () => http.Response('{"error":"reports_unavailable"}', 503);
      expect(await sender().send(report), ReportResult.refused);
      expect(queue().existsSync(), isFalse);
    },
  );

  test('a build without a server refuses at once', () async {
    final none = ReportSender(directory: () async => dir);
    expect(await none.send(report), ReportResult.refused);
  });

  test('the preview shows every field that is sent', () {
    final preview = reportPreview({
      'appVersion': '2.0.0-beta.5',
      'contact': '',
      'description': 'Reminders stopped',
      'diagnostics': 'Log:\nline',
    });
    expect(
      preview,
      'appVersion: 2.0.0-beta.5\ndescription: Reminders stopped\n\nLog:\nline',
    );
  });
}
