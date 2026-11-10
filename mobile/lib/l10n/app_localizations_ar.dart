// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get chatReactionPickerTitle => 'اختر تفاعلاً';

  @override
  String get chatReactionKeyboardHint => 'اختر رمزاً تعبيرياً من لوحة المفاتيح';

  @override
  String get chatReactionOneEmoji => 'اختر رمزاً تعبيرياً واحداً.';

  @override
  String get chatReactionSearchHint => 'ابحث عن رمز تعبيري';

  @override
  String get chatReactionNoResults => 'لا توجد نتائج';

  @override
  String get chatReactionRecent => 'المستخدمة مؤخراً';

  @override
  String get chatReactionFrequent => 'الأكثر استخداماً';

  @override
  String get chatReactionCatFaces => 'الوجوه';

  @override
  String get chatReactionCatPeople => 'الأشخاص';

  @override
  String get chatReactionCatNature => 'الحيوانات والطبيعة';

  @override
  String get chatReactionCatFood => 'الطعام والشراب';

  @override
  String get chatReactionCatActivities => 'الأنشطة';

  @override
  String get chatReactionCatTravel => 'السفر';

  @override
  String get chatReactionCatObjects => 'الأشياء';

  @override
  String get chatReactionCatSymbols => 'الرموز';

  @override
  String get chatReactionCatFlags => 'الأعلام';

  @override
  String get chatReactionUnsupported => 'هذا الرمز التعبيري غير مدعوم حالياً';

  @override
  String get chatReactionLimit =>
      'لا يمكن إضافة المزيد من الرموز التعبيرية المختلفة إلى هذه الرسالة';

  @override
  String get chatMessageInfoTitle => 'معلومات الرسالة';

  @override
  String get chatMessageSent => 'تم الإرسال';

  @override
  String get chatMessageDelivered => 'تم التسليم';

  @override
  String get chatMessageRead => 'تمت القراءة';

  @override
  String get chatMessageTimeUnknown => 'لم يتم تسجيل الوقت';

  @override
  String get chatMessageWaiting => 'ليس بعد';

  @override
  String get chatMessageReplies => 'الردود على هذه الرسالة';

  @override
  String get chatMessageNoReplies => 'لا توجد ردود على هذه الرسالة بعد.';

  @override
  String get chatMessageReactions => 'التفاعلات';

  @override
  String get chatMessageEditedNote => 'تم تعديل هذه الرسالة';

  @override
  String get chatPremiumAllPhotos => 'كل الصور';

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
  String get configError => 'الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً.';

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
  String get loginSubtitle => 'سجّل الدخول ببريدك الإلكتروني.';

  @override
  String get loginReplacedNotice =>
      'تم إغلاق الجلسة على هذا الجهاز. ربما تم تسجيل الخروج منه من جهاز آخر؛ سجّل الدخول مجددا للمتابعة.';

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
  String get authIdHint => 'البريد الإلكتروني';

  @override
  String get loginSubtitleNumber => 'سجّل الدخول ببريدك الإلكتروني.';

  @override
  String get authVerify => 'تحقق';

  @override
  String get authResendCode => 'إعادة إرسال الرمز';

  @override
  String authResendInTime(String time) {
    return 'إعادة الإرسال ($time)';
  }

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
  String get authPasswordMin8 => 'كلمة المرور (6 أحرف على الأقل)';

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
  String get acadExamsTitle => 'الامتحانات';

  @override
  String get acadExamsAdd => 'إضافة امتحان';

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
    return 'يبدأ بعد ساعتين$room';
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
  String get acadTimeHourBefore => 'قبل الاختبار بساعتين (إشعار)';

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
  String get chatEncNoticeDirect => 'يتم تشفير رسائلك أثناء النقل وعلى الخادم.';

  @override
  String get chatEncNoticeGroup =>
      'يتم تشفير رسائل هذه المحادثة أثناء النقل وعلى الخادم. يمكن لجميع أعضاء المحادثة رؤيتها.';

  @override
  String get chatEncNoticeRoom =>
      'يتم تشفير رسائل هذه الغرفة أثناء النقل وعلى الخادم. يمكن لجميع أعضاء الغرفة رؤيتها.';

  @override
  String get chatEncMore => 'معرفة المزيد';

  @override
  String get chatEncPageTitle => 'أمان المحادثة';

  @override
  String get chatEncHeroTitle => 'رسائلك مشفّرة';

  @override
  String get chatEncHeroBody =>
      'يتم تشفير رسائلك أثناء النقل وعلى الخادم. نشرح لك أدناه بوضوح ما الذي يُحمى وكيف، وما الذي ينبغي أن تنتبه إليه.';

  @override
  String get chatEncSecHow => 'كيف تتم الحماية';

  @override
  String get chatEncTlsTitle => 'مشفّرة أثناء النقل';

  @override
  String get chatEncTlsBody =>
      'تنتقل رسائلك وصور المحادثة بين التطبيق والخادم عبر اتصال مشفّر (TLS/WSS).';

  @override
  String get chatEncRestTitle => 'تخزين مشفّر على الخادم';

  @override
  String get chatEncRestBody =>
      'تُخزَّن الرسائل مشفّرة بخوارزمية AES-256-GCM بمفتاح مستقل لكل محادثة، وتُخزَّن صور المحادثة ومقاطع الفيديو مشفّرة أيضًا. تُحفظ المفاتيح بعيدًا عن قاعدة البيانات في بيئة الخادم، مما يصعّب قراءة الرسائل حتى لو تم الحصول على نسخة احتياطية من قاعدة البيانات.';

  @override
  String get chatEncAuditTitle => 'وصول المشرفين مسجَّل';

  @override
  String get chatEncAuditBody =>
      'لا يمكن الاطلاع على محادثاتك إلا للمشرفين المخوّلين، ولأسباب مثل مراجعة البلاغات أو الأمان أو الطلبات القانونية. يُكتب كل اطلاع في سجل وصول لا يمكن حذفه قبل عرض المحتوى.';

  @override
  String get chatEncBlockTitle => 'الحظر والإبلاغ';

  @override
  String get chatEncBlockBody =>
      'يمكنك حظر من لا تريد التواصل معه والإبلاغ عن الرسائل والمستخدمين غير اللائقين. لا تصلك رسائل من حظرتَه.';

  @override
  String get chatEncOnceTitle => 'صورة تُعرض مرة واحدة';

  @override
  String get chatEncOnceBody =>
      'يمكن للمستلم فتح الصورة التي تُعرض مرة واحدة مرة واحدة فقط، ولا يستطيع رؤيتها مجددًا بعد فتحها.';

  @override
  String get chatEncDeleteTitle => 'الحذف للجميع';

  @override
  String get chatEncDeleteBody =>
      'يمكنك حذف رسالتك للجميع، ويرى الآخرون إشعارًا بأنها حُذفت بدل الرسالة.';

  @override
  String get chatEncExifTitle => 'إزالة الموقع من الصور';

  @override
  String get chatEncExifBody =>
      'تتم إعادة ترميز الصور التي ترسلها على الخادم وإزالة بيانات EXIF مثل الموقع.';

  @override
  String get chatEncDataTitle => 'بياناتك لك';

  @override
  String get chatEncDataBody =>
      'من قسم الملف الشخصي يمكنك تنزيل بياناتك أو حذف حسابك.';

  @override
  String get chatEncNoSellTitle => 'لا تُباع ولا تُشارك للإعلانات';

  @override
  String get chatEncNoSellBody =>
      'لا نبيع بياناتك ولا نشاركها مع أطراف ثالثة لأغراض الإعلان.';

  @override
  String get chatEncSecKnow => 'ما ينبغي أن تعرفه';

  @override
  String get chatEncNotE2eeTitle => 'غير مشفّرة من طرف إلى طرف';

  @override
  String get chatEncNotE2eeBody =>
      'الرسائل في هذا التطبيق غير مشفّرة من طرف إلى طرف. تُحفظ مفاتيح التشفير على الخادم، لذلك يمكن للنظام فك تشفير الرسائل عند الضرورة. يرجى استخدام التطبيق مع أخذ ذلك في الاعتبار.';

  @override
  String get chatEncRetainTitle => 'قد يُحتفظ بالمحتوى المحذوف';

  @override
  String get chatEncRetainBody =>
      'قد يُحتفظ على الخادم بنسخة مشفّرة من الرسائل المحذوفة للجميع وسجل تعديلاتها ونسخة مشفّرة من الصور التي تُعرض مرة واحدة لأغراض المراجعة الأمنية. مدد الاحتفاظ مذكورة في سياسة الخصوصية.';

  @override
  String get chatEncMembersTitle => 'الجميع يرى في المجموعات';

  @override
  String get chatEncMembersBody =>
      'يمكن لجميع أعضاء المجموعات وغرف النوادي وغرف الفعاليات رؤية الرسائل في الغرفة.';

  @override
  String get chatEncScreenshotTitle => 'لا يمكن منع لقطات الشاشة';

  @override
  String get chatEncScreenshotBody =>
      'يمكن للطرف الآخر حفظ الرسالة بلقطة شاشة أو بجهاز آخر ومشاركتها. لا يمكننا منع ذلك تمامًا حتى في الصور التي تُعرض مرة واحدة.';

  @override
  String get chatEncAccountTitle => 'تبقى الرسائل بعد حذف الحساب';

  @override
  String get chatEncAccountBody =>
      'إذا حذفت حسابك تُجعل بياناتك الشخصية مجهولة الهوية، وتبقى الرسائل التي أرسلتها جزءًا من المحادثة باسم كاتب مجهول.';

  @override
  String get chatEncSecHelp => 'الإبلاغ والحظر';

  @override
  String chatEncHelpMessage(String report) {
    return 'للإبلاغ عن رسالة، اضغط عليها مطولًا ثم اختر $report.';
  }

  @override
  String chatEncHelpPerson(String block, String report) {
    return 'لحظر شخص أو الإبلاغ عنه في محادثة فردية، اضغط على الاسم في الأعلى، ثم في معلومات المحادثة استخدم $block أو $report.';
  }

  @override
  String get chatEncSecRead => 'المزيد';

  @override
  String get chatEncPrivacyLink => 'سياسة الخصوصية';

  @override
  String get chatEncRulesLink => 'قواعد المجتمع';

  @override
  String get chatEncInfoRow => 'التشفير والأمان';

  @override
  String get chatEncFootnote => 'يتم تشفير رسائلك أثناء النقل وعلى الخادم.';

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
  String get chatInfoSearchInChat => 'البحث في المحادثة';

  @override
  String get chatInfoMediaFiles => 'الوسائط والملفات';

  @override
  String get chatInfoTabPhotos => 'الصور';

  @override
  String get chatInfoTabVideos => 'الفيديوهات';

  @override
  String get chatInfoTabFiles => 'الملفات';

  @override
  String get chatInfoNoPhotos => 'لا توجد صور في هذه المحادثة بعد.';

  @override
  String get chatInfoNoVideos => 'لا توجد فيديوهات في هذه المحادثة بعد.';

  @override
  String get chatInfoFilesUnsupportedTitle => 'مشاركة الملفات غير مدعومة';

  @override
  String get chatInfoFilesUnsupportedBody =>
      'يمكن حاليًا مشاركة الصور والفيديوهات فقط في هذه المحادثة.';

  @override
  String get chatInfoReported => 'تم الإبلاغ';

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
  String get chatStatusSending => 'جارٍ الإرسال…';

  @override
  String get chatStatusSent => 'تم الإرسال';

  @override
  String get chatStatusSeen => 'تمت المشاهدة';

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
  String get shareTitle => 'مشاركة';

  @override
  String get shareSendTo => 'إرسال إلى';

  @override
  String get shareRecent => 'المحادثات الأخيرة';

  @override
  String get shareSearchHint => 'ابحث عن شخص أو محادثة';

  @override
  String get shareNoteHint => 'أضف ملاحظة (اختياري)';

  @override
  String get shareCopyLink => 'نسخ الرابط';

  @override
  String get shareLinkCopied => 'تم نسخ الرابط';

  @override
  String get shareMoreApps => 'تطبيقات أخرى';

  @override
  String get shareExternalFailed => 'تعذّر فتح نافذة المشاركة';

  @override
  String get shareSentOne => 'تم الإرسال';

  @override
  String shareSentMany(String n) {
    return 'تم الإرسال إلى $n محادثات';
  }

  @override
  String get shareQueued => 'لا يوجد اتصال؛ سيتم الإرسال عند عودة الاتصال';

  @override
  String get shareFailedAll => 'تعذّر الإرسال. حاول مجددًا.';

  @override
  String shareFailedSome(String n) {
    return 'تعذّر الإرسال إلى $n محادثات';
  }

  @override
  String get shareKindPost => 'منشور';

  @override
  String get shareKindReel => 'ريلز';

  @override
  String get shareKindNews => 'خبر';

  @override
  String get shareKindAnnouncement => 'إعلان';

  @override
  String get shareKindEvent => 'فعالية';

  @override
  String get shareUnavailable => 'لم يعد هذا المحتوى متاحًا';

  @override
  String get shareChatPostShared => 'شارك منشورًا';

  @override
  String get shareChatReelShared => 'شارك ريلز';

  @override
  String get shareChatNewsShared => 'شارك خبرًا';

  @override
  String get shareChatAnnouncementShared => 'شارك إعلانًا';

  @override
  String get shareChatEventShared => 'شارك فعالية';

  @override
  String get forumActivityAnonBadge => 'مجهول';

  @override
  String get forumActivityAnonBadgeLong => 'منشور مجهول: لا يراه سواك';

  @override
  String get forumActivityAnonymous => 'مجهول';

  @override
  String get forumActivityCommentDeleted => 'تم حذف هذا التعليق';

  @override
  String forumActivityCounts(String likes, String comments) {
    return '$likes إعجاب، $comments تعليق';
  }

  @override
  String get forumActivityEmptyCommentsBody =>
      'ستظهر هنا التعليقات التي تكتبها.';

  @override
  String get forumActivityEmptyCommentsTitle => 'لا توجد تعليقات بعد';

  @override
  String get forumActivityEmptyFollowingBody =>
      'تابع موضوعًا لتصلك التعليقات الجديدة.';

  @override
  String get forumActivityEmptyFollowingTitle => 'لا توجد مواضيع تتابعها';

  @override
  String get forumActivityEmptyTopicsBody =>
      'تظهر هنا المواضيع التي تفتحها. المجهولة منها تظهر لك وحدك.';

  @override
  String get forumActivityEmptyTopicsTitle => 'لم تفتح أي موضوع بعد';

  @override
  String get forumActivityRemoved => 'تمت إزالة هذا الموضوع';

  @override
  String get forumActivitySection => 'المنتدى';

  @override
  String get forumActivityTabComments => 'تعليقاتي';

  @override
  String get forumActivityTabCommentsPublic => 'التعليقات';

  @override
  String get forumActivityTabFollowing => 'ما أتابعه';

  @override
  String get forumActivityTabSaved => 'المحفوظات';

  @override
  String get forumActivityTabTopics => 'مواضيعي';

  @override
  String get forumActivityTabTopicsPublic => 'المواضيع';

  @override
  String get forumActivityTitle => 'نشاطي في المنتدى';

  @override
  String get forumActivityUserEmptyComments => 'لا توجد تعليقات عامة بعد';

  @override
  String get forumActivityUserEmptyTopics => 'لا توجد مواضيع عامة بعد';

  @override
  String forumActivityUserTitle(String name) {
    return 'نشاط $name في المنتدى';
  }

  @override
  String get forumPrefsAll => 'كل إشعارات المنتدى';

  @override
  String get forumPrefsAllSub => 'عند إيقافه تتوقف كل الإشعارات أدناه.';

  @override
  String get forumPrefsFollowed => 'المواضيع التي أتابعها';

  @override
  String get forumPrefsLikes => 'إشعارات الإعجاب';

  @override
  String get forumPrefsModerationNote =>
      'لا يمكن إيقاف إشعارات الإشراف (مثل إزالة محتواك).';

  @override
  String get forumPrefsMutedEmpty => 'لم تكتم أي شخص.';

  @override
  String get forumPrefsMutedSection => 'من كتمتهم';

  @override
  String get forumPrefsNotifLabel => 'المنتدى';

  @override
  String get forumPrefsReplies => 'الردود على تعليقاتي';

  @override
  String get forumPrefsRowSub => 'إشعارات المواضيع والردود والإعجابات';

  @override
  String get forumPrefsRowTitle => 'إشعارات المنتدى';

  @override
  String get forumPrefsTitle => 'إشعارات المنتدى';

  @override
  String get forumPrefsTopicComments => 'إشعارات المواضيع';

  @override
  String get forumPrefsUnmute => 'إلغاء الكتم';

  @override
  String get forumPrefsUnmuted => 'تم إلغاء الكتم';

  @override
  String get forumReportAlready => 'لقد أبلغت عن هذا المحتوى مسبقًا.';

  @override
  String get forumReportAlsoBlock => 'احظر هذا الكاتب أيضًا';

  @override
  String get forumReportAlsoBlockHint =>
      'يختفي محتواه عنك. لا تُعرض هويته أبدًا.';

  @override
  String get forumReportBlockBody =>
      'تختفي عنك كل مواضيع هذا الكاتب وتعليقاته في المنتدى. حتى لو كان مجهولًا لن تعرف هويته.';

  @override
  String get forumReportBlockConfirm => 'حظر';

  @override
  String get forumReportBlockTitle => 'حظر هذا الكاتب؟';

  @override
  String get forumReportBlocked => 'تم حظر الكاتب.';

  @override
  String forumReportMuteBody(String name) {
    return 'يختفي عنك محتوى $name في المنتدى. لا تتأثر المحادثات والملف الشخصي. يمكنك التراجع من الإعدادات.';
  }

  @override
  String get forumReportMuteConfirm => 'كتم';

  @override
  String get forumReportMuteTitle => 'كتم هذا الشخص؟';

  @override
  String get forumReportMuted => 'تم الكتم.';

  @override
  String get forumReportNoteHint => 'هل تريد إضافة ملاحظة؟ (اختياري)';

  @override
  String get forumReportReasonHarassment => 'إساءة أو تحرش';

  @override
  String get forumReportReasonInappropriate => 'محتوى غير لائق';

  @override
  String get forumReportReasonOther => 'أخرى';

  @override
  String get forumReportReasonPersonalInfo => 'مشاركة معلومات شخصية';

  @override
  String get forumReportReasonSpam => 'رسائل مزعجة أو إعلانات';

  @override
  String get forumReportThanks => 'شكرًا، تم إرسال بلاغك إلى فريقنا.';

  @override
  String get forumReportTitle => 'إبلاغ';

  @override
  String get forumSavedEmptyBody =>
      'اضغط على أيقونة الحفظ في المواضيع والتعليقات لإضافتها هنا.';

  @override
  String get forumSavedEmptyTitle => 'لا يوجد شيء محفوظ بعد';

  @override
  String get forumSavedRemove => 'إزالة من المحفوظات';

  @override
  String get forumSavedRemoved => 'أُزيل من المحفوظات';

  @override
  String get forumSavedTitle => 'المحفوظات';

  @override
  String get forumSearchAllCategories => 'الكل';

  @override
  String get forumSearchClearAll => 'مسح';

  @override
  String forumSearchEmptyBody(String q) {
    return 'لا توجد مواضيع مطابقة لـ “$q”. جرّب كلمة أو فئة أخرى.';
  }

  @override
  String get forumSearchEmptyTitle => 'لا توجد نتائج';

  @override
  String get forumSearchHint => 'ابحث في المنتدى';

  @override
  String get forumSearchMatchBody => 'في الوصف';

  @override
  String get forumSearchMatchCategory => 'في الفئة';

  @override
  String get forumSearchMatchComment => 'في تعليق';

  @override
  String get forumSearchMatchTitle => 'في العنوان';

  @override
  String get forumSearchMinChars => 'اكتب حرفين على الأقل.';

  @override
  String get forumSearchPopular => 'المواضيع الشائعة';

  @override
  String get forumSearchPopularEmpty => 'لا توجد مواضيع رائجة حاليًا.';

  @override
  String get forumSearchRecent => 'عمليات البحث الأخيرة';

  @override
  String get forumSearchRemoveRecent => 'حذف البحث';

  @override
  String get forumSearchSortNewest => 'الأحدث';

  @override
  String get forumSearchSortPopular => 'الأكثر شيوعًا';

  @override
  String get forumSearchSortRelevance => 'الأكثر صلة';

  @override
  String get forumSearchStartBody =>
      'ابحث بعنوان الموضوع أو وصفه أو التعليقات أو اسم الفئة.';

  @override
  String get forumSearchStartTitle => 'ابحث في المنتدى';

  @override
  String get forumSearchTitle => 'بحث المنتدى';

  @override
  String get forumShareChatCommentShared => 'شارك تعليقًا من المنتدى';

  @override
  String get forumShareChatTopicShared => 'شارك موضوعًا من المنتدى';

  @override
  String get forumShareKindComment => 'تعليق في المنتدى';

  @override
  String get forumShareKindTopic => 'المنتدى';

  @override
  String get sharePrivateHint =>
      'منشورات الحسابات الخاصة تُشارك مع الأشخاص عبر الرسائل فقط.';

  @override
  String get shareNotFoundTitle => 'المحتوى غير موجود';

  @override
  String get shareNoChats => 'لا توجد محادثات. ابحث للعثور على أشخاص.';

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
      'امنح ما تشاء الآن، ويمكنك تغيير الباقي لاحقًا من الإعدادات.';

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
  String get coreIdEmpty => 'أدخل بريدك الإلكتروني.';

  @override
  String get coreIdEmail => 'أدخل عنوان بريد إلكتروني صالحًا.';

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
  String get eventListShortCodeNeedsEvent =>
      'لا توجد لديك فعالية مفتوحة للحضور الآن. أدخل الرمز القصير في صفحة الفعالية ضمن «إدخال الرمز يدويًا».';

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
      'الموقع المصدر غير متاح، وقد تكون البيانات قديمة.';

  @override
  String get homeSearchHint => 'ابحث في الحرم الجامعي';

  @override
  String get homeMyClubs => 'من أنديتي';

  @override
  String get homeAll => 'الكل';

  @override
  String get homeAgenda => 'المستجدات';

  @override
  String get homeContentLoadFailed => 'تعذر تحميل المحتوى.';

  @override
  String get homeNoContent => 'لا يوجد محتوى.';

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
  String get menuTopUpTitle => 'رصيد بطاقة الطعام';

  @override
  String get menuTopUpBody =>
      'نفد رصيدك؟ يمكنك شحن بطاقة المطعم بأمان عبر yukle.al.';

  @override
  String get menuTopUpAction => 'شحن الرصيد';

  @override
  String get menuTopUpFailed =>
      'تعذر فتح الرابط. يرجى زيارة yukle.al من المتصفح.';

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
  String get notifEmpty => 'لا توجد إشعارات بعد.';

  @override
  String get activityTitle => 'النشاط';

  @override
  String get activityFilterLikes => 'الإعجابات';

  @override
  String get activityFilterComments => 'التعليقات';

  @override
  String get activityFilterFollows => 'المتابعة والطلبات';

  @override
  String get notifFilterEvents => 'الفعاليات';

  @override
  String get notifFilterAnnouncements => 'الإعلانات';

  @override
  String get notifFilterSystem => 'النظام';

  @override
  String get activityRequestStale =>
      'لم يعد هذا الطلب معلقاً؛ ربما تمت معالجته مسبقاً.';

  @override
  String get activityEmpty =>
      'لا يوجد نشاط بعد. تظهر هنا الإعجابات والتعليقات والمتابعون الجدد والطلبات.';

  @override
  String get notifTargetOpenFailed => 'تعذّر فتح هذا الإشعار.';

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
  String get srLoadMore => 'عرض المزيد';

  @override
  String get srSearchHint => 'ابحث عن مستخدم أو منشور';

  @override
  String get srTabUsers => 'المستخدمون';

  @override
  String get srTabPosts => 'المنشورات';

  @override
  String get srTabReels => 'ريلز';

  @override
  String get srSearchTabsLabel => 'أنواع نتائج البحث';

  @override
  String get srSearchPrompt =>
      'اكتب حرفين على الأقل للبحث عن مستخدمين أو منشورات أو ريلز.';

  @override
  String get srSeeAll => 'عرض الكل';

  @override
  String get srReelsUnavailable => 'البحث في الريلز غير متاح حاليًا.';

  @override
  String get srPrivateAccount => 'حساب خاص';

  @override
  String srLikeCount(String count) {
    return '$count إعجاب';
  }

  @override
  String srOpenProfileOf(String name) {
    return 'فتح ملف $name';
  }

  @override
  String srPostByAuthor(String name) {
    return 'منشور $name';
  }

  @override
  String get srVideoBadge => 'فيديو';

  @override
  String get srProfileTabsLabel => 'محتوى الملف الشخصي';

  @override
  String get srProfilePostsEmpty => 'لا توجد منشورات بعد.';

  @override
  String get srProfileReelsEmpty => 'لا توجد ريلز بعد.';

  @override
  String srViewCount(String count) {
    return '$count مشاهدة';
  }

  @override
  String get srPhotoViewerTitle => 'صورة الملف الشخصي';

  @override
  String get srPhotoViewerError => 'تعذّر تحميل الصورة';

  @override
  String get srPhotoViewerClose => 'إغلاق المعاينة';

  @override
  String get srAvatarLongPressHint => 'اضغط مطولًا لعرض الصورة الكبيرة';

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
  String get followReasonClub => 'نادٍ مشترك';

  @override
  String get followReasonGrade => 'نفس السنة الدراسية';

  @override
  String get followReasonDepartment => 'نفس القسم';

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
  String get pollClubEmpty => 'لا توجد استطلاعات بعد.';

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
  String get g2PostQueued => 'المنشور في قائمة الانتظار';

  @override
  String g2PostUploading(String pct) {
    return 'جارٍ رفع المنشور $pct';
  }

  @override
  String get g2PostWaiting => 'بانتظار الاتصال، سيتابع عند عودته';

  @override
  String get g2PostPublishing => 'جارٍ النشر';

  @override
  String get g2PostFailed => 'تعذّر النشر';

  @override
  String get g2PostEdit => 'تعديل';

  @override
  String get g2PostRetry => 'أعد المحاولة';

  @override
  String get g2PostRemove => 'حذف';

  @override
  String get g2PostCancel => 'إلغاء';

  @override
  String get g2PostRemoveTitle => 'هل تريد حذف هذا المنشور؟';

  @override
  String get g2PostRemoveBody =>
      'سيتم حذف النص الذي كتبته والملفات التي اخترتها.';

  @override
  String get g2PostQueuedToast => 'يتم إرسال منشورك في الخلفية.';

  @override
  String get g2PostErrFiles =>
      'لم يتم العثور على الملفات. عدّل المنشور وحاول مجدداً.';

  @override
  String get g2PostPending => 'منشور قيد الانتظار';

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
  String get postPickerCameraHint =>
      'اضغط لالتقاط صورة، واضغط مطولًا لتسجيل فيديو';

  @override
  String get postPickerLimitedBody =>
      'تظهر فقط الصور ومقاطع الفيديو التي سمحت بها. يمكنك إضافة المزيد للمشاركة.';

  @override
  String get postPickerDeniedBody =>
      'اسمح بالوصول إلى المعرض لمشاركة منشور. يمكنك أيضًا الاختيار من معرض النظام.';

  @override
  String get postPickerUseSystem => 'استخدام معرض النظام';

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
  String get profileChangePhotoSemantic => 'تغيير صورة الملف الشخصي';

  @override
  String get profileUploading => 'جارٍ الرفع…';

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
  String get profileFullName => 'الاسم الكامل';

  @override
  String get profileEditNameSemantic => 'تعديل الاسم الكامل';

  @override
  String get profileEditBioSemantic => 'تعديل نبذة عني';

  @override
  String get profileEditDeptSemantic => 'تغيير القسم';

  @override
  String get profileEditGradeSemantic => 'تغيير السنة الدراسية';

  @override
  String get profileBioEmptyCta => 'عرّف بنفسك';

  @override
  String get profileSavingSemantic => 'جارٍ الحفظ';

  @override
  String get profileNameMin => 'يجب أن يتكون الاسم من حرفين على الأقل.';

  @override
  String get profileAbout => 'نبذة عني';

  @override
  String get profileBioHint => 'عرّف بنفسك باختصار';

  @override
  String get profileMenuTitle => 'القائمة';

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
  String get profileSaved => 'الأخبار المحفوظة';

  @override
  String get profileLiked => 'الإعجابات';

  @override
  String get likedAll => 'الكل';

  @override
  String get likedEmpty => 'لم تعجب بأي منشور بعد.';

  @override
  String get likedEmptyReels => 'لم تعجب بأي ريلز بعد.';

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
  String get profilePrefsNotifMessages => 'إشعارات الرسائل (دفع)';

  @override
  String get profilePrefsNotifPolls => 'الاستطلاعات';

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
  String get authSectionPersonal => 'المعلومات الشخصية';

  @override
  String get authHintPersonal => 'أدخل اسمك وعنوان بريدك الإلكتروني.';

  @override
  String get authNext => 'متابعة';

  @override
  String get authTermsAutoPrefix => 'بالتسجيل، فإنك توافق على ';

  @override
  String get authTermsAutoSuffix => '.';

  @override
  String get oaHeadline => 'جامعتك هنا.';

  @override
  String get oaSub => 'شارك واكتشف وانضم إلى مجتمعك.';

  @override
  String get oaContinueGoogle => 'المتابعة باستخدام Google';

  @override
  String get oaContinueApple => 'المتابعة باستخدام Apple';

  @override
  String get oaContinueEmail => 'المتابعة بالبريد الإلكتروني';

  @override
  String get oaOr => 'أو';

  @override
  String get oaLegalLead => 'بالمتابعة فإنك توافق على:';

  @override
  String get oaTermsLink => 'شروط الاستخدام';

  @override
  String get oaPrivacyLink => 'سياسة الخصوصية';

  @override
  String get oaProviderGoogle => 'Google';

  @override
  String get oaProviderApple => 'Apple';

  @override
  String get oaLinkTitle => 'لديك حساب بهذا البريد بالفعل';

  @override
  String oaLinkBody(String provider) {
    return 'سجّل الدخول أولاً بالبريد الإلكتروني وكلمة المرور، ثم اربط حساب $provider من قسم الحساب والأمان.';
  }

  @override
  String oaLinkMasked(String email) {
    return 'الحساب: $email';
  }

  @override
  String get oaErrFailed => 'تعذّر إكمال تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get oaErrTokenInvalid =>
      'تعذّر التحقق من تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get oaErrEmailUnverified =>
      'لم يتم التحقق من البريد الإلكتروني لهذا الحساب لدى المزوّد. تحقق منه أولاً أو تابع بالبريد الإلكتروني.';

  @override
  String get oaErrEmailMissing =>
      'تعذّر الحصول على عنوان بريد إلكتروني من حسابك. يمكنك المتابعة بالبريد الإلكتروني.';

  @override
  String get oaErrDisabled =>
      'طريقة تسجيل الدخول هذه غير متاحة حالياً. يمكنك المتابعة بالبريد الإلكتروني.';

  @override
  String get oaErrLastMethod =>
      'هذه هي الطريقة الوحيدة لتسجيل الدخول إلى حسابك. عيّن كلمة مرور قبل إزالتها.';

  @override
  String get oaErrProfileIncomplete => 'أكمل ملفك الشخصي قبل المتابعة.';

  @override
  String get oaOb1Title => 'لنتعرّف أولاً.';

  @override
  String get oaOb1Sub => 'لنُنشئ ملفك الشخصي في BÜKampüs في بضع خطوات.';

  @override
  String get oaFirstName => 'الاسم';

  @override
  String get oaLastName => 'اللقب';

  @override
  String get oaFirstRequired => 'أدخل اسمك.';

  @override
  String get oaLastRequired => 'أدخل لقبك.';

  @override
  String get oaUsername => 'اسم المستخدم';

  @override
  String get oaUserRule => 'من 3 إلى 24 حرفاً: a-z و 0-9 ونقطة وشرطة سفلية.';

  @override
  String get oaUserChecking => 'جارٍ التحقق…';

  @override
  String get oaUserAvail => 'اسم المستخدم متاح.';

  @override
  String get oaUserTaken => 'اسم المستخدم هذا مستخدم.';

  @override
  String get oaUserInvalid =>
      'يجب أن يتكوّن اسم المستخدم من 3 إلى 24 حرفاً؛ يُسمح فقط بـ a-z و 0-9 والنقطة والشرطة السفلية.';

  @override
  String get oaUserReserved => 'لا يمكن استخدام اسم المستخدم هذا.';

  @override
  String get oaUserRequired => 'اختر اسم مستخدم.';

  @override
  String get oaPhotoOptional => 'صورة الملف الشخصي (اختياري)';

  @override
  String get oaPhotoAdd => 'إضافة صورة';

  @override
  String get oaPhotoChange => 'تغيير الصورة';

  @override
  String oaStepOf(String a, String b) {
    return 'الخطوة $a من $b';
  }

  @override
  String get oaOb2Title => 'أين أنت في الحرم الجامعي؟';

  @override
  String get oaOb2Sub => 'اختر قسمك واكتشف المجتمعات المناسبة لك.';

  @override
  String get oaUniversity => 'الجامعة';

  @override
  String get oaUniversityName => 'جامعة بينغول';

  @override
  String get oaFaculty => 'الكلية';

  @override
  String get oaPickFaculty => 'اختر الكلية';

  @override
  String get oaPickFacultyFirst => 'اختر الكلية أولاً';

  @override
  String get oaSelectFaculty => 'اختر كليتك.';

  @override
  String get oaClassPostgrad => 'دراسات عليا';

  @override
  String get oaClassOther => 'أخرى';

  @override
  String get oaBio => 'نبذة قصيرة (اختياري)';

  @override
  String get oaBioHint => 'عرّف بنفسك في بضع كلمات';

  @override
  String get oaDeclareNote =>
      'المعلومات التي تختارها هي إقرار منك ويمكنك تغييرها من ملفك الشخصي في أي وقت.';

  @override
  String get oaJoin => 'انضم إلى BÜKampüs';

  @override
  String get oaLinkedTitle => 'الحسابات المرتبطة';

  @override
  String get oaLinkedYes => 'مرتبط';

  @override
  String get oaLinkedNo => 'غير مرتبط';

  @override
  String get oaLinkAction => 'ربط';

  @override
  String get oaUnlinkAction => 'إلغاء الربط';

  @override
  String get oaLinkPwTitle => 'أكّد كلمة المرور';

  @override
  String oaLinkPwBody(String provider) {
    return 'أدخل كلمة المرور الحالية لربط حساب $provider.';
  }

  @override
  String get oaPasswordLabel => 'كلمة المرور';

  @override
  String oaLinkDone(String provider) {
    return 'تم ربط حساب $provider.';
  }

  @override
  String get oaUnlinkTitle => 'إزالة الربط؟';

  @override
  String oaUnlinkBody(String provider) {
    return 'سيتم إزالة تسجيل الدخول عبر $provider؛ ستحتاج إلى طريقة أخرى لتسجيل الدخول.';
  }

  @override
  String oaUnlinkDone(String provider) {
    return 'تمت إزالة ربط $provider.';
  }

  @override
  String get oaLinkedFailed => 'تعذّر تحميل الحسابات المرتبطة.';

  @override
  String get authPwMinErr => 'يجب ألا تقل كلمة المرور عن 6 أحرف.';

  @override
  String get authPwMaxErr => 'يجب ألا تزيد كلمة المرور عن 72 حرفًا.';

  @override
  String get authRegIdEmpty => 'أدخل بريدك الإلكتروني.';

  @override
  String get authRegIdFull => 'أدخل عنوان بريدك الإلكتروني كاملاً.';

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
  String get authForgotSubNumber =>
      'أدخل بريدك الإلكتروني. سنرسل رمزًا من 6 أرقام إلى بريدك الإلكتروني.';

  @override
  String get authForgotSub =>
      'أدخل بريدك الإلكتروني وسنرسل لك رمزًا من 6 أرقام.';

  @override
  String get authBackToLogin => 'العودة لتسجيل الدخول';

  @override
  String get realEmailTitle => 'عنوان بريدك الإلكتروني الحقيقي';

  @override
  String get realEmailSubtitle =>
      'لا يستطيع عنوان Apple المخفي استلام الإشعارات ورسائل إعادة تعيين كلمة المرور. أدخل عنوان بريدك الإلكتروني الذي تستخدمه فعليًا؛ سيكون البريد الوحيد لحسابك.';

  @override
  String get realEmailSoftNote =>
      'هذه الخطوة اختيارية لكنها موصى بها لإعادة تعيين كلمة المرور والإشعارات.';

  @override
  String get realEmailSendCode => 'إرسال الرمز';

  @override
  String get realEmailLater => 'ليس الآن';

  @override
  String get realEmailCodeTitle => 'أدخل الرمز';

  @override
  String get realEmailNoCodeHint =>
      'إذا لم يصل الرمز فتحقق من مجلد الرسائل غير المرغوب فيها. إذا كان العنوان مسجلًا في حساب آخر فلا يمكن إكمال التحقق؛ سجّل الدخول إلى ذلك الحساب أو جرّب عنوانًا آخر.';

  @override
  String get realEmailDoneTitle => 'تم تحديث بريدك الإلكتروني';

  @override
  String realEmailDoneBody(String email) {
    return 'أصبح بريد حسابك الإلكتروني $email. ستصل الإشعارات وإعادة تعيين كلمة المرور إلى هذا العنوان.';
  }

  @override
  String get realEmailContinue => 'متابعة';

  @override
  String get realEmailErrRelay =>
      'لا يمكن استخدام عنوان مخفي (مؤقت). أدخل عنوان بريدك الإلكتروني الحقيقي الذي تستخدمه فعليًا.';

  @override
  String get realEmailErrUnavailable =>
      'لا يمكن استخدام عنوان البريد الإلكتروني هذا. جرّب عنوانًا آخر أو سجّل الدخول إلى الحساب المفتوح به.';

  @override
  String get realEmailErrUnchanged =>
      'هذا هو عنوان البريد الإلكتروني الحالي لحسابك بالفعل.';

  @override
  String get realEmailErrRequired =>
      'أضف بريدك الإلكتروني الحقيقي والنشط وتحقّق منه قبل المتابعة.';

  @override
  String get authChangeEmail => 'تغيير البريد الإلكتروني';

  @override
  String get authNewPwSub =>
      'ستحل محل كلمة المرور القديمة. سيتم إنهاء الجلسات على جميع الأجهزة.';

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
  String get welcomeNote =>
      'يمكنك التسجيل ببريد Gmail أو Outlook أو Hotmail أو Yahoo أو أي بريد إلكتروني آخر.';

  @override
  String get welcomeLanguage => 'اللغة';

  @override
  String get chatlistSearchHint => 'ابحث في المحادثات';

  @override
  String get bildirimFilterAll => 'الكل';

  @override
  String get bildirimFilterUnread => 'غير المقروءة';

  @override
  String get bildirimEmptyUnread => 'لا توجد إشعارات غير مقروءة.';

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
  String get kesSegPosts => 'المنشورات';

  @override
  String get kesSegReels => 'ريلز';

  @override
  String get kesPickVideo => 'اختيار فيديو';

  @override
  String get kesRecordVideo => 'تسجيل فيديو';

  @override
  String get kesVideoLimits => 'يمكن أن يصل الفيديو إلى 60 ثانية و50 ميغابايت.';

  @override
  String kesVideoPreparing(String pct) {
    return 'جارٍ تجهيز الفيديو… $pct';
  }

  @override
  String kesVideoUploading(String pct) {
    return 'جارٍ رفع الفيديو… $pct';
  }

  @override
  String get kesVideoChange => 'تغيير الفيديو';

  @override
  String get kesErrVideoTooLarge => 'الفيديو كبير جدًا (50 ميغابايت كحد أقصى).';

  @override
  String get kesFullscreen => 'المشاهدة بملء الشاشة';

  @override
  String get kesReelsEmptyTitle => 'لا توجد ريلز بعد';

  @override
  String get kesReelsEmptyBody => 'كن أول من يشارك فيديو.';

  @override
  String get kesReelsDoneTitle => 'شاهدت كل الفيديوهات حاليًا';

  @override
  String get kesReelsDoneBody => 'ستظهر الفيديوهات الجديدة هنا.';

  @override
  String get kesReelsReplay => 'شاهد مرة أخرى';

  @override
  String get kesReelsToPosts => 'تصفح منشورات الاستكشاف';

  @override
  String get kesActionComments => 'التعليقات';

  @override
  String get kesActionSave => 'حفظ';

  @override
  String get kesActionSaved => 'تم الحفظ';

  @override
  String get kesNotInterested => 'غير مهتم';

  @override
  String get kesNotInterestedDone => 'لن يُقترح هذا الفيديو مرة أخرى.';

  @override
  String get kesMore => 'المزيد من الإجراءات';

  @override
  String kesViews(String count) {
    return '$count مشاهدة';
  }

  @override
  String get kesCoverTitle => 'إطار الغلاف';

  @override
  String get kesCoverHint => 'اختر إطارًا من الفيديو.';

  @override
  String get kesComposeMenuPhoto => 'مشاركة صورة';

  @override
  String get kesComposeMenuVideo => 'مشاركة فيديو / ريلز';

  @override
  String get kesCommentsTitle => 'التعليقات';

  @override
  String get kesCommentsEmpty => 'لا توجد تعليقات بعد.';

  @override
  String get kesCommentsWrite => 'اكتب تعليقًا…';

  @override
  String get kesCommentsSend => 'إرسال';

  @override
  String get kesCommentsReply => 'رد';

  @override
  String kesCommentsReplyingTo(String name) {
    return 'الرد على $name';
  }

  @override
  String kesCommentsMoreReplies(String count) {
    return 'عرض $count ردود';
  }

  @override
  String get kesCommentsLoadFailed => 'تعذّر تحميل التعليقات.';

  @override
  String get kesCommentsDelete => 'حذف التعليق';

  @override
  String get kesAvatarPreview => 'صورة الملف الشخصي';

  @override
  String get kesCommentsSortTop => 'الأفضل';

  @override
  String get kesCommentsSortNew => 'الأحدث';

  @override
  String get kesCommentsAuthorBadge => 'الكاتب';

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
  String get profil2VisShared => 'معارفي';

  @override
  String get profil2VisOnlyMe => 'أنا فقط';

  @override
  String get profil2SharedHintLead => 'معارفي:';

  @override
  String get profil2SharedHintBody =>
      'الأشخاص الذين يشاركونك نادياً أو محادثة أو فعالية.';

  @override
  String get profil2ShowEmail => 'إظهار بريدي الإلكتروني للمستخدمين الآخرين';

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
  String get profil2SecNewHint => '6 أحرف على الأقل';

  @override
  String get profil2SecRepeatLabel => 'كلمة المرور الجديدة (تكرار)';

  @override
  String get profil2SecRepeatHint => 'أعد كتابة كلمة المرور الجديدة';

  @override
  String get profil2SecPwRule =>
      '6 أحرف على الأقل. خلط الحروف والأرقام يجعلها أقوى.';

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
  String get profil1Support => 'المساعدة والدعم';

  @override
  String get profil1Legal => 'الاتفاقيات والسياسات';

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
  String get gonderiTextHint => 'اكتب شيئًا…';

  @override
  String gonderiWordCount(String n, String max) {
    return '$n/$max';
  }

  @override
  String gonderiWordLimit(String max) {
    return 'الحد الأقصى للكلمات: $max.';
  }

  @override
  String get composeTrimTitle => 'قصّ الفيديو';

  @override
  String get composeTrimDone => 'تم';

  @override
  String get composeTrimEdit => 'تعديل';

  @override
  String get composeTrimCta => 'قصّ الفيديو';

  @override
  String get composeTrimming => 'جارٍ قصّ الفيديو…';

  @override
  String composeTrimSelected(String dur) {
    return 'المدة المحددة $dur';
  }

  @override
  String composeTrimHint(String max) {
    return 'اسحب المقبضين لاختيار مقطع. حتى $max.';
  }

  @override
  String composeTrimTooLong(String max) {
    return 'الفيديو طويل جدًا. اختر مقطعًا لا يتجاوز $max لمشاركته.';
  }

  @override
  String get composeTrimStart => 'البداية';

  @override
  String get composeTrimEnd => 'النهاية';

  @override
  String get composeTrimPlay => 'تشغيل';

  @override
  String get composeTrimPause => 'إيقاف مؤقت';

  @override
  String get composeTooLongTitle => 'الفيديو طويل جدًا';

  @override
  String composeTooLongBody(String dur, String max) {
    return 'مدة هذا الفيديو $dur. يمكنك مشاركة $max كحد أقصى، لذا قصّه أولًا.';
  }

  @override
  String get composeTooLongOther => 'اختر فيديو آخر';

  @override
  String composeVideoLimitsHint(String n) {
    return 'حتى $n ثانية؛ يمكنك قصّ الفيديو الأطول.';
  }

  @override
  String get composeTagPerson => 'وسم أشخاص';

  @override
  String composeTagRemove(String name) {
    return 'إزالة وسم $name';
  }

  @override
  String get composeMentionSearch => 'ابحث بين من تتابعهم';

  @override
  String get composeMentionEmpty => 'تابع أشخاصًا لتتمكن من وسمهم';

  @override
  String get composeMentionNoMatch => 'لا يوجد أشخاص مطابقون';

  @override
  String composeMentionMax(String max) {
    return 'يمكنك وسم $max أشخاص كحد أقصى.';
  }

  @override
  String get composeMentionDone => 'تم';

  @override
  String postMentionOpen(String name) {
    return 'فتح ملف $name';
  }

  @override
  String get postComposeErrTextTooLong =>
      'نص المنشور طويل جدًا. اختصره قليلًا وحاول مرة أخرى.';

  @override
  String get gonderiPickPhoto => 'اختر صورة';

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
  String get sistemuiPermCameraTitle => 'الكاميرا والمعرض';

  @override
  String get sistemuiPermCameraText => 'لمسح رموز QR والتقاط الصور ومشاركتها.';

  @override
  String get sistemuiOfflineTitle => 'لا يوجد اتصال';

  @override
  String get sistemuiOfflineBody => 'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';

  @override
  String get sistemuiErrorTitle => 'حدث خطأ ما';

  @override
  String get sistemuiMaintTitle => 'النظام قيد الصيانة';

  @override
  String get sistemuiMaintBody => 'حاول مرة أخرى بعد قليل. بياناتك في أمان.';

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
  String get profilyardClubsEmptyTitle => 'لم تنضم إلى أي نادٍ بعد.';

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
  String get profilyardEventsEmptyTitle => 'لا توجد فعاليات ستحضرها بعد.';

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
  String get updateRequiredFromStore => 'يرجى التحديث من المتجر';

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
  String get chatRealtimeLost =>
      'انقطع الاتصال المباشر؛ تُحدَّث الرسائل بشكل دوري.';

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
  String get p05SearchNoResultsBody => 'جرّب كلمة مختلفة.';

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
  String get p01ConfigTitle => 'يتعذر الاتصال الآن';

  @override
  String get p01ConfigBody =>
      'الخدمة غير متاحة حالياً. يرجى المحاولة لاحقاً. إذا استمرت المشكلة، تأكد من تحديث التطبيق.';

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
  String get p03MenuKcalMissing => 'لم تُدخل السعرات الحرارية لبعض الأطباق.';

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
      'تظهر هنا إشعارات الأندية والفعاليات والرسائل.';

  @override
  String get p03NotifUnreadEmptyBody => 'لقد قرأت كل شيء.';

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
  String get p05NewsErrorTitle => 'تعذّر تحميل المحتوى';

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
  String get p17CourseInfoSemantic => 'تفاصيل المقرر';

  @override
  String get p20HubExamPlan => 'خطة الجلسات';

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
  String get p05NewsLoadingMore => 'جارٍ التحميل';

  @override
  String get p05SavedDiscover => 'استكشف الأخبار';

  @override
  String get p05SavedEmptyTitle2 => 'لا توجد أخبار محفوظة بعد.';

  @override
  String get p05SavedEmptyBody2 =>
      'استخدم علامة الحفظ في صفحة الخبر لإضافة الأخبار هنا.';

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
  String get p20RemHourSub =>
      'يصل من الخادم حتى لو كان التطبيق مغلقًا؛ ويتبع إعداد الإعلانات الأكاديمية';

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
  String get p04FeedErrTitle => 'تعذّر التحميل';

  @override
  String get p04FeedErrBody => 'تحقق من اتصالك ثم حاول مجددًا.';

  @override
  String get p09ForwardDirect => 'محادثة فردية';

  @override
  String get p03HomeBrandSub => 'تطبيق طلابي مستقل';

  @override
  String get p03HomeQuickTitle => 'وصول سريع';

  @override
  String get p03HomeQuickEvents => 'الفعاليات';

  @override
  String get p03HomeQuickSchedule => 'الجدول';

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

  @override
  String get p18ProfileTitle => 'ملفي';

  @override
  String get p18ProfileLoadFailed => 'تعذّر التحميل، حاول مرة أخرى';

  @override
  String p15PercentFull(String n) {
    return '$n% ممتلئ';
  }

  @override
  String get p15ChatSub => 'تعرّف على المشاركين والمنظّم';

  @override
  String get p15ChatLockedSub => 'متاح للمشاركين المعتمدين فقط';

  @override
  String get p15AboutTitle => 'عن الفعالية';

  @override
  String get p15AttOpenHint =>
      'امسح رمز QR في القاعة أو أدخل الرمز الذي أعلنه المنظّم لتسجيل حضورك.';

  @override
  String get p15CheckedInBody => 'تم تسجيل حضورك في الفعالية.';

  @override
  String get p15CancelledNotice => 'تم إلغاء هذه الفعالية.';

  @override
  String get p15StatusInterested => 'مهتم';

  @override
  String p15AttendeesLine(String going, String interested) {
    return '$going مشارك · $interested مهتم';
  }

  @override
  String get p13SuppFaqHeading => 'الأسئلة الشائعة';

  @override
  String get p13SuppToday => 'اليوم';

  @override
  String get p23GroupNameHint => 'مثال: فريق مشروع الهندسة...';

  @override
  String p09GradeYear(String n) {
    return 'السنة $n';
  }

  @override
  String get p14UpcomingOther => 'فعاليات الأيام القادمة';

  @override
  String get p14ErrorBodyCache =>
      'حدثت مشكلة أثناء الاتصال بالخادم. تُعرض النسخة المخزّنة دون اتصال.';

  @override
  String get p14Completed => 'اكتملت';

  @override
  String get p15LockedBadge => 'مقفل';

  @override
  String get p15CancelledBody => 'يتم إشعار المشاركين.';

  @override
  String get eventEndedNotice => 'انتهت هذه الفعالية.';

  @override
  String get eventEndedBody => 'تم إغلاق الانضمام والطلبات.';

  @override
  String get notifEventEnded => 'انتهت';

  @override
  String get notifEventCancelled => 'أُلغيت';

  @override
  String get p15WontHappen => 'لن تقام';

  @override
  String get p15AnswerHint => 'أخبرنا باختصار...';

  @override
  String get p15NoteHint => 'أي ملاحظة إضافية تودّ إيصالها...';

  @override
  String p15CodeChars(String n) {
    return '$n حرف';
  }

  @override
  String get p15LeaveHint => 'يمكنك تغيير حالة مشاركتك في أي وقت.';

  @override
  String get p15SettingsSub => 'نوع المشاركة والسعة والتسجيل';

  @override
  String get p15ClearField => 'مسح';

  @override
  String get p18SecPrefs => 'تفضيلات التطبيق';

  @override
  String get p18SecAccount => 'الحساب والأمان';

  @override
  String get p18SecAbout => 'حول والدعم';

  @override
  String get p18CounterClubs => 'الأندية';

  @override
  String get p18CounterEvents => 'الفعاليات';

  @override
  String get p18ClearSearch => 'مسح البحث';

  @override
  String p18NavUnread(String n) {
    return '$n غير مقروءة';
  }

  @override
  String get p19PushOffShort => 'متوقف';

  @override
  String get p19SaveFailedSub => 'حدث خطأ في الاتصال.';

  @override
  String get p20GradeLevel => 'المستوى الدراسي';

  @override
  String get p21ChanChatDesc =>
      'رسائل المحادثات الفردية والجماعية. تصل بصوت واهتزاز.';

  @override
  String get p21ChanEventDesc => 'تذكيرات الفعاليات والتغييرات ونتائج الحضور.';

  @override
  String get p21ChanAnnouncementDesc =>
      'إشعارات الأخبار والإعلانات والأندية والنظام.';

  @override
  String get p21ChanSocialDesc => 'إشعارات الإعجاب والمتابعة. تصل بصمت.';

  @override
  String get p21ChanPollDesc => 'الاستطلاعات الجديدة ونتائجها.';

  @override
  String get p21ChanAcademicDesc => 'تذكيرات محلية قبل المحاضرات والامتحانات.';

  @override
  String get p21HelpTitle => 'الإشعارات لا تعمل؟';

  @override
  String get p21HelpLink => 'الإشعارات لا تعمل؟';

  @override
  String get p21HelpAllGood => 'كل شيء يبدو سليماً على هذا الجهاز.';

  @override
  String get p21HelpSomeIssue =>
      'هناك ما يمنعك من تلقي الإشعارات. راجع الخطوات أدناه.';

  @override
  String get p21HelpPermTitle => 'إذن الإشعارات';

  @override
  String get p21HelpPermOk => 'إشعارات التطبيق مفعّلة.';

  @override
  String get p21HelpPermOff =>
      'الإشعارات معطّلة من إعدادات النظام. لن تصلك أي إشعارات قبل تفعيلها.';

  @override
  String get p21HelpChanTitle => 'فئات الإشعارات';

  @override
  String get p21HelpChanChat =>
      'فئة الرسائل معطّلة من إعدادات النظام. فعّلها وإلا لن تصلك إشعارات الرسائل الجديدة.';

  @override
  String get p21HelpChanOther =>
      'بعض فئات الإشعارات معطّلة من إعدادات النظام. فعّل ما تريده.';

  @override
  String get p21HelpDeviceTitle => 'تسجيل هذا الجهاز';

  @override
  String get p21HelpDeviceOk => 'جهازك مسجّل ليتمكن الخادم من إرسال الإشعارات.';

  @override
  String get p21HelpDeviceBad =>
      'جهازك غير مسجّل بعد. تحقق من اتصال الإنترنت ثم سجّله مجدداً.';

  @override
  String get p21HelpDeviceUnsupported =>
      'الإشعارات الفورية غير مهيأة في هذا الإصدار.';

  @override
  String get p21HelpDeviceRetry => 'إعادة التسجيل';

  @override
  String get p21HelpBatteryTitle => 'البطارية والخلفية';

  @override
  String get p21HelpBatteryOem =>
      'قد يغلق هاتفك التطبيق لتوفير البطارية. إذا لم تصل الإشعارات والتطبيق مغلق، أزل القيود عن BÜ Kampüs في إعدادات البطارية، وفعّل التشغيل التلقائي إن وُجد، وثبّت التطبيق في التطبيقات الأخيرة.';

  @override
  String get p21HelpBatteryGeneric =>
      'إذا لم تصل الإشعارات والتطبيق مغلق، أزل قيود البطارية عن BÜ Kampüs في إعدادات البطارية. إغلاق التطبيق بالسحب من التطبيقات الأخيرة يوقف الإشعارات في بعض الهواتف.';

  @override
  String get p21HelpBatteryOpen => 'فتح إعدادات البطارية';

  @override
  String get p21HelpFooter =>
      'قد تمنع ساعات الهدوء وتفضيلات الإشعارات وصول الإشعار أيضاً. تحقق منها في تفضيلات الإشعارات.';

  @override
  String get p22SaveGalleryTitle => 'حفظ الصور في المعرض';

  @override
  String get p22SaveGalleryDesc =>
      'تُحفظ الصور التي تستلمها وترسلها في المحادثات في معرض هاتفك، ولا تُحفظ الصور ذات العرض لمرة واحدة.';

  @override
  String get p22SaveGalleryCloud =>
      'إذا كان النسخ الاحتياطي السحابي لمعرضك مفعّلاً فقد تُرفع الصور إليه أيضاً.';

  @override
  String get p22SaveDeniedToast =>
      'تعذّر حفظ الصور في المعرض لأن الإذن غير ممنوح. يمكنك السماح به من الإعدادات.';

  @override
  String get p22OpenSettings => 'الإعدادات';

  @override
  String get p26PrefPollsNeedsParents =>
      'لن تصلك إشعارات الاستطلاعات عند إيقاف الإعلانات أو الأندية';

  @override
  String get p32ExportShareFailed =>
      'تعذّر تجهيز بياناتك للمشاركة. يُرجى المحاولة مرة أخرى.';

  @override
  String get p31ChatPlaceholderBlocked => 'رسالة مستخدم قمت بحظره مخفية';

  @override
  String get p31ChatPlaceholderUnreadable => 'تعذّر عرض هذه الرسالة';

  @override
  String p31ChatMsgTooLong(String max) {
    return 'يجب ألا تتجاوز الرسالة $max حرفًا.';
  }

  @override
  String get p31ChatRemovedToast => 'تمت إزالتك من هذه المحادثة.';

  @override
  String get p30AutosaveConsentTitle => 'حفظ الصور في المعرض؟';

  @override
  String get p30AutosaveConsentBody =>
      'تُحفظ الصور التي ترسلها وتستقبلها في المحادثات الفردية في معرض هاتفك (ألبوم BU Kampus). لا تُحفظ الصور ذات المشاهدة الواحدة. يمكنك إيقاف ذلك من هنا في أي وقت.';

  @override
  String get p30AutosaveConsentOk => 'تشغيل';

  @override
  String get p60EditHome => 'تعديل الصفحة الرئيسية';

  @override
  String get p60EditHint => 'رتّب الأقسام بالسحب وأظهرها أو أخفِها بالمفتاح.';

  @override
  String get p60Done => 'تم';

  @override
  String get p60ResetDefault => 'استعادة الافتراضي';

  @override
  String get p60SectionClasses => 'دروس اليوم';

  @override
  String p60MoveUp(String name) {
    return 'انقل $name للأعلى';
  }

  @override
  String p60MoveDown(String name) {
    return 'انقل $name للأسفل';
  }

  @override
  String get p60Shortcuts => 'اختيار الاختصارات';

  @override
  String p60ShortcutsCount(String n) {
    return '$n اختصارات';
  }

  @override
  String get p60ShortcutsHint => 'اختر حتى 5 اختصارات؛ اسحب لتغيير الترتيب.';

  @override
  String get p60EmptyTitle => 'صفحتك الرئيسية فارغة';

  @override
  String get p60EmptyAction => 'إضافة قسم';

  @override
  String get p60NoClassesToday => 'لا دروس اليوم';

  @override
  String get p60NoTimetable => 'لم تتم إضافة جدول دروس';

  @override
  String get p60ShortSearch => 'بحث';

  @override
  String get p67ChatBgTitle => 'خلفية المحادثة';

  @override
  String get p67ChatBgPattern => 'نقش';

  @override
  String get p67ChatBgSoft => 'خفيف';

  @override
  String get p67ChatBgStrong => 'متوسط';

  @override
  String get p67ChatBgPlain => 'سادة';

  @override
  String get p67ChatBgPreviewIn => 'مرحبا، نراك في المحاضرة.';

  @override
  String get p67ChatBgPreviewOut => 'حسنا، نراك لاحقا.';

  @override
  String get p67SettingsChats => 'المحادثات';

  @override
  String get p67AttachAllowPhotos => 'السماح بالوصول إلى الصور';

  @override
  String p67PickerSend(String n) {
    return 'إرسال ($n)';
  }

  @override
  String get p66HelpPrompt => 'لا تستطيع تسجيل الدخول؟';

  @override
  String get p66HelpAction => 'احصل على مساعدة';

  @override
  String get p66HelpSub =>
      'إذا تعذّر عليك تسجيل الدخول فراسلنا. سنرسل رمز التحقق إلى بريدك الإلكتروني.';

  @override
  String get p66FieldName => 'الاسم الكامل';

  @override
  String get p66FieldEmail => 'البريد الإلكتروني';

  @override
  String get p66FieldTopic => 'الموضوع';

  @override
  String get p66FieldMessage => 'رسالتك';

  @override
  String get p66ErrName => 'أدخل اسمك الكامل.';

  @override
  String get p66ErrEmail => 'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get p66ErrMsgShort => 'يجب ألا تقل الرسالة عن 10 أحرف.';

  @override
  String get p66ErrMsgLong => 'يجب ألا تزيد الرسالة عن 2000 حرف.';

  @override
  String get p66ReplyNote => 'سنرسل الرد إلى بريدك الإلكتروني.';

  @override
  String get p66CodeSix => 'أدخل الرمز المكوّن من 6 أرقام.';

  @override
  String get p66CodeBad => 'الرمز غير صحيح أو انتهت صلاحيته.';

  @override
  String get p66TrackTitle => 'طلبك';

  @override
  String get p66TrackYou => 'أنت';

  @override
  String get p66TrackStaff => 'فريق الدعم';

  @override
  String get p66TrackHint => 'اكتب ردّك';

  @override
  String get p66TrackSend => 'إرسال';

  @override
  String get p66TrackClosed => 'تم إغلاق هذا الطلب.';

  @override
  String get p66MyTicket => 'طلبي';

  @override
  String get p66AboutBody =>
      'تطبيق طلابي مستقل مخصص لطلاب وموظفي جامعة بينغول.';

  @override
  String get p67AttachRecent => 'أحدث الصور';

  @override
  String get p67AttachOnceHint =>
      'لإرسال صورة تُعرض مرة واحدة، اختر الصورة ثم المس الرمز 1.';

  @override
  String get p67AttachGrant => 'سماح';

  @override
  String get p51ClubsEmpty => 'لا توجد أندية بعد.';

  @override
  String get p51ClubsLoadFailed => 'تعذّر التحميل، حاول مجددًا';

  @override
  String get p51Managed => 'أديرها';

  @override
  String get p51RoleMember => 'عضو';

  @override
  String get p51AwaitingReply => 'بانتظار الرد';

  @override
  String p51ApplyDate(String date) {
    return 'تاريخ الطلب: $date';
  }

  @override
  String get p51AboutFounded => 'التأسيس';

  @override
  String get p51CreateClubTitle => 'إنشاء نادٍ';

  @override
  String get p51Create => 'إنشاء';

  @override
  String get p51JoinApproval => 'بطلب';

  @override
  String get p51DescLabel => 'الوصف';

  @override
  String get p51DescHint => 'صف هدف ناديك وأهدافه باختصار…';

  @override
  String get p51AddJoinQuestion => 'إضافة سؤال انضمام';

  @override
  String get p64CropDone => 'تم';

  @override
  String get p64FeedOffline =>
      'أنت غير متصل. قد تكون المنشورات المعروضة قديمة.';

  @override
  String get p67ChatBgDensity => 'الكثافة';

  @override
  String get p67ChatBgApply => 'تطبيق';

  @override
  String get p67ChatBgReset => 'العودة إلى الافتراضي';

  @override
  String get p67ChatBgStyleCampus => 'الحرم';

  @override
  String get p67ChatBgStyleStudy => 'الدراسة';

  @override
  String get p67ChatBgStyleSocial => 'اجتماعي';

  @override
  String get p67ChatBgStyleScience => 'العلوم';

  @override
  String get p67ChatBgStyleGeometry => 'هندسي';

  @override
  String get p67ChatBgStyleLabel => 'النقش';

  @override
  String p67PickerLimit(String max) {
    return 'يمكنك اختيار $max عناصر كحد أقصى.';
  }

  @override
  String get p51EvEmptyDayBody => 'اختر يومًا آخر أو تصفّح الأندية.';

  @override
  String get p51EvBrowseAll => 'استكشف كل الأندية';

  @override
  String get p51EvOffline => 'أنت غير متصل. تُعرض الفعاليات المحفوظة.';

  @override
  String get p69WeeklyFlow => 'الجدول الأسبوعي';

  @override
  String p69WeekN(String n) {
    return 'الأسبوع $n';
  }

  @override
  String get p69Done => 'اكتملت';

  @override
  String get p69LastSession => 'آخر محاضرة';

  @override
  String p69Hours(String h) {
    return '$h ساعة';
  }

  @override
  String p69TodayTotal(String n, String hours) {
    return 'اليوم: $n محاضرات في المجموع ($hours)';
  }

  @override
  String get p69ExamCalendar => 'جدول الامتحانات';

  @override
  String get p69Now => 'الآن';

  @override
  String get p69ExamName => 'اسم الامتحان';

  @override
  String get p69ExamNameHint => 'مثال: امتحان منتصف الفصل في هياكل البيانات';

  @override
  String get p69ExamNameErr => 'اسم الامتحان مطلوب.';

  @override
  String get p69PickCourse => 'اختر مقررًا';

  @override
  String get p69DateLabel => 'التاريخ';

  @override
  String get p69TimeLabel => 'الوقت';

  @override
  String get p69ExamNote =>
      'ستصلك تذكير محلي قبل الامتحان بيوم وإشعار فوري قبله بساعتين.';

  @override
  String p69SemesterTerm(String name) {
    return 'فصل $name';
  }

  @override
  String get p69TodayJump => 'العودة إلى اليوم';

  @override
  String get p69Events => 'الأحداث الأكاديمية';

  @override
  String p69Records(String n) {
    return '$n عناصر';
  }

  @override
  String get p69ExamReminder => 'تذكير الامتحان';

  @override
  String get p69ExamReminderSub =>
      'على هاتفك قبل الامتحان بيوم، وكإشعار قبله بساعتين.';

  @override
  String p69ClassReminderSub(String n) {
    return 'قبل المحاضرة بـ $n دقيقة.';
  }

  @override
  String get p69Duration => 'المدة';

  @override
  String get p69Classes => 'المحاضرات';

  @override
  String get p69RemindersFooter => 'تُنشأ التذكيرات على هذا الهاتف.';

  @override
  String get p69PermOff =>
      'إذن الإشعارات متوقف. اسمح به من الإعدادات لتلقي التذكيرات.';

  @override
  String get p69NoExams => 'لم تضف أي امتحان بعد.';

  @override
  String get p68New => 'جديد';

  @override
  String get p68FormKind => 'النوع';

  @override
  String get p68OptionsLabel => 'الخيارات (2-12)';

  @override
  String get p68PickDate => 'اختر تاريخًا';

  @override
  String get p68Retract => 'سحب صوتي';

  @override
  String get p68MyVote => 'صوتك';

  @override
  String p68TicketNo(String n) {
    return 'التذكرة #$n';
  }

  @override
  String get p68Required => 'مطلوب';

  @override
  String get p68SubjectLabel => 'الموضوع';

  @override
  String get p68SubjectHint => 'ماذا حدث باختصار؟';

  @override
  String get p68SubjectMin => 'يجب ألا يقل الموضوع عن 3 أحرف.';

  @override
  String get p68MessageLabel => 'الرسالة';

  @override
  String get p68MessageHint => 'اشرح المشكلة أو الطلب خطوة بخطوة…';

  @override
  String get p68ReplyNote => 'ستصلك الإجابة بإشعار وبريد إلكتروني.';

  @override
  String get p68CategoryLabel => 'الفئة';

  @override
  String get p68ReplyHint => 'اكتب ردك';

  @override
  String get p68Staff => 'الدعم';

  @override
  String get p68NoTickets => 'ليس لديك طلبات بعد.';

  @override
  String get p68SugTitle => 'الاقتراحات';

  @override
  String get p68SugSend => 'أرسل اقتراحًا';

  @override
  String get p68SugTop => 'الأكثر تصويتًا';

  @override
  String get p68SugNew => 'الأحدث';

  @override
  String get p68SugEmpty => 'لا توجد اقتراحات بعد.';

  @override
  String get p51EvAttOpen => 'تسجيل الحضور مفتوح';

  @override
  String get p51EvScanQr => 'سجّل حضورك برمز QR';

  @override
  String get p51EvGoingYou => 'ستحضر';

  @override
  String get p51EvLblDate => 'التاريخ';

  @override
  String get p51EvLblTime => 'الوقت';

  @override
  String get p51EvLblPlace => 'المكان';

  @override
  String get p51EvLblAttendees => 'المشاركون';

  @override
  String p51EvPeople(String count) {
    return '$count شخص';
  }

  @override
  String get p51EvQrTitle => 'رمز QR للحضور';

  @override
  String get p51EvReqTitle => 'الطلبات';

  @override
  String get p51EvTabPending => 'قيد الانتظار';

  @override
  String get p51EvTabApproved => 'المقبولة';

  @override
  String get p51EvTabRejected => 'المرفوضة';

  @override
  String p51EvQuota(String cap, String going) {
    return 'السعة $cap · $going مقبول';
  }

  @override
  String p51EvQuotaGoing(String n) {
    return '$n مقبول';
  }

  @override
  String get p51EvQuotaNote => 'لا يمكن قبول طلبات جديدة عند اكتمال السعة.';

  @override
  String p51EvPresentAbsent(String present, String absent) {
    return '$present حضروا · $absent لم يحضروا';
  }

  @override
  String p51EvTotalPeople(String count) {
    return 'الإجمالي $count شخص';
  }

  @override
  String get p68TypeMulti => 'متعدد';

  @override
  String get p68TypeRanked => 'مرتّب';

  @override
  String get p51EvAttList => 'قائمة الحضور';

  @override
  String get p51EvClubOnly => 'تُنشأ الفعاليات باسم الأندية.';

  @override
  String get p60Today => 'اليوم في الحرم الجامعي';

  @override
  String get p60NextClass => 'الدرس القادم';

  @override
  String get p60UpcomingExam => 'الاختبار القادم';

  @override
  String get p60OpenMenu => 'فتح القائمة';

  @override
  String get p60NoNews => 'لا توجد أخبار بعد.';

  @override
  String get p60NoAnnouncements => 'لا توجد إعلانات بعد.';

  @override
  String p60Classroom(String room) {
    return 'القاعة $room';
  }

  @override
  String get p60EmptySub => 'لم تختر أي قسم للعرض.';

  @override
  String get p60Selected => 'الاختصارات المحددة (الترتيب)';

  @override
  String get p60AllShortcuts => 'كل الاختصارات';

  @override
  String p60Remove(String name) {
    return 'إزالة $name';
  }

  @override
  String get p60ShortScheduleFull => 'جدول الدروس';

  @override
  String p63NewsLastUpdate(String when) {
    return 'آخر تحديث: $when';
  }

  @override
  String get frqPrivateTitle => 'حساب خاص';

  @override
  String get frqPrivateSub =>
      'في الحساب الخاص لا يرى منشوراتك وقائمة متابعيك إلا من توافق عليهم. يبقى متابعوك الحاليون.';

  @override
  String get frqPrivateOffTitle => 'جعل الحساب عامًا؟';

  @override
  String get frqPrivateOffBody =>
      'تُقبل طلبات المتابعة المعلّقة تلقائيًا. سيتمكن الجميع من رؤية منشوراتك وقائمة متابعيك.';

  @override
  String get frqPrivateOffConfirm => 'جعله عامًا';

  @override
  String get frqFollowRequested => 'تم إرسال الطلب';

  @override
  String get frqSemRequested => 'تم إرسال طلب المتابعة. المس لسحبه';

  @override
  String get frqUnfollowTitle => 'إلغاء المتابعة؟';

  @override
  String get frqUnfollowBody => 'لن تتابع هذا الشخص بعد الآن.';

  @override
  String get frqUnfollowBodyPrivate =>
      'هذا الحساب خاص. إذا ألغيت المتابعة فعليك إرسال طلب جديد.';

  @override
  String get frqUnfollowConfirm => 'إلغاء المتابعة';

  @override
  String get frqCancelReqTitle => 'سحب الطلب؟';

  @override
  String get frqCancelReqBody =>
      'سيتم سحب طلب المتابعة. يمكنك إرساله مجددًا لاحقًا.';

  @override
  String get frqCancelReqConfirm => 'سحب الطلب';

  @override
  String get frqLockedTitle => 'هذا الحساب خاص';

  @override
  String get frqLockedBody => 'أرسل طلب متابعة لترى منشوراته.';

  @override
  String get frqLockedBodyRequested =>
      'ستتمكن من رؤية منشوراته عند الموافقة على طلبك.';

  @override
  String get frqReqTitle => 'طلبات المتابعة';

  @override
  String frqReqRow(String n) {
    return 'طلبات المتابعة ($n)';
  }

  @override
  String frqReqPending(String n) {
    return 'الطلبات المعلّقة ($n)';
  }

  @override
  String get frqReqAccept => 'قبول';

  @override
  String get frqReqDecline => 'حذف';

  @override
  String frqReqAcceptSem(String name) {
    return 'قبول طلب $name';
  }

  @override
  String frqReqDeclineSem(String name) {
    return 'حذف طلب $name';
  }

  @override
  String get frqReqEmpty => 'لا توجد طلبات متابعة معلّقة.';

  @override
  String get frqNotifTypeFollow => 'متابعة';

  @override
  String frqMsgReqRow(String n) {
    return 'طلبات الرسائل ($n)';
  }

  @override
  String get frqMsgReqTitle => 'طلبات الرسائل';

  @override
  String get frqMsgReqInfo =>
      'تظهر هنا رسائل الأشخاص الذين لا تتابعهم ولا يشاركونك نادياً أو فعالية. حتى تقبل الطلب لا يرى المرسل ما إذا قرأت رسائله. عند الرد يُقبل الطلب تلقائيًا.';

  @override
  String get frqMsgReqAccept => 'قبول';

  @override
  String get frqMsgReqDecline => 'حذف';

  @override
  String get frqMsgReqGroupInvite => 'دعوة إلى مجموعة';

  @override
  String get frqMsgReqEmpty => 'لا توجد طلبات رسائل معلّقة.';

  @override
  String get frqMsgReqDeclineGroupTitle => 'حذف دعوة المجموعة؟';

  @override
  String get frqMsgReqDeclineGroupBody =>
      'ستغادر المجموعة ولن يتمكن الشخص الذي أضافك من إضافتك مرة أخرى.';

  @override
  String get frqMsgReqDeclineGroupConfirm => 'حذف الدعوة';

  @override
  String get homeBrandSubtitle => 'تطبيق حرم جامعة بينغول';

  @override
  String get homeLibrary => 'المكتبة';

  @override
  String get homeFeaturedSchedule => 'جدول الدروس';

  @override
  String get homeFeaturedMenu => 'قائمة الطعام';

  @override
  String get homeMenuRate => 'قيّم القائمة';

  @override
  String get homeMenuPhotoPending => 'بانتظار صورة جديدة';

  @override
  String get homeSearchFilters => 'فلاتر البحث';

  @override
  String get homeMore => 'المزيد';

  @override
  String get homeViewAll => 'عرض الكل';

  @override
  String get homeJoinedEvents => 'الفعاليات التي انضممت إليها';

  @override
  String get regTitle => 'أنشئ حسابك';

  @override
  String get regSubtitle =>
      'أدخل اسمك وعنوان بريدك الإلكتروني وكلمة مرور. سيُرسل رمز التحقق إلى بريدك الإلكتروني.';

  @override
  String get profileSetupTitle => 'اختر قسمك';

  @override
  String get profileSetupSubtitle =>
      'أدخل قسمك وصفك مرة واحدة؛ يمكنك تغييرهما لاحقًا من ملفك الشخصي.';

  @override
  String get photoSetupTitle => 'هل تريد إضافة صورة للملف الشخصي؟';

  @override
  String get photoSetupSubtitle =>
      'سيتعرّف عليك الطلاب الآخرون بسهولة أكبر. يمكنك إضافتها أو تغييرها من ملفك الشخصي في أي وقت.';

  @override
  String get photoSetupPick => 'اختر صورة';

  @override
  String get photoSetupChange => 'تغيير';

  @override
  String get photoSetupSkip => 'تخطَّ الآن';

  @override
  String get photoSetupAvatarSemantic => 'اختيار صورة الملف الشخصي';

  @override
  String get avatarEdTitle => 'تعديل الصورة';

  @override
  String get avatarEdCancel => 'إلغاء';

  @override
  String get avatarEdDone => 'تم';

  @override
  String get avatarEdUndo => 'تراجع';

  @override
  String get avatarEdRedo => 'إعادة';

  @override
  String get avatarEdTabCrop => 'اقتصاص';

  @override
  String get avatarEdTabBg => 'الخلفية';

  @override
  String get avatarEdTabFilter => 'فلتر';

  @override
  String get avatarEdTabAdjust => 'ضبط';

  @override
  String get avatarEdRotateLeft => 'تدوير لليسار';

  @override
  String get avatarEdRotateRight => 'تدوير لليمين';

  @override
  String get avatarEdMirror => 'قلب أفقي';

  @override
  String get avatarEdReset => 'إعادة ضبط';

  @override
  String get avatarEdZoom => 'التقريب';

  @override
  String get avatarEdAngle => 'الزاوية';

  @override
  String get avatarEdBgBlur => 'ضبابية';

  @override
  String get avatarEdBgWhite => 'أبيض';

  @override
  String get avatarEdBgBlack => 'أسود';

  @override
  String get avatarEdBgBrand => 'لون الهوية';

  @override
  String get avatarEdBgNavy => 'كحلي';

  @override
  String get avatarEdBgSand => 'رملي';

  @override
  String get avatarEdBgHint =>
      'إذا كانت الصورة أصغر من الإطار، تُملأ المساحة الفارغة بهذه الخلفية.';

  @override
  String get avatarEdFOriginal => 'الأصلية';

  @override
  String get avatarEdFVivid => 'نابض';

  @override
  String get avatarEdFCool => 'بارد';

  @override
  String get avatarEdFWarm => 'دافئ';

  @override
  String get avatarEdFMono => 'أبيض وأسود';

  @override
  String get avatarEdFFaded => 'باهت';

  @override
  String get avatarEdBrightness => 'السطوع';

  @override
  String get avatarEdContrast => 'التباين';

  @override
  String get avatarEdSaturation => 'التشبع';

  @override
  String get avatarEdWarmth => 'الدفء';

  @override
  String get avatarEdVignette => 'التعتيم الحواف';

  @override
  String get avatarEdStageSemantic =>
      'منطقة تعديل الصورة. اسحب، وقرّب أو بعّد بإصبعين، وانقر مرتين للملاءمة.';

  @override
  String get photoEdTabRatio => 'النسبة';

  @override
  String get photoEdRatioFree => 'حر';

  @override
  String get photoEdRatioHint =>
      'اختر نسبة الإطار؛ تُقصّ الصورة وفقها. «حر» يحافظ على نسبة الصورة الأصلية.';

  @override
  String get avatarSheetTitle => 'صورة الملف الشخصي';

  @override
  String get avatarRemoveTitle => 'هل تريد إزالة صورة ملفك الشخصي؟';

  @override
  String get avatarRemoveBody =>
      'ستظهر الصورة الافتراضية. يمكنك إضافة صورة من جديد في أي وقت.';

  @override
  String get avatarRemoveConfirm => 'إزالة';

  @override
  String get avatarCropTitle => 'ضبط الصورة';

  @override
  String get avatarCropConfirm => 'تأكيد';

  @override
  String get avatarCropCancel => 'إلغاء';

  @override
  String get avatarCropHint =>
      'قرّب بإصبعين واسحب لضبط الموضع. هكذا تظهر في ملفك الشخصي.';

  @override
  String get avatarUpdated => 'تم تحديث صورة ملفك الشخصي.';

  @override
  String get avatarRemoved => 'تمت إزالة صورة ملفك الشخصي.';

  @override
  String get campusAbout => 'نبذة';

  @override
  String get campusSort => 'ترتيب';

  @override
  String get settingsAnalytics => 'تحليل الاستخدام';

  @override
  String get settingsAnalyticsSub =>
      'تُرسل بيانات الاستخدام، مثل مدة البقاء في الشاشات والإجراءات، لتحسين التطبيق. لا يتم إرسال محتوى الرسائل أو نص البحث أو البيانات الشخصية. عند الإيقاف يتوقف الجمع وتُحذف البيانات المعلقة.';

  @override
  String get chatSecureCaptured =>
      'لا يمكن عرض هذا المحتوى أثناء تسجيل الشاشة.';

  @override
  String get chatSecureScreenshot => 'تم اكتشاف لقطة شاشة. تم إغلاق الصورة.';

  @override
  String get chatSecureProtectedTitle => 'حماية من التقاط الشاشة';

  @override
  String get chatSecureProtectedBody =>
      'يمكن عرض هذه الصورة مرة واحدة فقط وهي محمية.';

  @override
  String get chatSecureUnsupportedTitle => 'لا يمكن الفتح بأمان على هذا الجهاز';

  @override
  String get chatSecureUnsupportedBody =>
      'تعذّر إعداد الحماية من التقاط الشاشة، لذلك لم تُفتح هذه الصورة ذات العرض لمرة واحدة ولم يُستهلك حقّ العرض.';

  @override
  String get chatSecureRevokedBody =>
      'أُغلقت الصورة لأن الحماية من التقاط الشاشة توقفت عن العمل.';

  @override
  String get verifyEmailBannerTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String get verifyEmailBannerBody =>
      'إلى أن يتم التحقق، بعض الإجراءات (المنشورات والرسائل والمتابعة...) غير متاحة.';

  @override
  String get verifyEmailBannerCta => 'أدخل الرمز';

  @override
  String get verifySheetTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String get verifySheetBody =>
      'أدخل الرمز المكوّن من 6 أرقام المرسل إلى بريدك الإلكتروني.';

  @override
  String get verifyQuotaInfo =>
      'تعذّر إرسال رسالة التحقق حاليًا، وسنرسلها في أقرب وقت. يمكنك إدخال الرمز هنا عند وصوله.';

  @override
  String get verifyDone => 'تم التحقق من بريدك الإلكتروني';

  @override
  String get errEmailVerificationRequired =>
      'تحقق من بريدك الإلكتروني للقيام بذلك';

  @override
  String get notifActionAck => 'فهمت';

  @override
  String get notifActionQuickReply => 'رد سريع';

  @override
  String get notifActionOpenAll => 'فتح الكل';

  @override
  String get notifActionProgram => 'تفاصيل البرنامج';

  @override
  String notifKcalTotal(String n) {
    return 'المجموع $n سعرة';
  }

  @override
  String notifOldTime(String time) {
    return 'الوقت السابق: $time';
  }

  @override
  String notifNewTime(String time) {
    return 'الوقت الجديد $time';
  }

  @override
  String get notifBadgeImportant => 'مهم';

  @override
  String get notifSourceModeration => 'الإشراف';

  @override
  String notifAgoMin(String n) {
    return 'منذ $n د';
  }

  @override
  String notifAgoHour(String n) {
    return 'منذ $n س';
  }

  @override
  String notifAgoDay(String n) {
    return 'منذ $n يوم';
  }

  @override
  String notifYesterdayAt(String time) {
    return 'أمس $time';
  }

  @override
  String notifNewCount(String n) {
    return '$n جديد';
  }

  @override
  String notifGroupUnread(String n) {
    return '$n غير مقروء';
  }

  @override
  String get notifPrefMealMenu => 'قائمة اليوم';

  @override
  String get notifPrefMealMenuSub => 'إشعار بقائمة طعام اليوم. متوقف افتراضيا.';

  @override
  String get notifExamAlarmOn => 'التذكير مفعل';

  @override
  String get notifExamAlarmOff => 'التذكير متوقف';

  @override
  String notifCapacityFull(String n) {
    return 'السعة: $n% ممتلئة';
  }

  @override
  String get alarmClockNote =>
      'تُضاف المنبّهات إلى تطبيق الساعة في هاتفك. لحذفها افتح تطبيق الساعة.';

  @override
  String get alarmIosNote =>
      'لا يسمح iPhone بإضافة منبّهات إلى تطبيق الساعة. هذا الإشعار يحلّ محل المنبّه وقد لا يصدر صوتًا في الوضع الصامت.';

  @override
  String get alarmUnavailable =>
      'لم يتم العثور على تطبيق الساعة على هذا الجهاز.';

  @override
  String get alarmNotifOff =>
      'الإشعارات مغلقة. فعّلها من الإعدادات > BÜ Kampüs > الإشعارات لتصلك التذكيرات.';

  @override
  String get alarmExamAction => 'ضبط منبّهات أول امتحان';

  @override
  String get alarmExamActionIos => 'تذكيري بالامتحانات بإشعارات';

  @override
  String get alarmExamSheetTitle => 'منبّهات يوم الامتحان';

  @override
  String get alarmExamSheetTitleIos => 'إشعارات يوم الامتحان';

  @override
  String get alarmExamSheetSub =>
      'مرة واحدة، قبل ساعة من أول امتحان في كل يوم فقط.';

  @override
  String alarmExamRow(String exam, String alarm) {
    return 'امتحان $exam ← منبّه $alarm';
  }

  @override
  String alarmExamSkipped(String times) {
    return 'لا منبّه لامتحان $times';
  }

  @override
  String get alarmExamNone => 'لا توجد امتحانات قادمة لضبط منبّهات لها.';

  @override
  String alarmExamDeferred(String n) {
    return '$n منبّه لتواريخ لاحقة. لا يدعم تطبيق الساعة في Android منبّهًا لمرة واحدة في تاريخ بعيد، لذا نذكّرك مساء اليوم السابق للامتحان لتضبطه بلمسة واحدة.';
  }

  @override
  String get alarmExamDeferredRow => 'يُذكَّر مساء اليوم السابق';

  @override
  String alarmSetCount(String n) {
    return 'ضبط $n منبّه';
  }

  @override
  String alarmNotifyCount(String n) {
    return 'جدولة $n إشعار';
  }

  @override
  String alarmDoneSet(String n) {
    return 'تم ضبط $n منبّه. تحقّق منها في تطبيق الساعة.';
  }

  @override
  String alarmDoneNotif(String n) {
    return 'تمت جدولة $n إشعار.';
  }

  @override
  String alarmDoneDeferred(String n) {
    return 'سيتم تذكيرك قبل يوم الامتحان بـ $n منبّه.';
  }

  @override
  String alarmDoneFail(String n) {
    return 'تعذّر ضبط $n منبّه.';
  }

  @override
  String alarmDueBanner(String n) {
    return '$n منبّه امتحان جاهز للضبط.';
  }

  @override
  String get alarmDueAction => 'اضبط الآن';

  @override
  String get alarmNudgeTitle => 'اضبط منبّه الامتحان';

  @override
  String alarmNudgeBody(String title, String time) {
    return '$title: منبّه $time جاهز. المس لضبطه من صفحة الامتحانات.';
  }

  @override
  String alarmExamLabel(String time, String title) {
    return 'امتحان $time: $title';
  }

  @override
  String get alarmExamNotifTitle => 'منبّه: الامتحان بعد ساعة';

  @override
  String get alarmClassAction => 'ضبط منبّهات الصباح';

  @override
  String get alarmClassActionIos => 'إشعارات محاضرات الصباح';

  @override
  String get alarmClassSheetTitle => 'منبّهات محاضرات الصباح';

  @override
  String get alarmClassSheetTitleIos => 'إشعارات محاضرات الصباح';

  @override
  String get alarmClassSheetSub =>
      'إذا بدأت أول محاضرة في اليوم قبل الظهر: قبل ساعة، وتتكرر كل أسبوع.';

  @override
  String alarmClassRow(String classTime, String alarm) {
    return 'محاضرة $classTime ← منبّه $alarm · أسبوعيًا';
  }

  @override
  String alarmClassSkipped(String days) {
    return '$days: أول محاضرة بعد الظهر، لا منبّه';
  }

  @override
  String get alarmClassNone => 'لا توجد محاضرات صباحية؛ لن يُضبط منبّه.';

  @override
  String alarmClassLabel(String time) {
    return 'منبّه المحاضرة · الأولى $time';
  }

  @override
  String get alarmClassNotifTitle => 'منبّه: المحاضرة بعد ساعة';

  @override
  String alarmClassNotifBody(String time) {
    return 'تبدأ أول محاضرة لك الساعة $time.';
  }

  @override
  String alarmRepeatWarn(String date) {
    return 'تم ضبط هذه المنبّهات في $date. قد يؤدي ضبطها مجددًا إلى تكرارها في تطبيق الساعة.';
  }

  @override
  String get alarmSetAnyway => 'اضبط على أي حال';

  @override
  String alarmDoneClassSet(String n) {
    return 'تم ضبط $n منبّه متكرر. تحقّق منها أو احذفها من تطبيق الساعة.';
  }

  @override
  String get calSyncRowTitle => 'إضافة إلى تقويم الجهاز';

  @override
  String get calSyncRowSub =>
      'التقويم الأكاديمي كاملًا مع تذكير الساعة 08:00 في اليوم نفسه';

  @override
  String calSyncRowDone(String n) {
    return 'في تقويم الجهاز · $n حدث';
  }

  @override
  String get calSyncRowDoneSub => 'حدّث أو أزل';

  @override
  String get calSyncSheetBody =>
      'يُكتب التقويم الأكاديمي للأشهر الاثني عشر القادمة كأحداث. تحصل الأحداث طوال اليوم على تذكير الساعة 08:00 في يومها، ويُرسل تطبيق التقويم الإشعار. تُضاف أحداث BÜ Kampüs وتُحذف فقط.';

  @override
  String get calSyncTarget => 'التقويم';

  @override
  String get calSyncNewLocal => 'BÜ Kampüs (تقويم محلي جديد)';

  @override
  String get calSyncAdd => 'إضافة إلى التقويم';

  @override
  String get calSyncUpdate => 'تحديث';

  @override
  String get calSyncRemove => 'إزالة من التقويم';

  @override
  String get calSyncRemoveTitle => 'إزالة أحداث BÜ Kampüs؟';

  @override
  String calSyncRemoveBody(String n) {
    return 'سيتم حذف $n حدث أضافها هذا التطبيق إلى تقويمك. لا تتأثر أحداثك الأخرى.';
  }

  @override
  String calSyncResult(String added, String updated, String same) {
    return 'أُضيف $added وحُدّث $updated وبقي $same دون تغيير.';
  }

  @override
  String calSyncRemovedN(String n) {
    return 'أُزيل $n.';
  }

  @override
  String calSyncFailedN(String n) {
    return 'تعذّرت كتابة $n.';
  }

  @override
  String get calSyncRationale =>
      'يلزم الوصول إلى التقويم لكتابة التقويم الأكاديمي في تقويم جهازك. تُضاف أحداث BÜ Kampüs وتُحذف فقط ولا يُمسّ غيرها.';

  @override
  String get calSyncDenied =>
      'إذن التقويم مغلق. فعّله من الإعدادات > BÜ Kampüs > التقويم.';

  @override
  String get calSyncOpenSettings => 'فتح الإعدادات';

  @override
  String get calSyncNoCalendar =>
      'لا يوجد تقويم قابل للكتابة على الجهاز. سيتم إنشاء تقويم محلي باسم BÜ Kampüs.';

  @override
  String get calSyncFetchError =>
      'تعذّر تحميل التقويم الأكاديمي. تحقّق من الاتصال وأعد المحاولة.';

  @override
  String get calSyncEmpty =>
      'لا توجد إدخالات حالية في التقويم الأكاديمي لكتابتها.';

  @override
  String get calSyncUnavailable =>
      'الوصول إلى التقويم غير مدعوم على هذا الجهاز.';

  @override
  String calSyncRemoveDone(String n) {
    return 'تمت إزالة $n حدث من التقويم.';
  }

  @override
  String get calSyncCreateFail => 'تعذّر إنشاء التقويم.';

  @override
  String get calSyncWorking => 'جارٍ الكتابة إلى التقويم…';

  @override
  String get tfTitle => 'المصادقة الثنائية';

  @override
  String get tfSecSection => 'أمان تسجيل الدخول';

  @override
  String get tfOn => 'مفعّلة';

  @override
  String get tfOff => 'متوقفة';

  @override
  String get tfToggleSubOff =>
      'متوقفة. عند تسجيل الدخول من جهاز غير معروف يُرسل رمز إلى بريدك الإلكتروني.';

  @override
  String get tfToggleSubOn =>
      'مفعّلة. يُطلب الرمز المرسل إلى بريدك الإلكتروني عند الدخول من جهاز غير معروف.';

  @override
  String get tfIntro =>
      'عند الدخول إلى حسابك من جهاز غير معروف يُرسل رمز من 6 أرقام إلى بريدك الإلكتروني. لا يُطلب الرمز على الأجهزة الموثوقة.';

  @override
  String get tfDevicesSection => 'الأجهزة الموثوقة';

  @override
  String get tfDevicesEmpty =>
      'لا توجد أجهزة موثوقة بعد. فعّل خيار الوثوق بهذا الجهاز عند تسجيل الدخول ليظهر هنا.';

  @override
  String get tfDeviceThis => 'هذا الجهاز';

  @override
  String get tfDeviceUnnamed => 'جهاز';

  @override
  String tfDeviceLastUsed(String date) {
    return 'آخر استخدام $date';
  }

  @override
  String get tfDeviceRemove => 'إزالة الجهاز';

  @override
  String get tfDeviceRemoveTitle => 'هل تريد إزالة الجهاز؟';

  @override
  String get tfDeviceRemoveBody =>
      'سيُطلب الرمز مجددًا عند الدخول التالي من هذا الجهاز. لن تُغلق الجلسة المفتوحة.';

  @override
  String get tfDeviceRemoveConfirm => 'إزالة';

  @override
  String get tfDeviceRemoved => 'تمت إزالة الجهاز.';

  @override
  String get tfEnabledToast => 'تم تفعيل المصادقة الثنائية.';

  @override
  String get tfDisabledToast => 'تم إيقاف المصادقة الثنائية.';

  @override
  String tfEnableSubtitle(String email) {
    return 'لتفعيلها أدخل الرمز المكوّن من 6 أرقام المرسل إلى $email. الرمز صالح لمدة 10 دقائق.';
  }

  @override
  String get tfEnableSubtitleNoMail =>
      'لتفعيلها أدخل الرمز المكوّن من 6 أرقام المرسل إلى بريدك الإلكتروني. الرمز صالح لمدة 10 دقائق.';

  @override
  String get tfDisableTitle => 'هل تريد إيقاف المصادقة الثنائية؟';

  @override
  String get tfDisableBody =>
      'أكّد بإدخال كلمة المرور. تُحذف كل الأجهزة الموثوقة ويصبح حسابك محميًا بكلمة المرور فقط.';

  @override
  String get tfDisableConfirm => 'إيقاف';

  @override
  String get tfWrongPassword => 'كلمة المرور غير صحيحة.';

  @override
  String tfLoginSubtitle(String email) {
    return 'لتسجيل الدخول أدخل الرمز المكوّن من 6 أرقام المرسل إلى $email. الرمز صالح لمدة 10 دقائق.';
  }

  @override
  String get tfLoginSubtitleNoMail =>
      'لتسجيل الدخول أدخل الرمز المكوّن من 6 أرقام المرسل إلى بريدك الإلكتروني. الرمز صالح لمدة 10 دقائق.';

  @override
  String get tfTrustLabel => 'الوثوق بهذا الجهاز';

  @override
  String get tfTrustHint =>
      'لن يُطلب الرمز عند الدخول لاحقًا من هذا الجهاز. فعّله فقط على هاتفك الشخصي.';

  @override
  String get tfBackToLogin => 'العودة إلى تسجيل الدخول';

  @override
  String get tfErrCodeInvalid => 'رمز التحقق غير صحيح أو انتهت صلاحيته.';

  @override
  String get tfErrChallengeExpired =>
      'انتهت صلاحية جلسة التحقق. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get tfErrLocked =>
      'تم إدخال عدد كبير من رموز التحقق الخاطئة؛ تم قفل الدخول من جهاز جديد لمدة 24 ساعة. يمكنك الدخول من جهاز موثوق أو إعادة تعيين كلمة المرور.';

  @override
  String get tfErrAlreadyEnabled => 'المصادقة الثنائية مفعّلة بالفعل.';

  @override
  String get tfErrNotEnabled => 'المصادقة الثنائية غير مفعّلة.';

  @override
  String get chatArchiveBarTitle => 'المؤرشفة';

  @override
  String chatArchiveBarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار',
      many: '$count إشعارًا',
      few: '$count إشعارات',
      two: 'إشعاران',
      one: 'إشعار واحد',
    );
    return '$_temp0';
  }

  @override
  String chatArchiveBarSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إشعار',
      many: '$count إشعارًا',
      few: '$count إشعارات',
      two: 'إشعاران',
      one: 'إشعار واحد',
    );
    return 'المؤرشفة، $_temp0';
  }

  @override
  String forumCommentLikeSemantic(String n) {
    return 'إعجاب، $n';
  }

  @override
  String forumCommentUnlikeSemantic(String n) {
    return 'إلغاء الإعجاب، $n';
  }

  @override
  String get forumCommentReadMore => 'اقرأ المزيد';

  @override
  String get forumCommentReadLess => 'عرض أقل';

  @override
  String get forumDetailDeletedAccount => 'حساب محذوف';

  @override
  String get forumCommentDeletedPlaceholder => 'تم حذف هذا التعليق';

  @override
  String get forumCommentAuthorBadge => 'الكاتب';

  @override
  String get forumCommentEdited => 'تم التعديل';

  @override
  String get forumCommentReply => 'رد';

  @override
  String get forumCommentMore => 'المزيد';

  @override
  String get forumCommentLockedHint =>
      'هذا الموضوع مقفل ولا يمكن التعليق عليه.';

  @override
  String get forumCommentEditingBanner => 'تعدّل تعليقك';

  @override
  String forumCommentReplyingTo(String name) {
    return 'ترد على $name';
  }

  @override
  String get forumCommentCancelTarget => 'إلغاء الرد أو التعديل';

  @override
  String get forumCommentHint => 'اكتب تعليقًا…';

  @override
  String get forumCommentHintReply => 'اكتب ردك…';

  @override
  String get forumCommentAnonLabel => 'التعليق بشكل مجهول';

  @override
  String forumCommentCounter(String n, String max) {
    return '$n / $max';
  }

  @override
  String get forumCommentSend => 'إرسال';

  @override
  String get forumCommentSaveEdit => 'حفظ';

  @override
  String forumCommentShowReplies(String n) {
    return 'عرض $n ردًا';
  }

  @override
  String forumCommentReplyContext(String name) {
    return 'رد على $name';
  }

  @override
  String get forumModRemoveAction => 'إزالة (مشرف)';

  @override
  String get forumModReasonTitle => 'إزالة المحتوى';

  @override
  String get forumModReasonBody =>
      'يُرسل السبب إلى صاحب المحتوى ويُسجَّل في سجل الإشراف.';

  @override
  String get forumModReasonHint => 'السبب (3 أحرف على الأقل)';

  @override
  String get forumModRemoveConfirm => 'إزالة';

  @override
  String get forumModRemovedDone => 'تمت إزالة المحتوى.';

  @override
  String get forumCommentHideReplies => 'إخفاء الردود';

  @override
  String forumCommentMoreReplies(String n) {
    return '$n ردود أخرى';
  }

  @override
  String get forumCommentMoreRepliesGeneric => 'المزيد من الردود';

  @override
  String forumCommentOpenChain(String n) {
    return 'فتح سلسلة الردود ($n)';
  }

  @override
  String get forumCommentRepliesFailed => 'تعذّر تحميل الردود.';

  @override
  String get forumCommentActionEdit => 'تعديل';

  @override
  String get forumCommentActionDelete => 'حذف';

  @override
  String get forumCommentActionCopy => 'نسخ النص';

  @override
  String get forumCommentActionShare => 'مشاركة الرابط';

  @override
  String get forumCommentActionLike => 'إعجاب';

  @override
  String get forumCommentActionUnlike => 'إلغاء الإعجاب';

  @override
  String get forumCommentActionSave => 'حفظ';

  @override
  String get forumCommentActionUnsave => 'إزالة من المحفوظات';

  @override
  String get forumCommentActionReport => 'إبلاغ';

  @override
  String get forumCommentActionBlock => 'حظر المستخدم';

  @override
  String get forumCommentCopied => 'تم نسخ النص';

  @override
  String get forumCommentDeleted => 'تم حذف التعليق';

  @override
  String get forumCommentDeleteTitle => 'حذف هذا التعليق؟';

  @override
  String get forumCommentDeleteBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get forumCommentDeleteConfirm => 'حذف';

  @override
  String get forumCommentBlockTitle => 'حظر هذا المستخدم؟';

  @override
  String get forumCommentBlockBody =>
      'لن ترى محتوى هذا الشخص بعد الآن. لا تُكشف هوية الكاتب المجهول أبدًا.';

  @override
  String get forumCommentBlockConfirm => 'حظر';

  @override
  String get forumCommentBlocked => 'تم حظر المستخدم';

  @override
  String get forumCommentSaved => 'تم الحفظ';

  @override
  String get forumCommentUnsaved => 'تمت الإزالة من المحفوظات';

  @override
  String get forumCommentGone =>
      'هذا التعليق لم يعد موجودًا. تم تحديث القائمة.';

  @override
  String get forumCommentConflict =>
      'تم تغيير التعليق في مكان آخر. تم تحديث القائمة.';

  @override
  String get forumCommentSent => 'تم نشر تعليقك';

  @override
  String get forumCommentReplySent => 'تم نشر ردك';

  @override
  String get forumCommentEditDone => 'تم تحديث التعليق';

  @override
  String get forumCommentLinkNotFound => 'تعذّر العثور على التعليق في الرابط';

  @override
  String get forumDetailSortBest => 'الأفضل';

  @override
  String get forumDetailSortNewest => 'الأحدث';

  @override
  String get forumDetailSortOldest => 'الأقدم';

  @override
  String forumDetailCommentsHeader(String n) {
    return 'التعليقات ($n)';
  }

  @override
  String get forumDetailNoComments => 'لا توجد تعليقات بعد';

  @override
  String get forumDetailNoCommentsBody => 'كن أول من يعلّق.';

  @override
  String get forumDetailCommentsError => 'تعذّر تحميل التعليقات';

  @override
  String get forumDetailSlow => 'الاتصال بطيء، يرجى الانتظار قليلًا…';

  @override
  String get forumDetailSemanticTitle => 'الموضوع';

  @override
  String get forumDetailNotFoundTitle => 'هذا الموضوع لم يعد موجودًا';

  @override
  String get forumDetailNotFoundBody => 'ربما تم حذفه أو إزالته.';

  @override
  String get forumDetailRemovedTitle => 'تمت إزالة هذا الموضوع';

  @override
  String get forumDetailRemovedBody => 'تمت إزالته وفقًا لقواعد المجتمع.';

  @override
  String get forumDetailLockedBanner =>
      'هذا الموضوع مقفل. لا يمكن إضافة تعليقات جديدة.';

  @override
  String get forumDetailPinned => 'مثبّت';

  @override
  String get forumDetailEdited => 'تم التعديل';

  @override
  String get forumDetailLikeAction => 'إعجاب';

  @override
  String get forumDetailUnlikeAction => 'إلغاء الإعجاب';

  @override
  String get forumDetailSaveAction => 'حفظ';

  @override
  String get forumDetailUnsaveAction => 'إزالة من المحفوظات';

  @override
  String get forumDetailFollowAction => 'متابعة';

  @override
  String get forumDetailUnfollowAction => 'إلغاء المتابعة';

  @override
  String get forumDetailShareAction => 'مشاركة';

  @override
  String get forumDetailCommentsAction => 'الانتقال إلى التعليقات';

  @override
  String forumDetailCommentCount(String n) {
    return '$n تعليقات';
  }

  @override
  String forumDetailLikeCount(String n) {
    return '$n إعجاب';
  }

  @override
  String get forumDetailMenu => 'خيارات الموضوع';

  @override
  String get forumDetailMenuEdit => 'تعديل الموضوع';

  @override
  String get forumDetailMenuDelete => 'حذف الموضوع';

  @override
  String get forumDetailMenuNotificationsOff => 'إيقاف الإشعارات';

  @override
  String get forumDetailMenuNotificationsOn => 'تشغيل الإشعارات';

  @override
  String get forumDetailMenuShare => 'مشاركة الرابط';

  @override
  String get forumDetailMenuPin => 'تثبيت الموضوع';

  @override
  String get forumDetailMenuUnpin => 'إلغاء تثبيت الموضوع';

  @override
  String get forumDetailMenuLock => 'قفل التعليقات';

  @override
  String get forumDetailMenuUnlock => 'فتح التعليقات';

  @override
  String get forumDetailMenuReport => 'إبلاغ';

  @override
  String get forumDetailMenuBlock => 'حظر الكاتب';

  @override
  String get forumDetailDeleteTitle => 'حذف هذا الموضوع؟';

  @override
  String get forumDetailDeleteBody =>
      'ستتم إزالة الموضوع وتعليقاته. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get forumDetailDeleteConfirm => 'حذف';

  @override
  String get forumDetailDeleted => 'تم حذف الموضوع';

  @override
  String get forumDetailBlockTitle => 'حظر هذا الكاتب؟';

  @override
  String get forumDetailBlockBody =>
      'لن ترى محتوى هذا الكاتب بعد الآن. إن كان مجهولًا فلن تُكشف هويته.';

  @override
  String get forumDetailBlockConfirm => 'حظر';

  @override
  String get forumDetailBlocked => 'تم حظر الكاتب';

  @override
  String get forumDetailNotificationsOffDone => 'تم إيقاف إشعارات هذا الموضوع';

  @override
  String get forumDetailNotificationsOnDone => 'تم تشغيل إشعارات هذا الموضوع';

  @override
  String get forumDetailPinnedDone => 'تم تثبيت الموضوع';

  @override
  String get forumDetailUnpinnedDone => 'تم إلغاء التثبيت';

  @override
  String get forumDetailLockedDone => 'تم قفل التعليقات';

  @override
  String get forumDetailUnlockedDone => 'تم فتح التعليقات';

  @override
  String forumDetailImageIndex(String i, String n) {
    return '$i / $n';
  }

  @override
  String forumDetailImageSemantic(String i, String n) {
    return 'صورة الموضوع $i من $n';
  }

  @override
  String get forumDetailChainRoot => 'سلسلة الردود';

  @override
  String get forumDetailFollowing => 'تتم متابعة الموضوع';

  @override
  String get forumDetailUnfollowed => 'تم إلغاء متابعة الموضوع';

  @override
  String get forumDetailSaved => 'تم حفظ الموضوع';

  @override
  String get forumDetailUnsaved => 'تمت الإزالة من المحفوظات';

  @override
  String get forumDetailLockedChip => 'مقفل';

  @override
  String get forumComposeClose => 'إغلاق';

  @override
  String get forumComposePublish => 'نشر';

  @override
  String get forumComposePublishing => 'جارٍ النشر';

  @override
  String get forumComposeTitleHint => 'العنوان';

  @override
  String get forumComposeBodyHint => 'ماذا تريد أن تناقش؟';

  @override
  String get forumComposeCategoryLabel => 'الفئة';

  @override
  String get forumComposeCategoryPick => 'اختر فئة';

  @override
  String get forumComposeCategoryLoading => 'جارٍ تحميل الفئات';

  @override
  String get forumComposeCategoryError => 'تعذر تحميل الفئات';

  @override
  String get forumComposeRetry => 'حاول مرة أخرى';

  @override
  String get forumComposeAddImage => 'إضافة صورة';

  @override
  String forumComposeImageCount(int count, int max) {
    return '$count/$max صور';
  }

  @override
  String get forumComposeGallery => 'اختيار من المعرض';

  @override
  String get forumComposeCamera => 'التقاط صورة';

  @override
  String get forumComposeImageRemove => 'إزالة الصورة';

  @override
  String get forumComposeImageUploading => 'جارٍ رفع الصورة';

  @override
  String get forumComposeImageRetry => 'إعادة رفع الصورة';

  @override
  String get forumComposeImagesPending => 'يمكنك النشر بعد اكتمال رفع الصور.';

  @override
  String get forumComposeImageFailedHint =>
      'تعذر رفع صورة. أعد المحاولة أو أزلها.';

  @override
  String get forumComposeErrImageTooLarge => 'الصورة كبيرة جدًا.';

  @override
  String get forumComposeErrImageType => 'يمكن إضافة صور JPEG وPNG وWebP فقط.';

  @override
  String get forumComposeErrImageRead => 'تعذرت قراءة الصورة.';

  @override
  String get forumComposeErrImageUpload => 'تعذر رفع الصورة.';

  @override
  String get forumComposePollAdd => 'إضافة استطلاع';

  @override
  String get forumComposeAnonymous => 'النشر بشكل مجهول';

  @override
  String get forumComposeAnonymousDesc => 'لا يظهر اسمك للطلاب الآخرين.';

  @override
  String get forumComposeAnonymousNote =>
      'يمكن للمشرفين مراجعة إساءة الاستخدام.';

  @override
  String get forumComposeNeedTitle => 'اكتب عنوانًا.';

  @override
  String get forumComposeNeedBody => 'اكتب وصفًا.';

  @override
  String get forumComposeNeedCategory => 'اختر فئة.';

  @override
  String get forumComposeNeedPoll =>
      'يجب أن يحتوي الاستطلاع على خيارين على الأقل.';

  @override
  String get forumComposeDraftRestored => 'تمت استعادة المسودة';

  @override
  String get forumComposeDraftSheetTitle => 'هل تريد حفظ مسودة؟';

  @override
  String get forumComposeDraftSheetBody => 'سيعود ما كتبته في المرة القادمة.';

  @override
  String get forumComposeDraftSave => 'حفظ المسودة';

  @override
  String get forumComposeDraftDelete => 'حذف';

  @override
  String get forumComposeDraftContinue => 'متابعة';

  @override
  String get forumComposeErrNetwork =>
      'لا يوجد اتصال بالإنترنت. تم الاحتفاظ بما كتبته.';

  @override
  String get forumComposeErrRate =>
      'أنت تنشر بوتيرة عالية. انتظر قليلًا ثم حاول مجددًا.';

  @override
  String get forumComposeErrDuplicate => 'لقد نشرت المحتوى نفسه قبل قليل.';

  @override
  String get forumComposeErrProfanity =>
      'يحتوي النص على ألفاظ غير لائقة. عدّله وحاول مجددًا.';

  @override
  String get forumComposeErrCategory =>
      'هذه الفئة لم تعد متاحة. اختر فئة أخرى.';

  @override
  String get forumComposeErrInvalid =>
      'المحتوى غير صالح. تحقق من العنوان والوصف.';

  @override
  String get forumComposeErrGeneric =>
      'تعذر نشر الموضوع. تم الاحتفاظ بما كتبته، حاول مجددًا.';

  @override
  String get forumComposeEditSave => 'حفظ';

  @override
  String get forumComposeEditSaving => 'جارٍ الحفظ';

  @override
  String get forumComposeEditLocked => 'هذا الموضوع مقفل ولا يمكن تعديله.';

  @override
  String get forumComposeEditGone => 'هذا الموضوع لم يعد موجودًا.';

  @override
  String get forumComposeEditNotOwner => 'يمكن للمالك فقط تعديل هذا الموضوع.';

  @override
  String get forumComposeEditSaved => 'تم التعديل';

  @override
  String get forumComposeEditNote => 'لا يمكن تغيير الصور والاستطلاع لاحقًا.';

  @override
  String get forumPollQuestionHint => 'السؤال (اختياري)';

  @override
  String forumPollOptionHint(int n) {
    return 'الخيار $n';
  }

  @override
  String get forumPollAddOption => 'إضافة خيار';

  @override
  String get forumPollRemoveOption => 'إزالة الخيار';

  @override
  String forumPollMaxOptions(int max) {
    return 'يمكن إضافة $max خيارات كحد أقصى.';
  }

  @override
  String get forumPollEndsAt => 'ينتهي';

  @override
  String get forumPollEndsNone => 'بدون نهاية';

  @override
  String forumPollEndsDays(int n) {
    return '$n أيام';
  }

  @override
  String get forumPollEndsPickDate => 'اختر تاريخًا';

  @override
  String forumPollEndsOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String get forumPollAllowChange => 'يمكن تغيير الصوت';

  @override
  String get forumPollRemove => 'إزالة الاستطلاع';

  @override
  String forumPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صوت',
      many: '$count صوتًا',
      few: '$count أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات',
    );
    return '$_temp0';
  }

  @override
  String forumPollPercent(String p) {
    return '$p%';
  }

  @override
  String get forumPollMine => 'صوتك';

  @override
  String get forumPollEnded => 'انتهى الاستطلاع';

  @override
  String forumPollLeftDays(int n) {
    return 'متبقي $n يوم';
  }

  @override
  String forumPollLeftHours(int n) {
    return 'متبقي $n ساعة';
  }

  @override
  String forumPollLeftMinutes(int n) {
    return 'متبقي $n دقيقة';
  }

  @override
  String get forumPollCanChange => 'يمكنك تغيير صوتك';

  @override
  String get forumPollLocked => 'لا يمكن تغيير الصوت بعد التصويت';

  @override
  String get forumPollUndo => 'سحب صوتي';

  @override
  String forumPollSemantics(String text, String percent, String votes) {
    return '$text، $percent، $votes';
  }

  @override
  String get forumPollSelected => 'محدد';

  @override
  String get forumPollErrClosed => 'انتهى الاستطلاع.';

  @override
  String get forumPollErrAlready => 'تم تسجيل صوتك مسبقًا ولا يمكن تغييره.';

  @override
  String get forumPollErrNetwork =>
      'لا يوجد اتصال بالإنترنت. لم يتم إرسال صوتك.';

  @override
  String get forumPollErrRate => 'عدد كبير من عمليات التصويت. انتظر قليلًا.';

  @override
  String get forumPollErrGone => 'هذا الموضوع أو الاستطلاع لم يعد موجودًا.';

  @override
  String get forumPollErrForbidden => 'لا يمكنك التصويت في هذا الاستطلاع.';

  @override
  String get forumPollErrGeneric => 'تعذر حفظ الصوت. حاول مجددًا.';

  @override
  String get forumPollTitle => 'استطلاع';

  @override
  String get forumComposeDiscardTitle => 'هل تريد تجاهل التغييرات؟';

  @override
  String get forumComposeDiscardConfirm => 'تجاهل';

  @override
  String get forumComposeDiscardKeep => 'متابعة التعديل';

  @override
  String get forumComposeCategorySheetEmpty => 'لا توجد فئات متاحة.';

  @override
  String get forumComposeEditErrGeneric => 'تعذر حفظ التغييرات. حاول مجددًا.';

  @override
  String get forumHomeA11y => 'منتدى الحرم الجامعي';

  @override
  String get forumHomeHint => 'المكان الذي يتحدث فيه الجميع في الحرم الجامعي';

  @override
  String get forumHomeSearch => 'ابحث في المنتدى';

  @override
  String get forumHomeNotifications => 'الإشعارات';

  @override
  String get forumHomeNewTopic => 'موضوع جديد';

  @override
  String get forumHomeSortTitle => 'ترتيب حسب';

  @override
  String get forumHomeSortForYou => 'لك';

  @override
  String get forumHomeSortNewest => 'الأحدث';

  @override
  String get forumHomeSortPopular => 'الأكثر شعبية';

  @override
  String get forumHomeSortMostCommented => 'الأكثر تعليقًا';

  @override
  String get forumHomeSortFollowing => 'ما أتابعه';

  @override
  String get forumHomeCategoryAll => 'الكل';

  @override
  String get forumHomeCategories => 'الفئات';

  @override
  String get forumHomePinned => 'مثبّت';

  @override
  String get forumHomeLocked => 'مقفل';

  @override
  String get forumHomePoll => 'استطلاع';

  @override
  String get forumHomeEdited => 'معدّل';

  @override
  String forumHomeCommentsA11y(String n) {
    return '$n تعليق';
  }

  @override
  String forumHomeLikesA11y(String n) {
    return '$n إعجاب';
  }

  @override
  String get forumHomeOpenComments => 'افتح التعليقات';

  @override
  String get forumHomeLike => 'أعجبني';

  @override
  String get forumHomeUnlike => 'إلغاء الإعجاب';

  @override
  String get forumHomeSave => 'حفظ';

  @override
  String get forumHomeUnsave => 'إزالة من المحفوظات';

  @override
  String get forumHomeShare => 'مشاركة';

  @override
  String get forumHomeMore => 'المزيد';

  @override
  String get forumHomeMenuCopyLink => 'نسخ الرابط';

  @override
  String get forumHomeMenuReport => 'إبلاغ';

  @override
  String get forumHomeMenuMute => 'كتم المستخدم';

  @override
  String get forumHomeMenuBlock => 'حظر الكاتب';

  @override
  String get forumHomeBlockTitle => 'هل تريد حظر هذا الكاتب؟';

  @override
  String get forumHomeBlockBody =>
      'لن تظهر لك مواضيع هذا الكاتب وتعليقاته بعد الآن. إذا كان مجهولًا فلن تُكشف هويته.';

  @override
  String get forumHomeBlockConfirm => 'حظر';

  @override
  String get forumHomeMuteTitle => 'هل تريد كتم هذا المستخدم؟';

  @override
  String get forumHomeMuteBody =>
      'لن يظهر لك محتوى هذا المستخدم. يمكنك التراجع في أي وقت.';

  @override
  String get forumHomeMuteConfirm => 'كتم';

  @override
  String get forumHomeBlocked => 'تم حظر الكاتب';

  @override
  String get forumHomeMuted => 'تم كتم المستخدم';

  @override
  String get forumHomeLinkCopied => 'تم نسخ الرابط';

  @override
  String get forumHomeLikeFailed => 'تعذّر حفظ الإعجاب';

  @override
  String get forumHomeSaveFailed => 'تعذّر إتمام الحفظ';

  @override
  String get forumHomeEmptyTitle => 'لا توجد مواضيع بعد';

  @override
  String get forumHomeEmptyBody => 'ابدأ أول موضوع ودع الحرم الجامعي يتحدث.';

  @override
  String get forumHomeEmptyAction => 'ابدأ موضوعًا';

  @override
  String get forumHomeEmptyCategoryTitle => 'لا توجد مواضيع في هذه الفئة';

  @override
  String get forumHomeEmptyCategoryBody => 'جرّب فئة أخرى أو ابدأ أول موضوع.';

  @override
  String get forumHomeEmptyFollowingTitle => 'أنت لا تتابع أي موضوع';

  @override
  String get forumHomeEmptyFollowingBody =>
      'تابع موضوعًا وستظهر تعليقاته الجديدة هنا.';

  @override
  String get forumHomeLoadMoreFailed => 'تعذّر تحميل المزيد';

  @override
  String get forumHomeStripSub =>
      'المكان الذي يتحدث فيه الجميع في الحرم الجامعي';

  @override
  String get forumHomeTalkedTitle => 'الأكثر نقاشًا في الحرم';

  @override
  String get forumHomeTalkedAll => 'عرض الكل';

  @override
  String get forumStateOffline =>
      'لا يوجد اتصال بالإنترنت. حاول مرة أخرى عند عودة الاتصال.';

  @override
  String get forumStateServerError =>
      'الخادم غير متاح حاليًا. حاول مرة أخرى بعد قليل.';

  @override
  String get forumStateSessionExpired =>
      'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get forumStateNotFound =>
      'لم يتم العثور على هذا المحتوى أو تمت إزالته.';

  @override
  String get forumStateTopicRemoved => 'تمت إزالة هذا الموضوع.';

  @override
  String get forumStateCommentRemoved => 'تمت إزالة هذا التعليق.';

  @override
  String get forumStateCommentDeleted => 'تم حذف هذا التعليق.';

  @override
  String get forumStateLocked => 'تم إغلاق التعليقات على هذا الموضوع.';

  @override
  String get forumStateNotOwner => 'ليست لديك صلاحية لهذا الإجراء.';

  @override
  String get forumStateRateLimited =>
      'أنت سريع جدًا. انتظر قليلًا وحاول مرة أخرى.';

  @override
  String get forumStateDuplicate => 'لقد نشرت المحتوى نفسه قبل قليل.';

  @override
  String get forumStateProfanity =>
      'يحتوي النص على ألفاظ غير لائقة. عدّله وحاول مرة أخرى.';

  @override
  String get forumStatePollClosed => 'انتهى هذا الاستطلاع.';

  @override
  String get forumStateAlreadyVoted => 'لقد صوّتّ في هذا الاستطلاع بالفعل.';

  @override
  String get forumStateEmptyContent => 'لا يمكن نشر محتوى فارغ.';

  @override
  String get forumStateNoAccess => 'لا يمكنك الوصول إلى هذا المحتوى.';

  @override
  String get forumStateGeneric => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get forumHomeMenuSaved => 'المواضيع المحفوظة';

  @override
  String get forumHomeMenuActivity => 'نشاطي في المنتدى';

  @override
  String get forumHomeMenuPrefs => 'إعدادات إشعارات المنتدى';

  @override
  String get notif2SocialSection => 'التفاعل الاجتماعي';

  @override
  String get notif2LikeSub => 'عندما يعجب أحد بمنشورك';

  @override
  String get notif2CommentSub => 'عندما يعلّق أحد على منشورك';

  @override
  String get notif2ReplySub => 'عندما يرد أحد على تعليقك';

  @override
  String get notif2MentionSub => 'عندما تتم الإشارة إليك في منشور';

  @override
  String get notif2FollowSub => 'عندما يبدأ أحد بمتابعتك';

  @override
  String get notif2FollowRequestTitle => 'طلبات المتابعة';

  @override
  String get notif2FollowRequestSub => 'عندما يطلب أحد متابعتك';

  @override
  String get notif2FollowAcceptedTitle => 'الطلبات المقبولة';

  @override
  String get notif2FollowAcceptedSub => 'عندما يتم قبول طلب المتابعة الخاص بك';

  @override
  String get notif2AcademicTitle => 'الإعلانات الأكاديمية';

  @override
  String get notif2AcademicSub => 'تذكيرات الامتحانات والإعلانات الأكاديمية';

  @override
  String get notif2AcademicNeedsAnnouncements =>
      'لا تصل الإشعارات الأكاديمية عند إيقاف الإعلانات';

  @override
  String get notif2PreviewSection => 'المعاينة';

  @override
  String get notif2HidePreviewTitle => 'إخفاء محتوى الرسالة';

  @override
  String get notif2HidePreviewSub =>
      'عند التفعيل يظهر إشعار رسالة جديدة بدلا من النص ولا يظهر المحتوى على شاشة القفل.';

  @override
  String get notif2SystemSection => 'النظام والأمان';

  @override
  String get notif2SystemSettingsTitle => 'إعدادات إشعارات النظام';

  @override
  String get notif2SystemSettingsSub =>
      'يتم إدارة الصوت والاهتزاز وفئات الإشعارات من إعدادات الجهاز.';

  @override
  String get notif2SecurityNote =>
      'تصل إشعارات أمان الحساب والجلسات والإشراف دائما بغض النظر عن هذه الإعدادات.';

  @override
  String get devTitle => 'أجهزتي';

  @override
  String get devIntro =>
      'الأجهزة التي سُجّل الدخول منها إلى حسابك. إذا رأيت جهازا لا تعرفه فاخرج منه وغيّر كلمة المرور.';

  @override
  String get devSection => 'الجلسات المفتوحة';

  @override
  String get devThisDevice => 'هذا الجهاز';

  @override
  String devLastUsed(String when) {
    return 'آخر استخدام: $when';
  }

  @override
  String get devNameAndroid => 'جهاز أندرويد';

  @override
  String get devNameIos => 'آيفون';

  @override
  String get devNameWeb => 'متصفح الويب';

  @override
  String get devNameUnknown => 'جهاز غير معروف';

  @override
  String get devSignOut => 'تسجيل الخروج';

  @override
  String get devSignOutTitle => 'تسجيل الخروج من هذا الجهاز؟';

  @override
  String devSignOutBody(String device) {
    return 'سيتم إغلاق الجلسة على $device. ستحتاج إلى تسجيل الدخول مجددا لاستخدامه.';
  }

  @override
  String get devSignOutThisBody =>
      'سيتم إغلاق الجلسة على هذا الجهاز وستعود إلى شاشة تسجيل الدخول.';

  @override
  String devSignedOut(String device) {
    return 'تم تسجيل الخروج من $device.';
  }

  @override
  String get devGone => 'هذه الجلسة مغلقة بالفعل.';

  @override
  String get devEmpty => 'لا توجد جلسات مفتوحة لعرضها.';

  @override
  String get devAllSection => 'كل الأجهزة';

  @override
  String get devAllHint =>
      'سيتم إغلاق الجلسات على كل الأجهزة بما فيها هذا الجهاز.';

  @override
  String get devPlatformAndroid => 'Android';

  @override
  String get devPlatformIos => 'iOS';

  @override
  String get devPlatformWeb => 'Web';

  @override
  String get pwRowLabel => 'كلمة المرور';

  @override
  String get pwRowSub => 'حدّث كلمة المرور';

  @override
  String get pwpIntro => 'أدخل كلمة المرور الحالية لتعيين كلمة مرور جديدة.';

  @override
  String get pwpForgotTitle => 'نسيت كلمة المرور؟';

  @override
  String get pwpForgotBody =>
      'سنرسل رمز تحقق من 6 أرقام إلى البريد الإلكتروني المسجّل في حسابك لتتمكن من تعيين كلمة مرور جديدة.';

  @override
  String pwpForgotTo(String email) {
    return 'يُرسل الرمز إلى $email.';
  }

  @override
  String get pwpForgotButton => 'أرسل رمز التحقق';

  @override
  String get pwpExpired => 'انتهت مهلة التحقق. اطلب رمزًا جديدًا.';

  @override
  String get pwpDoneTitle => 'تم تحديث كلمة المرور';

  @override
  String get pwpDoneBody =>
      'حفاظًا على أمانك، أُغلقت جميع الجلسات على كل الأجهزة بما فيها هذا الجهاز. سجّل الدخول من جديد بكلمة مرورك الجديدة.';

  @override
  String get cplLockTitle => 'انضم إلى النادي لعرض استطلاعاته';

  @override
  String get cplLockBody => 'استطلاعات النادي متاحة للأعضاء فقط.';

  @override
  String get cplLockBodyApproval =>
      'استطلاعات النادي متاحة للأعضاء فقط. ستظهر هنا بعد الموافقة على طلب انضمامك.';

  @override
  String get cplPendingTitle => 'طلب عضويتك بانتظار الموافقة';

  @override
  String get cplPendingBody => 'عند الموافقة ستظهر استطلاعات النادي هنا.';

  @override
  String get cplEmptyManagerBody => 'أنشئ أول استطلاع لمعرفة آراء الأعضاء.';

  @override
  String get chcEmptyTitle => 'لا توجد أندية بعد';

  @override
  String get chcEmptyBody => 'أسّس أول نادٍ وادعُ أصدقاءك.';

  @override
  String get chcLoadFailed => 'تعذّر تحميل الأندية.';

  @override
  String clsSortLabel(String name) {
    return 'الترتيب: $name';
  }

  @override
  String get clsSortTitle => 'ترتيب حسب';

  @override
  String get clsSortPopular => 'الأكثر شعبية';

  @override
  String get clsSortNewest => 'الأحدث';

  @override
  String get clsSortAz => 'أ-ي';

  @override
  String clsCount(String count) {
    return '$count نادي';
  }

  @override
  String get forumCatAll => 'كل الفئات';

  @override
  String get forumCatPickerA11y => 'اختيار الفئة';

  @override
  String get forumCatSearchHint => 'ابحث في الفئات';

  @override
  String get forumCatEmptyTitle => 'لم يتم العثور على فئات';

  @override
  String forumCatEmptyBody(String q) {
    return 'لا توجد فئة مطابقة لـ “$q”. جرّب كلمة أخرى.';
  }

  @override
  String forumCatTopicCount(int count) {
    return '$count موضوع';
  }

  @override
  String get forumCatLoadFailed => 'تعذر تحميل الفئات';

  @override
  String get cplSendRequest => 'إرسال طلب';

  @override
  String get evtQrScanTitle => 'مسح الرمز';

  @override
  String get evtQrScanHint => 'وجّه الكاميرا نحو رمز QR الخاص بالمشارك.';

  @override
  String evtQrScanMarked(String name) {
    return 'تم تسجيل حضور $name';
  }

  @override
  String evtQrScanAlready(String name) {
    return '$name سُجّل حضوره مسبقًا';
  }

  @override
  String get evtQrMyTitle => 'رمزي';

  @override
  String get evtQrMyHint =>
      'اعرض هذا الرمز على منظم الفعالية عند الدخول. يتجدد خلال وقت قصير.';

  @override
  String get evtQrMyNotApproved => 'يظهر رمزك هنا بعد الموافقة على مشاركتك.';

  @override
  String get evtQrMyBeforeStart =>
      'يُفتح تسجيل الحضور في موعد الفعالية؛ يمكنك تجهيز رمزك الآن.';

  @override
  String get evtQrScanClosed => 'لم يُفتح تسجيل الحضور بعد أو أُغلق.';

  @override
  String get evtAttOpenTitle => 'تسجيل الحضور مفتوح';

  @override
  String get evtAttOpenSub =>
      'أثناء الفتح يعرض المشاركون رموزهم ويقوم المنظم والمشرفون بمسحها.';

  @override
  String get evtAttOpenYou => 'تسجيل الحضور مفتوح: اعرض رمزك عند الدخول.';

  @override
  String get evtModTitle => 'المشرفون';

  @override
  String get evtModSub => 'اختر من أعضاء النادي وفعّل كل صلاحية أو عطّلها.';

  @override
  String get evtModAdd => 'إضافة مشرف';

  @override
  String get evtModEmpty => 'لا يوجد مشرفون بعد.';

  @override
  String get evtModRemove => 'إزالة المشرف';

  @override
  String get evtModSearch => 'ابحث عن عضو';

  @override
  String get evtModOwnerNote =>
      'الإغلاق والإلغاء وفتح تسجيل الحضور وإدارة المشرفين من صلاحيات المالك فقط.';

  @override
  String get evtModRole => 'مشرف';

  @override
  String get evtModNoMembers => 'لا يوجد أعضاء متاحون للإضافة.';

  @override
  String get evtPermTakeAttendance => 'تسجيل الحضور';

  @override
  String get evtPermTakeAttendanceSub => 'مسح الرموز وتسجيل الحضور يدويًا.';

  @override
  String get evtPermManageRequests => 'إدارة طلبات الانضمام';

  @override
  String get evtPermManageRequestsSub => 'قبول الطلبات أو رفضها.';

  @override
  String get evtPermViewAttendees => 'عرض قائمة المشاركين';

  @override
  String get evtPermViewAttendeesSub => 'عرض المشاركين وحالة حضورهم.';

  @override
  String get evtPermSendAnnouncement => 'إرسال الإعلانات';

  @override
  String get evtPermSendAnnouncementSub => 'إرسال إعلانات الفعالية للمشاركين.';

  @override
  String get evtPermEditInfo => 'تعديل التفاصيل';

  @override
  String get evtPermEditInfoSub => 'تغيير العنوان والوصف والمكان.';

  @override
  String get evtPermEditSchedule => 'تعديل التاريخ والوقت';

  @override
  String get evtPermEditScheduleSub => 'تغيير وقت البدء والانتهاء.';

  @override
  String get evtModManageTitle => 'صلاحياتك كمشرف';

  @override
  String get evtModManageNone => 'ليست لديك صلاحية في هذه الفعالية.';

  @override
  String get evtAttClosedNote => 'تسجيل الحضور مغلق حاليًا.';

  @override
  String get evtQrOwnerClosed => 'الحضور مغلق: لا يستطيع المشاركون عرض رمز QR.';

  @override
  String get evtQrOwnerOpenAction => 'فتح الحضور';

  @override
  String get evtQrOwnerOutside =>
      'نحن خارج أوقات الفعالية؛ يُفتح الحضور تلقائيًا قبل البداية بـ 30 دقيقة. يمكنك فتحه الآن.';

  @override
  String get evtQrMyOwnerTitle => 'أنت منظم هذه الفعالية';

  @override
  String get evtQrMyOwnerBody => 'تسجّل الحضور بمسح رموز QR الخاصة بالمشاركين.';

  @override
  String get evtQrMyOwnerScan => 'مسح QR';

  @override
  String get evtQrMyOwnerJoin => 'انضم كمشارك أيضًا';

  @override
  String get evtAtt2ToolTitle => 'أداة الحضور';

  @override
  String get evtAtt2ToolSub => 'امسح رموز QR وسجّل من القائمة';

  @override
  String get evtAtt2ScanQr => 'مسح QR';

  @override
  String get evtAtt2Search => 'ابحث عن مشارك';

  @override
  String get evtAtt2Pending => 'قيد الانتظار';

  @override
  String evtAtt2Counter(String present, String absent, String pending) {
    return '$present حضروا · $absent غابوا · $pending قيد الانتظار';
  }

  @override
  String get evtAtt2MarkPresent => 'حضر';

  @override
  String get evtAtt2MarkAbsent => 'غائب';

  @override
  String get evtAtt2MarkReset => 'إعادة التعيين (قيد الانتظار)';

  @override
  String evtAtt2SheetTitle(String name) {
    return 'الحضور لـ $name';
  }

  @override
  String get evtAtt2BulkRest => 'تسجيل الباقين كغائبين';

  @override
  String get evtAtt2BulkTitle => 'تسجيل الباقين كغائبين؟';

  @override
  String evtAtt2BulkBody(String count) {
    return 'سيتم تسجيل $count شخصًا كـ \"غائب\". يمكنك تغيير كل واحد لاحقًا.';
  }

  @override
  String evtAtt2BulkDone(String count) {
    return 'تم تسجيل $count شخصًا كغائبين';
  }

  @override
  String get evtAtt2SrcQr => 'QR';

  @override
  String get evtAtt2SrcManual => 'يدويًا';

  @override
  String evtAtt2ByScanner(String name) {
    return 'مسحه $name';
  }

  @override
  String evtAtt2ByMarker(String name) {
    return 'سجّله $name';
  }

  @override
  String get evtAtt2ViewOnly =>
      'يمكنك عرض القائمة فقط؛ ليس لديك صلاحية التسجيل.';

  @override
  String get evtAtt2NoMatch => 'لا يوجد مشارك يطابق بحثك.';

  @override
  String get evtAtt2ListEmpty => 'لا يوجد مشاركون معتمدون بعد.';

  @override
  String evtAtt2ToastAbsent(String name) {
    return 'تم تسجيل $name كغائب';
  }

  @override
  String evtAtt2ToastPresent(String name) {
    return 'تم تسجيل $name كحاضر';
  }

  @override
  String evtAtt2ToastReset(String name) {
    return 'تمت إعادة تعيين $name';
  }

  @override
  String get evtAtt2StaffNoQr =>
      'من يأخذون الحضور ليس لديهم رمز QR شخصي؛ تقوم بمسح رموز المشاركين.';

  @override
  String get evtAtt2ParticipantHint =>
      'اعرض هذا الرمز على المسؤول عن الحضور. لا حاجة لأي شيء آخر.';

  @override
  String get evtAtt2StatusArrived => 'تم تسجيل حضورك';

  @override
  String get evtMeetLabel => 'نقطة التجمع';

  @override
  String get evtMeetHint => 'مثال: أمام كلية الهندسة، المدخل الرئيسي';

  @override
  String get evtMeetHelp =>
      'المكان الذي يتجمع فيه المشاركون (منفصل عن مكان الفعالية).';

  @override
  String get evtMeetOpenMap => 'افتح في الخريطة';

  @override
  String get evtMeetMapFail => 'تعذّر فتح الخريطة.';

  @override
  String get evtMeetLat => 'خط العرض (اختياري)';

  @override
  String get evtMeetLng => 'خط الطول (اختياري)';

  @override
  String get evtMeetCoordInvalid =>
      'يجب أن يكون خط العرض بين -90 و90 وخط الطول بين -180 و180 ويُدخلان معًا.';

  @override
  String get evtEditEndedNote => 'انتهت الفعالية: يمكن تعديل الوصف فقط.';

  @override
  String get unitNewsTitle => 'قسمي';

  @override
  String get unitNewsSemantic => 'إعلانات قسمي';

  @override
  String get unitNewsAttachments => 'المرفقات';

  @override
  String get unitNewsError => 'تعذّر تحميل الإعلان.';

  @override
  String get qa1DelReauthBody =>
      'تم إنشاء حسابك عبر Google أو Apple لذلك لا توجد له كلمة مرور. أكّد هويتك بالحساب المرتبط لحذفه. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get qa1DelReauthAction => 'تأكيد الهوية وحذف الحساب';

  @override
  String get qa1NoPasswordNote =>
      'تم إنشاء حسابك عبر Google أو Apple لذلك لا توجد لك كلمة مرور. يمكنك تعيين واحدة برمز يصل إلى بريدك الإلكتروني، ثم الدخول أيضًا بالبريد وكلمة المرور.';

  @override
  String get qa1PwSetButton => 'تعيين كلمة مرور';

  @override
  String get qa1TfNeedPassword =>
      'إيقاف التحقق بخطوتين يتطلب كلمة مرور وحسابك بلا كلمة مرور: عيّن واحدة أولًا من شاشة كلمة المرور برمز يصل إلى بريدك الإلكتروني.';

  @override
  String get qa1TfDisableReauthBody =>
      'حسابك بلا كلمة مرور، لذا أكّد هويتك عبر Google أو Apple. تُحذف جميع الأجهزة الموثوقة.';

  @override
  String get widgetsRowTitle => 'ودجات الشاشة الرئيسية';

  @override
  String get widgetsInfoTitle => 'ودجات الشاشة الرئيسية';

  @override
  String get widgetsIntro =>
      'شاهد الوجبات والمحاضرات والفعاليات والإعلانات والاستطلاع والملخص الاجتماعي من الشاشة الرئيسية دون فتح التطبيق.';

  @override
  String get widgetsListTitle => 'الودجات المتاحة';

  @override
  String get widgetsList =>
      'قائمة الطعام، الجدول الدراسي، الفعاليات القادمة، إعلانات الحرم الجامعي، استطلاع اليوم، الوصول السريع والملخص الاجتماعي.';

  @override
  String get widgetsIosTitle => 'iPhone';

  @override
  String get widgetsIosSteps =>
      'اضغط مطولاً على مساحة فارغة في الشاشة الرئيسية، ثم اضغط زر + في الأعلى، واختر BÜ Kampüs وأضف الودجت الذي تريده.';

  @override
  String get widgetsAndroidTitle => 'Android';

  @override
  String get widgetsAndroidSteps =>
      'اضغط مطولاً على مساحة فارغة في الشاشة الرئيسية، ثم اضغط على الودجات، وابحث عن BÜ Kampüs واسحب الودجت الذي تريده إلى الشاشة الرئيسية.';

  @override
  String get widgetsRefreshTitle => 'التحديث';

  @override
  String get widgetsRefresh =>
      'تتحدث المعلومات عند فتح التطبيق وعند حدوث تغيير وبشكل دوري. الضغط على الودجت يفتح الشاشة المناسبة.';

  @override
  String get widgetsPrivacyTitle => 'الخصوصية';

  @override
  String get widgetsPrivacy =>
      'لا تعرض الودجات أسماء المستخدمين الآخرين أو رسائلهم أو صورهم؛ يعرض الملخص الاجتماعي الأعداد فقط. عند تسجيل الخروج تُحذف بيانات الودجات وتعود إلى حالة تسجيل الدخول.';

  @override
  String get chatLongShowMore => 'عرض المزيد';

  @override
  String get chatLongShowLess => 'عرض أقل';

  @override
  String get evtLiveCheckedInTitle => 'تم المسح';

  @override
  String get evtLiveCheckedInBody => 'تم تسجيل حضورك.';

  @override
  String evtLiveCheckedInAt(String time) {
    return 'الساعة $time';
  }

  @override
  String evtLiveLastScanned(String name) {
    return 'آخر من تم مسحه: $name';
  }

  @override
  String evtLiveScanCount(String name) {
    return 'تم مسح $name';
  }

  @override
  String get settingsFindContacts => 'ابحث عن أشخاص من جهات الاتصال';

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
      'لم نجد أيًّا من جهات اتصالك يستخدم التطبيق. سيظهر أصدقاؤك هنا عند انضمامهم.';

  @override
  String get chatMiscContactsSearchHint => 'ابحث في الأشخاص';

  @override
  String get chatMiscContactsTruncated =>
      'تم بلوغ حد الطلبات في الساعة؛ ستتم مطابقة بقية الأشخاص لاحقًا.';

  @override
  String get qa4ContactsConsentTitle => 'يمكن العثور عليّ عبر جهات الاتصال';

  @override
  String get qa4ContactsConsentText =>
      'فعّل هذا الخيار أولاً للعثور على الأشخاص من جهات اتصالك. المطابقة متبادلة: لا تجد إلا من فعّلوا الخيار أيضًا، ولا يجدك غيرك إلا عند تفعيله. يمكنك إيقافه في أي وقت.';

  @override
  String get qa4ContactsConsentAction => 'تفعيل ومتابعة';

  @override
  String get qa4ContactsConsentOff =>
      'إيقاف إمكانية العثور عليّ عبر جهات الاتصال';

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
  String get permContactsTitle => 'جهات الاتصال';

  @override
  String get permContactsText =>
      'مطلوب للعثور على أشخاص الجامعة في جهات اتصالك وبدء المحادثات. لا يتم إرسال جهات اتصالك إلى الخادم.';

  @override
  String get sistemuiPermContactsText =>
      'للعثور على جهات اتصال الجامعة في دفتر العناوين وبدء المحادثات. لا يتم إرسال جهات اتصالك إلى الخادم.';

  @override
  String get p23PrivacyShort => 'لا تُرسل جهات اتصالك إلى الخادم.';

  @override
  String get p23NoneText => 'لم يُعثر على أحد من جهات اتصالك يستخدم التطبيق.';

  @override
  String get liveTrackStart => 'تتبع مباشر';

  @override
  String get liveTrackStop => 'إيقاف التتبع المباشر';

  @override
  String get liveTrackStarted => 'بدأ التتبع المباشر';

  @override
  String get liveTrackFailed => 'تعذر بدء التتبع المباشر';

  @override
  String get liveTrackDisabled =>
      'الأنشطة المباشرة متوقفة. يمكنك تفعيلها من الإعدادات.';

  @override
  String get liveLabelStartsIn => 'يبدأ خلال';

  @override
  String get liveLabelEndsIn => 'ينتهي خلال';

  @override
  String get liveChannelName => 'التحديثات المباشرة';

  @override
  String get hubSumClubs => 'الأندية';

  @override
  String get hubSumEvents => 'فعاليات قادمة';

  @override
  String get hubSumPending => 'طلبات معلّقة';

  @override
  String get hubSumManaged => 'أديرها';

  @override
  String get hubPanel => 'لوحة الإدارة';

  @override
  String get hubViewEvents => 'عرض الفعاليات';

  @override
  String get hubUpcomingHead => 'فعالياتي القادمة';

  @override
  String get hubManageTitle => 'إدارة النادي';

  @override
  String get hubStatMembers => 'إجمالي الأعضاء';

  @override
  String get hubActEvents => 'إدارة الفعاليات';

  @override
  String get hubActEventsSub => 'تعديل وإدارة الحضور والتسجيل';

  @override
  String get hubActAnnounce => 'إنشاء إعلان';

  @override
  String get hubActPosts => 'إدارة منشورات النادي';

  @override
  String get hubActRoles => 'إدارة صلاحيات المشرفين';

  @override
  String get hubSwitchClub => 'تبديل النادي';

  @override
  String get hubNoAccess => 'ليست لديك صلاحية إدارة في هذا النادي.';

  @override
  String get hubSubPlanned => 'سأحضرها';

  @override
  String get hubSubRequests => 'طلباتي';

  @override
  String get hubNoRequests => 'لا توجد طلبات معلّقة.';

  @override
  String get hubNoPast => 'لا توجد فعاليات سابقة.';

  @override
  String get profileClubHub => 'أنديتي وفعالياتي';

  @override
  String get hubOpenManage => 'إدارة ناديي';

  @override
  String get shareUnavailablePost =>
      'هذا المنشور غير متاح. قد يعود إلى حساب خاص.';

  @override
  String postPhotoOfTotal(String n, String total) {
    return 'صورة $n/$total';
  }

  @override
  String get postMultiBadgeLabel => 'منشور متعدد الصور';

  @override
  String composePhotoCount(String n, String max) {
    return '$n/$max صور';
  }

  @override
  String get composeAddPhotos => 'إضافة صور';

  @override
  String get composeAddPhotosShort => 'إضافة';

  @override
  String get composeRemovePhoto => 'إزالة الصورة';

  @override
  String get composeReorderHint => 'اضغط مطولًا واسحب لإعادة الترتيب';

  @override
  String composeUploadingN(String n, String total) {
    return 'جارٍ الرفع $n/$total';
  }

  @override
  String get postComposeErrMediaLimit =>
      'يمكن إضافة 10 صور كحد أقصى إلى المنشور.';

  @override
  String get postComposeErrMediaMix =>
      'يجب أن يكون منشور الفيديو بمفرده؛ لا يمكن خلطه بالصور.';

  @override
  String get evCalRow => 'أضف إلى التقويم وذكّرني';

  @override
  String get evCalRowDone => 'في التقويم · التذكير مفعّل';

  @override
  String get evCalSheetTitle => 'أضف إلى التقويم';

  @override
  String get evCalBody =>
      'تُضاف الفعالية إلى تقويم جهازك ويرسل تطبيق التقويم التذكير. تُضاف أو تُحذف فعاليات BÜ Kampüs فقط.';

  @override
  String get evCalPromptBody =>
      'تم تسجيل مشاركتك. هل نضيف الفعالية إلى تقويمك ونذكّرك؟ المقترح: قبل ساعة.';

  @override
  String get evCalRemind => 'التذكير';

  @override
  String get evCalLead15 => 'قبل 15 دقيقة';

  @override
  String get evCalLead60 => 'قبل ساعة';

  @override
  String get evCalLead1440 => 'قبل يوم';

  @override
  String get evCalAdd => 'أضف إلى التقويم';

  @override
  String get evCalUpdate => 'تحديث';

  @override
  String get evCalRemove => 'إزالة من التقويم';

  @override
  String get evCalLater => 'ليس الآن';

  @override
  String get evCalNever => 'لا تسأل مرة أخرى';

  @override
  String get evCalAdded => 'أُضيفت الفعالية إلى التقويم';

  @override
  String get evCalUpdated => 'تم تحديث إدخال التقويم';

  @override
  String get evCalRemoved => 'تمت الإزالة من التقويم';

  @override
  String get evCalFailed => 'تعذّرت الكتابة في التقويم.';

  @override
  String get evCalPast => 'لا يمكن إضافة فعالية بدأت.';

  @override
  String clubShareMsg(String name, String link) {
    return 'تعرّف على نادي $name في BÜ Kampüs: $link';
  }

  @override
  String offlineStripWithTime(String zaman) {
    return 'غير متصل · آخر تحديث $zaman';
  }

  @override
  String get offlineStripNoTime => 'غير متصل · عرض البيانات المحفوظة';

  @override
  String get menuRemTitle => 'تذكير القائمة اليومية';

  @override
  String get menuRemSub => 'يذكّرك بقائمة اليوم في الوقت الذي تختاره كل يوم';

  @override
  String get menuRemTime => 'وقت التذكير';

  @override
  String get menuRemNotifTitle => 'قائمة اليوم';

  @override
  String get menuRemNotifBody => 'ألقِ نظرة على قائمة المطعم.';

  @override
  String get menuRemPermNeeded => 'يلزم إذن الإشعارات للتذكير.';

  @override
  String get searchForum => 'المنتدى';

  @override
  String get icerikGroupForum => 'المنتدى';

  @override
  String get searchSuggestionsLabel => 'اقتراحات البحث';

  @override
  String searchForumLikes(String n) {
    return '$n إعجاب';
  }

  @override
  String get svTitle => 'المحفوظات';

  @override
  String get svFilterAll => 'الكل';

  @override
  String get svFilterNews => 'الأخبار';

  @override
  String get svFilterEvents => 'الفعاليات';

  @override
  String get svFilterClubs => 'النوادي';

  @override
  String get svFilterPolls => 'الاستطلاعات';

  @override
  String get svFilterPosts => 'المنشورات';

  @override
  String get svFilterForum => 'المنتدى';

  @override
  String get svEmptyTitle => 'لا شيء محفوظ بعد';

  @override
  String get svEmptyBody =>
      'استخدم أيقونة الإشارة المرجعية في الأخبار والفعاليات والنوادي والاستطلاعات والمنشورات ومواضيع المنتدى لحفظها.';

  @override
  String get svEmptyFilterTitle => 'لا يوجد محفوظ من هذا النوع';

  @override
  String get svEmptyFilterBody => 'اختر نوعا آخر أو احفظ عنصرا من هذا النوع.';

  @override
  String get svErrorTitle => 'تعذر تحميل المحفوظات';

  @override
  String get svRemoved => 'تمت الإزالة من المحفوظات';

  @override
  String get svRemoveAction => 'إزالة من المحفوظات';

  @override
  String get svOpenFailed => 'لم يعد بالإمكان فتح هذا المحتوى';

  @override
  String get svSave => 'حفظ';

  @override
  String get svUnsave => 'إزالة من المحفوظات';

  @override
  String get svSavedToast => 'تم الحفظ';

  @override
  String get svTypeNews => 'خبر';

  @override
  String get svTypeEvent => 'فعالية';

  @override
  String get svTypeCommunity => 'نادٍ';

  @override
  String get svTypePoll => 'استطلاع';

  @override
  String get svTypeAcademic => 'أكاديمي';

  @override
  String get svTypePost => 'منشور';

  @override
  String get svTypeTopic => 'موضوع منتدى';

  @override
  String get svTypeComment => 'تعليق منتدى';

  @override
  String get svMenuRow => 'المحفوظات';

  @override
  String get muteAction => 'كتم الإشعارات';

  @override
  String get muteActionOff => 'إلغاء كتم الإشعارات';

  @override
  String get muteOnToast => 'تم كتم الإشعارات';

  @override
  String get muteOffToast => 'تم تشغيل الإشعارات';

  @override
  String get muteCriticalNote =>
      'تصلك الإشعارات المهمة مثل الإلغاء والقبول وتغيير الدور والحضور حتى مع الكتم.';

  @override
  String get mutedRowTitle => 'المكتومة';

  @override
  String get mutedRowSub => 'النوادي والفعاليات التي كتمتها';

  @override
  String get mutedClubs => 'النوادي';

  @override
  String get mutedEvents => 'الفعاليات';

  @override
  String get mutedEmptyTitle => 'لم تكتم أي شيء';

  @override
  String get mutedEmptyBody =>
      'يمكنك كتم الإشعارات من القائمة في صفحة النادي أو الفعالية.';

  @override
  String get mutedErrorTitle => 'تعذر تحميل القائمة';

  @override
  String get mutedUnmute => 'إلغاء الكتم';

  @override
  String mutedClubFallback(String id) {
    return 'نادٍ $id';
  }

  @override
  String mutedEventFallback(String id) {
    return 'فعالية $id';
  }

  @override
  String get reportsMineTitle => 'بلاغاتي';

  @override
  String get reportsMineSub => 'حالة البلاغات التي أرسلتها';

  @override
  String get reportsMineNote => 'حفاظا على الخصوصية تظهر الحالة العامة فقط.';

  @override
  String get reportsStatusOpen => 'مفتوح';

  @override
  String get reportsStatusResolved => 'تمت المعالجة';

  @override
  String get reportsEmptyTitle => 'لم تبلغ عن أي شيء بعد';

  @override
  String get reportsEmptyBody => 'عند الإبلاغ عن محتوى ستظهر حالته العامة هنا.';

  @override
  String get reportsErrorTitle => 'تعذر تحميل البلاغات';

  @override
  String reportsResolvedOn(String date) {
    return 'تمت المعالجة: $date';
  }

  @override
  String get reportsTypeUser => 'مستخدم';

  @override
  String get reportsTypeMessage => 'رسالة';

  @override
  String get reportsTypePost => 'منشور';

  @override
  String get reportsTypeCommunity => 'نادٍ';

  @override
  String get reportsTypeEvent => 'فعالية';

  @override
  String get reportsTypeTopic => 'موضوع منتدى';

  @override
  String get reportsTypeComment => 'تعليق منتدى';

  @override
  String get reportsTypeOther => 'محتوى';

  @override
  String get reportsReasonPersonalInfo => 'نشر معلومات شخصية';

  @override
  String get chatSeenAgoNow => 'قبل لحظات';

  @override
  String chatSeenAgoMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n دقيقة',
      many: 'منذ $n دقيقة',
      few: 'منذ $n دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n ساعة',
      many: 'منذ $n ساعة',
      few: 'منذ $n ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n يومًا',
      many: 'منذ $n يومًا',
      few: 'منذ $n أيام',
      two: 'منذ يومين',
      one: 'منذ يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n أسبوعًا',
      many: 'منذ $n أسبوعًا',
      few: 'منذ $n أسابيع',
      two: 'منذ أسبوعين',
      one: 'منذ أسبوع واحد',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n شهرًا',
      many: 'منذ $n شهرًا',
      few: 'منذ $n أشهر',
      two: 'منذ شهرين',
      one: 'منذ شهر واحد',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'منذ $n سنة',
      many: 'منذ $n سنة',
      few: 'منذ $n سنوات',
      two: 'منذ سنتين',
      one: 'منذ سنة واحدة',
    );
    return '$_temp0';
  }

  @override
  String chatStatusSentAt(String when) {
    return 'تم الإرسال · $when';
  }

  @override
  String chatStatusSeenAt(String when) {
    return 'تمت المشاهدة · $when';
  }

  @override
  String get pcmWriteHint => 'أضف تعليقًا…';

  @override
  String get pcmEmptyTitle => 'كن أول من يعلّق';

  @override
  String get pcmEmptyBody => 'شارك رأيك وابدأ النقاش.';

  @override
  String pcmReplyingTo(String name) {
    return 'الرد على $name';
  }

  @override
  String get pcmHideReplies => 'إخفاء الردود';

  @override
  String get pcmSendFailed => 'تعذّر الإرسال';

  @override
  String get pcmRetry => 'أعد المحاولة';

  @override
  String get pcmSending => 'جارٍ الإرسال…';

  @override
  String get pcmDeleted => 'تم حذف هذا التعليق';

  @override
  String get pcmMenuDelete => 'حذف';

  @override
  String get pcmMenuReport => 'إبلاغ';

  @override
  String get pcmMenuCopy => 'نسخ النص';

  @override
  String get pcmCopied => 'تم النسخ';

  @override
  String get pcmMoreActions => 'خيارات التعليق';

  @override
  String get pcmLikeA11y => 'الإعجاب بالتعليق';

  @override
  String get pcmUnlikeA11y => 'إلغاء الإعجاب بالتعليق';

  @override
  String pcmLikeCountA11y(String count) {
    return '$count إعجاب';
  }

  @override
  String pcmCommentCountA11y(String count) {
    return '$count تعليق';
  }

  @override
  String pcmViewAll(String count) {
    return 'عرض كل التعليقات ($count)';
  }

  @override
  String get pcmViewAllPlain => 'عرض التعليقات';

  @override
  String get pcmErrTooLong => 'الحد الأقصى للتعليق 500 حرف.';

  @override
  String get pcmErrPostGone => 'هذا المنشور لم يعد متاحًا.';

  @override
  String get pcmErrParent => 'التعليق الذي رددت عليه لم يعد موجودًا.';

  @override
  String get pcmErrRate => 'تعلّق بسرعة كبيرة. حاول بعد قليل.';

  @override
  String get pcmMoreReplies => 'المزيد من الردود';

  @override
  String get pcmSortLabel => 'ترتيب';

  @override
  String pcmCharsLeft(String n) {
    return 'تبقّى $n حرفًا';
  }

  @override
  String get postSettingsAdvanced => 'إعدادات متقدمة';

  @override
  String get postSettingsHideLikes => 'إخفاء عدد الإعجابات';

  @override
  String get postSettingsHideLikesDesc =>
      'لن يرى الآخرون عدد الإعجابات على هذا المنشور، وستظل تراه أنت.';

  @override
  String get postSettingsCommentsOff => 'إيقاف التعليقات';

  @override
  String get postSettingsCommentsOffDesc =>
      'لا يمكن لأحد التعليق على هذا المنشور. تبقى التعليقات الحالية ظاهرة.';

  @override
  String get postHideLikesHint => 'عدد الإعجابات مخفي عن الآخرين';

  @override
  String get pcmCommentsDisabled => 'التعليقات متوقفة على هذا المنشور';

  @override
  String get postMenuHideLikes => 'إخفاء عدد الإعجابات';

  @override
  String get postMenuShowLikes => 'إظهار عدد الإعجابات';

  @override
  String get postMenuCommentsOff => 'إيقاف التعليقات';

  @override
  String get postMenuCommentsOn => 'تفعيل التعليقات';

  @override
  String get postSettingsLikesHiddenDone => 'تم إخفاء عدد الإعجابات';

  @override
  String get postSettingsLikesShownDone => 'تم إظهار عدد الإعجابات';

  @override
  String get postSettingsCommentsOffDone => 'تم إيقاف التعليقات';

  @override
  String get postSettingsCommentsOnDone => 'تم تفعيل التعليقات';

  @override
  String get postSettingsFailed => 'تعذّر تغيير الإعداد. حاول مرة أخرى.';

  @override
  String get pcmDeleteOthersTitle => 'حذف هذا التعليق؟';

  @override
  String get pcmDeleteOthersBody =>
      'سيُزال هذا التعليق للجميع. لا يمكن التراجع عن ذلك.';

  @override
  String get accTitle => 'الحسابات';

  @override
  String get accSwitch => 'تبديل الحساب';

  @override
  String get accAdd => 'إضافة حساب';

  @override
  String get accActive => 'الحساب الحالي';

  @override
  String get accExpired => 'انتهت الجلسة';

  @override
  String get accOptions => 'خيارات الحساب';

  @override
  String get accRemove => 'إزالة من هذا الجهاز';

  @override
  String get accRemoveTitle => 'هل تريد إزالة هذا الحساب؟';

  @override
  String accRemoveBody(String name) {
    return 'سيتم تسجيل خروج $name من هذا الجهاز. لن يتم حذف الحساب ويمكنك تسجيل الدخول مرة أخرى في أي وقت.';
  }

  @override
  String get accRemoveConfirm => 'إزالة';

  @override
  String get accLimit => 'يمكن إضافة 5 حسابات كحد أقصى على هذا الجهاز.';

  @override
  String get accPushNote => 'تصل الإشعارات إلى الحساب الحالي فقط.';

  @override
  String accSwitchedTo(String name) {
    return 'تم التبديل إلى $name';
  }

  @override
  String accExpiredSwitched(String name) {
    return 'انتهت جلسة $name. تم التبديل إلى حساب آخر.';
  }

  @override
  String get accExpiredSwitchedAnon => 'انتهت الجلسة. تم التبديل إلى حساب آخر.';

  @override
  String get accSignOutAll => 'تسجيل الخروج من جميع الحسابات';

  @override
  String accSignOutAllBody(String count) {
    return 'سيتم تسجيل الخروج من جميع الحسابات ($count) على هذا الجهاز.';
  }

  @override
  String get accAddSub =>
      'سجّل الدخول بحساب آخر أو أنشئ حسابًا جديدًا. يبقى حسابك الحالي مفتوحًا.';

  @override
  String accReloginHint(String mail) {
    return 'انتهت الجلسة. سجّل الدخول مجددًا: $mail';
  }

  @override
  String get accBusy => 'لا يمكن تبديل الحساب الآن. حاول مرة أخرى بعد قليل.';

  @override
  String get accAccountNoName => 'حساب';

  @override
  String get postPeekOpen => 'فتح المنشور';

  @override
  String get homeTodayPeekOpen => 'فتح';

  @override
  String get homeTodayPeekHint => 'فتح المعاينة';

  @override
  String get homeTodayPeekTime => 'الوقت';

  @override
  String get homeTodayPeekRoom => 'المكان';

  @override
  String get homeTodayPeekInstructor => 'المحاضر';

  @override
  String get deptChatTag => 'القسم';

  @override
  String deptChatJoinRow(String name) {
    return 'انضم إلى مجموعة القسم: $name';
  }

  @override
  String get clubAudienceLabel => 'اقتراح النادي لأقسام';

  @override
  String get clubAudienceHint => 'لم يتم الاختيار (اختياري)';

  @override
  String get clubAudienceSheetTitle => 'لمن يُقترح هذا النادي؟';

  @override
  String get clubAudienceSheetHint =>
      'يؤثر على الاقتراحات فقط، ويبقى النادي ظاهرا للجميع.';

  @override
  String get clubAudienceSearchHint => 'ابحث عن كلية أو قسم';

  @override
  String get clubAudienceNoMatch => 'لا توجد كلية أو قسم مطابق';

  @override
  String get clubAudienceRetry => 'أعد المحاولة';

  @override
  String get clubAudienceClear => 'مسح';

  @override
  String get clubAudienceExpand => 'عرض الأقسام';

  @override
  String get clubAudienceCollapse => 'إخفاء الأقسام';

  @override
  String clubAudienceDeptCount(int count) {
    return '$count أقسام';
  }

  @override
  String clubAudienceSelected(int count) {
    return 'تم اختيار $count هدف';
  }

  @override
  String clubAudienceDone(int count) {
    return 'تم ($count)';
  }

  @override
  String get clubRecommendedTitle => 'أندية مناسبة لقسمك';

  @override
  String get clubRecommendedAll => 'جميع الأندية';

  @override
  String get eventRecommendedTitle => 'فعاليات مناسبة لقسمك';

  @override
  String get deptChatFilterDepartments => 'الأقسام';

  @override
  String get deptChatBrowse => 'استكشف محادثات الأقسام';

  @override
  String get deptChatBrowseSubtitle =>
      'ابحث عن قسم وانضم إلى محادثته أو غادر متى شئت.';

  @override
  String get deptChatSearch => 'ابحث عن قسم';

  @override
  String get clubReviewRequiredTitle => 'موافقة الإدارة مطلوبة';

  @override
  String get clubReviewRequiredBody =>
      'سينتظر ناديك المراجعة بعد إنشائه. يمكنك وحدك رؤيته حتى الموافقة عليه. سنرسل إليك إشعاراً عند الموافقة.';

  @override
  String get coreErrServiceUnavailable =>
      'يتعذر إكمال العملية حالياً. يرجى المحاولة لاحقاً.';

  @override
  String get chatMiscMoreAction => 'المزيد';

  @override
  String get chatMiscPeekOpen => 'فتح المحادثة';

  @override
  String get chatMiscPeekError => 'تعذر تحميل الرسائل.';

  @override
  String get chatMiscPeekEmpty => 'لا توجد رسائل بعد.';

  @override
  String get pushForeignSwitched =>
      'كان هذا الإشعار يخص حسابًا آخر لديك، وتم التبديل إليه.';

  @override
  String get pushForeignMissing =>
      'يخص هذا الإشعار حسابًا آخر غير محفوظ على هذا الجهاز.';

  @override
  String get pushForeignExpired =>
      'يخص هذا الإشعار حسابًا انتهت جلسته. سيُفتح بعد تسجيل الدخول إليه.';

  @override
  String get pushContentGone => 'هذا المحتوى لم يعد متاحًا.';

  @override
  String get sessionEndedFormClosed =>
      'انتهت جلستك فأُغلقت الصفحة المفتوحة. لم يتم حفظ ما كتبته.';

  @override
  String get formDiscardTitle => 'هل تريد تجاهل ما كتبته؟';

  @override
  String get formDiscardBody => 'إذا غادرت ستفقد المعلومات التي أدخلتها.';

  @override
  String get formDiscardConfirm => 'تجاهل وخروج';

  @override
  String get formDiscardKeep => 'متابعة التحرير';

  @override
  String get g4ChatJumpMissing => 'هذه الرسالة لم تعد متاحة أو تعذر تحميلها.';

  @override
  String get shareKindProfile => 'ملف شخصي';

  @override
  String get shareChatProfileShared => 'شارك ملفًا شخصيًا';

  @override
  String get profileShareAction => 'مشاركة الملف الشخصي';

  @override
  String get profileQrMyCode => 'رمز QR الخاص بي';

  @override
  String get profileQrHint =>
      'من يمسح هذا الرمز يرى الملف الشخصي في BÜ Kampüs. يمكن لكاميرا الهاتف قراءته أيضًا.';

  @override
  String get profileQrShareImage => 'مشاركة كصورة';

  @override
  String get profileQrImageFailed => 'تعذر تجهيز الصورة. يمكنك مشاركة الرابط.';

  @override
  String get profileQrLoadFailed => 'تعذر تجهيز رمز QR الآن.';

  @override
  String get profileQrScan => 'مسح رمز QR';

  @override
  String get profileQrScanTitle => 'مسح رمز QR لملف شخصي';

  @override
  String get profileQrScanHint => 'وجّه رمز ملف BÜ Kampüs داخل الإطار.';

  @override
  String get profileQrInvalid => 'هذا ليس رمز ملف شخصي في BÜ Kampüs.';

  @override
  String get profileQrOpenSettings => 'فتح الإعدادات';

  @override
  String get profileQrGallery => 'اختيار من المعرض';

  @override
  String get profileQrGalleryNone => 'لم يتم العثور على رمز QR في الصورة.';

  @override
  String get profileQrMyProfile => 'هذا رمزك، سيتم فتح ملفك الشخصي.';

  @override
  String get profileQrFindMe => 'ابحث عني في BÜ Kampüs';

  @override
  String get chatVoiceMic => 'تسجيل رسالة صوتية';

  @override
  String get chatVoiceHold => 'اضغط مطولاً على الميكروفون للتسجيل';

  @override
  String get chatVoiceSlideCancel => 'اسحب للإلغاء';

  @override
  String get chatVoiceStopSend => 'إنهاء التسجيل وإرساله';

  @override
  String get chatVoiceCancel => 'إلغاء التسجيل';

  @override
  String get chatVoiceMessage => 'رسالة صوتية';

  @override
  String get chatVoicePlay => 'تشغيل';

  @override
  String get chatVoicePause => 'إيقاف مؤقت';

  @override
  String get chatVoiceInterrupted => 'انقطع التسجيل';

  @override
  String get chatVoiceFailed => 'تعذر تشغيل الرسالة الصوتية';

  @override
  String get chatVoiceLimit =>
      'يجب ألا تتجاوز الرسالة الصوتية 5 دقائق؛ تم إرسال التسجيل.';

  @override
  String get chatVoiceNoMic => 'تعذر تشغيل الميكروفون';

  @override
  String chatVoiceSemantics(String duration, String state) {
    return 'رسالة صوتية، $duration، $state';
  }

  @override
  String chatVoiceRecording(String time) {
    return 'جارٍ التسجيل $time';
  }

  @override
  String chatVoiceSpeed(String speed) {
    return 'سرعة التشغيل $speed';
  }
}
