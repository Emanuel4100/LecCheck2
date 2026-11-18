import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/recording_match.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_data.dart';
import '../db/schedule_repository.dart';
import '../dev/dev_log.dart';
import 'match_report.dart';
import 'panopto_api.dart';
import 'panopto_connection.dart';

/// A group question from the last look, with its course.
class OpenGroupQuestion {
  const OpenGroupQuestion(this.courseId, this.question);

  factory OpenGroupQuestion.fromJson(Map<String, Object?> json) {
    final options = json['options'] as List? ?? const [];
    final hint = json['hint'] as String?;
    return OpenGroupQuestion(
      json['courseId'] as String? ?? '',
      GroupQuestion(
        meetingId: json['meetingId'] as String? ?? '',
        options: [
          for (final o in options)
            if (o is Map)
              GroupOption(
                group: o['group'] as String? ?? '',
                room: o['room'] as String?,
                type: o['type'] == null
                    ? null
                    : SessionType.fromKey(o['type'] as String?),
              ),
        ],
        suggested: json['suggested'] as String?,
        hint: GroupHint.values.where((h) => h.name == hint).firstOrNull,
      ),
    );
  }

  final String courseId;
  final GroupQuestion question;

  Map<String, Object?> toJson() => {
    'courseId': courseId,
    'meetingId': question.meetingId,
    'options': [
      for (final o in question.options)
        {'group': o.group, 'room': o.room, 'type': o.type?.key},
    ],
    'suggested': question.suggested,
    'hint': question.hint?.name,
  };
}

/// What the last look found, kept on this device for Settings and the
/// course pages.
class LinkerReport {
  const LinkerReport({
    this.at,
    this.written = 0,
    this.error,
    this.questions = const [],
    this.chooseFolder = const [],
    this.courses = const [],
  });

  factory LinkerReport.fromJson(Map<String, Object?> json) => LinkerReport(
    at: switch (json['at']) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    },
    written: json['written'] as int? ?? 0,
    error: json['error'] as String?,
    questions: [
      for (final q in json['questions'] as List? ?? const [])
        if (q is Map) OpenGroupQuestion.fromJson(q.cast()),
    ],
    chooseFolder: [
      for (final id in json['chooseFolder'] as List? ?? const [])
        if (id is String) id,
    ],
  );

  /// When the last look finished.
  final DateTime? at;

  /// Links it wrote.
  final int written;

  /// A [PanoptoException.code], or null when it went fine.
  final String? error;
  final List<OpenGroupQuestion> questions;

  /// Courses whose number found several folders: the user picks.
  final List<String> chooseFolder;

  /// What happened in each course, for Developer mode. Only from a look in
  /// this run of the app: never saved.
  final List<CourseLook> courses;

  Map<String, Object?> toJson() => {
    'at': at?.millisecondsSinceEpoch,
    'written': written,
    'error': error,
    'questions': [for (final q in questions) q.toJson()],
    'chooseFolder': chooseFolder,
  };
}

/// What Panopto has for one session ([RecordingLinker.check]).
class SessionCheck {
  const SessionCheck({
    this.found,
    this.question,
    this.outcome,
    this.sameDay = const [],
    this.noFolder = false,
  });

  /// The recording that fits the session, its own link left out.
  final PanoptoRecording? found;

  /// Several groups were recorded at its time and the meeting has none
  /// chosen: which one is the user's?
  final GroupQuestion? question;

  /// Why it has no [found] recording (or [SessionOutcome.found]).
  final SessionOutcome? outcome;

  /// The course's finished recordings on the session's date, by start, for
  /// picking one by hand.
  final List<RecordingDetail> sameDay;

  /// The course has no Panopto folder (none found by its number, or set to
  /// none).
  final bool noFolder;
}

