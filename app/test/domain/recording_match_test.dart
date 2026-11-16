import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leccheck/core/recordings/panopto_api.dart';
import 'package:leccheck/domain/occurrence.dart';
import 'package:leccheck/domain/occurrence_engine.dart';
import 'package:leccheck/domain/recording_match.dart';
import 'package:leccheck/domain/schedule_types.dart';

import 'helpers.dart';

/// Course 80430's Panopto folder on 2026-11-16 (58 recordings; ids and links
/// replaced): HUJI's automatic recordings plus a few named by hand.
List<PanoptoRecording> folder() => [
  for (final page in [0, 1])
    for (final json
        in (jsonDecode(
                  File('test/fixtures/panopto/folder_sessions_p$page.json')
                      .readAsStringSync(),
                )['Results']
                as List)
            .cast<Map<String, Object?>>())
      PanoptoApi.recordingFromJson(json, site: 'example.cloud.panopto.eu')!,
];

/// The owner's 80430 meetings, as imported from HUJI's timetable.
final _meetings = [
  weekly(
    id: 'tue9',
    type: SessionType.other,
    weekday: DateTime.tuesday,
    startMin: 9 * 60,
    endMin: 9 * 60 + 45,
    location: 'אודיטוריום הנדסה',
  ),
  weekly(
    id: 'tue10',
    weekday: DateTime.tuesday,
    startMin: 10 * 60,
    endMin: 11 * 60 + 45,
    location: 'קפלן',
  ),
  weekly(
    id: 'thuPractice',
    type: SessionType.practice,
    weekday: DateTime.thursday,
    startMin: 10 * 60,
    endMin: 11 * 60 + 45,
    location: 'שפרינצק 27',
  ),
  weekly(
    id: 'thu12',
    weekday: DateTime.thursday,
    startMin: 12 * 60,
    endMin: 13 * 60 + 45,
    location: 'פלדמן ב',
  ),
];

final _now = DateTime(2026, 11, 16, 20);

List<Occurrence> sessions({
  List<MeetingRule>? meetings,
  List<SessionOverride> overrides = const [],
}) => OccurrenceEngine.expand(
  semester: semester(start: '2026-10-11'),
  meetings: meetings ?? _meetings,
  overrides: overrides,
).all;

RecordingMatchResult match({
  List<PanoptoRecording>? recordings,
  List<Occurrence>? on,
  List<MeetingRule>? meetings,
  Map<String, String> groups = const {},
  DateTime? now,
}) => RecordingMatcher.match(
  recordings: recordings ?? folder(),
  sessions: on ?? sessions(meetings: meetings),
  meetings: meetings ?? _meetings,
  groups: groups,
  now: now ?? _now,
  courseCode: '80430',
);

/// "meetingId date ← recording name / room".
List<String> describe(RecordingMatchResult result) => [
  for (final f in result.links)
    '${f.session.meetingId} ${f.session.date} ← ${f.recording.name}'
        ' / ${f.recording.room}',
];

String _viewer(PanoptoRecording r) => r.viewerUrl;

PanoptoRecording named(String name, {String? group}) => folder().firstWhere(
  (r) => r.name == name && (group == null || r.group == group),
);

