// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonRetryShort => 'حاول مرة أخرى';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonLoading => 'جارٍ التحميل';

  @override
  String get commonUpdate => 'تحديث';

  @override
  String get commonOpenInStore => 'افتح في المتجر';

  @override
  String get commonSomethingWentWrong => 'حدث خطأ ما';

  @override
  String get configError =>
      'خطأ في الإعدادات: عنوان الخادم (API_BASE) غير آمن (https). أعد بناء التطبيق بالعنوان الصحيح.';

  @override
  String get exitAgainHint => 'اضغط رجوع مرة أخرى للخروج';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navDiscover => 'استكشف';

  @override
  String get navChat => 'المحادثات';

  @override
  String get navClubs => 'النوادي';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get updateRequiredTitle => 'التحديث مطلوب';

  @override
  String get updateRequiredBody =>
      'يجب تحديث التطبيق إلى أحدث إصدار لمتابعة استخدامه.';

  @override
  String get updateAvailable => 'يتوفر إصدار جديد.';

  @override
  String updateAvailableVersion(String version) {
    return 'يتوفر إصدار جديد ($version).';
  }

  @override
  String get accessBlockedTitle => 'تم حظر الوصول';

  @override
  String get accessBlockedBody =>
      'تم حظر الوصول من هذا الجهاز أو الشبكة. إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSectionAppearance => 'المظهر';

  @override
  String get settingsSectionNotifications => 'الإشعارات';

  @override
  String get settingsSectionPrivacy => 'الخصوصية والحساب';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageHint =>
      'لغة التطبيق والإشعارات والبريد الإلكتروني';

  @override
  String get languageSystem => 'النظام';

  @override
  String get pushPermission => 'إذن الإشعارات (push)';

  @override
  String get pushNotConfigured => 'لم يتم الإعداد بعد';

  @override
  String get pushOn => 'مفعّل';

  @override
  String get pushOff => 'متوقف (فعّله من إعدادات النظام)';

  @override
  String get pushNotGranted => 'لم يتم منح الإذن';

  @override
  String get pushOnToast => 'الإشعارات الفورية مفعّلة.';

  @override
  String pushStatusToast(String status) {
    return 'الإشعارات الفورية: $status';
  }

  @override
  String get settingsShowEmail => 'إظهار بريدي الإلكتروني للآخرين';

  @override
  String get settingsFindContacts => 'ابحث عن أشخاص من جهات الاتصال';

  @override
  String get settingsPrivacyData => 'الخصوصية والبيانات';

  @override
  String get settingsSupport => 'الدعم والأسئلة الشائعة';

  @override
  String get settingsLogoutAll => 'تسجيل الخروج من جميع الأجهزة';

  @override
  String get settingsLogoutAllTitle => 'تسجيل الخروج من جميع الأجهزة';

  @override
  String get settingsLogoutAllBody =>
      'سيتم تسجيل خروج حسابك من جميع الأجهزة وستحتاج إلى تسجيل الدخول مجددًا.';

  @override
  String get settingsLogoutAllConfirm => 'تسجيل الخروج';

  @override
  String settingsVersion(String version) {
    return 'BÜ Kampüs · الإصدار $version';
  }

  @override
  String get loginWelcome => 'مرحبًا بك';

  @override
  String get loginSubtitle => 'سجّل الدخول ببريدك الجامعي.';

  @override
  String get loginReplacedNotice =>
      'تم تسجيل الدخول إلى حسابك من جهاز آخر. حفاظًا على أمانك أُغلقت الجلسة على هذا الجهاز.';

  @override
  String get loginPasswordRequired => 'أدخل كلمة المرور.';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور';

  @override
  String get loginSubmit => 'تسجيل الدخول';

  @override
  String get loginNoAccount => 'ليس لديك حساب؟';

  @override
  String get loginRegister => 'إنشاء حساب';

  @override
  String get loginCompleteVerification => 'أكمل التحقق';

  @override
  String get authBack => 'رجوع';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get authPasswordLabel => 'كلمة المرور';

  @override
  String get authIdHint => 'بريدك الجامعي';

  @override
  String get authVerify => 'تحقق';

  @override
  String get authResendCode => 'إعادة إرسال الرمز';

  @override
  String authResendIn(String seconds) {
    return 'إعادة الإرسال ($seconds ث)';
  }

  @override
  String authNewCodeIn(String seconds) {
    return 'انتظر $seconds ث للحصول على رمز جديد';
  }

  @override
  String get authCodeSent => 'تم إرسال الرمز.';

  @override
  String get authNewCodeSent => 'تم إرسال رمز جديد.';

  @override
  String get authEnterCode => 'أدخل الرمز';

  @override
  String authCodeSentTo(String email) {
    return 'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى $email.';
  }

  @override
  String get authVerifyEmailTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String authVerifySubtitle(String email) {
    return 'تم إرسال رمز إلى $email. صالح لمدة 10 دقائق.';
  }

  @override
  String get authUnverifiedNotice =>
      'تحقق من بريدك الإلكتروني. يجب توثيق حسابك لتتمكن من تسجيل الدخول.';

  @override
  String get authUseOtherAccount => 'سجّل الدخول بحساب آخر';

  @override
  String get authResetTitle => 'هل نسيت كلمة المرور؟';

  @override
  String get authSendCode => 'إرسال الرمز';

  @override
  String get authNewPasswordTitle => 'عيّن كلمة مرور جديدة';

  @override
  String get authNewPasswordLabel => 'كلمة مرور جديدة';

  @override
  String get authUpdatePassword => 'تحديث كلمة المرور';

  @override
  String get authPasswordUpdated => 'تم تحديث كلمة المرور.';

  @override
  String get authSessionExpired => 'انتهت المهلة. ابدأ من جديد.';

  @override
  String get authCreateAccount => 'إنشاء حساب';

  @override
  String get authSelectDepartment => 'اختر قسمك.';

  @override
  String get authSelectGrade => 'اختر سنتك الدراسية.';

  @override
  String get authDepartmentsLoadFailed =>
      'تعذّر تحميل قائمة الأقسام. حاول مرة أخرى.';

  @override
  String get authNameRequired => 'أدخل اسمك الكامل.';

  @override
  String get authNameHint => 'الاسم الكامل';

  @override
  String get authPasswordMin8 => 'كلمة المرور (8 أحرف على الأقل)';

  @override
  String get authTermsPrefix => 'أوافق على ';

  @override
  String get authTermsLink => 'شروط الاستخدام';

  @override
  String get authTermsSep => ' و';

  @override
  String get authPrivacyLink => 'سياسة الخصوصية';

  @override
  String get authTermsSuffix => '';

  @override
  String get authMustAccept => 'يجب الموافقة للمتابعة.';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get authRegisterSubtitle => 'انضم إلى الحرم الجامعي في بضع خطوات.';

  @override
  String get authSectionAcademic => 'المعلومات الأكاديمية';

  @override
  String get authSectionAccount => 'معلومات الحساب';

  @override
  String get authPwWeak => 'ضعيفة';

  @override
  String get authPwFair => 'متوسطة';

  @override
  String get authPwStrong => 'قوية';

  @override
  String get acadMonth1 => 'يناير';

  @override
  String get acadMonth2 => 'فبراير';

  @override
  String get acadMonth3 => 'مارس';

  @override
  String get acadMonth4 => 'أبريل';

  @override
  String get acadMonth5 => 'مايو';

  @override
  String get acadMonth6 => 'يونيو';

  @override
  String get acadMonth7 => 'يوليو';

  @override
  String get acadMonth8 => 'أغسطس';

  @override
  String get acadMonth9 => 'سبتمبر';

  @override
  String get acadMonth10 => 'أكتوبر';

  @override
  String get acadMonth11 => 'نوفمبر';

  @override
  String get acadMonth12 => 'ديسمبر';

  @override
  String get acadDay1 => 'الاثنين';

  @override
  String get acadDay2 => 'الثلاثاء';

  @override
  String get acadDay3 => 'الأربعاء';

  @override
  String get acadDay4 => 'الخميس';

  @override
  String get acadDay5 => 'الجمعة';

  @override
  String get acadDay6 => 'السبت';

  @override
  String get acadDay7 => 'الأحد';

  @override
  String get acadDayShort1 => 'اث';

  @override
  String get acadDayShort2 => 'ثل';

  @override
  String get acadDayShort3 => 'أر';

  @override
  String get acadDayShort4 => 'خم';

  @override
  String get acadDayShort5 => 'جم';

  @override
  String get acadDayShort6 => 'سب';

  @override
  String get acadDayShort7 => 'أح';

  @override
  String get acadColorRed => 'أحمر';

  @override
  String get acadColorOrange => 'برتقالي';

  @override
  String get acadColorAmber => 'أصفر';

  @override
  String get acadColorGreen => 'أخضر';

  @override
  String get acadColorTeal => 'تركوازي';

  @override
  String get acadColorBlue => 'أزرق';

  @override
  String get acadColorIndigo => 'نيلي';

  @override
  String get acadColorPurple => 'بنفسجي';

  @override
  String get acadColorPink => 'وردي';

  @override
  String get acadColorGray => 'رمادي';

  @override
  String get acadExamTypeVize => 'امتحان نصفي';

  @override
  String get acadExamTypeFinal => 'امتحان نهائي';

  @override
  String get acadExamTypeBut => 'امتحان تكميلي';

  @override
  String get acadExamTypeQuiz => 'اختبار قصير';

  @override
  String get acadExamTypeOdev => 'واجب';

  @override
  String get acadExamTypeDiger => 'أخرى';

  @override
  String get acadEventKindSemesterStart => 'بداية الفصل';

  @override
  String get acadEventKindRegistration => 'تسجيل المقررات';

  @override
  String get acadEventKindHoliday => 'عطلة';

  @override
  String get acadEventKindPublicHoliday => 'عطلة رسمية';

  @override
  String acadCountdownDays(String n) {
    return 'متبقي $n يوم';
  }

  @override
  String acadCountdownHours(String n) {
    return 'متبقي $n ساعة';
  }

  @override
  String acadCountdownMinutes(String n) {
    return 'متبقي $n دقيقة';
  }

  @override
  String get acadGradePrep => 'السنة التحضيرية';

  @override
  String get acadGradeMaster => 'ماجستير';

  @override
  String get acadGradePhd => 'دكتوراه';

  @override
  String acadGradeN(String n) {
    return 'السنة $n';
  }

  @override
  String get acadSave => 'حفظ';

  @override
  String get acadDelete => 'حذف';

  @override
  String get acadCancel => 'إلغاء';

  @override
  String get acadRetry => 'إعادة المحاولة';

  @override
  String get acadSelect => 'اختيار';

  @override
  String get acadMaintenance =>
      'الخدمات الأكاديمية قيد الصيانة. يرجى المحاولة لاحقًا.';

  @override
  String get acadMyDept => 'قسمي';

  @override
  String get acadAll => 'الكل';

  @override
  String get acadHubTitle => 'الأكاديمي';

  @override
  String get acadHubReminders => 'التذكيرات';

  @override
  String get acadHubAddCourses => 'أضف مقرراتك';

  @override
  String get acadHubNoClassWeek => 'لا توجد محاضرات هذا الأسبوع';

  @override
  String acadHubNext(String course, String time) {
    return 'التالي: $course $time';
  }

  @override
  String get acadHubNoExam => 'لا توجد امتحانات قادمة';

  @override
  String acadHubExamCount(String n) {
    return 'امتحانات قادمة: $n';
  }

  @override
  String get acadHubTimetable => 'الجدول الدراسي';

  @override
  String get acadHubTimetableSub => 'جدولك الدراسي الأسبوعي';

  @override
  String get acadHubExamsSub => 'جدول امتحاناتك والبرنامج الرسمي';

  @override
  String get acadHubCalendarSub => 'تواريخ الفصل والتسجيل والامتحانات';

  @override
  String get acadHubAnnouncementsSub => 'إعلانات خاصة بقسمك';

  @override
  String acadHubUnread(String n) {
    return '$n غير مقروءة';
  }

  @override
  String get acadExamsTitle => 'الامتحانات';

  @override
  String get acadExamsAdd => 'إضافة امتحان';

  @override
  String get acadExamsTabMine => 'امتحاناتي';

  @override
  String get acadExamsTabOfficial => 'البرنامج الرسمي';

  @override
  String get acadExamsEmptyMine =>
      'لم تضف أي امتحان شخصي.\nتابع مواعيد الامتحانات النصفية والنهائية والاختبارات القصيرة من هنا.';

  @override
  String get acadExamsUpcoming => 'القادمة';

  @override
  String get acadExamsNoUpcoming => 'لا توجد امتحانات قادمة.';

  @override
  String get acadExamsPast => 'السابقة';

  @override
  String acadExamsSemantic(String type, String title, String date) {
    return '$type: $title. $date. المس للتعديل.';
  }

  @override
  String acadExamsSemanticCd(
      String type, String title, String date, String countdown) {
    return '$type: $title. $date. $countdown. المس للتعديل.';
  }

  @override
  String acadOfficialSemantic(String type, String title, String date) {
    return '$type: $title. $date';
  }

  @override
  String acadOfficialSemanticRoom(
      String type, String title, String date, String room) {
    return '$type: $title. $date، $room';
  }

  @override
  String get acadExamsProfileIncomplete =>
      'لا يوجد قسم في ملفك الشخصي؛ تُعرض الامتحانات العامة فقط. يمكنك إضافة قسمك عبر تعديل الملف الشخصي.';

  @override
  String get acadExamsEmptyOfficial => 'لم يُنشر أي برنامج امتحانات رسمي بعد.';

  @override
  String get acadFormErrTitle => 'عنوان الامتحان مطلوب.';

  @override
  String get acadFormErrDate => 'اختر تاريخ الامتحان.';

  @override
  String get acadFormErrEnd => 'يجب أن يكون وقت الانتهاء بعد وقت البدء.';

  @override
  String get acadFormDeleteTitle => 'حذف الامتحان';

  @override
  String acadFormDeleteText(String title) {
    return 'سيتم حذف \"$title\".';
  }

  @override
  String get acadFormEdit => 'تعديل الامتحان';

  @override
  String get acadFormNew => 'امتحان جديد';

  @override
  String get acadFormTitleLabel => 'العنوان';

  @override
  String get acadFormTitleHint => 'مثال: هياكل البيانات - النصفي الأول';

  @override
  String get acadFormType => 'النوع';

  @override
  String get acadFormCourseOpt => 'المقرر (اختياري)';

  @override
  String get acadFormNone => 'بدون';

  @override
  String get acadFormDateTime => 'التاريخ والوقت';

  @override
  String get acadFormExamDate => 'تاريخ الامتحان';

  @override
  String get acadFormPickDate => 'اختر التاريخ';

  @override
  String get acadFormStartTime => 'وقت البدء';

  @override
  String get acadFormEndTime => 'وقت الانتهاء';

  @override
  String get acadFormEndHint => 'الانتهاء (اختياري)';

  @override
  String get acadFormRoom => 'القاعة';

  @override
  String get acadFormRoomHint => 'مثال: B-204';

  @override
  String get acadFormNote => 'ملاحظة';

  @override
  String get acadFormNoteHint => 'اختياري';

  @override
  String get acadFormAdd => 'إضافة الامتحان';

  @override
  String get acadAnnTitle => 'إعلانات القسم';

  @override
  String get acadAnnDetailTitle => 'إعلان';

  @override
  String get acadAnnReadAll => 'تحديد الكل كمقروء';

  @override
  String get acadAnnEmptyMine =>
      'لا توجد إعلانات خاصة بقسمك.\nيمكنك رؤية كل الإعلانات من تبويب \"الكل\".';

  @override
  String get acadAnnEmptyAll => 'لا توجد إعلانات بعد.';

  @override
  String get acadAnnAudienceAll => 'الجامعة كاملة';

  @override
  String get acadAnnUnread => 'غير مقروء';

  @override
  String get acadAnnPinned => 'مثبّت';

  @override
  String get acadAnnLinkError => 'تعذر فتح الرابط.';

  @override
  String get acadAnnOpenAttachment => 'فتح المرفق';

  @override
  String get acadCalTitle => 'التقويم الأكاديمي';

  @override
  String get acadCalPrev => 'الشهر السابق';

  @override
  String get acadCalNext => 'الشهر التالي';

  @override
  String get acadCalToday => 'اليوم';

  @override
  String acadCalEventCount(String n) {
    return 'تواريخ مهمة: $n';
  }

  @override
  String acadCalMonthHeading(String month) {
    return 'التواريخ المهمة لشهر $month';
  }

  @override
  String get acadCalNoMonth => 'لا توجد تواريخ مهمة مسجلة لهذا الشهر.';

  @override
  String get acadCalNoDay => 'لا توجد تواريخ مهمة في هذا اليوم.';

  @override
  String get acadCalNextHeading => 'التواريخ المهمة القادمة';

  @override
  String get acadTimeDay1 => 'الاثنين';

  @override
  String get acadTimeDay2 => 'الثلاثاء';

  @override
  String get acadTimeDay3 => 'الأربعاء';

  @override
  String get acadTimeDay4 => 'الخميس';

  @override
  String get acadTimeDay5 => 'الجمعة';

  @override
  String get acadTimeDay6 => 'السبت';

  @override
  String get acadTimeDay7 => 'الأحد';

  @override
  String get acadTimeDayShort1 => 'اثن';

  @override
  String get acadTimeDayShort2 => 'ثلا';

  @override
  String get acadTimeDayShort3 => 'أرب';

  @override
  String get acadTimeDayShort4 => 'خمي';

  @override
  String get acadTimeDayShort5 => 'جمع';

  @override
  String get acadTimeDayShort6 => 'سبت';

  @override
  String get acadTimeDayShort7 => 'أحد';

  @override
  String get acadTimeColorRed => 'أحمر';

  @override
  String get acadTimeColorOrange => 'برتقالي';

  @override
  String get acadTimeColorAmber => 'أصفر';

  @override
  String get acadTimeColorGreen => 'أخضر';

  @override
  String get acadTimeColorTeal => 'تركوازي';

  @override
  String get acadTimeColorBlue => 'أزرق';

  @override
  String get acadTimeColorIndigo => 'نيلي';

  @override
  String get acadTimeColorPurple => 'بنفسجي';

  @override
  String get acadTimeColorPink => 'وردي';

  @override
  String get acadTimeColorGray => 'رمادي';

  @override
  String get acadTimeExamVize => 'امتحان نصفي';

  @override
  String get acadTimeExamFinal => 'امتحان نهائي';

  @override
  String get acadTimeExamBut => 'امتحان تكميلي';

  @override
  String get acadTimeExamQuiz => 'اختبار قصير';

  @override
  String get acadTimeExamOdev => 'واجب';

  @override
  String get acadTimeExamOther => 'أخرى';

  @override
  String acadTimeRemClass(String min, String time, String room) {
    return 'يبدأ بعد $min دقيقة ($time$room)';
  }

  @override
  String acadTimeRemExamLabel(String type, String title) {
    return '$type: $title';
  }

  @override
  String acadTimeRemExamTomorrow(String time, String room) {
    return 'غدًا $time$room';
  }

  @override
  String acadTimeRemExamHour(String room) {
    return 'يبدأ بعد ساعة$room';
  }

  @override
  String get acadTimeExportNone => 'لا توجد مقررات للتصدير.';

  @override
  String get acadTimeExportCopied => 'تم نسخ نص التقويم (.ics) إلى الحافظة.';

  @override
  String get acadTimeTitle => 'الجدول الدراسي';

  @override
  String get acadTimeExportTooltip => 'تصدير إلى التقويم (.ics)';

  @override
  String get acadTimeAddCourse => 'إضافة مقرر';

  @override
  String get acadTimeStale => 'تعذر التحديث، تُعرض آخر البيانات.';

  @override
  String get acadTimePickSemester => 'اختر الفصل';

  @override
  String acadTimeMyCourses(String count) {
    return 'مقرراتي ($count)';
  }

  @override
  String get acadTimeEmptyText =>
      'لم تضف أي مقرر بعد.\nأضف مقرراتك لإنشاء جدولك الأسبوعي.';

  @override
  String get acadTimeAddFirst => 'أضف أول مقرر';

  @override
  String get acadTimeNowInClass => 'في المحاضرة الآن';

  @override
  String acadTimeMinLeft(String name, String min) {
    return '$name · متبقي $min دقيقة';
  }

  @override
  String get acadTimeNextClass => 'المحاضرة التالية';

  @override
  String acadTimeWhenMin(String min) {
    return 'بعد $min دقيقة';
  }

  @override
  String acadTimeWhenHours(String h) {
    return 'بعد $h ساعة';
  }

  @override
  String acadTimeWhenHoursMin(String h, String min) {
    return 'بعد $h ساعة و$min دقيقة';
  }

  @override
  String acadTimeWhenDay(String day, String time) {
    return '$day $time';
  }

  @override
  String get acadTimeToday => 'اليوم';

  @override
  String get acadTimeNoMoreWeek => 'لا توجد محاضرات أخرى هذا الأسبوع.';

  @override
  String get acadTimeTodayNone => 'لا توجد محاضرات متبقية اليوم';

  @override
  String acadTimeTodayLeft(String count) {
    return 'المحاضرات المتبقية اليوم: $count';
  }

  @override
  String acadTimeDayToday(String day) {
    return '$day، اليوم';
  }

  @override
  String acadTimeNoClassDay(String day) {
    return 'لا توجد محاضرات يوم $day.';
  }

  @override
  String get acadTimeOutOfRange => 'هذا التاريخ خارج نطاق الفصل.';

  @override
  String get acadTimeStatusNow => 'الآن';

  @override
  String get acadTimeStatusDone => 'انتهت';

  @override
  String acadTimeSlotSemantic(
      String name, String day, String start, String end) {
    return '$name، $day من $start إلى $end';
  }

  @override
  String acadTimeCourseSemantic(String name, String days) {
    return '$name. $days. المس للتعديل.';
  }

  @override
  String get acadTimeNoSessions => 'لا توجد جلسات';

  @override
  String get acadTimeNameRequired => 'اسم المقرر مطلوب';

  @override
  String get acadTimeEndAfterStart => 'يجب أن يكون وقت الانتهاء بعد وقت البدء.';

  @override
  String get acadTimeOwnConflict => 'جلسات هذا المقرر متداخلة';

  @override
  String get acadTimeConflictTitle => 'تعارض في المواعيد';

  @override
  String acadTimeConflictText(String lines) {
    return 'تتعارض المواعيد مع هذه المقررات:\n$lines\n\nهل تريد الحفظ على أي حال؟';
  }

  @override
  String acadTimeConflictServerText(String message) {
    return '$message\n\nهل تريد الحفظ على أي حال؟';
  }

  @override
  String get acadTimeSaveAnyway => 'احفظ على أي حال';

  @override
  String get acadTimeDeleteCourse => 'حذف المقرر';

  @override
  String acadTimeDeleteCourseText(String name) {
    return 'سيتم حذف المقرر \"$name\" وجميع جلساتها.';
  }

  @override
  String get acadTimeDelete => 'حذف';

  @override
  String get acadTimeEditCourse => 'تعديل المقرر';

  @override
  String get acadTimeNewCourse => 'مقرر جديد';

  @override
  String get acadTimeCourseName => 'اسم المقرر';

  @override
  String get acadTimeNameHint => 'مثال: هياكل البيانات';

  @override
  String get acadTimeCourseCode => 'رمز المقرر';

  @override
  String get acadTimeInstructor => 'المحاضر';

  @override
  String get acadTimeInstructorHint => 'د. أحمد علي';

  @override
  String get acadTimeColor => 'اللون';

  @override
  String acadTimeColorSemantic(String color) {
    return 'اللون $color';
  }

  @override
  String get acadTimeColorAuto => 'إذا لم تختر، سيتم تعيين لون تلقائيًا.';

  @override
  String get acadTimeDaysAndTimes => 'الأيام والأوقات';

  @override
  String get acadTimeAddSession => 'إضافة يوم/وقت آخر';

  @override
  String get acadTimeNote => 'ملاحظة';

  @override
  String get acadTimeNoteHint => 'اختياري (مثال: أحضر حاسوبًا محمولًا)';

  @override
  String get acadTimeSave => 'حفظ';

  @override
  String get acadTimeAddCourseBtn => 'إضافة المقرر';

  @override
  String acadTimeSessionN(String n) {
    return 'الجلسة $n';
  }

  @override
  String get acadTimeRemoveSession => 'إزالة الجلسة';

  @override
  String get acadTimeStartTime => 'وقت البدء';

  @override
  String get acadTimeEndTime => 'وقت الانتهاء';

  @override
  String get acadTimeRoomHint => 'القاعة (مثال: B-204)';

  @override
  String get acadTimeSemester => 'الفصل';

  @override
  String get acadTimeNoSemester =>
      'لا توجد فصول بعد. أضف فصلًا لتنظيم مقرراتك.';

  @override
  String get acadTimeAddSemester => 'إضافة فصل جديد';

  @override
  String acadTimeOfficial(String name) {
    return '$name (من التقويم الأكاديمي)';
  }

  @override
  String get acadTimeOfficialDefault => 'الفصل الرسمي';

  @override
  String get acadTimeClose => 'إغلاق';

  @override
  String get acadTimeCurrent => 'الحالي';

  @override
  String get acadTimeMakeCurrent => 'تعيين كفصل حالي';

  @override
  String get acadTimeDeleteSemester => 'حذف الفصل';

  @override
  String acadTimeDeleteSemesterText(String name) {
    return 'سيتم حذف \"$name\". ستبقى المقررات بدون فصل.';
  }

  @override
  String get acadTimeNewSemester => 'فصل جديد';

  @override
  String get acadTimeSemesterHint => 'خريف 2026-2027';

  @override
  String get acadTimeStartDate => 'تاريخ البدء';

  @override
  String get acadTimeEndDate => 'تاريخ الانتهاء';

  @override
  String get acadTimeCancel => 'إلغاء';

  @override
  String get acadTimeSemesterNeedAll => 'الاسم والتاريخان مطلوبان.';

  @override
  String get acadTimeSemesterEndAfter =>
      'يجب أن يكون تاريخ الانتهاء بعد تاريخ البدء.';

  @override
  String get acadTimeAdd => 'إضافة';

  @override
  String get acadTimeRemindersTitle => 'التذكيرات';

  @override
  String get acadTimeRemindersIntro =>
      'تتم جدولة الإشعارات على جهازك دون الحاجة إلى الإنترنت. وتُحدَّث عند تغيير جدولك أو امتحاناتك.';

  @override
  String get acadTimeClassReminder => 'تذكير المحاضرة';

  @override
  String get acadTimeBeforeClass => 'قبل بدء المحاضرة';

  @override
  String get acadTimeOneHour => 'ساعة';

  @override
  String acadTimeMinutes(String m) {
    return '$m د';
  }

  @override
  String get acadTimeExamReminders => 'تذكيرات الامتحانات';

  @override
  String get acadTimeDayBefore => 'قبل يوم';

  @override
  String get acadTimeHourBefore => 'قبل ساعة';

  @override
  String get authRestEnterCode => 'أدخل الرمز المكون من 6 أرقام.';

  @override
  String get authRestCodeLabel => 'رمز التحقق المكون من 6 أرقام';

  @override
  String chatDetailVideoPreparing(String pct) {
    return 'جارٍ تجهيز الفيديو… $pct%';
  }

  @override
  String get chatDetailCancel => 'إلغاء';

  @override
  String get chatDetailUserFallback => 'مستخدم';

  @override
  String get chatDetailYou => 'أنت';

  @override
  String get chatDetailChatFallback => 'محادثة';

  @override
  String get chatDetailGroupFallback => 'مجموعة';

  @override
  String get chatDetailVideoTooLong => 'يجب ألا تتجاوز مدة الفيديو 60 ثانية';

  @override
  String get chatDetailVideoTooLarge => 'الفيديو كبير جدًا، اختر فيديو أقصر';

  @override
  String get chatDetailVideoUnsupported =>
      'لا يمكن إرسال الفيديو على هذا الجهاز.';

  @override
  String get chatDetailVideoFailed => 'تعذر تجهيز الفيديو.';

  @override
  String get chatDetailVideosSplit =>
      'الفيديوهات كبيرة، لذا ستُرسل في عدة رسائل';

  @override
  String get chatDetailImageTooLarge => 'الصورة كبيرة جدًا، اختر صورة أصغر.';

  @override
  String get chatDetailImageTypes => 'يمكن إرسال صور JPEG أو PNG أو WebP فقط.';

  @override
  String get chatDetailImageUnreadable => 'تعذرت قراءة الصورة.';

  @override
  String get chatDetailVideoUnreadable => 'تعذرت قراءة الفيديو.';

  @override
  String get chatDetailSavedToGallery => 'تم الحفظ في المعرض';

  @override
  String get chatDetailDeleteTitle => 'هل تريد حذف الرسالة؟';

  @override
  String get chatDetailDeleteBody => 'ستُحذف هذه الرسالة للجميع.';

  @override
  String get chatDetailDelete => 'حذف';

  @override
  String get chatDetailMsgDeleted => 'تم حذف هذه الرسالة';

  @override
  String get chatDetailNevermind => 'تراجع';

  @override
  String get chatDetailToday => 'اليوم';

  @override
  String get chatDetailYesterday => 'أمس';

  @override
  String get chatDetailMonth1 => 'يناير';

  @override
  String get chatDetailMonth2 => 'فبراير';

  @override
  String get chatDetailMonth3 => 'مارس';

  @override
  String get chatDetailMonth4 => 'أبريل';

  @override
  String get chatDetailMonth5 => 'مايو';

  @override
  String get chatDetailMonth6 => 'يونيو';

  @override
  String get chatDetailMonth7 => 'يوليو';

  @override
  String get chatDetailMonth8 => 'أغسطس';

  @override
  String get chatDetailMonth9 => 'سبتمبر';

  @override
  String get chatDetailMonth10 => 'أكتوبر';

  @override
  String get chatDetailMonth11 => 'نوفمبر';

  @override
  String get chatDetailMonth12 => 'ديسمبر';

  @override
  String get chatDetailOnline => 'متصل';

  @override
  String chatDetailLastSeenToday(String time) {
    return 'آخر ظهور: اليوم $time';
  }

  @override
  String chatDetailLastSeenYesterday(String time) {
    return 'آخر ظهور: أمس $time';
  }

  @override
  String chatDetailLastSeenOn(String date) {
    return 'آخر ظهور: $date';
  }

  @override
  String chatDetailClubRoomMembers(String count) {
    return 'غرفة النادي · $count عضو';
  }

  @override
  String chatDetailEventRoomMembers(String count) {
    return 'غرفة الفعالية · $count عضو';
  }

  @override
  String chatDetailMembersCount(String count) {
    return '$count عضو';
  }

  @override
  String get chatDetailClubEventRoom => 'غرفة النادي/الفعالية';

  @override
  String get chatDetailResend => 'إعادة الإرسال';

  @override
  String get chatDetailReply => 'رد';

  @override
  String get chatDetailCopy => 'نسخ';

  @override
  String get chatDetailForward => 'إعادة توجيه';

  @override
  String get chatDetailEdit => 'تعديل';

  @override
  String get chatDetailDeleteForAll => 'حذف للجميع';

  @override
  String get chatDetailDeleteMessage => 'حذف الرسالة';

  @override
  String get chatDetailReport => 'إبلاغ';

  @override
  String get chatDetailCopied => 'تم النسخ';

  @override
  String get chatDetailForwarded => 'تمت إعادة التوجيه';

  @override
  String get chatDetailForwardFailedAll => 'تعذرت إعادة التوجيه';

  @override
  String chatDetailForwardFailedSome(String count) {
    return 'تعذرت إعادة التوجيه إلى $count من المحادثات';
  }

  @override
  String get chatDetailSearchInChat => 'البحث في المحادثة';

  @override
  String get chatDetailClubPage => 'صفحة النادي';

  @override
  String get chatDetailEventPage => 'صفحة الفعالية';

  @override
  String get chatDetailMembers => 'الأعضاء';

  @override
  String get chatDetailMedia => 'الوسائط';

  @override
  String get chatDetailSettings => 'الإعدادات';

  @override
  String get chatDetailLeaveChat => 'مغادرة المحادثة';

  @override
  String get chatDetailBlock => 'حظر';

  @override
  String get chatDetailUnblock => 'إلغاء الحظر';

  @override
  String get chatDetailReportUser => 'الإبلاغ عن المستخدم';

  @override
  String get chatDetailLeaveTitle => 'هل تريد مغادرة المحادثة؟';

  @override
  String get chatDetailLeaveBody => 'ستغادر هذه المحادثة.';

  @override
  String get chatDetailLeave => 'مغادرة';

  @override
  String get chatDetailBlockTitle => 'هل تريد حظر المستخدم؟';

  @override
  String get chatDetailBlockBody => 'لا يمكنك مراسلة شخص قمت بحظره.';

  @override
  String get chatDetailUserBlocked => 'تم حظر المستخدم';

  @override
  String get chatDetailUserUnblocked => 'تم إلغاء الحظر';

  @override
  String chatDetailMembersTitle(String count) {
    return 'الأعضاء ($count)';
  }

  @override
  String get chatDetailMembersLoadFailed => 'تعذر تحميل قائمة الأعضاء.';

  @override
  String get chatDetailAdmin => 'مدير';

  @override
  String get chatDetailBack => 'رجوع';

  @override
  String get chatDetailOpenProfile => 'فتح الملف الشخصي';

  @override
  String get chatDetailChatInfo => 'معلومات المحادثة';

  @override
  String get chatDetailTyping => 'يكتب…';

  @override
  String get chatDetailMenu => 'القائمة';

  @override
  String get chatDetailCloseSearch => 'إغلاق البحث';

  @override
  String get chatDetailTypeToSearch => 'اكتب للبحث';

  @override
  String get chatDetailNoMatch => 'لا توجد نتائج';

  @override
  String get chatDetailPrevMatch => 'النتيجة السابقة';

  @override
  String get chatDetailNextMatch => 'النتيجة التالية';

  @override
  String get chatDetailSearching => 'جارٍ البحث…';

  @override
  String get chatDetailSearchOlder => 'البحث في الرسائل الأقدم';

  @override
  String get chatDetailEmpty => 'لا توجد رسائل بعد. اكتب أول رسالة.';

  @override
  String get chatDetailScrollDown => 'الانتقال إلى الأسفل';

  @override
  String chatDetailScrollDownNew(String count) {
    return 'الانتقال إلى الأسفل، $count من الرسائل الجديدة';
  }

  @override
  String get chatDetailEditing => 'تعديل الرسالة';

  @override
  String get chatDetailAdd => 'إضافة';

  @override
  String get chatDetailWriteMessage => 'اكتب رسالة';

  @override
  String get chatDetailCamera => 'الكاميرا';

  @override
  String get chatDetailSave => 'حفظ';

  @override
  String get chatDetailSend => 'إرسال';

  @override
  String get chatDetailClose => 'إغلاق';

  @override
  String chatDetailReactionLabel(String emoji) {
    return 'تفاعل $emoji';
  }

  @override
  String get chatInfoUnmute => 'إلغاء الكتم';

  @override
  String get chatInfoMute => 'كتم';

  @override
  String get chatInfoUnarchive => 'إلغاء الأرشفة';

  @override
  String get chatInfoArchive => 'أرشفة';

  @override
  String get chatInfoDelete => 'حذف';

  @override
  String get chatInfoCancel => 'إلغاء';

  @override
  String get chatInfoSave => 'حفظ';

  @override
  String get chatInfoMute8h => '8 ساعات';

  @override
  String get chatInfoMute1w => 'أسبوع واحد';

  @override
  String get chatInfoMuteForever => 'دائمًا';

  @override
  String get chatInfoDeleteConvTitle => 'هل تريد حذف المحادثة؟';

  @override
  String get chatInfoDeleteConvGroup => 'ستغادر المجموعة وتحذف هذه المحادثة.';

  @override
  String get chatInfoDeleteConvDirect =>
      'ستُحذف هذه المحادثة لديك فقط ولن يتأثر الطرف الآخر.';

  @override
  String get chatInfoUser => 'مستخدم';

  @override
  String get chatInfoYou => 'أنت';

  @override
  String get chatInfoAdmin => 'مدير';

  @override
  String get chatInfoRemoveFromGroup => 'إزالة من المجموعة';

  @override
  String chatInfoMembersCount(String n) {
    return 'الأعضاء ($n)';
  }

  @override
  String get chatInfoSearchMember => 'ابحث عن عضو';

  @override
  String get chatInfoNoResults => 'لا توجد نتائج.';

  @override
  String get chatInfoOpenVideo => 'فتح الفيديو';

  @override
  String get chatInfoOpenImage => 'فتح الصورة';

  @override
  String get chatInfoMedia => 'الوسائط';

  @override
  String get chatInfoRetry => 'إعادة المحاولة';

  @override
  String get chatInfoChat => 'محادثة';

  @override
  String get chatInfoGroup => 'مجموعة';

  @override
  String get chatInfoUnmuted => 'تم إلغاء كتم الإشعارات';

  @override
  String get chatInfoMuted => 'تم كتم المحادثة';

  @override
  String get chatInfoUnarchived => 'تم إلغاء أرشفة المحادثة';

  @override
  String get chatInfoArchived => 'تمت أرشفة المحادثة';

  @override
  String get chatInfoLeaveTitle => 'هل تريد مغادرة المحادثة؟';

  @override
  String get chatInfoLeaveBody => 'ستغادر هذه المحادثة.';

  @override
  String get chatInfoLeave => 'مغادرة';

  @override
  String get chatInfoUnblocked => 'تم رفع الحظر';

  @override
  String get chatInfoBlockTitle => 'هل تريد حظر المستخدم؟';

  @override
  String get chatInfoBlockBody => 'لا يمكنك مراسلة شخص قمت بحظره.';

  @override
  String get chatInfoBlock => 'حظر';

  @override
  String get chatInfoBlocked => 'تم حظر المستخدم';

  @override
  String get chatInfoUnblock => 'رفع الحظر';

  @override
  String get chatInfoReportUser => 'الإبلاغ عن المستخدم';

  @override
  String get chatInfoReport => 'إبلاغ';

  @override
  String get chatInfoRemoveMemberTitle => 'هل تريد إزالة العضو؟';

  @override
  String chatInfoRemoveMemberBody(String name) {
    return 'ستتم إزالة $name من المجموعة.';
  }

  @override
  String get chatInfoRemove => 'إزالة';

  @override
  String get chatInfoPickGallery => 'اختيار من المعرض';

  @override
  String get chatInfoRemovePhoto => 'إزالة الصورة';

  @override
  String get chatInfoImageTooLarge => 'الصورة كبيرة جدًا، اختر صورة أصغر.';

  @override
  String get chatInfoImageTypeOnly => 'يُسمح فقط بصور JPEG أو PNG أو WebP.';

  @override
  String get chatInfoTitle => 'معلومات المحادثة';

  @override
  String get chatInfoNoMembers => 'لا توجد قائمة أعضاء.';

  @override
  String get chatInfoClubRoom => 'غرفة النادي';

  @override
  String get chatInfoEventRoom => 'غرفة الفعالية';

  @override
  String chatInfoMemberCount(String n) {
    return '$n عضو';
  }

  @override
  String get chatInfoChangePhoto => 'تغيير الصورة';

  @override
  String get chatInfoEditName => 'تعديل الاسم';

  @override
  String get chatInfoClub => 'النادي';

  @override
  String get chatInfoEvent => 'الفعالية';

  @override
  String get chatInfoSearch => 'بحث';

  @override
  String get chatInfoMembers => 'الأعضاء';

  @override
  String chatInfoMembersDot(String n) {
    return 'الأعضاء · $n';
  }

  @override
  String get chatInfoNoMedia => 'لا توجد صور في هذه المحادثة بعد.';

  @override
  String get chatInfoSeeAllMedia => 'عرض كل الوسائط';

  @override
  String chatInfoMediaDot(String count) {
    return 'الوسائط · $count';
  }

  @override
  String get chatInfoAll => 'الكل';

  @override
  String get chatInfoMuteOn => 'مفعّل';

  @override
  String get chatInfoMutedAlways => 'مكتومة · دائمًا';

  @override
  String chatInfoMutedDays(String n) {
    return 'مكتومة · يُلغى الكتم بعد $n يوم';
  }

  @override
  String chatInfoMutedHours(String n) {
    return 'مكتومة · يُلغى الكتم بعد $n ساعة';
  }

  @override
  String get chatInfoMutedSoon => 'مكتومة · سيُلغى الكتم قريبًا';

  @override
  String get chatInfoMutedLabel => 'مكتومة';

  @override
  String get chatInfoOpenClubPage => 'فتح صفحة النادي';

  @override
  String get chatInfoOpenEventPage => 'فتح صفحة الفعالية';

  @override
  String get chatInfoViewProfile => 'عرض الملف الشخصي';

  @override
  String get chatInfoMuteNotifications => 'كتم الإشعارات';

  @override
  String get chatInfoClosed => 'هذه المحادثة مغلقة';

  @override
  String get chatInfoClosedSub => 'لا يمكن إرسال رسائل جديدة';

  @override
  String get chatInfoLeaveChat => 'مغادرة المحادثة';

  @override
  String get chatInfoSettings => 'الإعدادات';

  @override
  String get chatInfoGroupName => 'اسم المجموعة';

  @override
  String get chatMiscFilterAll => 'الكل';

  @override
  String get chatMiscFilterPeople => 'الأشخاص';

  @override
  String get chatMiscFilterClubs => 'الأندية';

  @override
  String get chatMiscFilterEvents => 'الفعاليات';

  @override
  String get chatMiscArchived => 'تمت أرشفة المحادثة';

  @override
  String get chatMiscUnarchived => 'تمت إزالة المحادثة من الأرشيف';

  @override
  String get chatMiscChat => 'محادثة';

  @override
  String get chatMiscArchive => 'الأرشيف';

  @override
  String get chatMiscNewChat => 'محادثة جديدة';

  @override
  String get chatMiscEmptyArchive => 'لا توجد محادثات في الأرشيف';

  @override
  String get chatMiscEmptyNoMatch => 'لم يتم العثور على محادثات مطابقة';

  @override
  String get chatMiscEmptyNone => 'ليست لديك محادثات بعد';

  @override
  String get chatMiscUnarchiveAction => 'إزالة';

  @override
  String get chatMiscArchiveAction => 'أرشفة';

  @override
  String get chatMiscSearchHint => 'ابحث عن شخص أو مجموعة';

  @override
  String get chatMiscTagClub => 'نادٍ';

  @override
  String get chatMiscTagEvent => 'فعالية';

  @override
  String get chatMiscMessageDeleted => 'تم حذف الرسالة';

  @override
  String get chatMiscOnceText => 'صورة (عرض لمرة واحدة)';

  @override
  String get chatMiscImage => 'صورة';

  @override
  String get chatMiscDayMon => 'الإثنين';

  @override
  String get chatMiscDayTue => 'الثلاثاء';

  @override
  String get chatMiscDayWed => 'الأربعاء';

  @override
  String get chatMiscDayThu => 'الخميس';

  @override
  String get chatMiscDayFri => 'الجمعة';

  @override
  String get chatMiscDaySat => 'السبت';

  @override
  String get chatMiscDaySun => 'الأحد';

  @override
  String get chatMiscYesterday => 'أمس';

  @override
  String chatMiscSendFailedRetry(String error) {
    return '$error · أعد المحاولة';
  }

  @override
  String get chatMiscSendFailed => 'تعذر الإرسال';

  @override
  String get chatMiscThisMessageDeleted => 'تم حذف هذه الرسالة';

  @override
  String get chatMiscVideo => 'فيديو';

  @override
  String get chatMiscPhoto => 'صورة';

  @override
  String get chatMiscUser => 'مستخدم';

  @override
  String get chatMiscStatusSending => 'جارٍ الإرسال';

  @override
  String get chatMiscStatusSent => 'تم الإرسال';

  @override
  String get chatMiscStatusDelivered => 'تم التسليم';

  @override
  String get chatMiscStatusRead => 'تمت القراءة';

  @override
  String get chatMiscImageUnavailable => 'الصورة غير متاحة';

  @override
  String chatMiscVideoWithDuration(String duration) {
    return 'فيديو، $duration';
  }

  @override
  String get chatMiscClose => 'إغلاق';

  @override
  String get chatMiscImageLoadFailed => 'تعذر تحميل الصورة.';

  @override
  String get chatMiscOnceOpened => 'تم الفتح';

  @override
  String get chatMiscOnceSending => 'صورة · جارٍ الإرسال';

  @override
  String get chatMiscOnceSent => 'صورة · تم الإرسال';

  @override
  String get chatMiscOnceTapToOpen => 'صورة · المس للفتح';

  @override
  String chatMiscOnceSemantics(String label) {
    return 'صورة لمرة واحدة. $label';
  }

  @override
  String get chatMiscEdited => 'تم التعديل';

  @override
  String get chatMiscContactsFind => 'ابحث عن أشخاص من جهات الاتصال';

  @override
  String get chatMiscContactsRationale =>
      'نحتاج إلى الوصول إلى جهات الاتصال للعثور على أشخاص الجامعة بينها. لا يتم إرسال جهات الاتصال إلى الخادم، بل تتم مطابقة ملخصات البريد الإلكتروني فقط.';

  @override
  String get chatMiscContactsSubtitle => 'أشخاص من الجامعة';

  @override
  String get chatMiscContactsPermTitle => 'إذن جهات الاتصال مطلوب';

  @override
  String get chatMiscContactsPermText =>
      'يجب منح إذن الوصول إلى جهات الاتصال حتى نتمكن من العثور على أشخاص الحرم الجامعي بينها.';

  @override
  String get chatMiscContactsPermAction => 'السماح';

  @override
  String get chatMiscContactsNoneTitle => 'لا يوجد أشخاص مطابقون';

  @override
  String get chatMiscContactsNoneText =>
      'لم نجد أيًّا من جهات اتصالك يستخدم التطبيق ببريده الجامعي. سيظهر أصدقاؤك هنا عند انضمامهم.';

  @override
  String get chatMiscContactsSearchHint => 'ابحث في الأشخاص';

  @override
  String get chatMiscContactsTruncated =>
      'تم بلوغ حد الطلبات في الساعة؛ ستتم مطابقة بقية الأشخاص لاحقًا.';

  @override
  String get chatMiscContactsNoSearchMatch => 'لا يوجد أشخاص مطابقون لبحثك.';

  @override
  String chatMiscContactsCount(String n) {
    return '$n شخص';
  }

  @override
  String get chatMiscMessage => 'رسالة';

  @override
  String get chatMiscContactsPrivacy =>
      'لا يتم إرسال جهات الاتصال إلى الخادم، بل تتم مطابقة ملخصات البريد الإلكتروني فقط.';

  @override
  String get chatMiscGroupMax => 'يمكن إضافة 50 شخصًا كحد أقصى إلى المجموعة.';

  @override
  String get chatMiscGroupNameRequired => 'أدخل اسم المجموعة.';

  @override
  String get chatMiscUserSearchHint => 'ابحث بالاسم أو البريد الإلكتروني';

  @override
  String get chatMiscCreateGroup => 'إنشاء المجموعة';

  @override
  String get chatMiscStartChat => 'بدء المحادثة';

  @override
  String get chatMiscGroupCardTitle => 'إنشاء مجموعة';

  @override
  String chatMiscSelectedCount(String n) {
    return 'تم اختيار $n';
  }

  @override
  String get chatMiscGroupName => 'اسم المجموعة';

  @override
  String get chatMiscMax50 => 'الحد الأقصى 50';

  @override
  String get chatMiscSearchMin => 'اكتب حرفين على الأقل للبحث عن الأشخاص.';

  @override
  String get chatMiscNoMatchPeople => 'لم يتم العثور على أشخاص مطابقين.';

  @override
  String get chatMiscPeopleHeader => 'الأشخاص';

  @override
  String get chatMiscForward => 'إعادة توجيه';

  @override
  String get chatMiscSearchChat => 'ابحث في المحادثات';

  @override
  String chatMiscForwardMax(String max) {
    return 'الحد الأقصى للمحادثات: $max.';
  }

  @override
  String get chatMiscSend => 'إرسال';

  @override
  String chatMiscSendCount(String n) {
    return 'إرسال ($n)';
  }

  @override
  String get chatMiscChatNotFound => 'لم يتم العثور على محادثات.';

  @override
  String get chatMiscGalleryRationale =>
      'نحتاج إلى إذن الوصول لعرض الصور ومقاطع الفيديو في معرضك.';

  @override
  String get chatMiscVideoMax60 => 'يجب ألا يتجاوز الفيديو 60 ثانية';

  @override
  String chatMiscPickMax(String max) {
    return 'الحد الأقصى للعناصر: $max';
  }

  @override
  String get chatMiscAll => 'الكل';

  @override
  String get chatMiscGallery => 'المعرض';

  @override
  String get chatMiscLimitedNote => 'تظهر فقط العناصر التي سمحت بها.';

  @override
  String get chatMiscSelectMore => 'اختر المزيد';

  @override
  String get chatMiscSettings => 'الإعدادات';

  @override
  String get chatMiscGalleryDenied => 'لم يتم منح إذن الوصول إلى المعرض.';

  @override
  String get chatMiscOpenSettings => 'افتح من الإعدادات';

  @override
  String get chatMiscCamera => 'الكاميرا';

  @override
  String chatMiscPreviewCount(String n) {
    return 'معاينة ($n)';
  }

  @override
  String get chatMiscCameraRationale =>
      'نحتاج إلى الوصول إلى الكاميرا لتتمكن من التقاط الصور والفيديو.';

  @override
  String get chatMiscMicRationale =>
      'نحتاج إلى الوصول إلى الميكروفون لتسجيل الصوت مع الفيديو.';

  @override
  String get chatMiscPhotoFailed => 'تعذر التقاط الصورة.';

  @override
  String get chatMiscVideoSaveFailed => 'تعذر حفظ الفيديو.';

  @override
  String get chatMiscCameraUnavailable => 'الكاميرا غير متاحة.';

  @override
  String get chatMiscCameraHint => 'المس: صورة · اضغط مطولًا: فيديو';

  @override
  String get chatMiscFlipCamera => 'تبديل الكاميرا';

  @override
  String get chatMiscOnceToast =>
      'عرض لمرة واحدة: يمكن للمستلم مشاهدتها مرة واحدة فقط';

  @override
  String get chatMiscAddCaption => 'أضف تعليقًا…';

  @override
  String get chatMiscOnceSendLabel => 'عرض لمرة واحدة';

  @override
  String get chatMiscOnceGone => 'لم يعد بالإمكان عرض هذه الصورة.';

  @override
  String get chatMiscOnceOwn =>
      'لا يمكنك فتح صورة العرض لمرة واحدة التي أرسلتها.';

  @override
  String get chatMiscOnceNetwork =>
      'تعذر تحميل الصورة. تحقق من اتصالك. بما أنها للعرض لمرة واحدة، قد لا يمكن فتحها مرة أخرى.';

  @override
  String get chatMiscOnceShowFailed =>
      'تعذر عرض الصورة. بما أنها للعرض لمرة واحدة، قد لا يمكن فتحها مرة أخرى.';

  @override
  String get chatMiscOnceTitle => 'عرض لمرة واحدة';

  @override
  String get chatMiscRetry => 'أعد المحاولة';

  @override
  String get chatMiscSaveUnsupported => 'غير مدعوم على هذا الجهاز.';

  @override
  String get chatMiscSaveDenied => 'لم يتم منح إذن المعرض.';

  @override
  String get chatMiscSaveNoSpace => 'لا توجد مساحة كافية على الجهاز.';

  @override
  String get chatMiscImageSaveFailed => 'تعذر حفظ الصورة.';

  @override
  String get chatMiscSavedToGallery => 'تم الحفظ في المعرض';

  @override
  String get chatMiscDownload => 'تنزيل';

  @override
  String get chatMiscPlayVideo => 'تشغيل الفيديو';

  @override
  String get chatMiscVideoPlayFailed => 'تعذر تشغيل الفيديو';

  @override
  String get clubWithdrawTitle => 'سحب الطلب';

  @override
  String get clubWithdrawMessage => 'هل تريد سحب طلب الانضمام؟';

  @override
  String get clubWithdrawConfirm => 'سحب';

  @override
  String get clubImageTooLarge => 'الصورة كبيرة جدًا.';

  @override
  String get clubImageUnsupported => 'يمكن رفع صور JPEG أو PNG أو WebP فقط.';

  @override
  String get clubImageUnreadable => 'تعذرت قراءة الصورة.';

  @override
  String get clubImagePickFailed => 'تعذر اختيار الصورة.';

  @override
  String get clubImageUploadFailed => 'تعذر رفع الصورة.';

  @override
  String get clubDeleted => 'تم حذف النادي.';

  @override
  String get clubChatClosed => 'محادثة النادي مغلقة حاليًا.';

  @override
  String get clubChatPreparing =>
      'محادثة النادي قيد التجهيز، حاول مرة أخرى بعد قليل.';

  @override
  String get clubChat => 'محادثة النادي';

  @override
  String get clubDeletePostTitle => 'حذف المنشور';

  @override
  String get clubDeletePostMessage => 'هل تريد حذف هذا المنشور نهائيًا؟';

  @override
  String get clubCancel => 'إلغاء';

  @override
  String get clubDelete => 'حذف';

  @override
  String get clubReportClub => 'الإبلاغ عن النادي';

  @override
  String get clubReportPost => 'الإبلاغ عن المنشور';

  @override
  String clubMemberCount(String count) {
    return '$count عضو';
  }

  @override
  String get clubPrivate => 'خاص';

  @override
  String get clubPublic => 'عام';

  @override
  String get clubTitle => 'النادي';

  @override
  String get clubBack => 'رجوع';

  @override
  String get clubOptions => 'خيارات النادي';

  @override
  String get clubEdit => 'تعديل النادي';

  @override
  String clubRequestsWithCount(String count) {
    return 'الطلبات ($count)';
  }

  @override
  String get clubRequests => 'الطلبات';

  @override
  String get clubManageMembers => 'إدارة الأعضاء';

  @override
  String get clubChangeCover => 'تغيير الغلاف';

  @override
  String get clubDeleteClub => 'حذف النادي';

  @override
  String get clubLeave => 'مغادرة النادي';

  @override
  String get clubIsMember => 'أنت عضو';

  @override
  String get clubRequestSent => 'تم إرسال الطلب';

  @override
  String get clubCannotJoin => 'لا يمكنك الانضمام';

  @override
  String get clubSendJoinRequest => 'إرسال طلب انضمام';

  @override
  String get clubJoin => 'انضمام';

  @override
  String get clubTabPosts => 'المنشورات';

  @override
  String get clubTabEvents => 'الفعاليات';

  @override
  String get clubTabMembers => 'الأعضاء';

  @override
  String get clubTabPolls => 'الاستطلاعات';

  @override
  String get clubNoPosts => 'لا توجد منشورات بعد.';

  @override
  String get clubNoEvents => 'لا توجد فعاليات قادمة لهذا النادي.';

  @override
  String get clubNoMembers => 'لم يتم العثور على أعضاء.';

  @override
  String get clubLoadFailedRetry => 'تعذر التحميل، حاول مرة أخرى';

  @override
  String get clubWriteHint => 'اكتب شيئًا للنادي';

  @override
  String get clubAddImage => 'إضافة صورة';

  @override
  String get clubShare => 'مشاركة';

  @override
  String get clubRemoveImage => 'إزالة الصورة';

  @override
  String get clubPendingRequests => 'الطلبات المعلقة';

  @override
  String get clubPostActions => 'إجراءات المنشور';

  @override
  String get clubUnpin => 'إلغاء التثبيت';

  @override
  String get clubPin => 'تثبيت';

  @override
  String get clubReport => 'إبلاغ';

  @override
  String get clubPinned => 'مثبت';

  @override
  String get clubUser => 'مستخدم';

  @override
  String get clubRoleOwner => 'مدير';

  @override
  String get clubRoleModerator => 'مشرف';

  @override
  String get clubDeleteBody =>
      'سيتم حذف الأعضاء والفعاليات والمحادثة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String clubDeleteTypeName(String name) {
    return 'اكتب اسم النادي للتأكيد: $name';
  }

  @override
  String get clubNameHint => 'اسم النادي';

  @override
  String get clubOwnerCannotLeave =>
      'لا يمكن لمالك النادي المغادرة. انقل الملكية أولًا أو احذف النادي.';

  @override
  String get clubCannotLeaveTitle => 'لا يمكنك مغادرة النادي';

  @override
  String get clubOk => 'حسنًا';

  @override
  String get clubThisClub => 'هذا النادي';

  @override
  String clubLeaveMessage(String name) {
    return 'هل تريد مغادرة $name؟ ستتم إزالتك من محادثة النادي أيضًا وستختفي من قائمة محادثاتك.';
  }

  @override
  String get clubLeaveConfirm => 'مغادرة';

  @override
  String get clubMgmtJoinTitle => 'طلب الانضمام';

  @override
  String clubMgmtJoinAdminsSee(String club) {
    return 'سيرى مديرو $club إجاباتك.';
  }

  @override
  String get clubMgmtAnswerHint => 'إجابتك';

  @override
  String get clubMgmtQuestionRequired => 'هذا السؤال إلزامي';

  @override
  String get clubMgmtCancel => 'إلغاء';

  @override
  String get clubMgmtSendRequest => 'إرسال الطلب';

  @override
  String get clubMgmtNoPending => 'لا توجد طلبات معلقة.';

  @override
  String get clubMgmtMoreRequests => 'المزيد من الطلبات';

  @override
  String get clubMgmtRequestsTitle => 'الطلبات';

  @override
  String clubMgmtWaitingCount(String count) {
    return '$count في الانتظار';
  }

  @override
  String get clubMgmtUser => 'مستخدم';

  @override
  String get clubMgmtReject => 'رفض';

  @override
  String get clubMgmtApprove => 'قبول';

  @override
  String get clubMgmtBan => 'حظر';

  @override
  String get clubMgmtRemoveFromClub => 'إزالة من النادي';

  @override
  String clubMgmtBanMessage(String name) {
    return 'هل تريد إزالة $name من النادي ومنعه من الانضمام مجددًا؟';
  }

  @override
  String clubMgmtRemoveMessage(String name) {
    return 'هل تريد إزالة $name من النادي؟ وستتم إزالته أيضًا من محادثة النادي.';
  }

  @override
  String get clubMgmtRemoveConfirm => 'إزالة';

  @override
  String get clubMgmtNoMembers => 'لم يتم العثور على أعضاء.';

  @override
  String get clubMgmtMembersTitle => 'الأعضاء';

  @override
  String get clubMgmtSearchMember => 'ابحث عن عضو';

  @override
  String get clubMgmtRoleManager => 'مدير';

  @override
  String get clubMgmtRoleModerator => 'مشرف';

  @override
  String get clubMgmtMemberActions => 'إجراءات العضو';

  @override
  String get clubMgmtMakeModerator => 'تعيين كمراقب';

  @override
  String get clubMgmtMakeMember => 'تعيين كعضو';

  @override
  String get clubMgmtPendingTitle => 'تم إرسال ناديك للموافقة';

  @override
  String get clubMgmtPendingBody =>
      'سيتم نشر النادي بعد مراجعة الإدارة. يمكنك متابعة الحالة من قسم أنديتي.';

  @override
  String get clubMgmtOk => 'حسنًا';

  @override
  String get clubMgmtImageTooLarge => 'الصورة كبيرة جدًا.';

  @override
  String get clubMgmtImageUnsupported =>
      'يمكن رفع صور JPEG أو PNG أو WebP فقط.';

  @override
  String get clubMgmtImageUnreadable => 'تعذرت قراءة الصورة.';

  @override
  String get clubMgmtImagePickFailed => 'تعذر اختيار الصورة.';

  @override
  String get clubMgmtNameMin => 'يجب ألا يقل اسم النادي عن 3 أحرف.';

  @override
  String get clubMgmtNameMax => 'يجب ألا يتجاوز اسم النادي 80 حرفًا.';

  @override
  String get clubMgmtDescMax => 'يجب ألا يتجاوز الوصف 1000 حرف.';

  @override
  String get clubMgmtCategoryMax => 'يجب ألا تتجاوز الفئة 40 حرفًا.';

  @override
  String get clubMgmtSavedWithWarning =>
      'تم حفظ النادي لكن تعذر حفظ الغلاف أو أسئلة الانضمام.';

  @override
  String get clubMgmtEditTitle => 'تعديل النادي';

  @override
  String get clubMgmtCreateTitle => 'إنشاء نادٍ';

  @override
  String get clubMgmtNameLabel => 'اسم النادي';

  @override
  String get clubMgmtNameHint => 'مثال: نادي الروبوتات';

  @override
  String get clubMgmtDescLabel => 'وصف قصير';

  @override
  String get clubMgmtDescHint => 'ماذا يفعل النادي؟';

  @override
  String get clubMgmtCategoryLabel => 'الفئة';

  @override
  String get clubMgmtCategoryHint => 'اختر من القائمة أو اكتب (اختياري)';

  @override
  String get clubMgmtVisibility => 'الظهور';

  @override
  String get clubMgmtPublic => 'عام';

  @override
  String get clubMgmtPrivate => 'خاص';

  @override
  String get clubMgmtPrivateHint =>
      'يرى المحتوى الأعضاء فقط، والانضمام بموافقة.';

  @override
  String get clubMgmtPublicHint => 'يظهر النادي في قسم استكشاف.';

  @override
  String get clubMgmtJoinLabel => 'الانضمام';

  @override
  String get clubMgmtOpenPolicy => 'مفتوح';

  @override
  String get clubMgmtApprovalPolicy => 'بموافقة';

  @override
  String get clubMgmtApprovalHint =>
      'يرسل الراغبون في الانضمام طلبًا ويوافق عليه مديرو النادي.';

  @override
  String get clubMgmtOpenHint => 'يمكن للجميع الانضمام مباشرة.';

  @override
  String clubMgmtQuestionsLabel(String max) {
    return 'أسئلة الانضمام (حتى $max)';
  }

  @override
  String clubMgmtQuestionHint(String n) {
    return 'السؤال $n';
  }

  @override
  String get clubMgmtRemoveQuestion => 'إزالة السؤال';

  @override
  String get clubMgmtAddQuestion => 'إضافة سؤال';

  @override
  String get clubMgmtSave => 'حفظ';

  @override
  String get clubMgmtCreateButton => 'إنشاء النادي';

  @override
  String get clubMgmtChangeCover => 'تغيير الغلاف';

  @override
  String get clubMgmtAddCover => 'إضافة غلاف (اختياري)';

  @override
  String get clubMgmtClubsTitle => 'الأندية';

  @override
  String get clubMgmtSearch => 'بحث';

  @override
  String get clubMgmtSearchClub => 'ابحث عن نادٍ';

  @override
  String get clubMgmtTabDiscover => 'استكشف';

  @override
  String get clubMgmtTabMine => 'أنديتي';

  @override
  String get clubMgmtAll => 'الكل';

  @override
  String get clubMgmtEmptyMine => 'لست عضوًا في أي نادٍ بعد.';

  @override
  String get clubMgmtNotFound => 'لم يتم العثور على أندية.';

  @override
  String clubMgmtMemberCount(String count) {
    return '$count عضو';
  }

  @override
  String get clubMgmtYouAreMember => 'عضو';

  @override
  String get clubMgmtRequestSent => 'تم إرسال الطلب';

  @override
  String get clubMgmtBanned => 'محظور';

  @override
  String get clubMgmtJoin => 'انضم';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonSearchHint => 'بحث';

  @override
  String get commonJustNow => 'الآن';

  @override
  String commonMinutesAgo(String n) {
    return 'منذ $n د';
  }

  @override
  String commonHoursAgo(String n) {
    return 'منذ $n س';
  }

  @override
  String commonDaysAgo(String n) {
    return 'منذ $n يوم';
  }

  @override
  String commonLongDate(String day, String month, String weekday) {
    return '$weekday، $day $month';
  }

  @override
  String get commonTypeNews => 'خبر';

  @override
  String get commonTypeAnnouncement => 'إعلان';

  @override
  String get commonTypeEvent => 'فعالية';

  @override
  String get commonMonth1 => 'يناير';

  @override
  String get commonMonth2 => 'فبراير';

  @override
  String get commonMonth3 => 'مارس';

  @override
  String get commonMonth4 => 'أبريل';

  @override
  String get commonMonth5 => 'مايو';

  @override
  String get commonMonth6 => 'يونيو';

  @override
  String get commonMonth7 => 'يوليو';

  @override
  String get commonMonth8 => 'أغسطس';

  @override
  String get commonMonth9 => 'سبتمبر';

  @override
  String get commonMonth10 => 'أكتوبر';

  @override
  String get commonMonth11 => 'نوفمبر';

  @override
  String get commonMonth12 => 'ديسمبر';

  @override
  String get commonWeekday1 => 'الاثنين';

  @override
  String get commonWeekday2 => 'الثلاثاء';

  @override
  String get commonWeekday3 => 'الأربعاء';

  @override
  String get commonWeekday4 => 'الخميس';

  @override
  String get commonWeekday5 => 'الجمعة';

  @override
  String get commonWeekday6 => 'السبت';

  @override
  String get commonWeekday7 => 'الأحد';

  @override
  String get reportReasonSpam => 'بريد مزعج أو إعلان';

  @override
  String get reportReasonHarassment => 'تحرش أو تنمر';

  @override
  String get reportReasonInappropriate => 'محتوى غير لائق';

  @override
  String get reportReasonImpersonation => 'انتحال شخصية';

  @override
  String get reportReasonOther => 'أخرى';

  @override
  String get reportTitle => 'إبلاغ';

  @override
  String get reportMessageTitle => 'الإبلاغ عن الرسالة';

  @override
  String get reportThanks => 'تم استلام بلاغك. شكرًا لك.';

  @override
  String get reportPrompt => 'اختر السبب. سيتم إرسال بلاغك إلى الإدارة.';

  @override
  String get reportDetailsHint => 'تفاصيل إضافية (اختياري)';

  @override
  String get reportSend => 'إرسال';

  @override
  String get permNotificationsTitle => 'الإشعارات';

  @override
  String get permNotificationsText =>
      'اسمح لنا بإرسال الإشعارات لتعرف فورًا بالرسائل والفعاليات والإعلانات.';

  @override
  String get permContactsTitle => 'جهات الاتصال';

  @override
  String get permContactsText =>
      'مطلوب للعثور على أشخاص الجامعة في جهات اتصالك وبدء المحادثات. لا يتم إرسال جهات اتصالك إلى الخادم.';

  @override
  String get permCameraTitle => 'الكاميرا';

  @override
  String get permCameraText =>
      'نحتاج إلى الوصول إلى الكاميرا لمسح رموز QR والتقاط الصور.';

  @override
  String get permMicrophoneTitle => 'الميكروفون';

  @override
  String get permMicrophoneText =>
      'نحتاج إلى الوصول إلى الميكروفون لتتمكن من تسجيل الصوت والفيديو.';

  @override
  String get permPhotosTitle => 'الصور';

  @override
  String get permPhotosText =>
      'نحتاج إلى الوصول إلى معرض الصور لتتمكن من اختيار الصور ومشاركتها.';

  @override
  String get permContinue => 'متابعة';

  @override
  String get permNotNow => 'ليس الآن';

  @override
  String permDeniedText(String title) {
    return 'لم يتم منح إذن $title، لذلك هذه الميزة غير متاحة. يمكنك تفعيله من الإعدادات > BÜ Kampüs.';
  }

  @override
  String get permOpenSettings => 'فتح الإعدادات';

  @override
  String get permClose => 'إغلاق';

  @override
  String get permPageTitle => 'بعض الأذونات';

  @override
  String get permPageIntro =>
      'نطلب الأذونات التالية لتستفيد من التطبيق بأفضل شكل. لست مضطرًا لمنح أي منها الآن، ويمكنك تغييرها لاحقًا من الإعدادات.';

  @override
  String get permStart => 'ابدأ';

  @override
  String get permGranted => 'تم المنح';

  @override
  String get permDenied => 'مرفوض';

  @override
  String get permRetry => 'حاول مرة أخرى';

  @override
  String get permAllow => 'السماح';

  @override
  String get coreErrNetwork => 'تعذر الوصول إلى الخادم. تحقق من اتصالك.';

  @override
  String get coreErrTooMany => 'محاولات كثيرة. يرجى الانتظار قليلًا.';

  @override
  String get coreErrGeneric => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get coreIdEmpty => 'أدخل رقمك الجامعي أو بريدك الإلكتروني.';

  @override
  String get coreIdDomain => 'يمكن استخدام عناوين bingol.edu.tr فقط.';

  @override
  String get coreIdNumber => 'تحقق من رقمك الجامعي.';

  @override
  String get coreOffline => 'غير متصل';

  @override
  String get coreMaintenance => 'النظام قيد الصيانة.';

  @override
  String get coreOpen => 'فتح';

  @override
  String get eventFormJoinFull => 'اكتمل العدد. يمكنك المتابعة عبر \"مهتم\".';

  @override
  String get eventFormLeaveTitle => 'إلغاء المشاركة';

  @override
  String get eventFormLeaveMessage =>
      'ستتم إزالة هذه الفعالية من قائمة فعالياتي.';

  @override
  String get eventFormLeaveConfirm => 'مغادرة';

  @override
  String get eventFormRegsClosedToast => 'تم إغلاق التسجيل.';

  @override
  String get eventFormRegsReopenedToast => 'تمت إعادة فتح التسجيل.';

  @override
  String get eventFormCancelTitle => 'إلغاء الفعالية';

  @override
  String get eventFormCancelMessage =>
      'سيتم إلغاء هذه الفعالية لجميع المشاركين.';

  @override
  String get eventFormCancelAction => 'إلغاء الفعالية';

  @override
  String get eventFormCancelledToast => 'تم إلغاء الفعالية.';

  @override
  String get eventFormScanTitle => 'امسح رمز QR للحضور';

  @override
  String get eventFormWrongEventCode => 'هذا الرمز يخص فعالية أخرى.';

  @override
  String get eventFormCheckedIn => 'تم تسجيل حضورك';

  @override
  String get eventFormChatSoon => 'محادثة الفعالية قريبًا';

  @override
  String get eventFormEventTitle => 'الفعالية';

  @override
  String get eventFormNotFound => 'الفعالية غير موجودة';

  @override
  String get eventFormRegsClosed => 'التسجيل مغلق';

  @override
  String get eventFormJoin => 'انضم';

  @override
  String get eventFormInterested => 'مهتم';

  @override
  String get eventFormBack => 'رجوع';

  @override
  String get eventFormManage => 'إدارة';

  @override
  String get eventFormEdit => 'تعديل';

  @override
  String get eventFormReopenRegs => 'إعادة فتح التسجيل';

  @override
  String get eventFormCloseRegs => 'إغلاق التسجيل';

  @override
  String get eventFormReport => 'إبلاغ';

  @override
  String get eventFormReportEvent => 'الإبلاغ عن الفعالية';

  @override
  String get eventFormCancelledPill => 'ملغاة';

  @override
  String get eventFormInMine => 'ضمن فعالياتي';

  @override
  String get eventFormOrganizedBy => 'المنظم:';

  @override
  String get eventFormCapacityFull => 'اكتمل العدد';

  @override
  String eventFormCapacityCount(String going, String cap) {
    return 'السعة: $going / $cap';
  }

  @override
  String get eventFormGoingLabel => 'مشارك';

  @override
  String get eventFormInterestedLabel => 'مهتم';

  @override
  String get eventFormInterestedShort => 'مهتم';

  @override
  String get eventFormFullHint => 'اكتمل العدد، لكن يمكنك الإشارة إلى اهتمامك.';

  @override
  String get eventFormChat => 'محادثة الفعالية';

  @override
  String get eventFormManageJoin => 'إدارة المشاركة';

  @override
  String get eventFormCheckInLater => 'يفتح تسجيل الحضور في وقت الفعالية.';

  @override
  String get eventFormScanQr => 'مسح رمز QR';

  @override
  String get eventFormEnterCode => 'أدخل الرمز يدويًا';

  @override
  String get eventFormEnterOrganizerCode => 'أدخل الرمز الذي يعرضه المنظم';

  @override
  String get eventFormCheckInCode => 'رمز الحضور';

  @override
  String get eventFormSendCheckIn => 'إرسال الحضور';

  @override
  String get eventFormCodePreparing => 'جار تجهيز الرمز…';

  @override
  String get eventFormCodeFailed => 'تعذر الحصول على الرمز.';

  @override
  String get eventFormQrHelp => 'يمسح المشاركون رمز QR هذا من التطبيق.';

  @override
  String get eventFormCodeShortLived => 'الرمز صالح لفترة قصيرة.';

  @override
  String eventFormCodeExpires(String time) {
    return 'ينتهي: $time · يتجدد الرمز تلقائيًا';
  }

  @override
  String get eventFormRefreshCode => 'تحديث الرمز';

  @override
  String get eventFormNoAttendance => 'لا توجد سجلات حضور بعد';

  @override
  String eventFormAttendanceCount(String present, String total) {
    return 'الحضور: $present / $total شخص';
  }

  @override
  String get eventFormAttendees => 'المشاركون';

  @override
  String get eventFormShowMore => 'عرض المزيد';

  @override
  String eventFormCoverCreatedFail(String reason) {
    return 'تم إنشاء الفعالية لكن تعذر رفع الغلاف.$reason';
  }

  @override
  String eventFormCoverFail(String reason) {
    return 'تعذر رفع الغلاف.$reason';
  }

  @override
  String get eventFormRetry => 'حاول مرة أخرى';

  @override
  String get eventFormPickGallery => 'اختيار من المعرض';

  @override
  String get eventFormTakePhoto => 'التقاط صورة';

  @override
  String get eventFormImgTooLarge => 'الصورة كبيرة جدًا، اختر صورة أصغر.';

  @override
  String get eventFormImgUnsupported => 'يمكن رفع صور JPEG أو PNG أو WebP فقط.';

  @override
  String get eventFormImgUnreadable => 'تعذرت قراءة الصورة.';

  @override
  String get eventFormImgPickFail => 'تعذر اختيار الصورة. تحقق من الأذونات.';

  @override
  String get eventFormTitleTooShort => 'يجب ألا يقل العنوان عن 3 أحرف.';

  @override
  String get eventFormEndBeforeStart => 'يجب أن يكون الانتهاء بعد البداية.';

  @override
  String get eventFormCapInvalid => 'يجب أن تكون السعة رقمًا لا يقل عن 1.';

  @override
  String eventFormCoverRemoveFail(String reason) {
    return 'تعذرت إزالة الغلاف. $reason';
  }

  @override
  String get eventFormCreated => 'تم إنشاء الفعالية.';

  @override
  String get eventFormEditTitle => 'تعديل الفعالية';

  @override
  String get eventFormNewTitle => 'فعالية جديدة';

  @override
  String get eventFormFieldTitle => 'العنوان';

  @override
  String get eventFormTitleHint => 'عنوان الفعالية';

  @override
  String get eventFormFieldDesc => 'الوصف';

  @override
  String get eventFormDescHint => 'نبذة قصيرة عن الفعالية';

  @override
  String get eventFormStart => 'البداية';

  @override
  String get eventFormStartSem => 'وقت البداية';

  @override
  String get eventFormEnd => 'الانتهاء';

  @override
  String get eventFormEndSem => 'وقت الانتهاء';

  @override
  String get eventFormPlace => 'المكان';

  @override
  String get eventFormPlaceHint => 'مثال: قاعة المؤتمرات';

  @override
  String get eventFormCapacityLabel => 'السعة';

  @override
  String get eventFormCapHint => 'اتركه فارغًا لعدد غير محدود';

  @override
  String get eventFormSave => 'حفظ';

  @override
  String get eventFormCreate => 'إنشاء الفعالية';

  @override
  String get eventFormAddCover => 'إضافة صورة غلاف';

  @override
  String get eventFormChangeCover => 'تغيير الغلاف';

  @override
  String get eventFormRemoveCover => 'إزالة الغلاف';

  @override
  String get eventListTitle => 'الفعاليات';

  @override
  String get eventListCreate => 'إنشاء فعالية';

  @override
  String get eventListCheckin => 'تسجيل الحضور';

  @override
  String get eventListTabDiscover => 'استكشاف';

  @override
  String get eventListTabMine => 'فعالياتي';

  @override
  String get eventListTabCreated => 'ما أنشأته';

  @override
  String get eventListLoading => 'جارٍ التحميل';

  @override
  String get eventListPrevMonth => 'الشهر السابق';

  @override
  String get eventListNextMonth => 'الشهر التالي';

  @override
  String eventListMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String eventListLongDate(String day, String month, String weekday) {
    return '$weekday، $day $month';
  }

  @override
  String get eventListFull => 'اكتمل العدد. يمكنك المتابعة عبر \"مهتم\".';

  @override
  String get eventListLeaveTitle => 'مغادرة الفعالية';

  @override
  String get eventListLeaveMsg => 'ستتم إزالة هذه الفعالية من قائمة فعالياتي.';

  @override
  String get eventListLeave => 'مغادرة';

  @override
  String get eventListLeft => 'غادرت الفعالية.';

  @override
  String get eventListClosedDone => 'تم إغلاق التسجيل.';

  @override
  String get eventListReopenedDone => 'تمت إعادة فتح التسجيل.';

  @override
  String get eventListCancelTitle => 'إلغاء الفعالية';

  @override
  String get eventListCancelMsg => 'سيتم إلغاء هذه الفعالية لجميع المشاركين.';

  @override
  String get eventListCancelConfirm => 'إلغاء الفعالية';

  @override
  String get eventListCancelledDone => 'تم إلغاء الفعالية.';

  @override
  String get eventListScanTitle => 'امسح رمز QR للحضور';

  @override
  String get eventListNotCode => 'هذا ليس رمز حضور.';

  @override
  String get eventListCheckedIn => 'تم تسجيل حضورك.';

  @override
  String get eventListEmptyDay => 'لا توجد فعاليات لهذا اليوم.';

  @override
  String get eventListEmptyMonth => 'لا توجد فعاليات هذا الشهر.';

  @override
  String get eventListPastMonth => 'شهر سابق: للعرض فقط.';

  @override
  String get eventListTruncated =>
      'لا يمكن عرض الشهر كاملًا؛ بعض الفعاليات غير موجودة في القائمة.';

  @override
  String get eventListUpcoming => 'القادمة';

  @override
  String get eventListPast => 'السابقة';

  @override
  String get eventListCreatedHint =>
      'يمكنك إدارة الفعاليات التي أنشأتها من هنا.';

  @override
  String get eventListEmptyUpcoming => 'ليس لديك فعاليات للمشاركة فيها.';

  @override
  String get eventListEmptyPast => 'ليس لديك فعاليات سابقة.';

  @override
  String get eventListEmptyCreated => 'لم تنشئ أي فعالية بعد.';

  @override
  String get eventListDiscover => 'استكشف الفعاليات';

  @override
  String get eventListOfficial => 'رسمي';

  @override
  String get eventListCancelled => 'ملغاة';

  @override
  String get eventListRegClosedTag => 'التسجيل مغلق';

  @override
  String get eventListOpen => 'مفتوحة';

  @override
  String get eventListRegsClosed => 'التسجيل مغلق';

  @override
  String get eventListJoin => 'انضم';

  @override
  String get eventListInterested => 'مهتم';

  @override
  String get eventListGoing => 'مشارك';

  @override
  String get eventListOptions => 'خيارات';

  @override
  String eventListAttendeeCount(String count) {
    return '$count مشارك';
  }

  @override
  String get eventListAttendees => 'المشاركون';

  @override
  String get eventListEdit => 'تعديل';

  @override
  String get eventListReopen => 'إعادة فتح التسجيل';

  @override
  String get eventListClose => 'إغلاق التسجيل';

  @override
  String get eventListRegClosedError => 'التسجيل في هذه الفعالية مغلق.';

  @override
  String get eventListAddedMine => 'تمت الإضافة إلى فعالياتي';

  @override
  String get eventListDismiss => 'تراجع';

  @override
  String get eventListInMine => 'في فعالياتي';

  @override
  String get eventListQrLabel => 'رمز QR للحضور';

  @override
  String get eventListMonth1 => 'يناير';

  @override
  String get eventListMonth2 => 'فبراير';

  @override
  String get eventListMonth3 => 'مارس';

  @override
  String get eventListMonth4 => 'أبريل';

  @override
  String get eventListMonth5 => 'مايو';

  @override
  String get eventListMonth6 => 'يونيو';

  @override
  String get eventListMonth7 => 'يوليو';

  @override
  String get eventListMonth8 => 'أغسطس';

  @override
  String get eventListMonth9 => 'سبتمبر';

  @override
  String get eventListMonth10 => 'أكتوبر';

  @override
  String get eventListMonth11 => 'نوفمبر';

  @override
  String get eventListMonth12 => 'ديسمبر';

  @override
  String get eventListMon1 => 'يناير';

  @override
  String get eventListMon2 => 'فبراير';

  @override
  String get eventListMon3 => 'مارس';

  @override
  String get eventListMon4 => 'أبريل';

  @override
  String get eventListMon5 => 'مايو';

  @override
  String get eventListMon6 => 'يونيو';

  @override
  String get eventListMon7 => 'يوليو';

  @override
  String get eventListMon8 => 'أغسطس';

  @override
  String get eventListMon9 => 'سبتمبر';

  @override
  String get eventListMon10 => 'أكتوبر';

  @override
  String get eventListMon11 => 'نوفمبر';

  @override
  String get eventListMon12 => 'ديسمبر';

  @override
  String get eventListDayShort1 => 'اثن';

  @override
  String get eventListDayShort2 => 'ثلا';

  @override
  String get eventListDayShort3 => 'أرب';

  @override
  String get eventListDayShort4 => 'خمي';

  @override
  String get eventListDayShort5 => 'جمع';

  @override
  String get eventListDayShort6 => 'سبت';

  @override
  String get eventListDayShort7 => 'أحد';

  @override
  String get eventListDayLong1 => 'الاثنين';

  @override
  String get eventListDayLong2 => 'الثلاثاء';

  @override
  String get eventListDayLong3 => 'الأربعاء';

  @override
  String get eventListDayLong4 => 'الخميس';

  @override
  String get eventListDayLong5 => 'الجمعة';

  @override
  String get eventListDayLong6 => 'السبت';

  @override
  String get eventListDayLong7 => 'الأحد';

  @override
  String get homeGreetNight => 'طابت ليلتك';

  @override
  String get homeGreetMorning => 'صباح الخير';

  @override
  String get homeGreetDay => 'نهارك سعيد';

  @override
  String get homeGreetEvening => 'مساء الخير';

  @override
  String get homeEventLoadFailedToast => 'تعذر تحميل الفعالية.';

  @override
  String get homeEventLoadFailedTitle => 'تعذر تحميل الفعالية';

  @override
  String get homeQuotaFull => 'اكتمل العدد.';

  @override
  String get homeMaintenanceDefault => 'النظام قيد الصيانة.';

  @override
  String get homeSourceUnreachable =>
      'الموقع المصدر غير متاح حاليًا، وقد تكون البيانات غير محدثة.';

  @override
  String get homeSearchHint => 'ابحث عن أخبار أو أندية أو فعاليات';

  @override
  String get homeMyClubs => 'من أنديتي';

  @override
  String get homeAll => 'الكل';

  @override
  String get homeAgenda => 'المستجدات';

  @override
  String get homeContentLoadFailed => 'تعذر تحميل المحتوى.';

  @override
  String get homeNoContent => 'لا يوجد محتوى بعد.';

  @override
  String get homeMyProfile => 'ملفي الشخصي';

  @override
  String get homeFeaturedEvent => 'فعالية مميزة';

  @override
  String get homeNextEvent => 'الفعالية القادمة';

  @override
  String get homeNoUpcoming => 'لا توجد فعاليات قادمة';

  @override
  String get homeBrowseEvents => 'تصفح الفعاليات';

  @override
  String get homeOfficialEvent => 'فعالية رسمية';

  @override
  String get homeMostAttended => 'الأكثر حضورًا';

  @override
  String homeGoingCount(String count) {
    return '$count مشارك';
  }

  @override
  String get homeBeFirst => 'كن أول المشاركين';

  @override
  String get homeInMyEvents => 'ضمن فعالياتي';

  @override
  String get homeFull => 'مكتمل';

  @override
  String get homeRegClosed => 'التسجيل مغلق';

  @override
  String get homeJoin => 'انضم';

  @override
  String get homeQuickEvent => 'الفعاليات';

  @override
  String get homeQuickFood => 'الوجبات';

  @override
  String get homeQuickSupport => 'الدعم';

  @override
  String get homeTodayMeal => 'وجبة اليوم';

  @override
  String get homeNoMenuToday => 'لا توجد قائمة لليوم';

  @override
  String get homeNewMessages => 'رسائل جديدة';

  @override
  String get homeClubMemberships => 'عضويات الأندية';

  @override
  String homeMemberCount(String count) {
    return '$count عضو';
  }

  @override
  String get newsTypeNews => 'خبر';

  @override
  String get newsTypeAnnouncement => 'إعلان';

  @override
  String get newsTypeEvent => 'فعالية';

  @override
  String newsEventDateShort(String date) {
    return 'الفعالية: $date';
  }

  @override
  String newsEventDate(String date) {
    return 'تاريخ الفعالية: $date';
  }

  @override
  String get newsSaveRemove => 'إزالة من المفضلة';

  @override
  String get newsSaveAdd => 'إضافة إلى المفضلة';

  @override
  String get newsLinkOpenFailed => 'تعذر فتح الرابط.';

  @override
  String get newsFullContent =>
      'افتح الصفحة المصدر للاطلاع على المحتوى كاملًا.';

  @override
  String get newsOpenSource => 'فتح في الصفحة المصدر';

  @override
  String get newsMonth1 => 'يناير';

  @override
  String get newsMonth2 => 'فبراير';

  @override
  String get newsMonth3 => 'مارس';

  @override
  String get newsMonth4 => 'أبريل';

  @override
  String get newsMonth5 => 'مايو';

  @override
  String get newsMonth6 => 'يونيو';

  @override
  String get newsMonth7 => 'يوليو';

  @override
  String get newsMonth8 => 'أغسطس';

  @override
  String get newsMonth9 => 'سبتمبر';

  @override
  String get newsMonth10 => 'أكتوبر';

  @override
  String get newsMonth11 => 'نوفمبر';

  @override
  String get newsMonth12 => 'ديسمبر';

  @override
  String get newsDayLong1 => 'الاثنين';

  @override
  String get newsDayLong2 => 'الثلاثاء';

  @override
  String get newsDayLong3 => 'الأربعاء';

  @override
  String get newsDayLong4 => 'الخميس';

  @override
  String get newsDayLong5 => 'الجمعة';

  @override
  String get newsDayLong6 => 'السبت';

  @override
  String get newsDayLong7 => 'الأحد';

  @override
  String get newsDayShort1 => 'اثن';

  @override
  String get newsDayShort2 => 'ثلا';

  @override
  String get newsDayShort3 => 'أرب';

  @override
  String get newsDayShort4 => 'خمي';

  @override
  String get newsDayShort5 => 'جمع';

  @override
  String get newsDayShort6 => 'سبت';

  @override
  String get newsDayShort7 => 'أحد';

  @override
  String get discoverSaved => 'المحفوظات';

  @override
  String get discoverScopeLatest => 'الأحدث';

  @override
  String get discoverScopePopular => 'الرائج';

  @override
  String get discoverScopeFollowing => 'المتابَعون';

  @override
  String get discoverScopeDepartment => 'قسمي';

  @override
  String get discoverNoSaved => 'لم تحفظ أي خبر بعد.';

  @override
  String get discoverNoCategory => 'لا يوجد محتوى في هذه الفئة بعد.';

  @override
  String get discoverDeptHint =>
      'اختر قسمك من ملفك الشخصي لترى منشورات قسمك هنا.';

  @override
  String get discoverDeptEmpty => 'لا توجد منشورات من قسمك بعد.';

  @override
  String get discoverProfilePath => 'الملف الشخصي > تعديل الملف الشخصي';

  @override
  String get discoverPolls => 'الاستطلاعات';

  @override
  String get discoverSearch => 'بحث';

  @override
  String get discoverCompose => 'إنشاء منشور';

  @override
  String get discoverPosts => 'المنشورات';

  @override
  String get discoverNews => 'الأخبار';

  @override
  String get discoverSourceMaint =>
      'الموقع المصدر قيد الصيانة حاليًا. قد تكون البيانات غير محدثة.';

  @override
  String get menuTitle => 'قائمة الطعام';

  @override
  String get menuStale => 'تعذر تحديث قائمة الطعام، وتُعرض آخر قائمة معروفة.';

  @override
  String get menuPrevMonth => 'الشهر السابق';

  @override
  String get menuNextMonth => 'الشهر التالي';

  @override
  String menuTodayLabel(String date) {
    return 'اليوم · $date';
  }

  @override
  String get menuNoMenuDay => 'لا توجد قائمة طعام لهذا اليوم.';

  @override
  String get menuNoMenuMonth => 'لم تُنشر قائمة الطعام لهذا الشهر بعد.';

  @override
  String get menuNoList => 'لا توجد قائمة طعام.';

  @override
  String get menuPhotoLabel => 'صورة قائمة طعام اليوم';

  @override
  String get notifTitle => 'الإشعارات';

  @override
  String get notifMarkAll => 'تحديد الكل كمقروء';

  @override
  String get notifEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notifUnread => 'إشعار غير مقروء';

  @override
  String get notifGroupToday => 'اليوم';

  @override
  String get notifGroupYesterday => 'أمس';

  @override
  String get notifGroupOlder => 'أقدم';

  @override
  String get notifNow => 'الآن';

  @override
  String notifMinAgo(String n) {
    return 'منذ $n دقيقة';
  }

  @override
  String notifHourAgo(String n) {
    return 'منذ $n ساعة';
  }

  @override
  String notifDayAgo(String n) {
    return 'منذ $n يوم';
  }

  @override
  String get searchAll => 'الكل';

  @override
  String get searchClub => 'نادٍ';

  @override
  String get searchPost => 'منشور';

  @override
  String get searchPerson => 'شخص';

  @override
  String searchClassYear(String n) {
    return 'السنة $n';
  }

  @override
  String get searchUserDefault => 'مستخدم';

  @override
  String get searchHint =>
      'ابحث عن أخبار أو أندية أو فعاليات أو منشورات أو أشخاص';

  @override
  String get searchClear => 'مسح البحث';

  @override
  String get searchPrompt =>
      'اكتب حرفين على الأقل للبحث عن أخبار أو إعلانات أو أندية أو فعاليات أو أشخاص.';

  @override
  String get searchRecent => 'عمليات البحث الأخيرة';

  @override
  String get searchClearRecent => 'مسح';

  @override
  String get searchNoResults => 'لم يتم العثور على نتائج.';

  @override
  String searchResultCount(String count) {
    return '$count نتيجة';
  }

  @override
  String get searchTooMany => 'تم إرسال طلبات كثيرة، يرجى الانتظار بضع ثوان.';

  @override
  String get followButtonUnfollow => 'إلغاء المتابعة';

  @override
  String get followButtonFollow => 'متابعة';

  @override
  String get followButtonFollowing => 'متابَع';

  @override
  String get followersTitle => 'المتابعون';

  @override
  String get followingTitle => 'المتابَعون';

  @override
  String get followersEmpty => 'لا يوجد متابعون بعد.';

  @override
  String get followingEmpty => 'لا تتابع أحدًا بعد.';

  @override
  String get followSuggestionsEmpty => 'لا توجد اقتراحات حاليًا.';

  @override
  String get followSuggestionsTitle => 'أشخاص مقترحون';

  @override
  String get followFeedHint => 'تظهر هنا منشورات من تتابعهم.';

  @override
  String get followersCount => 'متابِع';

  @override
  String get followingCount => 'يتابع';

  @override
  String get qrScanTitle => 'مسح رمز QR';

  @override
  String get qrCameraRationale => 'نحتاج إلى الوصول إلى الكاميرا لمسح رمز QR.';

  @override
  String get qrManualLabel => 'أدخل الرمز يدويًا';

  @override
  String get qrConfirm => 'تأكيد';

  @override
  String get qrCameraDenied =>
      'لم يتم منح إذن الكاميرا. يمكنك إدخال الرمز يدويًا أو منح الإذن ومحاولة المسح مرة أخرى.';

  @override
  String get qrGrantCamera => 'منح إذن الكاميرا';

  @override
  String get qrDeniedSettings =>
      'لم يتم منح إذن الكاميرا. يمكنك السماح به من الإعدادات > BÜ Kampüs أو إدخال الرمز يدويًا.';

  @override
  String get qrCameraFailed => 'تعذر فتح الكاميرا. يمكنك إدخال الرمز يدويًا.';

  @override
  String get qrTorch => 'المصباح';

  @override
  String get pollListTitle => 'الاستطلاعات';

  @override
  String get pollClubPolls => 'استطلاعات النادي';

  @override
  String get pollTabOpen => 'مفتوحة';

  @override
  String get pollTabMine => 'شاركت فيها';

  @override
  String get pollTabClosed => 'المغلقة';

  @override
  String get pollEmptyOpen => 'لا توجد استطلاعات مفتوحة حاليًا.';

  @override
  String get pollEmptyMine => 'لم تشارك في أي استطلاع بعد.';

  @override
  String get pollEmptyClosed => 'لا توجد استطلاعات مغلقة.';

  @override
  String get pollLoadFailedRetry => 'تعذر التحميل، حاول مرة أخرى';

  @override
  String get pollCreate => 'إنشاء استطلاع';

  @override
  String get pollClubEmpty => 'لا توجد استطلاعات لهذا النادي.';

  @override
  String get pollSeeAll => 'عرض كل الاستطلاعات';

  @override
  String get pollMenuRateToday => 'قيّم قائمة اليوم';

  @override
  String pollYourRating(String rating) {
    return 'تقييمك: $rating';
  }

  @override
  String pollYourRatingAvg(String rating, String avg) {
    return 'تقييمك: $rating · المتوسط $avg';
  }

  @override
  String get pollTapStar => 'المس نجمة للتقييم';

  @override
  String get pollNoVoteRight => 'لا يحق لك التصويت في هذا الاستطلاع';

  @override
  String pollStars(String n) {
    return 'النجوم: $n';
  }

  @override
  String pollSemPercent(String text, String pct) {
    return '$text، $pct بالمئة';
  }

  @override
  String pollVotes(String votes) {
    return '$votes صوت';
  }

  @override
  String pollVotesWithScore(String votes, String score) {
    return '$votes صوت · $score نقطة';
  }

  @override
  String get pollSemMine => 'اختيارك';

  @override
  String get pollTypeSingle => 'اختيار واحد';

  @override
  String get pollTypeMulti => 'اختيار متعدد';

  @override
  String get pollTypeRating => 'تقييم';

  @override
  String get pollTypeRanked => 'اختيار مرتب';

  @override
  String get pollAnonymous => 'تصويت سري';

  @override
  String get pollVotedBadge => 'تم تصويتك';

  @override
  String get pollClosedBadge => 'مغلق';

  @override
  String pollParticipants(String n) {
    return '$n مشاركة';
  }

  @override
  String pollParticipationOf(String v, String e) {
    return 'شارك $v من $e';
  }

  @override
  String pollSemPoll(String title) {
    return 'استطلاع: $title';
  }

  @override
  String get pollEnded => 'انتهى';

  @override
  String pollDaysLeft(String n) {
    return 'متبقي $n يوم';
  }

  @override
  String pollHoursLeft(String n) {
    return 'متبقي $n س';
  }

  @override
  String pollMinutesLeft(String n) {
    return 'متبقي $n د';
  }

  @override
  String get pollBlockedNotEligible =>
      'ليس لديك صلاحية المشاركة في هذا الاستطلاع.';

  @override
  String get pollBlockedClosed => 'هذا الاستطلاع مغلق. لا يمكن التصويت.';

  @override
  String get pollBlockedNotOpen => 'لم يُفتح هذا الاستطلاع بعد.';

  @override
  String get pollBlockedAlreadyVoted =>
      'تم حفظ صوتك؛ لا يمكن تغيير الصوت في هذا الاستطلاع.';

  @override
  String get pollBlockedDefault => 'لا يمكنك التصويت في هذا الاستطلاع.';

  @override
  String get pollValTitle => 'العنوان مطلوب.';

  @override
  String get pollValMin2 => 'أدخل خيارين على الأقل.';

  @override
  String get pollValMax12 => 'الحد الأقصى 12 خيارًا.';

  @override
  String get pollValDistinct => 'يجب أن تكون الخيارات مختلفة.';

  @override
  String get pollValEnd => 'اختر وقت الانتهاء.';

  @override
  String get pollValFuture => 'يجب أن يكون وقت الانتهاء في المستقبل.';

  @override
  String get pollErrClosed => 'هذا الاستطلاع مغلق.';

  @override
  String get pollErrAlreadyVoted => 'تم تسجيل صوتك في هذا الاستطلاع مسبقًا.';

  @override
  String get pollErrForbidden => 'ليس لديك صلاحية لهذا الإجراء.';

  @override
  String get pollErrNotFound => 'لم يتم العثور على الاستطلاع.';

  @override
  String get pollErrInvalidVote => 'اختيار غير صالح.';

  @override
  String get pollHeader => 'استطلاع';

  @override
  String get pollStale => 'تعذر التحديث؛ يتم عرض آخر بيانات معروفة.';

  @override
  String get pollVoteSaved => 'تم حفظ صوتك.';

  @override
  String get pollVoteRetracted => 'تم سحب صوتك.';

  @override
  String get pollRetractTitle => 'سحب الصوت';

  @override
  String get pollRetractBody => 'سيتم حذف صوتك. هل تريد المتابعة؟';

  @override
  String get pollCancel => 'إلغاء';

  @override
  String get pollRetractAction => 'سحب';

  @override
  String pollMaxChoicesSnack(String n) {
    return 'الحد الأقصى للخيارات: $n.';
  }

  @override
  String get pollSecretVote => 'صوتك سري';

  @override
  String get pollResultsAfterClose => 'ستظهر النتائج عند إغلاق الاستطلاع.';

  @override
  String get pollHintRanked =>
      'المس الخيارات بترتيب الأفضلية؛ أول خيار تلمسه هو الأول.';

  @override
  String pollHintMax(String n) {
    return 'الحد الأقصى للاختيار: $n.';
  }

  @override
  String get pollHintMulti => 'يمكنك اختيار أكثر من خيار.';

  @override
  String get pollVoteUpdate => 'تحديث الصوت';

  @override
  String get pollVote => 'صوّت';

  @override
  String get pollChangeVote => 'تغيير الصوت';

  @override
  String pollRatingCount(String n) {
    return '$n تقييم';
  }

  @override
  String get pollFieldTitle => 'العنوان';

  @override
  String get pollTitleHint => 'مثال: انتخاب رئيس الفترة الجديدة';

  @override
  String get pollFieldDesc => 'الوصف (اختياري)';

  @override
  String get pollDescHint => 'وصف قصير';

  @override
  String get pollFieldType => 'النوع';

  @override
  String pollFieldOptions(String max) {
    return 'الخيارات (2-$max)';
  }

  @override
  String pollOptionHint(String n) {
    return 'الخيار $n';
  }

  @override
  String get pollRemoveOption => 'حذف الخيار';

  @override
  String get pollAddOption => 'إضافة خيار';

  @override
  String get pollAnonymousSub => 'لا يظهر لأحد من صوّت لأي خيار.';

  @override
  String get pollFieldEnd => 'وقت الانتهاء';

  @override
  String pollDurDays(String n) {
    return '$n يوم';
  }

  @override
  String get pollPickDateTime => 'اختر التاريخ والوقت';

  @override
  String get pollChange => 'تغيير';

  @override
  String get pollPublish => 'نشر';

  @override
  String get postComposeErrBadResponse => 'استجابة غير متوقعة من الخادم.';

  @override
  String get postComposeErrPrepare => 'تعذر تجهيز الوسائط.';

  @override
  String get postComposeErrImageTooLarge => 'الصورة كبيرة جدًا.';

  @override
  String get postComposeErrImageUnsupported => 'صيغة هذه الصورة غير مدعومة.';

  @override
  String get postComposeErrImageUnreadable => 'تعذرت قراءة الصورة.';

  @override
  String get postComposeErrNetwork => 'لا يوجد اتصال، حاول مرة أخرى.';

  @override
  String get postComposeErrVideoTooLarge =>
      'الفيديو كبير جدًا (الحد الأقصى 40 ميغابايت).';

  @override
  String get postComposeErrVideoTooLong => 'يجب ألا يتجاوز الفيديو 60 ثانية.';

  @override
  String get postComposeErrVideoInvalid => 'صيغة الفيديو غير مدعومة.';

  @override
  String get postComposeErrBlocked => 'لا يمكن مشاركة هذا المحتوى.';

  @override
  String get postComposeErrMediaInvalid => 'الوسائط غير صالحة، أعد رفعها.';

  @override
  String get postComposeErrProfanity =>
      'لا يُسمح بالألفاظ غير اللائقة هنا. يرجى تعديل النص.';

  @override
  String get postComposeErrRate => 'أنت تنشر بسرعة كبيرة، انتظر قليلًا.';

  @override
  String get postComposeErrFileTooLarge => 'الملف كبير جدًا.';

  @override
  String get postComposeErrGeneric => 'حدث خطأ، حاول مرة أخرى.';

  @override
  String get postComposeErrVideoUnsupported =>
      'لا يمكن تجهيز الفيديو على هذا الجهاز.';

  @override
  String get postComposeErrCancelled => 'تم الإلغاء.';

  @override
  String get postComposeErrVideoFailed => 'تعذر تجهيز الفيديو.';

  @override
  String get postComposeEdit => 'تعديل';

  @override
  String get postComposeDelete => 'حذف';

  @override
  String get postComposeViewProfile => 'عرض الملف الشخصي';

  @override
  String get postComposeReport => 'إبلاغ';

  @override
  String get postComposeBlockUser => 'حظر هذا المستخدم';

  @override
  String get postComposeClose => 'إغلاق';

  @override
  String get postComposeReportTitle => 'الإبلاغ عن المنشور';

  @override
  String get postComposeDeleteTitle => 'هل تريد حذف المنشور؟';

  @override
  String get postComposeDeleteBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get postComposeCancel => 'إلغاء';

  @override
  String get postComposeDeleted => 'تم حذف المنشور';

  @override
  String get postComposeBlockTitle => 'هل تريد حظر المستخدم؟';

  @override
  String get postComposeBlockBody =>
      'لن ترى منشورات من تحظره ولن تتمكن من مراسلته.';

  @override
  String get postComposeBlock => 'حظر';

  @override
  String get postComposeBlocked => 'تم حظر المستخدم';

  @override
  String get postComposeEditTitle => 'تعديل المنشور';

  @override
  String get postComposeTextEmpty => 'لا يمكن أن يكون النص فارغًا.';

  @override
  String get postComposeProfanityFallback => 'يحتوي النص على ألفاظ غير لائقة.';

  @override
  String get postComposeHint => 'ماذا يدور في بالك؟';

  @override
  String get postComposeSave => 'حفظ';

  @override
  String get postComposeMore => 'المزيد';

  @override
  String postComposeMaxMedia(String max) {
    return 'الحد الأقصى للوسائط: $max';
  }

  @override
  String postComposeFailedCount(String count) {
    return 'تعذر رفع $count من الوسائط. يمكنك إعادة المحاولة أو إزالتها.';
  }

  @override
  String get postComposeInvalidRetry =>
      'الوسائط غير صالحة وسيعاد رفعها. المس مشاركة مرة أخرى.';

  @override
  String get postComposeNetworkDraftKept =>
      'لا يوجد اتصال. تم حفظ مسودتك، حاول مرة أخرى.';

  @override
  String get postComposeShared => 'تمت المشاركة';

  @override
  String get postComposeDiscardTitle => 'هل تريد حذف المسودة؟';

  @override
  String get postComposeDiscardBody =>
      'سيتم حذف ما كتبته والوسائط التي اخترتها.';

  @override
  String get postComposeContinue => 'متابعة';

  @override
  String get postComposeDiscardDraft => 'حذف المسودة';

  @override
  String get postComposeNewPost => 'منشور جديد';

  @override
  String get postComposeShare => 'مشاركة';

  @override
  String get postComposeDraftBanner => 'لديك مسودة محفوظة.';

  @override
  String get postComposeRestoreDraft => 'استعادة المسودة';

  @override
  String get postComposeRetry => 'إعادة المحاولة';

  @override
  String get postComposeRemoveFailed => 'إزالة الفاشلة';

  @override
  String get postComposeRemove => 'إزالة';

  @override
  String get postComposeGallery => 'المعرض';

  @override
  String get postComposeCamera => 'الكاميرا';

  @override
  String get postComposeSaveUnsupported => 'غير مدعوم على هذا الجهاز.';

  @override
  String get postComposeSaveDenied => 'لم يتم منح إذن المعرض.';

  @override
  String get postComposeSaveNoSpace => 'لا توجد مساحة كافية على الجهاز.';

  @override
  String get postComposeImageSaveFailed => 'تعذر حفظ الصورة.';

  @override
  String get postComposeSavedToGallery => 'تم الحفظ في المعرض';

  @override
  String get postComposeDownload => 'تنزيل';

  @override
  String get postComposeImageLoadFailed => 'تعذر تحميل الصورة.';

  @override
  String get postComposeVideoPlayFailed => 'تعذر تشغيل الفيديو';

  @override
  String postComposeVideoOf(String n, String total) {
    return 'فيديو $n / $total';
  }

  @override
  String postComposePhotoOf(String n, String total) {
    return 'صورة $n / $total';
  }

  @override
  String postComposeVideoOfMore(String n, String total, String more) {
    return 'فيديو $n / $total، +$more أخرى';
  }

  @override
  String postComposePhotoOfMore(String n, String total, String more) {
    return 'صورة $n / $total، +$more أخرى';
  }

  @override
  String get postComposeVideo => 'فيديو';

  @override
  String get postComposePhoto => 'صورة';

  @override
  String get postComposePlayVideo => 'تشغيل الفيديو';

  @override
  String get postComposeUnmute => 'تشغيل الصوت';

  @override
  String get postComposeMute => 'كتم الصوت';

  @override
  String postComposeMentionAdd(String name) {
    return 'إضافة إشارة $name';
  }

  @override
  String postComposeTagAdd(String tag) {
    return 'إضافة وسم $tag';
  }

  @override
  String postComposePostCount(String count) {
    return '$count منشور';
  }

  @override
  String postComposeUserLabel(String name) {
    return 'المستخدم $name';
  }

  @override
  String postComposeTagLabel(String tag) {
    return 'وسم $tag';
  }

  @override
  String postComposeTagLabelCount(String tag, String count) {
    return 'وسم $tag، $count منشور';
  }

  @override
  String postViewReplyingTo(String name) {
    return 'رد على @$name';
  }

  @override
  String get postViewCancelReply => 'إلغاء الرد';

  @override
  String get postViewWriteReplyHint => 'اكتب ردك…';

  @override
  String get postViewWriteCommentHint => 'اكتب تعليقًا…';

  @override
  String get postViewSend => 'إرسال';

  @override
  String get postViewAgoNow => 'الآن';

  @override
  String postViewAgoMin(String n) {
    return '$n د';
  }

  @override
  String postViewAgoHour(String n) {
    return '$n س';
  }

  @override
  String postViewAgoDay(String n) {
    return '$n ي';
  }

  @override
  String postViewAgoWeek(String n) {
    return '$n أسبوع';
  }

  @override
  String postViewAgoYear(String n) {
    return '$n سنة';
  }

  @override
  String postViewAgoMinFull(String n) {
    return 'منذ $n دقيقة';
  }

  @override
  String postViewAgoHourFull(String n) {
    return 'منذ $n ساعة';
  }

  @override
  String postViewAgoDayFull(String n) {
    return 'منذ $n يوم';
  }

  @override
  String get postViewRepliesLoadFailed => 'تعذر تحميل الردود · أعد المحاولة';

  @override
  String postViewShowReplies(String n) {
    return 'عرض $n من الردود';
  }

  @override
  String get postViewShowMoreReplies => 'عرض المزيد من الردود';

  @override
  String get postViewHideReplies => 'إخفاء الردود';

  @override
  String get postViewCommentsLoadFailed =>
      'تعذر تحميل التعليقات · أعد المحاولة';

  @override
  String get postViewCommentsLoading => 'جارٍ تحميل التعليقات';

  @override
  String get postViewEdit => 'تعديل';

  @override
  String get postViewDelete => 'حذف';

  @override
  String get postViewReport => 'إبلاغ';

  @override
  String get postViewReportComment => 'الإبلاغ عن التعليق';

  @override
  String get postViewDeleteCommentTitle => 'هل تريد حذف التعليق؟';

  @override
  String get postViewCannotUndo => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get postViewCancelAction => 'تراجع';

  @override
  String get postViewCommentDeleted => 'تم حذف هذا التعليق';

  @override
  String get postViewEdited => 'معدّل';

  @override
  String postViewProfileOf(String name) {
    return 'ملف $name';
  }

  @override
  String get postViewSendFailedRetryA11y => 'تعذر الإرسال، أعد المحاولة';

  @override
  String get postViewSendFailedRetry => 'تعذر الإرسال · أعد المحاولة';

  @override
  String get postViewRemove => 'إزالة';

  @override
  String get postViewSending => 'جارٍ الإرسال…';

  @override
  String postViewReplyToA11y(String name) {
    return 'الرد على $name';
  }

  @override
  String get postViewReply => 'رد';

  @override
  String get postViewCommentOptions => 'خيارات التعليق';

  @override
  String get postViewEditCommentHint => 'عدّل التعليق';

  @override
  String get postViewCancel => 'إلغاء';

  @override
  String get postViewSave => 'حفظ';

  @override
  String postViewLikersWithCount(String n) {
    return 'الإعجابات ($n)';
  }

  @override
  String get postViewLikers => 'الإعجابات';

  @override
  String get postViewRetry => 'أعد المحاولة';

  @override
  String get postViewNoLikers => 'لا توجد إعجابات بعد';

  @override
  String get postViewUser => 'مستخدم';

  @override
  String get postViewLikeFailed => 'تعذر حفظ الإعجاب';

  @override
  String get postViewUnlike => 'إلغاء الإعجاب';

  @override
  String get postViewLike => 'إعجاب';

  @override
  String get postViewSavedAdded => 'تمت الإضافة إلى المحفوظات';

  @override
  String get postViewSavedRemoved => 'تمت الإزالة من المحفوظات';

  @override
  String get postViewUnsave => 'إزالة من المحفوظات';

  @override
  String postViewNoTagPosts(String tag) {
    return 'لا توجد منشورات بالوسم #$tag.';
  }

  @override
  String get postViewSavedPostsTitle => 'المنشورات المحفوظة';

  @override
  String get postViewNoSavedPosts => 'لم تحفظ أي منشور بعد.';

  @override
  String get postViewPosts => 'المنشورات';

  @override
  String get postViewSeeAll => 'عرض الكل';

  @override
  String get postViewPost => 'منشور';

  @override
  String get postViewMyPosts => 'منشوراتي';

  @override
  String get postViewNoPosts => 'لا توجد منشورات بعد';

  @override
  String get postViewReadMore => 'اقرأ المزيد';

  @override
  String get postViewReportSent => 'تم إرسال بلاغك.';

  @override
  String get postViewMore => 'المزيد';

  @override
  String get postViewFeedEmpty => 'لا توجد منشورات بعد. كن أول من يشارك!';

  @override
  String postViewCommentsWithCount(String n) {
    return 'التعليقات ($n)';
  }

  @override
  String get postViewComments => 'التعليقات';

  @override
  String get postViewSortNew => 'الأحدث';

  @override
  String get postViewSortTop => 'الأعلى';

  @override
  String get postViewFirstComment => 'كن أول من يعلق';

  @override
  String get profileDeptRequired => 'اختر القسم.';

  @override
  String get profileDiscardTitle => 'لم يتم حفظ التغييرات';

  @override
  String get profileDiscardBody => 'إذا خرجت فستفقد التغييرات التي أجريتها.';

  @override
  String get profileKeepEditing => 'متابعة التعديل';

  @override
  String get profileDiscardExit => 'تجاهل والخروج';

  @override
  String get profileChangePhotoSemantic => 'تغيير صورة الملف الشخصي';

  @override
  String get profileUploading => 'جارٍ الرفع…';

  @override
  String get profileChangePhoto => 'تغيير الصورة';

  @override
  String get profilePickGallery => 'اختيار من المعرض';

  @override
  String get profileTakePhoto => 'التقاط صورة';

  @override
  String get profileRemovePhoto => 'إزالة الصورة';

  @override
  String get profilePhotoTooLargeHint =>
      'الحد الأقصى لحجم الصورة 2 ميغابايت. اختر صورة أصغر.';

  @override
  String get profilePhotoUnsupported => 'يمكن رفع صور JPG أو PNG أو WebP فقط.';

  @override
  String get profilePhotoUnreadable => 'تعذرت قراءة الملف المحدد.';

  @override
  String get profilePhotoTooLarge => 'الحد الأقصى لحجم الصورة 2 ميغابايت.';

  @override
  String get profileEditTitle => 'تعديل الملف الشخصي';

  @override
  String get profileFullName => 'الاسم الكامل';

  @override
  String get profileNameMin => 'يجب أن يتكون الاسم من حرفين على الأقل.';

  @override
  String get profileAbout => 'نبذة عني';

  @override
  String get profileBioHint => 'عرّف بنفسك باختصار';

  @override
  String get profileShowEmail => 'إظهار بريدي الإلكتروني للمستخدمين الآخرين';

  @override
  String get profileSave => 'حفظ';

  @override
  String get profileUserDefault => 'مستخدم';

  @override
  String profileGradeYear(String year) {
    return 'السنة $year';
  }

  @override
  String get profileBlockTitle => 'هل تريد حظر هذا المستخدم؟';

  @override
  String get profileBlockBody => 'لن تتمكن من مراسلة الأشخاص الذين تحظرهم.';

  @override
  String get profileCancel => 'إلغاء';

  @override
  String get profileBlock => 'حظر';

  @override
  String get profileUnblock => 'إلغاء الحظر';

  @override
  String get profileUnblocked => 'تم إلغاء الحظر';

  @override
  String get profileBlocked => 'تم حظر المستخدم';

  @override
  String get profileReportUser => 'الإبلاغ عن المستخدم';

  @override
  String get profileOnline => 'متصل';

  @override
  String profileLastSeenToday(String time) {
    return 'آخر ظهور اليوم $time';
  }

  @override
  String profileLastSeenYesterday(String time) {
    return 'آخر ظهور أمس $time';
  }

  @override
  String profileLastSeenDate(String date, String time) {
    return 'آخر ظهور $date $time';
  }

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileNotFound => 'المستخدم غير موجود';

  @override
  String get profileFaculty => 'الكلية';

  @override
  String get profileDepartment => 'القسم';

  @override
  String get profileGrade => 'السنة الدراسية';

  @override
  String get profileEmail => 'البريد الإلكتروني';

  @override
  String get profileMessage => 'رسالة';

  @override
  String get profileReport => 'إبلاغ';

  @override
  String get profileAboutShort => 'نبذة';

  @override
  String get profileSignOutTitle => 'هل تريد تسجيل الخروج؟';

  @override
  String get profileSignOutBody => 'سيتم إنهاء جلستك على هذا الجهاز.';

  @override
  String get profileSignOut => 'تسجيل الخروج';

  @override
  String get profileSettings => 'الإعدادات';

  @override
  String get profileStatClubs => 'النوادي';

  @override
  String get profileStatEvents => 'الفعاليات';

  @override
  String get profileStatSavedNews => 'الأخبار المحفوظة';

  @override
  String get profileMyPosts => 'منشوراتي';

  @override
  String get profileSavedPosts => 'المنشورات المحفوظة';

  @override
  String get profileSuggested => 'أشخاص مقترحون';

  @override
  String get profileSaved => 'المحفوظات';

  @override
  String get profileAcademic => 'الأكاديمي';

  @override
  String get profileMyEvents => 'فعالياتي';

  @override
  String get profileMyClubs => 'أنديتي';

  @override
  String get profileReminders => 'تذكيرات المحاضرات والامتحانات';

  @override
  String get profileSavedEmpty =>
      'لم تحفظ أي خبر بعد. المس أيقونة الإشارة المرجعية في الأخبار.';

  @override
  String get profileRetry => 'أعد المحاولة';

  @override
  String profileNewsCount(String count) {
    return '$count خبر';
  }

  @override
  String profileNewsCountMore(String count) {
    return '$count+ خبر';
  }

  @override
  String get profileLegalTitle => 'الاتفاقيات';

  @override
  String get profileLegalEmpty => 'لا توجد اتفاقيات منشورة.';

  @override
  String get profileLegalDocFallback => 'الاتفاقية';

  @override
  String profileVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String profileVersionDate(String version, String date) {
    return 'الإصدار $version · $date';
  }

  @override
  String get profilePrefsDataCopied => 'تم نسخ بياناتك إلى الحافظة';

  @override
  String get profilePrefsExportLimit =>
      'يمكنك تنزيل بياناتك 3 مرات كحد أقصى في اليوم.';

  @override
  String get profilePrefsBlockedUsers => 'المستخدمون المحظورون';

  @override
  String get profilePrefsLegalPrivacy => 'الاتفاقيات والخصوصية';

  @override
  String get profilePrefsDownloadData => 'تنزيل بياناتي';

  @override
  String get profilePrefsAccountMgmt => 'إدارة الحساب';

  @override
  String get profilePrefsDeleteMyAccount => 'حذف حسابي';

  @override
  String get profilePrefsEnterPassword => 'أدخل كلمة المرور.';

  @override
  String get profilePrefsWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String get profilePrefsDeleteAccountTitle => 'حذف الحساب';

  @override
  String get profilePrefsDeleteAccountBody =>
      'سيتم حذف حسابك وبياناتك الشخصية. لا يمكن التراجع عن هذا الإجراء. أدخل كلمة المرور للتأكيد.';

  @override
  String get profilePrefsPassword => 'كلمة المرور';

  @override
  String get profilePrefsClubLeft => 'لقد غادرت النادي.';

  @override
  String get profilePrefsWithdrawTitle => 'سحب الطلب';

  @override
  String get profilePrefsWithdrawBody => 'هل تريد سحب طلب الانضمام؟';

  @override
  String get profilePrefsWithdrawConfirm => 'سحب';

  @override
  String get profilePrefsNoClubs => 'لست عضوًا في أي نادٍ بعد.';

  @override
  String get profilePrefsClubsOwned => 'التي أسستها';

  @override
  String get profilePrefsClubsMember => 'عضويتي';

  @override
  String get profilePrefsClubsPending => 'الطلبات المعلقة';

  @override
  String get profilePrefsMyClubs => 'أنديتي';

  @override
  String get profilePrefsCreateClub => 'تأسيس نادٍ';

  @override
  String profilePrefsMembersCount(String count) {
    return '$count عضو';
  }

  @override
  String get profilePrefsAwaitingApproval => 'بانتظار الموافقة';

  @override
  String get profilePrefsAwaitingPublish => 'بانتظار موافقة النشر';

  @override
  String get profilePrefsManage => 'إدارة';

  @override
  String get profilePrefsOptions => 'خيارات';

  @override
  String get profilePrefsOpen => 'فتح';

  @override
  String get profilePrefsManageEdit => 'إدارة: تعديل';

  @override
  String get profilePrefsManageRequests => 'إدارة: الطلبات';

  @override
  String get profilePrefsManageMembers => 'إدارة: الأعضاء';

  @override
  String get profilePrefsLeaveClub => 'مغادرة النادي';

  @override
  String get profilePrefsReminders => 'تذكيرات المحاضرات والامتحانات';

  @override
  String get profilePrefsNotifNews => 'الأخبار';

  @override
  String get profilePrefsNotifAnnouncements => 'الإعلانات';

  @override
  String get profilePrefsNotifEvents => 'الفعاليات';

  @override
  String get profilePrefsNotifCommunities => 'الأندية';

  @override
  String get profilePrefsNotifMessages => 'الرسائل';

  @override
  String get profilePrefsNotifPolls => 'الاستطلاعات';

  @override
  String get profilePrefsNotifAcademic => 'الإعلانات الأكاديمية';

  @override
  String get profilePrefsNotifStories => 'القصص';

  @override
  String get profilePrefsNotifMention => 'الإشارات';

  @override
  String get profilePrefsNotifFollow => 'متابعون جدد';

  @override
  String get profilePrefsNotifLike => 'الإعجابات بالمنشورات';

  @override
  String get profilePrefsNotifComment => 'التعليقات على المنشورات';

  @override
  String get profilePrefsNotifReply => 'الردود على التعليقات';

  @override
  String get profilePrefsSocial => 'اجتماعي';

  @override
  String get profilePrefsOnThisDevice => 'على هذا الجهاز';

  @override
  String profilePrefsTapToRetry(String error) {
    return '$error المس للمحاولة مرة أخرى.';
  }

  @override
  String get profilePrefsNotifTitle => 'الإشعارات';

  @override
  String get profilePrefsNoBlocked => 'لم تحظر أي مستخدم.';

  @override
  String get profilePrefsUser => 'مستخدم';

  @override
  String get profilePrefsUnblock => 'إلغاء الحظر';

  @override
  String get profilePrefsBlockedTitle => 'المحظورون';

  @override
  String get pickDepartment => 'القسم';

  @override
  String get pickSelectDepartment => 'اختر القسم';

  @override
  String get pickLoading => 'جارٍ التحميل…';

  @override
  String get pickListFailed => 'تعذر تحميل قائمة الأقسام.';

  @override
  String get pickRetry => 'إعادة المحاولة';

  @override
  String get pickGrade => 'السنة الدراسية';

  @override
  String get pickSelectGrade => 'اختر السنة الدراسية';

  @override
  String get pickSearch => 'بحث';

  @override
  String get pickNoResults => 'لا توجد نتائج.';

  @override
  String authStepOf(String n, String total) {
    return 'الخطوة $n من $total';
  }

  @override
  String get authSectionPersonal => 'المعلومات الشخصية';

  @override
  String get authSectionPassword => 'عيّن كلمة مرور';

  @override
  String get authHintAcademic => 'اختر قسمك وسنتك الدراسية.';

  @override
  String get authHintPersonal => 'أدخل اسمك وبريدك الجامعي.';

  @override
  String get authHintPassword => 'اختر كلمة مرور من 8 أحرف على الأقل.';

  @override
  String get authNext => 'متابعة';

  @override
  String get authTermsAutoPrefix => 'بالتسجيل، فإنك توافق على ';

  @override
  String get authTermsAutoSuffix => '.';

  @override
  String get authPwMinErr => 'يجب ألا تقل كلمة المرور عن 8 أحرف.';

  @override
  String get authPwMaxErr => 'يجب ألا تزيد كلمة المرور عن 72 حرفًا.';

  @override
  String get authIdHelper => '226051015 أو name.surname@bingol.edu.tr';

  @override
  String get supportCatAccount => 'الحساب';

  @override
  String get supportCatTechnical => 'تقني';

  @override
  String get supportCatContent => 'المحتوى';

  @override
  String get supportCatOther => 'أخرى';

  @override
  String get supportFbBug => 'خطأ';

  @override
  String get supportFbSuggestion => 'اقتراح';

  @override
  String get supportFbComplaint => 'شكوى';

  @override
  String get supportFbPraise => 'شكر';

  @override
  String get supportStNew => 'جديد';

  @override
  String get supportStInReview => 'قيد المراجعة';

  @override
  String get supportStPlanned => 'مخطط له';

  @override
  String get supportStDone => 'مكتمل';

  @override
  String get supportStRejected => 'مرفوض';

  @override
  String get supportStatusAnswered => 'تم الرد';

  @override
  String get supportStatusClosed => 'مغلق';

  @override
  String get supportStatusOpen => 'مفتوح';

  @override
  String get supportTooManyRequests =>
      'لقد أرسلت طلبات كثيرة. يرجى الانتظار قليلًا ثم المحاولة مرة أخرى.';

  @override
  String get supportLabelCategory => 'الفئة';

  @override
  String get supportLabelSubject => 'الموضوع';

  @override
  String get supportLabelMessage => 'الرسالة';

  @override
  String get supportLabelMine => 'ما أرسلته';

  @override
  String get supportHintSubject => 'الموضوع باختصار';

  @override
  String get supportHintFeedback => 'اكتب رأيك';

  @override
  String get supportHintIssue => 'اشرح مشكلتك';

  @override
  String get supportHintReply => 'اكتب ردًا';

  @override
  String get supportFillFields => 'يرجى ملء حقلي الموضوع والرسالة.';

  @override
  String get supportFeedbackThanks => 'شكرًا على ملاحظاتك.';

  @override
  String get supportFeedbackTitle => 'ملاحظات';

  @override
  String get supportSend => 'إرسال';

  @override
  String get supportNoFeedback => 'لم ترسل أي ملاحظات بعد.';

  @override
  String get supportMore => 'المزيد';

  @override
  String get supportTicketReceived => 'تم استلام طلب الدعم الخاص بك.';

  @override
  String get supportNewTicketTitle => 'طلب جديد';

  @override
  String get supportTitle => 'الدعم';

  @override
  String get supportFaqLabel => 'الأسئلة الشائعة';

  @override
  String get supportMyTickets => 'طلباتي';

  @override
  String get supportShareLabel => 'شاركنا رأيك';

  @override
  String get supportBoard => 'لوحة الاقتراحات';

  @override
  String get supportCreateTicket => 'إنشاء طلب دعم';

  @override
  String get supportNoFaq => 'لا توجد أسئلة شائعة بعد.';

  @override
  String get supportRetry => 'إعادة المحاولة';

  @override
  String get supportNoTickets => 'ليس لديك طلبات دعم بعد.';

  @override
  String get supportSortTop => 'الأكثر تصويتًا';

  @override
  String get supportSortNew => 'الأحدث';

  @override
  String get supportAddSuggestion => 'إضافة اقتراح';

  @override
  String get supportNoSuggestions =>
      'لا توجد اقتراحات منشورة بعد. كن أول من يضيف اقتراحًا.';

  @override
  String get supportCloseTicketTitle => 'إغلاق الطلب';

  @override
  String get supportCloseTicketBody =>
      'سيتم إغلاق هذا الطلب ولن تتمكن من كتابة ردود جديدة. هل تريد المتابعة؟';

  @override
  String get supportCancel => 'إلغاء';

  @override
  String get supportClose => 'إغلاق';

  @override
  String get supportTicketTitle => 'الطلب';

  @override
  String get supportTicketClosedNote => 'تم إغلاق هذا الطلب.';

  @override
  String get supportStaff => 'فريق الدعم';

  @override
  String get storyVideoTooLong => 'يجب ألا يزيد فيديو القصة عن 30 ثانية.';

  @override
  String get storyCreateTitle => 'إنشاء قصة';

  @override
  String get storyShare => 'مشاركة';

  @override
  String get storyModeMedia => 'صورة / فيديو';

  @override
  String get storyModeText => 'نص';

  @override
  String get storyVisible24 => 'تظهر قصتك لمدة 24 ساعة';

  @override
  String get storyGallery => 'المعرض';

  @override
  String get storyCamera => 'الكاميرا';

  @override
  String get storyCaptionHint => 'أضف وصفًا…';

  @override
  String get storyTextHint => 'اكتب شيئًا…';

  @override
  String storyBgColor(String n) {
    return 'لون الخلفية $n';
  }

  @override
  String get storyYours => 'قصتك';

  @override
  String storyNewSemantics(String name) {
    return '$name، قصة جديدة';
  }

  @override
  String storySemantics(String name) {
    return '$name، قصة';
  }

  @override
  String get storyDeleteTitle => 'هل تريد حذف القصة؟';

  @override
  String get storyDeleteBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get storyCancel => 'إلغاء';

  @override
  String get storyDelete => 'حذف';

  @override
  String get storyRetry => 'إعادة المحاولة';

  @override
  String get storyClose => 'إغلاق';

  @override
  String storyViewsSemantics(String count) {
    return '$count مشاهدة، عرض المشاهدين';
  }

  @override
  String get storyDeleteTooltip => 'حذف القصة';

  @override
  String storyBarSemantics(String index, String total) {
    return 'القصة $index / $total';
  }

  @override
  String get storyNoViewers => 'لم يشاهدها أحد بعد.';

  @override
  String storyViewersTitle(String count) {
    return 'المشاهدون ($count)';
  }

  @override
  String get authForgotSub => 'أدخل بريدك الجامعي وسنرسل لك رمزًا من 6 أرقام.';

  @override
  String get authBackToLogin => 'العودة لتسجيل الدخول';

  @override
  String get authChangeEmail => 'تغيير البريد الإلكتروني';

  @override
  String get authNewPwSub =>
      'ستحل محل كلمة المرور القديمة. سيتم إنهاء الجلسات على جميع الأجهزة.';

  @override
  String get authRuleLen => '8 أحرف على الأقل';

  @override
  String get authRuleMix => 'تحتوي على أحرف وأرقام';

  @override
  String get authStep1Title => 'في أي قسم أنت؟';

  @override
  String get authStep2Title => 'لنتعرف عليك';

  @override
  String get welcomeHeadline => 'الحرم الجامعي\nفي جيبك';

  @override
  String get welcomeSub =>
      'الإعلانات وقائمة الطعام والأندية والفعاليات في تطبيق واحد.';

  @override
  String get welcomeNews => 'الأخبار والإعلانات';

  @override
  String get welcomeMenu => 'قائمة طعام اليوم';

  @override
  String get welcomeClubs => 'الأندية والفعاليات';

  @override
  String get welcomeNote => 'التسجيل متاح فقط بالبريد الجامعي (bingol.edu.tr).';

  @override
  String get welcomeLanguage => 'اللغة';

  @override
  String get chatlistSearchHint => 'ابحث في المحادثات';

  @override
  String get bildirimFilterAll => 'الكل';

  @override
  String get bildirimFilterUnread => 'غير المقروءة';

  @override
  String get bildirimEmptyUnread => 'لا توجد إشعارات غير مقروءة';

  @override
  String get bildirimAllCaughtUp => 'هذا كل شيء';

  @override
  String get bildirimSwipeHint => 'اسحب الإشعار لحذفه';

  @override
  String get bildirimDelete => 'حذف';

  @override
  String bildirimShortMin(String n) {
    return '$n د';
  }

  @override
  String bildirimShortHour(String n) {
    return '$n س';
  }

  @override
  String bildirimShortDay(String n) {
    return '$n ي';
  }

  @override
  String get bildirimYesterday => 'أمس';

  @override
  String get bildirimTypeNews => 'خبر';

  @override
  String get bildirimTypeAnnouncement => 'إعلان';

  @override
  String get bildirimTypeEvent => 'فعالية';

  @override
  String get bildirimTypeMessage => 'محادثة';

  @override
  String get bildirimTypeCommunity => 'نادٍ';

  @override
  String get bildirimTypePoll => 'استطلاع';

  @override
  String get bildirimTypePost => 'منشور';

  @override
  String get bildirimTypeOther => 'إشعار';

  @override
  String get acadhubNextExam => 'الامتحان القادم';

  @override
  String get acadhubUpcoming => 'التواريخ القادمة';

  @override
  String get acadhubCalendarLink => 'التقويم';

  @override
  String get acadhubNoUpcoming => 'لا توجد تواريخ قادمة';

  @override
  String get kuluplerAllClubs => 'جميع الأندية';

  @override
  String get kesfetSubtitle => 'منشورات من الطلاب';

  @override
  String get kesfetSearchHint => 'ابحث عن منشورات أو أشخاص';

  @override
  String get profil2PrivacyTitle => 'الخصوصية والمحظورون';

  @override
  String get profil2PrivacyIntro =>
      'اختر من يمكنه رؤية كل جزء من ملفك الشخصي. أنت ترى ملفك الشخصي كاملًا دائمًا.';

  @override
  String get profil2VisibilitySection => 'ظهور الملف الشخصي';

  @override
  String get profil2FieldAvatar => 'الصورة الشخصية';

  @override
  String get profil2FieldBio => 'نبذة عني';

  @override
  String get profil2FieldFaculty => 'الكلية';

  @override
  String get profil2FieldDepartment => 'القسم';

  @override
  String get profil2FieldClassYear => 'السنة الدراسية';

  @override
  String get profil2VisEveryone => 'الجميع';

  @override
  String get profil2VisShared => 'سياق مشترك';

  @override
  String get profil2VisOnlyMe => 'أنا فقط';

  @override
  String get profil2SharedHintLead => 'السياق المشترك:';

  @override
  String get profil2SharedHintBody =>
      'الأشخاص الذين تشترك معهم في نادٍ أو محادثة أو فعالية.';

  @override
  String get profil2ShowEmail => 'إظهار بريدي الإلكتروني في ملفي';

  @override
  String get profil2ShowEmailSub => 'عند الإيقاف، أنت فقط من يراه';

  @override
  String get profil2BlockedSection => 'المحظورون';

  @override
  String get profil2BlockedHint => 'لا يستطيع من تحظرهم رؤيتك أو مراسلتك.';

  @override
  String get profil2AvatarModerated => 'تم إخفاء صورتك الشخصية بسبب الإشراف.';

  @override
  String get profil2SaveFailed => 'تعذر حفظ التغيير.';

  @override
  String get profil2MyDataRow => 'بياناتي وحسابي';

  @override
  String get profil2DataTitle => 'بياناتي';

  @override
  String get profil2DataIntro =>
      'يمكنك تنزيل نسخة من بياناتك الشخصية التي نحتفظ بها في التطبيق وفق قانون حماية البيانات الشخصية (KVKK).';

  @override
  String get profil2DataFileSub => 'يتم إعدادها كملف JSON';

  @override
  String get profil2DataContents => 'محتويات الملف';

  @override
  String get profil2DataItemProfile => 'معلومات ملفك الشخصي';

  @override
  String get profil2DataItemPrefs => 'تفضيلات الخصوصية والإشعارات';

  @override
  String get profil2DataItemClubs => 'سجلات النوادي والفعاليات';

  @override
  String get profil2DataItemSaved => 'الأخبار المحفوظة والإشعارات';

  @override
  String get profil2DataItemSupport => 'سجلات الدعم والملاحظات';

  @override
  String get profil2DataLimit =>
      'يمكنك التنزيل حتى 3 مرات يوميًا. احتفظ بالملف بأمان فهو يحتوي على معلومات شخصية.';

  @override
  String get profil2DataOther => 'أخرى';

  @override
  String get profil2DataKvkk => 'إشعار حماية البيانات الشخصية (KVKK)';

  @override
  String get profil2DelWarnLead => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get profil2DelWarnBody =>
      'سيتم إخفاء هوية حسابك ولن تتمكن من تسجيل الدخول مجددًا.';

  @override
  String get profil2DelWhatHappens => 'ماذا سيحدث';

  @override
  String get profil2DelItem1 =>
      'يتم حذف اسمك وبريدك وصورتك ومعلومات ملفك. يبقى الحساب باسم مستخدم محذوف.';

  @override
  String get profil2DelItem2 =>
      'يتم حذف إشعاراتك وأخبارك المحفوظة وسجلات أجهزتك وتفضيلاتك.';

  @override
  String get profil2DelItem3 =>
      'تتم إزالة عضوياتك في النوادي ومشاركاتك في الفعاليات.';

  @override
  String get profil2DelItem4 => 'يتم إغلاق جلساتك على جميع الأجهزة.';

  @override
  String get profil2DelBackupHint => 'إن أردت، يمكنك تنزيل بياناتك قبل الحذف.';

  @override
  String get profil2DelAck =>
      'أفهم أنه سيتم حذف حسابي نهائيًا ولا يمكن التراجع عن ذلك.';

  @override
  String get profil2Continue => 'متابعة';

  @override
  String get profil2DelConfirmTitle => 'تأكيد الحذف';

  @override
  String get profil2DelConfirmBody =>
      'أدخل كلمة المرور للمتابعة. سيتم إخفاء هوية حسابك فورًا وتسجيل خروجك من جميع الأجهزة.';

  @override
  String get profil2SecTitle => 'الحساب والأمان';

  @override
  String get profil2SecEmailFixed => 'لا يمكن تغييره';

  @override
  String get profil2SecVerified => 'تم التحقق';

  @override
  String get profil2SecPwSection => 'تحديث كلمة المرور';

  @override
  String get profil2SecCurrentLabel => 'كلمة المرور الحالية';

  @override
  String get profil2SecCurrentHint => 'كلمة مرورك الحالية';

  @override
  String get profil2SecNewLabel => 'كلمة المرور الجديدة';

  @override
  String get profil2SecNewHint => '8 أحرف على الأقل';

  @override
  String get profil2SecRepeatLabel => 'كلمة المرور الجديدة (تكرار)';

  @override
  String get profil2SecRepeatHint => 'أعد كتابة كلمة المرور الجديدة';

  @override
  String get profil2SecPwRule =>
      'من 8 إلى 72 حرفًا. خلط الحروف والأرقام يجعلها أقوى.';

  @override
  String get profil2SecPwButton => 'تحديث كلمة المرور';

  @override
  String get profil2SecMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get profil2SecSame =>
      'لا يمكن أن تكون كلمة المرور الجديدة مثل الحالية.';

  @override
  String get profil2SecWrongCurrent => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get profil2SecFailed =>
      'تعذر تحديث كلمة المرور. يرجى المحاولة لاحقًا.';

  @override
  String get profil2SecUpdated => 'تم تحديث كلمة المرور.';

  @override
  String get profil2SecSessions => 'الجلسات';

  @override
  String get profil1SecContent => 'محتواي';

  @override
  String get profil1SecAccount => 'الحساب';

  @override
  String get profil1SecApp => 'التطبيق';

  @override
  String get profil1SecSupport => 'الدعم والشؤون القانونية';

  @override
  String get profil1AccountSecurity => 'الحساب والأمان';

  @override
  String get profil1PrivacyBlocked => 'الخصوصية والمحظورون';

  @override
  String get profil1MyData => 'بياناتي';

  @override
  String get profil1Notifications => 'تفضيلات الإشعارات';

  @override
  String get profil1Theme => 'المظهر';

  @override
  String get profil1Support => 'الدعم';

  @override
  String get profil1Legal => 'الاتفاقيات والسياسات';

  @override
  String get profil1CorpEmail => 'البريد الجامعي';

  @override
  String get profil1Remove => 'إزالة';

  @override
  String get profil1PushTitle => 'الإشعارات الفورية';

  @override
  String get profil1PushGranted => 'مسموح على هذا الجهاز';

  @override
  String get profil1PillOff => 'متوقف';

  @override
  String get profil1WhatSection => 'ما الذي يتم إشعارك به';

  @override
  String get profil1NotifClubs => 'الأندية';

  @override
  String get profil1NewsSub => 'أخبار جديدة من الجامعة';

  @override
  String get profil1AnnSub => 'إعلانات مهمة';

  @override
  String get profil1EventsSub => 'تذكيرات وتغييرات وقبول';

  @override
  String get profil1MsgSub => 'المحادثات الفردية والجماعية';

  @override
  String get profil1ClubsSub => 'المنشورات والأدوار والانضمام';

  @override
  String get profil1Detailed => 'تفضيلات مفصلة';

  @override
  String get profil1SubMsgDirect => 'الرسائل الفردية';

  @override
  String get profil1SubMsgGroup => 'رسائل المجموعات';

  @override
  String get profil1SubEventReminder => 'تذكيرات الفعاليات';

  @override
  String get profil1SubEventUpdate => 'تغييرات الفعاليات';

  @override
  String get profil1SubEventAdmission => 'قبول الفعاليات';

  @override
  String get profil1SubClubPost => 'منشورات الأندية';

  @override
  String get profil1SubClubRole => 'تغييرات أدوار النادي';

  @override
  String get profil1SubClubJoin => 'طلبات الانضمام للنادي';

  @override
  String get profil1QuietTitle => 'ساعات الهدوء';

  @override
  String get profil1QuietToggle => 'تفعيل ساعات الهدوء';

  @override
  String get profil1QuietSub => 'لا صوت للإشعارات في هذه الساعات';

  @override
  String get profil1QuietStart => 'البداية';

  @override
  String get profil1QuietEnd => 'النهاية';

  @override
  String get sohbetmedyaNext => 'التالي';

  @override
  String sohbetmedyaSelectedOf(String n, String max) {
    return 'تم تحديد $n / $max';
  }

  @override
  String get sohbetmedyaRecent => 'الأحدث';

  @override
  String get sohbetmedyaPhotoVideo => 'الصور والفيديو';

  @override
  String sohbetmedyaLimitNote(String max) {
    return 'الحد الأقصى للعناصر: $max. مدة الفيديو 60 ثانية كحد أقصى.';
  }

  @override
  String get sohbetmedyaAddMore => 'إضافة المزيد';

  @override
  String sohbetmedyaSendItems(String n) {
    return 'إرسال ($n)';
  }

  @override
  String get chatdSendingMedia => 'جارٍ الإرسال…';

  @override
  String get chatdPhotoLoading => 'جارٍ تحميل الصورة…';

  @override
  String get chatdOnceLocked => 'صورة تُعرض مرة واحدة';

  @override
  String get chatdOnceView => 'عرض';

  @override
  String get chatdOnceOpenedFull => 'صورة · تم الفتح';

  @override
  String anasayfaHello(String name) {
    return 'مرحبًا، $name';
  }

  @override
  String get anasayfaHelloNoName => 'مرحبًا';

  @override
  String get anasayfaMealLunch => 'وجبة اليوم · الغداء';

  @override
  String get anasayfaAnnouncements => 'الإعلانات';

  @override
  String get anasayfaQuickAcademic => 'الأكاديمي';

  @override
  String get gonderiTextHint => 'أضف ملاحظة قصيرة (اختياري)';

  @override
  String gonderiWordCount(String n, String max) {
    return '$n/$max';
  }

  @override
  String gonderiWordLimit(String max) {
    return 'الحد الأقصى للكلمات: $max.';
  }

  @override
  String get gonderiPickPhoto => 'اختر من المعرض';

  @override
  String get gonderiTakePhoto => 'التقط صورة';

  @override
  String get gonderiPhotoRequired => 'اختر صورة للمشاركة.';

  @override
  String get gonderiPhotoHint => 'تتكون المشاركة من صورة واحدة.';

  @override
  String get gonderiChangePhoto => 'تغيير الصورة';

  @override
  String get gonderiDiscardTitle => 'هل تريد التخلي عن المشاركة؟';

  @override
  String get gonderiDiscardBody =>
      'سيتم حذف الصورة التي اخترتها والنص الذي كتبته.';

  @override
  String get gonderiDiscardYes => 'تخلَّ';

  @override
  String get yemekLunch => 'وجبة الغداء';

  @override
  String get yemekTodaysMenu => 'قائمة اليوم';

  @override
  String get yemekToday => 'اليوم';

  @override
  String get yemekPrevDay => 'اليوم السابق';

  @override
  String get yemekNextDay => 'اليوم التالي';

  @override
  String get destekFaqHeading => 'الأسئلة الشائعة';

  @override
  String get destekFaqSearchHint => 'ابحث عن سؤالك';

  @override
  String get destekFaqAll => 'الكل';

  @override
  String get destekFaqNoMatch => 'لم يتم العثور على سؤال مطابق.';

  @override
  String get destekSortMine => 'اقتراحاتي';

  @override
  String get destekSortPopular => 'الأكثر شعبية';

  @override
  String get destekShareSuggestion => 'شارك اقتراحًا';

  @override
  String destekEffective(String date) {
    return 'ساري المفعول: $date';
  }

  @override
  String destekVoteLabel(String count) {
    return 'صوّت، الأصوات الحالية $count';
  }

  @override
  String get anketScopeGlobal => 'عام';

  @override
  String get anketScopeClub => 'نادٍ';

  @override
  String get anketScopeMenu => 'الوجبة';

  @override
  String get anketSecretNote =>
      'صوتك سري. لا يرى اختيارك أحد غيرك، ولا يستطيع أحد، بمن فيهم الإدارة، معرفة من اختار أي خيار.';

  @override
  String get anketSecretVoteNote =>
      'يبقى صوتك سريًا ولا يستطيع أحد معرفة من اختار أي خيار.';

  @override
  String get anketMineBadge => 'اختيارك';

  @override
  String get anketRatingSummary => 'ملخص التقييم';

  @override
  String get anketResultsTitle => 'النتائج';

  @override
  String get anketFieldQuestion => 'السؤال';

  @override
  String get anketVisTitle => 'متى تظهر النتائج؟';

  @override
  String get anketVisAlways => 'دائمًا';

  @override
  String get anketVisAfterVote => 'بعد التصويت';

  @override
  String get anketVisAfterClose => 'عند إغلاق الاستطلاع';

  @override
  String get anketNotifyTitle => 'إرسال إشعار';

  @override
  String get anketNotifySub => 'إشعار الجمهور المستهدف بفتح الاستطلاع';

  @override
  String get icerikHidden => 'مخفي';

  @override
  String get icerikStatPosts => 'منشور';

  @override
  String get icerikStatFollowers => 'متابع';

  @override
  String get icerikStatFollowing => 'يتابع';

  @override
  String get icerikMessageSend => 'إرسال رسالة';

  @override
  String get icerikReport => 'إبلاغ';

  @override
  String get icerikMoreActions => 'إجراءات أخرى';

  @override
  String get icerikUserMenu => 'إجراءات المستخدم';

  @override
  String get icerikPostsHeading => 'المنشورات';

  @override
  String get icerikOpenPost => 'فتح المنشور';

  @override
  String get icerikPostPhoto => 'صورة المنشور';

  @override
  String get icerikNewsTitle => 'الأخبار';

  @override
  String get icerikNewsTypeTabs => 'النوع';

  @override
  String get icerikNewsList => 'قائمة الأخبار';

  @override
  String get icerikNewsEmpty => 'لا يوجد محتوى في هذه الفئة بعد.';

  @override
  String get icerikFavorites => 'الأخبار المفضلة';

  @override
  String get icerikMaintenance =>
      'تعذر الوصول إلى مصدر الأخبار حاليًا. يتم عرض آخر الأخبار المحفوظة.';

  @override
  String get icerikOpenSource => 'فتح في الموقع المصدر';

  @override
  String get icerikShare => 'مشاركة';

  @override
  String get icerikLinkCopied => 'تم نسخ رابط الخبر.';

  @override
  String icerikSavedCount(String count) {
    return '$count خبر محفوظ';
  }

  @override
  String get icerikSavedMoreTitle => 'احفظ المزيد من الأخبار';

  @override
  String get icerikSavedMoreBody => 'استخدم العلامة في صفحة الخبر لإضافته هنا.';

  @override
  String get icerikSavedList => 'المفضلة';

  @override
  String get icerikSearchTabs => 'نوع النتيجة';

  @override
  String get icerikGroupNews => 'الأخبار';

  @override
  String get icerikGroupAnnouncement => 'الإعلانات';

  @override
  String get icerikGroupEvent => 'الفعاليات';

  @override
  String get icerikGroupClub => 'النوادي';

  @override
  String get icerikGroupPerson => 'الأشخاص';

  @override
  String get icerikGroupPost => 'المنشورات';

  @override
  String get kulupdetayRequestsTitle => 'طلبات الانضمام';

  @override
  String kulupdetayPendingBanner(String count) {
    return 'طلبات انضمام معلقة: $count';
  }

  @override
  String get kulupdetaySendRequest => 'إرسال الطلب';

  @override
  String get kulupdetayAnswerHint => 'اكتب إجابتك';

  @override
  String get kulupdetayRequired => 'هذا السؤال إلزامي.';

  @override
  String get kulupdetayApproving => 'جارٍ القبول...';

  @override
  String get kulupdetayCreateTitle => 'إنشاء نادٍ';

  @override
  String kulupdetayMembersSubtitle(String club, String count) {
    return '$club · $count عضو';
  }

  @override
  String akademik2DayHeadingToday(String day) {
    return '$day، اليوم';
  }

  @override
  String akademik2CourseCount(String count) {
    return 'المحاضرات: $count';
  }

  @override
  String get akademik2ExportLabel => 'تصدير إلى التقويم';

  @override
  String get akademik2CourseHours => 'موعد المحاضرة';

  @override
  String get akademik2Instructor => 'المحاضر';

  @override
  String get akademik2Start => 'البداية';

  @override
  String get akademik2End => 'النهاية';

  @override
  String get akademik2EndOptional => 'النهاية (اختياري)';

  @override
  String get akademik2RoomShort => 'القاعة';

  @override
  String get akademik2AddDay => 'إضافة يوم آخر';

  @override
  String get akademik2OfficialTag => 'رسمي';

  @override
  String get akademik2Passed => 'انتهى';

  @override
  String get akademik2ExamTitle => 'عنوان الامتحان';

  @override
  String get akademik2Course => 'المقرر';

  @override
  String get akademik2Place => 'المكان';

  @override
  String get akademik2NewTag => 'جديد';

  @override
  String get akademik2Attachment => 'مرفق';

  @override
  String get akademik2RemindEach => 'قبل كل محاضرة';

  @override
  String get akademik2BeforeClassShort => 'قبل المحاضرة';

  @override
  String get akademik2SemesterTitle => 'اختر الفصل';

  @override
  String sistemuiPermStep(String current, String total) {
    return 'الخطوة $current / $total';
  }

  @override
  String get sistemuiPermNotifText =>
      'لتصلك إشعارات فورية عن الرسائل والفعاليات والإعلانات.';

  @override
  String get sistemuiPermContactsText =>
      'للعثور على جهات اتصال الجامعة في دفتر العناوين وبدء المحادثات. لا يتم إرسال جهات اتصالك إلى الخادم.';

  @override
  String get sistemuiPermCameraTitle => 'الكاميرا والمعرض';

  @override
  String get sistemuiPermCameraText => 'لمسح رموز QR والتقاط الصور ومشاركتها.';

  @override
  String get sistemuiOfflineTitle => 'لا يوجد اتصال';

  @override
  String get sistemuiOfflineBody =>
      'تحقق من اتصالك بالإنترنت وحاول مرة أخرى. قد يتعذر الوصول إلى الخادم الآن.';

  @override
  String get sistemuiErrorTitle => 'حدث خطأ ما';

  @override
  String get sistemuiMaintTitle => 'النظام قيد الصيانة';

  @override
  String get sistemuiMaintBody =>
      'نعمل على تحسين التطبيق من أجلك. حاول مرة أخرى بعد قليل. بياناتك في أمان.';

  @override
  String get sistemuiMaintBand => 'قد تكون بعض الميزات غير متاحة مؤقتًا.';

  @override
  String sistemuiUpdateVersions(String current, String required) {
    return 'الإصدار المثبت $current · الإصدار المطلوب $required';
  }

  @override
  String get sistemuiBlockedCode => 'رمز الخطأ: ACCESS_BLOCKED';

  @override
  String get sistemuiQrHint => 'ضع رمز QR داخل الإطار';

  @override
  String get sistemuiQrNotice =>
      'يفتح تسجيل الحضور في وقت الفعالية. امسح الرمز الذي يعرضه المنظم.';

  @override
  String get sistemuiQrOr => 'أو';

  @override
  String get sistemuiQrManualHint => 'مثال: K7M4QX';

  @override
  String get sistemuiQrSubmit => 'إرسال الحضور';

  @override
  String get profilyardBlockedNote =>
      'لا يمكن للأشخاص الذين تحظرهم رؤية ملفك الشخصي أو مراسلتك أو متابعتك.';

  @override
  String get profilyardBlockedEmptyTitle => 'لم تحظر أي شخص';

  @override
  String get profilyardBlockedEmptyBody =>
      'يمكنك حظر مستخدم مزعج من ملفه الشخصي.';

  @override
  String profilyardUnblockOf(String name) {
    return 'إلغاء حظر $name';
  }

  @override
  String get profilyardClubsManaged => 'التي أديرها';

  @override
  String get profilyardClubsMember => 'التي أنا عضو فيها';

  @override
  String get profilyardClubsPending => 'الطلبات المعلقة';

  @override
  String get profilyardRoleOwner => 'الرئيس';

  @override
  String get profilyardRoleFounder => 'المؤسس';

  @override
  String get profilyardRoleAdmin => 'مدير';

  @override
  String get profilyardRoleModerator => 'مشرف';

  @override
  String get profilyardRoleMember => 'عضو';

  @override
  String get profilyardClubsEmptyTitle => 'ليس لديك أي نادٍ بعد';

  @override
  String get profilyardClubsEmptyBody =>
      'يمكنك استكشاف الأندية والانضمام إليها أو تأسيس ناديك الخاص.';

  @override
  String get profilyardClubsDiscover => 'استكشف الأندية';

  @override
  String get profilyardEventsAttended => 'التي أشارك فيها';

  @override
  String get profilyardEventsCreated => 'التي أنشأتها';

  @override
  String get profilyardEventsUpcoming => 'القادمة';

  @override
  String get profilyardEventsPast => 'السابقة';

  @override
  String get profilyardEventGoing => 'سأحضر';

  @override
  String get profilyardEventRequested => 'تم إرسال الطلب';

  @override
  String get profilyardEventInterested => 'مهتم';

  @override
  String profilyardEventPendingCount(String count) {
    return 'طلبات معلقة: $count';
  }

  @override
  String get profilyardEventsEmptyTitle => 'ليس لديك أي فعالية بعد';

  @override
  String get profilyardEventsEmptyBody =>
      'تصفح الفعاليات أو أنشئ فعاليتك الخاصة.';

  @override
  String profilyardFollowersTab(String count) {
    return 'المتابعون $count';
  }

  @override
  String profilyardFollowingTab(String count) {
    return 'المتابَعون $count';
  }

  @override
  String get profilyardFollowersSearch => 'ابحث في المتابعين';

  @override
  String get profilyardFollowingSearch => 'ابحث في المتابَعين';

  @override
  String get profilyardFollowMutual => 'تتابعان بعضكما';

  @override
  String get profilyardFollowsYou => 'يتابعك';

  @override
  String get profilyardFollowingYou => 'تتابعه';

  @override
  String get profilyardFollowNoMatch => 'لا يوجد أشخاص مطابقون.';

  @override
  String get profilyardFbIntro =>
      'ساعدنا في تحسين التطبيق. اكتب اقتراحك أو الخطأ الذي واجهته أو أفكارك.';

  @override
  String get profilyardFbType => 'النوع';

  @override
  String get profilyardFbTitle => 'العنوان';

  @override
  String get profilyardFbMessage => 'الرسالة';

  @override
  String get profilyardFbTitleHint => 'لخّص باختصار';

  @override
  String get profilyardFbMessageHint => 'اكتب التفاصيل';

  @override
  String profilyardFbCounter(String n, String max) {
    return '$n / $max';
  }

  @override
  String get sohbetyAddMember => 'إضافة عضو';

  @override
  String sohbetyAddCount(String n) {
    return 'إضافة ($n)';
  }

  @override
  String get sohbetyProfile => 'الملف الشخصي';

  @override
  String get sohbetyNewGroup => 'مجموعة جديدة';

  @override
  String get sohbetyNewGroupSub => 'حتى 50 شخصًا';

  @override
  String get sohbetyGroupMin => 'اختر شخصين على الأقل للمجموعة.';

  @override
  String get sohbetyTypePerson => 'شخص';

  @override
  String get sohbetyFlash => 'الفلاش';

  @override
  String get sohbetyStopRec => 'إيقاف التسجيل';

  @override
  String get sohbetyTakePhoto => 'التقاط صورة';

  @override
  String get sohbetyAddDone => 'تمت إضافة الأعضاء';

  @override
  String get etkinlik2PolicyOpen => 'مفتوح للجميع';

  @override
  String get etkinlik2PolicyApproval => 'بطلب';

  @override
  String get etkinlik2PolicyApprovalTag => 'الانضمام بطلب';

  @override
  String get etkinlik2Organizer => 'المنظّم';

  @override
  String get etkinlik2JoinPolicyLabel => 'المشاركة';

  @override
  String get etkinlik2PolicyApprovalHint =>
      'عند اختيار \"بطلب\" توافق أنت على كل مشارك.';

  @override
  String get etkinlik2FormClub => 'باسم نادٍ (اختياري)';

  @override
  String get etkinlik2ClubNone => 'غير محدد';

  @override
  String get etkinlik2ClubSheetTitle => 'اختر ناديًا';

  @override
  String get etkinlik2ClubNoneOption => 'ليس باسم نادٍ';

  @override
  String get etkinlik2ClubNoClubs => 'لا توجد أندية يمكنك إنشاء فعالية لها.';

  @override
  String get etkinlik2ChatAutoTitle => 'تُفتح محادثة الفعالية تلقائيًا';

  @override
  String get etkinlik2ChatAutoBody =>
      'يدخل المشاركون وأنت إلى المحادثة. في الانضمام بطلب يدخل المعتمدون فقط.';

  @override
  String get etkinlik2CapacityOptional => 'السعة (اختياري)';

  @override
  String get etkinlik2Unlimited => 'غير محدود';

  @override
  String etkinlik2RegOpenSlots(String n) {
    return 'التسجيل مفتوح · بقي $n مكان';
  }

  @override
  String get etkinlik2RegOpen => 'التسجيل مفتوح';

  @override
  String get etkinlik2ApprovalByOrganizer => 'المنظّم يوافق على المشاركة';

  @override
  String get etkinlik2SendRequest => 'إرسال طلب انضمام';

  @override
  String get etkinlik2RequestHint =>
      'تدخل محادثة الفعالية عندما يوافق المنظّم.';

  @override
  String get etkinlik2RequestSent => 'تم إرسال الطلب';

  @override
  String get etkinlik2AwaitingReply => 'بانتظار الرد';

  @override
  String get etkinlik2Withdraw => 'سحب';

  @override
  String get etkinlik2WithdrawTitle => 'سحب الطلب';

  @override
  String get etkinlik2WithdrawMessage => 'سيتم سحب طلب انضمامك.';

  @override
  String get etkinlik2ChatLocked => 'محادثة الفعالية · تُفتح بعد الموافقة';

  @override
  String get etkinlik2RejectedTitle => 'تم رفض طلبك';

  @override
  String get etkinlik2RejectedBody => 'لم يقبل المنظّم طلبك لهذه الفعالية.';

  @override
  String get etkinlik2RequestSentToast => 'تم إرسال طلب انضمامك.';

  @override
  String get etkinlik2WithdrawnToast => 'تم سحب الطلب.';

  @override
  String etkinlik2GoingInterested(String going, String interested) {
    return '$going مشارك · $interested مهتم';
  }

  @override
  String etkinlik2GoingOnly(String going) {
    return '$going مشارك';
  }

  @override
  String get etkinlik2ManageRequests => 'طلبات الانضمام';

  @override
  String etkinlik2ManagePending(String n) {
    return '$n طلب معلّق';
  }

  @override
  String get etkinlik2ManageNoPending => 'لا طلبات معلّقة';

  @override
  String get etkinlik2ManageAttendance => 'المشاركون والحضور';

  @override
  String get etkinlik2ManageSettings => 'إعدادات الفعالية';

  @override
  String get etkinlik2ManageSection => 'الإدارة';

  @override
  String get etkinlik2ReqQuota => 'السعة';

  @override
  String etkinlik2ReqSlotsLeft(String n) {
    return 'بقي $n مكان';
  }

  @override
  String get etkinlik2ReqNoLimit => 'لا حد للسعة';

  @override
  String get etkinlik2ReqFullBanner =>
      'اكتملت السعة؛ لا يمكن الموافقة على طلبات جديدة. ارفع السعة لإتاحة أماكن.';

  @override
  String etkinlik2ReqPendingHeader(String n) {
    return 'معلّق · $n';
  }

  @override
  String get etkinlik2ReqAnsweredHeader => 'تم الرد عليها';

  @override
  String get etkinlik2ReqNone => 'لا توجد طلبات معلّقة.';

  @override
  String get etkinlik2Approve => 'قبول';

  @override
  String get etkinlik2Reject => 'رفض';

  @override
  String etkinlik2ApproveSem(String name) {
    return 'قبول طلب $name';
  }

  @override
  String etkinlik2RejectSem(String name) {
    return 'رفض طلب $name';
  }

  @override
  String get etkinlik2ApprovedTag => 'تمت الموافقة';

  @override
  String get etkinlik2RejectedTag => 'مرفوض';

  @override
  String get etkinlik2ApprovedToast => 'تمت الموافقة على الطلب.';

  @override
  String get etkinlik2RejectedToast => 'تم رفض الطلب.';

  @override
  String get etkinlik2SettingsTitle => 'إعدادات الفعالية';

  @override
  String get etkinlik2SettingsPolicy => 'نوع المشاركة';

  @override
  String etkinlik2SettingsCapMin(String n) {
    return 'عدد المؤكَّدين $n. لا يمكنك خفض السعة عن ذلك.';
  }

  @override
  String etkinlik2SettingsCapTooLow(String n) {
    return 'لا يمكن أن تقل السعة عن عدد المؤكَّدين ($n).';
  }

  @override
  String get etkinlik2SettingsRegChat => 'التسجيل والمحادثة';

  @override
  String get etkinlik2SettingsRegOpen => 'التسجيل مفتوح';

  @override
  String get etkinlik2SettingsRegHint =>
      'عند الإيقاف لا تُقبل طلبات أو مشاركات جديدة.';

  @override
  String get etkinlik2SettingsChatOpen => 'محادثة الفعالية مفتوحة';

  @override
  String get etkinlik2SettingsChatHint =>
      'عند الإيقاف تتوقف الرسائل ويُحتفظ بالسجل.';

  @override
  String get etkinlik2SettingsDanger => 'منطقة الخطر';

  @override
  String etkinlik2SettingsCancelBody(String n) {
    return 'سيتم إشعار جميع المشاركين ($n) وتُغلق المحادثة. لا يمكن التراجع.';
  }

  @override
  String get etkinlik2SettingsSaved => 'تم حفظ الإعدادات.';

  @override
  String get etkinlik2QrManualCaption => 'لإدخال الرمز يدويًا';

  @override
  String etkinlik2QrRenewsIn(String n) {
    return 'يتجدد الرمز بعد $n ث';
  }

  @override
  String get etkinlik2AttendanceLabel => 'الحضور';

  @override
  String etkinlik2PresentOf(String present, String total) {
    return 'حضر $present من $total';
  }

  @override
  String get etkinlik2FilterAll => 'الكل';

  @override
  String get etkinlik2FilterPresent => 'حضر';

  @override
  String get etkinlik2FilterAbsent => 'لم يحضر';

  @override
  String etkinlik2MarkSem(String name) {
    return 'تعيين $name كحاضر';
  }

  @override
  String get etkinlik2MethodQr => 'رمز QR';

  @override
  String get etkinlik2MethodManual => 'يدوي';

  @override
  String get etkinlik2ShowQrSem => 'عرض رمز QR';

  @override
  String get etkinlik2AttendanceEmpty => 'لا يوجد مشاركون للعرض.';

  @override
  String get etkinlik2MarkFailed => 'تعذّر تحديث الحضور.';

  @override
  String get etkinlik2ChatClosedToast => 'تم إغلاق المحادثة.';

  @override
  String get etkinlik2ChatOpenedToast => 'تم فتح المحادثة.';

  @override
  String get etkinlik2NoteLabel => 'ملاحظة للمنظّم (اختياري)';

  @override
  String get etkinlik2AnswerRequired => 'يجب الإجابة عن جميع الأسئلة.';

  @override
  String get etkinlik2ClubSemPrefix => 'النادي';

  @override
  String cevrimdisiBekleyenMesaj(String n) {
    return 'سيتم إرسال $n رسالة عند عودة الاتصال';
  }

  @override
  String cevrimdisiGonderiliyor(String n) {
    return 'جارٍ إرسال $n رسالة…';
  }

  @override
  String get cevrimdisiGonderilemedi => 'لم يتم الإرسال';

  @override
  String cevrimdisiSonGuncelleme(String zaman) {
    return 'آخر تحديث: $zaman';
  }

  @override
  String get cevrimdisiKayitliVeri => 'يتم عرض البيانات المحفوظة';

  @override
  String get cevrimdisiBekliyor => 'في الانتظار';

  @override
  String get cevrimdisiYenidenDene => 'إعادة المحاولة';

  @override
  String get cevrimdisiMedyaBaglanti => 'حاول مرة أخرى عند عودة الاتصال';

  @override
  String get cevrimdisiInternetYok => 'لا يوجد اتصال بالإنترنت';

  @override
  String get bildirimmobilKanalChat => 'الرسائل';

  @override
  String get bildirimmobilKanalEvent => 'الفعاليات';

  @override
  String get bildirimmobilKanalAnnouncement => 'الإعلانات والأخبار';

  @override
  String get bildirimmobilKanalSocial => 'اجتماعي (الإعجابات، المتابعات)';

  @override
  String get bildirimmobilKanalPoll => 'الاستطلاعات';

  @override
  String get bildirimmobilKanalAcademic => 'تذكيرات المحاضرات والامتحانات';

  @override
  String get evcLabelClub => 'النادي';

  @override
  String get evcInfoInstant => 'يُنشر فورًا.';

  @override
  String get evcInfoReview => 'يُنشر بعد موافقة الإدارة.';

  @override
  String get evcClubRequiredHint => 'اختر ناديًا أولًا.';

  @override
  String get evcEmptyTitle => 'يجب أن تكون مديرًا في نادٍ لإنشاء فعالية';

  @override
  String get evcEmptyBody =>
      'تُنشأ الفعاليات باسم الأندية. عندما تصبح مديرًا في نادٍ يمكنك إنشاء الفعاليات هنا.';

  @override
  String get evcBrowseClubs => 'تصفّح الأندية';

  @override
  String get evcSubmittedTitle => 'أُرسلت للموافقة';

  @override
  String get evcSubmittedBody =>
      'ستُنشر فعاليتك بعد موافقة الإدارة. يمكنك متابعة حالتها من تبويب ما أنشأته.';

  @override
  String get evcOk => 'حسنًا';

  @override
  String get evcStatusPending => 'بانتظار الموافقة';

  @override
  String get evcStatusRejected => 'مرفوضة';

  @override
  String evcRejectReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get evcErrClubRequired => 'يجب إنشاء الفعالية باسم نادٍ. اختر ناديًا.';

  @override
  String get evcErrForbidden => 'ليست لديك صلاحية إنشاء فعاليات لهذا النادي.';

  @override
  String get evcErrClubNotActive => 'هذا النادي غير نشط حاليًا.';

  @override
  String get evcErrPast => 'لا يمكن أن تبدأ الفعالية في الماضي.';

  @override
  String get evcErrDates => 'يجب أن تكون النهاية بعد البداية.';

  @override
  String get evcErrProfanity => 'يحتوي النص على عبارات غير لائقة. يرجى تعديله.';

  @override
  String get evdLabelDate => 'التاريخ';

  @override
  String get evdLabelTime => 'وقت البدء';

  @override
  String get evdLabelDuration => 'المدة';

  @override
  String get evdChipToday => 'اليوم';

  @override
  String get evdChipTomorrow => 'غدًا';

  @override
  String get evdChipWeekend => 'نهاية هذا الأسبوع';

  @override
  String get evdChipNextWeek => 'الأسبوع القادم';

  @override
  String get evdChipPickDate => 'اختر تاريخًا';

  @override
  String get evdChipCustomTime => 'وقت مخصص';

  @override
  String get evdDur1h => 'ساعة';

  @override
  String get evdDur2h => 'ساعتان';

  @override
  String get evdDurHalfDay => 'نصف يوم';

  @override
  String get evdChipCustomEnd => 'اختر تاريخ الانتهاء';

  @override
  String get evdErrStartPast => 'لا يمكن أن يكون البدء في الماضي.';

  @override
  String get evdErrEndBeforeStart => 'يجب أن تكون النهاية بعد البداية.';

  @override
  String get evdEndAdjusted => 'تم ضبط النهاية تلقائيًا بعد ساعة من البدء.';

  @override
  String evdDescCounter(String count, String max) {
    return '$count/$max';
  }

  @override
  String evdErrDescTooLong(String max) {
    return 'يجب ألا يتجاوز الوصف $max حرفًا.';
  }

  @override
  String get evdErrDescTooLongServer => 'الوصف طويل جدًا. يرجى اختصاره.';

  @override
  String get clubMgmtCategoryNone => 'غير محدد';

  @override
  String clubMgmtCategoryInactive(String name) {
    return '$name (غير مستخدم)';
  }

  @override
  String get clubMgmtCategoryInvalid =>
      'الفئة المحددة غير صالحة. اختر فئة أخرى من القائمة.';

  @override
  String get errEmailAliasNotAllowed =>
      'لا يمكن استخدام وسم + في عنوان البريد الإلكتروني.';

  @override
  String get errPasswordTooLong =>
      'كلمة المرور طويلة جدًا: الحد الأقصى 72 بايت (الأحرف التركية والعربية تشغل أكثر من بايت).';

  @override
  String get errPayloadTooLarge =>
      'حجم البيانات المرسلة كبير جدًا. جرّب ملفًا أصغر أو نصًا أقصر.';

  @override
  String get errUploadBusy =>
      'هناك عملية رفع أخرى قيد التنفيذ أو الخادم مشغول. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String get errUploadQuota =>
      'لقد أجريت عددًا كبيرًا من عمليات الرفع. حاول مرة أخرى بعد قليل.';

  @override
  String get errMailQuota =>
      'لا يمكننا إرسال رموز التحقق حاليًا. يرجى المحاولة لاحقًا.';

  @override
  String get errServiceBusy =>
      'النظام مشغول حاليًا. يرجى المحاولة مرة أخرى بعد بضع ثوانٍ.';

  @override
  String get errLegalReaccept =>
      'تم تحديث الاتفاقيات. يجب عليك الموافقة على الاتفاقيات المحدّثة للمتابعة.';

  @override
  String coreErrRetryAfterSec(String n) {
    return 'حاول مرة أخرى بعد $n ث.';
  }

  @override
  String coreErrRetryAfterMin(String n) {
    return 'حاول مرة أخرى بعد $n د.';
  }

  @override
  String get clubPostTextRequired => 'أضف نصًا لمشاركته مع الصورة.';

  @override
  String get etkinlik2QrExpired => 'انتهت الصلاحية، جارٍ التحديث…';

  @override
  String get updateRequiredRecheck => 'تحقق مرة أخرى';

  @override
  String get legalReacceptTitle => 'تم تحديث الاتفاقيات';

  @override
  String get legalReacceptIntro =>
      'أجرينا تغييرات على شروط الاستخدام ووثائق الخصوصية. لمواصلة استخدام التطبيق، يرجى قراءة الوثائق المحدّثة والموافقة عليها.';

  @override
  String get legalReacceptIntroSoft =>
      'تم نشر إصدارات جديدة من بعض الوثائق. يمكنك مراجعتها والموافقة عليها الآن أو لاحقًا، وستحتاج إلى الموافقة عليها في الأيام القادمة.';

  @override
  String get legalReacceptListTitle => 'الوثائق المحدّثة';

  @override
  String get legalReacceptTypeTerms => 'شروط الاستخدام';

  @override
  String get legalReacceptTypePrivacy => 'سياسة الخصوصية';

  @override
  String get legalReacceptTypeKvkk => 'إشعار حماية البيانات (KVKK)';

  @override
  String get legalReacceptTypeRules => 'قواعد المجتمع';

  @override
  String get legalReacceptNoteExplicit =>
      'أذونات الموافقة الصريحة الاختيارية منفصلة عن هذه الموافقة ولا تُعدّ ممنوحة بها.';

  @override
  String get legalReacceptCheck => 'لقد قرأت الوثائق المحدّثة وأوافق عليها';

  @override
  String get legalReacceptAccept => 'أوافق';

  @override
  String get legalReacceptLater => 'لاحقًا';

  @override
  String get legalReacceptDecline => 'لا أوافق';

  @override
  String get legalReacceptDeclineTitle => 'لا يمكن المتابعة دون الموافقة';

  @override
  String get legalReacceptDeclineBody =>
      'إذا لم توافق على الاتفاقيات الحالية فلن تتمكن من استخدام التطبيق. يمكنك حذف حسابك، أو تسجيل الخروج واتخاذ القرار لاحقًا.';

  @override
  String get legalReacceptDeleteAccount => 'حذف حسابي';

  @override
  String get legalReacceptSignOut => 'تسجيل الخروج';

  @override
  String get legalReacceptOutdated =>
      'تم تحديث الوثائق مرة أخرى. يرجى مراجعة الإصدارات الجديدة والموافقة عليها من جديد.';

  @override
  String get authVerifyPasswordLabel => 'كلمة المرور التي اخترتها عند التسجيل';

  @override
  String get authVerifyPasswordNote =>
      'لأسباب أمنية، أعد إدخال كلمة المرور التي استخدمتها عند التسجيل.';

  @override
  String get authVerifyPasswordRequired =>
      'أدخل كلمة المرور التي اخترتها عند التسجيل.';

  @override
  String get chatClosedBanner => 'أغلق أحد المشرفين هذه المحادثة.';

  @override
  String get chatAdminRemovedMsg => 'أزال أحد المشرفين هذه الرسالة';

  @override
  String get chatModRemovedMsg => 'تمت إزالة هذه الرسالة';

  @override
  String get errCertificateRevoked => 'ألغى أحد المشرفين هذه الشهادة.';

  @override
  String get clubUnavailable => 'هذا النادي غير متاح حاليًا.';

  @override
  String get profil2DelItemUsage =>
      'يتم حذف سجلات أجهزتك وعنوان IP وبيانات الاستخدام (التحليلات) فورًا.';

  @override
  String get profil2DelItemClubOwner =>
      'تُنقل ملكية النوادي التي تملكها إلى عضو مشرف؛ وإذا لم يوجد مرشح يُغلق النادي.';

  @override
  String get settingsCrashReports => 'إرسال تقارير الأعطال';

  @override
  String get settingsCrashReportsDesc =>
      'عند حدوث خطأ في التطبيق أو إغلاقه بشكل غير متوقع، يُرسل تقرير أعطال مجهول إلى خادم BÜ Kampüs: إصدار التطبيق ونظام التشغيل ونوع الخطأ وتتبع تقني للمكدس دون بيانات شخصية. لا يتم إرسال بريدك الإلكتروني أو كلمة المرور أو محتوى الرسائل أو هويتك، ولا يُنقل أي شيء إلى خدمات خارجية. يمكنك إيقاف ذلك في أي وقت.';

  @override
  String get welcomeChipNews => 'الأخبار';

  @override
  String get welcomeChipMenu => 'الطعام';

  @override
  String get welcomeChipClubs => 'الأندية';

  @override
  String get authLangTitle => 'اختر اللغة';

  @override
  String get authPaste => 'لصق';

  @override
  String get authResetDoneTitle => 'تم تحديث كلمة المرور';

  @override
  String get authResetDoneBody =>
      'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة. تم إغلاق الجلسات على الأجهزة الأخرى.';

  @override
  String get authTrustAcademic =>
      'يُستخدم قسمك لعرض الإعلانات والأندية المناسبة لك.';

  @override
  String get authTrustName =>
      'يظهر اسمك للطلاب الآخرين في ملفك الشخصي وفي المحادثات.';

  @override
  String get authTrustPassword =>
      'تُخزَّن كلمة المرور على شكل بصمة مشفّرة فقط؛ لا يمكن لأحد قراءتها.';

  @override
  String get authTrustCode =>
      'إذا لم يصل البريد، فتحقق من مجلد الرسائل غير المرغوبة أيضًا.';

  @override
  String get authTrustSecure => 'اتصالك مشفّر وآمن.';

  @override
  String p00StepOf(String current, String total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get p05NewsEmptyBody => 'ستظهر العناصر الجديدة هنا عند وصولها.';

  @override
  String get p05SavedEmptyTitle => 'لا توجد مفضلات بعد';

  @override
  String get p05SavedToast => 'تمت الإضافة إلى المفضلة';

  @override
  String get p05UnsavedToast => 'تمت الإزالة من المفضلة';

  @override
  String get p05SearchIdleTitle => 'ابحث في الحرم الجامعي';

  @override
  String get p05SearchNoResultsBody => 'جرّب كلمة مختلفة أو تحقق من الإملاء.';

  @override
  String get p05Source => 'المصدر';

  @override
  String p05ReadMinutes(String count) {
    return 'قراءة $count د';
  }

  @override
  String p17WeekOf(String n, String total) {
    return 'الأسبوع $n من $total';
  }

  @override
  String get p17SemesterName => 'اسم الفصل';

  @override
  String get p17NoClassesTitle => 'جدولك الأسبوعي فارغ';

  @override
  String get p17ExamsEmptyTitle => 'لا توجد امتحانات بعد';

  @override
  String get p17OfficialEmptyTitle => 'لم يُنشر الجدول الرسمي بعد';

  @override
  String get p17SemestersEmptyTitle => 'لا توجد فصول';

  @override
  String get p17MaintenanceTitle => 'قيد الصيانة';

  @override
  String get p17PreviewHint => 'معاينة';

  @override
  String get p16QrCopy => 'نسخ الرمز';

  @override
  String get p16QrCopied => 'تم نسخ الرمز';

  @override
  String get p16ReqNoneBody => 'ستظهر طلبات الانضمام الجديدة هنا.';

  @override
  String get p16AttEmptyBody => 'يُعرض الحضور هنا عند انضمامهم إلى الفعالية.';

  @override
  String get p16AttFilterEmpty => 'لا أحد يطابق هذا الفلتر.';

  @override
  String get p16PolicyOpenHint => 'يمكن لأي شخص الانضمام مباشرة دون إرسال طلب.';

  @override
  String p16AttPresentCount(String n) {
    return 'حضر $n';
  }

  @override
  String get p10PageTitle => 'إضافة وسائط';

  @override
  String get p10SheetTitle => 'إضافة';

  @override
  String get p10SheetSubtitle => 'ماذا تريد أن ترسل؟';

  @override
  String get p10SourcePhotos => 'صور';

  @override
  String get p10SourcePhotosHint => 'اختر صورة أو أكثر من معرض الصور';

  @override
  String get p10SourceVideo => 'فيديو';

  @override
  String get p10SourceVideoHint => 'اختر فيديو من المعرض (حتى 60 ثانية)';

  @override
  String get p10SourceCamera => 'الكاميرا';

  @override
  String get p10SourceCameraHint => 'التقط صورة أو سجّل فيديو';

  @override
  String get p10PrivacyNote =>
      'تتم مشاركة العناصر التي تختارها فقط، ولا يُفتح معرض صورك بالكامل.';

  @override
  String get p10PickedHeader => 'المحدد';

  @override
  String get p10EmptyTitle => 'لم تختر شيئاً بعد';

  @override
  String get p10EmptyBody => 'ابدأ باختيار صور أو فيديو أو الكاميرا من الأعلى.';

  @override
  String get p10Preview => 'معاينة';

  @override
  String get p10Remove => 'إزالة';

  @override
  String get p10PickFailed => 'تعذّر فتح المنتقي. حاول مرة أخرى.';

  @override
  String get p14Today => 'اليوم';

  @override
  String get p14Tomorrow => 'غدًا';

  @override
  String get p14ClearDay => 'الشهر كاملًا';

  @override
  String get p14Ended => 'انتهت';

  @override
  String get p14Live => 'جارية الآن';

  @override
  String p14EventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فعالية',
      many: '$count فعالية',
      few: '$count فعاليات',
      two: 'فعاليتان',
      one: 'فعالية واحدة',
      zero: 'لا فعاليات',
    );
    return '$_temp0';
  }

  @override
  String get p14EmptyMonthBody =>
      'تصفح شهرًا آخر؛ ستظهر الفعاليات الجديدة هنا فور إضافتها.';

  @override
  String get p14EmptyDayBody => 'اختر يومًا آخر أو اعرض الشهر كاملًا.';

  @override
  String get p14EmptyUpcomingBody =>
      'انضم إلى فعاليات الأندية وستجد ما تشارك فيه هنا.';

  @override
  String get p14EmptyPastBody =>
      'تُحفظ هنا الفعاليات التي شاركت فيها بعد انتهائها.';

  @override
  String get p14EmptyCreatedBody =>
      'أنشئ فعالية باسم ناديك وأدر الطلبات والحضور من هنا.';

  @override
  String get p13SuppAskTitle => 'كيف يمكننا مساعدتك؟';

  @override
  String get p13SuppAskBody => 'تصفّح الأسئلة الشائعة أو راسل فريق الدعم.';

  @override
  String get p13TicketIntro =>
      'اشرح مشكلتك باختصار، وسيردّ فريق الدعم في أقرب وقت.';

  @override
  String get p13TicketsEmptyHint => 'إذا واجهت مشكلة، يمكنك إنشاء طلب جديد.';

  @override
  String get p13FeedbackEmptyHint =>
      'تظهر هنا الاقتراحات وبلاغات الأخطاء التي ترسلها.';

  @override
  String get p13SugEmptyTitle => 'الأفكار تجتمع هنا';

  @override
  String get p13PollEmptyOpenHint => 'ستظهر الاستطلاعات الجديدة هنا عند فتحها.';

  @override
  String get p13PollEmptyMineHint => 'تظهر هنا الاستطلاعات التي صوّتّ فيها.';

  @override
  String get p13PollEmptyClosedHint => 'تُحفظ هنا نتائج الاستطلاعات المنتهية.';

  @override
  String get p13Rate1 => 'سيئ جدًا';

  @override
  String get p13Rate2 => 'سيئ';

  @override
  String get p13Rate3 => 'مقبول';

  @override
  String get p13Rate4 => 'جيد';

  @override
  String get p13Rate5 => 'ممتاز';

  @override
  String get p13Leading => 'في الصدارة';

  @override
  String p08ItemOf(String n, String total) {
    return '$n / $total';
  }

  @override
  String get p08Pause => 'إيقاف مؤقت';

  @override
  String get p08Seek => 'موضع الفيديو';

  @override
  String get p08OnceHint => 'بعد الإغلاق لا يمكن فتح هذه الصورة مرة أخرى.';

  @override
  String get p13TicketsHeading => 'طلباتي';

  @override
  String get p13ShareHeading => 'شاركنا رأيك';

  @override
  String get p13FeedbackMine => 'ما أرسلته';

  @override
  String get p11ReadMore => 'عرض المزيد';

  @override
  String get p11ReadLess => 'عرض أقل';

  @override
  String get p11TypeSingleHint => 'يختار المصوّت خيارًا واحدًا';

  @override
  String get p11TypeMultiHint => 'يمكن اختيار أكثر من خيار';

  @override
  String get p11TypeRankedHint => 'تُرتَّب الخيارات حسب التفضيل';

  @override
  String get p11TypeRatingHint => 'التقييم بنجمة من 1 إلى 5';

  @override
  String get p11RequestsEmptyBody => 'ستظهر هنا طلبات الانضمام الجديدة.';

  @override
  String get p06EmptyNoneBody =>
      'ابدأ المراسلة مع أصدقائك أو الأندية الطلابية أو مجموعات الفعاليات.';

  @override
  String p06NoMatchBody(String q) {
    return 'لا يوجد شخص أو نادٍ أو رسالة تطابق “$q”.';
  }

  @override
  String get p06ResetSearch => 'إعادة ضبط البحث';

  @override
  String get p06ArchiveEmptyBody =>
      'تُحفظ المحادثات المؤرشفة هنا لتبقى قائمتك مرتبة.';

  @override
  String get p06BackToChats => 'العودة إلى المحادثات';

  @override
  String get p06LoadFailedTitle => 'تعذّر التحميل، حاول مجددًا';

  @override
  String get p06LoadFailedBody =>
      'حدث خطأ في الاتصال أثناء تحديث قائمة المحادثات. يرجى التحقق من اتصالك.';

  @override
  String get p06MenuDeleteChat => 'حذف المحادثة';

  @override
  String get p08OnceSubtitle => 'يمكن عرضها مرة واحدة فقط';

  @override
  String get p08OnceSentSub => 'عرض لمرة واحدة';

  @override
  String get p08ModerationTitle => 'إشعار الإشراف';

  @override
  String p08Percent(String n) {
    return '$n٪';
  }

  @override
  String get p08PhotoLoadingSub => 'جارٍ التنزيل من الخادم';

  @override
  String get p08Queued => 'في قائمة الانتظار · بانتظار الاتصال';

  @override
  String get p01ConfigTitle => 'خطأ في الإعدادات';

  @override
  String get p01ConfigBody =>
      'عنوان الخادم (API_BASE) غير آمن (https). أعد بناء التطبيق بالعنوان الصحيح.';

  @override
  String get p01ConfigCode => 'رمز الخطأ • BUILD_ENV';

  @override
  String get p01UpdateNoticeLabel => 'تحديث التطبيق';

  @override
  String get p01PushNow => 'الآن';

  @override
  String p01PushMore(String n) {
    return '+$n رسائل أخرى';
  }

  @override
  String get p01PushReply => 'المس للرد';

  @override
  String p01PermDeniedTitle(String title) {
    return 'لم يتم منح إذن $title';
  }

  @override
  String get p01QrAttended => 'تم تسجيل حضورك';

  @override
  String get p07ChatEmptyTitle => 'لا توجد رسائل بعد';

  @override
  String get p07ChatEmptyBody => 'اكتب أول رسالة.';

  @override
  String get p07ChatBlockedLine => 'لا يمكنك مراسلة شخص قمت بحظره.';

  @override
  String get p02WelcomeNewsSub => 'إشعارات فورية وآخر مستجدات الحرم الجامعي.';

  @override
  String get p02WelcomeMenuSub => 'السعرات اليومية وتفاصيل محتوى الوجبات.';

  @override
  String get p02WelcomeClubsSub => 'الأندية وورش العمل وتسجيل الحضور.';

  @override
  String get p02BrandSub => 'تطبيق طلابي مستقل';

  @override
  String get p02LoginBusy => 'جارٍ تسجيل الدخول…';

  @override
  String get p02PwStrengthTitle => 'قوة كلمة المرور';

  @override
  String get p02TipTitle => 'نصيحة';

  @override
  String p02FacultyCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n قسم',
      many: '$n قسمًا',
      few: '$n أقسام',
      two: 'قسمان',
      one: 'قسم واحد',
    );
    return '$_temp0';
  }

  @override
  String get p02PendingTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String get p02PendingBody => 'يجب التحقق من حسابك قبل تسجيل الدخول.';

  @override
  String get p02ReplacedTitle => 'انتهت الجلسة';

  @override
  String get p01LgLoadFailed => 'تعذّر التحميل، حاول مرة أخرى';

  @override
  String p01LgMetaLine(String version, String date) {
    return 'الإصدار $version · السريان: $date';
  }

  @override
  String get p03MenuTotal => 'الإجمالي';

  @override
  String get p03MenuTotalEnergy => 'إجمالي الطاقة';

  @override
  String p03MenuKcal(String n) {
    return '$n kcal';
  }

  @override
  String p03MenuAtLeast(String n) {
    return '$n kcal على الأقل';
  }

  @override
  String get p03MenuKcalMissing => 'لم تُدخل السعرات الحرارية لبعض الأطباق';

  @override
  String get p03MenuKcalNone => 'لا توجد سعرات';

  @override
  String get p03MenuNoList => 'لا توجد قائمة طعام.';

  @override
  String get p03MenuMaintenance => 'النظام قيد الصيانة.';

  @override
  String p03NotifNewCount(String n) {
    return '$n جديد';
  }

  @override
  String get p03NotifEmptyBody =>
      'ستظهر هنا إشعارات إعلانات الأندية والفعاليات والرسائل.';

  @override
  String get p03NotifUnreadEmptyBody =>
      'رائع! لقد قرأت جميع الإشعارات الجديدة. ستصلك التنبيهات فور صدور إعلانات جديدة.';

  @override
  String get p03NotifLoadFailed => 'تعذّر التحميل، حاول مرة أخرى';

  @override
  String get p03NotifLoadingMore => 'جارٍ تحميل المزيد...';

  @override
  String get p03HomeMealTitle => 'قائمة اليوم';

  @override
  String get p03HomeNoMenuBody => 'لم تُدخل قائمة المطعم بعد.';

  @override
  String get p03HomeEventsTitle => 'الفعاليات القادمة';

  @override
  String get p03HomeNoEventBody => 'لا توجد فعاليات أندية مجدولة حالياً.';

  @override
  String get p05NewsOpenSource => 'فتح صفحة المصدر';

  @override
  String get p05NewsErrorTitle => 'حدث خطأ ما';

  @override
  String get p05NewsErrorBody =>
      'حدثت مشكلة أثناء تحميل المحتوى. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';

  @override
  String p05SearchCountFor(String q) {
    return 'لـ «$q»';
  }

  @override
  String p05SearchFoundNews(String n) {
    return 'تم العثور على $n خبر';
  }

  @override
  String p05SearchFoundEvents(String n) {
    return 'تم العثور على $n فعالية';
  }

  @override
  String p05SearchFoundClubs(String n) {
    return 'تم العثور على $n نادٍ';
  }

  @override
  String p05SearchFoundPeople(String n) {
    return 'تم العثور على $n شخص';
  }

  @override
  String p05SearchFoundPosts(String n) {
    return 'تم العثور على $n منشور';
  }

  @override
  String p05SearchSeeAllN(String n) {
    return 'عرض الكل ($n)';
  }

  @override
  String get p05SearchRemoveRecent => 'حذف البحث';

  @override
  String get p11PendingInfoTitle => 'الطلب قيد المراجعة';

  @override
  String get p11PendingInfoBody =>
      'طلب انضمامك بانتظار موافقة مديري النادي. سيصلك إشعار عند صدور القرار.';

  @override
  String get p11LockPrivateTitle => 'هذا النادي خاص';

  @override
  String get p11LockPrivateBody =>
      'لا يستطيع رؤية المنشورات وقائمة الأعضاء إلا الأعضاء المعتمدون.';

  @override
  String get p11LockMembersTitle => 'المحتوى للأعضاء فقط';

  @override
  String get p11LockMembersBody => 'تظهر منشورات النادي بعد الموافقة على طلبك.';

  @override
  String get p11LockBannedTitle => 'المحتوى غير متاح';

  @override
  String get p11LockBannedBody => 'تم إخفاء محتوى النادي لأن وصولك مقيّد.';

  @override
  String get p11BannedTitle => 'تمت إزالتك من النادي';

  @override
  String get p11BannedBody =>
      'لا يمكنك الانضمام إلى هذا النادي أو التقديم على فعالياته.';

  @override
  String get p11ApprovalNote =>
      'يُفتح محتوى النادي بعد موافقة المديرين على طلبك.';

  @override
  String get p11PostPinSub => 'ضعه في أعلى صفحة النادي';

  @override
  String get p11PostUnpinSub => 'أعد المنشور إلى ترتيبه العادي';

  @override
  String get p11PostDeleteSub => 'احذف المنشور نهائيًا من الصفحة';

  @override
  String get p11PostReportSub => 'أبلغ عن مخالفة للقواعد';

  @override
  String get p11PollsSub => 'قرارات الأعضاء واختياراتهم';

  @override
  String p11SearchEmptyBody(String query) {
    return 'لا يوجد عضو يطابق “$query”. تحقق من الاسم وحاول مجددًا.';
  }

  @override
  String get p11ClearSearch => 'مسح البحث';

  @override
  String get p11RequestsEmptyAll =>
      'تم الرد على جميع الطلبات أو لم يصل طلب جديد بعد.';

  @override
  String get p11LoadErrorBody => 'حدث خطأ في الاتصال. تعذّر جلب البيانات.';

  @override
  String get p12LogoAdd => 'إضافة شعار';

  @override
  String get p12LogoChange => 'تغيير الشعار';

  @override
  String get p12LogoHint => 'ملف شخصي مربع (1:1)';

  @override
  String get p12CoverHint => 'يُنصح بصورة أفقية 16:9';

  @override
  String get p12QuestionsSubtitle => 'نموذج قصير للمتقدمين';

  @override
  String get p12QuestionPlaceholder => 'اكتب سؤالك...';

  @override
  String get p12ConsentNote =>
      'بإنشائك النادي فإنك توافق على الالتزام بمبادئ المجتمع وقواعد الطلاب.';

  @override
  String get p12PartialTitle => 'حُفظ جزئيًا';

  @override
  String get p12CategorySheetTitle => 'اختر فئة';

  @override
  String get p12JoinNote => 'ستصلك إشعارات عند الموافقة على طلبك.';

  @override
  String p12CountClubs(String count) {
    return '$count نادٍ';
  }

  @override
  String p12CountRequests(String count) {
    return '$count طلب';
  }

  @override
  String get p15PublishRoleActive => 'صلاحية المدير مفعّلة';

  @override
  String get p15CoverOptional => 'اختياري';

  @override
  String get p15CoverHint => 'يُفضّل 16:9 أفقي • بحد أقصى 3 ميغابايت';

  @override
  String get p15CoverChange => 'تغيير';

  @override
  String get p15CoverSheetTitle => 'صورة الغلاف';

  @override
  String get p15CoverGallerySub => 'اختر صورة من ألبومات جهازك';

  @override
  String get p15CoverCameraSub => 'التقط صورة فورًا بالكاميرا';

  @override
  String get p15CoverRemoveSub => 'العودة إلى الصورة الافتراضية';

  @override
  String p15ErrBannerTitle(String n) {
    return 'يرجى تصحيح $n من الأخطاء في النموذج.';
  }

  @override
  String get p15ErrBannerBody =>
      'بعض المعلومات التي أدخلتها ناقصة أو لا تلتزم بالقواعد. راجع الحقول المحددة.';

  @override
  String get p15ErrHint =>
      'يصبح زر الإنشاء نشطًا تلقائيًا بعد تصحيح الحقول المطلوبة.';

  @override
  String p15ErrLocked(String n) {
    return 'أصلح $n من أخطاء التحقق أولًا';
  }

  @override
  String get p15ErrForbiddenTitle => 'قيد في الصلاحية';

  @override
  String get p15ErrInactiveTitle => 'النادي غير نشط';

  @override
  String get p15PickerSubtitle => 'النادي المخوّل الذي سيُنشر الحدث باسمه';

  @override
  String get p15PickerSearch => 'ابحث عن نادٍ…';

  @override
  String get p15PickerNoMatch => 'لا يوجد نادٍ مطابق.';

  @override
  String p15PickerMembers(String n) {
    return '$n عضو';
  }

  @override
  String get p15PickerInfoTitle => 'معلومات الصلاحيات';

  @override
  String get p15PickerInfoBody =>
      'تُنشر الأحداث فورًا في الأندية التي تديرها أو تشرف عليها. أما أحداث الأعضاء الذين لديهم صلاحية الأحداث فتُنشر بعد موافقة الإدارة.';

  @override
  String get p15PickerEmptyBody =>
      'لا يوجد نادٍ تملك فيه صلاحية المدير أو المشرف.';

  @override
  String get p15RefreshPerms => 'تحديث الصلاحيات';

  @override
  String get p16ReqQuotaStatus => 'حالة السعة';

  @override
  String get p16ReqRegistered => 'مسجّل';

  @override
  String get p16ReqUnlimitedTitle => 'حصة المشاركين';

  @override
  String get p16ReqPendingTitle => 'الطلبات المعلقة';

  @override
  String get p16ReqNoteLabel => 'ملاحظة الطلب';

  @override
  String get p16ReqFullTitle => 'اكتملت السعة';

  @override
  String get p16ReqFullBody =>
      'لا يمكن قبول طلبات جديدة. ارفع السعة أو حدّث قائمة المشاركين لتوفير مكان.';

  @override
  String get p16ReqRaiseQuota => 'رفع السعة';

  @override
  String p16ReqFullPeople(String a, String b) {
    return '$a / $b شخص';
  }

  @override
  String get p16ReqCantApprove => 'لا يمكن القبول: السعة غير كافية';

  @override
  String get p16ReqErrTitle => 'تعذّر تحديث قائمة الطلبات.';

  @override
  String get p16ReqBackToEvent => 'العودة إلى تفاصيل الحدث';

  @override
  String get p16ReqEmptyBody =>
      'تمت الإجابة على جميع الطلبات أو لم يصل طلب جديد بعد.';

  @override
  String p16SetApproved(String n) {
    return '$n مشارك معتمد';
  }

  @override
  String get p16SetOpenSub => 'يُقبل كل من يسجّل مباشرة.';

  @override
  String get p16SetApprovalSub => 'يمرّ كل طلب بموافقة المنظّم.';

  @override
  String get p16SetCapLabel => 'السعة (أشخاص)';

  @override
  String p16SetCapCurrent(String n) {
    return 'الحالي: $n شخص';
  }

  @override
  String get p16SetCapDec => 'إنقاص السعة';

  @override
  String get p16SetCapInc => 'زيادة السعة';

  @override
  String p16SetCancelNote(String n) {
    return 'سيتم إشعار $n من المشاركين فورًا وإزالة الحدث من القوائم.';
  }

  @override
  String get p16QrStatusTitle => 'حالة الحضور';

  @override
  String get p16QrStatusSub => 'سجل الحضور المباشر';

  @override
  String get p16QrList => 'قائمة المشاركين';

  @override
  String get p16QrExpiredTitle => 'انتهت الصلاحية';

  @override
  String get p16QrRefreshing => 'جارٍ التحديث…';

  @override
  String get p16QrErrBody => 'تعذّر الاتصال بالخادم أو انتهت مهلة الجلسة.';

  @override
  String get p16QrCopyBtn => 'نسخ';

  @override
  String get p16AttTitle => 'المشاركون والحضور';

  @override
  String get p16AttWaiting => 'في الانتظار';

  @override
  String get p16AttFilterEmptyBody => 'لا يوجد مشارك يطابق هذا المرشح.';

  @override
  String p16AttMarkedToast(String name, String method) {
    return 'تمت إضافة $name إلى الحضور ($method)';
  }

  @override
  String p16AttUnmarkedToast(String name) {
    return 'تمت إزالة $name من الحضور';
  }

  @override
  String get p07ChatSearchClear => 'مسح';

  @override
  String get p17DailyFlow => 'الجدول اليومي';

  @override
  String p17DayPlanned(String n) {
    return '$n محاضرات مجدولة';
  }

  @override
  String get p17SlotWaiting => 'قادمة';

  @override
  String p17RoomLabel(String room) {
    return 'القاعة $room';
  }

  @override
  String p17HoursPerWeek(String n) {
    return '$n ساعة / أسبوع';
  }

  @override
  String get p17NoSemesterTitle => 'لا يوجد فصل دراسي بعد';

  @override
  String get p17NoSemesterBody => 'أضف فصلًا دراسيًا لتنظيم محاضراتك.';

  @override
  String get p17NoCourseTitle => 'لم تضف أي مقرر بعد';

  @override
  String get p17NoCourseBody => 'احفظ أول مقرر لبناء جدولك الأسبوعي.';

  @override
  String get p17DayFreeBody =>
      'يمكنك قضاء اليوم في الراحة أو الدراسة في المكتبة أو شرب القهوة في الحرم الجامعي!';

  @override
  String get p17TodayDoneBody => 'أنهيت كل محاضرات اليوم، استمتع بالراحة.';

  @override
  String get p17WeekDoneBody =>
      'انتهى جدول هذا الأسبوع. أنت جاهز للأسبوع القادم!';

  @override
  String get p17OutOfRangeBody => 'اليوم المحدد خارج التقويم الأكاديمي.';

  @override
  String get p17LoadErrTitle => 'حدثت مشكلة أثناء تحميل الجدول الدراسي.';

  @override
  String p17SemesterCount(String n) {
    return '$n فصول محفوظة';
  }

  @override
  String get p17CheckFields => 'يرجى التحقق من الحقول التالية:';

  @override
  String get p17ExamDetail => 'التفاصيل';

  @override
  String get p17ExamsNoUpcomingBody =>
      'تهانينا! لا توجد اختبارات قادمة حاليًا.';

  @override
  String get p17ExamsEmptyMineTitle => 'لم تضف أي اختبار شخصي.';

  @override
  String get p17ExamsEmptyMineBody =>
      'أضف أول اختبار لبناء جدولك ومتابعة العد التنازلي.';

  @override
  String get p17OfficialEmptyBody =>
      'ستظهر هنا قائمة اختبارات قسمك عند الإعلان عنها.';

  @override
  String get p17CourseInfoSemantic => 'تفاصيل المقرر';

  @override
  String get p20EditProfile => 'تعديل الملف الشخصي';

  @override
  String get p20HubExamPlan => 'خطة الجلسات';

  @override
  String get p20HubNoDeptTitle => 'لا يوجد قسم في ملفك الشخصي';

  @override
  String get p20HubNoDeptBody =>
      'أكمل بيانات كليتك للحصول على جدول وإعلانات مخصصة.';

  @override
  String get p20HubTimetableEmptyBody =>
      'أضف مقرراتك لمتابعة جدولك الأسبوعي وبناء تقويم الصف.';

  @override
  String get p20HubExamBadge => 'نصفي ونهائي';

  @override
  String get p20HubExamEmptyBody =>
      'تهانينا! لا يوجد اختبار نصفي أو نهائي مخطط في تقويمك حاليًا.';

  @override
  String get p20HubCalEmptySub => 'انتهت الفترات الزمنية داخل الفصل';

  @override
  String get p20HubAnnEmptyTitle => 'لا توجد إعلانات غير مقروءة';

  @override
  String get p20HubAnnEmptyBody =>
      'ستظهر هنا الإشعارات الجديدة من سكرتارية القسم أو المرشد.';

  @override
  String get p20HubDateTime => 'التاريخ والوقت';

  @override
  String p20CalToday(String date) {
    return 'اليوم: $date';
  }

  @override
  String get p20CalSelected => 'المحدد';

  @override
  String get p20CalImportant => 'تاريخ مهم';

  @override
  String get p20Yesterday => 'أمس';

  @override
  String get p20AnnFooterTitle => 'لا توجد إعلانات أخرى لقسمك.';

  @override
  String get p20AnnFooterBody =>
      'ستصلك إشعارات عند نشر تقويم أو اختبارات جديدة.';

  @override
  String get p20AnnLinkErrBody =>
      'تعذر الوصول إلى خادم الملفات. يرجى التحقق من اتصالك.';

  @override
  String get p20RemPermTitle => 'لم يتم منح إذن الإشعارات';

  @override
  String get p20RemPermBody =>
      'تحتاج التذكيرات إلى إذن إشعارات النظام لتعمل في وقتها.';

  @override
  String get p20RemOpenSettings => 'فتح من الإعدادات';

  @override
  String p13PollArchiveCount(String n) {
    return '$n استطلاعات في الأرشيف';
  }

  @override
  String get p13PollArchiveHeading => 'الاستطلاعات المنتهية';

  @override
  String p13PollAvgOutOf(String avg) {
    return '$avg من 5';
  }

  @override
  String get p13PollAvgTitle => 'متوسط الرضا';

  @override
  String get p13PollChangeNote => 'يمكنك تغيير رأيك بعد التصويت.';

  @override
  String get p13PollClosingSoon => 'ينتهي قريبًا';

  @override
  String get p13PollClubEmptyBody =>
      'لم يشارك مسؤولو النادي أي استطلاع للتصويت بعد.';

  @override
  String get p13PollDateTime => 'التاريخ والوقت';

  @override
  String get p13PollEditMode => 'وضع تغيير التصويت';

  @override
  String get p13PollEditNote =>
      'عند تغيير اختيارك يُلغى تصويتك السابق تلقائيًا ويُحتسب اختيارك الجديد.';

  @override
  String get p13PollEmptyClosedBody =>
      'تُنقل الاستطلاعات المنتهية إلى الأرشيف.';

  @override
  String get p13PollEmptyMineBody => 'تُجمع هنا الاستطلاعات التي صوّتَّ فيها.';

  @override
  String get p13PollEmptyOpenBody => 'ستظهر الاستطلاعات الجديدة هنا عند فتحها.';

  @override
  String get p13PollErrBody => 'تعذّر الاتصال بالخادم';

  @override
  String get p13PollFormType => 'نوع الاستطلاع';

  @override
  String get p13PollHowTo => 'كيف يتم التصويت؟';

  @override
  String get p13PollMin2 => 'خياران على الأقل';

  @override
  String get p13PollOptionsTitle => 'الخيارات';

  @override
  String get p13PollPickEndDate => 'اختر تاريخ الانتهاء';

  @override
  String get p13PollPickEndTime => 'اختر وقت الانتهاء';

  @override
  String get p13PollPrefs => 'تفضيلات المشاركة';

  @override
  String get p13PollPrevChoice => 'اختيارك السابق';

  @override
  String get p13PollQuick => 'مدة سريعة';

  @override
  String p13PollRankLabel(String n) {
    return 'الاختيار $n';
  }

  @override
  String get p13PollRankReset => 'اضغط على الخيار مرة أخرى لإعادة ضبط الترتيب.';

  @override
  String get p13PollRankTap => 'اضغط للاختيار';

  @override
  String get p13PollRateCta => 'قيّم';

  @override
  String get p13PollSecretBody =>
      'لا يمكن لأي مسؤول أو ممثل نادٍ أو طالب رؤية هويتك.';

  @override
  String p13PollSelectedCount(String n, String max) {
    return '$n / $max محدد';
  }

  @override
  String get p13PollTopOption => 'الخيار الأكثر تصويتًا';

  @override
  String get p13PollTypeMultiHint => 'يمكن تحديد أكثر من خيار';

  @override
  String get p13PollTypeRankedHint => 'الترتيب حسب الأفضلية';

  @override
  String get p13PollTypeRatingHint => 'التقييم من 1 إلى 5 نجوم';

  @override
  String get p13PollTypeSingleHint => 'يمكن اختيار خيار واحد فقط';

  @override
  String get p13PollVisAfterCloseSub => 'لا تُعرض أي بيانات حتى انتهاء المدة';

  @override
  String get p13PollVisAfterVoteSub => 'تظهر للمستخدم بعد تصويته';

  @override
  String get p13PollVisAlwaysSub => 'يمكن متابعة جميع الأصوات مباشرة';

  @override
  String get p13PollYourScore => 'تقييمك';

  @override
  String get p17MyCourses => 'مقرراتي';

  @override
  String p11LikeCount(String count) {
    return '$count إعجاب';
  }

  @override
  String get p11CaseSensitive => 'حساس لحالة الأحرف';

  @override
  String get p12BasicInfo => 'المعلومات الأساسية';

  @override
  String get p12VisibilityAndJoin => 'الظهور والانضمام';

  @override
  String get p17ConflictIntro => 'تتعارض الأوقات مع هذه المقررات:';

  @override
  String p17ColorSelected(String name) {
    return 'المحدد: $name';
  }

  @override
  String get p17WeekDay => 'يوم الأسبوع';

  @override
  String get p13PollViewAll => 'عرض الكل';

  @override
  String get p13PollReview => 'مراجعة التصويت';

  @override
  String get p13PollOpenBadge => 'استطلاع مفتوح';

  @override
  String get p13PollClosedKicker => 'استطلاع مغلق';

  @override
  String p13PollDone(String n) {
    return 'اكتمل · $n صوت';
  }

  @override
  String p13PollWinner(String name, String pct) {
    return 'الفائز: $name ($pct%)';
  }

  @override
  String get p13PollOneVote => 'صوت واحد';

  @override
  String get p13PollHiddenResults => 'نتائج مخفية';

  @override
  String get p13PollVoteCta => 'صوّت';

  @override
  String get p13PollNoMoreActive => 'لا يوجد استطلاع نشط آخر لهذا النادي.';

  @override
  String get p13PollNoMoreBody =>
      'تُنشر هنا قرارات المجتمع وتفضيلات الفعاليات.';

  @override
  String get p04DiscoverSub => 'تعرّف على نبض الحرم الجامعي والمنشورات الحية';

  @override
  String get p04SearchHint => 'ابحث في الحرم: أندية، فعاليات، أشخاص...';

  @override
  String get p04ChipAll => 'الكل';

  @override
  String get p04SuggestTitle => 'قد تعرفهم';

  @override
  String get p04SuggestSeeAll => 'عرض الكل';

  @override
  String get p04FollowAction => 'متابعة';

  @override
  String get p04FollowingState => 'تتابعه';

  @override
  String get p04FeedTitle => 'منشورات الطلاب';

  @override
  String p04LikeCount(String count) {
    return '$count إعجاب';
  }

  @override
  String get p11UnavailableBody =>
      'تم تجميد هذا المجتمع مؤقتًا أو أنه قيد المراجعة.';

  @override
  String get p11UnderReview => 'قيد المراجعة';

  @override
  String get p12ConsentBold => 'مبادئ المجتمع';

  @override
  String get p03NotifLoadFailedBody =>
      'تعذّرت مزامنة آخر التحديثات مع الخادم. يرجى التحقق من اتصالك.';

  @override
  String p03NotifShortDay(String n) {
    return '$n يوم';
  }

  @override
  String p05SearchLikes(String n) {
    return '$n إعجاب';
  }

  @override
  String get p05SearchErrorTitle => 'تعذّر التحميل';

  @override
  String get p05SearchErrorBody => 'حدث خطأ في الاتصال أثناء جلب نتائج البحث.';

  @override
  String get p13PollDistribution => 'توزيع الخيارات';

  @override
  String get p13PollWinnerOption => 'الخيار الفائز';

  @override
  String get p13PollRatingSummary => 'ملخص التقييم';

  @override
  String get p13PollOutOf5 => 'من 5';

  @override
  String get p13MenuRated => 'تم حفظ تقييمك. شكرًا لك!';

  @override
  String get p04CropProfileTitle => 'اقتصاص الصورة';

  @override
  String get p04CropPostTitle => 'صورة المنشور';

  @override
  String get p04CropLogoTitle => 'شعار النادي';

  @override
  String get p04CropCoverTitle => 'صورة الغلاف';

  @override
  String get p04CropChatTitle => 'صورة المحادثة';

  @override
  String get p04CropHint => 'اسحب وكبّر بإصبعين';

  @override
  String get p04CropRotate => 'تدوير';

  @override
  String get p04CropReset => 'إعادة ضبط';

  @override
  String get p04CropScale => 'حجم الصورة';

  @override
  String get p04CropCrop => 'اقتصاص';

  @override
  String get p04CropError => 'تعذّرت معالجة الصورة. جرّب صورة أخرى.';

  @override
  String get p04CropPreviewProfile => 'هكذا ستظهر في ملفك';

  @override
  String get p04CropPreviewFeed => 'هكذا ستظهر في الخلاصة';

  @override
  String get p04CropPreviewTitle => 'معاينة';

  @override
  String get p04CropPreviewClubPage => 'صفحة النادي';

  @override
  String get p04CropPreviewClubCard => 'بطاقة النادي';

  @override
  String get p04CropRemoveCover => 'إزالة الغلاف';

  @override
  String get p04SrcTitle => 'الصورة';

  @override
  String get p04SrcGallery => 'اختيار من المعرض';

  @override
  String get p04SrcCamera => 'التقاط صورة';

  @override
  String get p04SrcRemove => 'إزالة الصورة';

  @override
  String get p04Recrop => 'اقتصاص مجدد';

  @override
  String get p04PostNotFound =>
      'لم يتم العثور على المنشور (ربما حُذف أو أُخفي)';

  @override
  String get p04PostSharing => 'جارٍ النشر...';

  @override
  String get p04PostPhotoNone => 'لم تُختر صورة';

  @override
  String get p04PostFormatHint => 'يُفضّل التنسيق العمودي 4:5';

  @override
  String get p04ContentWarning => 'تنبيه بشأن المحتوى';

  @override
  String get p23AddPeople => 'إضافة أشخاص';

  @override
  String get p23Selected => 'المشاركون المحددون';

  @override
  String get p23MinTwo => 'شخصان على الأقل';

  @override
  String get p23PrivacyShort => 'لا تُرسل جهات اتصالك إلى الخادم.';

  @override
  String get p26OnceCaption => 'يمكنك مشاهدة هذه الصورة مرة واحدة فقط.';

  @override
  String p09BlockNamed(String name) {
    return 'حظر $name';
  }

  @override
  String get p09MemberOptions => 'خيارات العضو';

  @override
  String p09MemberRemoved(String name) {
    return 'تمت إزالة $name من المجموعة';
  }

  @override
  String get p09MediaLoading => 'جارٍ التحميل...';

  @override
  String get p09MediaEmptyBody => 'تظهر الصور ومقاطع الفيديو المشتركة هنا.';

  @override
  String get p09MediaErrorTitle => 'حدث خطأ';

  @override
  String get p09MediaErrorBody => 'تعذر تحميل الوسائط.';

  @override
  String get p09ClubPageSub => 'الفعاليات والمشاريع';

  @override
  String get p09MembersLoadFailed => 'تعذر تحميل قائمة الأعضاء.';

  @override
  String get p10AlbumTitle => 'الألبوم';

  @override
  String p10AlbumCount(String n) {
    return '$n ألبوم';
  }

  @override
  String get p10ItemUnit => 'عنصر';

  @override
  String get p10LimitedBody =>
      'يمكنك اختيار المزيد من الصور من مكتبتك لإرسالها في الدردشة.';

  @override
  String get p10DeniedBody =>
      'لإرسال الصور والفيديو، اسمح بالوصول إلى المعرض من إعدادات التطبيق.';

  @override
  String get p10GalleryEmpty => 'لا توجد صور أو فيديوهات في المعرض.';

  @override
  String p10SelCount(String n, String max) {
    return '$n / $max';
  }

  @override
  String get p10SelWord => 'محدّد';

  @override
  String p10TileSelected(String n) {
    return 'محدد، رقم $n';
  }

  @override
  String get p10VideoPrepareSub => 'جارٍ الضغط والتخزين المؤقت';

  @override
  String get p10CloseNotice => 'إغلاق الإشعار';

  @override
  String get p01LgReview => 'مراجعة الاتفاقيات مرة أخرى';

  @override
  String get p14ErrorTitle => 'تعذّر التحميل، حاول مجددًا';

  @override
  String get p14ErrorBody => 'حدثت مشكلة أثناء الاتصال بالخادم.';

  @override
  String get p14OfflineStrip =>
      'لا يوجد اتصال بالإنترنت · عرض البيانات المحفوظة';

  @override
  String get p14EmptyUpcomingBody2 => 'تصفّح فعاليات أندية الحرم وانضم فورًا.';

  @override
  String get p14EmptyPastBody2 => 'تُؤرشف هنا الفعاليات التي حضرتها أو انتهت.';

  @override
  String get p14EmptyCreatedBody2 =>
      'أدر هنا ورش العمل والندوات واللقاءات التي تخطط لها مع ناديك.';

  @override
  String get p14Detail => 'التفاصيل';

  @override
  String get p14Attended => 'حضرت';

  @override
  String get p14WithdrawRequest => 'سحب الطلب';

  @override
  String get p14StatusGoing => 'مشارك';

  @override
  String p18ClassYear(String n) {
    return 'السنة $n';
  }

  @override
  String get p18FollowErrorTitle => 'خطأ في الاتصال';

  @override
  String get p18FollowersEmptyBody =>
      'عندما يصبح ملفك نشطًا سيبدأ أصدقاؤك بمتابعتك هنا.';

  @override
  String get p18FollowingEmptyBody =>
      'تابع الطلاب وأعضاء الأندية الذين تهتم بهم حتى لا تفوتك منشورات الحرم الجامعي.';

  @override
  String get p18FollowNoMatchBody =>
      'لم يتم العثور على مستخدم يطابق بحثك. تحقق من الكتابة وحاول مرة أخرى.';

  @override
  String p18AllFollowers(String n) {
    return 'كل المتابعين ($n)';
  }

  @override
  String p18AllFollowing(String n) {
    return 'المتابَعون ($n)';
  }

  @override
  String get p19AcademicInfo => 'المعلومات الأكاديمية';

  @override
  String get p19ShowEmailDesc =>
      'يمكن للطلاب الذين يزورون ملفك رؤية بريدك الإلكتروني.';

  @override
  String get p19LangSystemDesc => 'يستخدم لغة جهازك الافتراضية';

  @override
  String get p19CrashReportsShort =>
      'يُرسل تقرير خطأ مجهول عند حدوث خطأ في التطبيق.';

  @override
  String get p19LogoutAllSub => 'يغلق جلسات الهاتف والمتصفح الأخرى المفتوحة.';

  @override
  String get p05NewsLoadingMore => 'جارٍ تحميل أخبار أقدم...';

  @override
  String get p05SavedDiscover => 'استكشف الأخبار';

  @override
  String get p05SavedEmptyTitle2 => 'لا توجد أخبار محفوظة بعد.';

  @override
  String get p05SavedEmptyBody2 =>
      'يمكنك حفظ الأخبار التي تعجبك بالنقر على أيقونة العلامة.';

  @override
  String get p05ListErrorTitle => 'تعذّر التحميل، حاول مرة أخرى';

  @override
  String get p05ListErrorBody =>
      'حدثت مشكلة أثناء الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت.';

  @override
  String get p13SuppLoadFailed => 'تعذّر التحميل';

  @override
  String get p13SuppFaqEmptyBody => 'لم تتم إضافة مقالات لهذه الفئة بعد.';

  @override
  String get p13SuppFaqNoMatchBody => 'لا توجد نتائج تطابق بحثك.';

  @override
  String get p13SuppTicketsEmptyBody => 'ليس لديك أي سجل دعم نشط أو سابق.';

  @override
  String get p13SuppFeedbackSub => 'قيّم تجربتك مع التطبيق';

  @override
  String get p13SuppBoardSub => 'شارك أفكارك للميزات الجديدة';

  @override
  String get p02IdLabel => 'البريد / رقم الطالب';

  @override
  String get p17PickDateHelp => 'اختر التاريخ';

  @override
  String get p20ProfileTitle => 'الملف الشخصي';

  @override
  String get p20AboutNoBio => 'لم تتم إضافة سيرة ذاتية.';

  @override
  String get p20AcademicInfo => 'المعلومات الأكاديمية';

  @override
  String get p20AvatarHidden =>
      'تم إخفاء صورة ملفك الشخصي بسبب الإشراف. ستظهر الأحرف الأولى من اسمك حتى ترفع صورة تلتزم بقواعد الحرم.';

  @override
  String get p20BlockInfo => 'لن ترى منشورات هذا الشخص ولن تتمكن من مراسلته.';

  @override
  String get p20ReportSendHint => 'يمكنك وصف الموقف باختصار...';

  @override
  String get p20PrefPollsSub => 'استطلاعات الطلاب والموظفين';

  @override
  String get p20PrefAcademicSub => 'إعلانات القسم والكلية والاختبارات';

  @override
  String get p20PrefDetailHead =>
      'أدر الأنواع الفرعية لكل فئة على حدة. عند إيقاف المفتاح الرئيسي تُكتم الأنواع الفرعية التابعة له.';

  @override
  String get p20PrefDetailSub => 'الفئات الفرعية وأنواع الإشعارات';

  @override
  String get p20PrefOffTag => 'معطل';

  @override
  String get p20PrefMsgGroupSub => 'المراسلة الفورية';

  @override
  String get p20PrefEventsGroupSub => 'التقويم واللقاءات';

  @override
  String get p20PrefClubsGroupSub => 'نشاط المجتمعات';

  @override
  String get p20PrefSubDirect => 'المحادثات الخاصة الفردية';

  @override
  String get p20PrefSubGroup => 'محادثات مجموعات المقررات والنوادي';

  @override
  String get p20PrefSubEventReminder => 'قبل ساعة من البدء';

  @override
  String get p20PrefSubEventUpdate => 'تحديثات التاريخ أو الوقت أو المكان';

  @override
  String get p20PrefSubEventAdmission => 'موافقات المشاركة في فعاليات النادي';

  @override
  String get p20PrefSubClubPost => 'الإعلانات والصور التي تشاركها النوادي';

  @override
  String get p20PrefSubClubRole => 'صلاحيات الإدارة والعضوية';

  @override
  String get p20PrefSubClubJoin => 'طلبات الانضمام وردودها';

  @override
  String get p20PrefLoadFail => 'تعذر التحميل';

  @override
  String get p20PrefTapRetry => 'اضغط لإعادة المحاولة.';

  @override
  String p20PrefRemSub(String m) {
    return 'تنبيه محلي قبل بدء المحاضرة بـ $m د';
  }

  @override
  String get p20QuietPickHelp => 'اختر الوقت';

  @override
  String get p20ThemeSystemSub => 'حسب إعدادات الجهاز';

  @override
  String get p20HalfDay => 'نصف يوم';

  @override
  String get p20AllDay => 'طوال اليوم';

  @override
  String p20RangeDays(String n) {
    return '$n أيام';
  }

  @override
  String p20RangeWeeks(String n) {
    return '$n أسابيع';
  }

  @override
  String get p20RemDaySub => 'تذكير قبل الاختبار بيوم';

  @override
  String get p20RemHourSub => 'إشعار قبل الاختبار بساعة';

  @override
  String get p13SugSortTop => 'الأكثر تصويتًا';

  @override
  String get p13SugAdd => 'إضافة اقتراح';

  @override
  String get p13SugApprovalNote => 'تُنشر الاقتراحات بعد موافقة المسؤول.';

  @override
  String get p13SugVoteHint => 'اضغط للتصويت';

  @override
  String get p13SugVoted => 'تم حفظ صوتك';

  @override
  String get p04PostsEmptyBody => 'تظهر الصور التي تشاركها هنا.';

  @override
  String get p04PostsLoadFail => 'تعذّر التحميل، حاول مجددًا';

  @override
  String get p04FeedErrTitle => 'تعذّر الوصول إلى الخادم';

  @override
  String get p04FeedErrBody =>
      'تحقق من اتصالك أو تصفّح الذاكرة المؤقتة دون اتصال.';

  @override
  String get p09ForwardDirect => 'محادثة فردية';

  @override
  String get p03HomeBrandSub => 'تطبيق طلابي مستقل';

  @override
  String get p03HomeQuickTitle => 'وصول سريع';

  @override
  String get p03HomeQuickEvents => 'الفعاليات';

  @override
  String get p03HomeQuickSchedule => 'جدول الدروس';

  @override
  String get p03HomeFeaturedNews => 'أبرز الأخبار';

  @override
  String get p03HomeUpcoming => 'الفعالية القادمة';

  @override
  String get p03HomeMealHeroTitle => 'قائمة طعام اليوم';

  @override
  String p03HomeLunchCount(String n) {
    return 'غداء • $n أصناف';
  }

  @override
  String get p03HomeMenuDetail => 'تفاصيل القائمة';

  @override
  String p03HomeHosts(String club) {
    return 'تنظّمه $club';
  }

  @override
  String get p04CropCenter => 'توسيط';

  @override
  String get p04SrcSizeTitle => 'حجم الملف كبير';
}
