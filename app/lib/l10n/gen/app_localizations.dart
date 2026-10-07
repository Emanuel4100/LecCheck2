import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LecCheck'**
  String get appTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get navWeek;

  /// No description provided for @navCourses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get navCourses;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @typeLecture.
  ///
  /// In en, this message translates to:
  /// **'Lecture'**
  String get typeLecture;

  /// No description provided for @typePractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get typePractice;

  /// No description provided for @typeLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get typeLab;

  /// No description provided for @typeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get typeOther;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get statusAttended;

  /// No description provided for @statusWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched recording'**
  String get statusWatched;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get statusCanceled;

  /// No description provided for @statusCanceledHoliday.
  ///
  /// In en, this message translates to:
  /// **'No class'**
  String get statusCanceledHoliday;

  /// No description provided for @markAttended.
  ///
  /// In en, this message translates to:
  /// **'Attended'**
  String get markAttended;

  /// No description provided for @markMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get markMissed;

  /// No description provided for @markWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get markWatched;

  /// No description provided for @markSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get markSkipped;

  /// No description provided for @markCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get markCanceled;

  /// No description provided for @clearStatus.
  ///
  /// In en, this message translates to:
  /// **'Clear status'**
  String get clearStatus;

  /// No description provided for @markedAs.
  ///
  /// In en, this message translates to:
  /// **'Marked as {status}'**
  String markedAs(String status);

  /// No description provided for @markedManyAs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session marked {status}} other{{count} sessions marked {status}}}'**
  String markedManyAs(int count, String status);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to LecCheck'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark every lecture, practice and lab you attend, and see your semester at a glance.'**
  String get welcomeSubtitle;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue without an account'**
  String get continueAsGuest;

  /// No description provided for @guestNote.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this device. You can sign in later to sync.'**
  String get guestNote;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInSoon.
  ///
  /// In en, this message translates to:
  /// **'Sync arrives in an upcoming update.'**
  String get signInSoon;

  /// No description provided for @semesterSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your semester'**
  String get semesterSetupTitle;

  /// No description provided for @semesterSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change all of this later in Settings.'**
  String get semesterSetupSubtitle;

  /// No description provided for @semesterName.
  ///
  /// In en, this message translates to:
  /// **'Semester name'**
  String get semesterName;

  /// No description provided for @semesterDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Semester A'**
  String get semesterDefaultName;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// No description provided for @weekStartsOn.
  ///
  /// In en, this message translates to:
  /// **'Week starts on'**
  String get weekStartsOn;

  /// No description provided for @visibleDays.
  ///
  /// In en, this message translates to:
  /// **'Days shown in the week view'**
  String get visibleDays;

  /// No description provided for @semesterLength.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =1{1 week} other{{weeks} weeks}}'**
  String semesterLength(int weeks);

  /// No description provided for @dateRangeError.
  ///
  /// In en, this message translates to:
  /// **'The end date must be after the start date.'**
  String get dateRangeError;

  /// No description provided for @createSemester.
  ///
  /// In en, this message translates to:
  /// **'Create semester'**
  String get createSemester;

  /// No description provided for @addFirstCoursesTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your courses'**
  String get addFirstCoursesTitle;

  /// No description provided for @addFirstCoursesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add each course with its weekly lectures, practices and labs.'**
  String get addFirstCoursesSubtitle;

  /// No description provided for @finishSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishSetup;

  /// No description provided for @weekOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Week {week} of {total}'**
  String weekOfTotal(int week, int total);

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String weekNumber(int week);

  /// No description provided for @beforeSemester.
  ///
  /// In en, this message translates to:
  /// **'Semester starts {date}'**
  String beforeSemester(String date);

  /// No description provided for @afterSemester.
  ///
  /// In en, this message translates to:
  /// **'Semester ended'**
  String get afterSemester;

  /// No description provided for @nowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nowLabel;

  /// No description provided for @nextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextLabel;

  /// No description provided for @startsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {duration}'**
  String startsIn(String duration);

  /// No description provided for @endsIn.
  ///
  /// In en, this message translates to:
  /// **'Ends in {duration}'**
  String endsIn(String duration);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @noClassesToday.
  ///
  /// In en, this message translates to:
  /// **'No classes today'**
  String get noClassesToday;

  /// No description provided for @noUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled ahead'**
  String get noUpcoming;

  /// No description provided for @needsMarking.
  ///
  /// In en, this message translates to:
  /// **'Needs marking'**
  String get needsMarking;

  /// No description provided for @needsMarkingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String needsMarkingCount(int count);

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get allCaughtUp;

  /// No description provided for @allCaughtUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every past session has a status.'**
  String get allCaughtUpSubtitle;

  /// No description provided for @markAllAttended.
  ///
  /// In en, this message translates to:
  /// **'Mark all attended'**
  String get markAllAttended;

  /// No description provided for @todaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get todaySchedule;

  /// No description provided for @comingUp.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get comingUp;

  /// No description provided for @allSessions.
  ///
  /// In en, this message translates to:
  /// **'All sessions'**
  String get allSessions;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe right for attended, left for missed'**
  String get swipeHint;

  /// No description provided for @openLink.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get openLink;

  /// No description provided for @noSemesterTitle.
  ///
  /// In en, this message translates to:
  /// **'No semester yet'**
  String get noSemesterTitle;

  /// No description provided for @noSemesterBody.
  ///
  /// In en, this message translates to:
  /// **'Create a semester to start tracking.'**
  String get noSemesterBody;

  /// No description provided for @addCourseFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your courses to see your schedule here.'**
  String get addCourseFirst;

  /// No description provided for @goToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to today'**
  String get goToToday;

  /// No description provided for @jumpToDate.
  ///
  /// In en, this message translates to:
  /// **'Jump to date'**
  String get jumpToDate;

  /// No description provided for @dayOptions.
  ///
  /// In en, this message translates to:
  /// **'Day options'**
  String get dayOptions;

  /// No description provided for @markNoClassDay.
  ///
  /// In en, this message translates to:
  /// **'No class this day'**
  String get markNoClassDay;

  /// No description provided for @markNoClassDaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cancels every session on this day. You can undo it any time.'**
  String get markNoClassDaySubtitle;

  /// No description provided for @restoreDay.
  ///
  /// In en, this message translates to:
  /// **'Restore classes'**
  String get restoreDay;

  /// No description provided for @noClassReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get noClassReason;

  /// No description provided for @noClassReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Holiday, strike, exam day…'**
  String get noClassReasonHint;

  /// No description provided for @coursesTitle.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get coursesTitle;

  /// No description provided for @addCourse.
  ///
  /// In en, this message translates to:
  /// **'Add course'**
  String get addCourse;

  /// No description provided for @addOneTimeSession.
  ///
  /// In en, this message translates to:
  /// **'Add one-time session'**
  String get addOneTimeSession;

  /// No description provided for @noCoursesYet.
  ///
  /// In en, this message translates to:
  /// **'No courses yet'**
  String get noCoursesYet;

  /// No description provided for @noCoursesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first course with its weekly meetings.'**
  String get noCoursesSubtitle;

  /// No description provided for @nextSession.
  ///
  /// In en, this message translates to:
  /// **'Next: {when}'**
  String nextSession(String when);

  /// No description provided for @noUpcomingSessions.
  ///
  /// In en, this message translates to:
  /// **'No upcoming sessions'**
  String get noUpcomingSessions;

  /// No description provided for @attendancePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% attended'**
  String attendancePercent(int percent);

  /// No description provided for @canMissMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Can\'t miss any more} =1{Can miss 1 more} other{Can miss {count} more}}'**
  String canMissMore(int count);

  /// No description provided for @requirementAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Must attend all remaining'**
  String get requirementAtRisk;

  /// No description provided for @requirementFailed.
  ///
  /// In en, this message translates to:
  /// **'Requirement can\'t be met'**
  String get requirementFailed;

  /// No description provided for @requirementMet.
  ///
  /// In en, this message translates to:
  /// **'Requirement met'**
  String get requirementMet;

  /// No description provided for @sessionsHistory.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsHistory;

  /// No description provided for @courseNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get courseNotes;

  /// No description provided for @courseLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get courseLinks;

  /// No description provided for @courseWebsite.
  ///
  /// In en, this message translates to:
  /// **'Course website'**
  String get courseWebsite;

  /// No description provided for @lecturer.
  ///
  /// In en, this message translates to:
  /// **'Lecturer'**
  String get lecturer;

  /// No description provided for @courseCode.
  ///
  /// In en, this message translates to:
  /// **'Course code'**
  String get courseCode;

  /// No description provided for @newCourse.
  ///
  /// In en, this message translates to:
  /// **'New course'**
  String get newCourse;

  /// No description provided for @editCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit course'**
  String get editCourse;

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseName;

  /// No description provided for @shortName.
  ///
  /// In en, this message translates to:
  /// **'Short name'**
  String get shortName;

  /// No description provided for @shortNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown in the week view when the full name doesn\'t fit'**
  String get shortNameHelper;

  /// No description provided for @courseNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a course name'**
  String get courseNameRequired;

  /// No description provided for @courseNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Reading list, exam rules, grading…'**
  String get courseNotesHint;

  /// No description provided for @courseColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get courseColor;

  /// No description provided for @extraLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get extraLinks;

  /// No description provided for @addLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get addLink;

  /// No description provided for @linkTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get linkTitle;

  /// No description provided for @linkUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get linkUrl;

  /// No description provided for @meetingsSection.
  ///
  /// In en, this message translates to:
  /// **'Weekly schedule'**
  String get meetingsSection;

  /// No description provided for @addMeeting.
  ///
  /// In en, this message translates to:
  /// **'Add meeting'**
  String get addMeeting;

  /// No description provided for @noMeetingsYet.
  ///
  /// In en, this message translates to:
  /// **'Add the lectures, practices and labs of this course.'**
  String get noMeetingsYet;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @oneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get oneTime;

  /// No description provided for @everyOtherWeek.
  ///
  /// In en, this message translates to:
  /// **'Every other week'**
  String get everyOtherWeek;

  /// No description provided for @firstWeek.
  ///
  /// In en, this message translates to:
  /// **'First week'**
  String get firstWeek;

  /// No description provided for @secondWeek.
  ///
  /// In en, this message translates to:
  /// **'Second week'**
  String get secondWeek;

  /// No description provided for @weekday.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get weekday;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endTime;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Room / location'**
  String get location;

  /// No description provided for @endAfterStartError.
  ///
  /// In en, this message translates to:
  /// **'End time must be after the start time'**
  String get endAfterStartError;

  /// No description provided for @removeMeeting.
  ///
  /// In en, this message translates to:
  /// **'Remove meeting'**
  String get removeMeeting;

  /// No description provided for @meetingLinks.
  ///
  /// In en, this message translates to:
  /// **'Meeting links'**
  String get meetingLinks;

  /// No description provided for @requirementsSection.
  ///
  /// In en, this message translates to:
  /// **'Attendance requirement'**
  String get requirementsSection;

  /// No description provided for @requirementsHint.
  ///
  /// In en, this message translates to:
  /// **'Set a minimum attendance and LecCheck tells you how many sessions you can still miss.'**
  String get requirementsHint;

  /// No description provided for @addRequirement.
  ///
  /// In en, this message translates to:
  /// **'Add requirement'**
  String get addRequirement;

  /// No description provided for @minAttendance.
  ///
  /// In en, this message translates to:
  /// **'Minimum attendance'**
  String get minAttendance;

  /// No description provided for @appliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get appliesTo;

  /// No description provided for @allTypes.
  ///
  /// In en, this message translates to:
  /// **'All sessions'**
  String get allTypes;

  /// No description provided for @recordingsCount.
  ///
  /// In en, this message translates to:
  /// **'Watched recordings count as attended'**
  String get recordingsCount;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits to this course haven\'t been saved.'**
  String get discardChangesBody;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @deleteCourseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this course?'**
  String get deleteCourseTitle;

  /// No description provided for @deleteCourseBody.
  ///
  /// In en, this message translates to:
  /// **'Its meetings and all marked sessions will be removed. You can undo right after.'**
  String get deleteCourseBody;

  /// No description provided for @courseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Course deleted'**
  String get courseDeleted;

  /// No description provided for @applyChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply this change to'**
  String get applyChangeTitle;

  /// No description provided for @applyAllWeeks.
  ///
  /// In en, this message translates to:
  /// **'All weeks'**
  String get applyAllWeeks;

  /// No description provided for @applyFromThisWeek.
  ///
  /// In en, this message translates to:
  /// **'From this week on'**
  String get applyFromThisWeek;

  /// No description provided for @sessionDetails.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionDetails;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @sessionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes for this session'**
  String get sessionNotes;

  /// No description provided for @sessionNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Topics, homework, reminders…'**
  String get sessionNotesHint;

  /// No description provided for @recordingLink.
  ///
  /// In en, this message translates to:
  /// **'Recording link'**
  String get recordingLink;

  /// No description provided for @addRecordingLink.
  ///
  /// In en, this message translates to:
  /// **'Add recording link'**
  String get addRecordingLink;

  /// No description provided for @thisWeekOnly.
  ///
  /// In en, this message translates to:
  /// **'This week only'**
  String get thisWeekOnly;

  /// No description provided for @moveSession.
  ///
  /// In en, this message translates to:
  /// **'Change date, time or room'**
  String get moveSession;

  /// No description provided for @resetChanges.
  ///
  /// In en, this message translates to:
  /// **'Undo changes for this week'**
  String get resetChanges;

  /// No description provided for @movedLabel.
  ///
  /// In en, this message translates to:
  /// **'Changed this week'**
  String get movedLabel;

  /// No description provided for @canceledByHolidayHint.
  ///
  /// In en, this message translates to:
  /// **'Canceled because of a no-class day'**
  String get canceledByHolidayHint;

  /// No description provided for @removeOneTime.
  ///
  /// In en, this message translates to:
  /// **'Remove this one-time session'**
  String get removeOneTime;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @attendanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attended or watched, out of sessions you attended, watched or missed.'**
  String get attendanceSubtitle;

  /// No description provided for @semesterProgress.
  ///
  /// In en, this message translates to:
  /// **'Semester progress'**
  String get semesterProgress;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @streakValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String streakValue(int count);

  /// No description provided for @bestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {count}'**
  String bestStreak(int count);

  /// No description provided for @toMark.
  ///
  /// In en, this message translates to:
  /// **'To mark'**
  String get toMark;

  /// No description provided for @byCourse.
  ///
  /// In en, this message translates to:
  /// **'By course'**
  String get byCourse;

  /// No description provided for @byType.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get byType;

  /// No description provided for @weeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly attendance'**
  String get weeklyTrend;

  /// No description provided for @statusMix.
  ///
  /// In en, this message translates to:
  /// **'Past sessions'**
  String get statusMix;

  /// No description provided for @catchUp.
  ///
  /// In en, this message translates to:
  /// **'Catch up on recordings'**
  String get catchUp;

  /// No description provided for @catchUpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No missed sessions with a recording.'**
  String get catchUpEmpty;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'Mark a few sessions to see stats here.'**
  String get noDataYet;

  /// No description provided for @requirementsOverview.
  ///
  /// In en, this message translates to:
  /// **'Attendance requirements'**
  String get requirementsOverview;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get guestMode;

  /// No description provided for @guestModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored only on this device.'**
  String get guestModeSubtitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @pureBlack.
  ///
  /// In en, this message translates to:
  /// **'Pure black'**
  String get pureBlack;

  /// No description provided for @pureBlackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Darker dark mode for OLED screens'**
  String get pureBlackSubtitle;

  /// No description provided for @colorTheme.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get colorTheme;

  /// No description provided for @presetWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper'**
  String get presetWallpaper;

  /// No description provided for @presetOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get presetOcean;

  /// No description provided for @presetSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get presetSunset;

  /// No description provided for @presetForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get presetForest;

  /// No description provided for @presetGrape.
  ///
  /// In en, this message translates to:
  /// **'Grape'**
  String get presetGrape;

  /// No description provided for @presetRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get presetRose;

  /// No description provided for @presetMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get presetMono;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @time24h.
  ///
  /// In en, this message translates to:
  /// **'24-hour time'**
  String get time24h;

  /// No description provided for @time24hSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show 14:30 instead of 2:30 PM'**
  String get time24hSubtitle;

  /// No description provided for @meetingNumbers.
  ///
  /// In en, this message translates to:
  /// **'Number sessions'**
  String get meetingNumbers;

  /// No description provided for @meetingNumbersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show #1, #2… for each course and type'**
  String get meetingNumbersSubtitle;

  /// No description provided for @semesterSection.
  ///
  /// In en, this message translates to:
  /// **'Semester'**
  String get semesterSection;

  /// No description provided for @semesters.
  ///
  /// In en, this message translates to:
  /// **'Semesters'**
  String get semesters;

  /// No description provided for @addSemester.
  ///
  /// In en, this message translates to:
  /// **'Add semester'**
  String get addSemester;

  /// No description provided for @editSemester.
  ///
  /// In en, this message translates to:
  /// **'Edit semester'**
  String get editSemester;

  /// No description provided for @deleteSemesterTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this semester?'**
  String get deleteSemesterTitle;

  /// No description provided for @deleteSemesterBody.
  ///
  /// In en, this message translates to:
  /// **'All its courses and marked sessions will be removed. You can undo right after.'**
  String get deleteSemesterBody;

  /// No description provided for @semesterDeleted.
  ///
  /// In en, this message translates to:
  /// **'Semester deleted'**
  String get semesterDeleted;

  /// No description provided for @activeSemester.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeSemester;

  /// No description provided for @noClassDays.
  ///
  /// In en, this message translates to:
  /// **'Holidays and no-class days'**
  String get noClassDays;

  /// No description provided for @noClassDaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions on these dates show as canceled.'**
  String get noClassDaysSubtitle;

  /// No description provided for @addNoClassRange.
  ///
  /// In en, this message translates to:
  /// **'Add dates'**
  String get addNoClassRange;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportData;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a JSON file with all semesters'**
  String get exportDataSubtitle;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get importData;

  /// No description provided for @importDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore a LecCheck backup (including files from the old app)'**
  String get importDataSubtitle;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 semester} other{Imported {count} semesters}}'**
  String importDone(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a LecCheck backup.'**
  String get importFailed;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get exportDone;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get sourceCode;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @licenseSummary.
  ///
  /// In en, this message translates to:
  /// **'Free software under the GNU GPL v3 or later, with no warranty.'**
  String get licenseSummary;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @developerTools.
  ///
  /// In en, this message translates to:
  /// **'Developer tools'**
  String get developerTools;

  /// No description provided for @developerToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Test notifications, sync, backups and the widget on this device'**
  String get developerToolsSubtitle;

  /// No description provided for @devModeSteps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more tap to turn on developer mode} other{{count} more taps to turn on developer mode}}'**
  String devModeSteps(int count);

  /// No description provided for @devModeOn.
  ///
  /// In en, this message translates to:
  /// **'Developer mode is on'**
  String get devModeOn;

  /// No description provided for @devModeAlreadyOn.
  ///
  /// In en, this message translates to:
  /// **'Developer mode is already on'**
  String get devModeAlreadyOn;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Check your connection and try again.'**
  String get signInFailed;

  /// No description provided for @devSignIn.
  ///
  /// In en, this message translates to:
  /// **'Developer sign-in'**
  String get devSignIn;

  /// No description provided for @restoringData.
  ///
  /// In en, this message translates to:
  /// **'Restoring your data…'**
  String get restoringData;

  /// No description provided for @syncSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced {time}'**
  String syncSynced(String time);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncSyncing;

  /// No description provided for @syncConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get syncConnecting;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline — changes will sync later'**
  String get syncOffline;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String syncPending(int count);

  /// No description provided for @syncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sync isn\'t set up in this build.'**
  String get syncNotConfigured;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays in your Google account; sign in again to get it back. Keep a copy on this device too?'**
  String get signOutBody;

  /// No description provided for @keepData.
  ///
  /// In en, this message translates to:
  /// **'Keep on this device'**
  String get keepData;

  /// No description provided for @removeData.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get removeData;

  /// No description provided for @signOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out on all devices'**
  String get signOutEverywhere;

  /// No description provided for @deleteCloudData.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud data'**
  String get deleteCloudData;

  /// No description provided for @deleteCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your cloud data?'**
  String get deleteCloudTitle;

  /// No description provided for @deleteCloudBody.
  ///
  /// In en, this message translates to:
  /// **'Your synced data will be removed from the server, and your devices will be signed out. This device keeps its copy.'**
  String get deleteCloudBody;

  /// No description provided for @replaceDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch accounts?'**
  String get replaceDataTitle;

  /// No description provided for @replaceDataBody.
  ///
  /// In en, this message translates to:
  /// **'This device has data from another account. Signing in will replace it with this account\'s data.'**
  String get replaceDataBody;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @syncHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync with your other devices. Free, and your data stays private to your account.'**
  String get syncHint;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @beforeClass.
  ///
  /// In en, this message translates to:
  /// **'Before class'**
  String get beforeClass;

  /// No description provided for @beforeClassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A reminder with the room and link'**
  String get beforeClassSubtitle;

  /// No description provided for @afterClass.
  ///
  /// In en, this message translates to:
  /// **'After class: how was it?'**
  String get afterClass;

  /// No description provided for @afterClassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark attendance right from the notification'**
  String get afterClassSubtitle;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get testNotification;

  /// No description provided for @notificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t show the notification: {error}'**
  String notificationFailed(String error);

  /// No description provided for @notificationsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Allow them in system settings.'**
  String get notificationsBlocked;

  /// No description provided for @notifyBeforeTitle.
  ///
  /// In en, this message translates to:
  /// **'{course} · {type} in {minutes} min'**
  String notifyBeforeTitle(String course, String type, int minutes);

  /// No description provided for @notifyAfterTitle.
  ///
  /// In en, this message translates to:
  /// **'How was {course}?'**
  String notifyAfterTitle(String course);

  /// No description provided for @notifyTestTitle.
  ///
  /// In en, this message translates to:
  /// **'LecCheck reminders are on'**
  String get notifyTestTitle;

  /// No description provided for @notifyTestBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get reminders like this before and after class.'**
  String get notifyTestBody;

  /// No description provided for @channelBefore.
  ///
  /// In en, this message translates to:
  /// **'Before class'**
  String get channelBefore;

  /// No description provided for @channelAfter.
  ///
  /// In en, this message translates to:
  /// **'After class'**
  String get channelAfter;

  /// No description provided for @previousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get previousWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// No description provided for @rightClickHint.
  ///
  /// In en, this message translates to:
  /// **'Right-click a session for more options'**
  String get rightClickHint;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @goToCourse.
  ///
  /// In en, this message translates to:
  /// **'Go to course'**
  String get goToCourse;

  /// No description provided for @selectSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Select a session to see its details here'**
  String get selectSessionHint;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @keyboardShortcutsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Press F1 to see them anytime'**
  String get keyboardShortcutsSubtitle;

  /// No description provided for @shortcutTabs.
  ///
  /// In en, this message translates to:
  /// **'Switch tabs'**
  String get shortcutTabs;

  /// No description provided for @shortcutSearch.
  ///
  /// In en, this message translates to:
  /// **'Search sessions'**
  String get shortcutSearch;

  /// No description provided for @shortcutWeeks.
  ///
  /// In en, this message translates to:
  /// **'Previous / next week'**
  String get shortcutWeeks;

  /// No description provided for @shortcutZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom the week in / out / reset'**
  String get shortcutZoom;

  /// No description provided for @shortcutMark.
  ///
  /// In en, this message translates to:
  /// **'Mark the open session: attended, missed, watched, skipped, canceled'**
  String get shortcutMark;

  /// No description provided for @shortcutBack.
  ///
  /// In en, this message translates to:
  /// **'Close / go back'**
  String get shortcutBack;

  /// No description provided for @shortcutHelp.
  ///
  /// In en, this message translates to:
  /// **'Show this list'**
  String get shortcutHelp;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @addWidget.
  ///
  /// In en, this message translates to:
  /// **'Add widget to home screen'**
  String get addWidget;

  /// No description provided for @addWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sessions with one-tap marking'**
  String get addWidgetSubtitle;

  /// No description provided for @altStoreRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh in AltStore or SideStore every week'**
  String get altStoreRefresh;

  /// No description provided for @altStoreRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apps installed with a free Apple ID stop opening after 7 days without a refresh.'**
  String get altStoreRefreshSubtitle;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for LecCheck'**
  String get notificationsOff;

  /// No description provided for @notificationsOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders can\'t appear until you allow them.'**
  String get notificationsOffSubtitle;

  /// No description provided for @allow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// No description provided for @remindersWhileOpen.
  ///
  /// In en, this message translates to:
  /// **'On this computer, reminders appear while LecCheck is open.'**
  String get remindersWhileOpen;

  /// No description provided for @presetAccent.
  ///
  /// In en, this message translates to:
  /// **'System accent'**
  String get presetAccent;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import this backup?'**
  String get importTitle;

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'This backup has {semesters} semesters: {added} new items and {changed} that differ from yours.\n\n“Add missing” only adds what you don\'t have. “Replace” overwrites your versions on all your devices; an automatic backup is saved first.'**
  String importPreview(int semesters, int added, int changed);

  /// No description provided for @importMerge.
  ///
  /// In en, this message translates to:
  /// **'Add missing'**
  String get importMerge;

  /// No description provided for @importNothing.
  ///
  /// In en, this message translates to:
  /// **'Everything in this backup is already here.'**
  String get importNothing;

  /// No description provided for @snapshots.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get snapshots;

  /// No description provided for @snapshotsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved daily and before imports or sign-out. Go back to an earlier state.'**
  String get snapshotsSubtitle;

  /// No description provided for @snapshotsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No automatic backups yet.'**
  String get snapshotsEmpty;

  /// No description provided for @snapshotDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get snapshotDaily;

  /// No description provided for @snapshotImport.
  ///
  /// In en, this message translates to:
  /// **'Before import'**
  String get snapshotImport;

  /// No description provided for @snapshotRestore.
  ///
  /// In en, this message translates to:
  /// **'Before restore'**
  String get snapshotRestore;

  /// No description provided for @snapshotSignOut.
  ///
  /// In en, this message translates to:
  /// **'Before sign-out'**
  String get snapshotSignOut;

  /// No description provided for @snapshotSwitch.
  ///
  /// In en, this message translates to:
  /// **'Before switching accounts'**
  String get snapshotSwitch;

  /// No description provided for @restoreSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get restoreSnapshotTitle;

  /// No description provided for @restoreSnapshotBody.
  ///
  /// In en, this message translates to:
  /// **'Your data goes back to how it was then, on all your synced devices. Your current data is saved as a backup first, so you can undo this.'**
  String get restoreSnapshotBody;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @restoreDone.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get restoreDone;

  /// No description provided for @recentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get recentlyDeleted;

  /// No description provided for @recentlyDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Semesters and courses deleted in the last 30 days'**
  String get recentlyDeletedSubtitle;

  /// No description provided for @recentlyDeletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted recently.'**
  String get recentlyDeletedEmpty;

  /// No description provided for @deletedSemester.
  ///
  /// In en, this message translates to:
  /// **'Semester · deleted {date}'**
  String deletedSemester(String date);

  /// No description provided for @deletedCourse.
  ///
  /// In en, this message translates to:
  /// **'Course · deleted {date}'**
  String deletedCourse(String date);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change couldn\'t sync} other{{count} changes couldn\'t sync}}'**
  String syncFailed(int count);

  /// No description provided for @syncFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'They\'re kept on this device.'**
  String get syncFailedSubtitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @syncPaused.
  ///
  /// In en, this message translates to:
  /// **'Sync paused until {time}'**
  String syncPaused(String time);

  /// No description provided for @syncPausedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The sync server is busy. Your changes are saved on this device and sync then.'**
  String get syncPausedSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
