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

/// What happened to one session, for the developer's matching details.
enum SessionOutcome {
  /// Gets (or keeps) a link found in Panopto.
  found,

  /// Has a link the user pasted.
  ownLink,

  /// The user removed its link (`''`).
  removed,
  canceled,

  /// Not over yet.
  notOver,

  /// Nothing of this course was recorded at its time.
  noRecording,

  /// Only recordings still being recorded or processed.
  processing,

  /// Only recordings of another group (the one chosen is missing).
  otherGroup,

  /// Only recordings of another type (a practice at a lecture's time).
  otherType,

  /// The recordings at its time went to other sessions.
  usedElsewhere,

  /// Several groups at its time: waiting for the user's answer.
  askGroup,
}

/// What happened to one recording, for the developer's matching details.
enum RecordingOutcome {
  /// Linked to a session.
  linked,

  /// A link the user pasted points to it.
  inYourLink,

  /// Still recording or processing.
  processing,

  /// Its name starts with another course number.
  otherCourse,

  /// No session of the course at its time.
  noSession,

  /// Fits only sessions that take no found link (canceled, the user's own
  /// or removed link, not over).
  sessionClosed,

  /// Another group's.
  otherGroup,

  /// Another type's (a practice at a lecture's time).
  otherType,

  /// Its session waits for the group question.
  askGroup,

  /// Another recording at the same time won the session.
  lostToAnother,
}

class SessionDetail {
  const SessionDetail(this.session, this.outcome, {this.recordingId});
  final Occurrence session;
  final SessionOutcome outcome;

  /// The recording linked ([SessionOutcome.found]).
  final String? recordingId;
}

class RecordingDetail {
  const RecordingDetail(
    this.recording,
    this.start,
    this.outcome, {
    this.session,
    this.closedAs,
    this.nearest,
  });
  final PanoptoRecording recording;

  /// Its start as the matcher read it.
  final RecordingTime start;
  final RecordingOutcome outcome;

  /// The session it went to, or the one it fits.
  final Occurrence? session;

  /// Why [session] takes no found link ([RecordingOutcome.sessionClosed]).
  final SessionOutcome? closedAs;

  /// [RecordingOutcome.noSession]: the course's session closest in start
  /// time on that date, if any.
  final Occurrence? nearest;
}

/// Why each session and recording ended up as it did.
class MatchDetails {
  const MatchDetails({
    required this.readUtc,
    required this.fitWall,
    required this.fitUtc,
    required this.sessions,
    required this.recordings,
  });

  /// `StartTime` was read as real UTC (otherwise as wall-clock digits).
  final bool readUtc;

  /// How many recordings fit some session with each reading.
  final int fitWall;
  final int fitUtc;

  /// The course's sessions up to now, newest first.
  final List<SessionDetail> sessions;

  /// Every recording read, newest first.
  final List<RecordingDetail> recordings;

  static const empty = MatchDetails(
    readUtc: false,
    fitWall: 0,
    fitUtc: 0,
    sessions: [],
    recordings: [],
  );
}

class RecordingMatchResult {
  const RecordingMatchResult({
    this.links = const [],
    this.questions = const [],
    this.learnedGroups = const {},
    this.details = MatchDetails.empty,
  });

  /// Links to write: each session's current link is empty or was found
  /// automatically, and differs from this one.
  final List<FoundRecording> links;
  final List<GroupQuestion> questions;

  /// Groups to remember per meeting id, learned from the links the user
  /// pasted (see [RecordingMatcher.learnFrom]).
  final Map<String, String> learnedGroups;
  final MatchDetails details;
}

/// Puts a course's Panopto recordings on its sessions.
///
/// Pure: the caller fetches the recordings and writes the result.
abstract final class RecordingMatcher {
  /// How early a recording may start before its session.
  static const earlyMinutes = 30;

  /// A meeting without a chosen group takes the group of the recordings in
  /// links the user pasted into its sessions, when at least this many all
  /// point to the same group.
  static const learnFrom = 2;

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
    final sameCourse = [
      for (final r in recordings)
        if (_sameCourse(r, courseCode)) r,
    ];
    final ours = [
      for (final r in sameCourse)
        if (r.complete) r,
    ];
    final (:readUtc, :wall, :utc) = _reading(ours, sessions);
    RecordingTime startOf(PanoptoRecording r) =>
        readUtc ? r.utcStart! : r.wallStart;

    // Recordings already in links pasted by hand stay where they are. Links
    // found automatically are found again (and may move to a better match).
    final byId = {for (final r in ours) r.id: r};
    final used = <String>{};
    final pasted = <String>{};
    final pastedGroups = <String, Map<String, int>>{};
    for (final s in sessions) {
      final url = s.recordingUrl;
      if (url == null || url.trim().isEmpty || s.recordingAuto) continue;
      final id = recordingIdOf(url);
      if (id == null) continue;
      used.add(id);
      pasted.add(id);
      final group = byId[id]?.group;
      if (group != null) {
        final counts = pastedGroups.putIfAbsent(s.meetingId, () => {});
        counts[group] = (counts[group] ?? 0) + 1;
      }
    }

