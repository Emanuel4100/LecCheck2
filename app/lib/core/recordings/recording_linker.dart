import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/local_date.dart';
import '../../domain/recording_match.dart';
import '../../domain/schedule_types.dart';
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
    final started = prefs.getInt(_startedKey);
    if (!force &&
        started != null &&
        now.millisecondsSinceEpoch - started < interval.inMilliseconds) {
      return null;
    }
    // Before looking, so a second trigger meanwhile doesn't look again.
    await prefs.setInt(_startedKey, now.millisecondsSinceEpoch);
    final api = await connection.api();
    if (api == null) return null;

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
          var refs = folders[course.id];
          if (refs == null) {
            refs = await _findFolders(api, course, data.semester);
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
            await repo.setPanoptoFolders(course.id, refs);
          }
          if (refs.isEmpty) {
            looks.add(skip('folder set to none'));
            continue;
          }
          final recordings = <PanoptoRecording>[];
          final folderErrors = <String>[];
          for (final folder in refs) {
            final (found, problem) = await _recordingsOf(
              api,
              folder,
              since: data.semester.start.addDays(-7),
            );
            recordings.addAll(found);
            if (problem != null) folderErrors.add('${folder.name}: $problem');
          }
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
