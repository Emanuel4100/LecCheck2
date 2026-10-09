// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'LecCheck';

  @override
  String get ok => 'אישור';

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמירה';

  @override
  String get delete => 'מחיקה';

  @override
  String get undo => 'ביטול פעולה';

  @override
  String get edit => 'עריכה';

  @override
  String get add => 'הוספה';

  @override
  String get done => 'סיום';

  @override
  String get close => 'סגירה';

  @override
  String get next => 'הבא';

  @override
  String get back => 'חזרה';

  @override
  String get skip => 'דילוג';

  @override
  String get remove => 'הסרה';

  @override
  String get search => 'חיפוש';

  @override
  String get optional => 'אופציונלי';

  @override
  String get today => 'היום';

  @override
  String get tomorrow => 'מחר';

  @override
  String get yesterday => 'אתמול';

  @override
  String get settings => 'הגדרות';

  @override
  String get navToday => 'היום';

  @override
  String get navWeek => 'שבוע';

  @override
  String get navCourses => 'קורסים';

  @override
  String get navStats => 'סטטיסטיקה';

  @override
  String get typeLecture => 'הרצאה';

  @override
  String get typePractice => 'תרגול';

  @override
  String get typeLab => 'מעבדה';

  @override
  String get typeOther => 'אחר';

  @override
  String get statusPending => 'ממתין';

  @override
  String get statusAttended => 'נכח';

  @override
  String get statusWatched => 'נצפה בהקלטה';

  @override
  String get statusMissed => 'החסיר';

  @override
  String get statusSkipped => 'דילג';

  @override
  String get statusCanceled => 'מבוטל';

  @override
  String get statusCanceledHoliday => 'אין שיעור';

  @override
  String get markAttended => 'נכח';

  @override
  String get markMissed => 'החסיר';

  @override
  String get markWatched => 'צפייה';

  @override
  String get markSkipped => 'דילג';

  @override
  String get markCanceled => 'בוטל';

  @override
  String get clearStatus => 'ניקוי סטטוס';

  @override
  String markedAs(String status) {
    return 'סומן: $status';
  }

  @override
  String markedManyAs(int count, String status) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מפגשים סומנו: $status',
      two: 'שני מפגשים סומנו: $status',
      one: 'מפגש אחד סומן: $status',
    );
    return '$_temp0';
  }

  @override
  String get welcomeTitle => 'ברוכים הבאים ל-LecCheck';

  @override
  String get welcomeSubtitle =>
      'סמנו כל הרצאה, תרגול ומעבדה שהייתם בהם, וראו את כל הסמסטר במבט אחד.';

  @override
  String get continueAsGuest => 'המשך בלי חשבון';

  @override
  String get guestNote => 'הכול נשמר במכשיר הזה. אפשר להתחבר בהמשך כדי לסנכרן.';

  @override
  String get signInWithGoogle => 'התחברות עם Google';

  @override
  String get signInSoon => 'סנכרון יגיע בעדכון הקרוב.';

  @override
  String get semesterSetupTitle => 'הגדרת הסמסטר';

  @override
  String get semesterSetupSubtitle => 'אפשר לשנות הכול אחר כך בהגדרות.';

  @override
  String get semesterName => 'שם הסמסטר';

  @override
  String get semesterDefaultName => 'סמסטר א׳';

  @override
  String get startDate => 'תאריך התחלה';

  @override
  String get endDate => 'תאריך סיום';

  @override
  String get weekStartsOn => 'תחילת שבוע';

  @override
  String get visibleDays => 'ימים בתצוגה השבועית';

  @override
  String semesterLength(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks שבועות',
      two: 'שבועיים',
      one: 'שבוע אחד',
    );
    return '$_temp0';
  }

  @override
  String get dateRangeError => 'תאריך הסיום חייב להיות אחרי תאריך ההתחלה.';

  @override
  String get createSemester => 'יצירת סמסטר';

  @override
  String get addFirstCoursesTitle => 'הוספת הקורסים';

  @override
  String get addFirstCoursesSubtitle =>
      'הוסיפו כל קורס עם ההרצאות, התרגולים והמעבדות השבועיים שלו.';

  @override
  String get finishSetup => 'סיום';

  @override
  String weekOfTotal(int week, int total) {
    return 'שבוע $week מתוך $total';
  }

  @override
  String weekNumber(int week) {
    return 'שבוע $week';
  }

  @override
  String beforeSemester(String date) {
    return 'הסמסטר מתחיל ב-$date';
  }

  @override
  String get afterSemester => 'הסמסטר הסתיים';

  @override
  String get nowLabel => 'עכשיו';

  @override
  String get nextLabel => 'הבא';

  @override
  String startsIn(String duration) {
    return 'מתחיל בעוד $duration';
  }

  @override
  String endsIn(String duration) {
    return 'מסתיים בעוד $duration';
  }

  @override
  String durationHours(int hours) {
    return '$hours ש׳';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes ד׳';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ש׳ $minutes ד׳';
  }

  @override
  String get noClassesToday => 'אין שיעורים היום';

  @override
  String get noUpcoming => 'אין מפגשים מתוכננים';

  @override
  String get needsMarking => 'ממתינים לסימון';

  @override
  String needsMarkingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מפגשים',
      two: 'שני מפגשים',
      one: 'מפגש אחד',
    );
    return '$_temp0';
  }

  @override
  String get allCaughtUp => 'הכול מעודכן';

  @override
  String get allCaughtUpSubtitle => 'לכל מפגש שעבר יש סטטוס.';

  @override
  String get markAllAttended => 'סימון כולם כנוכחות';

  @override
  String get todaySchedule => 'הלו״ז של היום';

  @override
  String get comingUp => 'בקרוב';

  @override
  String get allSessions => 'כל המפגשים';

  @override
  String get swipeHint => 'החלקה ימינה לנוכחות, שמאלה להיעדרות';

  @override
  String get openLink => 'פתיחת קישור';

  @override
  String get noSemesterTitle => 'אין עדיין סמסטר';

  @override
  String get noSemesterBody => 'צרו סמסטר כדי להתחיל לעקוב.';

  @override
  String get addCourseFirst => 'הוסיפו את הקורסים כדי לראות כאן את הלו״ז.';

  @override
  String get goToToday => 'מעבר להיום';

  @override
  String get jumpToDate => 'מעבר לתאריך';

  @override
  String get dayOptions => 'אפשרויות יום';

  @override
  String get markNoClassDay => 'אין שיעורים ביום הזה';

  @override
  String get markNoClassDaySubtitle =>
      'מבטל את כל המפגשים ביום הזה. אפשר לבטל את זה בכל רגע.';

  @override
  String get restoreDay => 'החזרת השיעורים';

  @override
  String get noClassReason => 'סיבה (אופציונלי)';

  @override
  String get noClassReasonHint => 'חג, שביתה, יום מבחן…';

  @override
  String get coursesTitle => 'קורסים';

  @override
  String get addCourse => 'הוספת קורס';

  @override
  String get addOneTimeSession => 'הוספת מפגש חד-פעמי';

  @override
  String get noCoursesYet => 'אין עדיין קורסים';

  @override
  String get noCoursesSubtitle =>
      'הוסיפו את הקורס הראשון עם המפגשים השבועיים שלו.';

  @override
  String nextSession(String when) {
    return 'הבא: $when';
  }

  @override
  String get noUpcomingSessions => 'אין מפגשים קרובים';

  @override
  String attendancePercent(int percent) {
    return '$percent% נוכחות';
  }

  @override
  String canMissMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'אפשר להחסיר עוד $count מפגשים',
      two: 'אפשר להחסיר עוד שני מפגשים',
      one: 'אפשר להחסיר עוד מפגש אחד',
      zero: 'אי אפשר להחסיר יותר',
    );
    return '$_temp0';
  }

  @override
  String get requirementAtRisk => 'חובה להגיע לכל המפגשים שנותרו';

  @override
  String get requirementFailed => 'כבר אי אפשר לעמוד בדרישה';

  @override
  String get requirementMet => 'הדרישה הושגה';

  @override
  String get sessionsHistory => 'מפגשים';

  @override
  String get courseNotes => 'הערות';

  @override
  String get courseLinks => 'קישורים';

  @override
  String get courseWebsite => 'אתר הקורס';

  @override
  String get lecturer => 'מרצה';

  @override
  String get courseCode => 'קוד קורס';

  @override
  String get newCourse => 'קורס חדש';

  @override
  String get editCourse => 'עריכת קורס';

  @override
  String get courseName => 'שם הקורס';

  @override
  String get shortName => 'שם מקוצר';

  @override
  String get shortNameHelper => 'מוצג בתצוגה השבועית כשהשם המלא לא נכנס';

  @override
  String get courseNameRequired => 'יש להזין שם קורס';

  @override
  String get courseNotesHint => 'רשימת קריאה, כללי מבחן, הרכב ציון…';

  @override
  String get courseColor => 'צבע';

  @override
  String get extraLinks => 'קישורים';

  @override
  String get addLink => 'הוספת קישור';

  @override
  String get linkTitle => 'כותרת';

  @override
  String get linkUrl => 'כתובת';

  @override
  String get meetingsSection => 'מערכת שבועית';

  @override
  String get addMeeting => 'הוספת מפגש';

  @override
  String get noMeetingsYet => 'הוסיפו את ההרצאות, התרגולים והמעבדות של הקורס.';

  @override
  String get weekly => 'שבועי';

  @override
  String get oneTime => 'חד-פעמי';

  @override
  String get everyOtherWeek => 'פעם בשבועיים';

  @override
  String get firstWeek => 'שבוע ראשון';

  @override
  String get secondWeek => 'שבוע שני';

  @override
  String get weekday => 'יום';

  @override
  String get date => 'תאריך';

  @override
  String get startTime => 'התחלה';

  @override
  String get endTime => 'סיום';

  @override
  String get location => 'חדר / מיקום';

  @override
  String get endAfterStartError => 'שעת הסיום חייבת להיות אחרי שעת ההתחלה';

  @override
  String get removeMeeting => 'הסרת המפגש';

  @override
  String get meetingLinks => 'קישורים למפגש';

  @override
  String get requirementsSection => 'דרישת נוכחות';

  @override
  String get requirementsHint =>
      'הגדירו נוכחות מינימלית ו-LecCheck יגיד לכם כמה מפגשים עוד אפשר להחסיר.';

  @override
  String get addRequirement => 'הוספת דרישה';

  @override
  String get minAttendance => 'נוכחות מינימלית';

  @override
  String get appliesTo => 'חל על';

  @override
  String get allTypes => 'כל המפגשים';

  @override
  String get recordingsCount => 'צפייה בהקלטה נחשבת כנוכחות';

  @override
  String get discardChangesTitle => 'לבטל את השינויים?';

  @override
  String get discardChangesBody => 'השינויים בקורס לא נשמרו.';

  @override
  String get discard => 'ביטול שינויים';

  @override
  String get keepEditing => 'להמשיך לערוך';

  @override
  String get deleteCourseTitle => 'למחוק את הקורס?';

  @override
  String get deleteCourseBody =>
      'המפגשים וכל הסימונים שלו יימחקו. אפשר לבטל מיד אחרי.';

  @override
  String get courseDeleted => 'הקורס נמחק';

  @override
  String get applyChangeTitle => 'להחיל את השינוי על';

  @override
  String get applyAllWeeks => 'כל השבועות';

  @override
  String get applyFromThisWeek => 'מהשבוע הזה והלאה';

  @override
  String get sessionDetails => 'מפגש';

  @override
  String get status => 'סטטוס';

  @override
  String get sessionNotes => 'הערות למפגש זה';

  @override
  String get sessionNotesHint => 'נושאים, שיעורי בית, תזכורות…';

  @override
  String get recordingLink => 'קישור להקלטה';

  @override
  String get addRecordingLink => 'הוספת קישור להקלטה';

  @override
  String get thisWeekOnly => 'רק השבוע';

  @override
  String get moveSession => 'שינוי תאריך, שעה או חדר';

  @override
  String get resetChanges => 'ביטול השינויים לשבוע הזה';

  @override
  String get movedLabel => 'שונה השבוע';

  @override
  String get canceledByHolidayHint => 'בוטל בגלל יום ללא שיעורים';

  @override
  String get removeOneTime => 'הסרת המפגש החד-פעמי';

  @override
  String get statsTitle => 'סטטיסטיקה';

  @override
  String get attendance => 'נוכחות';

  @override
  String get attendanceSubtitle =>
      'נוכחות או צפייה, מתוך המפגשים שנכחתם, צפיתם או החסרתם.';

  @override
  String get semesterProgress => 'התקדמות הסמסטר';

  @override
  String get streak => 'רצף';

  @override
  String streakValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count מפגשים',
      two: 'שני מפגשים',
      one: 'מפגש אחד',
    );
    return '$_temp0';
  }

  @override
  String bestStreak(int count) {
    return 'שיא: $count';
  }

  @override
  String get toMark => 'לסימון';

  @override
  String get byCourse => 'לפי קורס';

  @override
  String get byType => 'לפי סוג';

  @override
  String get weeklyTrend => 'נוכחות שבועית';

  @override
  String get statusMix => 'מפגשים שעברו';

  @override
  String get catchUp => 'השלמת הקלטות';

  @override
  String get catchUpEmpty => 'אין מפגשים שהוחסרו ויש להם הקלטה.';

  @override
  String get noDataYet => 'סמנו כמה מפגשים כדי לראות כאן נתונים.';

  @override
  String get requirementsOverview => 'דרישות נוכחות';

  @override
  String get account => 'חשבון';

  @override
  String get guestMode => 'לא מחובר';

  @override
  String get guestModeSubtitle => 'הנתונים נשמרים רק במכשיר הזה.';

  @override
  String get appearance => 'מראה';

  @override
  String get themeMode => 'מצב';

  @override
  String get themeSystem => 'מערכת';

  @override
  String get themeLight => 'בהיר';

  @override
  String get themeDark => 'כהה';

  @override
  String get pureBlack => 'שחור מלא';

  @override
  String get pureBlackSubtitle => 'מצב כהה עמוק יותר למסכי OLED';

  @override
  String get colorTheme => 'ערכת צבעים';

  @override
  String get presetWallpaper => 'טפט';

  @override
  String get presetOcean => 'אוקיינוס';

  @override
  String get presetSunset => 'שקיעה';

  @override
  String get presetForest => 'יער';

  @override
  String get presetGrape => 'ענבים';

  @override
  String get presetRose => 'ורד';

  @override
  String get presetMono => 'מונו';

  @override
  String get language => 'שפה';

  @override
  String get languageSystem => 'ברירת המחדל של המערכת';

  @override
  String get time24h => 'שעון 24 שעות';

  @override
  String get time24hSubtitle => 'הצגת 14:30 במקום 2:30 PM';

  @override
  String get meetingNumbers => 'מספור מפגשים';

  @override
  String get meetingNumbersSubtitle => 'הצגת #1, #2… לכל קורס וסוג';

  @override
  String get semesterSection => 'סמסטר';

  @override
  String get semesters => 'סמסטרים';

  @override
  String get addSemester => 'הוספת סמסטר';

  @override
  String get editSemester => 'עריכת סמסטר';

  @override
  String get deleteSemesterTitle => 'למחוק את הסמסטר?';

  @override
  String get deleteSemesterBody =>
      'כל הקורסים והסימונים שלו יימחקו. אפשר לבטל מיד אחרי.';

  @override
  String get semesterDeleted => 'הסמסטר נמחק';

  @override
  String get activeSemester => 'פעיל';

  @override
  String get noClassDays => 'חגים וימים ללא שיעורים';

  @override
  String get noClassDaysSubtitle => 'מפגשים בתאריכים האלה יוצגו כמבוטלים.';

  @override
  String get addNoClassRange => 'הוספת תאריכים';

  @override
  String get data => 'נתונים';

  @override
  String get exportData => 'ייצוא גיבוי';

  @override
  String get exportDataSubtitle => 'שמירת קובץ JSON עם כל הסמסטרים';

  @override
  String get importData => 'ייבוא גיבוי';

  @override
  String get importDataSubtitle =>
      'שחזור גיבוי של LecCheck (כולל קבצים מהאפליקציה הישנה)';

  @override
  String importDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'יובאו $count סמסטרים',
      two: 'יובאו שני סמסטרים',
      one: 'יובא סמסטר אחד',
    );
    return '$_temp0';
  }

  @override
  String get importFailed => 'הקובץ הזה אינו גיבוי של LecCheck.';

  @override
  String get exportDone => 'הגיבוי נשמר';

  @override
  String get about => 'אודות';

  @override
  String get version => 'גרסה';

  @override
  String get sourceCode => 'קוד מקור';

  @override
  String get license => 'רישיון';

  @override
  String get licenseSummary =>
      'תוכנה חופשית לפי GNU GPL גרסה 3 ואילך, ללא אחריות.';

  @override
  String get developer => 'מפתחים';

  @override
  String get developerTools => 'כלי מפתחים';

  @override
  String get developerToolsSubtitle =>
      'בדיקת התראות, סנכרון, גיבויים והווידג׳ט במכשיר הזה';

  @override
  String devModeSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עוד $count הקשות להפעלת מצב מפתחים',
      one: 'עוד הקשה אחת להפעלת מצב מפתחים',
    );
    return '$_temp0';
  }

  @override
  String get devModeOn => 'מצב מפתחים פעיל';

  @override
  String get devModeAlreadyOn => 'מצב מפתחים כבר פעיל';

  @override
  String get signInFailed => 'ההתחברות נכשלה. בדקו את החיבור ונסו שוב.';

  @override
  String get devSignIn => 'התחברות מפתחים';

  @override
  String get restoringData => 'משחזרים את הנתונים שלך…';

  @override
  String syncSynced(String time) {
    return 'סונכרן $time';
  }

  @override
  String get justNow => 'הרגע';

  @override
  String get syncSyncing => 'מסנכרן…';

  @override
  String get syncConnecting => 'מתחבר…';

  @override
  String get syncOffline => 'אין חיבור — השינויים יסונכרנו אחר כך';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שינויים ממתינים לסנכרון',
      two: 'שני שינויים ממתינים לסנכרון',
      one: 'שינוי אחד ממתין לסנכרון',
    );
    return '$_temp0';
  }

  @override
  String get syncNotConfigured => 'הסנכרון לא מוגדר בגרסה הזו.';

  @override
  String get syncNow => 'סנכרון עכשיו';

  @override
  String get signOut => 'התנתקות';

  @override
  String get signOutTitle => 'להתנתק?';

  @override
  String get signOutBody =>
      'הנתונים נשמרים בחשבון Google שלך, ואפשר לקבל אותם בחזרה בהתחברות מחדש. לשמור עותק גם במכשיר הזה?';

  @override
  String get keepData => 'לשמור במכשיר';

  @override
  String get removeData => 'להסיר מהמכשיר';

  @override
  String get signOutEverywhere => 'התנתקות מכל המכשירים';

  @override
  String get deleteCloudData => 'מחיקת הנתונים בענן';

  @override
  String get deleteCloudTitle => 'למחוק את הנתונים בענן?';

  @override
  String get deleteCloudBody =>
      'הנתונים המסונכרנים יימחקו מהשרת, וכל המכשירים יתנתקו. במכשיר הזה יישאר עותק.';

  @override
  String get replaceDataTitle => 'להחליף חשבון?';

  @override
  String get replaceDataBody =>
      'במכשיר הזה יש נתונים של חשבון אחר. ההתחברות תחליף אותם בנתונים של החשבון הזה.';

  @override
  String get replace => 'החלפה';

  @override
  String get syncHint =>
      'התחברו כדי לסנכרן עם המכשירים האחרים שלכם. בחינם, והנתונים נשארים פרטיים לחשבון שלכם.';

  @override
  String get notifications => 'התראות';

  @override
  String get beforeClass => 'לפני השיעור';

  @override
  String get beforeClassSubtitle => 'תזכורת עם החדר והקישור';

  @override
  String get afterClass => 'אחרי השיעור: איך היה?';

  @override
  String get afterClassSubtitle => 'סימון נוכחות ישר מההתראה';

  @override
  String minutesShort(int minutes) {
    return '$minutes ד׳';
  }

  @override
  String get testNotification => 'שליחת התראת בדיקה';

  @override
  String notificationFailed(String error) {
    return 'לא ניתן להציג את ההתראה: $error';
  }

  @override
  String get notificationsBlocked =>
      'ההתראות חסומות. אפשרו אותן בהגדרות המערכת.';

  @override
  String notifyBeforeTitle(String course, String type, int minutes) {
    return '$course · $type בעוד $minutes ד׳';
  }

  @override
  String notifyAfterTitle(String course) {
    return 'איך היה ב$course?';
  }

  @override
  String get notifyTestTitle => 'התזכורות של LecCheck פעילות';

  @override
  String get notifyTestBody => 'כך ייראו התזכורות לפני ואחרי השיעור.';

  @override
  String get channelBefore => 'לפני השיעור';

  @override
  String get channelAfter => 'אחרי השיעור';

  @override
  String get previousWeek => 'השבוע הקודם';

  @override
  String get nextWeek => 'השבוע הבא';

  @override
  String get rightClickHint => 'לחיצה ימנית על מפגש פותחת אפשרויות נוספות';

  @override
  String get details => 'פרטים';

  @override
  String get goToCourse => 'מעבר לקורס';

  @override
  String get selectSessionHint => 'בחרו מפגש כדי לראות כאן את הפרטים שלו';

  @override
  String get keyboardShortcuts => 'קיצורי מקלדת';

  @override
  String get keyboardShortcutsSubtitle => 'אפשר להציג אותם בכל רגע עם F1';

  @override
  String get shortcutTabs => 'מעבר בין הלשוניות';

  @override
  String get shortcutSearch => 'חיפוש מפגשים';

  @override
  String get shortcutWeeks => 'שבוע קודם / הבא';

  @override
  String get shortcutZoom => 'הגדלה / הקטנה / איפוס של תצוגת השבוע';

  @override
  String get shortcutMark => 'סימון המפגש הפתוח: נכח, החסיר, צפייה, דילג, בוטל';

  @override
  String get shortcutBack => 'סגירה / חזרה';

  @override
  String get shortcutHelp => 'הצגת הרשימה הזו';

  @override
  String get thisDevice => 'המכשיר הזה';

  @override
  String get addWidget => 'הוספת וידג׳ט למסך הבית';

  @override
  String get addWidgetSubtitle => 'המפגשים של היום עם סימון בלחיצה אחת';

  @override
  String get altStoreRefresh => 'יש לרענן ב-AltStore או ב-SideStore כל שבוע';

  @override
  String get altStoreRefreshSubtitle =>
      'אפליקציות שהותקנו עם Apple ID חינמי מפסיקות להיפתח אחרי 7 ימים בלי רענון.';

  @override
  String get notificationsOff => 'ההתראות של LecCheck כבויות';

  @override
  String get notificationsOffSubtitle => 'התזכורות לא יופיעו עד שתאפשרו אותן.';

  @override
  String get allow => 'לאפשר';

  @override
  String get remindersWhileOpen =>
      'במחשב הזה התזכורות מופיעות כש-LecCheck פתוחה.';

  @override
  String get openSettings => 'לפתוח את ההגדרות';

  @override
  String get notificationsOffOpenSettings =>
      'יש להפעיל את ההתראות של LecCheck בהגדרות המערכת ולחזור לכאן.';

  @override
  String reminderChannelOff(String channel) {
    return 'ההתראות „$channel” כבויות בהגדרות המערכת.';
  }

  @override
  String get exactAlarmsOff => 'תזכורות עלולות להגיע באיחור';

  @override
  String get exactAlarmsOffSubtitle =>
      'יש לאפשר „שעונים מעוררים ותזכורות” כדי שיגיעו בדיוק בזמן.';

  @override
  String get backgroundRestricted => 'השימוש ברקע מוגבל';

  @override
  String get backgroundRestrictedSubtitle =>
      'התזכורות לא יופיעו כל עוד LecCheck מוגבלת. יש להגדיר את השימוש בסוללה כ„ללא הגבלה”.';

  @override
  String get batteryOptimized => 'אופטימיזציית הסוללה פועלת';

  @override
  String get batteryOptimizedSubtitle =>
      'אנדרואיד עלולה לעכב תזכורות. כדאי לכבות את האופטימיזציה עבור LecCheck.';

  @override
  String get batteryOptimizedSamsung =>
      'בטלפונים של סמסונג תזכורות עלולות להתעכב או להתפספס. כדאי לכבות את האופטימיזציה ולהוציא את LecCheck מ„אפליקציות במצב שינה” (הגדרות ← סוללה ← הגבלות שימוש ברקע).';

  @override
  String get turnOff => 'לכבות';

  @override
  String autostartHint(String maker) {
    return 'בטלפונים של $maker יש לאפשר גם הפעלה אוטומטית (Autostart) של LecCheck, אחרת התזכורות עלולות להיפסק.';
  }

  @override
  String get howTo => 'איך?';

  @override
  String get presetAccent => 'צבע המערכת';

  @override
  String get importTitle => 'לייבא את הגיבוי?';

  @override
  String importPreview(int semesters, int added, int changed) {
    return 'בגיבוי יש $semesters סמסטרים: $added פריטים חדשים ו־$changed שונים משלך.\n\n„הוספת החסר” מוסיפה רק מה שאין לך. „החלפה” דורסת את הגרסאות שלך בכל המכשירים; לפני כן נשמר גיבוי אוטומטי.';
  }

  @override
  String get importMerge => 'הוספת החסר';

  @override
  String get importNothing => 'כל מה שבגיבוי כבר נמצא כאן.';

  @override
  String get snapshots => 'גיבויים אוטומטיים';

  @override
  String get snapshotsSubtitle =>
      'נשמרים מדי יום ולפני ייבוא או התנתקות. אפשר לחזור למצב קודם.';

  @override
  String get snapshotsEmpty => 'עדיין אין גיבויים אוטומטיים.';

  @override
  String get snapshotDaily => 'יומי';

  @override
  String get snapshotImport => 'לפני ייבוא';

  @override
  String get snapshotRestore => 'לפני שחזור';

  @override
  String get snapshotSignOut => 'לפני התנתקות';

  @override
  String get snapshotSwitch => 'לפני החלפת חשבון';

  @override
  String get restoreSnapshotTitle => 'לשחזר את הגיבוי הזה?';

  @override
  String get restoreSnapshotBody =>
      'הנתונים יחזרו למצבם באותו זמן, בכל המכשירים המסונכרנים. הנתונים הנוכחיים נשמרים קודם כגיבוי, כך שאפשר לבטל.';

  @override
  String get restore => 'שחזור';

  @override
  String get restoreDone => 'שוחזר';

  @override
  String get recentlyDeleted => 'נמחקו לאחרונה';

  @override
  String get recentlyDeletedSubtitle =>
      'סמסטרים וקורסים שנמחקו ב־30 הימים האחרונים';

  @override
  String get recentlyDeletedEmpty => 'לא נמחק דבר לאחרונה.';

  @override
  String deletedSemester(String date) {
    return 'סמסטר · נמחק $date';
  }

  @override
  String deletedCourse(String date) {
    return 'קורס · נמחק $date';
  }

  @override
  String syncFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שינויים לא סונכרנו',
      two: 'שני שינויים לא סונכרנו',
      one: 'שינוי אחד לא סונכרן',
    );
    return '$_temp0';
  }

  @override
  String get syncFailedSubtitle => 'הם נשמרים במכשיר הזה.';

  @override
  String get retry => 'ניסיון חוזר';

  @override
  String syncPaused(String time) {
    return 'הסנכרון מושהה עד $time';
  }

  @override
  String get syncPausedSubtitle =>
      'שרת הסנכרון עמוס. השינויים שלך שמורים במכשיר הזה ויסונכרנו אז.';
}