    // The user follows the group their own links point to (the owner's
    // practice links are all group ו while the timetable says ד).
    final learned = <String, String>{
      for (final MapEntry(key: meetingId, value: counts)
          in pastedGroups.entries)
        if ((groups[meetingId] ?? '').isEmpty &&
            counts.length == 1 &&
            counts.values.single >= learnFrom)
          meetingId: counts.keys.single,
    };
    final chosenGroups = {...groups, ...learned};

    final links = <FoundRecording>[];
    final ties = <String, Map<String, GroupOption>>{};
    final outcomes = <String, SessionOutcome>{};
    final linkedTo = <String, String>{}; // session id → recording id
    final candidatesFor = <String, List<PanoptoRecording>>{};
    final dropped = <String, RecordingOutcome>{}; // recording id → why
    final open = [
      for (final s in sessions)
        if (_mayFill(s, now)) s,
    ]..sort((a, b) => a.start.compareTo(b.start));

    for (final s in open) {
      final fitting = [
        for (final r in ours)
          if (_fits(startOf(r), s)) r,
      ];
      var candidates = [
        for (final r in fitting)
          if (!used.contains(r.id)) r,
      ];
      if (candidates.isEmpty) {
        final busy = sameCourse.any(
          (r) => !r.complete && _fits(r.wallStart, s),
        );
        outcomes[s.id] = fitting.isNotEmpty
            ? SessionOutcome.usedElsewhere
            : busy
            ? SessionOutcome.processing
            : SessionOutcome.noRecording;
        continue;
      }
      final typed = _sameType(candidates, s.type);
      for (final r in candidates) {
        if (!typed.contains(r)) dropped[r.id] ??= RecordingOutcome.otherType;
      }
      if (typed.isEmpty) {
        outcomes[s.id] = SessionOutcome.otherType;
        continue;
      }
      candidates = typed;
      final chosen = chosenGroups[s.meetingId] ?? '';
      if (chosen.isNotEmpty) {
        final mine = [
          for (final r in candidates)
            if (r.group == null || r.group == chosen) r,
        ];
        for (final r in candidates) {
          if (!mine.contains(r)) dropped[r.id] ??= RecordingOutcome.otherGroup;
        }
        if (mine.isEmpty) {
          outcomes[s.id] = SessionOutcome.otherGroup;
          continue;
        }
        candidates = mine;
      } else {
        final groups = {
          for (final r in candidates)
            if (r.group != null) r.group!,
        };
        if (groups.length > 1) {
          final options = ties.putIfAbsent(s.meetingId, () => {});
          for (final r in candidates) {
            dropped[r.id] ??= RecordingOutcome.askGroup;
            if (r.group == null) continue;
            options[r.group!] = GroupOption(
              group: r.group!,
              room: r.room ?? options[r.group!]?.room,
              type: r.type,
            );
          }
          outcomes[s.id] = SessionOutcome.askGroup;
          continue;
        }
      }
      candidatesFor[s.id] = candidates;
    }

    // The closest pairs first, across sessions: a recording goes to the
    // session it fits best, not to whichever session came first.
    final pairs = [
      for (final s in open)
        for (final r in candidatesFor[s.id] ?? const <PanoptoRecording>[])
          (s, r),
    ];
    int rank((Occurrence, PanoptoRecording) pair) {
      final (s, r) = pair;
      return (startOf(r).minute - s.startMin).abs();
    }

