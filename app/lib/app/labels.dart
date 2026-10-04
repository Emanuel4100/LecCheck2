import 'package:material_ui/material_ui.dart';

import '../core/icons/lec_icons.dart';
import '../domain/occurrence.dart';
import '../domain/schedule_types.dart';
import '../l10n/gen/app_localizations.dart';

extension SessionTypeLabels on SessionType {
  String label(AppLocalizations l) => switch (this) {
    SessionType.lecture => l.typeLecture,
    SessionType.practice => l.typePractice,
    SessionType.lab => l.typeLab,
    SessionType.other => l.typeOther,
  };

  IconData get icon => switch (this) {
    SessionType.lecture => LecIcons.lecture,
    SessionType.practice => LecIcons.practice,
    SessionType.lab => LecIcons.lab,
    SessionType.other => LecIcons.other,
  };
}

extension StatusLabels on AttendanceStatus {
  String label(AppLocalizations l) => switch (this) {
    AttendanceStatus.pending => l.statusPending,
    AttendanceStatus.attended => l.statusAttended,
    AttendanceStatus.watched => l.statusWatched,
    AttendanceStatus.missed => l.statusMissed,
    AttendanceStatus.skipped => l.statusSkipped,
    AttendanceStatus.canceled => l.statusCanceled,
  };

  /// Short verb-like label for buttons.
  String action(AppLocalizations l) => switch (this) {
    AttendanceStatus.pending => l.clearStatus,
    AttendanceStatus.attended => l.markAttended,
    AttendanceStatus.watched => l.markWatched,
    AttendanceStatus.missed => l.markMissed,
    AttendanceStatus.skipped => l.markSkipped,
    AttendanceStatus.canceled => l.markCanceled,
  };

  IconData get icon => switch (this) {
    AttendanceStatus.pending => LecIcons.pending,
    AttendanceStatus.attended => LecIcons.attended,
    AttendanceStatus.watched => LecIcons.watched,
    AttendanceStatus.missed => LecIcons.missed,
    AttendanceStatus.skipped => LecIcons.skipped,
    AttendanceStatus.canceled => LecIcons.canceled,
  };
}

/// Joins detail parts ("Lecture #3 · 10:00–12:00 · Room 7") so separators
/// stay attached to the preceding part and short parts never split.
String joinDetails(Iterable<String> parts) => parts
    .where((p) => p.isNotEmpty)
    .map((p) => p.length <= 16 ? p.replaceAll(' ', '\u00A0') : p)
    .join('\u00A0· ');

/// "Lecture #3" / "Practice".
String sessionTitle(Occurrence o, AppLocalizations l, {required bool numbers}) {
  final type = o.type.label(l);
  return numbers && o.number != null ? '$type #${o.number}' : type;
}

/// Status label that distinguishes holiday cancellations.
String statusLabel(Occurrence o, AppLocalizations l) =>
    o.canceledByNoClassDay ? l.statusCanceledHoliday : o.status.label(l);