/// Finds each session's Panopto recording and fills in its link, on this
/// device (the links reach the user's other devices through sync).
class RecordingLinker {
  RecordingLinker({
    required this.repo,
    required this.connection,
    required this.prefs,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ScheduleRepository repo;
  final PanoptoConnection connection;
  final SharedPreferencesWithCache prefs;
  final DateTime Function() _clock;

  /// Looks run by themselves at most this often.
  static const interval = Duration(hours: 3);

  /// Semesters that ended this long ago still get their links.
  static const afterSemester = Duration(days: 30);

  static const _reportKey = 'panopto.report';
  static const _startedKey = 'panopto.started';

  LinkerReport get report {
    final raw = prefs.getString(_reportKey);
    if (raw == null) return const LinkerReport();
    try {
      return LinkerReport.fromJson((jsonDecode(raw) as Map).cast());
    } on Object {
      return const LinkerReport();
    }
  }

  Future<void> clearReport() async {
    await prefs.remove(_reportKey);
    await prefs.remove(_startedKey);
  }

  /// Looks for recordings unless a look ran in the last [interval]
  /// ([force]: look anyway). [courseId]: only that course. Returns the
  /// report, or null when it didn't look (not connected, or too soon).
  Future<LinkerReport?> run({bool force = false, String? courseId}) async {
    if (await connection.status() != PanoptoStatus.connected) return null;
    // Android's daily task runs in another isolate with its own cache.
    await prefs.reloadCache();
    final now = _clock();
    // With the account's vault, the 3 hours count for every device.
    SharedLook? shared;
    try {
      shared = await connection.claimLook(force: force);
    } on PanoptoException catch (e) {
      // No answer: this device's own time decides, and the look shows why.
      DevLog.add('Panopto: the account\'s look not claimed ($e)');
    }
    if (shared != null && !shared.ok) return null;
    final started = prefs.getInt(_startedKey);
    if (shared == null &&
        !force &&
        started != null &&
        now.millisecondsSinceEpoch - started < interval.inMilliseconds) {
      return null;
    }
    // Before looking, so a second trigger meanwhile doesn't look again.
    await prefs.setInt(_startedKey, now.millisecondsSinceEpoch);

    final previous = report;
    var written = 0;
    final questions = <OpenGroupQuestion>[
      // A look at one course keeps the other courses' questions.
      if (courseId != null)
        for (final q in previous.questions)
          if (q.courseId != courseId) q,
    ];
    final chooseFolder = <String>[
      if (courseId != null)
        for (final id in previous.chooseFolder)
          if (id != courseId) id,
    ];
    String? error;
    final looks = <CourseLook>[];
    try {
      final api = await connection.api();
      if (api == null) return null;
      final today = LocalDate.today(now);
      final window = await repo.loadWindow(
        today.addDays(-afterSemester.inDays),
        today,
      );
      final folders = await repo.panoptoFolders();
      final groups = await repo.panoptoGroups();
      for (final data in window.semesters) {
        for (final course in data.courses) {
          if (courseId != null && course.id != courseId) continue;
          CourseLook skip(String why) => CourseLook(
            courseId: course.id,
            courseName: course.name,
            code: course.code,
            skipped: why,
          );
          final refs = await _foldersOf(api, course, data.semester, folders);
          if (refs == null) {
            final hasCode = course.code.trim().isNotEmpty;
            if (hasCode) chooseFolder.add(course.id);
            looks.add(
              skip(
                hasCode
                    ? 'no single folder found by the course number'
                    : 'no course number to find its folder by',
              ),
            );
            continue;
          }
          if (refs.isEmpty) {
            looks.add(skip('folder set to none'));
            continue;
          }
          final (recordings, folderErrors) = await _read(
            api,
            refs,
            data.semester,
          );
          final result = RecordingMatcher.match(
            recordings: recordings,
            sessions: window.index.forCourse(course.id),
            meetings: data.meetingsOf(course.id),
            groups: groups,
            now: now,
            courseCode: course.code,
          );
          for (final MapEntry(key: meetingId, value: group)
              in result.learnedGroups.entries) {
            await repo.setPanoptoGroup(meetingId, group);
            DevLog.add('Panopto: group $group learned from pasted links');
          }
          final wrote = await repo.setFoundRecordings(result.links);
          written += wrote;
          questions.addAll([
            for (final q in result.questions) OpenGroupQuestion(course.id, q),
          ]);
          looks.add(
            CourseLook(
              courseId: course.id,
              courseName: course.name,
              code: course.code,
              folders: refs,
              recordingsRead: recordings.length,
              error: folderErrors.isEmpty ? null : folderErrors.join('; '),
              details: result.details,
              written: wrote,
            ),
          );
        }
      }
    } on PanoptoException catch (e) {
      error = e.code;
      DevLog.add('Panopto look failed: $e');
      // A passing problem (no connection yet, Panopto busy) doesn't wait
      // 3 hours: the next start or return to the app looks again.
      if (e.isPassing) await _giveBack(shared);
    }
    final next = LinkerReport(
      at: _clock(),
      written: written,
      error: error,
      questions: questions,
      chooseFolder: chooseFolder,
      courses: looks,
    );
    await prefs.setString(_reportKey, jsonEncode(next.toJson()));
    DevLog.add(
      'Panopto: $written links, ${questions.length} questions'
      '${error == null ? '' : ', $error'}',
    );
    return next;
  }

  /// What Panopto has for one [session], asked from its session sheet
  /// ("Find in Panopto"). The session's own link (pasted or removed) is
  /// left out, so the answer can be compared with it. Writes nothing, and
  /// doesn't count as the account's look. Throws [PanoptoException].
  Future<SessionCheck> check(Occurrence session) async {
    final api = await connection.api();
    if (api == null) throw const PanoptoException('reconnect');
    final course = await _courseOf(session.courseId, near: session.date);
    if (course == null) return const SessionCheck(noFolder: true);
    final (:data, :sessions) = course;
    final info = data.course(session.courseId)!;
    final refs = await _foldersOf(
      api,
      info,
      data.semester,
      await repo.panoptoFolders(),
    );
    if (refs == null || refs.isEmpty) return const SessionCheck(noFolder: true);
    final (recordings, _) = await _read(api, refs, data.semester);
    final result = RecordingMatcher.match(
      recordings: recordings,
      sessions: [
        for (final s in sessions)
          if (s.id == session.id) withoutLink(s) else s,
      ],
      meetings: data.meetingsOf(info.id),
      groups: await repo.panoptoGroups(),
      now: _clock(),
      courseCode: info.code,
    );
    final found = result.links
        .where((f) => f.session.id == session.id)
        .firstOrNull;
    final outcome = result.details.sessions
        .where((d) => d.session.id == session.id)
        .firstOrNull
        ?.outcome;
    return SessionCheck(
      found: found?.recording,
      question: found != null
          ? null
          : result.questions
                .where((q) => q.meetingId == session.meetingId)
                .firstOrNull,
      outcome: found != null
          ? SessionOutcome.found
          : outcome ?? SessionOutcome.notOver,
      sameDay: [
        for (final r in result.details.recordings)
          if (r.start.date == session.date &&
              r.outcome != RecordingOutcome.otherCourse &&
              r.outcome != RecordingOutcome.processing)
            r,
      ]..sort((a, b) => a.start.minute.compareTo(b.start.minute)),
    );
  }

  /// The groups recorded at [meetingId]'s times, whatever group is chosen
  /// for it now: for changing it on the course page. Throws
  /// [PanoptoException].
  Future<List<GroupOption>> groupOptions(
    String courseId,
    String meetingId,
  ) async {
    final api = await connection.api();
    if (api == null) throw const PanoptoException('reconnect');
    final course = await _courseOf(courseId);
    if (course == null) return const [];
    final (:data, :sessions) = course;
    final info = data.course(courseId)!;
    final refs = await _foldersOf(
      api,
      info,
      data.semester,
      await repo.panoptoFolders(),
    );
    if (refs == null || refs.isEmpty) return const [];
    final (recordings, _) = await _read(api, refs, data.semester);
    final meetingSessions = [
      for (final s in sessions)
        // Every past session of the meeting, its own links left out, so
        // each one shows the groups recorded at its time.
        if (s.meetingId == meetingId) withoutLink(s),
    ];
    final result = RecordingMatcher.match(
      recordings: recordings,
      sessions: meetingSessions,
      meetings: data.meetingsOf(courseId),
      groups: const {},
      now: _clock(),
      courseCode: info.code,
    );
    final question = result.questions
        .where((q) => q.meetingId == meetingId)
        .firstOrNull;
    if (question != null) return question.options;
    // One group (or none named) at its times.
    final seen = <String, GroupOption>{};
    for (final f in result.links) {
      final r = f.recording;
      if (r.group == null) continue;
      seen[r.group!] = GroupOption(group: r.group!, room: r.room, type: r.type);
    }
    return seen.values.toList()..sort((a, b) => a.group.compareTo(b.group));
  }

  /// [s] as if it had no link: neither pasted, found, nor removed.
  static Occurrence withoutLink(Occurrence s) => Occurrence(
    id: s.id,
    meetingId: s.meetingId,
    courseId: s.courseId,
    type: s.type,
    originalDate: s.originalDate,
    date: s.date,
    startMin: s.startMin,
    endMin: s.endMin,
    location: s.location,
    status: s.status,
    explicitStatus: s.explicitStatus,
    noClassDay: s.noClassDay,
    isMoved: s.isMoved,
    isOneOff: s.isOneOff,
    number: s.number,
    notes: s.notes,
    recordingUrl: null,
    excluded: s.excluded,
  );

  /// The semester holding [courseId] (the one around [near] first, then the
  /// newest), with the course's sessions.
  Future<({SemesterData data, List<Occurrence> sessions})?> _courseOf(
    String courseId, {
    LocalDate? near,
  }) async {
    final semesters = [...await repo.semesters()]
      ..sort((a, b) => b.start.compareTo(a.start));
    final ordered = [
      if (near != null)
        for (final s in semesters)
          if (!near.isBefore(s.start) && !s.end.isBefore(near)) s,
      ...semesters,
    ];
    for (final semester in ordered) {
      final window = await repo.loadWindow(semester.start, semester.end);
      for (final data in window.semesters) {
        if (data.semester.id == semester.id && data.course(courseId) != null) {
          return (data: data, sessions: window.index.forCourse(courseId));
        }
      }
    }
    return null;
  }

  /// The course's folders: the saved ones, or found by its number (and
  /// saved). Null when there's no single folder to take.
  Future<List<PanoptoFolderRef>?> _foldersOf(
    PanoptoApi api,
    CourseInfo course,
    SemesterInfo semester,
    Map<String, List<PanoptoFolderRef>?> saved,
  ) async {
    final refs = saved[course.id];
    if (refs != null) return refs;
    final found = await _findFolders(api, course, semester);
    if (found != null) await repo.setPanoptoFolders(course.id, found);
    return found;
  }

  /// The folders' recordings since a week before the semester, and the
  /// problems of folders that couldn't be read.
  Future<(List<PanoptoRecording>, List<String>)> _read(
    PanoptoApi api,
    List<PanoptoFolderRef> refs,
    SemesterInfo semester,
  ) async {
    final recordings = <PanoptoRecording>[];
    final errors = <String>[];
    for (final folder in refs) {
      final (found, problem) = await _recordingsOf(
        api,
        folder,
        since: semester.start.addDays(-7),
      );
      recordings.addAll(found);
      if (problem != null) errors.add('${folder.name}: $problem');
    }
    return (recordings, errors);
  }

  /// Lets the next start look again: gives back the account's claim, or
  /// this device's time.
  Future<void> _giveBack(SharedLook? shared) async {
    await prefs.remove(_startedKey);
    try {
      await shared?.cancel();
    } on PanoptoException catch (e) {
      DevLog.add('Panopto: the account\'s look not given back ($e)');
    }
  }

  /// A folder that's gone or no longer visible gives no recordings (and
  /// its error code); other errors stop the look.
  Future<(List<PanoptoRecording>, String?)> _recordingsOf(
    PanoptoApi api,
    PanoptoFolderRef folder, {
    required LocalDate since,
  }) async {
    try {
      return (await api.folderRecordings(folder.id, since: since), null);
    } on PanoptoException catch (e) {
      if (e.code == 'not_found' || e.code == 'forbidden') {
        return (const <PanoptoRecording>[], e.code);
      }
      rethrow;
    }
  }

  /// The course's folders found by its number: the one folder whose name
  /// has it, or the one of the semester's academic year (`2026-27`). Null
  /// when there's no number, nothing, or several to choose from; `[]` is
  /// never returned, so "none" stays the user's choice.
  static Future<List<PanoptoFolderRef>?> _findFolders(
    PanoptoApi api,
    CourseInfo course,
    SemesterInfo semester,
  ) async {
    final code = course.code.trim();
    if (code.isEmpty) return null;
    final number = RegExp('(^|\\D)${RegExp.escape(code)}(\\D|\$)');
    final found = [
      for (final f in await api.searchFolders(code))
        if (number.hasMatch(f.name)) f,
    ];
    if (found.length == 1) return found;
    final year = academicYear(semester.start);
    final thisYear = [
      for (final f in found)
        if (f.name.contains(year)) f,
    ];
    return thisYear.length == 1 ? thisYear : null;
  }

  /// HUJI's folder prefix for the academic year a semester starting on
  /// [start] belongs to: `2026-27` from August 2026 to July 2027.
  static String academicYear(LocalDate start) {
    final first = start.month >= 8 ? start.year : start.year - 1;
    return '$first-${((first + 1) % 100).toString().padLeft(2, '0')}';
  }
}