    pairs.sort((a, b) {
      final byTime = rank(a).compareTo(rank(b));
      if (byTime != 0) return byTime;
      final (sa, ra) = a;
      final (sb, rb) = b;
      final byRoom = _rank(ra.room == sa.location.trim())
          .compareTo(_rank(rb.room == sb.location.trim()));
      if (byRoom != 0) return byRoom;
      final byKind = _rank(ra.scheduled).compareTo(_rank(rb.scheduled));
      if (byKind != 0) return byKind;
      final byLength = rb.durationSec.compareTo(ra.durationSec);
      if (byLength != 0) return byLength;
      final bySession = sa.start.compareTo(sb.start);
      if (bySession != 0) return bySession;
      return ra.id.compareTo(rb.id);
    });
    final taken = <String>{};
    for (final (s, r) in pairs) {
      if (linkedTo.containsKey(s.id) || taken.contains(r.id)) continue;
      taken.add(r.id);
      linkedTo[s.id] = r.id;
      outcomes[s.id] = SessionOutcome.found;
      if (recordingIdOf(s.recordingUrl ?? '') != r.id) {
        links.add(FoundRecording(s, r));
      }
    }
    for (final s in open) {
      if (candidatesFor.containsKey(s.id) && !linkedTo.containsKey(s.id)) {
        outcomes[s.id] = SessionOutcome.usedElsewhere;
      }
    }
    for (final (_, r) in pairs) {
      if (!taken.contains(r.id)) {
        dropped[r.id] ??= RecordingOutcome.lostToAnother;
      }
    }
    links.sort((a, b) => a.session.start.compareTo(b.session.start));

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
    return RecordingMatchResult(
      links: links,
      questions: questions,
      learnedGroups: learned,
      details: _details(
        recordings: recordings,
        sessions: sessions,
        now: now,
        courseCode: courseCode,
        readUtc: readUtc,
        fitWall: wall,
        fitUtc: utc,
        outcomes: outcomes,
        linkedTo: linkedTo,
        pasted: pasted,
        dropped: dropped,
      ),
    );
  }

  /// Why each session and recording ended up as it did.
  static MatchDetails _details({
    required List<PanoptoRecording> recordings,
    required List<Occurrence> sessions,
    required DateTime now,
    required String courseCode,
    required bool readUtc,
    required int fitWall,
    required int fitUtc,
    required Map<String, SessionOutcome> outcomes,
    required Map<String, String> linkedTo,
    required Set<String> pasted,
    required Map<String, RecordingOutcome> dropped,
  }) {
    SessionOutcome outcomeOf(Occurrence s) {
      final known = outcomes[s.id];
      if (known != null) return known;
      if (!s.hasEnded(now)) return SessionOutcome.notOver;
      if (s.isCanceled) return SessionOutcome.canceled;
      if (s.recordingUrl == '') return SessionOutcome.removed;
      return SessionOutcome.ownLink;
    }

    final past = [
      for (final s in sessions)
        if (s.start.isBefore(now)) s,
    ]..sort((a, b) => b.start.compareTo(a.start));
    final sessionDetails = [
      for (final s in past)
        SessionDetail(s, outcomeOf(s), recordingId: linkedTo[s.id]),
    ];
    final sessionOf = {for (final e in linkedTo.entries) e.value: e.key};
    final byId = {for (final s in sessions) s.id: s};

    RecordingDetail detail(PanoptoRecording r) {
      final start = readUtc && r.utcStart != null ? r.utcStart! : r.wallStart;
      if (!_sameCourse(r, courseCode)) {
        return RecordingDetail(r, start, RecordingOutcome.otherCourse);
      }
      if (!r.complete) {
        return RecordingDetail(r, start, RecordingOutcome.processing);
      }
      final linked = sessionOf[r.id];
      if (linked != null) {
        return RecordingDetail(
          r,
          start,
          RecordingOutcome.linked,
          session: byId[linked],
        );
      }
      if (pasted.contains(r.id)) {
        return RecordingDetail(r, start, RecordingOutcome.inYourLink);
      }
      final fitting = [
        for (final s in sessions)
          if (_fits(start, s)) s,
      ];
      if (fitting.isEmpty) {
        Occurrence? nearest;
        for (final s in sessions) {
          if (s.date != start.date) continue;
          if (nearest == null ||
              (s.startMin - start.minute).abs() <
                  (nearest.startMin - start.minute).abs()) {
            nearest = s;
          }
        }
        return RecordingDetail(
          r,
          start,
          RecordingOutcome.noSession,
          nearest: nearest,
        );
      }
      final why = dropped[r.id];
      if (why != null) {
        return RecordingDetail(r, start, why, session: fitting.first);
      }
      final first = fitting.first;
      return RecordingDetail(
        r,
        start,
        RecordingOutcome.sessionClosed,
        session: first,
        closedAs: outcomeOf(first),
      );
    }

    final recordingDetails = [for (final r in recordings) detail(r)]
      ..sort((a, b) {
        final byDate = b.start.date.compareTo(a.start.date);
        return byDate != 0 ? byDate : b.start.minute.compareTo(a.start.minute);
      });
    return MatchDetails(
      readUtc: readUtc,
      fitWall: fitWall,
      fitUtc: fitUtc,
      sessions: sessionDetails,
      recordings: recordingDetails,
    );
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

  /// Reads `StartTime` as real UTC when that puts more recordings on
  /// sessions than reading its digits as local time.
  static ({bool readUtc, int wall, int utc}) _reading(
    List<PanoptoRecording> recordings,
    List<Occurrence> sessions,
  ) {
    var wall = 0;
    var utc = 0;
    final allUtc = recordings.every((r) => r.utcStart != null);
    for (final r in recordings) {
      if (sessions.any((s) => _fits(r.wallStart, s))) wall++;
      if (allUtc && sessions.any((s) => _fits(r.utcStart!, s))) utc++;
    }
    return (readUtc: allUtc && utc > wall, wall: wall, utc: utc);
  }
}
