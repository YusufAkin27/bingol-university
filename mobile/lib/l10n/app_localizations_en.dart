// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonRetryShort => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonOpenInStore => 'Open in store';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get configError =>
      'Configuration error: the server address (API_BASE) is not secure (https). Rebuild the app with the correct address.';

  @override
  String get exitAgainHint => 'Press back again to exit';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navChat => 'Chat';

  @override
  String get navClubs => 'Clubs';

  @override
  String get navProfile => 'Profile';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'You need to update to the latest version to keep using the app.';

  @override
  String get updateAvailable => 'A new version is available.';

  @override
  String updateAvailableVersion(String version) {
    return 'A new version is available ($version).';
  }

  @override
  String get accessBlockedTitle => 'Access blocked';

  @override
  String get accessBlockedBody =>
      'Access from this device or network has been blocked. If you think this is a mistake, contact support.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionAppearance => 'APPEARANCE';

  @override
  String get settingsSectionNotifications => 'NOTIFICATIONS';

  @override
  String get settingsSectionPrivacy => 'PRIVACY AND ACCOUNT';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint => 'App, notification and email language';

  @override
  String get languageSystem => 'System';

  @override
  String get pushPermission => 'Notification permission (push)';

  @override
  String get pushNotConfigured => 'Not configured yet';

  @override
  String get pushOn => 'On';

  @override
  String get pushOff => 'Off (enable in system settings)';

  @override
  String get pushNotGranted => 'Permission not granted';

  @override
  String get pushOnToast => 'Push notifications are on.';

  @override
  String pushStatusToast(String status) {
    return 'Push notifications: $status';
  }

  @override
  String get settingsShowEmail => 'Show my email to others';

  @override
  String get settingsFindContacts => 'Find people from contacts';

  @override
  String get settingsPrivacyData => 'Privacy and data';

  @override
  String get settingsSupport => 'Support and FAQ';

  @override
  String get settingsLogoutAll => 'Sign out of all devices';

  @override
  String get settingsLogoutAllTitle => 'Sign out of all devices';

  @override
  String get settingsLogoutAllBody =>
      'Your account will be signed out on all devices and you will need to sign in again.';

  @override
  String get settingsLogoutAllConfirm => 'Sign out';

  @override
  String settingsVersion(String version) {
    return 'BÜ Kampüs · Version $version';
  }

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in with your school email.';

  @override
  String get loginReplacedNotice =>
      'Your account was signed in on another device. For your security, the session on this device was closed.';

  @override
  String get loginPasswordRequired => 'Enter your password.';

  @override
  String get loginForgotPassword => 'Forgot password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginNoAccount => 'Do not have an account?';

  @override
  String get loginRegister => 'Sign up';

  @override
  String get loginCompleteVerification => 'Complete verification';

  @override
  String get authBack => 'Back';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authIdHint => 'Your school email';

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCode => 'Resend code';

  @override
  String authResendIn(String seconds) {
    return 'Resend ($seconds s)';
  }

  @override
  String authNewCodeIn(String seconds) {
    return 'Wait $seconds s for a new code';
  }

  @override
  String get authCodeSent => 'Code sent.';

  @override
  String get authNewCodeSent => 'A new code has been sent.';

  @override
  String get authEnterCode => 'Enter the code';

  @override
  String authCodeSentTo(String email) {
    return 'Enter the 6-digit code we sent to $email.';
  }

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String authVerifySubtitle(String email) {
    return 'A code was sent to $email. It is valid for 10 minutes.';
  }

  @override
  String get authUnverifiedNotice =>
      'Verify your email. Your account must be verified before you can sign in.';

  @override
  String get authUseOtherAccount => 'Sign in with another account';

  @override
  String get authResetTitle => 'Forgot your password?';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authNewPasswordTitle => 'Set a new password';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authUpdatePassword => 'Update password';

  @override
  String get authPasswordUpdated => 'Password updated.';

  @override
  String get authSessionExpired => 'Time expired. Please start over.';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSelectDepartment => 'Select your department.';

  @override
  String get authSelectGrade => 'Select your year.';

  @override
  String get authDepartmentsLoadFailed =>
      'Could not load the department list. Try again.';

  @override
  String get authNameRequired => 'Enter your first and last name.';

  @override
  String get authNameHint => 'Full name';

  @override
  String get authPasswordMin8 => 'Password (at least 8 characters)';

  @override
  String get authTermsPrefix => 'I accept the ';

  @override
  String get authTermsLink => 'Terms of Use';

  @override
  String get authTermsSep => ' and ';

  @override
  String get authPrivacyLink => 'Privacy Policy';

  @override
  String get authTermsSuffix => '';

  @override
  String get authMustAccept => 'You must accept to continue.';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authRegisterSubtitle => 'Join the campus in a few steps.';

  @override
  String get authSectionAcademic => 'Academic details';

  @override
  String get authSectionAccount => 'Account details';

  @override
  String get authPwWeak => 'Weak';

  @override
  String get authPwFair => 'Fair';

  @override
  String get authPwStrong => 'Strong';

  @override
  String get acadMonth1 => 'January';

  @override
  String get acadMonth2 => 'February';

  @override
  String get acadMonth3 => 'March';

  @override
  String get acadMonth4 => 'April';

  @override
  String get acadMonth5 => 'May';

  @override
  String get acadMonth6 => 'June';

  @override
  String get acadMonth7 => 'July';

  @override
  String get acadMonth8 => 'August';

  @override
  String get acadMonth9 => 'September';

  @override
  String get acadMonth10 => 'October';

  @override
  String get acadMonth11 => 'November';

  @override
  String get acadMonth12 => 'December';

  @override
  String get acadDay1 => 'Monday';

  @override
  String get acadDay2 => 'Tuesday';

  @override
  String get acadDay3 => 'Wednesday';

  @override
  String get acadDay4 => 'Thursday';

  @override
  String get acadDay5 => 'Friday';

  @override
  String get acadDay6 => 'Saturday';

  @override
  String get acadDay7 => 'Sunday';

  @override
  String get acadDayShort1 => 'Mon';

  @override
  String get acadDayShort2 => 'Tue';

  @override
  String get acadDayShort3 => 'Wed';

  @override
  String get acadDayShort4 => 'Thu';

  @override
  String get acadDayShort5 => 'Fri';

  @override
  String get acadDayShort6 => 'Sat';

  @override
  String get acadDayShort7 => 'Sun';

  @override
  String get acadColorRed => 'Red';

  @override
  String get acadColorOrange => 'Orange';

  @override
  String get acadColorAmber => 'Yellow';

  @override
  String get acadColorGreen => 'Green';

  @override
  String get acadColorTeal => 'Teal';

  @override
  String get acadColorBlue => 'Blue';

  @override
  String get acadColorIndigo => 'Indigo';

  @override
  String get acadColorPurple => 'Purple';

  @override
  String get acadColorPink => 'Pink';

  @override
  String get acadColorGray => 'Gray';

  @override
  String get acadExamTypeVize => 'Midterm';

  @override
  String get acadExamTypeFinal => 'Final';

  @override
  String get acadExamTypeBut => 'Make-up exam';

  @override
  String get acadExamTypeQuiz => 'Quiz';

  @override
  String get acadExamTypeOdev => 'Assignment';

  @override
  String get acadExamTypeDiger => 'Other';

  @override
  String get acadEventKindSemesterStart => 'Semester start';

  @override
  String get acadEventKindRegistration => 'Course registration';

  @override
  String get acadEventKindHoliday => 'Break';

  @override
  String get acadEventKindPublicHoliday => 'Public holiday';

  @override
  String acadCountdownDays(String n) {
    return '$n days left';
  }

  @override
  String acadCountdownHours(String n) {
    return '$n hours left';
  }

  @override
  String acadCountdownMinutes(String n) {
    return '$n min left';
  }

  @override
  String get acadGradePrep => 'Preparatory';

  @override
  String get acadGradeMaster => 'Master’s';

  @override
  String get acadGradePhd => 'PhD';

  @override
  String acadGradeN(String n) {
    return 'Year $n';
  }

  @override
  String get acadSave => 'Save';

  @override
  String get acadDelete => 'Delete';

  @override
  String get acadCancel => 'Cancel';

  @override
  String get acadRetry => 'Try again';

  @override
  String get acadSelect => 'Select';

  @override
  String get acadMaintenance =>
      'Academic services are under maintenance. Please try again later.';

  @override
  String get acadMyDept => 'My department';

  @override
  String get acadAll => 'All';

  @override
  String get acadHubTitle => 'Academic';

  @override
  String get acadHubReminders => 'Reminders';

  @override
  String get acadHubAddCourses => 'Add your courses';

  @override
  String get acadHubNoClassWeek => 'No classes this week';

  @override
  String acadHubNext(String course, String time) {
    return 'Next: $course $time';
  }

  @override
  String get acadHubNoExam => 'No upcoming exams';

  @override
  String acadHubExamCount(String n) {
    return '$n upcoming exams';
  }

  @override
  String get acadHubTimetable => 'Timetable';

  @override
  String get acadHubTimetableSub => 'Your weekly timetable';

  @override
  String get acadHubExamsSub => 'Your exam schedule and the official program';

  @override
  String get acadHubCalendarSub => 'Semester, registration and exam dates';

  @override
  String get acadHubAnnouncementsSub => 'Announcements for your department';

  @override
  String acadHubUnread(String n) {
    return '$n unread';
  }

  @override
  String get acadExamsTitle => 'Exams';

  @override
  String get acadExamsAdd => 'Add exam';

  @override
  String get acadExamsTabMine => 'My exams';

  @override
  String get acadExamsTabOfficial => 'Official schedule';

  @override
  String get acadExamsEmptyMine =>
      'You have not added any personal exams.\nTrack your midterm, final or quiz dates here.';

  @override
  String get acadExamsUpcoming => 'Upcoming';

  @override
  String get acadExamsNoUpcoming => 'You have no upcoming exams.';

  @override
  String get acadExamsPast => 'Past';

  @override
  String acadExamsSemantic(String type, String title, String date) {
    return '$type: $title. $date. Tap to edit.';
  }

  @override
  String acadExamsSemanticCd(
      String type, String title, String date, String countdown) {
    return '$type: $title. $date. $countdown. Tap to edit.';
  }

  @override
  String acadOfficialSemantic(String type, String title, String date) {
    return '$type: $title. $date';
  }

  @override
  String acadOfficialSemanticRoom(
      String type, String title, String date, String room) {
    return '$type: $title. $date, $room';
  }

  @override
  String get acadExamsProfileIncomplete =>
      'Your profile has no department; only public exams are shown. You can add your department by editing your profile.';

  @override
  String get acadExamsEmptyOfficial =>
      'No official exam schedule has been published yet.';

  @override
  String get acadFormErrTitle => 'Exam title is required.';

  @override
  String get acadFormErrDate => 'Select the exam date.';

  @override
  String get acadFormErrEnd => 'End time must be after the start time.';

  @override
  String get acadFormDeleteTitle => 'Delete exam';

  @override
  String acadFormDeleteText(String title) {
    return '\"$title\" will be deleted.';
  }

  @override
  String get acadFormEdit => 'Edit exam';

  @override
  String get acadFormNew => 'New exam';

  @override
  String get acadFormTitleLabel => 'Title';

  @override
  String get acadFormTitleHint => 'E.g. Data Structures Midterm 1';

  @override
  String get acadFormType => 'Type';

  @override
  String get acadFormCourseOpt => 'Course (optional)';

  @override
  String get acadFormNone => 'None';

  @override
  String get acadFormDateTime => 'Date and time';

  @override
  String get acadFormExamDate => 'Exam date';

  @override
  String get acadFormPickDate => 'Select date';

  @override
  String get acadFormStartTime => 'Start time';

  @override
  String get acadFormEndTime => 'End time';

  @override
  String get acadFormEndHint => 'End (opt.)';

  @override
  String get acadFormRoom => 'Room';

  @override
  String get acadFormRoomHint => 'E.g. B-204';

  @override
  String get acadFormNote => 'Note';

  @override
  String get acadFormNoteHint => 'Optional';

  @override
  String get acadFormAdd => 'Add exam';

  @override
  String get acadAnnTitle => 'Department announcements';

  @override
  String get acadAnnDetailTitle => 'Announcement';

  @override
  String get acadAnnReadAll => 'Mark all as read';

  @override
  String get acadAnnEmptyMine =>
      'No announcements for your department.\nSee all announcements in the \"All\" tab.';

  @override
  String get acadAnnEmptyAll => 'No announcements yet.';

  @override
  String get acadAnnAudienceAll => 'Whole university';

  @override
  String get acadAnnUnread => 'Unread';

  @override
  String get acadAnnPinned => 'Pinned';

  @override
  String get acadAnnLinkError => 'The link could not be opened.';

  @override
  String get acadAnnOpenAttachment => 'Open attachment';

  @override
  String get acadCalTitle => 'Academic calendar';

  @override
  String get acadCalPrev => 'Previous month';

  @override
  String get acadCalNext => 'Next month';

  @override
  String get acadCalToday => 'today';

  @override
  String acadCalEventCount(String n) {
    return '$n important dates';
  }

  @override
  String acadCalMonthHeading(String month) {
    return 'Important dates in $month';
  }

  @override
  String get acadCalNoMonth => 'No important dates recorded for this month.';

  @override
  String get acadCalNoDay => 'No important dates on this day.';

  @override
  String get acadCalNextHeading => 'Upcoming important dates';

  @override
  String get acadTimeDay1 => 'Monday';

  @override
  String get acadTimeDay2 => 'Tuesday';

  @override
  String get acadTimeDay3 => 'Wednesday';

  @override
  String get acadTimeDay4 => 'Thursday';

  @override
  String get acadTimeDay5 => 'Friday';

  @override
  String get acadTimeDay6 => 'Saturday';

  @override
  String get acadTimeDay7 => 'Sunday';

  @override
  String get acadTimeDayShort1 => 'Mon';

  @override
  String get acadTimeDayShort2 => 'Tue';

  @override
  String get acadTimeDayShort3 => 'Wed';

  @override
  String get acadTimeDayShort4 => 'Thu';

  @override
  String get acadTimeDayShort5 => 'Fri';

  @override
  String get acadTimeDayShort6 => 'Sat';

  @override
  String get acadTimeDayShort7 => 'Sun';

  @override
  String get acadTimeColorRed => 'Red';

  @override
  String get acadTimeColorOrange => 'Orange';

  @override
  String get acadTimeColorAmber => 'Yellow';

  @override
  String get acadTimeColorGreen => 'Green';

  @override
  String get acadTimeColorTeal => 'Teal';

  @override
  String get acadTimeColorBlue => 'Blue';

  @override
  String get acadTimeColorIndigo => 'Indigo';

  @override
  String get acadTimeColorPurple => 'Purple';

  @override
  String get acadTimeColorPink => 'Pink';

  @override
  String get acadTimeColorGray => 'Gray';

  @override
  String get acadTimeExamVize => 'Midterm';

  @override
  String get acadTimeExamFinal => 'Final';

  @override
  String get acadTimeExamBut => 'Make-up exam';

  @override
  String get acadTimeExamQuiz => 'Quiz';

  @override
  String get acadTimeExamOdev => 'Assignment';

  @override
  String get acadTimeExamOther => 'Other';

  @override
  String acadTimeRemClass(String min, String time, String room) {
    return 'Starts in $min min ($time$room)';
  }

  @override
  String acadTimeRemExamLabel(String type, String title) {
    return '$type: $title';
  }

  @override
  String acadTimeRemExamTomorrow(String time, String room) {
    return 'Tomorrow $time$room';
  }

  @override
  String acadTimeRemExamHour(String room) {
    return 'Starts in 1 hour$room';
  }

  @override
  String get acadTimeExportNone => 'No courses to export.';

  @override
  String get acadTimeExportCopied =>
      'Calendar (.ics) text copied to clipboard.';

  @override
  String get acadTimeTitle => 'Timetable';

  @override
  String get acadTimeExportTooltip => 'Export to calendar (.ics)';

  @override
  String get acadTimeAddCourse => 'Add course';

  @override
  String get acadTimeStale => 'Could not refresh, showing the latest data.';

  @override
  String get acadTimePickSemester => 'Select semester';

  @override
  String acadTimeMyCourses(String count) {
    return 'My courses ($count)';
  }

  @override
  String get acadTimeEmptyText =>
      'You have not added any courses yet.\nAdd your courses to build your weekly timetable.';

  @override
  String get acadTimeAddFirst => 'Add your first course';

  @override
  String get acadTimeNowInClass => 'In class now';

  @override
  String acadTimeMinLeft(String name, String min) {
    return '$name · $min min left';
  }

  @override
  String get acadTimeNextClass => 'Next class';

  @override
  String acadTimeWhenMin(String min) {
    return 'in $min min';
  }

  @override
  String acadTimeWhenHours(String h) {
    return 'in $h h';
  }

  @override
  String acadTimeWhenHoursMin(String h, String min) {
    return 'in $h h $min min';
  }

  @override
  String acadTimeWhenDay(String day, String time) {
    return '$day $time';
  }

  @override
  String get acadTimeToday => 'Today';

  @override
  String get acadTimeNoMoreWeek => 'No more classes this week.';

  @override
  String get acadTimeTodayNone => 'No classes left today';

  @override
  String acadTimeTodayLeft(String count) {
    return '$count classes left today';
  }

  @override
  String acadTimeDayToday(String day) {
    return '$day, today';
  }

  @override
  String acadTimeNoClassDay(String day) {
    return 'No classes on $day.';
  }

  @override
  String get acadTimeOutOfRange => 'This date is outside the semester range.';

  @override
  String get acadTimeStatusNow => 'Now';

  @override
  String get acadTimeStatusDone => 'Done';

  @override
  String acadTimeSlotSemantic(
      String name, String day, String start, String end) {
    return '$name, $day from $start to $end';
  }

  @override
  String acadTimeCourseSemantic(String name, String days) {
    return '$name. $days. Tap to edit.';
  }

  @override
  String get acadTimeNoSessions => 'No sessions';

  @override
  String get acadTimeNameRequired => 'Course name is required';

  @override
  String get acadTimeEndAfterStart => 'End time must be after the start time.';

  @override
  String get acadTimeOwnConflict => 'This course has overlapping sessions';

  @override
  String get acadTimeConflictTitle => 'Course conflict';

  @override
  String acadTimeConflictText(String lines) {
    return 'The times overlap with these courses:\n$lines\n\nSave anyway?';
  }

  @override
  String acadTimeConflictServerText(String message) {
    return '$message\n\nSave anyway?';
  }

  @override
  String get acadTimeSaveAnyway => 'Save anyway';

  @override
  String get acadTimeDeleteCourse => 'Delete course';

  @override
  String acadTimeDeleteCourseText(String name) {
    return 'The course \"$name\" and all its sessions will be deleted.';
  }

  @override
  String get acadTimeDelete => 'Delete';

  @override
  String get acadTimeEditCourse => 'Edit course';

  @override
  String get acadTimeNewCourse => 'New course';

  @override
  String get acadTimeCourseName => 'Course name';

  @override
  String get acadTimeNameHint => 'e.g. Data Structures';

  @override
  String get acadTimeCourseCode => 'Course code';

  @override
  String get acadTimeInstructor => 'Instructor';

  @override
  String get acadTimeInstructorHint => 'Dr. Jane Smith';

  @override
  String get acadTimeColor => 'Color';

  @override
  String acadTimeColorSemantic(String color) {
    return 'Color $color';
  }

  @override
  String get acadTimeColorAuto =>
      'If you do not choose, one is assigned automatically.';

  @override
  String get acadTimeDaysAndTimes => 'Days and times';

  @override
  String get acadTimeAddSession => 'Add another day/time';

  @override
  String get acadTimeNote => 'Note';

  @override
  String get acadTimeNoteHint => 'Optional (e.g. bring a laptop)';

  @override
  String get acadTimeSave => 'Save';

  @override
  String get acadTimeAddCourseBtn => 'Add course';

  @override
  String acadTimeSessionN(String n) {
    return 'Session $n';
  }

  @override
  String get acadTimeRemoveSession => 'Remove session';

  @override
  String get acadTimeStartTime => 'Start time';

  @override
  String get acadTimeEndTime => 'End time';

  @override
  String get acadTimeRoomHint => 'Room (e.g. B-204)';

  @override
  String get acadTimeSemester => 'Semester';

  @override
  String get acadTimeNoSemester =>
      'No semesters yet. Add a semester to organize your courses.';

  @override
  String get acadTimeAddSemester => 'Add new semester';

  @override
  String acadTimeOfficial(String name) {
    return '$name (from academic calendar)';
  }

  @override
  String get acadTimeOfficialDefault => 'Official semester';

  @override
  String get acadTimeClose => 'Close';

  @override
  String get acadTimeCurrent => 'Current';

  @override
  String get acadTimeMakeCurrent => 'Make current semester';

  @override
  String get acadTimeDeleteSemester => 'Delete semester';

  @override
  String acadTimeDeleteSemesterText(String name) {
    return '\"$name\" will be deleted. Courses will have no semester.';
  }

  @override
  String get acadTimeNewSemester => 'New semester';

  @override
  String get acadTimeSemesterHint => '2026-2027 Fall';

  @override
  String get acadTimeStartDate => 'Start date';

  @override
  String get acadTimeEndDate => 'End date';

  @override
  String get acadTimeCancel => 'Cancel';

  @override
  String get acadTimeSemesterNeedAll => 'A name and both dates are required.';

  @override
  String get acadTimeSemesterEndAfter =>
      'End date must be after the start date.';

  @override
  String get acadTimeAdd => 'Add';

  @override
  String get acadTimeRemindersTitle => 'Reminders';

  @override
  String get acadTimeRemindersIntro =>
      'Notifications are scheduled on your device; no internet is needed. They refresh when your timetable or exams change.';

  @override
  String get acadTimeClassReminder => 'Class reminder';

  @override
  String get acadTimeBeforeClass => 'Before class starts';

  @override
  String get acadTimeOneHour => '1 hour';

  @override
  String acadTimeMinutes(String m) {
    return '$m min';
  }

  @override
  String get acadTimeExamReminders => 'Exam reminders';

  @override
  String get acadTimeDayBefore => '1 day before';

  @override
  String get acadTimeHourBefore => '1 hour before';

  @override
  String get authRestEnterCode => 'Enter the 6-digit code.';

  @override
  String get authRestCodeLabel => '6-digit verification code';

  @override
  String chatDetailVideoPreparing(String pct) {
    return 'Preparing video… $pct%';
  }

  @override
  String get chatDetailCancel => 'Cancel';

  @override
  String get chatDetailUserFallback => 'User';

  @override
  String get chatDetailYou => 'You';

  @override
  String get chatDetailChatFallback => 'Chat';

  @override
  String get chatDetailGroupFallback => 'Group';

  @override
  String get chatDetailVideoTooLong => 'Videos can be 60 seconds at most';

  @override
  String get chatDetailVideoTooLarge =>
      'The video is too large, choose a shorter one';

  @override
  String get chatDetailVideoUnsupported =>
      'Videos cannot be sent on this device.';

  @override
  String get chatDetailVideoFailed => 'The video could not be prepared.';

  @override
  String get chatDetailVideosSplit =>
      'The videos are large, so they will be sent as multiple messages';

  @override
  String get chatDetailImageTooLarge =>
      'The image is too large, choose a smaller one.';

  @override
  String get chatDetailImageTypes =>
      'Only JPEG, PNG or WebP images can be sent.';

  @override
  String get chatDetailImageUnreadable => 'The image could not be read.';

  @override
  String get chatDetailVideoUnreadable => 'The video could not be read.';

  @override
  String get chatDetailSavedToGallery => 'Saved to gallery';

  @override
  String get chatDetailDeleteTitle => 'Delete message?';

  @override
  String get chatDetailDeleteBody =>
      'This message will be deleted for everyone.';

  @override
  String get chatDetailDelete => 'Delete';

  @override
  String get chatDetailMsgDeleted => 'This message was deleted';

  @override
  String get chatDetailNevermind => 'Cancel';

  @override
  String get chatDetailToday => 'Today';

  @override
  String get chatDetailYesterday => 'Yesterday';

  @override
  String get chatDetailMonth1 => 'January';

  @override
  String get chatDetailMonth2 => 'February';

  @override
  String get chatDetailMonth3 => 'March';

  @override
  String get chatDetailMonth4 => 'April';

  @override
  String get chatDetailMonth5 => 'May';

  @override
  String get chatDetailMonth6 => 'June';

  @override
  String get chatDetailMonth7 => 'July';

  @override
  String get chatDetailMonth8 => 'August';

  @override
  String get chatDetailMonth9 => 'September';

  @override
  String get chatDetailMonth10 => 'October';

  @override
  String get chatDetailMonth11 => 'November';

  @override
  String get chatDetailMonth12 => 'December';

  @override
  String get chatDetailOnline => 'Online';

  @override
  String chatDetailLastSeenToday(String time) {
    return 'Last seen today at $time';
  }

  @override
  String chatDetailLastSeenYesterday(String time) {
    return 'Last seen yesterday at $time';
  }

  @override
  String chatDetailLastSeenOn(String date) {
    return 'Last seen: $date';
  }

  @override
  String chatDetailClubRoomMembers(String count) {
    return 'Club room · $count members';
  }

  @override
  String chatDetailEventRoomMembers(String count) {
    return 'Event room · $count members';
  }

  @override
  String chatDetailMembersCount(String count) {
    return '$count members';
  }

  @override
  String get chatDetailClubEventRoom => 'Club/event room';

  @override
  String get chatDetailResend => 'Resend';

  @override
  String get chatDetailReply => 'Reply';

  @override
  String get chatDetailCopy => 'Copy';

  @override
  String get chatDetailForward => 'Forward';

  @override
  String get chatDetailEdit => 'Edit';

  @override
  String get chatDetailDeleteForAll => 'Delete for everyone';

  @override
  String get chatDetailDeleteMessage => 'Delete message';

  @override
  String get chatDetailReport => 'Report';

  @override
  String get chatDetailCopied => 'Copied';

  @override
  String get chatDetailForwarded => 'Forwarded';

  @override
  String get chatDetailForwardFailedAll => 'Could not be forwarded';

  @override
  String chatDetailForwardFailedSome(String count) {
    return 'Could not forward to $count chats';
  }

  @override
  String get chatDetailSearchInChat => 'Search in chat';

  @override
  String get chatDetailClubPage => 'Club page';

  @override
  String get chatDetailEventPage => 'Event page';

  @override
  String get chatDetailMembers => 'Members';

  @override
  String get chatDetailMedia => 'Media';

  @override
  String get chatDetailSettings => 'Settings';

  @override
  String get chatDetailLeaveChat => 'Leave chat';

  @override
  String get chatDetailBlock => 'Block';

  @override
  String get chatDetailUnblock => 'Unblock';

  @override
  String get chatDetailReportUser => 'Report user';

  @override
  String get chatDetailLeaveTitle => 'Leave this chat?';

  @override
  String get chatDetailLeaveBody => 'You will leave this chat.';

  @override
  String get chatDetailLeave => 'Leave';

  @override
  String get chatDetailBlockTitle => 'Block this user?';

  @override
  String get chatDetailBlockBody =>
      'You cannot message someone you have blocked.';

  @override
  String get chatDetailUserBlocked => 'User blocked';

  @override
  String get chatDetailUserUnblocked => 'User unblocked';

  @override
  String chatDetailMembersTitle(String count) {
    return 'Members ($count)';
  }

  @override
  String get chatDetailMembersLoadFailed =>
      'The member list could not be loaded.';

  @override
  String get chatDetailAdmin => 'Admin';

  @override
  String get chatDetailBack => 'Back';

  @override
  String get chatDetailOpenProfile => 'Open profile';

  @override
  String get chatDetailChatInfo => 'Chat info';

  @override
  String get chatDetailTyping => 'typing…';

  @override
  String get chatDetailMenu => 'Menu';

  @override
  String get chatDetailCloseSearch => 'Close search';

  @override
  String get chatDetailTypeToSearch => 'Type to search';

  @override
  String get chatDetailNoMatch => 'No matches';

  @override
  String get chatDetailPrevMatch => 'Previous match';

  @override
  String get chatDetailNextMatch => 'Next match';

  @override
  String get chatDetailSearching => 'Searching…';

  @override
  String get chatDetailSearchOlder => 'Search older messages';

  @override
  String get chatDetailEmpty => 'No messages yet. Write the first one.';

  @override
  String get chatDetailScrollDown => 'Scroll to bottom';

  @override
  String chatDetailScrollDownNew(String count) {
    return 'Scroll to bottom, $count new messages';
  }

  @override
  String get chatDetailEditing => 'Editing message';

  @override
  String get chatDetailAdd => 'Add';

  @override
  String get chatDetailWriteMessage => 'Write a message';

  @override
  String get chatDetailCamera => 'Camera';

  @override
  String get chatDetailSave => 'Save';

  @override
  String get chatDetailSend => 'Send';

  @override
  String get chatDetailClose => 'Close';

  @override
  String chatDetailReactionLabel(String emoji) {
    return 'Reaction $emoji';
  }

  @override
  String get chatInfoUnmute => 'Unmute';

  @override
  String get chatInfoMute => 'Mute';

  @override
  String get chatInfoUnarchive => 'Unarchive';

  @override
  String get chatInfoArchive => 'Archive';

  @override
  String get chatInfoDelete => 'Delete';

  @override
  String get chatInfoCancel => 'Cancel';

  @override
  String get chatInfoSave => 'Save';

  @override
  String get chatInfoMute8h => '8 hours';

  @override
  String get chatInfoMute1w => '1 week';

  @override
  String get chatInfoMuteForever => 'Always';

  @override
  String get chatInfoDeleteConvTitle => 'Delete this chat?';

  @override
  String get chatInfoDeleteConvGroup =>
      'You will leave the group and delete this chat.';

  @override
  String get chatInfoDeleteConvDirect =>
      'This chat will be deleted only for you. The other person is not affected.';

  @override
  String get chatInfoUser => 'User';

  @override
  String get chatInfoYou => 'You';

  @override
  String get chatInfoAdmin => 'Admin';

  @override
  String get chatInfoRemoveFromGroup => 'Remove from group';

  @override
  String chatInfoMembersCount(String n) {
    return 'Members ($n)';
  }

  @override
  String get chatInfoSearchMember => 'Search members';

  @override
  String get chatInfoNoResults => 'No results.';

  @override
  String get chatInfoOpenVideo => 'Open video';

  @override
  String get chatInfoOpenImage => 'Open image';

  @override
  String get chatInfoMedia => 'Media';

  @override
  String get chatInfoRetry => 'Try again';

  @override
  String get chatInfoChat => 'Chat';

  @override
  String get chatInfoGroup => 'Group';

  @override
  String get chatInfoUnmuted => 'Notifications unmuted';

  @override
  String get chatInfoMuted => 'Chat muted';

  @override
  String get chatInfoUnarchived => 'Chat unarchived';

  @override
  String get chatInfoArchived => 'Chat archived';

  @override
  String get chatInfoLeaveTitle => 'Leave this chat?';

  @override
  String get chatInfoLeaveBody => 'You will leave this chat.';

  @override
  String get chatInfoLeave => 'Leave';

  @override
  String get chatInfoUnblocked => 'User unblocked';

  @override
  String get chatInfoBlockTitle => 'Block this user?';

  @override
  String get chatInfoBlockBody =>
      'You cannot message someone you have blocked.';

  @override
  String get chatInfoBlock => 'Block';

  @override
  String get chatInfoBlocked => 'User blocked';

  @override
  String get chatInfoUnblock => 'Unblock';

  @override
  String get chatInfoReportUser => 'Report user';

  @override
  String get chatInfoReport => 'Report';

  @override
  String get chatInfoRemoveMemberTitle => 'Remove member?';

  @override
  String chatInfoRemoveMemberBody(String name) {
    return '$name will be removed from the group.';
  }

  @override
  String get chatInfoRemove => 'Remove';

  @override
  String get chatInfoPickGallery => 'Choose from gallery';

  @override
  String get chatInfoRemovePhoto => 'Remove photo';

  @override
  String get chatInfoImageTooLarge =>
      'Image is too large, choose a smaller one.';

  @override
  String get chatInfoImageTypeOnly =>
      'Only JPEG, PNG or WebP images are allowed.';

  @override
  String get chatInfoTitle => 'Chat info';

  @override
  String get chatInfoNoMembers => 'No member list.';

  @override
  String get chatInfoClubRoom => 'Club room';

  @override
  String get chatInfoEventRoom => 'Event room';

  @override
  String chatInfoMemberCount(String n) {
    return '$n members';
  }

  @override
  String get chatInfoChangePhoto => 'Change photo';

  @override
  String get chatInfoEditName => 'Edit name';

  @override
  String get chatInfoClub => 'Club';

  @override
  String get chatInfoEvent => 'Event';

  @override
  String get chatInfoSearch => 'Search';

  @override
  String get chatInfoMembers => 'Members';

  @override
  String chatInfoMembersDot(String n) {
    return 'Members · $n';
  }

  @override
  String get chatInfoNoMedia => 'No images in this chat yet.';

  @override
  String get chatInfoSeeAllMedia => 'See all media';

  @override
  String chatInfoMediaDot(String count) {
    return 'Media · $count';
  }

  @override
  String get chatInfoAll => 'All';

  @override
  String get chatInfoMuteOn => 'On';

  @override
  String get chatInfoMutedAlways => 'Muted · always';

  @override
  String chatInfoMutedDays(String n) {
    return 'Muted · unmutes in $n days';
  }

  @override
  String chatInfoMutedHours(String n) {
    return 'Muted · unmutes in $n hours';
  }

  @override
  String get chatInfoMutedSoon => 'Muted · unmutes soon';

  @override
  String get chatInfoMutedLabel => 'Muted';

  @override
  String get chatInfoOpenClubPage => 'Open club page';

  @override
  String get chatInfoOpenEventPage => 'Open event page';

  @override
  String get chatInfoViewProfile => 'View profile';

  @override
  String get chatInfoMuteNotifications => 'Mute notifications';

  @override
  String get chatInfoClosed => 'This chat is closed';

  @override
  String get chatInfoClosedSub => 'New messages cannot be sent';

  @override
  String get chatInfoLeaveChat => 'Leave chat';

  @override
  String get chatInfoSettings => 'Settings';

  @override
  String get chatInfoGroupName => 'Group name';

  @override
  String get chatMiscFilterAll => 'All';

  @override
  String get chatMiscFilterPeople => 'People';

  @override
  String get chatMiscFilterClubs => 'Clubs';

  @override
  String get chatMiscFilterEvents => 'Events';

  @override
  String get chatMiscArchived => 'Chat archived';

  @override
  String get chatMiscUnarchived => 'Chat removed from archive';

  @override
  String get chatMiscChat => 'Chat';

  @override
  String get chatMiscArchive => 'Archive';

  @override
  String get chatMiscNewChat => 'New chat';

  @override
  String get chatMiscEmptyArchive => 'No chats in the archive';

  @override
  String get chatMiscEmptyNoMatch => 'No matching chats found';

  @override
  String get chatMiscEmptyNone => 'You have no chats yet';

  @override
  String get chatMiscUnarchiveAction => 'Unarchive';

  @override
  String get chatMiscArchiveAction => 'Archive';

  @override
  String get chatMiscSearchHint => 'Search people or groups';

  @override
  String get chatMiscTagClub => 'Club';

  @override
  String get chatMiscTagEvent => 'Event';

  @override
  String get chatMiscMessageDeleted => 'Message deleted';

  @override
  String get chatMiscOnceText => 'Photo (view once)';

  @override
  String get chatMiscImage => 'Image';

  @override
  String get chatMiscDayMon => 'Mon';

  @override
  String get chatMiscDayTue => 'Tue';

  @override
  String get chatMiscDayWed => 'Wed';

  @override
  String get chatMiscDayThu => 'Thu';

  @override
  String get chatMiscDayFri => 'Fri';

  @override
  String get chatMiscDaySat => 'Sat';

  @override
  String get chatMiscDaySun => 'Sun';

  @override
  String get chatMiscYesterday => 'Yesterday';

  @override
  String chatMiscSendFailedRetry(String error) {
    return '$error · Retry';
  }

  @override
  String get chatMiscSendFailed => 'Failed to send';

  @override
  String get chatMiscThisMessageDeleted => 'This message was deleted';

  @override
  String get chatMiscVideo => 'Video';

  @override
  String get chatMiscPhoto => 'Photo';

  @override
  String get chatMiscUser => 'User';

  @override
  String get chatMiscStatusSending => 'Sending';

  @override
  String get chatMiscStatusSent => 'Sent';

  @override
  String get chatMiscStatusDelivered => 'Delivered';

  @override
  String get chatMiscStatusRead => 'Read';

  @override
  String get chatMiscImageUnavailable => 'Image unavailable';

  @override
  String chatMiscVideoWithDuration(String duration) {
    return 'Video, $duration';
  }

  @override
  String get chatMiscClose => 'Close';

  @override
  String get chatMiscImageLoadFailed => 'The image could not be loaded.';

  @override
  String get chatMiscOnceOpened => 'Opened';

  @override
  String get chatMiscOnceSending => 'Photo · Sending';

  @override
  String get chatMiscOnceSent => 'Photo · Sent';

  @override
  String get chatMiscOnceTapToOpen => 'Photo · Tap to open';

  @override
  String chatMiscOnceSemantics(String label) {
    return 'View-once photo. $label';
  }

  @override
  String get chatMiscEdited => 'edited';

  @override
  String get chatMiscContactsFind => 'Find people from contacts';

  @override
  String get chatMiscContactsRationale =>
      'We need access to your contacts to find Bingöl University people among them. Your contacts are not sent to the server; only email hashes are matched.';

  @override
  String get chatMiscContactsSubtitle => 'Bingöl University people';

  @override
  String get chatMiscContactsPermTitle => 'Contacts permission required';

  @override
  String get chatMiscContactsPermText =>
      'You need to allow access to your contacts so we can find campus people among them.';

  @override
  String get chatMiscContactsPermAction => 'Allow';

  @override
  String get chatMiscContactsNoneTitle => 'No matching people';

  @override
  String get chatMiscContactsNoneText =>
      'None of your contacts use the app with a Bingöl University email. Your friends will appear here as they join.';

  @override
  String get chatMiscContactsSearchHint => 'Search contacts';

  @override
  String get chatMiscContactsTruncated =>
      'Hourly request limit reached; the remaining contacts will be matched later.';

  @override
  String get chatMiscContactsNoSearchMatch => 'No one matches your search.';

  @override
  String chatMiscContactsCount(String n) {
    return '$n PEOPLE';
  }

  @override
  String get chatMiscMessage => 'Message';

  @override
  String get chatMiscContactsPrivacy =>
      'Your contacts are not sent to the server; only email hashes are matched.';

  @override
  String get chatMiscGroupMax => 'A group can have at most 50 people.';

  @override
  String get chatMiscGroupNameRequired => 'Enter a group name.';

  @override
  String get chatMiscUserSearchHint => 'Search by name or email';

  @override
  String get chatMiscCreateGroup => 'Create group';

  @override
  String get chatMiscStartChat => 'Start chat';

  @override
  String get chatMiscGroupCardTitle => 'Create a group';

  @override
  String chatMiscSelectedCount(String n) {
    return '$n selected';
  }

  @override
  String get chatMiscGroupName => 'Group name';

  @override
  String get chatMiscMax50 => 'max 50';

  @override
  String get chatMiscSearchMin =>
      'Type at least 2 characters to search for people.';

  @override
  String get chatMiscNoMatchPeople => 'No matching people found.';

  @override
  String get chatMiscPeopleHeader => 'PEOPLE';

  @override
  String get chatMiscForward => 'Forward';

  @override
  String get chatMiscSearchChat => 'Search chats';

  @override
  String chatMiscForwardMax(String max) {
    return 'You can select up to $max chats.';
  }

  @override
  String get chatMiscSend => 'Send';

  @override
  String chatMiscSendCount(String n) {
    return 'Send ($n)';
  }

  @override
  String get chatMiscChatNotFound => 'No chats found.';

  @override
  String get chatMiscGalleryRationale =>
      'We need access permission to show the photos and videos in your gallery.';

  @override
  String get chatMiscVideoMax60 => 'Videos can be at most 60 seconds';

  @override
  String chatMiscPickMax(String max) {
    return 'You can select up to $max items';
  }

  @override
  String get chatMiscAll => 'All';

  @override
  String get chatMiscGallery => 'Gallery';

  @override
  String get chatMiscLimitedNote => 'Only the items you allowed are shown.';

  @override
  String get chatMiscSelectMore => 'Select more';

  @override
  String get chatMiscSettings => 'Settings';

  @override
  String get chatMiscGalleryDenied => 'Gallery access was not granted.';

  @override
  String get chatMiscOpenSettings => 'Open in Settings';

  @override
  String get chatMiscCamera => 'Camera';

  @override
  String chatMiscPreviewCount(String n) {
    return 'Preview ($n)';
  }

  @override
  String get chatMiscCameraRationale =>
      'We need camera access so you can take photos and videos.';

  @override
  String get chatMiscMicRationale =>
      'We need microphone access to record sound with your videos.';

  @override
  String get chatMiscPhotoFailed => 'The photo could not be taken.';

  @override
  String get chatMiscVideoSaveFailed => 'The video could not be saved.';

  @override
  String get chatMiscCameraUnavailable => 'The camera is unavailable.';

  @override
  String get chatMiscCameraHint => 'Tap: photo · Hold: video';

  @override
  String get chatMiscFlipCamera => 'Flip camera';

  @override
  String get chatMiscOnceToast =>
      'View once: the recipient can see it only one time';

  @override
  String get chatMiscAddCaption => 'Add a caption…';

  @override
  String get chatMiscOnceSendLabel => 'View once';

  @override
  String get chatMiscOnceGone => 'This photo can no longer be viewed.';

  @override
  String get chatMiscOnceOwn =>
      'You cannot open a view-once photo that you sent.';

  @override
  String get chatMiscOnceNetwork =>
      'The photo could not be loaded. Check your connection. Because it is view-once, it may not be possible to open it again.';

  @override
  String get chatMiscOnceShowFailed =>
      'The photo could not be displayed. Because it is view-once, it may not be possible to open it again.';

  @override
  String get chatMiscOnceTitle => 'View once';

  @override
  String get chatMiscRetry => 'Try again';

  @override
  String get chatMiscSaveUnsupported => 'Not supported on this device.';

  @override
  String get chatMiscSaveDenied => 'Gallery permission was not granted.';

  @override
  String get chatMiscSaveNoSpace => 'Not enough space on the device.';

  @override
  String get chatMiscImageSaveFailed => 'The image could not be saved.';

  @override
  String get chatMiscSavedToGallery => 'Saved to gallery';

  @override
  String get chatMiscDownload => 'Download';

  @override
  String get chatMiscPlayVideo => 'Play video';

  @override
  String get chatMiscVideoPlayFailed => 'The video could not be played';

  @override
  String get clubWithdrawTitle => 'Withdraw request';

  @override
  String get clubWithdrawMessage => 'Withdraw your join request?';

  @override
  String get clubWithdrawConfirm => 'Withdraw';

  @override
  String get clubImageTooLarge => 'The image is too large.';

  @override
  String get clubImageUnsupported =>
      'Only JPEG, PNG or WebP images can be uploaded.';

  @override
  String get clubImageUnreadable => 'The image could not be read.';

  @override
  String get clubImagePickFailed => 'Could not select the image.';

  @override
  String get clubImageUploadFailed => 'The image could not be uploaded.';

  @override
  String get clubDeleted => 'Club deleted.';

  @override
  String get clubChatClosed => 'The club chat is currently closed.';

  @override
  String get clubChatPreparing =>
      'The club chat is being prepared, try again shortly.';

  @override
  String get clubChat => 'Club chat';

  @override
  String get clubDeletePostTitle => 'Delete post';

  @override
  String get clubDeletePostMessage => 'Delete this post permanently?';

  @override
  String get clubCancel => 'Cancel';

  @override
  String get clubDelete => 'Delete';

  @override
  String get clubReportClub => 'Report club';

  @override
  String get clubReportPost => 'Report post';

  @override
  String clubMemberCount(String count) {
    return '$count members';
  }

  @override
  String get clubPrivate => 'Private';

  @override
  String get clubPublic => 'Public';

  @override
  String get clubTitle => 'Club';

  @override
  String get clubBack => 'Back';

  @override
  String get clubOptions => 'Club options';

  @override
  String get clubEdit => 'Edit club';

  @override
  String clubRequestsWithCount(String count) {
    return 'Applications ($count)';
  }

  @override
  String get clubRequests => 'Applications';

  @override
  String get clubManageMembers => 'Manage members';

  @override
  String get clubChangeCover => 'Change cover';

  @override
  String get clubDeleteClub => 'Delete club';

  @override
  String get clubLeave => 'Leave club';

  @override
  String get clubIsMember => 'Member';

  @override
  String get clubRequestSent => 'Request sent';

  @override
  String get clubCannotJoin => 'Cannot join';

  @override
  String get clubSendJoinRequest => 'Send join request';

  @override
  String get clubJoin => 'Join';

  @override
  String get clubTabPosts => 'Posts';

  @override
  String get clubTabEvents => 'Events';

  @override
  String get clubTabMembers => 'Members';

  @override
  String get clubTabPolls => 'Polls';

  @override
  String get clubNoPosts => 'No posts yet.';

  @override
  String get clubNoEvents => 'This club has no upcoming events.';

  @override
  String get clubNoMembers => 'No members found.';

  @override
  String get clubLoadFailedRetry => 'Failed to load, try again';

  @override
  String get clubWriteHint => 'Write something to the club';

  @override
  String get clubAddImage => 'Add image';

  @override
  String get clubShare => 'Share';

  @override
  String get clubRemoveImage => 'Remove image';

  @override
  String get clubPendingRequests => 'Pending applications';

  @override
  String get clubPostActions => 'Post actions';

  @override
  String get clubUnpin => 'Unpin';

  @override
  String get clubPin => 'Pin';

  @override
  String get clubReport => 'Report';

  @override
  String get clubPinned => 'Pinned';

  @override
  String get clubUser => 'User';

  @override
  String get clubRoleOwner => 'Owner';

  @override
  String get clubRoleModerator => 'Moderator';

  @override
  String get clubDeleteBody =>
      'Members, events and the chat will be deleted. This cannot be undone.';

  @override
  String clubDeleteTypeName(String name) {
    return 'Type the club name to confirm: $name';
  }

  @override
  String get clubNameHint => 'Club name';

  @override
  String get clubOwnerCannotLeave =>
      'The club owner cannot leave. Transfer ownership or delete the club first.';

  @override
  String get clubCannotLeaveTitle => 'You cannot leave the club';

  @override
  String get clubOk => 'OK';

  @override
  String get clubThisClub => 'this club';

  @override
  String clubLeaveMessage(String name) {
    return 'Do you want to leave $name? You will also be removed from the club chat and it will disappear from your chat list.';
  }

  @override
  String get clubLeaveConfirm => 'Leave';

  @override
  String get clubMgmtJoinTitle => 'Join request';

  @override
  String clubMgmtJoinAdminsSee(String club) {
    return 'The admins of $club will see your answers.';
  }

  @override
  String get clubMgmtAnswerHint => 'Your answer';

  @override
  String get clubMgmtQuestionRequired => 'This question is required';

  @override
  String get clubMgmtCancel => 'Cancel';

  @override
  String get clubMgmtSendRequest => 'Send request';

  @override
  String get clubMgmtNoPending => 'No pending applications.';

  @override
  String get clubMgmtMoreRequests => 'More applications';

  @override
  String get clubMgmtRequestsTitle => 'Applications';

  @override
  String clubMgmtWaitingCount(String count) {
    return '$count waiting';
  }

  @override
  String get clubMgmtUser => 'User';

  @override
  String get clubMgmtReject => 'Reject';

  @override
  String get clubMgmtApprove => 'Approve';

  @override
  String get clubMgmtBan => 'Ban';

  @override
  String get clubMgmtRemoveFromClub => 'Remove from club';

  @override
  String clubMgmtBanMessage(String name) {
    return 'Remove $name from the club and prevent them from joining again?';
  }

  @override
  String clubMgmtRemoveMessage(String name) {
    return 'Remove $name from the club? They will also leave the club chat.';
  }

  @override
  String get clubMgmtRemoveConfirm => 'Remove';

  @override
  String get clubMgmtNoMembers => 'No members found.';

  @override
  String get clubMgmtMembersTitle => 'Members';

  @override
  String get clubMgmtSearchMember => 'Search members';

  @override
  String get clubMgmtRoleManager => 'Manager';

  @override
  String get clubMgmtRoleModerator => 'Moderator';

  @override
  String get clubMgmtMemberActions => 'Member actions';

  @override
  String get clubMgmtMakeModerator => 'Make moderator';

  @override
  String get clubMgmtMakeMember => 'Make member';

  @override
  String get clubMgmtPendingTitle => 'Your club was sent for approval';

  @override
  String get clubMgmtPendingBody =>
      'The club will go live once admins review it. You can follow its status in My Clubs.';

  @override
  String get clubMgmtOk => 'OK';

  @override
  String get clubMgmtImageTooLarge => 'The image is too large.';

  @override
  String get clubMgmtImageUnsupported =>
      'Only JPEG, PNG or WebP images can be uploaded.';

  @override
  String get clubMgmtImageUnreadable => 'The image could not be read.';

  @override
  String get clubMgmtImagePickFailed => 'Could not select the image.';

  @override
  String get clubMgmtNameMin => 'The club name must be at least 3 characters.';

  @override
  String get clubMgmtNameMax => 'The club name can be at most 80 characters.';

  @override
  String get clubMgmtDescMax =>
      'The description can be at most 1000 characters.';

  @override
  String get clubMgmtCategoryMax =>
      'The category can be at most 40 characters.';

  @override
  String get clubMgmtSavedWithWarning =>
      'The club was saved but the cover or join questions could not be saved.';

  @override
  String get clubMgmtEditTitle => 'Edit club';

  @override
  String get clubMgmtCreateTitle => 'Create a club';

  @override
  String get clubMgmtNameLabel => 'Club name';

  @override
  String get clubMgmtNameHint => 'e.g. Robotics Club';

  @override
  String get clubMgmtDescLabel => 'Short description';

  @override
  String get clubMgmtDescHint => 'What does the club do?';

  @override
  String get clubMgmtCategoryLabel => 'Category';

  @override
  String get clubMgmtCategoryHint => 'Pick from the list or type (optional)';

  @override
  String get clubMgmtVisibility => 'Visibility';

  @override
  String get clubMgmtPublic => 'Public';

  @override
  String get clubMgmtPrivate => 'Private';

  @override
  String get clubMgmtPrivateHint =>
      'Only members see the club content; joining requires approval.';

  @override
  String get clubMgmtPublicHint => 'The club appears in the Discover list.';

  @override
  String get clubMgmtJoinLabel => 'Joining';

  @override
  String get clubMgmtOpenPolicy => 'Open';

  @override
  String get clubMgmtApprovalPolicy => 'Approval';

  @override
  String get clubMgmtApprovalHint =>
      'People who want to join send an application and you approve it.';

  @override
  String get clubMgmtOpenHint => 'Anyone can join directly.';

  @override
  String clubMgmtQuestionsLabel(String max) {
    return 'Join questions (up to $max)';
  }

  @override
  String clubMgmtQuestionHint(String n) {
    return 'Question $n';
  }

  @override
  String get clubMgmtRemoveQuestion => 'Remove question';

  @override
  String get clubMgmtAddQuestion => 'Add question';

  @override
  String get clubMgmtSave => 'Save';

  @override
  String get clubMgmtCreateButton => 'Create club';

  @override
  String get clubMgmtChangeCover => 'Change cover';

  @override
  String get clubMgmtAddCover => 'Add a cover (optional)';

  @override
  String get clubMgmtClubsTitle => 'Clubs';

  @override
  String get clubMgmtSearch => 'Search';

  @override
  String get clubMgmtSearchClub => 'Search clubs';

  @override
  String get clubMgmtTabDiscover => 'Discover';

  @override
  String get clubMgmtTabMine => 'My Clubs';

  @override
  String get clubMgmtAll => 'All';

  @override
  String get clubMgmtEmptyMine => 'You are not a member of any club yet.';

  @override
  String get clubMgmtNotFound => 'No clubs found.';

  @override
  String clubMgmtMemberCount(String count) {
    return '$count members';
  }

  @override
  String get clubMgmtYouAreMember => 'Member';

  @override
  String get clubMgmtRequestSent => 'Request sent';

  @override
  String get clubMgmtBanned => 'Banned';

  @override
  String get clubMgmtJoin => 'Join';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSearchHint => 'Search';

  @override
  String get commonJustNow => 'just now';

  @override
  String commonMinutesAgo(String n) {
    return '$n min ago';
  }

  @override
  String commonHoursAgo(String n) {
    return '$n h ago';
  }

  @override
  String commonDaysAgo(String n) {
    return '$n d ago';
  }

  @override
  String commonLongDate(String day, String month, String weekday) {
    return '$weekday, $month $day';
  }

  @override
  String get commonTypeNews => 'News';

  @override
  String get commonTypeAnnouncement => 'Announcement';

  @override
  String get commonTypeEvent => 'Event';

  @override
  String get commonMonth1 => 'January';

  @override
  String get commonMonth2 => 'February';

  @override
  String get commonMonth3 => 'March';

  @override
  String get commonMonth4 => 'April';

  @override
  String get commonMonth5 => 'May';

  @override
  String get commonMonth6 => 'June';

  @override
  String get commonMonth7 => 'July';

  @override
  String get commonMonth8 => 'August';

  @override
  String get commonMonth9 => 'September';

  @override
  String get commonMonth10 => 'October';

  @override
  String get commonMonth11 => 'November';

  @override
  String get commonMonth12 => 'December';

  @override
  String get commonWeekday1 => 'Monday';

  @override
  String get commonWeekday2 => 'Tuesday';

  @override
  String get commonWeekday3 => 'Wednesday';

  @override
  String get commonWeekday4 => 'Thursday';

  @override
  String get commonWeekday5 => 'Friday';

  @override
  String get commonWeekday6 => 'Saturday';

  @override
  String get commonWeekday7 => 'Sunday';

  @override
  String get reportReasonSpam => 'Spam or advertising';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonImpersonation => 'Impersonation';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportTitle => 'Report';

  @override
  String get reportMessageTitle => 'Report message';

  @override
  String get reportThanks => 'Your report has been received. Thank you.';

  @override
  String get reportPrompt =>
      'Choose a reason. Your report is sent to the administrators.';

  @override
  String get reportDetailsHint => 'Additional details (optional)';

  @override
  String get reportSend => 'Send';

  @override
  String get permNotificationsTitle => 'Notifications';

  @override
  String get permNotificationsText =>
      'Allow us to send notifications so you hear instantly about messages, events and announcements.';

  @override
  String get permContactsTitle => 'Contacts';

  @override
  String get permContactsText =>
      'Needed to find Bingöl University people in your contacts and start chats. Your contacts are not sent to the server.';

  @override
  String get permCameraTitle => 'Camera';

  @override
  String get permCameraText =>
      'We need camera access to scan QR codes and take photos.';

  @override
  String get permMicrophoneTitle => 'Microphone';

  @override
  String get permMicrophoneText =>
      'We need microphone access so you can record audio and video.';

  @override
  String get permPhotosTitle => 'Photos';

  @override
  String get permPhotosText =>
      'We need access to your gallery so you can pick and share photos.';

  @override
  String get permContinue => 'Continue';

  @override
  String get permNotNow => 'Not now';

  @override
  String permDeniedText(String title) {
    return '$title permission was not granted, so this feature is unavailable. You can enable it under Settings > BÜ Kampüs.';
  }

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permClose => 'Close';

  @override
  String get permPageTitle => 'A few permissions';

  @override
  String get permPageIntro =>
      'We ask for the permissions below so you can get the most out of the app. You do not have to grant any of them now; you can change them later in Settings.';

  @override
  String get permStart => 'Get started';

  @override
  String get permGranted => 'Granted';

  @override
  String get permDenied => 'Denied';

  @override
  String get permRetry => 'Try again';

  @override
  String get permAllow => 'Allow';

  @override
  String get coreErrNetwork =>
      'Could not reach the server. Check your connection.';

  @override
  String get coreErrTooMany => 'Too many attempts. Please wait a moment.';

  @override
  String get coreErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get coreIdEmpty => 'Enter your student number or email address.';

  @override
  String get coreIdDomain => 'Only bingol.edu.tr addresses can be used.';

  @override
  String get coreIdNumber => 'Check your student number.';

  @override
  String get coreOffline => 'Offline';

  @override
  String get coreMaintenance => 'The system is under maintenance.';

  @override
  String get coreOpen => 'Open';

  @override
  String get eventFormJoinFull =>
      'The event is full. You can stay in the loop with \"Interested\".';

  @override
  String get eventFormLeaveTitle => 'Leave event';

  @override
  String get eventFormLeaveMessage =>
      'This event will be removed from your My events list.';

  @override
  String get eventFormLeaveConfirm => 'Leave';

  @override
  String get eventFormRegsClosedToast => 'Registrations closed.';

  @override
  String get eventFormRegsReopenedToast => 'Registrations reopened.';

  @override
  String get eventFormCancelTitle => 'Cancel event';

  @override
  String get eventFormCancelMessage =>
      'This event will be cancelled for all attendees.';

  @override
  String get eventFormCancelAction => 'Cancel event';

  @override
  String get eventFormCancelledToast => 'Event cancelled.';

  @override
  String get eventFormScanTitle => 'Scan the check-in QR code';

  @override
  String get eventFormWrongEventCode =>
      'This code belongs to a different event.';

  @override
  String get eventFormCheckedIn => 'You are checked in';

  @override
  String get eventFormChatSoon => 'Event chat coming soon';

  @override
  String get eventFormEventTitle => 'Event';

  @override
  String get eventFormNotFound => 'Event not found';

  @override
  String get eventFormRegsClosed => 'Registrations closed';

  @override
  String get eventFormJoin => 'Join';

  @override
  String get eventFormInterested => 'Interested';

  @override
  String get eventFormBack => 'Back';

  @override
  String get eventFormManage => 'Manage';

  @override
  String get eventFormEdit => 'Edit';

  @override
  String get eventFormReopenRegs => 'Reopen registrations';

  @override
  String get eventFormCloseRegs => 'Close registrations';

  @override
  String get eventFormReport => 'Report';

  @override
  String get eventFormReportEvent => 'Report event';

  @override
  String get eventFormCancelledPill => 'Cancelled';

  @override
  String get eventFormInMine => 'In my events';

  @override
  String get eventFormOrganizedBy => 'Organized by:';

  @override
  String get eventFormCapacityFull => 'Event is full';

  @override
  String eventFormCapacityCount(String going, String cap) {
    return 'Capacity: $going / $cap';
  }

  @override
  String get eventFormGoingLabel => 'going';

  @override
  String get eventFormInterestedLabel => 'interested';

  @override
  String get eventFormInterestedShort => 'Interested';

  @override
  String get eventFormFullHint =>
      'The event is full; you can still mark yourself as interested.';

  @override
  String get eventFormChat => 'Event chat';

  @override
  String get eventFormManageJoin => 'Manage attendance';

  @override
  String get eventFormCheckInLater => 'Check-in opens at the event time.';

  @override
  String get eventFormScanQr => 'Scan QR code';

  @override
  String get eventFormEnterCode => 'Enter code manually';

  @override
  String get eventFormEnterOrganizerCode =>
      'Enter the code shown by the organizer';

  @override
  String get eventFormCheckInCode => 'Check-in code';

  @override
  String get eventFormSendCheckIn => 'Submit check-in';

  @override
  String get eventFormCodePreparing => 'Preparing code…';

  @override
  String get eventFormCodeFailed => 'Could not get the code.';

  @override
  String get eventFormQrHelp => 'Attendees scan this QR code in the app.';

  @override
  String get eventFormCodeShortLived => 'The code is valid for a short time.';

  @override
  String eventFormCodeExpires(String time) {
    return 'Expires: $time · code refreshes automatically';
  }

  @override
  String get eventFormRefreshCode => 'Refresh code';

  @override
  String get eventFormNoAttendance => 'No check-ins yet';

  @override
  String eventFormAttendanceCount(String present, String total) {
    return 'Check-in: $present / $total attended';
  }

  @override
  String get eventFormAttendees => 'Attendees';

  @override
  String get eventFormShowMore => 'Show more';

  @override
  String eventFormCoverCreatedFail(String reason) {
    return 'Event created, but the cover could not be uploaded.$reason';
  }

  @override
  String eventFormCoverFail(String reason) {
    return 'Could not upload the cover.$reason';
  }

  @override
  String get eventFormRetry => 'Try again';

  @override
  String get eventFormPickGallery => 'Choose from gallery';

  @override
  String get eventFormTakePhoto => 'Take a photo';

  @override
  String get eventFormImgTooLarge =>
      'The image is too large, choose a smaller one.';

  @override
  String get eventFormImgUnsupported =>
      'Only JPEG, PNG or WebP images can be uploaded.';

  @override
  String get eventFormImgUnreadable => 'Could not read the image.';

  @override
  String get eventFormImgPickFail =>
      'Could not pick the image. Check permissions.';

  @override
  String get eventFormTitleTooShort => 'Title must be at least 3 characters.';

  @override
  String get eventFormEndBeforeStart => 'End must be after the start.';

  @override
  String get eventFormCapInvalid => 'Capacity must be a number of 1 or more.';

  @override
  String eventFormCoverRemoveFail(String reason) {
    return 'Could not remove the cover. $reason';
  }

  @override
  String get eventFormCreated => 'Event created.';

  @override
  String get eventFormEditTitle => 'Edit event';

  @override
  String get eventFormNewTitle => 'New event';

  @override
  String get eventFormFieldTitle => 'Title';

  @override
  String get eventFormTitleHint => 'Event title';

  @override
  String get eventFormFieldDesc => 'Description';

  @override
  String get eventFormDescHint => 'A short note about the event';

  @override
  String get eventFormStart => 'Start';

  @override
  String get eventFormStartSem => 'Start time';

  @override
  String get eventFormEnd => 'End';

  @override
  String get eventFormEndSem => 'End time';

  @override
  String get eventFormPlace => 'Venue';

  @override
  String get eventFormPlaceHint => 'e.g. Conference Hall';

  @override
  String get eventFormCapacityLabel => 'Capacity';

  @override
  String get eventFormCapHint => 'Leave empty for unlimited';

  @override
  String get eventFormSave => 'Save';

  @override
  String get eventFormCreate => 'Create event';

  @override
  String get eventFormAddCover => 'Add cover photo';

  @override
  String get eventFormChangeCover => 'Change cover';

  @override
  String get eventFormRemoveCover => 'Remove cover';

  @override
  String get eventListTitle => 'Events';

  @override
  String get eventListCreate => 'Create event';

  @override
  String get eventListCheckin => 'Check-in';

  @override
  String get eventListTabDiscover => 'Discover';

  @override
  String get eventListTabMine => 'My events';

  @override
  String get eventListTabCreated => 'Created by me';

  @override
  String get eventListLoading => 'Loading';

  @override
  String get eventListPrevMonth => 'Previous month';

  @override
  String get eventListNextMonth => 'Next month';

  @override
  String eventListMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String eventListLongDate(String day, String month, String weekday) {
    return '$weekday, $month $day';
  }

  @override
  String get eventListFull =>
      'The event is full. You can stay in the loop with \"Interested\".';

  @override
  String get eventListLeaveTitle => 'Leave event';

  @override
  String get eventListLeaveMsg =>
      'This event will be removed from your My events list.';

  @override
  String get eventListLeave => 'Leave';

  @override
  String get eventListLeft => 'You left the event.';

  @override
  String get eventListClosedDone => 'Registration closed.';

  @override
  String get eventListReopenedDone => 'Registration reopened.';

  @override
  String get eventListCancelTitle => 'Cancel event';

  @override
  String get eventListCancelMsg =>
      'This event will be cancelled for all attendees.';

  @override
  String get eventListCancelConfirm => 'Cancel event';

  @override
  String get eventListCancelledDone => 'Event cancelled.';

  @override
  String get eventListScanTitle => 'Scan the check-in QR code';

  @override
  String get eventListNotCode => 'This is not a check-in code.';

  @override
  String get eventListCheckedIn => 'You are checked in.';

  @override
  String get eventListEmptyDay => 'No events for this day.';

  @override
  String get eventListEmptyMonth => 'No events this month.';

  @override
  String get eventListPastMonth => 'Past month: view only.';

  @override
  String get eventListTruncated =>
      'The whole month cannot be shown; some events are missing from the list.';

  @override
  String get eventListUpcoming => 'Upcoming';

  @override
  String get eventListPast => 'Past';

  @override
  String get eventListCreatedHint =>
      'You can manage the events you created here.';

  @override
  String get eventListEmptyUpcoming => 'You have no events to attend.';

  @override
  String get eventListEmptyPast => 'You have no past events.';

  @override
  String get eventListEmptyCreated => 'You have not created an event yet.';

  @override
  String get eventListDiscover => 'Discover events';

  @override
  String get eventListOfficial => 'Official';

  @override
  String get eventListCancelled => 'Cancelled';

  @override
  String get eventListRegClosedTag => 'Registration closed';

  @override
  String get eventListOpen => 'Open';

  @override
  String get eventListRegsClosed => 'Registration closed';

  @override
  String get eventListJoin => 'Join';

  @override
  String get eventListInterested => 'Interested';

  @override
  String get eventListGoing => 'going';

  @override
  String get eventListOptions => 'Options';

  @override
  String eventListAttendeeCount(String count) {
    return '$count attendees';
  }

  @override
  String get eventListAttendees => 'Attendees';

  @override
  String get eventListEdit => 'Edit';

  @override
  String get eventListReopen => 'Reopen registration';

  @override
  String get eventListClose => 'Close registration';

  @override
  String get eventListRegClosedError =>
      'Registration for this event is closed.';

  @override
  String get eventListAddedMine => 'Added to my events';

  @override
  String get eventListDismiss => 'Cancel';

  @override
  String get eventListInMine => 'In my events';

  @override
  String get eventListQrLabel => 'Check-in QR code';

  @override
  String get eventListMonth1 => 'January';

  @override
  String get eventListMonth2 => 'February';

  @override
  String get eventListMonth3 => 'March';

  @override
  String get eventListMonth4 => 'April';

  @override
  String get eventListMonth5 => 'May';

  @override
  String get eventListMonth6 => 'June';

  @override
  String get eventListMonth7 => 'July';

  @override
  String get eventListMonth8 => 'August';

  @override
  String get eventListMonth9 => 'September';

  @override
  String get eventListMonth10 => 'October';

  @override
  String get eventListMonth11 => 'November';

  @override
  String get eventListMonth12 => 'December';

  @override
  String get eventListMon1 => 'JAN';

  @override
  String get eventListMon2 => 'FEB';

  @override
  String get eventListMon3 => 'MAR';

  @override
  String get eventListMon4 => 'APR';

  @override
  String get eventListMon5 => 'MAY';

  @override
  String get eventListMon6 => 'JUN';

  @override
  String get eventListMon7 => 'JUL';

  @override
  String get eventListMon8 => 'AUG';

  @override
  String get eventListMon9 => 'SEP';

  @override
  String get eventListMon10 => 'OCT';

  @override
  String get eventListMon11 => 'NOV';

  @override
  String get eventListMon12 => 'DEC';

  @override
  String get eventListDayShort1 => 'Mon';

  @override
  String get eventListDayShort2 => 'Tue';

  @override
  String get eventListDayShort3 => 'Wed';

  @override
  String get eventListDayShort4 => 'Thu';

  @override
  String get eventListDayShort5 => 'Fri';

  @override
  String get eventListDayShort6 => 'Sat';

  @override
  String get eventListDayShort7 => 'Sun';

  @override
  String get eventListDayLong1 => 'Monday';

  @override
  String get eventListDayLong2 => 'Tuesday';

  @override
  String get eventListDayLong3 => 'Wednesday';

  @override
  String get eventListDayLong4 => 'Thursday';

  @override
  String get eventListDayLong5 => 'Friday';

  @override
  String get eventListDayLong6 => 'Saturday';

  @override
  String get eventListDayLong7 => 'Sunday';

  @override
  String get homeGreetNight => 'Good night';

  @override
  String get homeGreetMorning => 'Good morning';

  @override
  String get homeGreetDay => 'Good day';

  @override
  String get homeGreetEvening => 'Good evening';

  @override
  String get homeEventLoadFailedToast => 'Could not load the event.';

  @override
  String get homeEventLoadFailedTitle => 'Could not load the event';

  @override
  String get homeQuotaFull => 'The event is full.';

  @override
  String get homeMaintenanceDefault => 'The system is under maintenance.';

  @override
  String get homeSourceUnreachable =>
      'The source site is currently unreachable; data may be out of date.';

  @override
  String get homeSearchHint => 'Search news, clubs, events';

  @override
  String get homeMyClubs => 'From my clubs';

  @override
  String get homeAll => 'All';

  @override
  String get homeAgenda => 'Latest';

  @override
  String get homeContentLoadFailed => 'Could not load content.';

  @override
  String get homeNoContent => 'No content yet.';

  @override
  String get homeMyProfile => 'My profile';

  @override
  String get homeFeaturedEvent => 'Featured event';

  @override
  String get homeNextEvent => 'Next event';

  @override
  String get homeNoUpcoming => 'No upcoming events';

  @override
  String get homeBrowseEvents => 'Browse events';

  @override
  String get homeOfficialEvent => 'Official event';

  @override
  String get homeMostAttended => 'Most attended';

  @override
  String homeGoingCount(String count) {
    return '$count people going';
  }

  @override
  String get homeBeFirst => 'Be the first to join';

  @override
  String get homeInMyEvents => 'In my events';

  @override
  String get homeFull => 'Full';

  @override
  String get homeRegClosed => 'Registration closed';

  @override
  String get homeJoin => 'Join';

  @override
  String get homeQuickEvent => 'Events';

  @override
  String get homeQuickFood => 'Meals';

  @override
  String get homeQuickSupport => 'Support';

  @override
  String get homeTodayMeal => 'Meal of the day';

  @override
  String get homeNoMenuToday => 'No menu for today';

  @override
  String get homeNewMessages => 'new messages';

  @override
  String get homeClubMemberships => 'club memberships';

  @override
  String homeMemberCount(String count) {
    return '$count members';
  }

  @override
  String get newsTypeNews => 'News';

  @override
  String get newsTypeAnnouncement => 'Announcement';

  @override
  String get newsTypeEvent => 'Event';

  @override
  String newsEventDateShort(String date) {
    return 'Event: $date';
  }

  @override
  String newsEventDate(String date) {
    return 'Event date: $date';
  }

  @override
  String get newsSaveRemove => 'Remove from favorites';

  @override
  String get newsSaveAdd => 'Add to favorites';

  @override
  String get newsLinkOpenFailed => 'Could not open the link.';

  @override
  String get newsFullContent => 'Open the source page for the full content.';

  @override
  String get newsOpenSource => 'Open on source page';

  @override
  String get newsMonth1 => 'January';

  @override
  String get newsMonth2 => 'February';

  @override
  String get newsMonth3 => 'March';

  @override
  String get newsMonth4 => 'April';

  @override
  String get newsMonth5 => 'May';

  @override
  String get newsMonth6 => 'June';

  @override
  String get newsMonth7 => 'July';

  @override
  String get newsMonth8 => 'August';

  @override
  String get newsMonth9 => 'September';

  @override
  String get newsMonth10 => 'October';

  @override
  String get newsMonth11 => 'November';

  @override
  String get newsMonth12 => 'December';

  @override
  String get newsDayLong1 => 'Monday';

  @override
  String get newsDayLong2 => 'Tuesday';

  @override
  String get newsDayLong3 => 'Wednesday';

  @override
  String get newsDayLong4 => 'Thursday';

  @override
  String get newsDayLong5 => 'Friday';

  @override
  String get newsDayLong6 => 'Saturday';

  @override
  String get newsDayLong7 => 'Sunday';

  @override
  String get newsDayShort1 => 'Mon';

  @override
  String get newsDayShort2 => 'Tue';

  @override
  String get newsDayShort3 => 'Wed';

  @override
  String get newsDayShort4 => 'Thu';

  @override
  String get newsDayShort5 => 'Fri';

  @override
  String get newsDayShort6 => 'Sat';

  @override
  String get newsDayShort7 => 'Sun';

  @override
  String get discoverSaved => 'Saved';

  @override
  String get discoverScopeLatest => 'New';

  @override
  String get discoverScopePopular => 'Popular';

  @override
  String get discoverScopeFollowing => 'Following';

  @override
  String get discoverScopeDepartment => 'My department';

  @override
  String get discoverNoSaved => 'You have not saved any news yet.';

  @override
  String get discoverNoCategory => 'No content in this category yet.';

  @override
  String get discoverDeptHint =>
      'Choose your department in your profile to see its posts here.';

  @override
  String get discoverDeptEmpty => 'No posts from your department yet.';

  @override
  String get discoverProfilePath => 'Profile > Edit profile';

  @override
  String get discoverPolls => 'Polls';

  @override
  String get discoverSearch => 'Search';

  @override
  String get discoverCompose => 'Create post';

  @override
  String get discoverPosts => 'Posts';

  @override
  String get discoverNews => 'News';

  @override
  String get discoverSourceMaint =>
      'The source site is under maintenance. Data may be out of date.';

  @override
  String get menuTitle => 'Meal menu';

  @override
  String get menuStale =>
      'The menu could not be updated; showing the last known menu.';

  @override
  String get menuPrevMonth => 'Previous month';

  @override
  String get menuNextMonth => 'Next month';

  @override
  String menuTodayLabel(String date) {
    return 'TODAY · $date';
  }

  @override
  String get menuNoMenuDay => 'No menu for this day.';

  @override
  String get menuNoMenuMonth =>
      'The menu for this month has not been published yet.';

  @override
  String get menuNoList => 'No menu.';

  @override
  String get menuPhotoLabel => 'Photo of the day menu';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifMarkAll => 'Mark all as read';

  @override
  String get notifEmpty => 'No notifications yet';

  @override
  String get notifUnread => 'Unread notification';

  @override
  String get notifGroupToday => 'TODAY';

  @override
  String get notifGroupYesterday => 'YESTERDAY';

  @override
  String get notifGroupOlder => 'EARLIER';

  @override
  String get notifNow => 'now';

  @override
  String notifMinAgo(String n) {
    return '$n min ago';
  }

  @override
  String notifHourAgo(String n) {
    return '$n h ago';
  }

  @override
  String notifDayAgo(String n) {
    return '$n days ago';
  }

  @override
  String get searchAll => 'All';

  @override
  String get searchClub => 'Club';

  @override
  String get searchPost => 'Post';

  @override
  String get searchPerson => 'Person';

  @override
  String searchClassYear(String n) {
    return 'Year $n';
  }

  @override
  String get searchUserDefault => 'User';

  @override
  String get searchHint => 'Search news, clubs, events, posts, people';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchPrompt =>
      'Type at least 2 characters to search news, announcements, clubs, events or people.';

  @override
  String get searchRecent => 'RECENT SEARCHES';

  @override
  String get searchClearRecent => 'Clear';

  @override
  String get searchNoResults => 'No results found.';

  @override
  String searchResultCount(String count) {
    return '$count RESULTS';
  }

  @override
  String get searchTooMany => 'Too many requests, please wait a few seconds.';

  @override
  String get followButtonUnfollow => 'Unfollow';

  @override
  String get followButtonFollow => 'Follow';

  @override
  String get followButtonFollowing => 'Following';

  @override
  String get followersTitle => 'Followers';

  @override
  String get followingTitle => 'Following';

  @override
  String get followersEmpty => 'No followers yet.';

  @override
  String get followingEmpty => 'Not following anyone yet.';

  @override
  String get followSuggestionsEmpty => 'No suggestions for now.';

  @override
  String get followSuggestionsTitle => 'Suggested people';

  @override
  String get followFeedHint => 'Posts from people you follow appear here.';

  @override
  String get followersCount => 'Followers';

  @override
  String get followingCount => 'Following';

  @override
  String get qrScanTitle => 'Scan QR code';

  @override
  String get qrCameraRationale => 'We need camera access to scan the QR code.';

  @override
  String get qrManualLabel => 'Enter code manually';

  @override
  String get qrConfirm => 'Confirm';

  @override
  String get qrCameraDenied =>
      'Camera permission was not granted. You can enter the code manually or grant permission and try scanning again.';

  @override
  String get qrGrantCamera => 'Grant camera permission';

  @override
  String get qrDeniedSettings =>
      'Camera permission was not granted. You can allow it in Settings > BÜ Kampüs or enter the code manually.';

  @override
  String get qrCameraFailed =>
      'The camera could not be opened. You can enter the code manually.';

  @override
  String get qrTorch => 'Flashlight';

  @override
  String get pollListTitle => 'Polls';

  @override
  String get pollClubPolls => 'Club polls';

  @override
  String get pollTabOpen => 'Open';

  @override
  String get pollTabMine => 'Joined';

  @override
  String get pollTabClosed => 'Closed';

  @override
  String get pollEmptyOpen => 'There are no open polls right now.';

  @override
  String get pollEmptyMine => 'You have not joined any poll yet.';

  @override
  String get pollEmptyClosed => 'There are no closed polls.';

  @override
  String get pollLoadFailedRetry => 'Could not load, try again';

  @override
  String get pollCreate => 'Create poll';

  @override
  String get pollClubEmpty => 'This club has no polls.';

  @override
  String get pollSeeAll => 'See all polls';

  @override
  String get pollMenuRateToday => 'Rate todays menu';

  @override
  String pollYourRating(String rating) {
    return 'Your rating: $rating';
  }

  @override
  String pollYourRatingAvg(String rating, String avg) {
    return 'Your rating: $rating · Average $avg';
  }

  @override
  String get pollTapStar => 'Tap a star to rate';

  @override
  String get pollNoVoteRight => 'You cannot vote in this poll';

  @override
  String pollStars(String n) {
    return '$n stars';
  }

  @override
  String pollSemPercent(String text, String pct) {
    return '$text, $pct percent';
  }

  @override
  String pollVotes(String votes) {
    return '$votes votes';
  }

  @override
  String pollVotesWithScore(String votes, String score) {
    return '$votes votes · $score points';
  }

  @override
  String get pollSemMine => 'your choice';

  @override
  String get pollTypeSingle => 'Single choice';

  @override
  String get pollTypeMulti => 'Multiple choice';

  @override
  String get pollTypeRating => 'Rating';

  @override
  String get pollTypeRanked => 'Ranked choice';

  @override
  String get pollAnonymous => 'Secret ballot';

  @override
  String get pollVotedBadge => 'You voted';

  @override
  String get pollClosedBadge => 'Closed';

  @override
  String pollParticipants(String n) {
    return '$n participants';
  }

  @override
  String pollParticipationOf(String v, String e) {
    return '$v / $e participated';
  }

  @override
  String pollSemPoll(String title) {
    return 'Poll: $title';
  }

  @override
  String get pollEnded => 'Ended';

  @override
  String pollDaysLeft(String n) {
    return '$n days left';
  }

  @override
  String pollHoursLeft(String n) {
    return '$n h left';
  }

  @override
  String pollMinutesLeft(String n) {
    return '$n min left';
  }

  @override
  String get pollBlockedNotEligible =>
      'You are not eligible to take part in this poll.';

  @override
  String get pollBlockedClosed =>
      'This poll is closed. Voting is not possible.';

  @override
  String get pollBlockedNotOpen => 'This poll has not opened yet.';

  @override
  String get pollBlockedAlreadyVoted =>
      'Your vote is saved; votes cannot be changed in this poll.';

  @override
  String get pollBlockedDefault => 'You cannot vote in this poll.';

  @override
  String get pollValTitle => 'A title is required.';

  @override
  String get pollValMin2 => 'Enter at least 2 options.';

  @override
  String get pollValMax12 => 'There can be at most 12 options.';

  @override
  String get pollValDistinct => 'Options must be different from each other.';

  @override
  String get pollValEnd => 'Choose an end time.';

  @override
  String get pollValFuture => 'The end time must be in the future.';

  @override
  String get pollErrClosed => 'This poll is closed.';

  @override
  String get pollErrAlreadyVoted => 'You have already voted in this poll.';

  @override
  String get pollErrForbidden => 'You do not have permission for this action.';

  @override
  String get pollErrNotFound => 'Poll not found.';

  @override
  String get pollErrInvalidVote => 'Invalid choice.';

  @override
  String get pollHeader => 'Poll';

  @override
  String get pollStale => 'Could not refresh; showing the last known data.';

  @override
  String get pollVoteSaved => 'Your vote has been saved.';

  @override
  String get pollVoteRetracted => 'Your vote has been withdrawn.';

  @override
  String get pollRetractTitle => 'Withdraw vote';

  @override
  String get pollRetractBody => 'Your vote will be deleted. Continue?';

  @override
  String get pollCancel => 'Cancel';

  @override
  String get pollRetractAction => 'Withdraw';

  @override
  String pollMaxChoicesSnack(String n) {
    return 'You can select at most $n options.';
  }

  @override
  String get pollSecretVote => 'Your vote is secret';

  @override
  String get pollResultsAfterClose =>
      'Results will be shown when the poll closes.';

  @override
  String get pollHintRanked =>
      'Tap in order of preference: the first one you tap is your top choice.';

  @override
  String pollHintMax(String n) {
    return 'Select at most $n options.';
  }

  @override
  String get pollHintMulti => 'You can select more than one option.';

  @override
  String get pollVoteUpdate => 'Update vote';

  @override
  String get pollVote => 'Vote';

  @override
  String get pollChangeVote => 'Change vote';

  @override
  String pollRatingCount(String n) {
    return '$n ratings';
  }

  @override
  String get pollFieldTitle => 'Title';

  @override
  String get pollTitleHint => 'e.g. New term president election';

  @override
  String get pollFieldDesc => 'Description (optional)';

  @override
  String get pollDescHint => 'A short description';

  @override
  String get pollFieldType => 'Type';

  @override
  String pollFieldOptions(String max) {
    return 'Options (2-$max)';
  }

  @override
  String pollOptionHint(String n) {
    return 'Option $n';
  }

  @override
  String get pollRemoveOption => 'Remove option';

  @override
  String get pollAddOption => 'Add option';

  @override
  String get pollAnonymousSub => 'Nobody can see who voted for what.';

  @override
  String get pollFieldEnd => 'End time';

  @override
  String pollDurDays(String n) {
    return '$n days';
  }

  @override
  String get pollPickDateTime => 'Pick date and time';

  @override
  String get pollChange => 'Change';

  @override
  String get pollPublish => 'Publish';

  @override
  String get postComposeErrBadResponse =>
      'Unexpected response from the server.';

  @override
  String get postComposeErrPrepare => 'Could not prepare the media.';

  @override
  String get postComposeErrImageTooLarge => 'The image is too large.';

  @override
  String get postComposeErrImageUnsupported =>
      'This image format is not supported.';

  @override
  String get postComposeErrImageUnreadable => 'The image could not be read.';

  @override
  String get postComposeErrNetwork => 'No connection, try again.';

  @override
  String get postComposeErrVideoTooLarge =>
      'The video is too large (40 MB max).';

  @override
  String get postComposeErrVideoTooLong => 'Videos can be 60 seconds at most.';

  @override
  String get postComposeErrVideoInvalid =>
      'This video format is not supported.';

  @override
  String get postComposeErrBlocked => 'This content cannot be shared.';

  @override
  String get postComposeErrMediaInvalid => 'Invalid media, upload it again.';

  @override
  String get postComposeErrProfanity =>
      'Inappropriate language is not allowed here. Please edit the text.';

  @override
  String get postComposeErrRate => 'You are posting too fast, wait a moment.';

  @override
  String get postComposeErrFileTooLarge => 'The file is too large.';

  @override
  String get postComposeErrGeneric => 'Something went wrong, try again.';

  @override
  String get postComposeErrVideoUnsupported =>
      'Video cannot be prepared on this device.';

  @override
  String get postComposeErrCancelled => 'Cancelled.';

  @override
  String get postComposeErrVideoFailed => 'The video could not be prepared.';

  @override
  String get postComposeEdit => 'Edit';

  @override
  String get postComposeDelete => 'Delete';

  @override
  String get postComposeViewProfile => 'View profile';

  @override
  String get postComposeReport => 'Report';

  @override
  String get postComposeBlockUser => 'Block this user';

  @override
  String get postComposeClose => 'Close';

  @override
  String get postComposeReportTitle => 'Report post';

  @override
  String get postComposeDeleteTitle => 'Delete this post?';

  @override
  String get postComposeDeleteBody => 'This action cannot be undone.';

  @override
  String get postComposeCancel => 'Cancel';

  @override
  String get postComposeDeleted => 'Post deleted';

  @override
  String get postComposeBlockTitle => 'Block this user?';

  @override
  String get postComposeBlockBody =>
      'You will not see posts from people you block and you cannot message them.';

  @override
  String get postComposeBlock => 'Block';

  @override
  String get postComposeBlocked => 'User blocked';

  @override
  String get postComposeEditTitle => 'Edit post';

  @override
  String get postComposeTextEmpty => 'The text cannot be empty.';

  @override
  String get postComposeProfanityFallback =>
      'The text contains inappropriate language.';

  @override
  String get postComposeHint => 'What is on your mind?';

  @override
  String get postComposeSave => 'Save';

  @override
  String get postComposeMore => 'More';

  @override
  String postComposeMaxMedia(String max) {
    return 'You can add up to $max media items';
  }

  @override
  String postComposeFailedCount(String count) {
    return '$count media items failed to upload. You can retry or remove them.';
  }

  @override
  String get postComposeInvalidRetry =>
      'Invalid media, it will be uploaded again. Tap Share once more.';

  @override
  String get postComposeNetworkDraftKept =>
      'No connection. Your draft is saved, try again.';

  @override
  String get postComposeShared => 'Shared';

  @override
  String get postComposeDiscardTitle => 'Discard the draft?';

  @override
  String get postComposeDiscardBody =>
      'Your text and selected media will be discarded.';

  @override
  String get postComposeContinue => 'Keep editing';

  @override
  String get postComposeDiscardDraft => 'Discard draft';

  @override
  String get postComposeNewPost => 'New post';

  @override
  String get postComposeShare => 'Share';

  @override
  String get postComposeDraftBanner => 'You have a saved draft.';

  @override
  String get postComposeRestoreDraft => 'Restore draft';

  @override
  String get postComposeRetry => 'Retry';

  @override
  String get postComposeRemoveFailed => 'Remove failed';

  @override
  String get postComposeRemove => 'Remove';

  @override
  String get postComposeGallery => 'Gallery';

  @override
  String get postComposeCamera => 'Camera';

  @override
  String get postComposeSaveUnsupported => 'Not supported on this device.';

  @override
  String get postComposeSaveDenied => 'Gallery permission was not granted.';

  @override
  String get postComposeSaveNoSpace => 'Not enough space on the device.';

  @override
  String get postComposeImageSaveFailed => 'The image could not be saved.';

  @override
  String get postComposeSavedToGallery => 'Saved to gallery';

  @override
  String get postComposeDownload => 'Download';

  @override
  String get postComposeImageLoadFailed => 'The image could not be loaded.';

  @override
  String get postComposeVideoPlayFailed => 'The video could not be played';

  @override
  String postComposeVideoOf(String n, String total) {
    return 'Video $n / $total';
  }

  @override
  String postComposePhotoOf(String n, String total) {
    return 'Photo $n / $total';
  }

  @override
  String postComposeVideoOfMore(String n, String total, String more) {
    return 'Video $n / $total, +$more more';
  }

  @override
  String postComposePhotoOfMore(String n, String total, String more) {
    return 'Photo $n / $total, +$more more';
  }

  @override
  String get postComposeVideo => 'Video';

  @override
  String get postComposePhoto => 'Photo';

  @override
  String get postComposePlayVideo => 'Play video';

  @override
  String get postComposeUnmute => 'Unmute';

  @override
  String get postComposeMute => 'Mute';

  @override
  String postComposeMentionAdd(String name) {
    return 'Add mention $name';
  }

  @override
  String postComposeTagAdd(String tag) {
    return 'Add tag $tag';
  }

  @override
  String postComposePostCount(String count) {
    return '$count posts';
  }

  @override
  String postComposeUserLabel(String name) {
    return 'User $name';
  }

  @override
  String postComposeTagLabel(String tag) {
    return 'Tag $tag';
  }

  @override
  String postComposeTagLabelCount(String tag, String count) {
    return 'Tag $tag, $count posts';
  }

  @override
  String postViewReplyingTo(String name) {
    return 'Replying to @$name';
  }

  @override
  String get postViewCancelReply => 'Cancel reply';

  @override
  String get postViewWriteReplyHint => 'Write your reply…';

  @override
  String get postViewWriteCommentHint => 'Write a comment…';

  @override
  String get postViewSend => 'Send';

  @override
  String get postViewAgoNow => 'now';

  @override
  String postViewAgoMin(String n) {
    return '${n}m';
  }

  @override
  String postViewAgoHour(String n) {
    return '${n}h';
  }

  @override
  String postViewAgoDay(String n) {
    return '${n}d';
  }

  @override
  String postViewAgoWeek(String n) {
    return '${n}w';
  }

  @override
  String postViewAgoYear(String n) {
    return '${n}y';
  }

  @override
  String postViewAgoMinFull(String n) {
    return '$n min ago';
  }

  @override
  String postViewAgoHourFull(String n) {
    return '$n h ago';
  }

  @override
  String postViewAgoDayFull(String n) {
    return '$n days ago';
  }

  @override
  String get postViewRepliesLoadFailed => 'Could not load replies · Retry';

  @override
  String postViewShowReplies(String n) {
    return 'Show $n replies';
  }

  @override
  String get postViewShowMoreReplies => 'Show more replies';

  @override
  String get postViewHideReplies => 'Hide replies';

  @override
  String get postViewCommentsLoadFailed => 'Could not load comments · Retry';

  @override
  String get postViewCommentsLoading => 'Loading comments';

  @override
  String get postViewEdit => 'Edit';

  @override
  String get postViewDelete => 'Delete';

  @override
  String get postViewReport => 'Report';

  @override
  String get postViewReportComment => 'Report comment';

  @override
  String get postViewDeleteCommentTitle => 'Delete this comment?';

  @override
  String get postViewCannotUndo => 'This action cannot be undone.';

  @override
  String get postViewCancelAction => 'Cancel';

  @override
  String get postViewCommentDeleted => 'This comment was deleted';

  @override
  String get postViewEdited => 'edited';

  @override
  String postViewProfileOf(String name) {
    return '$name profile';
  }

  @override
  String get postViewSendFailedRetryA11y => 'Failed to send, retry';

  @override
  String get postViewSendFailedRetry => 'Failed to send · Retry';

  @override
  String get postViewRemove => 'Remove';

  @override
  String get postViewSending => 'Sending…';

  @override
  String postViewReplyToA11y(String name) {
    return 'Reply to $name';
  }

  @override
  String get postViewReply => 'Reply';

  @override
  String get postViewCommentOptions => 'Comment options';

  @override
  String get postViewEditCommentHint => 'Edit comment';

  @override
  String get postViewCancel => 'Cancel';

  @override
  String get postViewSave => 'Save';

  @override
  String postViewLikersWithCount(String n) {
    return 'Likes ($n)';
  }

  @override
  String get postViewLikers => 'Likes';

  @override
  String get postViewRetry => 'Retry';

  @override
  String get postViewNoLikers => 'No likes yet';

  @override
  String get postViewUser => 'User';

  @override
  String get postViewLikeFailed => 'Could not save your like';

  @override
  String get postViewUnlike => 'Unlike';

  @override
  String get postViewLike => 'Like';

  @override
  String get postViewSavedAdded => 'Added to saved';

  @override
  String get postViewSavedRemoved => 'Removed from saved';

  @override
  String get postViewUnsave => 'Remove from saved';

  @override
  String postViewNoTagPosts(String tag) {
    return 'No posts tagged #$tag.';
  }

  @override
  String get postViewSavedPostsTitle => 'Saved posts';

  @override
  String get postViewNoSavedPosts => 'You have not saved any posts yet.';

  @override
  String get postViewPosts => 'Posts';

  @override
  String get postViewSeeAll => 'See all';

  @override
  String get postViewPost => 'Post';

  @override
  String get postViewMyPosts => 'My posts';

  @override
  String get postViewNoPosts => 'No posts yet';

  @override
  String get postViewReadMore => 'read more';

  @override
  String get postViewReportSent => 'Your report has been submitted.';

  @override
  String get postViewMore => 'More';

  @override
  String get postViewFeedEmpty => 'No posts yet. Be the first to share!';

  @override
  String postViewCommentsWithCount(String n) {
    return 'Comments ($n)';
  }

  @override
  String get postViewComments => 'Comments';

  @override
  String get postViewSortNew => 'New';

  @override
  String get postViewSortTop => 'Top';

  @override
  String get postViewFirstComment => 'Be the first to comment';

  @override
  String get profileDeptRequired => 'Select your department.';

  @override
  String get profileDiscardTitle => 'Changes not saved';

  @override
  String get profileDiscardBody => 'If you leave, your changes will be lost.';

  @override
  String get profileKeepEditing => 'Keep editing';

  @override
  String get profileDiscardExit => 'Discard and leave';

  @override
  String get profileChangePhotoSemantic => 'Change profile photo';

  @override
  String get profileUploading => 'Uploading…';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profilePickGallery => 'Choose from gallery';

  @override
  String get profileTakePhoto => 'Take a photo';

  @override
  String get profileRemovePhoto => 'Remove photo';

  @override
  String get profilePhotoTooLargeHint =>
      'The photo can be at most 2 MB. Choose a smaller one.';

  @override
  String get profilePhotoUnsupported =>
      'Only JPG, PNG or WebP photos can be uploaded.';

  @override
  String get profilePhotoUnreadable => 'The selected file could not be read.';

  @override
  String get profilePhotoTooLarge => 'The photo can be at most 2 MB.';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileFullName => 'Full name';

  @override
  String get profileNameMin => 'Name must be at least 2 characters.';

  @override
  String get profileAbout => 'About me';

  @override
  String get profileBioHint => 'Tell us a little about yourself';

  @override
  String get profileShowEmail => 'Show my email to other users';

  @override
  String get profileSave => 'Save';

  @override
  String get profileUserDefault => 'User';

  @override
  String profileGradeYear(String year) {
    return 'Year $year';
  }

  @override
  String get profileBlockTitle => 'Block this user?';

  @override
  String get profileBlockBody =>
      'You will not be able to message people you block.';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileBlock => 'Block';

  @override
  String get profileUnblock => 'Unblock';

  @override
  String get profileUnblocked => 'User unblocked';

  @override
  String get profileBlocked => 'User blocked';

  @override
  String get profileReportUser => 'Report user';

  @override
  String get profileOnline => 'Online';

  @override
  String profileLastSeenToday(String time) {
    return 'Last seen today at $time';
  }

  @override
  String profileLastSeenYesterday(String time) {
    return 'Last seen yesterday at $time';
  }

  @override
  String profileLastSeenDate(String date, String time) {
    return 'Last seen $date $time';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNotFound => 'User not found';

  @override
  String get profileFaculty => 'Faculty';

  @override
  String get profileDepartment => 'Department';

  @override
  String get profileGrade => 'Year';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileMessage => 'Message';

  @override
  String get profileReport => 'Report';

  @override
  String get profileAboutShort => 'About';

  @override
  String get profileSignOutTitle => 'Sign out?';

  @override
  String get profileSignOutBody =>
      'Your session on this device will be closed.';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileStatClubs => 'Clubs';

  @override
  String get profileStatEvents => 'Events';

  @override
  String get profileStatSavedNews => 'Saved news';

  @override
  String get profileMyPosts => 'My posts';

  @override
  String get profileSavedPosts => 'Saved posts';

  @override
  String get profileSuggested => 'Suggested people';

  @override
  String get profileSaved => 'Saved';

  @override
  String get profileAcademic => 'Academic';

  @override
  String get profileMyEvents => 'My events';

  @override
  String get profileMyClubs => 'My clubs';

  @override
  String get profileReminders => 'Class and exam reminders';

  @override
  String get profileSavedEmpty =>
      'You have not saved any news yet. Tap the bookmark icon on a news item.';

  @override
  String get profileRetry => 'Try again';

  @override
  String profileNewsCount(String count) {
    return '$count news';
  }

  @override
  String profileNewsCountMore(String count) {
    return '$count+ news';
  }

  @override
  String get profileLegalTitle => 'Agreements';

  @override
  String get profileLegalEmpty => 'No published agreements.';

  @override
  String get profileLegalDocFallback => 'Agreement';

  @override
  String profileVersion(String version) {
    return 'Version $version';
  }

  @override
  String profileVersionDate(String version, String date) {
    return 'Version $version · $date';
  }

  @override
  String get profilePrefsDataCopied => 'Your data was copied to the clipboard';

  @override
  String get profilePrefsExportLimit =>
      'You can download your data at most 3 times a day.';

  @override
  String get profilePrefsBlockedUsers => 'Blocked users';

  @override
  String get profilePrefsLegalPrivacy => 'Agreements and privacy';

  @override
  String get profilePrefsDownloadData => 'Download my data';

  @override
  String get profilePrefsAccountMgmt => 'Account management';

  @override
  String get profilePrefsDeleteMyAccount => 'Delete my account';

  @override
  String get profilePrefsEnterPassword => 'Enter your password.';

  @override
  String get profilePrefsWrongPassword => 'Wrong password.';

  @override
  String get profilePrefsDeleteAccountTitle => 'Delete account';

  @override
  String get profilePrefsDeleteAccountBody =>
      'Your account and personal data will be deleted. This cannot be undone. Enter your password to confirm.';

  @override
  String get profilePrefsPassword => 'Password';

  @override
  String get profilePrefsClubLeft => 'You left the club.';

  @override
  String get profilePrefsWithdrawTitle => 'Withdraw request';

  @override
  String get profilePrefsWithdrawBody =>
      'Do you want to withdraw your join request?';

  @override
  String get profilePrefsWithdrawConfirm => 'Withdraw';

  @override
  String get profilePrefsNoClubs => 'You are not a member of any club yet.';

  @override
  String get profilePrefsClubsOwned => 'Founded by me';

  @override
  String get profilePrefsClubsMember => 'My memberships';

  @override
  String get profilePrefsClubsPending => 'Pending applications';

  @override
  String get profilePrefsMyClubs => 'My clubs';

  @override
  String get profilePrefsCreateClub => 'Create a club';

  @override
  String profilePrefsMembersCount(String count) {
    return '$count members';
  }

  @override
  String get profilePrefsAwaitingApproval => 'Awaiting approval';

  @override
  String get profilePrefsAwaitingPublish => 'Awaiting publish approval';

  @override
  String get profilePrefsManage => 'Manage';

  @override
  String get profilePrefsOptions => 'Options';

  @override
  String get profilePrefsOpen => 'Open';

  @override
  String get profilePrefsManageEdit => 'Manage: edit';

  @override
  String get profilePrefsManageRequests => 'Manage: applications';

  @override
  String get profilePrefsManageMembers => 'Manage: members';

  @override
  String get profilePrefsLeaveClub => 'Leave club';

  @override
  String get profilePrefsReminders => 'Class and exam reminders';

  @override
  String get profilePrefsNotifNews => 'News';

  @override
  String get profilePrefsNotifAnnouncements => 'Announcements';

  @override
  String get profilePrefsNotifEvents => 'Events';

  @override
  String get profilePrefsNotifCommunities => 'Communities';

  @override
  String get profilePrefsNotifMessages => 'Messages';

  @override
  String get profilePrefsNotifPolls => 'Polls';

  @override
  String get profilePrefsNotifAcademic => 'Academic announcements';

  @override
  String get profilePrefsNotifStories => 'Stories';

  @override
  String get profilePrefsNotifMention => 'Mentions';

  @override
  String get profilePrefsNotifFollow => 'New followers';

  @override
  String get profilePrefsNotifLike => 'Post likes';

  @override
  String get profilePrefsNotifComment => 'Post comments';

  @override
  String get profilePrefsNotifReply => 'Comment replies';

  @override
  String get profilePrefsSocial => 'Social';

  @override
  String get profilePrefsOnThisDevice => 'On this device';

  @override
  String profilePrefsTapToRetry(String error) {
    return '$error Tap to try again.';
  }

  @override
  String get profilePrefsNotifTitle => 'Notifications';

  @override
  String get profilePrefsNoBlocked => 'You have not blocked anyone.';

  @override
  String get profilePrefsUser => 'User';

  @override
  String get profilePrefsUnblock => 'Unblock';

  @override
  String get profilePrefsBlockedTitle => 'Blocked';

  @override
  String get pickDepartment => 'Department';

  @override
  String get pickSelectDepartment => 'Select department';

  @override
  String get pickLoading => 'Loading…';

  @override
  String get pickListFailed => 'Could not load the department list.';

  @override
  String get pickRetry => 'Retry';

  @override
  String get pickGrade => 'Year';

  @override
  String get pickSelectGrade => 'Select year';

  @override
  String get pickSearch => 'Search';

  @override
  String get pickNoResults => 'No results found.';

  @override
  String authStepOf(String n, String total) {
    return 'Step $n of $total';
  }

  @override
  String get authSectionPersonal => 'Personal details';

  @override
  String get authSectionPassword => 'Set a password';

  @override
  String get authHintAcademic => 'Select your department and year.';

  @override
  String get authHintPersonal => 'Enter your name and school email.';

  @override
  String get authHintPassword =>
      'Choose a password with at least 8 characters.';

  @override
  String get authNext => 'Continue';

  @override
  String get authTermsAutoPrefix => 'By signing up, you agree to the ';

  @override
  String get authTermsAutoSuffix => '.';

  @override
  String get authPwMinErr => 'Password must be at least 8 characters.';

  @override
  String get authPwMaxErr => 'Password can be at most 72 characters.';

  @override
  String get authIdHelper => '226051015 or first.last@bingol.edu.tr';

  @override
  String get supportCatAccount => 'Account';

  @override
  String get supportCatTechnical => 'Technical';

  @override
  String get supportCatContent => 'Content';

  @override
  String get supportCatOther => 'Other';

  @override
  String get supportFbBug => 'Bug';

  @override
  String get supportFbSuggestion => 'Suggestion';

  @override
  String get supportFbComplaint => 'Complaint';

  @override
  String get supportFbPraise => 'Thanks';

  @override
  String get supportStNew => 'New';

  @override
  String get supportStInReview => 'In review';

  @override
  String get supportStPlanned => 'Planned';

  @override
  String get supportStDone => 'Done';

  @override
  String get supportStRejected => 'Rejected';

  @override
  String get supportStatusAnswered => 'Answered';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportStatusOpen => 'Open';

  @override
  String get supportTooManyRequests =>
      'You have sent too many requests. Please wait a moment and try again.';

  @override
  String get supportLabelCategory => 'CATEGORY';

  @override
  String get supportLabelSubject => 'SUBJECT';

  @override
  String get supportLabelMessage => 'MESSAGE';

  @override
  String get supportLabelMine => 'MY SUBMISSIONS';

  @override
  String get supportHintSubject => 'Brief subject';

  @override
  String get supportHintFeedback => 'Write your feedback';

  @override
  String get supportHintIssue => 'Describe your issue';

  @override
  String get supportHintReply => 'Write a reply';

  @override
  String get supportFillFields => 'Fill in the subject and message fields.';

  @override
  String get supportFeedbackThanks => 'Thank you for your feedback.';

  @override
  String get supportFeedbackTitle => 'Feedback';

  @override
  String get supportSend => 'Send';

  @override
  String get supportNoFeedback => 'You have not sent any feedback yet.';

  @override
  String get supportMore => 'Load more';

  @override
  String get supportTicketReceived => 'Your support request has been received.';

  @override
  String get supportNewTicketTitle => 'New request';

  @override
  String get supportTitle => 'Support';

  @override
  String get supportFaqLabel => 'FREQUENTLY ASKED QUESTIONS';

  @override
  String get supportMyTickets => 'MY REQUESTS';

  @override
  String get supportShareLabel => 'SHARE YOUR THOUGHTS';

  @override
  String get supportBoard => 'Suggestion board';

  @override
  String get supportCreateTicket => 'Create support request';

  @override
  String get supportNoFaq => 'There are no frequently asked questions yet.';

  @override
  String get supportRetry => 'Retry';

  @override
  String get supportNoTickets => 'You have no support requests yet.';

  @override
  String get supportSortTop => 'Most votes';

  @override
  String get supportSortNew => 'Newest';

  @override
  String get supportAddSuggestion => 'Add suggestion';

  @override
  String get supportNoSuggestions =>
      'No suggestions have been published yet. Be the first to add one.';

  @override
  String get supportCloseTicketTitle => 'Close request';

  @override
  String get supportCloseTicketBody =>
      'This request will be closed and you will not be able to write new replies. Continue?';

  @override
  String get supportCancel => 'Cancel';

  @override
  String get supportClose => 'Close';

  @override
  String get supportTicketTitle => 'Request';

  @override
  String get supportTicketClosedNote => 'This request has been closed.';

  @override
  String get supportStaff => 'Support team';

  @override
  String get storyVideoTooLong =>
      'A story video can be at most 30 seconds long.';

  @override
  String get storyCreateTitle => 'Create story';

  @override
  String get storyShare => 'Share';

  @override
  String get storyModeMedia => 'Photo / Video';

  @override
  String get storyModeText => 'Text';

  @override
  String get storyVisible24 => 'Your story is visible for 24 hours';

  @override
  String get storyGallery => 'Gallery';

  @override
  String get storyCamera => 'Camera';

  @override
  String get storyCaptionHint => 'Add a caption…';

  @override
  String get storyTextHint => 'Write something…';

  @override
  String storyBgColor(String n) {
    return 'Background color $n';
  }

  @override
  String get storyYours => 'Your story';

  @override
  String storyNewSemantics(String name) {
    return '$name, new story';
  }

  @override
  String storySemantics(String name) {
    return '$name, story';
  }

  @override
  String get storyDeleteTitle => 'Delete story?';

  @override
  String get storyDeleteBody => 'This action cannot be undone.';

  @override
  String get storyCancel => 'Cancel';

  @override
  String get storyDelete => 'Delete';

  @override
  String get storyRetry => 'Retry';

  @override
  String get storyClose => 'Close';

  @override
  String storyViewsSemantics(String count) {
    return '$count views, show viewers';
  }

  @override
  String get storyDeleteTooltip => 'Delete story';

  @override
  String storyBarSemantics(String index, String total) {
    return 'Story $index / $total';
  }

  @override
  String get storyNoViewers => 'No one has viewed it yet.';

  @override
  String storyViewersTitle(String count) {
    return 'Viewers ($count)';
  }

  @override
  String get authForgotSub =>
      'Enter your school email and we will send you a 6-digit code.';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authChangeEmail => 'Change email';

  @override
  String get authNewPwSub =>
      'This replaces your old password. You will be signed out on all devices.';

  @override
  String get authRuleLen => 'At least 8 characters';

  @override
  String get authRuleMix => 'Contains letters and numbers';

  @override
  String get authStep1Title => 'Which department are you in?';

  @override
  String get authStep2Title => 'Let us get to know you';

  @override
  String get welcomeHeadline => 'Campus is now\nin your pocket';

  @override
  String get welcomeSub =>
      'Announcements, the menu, clubs and events in one app.';

  @override
  String get welcomeNews => 'News and announcements';

  @override
  String get welcomeMenu => 'The menu of the day';

  @override
  String get welcomeClubs => 'Clubs and events';

  @override
  String get welcomeNote =>
      'Sign-up is only available with a school email (bingol.edu.tr).';

  @override
  String get welcomeLanguage => 'Language';

  @override
  String get chatlistSearchHint => 'Search chats';

  @override
  String get bildirimFilterAll => 'All';

  @override
  String get bildirimFilterUnread => 'Unread';

  @override
  String get bildirimEmptyUnread => 'No unread notifications';

  @override
  String get bildirimAllCaughtUp => 'You are all caught up';

  @override
  String get bildirimSwipeHint => 'Swipe a notification to delete it';

  @override
  String get bildirimDelete => 'Delete';

  @override
  String bildirimShortMin(String n) {
    return '$n m';
  }

  @override
  String bildirimShortHour(String n) {
    return '$n h';
  }

  @override
  String bildirimShortDay(String n) {
    return '$n d';
  }

  @override
  String get bildirimYesterday => 'Yesterday';

  @override
  String get bildirimTypeNews => 'News';

  @override
  String get bildirimTypeAnnouncement => 'Announcement';

  @override
  String get bildirimTypeEvent => 'Event';

  @override
  String get bildirimTypeMessage => 'Chat';

  @override
  String get bildirimTypeCommunity => 'Club';

  @override
  String get bildirimTypePoll => 'Poll';

  @override
  String get bildirimTypePost => 'Post';

  @override
  String get bildirimTypeOther => 'Notification';

  @override
  String get acadhubNextExam => 'Next exam';

  @override
  String get acadhubUpcoming => 'Upcoming dates';

  @override
  String get acadhubCalendarLink => 'Calendar';

  @override
  String get acadhubNoUpcoming => 'No upcoming dates';

  @override
  String get kuluplerAllClubs => 'All clubs';

  @override
  String get kesfetSubtitle => 'Posts from students';

  @override
  String get kesfetSearchHint => 'Search posts or people';

  @override
  String get profil2PrivacyTitle => 'Privacy and blocked users';

  @override
  String get profil2PrivacyIntro =>
      'Choose who can see each part of your profile. You always see your own profile in full.';

  @override
  String get profil2VisibilitySection => 'Profile visibility';

  @override
  String get profil2FieldAvatar => 'Profile photo';

  @override
  String get profil2FieldBio => 'About me';

  @override
  String get profil2FieldFaculty => 'Faculty';

  @override
  String get profil2FieldDepartment => 'Department';

  @override
  String get profil2FieldClassYear => 'Class year';

  @override
  String get profil2VisEveryone => 'Everyone';

  @override
  String get profil2VisShared => 'Shared context';

  @override
  String get profil2VisOnlyMe => 'Only me';

  @override
  String get profil2SharedHintLead => 'Shared context:';

  @override
  String get profil2SharedHintBody =>
      'people you share a club, chat or event with.';

  @override
  String get profil2ShowEmail => 'Show my email on my profile';

  @override
  String get profil2ShowEmailSub => 'When off, only you can see it';

  @override
  String get profil2BlockedSection => 'Blocked';

  @override
  String get profil2BlockedHint =>
      'People you block cannot see you or message you.';

  @override
  String get profil2AvatarModerated =>
      'Your profile photo was hidden by moderation.';

  @override
  String get profil2SaveFailed => 'Could not save the change.';

  @override
  String get profil2MyDataRow => 'My data and account';

  @override
  String get profil2DataTitle => 'My data';

  @override
  String get profil2DataIntro =>
      'You can download a copy of the personal data we keep in the app, as provided by data protection law.';

  @override
  String get profil2DataFileSub => 'Prepared as a JSON file';

  @override
  String get profil2DataContents => 'What is in the file';

  @override
  String get profil2DataItemProfile => 'Your profile details';

  @override
  String get profil2DataItemPrefs =>
      'Your privacy and notification preferences';

  @override
  String get profil2DataItemClubs => 'Your club and event records';

  @override
  String get profil2DataItemSaved => 'Your saved news and notifications';

  @override
  String get profil2DataItemSupport => 'Your support and feedback records';

  @override
  String get profil2DataLimit =>
      'You can download up to 3 times a day. Keep the file safe, it contains personal information.';

  @override
  String get profil2DataOther => 'Other';

  @override
  String get profil2DataKvkk => 'Data protection notice';

  @override
  String get profil2DelWarnLead => 'This cannot be undone.';

  @override
  String get profil2DelWarnBody =>
      'Your account is anonymized and you can no longer sign in.';

  @override
  String get profil2DelWhatHappens => 'What happens';

  @override
  String get profil2DelItem1 =>
      'Your name, email, photo and profile details are deleted. The account stays as Deleted user.';

  @override
  String get profil2DelItem2 =>
      'Your notifications, saved news, device records and preferences are deleted.';

  @override
  String get profil2DelItem3 =>
      'Your club memberships and event participations are removed.';

  @override
  String get profil2DelItem4 => 'Your sessions on all devices are closed.';

  @override
  String get profil2DelBackupHint =>
      'If you like, you can download your data before deleting.';

  @override
  String get profil2DelAck =>
      'I understand my account will be permanently deleted and this cannot be undone.';

  @override
  String get profil2Continue => 'Continue';

  @override
  String get profil2DelConfirmTitle => 'Confirm deletion';

  @override
  String get profil2DelConfirmBody =>
      'Enter your password to continue. Your account is anonymized right away and you are signed out on all devices.';

  @override
  String get profil2SecTitle => 'Account and security';

  @override
  String get profil2SecEmailFixed => 'Cannot be changed';

  @override
  String get profil2SecVerified => 'Verified';

  @override
  String get profil2SecPwSection => 'Update password';

  @override
  String get profil2SecCurrentLabel => 'Current password';

  @override
  String get profil2SecCurrentHint => 'Your current password';

  @override
  String get profil2SecNewLabel => 'New password';

  @override
  String get profil2SecNewHint => 'At least 8 characters';

  @override
  String get profil2SecRepeatLabel => 'New password (repeat)';

  @override
  String get profil2SecRepeatHint => 'Repeat the new password';

  @override
  String get profil2SecPwRule =>
      '8 to 72 characters. Mixing letters and digits makes it stronger.';

  @override
  String get profil2SecPwButton => 'Update password';

  @override
  String get profil2SecMismatch => 'Passwords do not match.';

  @override
  String get profil2SecSame =>
      'The new password cannot be the same as the current one.';

  @override
  String get profil2SecWrongCurrent => 'The current password is wrong.';

  @override
  String get profil2SecFailed =>
      'Could not update the password. Please try again later.';

  @override
  String get profil2SecUpdated => 'Your password was updated.';

  @override
  String get profil2SecSessions => 'Sessions';

  @override
  String get profil1SecContent => 'My content';

  @override
  String get profil1SecAccount => 'Account';

  @override
  String get profil1SecApp => 'App';

  @override
  String get profil1SecSupport => 'Support and legal';

  @override
  String get profil1AccountSecurity => 'Account and security';

  @override
  String get profil1PrivacyBlocked => 'Privacy and blocked users';

  @override
  String get profil1MyData => 'My data';

  @override
  String get profil1Notifications => 'Notification preferences';

  @override
  String get profil1Theme => 'Theme';

  @override
  String get profil1Support => 'Support';

  @override
  String get profil1Legal => 'Agreements and policies';

  @override
  String get profil1CorpEmail => 'University email';

  @override
  String get profil1Remove => 'Remove';

  @override
  String get profil1PushTitle => 'Push notifications';

  @override
  String get profil1PushGranted => 'Allowed on this device';

  @override
  String get profil1PillOff => 'Off';

  @override
  String get profil1WhatSection => 'What to notify';

  @override
  String get profil1NotifClubs => 'Clubs';

  @override
  String get profil1NewsSub => 'New stories from the university';

  @override
  String get profil1AnnSub => 'Important announcements';

  @override
  String get profil1EventsSub => 'Reminders, changes, admission';

  @override
  String get profil1MsgSub => 'Direct and group chats';

  @override
  String get profil1ClubsSub => 'Posts, roles and joining';

  @override
  String get profil1Detailed => 'Detailed preferences';

  @override
  String get profil1SubMsgDirect => 'Direct messages';

  @override
  String get profil1SubMsgGroup => 'Group messages';

  @override
  String get profil1SubEventReminder => 'Event reminders';

  @override
  String get profil1SubEventUpdate => 'Event changes';

  @override
  String get profil1SubEventAdmission => 'Event admissions';

  @override
  String get profil1SubClubPost => 'Club posts';

  @override
  String get profil1SubClubRole => 'Club role changes';

  @override
  String get profil1SubClubJoin => 'Club join requests';

  @override
  String get profil1QuietTitle => 'Quiet hours';

  @override
  String get profil1QuietToggle => 'Turn on quiet hours';

  @override
  String get profil1QuietSub => 'No notification sound during these hours';

  @override
  String get profil1QuietStart => 'Start';

  @override
  String get profil1QuietEnd => 'End';

  @override
  String get sohbetmedyaNext => 'Next';

  @override
  String sohbetmedyaSelectedOf(String n, String max) {
    return '$n / $max selected';
  }

  @override
  String get sohbetmedyaRecent => 'Recent';

  @override
  String get sohbetmedyaPhotoVideo => 'Photos and videos';

  @override
  String sohbetmedyaLimitNote(String max) {
    return 'You can select up to $max items. Videos can be at most 60 seconds.';
  }

  @override
  String get sohbetmedyaAddMore => 'Add more';

  @override
  String sohbetmedyaSendItems(String n) {
    return 'Send $n items';
  }

  @override
  String get chatdSendingMedia => 'Sending…';

  @override
  String get chatdPhotoLoading => 'Loading photo…';

  @override
  String get chatdOnceLocked => 'View-once photo';

  @override
  String get chatdOnceView => 'View';

  @override
  String get chatdOnceOpenedFull => 'Photo · Opened';

  @override
  String anasayfaHello(String name) {
    return 'Hello, $name';
  }

  @override
  String get anasayfaHelloNoName => 'Hello';

  @override
  String get anasayfaMealLunch => 'Todays meal · Lunch';

  @override
  String get anasayfaAnnouncements => 'Announcements';

  @override
  String get anasayfaQuickAcademic => 'Academic';

  @override
  String get gonderiTextHint => 'Add a short note (optional)';

  @override
  String gonderiWordCount(String n, String max) {
    return '$n/$max words';
  }

  @override
  String gonderiWordLimit(String max) {
    return 'You can write up to $max words.';
  }

  @override
  String get gonderiPickPhoto => 'Choose from gallery';

  @override
  String get gonderiTakePhoto => 'Take a photo';

  @override
  String get gonderiPhotoRequired => 'Choose a photo to share.';

  @override
  String get gonderiPhotoHint => 'A post is a single photo.';

  @override
  String get gonderiChangePhoto => 'Change photo';

  @override
  String get gonderiDiscardTitle => 'Discard this post?';

  @override
  String get gonderiDiscardBody =>
      'The photo you chose and your text will be discarded.';

  @override
  String get gonderiDiscardYes => 'Discard';

  @override
  String get yemekLunch => 'Lunch';

  @override
  String get yemekTodaysMenu => 'Todays menu';

  @override
  String get yemekToday => 'Today';

  @override
  String get yemekPrevDay => 'Previous day';

  @override
  String get yemekNextDay => 'Next day';

  @override
  String get destekFaqHeading => 'Frequently asked questions';

  @override
  String get destekFaqSearchHint => 'Search your question';

  @override
  String get destekFaqAll => 'All';

  @override
  String get destekFaqNoMatch => 'No matching question found.';

  @override
  String get destekSortMine => 'Mine';

  @override
  String get destekSortPopular => 'Popular';

  @override
  String get destekShareSuggestion => 'Share a suggestion';

  @override
  String destekEffective(String date) {
    return 'Effective: $date';
  }

  @override
  String destekVoteLabel(String count) {
    return 'Vote, currently $count votes';
  }

  @override
  String get anketScopeGlobal => 'General';

  @override
  String get anketScopeClub => 'Club';

  @override
  String get anketScopeMenu => 'Meal';

  @override
  String get anketSecretNote =>
      'Your vote is secret. Only you can see your choice; nobody, including admins, can see who chose what.';

  @override
  String get anketSecretVoteNote =>
      'Your vote stays secret; nobody can see who chose what.';

  @override
  String get anketMineBadge => 'Your pick';

  @override
  String get anketRatingSummary => 'Rating summary';

  @override
  String get anketResultsTitle => 'Results';

  @override
  String get anketFieldQuestion => 'Question';

  @override
  String get anketVisTitle => 'When are results visible?';

  @override
  String get anketVisAlways => 'Always';

  @override
  String get anketVisAfterVote => 'After voting';

  @override
  String get anketVisAfterClose => 'When the poll closes';

  @override
  String get anketNotifyTitle => 'Send notification';

  @override
  String get anketNotifySub => 'Notify the audience that the poll is open';

  @override
  String get icerikHidden => 'Hidden';

  @override
  String get icerikStatPosts => 'posts';

  @override
  String get icerikStatFollowers => 'followers';

  @override
  String get icerikStatFollowing => 'following';

  @override
  String get icerikMessageSend => 'Send message';

  @override
  String get icerikReport => 'Report';

  @override
  String get icerikMoreActions => 'More actions';

  @override
  String get icerikUserMenu => 'User actions';

  @override
  String get icerikPostsHeading => 'POSTS';

  @override
  String get icerikOpenPost => 'Open post';

  @override
  String get icerikPostPhoto => 'Post photo';

  @override
  String get icerikNewsTitle => 'News';

  @override
  String get icerikNewsTypeTabs => 'Type';

  @override
  String get icerikNewsList => 'News list';

  @override
  String get icerikNewsEmpty => 'No content in this category yet.';

  @override
  String get icerikFavorites => 'Favorite news';

  @override
  String get icerikMaintenance =>
      'The news source is unreachable right now. Showing the latest saved news.';

  @override
  String get icerikOpenSource => 'Open on source site';

  @override
  String get icerikShare => 'Share';

  @override
  String get icerikLinkCopied => 'News link copied.';

  @override
  String icerikSavedCount(String count) {
    return '$count saved news';
  }

  @override
  String get icerikSavedMoreTitle => 'Save more news';

  @override
  String get icerikSavedMoreBody =>
      'Use the bookmark on a news page to add it here.';

  @override
  String get icerikSavedList => 'Favorites';

  @override
  String get icerikSearchTabs => 'Result type';

  @override
  String get icerikGroupNews => 'NEWS';

  @override
  String get icerikGroupAnnouncement => 'ANNOUNCEMENT';

  @override
  String get icerikGroupEvent => 'EVENT';

  @override
  String get icerikGroupClub => 'CLUB';

  @override
  String get icerikGroupPerson => 'PEOPLE';

  @override
  String get icerikGroupPost => 'POSTS';

  @override
  String get kulupdetayRequestsTitle => 'Join requests';

  @override
  String kulupdetayPendingBanner(String count) {
    return '$count pending join requests';
  }

  @override
  String get kulupdetaySendRequest => 'Send request';

  @override
  String get kulupdetayAnswerHint => 'Write your answer';

  @override
  String get kulupdetayRequired => 'This question is required.';

  @override
  String get kulupdetayApproving => 'Approving...';

  @override
  String get kulupdetayCreateTitle => 'Create club';

  @override
  String kulupdetayMembersSubtitle(String club, String count) {
    return '$club · $count members';
  }

  @override
  String akademik2DayHeadingToday(String day) {
    return '$day, today';
  }

  @override
  String akademik2CourseCount(String count) {
    return '$count classes';
  }

  @override
  String get akademik2ExportLabel => 'Export to calendar';

  @override
  String get akademik2CourseHours => 'Class time';

  @override
  String get akademik2Instructor => 'Instructor';

  @override
  String get akademik2Start => 'Start';

  @override
  String get akademik2End => 'End';

  @override
  String get akademik2EndOptional => 'End (optional)';

  @override
  String get akademik2RoomShort => 'Room';

  @override
  String get akademik2AddDay => 'Add another day';

  @override
  String get akademik2OfficialTag => 'Official';

  @override
  String get akademik2Passed => 'Past';

  @override
  String get akademik2ExamTitle => 'Exam title';

  @override
  String get akademik2Course => 'Course';

  @override
  String get akademik2Place => 'Place';

  @override
  String get akademik2NewTag => 'New';

  @override
  String get akademik2Attachment => 'Attachment';

  @override
  String get akademik2RemindEach => 'Before every class';

  @override
  String get akademik2BeforeClassShort => 'Before class';

  @override
  String get akademik2SemesterTitle => 'Choose term';
}
