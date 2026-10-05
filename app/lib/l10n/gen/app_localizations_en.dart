// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LecCheck';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get remove => 'Remove';

  @override
  String get search => 'Search';

  @override
  String get optional => 'Optional';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get settings => 'Settings';

  @override
  String get navToday => 'Today';

  @override
  String get navWeek => 'Week';

  @override
  String get navCourses => 'Courses';

  @override
  String get navStats => 'Stats';

  @override
  String get typeLecture => 'Lecture';

  @override
  String get typePractice => 'Practice';

  @override
  String get typeLab => 'Lab';

  @override
  String get typeOther => 'Other';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusAttended => 'Attended';

  @override
  String get statusWatched => 'Watched recording';

  @override
  String get statusMissed => 'Missed';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusCanceled => 'Canceled';

  @override
  String get statusCanceledHoliday => 'No class';

  @override
  String get markAttended => 'Attended';

  @override
  String get markMissed => 'Missed';

  @override
  String get markWatched => 'Watched';

  @override
  String get markSkipped => 'Skipped';

  @override
  String get markCanceled => 'Canceled';

  @override
  String get clearStatus => 'Clear status';

  @override
  String markedAs(String status) {
    return 'Marked as $status';
  }

  @override
  String markedManyAs(int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions marked $status',
      one: '1 session marked $status',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'Welcome to LecCheck';

  @override
  String get welcomeSubtitle =>
      'Mark every lecture, practice and lab you attend, and see your semester at a glance.';

  @override
  String get continueAsGuest => 'Continue without an account';

  @override
  String get guestNote =>
      'Everything stays on this device. You can sign in later to sync.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInSoon => 'Sync arrives in an upcoming update.';

  @override
  String get semesterSetupTitle => 'Set up your semester';

  @override
  String get semesterSetupSubtitle =>
      'You can change all of this later in Settings.';

  @override
  String get semesterName => 'Semester name';

  @override
  String get semesterDefaultName => 'Semester A';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get weekStartsOn => 'Week starts on';

  @override
  String get visibleDays => 'Days shown in the week view';

  @override
  String semesterLength(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get dateRangeError => 'The end date must be after the start date.';

  @override
  String get createSemester => 'Create semester';

  @override
  String get addFirstCoursesTitle => 'Add your courses';

  @override
  String get addFirstCoursesSubtitle =>
      'Add each course with its weekly lectures, practices and labs.';

  @override
  String get finishSetup => 'Finish';

  @override
  String weekOfTotal(int week, int total) {
    return 'Week $week of $total';
  }

  @override
  String weekNumber(int week) {
    return 'Week $week';
  }

  @override
  String beforeSemester(String date) {
    return 'Semester starts $date';
  }

  @override
  String get afterSemester => 'Semester ended';

  @override
  String get nowLabel => 'Now';

  @override
  String get nextLabel => 'Next';

  @override
  String startsIn(String duration) {
    return 'Starts in $duration';
  }

  @override
  String endsIn(String duration) {
    return 'Ends in $duration';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get noClassesToday => 'No classes today';

  @override
  String get noUpcoming => 'Nothing scheduled ahead';

  @override
  String get needsMarking => 'Needs marking';

  @override
  String needsMarkingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'You\'re all caught up';

  @override
  String get allCaughtUpSubtitle => 'Every past session has a status.';

  @override
  String get markAllAttended => 'Mark all attended';

  @override
  String get todaySchedule => 'Today\'s schedule';

  @override
  String get comingUp => 'Coming up';

  @override
  String get allSessions => 'All sessions';

  @override
  String get swipeHint => 'Swipe right for attended, left for missed';

  @override
  String get openLink => 'Open link';

  @override
  String get noSemesterTitle => 'No semester yet';

  @override
  String get noSemesterBody => 'Create a semester to start tracking.';

  @override
  String get addCourseFirst => 'Add your courses to see your schedule here.';

  @override
  String get goToToday => 'Go to today';

  @override
  String get jumpToDate => 'Jump to date';

  @override
  String get dayOptions => 'Day options';

  @override
  String get markNoClassDay => 'No class this day';

  @override
  String get markNoClassDaySubtitle =>
      'Cancels every session on this day. You can undo it any time.';

  @override
  String get restoreDay => 'Restore classes';

  @override
  String get noClassReason => 'Reason (optional)';

  @override
  String get noClassReasonHint => 'Holiday, strike, exam day…';

  @override
  String get coursesTitle => 'Courses';

  @override
  String get addCourse => 'Add course';

  @override
  String get addOneTimeSession => 'Add one-time session';

  @override
  String get noCoursesYet => 'No courses yet';

  @override
  String get noCoursesSubtitle =>
      'Add your first course with its weekly meetings.';

  @override
  String nextSession(String when) {
    return 'Next: $when';
  }

  @override
  String get noUpcomingSessions => 'No upcoming sessions';

  @override
  String attendancePercent(int percent) {
    return '$percent% attended';
  }

  @override
  String canMissMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Can miss $count more',
      one: 'Can miss 1 more',
      zero: 'Can\'t miss any more',
    );
    return '$_temp0';
  }

  @override
  String get requirementAtRisk => 'Must attend all remaining';

  @override
  String get requirementFailed => 'Requirement can\'t be met';

  @override
  String get requirementMet => 'Requirement met';

  @override
  String get sessionsHistory => 'Sessions';

  @override
  String get courseNotes => 'Notes';

  @override
  String get courseLinks => 'Links';

  @override
  String get courseWebsite => 'Course website';

  @override
  String get lecturer => 'Lecturer';

  @override
  String get courseCode => 'Course code';

  @override
  String get newCourse => 'New course';

  @override
  String get editCourse => 'Edit course';

  @override
  String get courseName => 'Course name';

  @override
  String get courseNameRequired => 'Enter a course name';

  @override
  String get courseNotesHint => 'Reading list, exam rules, grading…';

  @override
  String get courseColor => 'Color';

  @override
  String get extraLinks => 'Links';

  @override
  String get addLink => 'Add link';

  @override
  String get linkTitle => 'Title';

  @override
  String get linkUrl => 'URL';

  @override
  String get meetingsSection => 'Weekly schedule';

  @override
  String get addMeeting => 'Add meeting';

  @override
  String get noMeetingsYet =>
      'Add the lectures, practices and labs of this course.';

  @override
  String get weekly => 'Weekly';

  @override
  String get oneTime => 'One-time';

  @override
  String get everyOtherWeek => 'Every other week';

  @override
  String get firstWeek => 'First week';

  @override
  String get secondWeek => 'Second week';

  @override
  String get weekday => 'Day';

  @override
  String get date => 'Date';

  @override
  String get startTime => 'Start';

  @override
  String get endTime => 'End';

  @override
  String get location => 'Room / location';

  @override
  String get endAfterStartError => 'End time must be after the start time';

  @override
  String get removeMeeting => 'Remove meeting';

  @override
  String get meetingLinks => 'Meeting links';

  @override
  String get requirementsSection => 'Attendance requirement';

  @override
  String get requirementsHint =>
      'Set a minimum attendance and LecCheck tells you how many sessions you can still miss.';

  @override
  String get addRequirement => 'Add requirement';

  @override
  String get minAttendance => 'Minimum attendance';

  @override
  String get appliesTo => 'Applies to';

  @override
  String get allTypes => 'All sessions';

  @override
  String get recordingsCount => 'Watched recordings count as attended';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesBody =>
      'Your edits to this course haven\'t been saved.';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get deleteCourseTitle => 'Delete this course?';

  @override
  String get deleteCourseBody =>
      'Its meetings and all marked sessions will be removed. You can undo right after.';

  @override
  String get courseDeleted => 'Course deleted';

  @override
  String get applyChangeTitle => 'Apply this change to';

  @override
  String get applyAllWeeks => 'All weeks';

  @override
  String get applyFromThisWeek => 'From this week on';

  @override
  String get sessionDetails => 'Session';

  @override
  String get status => 'Status';

  @override
  String get sessionNotes => 'Notes for this session';

  @override
  String get sessionNotesHint => 'Topics, homework, reminders…';

  @override
  String get recordingLink => 'Recording link';

  @override
  String get addRecordingLink => 'Add recording link';

  @override
  String get thisWeekOnly => 'This week only';

  @override
  String get moveSession => 'Change date, time or room';

  @override
  String get resetChanges => 'Undo changes for this week';

  @override
  String get movedLabel => 'Changed this week';

  @override
  String get canceledByHolidayHint => 'Canceled because of a no-class day';

  @override
  String get removeOneTime => 'Remove this one-time session';

  @override
  String get statsTitle => 'Stats';

  @override
  String get attendance => 'Attendance';

  @override
  String get attendanceSubtitle =>
      'Attended or watched, out of sessions you attended, watched or missed.';

  @override
  String get semesterProgress => 'Semester progress';

  @override
  String get streak => 'Streak';

  @override
  String streakValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String bestStreak(int count) {
    return 'Best: $count';
  }

  @override
  String get toMark => 'To mark';

  @override
  String get byCourse => 'By course';

  @override
  String get byType => 'By type';

  @override
  String get weeklyTrend => 'Weekly attendance';

  @override
  String get statusMix => 'Past sessions';

  @override
  String get catchUp => 'Catch up on recordings';

  @override
  String get catchUpEmpty => 'No missed sessions with a recording.';

  @override
  String get noDataYet => 'Mark a few sessions to see stats here.';

  @override
  String get requirementsOverview => 'Attendance requirements';

  @override
  String get account => 'Account';

  @override
  String get guestMode => 'Not signed in';

  @override
  String get guestModeSubtitle => 'Your data is stored only on this device.';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Mode';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get pureBlack => 'Pure black';

  @override
  String get pureBlackSubtitle => 'Darker dark mode for OLED screens';

  @override
  String get colorTheme => 'Color theme';

  @override
  String get presetWallpaper => 'Wallpaper';

  @override
  String get presetOcean => 'Ocean';

  @override
  String get presetSunset => 'Sunset';

  @override
  String get presetForest => 'Forest';

  @override
  String get presetGrape => 'Grape';

  @override
  String get presetRose => 'Rose';

  @override
  String get presetMono => 'Mono';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get time24h => '24-hour time';

  @override
  String get time24hSubtitle => 'Show 14:30 instead of 2:30 PM';

  @override
  String get meetingNumbers => 'Number sessions';

  @override
  String get meetingNumbersSubtitle => 'Show #1, #2… for each course and type';

  @override
  String get semesterSection => 'Semester';

  @override
  String get semesters => 'Semesters';

  @override
  String get addSemester => 'Add semester';

  @override
  String get editSemester => 'Edit semester';

  @override
  String get deleteSemesterTitle => 'Delete this semester?';

  @override
  String get deleteSemesterBody =>
      'All its courses and marked sessions will be removed. You can undo right after.';

  @override
  String get semesterDeleted => 'Semester deleted';

  @override
  String get activeSemester => 'Active';

  @override
  String get noClassDays => 'Holidays and no-class days';

  @override
  String get noClassDaysSubtitle => 'Sessions on these dates show as canceled.';

  @override
  String get addNoClassRange => 'Add dates';

  @override
  String get data => 'Data';

  @override
  String get exportData => 'Export backup';

  @override
  String get exportDataSubtitle => 'Save a JSON file with all semesters';

  @override
  String get importData => 'Import backup';

  @override
  String get importDataSubtitle =>
      'Restore a LecCheck backup (including files from the old app)';

  @override
  String get importReplaceTitle => 'Replace your data?';

  @override
  String get importReplaceBody =>
      'Imported semesters are added; semesters with the same ID are replaced.';

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count semesters',
      one: 'Imported 1 semester',
    );
    return '$_temp0';
  }

  @override
  String get importFailed => 'That file isn\'t a LecCheck backup.';

  @override
  String get exportDone => 'Backup saved';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get sourceCode => 'Source code';

  @override
  String get signInFailed =>
      'Couldn\'t sign in. Check your connection and try again.';

  @override
  String get devSignIn => 'Developer sign-in';

  @override
  String get restoringData => 'Restoring your data…';

  @override
  String syncSynced(String time) {
    return 'Synced $time';
  }

  @override
  String get justNow => 'just now';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncConnecting => 'Connecting…';

  @override
  String get syncOffline => 'Offline — changes will sync later';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get syncNotConfigured => 'Sync isn\'t set up in this build.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'Your data stays in your Google account; sign in again to get it back. Keep a copy on this device too?';

  @override
  String get keepData => 'Keep on this device';

  @override
  String get removeData => 'Remove from this device';

  @override
  String get signOutEverywhere => 'Sign out on all devices';

  @override
  String get deleteCloudData => 'Delete cloud data';

  @override
  String get deleteCloudTitle => 'Delete your cloud data?';

  @override
  String get deleteCloudBody =>
      'Your synced data will be removed from the server. This device keeps its copy.';

  @override
  String get replaceDataTitle => 'Switch accounts?';

  @override
  String get replaceDataBody =>
      'This device has data from another account. Signing in will replace it with this account\'s data.';

  @override
  String get replace => 'Replace';

  @override
  String get syncHint =>
      'Sign in to sync with your other devices. Free, and your data stays private to your account.';

  @override
  String get notifications => 'Notifications';

  @override
  String get beforeClass => 'Before class';

  @override
  String get beforeClassSubtitle => 'A reminder with the room and link';

  @override
  String get afterClass => 'After class: how was it?';

  @override
  String get afterClassSubtitle =>
      'Mark attendance right from the notification';

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get testNotification => 'Send a test notification';

  @override
  String get notificationsBlocked =>
      'Notifications are blocked. Allow them in system settings.';

  @override
  String notifyBeforeTitle(String course, String type, int minutes) {
    return '$course · $type in $minutes min';
  }

  @override
  String notifyAfterTitle(String course) {
    return 'How was $course?';
  }

  @override
  String get notifyTestTitle => 'LecCheck reminders are on';

  @override
  String get notifyTestBody =>
      'You\'ll get reminders like this before and after class.';

  @override
  String get channelBefore => 'Before class';

  @override
  String get channelAfter => 'After class';

  @override
  String get previousWeek => 'Previous week';

  @override
  String get nextWeek => 'Next week';

  @override
  String get rightClickHint => 'Right-click a session for more options';

  @override
  String get details => 'Details';

  @override
  String get goToCourse => 'Go to course';

  @override
  String get selectSessionHint => 'Select a session to see its details here';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get keyboardShortcutsSubtitle => 'Press F1 to see them anytime';

  @override
  String get shortcutTabs => 'Switch tabs';

  @override
  String get shortcutSearch => 'Search sessions';

  @override
  String get shortcutWeeks => 'Previous / next week';

  @override
  String get shortcutZoom => 'Zoom the week in / out / reset';

  @override
  String get shortcutMark =>
      'Mark the open session: attended, missed, watched, skipped, canceled';

  @override
  String get shortcutBack => 'Close / go back';

  @override
  String get shortcutHelp => 'Show this list';

  @override
  String get thisDevice => 'This device';

  @override
  String get addWidget => 'Add widget to home screen';

  @override
  String get addWidgetSubtitle => 'Today\'s sessions with one-tap marking';

  @override
  String get altStoreRefresh => 'Refresh in AltStore or SideStore every week';

  @override
  String get altStoreRefreshSubtitle =>
      'Apps installed with a free Apple ID stop opening after 7 days without a refresh.';

  @override
  String get notificationsOff => 'Notifications are off for LecCheck';

  @override
  String get notificationsOffSubtitle =>
      'Reminders can\'t appear until you allow them.';

  @override
  String get allow => 'Allow';

  @override
  String get remindersWhileOpen =>
      'On this computer, reminders appear while LecCheck is open.';

  @override
  String get presetAccent => 'System accent';
}
