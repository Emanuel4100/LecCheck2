import 'dart:convert';

import 'local_date.dart';
import 'occurrence.dart';
import 'schedule_types.dart';

/// A start time as a date and minutes after midnight, in local time.
typedef RecordingTime = ({LocalDate date, int minute});

/// A Panopto folder chosen for a course.
class PanoptoFolderRef {
  const PanoptoFolderRef({required this.id, required this.name});

  factory PanoptoFolderRef.fromJson(Map<String, Object?> json) =>
      PanoptoFolderRef(
        id: (json['id'] as String? ?? '').toLowerCase(),
        name: json['name'] as String? ?? '',
      );

  /// A GUID, lower case.
  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  /// `courses.panoptoFolders`: `''` = not chosen yet (null), otherwise a
  /// JSON list. Unreadable text counts as not chosen.
  static List<PanoptoFolderRef>? decodeList(String text) {
    if (text.trim().isEmpty) return null;
    try {
      final list = jsonDecode(text);
      if (list is! List) return null;
      return [
        for (final item in list)
          if (item is Map) PanoptoFolderRef.fromJson(item.cast()),
      ];
    } on FormatException {
      return null;
    }
  }

  static String encodeList(List<PanoptoFolderRef>? folders) =>
      folders == null ? '' : jsonEncode([for (final f in folders) f.toJson()]);

  @override
  bool operator ==(Object other) =>
      other is PanoptoFolderRef && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// One recording in a Panopto folder, as the matcher needs it.
class PanoptoRecording {
  PanoptoRecording({
    required this.id,
    required this.name,
    required this.wallStart,
    required this.durationSec,
    required this.complete,
    required this.viewerUrl,
    this.description = '',
    this.utcStart,
  }) : _details = RecordingDetails.parse(name, description);

  /// Panopto's session id (a GUID, lower case).
  final String id;
  final String name;
  final String description;

  /// `StartTime`'s clock digits read as local time. HUJI's site sends the
  /// local wall-clock time marked as UTC (`12:00:01Z` for a 12:00 class).
  final RecordingTime wallStart;

  /// `StartTime` read as real UTC and converted to the device's time zone:
  /// right if a site sends true UTC.
  final RecordingTime? utcStart;
  final double durationSec;

  /// Done recording and processing (status Complete or Archived).
  final bool complete;
  final String viewerUrl;
  final RecordingDetails _details;

  String? get room => _details.room;
  SessionType? get type => _details.type;

  /// The group letter, e.g. "ו" in `תרגיל ו`; null when unknown.
  String? get group => _details.group;

  /// Has the official slot from the timetable: an automatic recording.
  bool get scheduled => _details.scheduled;
}

/// What a recording's name and description say about it. HUJI's automatic
/// recordings are named `80430 2026-11-16 תרגיל א`, and their description
/// lines are the course number, its English and Hebrew names, the slot
/// (`יום ב 12:00 - 13:45`), the room and the type with the group.
class RecordingDetails {
  const RecordingDetails({
    this.room,
    this.type,
    this.group,
    this.scheduled = false,
  });

  factory RecordingDetails.parse(String name, String description) {
    final lines = [
      for (final l in description.split(RegExp(r'\r?\n')))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    String? room;
    SessionType? type;
    String? group;
    var scheduled = false;
    for (var i = 0; i < lines.length; i++) {
      final kind = _typeAndGroup.firstMatch(lines[i]);
      if (kind != null) {
        type = typeOfWord(kind.group(1)!);
        group = kind.group(2);
      }
      if (_slot.hasMatch(lines[i])) {
        scheduled = true;
        if (i + 1 < lines.length &&
            !_typeAndGroup.hasMatch(lines[i + 1]) &&
            !_slot.hasMatch(lines[i + 1])) {
          room = lines[i + 1];
        }
      }
    }
    if (type == null) {
      final fromName = _typeAndGroupAtEnd.firstMatch(name.trim());
      if (fromName != null) {
        type = typeOfWord(fromName.group(1)!);
        group = fromName.group(2);
      }
    }
    return RecordingDetails(
      room: room,
      type: type,
      group: group,
      scheduled: scheduled,
    );
  }

  final String? room;
  final SessionType? type;
  final String? group;
  final bool scheduled;

  static const _words = 'שעור|שיעור|הרצאה|תרגיל|תרגול|מעבדה';
  static final _typeAndGroup = RegExp('^($_words)\\s+(\\S+)\$');
  static final _typeAndGroupAtEnd = RegExp('($_words)\\s+(\\S+)\$');
  static final _slot = RegExp(
    r'^יום\s+\S+\s+\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}$',
  );

  static SessionType? typeOfWord(String word) => switch (word) {
    'שעור' || 'שיעור' || 'הרצאה' => SessionType.lecture,
    'תרגיל' || 'תרגול' => SessionType.practice,
    'מעבדה' => SessionType.lab,
    _ => null,
  };
}

/// A recording to link to a session.
class FoundRecording {
  const FoundRecording(this.session, this.recording);
  final Occurrence session;
  final PanoptoRecording recording;

