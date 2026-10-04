import 'package:material_ui/material_ui.dart';

import 'lec_icon_font.dart';

/// Every icon the app uses, by meaning. Screens reference these names only.
/// Identity icons (navigation, session types, statuses, …) come from the custom
/// LecCheck font built from `design/icons/`; generic actions use Material.
abstract final class LecIcons {
  // Navigation
  static const today = LecIconFont.today;
  static const todayFilled = LecIconFont.todayFilled;
  static const week = LecIconFont.week;
  static const weekFilled = LecIconFont.weekFilled;
  static const courses = LecIconFont.courses;
  static const coursesFilled = LecIconFont.coursesFilled;
  static const stats = LecIconFont.stats;
  static const statsFilled = LecIconFont.statsFilled;
  static const settings = LecIconFont.settings;
  static const settingsFilled = LecIconFont.settingsFilled;

  // Session types
  static const lecture = LecIconFont.lecture;
  static const practice = LecIconFont.practice;
  static const lab = LecIconFont.lab;
  static const other = LecIconFont.other;

  // Statuses
  static const pending = LecIconFont.pending;
  static const attended = LecIconFont.attended;
  static const watched = LecIconFont.watched;
  static const missed = LecIconFont.missed;
  static const skipped = LecIconFont.skipped;
  static const canceled = LecIconFont.canceled;

  // Actions & objects
  static const add = Icons.add_rounded;
  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline_rounded;
  static const close = Icons.close_rounded;
  static const check = Icons.check_rounded;
  static const chevronStart = Icons.chevron_left_rounded;
  static const chevronEnd = Icons.chevron_right_rounded;
  static const expand = Icons.expand_more_rounded;
  static const link = Icons.link_rounded;
  static const openLink = Icons.open_in_new_rounded;
  static const recording = Icons.smart_display_outlined;
  static const location = Icons.place_outlined;
  static const time = Icons.schedule_rounded;
  static const date = Icons.event_outlined;
  static const notes = Icons.sticky_note_2_outlined;
  static const lecturer = Icons.person_outline_rounded;
  static const semester = Icons.date_range_rounded;
  static const holiday = LecIconFont.holiday;
  static const target = LecIconFont.target;
  static const streak = LecIconFont.streak;
  static const search = Icons.search_rounded;
  static const sync = Icons.cloud_done_outlined;
  static const syncOff = Icons.cloud_off_outlined;
  static const account = Icons.account_circle_outlined;
  static const palette = Icons.palette_outlined;
  static const language = Icons.translate_rounded;
  static const darkMode = Icons.dark_mode_outlined;
  static const exportData = Icons.upload_file_rounded;
  static const importData = Icons.download_rounded;
  static const info = Icons.info_outline_rounded;
  static const code = Icons.code_rounded;
  static const moved = LecIconFont.moved;
  static const undo = Icons.undo_rounded;
  static const more = Icons.more_horiz_rounded;
  static const doneAll = Icons.done_all_rounded;
  static const celebrate = Icons.celebration_outlined;
  static const numbers = Icons.tag_rounded;
  static const clock24 = Icons.av_timer_rounded;
}
