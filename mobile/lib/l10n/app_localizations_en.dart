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
      'Configuration error: the server address (API_BASE) is not secure (HTTPS). Rebuild the app with the correct address.';

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
      'Update to the latest version to keep using the app.';

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
  String get pushPermission => 'Notification permission';

  @override
  String get pushNotConfigured => 'Not configured yet';

  @override
  String get pushOn => 'On';

  @override
  String get pushOff => 'Off (turn on in system settings)';

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
  String get settingsLogoutAll => 'Log out of all devices';

  @override
  String get settingsLogoutAllTitle => 'Log out of all devices';

  @override
  String get settingsLogoutAllBody =>
      'You will be logged out on all devices and will need to log in again.';

  @override
  String get settingsLogoutAllConfirm => 'Log out';

  @override
  String settingsVersion(String version) {
    return 'BÜ Kampüs · Version $version';
  }

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginSubtitle => 'Log in with your school email.';

  @override
  String get loginReplacedNotice =>
      'Your account was logged in on another device, so this session was closed for your security.';

  @override
  String get loginPasswordRequired => 'Enter your password.';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSubmit => 'Log in';

  @override
  String get loginNoAccount => 'No account yet?';

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
    return 'Resend in ${seconds}s';
  }

  @override
  String authNewCodeIn(String seconds) {
    return 'You can request a new code in ${seconds}s';
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
      'Verify your email to log in. Your account must be verified first.';

  @override
  String get authUseOtherAccount => 'Log in with another account';

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
  String get authSessionExpired => 'Your session expired. Please start over.';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSelectDepartment => 'Select your department.';

  @override
  String get authSelectGrade => 'Select your year of study.';

  @override
  String get authDepartmentsLoadFailed =>
      'Could not load the department list. Please try again.';

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
    return '$n d left';
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
  String get acadGradePrep => 'Prep year';

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
    return 'Upcoming exams: $n';
  }

  @override
  String get acadHubTimetable => 'Timetable';

  @override
  String get acadHubTimetableSub => 'Your weekly timetable';

  @override
  String get acadHubExamsSub => 'Your exam schedule and the official schedule';

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
      'Only public exams are shown because your profile has no department. Add one by editing your profile.';

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
  String get acadFormPickDate => 'Select a date';

  @override
  String get acadFormStartTime => 'Start time';

  @override
  String get acadFormEndTime => 'End time';

  @override
  String get acadFormEndHint => 'End (optional)';

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
    return 'Important dates: $n';
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
    return 'Starts in 2 hours$room';
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
  String get acadTimeStale => 'Could not refresh. Showing the latest data.';

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
    return 'Classes left today: $count';
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
  String get acadTimeNameRequired => 'Course name is required.';

  @override
  String get acadTimeEndAfterStart => 'End time must be after the start time.';

  @override
  String get acadTimeOwnConflict => 'This course has overlapping sessions.';

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
      'A color is assigned automatically if you do not choose one.';

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
  String get acadTimeAddSemester => 'Add semester';

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
  String get acadTimeMakeCurrent => 'Set as current semester';

  @override
  String get acadTimeDeleteSemester => 'Delete semester';

  @override
  String acadTimeDeleteSemesterText(String name) {
    return '\"$name\" will be deleted. Its courses will no longer belong to a semester.';
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
  String get acadTimeHourBefore => '2 hours before exam (notification)';

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
  String get chatDetailVideoTooLong => 'Videos can be up to 60 seconds long.';

  @override
  String get chatDetailVideoTooLarge =>
      'The video is too large. Choose a shorter one.';

  @override
  String get chatDetailVideoUnsupported =>
      'Videos cannot be sent on this device.';

  @override
  String get chatDetailVideoFailed => 'The video could not be prepared.';

  @override
  String get chatDetailVideosSplit =>
      'The videos are large, so they will be sent as multiple messages.';

  @override
  String get chatDetailImageTooLarge =>
      'The image is too large. Choose a smaller one.';

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
    return 'Last seen $date';
  }

  @override
  String chatDetailClubRoomMembers(String count) {
    return 'Club room · Members: $count';
  }

  @override
  String chatDetailEventRoomMembers(String count) {
    return 'Event room · Members: $count';
  }

  @override
  String chatDetailMembersCount(String count) {
    return 'Members: $count';
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
  String get chatDetailForwardFailedAll => 'Could not forward the message';

  @override
  String chatDetailForwardFailedSome(String count) {
    return 'Could not forward to some chats ($count)';
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
  String get chatDetailLeaveBody =>
      'You will no longer receive messages from this chat.';

  @override
  String get chatDetailLeave => 'Leave';

  @override
  String get chatDetailBlockTitle => 'Block this user?';

  @override
  String get chatDetailBlockBody =>
      'You will not be able to message people you block.';

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
  String get chatDetailEmpty => 'No messages yet. Send the first one.';

  @override
  String get chatDetailScrollDown => 'Scroll to bottom';

  @override
  String chatDetailScrollDownNew(String count) {
    return 'Scroll to bottom. New messages: $count';
  }

  @override
  String get chatDetailEditing => 'Editing message';

  @override
  String get chatDetailAdd => 'Add';

  @override
  String get chatDetailWriteMessage => 'Type a message';

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
  String get chatInfoLeaveBody =>
      'You will no longer receive messages from this chat.';

  @override
  String get chatInfoLeave => 'Leave';

  @override
  String get chatInfoUnblocked => 'User unblocked';

  @override
  String get chatInfoBlockTitle => 'Block this user?';

  @override
  String get chatInfoBlockBody =>
      'You will not be able to message people you block.';

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
      'The image is too large. Choose a smaller one.';

  @override
  String get chatInfoImageTypeOnly =>
      'Only JPEG, PNG or WebP images are allowed.';

  @override
  String get chatInfoTitle => 'Chat info';

  @override
  String get chatInfoNoMembers => 'Member list unavailable.';

  @override
  String get chatInfoClubRoom => 'Club room';

  @override
  String get chatInfoEventRoom => 'Event room';

  @override
  String chatInfoMemberCount(String n) {
    return 'Members: $n';
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
    return 'Muted · unmutes in $n d';
  }

  @override
  String chatInfoMutedHours(String n) {
    return 'Muted · unmutes in $n h';
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
  String get chatMiscUnarchived => 'Chat unarchived';

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
      'We need access to your contacts to find people from Bingöl University. Your contacts are never sent to the server; only hashed email addresses are matched.';

  @override
  String get chatMiscContactsSubtitle => 'People from Bingöl University';

  @override
  String get chatMiscContactsPermTitle => 'Contacts permission required';

  @override
  String get chatMiscContactsPermText =>
      'Allow access to your contacts so we can find campus people among them.';

  @override
  String get chatMiscContactsPermAction => 'Allow';

  @override
  String get chatMiscContactsNoneTitle => 'No matching people';

  @override
  String get chatMiscContactsNoneText =>
      'None of your contacts use the app with a Bingöl University email yet. Your friends will appear here as they join.';

  @override
  String get chatMiscContactsSearchHint => 'Search contacts';

  @override
  String get chatMiscContactsTruncated =>
      'Hourly request limit reached; the remaining contacts will be matched later.';

  @override
  String get chatMiscContactsNoSearchMatch => 'No one matches your search.';

  @override
  String chatMiscContactsCount(String n) {
    return 'PEOPLE · $n';
  }

  @override
  String get chatMiscMessage => 'Message';

  @override
  String get chatMiscContactsPrivacy =>
      'Your contacts are never sent to the server; only hashed email addresses are matched.';

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
  String get chatMiscMax50 => 'Max 50';

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
      'We need access to your gallery to show your photos and videos.';

  @override
  String get chatMiscVideoMax60 => 'Videos can be up to 60 seconds long';

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
  String get chatMiscOpenSettings => 'Open Settings';

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
      'View once: the recipient can open it only once';

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
      'The photo could not be loaded. Check your connection. As a view-once photo, it may not be possible to open it again.';

  @override
  String get chatMiscOnceShowFailed =>
      'The photo could not be displayed. As a view-once photo, it may not be possible to open it again.';

  @override
  String get chatMiscOnceTitle => 'View once';

  @override
  String get chatMiscRetry => 'Try again';

  @override
  String get chatMiscSaveUnsupported =>
      'Saving is not supported on this device.';

  @override
  String get chatMiscSaveDenied => 'Gallery permission was not granted.';

  @override
  String get chatMiscSaveNoSpace => 'Not enough storage space on this device.';

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
      'The club chat is being set up. Try again shortly.';

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
    return 'Members: $count';
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
    return 'Join requests ($count)';
  }

  @override
  String get clubRequests => 'Join requests';

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
  String get clubLoadFailedRetry => 'Could not load. Try again';

  @override
  String get clubWriteHint => 'Write something for the club';

  @override
  String get clubAddImage => 'Add image';

  @override
  String get clubShare => 'Share';

  @override
  String get clubRemoveImage => 'Remove image';

  @override
  String get clubPendingRequests => 'Pending join requests';

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
    return 'Leave $name? You will also be removed from the club chat.';
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
  String get clubMgmtNoPending => 'No pending join requests.';

  @override
  String get clubMgmtMoreRequests => 'More requests';

  @override
  String get clubMgmtRequestsTitle => 'Join requests';

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
  String get clubMgmtPendingTitle => 'Club submitted for approval';

  @override
  String get clubMgmtPendingBody =>
      'The club will be published once an admin approves it. Track its status under My clubs.';

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
      'The club was saved, but the cover or join questions could not be saved.';

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
  String get clubMgmtCategoryHint =>
      'Choose from the list or type your own (optional)';

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
      'People send a join request and you approve it.';

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
  String get clubMgmtTabMine => 'My clubs';

  @override
  String get clubMgmtAll => 'All';

  @override
  String get clubMgmtEmptyMine => 'You are not a member of any club yet.';

  @override
  String get clubMgmtNotFound => 'No clubs found.';

  @override
  String clubMgmtMemberCount(String count) {
    return 'Members: $count';
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
  String get reportThanks => 'Thank you. We have received your report.';

  @override
  String get reportPrompt => 'Choose a reason. Your report goes to the admins.';

  @override
  String get reportDetailsHint => 'Additional details (optional)';

  @override
  String get reportSend => 'Send';

  @override
  String get permNotificationsTitle => 'Notifications';

  @override
  String get permNotificationsText =>
      'Get instant alerts about messages, events and announcements.';

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
    return '$title access is off, so this feature is unavailable. You can turn it on in Settings > BÜ Kampüs.';
  }

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permClose => 'Close';

  @override
  String get permPageTitle => 'A few permissions';

  @override
  String get permPageIntro =>
      'Allow what you like now; you can change the rest later in Settings.';

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
      'The event is full. You can still mark yourself as Interested.';

  @override
  String get eventFormLeaveTitle => 'Leave event';

  @override
  String get eventFormLeaveMessage =>
      'This event will be removed from your My events list.';

  @override
  String get eventFormLeaveConfirm => 'Leave';

  @override
  String get eventFormRegsClosedToast => 'Registration closed.';

  @override
  String get eventFormRegsReopenedToast => 'Registration reopened.';

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
  String get eventFormRegsClosed => 'Registration closed';

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
  String get eventFormReopenRegs => 'Reopen registration';

  @override
  String get eventFormCloseRegs => 'Close registration';

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
  String get eventFormManageJoin => 'Manage participants';

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
    return '$present of $total checked in';
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
      'The image is too large. Choose a smaller one.';

  @override
  String get eventFormImgUnsupported =>
      'Only JPEG, PNG or WebP images can be uploaded.';

  @override
  String get eventFormImgUnreadable => 'Could not read the image.';

  @override
  String get eventFormImgPickFail =>
      'Could not select the image. Check permissions.';

  @override
  String get eventFormTitleTooShort => 'Title must be at least 3 characters.';

  @override
  String get eventFormEndBeforeStart => 'End must be after the start.';

  @override
  String get eventFormCapInvalid => 'Capacity must be 1 or more.';

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
      'The event is full. You can still mark yourself as Interested.';

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
      'Not all events for this month could be loaded.';

  @override
  String get eventListUpcoming => 'Upcoming';

  @override
  String get eventListPast => 'Past';

  @override
  String get eventListCreatedHint =>
      'You can manage the events you created here.';

  @override
  String get eventListEmptyUpcoming => 'You have no upcoming events.';

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
    return 'Attendees: $count';
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
  String get homeGreetDay => 'Good afternoon';

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
      'Source site unreachable; data may be outdated.';

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
  String get homeNoContent => 'No content.';

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
    return 'Going: $count';
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
  String get homeTodayMeal => 'Today’s meal';

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
  String get newsFullContent => 'The full text is on the source page.';

  @override
  String get newsOpenSource => 'Open on source site';

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
  String get menuNoList => 'No menu available.';

  @override
  String get menuPhotoLabel => 'Photo of the day menu';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifMarkAll => 'Mark all as read';

  @override
  String get notifEmpty => 'No notifications';

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
    return '$n d ago';
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
  String get searchPrompt => 'Type at least 2 characters.';

  @override
  String get searchRecent => 'Recent searches';

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
  String get pollTabMine => 'Voted';

  @override
  String get pollTabClosed => 'Closed';

  @override
  String get pollEmptyOpen => 'There are no open polls right now.';

  @override
  String get pollEmptyMine => 'You have not voted in any polls yet.';

  @override
  String get pollEmptyClosed => 'There are no closed polls.';

  @override
  String get pollLoadFailedRetry => 'Could not load. Try again';

  @override
  String get pollCreate => 'Create poll';

  @override
  String get pollClubEmpty => 'This club has no polls.';

  @override
  String get pollSeeAll => 'See all polls';

  @override
  String get pollMenuRateToday => 'Rate today’s menu';

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
  String get pollNoVoteRight => 'You cannot vote in this poll.';

  @override
  String pollStars(String n) {
    return 'Rating: $n';
  }

  @override
  String pollSemPercent(String text, String pct) {
    return '$text, $pct percent';
  }

  @override
  String pollVotes(String votes) {
    return 'Votes: $votes';
  }

  @override
  String pollVotesWithScore(String votes, String score) {
    return 'Votes: $votes · Points: $score';
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
    return 'Participants: $n';
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
    return '$n d left';
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
  String get pollRetractBody => 'Your vote will be removed. Continue?';

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
    return 'Ratings: $n';
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
    return '$n d';
  }

  @override
  String get pollPickDateTime => 'Select date and time';

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
  String get postComposeErrNetwork => 'No connection. Try again.';

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
  String get postComposeErrMediaInvalid => 'Invalid media. Upload it again.';

  @override
  String get postComposeErrProfanity =>
      'Inappropriate language is not allowed here. Please edit the text.';

  @override
  String get postComposeErrRate =>
      'You are posting too quickly. Please wait a moment.';

  @override
  String get postComposeErrFileTooLarge => 'The file is too large.';

  @override
  String get postComposeErrGeneric => 'Something went wrong. Try again.';

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
      'You will not see their posts or be able to message them.';

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
    return 'Some media failed to upload ($count). You can retry or remove them.';
  }

  @override
  String get postComposeInvalidRetry =>
      'Some media was invalid and will be uploaded again. Tap Share again.';

  @override
  String get postComposeNetworkDraftKept =>
      'No connection. Your draft is saved. Try again.';

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
  String get postComposeRemoveFailed => 'Could not remove';

  @override
  String get postComposeRemove => 'Remove';

  @override
  String get postComposeGallery => 'Gallery';

  @override
  String get postComposeCamera => 'Camera';

  @override
  String get postComposeSaveUnsupported =>
      'Saving is not supported on this device.';

  @override
  String get postComposeSaveDenied => 'Gallery permission was not granted.';

  @override
  String get postComposeSaveNoSpace =>
      'Not enough storage space on this device.';

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
    return 'Mention $name';
  }

  @override
  String postComposeTagAdd(String tag) {
    return 'Add tag $tag';
  }

  @override
  String postComposePostCount(String count) {
    return 'Posts: $count';
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
    return 'Tag $tag, posts: $count';
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
    return '$n d ago';
  }

  @override
  String get postViewRepliesLoadFailed => 'Could not load replies · Retry';

  @override
  String postViewShowReplies(String n) {
    return 'Show replies ($n)';
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
    return '$name’s profile';
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
  String get postViewSavedAdded => 'Post saved';

  @override
  String get postViewSavedRemoved => 'Post removed from saved';

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
  String get profileDiscardTitle => 'Unsaved changes';

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
      'Only JPEG, PNG or WebP photos can be uploaded.';

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
    return 'Last seen $date at $time';
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
  String get profileGrade => 'Year of study';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileMessage => 'Message';

  @override
  String get profileReport => 'Report';

  @override
  String get profileAboutShort => 'About';

  @override
  String get profileSignOutTitle => 'Log out?';

  @override
  String get profileSignOutBody =>
      'Your session on this device will be closed.';

  @override
  String get profileSignOut => 'Log out';

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
    return 'News: $count';
  }

  @override
  String profileNewsCountMore(String count) {
    return 'News: $count+';
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
  String get profilePrefsClubsPending => 'Pending requests';

  @override
  String get profilePrefsMyClubs => 'My clubs';

  @override
  String get profilePrefsCreateClub => 'Create a club';

  @override
  String profilePrefsMembersCount(String count) {
    return 'Members: $count';
  }

  @override
  String get profilePrefsAwaitingApproval => 'Awaiting approval';

  @override
  String get profilePrefsAwaitingPublish => 'Awaiting approval to publish';

  @override
  String get profilePrefsManage => 'Manage';

  @override
  String get profilePrefsOptions => 'Options';

  @override
  String get profilePrefsOpen => 'Open';

  @override
  String get profilePrefsManageEdit => 'Manage: edit';

  @override
  String get profilePrefsManageRequests => 'Manage: join requests';

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
  String get profilePrefsNotifCommunities => 'Clubs';

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
  String get pickGrade => 'Year of study';

  @override
  String get pickSelectGrade => 'Select year of study';

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
  String get authHintAcademic => 'Select your department and year of study.';

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
  String get supportFillFields => 'Enter a subject and a message.';

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
    return 'Views: $count. Show viewers';
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
  String get authBackToLogin => 'Back to log in';

  @override
  String get authChangeEmail => 'Change email';

  @override
  String get authNewPwSub =>
      'This replaces your old password. You will be logged out on all devices.';

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
  String get welcomeMenu => 'Today’s menu';

  @override
  String get welcomeClubs => 'Clubs and events';

  @override
  String get welcomeNote => 'Sign-up requires a school email (bingol.edu.tr).';

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
  String get profil2FieldClassYear => 'Year of study';

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
      'You can download a copy of your personal data stored in the app, as provided by data protection law.';

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
      'You can download up to 3 times a day. Keep the file safe; it contains personal information.';

  @override
  String get profil2DataOther => 'Other';

  @override
  String get profil2DataKvkk => 'Data protection notice';

  @override
  String get profil2DelWarnLead => 'This cannot be undone.';

  @override
  String get profil2DelWarnBody =>
      'Your account will be anonymized and you will no longer be able to log in.';

  @override
  String get profil2DelWhatHappens => 'What happens';

  @override
  String get profil2DelItem1 =>
      'Your name, email, photo and profile details are deleted. The account remains as \"Deleted user\".';

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
      'You can download your data before deleting your account.';

  @override
  String get profil2DelAck =>
      'I understand my account will be permanently deleted and this cannot be undone.';

  @override
  String get profil2Continue => 'Continue';

  @override
  String get profil2DelConfirmTitle => 'Confirm deletion';

  @override
  String get profil2DelConfirmBody =>
      'Enter your password to continue. Your account is anonymized right away and you are logged out on all devices.';

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
  String get profil1NewsSub => 'Latest news from the university';

  @override
  String get profil1AnnSub => 'Important announcements';

  @override
  String get profil1EventsSub => 'Reminders, changes and approvals';

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
  String get profil1QuietSub => 'Notifications stay silent during these hours';

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
    return 'Send ($n)';
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
  String get anasayfaMealLunch => 'Today’s meal · Lunch';

  @override
  String get anasayfaAnnouncements => 'Announcements';

  @override
  String get anasayfaQuickAcademic => 'Academic';

  @override
  String get gonderiTextHint => 'Write a few words…';

  @override
  String gonderiWordCount(String n, String max) {
    return '$n/$max words';
  }

  @override
  String gonderiWordLimit(String max) {
    return 'You can write up to $max words.';
  }

  @override
  String get gonderiPickPhoto => 'Choose a photo';

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
  String get yemekTodaysMenu => 'Today’s menu';

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
    return 'Effective $date';
  }

  @override
  String destekVoteLabel(String count) {
    return 'Vote. Current votes: $count';
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
  String get icerikMaintenance => 'Source unreachable; showing saved news.';

  @override
  String get icerikOpenSource => 'Open on source site';

  @override
  String get icerikShare => 'Share';

  @override
  String get icerikLinkCopied => 'News link copied.';

  @override
  String icerikSavedCount(String count) {
    return 'Saved news: $count';
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
  String get icerikGroupNews => 'News';

  @override
  String get icerikGroupAnnouncement => 'Announcements';

  @override
  String get icerikGroupEvent => 'Events';

  @override
  String get icerikGroupClub => 'Clubs';

  @override
  String get icerikGroupPerson => 'People';

  @override
  String get icerikGroupPost => 'Posts';

  @override
  String get kulupdetayRequestsTitle => 'Join requests';

  @override
  String kulupdetayPendingBanner(String count) {
    return 'Pending join requests: $count';
  }

  @override
  String get kulupdetaySendRequest => 'Send request';

  @override
  String get kulupdetayAnswerHint => 'Write your answer';

  @override
  String get kulupdetayRequired => 'This question is required.';

  @override
  String get kulupdetayApproving => 'Approving…';

  @override
  String get kulupdetayCreateTitle => 'Create club';

  @override
  String kulupdetayMembersSubtitle(String club, String count) {
    return '$club · Members: $count';
  }

  @override
  String akademik2DayHeadingToday(String day) {
    return '$day, today';
  }

  @override
  String akademik2CourseCount(String count) {
    return 'Classes: $count';
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
  String get akademik2Place => 'Location';

  @override
  String get akademik2NewTag => 'New';

  @override
  String get akademik2Attachment => 'Attachment';

  @override
  String get akademik2RemindEach => 'Before every class';

  @override
  String get akademik2BeforeClassShort => 'Before class';

  @override
  String get akademik2SemesterTitle => 'Select semester';

  @override
  String sistemuiPermStep(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get sistemuiPermNotifText =>
      'To get instant updates about messages, events and announcements.';

  @override
  String get sistemuiPermContactsText =>
      'To find university contacts in your address book and start chats. Your contacts are never sent to the server.';

  @override
  String get sistemuiPermCameraTitle => 'Camera and gallery';

  @override
  String get sistemuiPermCameraText =>
      'To scan QR codes, take photos and share them.';

  @override
  String get sistemuiOfflineTitle => 'No connection';

  @override
  String get sistemuiOfflineBody =>
      'Check your internet connection and try again.';

  @override
  String get sistemuiErrorTitle => 'Something went wrong';

  @override
  String get sistemuiMaintTitle => 'System under maintenance';

  @override
  String get sistemuiMaintBody =>
      'Please try again shortly. Your data is safe.';

  @override
  String get sistemuiMaintBand =>
      'Some features may be temporarily unavailable.';

  @override
  String sistemuiUpdateVersions(String current, String required) {
    return 'Installed version $current · Required version $required';
  }

  @override
  String get sistemuiBlockedCode => 'Error code: ACCESS_BLOCKED';

  @override
  String get sistemuiQrHint => 'Align the QR code within the frame';

  @override
  String get sistemuiQrNotice =>
      'Check-in opens at the event time. Scan the code shown by the organizer.';

  @override
  String get sistemuiQrOr => 'or';

  @override
  String get sistemuiQrManualHint => 'E.g. K7M4QX';

  @override
  String get sistemuiQrSubmit => 'Submit check-in';

  @override
  String get profilyardBlockedNote =>
      'People you block cannot see your profile, message you or follow you.';

  @override
  String get profilyardBlockedEmptyTitle => 'You have not blocked anyone';

  @override
  String get profilyardBlockedEmptyBody =>
      'You can block someone from their profile.';

  @override
  String profilyardUnblockOf(String name) {
    return 'Unblock $name';
  }

  @override
  String get profilyardClubsManaged => 'Managed by me';

  @override
  String get profilyardClubsMember => 'Clubs I belong to';

  @override
  String get profilyardClubsPending => 'Pending requests';

  @override
  String get profilyardRoleOwner => 'President';

  @override
  String get profilyardRoleFounder => 'Founder';

  @override
  String get profilyardRoleAdmin => 'Manager';

  @override
  String get profilyardRoleModerator => 'Moderator';

  @override
  String get profilyardRoleMember => 'Member';

  @override
  String get profilyardClubsEmptyTitle => 'You have no clubs yet';

  @override
  String get profilyardClubsEmptyBody =>
      'Discover and join clubs, or start your own.';

  @override
  String get profilyardClubsDiscover => 'Discover clubs';

  @override
  String get profilyardEventsAttended => 'Attending';

  @override
  String get profilyardEventsCreated => 'Created by me';

  @override
  String get profilyardEventsUpcoming => 'Upcoming';

  @override
  String get profilyardEventsPast => 'Past';

  @override
  String get profilyardEventGoing => 'Going';

  @override
  String get profilyardEventRequested => 'Request sent';

  @override
  String get profilyardEventInterested => 'Interested';

  @override
  String profilyardEventPendingCount(String count) {
    return '$count pending requests';
  }

  @override
  String get profilyardEventsEmptyTitle => 'You have no events yet';

  @override
  String get profilyardEventsEmptyBody => 'Browse events or create your own.';

  @override
  String profilyardFollowersTab(String count) {
    return 'Followers $count';
  }

  @override
  String profilyardFollowingTab(String count) {
    return 'Following $count';
  }

  @override
  String get profilyardFollowersSearch => 'Search followers';

  @override
  String get profilyardFollowingSearch => 'Search following';

  @override
  String get profilyardFollowMutual => 'You follow each other';

  @override
  String get profilyardFollowsYou => 'Follows you';

  @override
  String get profilyardFollowingYou => 'Following';

  @override
  String get profilyardFollowNoMatch => 'No matching people.';

  @override
  String get profilyardFbIntro =>
      'Help us improve the app. Share a suggestion, a bug you found or your thoughts.';

  @override
  String get profilyardFbType => 'Type';

  @override
  String get profilyardFbTitle => 'Title';

  @override
  String get profilyardFbMessage => 'Message';

  @override
  String get profilyardFbTitleHint => 'Summarize briefly';

  @override
  String get profilyardFbMessageHint => 'Write the details';

  @override
  String profilyardFbCounter(String n, String max) {
    return '$n / $max';
  }

  @override
  String get sohbetyAddMember => 'Add member';

  @override
  String sohbetyAddCount(String n) {
    return 'Add ($n)';
  }

  @override
  String get sohbetyProfile => 'Profile';

  @override
  String get sohbetyNewGroup => 'New group';

  @override
  String get sohbetyNewGroupSub => 'Up to 50 people';

  @override
  String get sohbetyGroupMin => 'Select at least 2 people for a group.';

  @override
  String get sohbetyTypePerson => 'Person';

  @override
  String get sohbetyFlash => 'Flash';

  @override
  String get sohbetyStopRec => 'Stop recording';

  @override
  String get sohbetyTakePhoto => 'Take photo';

  @override
  String get sohbetyAddDone => 'Members added';

  @override
  String get etkinlik2PolicyOpen => 'Open to everyone';

  @override
  String get etkinlik2PolicyApproval => 'By request';

  @override
  String get etkinlik2PolicyApprovalTag => 'Join by request';

  @override
  String get etkinlik2Organizer => 'Organizer';

  @override
  String get etkinlik2JoinPolicyLabel => 'Participation';

  @override
  String get etkinlik2PolicyApprovalHint =>
      'With \"By request\", you approve each participant.';

  @override
  String get etkinlik2FormClub => 'On behalf of a club (optional)';

  @override
  String get etkinlik2ClubNone => 'Not selected';

  @override
  String get etkinlik2ClubSheetTitle => 'Choose a club';

  @override
  String get etkinlik2ClubNoneOption => 'Not on behalf of a club';

  @override
  String get etkinlik2ClubNoClubs => 'You have no clubs to host an event for.';

  @override
  String get etkinlik2ChatAutoTitle => 'Event chat opens automatically';

  @override
  String get etkinlik2ChatAutoBody =>
      'You and the participants are added to the chat automatically. With join by request, only approved people get in.';

  @override
  String get etkinlik2CapacityOptional => 'Capacity (optional)';

  @override
  String get etkinlik2Unlimited => 'Unlimited';

  @override
  String etkinlik2RegOpenSlots(String n) {
    return 'Registration open · Spots left: $n';
  }

  @override
  String get etkinlik2RegOpen => 'Registration open';

  @override
  String get etkinlik2ApprovalByOrganizer =>
      'The organizer approves participation';

  @override
  String get etkinlik2SendRequest => 'Send join request';

  @override
  String get etkinlik2RequestHint =>
      'You join the event chat once the organizer approves.';

  @override
  String get etkinlik2RequestSent => 'Request sent';

  @override
  String get etkinlik2AwaitingReply => 'Waiting for a reply';

  @override
  String get etkinlik2Withdraw => 'Withdraw';

  @override
  String get etkinlik2WithdrawTitle => 'Withdraw request';

  @override
  String get etkinlik2WithdrawMessage => 'Your join request will be withdrawn.';

  @override
  String get etkinlik2ChatLocked => 'Event chat · Opens once approved';

  @override
  String get etkinlik2RejectedTitle => 'Your request was declined';

  @override
  String get etkinlik2RejectedBody =>
      'The organizer did not accept your request for this event.';

  @override
  String get etkinlik2RequestSentToast => 'Your join request was sent.';

  @override
  String get etkinlik2WithdrawnToast => 'Request withdrawn.';

  @override
  String etkinlik2GoingInterested(String going, String interested) {
    return '$going going · $interested interested';
  }

  @override
  String etkinlik2GoingOnly(String going) {
    return '$going going';
  }

  @override
  String get etkinlik2ManageRequests => 'Join requests';

  @override
  String etkinlik2ManagePending(String n) {
    return '$n pending';
  }

  @override
  String get etkinlik2ManageNoPending => 'No pending requests';

  @override
  String get etkinlik2ManageAttendance => 'Participants and check-in';

  @override
  String get etkinlik2ManageSettings => 'Event settings';

  @override
  String get etkinlik2ManageSection => 'Manage';

  @override
  String get etkinlik2ReqQuota => 'Capacity';

  @override
  String etkinlik2ReqSlotsLeft(String n) {
    return 'Spots left: $n';
  }

  @override
  String get etkinlik2ReqNoLimit => 'No capacity limit';

  @override
  String get etkinlik2ReqFullBanner =>
      'Capacity is full; new requests cannot be approved. Raise the capacity to free spots.';

  @override
  String etkinlik2ReqPendingHeader(String n) {
    return 'Pending · $n';
  }

  @override
  String get etkinlik2ReqAnsweredHeader => 'Answered';

  @override
  String get etkinlik2ReqNone => 'No pending requests.';

  @override
  String get etkinlik2Approve => 'Approve';

  @override
  String get etkinlik2Reject => 'Decline';

  @override
  String etkinlik2ApproveSem(String name) {
    return 'Approve $name’s request';
  }

  @override
  String etkinlik2RejectSem(String name) {
    return 'Decline $name’s request';
  }

  @override
  String get etkinlik2ApprovedTag => 'Approved';

  @override
  String get etkinlik2RejectedTag => 'Declined';

  @override
  String get etkinlik2ApprovedToast => 'Request approved.';

  @override
  String get etkinlik2RejectedToast => 'Request declined.';

  @override
  String get etkinlik2SettingsTitle => 'Event settings';

  @override
  String get etkinlik2SettingsPolicy => 'Participation type';

  @override
  String etkinlik2SettingsCapMin(String n) {
    return 'Confirmed participants: $n. You cannot set the capacity below that.';
  }

  @override
  String etkinlik2SettingsCapTooLow(String n) {
    return 'Capacity cannot be lower than the confirmed count ($n).';
  }

  @override
  String get etkinlik2SettingsRegChat => 'Registration and chat';

  @override
  String get etkinlik2SettingsRegOpen => 'Registration open';

  @override
  String get etkinlik2SettingsRegHint =>
      'If you turn it off, no new requests or joins are accepted.';

  @override
  String get etkinlik2SettingsChatOpen => 'Event chat open';

  @override
  String get etkinlik2SettingsChatHint =>
      'If you turn it off, messages stop and history is kept.';

  @override
  String get etkinlik2SettingsDanger => 'Danger zone';

  @override
  String etkinlik2SettingsCancelBody(String n) {
    return 'All participants ($n) are notified and the chat closes. This cannot be undone.';
  }

  @override
  String get etkinlik2SettingsSaved => 'Settings saved.';

  @override
  String get etkinlik2QrManualCaption => 'TO ENTER THE CODE MANUALLY';

  @override
  String etkinlik2QrRenewsIn(String n) {
    return 'Code renews in $n s';
  }

  @override
  String get etkinlik2AttendanceLabel => 'Check-in';

  @override
  String etkinlik2PresentOf(String present, String total) {
    return '$present / $total checked in';
  }

  @override
  String get etkinlik2FilterAll => 'All';

  @override
  String get etkinlik2FilterPresent => 'Checked in';

  @override
  String get etkinlik2FilterAbsent => 'Not checked in';

  @override
  String etkinlik2MarkSem(String name) {
    return 'Mark $name as checked in';
  }

  @override
  String get etkinlik2MethodQr => 'QR';

  @override
  String get etkinlik2MethodManual => 'Manual';

  @override
  String get etkinlik2ShowQrSem => 'Show QR code';

  @override
  String get etkinlik2AttendanceEmpty => 'No participants to show.';

  @override
  String get etkinlik2MarkFailed => 'Could not update check-in.';

  @override
  String get etkinlik2ChatClosedToast => 'Chat closed.';

  @override
  String get etkinlik2ChatOpenedToast => 'Chat opened.';

  @override
  String get etkinlik2NoteLabel => 'Note to the organizer (optional)';

  @override
  String get etkinlik2AnswerRequired => 'Please answer all questions.';

  @override
  String get etkinlik2ClubSemPrefix => 'Club';

  @override
  String cevrimdisiBekleyenMesaj(String n) {
    return 'Messages waiting to send: $n. They will be sent when you are back online.';
  }

  @override
  String cevrimdisiGonderiliyor(String n) {
    return 'Sending messages ($n)…';
  }

  @override
  String get cevrimdisiGonderilemedi => 'Not sent';

  @override
  String cevrimdisiSonGuncelleme(String zaman) {
    return 'Last updated: $zaman';
  }

  @override
  String get cevrimdisiKayitliVeri => 'Showing saved data';

  @override
  String get cevrimdisiBekliyor => 'Waiting';

  @override
  String get cevrimdisiYenidenDene => 'Try again';

  @override
  String get cevrimdisiMedyaBaglanti => 'Try again when you are back online';

  @override
  String get cevrimdisiInternetYok => 'No internet connection';

  @override
  String get bildirimmobilKanalChat => 'Messages';

  @override
  String get bildirimmobilKanalEvent => 'Events';

  @override
  String get bildirimmobilKanalAnnouncement => 'Announcements and news';

  @override
  String get bildirimmobilKanalSocial => 'Social (likes, follows)';

  @override
  String get bildirimmobilKanalPoll => 'Polls';

  @override
  String get bildirimmobilKanalAcademic => 'Class and exam reminders';

  @override
  String get evcLabelClub => 'Club';

  @override
  String get evcInfoInstant => 'Published right away.';

  @override
  String get evcInfoReview => 'Published after admin approval.';

  @override
  String get evcClubRequiredHint => 'Select a club first.';

  @override
  String get evcEmptyTitle =>
      'You need to be a club manager to create an event';

  @override
  String get evcEmptyBody =>
      'Events are created on behalf of clubs. Once you manage a club you can create events here.';

  @override
  String get evcBrowseClubs => 'Browse clubs';

  @override
  String get evcSubmittedTitle => 'Submitted for approval';

  @override
  String get evcSubmittedBody =>
      'Your event will be published after admin approval. You can follow its status in the Created tab.';

  @override
  String get evcOk => 'OK';

  @override
  String get evcStatusPending => 'Awaiting approval';

  @override
  String get evcStatusRejected => 'Rejected';

  @override
  String evcRejectReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get evcErrClubRequired =>
      'Events are created on behalf of a club. Select a club.';

  @override
  String get evcErrForbidden =>
      'You are not allowed to create events for this club.';

  @override
  String get evcErrClubNotActive => 'This club is not active right now.';

  @override
  String get evcErrPast => 'The event cannot start in the past.';

  @override
  String get evcErrDates => 'The end must be after the start.';

  @override
  String get evcErrProfanity =>
      'The text contains inappropriate language. Please edit it.';

  @override
  String get evdLabelDate => 'Date';

  @override
  String get evdLabelTime => 'Start time';

  @override
  String get evdLabelDuration => 'Duration';

  @override
  String get evdChipToday => 'Today';

  @override
  String get evdChipTomorrow => 'Tomorrow';

  @override
  String get evdChipWeekend => 'This weekend';

  @override
  String get evdChipNextWeek => 'Next week';

  @override
  String get evdChipPickDate => 'Select date';

  @override
  String get evdChipCustomTime => 'Custom time';

  @override
  String get evdDur1h => '1 hour';

  @override
  String get evdDur2h => '2 hours';

  @override
  String get evdDurHalfDay => 'Half day';

  @override
  String get evdChipCustomEnd => 'Select end date';

  @override
  String get evdErrStartPast => 'The start cannot be in the past.';

  @override
  String get evdErrEndBeforeStart => 'The end must be after the start.';

  @override
  String get evdEndAdjusted =>
      'The end was automatically set to 1 hour after the start.';

  @override
  String evdDescCounter(String count, String max) {
    return '$count/$max';
  }

  @override
  String evdErrDescTooLong(String max) {
    return 'The description can be at most $max characters.';
  }

  @override
  String get evdErrDescTooLongServer =>
      'The description is too long. Please shorten it.';

  @override
  String get clubMgmtCategoryNone => 'Not selected';

  @override
  String clubMgmtCategoryInactive(String name) {
    return '$name (no longer in use)';
  }

  @override
  String get clubMgmtCategoryInvalid =>
      'The selected category is not valid. Choose another one from the list.';

  @override
  String get errEmailAliasNotAllowed =>
      'A + tag cannot be used in the email address.';

  @override
  String get errPasswordTooLong =>
      'The password is too long: at most 72 bytes (Turkish and Arabic characters take more than one byte).';

  @override
  String get errPayloadTooLarge =>
      'The data you sent is too large. Try a smaller file or shorter text.';

  @override
  String get errUploadBusy =>
      'Another upload is in progress or the server is busy. Please wait a moment and try again.';

  @override
  String get errUploadQuota =>
      'You have uploaded too much. Please try again a little later.';

  @override
  String get errMailQuota =>
      'We cannot send verification codes right now. Please try again later.';

  @override
  String get errServiceBusy =>
      'The system is busy right now. Please try again in a few seconds.';

  @override
  String get errLegalReaccept =>
      'The agreements have been updated. You need to accept the updated agreements to continue.';

  @override
  String coreErrRetryAfterSec(String n) {
    return 'Try again in $n s.';
  }

  @override
  String coreErrRetryAfterMin(String n) {
    return 'Try again in $n min.';
  }

  @override
  String get clubPostTextRequired => 'Add some text to share with the image.';

  @override
  String get etkinlik2QrExpired => 'Expired, refreshing…';

  @override
  String get updateRequiredRecheck => 'Check again';

  @override
  String get legalReacceptTitle => 'Agreements updated';

  @override
  String get legalReacceptIntro =>
      'We have updated our terms and privacy documents. To keep using the app, please read and accept the updated documents.';

  @override
  String get legalReacceptIntroSoft =>
      'New versions of some documents have been published. You can review and accept them now or later; you will need to accept them in the coming days.';

  @override
  String get legalReacceptListTitle => 'Updated documents';

  @override
  String get legalReacceptTypeTerms => 'Terms of Use';

  @override
  String get legalReacceptTypePrivacy => 'Privacy Policy';

  @override
  String get legalReacceptTypeKvkk => 'Data Protection Notice (KVKK)';

  @override
  String get legalReacceptTypeRules => 'Community Rules';

  @override
  String get legalReacceptNoteExplicit =>
      'Optional explicit consents are separate from this acceptance and are not given by it.';

  @override
  String get legalReacceptCheck =>
      'I have read and accept the updated documents';

  @override
  String get legalReacceptAccept => 'Accept';

  @override
  String get legalReacceptLater => 'Later';

  @override
  String get legalReacceptDecline => 'I do not accept';

  @override
  String get legalReacceptDeclineTitle =>
      'You cannot continue without accepting';

  @override
  String get legalReacceptDeclineBody =>
      'If you do not accept the current agreements you cannot use the app. You can delete your account, or sign out and decide again later.';

  @override
  String get legalReacceptDeleteAccount => 'Delete my account';

  @override
  String get legalReacceptSignOut => 'Sign out';

  @override
  String get legalReacceptOutdated =>
      'The documents were updated again. Please review the new versions and accept again.';

  @override
  String get authVerifyPasswordLabel => 'The password you chose at sign-up';

  @override
  String get authVerifyPasswordNote =>
      'For security, enter the password you used when registering again.';

  @override
  String get authVerifyPasswordRequired =>
      'Enter the password you chose at sign-up.';

  @override
  String get chatClosedBanner =>
      'This conversation was closed by an administrator.';

  @override
  String get chatAdminRemovedMsg =>
      'This message was removed by an administrator';

  @override
  String get chatModRemovedMsg => 'This message was removed';

  @override
  String get errCertificateRevoked =>
      'This certificate was revoked by an administrator.';

  @override
  String get clubUnavailable => 'This club is not available right now.';

  @override
  String get profil2DelItemUsage =>
      'Your device, IP and usage (analytics) records are deleted immediately.';

  @override
  String get profil2DelItemClubOwner =>
      'Clubs you own are transferred to an admin member; if there is no candidate, the club is closed.';

  @override
  String get settingsCrashReports => 'Send crash reports';

  @override
  String get settingsCrashReportsDesc =>
      'When the app hits an error or closes unexpectedly, an anonymous crash report is sent to the BÜ Kampüs server: app version, operating system, error type and a technical stack trace without personal data. Your email, password, message content or identity are never sent, and nothing goes to third-party services. You can turn this off at any time.';

  @override
  String get welcomeChipNews => 'News';

  @override
  String get welcomeChipMenu => 'Menu';

  @override
  String get welcomeChipClubs => 'Clubs';

  @override
  String get authLangTitle => 'Choose language';

  @override
  String get authPaste => 'Paste';

  @override
  String get authResetDoneTitle => 'Password updated';

  @override
  String get authResetDoneBody =>
      'You can now sign in with your new password. Sessions on other devices were signed out.';

  @override
  String get authTrustAcademic =>
      'Your department is used to show you relevant announcements and clubs.';

  @override
  String get authTrustName =>
      'Your name is visible to other students on your profile and in chats.';

  @override
  String get authTrustPassword =>
      'Your password is stored only as a one-way hash; nobody can read it.';

  @override
  String get authTrustCode =>
      'If the email has not arrived, check your spam folder too.';

  @override
  String get authTrustSecure => 'Your connection is encrypted and secure.';

  @override
  String p00StepOf(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get p05NewsEmptyBody =>
      'New items will show up here when they arrive.';

  @override
  String get p05SavedEmptyTitle => 'No favorites yet';

  @override
  String get p05SavedToast => 'Added to favorites';

  @override
  String get p05UnsavedToast => 'Removed from favorites';

  @override
  String get p05SearchIdleTitle => 'Search the campus';

  @override
  String get p05SearchNoResultsBody =>
      'Try a different word or check the spelling.';

  @override
  String get p05Source => 'Source';

  @override
  String p05ReadMinutes(String count) {
    return '$count min read';
  }

  @override
  String p17WeekOf(String n, String total) {
    return 'Week $n of $total';
  }

  @override
  String get p17SemesterName => 'Semester name';

  @override
  String get p17NoClassesTitle => 'Your timetable is empty';

  @override
  String get p17ExamsEmptyTitle => 'No exams yet';

  @override
  String get p17OfficialEmptyTitle => 'No official schedule yet';

  @override
  String get p17SemestersEmptyTitle => 'No semesters';

  @override
  String get p17MaintenanceTitle => 'Under maintenance';

  @override
  String get p17PreviewHint => 'Preview';

  @override
  String get p16QrCopy => 'Copy code';

  @override
  String get p16QrCopied => 'Code copied';

  @override
  String get p16ReqNoneBody => 'New join requests will show up here.';

  @override
  String get p16AttEmptyBody =>
      'Attendees are listed here as they join the event.';

  @override
  String get p16AttFilterEmpty => 'No one matches this filter.';

  @override
  String get p16PolicyOpenHint =>
      'Anyone can join directly without sending a request.';

  @override
  String p16AttPresentCount(String n) {
    return '$n checked in';
  }

  @override
  String get p10PageTitle => 'Add media';

  @override
  String get p10SheetTitle => 'Add';

  @override
  String get p10SheetSubtitle => 'What would you like to send?';

  @override
  String get p10SourcePhotos => 'Photos';

  @override
  String get p10SourcePhotosHint => 'Pick one or more photos from your library';

  @override
  String get p10SourceVideo => 'Video';

  @override
  String get p10SourceVideoHint =>
      'Pick a video from your library (up to 60 s)';

  @override
  String get p10SourceCamera => 'Camera';

  @override
  String get p10SourceCameraHint => 'Take a photo or record a video';

  @override
  String get p10PrivacyNote =>
      'Only the items you pick are shared. Your whole library stays private.';

  @override
  String get p10PickedHeader => 'Selected';

  @override
  String get p10EmptyTitle => 'Nothing selected yet';

  @override
  String get p10EmptyBody =>
      'Start by choosing photos, a video or the camera above.';

  @override
  String get p10Preview => 'Preview';

  @override
  String get p10Remove => 'Remove';

  @override
  String get p10PickFailed => 'Could not open the picker. Please try again.';

  @override
  String get p14Today => 'Today';

  @override
  String get p14Tomorrow => 'Tomorrow';

  @override
  String get p14ClearDay => 'Whole month';

  @override
  String get p14Ended => 'Ended';

  @override
  String get p14Live => 'Live now';

  @override
  String p14EventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get p14EmptyMonthBody =>
      'Browse another month; new events show up here as soon as they are added.';

  @override
  String get p14EmptyDayBody => 'Pick another day or see the whole month.';

  @override
  String get p14EmptyUpcomingBody =>
      'Join club events and the ones you attend are collected here.';

  @override
  String get p14EmptyPastBody =>
      'Events you attended are kept here once they end.';

  @override
  String get p14EmptyCreatedBody =>
      'Create an event for your club and manage requests and attendance here.';

  @override
  String get p13SuppAskTitle => 'How can we help you?';

  @override
  String get p13SuppAskBody => 'Browse the FAQ or write to the support team.';

  @override
  String get p13TicketIntro =>
      'Describe your issue briefly; the support team will reply as soon as possible.';

  @override
  String get p13TicketsEmptyHint =>
      'If you run into a problem, you can create a new request.';

  @override
  String get p13FeedbackEmptyHint =>
      'The suggestions and bug reports you send are listed here.';

  @override
  String get p13SugEmptyTitle => 'Ideas gather here';

  @override
  String get p13PollEmptyOpenHint =>
      'New polls will appear here when they open.';

  @override
  String get p13PollEmptyMineHint => 'Polls you vote in are listed here.';

  @override
  String get p13PollEmptyClosedHint => 'Results of ended polls are kept here.';

  @override
  String get p13Rate1 => 'Very bad';

  @override
  String get p13Rate2 => 'Poor';

  @override
  String get p13Rate3 => 'Okay';

  @override
  String get p13Rate4 => 'Good';

  @override
  String get p13Rate5 => 'Excellent';

  @override
  String get p13Leading => 'Leading';

  @override
  String p08ItemOf(String n, String total) {
    return '$n / $total';
  }

  @override
  String get p08Pause => 'Pause';

  @override
  String get p08Seek => 'Video position';

  @override
  String get p08OnceHint =>
      'Once you close it, this photo can\'t be opened again.';

  @override
  String get p13TicketsHeading => 'My requests';

  @override
  String get p13ShareHeading => 'Share your thoughts';

  @override
  String get p13FeedbackMine => 'My submissions';

  @override
  String get p11ReadMore => 'Show more';

  @override
  String get p11ReadLess => 'Show less';

  @override
  String get p11TypeSingleHint => 'Voters pick one option';

  @override
  String get p11TypeMultiHint => 'Voters can pick several options';

  @override
  String get p11TypeRankedHint => 'Options are ranked by preference';

  @override
  String get p11TypeRatingHint => 'Rated with 1-5 stars';

  @override
  String get p11RequestsEmptyBody => 'New join requests will show up here.';

  @override
  String get p06EmptyNoneBody =>
      'Start messaging your friends, student clubs or event groups.';

  @override
  String p06NoMatchBody(String q) {
    return 'No person, club or message matches “$q”.';
  }

  @override
  String get p06ResetSearch => 'Reset search';

  @override
  String get p06ArchiveEmptyBody =>
      'Archived chats are kept here and keep your inbox tidy.';

  @override
  String get p06BackToChats => 'Back to chats';

  @override
  String get p06LoadFailedTitle => 'Could not load, try again';

  @override
  String get p06LoadFailedBody =>
      'A connection error occurred while updating the chat list. Please check your connection.';

  @override
  String get p06MenuDeleteChat => 'Delete chat';

  @override
  String get p08OnceSubtitle => 'Can only be viewed once';

  @override
  String get p08OnceSentSub => 'One-time view';

  @override
  String get p08ModerationTitle => 'Moderation notice';

  @override
  String p08Percent(String n) {
    return '$n%';
  }

  @override
  String get p08PhotoLoadingSub => 'Downloading from the server';

  @override
  String get p08Queued => 'Queued · Waiting';

  @override
  String get p01ConfigTitle => 'Configuration error';

  @override
  String get p01ConfigBody =>
      'The server address (API_BASE) is not secure (https). Rebuild the app with the correct address.';

  @override
  String get p01ConfigCode => 'ERROR CODE • BUILD_ENV';

  @override
  String get p01UpdateNoticeLabel => 'App update';

  @override
  String get p01PushNow => 'now';

  @override
  String p01PushMore(String n) {
    return '+$n more messages';
  }

  @override
  String get p01PushReply => 'Tap to reply';

  @override
  String p01PermDeniedTitle(String title) {
    return '$title permission not granted';
  }

  @override
  String get p01QrAttended => 'Attendance recorded';

  @override
  String get p07ChatEmptyTitle => 'No messages yet';

  @override
  String get p07ChatEmptyBody => 'Send the first one.';

  @override
  String get p07ChatBlockedLine =>
      'You can\'t message someone you have blocked.';

  @override
  String get p02WelcomeNewsSub => 'Instant alerts and campus updates.';

  @override
  String get p02WelcomeMenuSub => 'Daily calories and detailed meal contents.';

  @override
  String get p02WelcomeClubsSub => 'Clubs, workshops and attendance check-in.';

  @override
  String get p02BrandSub => 'Independent student app';

  @override
  String get p02LoginBusy => 'Signing in…';

  @override
  String get p02PwStrengthTitle => 'Password strength';

  @override
  String get p02TipTitle => 'Tip';

  @override
  String p02FacultyCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n departments',
      one: '1 department',
    );
    return '$_temp0';
  }

  @override
  String get p02PendingTitle => 'Verify your email';

  @override
  String get p02PendingBody =>
      'Your account must be verified before you can sign in.';

  @override
  String get p02ReplacedTitle => 'Session ended';

  @override
  String get p01LgLoadFailed => 'Could not load, try again';

  @override
  String p01LgMetaLine(String version, String date) {
    return 'Version $version · Effective: $date';
  }

  @override
  String get p03MenuTotal => 'Total';

  @override
  String get p03MenuTotalEnergy => 'Total energy';

  @override
  String p03MenuKcal(String n) {
    return '$n kcal';
  }

  @override
  String p03MenuAtLeast(String n) {
    return 'At least $n kcal';
  }

  @override
  String get p03MenuKcalMissing => 'Calories are missing for some dishes';

  @override
  String get p03MenuKcalNone => 'No calorie info';

  @override
  String get p03MenuNoList => 'No menu available.';

  @override
  String get p03MenuMaintenance => 'System under maintenance.';

  @override
  String p03NotifNewCount(String n) {
    return '$n new';
  }

  @override
  String get p03NotifEmptyBody => 'Club, event and message alerts appear here.';

  @override
  String get p03NotifUnreadEmptyBody => 'You are all caught up.';

  @override
  String get p03NotifLoadFailed => 'Could not load, try again';

  @override
  String get p03NotifLoadingMore => 'Loading more...';

  @override
  String get p03HomeMealTitle => 'Menu of the Day';

  @override
  String get p03HomeNoMenuBody =>
      'The cafeteria menu has not been entered yet.';

  @override
  String get p03HomeEventsTitle => 'Upcoming Events';

  @override
  String get p03HomeNoEventBody =>
      'There are no scheduled club events right now.';

  @override
  String get p05NewsOpenSource => 'Open source page';

  @override
  String get p05NewsErrorTitle => 'Could not load the content';

  @override
  String get p05NewsErrorBody =>
      'There was a problem loading the content. Please check your internet connection and try again.';

  @override
  String p05SearchCountFor(String q) {
    return 'for “$q”';
  }

  @override
  String p05SearchFoundNews(String n) {
    return '$n NEWS FOUND';
  }

  @override
  String p05SearchFoundEvents(String n) {
    return '$n EVENTS FOUND';
  }

  @override
  String p05SearchFoundClubs(String n) {
    return '$n CLUBS FOUND';
  }

  @override
  String p05SearchFoundPeople(String n) {
    return '$n PEOPLE FOUND';
  }

  @override
  String p05SearchFoundPosts(String n) {
    return '$n POSTS FOUND';
  }

  @override
  String p05SearchSeeAllN(String n) {
    return 'See all ($n)';
  }

  @override
  String get p05SearchRemoveRecent => 'Remove search';

  @override
  String get p11PendingInfoTitle => 'Application under review';

  @override
  String get p11PendingInfoBody =>
      'Your join request is waiting for the club managers to approve it. You will be notified once it is decided.';

  @override
  String get p11LockPrivateTitle => 'This club is private';

  @override
  String get p11LockPrivateBody =>
      'Only approved members can see its posts and member list.';

  @override
  String get p11LockMembersTitle => 'Content is for members only';

  @override
  String get p11LockMembersBody =>
      'Club posts become visible after your request is approved.';

  @override
  String get p11LockBannedTitle => 'Content unavailable';

  @override
  String get p11LockBannedBody =>
      'Club content is hidden because your access is restricted.';

  @override
  String get p11BannedTitle => 'You were removed from the club';

  @override
  String get p11BannedBody =>
      'You cannot join this club or apply to its events.';

  @override
  String get p11ApprovalNote =>
      'Club content opens once the managers approve your request.';

  @override
  String get p11PostPinSub => 'Place it at the top of the club page';

  @override
  String get p11PostUnpinSub => 'Return the post to its normal order';

  @override
  String get p11PostDeleteSub => 'Remove the post from the feed permanently';

  @override
  String get p11PostReportSub => 'Report a violation of the rules';

  @override
  String get p11PollsSub => 'Member decisions and choices';

  @override
  String p11SearchEmptyBody(String query) {
    return 'No club member matches “$query”. Check the name and try again.';
  }

  @override
  String get p11ClearSearch => 'Clear search';

  @override
  String get p11RequestsEmptyAll =>
      'All requests have been answered or none has arrived yet.';

  @override
  String get p11LoadErrorBody =>
      'A connection error occurred. The data could not be fetched.';

  @override
  String get p12LogoAdd => 'Add logo';

  @override
  String get p12LogoChange => 'Change logo';

  @override
  String get p12LogoHint => 'Square profile (1:1)';

  @override
  String get p12CoverHint => 'A 16:9 landscape image is recommended';

  @override
  String get p12QuestionsSubtitle => 'A short form for applicants';

  @override
  String get p12QuestionPlaceholder => 'Write your question...';

  @override
  String get p12ConsentNote =>
      'By creating a club you agree to follow the community guidelines and student rules.';

  @override
  String get p12PartialTitle => 'Partially saved';

  @override
  String get p12CategorySheetTitle => 'Choose a category';

  @override
  String get p12JoinNote =>
      'You will be notified when your request is approved.';

  @override
  String p12CountClubs(String count) {
    return '$count clubs';
  }

  @override
  String p12CountRequests(String count) {
    return '$count requests';
  }

  @override
  String get p15PublishRoleActive => 'Manager access active';

  @override
  String get p15CoverOptional => 'Optional';

  @override
  String get p15CoverHint => '16:9 landscape recommended • Up to 3 MB';

  @override
  String get p15CoverChange => 'Change';

  @override
  String get p15CoverSheetTitle => 'Cover photo';

  @override
  String get p15CoverGallerySub => 'Pick an image from your device albums';

  @override
  String get p15CoverCameraSub => 'Take a photo right now with the camera';

  @override
  String get p15CoverRemoveSub => 'Go back to the default placeholder image';

  @override
  String p15ErrBannerTitle(String n) {
    return 'Please fix the $n error(s) in the form.';
  }

  @override
  String get p15ErrBannerBody =>
      'Some of the information you entered is missing or breaks the rules. Check the marked fields.';

  @override
  String get p15ErrHint =>
      'The create button becomes active automatically once the required fields are fixed.';

  @override
  String p15ErrLocked(String n) {
    return 'Fix the $n validation error(s) first';
  }

  @override
  String get p15ErrForbiddenTitle => 'Permission restricted';

  @override
  String get p15ErrInactiveTitle => 'Club is inactive';

  @override
  String get p15PickerSubtitle =>
      'The club you manage that will host the event';

  @override
  String get p15PickerSearch => 'Search clubs…';

  @override
  String get p15PickerNoMatch => 'No matching club.';

  @override
  String p15PickerMembers(String n) {
    return '$n members';
  }

  @override
  String get p15PickerInfoTitle => 'About permissions';

  @override
  String get p15PickerInfoBody =>
      'Events in clubs where you are a manager or moderator are published right away. Events by members with event permission are published after admin approval.';

  @override
  String get p15PickerEmptyBody =>
      'You are not a manager or moderator of any club.';

  @override
  String get p15RefreshPerms => 'Refresh permissions';

  @override
  String get p16ReqQuotaStatus => 'Capacity status';

  @override
  String get p16ReqRegistered => 'Registered';

  @override
  String get p16ReqUnlimitedTitle => 'Attendee quota';

  @override
  String get p16ReqPendingTitle => 'Pending requests';

  @override
  String get p16ReqNoteLabel => 'Application note';

  @override
  String get p16ReqFullTitle => 'Capacity reached';

  @override
  String get p16ReqFullBody =>
      'New requests can\'t be approved. Raise the capacity or update the attendee list to free up a spot.';

  @override
  String get p16ReqRaiseQuota => 'Raise capacity';

  @override
  String p16ReqFullPeople(String a, String b) {
    return '$a / $b people';
  }

  @override
  String get p16ReqCantApprove => 'Can\'t approve: not enough capacity';

  @override
  String get p16ReqErrTitle => 'The request list couldn\'t be updated.';

  @override
  String get p16ReqBackToEvent => 'Back to event details';

  @override
  String get p16ReqEmptyBody =>
      'All requests have been answered or no new request has arrived yet.';

  @override
  String p16SetApproved(String n) {
    return '$n approved attendees';
  }

  @override
  String get p16SetOpenSub => 'Everyone who registers is approved right away.';

  @override
  String get p16SetApprovalSub =>
      'Every request goes through organizer approval.';

  @override
  String get p16SetCapLabel => 'Capacity (people)';

  @override
  String p16SetCapCurrent(String n) {
    return 'Current: $n people';
  }

  @override
  String get p16SetCapDec => 'Decrease capacity';

  @override
  String get p16SetCapInc => 'Increase capacity';

  @override
  String p16SetCancelNote(String n) {
    return '$n attendees will be notified right away and the event will be removed from the lists.';
  }

  @override
  String get p16QrStatusTitle => 'Attendance status';

  @override
  String get p16QrStatusSub => 'Live attendance record';

  @override
  String get p16QrList => 'Attendee list';

  @override
  String get p16QrExpiredTitle => 'Expired';

  @override
  String get p16QrRefreshing => 'Refreshing…';

  @override
  String get p16QrErrBody =>
      'Couldn\'t reach the server or the session timed out.';

  @override
  String get p16QrCopyBtn => 'Copy';

  @override
  String get p16AttTitle => 'Attendees and attendance';

  @override
  String get p16AttWaiting => 'Waiting';

  @override
  String get p16AttFilterEmptyBody => 'No attendee matches this filter.';

  @override
  String p16AttMarkedToast(String name, String method) {
    return '$name was marked present ($method)';
  }

  @override
  String p16AttUnmarkedToast(String name) {
    return '$name was removed from attendance';
  }

  @override
  String get p07ChatSearchClear => 'Clear';

  @override
  String get p17DailyFlow => 'Daily schedule';

  @override
  String p17DayPlanned(String n) {
    return '$n classes scheduled';
  }

  @override
  String get p17SlotWaiting => 'Upcoming';

  @override
  String p17RoomLabel(String room) {
    return 'Room $room';
  }

  @override
  String p17HoursPerWeek(String n) {
    return '$n h / week';
  }

  @override
  String get p17NoSemesterTitle => 'No semester yet';

  @override
  String get p17NoSemesterBody => 'Add a semester to organise your classes.';

  @override
  String get p17NoCourseTitle => 'You have not added a course yet';

  @override
  String get p17NoCourseBody =>
      'Save your first course to build your weekly timetable.';

  @override
  String get p17DayFreeBody =>
      'Spend the day resting, studying in the library or having a coffee on campus!';

  @override
  String get p17TodayDoneBody =>
      'You have finished all of today\'s classes. Enjoy your rest.';

  @override
  String get p17WeekDoneBody =>
      'This week\'s schedule is over. You are ready for next week!';

  @override
  String get p17OutOfRangeBody =>
      'The selected day is outside the academic calendar.';

  @override
  String get p17LoadErrTitle => 'There was a problem loading the timetable.';

  @override
  String p17SemesterCount(String n) {
    return '$n saved semesters';
  }

  @override
  String get p17CheckFields => 'Please check the following fields:';

  @override
  String get p17ExamDetail => 'Details';

  @override
  String get p17ExamsNoUpcomingBody =>
      'Congratulations! There is no upcoming midterm, final or quiz right now.';

  @override
  String get p17ExamsEmptyMineTitle => 'You have not added a personal exam.';

  @override
  String get p17ExamsEmptyMineBody =>
      'Add your first exam to build your schedule and follow the countdown.';

  @override
  String get p17OfficialEmptyBody =>
      'Your department\'s exam schedule will be listed here once announced.';

  @override
  String get p17CourseInfoSemantic => 'Course details';

  @override
  String get p20EditProfile => 'Edit profile';

  @override
  String get p20HubExamPlan => 'Exam plan';

  @override
  String get p20HubNoDeptTitle => 'No department in your profile';

  @override
  String get p20HubNoDeptBody =>
      'Complete your faculty details for a timetable and personalised announcements.';

  @override
  String get p20HubTimetableEmptyBody =>
      'Add your courses to follow your weekly flow and build your class calendar.';

  @override
  String get p20HubExamBadge => 'Midterm & Final';

  @override
  String get p20HubExamEmptyBody =>
      'Congratulations! No midterm or final is planned in your calendar right now.';

  @override
  String get p20HubCalEmptySub => 'The in-semester date ranges are over';

  @override
  String get p20HubAnnEmptyTitle => 'No unread announcements';

  @override
  String get p20HubAnnEmptyBody =>
      'New notices from your department office or advisor will be listed here.';

  @override
  String get p20HubDateTime => 'Date & time';

  @override
  String p20CalToday(String date) {
    return 'Today: $date';
  }

  @override
  String get p20CalSelected => 'Selected';

  @override
  String get p20CalImportant => 'Important date';

  @override
  String get p20Yesterday => 'Yesterday';

  @override
  String get p20AnnFooterTitle => 'No more announcements for your department.';

  @override
  String get p20AnnFooterBody =>
      'You will be notified when new calendar and exam notices are published.';

  @override
  String get p20AnnLinkErrBody =>
      'The file server could not be reached. Please check your connection.';

  @override
  String get p20RemPermTitle => 'Notification permission not granted';

  @override
  String get p20RemPermBody =>
      'Reminders need the system notification permission to ring on time.';

  @override
  String get p20RemOpenSettings => 'Open in settings';

  @override
  String p13PollArchiveCount(String n) {
    return '$n Polls Archived';
  }

  @override
  String get p13PollArchiveHeading => 'Concluded Polls';

  @override
  String p13PollAvgOutOf(String avg) {
    return '$avg out of 5';
  }

  @override
  String get p13PollAvgTitle => 'Average Satisfaction';

  @override
  String get p13PollChangeNote => 'You can change your mind after voting.';

  @override
  String get p13PollClosingSoon => 'Ending soon';

  @override
  String get p13PollClubEmptyBody =>
      'Club managers have not shared any poll for voting yet.';

  @override
  String get p13PollDateTime => 'Date and time';

  @override
  String get p13PollEditMode => 'Changing your vote';

  @override
  String get p13PollEditNote =>
      'When you change your choice, your previous vote is cancelled automatically and your new choice is counted.';

  @override
  String get p13PollEmptyClosedBody =>
      'Concluded polls are moved to the archive.';

  @override
  String get p13PollEmptyMineBody =>
      'Polls you have voted in are collected here.';

  @override
  String get p13PollEmptyOpenBody =>
      'New polls will be listed here when they open.';

  @override
  String get p13PollErrBody => 'Could not connect to the server';

  @override
  String get p13PollFormType => 'Poll type';

  @override
  String get p13PollHowTo => 'How does voting work?';

  @override
  String get p13PollMin2 => 'At least 2 options';

  @override
  String get p13PollOptionsTitle => 'Options';

  @override
  String get p13PollPickEndDate => 'Select end date';

  @override
  String get p13PollPickEndTime => 'Select end time';

  @override
  String get p13PollPrefs => 'Participation settings';

  @override
  String get p13PollPrevChoice => 'Your previous choice';

  @override
  String get p13PollQuick => 'Quick duration';

  @override
  String p13PollRankLabel(String n) {
    return 'Choice $n';
  }

  @override
  String get p13PollRankReset => 'Tap an option again to reset the ranking.';

  @override
  String get p13PollRankTap => 'Tap to select';

  @override
  String get p13PollRateCta => 'Rate';

  @override
  String get p13PollSecretBody =>
      'Your identity cannot be seen by any administrator, club representative or student.';

  @override
  String p13PollSelectedCount(String n, String max) {
    return '$n / $max selected';
  }

  @override
  String get p13PollTopOption => 'Most voted option';

  @override
  String get p13PollTypeMultiHint => 'Several options can be selected';

  @override
  String get p13PollTypeRankedHint => 'Order by preference';

  @override
  String get p13PollTypeRatingHint => 'Rate with 1-5 stars';

  @override
  String get p13PollTypeSingleHint => 'Only one option can be chosen';

  @override
  String get p13PollVisAfterCloseSub => 'No data is shown until the poll ends';

  @override
  String get p13PollVisAfterVoteSub => 'Shown to a user after they vote';

  @override
  String get p13PollVisAlwaysSub => 'All votes can be followed live';

  @override
  String get p13PollYourScore => 'Your rating';

  @override
  String get p17MyCourses => 'My courses';

  @override
  String p11LikeCount(String count) {
    return '$count likes';
  }

  @override
  String get p11CaseSensitive => 'Case sensitive';

  @override
  String get p12BasicInfo => 'Basic information';

  @override
  String get p12VisibilityAndJoin => 'Visibility and joining';

  @override
  String get p17ConflictIntro => 'The times clash with these courses:';

  @override
  String p17ColorSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get p17WeekDay => 'Day of the week';

  @override
  String get p13PollViewAll => 'View All';

  @override
  String get p13PollReview => 'Review Vote';

  @override
  String get p13PollOpenBadge => 'Open poll';

  @override
  String get p13PollClosedKicker => 'Closed poll';

  @override
  String p13PollDone(String n) {
    return 'Completed · $n votes';
  }

  @override
  String p13PollWinner(String name, String pct) {
    return 'Winner: $name ($pct%)';
  }

  @override
  String get p13PollOneVote => 'One vote';

  @override
  String get p13PollHiddenResults => 'Hidden results';

  @override
  String get p13PollVoteCta => 'Vote';

  @override
  String get p13PollNoMoreActive => 'This club has no other active poll.';

  @override
  String get p13PollNoMoreBody =>
      'Community decisions and event preferences are published here.';

  @override
  String get p04DiscoverSub => 'Catch the pulse of campus and live posts';

  @override
  String get p04SearchHint => 'Search campus: clubs, events, people...';

  @override
  String get p04ChipAll => 'All';

  @override
  String get p04SuggestTitle => 'People You May Know';

  @override
  String get p04SuggestSeeAll => 'See All';

  @override
  String get p04FollowAction => 'Follow';

  @override
  String get p04FollowingState => 'Following';

  @override
  String get p04FeedTitle => 'Student Feed';

  @override
  String p04LikeCount(String count) {
    return '$count likes';
  }

  @override
  String get p11UnavailableBody =>
      'This community is temporarily frozen or under review.';

  @override
  String get p11UnderReview => 'Under review';

  @override
  String get p12ConsentBold => 'community guidelines';

  @override
  String get p03NotifLoadFailedBody =>
      'The latest updates could not be synced with the server. Please check your connection.';

  @override
  String p03NotifShortDay(String n) {
    return '${n}d';
  }

  @override
  String p05SearchLikes(String n) {
    return '$n likes';
  }

  @override
  String get p05SearchErrorTitle => 'Could not load results';

  @override
  String get p05SearchErrorBody =>
      'A connection error occurred while fetching search results.';

  @override
  String get p13PollDistribution => 'Option Distribution';

  @override
  String get p13PollWinnerOption => 'Winning Option';

  @override
  String get p13PollRatingSummary => 'Rating summary';

  @override
  String get p13PollOutOf5 => 'out of 5';

  @override
  String get p13MenuRated => 'Your rating has been saved. Thank you!';

  @override
  String get p04CropProfileTitle => 'Crop photo';

  @override
  String get p04CropPostTitle => 'Post photo';

  @override
  String get p04CropLogoTitle => 'Club logo';

  @override
  String get p04CropCoverTitle => 'Cover photo';

  @override
  String get p04CropChatTitle => 'Chat image';

  @override
  String get p04CropHint => 'Drag and pinch to zoom';

  @override
  String get p04CropRotate => 'Rotate';

  @override
  String get p04CropReset => 'Reset';

  @override
  String get p04CropScale => 'Photo scale';

  @override
  String get p04CropCrop => 'Crop';

  @override
  String get p04CropError =>
      'The photo could not be processed. Try another photo.';

  @override
  String get p04CropPreviewProfile => 'How it will look on your profile';

  @override
  String get p04CropPreviewFeed => 'How it will look in the feed';

  @override
  String get p04CropPreviewTitle => 'Preview';

  @override
  String get p04CropPreviewClubPage => 'Club page';

  @override
  String get p04CropPreviewClubCard => 'Club card';

  @override
  String get p04CropRemoveCover => 'Remove cover';

  @override
  String get p04SrcTitle => 'Photo';

  @override
  String get p04SrcGallery => 'Choose from gallery';

  @override
  String get p04SrcCamera => 'Take a photo';

  @override
  String get p04SrcRemove => 'Remove photo';

  @override
  String get p04Recrop => 'Crop again';

  @override
  String get p04PostNotFound =>
      'Post not found (it may have been deleted or hidden)';

  @override
  String get p04PostSharing => 'Sharing...';

  @override
  String get p04PostPhotoNone => 'No photo selected';

  @override
  String get p04PostFormatHint => '4:5 portrait format recommended';

  @override
  String get p04ContentWarning => 'Content warning';

  @override
  String get p23AddPeople => 'Add people';

  @override
  String get p23Selected => 'Selected participants';

  @override
  String get p23MinTwo => 'At least 2 people';

  @override
  String get p23PrivacyShort => 'Your contacts are not sent to the server.';

  @override
  String get p26OnceCaption => 'You can view this photo only once.';

  @override
  String p09BlockNamed(String name) {
    return 'Block $name';
  }

  @override
  String get p09MemberOptions => 'Member options';

  @override
  String p09MemberRemoved(String name) {
    return '$name was removed from the group';
  }

  @override
  String get p09MediaLoading => 'Loading...';

  @override
  String get p09MediaEmptyBody => 'Shared photos and videos appear here.';

  @override
  String get p09MediaErrorTitle => 'Something went wrong';

  @override
  String get p09MediaErrorBody => 'Media could not be loaded.';

  @override
  String get p09ClubPageSub => 'Events and projects';

  @override
  String get p09MembersLoadFailed => 'The member list could not be loaded.';

  @override
  String get p10AlbumTitle => 'Album';

  @override
  String p10AlbumCount(String n) {
    return '$n albums';
  }

  @override
  String get p10ItemUnit => 'items';

  @override
  String get p10LimitedBody =>
      'You can pick more photos from your library to send in chat.';

  @override
  String get p10DeniedBody =>
      'To send photos and videos, allow gallery access in the app settings.';

  @override
  String get p10GalleryEmpty => 'There are no photos or videos in the gallery.';

  @override
  String p10SelCount(String n, String max) {
    return '$n / $max';
  }

  @override
  String get p10SelWord => 'selected';

  @override
  String p10TileSelected(String n) {
    return 'Selected, number $n';
  }

  @override
  String get p10VideoPrepareSub => 'Compressing and caching';

  @override
  String get p10CloseNotice => 'Dismiss notice';

  @override
  String get p01LgReview => 'Review the agreements again';

  @override
  String get p14ErrorTitle => 'Couldn\'t load, try again';

  @override
  String get p14ErrorBody => 'There was a problem reaching the server.';

  @override
  String get p14OfflineStrip => 'No internet connection · Showing saved data';

  @override
  String get p14EmptyUpcomingBody2 =>
      'Browse campus club events and join right away.';

  @override
  String get p14EmptyPastBody2 =>
      'Events you attended or that have finished are archived here.';

  @override
  String get p14EmptyCreatedBody2 =>
      'Manage the workshops, seminars and meetups you plan with your club here.';

  @override
  String get p14Detail => 'Details';

  @override
  String get p14Attended => 'You attended';

  @override
  String get p14WithdrawRequest => 'Withdraw request';

  @override
  String get p14StatusGoing => 'Going';

  @override
  String p18ClassYear(String n) {
    return '${n}th year';
  }

  @override
  String get p18FollowErrorTitle => 'Connection error';

  @override
  String get p18FollowersEmptyBody =>
      'As your profile gets active, your friends will start following you here.';

  @override
  String get p18FollowingEmptyBody =>
      'Follow students and club members you like so you do not miss campus posts.';

  @override
  String get p18FollowNoMatchBody =>
      'No user matched your search. Check the spelling and try again.';

  @override
  String p18AllFollowers(String n) {
    return 'All followers ($n)';
  }

  @override
  String p18AllFollowing(String n) {
    return 'Following ($n)';
  }

  @override
  String get p19AcademicInfo => 'Academic information';

  @override
  String get p19ShowEmailDesc =>
      'Students who visit your profile can see your email address.';

  @override
  String get p19LangSystemDesc => 'Uses your device default language';

  @override
  String get p19CrashReportsShort =>
      'An anonymous crash report is sent when the app hits an error.';

  @override
  String get p19LogoutAllSub =>
      'Closes your other open phone and browser sessions.';

  @override
  String get p05NewsLoadingMore => 'Loading older news...';

  @override
  String get p05SavedDiscover => 'Explore News';

  @override
  String get p05SavedEmptyTitle2 => 'You have no saved news yet.';

  @override
  String get p05SavedEmptyBody2 =>
      'You can save news you like by tapping the bookmark icon.';

  @override
  String get p05ListErrorTitle => 'Could not load';

  @override
  String get p05ListErrorBody =>
      'There was a problem connecting to the server. Please check your internet connection.';

  @override
  String get p13SuppLoadFailed => 'Could not load';

  @override
  String get p13SuppFaqEmptyBody =>
      'No articles have been added for this category yet.';

  @override
  String get p13SuppFaqNoMatchBody => 'No results match your search.';

  @override
  String get p13SuppTicketsEmptyBody =>
      'You have no active or past support records.';

  @override
  String get p13SuppFeedbackSub => 'Rate your app experience';

  @override
  String get p13SuppBoardSub => 'Share ideas for new features';

  @override
  String get p02IdLabel => 'Email / Student No';

  @override
  String get p17PickDateHelp => 'Select date';

  @override
  String get p20ProfileTitle => 'Profile';

  @override
  String get p20AboutNoBio => 'No biography provided.';

  @override
  String get p20AcademicInfo => 'Academic Info';

  @override
  String get p20AvatarHidden =>
      'Your profile photo was hidden by moderation. Your initials are shown until you upload a photo that follows campus rules.';

  @override
  String get p20BlockInfo =>
      'You will not see this person\'s posts and cannot message them.';

  @override
  String get p20ReportSendHint => 'You can briefly describe the situation...';

  @override
  String get p20PrefPollsSub => 'Student and staff polls';

  @override
  String get p20PrefAcademicSub => 'Department, faculty and exam notices';

  @override
  String get p20PrefDetailHead =>
      'Manage the sub-types of each category one by one. Turning off the main switch silences the related sub-types.';

  @override
  String get p20PrefDetailSub => 'Sub-categories and notification types';

  @override
  String get p20PrefOffTag => 'Off';

  @override
  String get p20PrefMsgGroupSub => 'Instant messaging';

  @override
  String get p20PrefEventsGroupSub => 'Calendar and meetups';

  @override
  String get p20PrefClubsGroupSub => 'Community activity';

  @override
  String get p20PrefSubDirect => 'One-to-one private chats';

  @override
  String get p20PrefSubGroup => 'Course and club group chats';

  @override
  String get p20PrefSubEventReminder => '1 hour before it starts';

  @override
  String get p20PrefSubEventUpdate => 'Date, time or place updates';

  @override
  String get p20PrefSubEventAdmission => 'Club event attendance approvals';

  @override
  String get p20PrefSubClubPost => 'Announcements and photos shared by clubs';

  @override
  String get p20PrefSubClubRole => 'Management and membership roles';

  @override
  String get p20PrefSubClubJoin => 'Join requests and replies';

  @override
  String get p20PrefLoadFail => 'Could not load';

  @override
  String get p20PrefTapRetry => 'Tap to try again.';

  @override
  String p20PrefRemSub(String m) {
    return 'Local alarm/notification $m min before class';
  }

  @override
  String get p20QuietPickHelp => 'Select time';

  @override
  String get p20ThemeSystemSub => 'Follows your device settings';

  @override
  String get p20HalfDay => 'Half day';

  @override
  String get p20AllDay => 'All day';

  @override
  String p20RangeDays(String n) {
    return '$n days';
  }

  @override
  String p20RangeWeeks(String n) {
    return '$n weeks';
  }

  @override
  String get p20RemDaySub => 'Remind one day before the exam';

  @override
  String get p20RemHourSub =>
      'Sent by the server, even when the app is closed; follows the Academic announcements setting';

  @override
  String get p13SugSortTop => 'Most voted';

  @override
  String get p13SugAdd => 'Add suggestion';

  @override
  String get p13SugApprovalNote =>
      'Suggestions are published after administrator approval.';

  @override
  String get p13SugVoteHint => 'Tap to vote';

  @override
  String get p13SugVoted => 'Your vote is saved';

  @override
  String get p04PostsEmptyBody => 'Photos you share are listed here.';

  @override
  String get p04PostsLoadFail => 'Could not load, try again';

  @override
  String get p04FeedErrTitle => 'Could not load';

  @override
  String get p04FeedErrBody => 'Check your connection and try again.';

  @override
  String get p09ForwardDirect => 'Direct chat';

  @override
  String get p03HomeBrandSub => 'Independent student app';

  @override
  String get p03HomeQuickTitle => 'Quick Access';

  @override
  String get p03HomeQuickEvents => 'Events';

  @override
  String get p03HomeQuickSchedule => 'Schedule';

  @override
  String get p03HomeFeaturedNews => 'Featured News';

  @override
  String get p03HomeUpcoming => 'Upcoming Event';

  @override
  String get p03HomeMealHeroTitle => 'Meal Menu of the Day';

  @override
  String p03HomeLunchCount(String n) {
    return 'Lunch • $n dishes';
  }

  @override
  String get p03HomeMenuDetail => 'Menu Details';

  @override
  String p03HomeHosts(String club) {
    return 'Hosted by $club';
  }

  @override
  String get p04CropCenter => 'Center';

  @override
  String get p04SrcSizeTitle => 'File is too large';

  @override
  String get p18ProfileTitle => 'My profile';

  @override
  String get p18Edit => 'Edit';

  @override
  String get p18ProfileLoadFailed => 'Could not load, try again';

  @override
  String p15PercentFull(String n) {
    return '$n% full';
  }

  @override
  String get p15ChatSub => 'Meet the attendees and the organizer';

  @override
  String get p15ChatLockedSub => 'Only open to approved attendees';

  @override
  String get p15AboutTitle => 'About the event';

  @override
  String get p15AttOpenHint =>
      'Scan the QR code in the hall or enter the code the organizer announced to record your attendance.';

  @override
  String get p15CheckedInBody => 'Your attendance has been recorded.';

  @override
  String get p15CancelledNotice => 'This event has been cancelled.';

  @override
  String get p15StatusInterested => 'Interested';

  @override
  String p15AttendeesLine(String going, String interested) {
    return '$going going · $interested interested';
  }

  @override
  String get p13SuppFaqHeading => 'Frequently asked questions';

  @override
  String get p13SuppToday => 'Today';

  @override
  String get p23GroupNameHint => 'E.g. Engineering Project Team...';

  @override
  String get p23NoneText =>
      'None of your contacts use the app with a Bingöl University email.';

  @override
  String p09GradeYear(String n) {
    return 'Year $n';
  }

  @override
  String get p14UpcomingOther => 'Upcoming on other days';

  @override
  String get p14ErrorBodyCache =>
      'There was a problem reaching the server. Showing the offline cache.';

  @override
  String get p14Completed => 'Completed';

  @override
  String get p15LockedBadge => 'Locked';

  @override
  String get p15CancelledBody => 'Attendees are notified.';

  @override
  String get p15WontHappen => 'Won\'t take place';

  @override
  String get p15AnswerHint => 'Tell us briefly...';

  @override
  String get p15NoteHint => 'Any extra note you\'d like to share...';

  @override
  String p15CodeChars(String n) {
    return '$n characters';
  }

  @override
  String get p15LeaveHint => 'You can change your attendance status any time.';

  @override
  String get p15SettingsSub => 'Join type, capacity and registration';

  @override
  String get p15ClearField => 'Clear';

  @override
  String get p18SecPrefs => 'App preferences';

  @override
  String get p18SecAccount => 'Account & security';

  @override
  String get p18SecAbout => 'About & support';

  @override
  String get p18CounterClubs => 'Clubs';

  @override
  String get p18CounterEvents => 'Events';

  @override
  String get p18ClearSearch => 'Clear search';

  @override
  String p18NavUnread(String n) {
    return '$n unread';
  }

  @override
  String get p19PushOffShort => 'Off';

  @override
  String get p19SaveFailedSub => 'A connection error occurred.';

  @override
  String get p19FormErrTitle => 'Some fields need fixing';

  @override
  String get p19FormErrBody =>
      'Please check your profile photo and the marked required fields.';

  @override
  String get p19PhotoChange => 'Change photo';

  @override
  String get p19Cancel => 'Cancel';

  @override
  String get p20GradeLevel => 'Grade Level';

  @override
  String get p21ChanChatDesc =>
      'Direct and group chat messages. Arrive with sound and vibration.';

  @override
  String get p21ChanEventDesc =>
      'Event reminders, changes and attendance results.';

  @override
  String get p21ChanAnnouncementDesc =>
      'News, announcements, club and system notifications.';

  @override
  String get p21ChanSocialDesc =>
      'Like and follow notifications. Delivered silently.';

  @override
  String get p21ChanPollDesc => 'New polls and their results.';

  @override
  String get p21ChanAcademicDesc =>
      'Local reminders before your classes and exams.';

  @override
  String get p21HelpTitle => 'Notifications not working?';

  @override
  String get p21HelpLink => 'Notifications not working?';

  @override
  String get p21HelpAllGood => 'Everything looks fine on this device.';

  @override
  String get p21HelpSomeIssue =>
      'Something is preventing you from receiving notifications. See the steps below.';

  @override
  String get p21HelpPermTitle => 'Notification permission';

  @override
  String get p21HelpPermOk => 'App notifications are on.';

  @override
  String get p21HelpPermOff =>
      'Notifications are turned off in system settings. You will not receive any until you turn them on.';

  @override
  String get p21HelpChanTitle => 'Notification categories';

  @override
  String get p21HelpChanChat =>
      'The Messages category is turned off in system settings. Turn it on or you will not get new message notifications.';

  @override
  String get p21HelpChanOther =>
      'Some notification categories are turned off in system settings. Turn on the ones you want.';

  @override
  String get p21HelpDeviceTitle => 'This device registration';

  @override
  String get p21HelpDeviceOk =>
      'Your device is registered so we can send notifications.';

  @override
  String get p21HelpDeviceBad =>
      'Your device is not registered yet. Check your internet connection and register again.';

  @override
  String get p21HelpDeviceUnsupported =>
      'Push notifications are not configured in this version.';

  @override
  String get p21HelpDeviceRetry => 'Register again';

  @override
  String get p21HelpBatteryTitle => 'Battery and background';

  @override
  String get p21HelpBatteryOem =>
      'Your phone may shut the app down to save battery. If notifications do not arrive while the app is closed, remove the restriction for BÜ Kampüs in battery settings, allow Autostart if your phone has it, and lock the app in recent apps.';

  @override
  String get p21HelpBatteryGeneric =>
      'If notifications do not arrive while the app is closed, remove the battery restriction for BÜ Kampüs in battery settings. Swiping the app away from recent apps stops notifications on some phones.';

  @override
  String get p21HelpBatteryOpen => 'Open battery settings';

  @override
  String get p21HelpFooter =>
      'Quiet hours and notification preferences can also block a notification. Check them in Notification preferences.';

  @override
  String get p22SaveGalleryTitle => 'Save photos to gallery';

  @override
  String get p22SaveGalleryDesc =>
      'Photos you receive and send in chats are saved to your gallery; view-once photos are never saved.';

  @override
  String get p22SaveGalleryCloud =>
      'If your gallery has cloud backup turned on, the photos may be uploaded there too.';

  @override
  String get p22SaveDeniedToast =>
      'Photos could not be saved to the gallery: permission was not granted. You can allow it in Settings.';

  @override
  String get p22OpenSettings => 'Settings';

  @override
  String get p21PreviewTitle => 'Message preview in notifications';

  @override
  String get p21PreviewSub =>
      'When on, the start of the message shows in the notification and on the lock screen; the text passes through Google/Apple notification servers. When off, only the sender name is shown.';

  @override
  String get p26PrefNeedsAnnouncements =>
      'No notifications while Announcements is off';

  @override
  String get p26PrefPollsNeedsParents =>
      'No poll notifications while Announcements or Clubs is off';

  @override
  String get p32ExportShareFailed =>
      'Your data could not be prepared for sharing. Please try again.';

  @override
  String get p31ChatPlaceholderBlocked =>
      'Message from a user you blocked is hidden';

  @override
  String get p31ChatPlaceholderUnreadable => 'This message cannot be displayed';

  @override
  String p31ChatMsgTooLong(String max) {
    return 'A message can be at most $max characters.';
  }

  @override
  String get p31ChatRemovedToast => 'You were removed from this chat.';

  @override
  String get p30AutosaveConsentTitle => 'Save photos to your gallery?';

  @override
  String get p30AutosaveConsentBody =>
      'Photos you send and receive in one-to-one chats are saved to your phone\'s gallery (BU Kampus album). View-once photos are never saved. You can turn this off here at any time.';

  @override
  String get p30AutosaveConsentOk => 'Turn on';

  @override
  String get p60EditHome => 'Edit home';

  @override
  String get p60EditHint => 'Press and hold to drag, or use the arrows.';

  @override
  String get p60Done => 'Done';

  @override
  String get p60ResetDefault => 'Reset to default';

  @override
  String get p60SectionClasses => 'Classes today';

  @override
  String p60MoveUp(String name) {
    return 'Move $name up';
  }

  @override
  String p60MoveDown(String name) {
    return 'Move $name down';
  }

  @override
  String get p60Shortcuts => 'Choose shortcuts';

  @override
  String p60ShortcutsCount(String n) {
    return '$n shortcuts';
  }

  @override
  String get p60ShortcutsHint => 'Pick up to 5 shortcuts.';

  @override
  String get p60EmptyTitle => 'Your home is empty';

  @override
  String get p60EmptyAction => 'Add a section';

  @override
  String get p60NoClassesToday => 'No classes today';

  @override
  String get p60NoTimetable => 'No timetable yet';

  @override
  String get p60ShortSearch => 'Search';

  @override
  String get p67ChatBgTitle => 'Chat background';

  @override
  String get p67ChatBgPattern => 'Pattern';

  @override
  String get p67ChatBgSoft => 'Subtle';

  @override
  String get p67ChatBgStrong => 'Medium';

  @override
  String get p67ChatBgPlain => 'Plain';

  @override
  String get p67ChatBgPreviewIn => 'Hi, see you in class.';

  @override
  String get p67ChatBgPreviewOut => 'Okay, see you.';

  @override
  String get p67SettingsChats => 'Chats';

  @override
  String get p67AttachAllowPhotos => 'Allow access to photos';

  @override
  String p67PickerSend(String n) {
    return 'Send ($n)';
  }

  @override
  String get p66HelpPrompt => 'Can’t sign in?';

  @override
  String get p66HelpAction => 'Get help';

  @override
  String get p66HelpSub =>
      'If you can’t sign in, write to us. We will email you a verification code.';

  @override
  String get p66FieldName => 'Full name';

  @override
  String get p66FieldEmail => 'Email';

  @override
  String get p66FieldTopic => 'Topic';

  @override
  String get p66FieldMessage => 'Your message';

  @override
  String get p66ErrName => 'Enter your full name.';

  @override
  String get p66ErrEmail => 'Enter a valid email address.';

  @override
  String get p66ErrMsgShort => 'The message must be at least 10 characters.';

  @override
  String get p66ErrMsgLong => 'The message can be at most 2000 characters.';

  @override
  String get p66ReplyNote => 'We will send the reply to your email.';

  @override
  String get p66CodeSix => 'Enter the 6-digit code.';

  @override
  String get p66CodeBad => 'The code is wrong or has expired.';

  @override
  String get p66TrackTitle => 'Your request';

  @override
  String get p66TrackYou => 'You';

  @override
  String get p66TrackStaff => 'Support team';

  @override
  String get p66TrackHint => 'Write your reply';

  @override
  String get p66TrackSend => 'Send';

  @override
  String get p66TrackClosed => 'This request is closed.';

  @override
  String get p66MyTicket => 'My request';

  @override
  String get p66AboutBody =>
      'An independent student app built for the students and staff of Bingöl University.';

  @override
  String get p67AttachRecent => 'Recent photos';

  @override
  String get p67AttachOnceHint =>
      'To send a view-once photo, select it and tap the 1 icon.';

  @override
  String get p67AttachGrant => 'Allow';

  @override
  String get p51ClubsEmpty => 'No clubs yet.';

  @override
  String get p51ClubsLoadFailed => 'Couldn\'t load. Try again.';

  @override
  String get p51Managed => 'Managed by me';

  @override
  String get p51RoleMember => 'Member';

  @override
  String get p51AwaitingReply => 'Awaiting reply';

  @override
  String p51ApplyDate(String date) {
    return 'Applied: $date';
  }

  @override
  String get p51AboutFounded => 'Founded';

  @override
  String get p51CreateClubTitle => 'Create club';

  @override
  String get p51Create => 'Create';

  @override
  String get p51JoinApproval => 'By request';

  @override
  String get p51DescLabel => 'Description';

  @override
  String get p51DescHint => 'Briefly describe your club\'s purpose and goals…';

  @override
  String get p51AddJoinQuestion => 'Add a join question';

  @override
  String get p64CropDone => 'Done';

  @override
  String get p64FeedOffline =>
      'You are offline. Posts shown may be out of date.';

  @override
  String get p67ChatBgDensity => 'Density';

  @override
  String get p67ChatBgApply => 'Apply';

  @override
  String get p67ChatBgReset => 'Reset to default';
}