  @override
  String toString() => 'FoundRecording(${session.id} ← ${recording.name})';
}

/// One group's recordings, offered when several groups are recorded at a
/// meeting's time.
class GroupOption {
  const GroupOption({required this.group, this.room, this.type});
  final String group;
  final String? room;
  final SessionType? type;

  @override
  bool operator ==(Object other) =>
      other is GroupOption &&
      other.group == group &&
      other.room == room &&
      other.type == type;

  @override
  int get hashCode => Object.hash(group, room, type);

  @override
  String toString() => 'GroupOption($group, $room)';
}

/// Why a group is suggested.
enum GroupHint {
  /// Links pasted by hand into this meeting's sessions point to its
  /// recordings.
  links,

  /// Its room is the meeting's room.
  room,
}

/// Several groups are recorded at this meeting's time: which one's
/// recordings are the user's?
class GroupQuestion {
  const GroupQuestion({
    required this.meetingId,
    required this.options,
    this.suggested,
    this.hint,
  });
  final String meetingId;

  /// Sorted by group.
  final List<GroupOption> options;
  final String? suggested;
  final GroupHint? hint;

  @override
  String toString() => 'GroupQuestion($meetingId, $options, $suggested)';
}

class RecordingMatchResult {
  const RecordingMatchResult({
    this.links = const [],
    this.questions = const [],
  });

  /// Links to write: each session's current link is empty or was found
  /// automatically, and differs from this one.
  final List<FoundRecording> links;
  final List<GroupQuestion> questions;
}

/// Puts a course's Panopto recordings on its sessions.
///
/// Pure: the caller fetches the recordings and writes the result.
abstract final class RecordingMatcher {
  /// How early a recording may start before its session.
  static const earlyMinutes = 30;

  /// [sessions] are the course's sessions (any status), [meetings] its
  /// meetings (for their rooms), and [groups] the group letters chosen per
  /// meeting id.
  static RecordingMatchResult match({
    required List<PanoptoRecording> recordings,
    required List<Occurrence> sessions,
    required List<MeetingRule> meetings,
    required DateTime now,
    Map<String, String> groups = const {},
    String courseCode = '',
  }) {
    final meetingById = {for (final m in meetings) m.id: m};
    final ours = [
      for (final r in recordings)
        if (r.complete && _sameCourse(r, courseCode)) r,
    ];
    final readUtc = _utcFitsBetter(ours, sessions);
    RecordingTime startOf(PanoptoRecording r) =>
        readUtc ? r.utcStart! : r.wallStart;

    // Recordings already in links pasted by hand stay where they are. Links
    // found automatically are found again (and may move to a better match).
    final byId = {for (final r in ours) r.id: r};
    final used = <String>{};
    final pastedGroups = <String, Map<String, int>>{};
    for (final s in sessions) {
      final url = s.recordingUrl;
      if (url == null || url.trim().isEmpty || s.recordingAuto) continue;
      final id = recordingIdOf(url);
      if (id == null) continue;
      used.add(id);
      final group = byId[id]?.group;
      if (group != null) {
        final counts = pastedGroups.putIfAbsent(s.meetingId, () => {});
        counts[group] = (counts[group] ?? 0) + 1;
      }
    }

    final links = <FoundRecording>[];
    final ties = <String, Map<String, GroupOption>>{};
    final open = [
      for (final s in sessions)
        if (_mayFill(s, now)) s,
    ]..sort((a, b) => a.start.compareTo(b.start));

    for (final s in open) {
      var candidates = [
        for (final r in ours)
          if (!used.contains(r.id) && _fits(startOf(r), s)) r,
      ];
      candidates = _sameType(candidates, s.type);
      final chosen = groups[s.meetingId] ?? '';
      if (chosen.isNotEmpty) {
        candidates = [
          for (final r in candidates)
            if (r.group == null || r.group == chosen) r,
        ];
      } else {
        final groups = {
          for (final r in candidates)
            if (r.group != null) r.group!,
        };
        if (groups.length > 1) {
          final options = ties.putIfAbsent(s.meetingId, () => {});
          for (final r in candidates) {
            if (r.group == null) continue;
            options[r.group!] = GroupOption(
              group: r.group!,
              room: r.room ?? options[r.group!]?.room,
              type: r.type,
            );
          }
          continue;
        }
      }
      if (candidates.isEmpty) continue;
      final room = s.location.trim();
      int distance(PanoptoRecording r) =>
          (startOf(r).minute - s.startMin).abs();
      candidates.sort((a, b) {
        final byTime = distance(a).compareTo(distance(b));
        if (byTime != 0) return byTime;
        final byRoom = _rank(a.room == room).compareTo(_rank(b.room == room));
        if (byRoom != 0) return byRoom;
        final byKind = _rank(a.scheduled).compareTo(_rank(b.scheduled));
        if (byKind != 0) return byKind;
        final byLength = b.durationSec.compareTo(a.durationSec);
        if (byLength != 0) return byLength;
        return a.id.compareTo(b.id);
      });
      final best = candidates.first;
      used.add(best.id);
      if (recordingIdOf(s.recordingUrl ?? '') != best.id) {
        links.add(FoundRecording(s, best));
      }
    }

    final questions = <GroupQuestion>[];
    for (final MapEntry(key: meetingId, value: options) in ties.entries) {
      final sorted = options.values.toList()
        ..sort((a, b) => a.group.compareTo(b.group));
      String? suggested;
      GroupHint? hint;
      final pasted = pastedGroups[meetingId] ?? const {};
      final fromLinks =
          pasted.entries.where((e) => options.containsKey(e.key)).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      if (fromLinks.isNotEmpty) {
        suggested = fromLinks.first.key;
        hint = GroupHint.links;
      } else {
        final room = meetingById[meetingId]?.location.trim() ?? '';
        final sameRoom = sorted.where((o) => room.isNotEmpty && o.room == room);
        if (sameRoom.length == 1) {
          suggested = sameRoom.first.group;
          hint = GroupHint.room;
        }
      }
      questions.add(
        GroupQuestion(
          meetingId: meetingId,
          options: sorted,
          suggested: suggested,
          hint: hint,
        ),
      );
    }
    return RecordingMatchResult(links: links, questions: questions);
  }

