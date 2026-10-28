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
  String get navChat => 'الدردشة';

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
  String get loginSubtitle => 'سجّل الدخول بحساب جامعة بينغول.';

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
  String get authIdHint => 'الرقم الجامعي أو البريد الإلكتروني';

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
    return 'تم إرسال رمز إلى $email.';
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
  String get authResetTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get authSendCode => 'إرسال الرمز';

  @override
  String get authNewPasswordTitle => 'كلمة مرور جديدة';

  @override
  String get authNewPasswordLabel => 'كلمة المرور الجديدة (8 أحرف على الأقل)';

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
}
