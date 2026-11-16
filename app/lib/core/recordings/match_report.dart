import '../../domain/local_date.dart';
import '../../domain/occurrence.dart';
import '../../domain/recording_match.dart';

/// One course of a look, kept for Developer mode's matching details.
class CourseLook {
  const CourseLook({
    required this.courseId,
    required this.courseName,
    required this.code,
    this.folders = const [],
    this.recordingsRead = 0,
    this.skipped,
    this.error,
    this.details = MatchDetails.empty,
    this.written = 0,
  });

  final String courseId;
  final String courseName;
  final String code;
  final List<PanoptoFolderRef> folders;
  final int recordingsRead;

  /// Why the course wasn't looked at: `no folder`, `no course number`,
  /// `several folders`, `folder: none`.
  final String? skipped;

  /// A Panopto error code for this course (`forbidden`, …).
  final String? error;
  final MatchDetails details;

  /// Links written by this look.
  final int written;

  /// Sessions up to now, by outcome.
  Map<SessionOutcome, int> get sessionCounts =>
      _count(details.sessions.map((s) => s.outcome));

  /// Recordings, by outcome.
  Map<RecordingOutcome, int> get recordingCounts =>
      _count(details.recordings.map((r) => r.outcome));

  static Map<T, int> _count<T>(Iterable<T> items) {
    final counts = <T, int>{};
    for (final i in items) {
      counts[i] = (counts[i] ?? 0) + 1;
    }
    return counts;
  }
}

/// Sessions that could have had a found link but didn't.
const missingOutcomes = {
  SessionOutcome.noRecording,
  SessionOutcome.processing,
  SessionOutcome.otherGroup,
  SessionOutcome.otherType,
  SessionOutcome.usedElsewhere,
  SessionOutcome.askGroup,
};

/// Recordings no session took, for a reason worth looking at.
const unusedOutcomes = {
  RecordingOutcome.noSession,
  RecordingOutcome.sessionClosed,
  RecordingOutcome.otherGroup,
  RecordingOutcome.otherType,
  RecordingOutcome.askGroup,
  RecordingOutcome.lostToAnother,
  RecordingOutcome.processing,
  RecordingOutcome.otherCourse,
};

String sessionOutcomeText(SessionOutcome o) => switch (o) {
  SessionOutcome.found => 'found',
  SessionOutcome.ownLink => 'your link',
  SessionOutcome.removed => 'link removed',
  SessionOutcome.canceled => 'canceled',
  SessionOutcome.notOver => 'not over',
  SessionOutcome.noRecording => 'nothing recorded at its time',
  SessionOutcome.processing => 'recording still processing',
  SessionOutcome.otherGroup => 'only other groups recorded',
  SessionOutcome.otherType => 'only another type recorded',
  SessionOutcome.usedElsewhere => 'its recording went to another session',
  SessionOutcome.askGroup => 'waiting for the group question',
};

String recordingOutcomeText(RecordingOutcome o) => switch (o) {
  RecordingOutcome.linked => 'linked',
  RecordingOutcome.inYourLink => 'in a link you pasted',
  RecordingOutcome.processing => 'still processing',
  RecordingOutcome.otherCourse => 'another course number',
  RecordingOutcome.noSession => 'no session at its time',
  RecordingOutcome.sessionClosed => 'its session takes no found link',
  RecordingOutcome.otherGroup => 'another group',
  RecordingOutcome.otherType => 'another type',
  RecordingOutcome.askGroup => 'waiting for the group question',
  RecordingOutcome.lostToAnother => 'another recording took its session',
};

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _hm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

String _day(LocalDate d) => '${_days[d.weekday - 1]} $d';

/// "Tue 2026-11-10 10:00 lecture @ קפלן".
String sessionLabel(Occurrence s) =>
    '${_day(s.date)} ${_hm(s.startMin)} ${s.type.key}'
    '${s.location.isEmpty ? '' : ' @ ${s.location}'}';

/// "Tue 2026-11-10 10:00 110 min "80430 2026-11-10 שעור א" (קפלן, שעור א)".
String recordingLabel(RecordingDetail d) {
  final r = d.recording;
  final extra = [
    ?r.room,
    if (r.type != null || r.group != null)
      [?r.type?.key, if (r.group != null) 'group ${r.group}'].join(' '),
  ];
  return '${_day(d.start.date)} ${_hm(d.start.minute)} '
      '${(r.durationSec / 60).round()} min "${r.name}"'
      '${extra.isEmpty ? '' : ' (${extra.join(', ')})'}';
}

/// Why [d] wasn't used, with the session it concerns.
String recordingReason(RecordingDetail d) {
  final text = recordingOutcomeText(d.outcome);
  final s = d.session;
  return switch (d.outcome) {
    RecordingOutcome.noSession when d.nearest != null =>
      '$text (closest: ${d.nearest!.type.key} ${_hm(d.nearest!.startMin)}, '
          '${(d.nearest!.startMin - d.start.minute).abs()} min away)',
    RecordingOutcome.noSession => '$text (no class that day)',
    RecordingOutcome.sessionClosed when s != null =>
      '$text: ${sessionLabel(s)} is '
          '${sessionOutcomeText(d.closedAs ?? SessionOutcome.ownLink)}',
    _ when s != null => '$text: ${sessionLabel(s)}',
    _ => text,
  };
}

/// The whole look as text, to copy into a bug report or a chat.
String lookReportText(List<CourseLook> courses, {DateTime? at}) {
  final out = StringBuffer('Panopto matching details');
  if (at != null) out.write(' ($at)');
  out.writeln();
  for (final c in courses) {
    out
      ..writeln()
      ..writeln('== ${c.code} ${c.courseName}');
    if (c.skipped != null) {
      out.writeln('Not looked at: ${c.skipped}');
      continue;
    }
    for (final f in c.folders) {
      out.writeln('Folder: ${f.name}');
    }
    if (c.error != null) out.writeln('Error: ${c.error}');
    final d = c.details;
    out.writeln(
      'Start times read as ${d.readUtc ? 'real UTC' : 'wall clock'} '
      '(fit sessions: wall clock ${d.fitWall}, UTC ${d.fitUtc}); '
      '${c.recordingsRead} recordings read, ${c.written} links written',
    );
    String counts<T extends Enum>(Map<T, int> m, String Function(T) name) =>
        [for (final e in m.entries) '${name(e.key)} ${e.value}'].join(', ');
    out
      ..writeln(
        'Sessions so far: ${d.sessions.length} '
        '(${counts(c.sessionCounts, sessionOutcomeText)})',
      )
      ..writeln(
        'Recordings: ${d.recordings.length} '
        '(${counts(c.recordingCounts, recordingOutcomeText)})',
      );
    final missing = [
      for (final s in d.sessions)
        if (missingOutcomes.contains(s.outcome)) s,
    ];
    if (missing.isNotEmpty) out.writeln('Sessions without a found link:');
    for (final s in missing) {
      out.writeln(
        '  ${sessionLabel(s.session)}: ${sessionOutcomeText(s.outcome)}',
      );
    }
    final unused = [
      for (final r in d.recordings)
        if (unusedOutcomes.contains(r.outcome)) r,
    ];
    if (unused.isNotEmpty) out.writeln('Recordings not used:');
    for (final r in unused) {
      out.writeln('  ${recordingLabel(r)}: ${recordingReason(r)}');
    }
  }
  return out.toString();
}