  /// The Panopto session id in a viewer or embed link (`…?id=<guid>`).
  static String? recordingIdOf(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    for (final MapEntry(:key, :value) in uri.queryParameters.entries) {
      if (key.toLowerCase() == 'id' && _guid.hasMatch(value)) {
        return value.toLowerCase();
      }
    }
    return null;
  }

  static final _guid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static int _rank(bool good) => good ? 0 : 1;

  /// Sessions that may get a link: over, not canceled, real classes, and
  /// either without a link or with one found automatically. A link cleared
  /// by hand is `''` and stays cleared.
  static bool _mayFill(Occurrence s, DateTime now) =>
      s.hasEnded(now) &&
      !s.isCanceled &&
      s.type != SessionType.reception &&
      (s.recordingUrl == null || (s.recordingAuto && s.recordingUrl != ''));

  static bool _fits(RecordingTime start, Occurrence s) =>
      start.date == s.date &&
      start.minute >= s.startMin - earlyMinutes &&
      start.minute < s.endMin;

  /// Lectures get lecture recordings and practices practice ones when the
  /// recordings say which they are. "Other" sessions take any.
  static List<PanoptoRecording> _sameType(
    List<PanoptoRecording> candidates,
    SessionType type,
  ) {
    if (type == SessionType.other) return candidates;
    return [
      for (final r in candidates)
        if (r.type == null || r.type == type) r,
    ];
  }

  /// A folder can hold other courses' recordings: names starting with
  /// another course number are left out.
  static bool _sameCourse(PanoptoRecording r, String courseCode) {
    final code = courseCode.trim();
    if (code.isEmpty) return true;
    final first = r.name.trim().split(RegExp(r'\s+')).first;
    final number = RegExp(r'^(\d{4,})(?:_\d+)?$').firstMatch(first);
    if (number == null) return true;
    return _digits(number.group(1)!) == _digits(code);
  }

  static String _digits(String s) =>
      s.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp('^0+'), '');

  /// Whether reading `StartTime` as real UTC puts more recordings on
  /// sessions than reading its digits as local time.
  static bool _utcFitsBetter(
    List<PanoptoRecording> recordings,
    List<Occurrence> sessions,
  ) {
    if (recordings.any((r) => r.utcStart == null)) return false;
    var wall = 0;
    var utc = 0;
    for (final r in recordings) {
      if (sessions.any((s) => _fits(r.wallStart, s))) wall++;
      if (sessions.any((s) => _fits(r.utcStart!, s))) utc++;
    }
    return utc > wall;
  }
}
