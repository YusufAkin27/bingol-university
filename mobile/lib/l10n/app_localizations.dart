import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @commonRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get commonRetry;

  /// No description provided for @commonRetryShort.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get commonRetryShort;

  /// No description provided for @commonCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get commonClose;

  /// No description provided for @commonLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor'**
  String get commonLoading;

  /// No description provided for @commonUpdate.
  ///
  /// In tr, this message translates to:
  /// **'Güncelle'**
  String get commonUpdate;

  /// No description provided for @commonOpenInStore.
  ///
  /// In tr, this message translates to:
  /// **'Mağazada aç'**
  String get commonOpenInStore;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti'**
  String get commonSomethingWentWrong;

  /// No description provided for @configError.
  ///
  /// In tr, this message translates to:
  /// **'Yapılandırma hatası: sunucu adresi (API_BASE) güvenli (https) değil. Uygulamayı doğru adresle yeniden derleyin.'**
  String get configError;

  /// No description provided for @exitAgainHint.
  ///
  /// In tr, this message translates to:
  /// **'Çıkmak için tekrar geri basın'**
  String get exitAgainHint;

  /// No description provided for @navHome.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get navHome;

  /// No description provided for @navDiscover.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get navDiscover;

  /// No description provided for @navChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get navChat;

  /// No description provided for @navClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpler'**
  String get navClubs;

  /// No description provided for @navProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme gerekli'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.'**
  String get updateRequiredBody;

  /// No description provided for @updateAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sürüm mevcut.'**
  String get updateAvailable;

  /// No description provided for @updateAvailableVersion.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sürüm mevcut ({version}).'**
  String updateAvailableVersion(String version);

  /// No description provided for @accessBlockedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Erişim kapatıldı'**
  String get accessBlockedTitle;

  /// No description provided for @accessBlockedBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihaza veya ağa erişim kapatıldı. Hatalı olduğunu düşünüyorsan destek ile iletişime geç.'**
  String get accessBlockedBody;

  /// No description provided for @settingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In tr, this message translates to:
  /// **'GÖRÜNÜM'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In tr, this message translates to:
  /// **'BİLDİRİMLER'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'GİZLİLİK VE HESAP'**
  String get settingsSectionPrivacy;

  /// No description provided for @themeSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In tr, this message translates to:
  /// **'Arayüz, bildirim ve e-posta dili'**
  String get settingsLanguageHint;

  /// No description provided for @languageSystem.
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get languageSystem;

  /// No description provided for @pushPermission.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni (push)'**
  String get pushPermission;

  /// No description provided for @pushNotConfigured.
  ///
  /// In tr, this message translates to:
  /// **'Henüz yapılandırılmadı'**
  String get pushNotConfigured;

  /// No description provided for @pushOn.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get pushOn;

  /// No description provided for @pushOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı (sistem ayarlarından açın)'**
  String get pushOff;

  /// No description provided for @pushNotGranted.
  ///
  /// In tr, this message translates to:
  /// **'İzin verilmedi'**
  String get pushNotGranted;

  /// No description provided for @pushOnToast.
  ///
  /// In tr, this message translates to:
  /// **'Anlık bildirimler açık.'**
  String get pushOnToast;

  /// No description provided for @pushStatusToast.
  ///
  /// In tr, this message translates to:
  /// **'Anlık bildirimler: {status}'**
  String pushStatusToast(String status);

  /// No description provided for @settingsShowEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-postamı diğerlerine göster'**
  String get settingsShowEmail;

  /// No description provided for @settingsFindContacts.
  ///
  /// In tr, this message translates to:
  /// **'Rehberden kişi bul'**
  String get settingsFindContacts;

  /// No description provided for @settingsPrivacyData.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik ve veriler'**
  String get settingsPrivacyData;

  /// No description provided for @settingsSupport.
  ///
  /// In tr, this message translates to:
  /// **'Destek ve SSS'**
  String get settingsSupport;

  /// No description provided for @settingsLogoutAll.
  ///
  /// In tr, this message translates to:
  /// **'Tüm cihazlardan çıkış yap'**
  String get settingsLogoutAll;

  /// No description provided for @settingsLogoutAllTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm cihazlardan çıkış'**
  String get settingsLogoutAllTitle;

  /// No description provided for @settingsLogoutAllBody.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız tüm cihazlarda kapatılacak ve yeniden giriş yapmanız gerekecek.'**
  String get settingsLogoutAllBody;

  /// No description provided for @settingsLogoutAllConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get settingsLogoutAllConfirm;

  /// No description provided for @settingsVersion.
  ///
  /// In tr, this message translates to:
  /// **'BÜ Kampüs · Sürüm {version}'**
  String settingsVersion(String version);

  /// No description provided for @loginWelcome.
  ///
  /// In tr, this message translates to:
  /// **'Hoş geldiniz'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Bingöl Üniversitesi hesabınızla giriş yapın.'**
  String get loginSubtitle;

  /// No description provided for @loginReplacedNotice.
  ///
  /// In tr, this message translates to:
  /// **'Hesabına başka bir cihazdan giriş yapıldı. Güvenliğin için bu cihazdaki oturum kapatıldı.'**
  String get loginReplacedNotice;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In tr, this message translates to:
  /// **'Şifrenizi girin.'**
  String get loginPasswordRequired;

  /// No description provided for @loginForgotPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifremi unuttum'**
  String get loginForgotPassword;

  /// No description provided for @loginSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yap'**
  String get loginSubmit;

  /// No description provided for @loginNoAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız yok mu?'**
  String get loginNoAccount;

  /// No description provided for @loginRegister.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ol'**
  String get loginRegister;

  /// No description provided for @loginCompleteVerification.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulamayı tamamla'**
  String get loginCompleteVerification;

  /// No description provided for @authBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get authBack;

  /// No description provided for @authShowPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi göster'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi gizle'**
  String get authHidePassword;

  /// No description provided for @authPasswordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get authPasswordLabel;

  /// No description provided for @authIdHint.
  ///
  /// In tr, this message translates to:
  /// **'Okul numarası veya e-posta'**
  String get authIdHint;

  /// No description provided for @authVerify.
  ///
  /// In tr, this message translates to:
  /// **'Doğrula'**
  String get authVerify;

  /// No description provided for @authResendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu yeniden gönder'**
  String get authResendCode;

  /// No description provided for @authResendIn.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden gönder ({seconds} sn)'**
  String authResendIn(String seconds);

  /// No description provided for @authNewCodeIn.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kod için {seconds} sn bekleyin'**
  String authNewCodeIn(String seconds);

  /// No description provided for @authCodeSent.
  ///
  /// In tr, this message translates to:
  /// **'Kod gönderildi.'**
  String get authCodeSent;

  /// No description provided for @authNewCodeSent.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kod gönderildi.'**
  String get authNewCodeSent;

  /// No description provided for @authEnterCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu girin'**
  String get authEnterCode;

  /// No description provided for @authCodeSentTo.
  ///
  /// In tr, this message translates to:
  /// **'{email} adresine kod gönderildi.'**
  String authCodeSentTo(String email);

  /// No description provided for @authVerifyEmailTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-postanızı doğrulayın'**
  String get authVerifyEmailTitle;

  /// No description provided for @authVerifySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Kod {email} adresine gönderildi. 10 dakika geçerlidir.'**
  String authVerifySubtitle(String email);

  /// No description provided for @authUnverifiedNotice.
  ///
  /// In tr, this message translates to:
  /// **'E-postanı doğrula. Giriş yapabilmek için hesabının doğrulanması gerekir.'**
  String get authUnverifiedNotice;

  /// No description provided for @authUseOtherAccount.
  ///
  /// In tr, this message translates to:
  /// **'Başka hesapla giriş yap'**
  String get authUseOtherAccount;

  /// No description provided for @authResetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şifreni sıfırla'**
  String get authResetTitle;

  /// No description provided for @authSendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod gönder'**
  String get authSendCode;

  /// No description provided for @authNewPasswordTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre'**
  String get authNewPasswordTitle;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre (en az 8 karakter)'**
  String get authNewPasswordLabel;

  /// No description provided for @authUpdatePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi güncelle'**
  String get authUpdatePassword;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Şifre güncellendi.'**
  String get authPasswordUpdated;

  /// No description provided for @authSessionExpired.
  ///
  /// In tr, this message translates to:
  /// **'Süre doldu. Baştan başlayın.'**
  String get authSessionExpired;

  /// No description provided for @authCreateAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap oluştur'**
  String get authCreateAccount;

  /// No description provided for @authSelectDepartment.
  ///
  /// In tr, this message translates to:
  /// **'Bölümünüzü seçin.'**
  String get authSelectDepartment;

  /// No description provided for @authSelectGrade.
  ///
  /// In tr, this message translates to:
  /// **'Sınıfınızı seçin.'**
  String get authSelectGrade;

  /// No description provided for @authDepartmentsLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm listesi yüklenemedi. Yeniden deneyin.'**
  String get authDepartmentsLoadFailed;

  /// No description provided for @authNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Adınızı ve soyadınızı girin.'**
  String get authNameRequired;

  /// No description provided for @authNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad'**
  String get authNameHint;

  /// No description provided for @authPasswordMin8.
  ///
  /// In tr, this message translates to:
  /// **'Şifre (en az 8 karakter)'**
  String get authPasswordMin8;

  /// No description provided for @authTermsPrefix.
  ///
  /// In tr, this message translates to:
  /// **''**
  String get authTermsPrefix;

  /// No description provided for @authTermsLink.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım koşulları'**
  String get authTermsLink;

  /// No description provided for @authTermsSep.
  ///
  /// In tr, this message translates to:
  /// **' ve '**
  String get authTermsSep;

  /// No description provided for @authPrivacyLink.
  ///
  /// In tr, this message translates to:
  /// **'gizlilik politikasını'**
  String get authPrivacyLink;

  /// No description provided for @authTermsSuffix.
  ///
  /// In tr, this message translates to:
  /// **' kabul ediyorum'**
  String get authTermsSuffix;

  /// No description provided for @authMustAccept.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için kabul etmelisiniz.'**
  String get authMustAccept;

  /// No description provided for @authHaveAccount.
  ///
  /// In tr, this message translates to:
  /// **'Zaten hesabınız var mı?'**
  String get authHaveAccount;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Birkaç adımda kampüse katılın.'**
  String get authRegisterSubtitle;

  /// No description provided for @authSectionAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Akademik bilgiler'**
  String get authSectionAcademic;

  /// No description provided for @authSectionAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap bilgileri'**
  String get authSectionAccount;

  /// No description provided for @authPwWeak.
  ///
  /// In tr, this message translates to:
  /// **'Zayıf'**
  String get authPwWeak;

  /// No description provided for @authPwFair.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get authPwFair;

  /// No description provided for @authPwStrong.
  ///
  /// In tr, this message translates to:
  /// **'Güçlü'**
  String get authPwStrong;
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
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
