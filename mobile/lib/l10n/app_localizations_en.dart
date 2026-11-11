// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chatReactionPickerTitle => 'Choose a reaction';

  @override
  String get chatReactionKeyboardHint => 'Choose an emoji from your keyboard';

  @override
  String get chatReactionOneEmoji => 'Choose a single emoji.';

  @override
  String get chatReactionSearchHint => 'Search emoji';

  @override
  String get chatReactionNoResults => 'No results';

  @override
  String get chatReactionRecent => 'Recently used';

  @override
  String get chatReactionFrequent => 'Frequently used';

  @override
  String get chatReactionCatFaces => 'Smileys';

  @override
  String get chatReactionCatPeople => 'People';

  @override
  String get chatReactionCatNature => 'Animals and nature';

  @override
  String get chatReactionCatFood => 'Food and drink';

  @override
  String get chatReactionCatActivities => 'Activities';

  @override
  String get chatReactionCatTravel => 'Travel';

  @override
  String get chatReactionCatObjects => 'Objects';

  @override
  String get chatReactionCatSymbols => 'Symbols';

  @override
  String get chatReactionCatFlags => 'Flags';

  @override
  String get chatReactionUnsupported => 'This emoji is not supported right now';

  @override
  String get chatReactionLimit =>
      'This message cannot have more different emojis';

  @override
  String get chatMessageInfoTitle => 'Message info';

  @override
  String get chatMessageSent => 'Sent';

  @override
  String get chatMessageDelivered => 'Delivered';

  @override
  String get chatMessageRead => 'Read';

  @override
  String get chatMessageTimeUnknown => 'Time was not recorded';

  @override
  String get chatMessageWaiting => 'Not yet';

  @override
  String get chatMessageReplies => 'Replies to this message';

  @override
  String get chatMessageNoReplies => 'No replies to this message yet.';

  @override
  String get chatMessageReactions => 'Reactions';

  @override
  String get chatMessageEditedNote => 'This message was edited';

  @override
  String get chatPremiumAllPhotos => 'All photos';

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
      'The service is currently unavailable. Please try again later.';

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
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionPrivacy => 'Privacy and account';

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
  String get loginSubtitle => 'Log in with your email address.';

  @override
  String get loginReplacedNotice =>
      'The session on this device was closed. It may have been signed out from another device; sign in again to continue.';

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
  String get authIdHint => 'Email';

  @override
  String get loginSubtitleNumber => 'Log in with your email address.';

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCode => 'Resend code';

  @override
  String authResendInTime(String time) {
    return 'Resend ($time)';
  }

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
  String get authPasswordMin8 => 'Password (at least 6 characters)';

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
  String get acadExamsTitle => 'Exams';

  @override
  String get acadExamsAdd => 'Add exam';

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
  String get chatEncNoticeDirect =>
      'Your messages are encrypted in transit and on the server.';

  @override
  String get chatEncNoticeGroup =>
      'Messages in this chat are encrypted in transit and on the server. All members of the chat can see them.';

  @override
  String get chatEncNoticeRoom =>
      'Messages in this room are encrypted in transit and on the server. All members of the room can see them.';

  @override
  String get chatEncMore => 'Learn more';

  @override
  String get chatEncPageTitle => 'Chat security';

  @override
  String get chatEncHeroTitle => 'Your messages are encrypted';

  @override
  String get chatEncHeroBody =>
      'Your messages are encrypted in transit and on the server. Below we explain plainly what is protected, how, and what you should keep in mind.';

  @override
  String get chatEncSecHow => 'How it is protected';

  @override
  String get chatEncTlsTitle => 'Encrypted in transit';

  @override
  String get chatEncTlsBody =>
      'Your messages and chat photos travel between the app and the server over an encrypted connection (TLS/WSS).';

  @override
  String get chatEncRestTitle => 'Encrypted storage on the server';

  @override
  String get chatEncRestBody =>
      'Messages are stored encrypted with AES-256-GCM using a separate key for each chat; chat photos and videos are stored encrypted too. The keys are kept apart from the database, in the server environment. This makes messages harder to read even if a database backup is obtained.';

  @override
  String get chatEncAuditTitle => 'Admin access is logged';

  @override
  String get chatEncAuditBody =>
      'Only authorized administrators can look at conversations, and only for reasons such as reviewing a report, security or legal requests. Every view is written to a tamper-proof access log before the content is shown.';

  @override
  String get chatEncBlockTitle => 'Block and report';

  @override
  String get chatEncBlockBody =>
      'You can block people you do not want to hear from and report inappropriate messages and users. Messages from someone you blocked are not delivered to you.';

  @override
  String get chatEncOnceTitle => 'View-once photos';

  @override
  String get chatEncOnceBody =>
      'The recipient can open a view-once photo only one time; after opening it they cannot see it again.';

  @override
  String get chatEncDeleteTitle => 'Delete for everyone';

  @override
  String get chatEncDeleteBody =>
      'You can delete your own message for everyone; others see a note that it was deleted instead of the message.';

  @override
  String get chatEncExifTitle => 'Location is removed from photos';

  @override
  String get chatEncExifBody =>
      'Photos you send are re-encoded on the server and EXIF data such as location is removed.';

  @override
  String get chatEncDataTitle => 'Your data is yours';

  @override
  String get chatEncDataBody =>
      'From the Profile section you can download your data or delete your account.';

  @override
  String get chatEncNoSellTitle => 'Not sold, not shared for ads';

  @override
  String get chatEncNoSellBody =>
      'We do not sell your data and we do not share it with third parties for advertising.';

  @override
  String get chatEncSecKnow => 'What you should know';

  @override
  String get chatEncNotE2eeTitle => 'Not end-to-end encrypted';

  @override
  String get chatEncNotE2eeBody =>
      'Messages in this app are not end-to-end encrypted. The encryption keys are held on the server, so the system can decrypt messages when necessary. Please use the app with this in mind.';

  @override
  String get chatEncRetainTitle => 'Deleted content may be kept';

  @override
  String get chatEncRetainBody =>
      'The encrypted copy of messages deleted for everyone, their edit history and the encrypted copy of view-once photos may be kept on the server for security review. Retention periods are stated in the Privacy Policy.';

  @override
  String get chatEncMembersTitle => 'Everyone in a group can see';

  @override
  String get chatEncMembersBody =>
      'Messages in groups, club rooms and event rooms can be seen by all members of the room.';

  @override
  String get chatEncScreenshotTitle => 'Screenshots cannot be prevented';

  @override
  String get chatEncScreenshotBody =>
      'The other person can capture a message with a screenshot or another device and share it. We cannot fully prevent this, even for view-once photos.';

  @override
  String get chatEncAccountTitle => 'Messages remain after account deletion';

  @override
  String get chatEncAccountBody =>
      'If you delete your account, your personal details are anonymized; the messages you sent remain as part of the chat under an anonymous author.';

  @override
  String get chatEncSecHelp => 'Report and block';

  @override
  String chatEncHelpMessage(String report) {
    return 'To report a message, press and hold it and tap $report.';
  }

  @override
  String chatEncHelpPerson(String block, String report) {
    return 'To block or report someone in a one-to-one chat, tap the name at the top; in chat info use $block or $report.';
  }

  @override
  String get chatEncSecRead => 'More';

  @override
  String get chatEncPrivacyLink => 'Privacy Policy';

  @override
  String get chatEncRulesLink => 'Community Rules';

  @override
  String get chatEncInfoRow => 'Encryption and security';

  @override
  String get chatEncFootnote =>
      'Your messages are encrypted in transit and on the server.';

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
  String get chatDetailOnline => 'online';

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
  String get chatInfoSearchInChat => 'Search in chat';

  @override
  String get chatInfoMediaFiles => 'Media and files';

  @override
  String get chatInfoTabPhotos => 'Photos';

  @override
  String get chatInfoTabVideos => 'Videos';

  @override
  String get chatInfoTabFiles => 'Files';

  @override
  String get chatInfoNoPhotos => 'No photos in this chat yet.';

  @override
  String get chatInfoNoVideos => 'No videos in this chat yet.';

  @override
  String get chatInfoFilesUnsupportedTitle => 'File sharing is not supported';

  @override
  String get chatInfoFilesUnsupportedBody =>
      'For now only photos and videos can be shared in this chat.';

  @override
  String get chatInfoReported => 'Reported';

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
  String get chatStatusSending => 'Sending…';

  @override
  String get chatStatusSent => 'Sent';

  @override
  String get chatStatusSeen => 'Seen';

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
  String get shareTitle => 'Share';

  @override
  String get shareSendTo => 'Send to';

  @override
  String get shareRecent => 'Recent chats';

  @override
  String get shareSearchHint => 'Search people or chats';

  @override
  String get shareNoteHint => 'Add a note (optional)';

  @override
  String get shareCopyLink => 'Copy link';

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get shareMoreApps => 'More apps';

  @override
  String get shareExternalFailed => 'Could not open the share sheet';

  @override
  String get shareSentOne => 'Sent';

  @override
  String shareSentMany(String n) {
    return 'Sent to $n chats';
  }

  @override
  String get shareQueued =>
      'You are offline; it will be sent when you are back online';

  @override
  String get shareFailedAll => 'Could not send. Try again.';

  @override
  String shareFailedSome(String n) {
    return 'Could not send to $n chats';
  }

  @override
  String get shareKindPost => 'Post';

  @override
  String get shareKindReel => 'Reel';

  @override
  String get shareKindNews => 'News';

  @override
  String get shareKindAnnouncement => 'Announcement';

  @override
  String get shareKindEvent => 'Event';

  @override
  String get shareUnavailable => 'This content is no longer available';

  @override
  String get shareChatPostShared => 'Shared a post';

  @override
  String get shareChatReelShared => 'Shared a reel';

  @override
  String get shareChatNewsShared => 'Shared a news story';

  @override
  String get shareChatAnnouncementShared => 'Shared an announcement';

  @override
  String get shareChatEventShared => 'Shared an event';

  @override
  String get forumActivityAnonBadge => 'Anonymous';

  @override
  String get forumActivityAnonBadgeLong =>
      'Anonymous post: only you can see this';

  @override
  String get forumActivityAnonymous => 'Anonymous';

  @override
  String get forumActivityCommentDeleted => 'This comment was deleted';

  @override
  String forumActivityCounts(String likes, String comments) {
    return '$likes likes, $comments comments';
  }

  @override
  String get forumActivityEmptyCommentsBody =>
      'Comments you write will appear here.';

  @override
  String get forumActivityEmptyCommentsTitle => 'No comments yet';

  @override
  String get forumActivityEmptyFollowingBody =>
      'Follow a topic to hear about new comments.';

  @override
  String get forumActivityEmptyFollowingTitle => 'You follow no topics';

  @override
  String get forumActivityEmptyTopicsBody =>
      'Topics you start are listed here. Anonymous ones are visible only to you.';

  @override
  String get forumActivityEmptyTopicsTitle =>
      'You have not started a topic yet';

  @override
  String get forumActivityRemoved => 'This topic was removed';

  @override
  String get forumActivitySection => 'Forum';

  @override
  String get forumActivityTabComments => 'My comments';

  @override
  String get forumActivityTabCommentsPublic => 'Comments';

  @override
  String get forumActivityTabFollowing => 'Following';

  @override
  String get forumActivityTabSaved => 'Saved';

  @override
  String get forumActivityTabTopics => 'My topics';

  @override
  String get forumActivityTabTopicsPublic => 'Topics';

  @override
  String get forumActivityTitle => 'My forum activity';

  @override
  String get forumActivityUserEmptyComments => 'No public comments yet';

  @override
  String get forumActivityUserEmptyTopics => 'No public topics yet';

  @override
  String forumActivityUserTitle(String name) {
    return 'Forum activity of $name';
  }

  @override
  String get forumPrefsAll => 'All forum notifications';

  @override
  String get forumPrefsAllSub =>
      'Turning this off stops all of the notifications below.';

  @override
  String get forumPrefsFollowed => 'Topics I follow';

  @override
  String get forumPrefsLikes => 'Like notifications';

  @override
  String get forumPrefsModerationNote =>
      'Moderation notices (for example when your content is removed) cannot be turned off.';

  @override
  String get forumPrefsMutedEmpty => 'You have not muted anyone.';

  @override
  String get forumPrefsMutedSection => 'People you muted';

  @override
  String get forumPrefsNotifLabel => 'Forum';

  @override
  String get forumPrefsReplies => 'Replies to my comments';

  @override
  String get forumPrefsRowSub => 'Topic, reply and like notifications';

  @override
  String get forumPrefsRowTitle => 'Forum notifications';

  @override
  String get forumPrefsTitle => 'Forum notifications';

  @override
  String get forumPrefsTopicComments => 'Topic notifications';

  @override
  String get forumPrefsUnmute => 'Unmute';

  @override
  String get forumPrefsUnmuted => 'Unmuted';

  @override
  String get forumReportAlready => 'You already reported this content.';

  @override
  String get forumReportAlsoBlock => 'Also block this author';

  @override
  String get forumReportAlsoBlockHint =>
      'Their content is hidden from you. Their identity is never shown.';

  @override
  String get forumReportBlockBody =>
      'All of this author’s forum topics and comments are hidden from you. Even if they are anonymous, you will not learn who they are.';

  @override
  String get forumReportBlockConfirm => 'Block';

  @override
  String get forumReportBlockTitle => 'Block this author?';

  @override
  String get forumReportBlocked => 'Author blocked.';

  @override
  String forumReportMuteBody(String name) {
    return 'Forum content from $name is hidden from you. Chats and profile interactions are not affected. You can undo this in settings.';
  }

  @override
  String get forumReportMuteConfirm => 'Mute';

  @override
  String get forumReportMuteTitle => 'Mute this person?';

  @override
  String get forumReportMuted => 'Muted.';

  @override
  String get forumReportNoteHint => 'Anything to add? (optional)';

  @override
  String get forumReportReasonHarassment => 'Insults or harassment';

  @override
  String get forumReportReasonInappropriate => 'Inappropriate content';

  @override
  String get forumReportReasonOther => 'Other';

  @override
  String get forumReportReasonPersonalInfo => 'Sharing personal information';

  @override
  String get forumReportReasonSpam => 'Spam or advertising';

  @override
  String get forumReportThanks => 'Thanks, your report was sent to our team.';

  @override
  String get forumReportTitle => 'Report';

  @override
  String get forumSavedEmptyBody =>
      'Tap the save icon on topics and comments to add them here.';

  @override
  String get forumSavedEmptyTitle => 'Nothing saved yet';

  @override
  String get forumSavedRemove => 'Remove from saved';

  @override
  String get forumSavedRemoved => 'Removed from saved';

  @override
  String get forumSavedTitle => 'Saved';

  @override
  String get forumSearchAllCategories => 'All';

  @override
  String get forumSearchClearAll => 'Clear';

  @override
  String forumSearchEmptyBody(String q) {
    return 'No topics match “$q”. Try a different word or category.';
  }

  @override
  String get forumSearchEmptyTitle => 'No results';

  @override
  String get forumSearchHint => 'Search the forum';

  @override
  String get forumSearchMatchBody => 'In description';

  @override
  String get forumSearchMatchCategory => 'In category';

  @override
  String get forumSearchMatchComment => 'In a comment';

  @override
  String get forumSearchMatchTitle => 'In title';

  @override
  String get forumSearchMinChars => 'Type at least 2 characters.';

  @override
  String get forumSearchPopular => 'Popular topics';

  @override
  String get forumSearchPopularEmpty => 'No trending topics right now.';

  @override
  String get forumSearchRecent => 'Recent searches';

  @override
  String get forumSearchRemoveRecent => 'Remove search';

  @override
  String get forumSearchSortNewest => 'Newest';

  @override
  String get forumSearchSortPopular => 'Popular';

  @override
  String get forumSearchSortRelevance => 'Relevant';

  @override
  String get forumSearchStartBody =>
      'Search by topic title, description, comment or category name.';

  @override
  String get forumSearchStartTitle => 'Search the forum';

  @override
  String get forumSearchTitle => 'Forum search';

  @override
  String get forumShareChatCommentShared => 'Shared a forum comment';

  @override
  String get forumShareChatTopicShared => 'Shared a forum topic';

  @override
  String get forumShareKindComment => 'Forum comment';

  @override
  String get forumShareKindTopic => 'Forum';

  @override
  String get sharePrivateHint =>
      'Posts from private accounts can only be shared with people by message.';

  @override
  String get shareNotFoundTitle => 'Content not found';

  @override
  String get shareNoChats => 'No chats found. Search to find people.';

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
  String get coreIdEmpty => 'Enter your email address.';

  @override
  String get coreIdEmail => 'Enter a valid email address.';

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
  String get eventListShortCodeNeedsEvent =>
      'None of your events has check-in open right now. Enter the short code on the event page under “Enter code manually”.';

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
  String get homeSearchHint => 'Search campus';

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
  String get newsFullContent => 'Open the source page to read the full text.';

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
  String get menuTopUpTitle => 'Meal card balance';

  @override
  String get menuTopUpBody =>
      'Out of balance? Top up your cafeteria card securely on yukle.al.';

  @override
  String get menuTopUpAction => 'Top up balance';

  @override
  String get menuTopUpFailed =>
      'Could not open the link. Please visit yukle.al in your browser.';

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
  String get notifEmpty => 'No notifications yet.';

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityFilterLikes => 'Likes';

  @override
  String get activityFilterComments => 'Comments';

  @override
  String get activityFilterFollows => 'Follows & requests';

  @override
  String get notifFilterEvents => 'Events';

  @override
  String get notifFilterAnnouncements => 'Announcements';

  @override
  String get notifFilterSystem => 'System';

  @override
  String get activityRequestStale =>
      'This request is no longer pending; it may already have been handled.';

  @override
  String get activityEmpty =>
      'No activity yet. Likes, comments, new followers and requests show up here.';

  @override
  String get notifTargetOpenFailed => 'This notification could not be opened.';

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
  String get srLoadMore => 'Show more';

  @override
  String get srSearchHint => 'Search users or posts';

  @override
  String get srTabUsers => 'Users';

  @override
  String get srTabPosts => 'Posts';

  @override
  String get srTabReels => 'Reels';

  @override
  String get srSearchTabsLabel => 'Search result types';

  @override
  String get srSearchPrompt =>
      'Type at least 2 characters to search users, posts or reels.';

  @override
  String get srSeeAll => 'See all';

  @override
  String get srReelsUnavailable => 'Reels search is not available right now.';

  @override
  String get srPrivateAccount => 'Private account';

  @override
  String srLikeCount(String count) {
    return '$count likes';
  }

  @override
  String srOpenProfileOf(String name) {
    return 'Open profile of $name';
  }

  @override
  String srPostByAuthor(String name) {
    return 'Post by $name';
  }

  @override
  String get srVideoBadge => 'Video';

  @override
  String get srProfileTabsLabel => 'Profile content';

  @override
  String get srProfilePostsEmpty => 'No posts yet.';

  @override
  String get srProfileReelsEmpty => 'No reels yet.';

  @override
  String srViewCount(String count) {
    return '$count views';
  }

  @override
  String get srPhotoViewerTitle => 'Profile photo';

  @override
  String get srPhotoViewerError => 'The photo could not be loaded';

  @override
  String get srPhotoViewerClose => 'Close preview';

  @override
  String get srAvatarLongPressHint => 'Long press to see the large photo';

  @override
  String get searchPrompt =>
      'Type at least 2 characters to search news, announcements, clubs, events or people.';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchClearRecent => 'Clear';

  @override
  String get searchNoResults => 'No results found.';

  @override
  String searchResultCount(String count) {
    return '$count results';
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
  String get followReasonClub => 'Shared club';

  @override
  String get followReasonGrade => 'Same class year';

  @override
  String get followReasonDepartment => 'Same department';

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
  String get pollClubEmpty => 'No polls yet.';

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
  String get d1MenuRateTodayOnly => 'Rating is only open for today\'s menu.';

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
  String get g2PostQueued => 'Post queued';

  @override
  String g2PostUploading(String pct) {
    return 'Uploading post $pct';
  }

  @override
  String get g2PostWaiting => 'Waiting for connection, will continue when back';

  @override
  String get g2PostPublishing => 'Posting';

  @override
  String get g2PostFailed => 'Could not post';

  @override
  String get g2PostEdit => 'Edit';

  @override
  String get g2PostRetry => 'Try again';

  @override
  String get g2PostRemove => 'Delete';

  @override
  String get g2PostCancel => 'Cancel';

  @override
  String get g2PostRemoveTitle => 'Delete this post?';

  @override
  String get g2PostRemoveBody =>
      'The text you wrote and the files you chose will be deleted.';

  @override
  String get g2PostQueuedToast => 'Your post is being sent in the background.';

  @override
  String get g2PostErrFiles => 'Files not found. Edit the post and try again.';

  @override
  String get g2PostPending => 'Pending post';

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
  String get postPickerCameraHint => 'Tap for a photo, hold for a video';

  @override
  String get postPickerLimitedBody =>
      'Only the photos and videos you allowed are shown. You can add more to share.';

  @override
  String get postPickerDeniedBody =>
      'Allow access to your gallery to share a post. You can also choose from the system gallery instead.';

  @override
  String get postPickerUseSystem => 'Use system gallery';

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
  String get profileChangePhotoSemantic => 'Change profile photo';

  @override
  String get profileUploading => 'Uploading…';

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
  String get profileFullName => 'Full name';

  @override
  String get profileEditNameSemantic => 'Edit full name';

  @override
  String get profileEditBioSemantic => 'Edit about me';

  @override
  String get profileEditDeptSemantic => 'Change department';

  @override
  String get profileEditGradeSemantic => 'Change year of study';

  @override
  String get profileBioEmptyCta => 'Introduce yourself';

  @override
  String get profileSavingSemantic => 'Saving';

  @override
  String get profileNameMin => 'Name must be at least 2 characters.';

  @override
  String get profileAbout => 'About me';

  @override
  String get profileBioHint => 'Tell us a little about yourself';

  @override
  String get profileMenuTitle => 'Menu';

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
  String get profileSaved => 'Saved news';

  @override
  String get profileLiked => 'Liked';

  @override
  String get likedAll => 'All';

  @override
  String get likedEmpty => 'You have not liked any posts yet.';

  @override
  String get likedEmptyReels => 'You have not liked any Reels yet.';

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
  String get profilePrefsNotifMessages => 'Message notifications (push)';

  @override
  String get profilePrefsNotifPolls => 'Polls';

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
  String get authSectionPersonal => 'Personal details';

  @override
  String get authHintPersonal => 'Enter your name and email address.';

  @override
  String get authNext => 'Continue';

  @override
  String get authTermsAutoPrefix => 'By signing up, you agree to the ';

  @override
  String get authTermsAutoSuffix => '.';

  @override
  String get oaHeadline => 'Your campus is here.';

  @override
  String get oaSub => 'Share, explore and join your community.';

  @override
  String get oaContinueGoogle => 'Continue with Google';

  @override
  String get oaContinueApple => 'Continue with Apple';

  @override
  String get oaContinueEmail => 'Continue with email';

  @override
  String get oaOr => 'or';

  @override
  String get oaLegalLead => 'By continuing you agree to the:';

  @override
  String get oaTermsLink => 'Terms of Use';

  @override
  String get oaPrivacyLink => 'Privacy Policy';

  @override
  String get oaProviderGoogle => 'Google';

  @override
  String get oaProviderApple => 'Apple';

  @override
  String get oaLinkTitle => 'You already have an account with this email';

  @override
  String oaLinkBody(String provider) {
    return 'Sign in with your email and password first, then link your $provider account under Account and security.';
  }

  @override
  String oaLinkMasked(String email) {
    return 'Account: $email';
  }

  @override
  String get oaErrFailed => 'Sign-in could not be completed. Please try again.';

  @override
  String get oaErrTokenInvalid =>
      'We could not verify this sign-in. Please try again.';

  @override
  String get oaErrEmailUnverified =>
      'The email address of this account is not verified by the provider. Verify it first or continue with email.';

  @override
  String get oaErrEmailMissing =>
      'We could not get an email address from your account. You can continue with email.';

  @override
  String get oaErrDisabled =>
      'This sign-in method is unavailable right now. You can continue with email.';

  @override
  String get oaErrLastMethod =>
      'This is the only way you can sign in to your account. Set a password before removing it.';

  @override
  String get oaErrProfileIncomplete =>
      'Please complete your profile before continuing.';

  @override
  String get oaOb1Title => 'Let us meet first.';

  @override
  String get oaOb1Sub => 'Let us build your BÜKampüs profile in a few steps.';

  @override
  String get oaFirstName => 'First name';

  @override
  String get oaLastName => 'Last name';

  @override
  String get oaFirstRequired => 'Enter your first name.';

  @override
  String get oaLastRequired => 'Enter your last name.';

  @override
  String get oaUsername => 'Username';

  @override
  String get oaUserRule => '3-24 characters: a-z, 0-9, dot and underscore.';

  @override
  String get oaUserChecking => 'Checking…';

  @override
  String get oaUserAvail => 'Username is available.';

  @override
  String get oaUserTaken => 'This username is taken.';

  @override
  String get oaUserInvalid =>
      'The username must be 3-24 characters; only a-z, 0-9, dot and underscore are allowed.';

  @override
  String get oaUserReserved => 'This username cannot be used.';

  @override
  String get oaUserRequired => 'Choose a username.';

  @override
  String get oaPhotoOptional => 'Profile photo (optional)';

  @override
  String get oaPhotoAdd => 'Add photo';

  @override
  String get oaPhotoChange => 'Change photo';

  @override
  String oaStepOf(String a, String b) {
    return 'Step $a of $b';
  }

  @override
  String get oaOb2Title => 'Where are you on campus?';

  @override
  String get oaOb2Sub =>
      'Pick your department and discover communities for you.';

  @override
  String get oaUniversity => 'University';

  @override
  String get oaUniversityName => 'Bingöl University';

  @override
  String get oaFaculty => 'Faculty';

  @override
  String get oaPickFaculty => 'Select faculty';

  @override
  String get oaPickFacultyFirst => 'Select a faculty first';

  @override
  String get oaSelectFaculty => 'Select your faculty.';

  @override
  String get oaClassPostgrad => 'Postgraduate';

  @override
  String get oaClassOther => 'Other';

  @override
  String get oaBio => 'Short bio (optional)';

  @override
  String get oaBioHint => 'Describe yourself in a few words';

  @override
  String get oaDeclareNote =>
      'The details you choose are self-declared; you can change them in your profile at any time.';

  @override
  String get oaJoin => 'Join BÜKampüs';

  @override
  String get oaLinkedTitle => 'Linked accounts';

  @override
  String get oaLinkedYes => 'Linked';

  @override
  String get oaLinkedNo => 'Not linked';

  @override
  String get oaLinkAction => 'Link';

  @override
  String get oaUnlinkAction => 'Unlink';

  @override
  String get oaLinkPwTitle => 'Confirm your password';

  @override
  String oaLinkPwBody(String provider) {
    return 'Enter your current password to link your $provider account.';
  }

  @override
  String get oaPasswordLabel => 'Password';

  @override
  String oaLinkDone(String provider) {
    return '$provider account linked.';
  }

  @override
  String get oaUnlinkTitle => 'Remove link?';

  @override
  String oaUnlinkBody(String provider) {
    return 'Sign-in with $provider will be removed; you will need another method to sign in.';
  }

  @override
  String oaUnlinkDone(String provider) {
    return '$provider link removed.';
  }

  @override
  String get oaLinkedFailed => 'Could not load linked accounts.';

  @override
  String get authPwMinErr => 'Password must be at least 6 characters.';

  @override
  String get authPwMaxErr => 'Password can be at most 72 characters.';

  @override
  String get authRegIdEmpty => 'Enter your email address.';

  @override
  String get authRegIdFull => 'Enter your full email address.';

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
  String get authForgotSubNumber =>
      'Enter your email address. We will send a 6-digit code to your email address.';

  @override
  String get authForgotSub =>
      'Enter your email address and we will send you a 6-digit code.';

  @override
  String get authBackToLogin => 'Back to log in';

  @override
  String get realEmailTitle => 'Your real email address';

  @override
  String get realEmailSubtitle =>
      'Your hidden Apple address cannot receive notifications or password reset emails. Enter the email address you actively use; it will be the only email on your account.';

  @override
  String get realEmailSoftNote =>
      'This step is optional but recommended for password reset and notifications.';

  @override
  String get realEmailSendCode => 'Send code';

  @override
  String get realEmailLater => 'Not now';

  @override
  String get realEmailCodeTitle => 'Enter the code';

  @override
  String get realEmailNoCodeHint =>
      'If the code does not arrive, check your spam folder. If the address belongs to another account, verification cannot be completed; sign in to that account or try another address.';

  @override
  String get realEmailDoneTitle => 'Your email is updated';

  @override
  String realEmailDoneBody(String email) {
    return 'Your account email is now $email. Notifications and password reset will be sent to this address.';
  }

  @override
  String get realEmailContinue => 'Continue';

  @override
  String get realEmailErrRelay =>
      'A hidden (temporary) address cannot be used. Enter the real email address you actively use.';

  @override
  String get realEmailErrUnavailable =>
      'This email address cannot be used. Try another address or sign in to the account opened with it.';

  @override
  String get realEmailErrUnchanged =>
      'This is already your account email address.';

  @override
  String get realEmailErrRequired =>
      'Add and verify your real, active email address before continuing.';

  @override
  String get authChangeEmail => 'Change email';

  @override
  String get authNewPwSub =>
      'This replaces your old password. You will be logged out on all devices.';

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
  String get welcomeNote =>
      'You can sign up with Gmail, Outlook, Hotmail, Yahoo or any other email address.';

  @override
  String get welcomeLanguage => 'Language';

  @override
  String get chatlistSearchHint => 'Search chats';

  @override
  String get bildirimFilterAll => 'All';

  @override
  String get bildirimFilterUnread => 'Unread';

  @override
  String get bildirimEmptyUnread => 'You have no unread notifications.';

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
  String get kesSegPosts => 'Posts';

  @override
  String get kesSegReels => 'Reels';

  @override
  String get kesPickVideo => 'Choose video';

  @override
  String get kesRecordVideo => 'Record video';

  @override
  String get kesVideoLimits => 'Videos can be up to 60 seconds and 50 MB.';

  @override
  String kesVideoPreparing(String pct) {
    return 'Preparing video… $pct';
  }

  @override
  String kesVideoUploading(String pct) {
    return 'Uploading video… $pct';
  }

  @override
  String get kesVideoChange => 'Change video';

  @override
  String get kesErrVideoTooLarge => 'The video is too large (50 MB at most).';

  @override
  String get kesFullscreen => 'Watch full screen';

  @override
  String get kesReelsEmptyTitle => 'No reels yet';

  @override
  String get kesReelsEmptyBody => 'Be the first to share a video.';

  @override
  String get kesReelsDoneTitle => 'You have watched all videos for now';

  @override
  String get kesReelsDoneBody => 'New videos will appear here.';

  @override
  String get kesReelsReplay => 'Watch again';

  @override
  String get kesReelsToPosts => 'Browse Explore posts';

  @override
  String get kesActionComments => 'Comments';

  @override
  String get kesActionSave => 'Save';

  @override
  String get kesActionSaved => 'Saved';

  @override
  String get kesNotInterested => 'Not interested';

  @override
  String get kesNotInterestedDone => 'This video will not be suggested again.';

  @override
  String get kesMore => 'More actions';

  @override
  String kesViews(String count) {
    return '$count views';
  }

  @override
  String get kesCoverTitle => 'Cover frame';

  @override
  String get kesCoverHint => 'Pick a frame from the video.';

  @override
  String get kesComposeMenuPhoto => 'Share a photo';

  @override
  String get kesComposeMenuVideo => 'Share a video / Reel';

  @override
  String get kesCommentsTitle => 'Comments';

  @override
  String get kesCommentsEmpty => 'No comments yet.';

  @override
  String get kesCommentsWrite => 'Write a comment…';

  @override
  String get kesCommentsSend => 'Send';

  @override
  String get kesCommentsReply => 'Reply';

  @override
  String kesCommentsReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String kesCommentsMoreReplies(String count) {
    return 'View $count replies';
  }

  @override
  String get kesCommentsLoadFailed => 'Comments could not be loaded.';

  @override
  String get kesCommentsDelete => 'Delete comment';

  @override
  String get kesAvatarPreview => 'Profile photo';

  @override
  String get kesCommentsSortTop => 'Top';

  @override
  String get kesCommentsSortNew => 'New';

  @override
  String get kesCommentsAuthorBadge => 'Author';

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
  String get profil2VisShared => 'People I know';

  @override
  String get profil2VisOnlyMe => 'Only me';

  @override
  String get profil2SharedHintLead => 'People I know:';

  @override
  String get profil2SharedHintBody =>
      'people in the same club, chat or event as you.';

  @override
  String get profil2ShowEmail => 'Show my email to other users';

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
  String get profil2SecNewHint => 'At least 6 characters';

  @override
  String get profil2SecRepeatLabel => 'New password (repeat)';

  @override
  String get profil2SecRepeatHint => 'Repeat the new password';

  @override
  String get profil2SecPwRule =>
      'At least 6 characters. Mixing letters and digits makes it stronger.';

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
  String get profil1Support => 'Help and support';

  @override
  String get profil1Legal => 'Agreements and policies';

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
  String get gonderiTextHint => 'Write something…';

  @override
  String gonderiWordCount(String n, String max) {
    return '$n/$max words';
  }

  @override
  String gonderiWordLimit(String max) {
    return 'You can write up to $max words.';
  }

  @override
  String get composeTrimTitle => 'Trim video';

  @override
  String get composeTrimDone => 'Done';

  @override
  String get composeTrimEdit => 'Edit';

  @override
  String get composeTrimCta => 'Trim video';

  @override
  String get composeTrimming => 'Trimming video…';

  @override
  String composeTrimSelected(String dur) {
    return 'Selected length $dur';
  }

  @override
  String composeTrimHint(String max) {
    return 'Drag the handles to choose a section. Up to $max.';
  }

  @override
  String composeTrimTooLong(String max) {
    return 'This video is too long. Choose a section up to $max to share it.';
  }

  @override
  String get composeTrimStart => 'Start';

  @override
  String get composeTrimEnd => 'End';

  @override
  String get composeTrimPlay => 'Play';

  @override
  String get composeTrimPause => 'Pause';

  @override
  String get composeTooLongTitle => 'Video is too long';

  @override
  String composeTooLongBody(String dur, String max) {
    return 'This video is $dur long. You can share up to $max, so trim it first.';
  }

  @override
  String get composeTooLongOther => 'Choose another video';

  @override
  String composeVideoLimitsHint(String n) {
    return 'Up to $n seconds; trim longer videos.';
  }

  @override
  String get composeTagPerson => 'Tag people';

  @override
  String composeTagRemove(String name) {
    return 'Remove tag for $name';
  }

  @override
  String get composeMentionSearch => 'Search people you follow';

  @override
  String get composeMentionEmpty => 'Follow people to tag them';

  @override
  String get composeMentionNoMatch => 'No matching people';

  @override
  String composeMentionMax(String max) {
    return 'You can tag up to $max people.';
  }

  @override
  String get composeMentionDone => 'Done';

  @override
  String postMentionOpen(String name) {
    return 'Open the profile of $name';
  }

  @override
  String get postComposeErrTextTooLong =>
      'The post text is too long. Shorten it a little and try again.';

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
  String get icerikStatPosts => 'Posts';

  @override
  String get icerikStatFollowers => 'Followers';

  @override
  String get icerikStatFollowing => 'Following';

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
  String get profilyardClubsEmptyTitle => 'You have not joined a club yet.';

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
  String get profilyardEventsEmptyTitle => 'You have no events to attend yet.';

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
  String get updateRequiredFromStore => 'Please update from the store';

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
  String get chatRealtimeLost =>
      'Live connection lost; messages are refreshed periodically.';

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
  String get p05SearchNoResultsBody => 'Try a different word.';

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
  String get p01ConfigTitle => 'Unable to connect right now';

  @override
  String get p01ConfigBody =>
      'The service is currently unavailable. Please try again later. If the problem continues, make sure your app is up to date.';

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
  String get p03MenuKcalMissing => 'Calories are missing for some dishes.';

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
  String get p03HomeMealTitle => 'Menu of the day';

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
  String get p17CourseInfoSemantic => 'Course details';

  @override
  String get p20HubExamPlan => 'Exam plan';

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
  String get p05SearchErrorTitle => 'Could not load';

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
  String get p05NewsLoadingMore => 'Loading';

  @override
  String get p05SavedDiscover => 'Explore News';

  @override
  String get p05SavedEmptyTitle2 => 'You have no saved news yet.';

  @override
  String get p05SavedEmptyBody2 =>
      'Use the bookmark on a news page to add items here.';

  @override
  String get p05ListErrorTitle => 'Could not load, try again';

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
  String get p03HomeQuickTitle => 'Quick access';

  @override
  String get p03HomeQuickEvents => 'Events';

  @override
  String get p03HomeQuickSchedule => 'Schedule';

  @override
  String get p03HomeFeaturedNews => 'Featured news';

  @override
  String get p03HomeUpcoming => 'Upcoming events';

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
  String get eventEndedNotice => 'This event has ended.';

  @override
  String get eventEndedBody => 'Joining and applications are closed.';

  @override
  String get notifEventEnded => 'Ended';

  @override
  String get notifEventCancelled => 'Cancelled';

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
  String get p60EditHint =>
      'Drag sections to reorder; use the switch to show or hide them.';

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
  String get p60ShortcutsHint =>
      'Choose up to 5 shortcuts; drag to change the order.';

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

  @override
  String get p67ChatBgStyleCampus => 'Campus';

  @override
  String get p67ChatBgStyleStudy => 'Study';

  @override
  String get p67ChatBgStyleSocial => 'Social';

  @override
  String get p67ChatBgStyleScience => 'Science';

  @override
  String get p67ChatBgStyleGeometry => 'Geometry';

  @override
  String get p67ChatBgStyleLabel => 'Pattern';

  @override
  String p67PickerLimit(String max) {
    return 'You can select up to $max items.';
  }

  @override
  String get p51EvEmptyDayBody => 'Pick another day or browse clubs.';

  @override
  String get p51EvBrowseAll => 'Explore all clubs';

  @override
  String get p51EvOffline => 'You are offline. Showing saved events.';

  @override
  String get p69WeeklyFlow => 'Weekly Schedule';

  @override
  String p69WeekN(String n) {
    return 'Week $n';
  }

  @override
  String get p69Done => 'Completed';

  @override
  String get p69LastSession => 'Last session';

  @override
  String p69Hours(String h) {
    return '$h h';
  }

  @override
  String p69TodayTotal(String n, String hours) {
    return 'Today: $n sessions in total ($hours)';
  }

  @override
  String get p69ExamCalendar => 'Exam Schedule';

  @override
  String get p69Now => 'Now';

  @override
  String get p69ExamName => 'Exam name';

  @override
  String get p69ExamNameHint => 'e.g. Data Structures Midterm';

  @override
  String get p69ExamNameErr => 'Exam name is required.';

  @override
  String get p69PickCourse => 'Select a course';

  @override
  String get p69DateLabel => 'Date';

  @override
  String get p69TimeLabel => 'Time';

  @override
  String get p69ExamNote =>
      'You get a local reminder 1 day before and a push notification 2 hours before the exam.';

  @override
  String p69SemesterTerm(String name) {
    return '$name semester';
  }

  @override
  String get p69TodayJump => 'Back to Today';

  @override
  String get p69Events => 'Academic Events';

  @override
  String p69Records(String n) {
    return '$n items';
  }

  @override
  String get p69ExamReminder => 'Exam reminder';

  @override
  String get p69ExamReminderSub =>
      'On your phone 1 day before the exam, as a notification 2 hours before.';

  @override
  String p69ClassReminderSub(String n) {
    return '$n minutes before class.';
  }

  @override
  String get p69Duration => 'Lead time';

  @override
  String get p69Classes => 'Classes';

  @override
  String get p69RemindersFooter => 'Reminders are created on this phone.';

  @override
  String get p69PermOff =>
      'Notification permission is off. Allow it in settings to get reminders.';

  @override
  String get p69NoExams => 'You haven\'t added any exams yet.';

  @override
  String get p68New => 'New';

  @override
  String get p68FormKind => 'Type';

  @override
  String get p68OptionsLabel => 'Options (2-12)';

  @override
  String get p68PickDate => 'Pick a date';

  @override
  String get p68Retract => 'Withdraw my vote';

  @override
  String get p68MyVote => 'Your vote';

  @override
  String p68TicketNo(String n) {
    return 'Ticket #$n';
  }

  @override
  String get p68Required => 'Required';

  @override
  String get p68SubjectLabel => 'Subject';

  @override
  String get p68SubjectHint => 'What happened, briefly?';

  @override
  String get p68SubjectMin => 'Subject must be at least 3 characters.';

  @override
  String get p68MessageLabel => 'Message';

  @override
  String get p68MessageHint => 'Describe the problem or request step by step…';

  @override
  String get p68ReplyNote =>
      'You will get the reply by notification and email.';

  @override
  String get p68CategoryLabel => 'Category';

  @override
  String get p68ReplyHint => 'Write your reply';

  @override
  String get p68Staff => 'Support';

  @override
  String get p68NoTickets => 'You have no requests yet.';

  @override
  String get p68SugTitle => 'Suggestions';

  @override
  String get p68SugSend => 'Send a suggestion';

  @override
  String get p68SugTop => 'Top voted';

  @override
  String get p68SugNew => 'New';

  @override
  String get p68SugEmpty => 'No suggestions yet.';

  @override
  String get p51EvAttOpen => 'Check-in is open';

  @override
  String get p51EvScanQr => 'Check in with QR';

  @override
  String get p51EvGoingYou => 'You are going';

  @override
  String get p51EvLblDate => 'Date';

  @override
  String get p51EvLblTime => 'Time';

  @override
  String get p51EvLblPlace => 'Place';

  @override
  String get p51EvLblAttendees => 'Attendees';

  @override
  String p51EvPeople(String count) {
    return '$count people';
  }

  @override
  String get p51EvQrTitle => 'Check-in QR';

  @override
  String get p51EvReqTitle => 'Requests';

  @override
  String get p51EvTabPending => 'Pending';

  @override
  String get p51EvTabApproved => 'Approved';

  @override
  String get p51EvTabRejected => 'Rejected';

  @override
  String p51EvQuota(String cap, String going) {
    return 'Capacity $cap · $going approved';
  }

  @override
  String p51EvQuotaGoing(String n) {
    return '$n approved';
  }

  @override
  String get p51EvQuotaNote =>
      'New requests can\'t be approved once the capacity is full.';

  @override
  String p51EvPresentAbsent(String present, String absent) {
    return '$present present · $absent absent';
  }

  @override
  String p51EvTotalPeople(String count) {
    return 'Total $count people';
  }

  @override
  String get p68TypeMulti => 'Multiple';

  @override
  String get p68TypeRanked => 'Ranked';

  @override
  String get p51EvAttList => 'Check-in list';

  @override
  String get p51EvClubOnly => 'Events are created on behalf of clubs.';

  @override
  String get p60Today => 'Today on campus';

  @override
  String get p60NextClass => 'Next class';

  @override
  String get p60UpcomingExam => 'Upcoming exam';

  @override
  String get p60OpenMenu => 'Open menu';

  @override
  String get p60NoNews => 'No news yet.';

  @override
  String get p60NoAnnouncements => 'No announcements yet.';

  @override
  String p60Classroom(String room) {
    return 'Room $room';
  }

  @override
  String get p60EmptySub => 'You have not chosen any section to show.';

  @override
  String get p60Selected => 'Selected shortcuts (order)';

  @override
  String get p60AllShortcuts => 'All shortcuts';

  @override
  String p60Remove(String name) {
    return 'Remove $name';
  }

  @override
  String get p60ShortScheduleFull => 'Timetable';

  @override
  String p63NewsLastUpdate(String when) {
    return 'Last updated: $when';
  }

  @override
  String get frqPrivateTitle => 'Private account';

  @override
  String get frqPrivateSub =>
      'With a private account, only people you approve can see your posts and follower list. Your current followers stay.';

  @override
  String get frqPrivateOffTitle => 'Make account public?';

  @override
  String get frqPrivateOffBody =>
      'Pending follow requests are accepted automatically. Everyone can see your posts and follower list.';

  @override
  String get frqPrivateOffConfirm => 'Make public';

  @override
  String get frqFollowRequested => 'Request sent';

  @override
  String get frqSemRequested => 'Follow request sent. Tap to withdraw';

  @override
  String get frqUnfollowTitle => 'Unfollow?';

  @override
  String get frqUnfollowBody => 'You will no longer follow this person.';

  @override
  String get frqUnfollowBodyPrivate =>
      'This account is private. If you unfollow, you will need to send a new request.';

  @override
  String get frqUnfollowConfirm => 'Unfollow';

  @override
  String get frqCancelReqTitle => 'Withdraw request?';

  @override
  String get frqCancelReqBody =>
      'Your follow request will be withdrawn. You can send it again later.';

  @override
  String get frqCancelReqConfirm => 'Withdraw request';

  @override
  String get frqLockedTitle => 'This account is private';

  @override
  String get frqLockedBody => 'Send a follow request to see their posts.';

  @override
  String get frqLockedBodyRequested =>
      'You can see their posts once your request is approved.';

  @override
  String get frqReqTitle => 'Follow requests';

  @override
  String frqReqRow(String n) {
    return 'Follow requests ($n)';
  }

  @override
  String frqReqPending(String n) {
    return 'Pending requests ($n)';
  }

  @override
  String get frqReqAccept => 'Approve';

  @override
  String get frqReqDecline => 'Delete';

  @override
  String frqReqAcceptSem(String name) {
    return 'Approve request from $name';
  }

  @override
  String frqReqDeclineSem(String name) {
    return 'Delete request from $name';
  }

  @override
  String get frqReqEmpty => 'No pending follow requests.';

  @override
  String get frqNotifTypeFollow => 'Follow';

  @override
  String frqMsgReqRow(String n) {
    return 'Message requests ($n)';
  }

  @override
  String get frqMsgReqTitle => 'Message requests';

  @override
  String get frqMsgReqInfo =>
      'Messages from people you do not follow and who share no club or event with you appear here. Until you accept, the sender cannot see whether you have read their messages. Replying accepts the request automatically.';

  @override
  String get frqMsgReqAccept => 'Accept';

  @override
  String get frqMsgReqDecline => 'Delete';

  @override
  String get frqMsgReqGroupInvite => 'Group invite';

  @override
  String get frqMsgReqEmpty => 'No pending message requests.';

  @override
  String get frqMsgReqDeclineGroupTitle => 'Delete group invite?';

  @override
  String get frqMsgReqDeclineGroupBody =>
      'You will leave the group and the person who added you cannot add you again.';

  @override
  String get frqMsgReqDeclineGroupConfirm => 'Delete invite';

  @override
  String get homeBrandSubtitle => 'Bingöl University Campus App';

  @override
  String get homeLibrary => 'Library';

  @override
  String get homeFeaturedSchedule => 'Class Schedule';

  @override
  String get homeFeaturedMenu => 'Meal Menu';

  @override
  String get homeMenuRate => 'Rate the menu';

  @override
  String get homeMenuPhotoPending => 'Waiting for a new photo';

  @override
  String get homeSearchFilters => 'Search filters';

  @override
  String get homeMore => 'More';

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeJoinedEvents => 'Events I joined';

  @override
  String get regTitle => 'Create your account';

  @override
  String get regSubtitle =>
      'Enter your name, email address and a password. Your verification code will be sent to your email address.';

  @override
  String get profileSetupTitle => 'Choose your department';

  @override
  String get profileSetupSubtitle =>
      'Enter your department and year once; you can change them later from your profile.';

  @override
  String get photoSetupTitle => 'Would you like to add a profile photo?';

  @override
  String get photoSetupSubtitle =>
      'Other students will recognize you more easily. You can add or change it from your profile at any time.';

  @override
  String get photoSetupPick => 'Choose photo';

  @override
  String get photoSetupChange => 'Change';

  @override
  String get photoSetupSkip => 'Skip for now';

  @override
  String get photoSetupAvatarSemantic => 'Choose profile photo';

  @override
  String get avatarEdTitle => 'Edit photo';

  @override
  String get avatarEdCancel => 'Cancel';

  @override
  String get avatarEdDone => 'Done';

  @override
  String get avatarEdUndo => 'Undo';

  @override
  String get avatarEdRedo => 'Redo';

  @override
  String get avatarEdTabCrop => 'Crop';

  @override
  String get avatarEdTabBg => 'Backdrop';

  @override
  String get avatarEdTabFilter => 'Filter';

  @override
  String get avatarEdTabAdjust => 'Adjust';

  @override
  String get avatarEdRotateLeft => 'Rotate left';

  @override
  String get avatarEdRotateRight => 'Rotate right';

  @override
  String get avatarEdMirror => 'Mirror';

  @override
  String get avatarEdReset => 'Reset';

  @override
  String get avatarEdZoom => 'Zoom';

  @override
  String get avatarEdAngle => 'Angle';

  @override
  String get avatarEdBgBlur => 'Blur';

  @override
  String get avatarEdBgWhite => 'White';

  @override
  String get avatarEdBgBlack => 'Black';

  @override
  String get avatarEdBgBrand => 'Brand';

  @override
  String get avatarEdBgNavy => 'Navy';

  @override
  String get avatarEdBgSand => 'Sand';

  @override
  String get avatarEdBgHint =>
      'If the photo is smaller than the frame, the gap is filled with this backdrop.';

  @override
  String get avatarEdFOriginal => 'Original';

  @override
  String get avatarEdFVivid => 'Vivid';

  @override
  String get avatarEdFCool => 'Cool';

  @override
  String get avatarEdFWarm => 'Warm';

  @override
  String get avatarEdFMono => 'Black & white';

  @override
  String get avatarEdFFaded => 'Faded';

  @override
  String get avatarEdBrightness => 'Brightness';

  @override
  String get avatarEdContrast => 'Contrast';

  @override
  String get avatarEdSaturation => 'Saturation';

  @override
  String get avatarEdWarmth => 'Warmth';

  @override
  String get avatarEdVignette => 'Vignette';

  @override
  String get avatarEdStageSemantic =>
      'Photo editing area. Drag, pinch to zoom in or out, double-tap to fit.';

  @override
  String get photoEdTabRatio => 'Ratio';

  @override
  String get photoEdRatioFree => 'Free';

  @override
  String get photoEdRatioHint =>
      'Pick the frame ratio; the photo is cropped to it. Free keeps the photo\'s own ratio.';

  @override
  String get avatarSheetTitle => 'Profile photo';

  @override
  String get avatarRemoveTitle => 'Remove your profile photo?';

  @override
  String get avatarRemoveBody =>
      'The default picture will be shown. You can add a photo again at any time.';

  @override
  String get avatarRemoveConfirm => 'Remove';

  @override
  String get avatarCropTitle => 'Position photo';

  @override
  String get avatarCropConfirm => 'Confirm';

  @override
  String get avatarCropCancel => 'Cancel';

  @override
  String get avatarCropHint =>
      'Pinch to zoom, drag to position. This is how it looks on your profile.';

  @override
  String get avatarUpdated => 'Your profile photo was updated.';

  @override
  String get avatarRemoved => 'Your profile photo was removed.';

  @override
  String get campusAbout => 'About';

  @override
  String get campusSort => 'Sort';

  @override
  String get settingsAnalytics => 'Usage analytics';

  @override
  String get settingsAnalyticsSub =>
      'Usage data such as time spent on screens and actions is sent to improve the app. Message content, search text and personal details are never sent. Turning this off stops collection and deletes anything pending.';

  @override
  String get chatSecureCaptured =>
      'This content cannot be viewed while the screen is being recorded.';

  @override
  String get chatSecureScreenshot =>
      'Screenshot detected. The photo has been closed.';

  @override
  String get chatSecureProtectedTitle => 'Screen capture protection';

  @override
  String get chatSecureProtectedBody =>
      'This photo can be viewed only once and is protected.';

  @override
  String get chatSecureUnsupportedTitle =>
      'Can\'t be opened securely on this device';

  @override
  String get chatSecureUnsupportedBody =>
      'Screen capture protection could not be set up, so this view-once photo was not opened and your view was not used.';

  @override
  String get chatSecureRevokedBody =>
      'The photo was closed because screen capture protection stopped working.';

  @override
  String get verifyEmailBannerTitle => 'Verify your email';

  @override
  String get verifyEmailBannerBody =>
      'Until you verify, some actions (posts, messages, following...) are unavailable.';

  @override
  String get verifyEmailBannerCta => 'Enter code';

  @override
  String get verifySheetTitle => 'Verify your email';

  @override
  String get verifySheetBody => 'Enter the 6-digit code sent to your email.';

  @override
  String get verifyQuotaInfo =>
      'The verification email cannot be sent right now. We will send it as soon as possible. You can enter the code here once it arrives.';

  @override
  String get verifyDone => 'Your email is verified';

  @override
  String get errEmailVerificationRequired => 'Verify your email to do this';

  @override
  String get notifActionAck => 'Got it';

  @override
  String get notifActionQuickReply => 'Quick reply';

  @override
  String get notifActionOpenAll => 'Open all';

  @override
  String get notifActionProgram => 'Event details';

  @override
  String notifKcalTotal(String n) {
    return 'Total $n kcal';
  }

  @override
  String notifOldTime(String time) {
    return 'Old time: $time';
  }

  @override
  String notifNewTime(String time) {
    return 'New time $time';
  }

  @override
  String get notifBadgeImportant => 'IMPORTANT';

  @override
  String get notifSourceModeration => 'Moderation';

  @override
  String notifAgoMin(String n) {
    return '$n min ago';
  }

  @override
  String notifAgoHour(String n) {
    return '$n hr ago';
  }

  @override
  String notifAgoDay(String n) {
    return '$n d ago';
  }

  @override
  String notifYesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String notifNewCount(String n) {
    return '$n New';
  }

  @override
  String notifGroupUnread(String n) {
    return '$n unread';
  }

  @override
  String get notifPrefMealMenu => 'Daily menu';

  @override
  String get notifPrefMealMenuSub =>
      'A notification with the menu of the day. Off by default.';

  @override
  String get notifExamAlarmOn => 'Reminder on';

  @override
  String get notifExamAlarmOff => 'Reminder off';

  @override
  String notifCapacityFull(String n) {
    return 'Capacity: $n% full';
  }

  @override
  String get alarmClockNote =>
      'Alarms are added to the Clock app on your phone. Open the Clock app to delete them.';

  @override
  String get alarmIosNote =>
      'iPhone does not allow adding alarms to the Clock app. This notification replaces an alarm and may not sound in silent mode.';

  @override
  String get alarmUnavailable => 'No Clock app was found on this device.';

  @override
  String get alarmNotifOff =>
      'Notifications are off. Turn them on in Settings > BÜ Kampüs > Notifications to get the reminders.';

  @override
  String get alarmExamAction => 'Set first-exam alarms';

  @override
  String get alarmExamActionIos => 'Remind me of exams with notifications';

  @override
  String get alarmExamSheetTitle => 'Exam day alarms';

  @override
  String get alarmExamSheetTitleIos => 'Exam day notifications';

  @override
  String get alarmExamSheetSub =>
      'One-time, 1 hour before the first exam of each day only.';

  @override
  String alarmExamRow(String exam, String alarm) {
    return 'Exam $exam → Alarm $alarm';
  }

  @override
  String alarmExamSkipped(String times) {
    return 'No alarm for the $times exam';
  }

  @override
  String get alarmExamNone => 'No upcoming exams to set alarms for.';

  @override
  String alarmExamDeferred(String n) {
    return '$n alarms are for later dates. The Android Clock app cannot set a one-time alarm for a later date, so we notify you the evening before the exam day and you set it with one tap.';
  }

  @override
  String get alarmExamDeferredRow => 'Reminded the evening before';

  @override
  String alarmSetCount(String n) {
    return 'Set $n alarms';
  }

  @override
  String alarmNotifyCount(String n) {
    return 'Schedule $n notifications';
  }

  @override
  String alarmDoneSet(String n) {
    return '$n alarms set. Check them in the Clock app.';
  }

  @override
  String alarmDoneNotif(String n) {
    return '$n notifications scheduled.';
  }

  @override
  String alarmDoneDeferred(String n) {
    return '$n alarms will be reminded before the exam day.';
  }

  @override
  String alarmDoneFail(String n) {
    return '$n alarms could not be set.';
  }

  @override
  String alarmDueBanner(String n) {
    return '$n exam alarms are ready to set.';
  }

  @override
  String get alarmDueAction => 'Set now';

  @override
  String get alarmNudgeTitle => 'Set your exam alarm';

  @override
  String alarmNudgeBody(String title, String time) {
    return '$title: the $time alarm is ready. Tap to set it on the Exams page.';
  }

  @override
  String alarmExamLabel(String time, String title) {
    return 'Exam $time: $title';
  }

  @override
  String get alarmExamNotifTitle => 'Alarm: Exam in 1 hour';

  @override
  String get alarmClassAction => 'Set morning alarms';

  @override
  String get alarmClassActionIos => 'Set morning class notifications';

  @override
  String get alarmClassSheetTitle => 'Morning class alarms';

  @override
  String get alarmClassSheetTitleIos => 'Morning class notifications';

  @override
  String get alarmClassSheetSub =>
      'If the first class of a day starts before noon: 1 hour earlier, repeating every week.';

  @override
  String alarmClassRow(String classTime, String alarm) {
    return 'Class $classTime → Alarm $alarm · weekly';
  }

  @override
  String alarmClassSkipped(String days) {
    return '$days: first class is in the afternoon, no alarm';
  }

  @override
  String get alarmClassNone => 'No morning classes; no alarms to set.';

  @override
  String alarmClassLabel(String time) {
    return 'Class alarm · first class $time';
  }

  @override
  String get alarmClassNotifTitle => 'Alarm: Class in 1 hour';

  @override
  String alarmClassNotifBody(String time) {
    return 'Your first class starts at $time.';
  }

  @override
  String alarmRepeatWarn(String date) {
    return 'These alarms were set on $date. Setting them again may create duplicates in the Clock app.';
  }

  @override
  String get alarmSetAnyway => 'Set anyway';

  @override
  String alarmDoneClassSet(String n) {
    return '$n repeating alarms set. Check or delete them in the Clock app.';
  }

  @override
  String get calSyncRowTitle => 'Add to device calendar';

  @override
  String get calSyncRowSub =>
      'The whole academic calendar, with an 08:00 reminder on the day';

  @override
  String calSyncRowDone(String n) {
    return 'In device calendar · $n events';
  }

  @override
  String get calSyncRowDoneSub => 'Update or remove';

  @override
  String get calSyncSheetBody =>
      'The academic calendar for the next 12 months is written as events. All-day entries get a reminder at 08:00 on the day; your calendar app sends the notification. Only BÜ Kampüs events are added or removed.';

  @override
  String get calSyncTarget => 'Calendar';

  @override
  String get calSyncNewLocal => 'BÜ Kampüs (new local calendar)';

  @override
  String get calSyncAdd => 'Add to calendar';

  @override
  String get calSyncUpdate => 'Update';

  @override
  String get calSyncRemove => 'Remove from calendar';

  @override
  String get calSyncRemoveTitle => 'Remove BÜ Kampüs events?';

  @override
  String calSyncRemoveBody(String n) {
    return 'The $n events this app added to your calendar will be deleted. Your other events are not affected.';
  }

  @override
  String calSyncResult(String added, String updated, String same) {
    return '$added events added, $updated updated, $same unchanged.';
  }

  @override
  String calSyncRemovedN(String n) {
    return '$n removed.';
  }

  @override
  String calSyncFailedN(String n) {
    return '$n could not be written.';
  }

  @override
  String get calSyncRationale =>
      'Calendar access is needed to write the academic calendar to your device calendar. Only BÜ Kampüs events are added or removed; your other events are left alone.';

  @override
  String get calSyncDenied =>
      'Calendar access is off. Turn it on in Settings > BÜ Kampüs > Calendar.';

  @override
  String get calSyncOpenSettings => 'Open settings';

  @override
  String get calSyncNoCalendar =>
      'There is no writable calendar on this device. A local calendar named BÜ Kampüs will be created.';

  @override
  String get calSyncFetchError =>
      'Could not load the academic calendar. Check your connection and try again.';

  @override
  String get calSyncEmpty =>
      'There are no current academic calendar entries to write.';

  @override
  String get calSyncUnavailable =>
      'Calendar access is not supported on this device.';

  @override
  String calSyncRemoveDone(String n) {
    return '$n events removed from the calendar.';
  }

  @override
  String get calSyncCreateFail => 'Could not create the calendar.';

  @override
  String get calSyncWorking => 'Writing to calendar…';

  @override
  String get tfTitle => 'Two-factor authentication';

  @override
  String get tfSecSection => 'Sign-in security';

  @override
  String get tfOn => 'On';

  @override
  String get tfOff => 'Off';

  @override
  String get tfToggleSubOff =>
      'Off. When you sign in from an unknown device, a code is sent to your e-mail.';

  @override
  String get tfToggleSubOn =>
      'On. Signing in from an unknown device asks for the code sent to your e-mail.';

  @override
  String get tfIntro =>
      'When your account is signed in from an unknown device, a 6-digit code is sent to your e-mail. Trusted devices are not asked for a code.';

  @override
  String get tfDevicesSection => 'Trusted devices';

  @override
  String get tfDevicesEmpty =>
      'No trusted devices yet. Turn on Trust this device when signing in and it will be listed here.';

  @override
  String get tfDeviceThis => 'This device';

  @override
  String get tfDeviceUnnamed => 'Device';

  @override
  String tfDeviceLastUsed(String date) {
    return 'Last used $date';
  }

  @override
  String get tfDeviceRemove => 'Remove device';

  @override
  String get tfDeviceRemoveTitle => 'Remove this device?';

  @override
  String get tfDeviceRemoveBody =>
      'A code will be asked again at the next sign-in from this device. The open session stays signed in.';

  @override
  String get tfDeviceRemoveConfirm => 'Remove';

  @override
  String get tfDeviceRemoved => 'Device removed.';

  @override
  String get tfEnabledToast => 'Two-factor authentication is on.';

  @override
  String get tfDisabledToast => 'Two-factor authentication is off.';

  @override
  String tfEnableSubtitle(String email) {
    return 'To turn it on, enter the 6-digit code sent to $email. The code is valid for 10 minutes.';
  }

  @override
  String get tfEnableSubtitleNoMail =>
      'To turn it on, enter the 6-digit code sent to your e-mail. The code is valid for 10 minutes.';

  @override
  String get tfDisableTitle => 'Turn off two-factor authentication?';

  @override
  String get tfDisableBody =>
      'Confirm with your password. All trusted devices are removed and your account is protected by the password only.';

  @override
  String get tfDisableConfirm => 'Turn off';

  @override
  String get tfWrongPassword => 'Incorrect password.';

  @override
  String tfLoginSubtitle(String email) {
    return 'To sign in, enter the 6-digit code sent to $email. The code is valid for 10 minutes.';
  }

  @override
  String get tfLoginSubtitleNoMail =>
      'To sign in, enter the 6-digit code sent to your e-mail. The code is valid for 10 minutes.';

  @override
  String get tfTrustLabel => 'Trust this device';

  @override
  String get tfTrustHint =>
      'No code is asked on later sign-ins from this device. Turn it on only on your own phone.';

  @override
  String get tfBackToLogin => 'Back to sign in';

  @override
  String get tfErrCodeInvalid =>
      'The verification code is invalid or has expired.';

  @override
  String get tfErrChallengeExpired =>
      'The verification session has expired. Please sign in again.';

  @override
  String get tfErrLocked =>
      'Too many wrong verification codes were entered; sign-in from a new device is locked for 24 hours. You can sign in from a trusted device or reset your password.';

  @override
  String get tfErrAlreadyEnabled => 'Two-factor authentication is already on.';

  @override
  String get tfErrNotEnabled => 'Two-factor authentication is not on.';

  @override
  String get chatArchiveBarTitle => 'Archived';

  @override
  String chatArchiveBarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications',
      one: '1 notification',
    );
    return '$_temp0';
  }

  @override
  String chatArchiveBarSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications',
      one: '1 notification',
    );
    return 'Archived, $_temp0';
  }

  @override
  String forumCommentLikeSemantic(String n) {
    return 'Like, $n likes';
  }

  @override
  String forumCommentUnlikeSemantic(String n) {
    return 'Unlike, $n likes';
  }

  @override
  String get forumCommentReadMore => 'Read more';

  @override
  String get forumCommentReadLess => 'Show less';

  @override
  String get forumDetailDeletedAccount => 'Deleted account';

  @override
  String get forumCommentDeletedPlaceholder => 'This comment was deleted';

  @override
  String get forumCommentAuthorBadge => 'Author';

  @override
  String get forumCommentEdited => 'Edited';

  @override
  String get forumCommentReply => 'Reply';

  @override
  String get forumCommentMore => 'More actions';

  @override
  String get forumCommentLockedHint =>
      'This topic is locked. Comments are closed.';

  @override
  String get forumCommentEditingBanner => 'Editing your comment';

  @override
  String forumCommentReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get forumCommentCancelTarget => 'Cancel reply or edit';

  @override
  String get forumCommentHint => 'Write a comment…';

  @override
  String get forumCommentHintReply => 'Write your reply…';

  @override
  String get forumCommentAnonLabel => 'Comment anonymously';

  @override
  String forumCommentCounter(String n, String max) {
    return '$n / $max';
  }

  @override
  String get forumCommentSend => 'Send';

  @override
  String get forumCommentSaveEdit => 'Save';

  @override
  String forumCommentShowReplies(String n) {
    return 'Show $n replies';
  }

  @override
  String forumCommentReplyContext(String name) {
    return 'Replying to $name';
  }

  @override
  String get forumModRemoveAction => 'Remove (moderator)';

  @override
  String get forumModReasonTitle => 'Remove content';

  @override
  String get forumModReasonBody =>
      'The reason is sent to the author and written to the moderation log.';

  @override
  String get forumModReasonHint => 'Reason (at least 3 characters)';

  @override
  String get forumModRemoveConfirm => 'Remove';

  @override
  String get forumModRemovedDone => 'Content removed.';

  @override
  String get forumCommentHideReplies => 'Hide replies';

  @override
  String forumCommentMoreReplies(String n) {
    return '$n more replies';
  }

  @override
  String get forumCommentMoreRepliesGeneric => 'More replies';

  @override
  String forumCommentOpenChain(String n) {
    return 'Open reply chain ($n)';
  }

  @override
  String get forumCommentRepliesFailed => 'Could not load replies.';

  @override
  String get forumCommentActionEdit => 'Edit';

  @override
  String get forumCommentActionDelete => 'Delete';

  @override
  String get forumCommentActionCopy => 'Copy text';

  @override
  String get forumCommentActionShare => 'Share link';

  @override
  String get forumCommentActionLike => 'Like';

  @override
  String get forumCommentActionUnlike => 'Unlike';

  @override
  String get forumCommentActionSave => 'Save';

  @override
  String get forumCommentActionUnsave => 'Remove from saved';

  @override
  String get forumCommentActionReport => 'Report';

  @override
  String get forumCommentActionBlock => 'Block user';

  @override
  String get forumCommentCopied => 'Text copied';

  @override
  String get forumCommentDeleted => 'Comment deleted';

  @override
  String get forumCommentDeleteTitle => 'Delete this comment?';

  @override
  String get forumCommentDeleteBody => 'This cannot be undone.';

  @override
  String get forumCommentDeleteConfirm => 'Delete';

  @override
  String get forumCommentBlockTitle => 'Block this user?';

  @override
  String get forumCommentBlockBody =>
      'You will no longer see this person\'s content. An anonymous author\'s identity is never revealed.';

  @override
  String get forumCommentBlockConfirm => 'Block';

  @override
  String get forumCommentBlocked => 'User blocked';

  @override
  String get forumCommentSaved => 'Saved';

  @override
  String get forumCommentUnsaved => 'Removed from saved';

  @override
  String get forumCommentGone =>
      'This comment no longer exists. The list was refreshed.';

  @override
  String get forumCommentConflict =>
      'The comment was changed elsewhere. The list was refreshed.';

  @override
  String get forumCommentSent => 'Comment posted';

  @override
  String get forumCommentReplySent => 'Reply posted';

  @override
  String get forumCommentEditDone => 'Comment updated';

  @override
  String get forumCommentLinkNotFound =>
      'The linked comment could not be found';

  @override
  String get forumDetailSortBest => 'Best';

  @override
  String get forumDetailSortNewest => 'Newest';

  @override
  String get forumDetailSortOldest => 'Oldest';

  @override
  String forumDetailCommentsHeader(String n) {
    return 'Comments ($n)';
  }

  @override
  String get forumDetailNoComments => 'No comments yet';

  @override
  String get forumDetailNoCommentsBody => 'Be the first to comment.';

  @override
  String get forumDetailCommentsError => 'Could not load comments';

  @override
  String get forumDetailSlow => 'Slow connection, please wait a bit…';

  @override
  String get forumDetailSemanticTitle => 'Topic';

  @override
  String get forumDetailNotFoundTitle => 'This topic no longer exists';

  @override
  String get forumDetailNotFoundBody => 'It may have been deleted or removed.';

  @override
  String get forumDetailRemovedTitle => 'This topic was removed';

  @override
  String get forumDetailRemovedBody =>
      'It was removed under the community rules.';

  @override
  String get forumDetailLockedBanner =>
      'This topic is locked. New comments are closed.';

  @override
  String get forumDetailPinned => 'Pinned';

  @override
  String get forumDetailEdited => 'Edited';

  @override
  String get forumDetailLikeAction => 'Like';

  @override
  String get forumDetailUnlikeAction => 'Unlike';

  @override
  String get forumDetailSaveAction => 'Save';

  @override
  String get forumDetailUnsaveAction => 'Remove from saved';

  @override
  String get forumDetailFollowAction => 'Follow';

  @override
  String get forumDetailUnfollowAction => 'Unfollow';

  @override
  String get forumDetailShareAction => 'Share';

  @override
  String get forumDetailCommentsAction => 'Go to comments';

  @override
  String forumDetailCommentCount(String n) {
    return '$n comments';
  }

  @override
  String forumDetailLikeCount(String n) {
    return '$n likes';
  }

  @override
  String get forumDetailMenu => 'Topic options';

  @override
  String get forumDetailMenuEdit => 'Edit topic';

  @override
  String get forumDetailMenuDelete => 'Delete topic';

  @override
  String get forumDetailMenuNotificationsOff => 'Turn off notifications';

  @override
  String get forumDetailMenuNotificationsOn => 'Turn on notifications';

  @override
  String get forumDetailMenuShare => 'Share link';

  @override
  String get forumDetailMenuPin => 'Pin topic';

  @override
  String get forumDetailMenuUnpin => 'Unpin topic';

  @override
  String get forumDetailMenuLock => 'Lock comments';

  @override
  String get forumDetailMenuUnlock => 'Unlock comments';

  @override
  String get forumDetailMenuReport => 'Report';

  @override
  String get forumDetailMenuBlock => 'Block author';

  @override
  String get forumDetailDeleteTitle => 'Delete this topic?';

  @override
  String get forumDetailDeleteBody =>
      'The topic and its comments will be removed. This cannot be undone.';

  @override
  String get forumDetailDeleteConfirm => 'Delete';

  @override
  String get forumDetailDeleted => 'Topic deleted';

  @override
  String get forumDetailBlockTitle => 'Block this author?';

  @override
  String get forumDetailBlockBody =>
      'You will no longer see this author\'s content. If anonymous, the identity is never revealed.';

  @override
  String get forumDetailBlockConfirm => 'Block';

  @override
  String get forumDetailBlocked => 'Author blocked';

  @override
  String get forumDetailNotificationsOffDone =>
      'Notifications for this topic are off';

  @override
  String get forumDetailNotificationsOnDone =>
      'Notifications for this topic are on';

  @override
  String get forumDetailPinnedDone => 'Topic pinned';

  @override
  String get forumDetailUnpinnedDone => 'Topic unpinned';

  @override
  String get forumDetailLockedDone => 'Comments locked';

  @override
  String get forumDetailUnlockedDone => 'Comments unlocked';

  @override
  String forumDetailImageIndex(String i, String n) {
    return '$i / $n';
  }

  @override
  String forumDetailImageSemantic(String i, String n) {
    return 'Topic image $i of $n';
  }

  @override
  String get forumDetailChainRoot => 'Reply chain';

  @override
  String get forumDetailFollowing => 'Following this topic';

  @override
  String get forumDetailUnfollowed => 'Unfollowed this topic';

  @override
  String get forumDetailSaved => 'Topic saved';

  @override
  String get forumDetailUnsaved => 'Removed from saved';

  @override
  String get forumDetailLockedChip => 'Locked';

  @override
  String get forumComposeClose => 'Close';

  @override
  String get forumComposePublish => 'Publish';

  @override
  String get forumComposePublishing => 'Publishing';

  @override
  String get forumComposeTitleHint => 'Title';

  @override
  String get forumComposeBodyHint => 'What do you want to talk about?';

  @override
  String get forumComposeCategoryLabel => 'Category';

  @override
  String get forumComposeCategoryPick => 'Choose a category';

  @override
  String get forumComposeCategoryLoading => 'Loading categories';

  @override
  String get forumComposeCategoryError => 'Could not load categories';

  @override
  String get forumComposeRetry => 'Try again';

  @override
  String get forumComposeAddImage => 'Add image';

  @override
  String forumComposeImageCount(int count, int max) {
    return '$count/$max images';
  }

  @override
  String get forumComposeGallery => 'Choose from gallery';

  @override
  String get forumComposeCamera => 'Take a photo';

  @override
  String get forumComposeImageRemove => 'Remove image';

  @override
  String get forumComposeImageUploading => 'Uploading image';

  @override
  String get forumComposeImageRetry => 'Retry upload';

  @override
  String get forumComposeImagesPending =>
      'You can publish once the images finish uploading.';

  @override
  String get forumComposeImageFailedHint =>
      'An image failed to upload. Retry or remove it.';

  @override
  String get forumComposeErrImageTooLarge => 'The image is too large.';

  @override
  String get forumComposeErrImageType =>
      'Only JPEG, PNG and WebP images can be added.';

  @override
  String get forumComposeErrImageRead => 'The image could not be read.';

  @override
  String get forumComposeErrImageUpload => 'The image could not be uploaded.';

  @override
  String get forumComposePollAdd => 'Add a poll';

  @override
  String get forumComposeAnonymous => 'Post anonymously';

  @override
  String get forumComposeAnonymousDesc =>
      'Your name is not shown to other students.';

  @override
  String get forumComposeAnonymousNote => 'Moderators can review misuse.';

  @override
  String get forumComposeNeedTitle => 'Write a title.';

  @override
  String get forumComposeNeedBody => 'Write a description.';

  @override
  String get forumComposeNeedCategory => 'Choose a category.';

  @override
  String get forumComposeNeedPoll => 'A poll needs at least 2 filled options.';

  @override
  String get forumComposeDraftRestored => 'Draft restored';

  @override
  String get forumComposeDraftSheetTitle => 'Save as a draft?';

  @override
  String get forumComposeDraftSheetBody =>
      'What you wrote will be here next time.';

  @override
  String get forumComposeDraftSave => 'Save draft';

  @override
  String get forumComposeDraftDelete => 'Discard';

  @override
  String get forumComposeDraftContinue => 'Keep editing';

  @override
  String get forumComposeErrNetwork =>
      'No internet connection. Your text is kept.';

  @override
  String get forumComposeErrRate =>
      'You are posting too often. Wait a bit and try again.';

  @override
  String get forumComposeErrDuplicate => 'You just posted the same content.';

  @override
  String get forumComposeErrProfanity =>
      'The text contains inappropriate language. Edit it and try again.';

  @override
  String get forumComposeErrCategory =>
      'This category is no longer available. Choose another one.';

  @override
  String get forumComposeErrInvalid =>
      'The content is not valid. Check the title and description.';

  @override
  String get forumComposeErrGeneric =>
      'The topic could not be published. Your text is kept, try again.';

  @override
  String get forumComposeEditSave => 'Save';

  @override
  String get forumComposeEditSaving => 'Saving';

  @override
  String get forumComposeEditLocked =>
      'This topic is locked and cannot be edited.';

  @override
  String get forumComposeEditGone => 'This topic no longer exists.';

  @override
  String get forumComposeEditNotOwner => 'Only the owner can edit this topic.';

  @override
  String get forumComposeEditSaved => 'Edited';

  @override
  String get forumComposeEditNote =>
      'Images and the poll cannot be changed later.';

  @override
  String get forumPollQuestionHint => 'Question (optional)';

  @override
  String forumPollOptionHint(int n) {
    return 'Option $n';
  }

  @override
  String get forumPollAddOption => 'Add option';

  @override
  String get forumPollRemoveOption => 'Remove option';

  @override
  String forumPollMaxOptions(int max) {
    return 'At most $max options can be added.';
  }

  @override
  String get forumPollEndsAt => 'Ends';

  @override
  String get forumPollEndsNone => 'No end';

  @override
  String forumPollEndsDays(int n) {
    return '$n days';
  }

  @override
  String get forumPollEndsPickDate => 'Pick a date';

  @override
  String forumPollEndsOn(String date) {
    return 'Ends on $date';
  }

  @override
  String get forumPollAllowChange => 'Votes can be changed';

  @override
  String get forumPollRemove => 'Remove poll';

  @override
  String forumPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String forumPollPercent(String p) {
    return '$p%';
  }

  @override
  String get forumPollMine => 'Your vote';

  @override
  String get forumPollEnded => 'Poll ended';

  @override
  String forumPollLeftDays(int n) {
    return '$n days left';
  }

  @override
  String forumPollLeftHours(int n) {
    return '$n hours left';
  }

  @override
  String forumPollLeftMinutes(int n) {
    return '$n minutes left';
  }

  @override
  String get forumPollCanChange => 'You can change your vote';

  @override
  String get forumPollLocked => 'Votes cannot be changed once cast';

  @override
  String get forumPollUndo => 'Withdraw my vote';

  @override
  String forumPollSemantics(String text, String percent, String votes) {
    return '$text, $percent, $votes';
  }

  @override
  String get forumPollSelected => 'Selected';

  @override
  String get forumPollErrClosed => 'The poll has ended.';

  @override
  String get forumPollErrAlready =>
      'Your vote is already recorded and cannot be changed.';

  @override
  String get forumPollErrNetwork =>
      'No internet connection. Your vote was not sent.';

  @override
  String get forumPollErrRate => 'Too many vote actions. Wait a moment.';

  @override
  String get forumPollErrGone => 'This topic or poll no longer exists.';

  @override
  String get forumPollErrForbidden => 'You cannot vote in this poll.';

  @override
  String get forumPollErrGeneric => 'The vote could not be saved. Try again.';

  @override
  String get forumPollTitle => 'Poll';

  @override
  String get forumComposeDiscardTitle => 'Discard your changes?';

  @override
  String get forumComposeDiscardConfirm => 'Discard';

  @override
  String get forumComposeDiscardKeep => 'Keep editing';

  @override
  String get forumComposeCategorySheetEmpty =>
      'There are no categories to choose from.';

  @override
  String get forumComposeEditErrGeneric =>
      'Your changes could not be saved. Try again.';

  @override
  String get forumHomeA11y => 'Campus Forum';

  @override
  String get forumHomeHint => 'Where everyone on campus talks';

  @override
  String get forumHomeSearch => 'Search the forum';

  @override
  String get forumHomeNotifications => 'Notifications';

  @override
  String get forumHomeNewTopic => 'New topic';

  @override
  String get forumHomeSortTitle => 'Sort by';

  @override
  String get forumHomeSortForYou => 'For you';

  @override
  String get forumHomeSortNewest => 'Newest';

  @override
  String get forumHomeSortPopular => 'Popular';

  @override
  String get forumHomeSortMostCommented => 'Most commented';

  @override
  String get forumHomeSortFollowing => 'Following';

  @override
  String get forumHomeCategoryAll => 'All';

  @override
  String get forumHomeCategories => 'Categories';

  @override
  String get forumHomePinned => 'Pinned';

  @override
  String get forumHomeLocked => 'Locked';

  @override
  String get forumHomePoll => 'Poll';

  @override
  String get forumHomeEdited => 'edited';

  @override
  String forumHomeCommentsA11y(String n) {
    return '$n comments';
  }

  @override
  String forumHomeLikesA11y(String n) {
    return '$n likes';
  }

  @override
  String get forumHomeOpenComments => 'Open comments';

  @override
  String get forumHomeLike => 'Like';

  @override
  String get forumHomeUnlike => 'Unlike';

  @override
  String get forumHomeSave => 'Save';

  @override
  String get forumHomeUnsave => 'Remove from saved';

  @override
  String get forumHomeShare => 'Share';

  @override
  String get forumHomeMore => 'More actions';

  @override
  String get forumHomeMenuCopyLink => 'Copy link';

  @override
  String get forumHomeMenuReport => 'Report';

  @override
  String get forumHomeMenuMute => 'Mute user';

  @override
  String get forumHomeMenuBlock => 'Block author';

  @override
  String get forumHomeBlockTitle => 'Block this author?';

  @override
  String get forumHomeBlockBody =>
      'This author\'s topics and comments will be hidden from you. If the author is anonymous, their identity stays hidden.';

  @override
  String get forumHomeBlockConfirm => 'Block';

  @override
  String get forumHomeMuteTitle => 'Mute this user?';

  @override
  String get forumHomeMuteBody =>
      'Content from this user will be hidden from you. You can undo this at any time.';

  @override
  String get forumHomeMuteConfirm => 'Mute';

  @override
  String get forumHomeBlocked => 'Author blocked';

  @override
  String get forumHomeMuted => 'User muted';

  @override
  String get forumHomeLinkCopied => 'Link copied';

  @override
  String get forumHomeLikeFailed => 'Could not save your like';

  @override
  String get forumHomeSaveFailed => 'Could not save this topic';

  @override
  String get forumHomeEmptyTitle => 'No topics yet';

  @override
  String get forumHomeEmptyBody =>
      'Start the first topic and get the campus talking.';

  @override
  String get forumHomeEmptyAction => 'Start a topic';

  @override
  String get forumHomeEmptyCategoryTitle => 'No topics in this category';

  @override
  String get forumHomeEmptyCategoryBody =>
      'Try another category or start the first topic.';

  @override
  String get forumHomeEmptyFollowingTitle => 'You are not following any topics';

  @override
  String get forumHomeEmptyFollowingBody =>
      'Follow a topic and its new comments will show up here.';

  @override
  String get forumHomeLoadMoreFailed => 'Could not load more';

  @override
  String get forumHomeStripSub => 'Where everyone on campus talks';

  @override
  String get forumHomeTalkedTitle => 'Talked about on campus';

  @override
  String get forumHomeTalkedAll => 'See all';

  @override
  String get forumStateOffline =>
      'No internet connection. Try again when you are back online.';

  @override
  String get forumStateServerError =>
      'The server is unavailable right now. Try again in a moment.';

  @override
  String get forumStateSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get forumStateNotFound =>
      'This content could not be found or has been removed.';

  @override
  String get forumStateTopicRemoved => 'This topic has been removed.';

  @override
  String get forumStateCommentRemoved => 'This comment has been removed.';

  @override
  String get forumStateCommentDeleted => 'This comment was deleted.';

  @override
  String get forumStateLocked => 'Comments are closed on this topic.';

  @override
  String get forumStateNotOwner => 'You are not allowed to do this.';

  @override
  String get forumStateRateLimited =>
      'You are going too fast. Wait a moment and try again.';

  @override
  String get forumStateDuplicate => 'You posted the same content a moment ago.';

  @override
  String get forumStateProfanity =>
      'The text contains inappropriate language. Edit it and try again.';

  @override
  String get forumStatePollClosed => 'This poll has ended.';

  @override
  String get forumStateAlreadyVoted => 'You have already voted in this poll.';

  @override
  String get forumStateEmptyContent => 'Empty content cannot be posted.';

  @override
  String get forumStateNoAccess => 'You cannot access this content.';

  @override
  String get forumStateGeneric => 'Something went wrong. Please try again.';

  @override
  String get forumHomeMenuSaved => 'Saved topics';

  @override
  String get forumHomeMenuActivity => 'My forum activity';

  @override
  String get forumHomeMenuPrefs => 'Forum notification settings';

  @override
  String get notif2SocialSection => 'Social activity';

  @override
  String get notif2LikeSub => 'When someone likes your post';

  @override
  String get notif2CommentSub => 'When someone comments on your post';

  @override
  String get notif2ReplySub => 'When someone replies to your comment';

  @override
  String get notif2MentionSub => 'When you are mentioned in a post';

  @override
  String get notif2FollowSub => 'When someone starts following you';

  @override
  String get notif2FollowRequestTitle => 'Follow requests';

  @override
  String get notif2FollowRequestSub => 'When someone requests to follow you';

  @override
  String get notif2FollowAcceptedTitle => 'Accepted requests';

  @override
  String get notif2FollowAcceptedSub => 'When your follow request is accepted';

  @override
  String get notif2AcademicTitle => 'Academic announcements';

  @override
  String get notif2AcademicSub => 'Exam reminders and academic announcements';

  @override
  String get notif2AcademicNeedsAnnouncements =>
      'Academic notifications are not sent while Announcements is off';

  @override
  String get notif2PreviewSection => 'Preview';

  @override
  String get notif2HidePreviewTitle => 'Hide message content';

  @override
  String get notif2HidePreviewSub =>
      'When on, notifications say New message instead of the text, and nothing is shown on the lock screen.';

  @override
  String get notif2SystemSection => 'System and security';

  @override
  String get notif2SystemSettingsTitle => 'System notification settings';

  @override
  String get notif2SystemSettingsSub =>
      'Sound, vibration and notification categories are managed in device settings.';

  @override
  String get notif2SecurityNote =>
      'Account security, session and moderation notices are always delivered, regardless of these settings.';

  @override
  String get devTitle => 'My devices';

  @override
  String get devIntro =>
      'Devices signed in to your account. If you see one you do not recognise, sign it out and change your password.';

  @override
  String get devSection => 'Active sessions';

  @override
  String get devThisDevice => 'This device';

  @override
  String devLastUsed(String when) {
    return 'Last used: $when';
  }

  @override
  String get devNameAndroid => 'Android device';

  @override
  String get devNameIos => 'iPhone';

  @override
  String get devNameWeb => 'Web browser';

  @override
  String get devNameUnknown => 'Unknown device';

  @override
  String get devSignOut => 'Sign out';

  @override
  String get devSignOutTitle => 'Sign out of this device?';

  @override
  String devSignOutBody(String device) {
    return 'The session on $device will be closed. You will need to sign in again to use it.';
  }

  @override
  String get devSignOutThisBody =>
      'The session on this device will be closed and you will return to the sign-in screen.';

  @override
  String devSignedOut(String device) {
    return 'Signed out of $device.';
  }

  @override
  String get devGone => 'This session is already closed.';

  @override
  String get devEmpty => 'There are no active sessions to list.';

  @override
  String get devAllSection => 'All devices';

  @override
  String get devAllHint =>
      'Sessions on every device, including this one, will be closed.';

  @override
  String get devPlatformAndroid => 'Android';

  @override
  String get devPlatformIos => 'iOS';

  @override
  String get devPlatformWeb => 'Web';

  @override
  String get pwRowLabel => 'Password';

  @override
  String get pwRowSub => 'Update your password';

  @override
  String get pwpIntro => 'Enter your current password to set a new one.';

  @override
  String get pwpForgotTitle => 'Forgot your password?';

  @override
  String get pwpForgotBody =>
      'We will send a 6-digit verification code to your account email so you can set a new password.';

  @override
  String pwpForgotTo(String email) {
    return 'The code is sent to $email.';
  }

  @override
  String get pwpForgotButton => 'Send verification code';

  @override
  String get pwpExpired => 'Verification expired. Request a new code.';

  @override
  String get pwpDoneTitle => 'Your password is updated';

  @override
  String get pwpDoneBody =>
      'For your security, all sessions on every device, including this one, were signed out. Log in again with your new password.';

  @override
  String get cplLockTitle => 'Join the club to see its polls';

  @override
  String get cplLockBody => 'Club polls are open to members only.';

  @override
  String get cplLockBodyApproval =>
      'Club polls are open to members only. They appear here once your join request is approved.';

  @override
  String get cplPendingTitle => 'Your membership request is awaiting approval';

  @override
  String get cplPendingBody =>
      'Once approved, you will see the club polls here.';

  @override
  String get cplEmptyManagerBody =>
      'Create the first poll to hear from your members.';

  @override
  String get chcEmptyTitle => 'No clubs yet';

  @override
  String get chcEmptyBody => 'Start the first club and invite your friends.';

  @override
  String get chcLoadFailed => 'Could not load clubs.';

  @override
  String clsSortLabel(String name) {
    return 'Sort: $name';
  }

  @override
  String get clsSortTitle => 'Sort by';

  @override
  String get clsSortPopular => 'Popular';

  @override
  String get clsSortNewest => 'Newest';

  @override
  String get clsSortAz => 'A-Z';

  @override
  String clsCount(String count) {
    return '$count clubs';
  }

  @override
  String get forumCatAll => 'All categories';

  @override
  String get forumCatPickerA11y => 'Category picker';

  @override
  String get forumCatSearchHint => 'Search categories';

  @override
  String get forumCatEmptyTitle => 'No categories found';

  @override
  String forumCatEmptyBody(String q) {
    return 'No category matches “$q”. Try another word.';
  }

  @override
  String forumCatTopicCount(int count) {
    return '$count topics';
  }

  @override
  String get forumCatLoadFailed => 'Could not load categories';

  @override
  String get cplSendRequest => 'Send request';

  @override
  String get evtQrScanTitle => 'Scan QR';

  @override
  String get evtQrScanHint => 'Point the camera at the attendee QR code.';

  @override
  String evtQrScanMarked(String name) {
    return '$name checked in';
  }

  @override
  String evtQrScanAlready(String name) {
    return '$name already checked in';
  }

  @override
  String get evtQrScanClosed => 'Check-in has not opened yet or has closed.';

  @override
  String get evtAttOpenTitle => 'Check-in open';

  @override
  String get evtAttOpenSub =>
      'While open, attendees show their QR codes and you and moderators scan them.';

  @override
  String get evtAttOpenYou =>
      'Check-in is open: show your QR code at the entrance.';

  @override
  String get evtModTitle => 'Moderators';

  @override
  String get evtModSub =>
      'Pick club members and switch each permission on or off.';

  @override
  String get evtModAdd => 'Add moderator';

  @override
  String get evtModEmpty => 'No moderators yet.';

  @override
  String get evtModRemove => 'Remove moderator';

  @override
  String get evtModSearch => 'Search members';

  @override
  String get evtModOwnerNote =>
      'Closing, cancelling, opening check-in and managing moderators belong to the owner only.';

  @override
  String get evtModRole => 'Moderator';

  @override
  String get evtModNoMembers => 'No club member available to add.';

  @override
  String get evtPermTakeAttendance => 'Take attendance';

  @override
  String get evtPermTakeAttendanceSub =>
      'Scan QR codes and mark attendance by hand.';

  @override
  String get evtPermManageRequests => 'Manage join requests';

  @override
  String get evtPermManageRequestsSub => 'Approve or reject requests.';

  @override
  String get evtPermViewAttendees => 'See attendee list';

  @override
  String get evtPermViewAttendeesSub =>
      'View attendees and their check-in status.';

  @override
  String get evtPermSendAnnouncement => 'Send announcements';

  @override
  String get evtPermSendAnnouncementSub =>
      'Send event announcements to attendees.';

  @override
  String get evtPermEditInfo => 'Edit details';

  @override
  String get evtPermEditInfoSub => 'Change title, description and place.';

  @override
  String get evtPermEditSchedule => 'Edit date and time';

  @override
  String get evtPermEditScheduleSub => 'Change start and end time.';

  @override
  String get evtModManageTitle => 'Your moderator permissions';

  @override
  String get evtModManageNone => 'You have no permission for this event.';

  @override
  String get evtAttClosedNote => 'Check-in is closed right now.';

  @override
  String get evtQrOwnerClosed =>
      'Attendance is closed: attendees cannot show their QR.';

  @override
  String get evtQrOwnerOpenAction => 'Open attendance';

  @override
  String get evtQrOwnerOutside =>
      'It is outside the event hours; attendance opens by itself 30 min before the start. You can open it now if you like.';

  @override
  String get evtAtt2ToolTitle => 'Attendance tool';

  @override
  String get evtAtt2ToolSub => 'Scan QR codes, mark from the list';

  @override
  String get evtAtt2ScanQr => 'Scan QR';

  @override
  String get evtAtt2Search => 'Search attendees';

  @override
  String get evtAtt2Pending => 'Pending';

  @override
  String evtAtt2Counter(String present, String absent, String pending) {
    return '$present arrived · $absent absent · $pending pending';
  }

  @override
  String get evtAtt2MarkPresent => 'Arrived';

  @override
  String get evtAtt2MarkAbsent => 'Absent';

  @override
  String get evtAtt2MarkReset => 'Reset (pending)';

  @override
  String evtAtt2SheetTitle(String name) {
    return 'Attendance for $name';
  }

  @override
  String get evtAtt2BulkRest => 'Mark the rest as absent';

  @override
  String get evtAtt2BulkTitle => 'Mark the rest as absent?';

  @override
  String evtAtt2BulkBody(String count) {
    return '$count people will be marked \"Absent\". You can change each one later.';
  }

  @override
  String evtAtt2BulkDone(String count) {
    return '$count people marked absent';
  }

  @override
  String get evtAtt2SrcQr => 'QR';

  @override
  String get evtAtt2SrcManual => 'Manual';

  @override
  String evtAtt2ByScanner(String name) {
    return 'Scanned by $name';
  }

  @override
  String evtAtt2ByMarker(String name) {
    return 'Marked by $name';
  }

  @override
  String get evtAtt2ViewOnly =>
      'You can only view the list; you cannot mark attendance.';

  @override
  String get evtAtt2NoMatch => 'No attendee matches your search.';

  @override
  String get evtAtt2ListEmpty => 'No confirmed attendees yet.';

  @override
  String evtAtt2ToastAbsent(String name) {
    return '$name marked absent';
  }

  @override
  String evtAtt2ToastPresent(String name) {
    return '$name marked arrived';
  }

  @override
  String evtAtt2ToastReset(String name) {
    return '$name reset';
  }

  @override
  String get evtAtt2StaffNoQr =>
      'Staff taking attendance have no personal QR code; you scan the attendees QR codes.';

  @override
  String get evtAtt2ParticipantHint =>
      'Show this code to the staff member taking attendance. Nothing else is needed.';

  @override
  String get evtAtt2StatusArrived => 'You are checked in';

  @override
  String get evtMeetLabel => 'Meeting point';

  @override
  String get evtMeetHint =>
      'E.g. In front of the Engineering Faculty, main entrance';

  @override
  String get evtMeetHelp =>
      'Where attendees will gather (separate from the event venue).';

  @override
  String get evtMeetOpenMap => 'Open in maps';

  @override
  String get evtMeetMapFail => 'Could not open the map.';

  @override
  String get evtMeetLat => 'Latitude (optional)';

  @override
  String get evtMeetLng => 'Longitude (optional)';

  @override
  String get evtMeetCoordInvalid =>
      'Latitude must be -90 to 90 and longitude -180 to 180, entered together.';

  @override
  String get evtEditEndedNote =>
      'This event has ended: only the description can be edited.';

  @override
  String get unitNewsTitle => 'My department';

  @override
  String get unitNewsSemantic => 'Announcements for my department';

  @override
  String get unitNewsAttachments => 'Attachments';

  @override
  String get unitNewsError => 'Could not load the announcement.';

  @override
  String get qa1DelReauthBody =>
      'Your account was created with Google or Apple, so it has no password. Confirm your identity with the linked account to delete it. This cannot be undone.';

  @override
  String get qa1DelReauthAction => 'Verify identity and delete account';

  @override
  String get qa1NoPasswordNote =>
      'Your account was created with Google or Apple, so it has no password. You can set one with a code sent to your e-mail, then also sign in with e-mail and password.';

  @override
  String get qa1PwSetButton => 'Set a password';

  @override
  String get qa1TfNeedPassword =>
      'Turning off two-step verification needs a password. Your account has none: first set one on the Password screen with the code sent to your e-mail.';

  @override
  String get qa1TfDisableReauthBody =>
      'Your account has no password, so confirm with Google or Apple. All trusted devices are removed.';

  @override
  String get widgetsRowTitle => 'Home screen widgets';

  @override
  String get widgetsInfoTitle => 'Home screen widgets';

  @override
  String get widgetsIntro =>
      'See meals, classes, events, announcements, the poll and your social summary on the home screen without opening the app.';

  @override
  String get widgetsListTitle => 'Available widgets';

  @override
  String get widgetsList =>
      'Meal menu, Timetable, Upcoming events, Campus announcements, Today\'s poll, Quick access and Social summary.';

  @override
  String get widgetsIosTitle => 'iPhone';

  @override
  String get widgetsIosSteps =>
      'Touch and hold an empty spot on the home screen, tap the + button at the top left, choose BU Campus and add the widget you want.';

  @override
  String get widgetsAndroidTitle => 'Android';

  @override
  String get widgetsAndroidSteps =>
      'Touch and hold an empty spot on the home screen, tap Widgets, find BU Campus and drag the widget you want onto the home screen.';

  @override
  String get widgetsRefreshTitle => 'Updates';

  @override
  String get widgetsRefresh =>
      'Information refreshes when you open the app, when something changes and at regular intervals. Tapping a widget opens the related screen.';

  @override
  String get widgetsPrivacyTitle => 'Privacy';

  @override
  String get widgetsPrivacy =>
      'Widgets never show other users\' names, messages or photos; the social summary shows counts only. When you sign out, widget data is deleted and widgets return to the Sign in state.';

  @override
  String get chatLongShowMore => 'Read more';

  @override
  String get chatLongShowLess => 'Show less';

  @override
  String get evtLiveCheckedInTitle => 'Scanned';

  @override
  String get evtLiveCheckedInBody => 'Your attendance is recorded.';

  @override
  String evtLiveCheckedInAt(String time) {
    return 'At $time';
  }

  @override
  String evtLiveLastScanned(String name) {
    return 'Last scanned: $name';
  }

  @override
  String evtLiveScanCount(String name) {
    return '$name was scanned';
  }

  @override
  String get settingsFindContacts => 'Find people from contacts';

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
      'None of your contacts use the app yet. Your friends will appear here as they join.';

  @override
  String get chatMiscContactsSearchHint => 'Search contacts';

  @override
  String get chatMiscContactsTruncated =>
      'Hourly request limit reached; the remaining contacts will be matched later.';

  @override
  String get qa4ContactsConsentTitle => 'Findable from contacts';

  @override
  String get qa4ContactsConsentText =>
      'Turn this setting on before finding people from your contacts. Matching is mutual: you only find people who also turned it on, and they can only find you while it is on. You can turn it off any time.';

  @override
  String get qa4ContactsConsentAction => 'Turn on and continue';

  @override
  String get qa4ContactsConsentOff => 'Turn off findability from contacts';

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
  String get permContactsTitle => 'Contacts';

  @override
  String get permContactsText =>
      'Needed to find Bingöl University people in your contacts and start chats. Your contacts are not sent to the server.';

  @override
  String get sistemuiPermContactsText =>
      'To find university contacts in your address book and start chats. Your contacts are never sent to the server.';

  @override
  String get p23PrivacyShort => 'Your contacts are not sent to the server.';

  @override
  String get p23NoneText => 'None of your contacts use the app.';

  @override
  String get liveTrackStart => 'Track live';

  @override
  String get liveTrackStop => 'Stop live tracking';

  @override
  String get liveTrackStarted => 'Live tracking started';

  @override
  String get liveTrackFailed => 'Could not start live tracking';

  @override
  String get liveTrackDisabled =>
      'Live Activities are turned off. You can enable them in Settings.';

  @override
  String get liveLabelStartsIn => 'Starts in';

  @override
  String get liveLabelEndsIn => 'Ends in';

  @override
  String get liveChannelName => 'Live updates';

  @override
  String get hubSumClubs => 'Clubs';

  @override
  String get hubSumEvents => 'Upcoming events';

  @override
  String get hubSumPending => 'Pending requests';

  @override
  String get hubSumManaged => 'Managed';

  @override
  String get hubPanel => 'Management panel';

  @override
  String get hubViewEvents => 'View events';

  @override
  String get hubUpcomingHead => 'My upcoming events';

  @override
  String get hubManageTitle => 'Club management';

  @override
  String get hubStatMembers => 'Total members';

  @override
  String get hubActEvents => 'Manage events';

  @override
  String get hubActEventsSub => 'Edit, manage attendees and check-in';

  @override
  String get hubActAnnounce => 'Post an announcement';

  @override
  String get hubActPosts => 'Manage club posts';

  @override
  String get hubActRoles => 'Manage admin permissions';

  @override
  String get hubSwitchClub => 'Switch club';

  @override
  String get hubNoAccess => 'You have no management access in this club.';

  @override
  String get hubSubPlanned => 'Going';

  @override
  String get hubSubRequests => 'My requests';

  @override
  String get hubNoRequests => 'You have no pending requests.';

  @override
  String get hubNoPast => 'You have no past events.';

  @override
  String get profileClubHub => 'Clubs and events';

  @override
  String get hubOpenManage => 'Manage my club';

  @override
  String get shareUnavailablePost =>
      'This post is unavailable. It may belong to a private account.';

  @override
  String postPhotoOfTotal(String n, String total) {
    return 'Photo $n/$total';
  }

  @override
  String get postMultiBadgeLabel => 'Multi-photo post';

  @override
  String composePhotoCount(String n, String max) {
    return '$n/$max photos';
  }

  @override
  String get composeAddPhotos => 'Add photos';

  @override
  String get composeAddPhotosShort => 'Add';

  @override
  String get composeRemovePhoto => 'Remove photo';

  @override
  String get composeReorderHint => 'Press and drag to reorder';

  @override
  String composeUploadingN(String n, String total) {
    return 'Uploading $n/$total';
  }

  @override
  String get postComposeErrMediaLimit => 'A post can have at most 10 photos.';

  @override
  String get postComposeErrMediaMix =>
      'A video post must stand alone; it cannot be mixed with photos.';

  @override
  String get evCalRow => 'Add to calendar and remind me';

  @override
  String get evCalRowDone => 'In calendar · reminder on';

  @override
  String get evCalSheetTitle => 'Add to calendar';

  @override
  String get evCalBody =>
      'The event is added to your device calendar and your calendar app sends the reminder. Only BÜ Kampüs events are added or removed.';

  @override
  String get evCalPromptBody =>
      'You are in. Add the event to your calendar and remind you? Suggested: 1 hour before.';

  @override
  String get evCalRemind => 'Reminder';

  @override
  String get evCalLead15 => '15 minutes before';

  @override
  String get evCalLead60 => '1 hour before';

  @override
  String get evCalLead1440 => '1 day before';

  @override
  String get evCalAdd => 'Add to calendar';

  @override
  String get evCalUpdate => 'Update';

  @override
  String get evCalRemove => 'Remove from calendar';

  @override
  String get evCalLater => 'Not now';

  @override
  String get evCalNever => 'Do not ask again';

  @override
  String get evCalAdded => 'Event added to calendar';

  @override
  String get evCalUpdated => 'Calendar entry updated';

  @override
  String get evCalRemoved => 'Removed from calendar';

  @override
  String get evCalFailed => 'Could not write to the calendar.';

  @override
  String get evCalPast => 'A started event cannot be added.';

  @override
  String clubShareMsg(String name, String link) {
    return 'Check out $name on BÜ Kampüs: $link';
  }

  @override
  String offlineStripWithTime(String zaman) {
    return 'Offline · last updated $zaman';
  }

  @override
  String get offlineStripNoTime => 'Offline · showing saved data';

  @override
  String get menuRemTitle => 'Daily menu reminder';

  @override
  String get menuRemSub =>
      'Reminds you of the menu at the time you choose each day';

  @override
  String get menuRemTime => 'Reminder time';

  @override
  String get menuRemNotifTitle => 'Menu for today';

  @override
  String get menuRemNotifBody => 'Take a look at the dining hall menu.';

  @override
  String get menuRemPermNeeded =>
      'Notification permission is needed for the reminder.';

  @override
  String get searchForum => 'Forum';

  @override
  String get icerikGroupForum => 'FORUM';

  @override
  String get searchSuggestionsLabel => 'Search suggestions';

  @override
  String searchForumLikes(String n) {
    return '$n likes';
  }

  @override
  String get svTitle => 'Saved';

  @override
  String get svFilterAll => 'All';

  @override
  String get svFilterNews => 'News';

  @override
  String get svFilterEvents => 'Events';

  @override
  String get svFilterClubs => 'Clubs';

  @override
  String get svFilterPolls => 'Polls';

  @override
  String get svFilterPosts => 'Posts';

  @override
  String get svFilterForum => 'Forum';

  @override
  String get svEmptyTitle => 'Nothing saved yet';

  @override
  String get svEmptyBody =>
      'Use the bookmark icon on news, events, clubs, polls, posts and forum topics to save them.';

  @override
  String get svEmptyFilterTitle => 'Nothing saved of this type';

  @override
  String get svEmptyFilterBody =>
      'Pick another type or save something of this type.';

  @override
  String get svErrorTitle => 'Could not load saved items';

  @override
  String get svRemoved => 'Removed from saved';

  @override
  String get svRemoveAction => 'Remove from saved';

  @override
  String get svOpenFailed => 'This content can no longer be opened';

  @override
  String get svSave => 'Save';

  @override
  String get svUnsave => 'Remove from saved';

  @override
  String get svSavedToast => 'Saved';

  @override
  String get svTypeNews => 'News';

  @override
  String get svTypeEvent => 'Event';

  @override
  String get svTypeCommunity => 'Club';

  @override
  String get svTypePoll => 'Poll';

  @override
  String get svTypeAcademic => 'Academic';

  @override
  String get svTypePost => 'Post';

  @override
  String get svTypeTopic => 'Forum topic';

  @override
  String get svTypeComment => 'Forum comment';

  @override
  String get svMenuRow => 'Saved';

  @override
  String get muteAction => 'Mute notifications';

  @override
  String get muteActionOff => 'Unmute notifications';

  @override
  String get muteOnToast => 'Notifications muted';

  @override
  String get muteOffToast => 'Notifications turned on';

  @override
  String get muteCriticalNote =>
      'Important notifications such as cancellations, approvals, role and attendance changes still arrive even when muted.';

  @override
  String get mutedRowTitle => 'Muted';

  @override
  String get mutedRowSub => 'Clubs and events you muted';

  @override
  String get mutedClubs => 'Clubs';

  @override
  String get mutedEvents => 'Events';

  @override
  String get mutedEmptyTitle => 'You have not muted anything';

  @override
  String get mutedEmptyBody =>
      'Use the menu on a club or event page to mute its notifications.';

  @override
  String get mutedErrorTitle => 'Could not load the list';

  @override
  String get mutedUnmute => 'Unmute';

  @override
  String mutedClubFallback(String id) {
    return 'Club $id';
  }

  @override
  String mutedEventFallback(String id) {
    return 'Event $id';
  }

  @override
  String get reportsMineTitle => 'My reports';

  @override
  String get reportsMineSub => 'Status of the reports you sent';

  @override
  String get reportsMineNote => 'For privacy only the general status is shown.';

  @override
  String get reportsStatusOpen => 'Open';

  @override
  String get reportsStatusResolved => 'Resolved';

  @override
  String get reportsEmptyTitle => 'You have not reported anything';

  @override
  String get reportsEmptyBody =>
      'When you report content, its general status appears here.';

  @override
  String get reportsErrorTitle => 'Could not load reports';

  @override
  String reportsResolvedOn(String date) {
    return 'Resolved: $date';
  }

  @override
  String get reportsTypeUser => 'User';

  @override
  String get reportsTypeMessage => 'Message';

  @override
  String get reportsTypePost => 'Post';

  @override
  String get reportsTypeCommunity => 'Club';

  @override
  String get reportsTypeEvent => 'Event';

  @override
  String get reportsTypeTopic => 'Forum topic';

  @override
  String get reportsTypeComment => 'Forum comment';

  @override
  String get reportsTypeOther => 'Content';

  @override
  String get reportsReasonPersonalInfo => 'Sharing personal information';

  @override
  String get chatSeenAgoNow => 'just now';

  @override
  String chatSeenAgoMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n months ago',
      one: '1 month ago',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n years ago',
      one: '1 year ago',
    );
    return '$_temp0';
  }

  @override
  String chatStatusSentAt(String when) {
    return 'Sent · $when';
  }

  @override
  String chatStatusSeenAt(String when) {
    return 'Seen · $when';
  }

  @override
  String get pcmWriteHint => 'Add a comment…';

  @override
  String get pcmEmptyTitle => 'Be the first to comment';

  @override
  String get pcmEmptyBody => 'Share your thoughts and start the conversation.';

  @override
  String pcmReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get pcmHideReplies => 'Hide replies';

  @override
  String get pcmSendFailed => 'Couldn\'t send';

  @override
  String get pcmRetry => 'Try again';

  @override
  String get pcmSending => 'Sending…';

  @override
  String get pcmDeleted => 'This comment was deleted';

  @override
  String get pcmMenuDelete => 'Delete';

  @override
  String get pcmMenuReport => 'Report';

  @override
  String get pcmMenuCopy => 'Copy text';

  @override
  String get pcmCopied => 'Copied';

  @override
  String get pcmMoreActions => 'Comment options';

  @override
  String get pcmLikeA11y => 'Like comment';

  @override
  String get pcmUnlikeA11y => 'Unlike comment';

  @override
  String pcmLikeCountA11y(String count) {
    return '$count likes';
  }

  @override
  String pcmCommentCountA11y(String count) {
    return '$count comments';
  }

  @override
  String pcmViewAll(String count) {
    return 'View all $count comments';
  }

  @override
  String get pcmViewAllPlain => 'View comments';

  @override
  String get pcmErrTooLong => 'A comment can be at most 500 characters.';

  @override
  String get pcmErrPostGone => 'This post is no longer available.';

  @override
  String get pcmErrParent => 'The comment you replied to no longer exists.';

  @override
  String get pcmErrRate =>
      'You\'re commenting too fast. Try again in a moment.';

  @override
  String get pcmMoreReplies => 'More replies';

  @override
  String get pcmSortLabel => 'Sort';

  @override
  String pcmCharsLeft(String n) {
    return '$n characters left';
  }

  @override
  String get postSettingsAdvanced => 'Advanced settings';

  @override
  String get postSettingsHideLikes => 'Hide like count';

  @override
  String get postSettingsHideLikesDesc =>
      'Others can\'t see this post\'s like count. You still can.';

  @override
  String get postSettingsCommentsOff => 'Turn off commenting';

  @override
  String get postSettingsCommentsOffDesc =>
      'No one can comment on this post. Existing comments stay visible.';

  @override
  String get postHideLikesHint => 'Like count is hidden from others';

  @override
  String get pcmCommentsDisabled => 'Comments are turned off for this post';

  @override
  String get postMenuHideLikes => 'Hide like count';

  @override
  String get postMenuShowLikes => 'Show like count';

  @override
  String get postMenuCommentsOff => 'Turn off comments';

  @override
  String get postMenuCommentsOn => 'Turn on comments';

  @override
  String get postSettingsLikesHiddenDone => 'Like count hidden';

  @override
  String get postSettingsLikesShownDone => 'Like count shown';

  @override
  String get postSettingsCommentsOffDone => 'Comments turned off';

  @override
  String get postSettingsCommentsOnDone => 'Comments turned on';

  @override
  String get postSettingsFailed => 'Couldn\'t change the setting. Try again.';

  @override
  String get pcmDeleteOthersTitle => 'Delete this comment?';

  @override
  String get pcmDeleteOthersBody =>
      'This comment will be removed for everyone. This can\'t be undone.';

  @override
  String get accTitle => 'Accounts';

  @override
  String get accSwitch => 'Switch account';

  @override
  String get accAdd => 'Add account';

  @override
  String get accActive => 'Current account';

  @override
  String get accExpired => 'Session expired';

  @override
  String get accOptions => 'Account options';

  @override
  String get accRemove => 'Remove from this device';

  @override
  String get accRemoveTitle => 'Remove this account?';

  @override
  String accRemoveBody(String name) {
    return 'You will be signed out of $name on this device. The account is not deleted; you can sign in again any time.';
  }

  @override
  String get accRemoveConfirm => 'Remove';

  @override
  String get accLimit => 'You can add up to 5 accounts on this device.';

  @override
  String get accPushNote =>
      'Notifications are delivered to the current account only.';

  @override
  String accSwitchedTo(String name) {
    return 'Switched to $name';
  }

  @override
  String accExpiredSwitched(String name) {
    return 'The session for $name ended. Switched to another account.';
  }

  @override
  String get accExpiredSwitchedAnon =>
      'Your session ended. Switched to another account.';

  @override
  String get accSignOutAll => 'Log out of all accounts';

  @override
  String accSignOutAllBody(String count) {
    return 'You will be logged out of all $count accounts on this device.';
  }

  @override
  String get accAddSub =>
      'Log in with another account or create a new one. Your current account stays signed in.';

  @override
  String accReloginHint(String mail) {
    return 'Session expired. Log in again: $mail';
  }

  @override
  String get accBusy => 'Cannot switch accounts right now. Try again shortly.';

  @override
  String get accAccountNoName => 'Account';

  @override
  String get postPeekOpen => 'Open post';

  @override
  String get homeTodayPeekOpen => 'Open';

  @override
  String get homeTodayPeekHint => 'open preview';

  @override
  String get homeTodayPeekTime => 'Time';

  @override
  String get homeTodayPeekRoom => 'Place';

  @override
  String get homeTodayPeekInstructor => 'Instructor';

  @override
  String get deptChatTag => 'Department';

  @override
  String deptChatJoinRow(String name) {
    return 'Join the department group: $name';
  }

  @override
  String get clubAudienceLabel => 'Suggest to departments';

  @override
  String get clubAudienceHint => 'None selected (optional)';

  @override
  String get clubAudienceSheetTitle => 'Who should see this club suggested?';

  @override
  String get clubAudienceSheetHint =>
      'Only affects suggestions; the club stays visible to everyone.';

  @override
  String get clubAudienceSearchHint => 'Search faculty or department';

  @override
  String get clubAudienceNoMatch => 'No matching faculty or department';

  @override
  String get clubAudienceRetry => 'Try again';

  @override
  String get clubAudienceClear => 'Clear';

  @override
  String get clubAudienceExpand => 'Show departments';

  @override
  String get clubAudienceCollapse => 'Hide departments';

  @override
  String clubAudienceDeptCount(int count) {
    return '$count departments';
  }

  @override
  String clubAudienceSelected(int count) {
    return '$count targets selected';
  }

  @override
  String clubAudienceDone(int count) {
    return 'Done ($count)';
  }

  @override
  String get clubRecommendedTitle => 'Clubs for your department';

  @override
  String get clubRecommendedAll => 'All clubs';

  @override
  String get eventRecommendedTitle => 'Events for your department';

  @override
  String get deptChatFilterDepartments => 'Departments';

  @override
  String get deptChatBrowse => 'Explore department chats';

  @override
  String get deptChatBrowseSubtitle =>
      'Find a department, join its chat or leave anytime.';

  @override
  String get deptChatSearch => 'Search departments';

  @override
  String get clubReviewRequiredTitle => 'Admin approval required';

  @override
  String get clubReviewRequiredBody =>
      'Your club will wait for review after creation. Only you can see it until approval. We will notify you when it is approved.';

  @override
  String get coreErrServiceUnavailable =>
      'This action cannot be completed right now. Please try again later.';

  @override
  String get chatMiscMoreAction => 'More';

  @override
  String get chatMiscPeekOpen => 'Open chat';

  @override
  String get chatMiscPeekError => 'Could not load messages.';

  @override
  String get chatMiscPeekEmpty => 'No messages yet.';

  @override
  String get pushForeignSwitched =>
      'This notification belonged to another of your accounts; switched to it.';

  @override
  String get pushForeignMissing =>
      'This notification belongs to another account that is not saved on this device.';

  @override
  String get pushForeignExpired =>
      'This notification belongs to an account whose session ended. It opens after you log in to it.';

  @override
  String get pushContentGone => 'This content is no longer available.';

  @override
  String get sessionEndedFormClosed =>
      'Your session ended, so the open page was closed. What you typed was not saved.';

  @override
  String get formDiscardTitle => 'Discard what you wrote?';

  @override
  String get formDiscardBody =>
      'If you leave, the information you entered will be lost.';

  @override
  String get formDiscardConfirm => 'Discard and leave';

  @override
  String get formDiscardKeep => 'Keep editing';

  @override
  String get g4ChatJumpMissing =>
      'This message is no longer available or could not be loaded.';

  @override
  String get shareKindProfile => 'Profile';

  @override
  String get shareChatProfileShared => 'Shared a profile';

  @override
  String get shareKindClub => 'Club';

  @override
  String get shareKindPoll => 'Poll';

  @override
  String get shareChatClubShared => 'Shared a club';

  @override
  String get shareChatPollShared => 'Shared a poll';

  @override
  String get pollShareAction => 'Share poll';

  @override
  String get scanNotBu => 'This is not a BÜ Kampüs code.';

  @override
  String get scanTitle => 'Scan QR';

  @override
  String get scanHint =>
      'Align a profile, club, poll or event code in the frame.';

  @override
  String get scanCheckinNoRight =>
      'You are not allowed to scan this attendance code.';

  @override
  String scanCheckinDone(String name) {
    return 'Attendance recorded: $name';
  }

  @override
  String get signOutPendingTitle => 'Unsent messages will be deleted';

  @override
  String signOutPendingBody(String count) {
    return '$count unsent messages will be deleted. Sign out anyway?';
  }

  @override
  String get profileShareAction => 'Share profile';

  @override
  String get profileQrMyCode => 'My QR code';

  @override
  String get profileQrHint =>
      'Anyone who scans this code sees the profile in BÜ Kampüs. A phone camera can read it too.';

  @override
  String get profileQrShareImage => 'Share as image';

  @override
  String get profileQrImageFailed =>
      'Could not prepare the image. You can share the link instead.';

  @override
  String get profileQrLoadFailed =>
      'The QR code could not be prepared right now.';

  @override
  String get profileQrScan => 'Scan QR';

  @override
  String get profileQrScanTitle => 'Scan a profile QR code';

  @override
  String get profileQrScanHint =>
      'Align a BÜ Kampüs profile code inside the frame.';

  @override
  String get profileQrInvalid => 'This is not a BÜ Kampüs profile code.';

  @override
  String get profileQrOpenSettings => 'Open settings';

  @override
  String get profileQrGallery => 'Choose from gallery';

  @override
  String get profileQrGalleryNone => 'No QR code found in the image.';

  @override
  String get profileQrMyProfile =>
      'That is your own code, opening your profile.';

  @override
  String get profileQrFindMe => 'Find me on BÜ Kampüs';

  @override
  String get commentFocusMissing =>
      'This comment may no longer exist or was deleted.';

  @override
  String get chatVoiceMic => 'Record voice message';

  @override
  String get chatVoiceHold => 'Hold the microphone to record';

  @override
  String get chatVoiceSlideCancel => 'Slide to cancel';

  @override
  String get chatVoiceStopSend => 'Stop and send recording';

  @override
  String get chatVoiceCancel => 'Cancel recording';

  @override
  String get chatVoiceMessage => 'Voice message';

  @override
  String get chatVoicePlay => 'Play';

  @override
  String get chatVoicePause => 'Pause';

  @override
  String get chatVoiceInterrupted => 'Recording interrupted';

  @override
  String get chatVoiceFailed => 'Could not play the voice message';

  @override
  String get chatVoiceLimit =>
      'Voice messages can be at most 5 minutes; the recording was sent.';

  @override
  String get chatVoiceNoMic => 'Could not start the microphone';

  @override
  String chatVoiceSemantics(String duration, String state) {
    return 'Voice message, $duration, $state';
  }

  @override
  String chatVoiceRecording(String time) {
    return 'Recording $time';
  }

  @override
  String chatVoiceSpeed(String speed) {
    return 'Playback speed $speed';
  }

  @override
  String get evtTicketTitle => 'My ticket';

  @override
  String get evtTicketOpen => 'My ticket';

  @override
  String get evtTicketLoadFailed => 'Couldn\'t load the ticket.';

  @override
  String get evtTicketOffline =>
      'You are offline: showing the last seen ticket.';

  @override
  String get evtTicketOrganizer => 'Organizer';

  @override
  String get evtTicketHolder => 'Ticket holder';

  @override
  String get evtTicketPrivacyNote =>
      'This ticket is personal. Do not share it or send a screenshot to others.';

  @override
  String get evtTicketCancelled =>
      'This event was cancelled; the ticket is void.';

  @override
  String get evtTicketEnded =>
      'This event has ended; the ticket can no longer be used.';

  @override
  String get evtTicketQrUnavailable =>
      'The QR code couldn\'t be loaded right now. Try again later.';

  @override
  String get evtTicketQrNotOpen =>
      'Your QR code appears here when attendance opens.';

  @override
  String get evtTicketQrMaybeExpired =>
      'This code may have expired. It refreshes when you are back online.';
}