void main() {
  group('the real 80430 folder', () {
    test('each meeting gets its own recordings by time', () {
      final result = match();
      expect(
        describe(result)..sort(),
        [
          'thu12 2026-10-15 ← 80430 2026-10-15 שעור א / פלדמן ב',
          'tue9 2026-10-20 ← 80430 2026-10-20 שעור א / אודיטוריום הנדסה',
          'tue10 2026-10-13 ← 80430 2026-10-13 שעור א / קפלן',
          'tue10 2026-10-20 ← 80430 2026-10-20 שעור א / קפלן',
          'thu12 2026-10-22 ← 80430 2026-10-22 שעור א / פלדמן ב',
          'thu12 2026-10-29 ← 80430 2026-10-29 שעור א / פלדמן ב',
          'tue9 2026-11-03 ← 80430 2026-11-03 שעור א / אודיטוריום הנדסה',
          'tue10 2026-11-03 ← 80430 2026-11-03 שעור א / קפלן',
          'thu12 2026-11-05 ← 80430 2026-11-05 שעור א / פלדמן ב',
          'tue9 2026-11-10 ← 80430 2026-11-10 שעור א / אודיטוריום הנדסה',
          'tue10 2026-11-10 ← 80430 2026-11-10 שעור א / קפלן',
          'thu12 2026-11-12 ← 80430 2026-11-12 שעור א / פלדמן ב',
        ]..sort(),
      );
    });

    test('two practice groups at one time are a question, not a guess', () {
      final result = match();
      expect(
        result.links.where((f) => f.session.meetingId == 'thuPractice'),
        isEmpty,
      );
      expect(result.questions, hasLength(1));
      final q = result.questions.single;
      expect(q.meetingId, 'thuPractice');
      expect(q.options, const [
        GroupOption(group: 'ד', room: 'שפרינצק 27', type: SessionType.practice),
        GroupOption(
          group: 'ו',
          room: 'שפרינצק 115',
          type: SessionType.practice,
        ),
      ]);
      // The meeting's room is ד's.
      expect((q.suggested, q.hint), ('ד', GroupHint.room));
    });

    test('links pasted by hand suggest their group over the room', () {
      final pasted = named('80430 2026-10-29 תרגיל ו');
      final result = match(
        on: sessions(
          overrides: [
            SessionOverride(
              meetingId: 'thuPractice',
              originalDate: d('2026-10-29'),
              recordingUrl: _viewer(pasted),
            ),
          ],
        ),
      );
      final q = result.questions.single;
      expect((q.suggested, q.hint), ('ו', GroupHint.links));
    });

    test('a chosen group gets that group\'s recordings', () {
      final result = match(groups: {'thuPractice': 'ו'});
      expect(result.questions, isEmpty);
      final practice = [
        for (final f in result.links)
          if (f.session.meetingId == 'thuPractice')
            '${f.session.date} ${f.recording.group} ${f.recording.room}',
      ];
      expect(practice, [
        '2026-10-15 ו שפרינצק 115',
        '2026-10-22 ו שפרינצק 115',
        '2026-10-29 ו שפרינצק 115',
        '2026-11-05 ו שפרינצק 115',
        '2026-11-12 ו שפרינצק 115',
      ]);
    });
  });

  group('what is never filled', () {
    test('canceled sessions, cleared links and pasted links stay', () {
      final pasted = named('80430 2026-11-12 שעור א');
      final result = match(
        on: sessions(
          overrides: [
            SessionOverride(
              meetingId: 'thu12',
              originalDate: d('2026-10-15'),
              status: AttendanceStatus.canceled,
            ),
            SessionOverride(
              meetingId: 'thu12',
              originalDate: d('2026-10-22'),
              recordingUrl: '',
            ),
            // Pasted on the wrong week: kept, and not used again.
            SessionOverride(
              meetingId: 'thu12',
              originalDate: d('2026-10-29'),
              recordingUrl: _viewer(pasted),
            ),
          ],
        ),
      );
      final thu12 = [
        for (final f in result.links)
          if (f.session.meetingId == 'thu12') '${f.session.date}',
      ];
      expect(thu12, ['2026-11-05']);
    });

    test('sessions not over yet, and recordings still processing', () {
      final during = DateTime(2026, 11, 12, 13); // Thursday's lecture
      final processing = PanoptoRecording(
        id: 'p',
        name: '80430 2026-11-12 שעור א',
        wallStart: (date: d('2026-11-12'), minute: 12 * 60),
        durationSec: 3600,
        complete: false,
        viewerUrl: 'https://example/p',
      );
      final later = DateTime(2026, 11, 12, 15);
      final stillProcessing = match(
        recordings: [processing],
        meetings: [_meetings.last],
        now: later,
      );
      expect(stillProcessing.links, isEmpty);
      final thursday = match(meetings: [_meetings.last], now: during);
      expect(
        thursday.links.map((f) => '${f.session.date}'),
        isNot(contains('2026-11-12')),
      );
    });

    test('a lecture doesn\'t take a practice recording', () {
      // The owner's lecture meeting moved to Monday 12:00, when only group
      // א's practice is recorded.
      final monday = weekly(
        id: 'mon',
        weekday: DateTime.monday,
        startMin: 12 * 60,
        endMin: 13 * 60 + 45,
      );
      final result = match(meetings: [monday]);
      // Hand-named recordings (no type) still fit: 2026-10-12 has none of
      // those, 2026-11-02 and 2026-11-09 do.
      expect(describe(result), [
        'mon 2026-11-02 ← 80430 02/11 12-14 / null',
        'mon 2026-11-09 ← 80430 9.11 12-14 / null',
      ]);
    });
  });

  group('links found before', () {
    test('the same link again changes nothing', () {
      final first = match(meetings: [_meetings.last]).links;
      final again = match(
        meetings: [_meetings.last],
        on: sessions(
          meetings: [_meetings.last],
          overrides: [
            for (final f in first)
              SessionOverride(
                meetingId: f.session.meetingId,
                originalDate: f.session.originalDate,
                recordingFound: f.recording.viewerUrl,
              ),
          ],
        ),
      );
      expect(again.links, isEmpty);
    });

    test('a found link moves to a better match; a pasted one never', () {
      final wrong = named('80430 2026-11-12 תרגיל ד');
      final overrides = [
        SessionOverride(
          meetingId: 'thuPractice',
          originalDate: d('2026-11-12'),
          recordingFound: wrong.viewerUrl,
        ),
      ];
      final moved = match(
        groups: {'thuPractice': 'ו'},
        on: sessions(overrides: overrides),
      );
      expect(
        moved.links
            .where((f) => f.session.date == d('2026-11-12'))
            .where((f) => f.session.meetingId == 'thuPractice')
            .single
            .recording
            .group,
        'ו',
      );
      final pasted = match(
        groups: {'thuPractice': 'ו'},
        on: sessions(
          overrides: [
            SessionOverride(
              meetingId: 'thuPractice',
              originalDate: d('2026-11-12'),
              recordingUrl: wrong.viewerUrl,
            ),
          ],
        ),
      );
      expect(
        pasted.links.where(
          (f) =>
              f.session.date == d('2026-11-12') &&
              f.session.meetingId == 'thuPractice',
        ),
        isEmpty,
      );
    });
  });

  group('times', () {
    PanoptoRecording at(String id, String startTime) =>
        PanoptoApi.recordingFromJson({
          'Id': id,
          'Name': '80430 x',
          'StartTime': startTime,
          'Duration': 6000,
          'Status': 4,
        }, site: 'example')!;

    test('HUJI\'s wall-clock times marked UTC are read as local', () {
      final result = match(
        meetings: [_meetings.last],
        recordings: [at('a', '2026-11-12T12:00:01.3779456Z')],
      );
      expect(describe(result), ['thu12 2026-11-12 ← 80430 x / null']);
    });

    test('true UTC times are read as UTC when that fits better', () {
      // 12:00 in Jerusalem: 09:00Z before October 25, 10:00Z after.
      final result = match(
        meetings: [_meetings.last],
        recordings: [
          at('a', '2026-10-22T09:00:00Z'),
          at('b', '2026-11-12T10:00:00Z'),
        ],
      );
      expect(describe(result), [
        'thu12 2026-10-22 ← 80430 x / null',
        'thu12 2026-11-12 ← 80430 x / null',
      ]);
    });

    test('a moved session takes the recording at its new time', () {
      final result = match(
        meetings: [_meetings.last],
        recordings: [at('a', '2026-11-11T16:00:00Z')],
        on: sessions(
          meetings: [_meetings.last],
          overrides: [
            SessionOverride(
              meetingId: 'thu12',
              originalDate: d('2026-11-12'),
              movedDate: d('2026-11-11'),
              movedStartMin: 16 * 60,
              movedEndMin: 17 * 60 + 45,
            ),
          ],
        ),
      );
      expect(describe(result), ['thu12 2026-11-11 ← 80430 x / null']);
    });
  });

  group('details', () {
    test('an automatic recording\'s description', () {
      final r = named('80430 2026-11-16 תרגיל א');
      expect(
        (r.type, r.group, r.room, r.scheduled),
        (SessionType.practice, 'א', 'ספרייה 44', true),
      );
    });

    test('a recording named by hand', () {
      // Its "(יום ד)" has a no-break space.
      final r = folder().firstWhere(
        (r) => r.name.startsWith('80430 13-14 on 11/11/2026'),
      );
      expect((r.type, r.group, r.room, r.scheduled), (null, null, null, false));
    });

    test('the name alone', () {
      final details = RecordingDetails.parse('67010 2024-11-04 סמינריון א', '');
      expect(details.type, isNull);
      expect(
        RecordingDetails.parse('80430 2026-11-16 תרגול 02', '').group,
        '02',
      );
    });

    test('other course numbers in the folder are left out', () {
      final other = PanoptoApi.recordingFromJson({
        'Id': 'x',
        'Name': '67010 2026-11-12 שעור א',
        'StartTime': '2026-11-12T12:00:00Z',
        'Duration': 6000,
        'Status': 4,
      }, site: 'example')!;
      expect(
        match(meetings: [_meetings.last], recordings: [other]).links,
        isEmpty,
      );
    });

    test('recording ids in links', () {
      expect(
        RecordingMatcher.recordingIdOf(
          'https://huji.cloud.panopto.eu/Panopto/Pages/Viewer.aspx?id=AB040E1E-9C68-410E-B8B6-B4650147C6F8&start=12',
        ),
        'ab040e1e-9c68-410e-b8b6-b4650147c6f8',
      );
      expect(RecordingMatcher.recordingIdOf('https://youtu.be/x'), isNull);
      expect(RecordingMatcher.recordingIdOf(''), isNull);
    });
  });
}
