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
  /// **'Okul e-postanızla giriş yapın.'**
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
  /// **'Okul e-postanız'**
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
  /// **'{email} adresine gönderdiğimiz 6 haneli kodu girin.'**
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
  /// **'Şifrenizi mi unuttunuz?'**
  String get authResetTitle;

  /// No description provided for @authSendCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod gönder'**
  String get authSendCode;

  /// No description provided for @authNewPasswordTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre belirleyin'**
  String get authNewPasswordTitle;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre'**
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

  /// No description provided for @acadMonth1.
  ///
  /// In tr, this message translates to:
  /// **'Ocak'**
  String get acadMonth1;

  /// No description provided for @acadMonth2.
  ///
  /// In tr, this message translates to:
  /// **'Şubat'**
  String get acadMonth2;

  /// No description provided for @acadMonth3.
  ///
  /// In tr, this message translates to:
  /// **'Mart'**
  String get acadMonth3;

  /// No description provided for @acadMonth4.
  ///
  /// In tr, this message translates to:
  /// **'Nisan'**
  String get acadMonth4;

  /// No description provided for @acadMonth5.
  ///
  /// In tr, this message translates to:
  /// **'Mayıs'**
  String get acadMonth5;

  /// No description provided for @acadMonth6.
  ///
  /// In tr, this message translates to:
  /// **'Haziran'**
  String get acadMonth6;

  /// No description provided for @acadMonth7.
  ///
  /// In tr, this message translates to:
  /// **'Temmuz'**
  String get acadMonth7;

  /// No description provided for @acadMonth8.
  ///
  /// In tr, this message translates to:
  /// **'Ağustos'**
  String get acadMonth8;

  /// No description provided for @acadMonth9.
  ///
  /// In tr, this message translates to:
  /// **'Eylül'**
  String get acadMonth9;

  /// No description provided for @acadMonth10.
  ///
  /// In tr, this message translates to:
  /// **'Ekim'**
  String get acadMonth10;

  /// No description provided for @acadMonth11.
  ///
  /// In tr, this message translates to:
  /// **'Kasım'**
  String get acadMonth11;

  /// No description provided for @acadMonth12.
  ///
  /// In tr, this message translates to:
  /// **'Aralık'**
  String get acadMonth12;

  /// No description provided for @acadDay1.
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi'**
  String get acadDay1;

  /// No description provided for @acadDay2.
  ///
  /// In tr, this message translates to:
  /// **'Salı'**
  String get acadDay2;

  /// No description provided for @acadDay3.
  ///
  /// In tr, this message translates to:
  /// **'Çarşamba'**
  String get acadDay3;

  /// No description provided for @acadDay4.
  ///
  /// In tr, this message translates to:
  /// **'Perşembe'**
  String get acadDay4;

  /// No description provided for @acadDay5.
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get acadDay5;

  /// No description provided for @acadDay6.
  ///
  /// In tr, this message translates to:
  /// **'Cumartesi'**
  String get acadDay6;

  /// No description provided for @acadDay7.
  ///
  /// In tr, this message translates to:
  /// **'Pazar'**
  String get acadDay7;

  /// No description provided for @acadDayShort1.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get acadDayShort1;

  /// No description provided for @acadDayShort2.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get acadDayShort2;

  /// No description provided for @acadDayShort3.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get acadDayShort3;

  /// No description provided for @acadDayShort4.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get acadDayShort4;

  /// No description provided for @acadDayShort5.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get acadDayShort5;

  /// No description provided for @acadDayShort6.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get acadDayShort6;

  /// No description provided for @acadDayShort7.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get acadDayShort7;

  /// No description provided for @acadColorRed.
  ///
  /// In tr, this message translates to:
  /// **'Kırmızı'**
  String get acadColorRed;

  /// No description provided for @acadColorOrange.
  ///
  /// In tr, this message translates to:
  /// **'Turuncu'**
  String get acadColorOrange;

  /// No description provided for @acadColorAmber.
  ///
  /// In tr, this message translates to:
  /// **'Sarı'**
  String get acadColorAmber;

  /// No description provided for @acadColorGreen.
  ///
  /// In tr, this message translates to:
  /// **'Yeşil'**
  String get acadColorGreen;

  /// No description provided for @acadColorTeal.
  ///
  /// In tr, this message translates to:
  /// **'Turkuaz'**
  String get acadColorTeal;

  /// No description provided for @acadColorBlue.
  ///
  /// In tr, this message translates to:
  /// **'Mavi'**
  String get acadColorBlue;

  /// No description provided for @acadColorIndigo.
  ///
  /// In tr, this message translates to:
  /// **'Çivit'**
  String get acadColorIndigo;

  /// No description provided for @acadColorPurple.
  ///
  /// In tr, this message translates to:
  /// **'Mor'**
  String get acadColorPurple;

  /// No description provided for @acadColorPink.
  ///
  /// In tr, this message translates to:
  /// **'Pembe'**
  String get acadColorPink;

  /// No description provided for @acadColorGray.
  ///
  /// In tr, this message translates to:
  /// **'Gri'**
  String get acadColorGray;

  /// No description provided for @acadExamTypeVize.
  ///
  /// In tr, this message translates to:
  /// **'Vize'**
  String get acadExamTypeVize;

  /// No description provided for @acadExamTypeFinal.
  ///
  /// In tr, this message translates to:
  /// **'Final'**
  String get acadExamTypeFinal;

  /// No description provided for @acadExamTypeBut.
  ///
  /// In tr, this message translates to:
  /// **'Bütünleme'**
  String get acadExamTypeBut;

  /// No description provided for @acadExamTypeQuiz.
  ///
  /// In tr, this message translates to:
  /// **'Quiz'**
  String get acadExamTypeQuiz;

  /// No description provided for @acadExamTypeOdev.
  ///
  /// In tr, this message translates to:
  /// **'Ödev'**
  String get acadExamTypeOdev;

  /// No description provided for @acadExamTypeDiger.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get acadExamTypeDiger;

  /// No description provided for @acadEventKindSemesterStart.
  ///
  /// In tr, this message translates to:
  /// **'Dönem başlangıcı'**
  String get acadEventKindSemesterStart;

  /// No description provided for @acadEventKindRegistration.
  ///
  /// In tr, this message translates to:
  /// **'Ders kaydı'**
  String get acadEventKindRegistration;

  /// No description provided for @acadEventKindHoliday.
  ///
  /// In tr, this message translates to:
  /// **'Tatil'**
  String get acadEventKindHoliday;

  /// No description provided for @acadEventKindPublicHoliday.
  ///
  /// In tr, this message translates to:
  /// **'Resmi tatil'**
  String get acadEventKindPublicHoliday;

  /// No description provided for @acadCountdownDays.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün kaldı'**
  String acadCountdownDays(String n);

  /// No description provided for @acadCountdownHours.
  ///
  /// In tr, this message translates to:
  /// **'{n} saat kaldı'**
  String acadCountdownHours(String n);

  /// No description provided for @acadCountdownMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk kaldı'**
  String acadCountdownMinutes(String n);

  /// No description provided for @acadGradePrep.
  ///
  /// In tr, this message translates to:
  /// **'Hazırlık'**
  String get acadGradePrep;

  /// No description provided for @acadGradeMaster.
  ///
  /// In tr, this message translates to:
  /// **'Yüksek lisans'**
  String get acadGradeMaster;

  /// No description provided for @acadGradePhd.
  ///
  /// In tr, this message translates to:
  /// **'Doktora'**
  String get acadGradePhd;

  /// No description provided for @acadGradeN.
  ///
  /// In tr, this message translates to:
  /// **'{n}. sınıf'**
  String acadGradeN(String n);

  /// No description provided for @acadSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get acadSave;

  /// No description provided for @acadDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get acadDelete;

  /// No description provided for @acadCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get acadCancel;

  /// No description provided for @acadRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get acadRetry;

  /// No description provided for @acadSelect.
  ///
  /// In tr, this message translates to:
  /// **'Seç'**
  String get acadSelect;

  /// No description provided for @acadMaintenance.
  ///
  /// In tr, this message translates to:
  /// **'Akademik hizmetler bakımda. Daha sonra tekrar deneyin.'**
  String get acadMaintenance;

  /// No description provided for @acadMyDept.
  ///
  /// In tr, this message translates to:
  /// **'Bölümüm'**
  String get acadMyDept;

  /// No description provided for @acadAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get acadAll;

  /// No description provided for @acadHubTitle.
  ///
  /// In tr, this message translates to:
  /// **'Akademik'**
  String get acadHubTitle;

  /// No description provided for @acadHubReminders.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatmalar'**
  String get acadHubReminders;

  /// No description provided for @acadHubAddCourses.
  ///
  /// In tr, this message translates to:
  /// **'Derslerini ekle'**
  String get acadHubAddCourses;

  /// No description provided for @acadHubNoClassWeek.
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta ders yok'**
  String get acadHubNoClassWeek;

  /// No description provided for @acadHubNext.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki: {course} {time}'**
  String acadHubNext(String course, String time);

  /// No description provided for @acadHubNoExam.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan sınav yok'**
  String get acadHubNoExam;

  /// No description provided for @acadHubExamCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} yaklaşan sınav'**
  String acadHubExamCount(String n);

  /// No description provided for @acadHubTimetable.
  ///
  /// In tr, this message translates to:
  /// **'Ders programı'**
  String get acadHubTimetable;

  /// No description provided for @acadHubTimetableSub.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık ders programın'**
  String get acadHubTimetableSub;

  /// No description provided for @acadHubExamsSub.
  ///
  /// In tr, this message translates to:
  /// **'Sınav takvimin ve resmi program'**
  String get acadHubExamsSub;

  /// No description provided for @acadHubCalendarSub.
  ///
  /// In tr, this message translates to:
  /// **'Dönem, kayıt ve sınav tarihleri'**
  String get acadHubCalendarSub;

  /// No description provided for @acadHubAnnouncementsSub.
  ///
  /// In tr, this message translates to:
  /// **'Bölümüne özel duyurular'**
  String get acadHubAnnouncementsSub;

  /// No description provided for @acadHubUnread.
  ///
  /// In tr, this message translates to:
  /// **'{n} okunmamış'**
  String acadHubUnread(String n);

  /// No description provided for @acadExamsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sınavlar'**
  String get acadExamsTitle;

  /// No description provided for @acadExamsAdd.
  ///
  /// In tr, this message translates to:
  /// **'Sınav ekle'**
  String get acadExamsAdd;

  /// No description provided for @acadExamsTabMine.
  ///
  /// In tr, this message translates to:
  /// **'Sınavlarım'**
  String get acadExamsTabMine;

  /// No description provided for @acadExamsTabOfficial.
  ///
  /// In tr, this message translates to:
  /// **'Resmi program'**
  String get acadExamsTabOfficial;

  /// No description provided for @acadExamsEmptyMine.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel sınav eklemedin.\nVize, final ya da quiz tarihlerini buradan takip et.'**
  String get acadExamsEmptyMine;

  /// No description provided for @acadExamsUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get acadExamsUpcoming;

  /// No description provided for @acadExamsNoUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan sınavın yok.'**
  String get acadExamsNoUpcoming;

  /// No description provided for @acadExamsPast.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get acadExamsPast;

  /// No description provided for @acadExamsSemantic.
  ///
  /// In tr, this message translates to:
  /// **'{type}: {title}. {date}. Düzenlemek için dokun.'**
  String acadExamsSemantic(String type, String title, String date);

  /// No description provided for @acadExamsSemanticCd.
  ///
  /// In tr, this message translates to:
  /// **'{type}: {title}. {date}. {countdown}. Düzenlemek için dokun.'**
  String acadExamsSemanticCd(
      String type, String title, String date, String countdown);

  /// No description provided for @acadOfficialSemantic.
  ///
  /// In tr, this message translates to:
  /// **'{type}: {title}. {date}'**
  String acadOfficialSemantic(String type, String title, String date);

  /// No description provided for @acadOfficialSemanticRoom.
  ///
  /// In tr, this message translates to:
  /// **'{type}: {title}. {date}, {room}'**
  String acadOfficialSemanticRoom(
      String type, String title, String date, String room);

  /// No description provided for @acadExamsProfileIncomplete.
  ///
  /// In tr, this message translates to:
  /// **'Profilinde bölüm bilgisi yok; yalnız herkese açık sınavlar gösteriliyor. Profili düzenleyerek bölümünü ekleyebilirsin.'**
  String get acadExamsProfileIncomplete;

  /// No description provided for @acadExamsEmptyOfficial.
  ///
  /// In tr, this message translates to:
  /// **'Henüz yayınlanmış resmi sınav programı yok.'**
  String get acadExamsEmptyOfficial;

  /// No description provided for @acadFormErrTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sınav başlığı gerekli.'**
  String get acadFormErrTitle;

  /// No description provided for @acadFormErrDate.
  ///
  /// In tr, this message translates to:
  /// **'Sınav tarihini seç.'**
  String get acadFormErrDate;

  /// No description provided for @acadFormErrEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş saati başlangıçtan sonra olmalı.'**
  String get acadFormErrEnd;

  /// No description provided for @acadFormDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sınavı sil'**
  String get acadFormDeleteTitle;

  /// No description provided for @acadFormDeleteText.
  ///
  /// In tr, this message translates to:
  /// **'\"{title}\" silinecek.'**
  String acadFormDeleteText(String title);

  /// No description provided for @acadFormEdit.
  ///
  /// In tr, this message translates to:
  /// **'Sınavı düzenle'**
  String get acadFormEdit;

  /// No description provided for @acadFormNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sınav'**
  String get acadFormNew;

  /// No description provided for @acadFormTitleLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get acadFormTitleLabel;

  /// No description provided for @acadFormTitleHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Veri Yapıları Vize 1'**
  String get acadFormTitleHint;

  /// No description provided for @acadFormType.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get acadFormType;

  /// No description provided for @acadFormCourseOpt.
  ///
  /// In tr, this message translates to:
  /// **'Ders (isteğe bağlı)'**
  String get acadFormCourseOpt;

  /// No description provided for @acadFormNone.
  ///
  /// In tr, this message translates to:
  /// **'Yok'**
  String get acadFormNone;

  /// No description provided for @acadFormDateTime.
  ///
  /// In tr, this message translates to:
  /// **'Tarih ve saat'**
  String get acadFormDateTime;

  /// No description provided for @acadFormExamDate.
  ///
  /// In tr, this message translates to:
  /// **'Sınav tarihi'**
  String get acadFormExamDate;

  /// No description provided for @acadFormPickDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih seç'**
  String get acadFormPickDate;

  /// No description provided for @acadFormStartTime.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç saati'**
  String get acadFormStartTime;

  /// No description provided for @acadFormEndTime.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş saati'**
  String get acadFormEndTime;

  /// No description provided for @acadFormEndHint.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş (ops.)'**
  String get acadFormEndHint;

  /// No description provided for @acadFormRoom.
  ///
  /// In tr, this message translates to:
  /// **'Derslik'**
  String get acadFormRoom;

  /// No description provided for @acadFormRoomHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. B-204'**
  String get acadFormRoomHint;

  /// No description provided for @acadFormNote.
  ///
  /// In tr, this message translates to:
  /// **'Not'**
  String get acadFormNote;

  /// No description provided for @acadFormNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı'**
  String get acadFormNoteHint;

  /// No description provided for @acadFormAdd.
  ///
  /// In tr, this message translates to:
  /// **'Sınavı ekle'**
  String get acadFormAdd;

  /// No description provided for @acadAnnTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm duyuruları'**
  String get acadAnnTitle;

  /// No description provided for @acadAnnDetailTitle.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru'**
  String get acadAnnDetailTitle;

  /// No description provided for @acadAnnReadAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü okundu işaretle'**
  String get acadAnnReadAll;

  /// No description provided for @acadAnnEmptyMine.
  ///
  /// In tr, this message translates to:
  /// **'Bölümünle ilgili duyuru yok.\nTüm duyurulara \"Tümü\" sekmesinden bakabilirsin.'**
  String get acadAnnEmptyMine;

  /// No description provided for @acadAnnEmptyAll.
  ///
  /// In tr, this message translates to:
  /// **'Henüz duyuru yok.'**
  String get acadAnnEmptyAll;

  /// No description provided for @acadAnnAudienceAll.
  ///
  /// In tr, this message translates to:
  /// **'Tüm üniversite'**
  String get acadAnnAudienceAll;

  /// No description provided for @acadAnnUnread.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış'**
  String get acadAnnUnread;

  /// No description provided for @acadAnnPinned.
  ///
  /// In tr, this message translates to:
  /// **'Sabitlenmiş'**
  String get acadAnnPinned;

  /// No description provided for @acadAnnLinkError.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı açılamadı.'**
  String get acadAnnLinkError;

  /// No description provided for @acadAnnOpenAttachment.
  ///
  /// In tr, this message translates to:
  /// **'Eki aç'**
  String get acadAnnOpenAttachment;

  /// No description provided for @acadCalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Akademik takvim'**
  String get acadCalTitle;

  /// No description provided for @acadCalPrev.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get acadCalPrev;

  /// No description provided for @acadCalNext.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get acadCalNext;

  /// No description provided for @acadCalToday.
  ///
  /// In tr, this message translates to:
  /// **'bugün'**
  String get acadCalToday;

  /// No description provided for @acadCalEventCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} önemli tarih'**
  String acadCalEventCount(String n);

  /// No description provided for @acadCalMonthHeading.
  ///
  /// In tr, this message translates to:
  /// **'{month} ayı önemli tarihleri'**
  String acadCalMonthHeading(String month);

  /// No description provided for @acadCalNoMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay için kayıtlı önemli tarih yok.'**
  String get acadCalNoMonth;

  /// No description provided for @acadCalNoDay.
  ///
  /// In tr, this message translates to:
  /// **'Bu günde önemli tarih yok.'**
  String get acadCalNoDay;

  /// No description provided for @acadCalNextHeading.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki önemli tarihler'**
  String get acadCalNextHeading;

  /// No description provided for @acadTimeDay1.
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi'**
  String get acadTimeDay1;

  /// No description provided for @acadTimeDay2.
  ///
  /// In tr, this message translates to:
  /// **'Salı'**
  String get acadTimeDay2;

  /// No description provided for @acadTimeDay3.
  ///
  /// In tr, this message translates to:
  /// **'Çarşamba'**
  String get acadTimeDay3;

  /// No description provided for @acadTimeDay4.
  ///
  /// In tr, this message translates to:
  /// **'Perşembe'**
  String get acadTimeDay4;

  /// No description provided for @acadTimeDay5.
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get acadTimeDay5;

  /// No description provided for @acadTimeDay6.
  ///
  /// In tr, this message translates to:
  /// **'Cumartesi'**
  String get acadTimeDay6;

  /// No description provided for @acadTimeDay7.
  ///
  /// In tr, this message translates to:
  /// **'Pazar'**
  String get acadTimeDay7;

  /// No description provided for @acadTimeDayShort1.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get acadTimeDayShort1;

  /// No description provided for @acadTimeDayShort2.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get acadTimeDayShort2;

  /// No description provided for @acadTimeDayShort3.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get acadTimeDayShort3;

  /// No description provided for @acadTimeDayShort4.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get acadTimeDayShort4;

  /// No description provided for @acadTimeDayShort5.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get acadTimeDayShort5;

  /// No description provided for @acadTimeDayShort6.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get acadTimeDayShort6;

  /// No description provided for @acadTimeDayShort7.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get acadTimeDayShort7;

  /// No description provided for @acadTimeColorRed.
  ///
  /// In tr, this message translates to:
  /// **'Kırmızı'**
  String get acadTimeColorRed;

  /// No description provided for @acadTimeColorOrange.
  ///
  /// In tr, this message translates to:
  /// **'Turuncu'**
  String get acadTimeColorOrange;

  /// No description provided for @acadTimeColorAmber.
  ///
  /// In tr, this message translates to:
  /// **'Sarı'**
  String get acadTimeColorAmber;

  /// No description provided for @acadTimeColorGreen.
  ///
  /// In tr, this message translates to:
  /// **'Yeşil'**
  String get acadTimeColorGreen;

  /// No description provided for @acadTimeColorTeal.
  ///
  /// In tr, this message translates to:
  /// **'Turkuaz'**
  String get acadTimeColorTeal;

  /// No description provided for @acadTimeColorBlue.
  ///
  /// In tr, this message translates to:
  /// **'Mavi'**
  String get acadTimeColorBlue;

  /// No description provided for @acadTimeColorIndigo.
  ///
  /// In tr, this message translates to:
  /// **'Çivit'**
  String get acadTimeColorIndigo;

  /// No description provided for @acadTimeColorPurple.
  ///
  /// In tr, this message translates to:
  /// **'Mor'**
  String get acadTimeColorPurple;

  /// No description provided for @acadTimeColorPink.
  ///
  /// In tr, this message translates to:
  /// **'Pembe'**
  String get acadTimeColorPink;

  /// No description provided for @acadTimeColorGray.
  ///
  /// In tr, this message translates to:
  /// **'Gri'**
  String get acadTimeColorGray;

  /// No description provided for @acadTimeExamVize.
  ///
  /// In tr, this message translates to:
  /// **'Vize'**
  String get acadTimeExamVize;

  /// No description provided for @acadTimeExamFinal.
  ///
  /// In tr, this message translates to:
  /// **'Final'**
  String get acadTimeExamFinal;

  /// No description provided for @acadTimeExamBut.
  ///
  /// In tr, this message translates to:
  /// **'Bütünleme'**
  String get acadTimeExamBut;

  /// No description provided for @acadTimeExamQuiz.
  ///
  /// In tr, this message translates to:
  /// **'Quiz'**
  String get acadTimeExamQuiz;

  /// No description provided for @acadTimeExamOdev.
  ///
  /// In tr, this message translates to:
  /// **'Ödev'**
  String get acadTimeExamOdev;

  /// No description provided for @acadTimeExamOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get acadTimeExamOther;

  /// No description provided for @acadTimeRemClass.
  ///
  /// In tr, this message translates to:
  /// **'{min} dk sonra başlıyor ({time}{room})'**
  String acadTimeRemClass(String min, String time, String room);

  /// No description provided for @acadTimeRemExamLabel.
  ///
  /// In tr, this message translates to:
  /// **'{type}: {title}'**
  String acadTimeRemExamLabel(String type, String title);

  /// No description provided for @acadTimeRemExamTomorrow.
  ///
  /// In tr, this message translates to:
  /// **'Yarın {time}{room}'**
  String acadTimeRemExamTomorrow(String time, String room);

  /// No description provided for @acadTimeRemExamHour.
  ///
  /// In tr, this message translates to:
  /// **'1 saat sonra başlıyor{room}'**
  String acadTimeRemExamHour(String room);

  /// No description provided for @acadTimeExportNone.
  ///
  /// In tr, this message translates to:
  /// **'Dışa aktarılacak ders yok.'**
  String get acadTimeExportNone;

  /// No description provided for @acadTimeExportCopied.
  ///
  /// In tr, this message translates to:
  /// **'Takvim (.ics) metni panoya kopyalandı.'**
  String get acadTimeExportCopied;

  /// No description provided for @acadTimeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ders programı'**
  String get acadTimeTitle;

  /// No description provided for @acadTimeExportTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Takvime aktar (.ics)'**
  String get acadTimeExportTooltip;

  /// No description provided for @acadTimeAddCourse.
  ///
  /// In tr, this message translates to:
  /// **'Ders ekle'**
  String get acadTimeAddCourse;

  /// No description provided for @acadTimeStale.
  ///
  /// In tr, this message translates to:
  /// **'Güncellenemedi, son veriler gösteriliyor.'**
  String get acadTimeStale;

  /// No description provided for @acadTimePickSemester.
  ///
  /// In tr, this message translates to:
  /// **'Dönem seç'**
  String get acadTimePickSemester;

  /// No description provided for @acadTimeMyCourses.
  ///
  /// In tr, this message translates to:
  /// **'Derslerim ({count})'**
  String acadTimeMyCourses(String count);

  /// No description provided for @acadTimeEmptyText.
  ///
  /// In tr, this message translates to:
  /// **'Henüz ders eklemedin.\nHaftalık programını oluşturmak için derslerini ekle.'**
  String get acadTimeEmptyText;

  /// No description provided for @acadTimeAddFirst.
  ///
  /// In tr, this message translates to:
  /// **'İlk dersini ekle'**
  String get acadTimeAddFirst;

  /// No description provided for @acadTimeNowInClass.
  ///
  /// In tr, this message translates to:
  /// **'Şu an derste'**
  String get acadTimeNowInClass;

  /// No description provided for @acadTimeMinLeft.
  ///
  /// In tr, this message translates to:
  /// **'{name} · {min} dk kaldı'**
  String acadTimeMinLeft(String name, String min);

  /// No description provided for @acadTimeNextClass.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki ders'**
  String get acadTimeNextClass;

  /// No description provided for @acadTimeWhenMin.
  ///
  /// In tr, this message translates to:
  /// **'{min} dk sonra'**
  String acadTimeWhenMin(String min);

  /// No description provided for @acadTimeWhenHours.
  ///
  /// In tr, this message translates to:
  /// **'{h} sa sonra'**
  String acadTimeWhenHours(String h);

  /// No description provided for @acadTimeWhenHoursMin.
  ///
  /// In tr, this message translates to:
  /// **'{h} sa {min} dk sonra'**
  String acadTimeWhenHoursMin(String h, String min);

  /// No description provided for @acadTimeWhenDay.
  ///
  /// In tr, this message translates to:
  /// **'{day} {time}'**
  String acadTimeWhenDay(String day, String time);

  /// No description provided for @acadTimeToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get acadTimeToday;

  /// No description provided for @acadTimeNoMoreWeek.
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta başka dersin yok.'**
  String get acadTimeNoMoreWeek;

  /// No description provided for @acadTimeTodayNone.
  ///
  /// In tr, this message translates to:
  /// **'Bugün kalan ders yok'**
  String get acadTimeTodayNone;

  /// No description provided for @acadTimeTodayLeft.
  ///
  /// In tr, this message translates to:
  /// **'Bugün {count} ders kaldı'**
  String acadTimeTodayLeft(String count);

  /// No description provided for @acadTimeDayToday.
  ///
  /// In tr, this message translates to:
  /// **'{day}, bugün'**
  String acadTimeDayToday(String day);

  /// No description provided for @acadTimeNoClassDay.
  ///
  /// In tr, this message translates to:
  /// **'{day} günü dersin yok.'**
  String acadTimeNoClassDay(String day);

  /// No description provided for @acadTimeOutOfRange.
  ///
  /// In tr, this message translates to:
  /// **'Bu tarih dönem aralığı dışında.'**
  String get acadTimeOutOfRange;

  /// No description provided for @acadTimeStatusNow.
  ///
  /// In tr, this message translates to:
  /// **'Şu an'**
  String get acadTimeStatusNow;

  /// No description provided for @acadTimeStatusDone.
  ///
  /// In tr, this message translates to:
  /// **'Bitti'**
  String get acadTimeStatusDone;

  /// No description provided for @acadTimeSlotSemantic.
  ///
  /// In tr, this message translates to:
  /// **'{name}, {day} {start} ile {end} arası'**
  String acadTimeSlotSemantic(
      String name, String day, String start, String end);

  /// No description provided for @acadTimeCourseSemantic.
  ///
  /// In tr, this message translates to:
  /// **'{name}. {days}. Düzenlemek için dokun.'**
  String acadTimeCourseSemantic(String name, String days);

  /// No description provided for @acadTimeNoSessions.
  ///
  /// In tr, this message translates to:
  /// **'Oturum yok'**
  String get acadTimeNoSessions;

  /// No description provided for @acadTimeNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Ders adı gerekli'**
  String get acadTimeNameRequired;

  /// No description provided for @acadTimeEndAfterStart.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş saati başlangıçtan sonra olmalı.'**
  String get acadTimeEndAfterStart;

  /// No description provided for @acadTimeOwnConflict.
  ///
  /// In tr, this message translates to:
  /// **'Bu dersin kendi oturumları çakışıyor'**
  String get acadTimeOwnConflict;

  /// No description provided for @acadTimeConflictTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ders çakışması'**
  String get acadTimeConflictTitle;

  /// No description provided for @acadTimeConflictText.
  ///
  /// In tr, this message translates to:
  /// **'Şu derslerle saatler çakışıyor:\n{lines}\n\nYine de kaydedilsin mi?'**
  String acadTimeConflictText(String lines);

  /// No description provided for @acadTimeConflictServerText.
  ///
  /// In tr, this message translates to:
  /// **'{message}\n\nYine de kaydedilsin mi?'**
  String acadTimeConflictServerText(String message);

  /// No description provided for @acadTimeSaveAnyway.
  ///
  /// In tr, this message translates to:
  /// **'Yine de kaydet'**
  String get acadTimeSaveAnyway;

  /// No description provided for @acadTimeDeleteCourse.
  ///
  /// In tr, this message translates to:
  /// **'Dersi sil'**
  String get acadTimeDeleteCourse;

  /// No description provided for @acadTimeDeleteCourseText.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" dersi ve tüm oturumları silinecek.'**
  String acadTimeDeleteCourseText(String name);

  /// No description provided for @acadTimeDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get acadTimeDelete;

  /// No description provided for @acadTimeEditCourse.
  ///
  /// In tr, this message translates to:
  /// **'Dersi düzenle'**
  String get acadTimeEditCourse;

  /// No description provided for @acadTimeNewCourse.
  ///
  /// In tr, this message translates to:
  /// **'Yeni ders'**
  String get acadTimeNewCourse;

  /// No description provided for @acadTimeCourseName.
  ///
  /// In tr, this message translates to:
  /// **'Ders adı'**
  String get acadTimeCourseName;

  /// No description provided for @acadTimeNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Veri Yapıları'**
  String get acadTimeNameHint;

  /// No description provided for @acadTimeCourseCode.
  ///
  /// In tr, this message translates to:
  /// **'Ders kodu'**
  String get acadTimeCourseCode;

  /// No description provided for @acadTimeInstructor.
  ///
  /// In tr, this message translates to:
  /// **'Öğretim üyesi'**
  String get acadTimeInstructor;

  /// No description provided for @acadTimeInstructorHint.
  ///
  /// In tr, this message translates to:
  /// **'Dr. Ayşe Yılmaz'**
  String get acadTimeInstructorHint;

  /// No description provided for @acadTimeColor.
  ///
  /// In tr, this message translates to:
  /// **'Renk'**
  String get acadTimeColor;

  /// No description provided for @acadTimeColorSemantic.
  ///
  /// In tr, this message translates to:
  /// **'Renk {color}'**
  String acadTimeColorSemantic(String color);

  /// No description provided for @acadTimeColorAuto.
  ///
  /// In tr, this message translates to:
  /// **'Seçmezseniz otomatik atanır.'**
  String get acadTimeColorAuto;

  /// No description provided for @acadTimeDaysAndTimes.
  ///
  /// In tr, this message translates to:
  /// **'Gün ve saatler'**
  String get acadTimeDaysAndTimes;

  /// No description provided for @acadTimeAddSession.
  ///
  /// In tr, this message translates to:
  /// **'Başka gün/saat ekle'**
  String get acadTimeAddSession;

  /// No description provided for @acadTimeNote.
  ///
  /// In tr, this message translates to:
  /// **'Not'**
  String get acadTimeNote;

  /// No description provided for @acadTimeNoteHint.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı (örn. laptop getir)'**
  String get acadTimeNoteHint;

  /// No description provided for @acadTimeSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get acadTimeSave;

  /// No description provided for @acadTimeAddCourseBtn.
  ///
  /// In tr, this message translates to:
  /// **'Dersi ekle'**
  String get acadTimeAddCourseBtn;

  /// No description provided for @acadTimeSessionN.
  ///
  /// In tr, this message translates to:
  /// **'{n}. oturum'**
  String acadTimeSessionN(String n);

  /// No description provided for @acadTimeRemoveSession.
  ///
  /// In tr, this message translates to:
  /// **'Oturumu kaldır'**
  String get acadTimeRemoveSession;

  /// No description provided for @acadTimeStartTime.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç saati'**
  String get acadTimeStartTime;

  /// No description provided for @acadTimeEndTime.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş saati'**
  String get acadTimeEndTime;

  /// No description provided for @acadTimeRoomHint.
  ///
  /// In tr, this message translates to:
  /// **'Derslik (örn. B-204)'**
  String get acadTimeRoomHint;

  /// No description provided for @acadTimeSemester.
  ///
  /// In tr, this message translates to:
  /// **'Dönem'**
  String get acadTimeSemester;

  /// No description provided for @acadTimeNoSemester.
  ///
  /// In tr, this message translates to:
  /// **'Henüz dönem yok. Bir dönem ekleyerek derslerini düzenleyebilirsin.'**
  String get acadTimeNoSemester;

  /// No description provided for @acadTimeAddSemester.
  ///
  /// In tr, this message translates to:
  /// **'Yeni dönem ekle'**
  String get acadTimeAddSemester;

  /// No description provided for @acadTimeOfficial.
  ///
  /// In tr, this message translates to:
  /// **'{name} (akademik takvimden)'**
  String acadTimeOfficial(String name);

  /// No description provided for @acadTimeOfficialDefault.
  ///
  /// In tr, this message translates to:
  /// **'Resmi dönem'**
  String get acadTimeOfficialDefault;

  /// No description provided for @acadTimeClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get acadTimeClose;

  /// No description provided for @acadTimeCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Güncel'**
  String get acadTimeCurrent;

  /// No description provided for @acadTimeMakeCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Güncel dönem yap'**
  String get acadTimeMakeCurrent;

  /// No description provided for @acadTimeDeleteSemester.
  ///
  /// In tr, this message translates to:
  /// **'Dönemi sil'**
  String get acadTimeDeleteSemester;

  /// No description provided for @acadTimeDeleteSemesterText.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" silinecek. Dersler dönemsiz kalır.'**
  String acadTimeDeleteSemesterText(String name);

  /// No description provided for @acadTimeNewSemester.
  ///
  /// In tr, this message translates to:
  /// **'Yeni dönem'**
  String get acadTimeNewSemester;

  /// No description provided for @acadTimeSemesterHint.
  ///
  /// In tr, this message translates to:
  /// **'2026-2027 Güz'**
  String get acadTimeSemesterHint;

  /// No description provided for @acadTimeStartDate.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç tarihi'**
  String get acadTimeStartDate;

  /// No description provided for @acadTimeEndDate.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş tarihi'**
  String get acadTimeEndDate;

  /// No description provided for @acadTimeCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get acadTimeCancel;

  /// No description provided for @acadTimeSemesterNeedAll.
  ///
  /// In tr, this message translates to:
  /// **'Ad ve iki tarih de gerekli.'**
  String get acadTimeSemesterNeedAll;

  /// No description provided for @acadTimeSemesterEndAfter.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş tarihi başlangıçtan sonra olmalı.'**
  String get acadTimeSemesterEndAfter;

  /// No description provided for @acadTimeAdd.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get acadTimeAdd;

  /// No description provided for @acadTimeRemindersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatmalar'**
  String get acadTimeRemindersTitle;

  /// No description provided for @acadTimeRemindersIntro.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler cihazında zamanlanır; internet gerekmez. Ders programın veya sınavların değişince yenilenir.'**
  String get acadTimeRemindersIntro;

  /// No description provided for @acadTimeClassReminder.
  ///
  /// In tr, this message translates to:
  /// **'Ders hatırlatması'**
  String get acadTimeClassReminder;

  /// No description provided for @acadTimeBeforeClass.
  ///
  /// In tr, this message translates to:
  /// **'Ders başlamadan önce'**
  String get acadTimeBeforeClass;

  /// No description provided for @acadTimeOneHour.
  ///
  /// In tr, this message translates to:
  /// **'1 saat'**
  String get acadTimeOneHour;

  /// No description provided for @acadTimeMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{m} dk'**
  String acadTimeMinutes(String m);

  /// No description provided for @acadTimeExamReminders.
  ///
  /// In tr, this message translates to:
  /// **'Sınav hatırlatmaları'**
  String get acadTimeExamReminders;

  /// No description provided for @acadTimeDayBefore.
  ///
  /// In tr, this message translates to:
  /// **'1 gün önce'**
  String get acadTimeDayBefore;

  /// No description provided for @acadTimeHourBefore.
  ///
  /// In tr, this message translates to:
  /// **'1 saat önce'**
  String get acadTimeHourBefore;

  /// No description provided for @authRestEnterCode.
  ///
  /// In tr, this message translates to:
  /// **'6 haneli kodu girin.'**
  String get authRestEnterCode;

  /// No description provided for @authRestCodeLabel.
  ///
  /// In tr, this message translates to:
  /// **'6 haneli doğrulama kodu'**
  String get authRestCodeLabel;

  /// No description provided for @chatDetailVideoPreparing.
  ///
  /// In tr, this message translates to:
  /// **'Video hazırlanıyor… %{pct}'**
  String chatDetailVideoPreparing(String pct);

  /// No description provided for @chatDetailCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get chatDetailCancel;

  /// No description provided for @chatDetailUserFallback.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get chatDetailUserFallback;

  /// No description provided for @chatDetailYou.
  ///
  /// In tr, this message translates to:
  /// **'Sen'**
  String get chatDetailYou;

  /// No description provided for @chatDetailChatFallback.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get chatDetailChatFallback;

  /// No description provided for @chatDetailGroupFallback.
  ///
  /// In tr, this message translates to:
  /// **'Grup'**
  String get chatDetailGroupFallback;

  /// No description provided for @chatDetailVideoTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Video en fazla 60 saniye olabilir'**
  String get chatDetailVideoTooLong;

  /// No description provided for @chatDetailVideoTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Video çok büyük, daha kısa bir video seçin'**
  String get chatDetailVideoTooLarge;

  /// No description provided for @chatDetailVideoUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda video gönderilemiyor.'**
  String get chatDetailVideoUnsupported;

  /// No description provided for @chatDetailVideoFailed.
  ///
  /// In tr, this message translates to:
  /// **'Video hazırlanamadı.'**
  String get chatDetailVideoFailed;

  /// No description provided for @chatDetailVideosSplit.
  ///
  /// In tr, this message translates to:
  /// **'Videolar büyük olduğu için birden fazla mesaj olarak gönderilecek'**
  String get chatDetailVideosSplit;

  /// No description provided for @chatDetailImageTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Görsel çok büyük, daha küçük bir görsel seçin.'**
  String get chatDetailImageTooLarge;

  /// No description provided for @chatDetailImageTypes.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca JPEG, PNG veya WebP görseller gönderilebilir.'**
  String get chatDetailImageTypes;

  /// No description provided for @chatDetailImageUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel okunamadı.'**
  String get chatDetailImageUnreadable;

  /// No description provided for @chatDetailVideoUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Video okunamadı.'**
  String get chatDetailVideoUnreadable;

  /// No description provided for @chatDetailSavedToGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriye kaydedildi'**
  String get chatDetailSavedToGallery;

  /// No description provided for @chatDetailDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj silinsin mi?'**
  String get chatDetailDeleteTitle;

  /// No description provided for @chatDetailDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu mesaj herkes için silinir.'**
  String get chatDetailDeleteBody;

  /// No description provided for @chatDetailDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get chatDetailDelete;

  /// No description provided for @chatDetailMsgDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Bu mesaj silindi'**
  String get chatDetailMsgDeleted;

  /// No description provided for @chatDetailNevermind.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get chatDetailNevermind;

  /// No description provided for @chatDetailToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get chatDetailToday;

  /// No description provided for @chatDetailYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get chatDetailYesterday;

  /// No description provided for @chatDetailMonth1.
  ///
  /// In tr, this message translates to:
  /// **'Ocak'**
  String get chatDetailMonth1;

  /// No description provided for @chatDetailMonth2.
  ///
  /// In tr, this message translates to:
  /// **'Şubat'**
  String get chatDetailMonth2;

  /// No description provided for @chatDetailMonth3.
  ///
  /// In tr, this message translates to:
  /// **'Mart'**
  String get chatDetailMonth3;

  /// No description provided for @chatDetailMonth4.
  ///
  /// In tr, this message translates to:
  /// **'Nisan'**
  String get chatDetailMonth4;

  /// No description provided for @chatDetailMonth5.
  ///
  /// In tr, this message translates to:
  /// **'Mayıs'**
  String get chatDetailMonth5;

  /// No description provided for @chatDetailMonth6.
  ///
  /// In tr, this message translates to:
  /// **'Haziran'**
  String get chatDetailMonth6;

  /// No description provided for @chatDetailMonth7.
  ///
  /// In tr, this message translates to:
  /// **'Temmuz'**
  String get chatDetailMonth7;

  /// No description provided for @chatDetailMonth8.
  ///
  /// In tr, this message translates to:
  /// **'Ağustos'**
  String get chatDetailMonth8;

  /// No description provided for @chatDetailMonth9.
  ///
  /// In tr, this message translates to:
  /// **'Eylül'**
  String get chatDetailMonth9;

  /// No description provided for @chatDetailMonth10.
  ///
  /// In tr, this message translates to:
  /// **'Ekim'**
  String get chatDetailMonth10;

  /// No description provided for @chatDetailMonth11.
  ///
  /// In tr, this message translates to:
  /// **'Kasım'**
  String get chatDetailMonth11;

  /// No description provided for @chatDetailMonth12.
  ///
  /// In tr, this message translates to:
  /// **'Aralık'**
  String get chatDetailMonth12;

  /// No description provided for @chatDetailOnline.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimiçi'**
  String get chatDetailOnline;

  /// No description provided for @chatDetailLastSeenToday.
  ///
  /// In tr, this message translates to:
  /// **'Son görülme: bugün {time}'**
  String chatDetailLastSeenToday(String time);

  /// No description provided for @chatDetailLastSeenYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Son görülme: dün {time}'**
  String chatDetailLastSeenYesterday(String time);

  /// No description provided for @chatDetailLastSeenOn.
  ///
  /// In tr, this message translates to:
  /// **'Son görülme: {date}'**
  String chatDetailLastSeenOn(String date);

  /// No description provided for @chatDetailClubRoomMembers.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp odası · {count} üye'**
  String chatDetailClubRoomMembers(String count);

  /// No description provided for @chatDetailEventRoomMembers.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik odası · {count} üye'**
  String chatDetailEventRoomMembers(String count);

  /// No description provided for @chatDetailMembersCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String chatDetailMembersCount(String count);

  /// No description provided for @chatDetailClubEventRoom.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp/etkinlik odası'**
  String get chatDetailClubEventRoom;

  /// No description provided for @chatDetailResend.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden gönder'**
  String get chatDetailResend;

  /// No description provided for @chatDetailReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtla'**
  String get chatDetailReply;

  /// No description provided for @chatDetailCopy.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get chatDetailCopy;

  /// No description provided for @chatDetailForward.
  ///
  /// In tr, this message translates to:
  /// **'İlet'**
  String get chatDetailForward;

  /// No description provided for @chatDetailEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get chatDetailEdit;

  /// No description provided for @chatDetailDeleteForAll.
  ///
  /// In tr, this message translates to:
  /// **'Herkesten sil'**
  String get chatDetailDeleteForAll;

  /// No description provided for @chatDetailDeleteMessage.
  ///
  /// In tr, this message translates to:
  /// **'Mesajı sil'**
  String get chatDetailDeleteMessage;

  /// No description provided for @chatDetailReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get chatDetailReport;

  /// No description provided for @chatDetailCopied.
  ///
  /// In tr, this message translates to:
  /// **'Kopyalandı'**
  String get chatDetailCopied;

  /// No description provided for @chatDetailForwarded.
  ///
  /// In tr, this message translates to:
  /// **'İletildi'**
  String get chatDetailForwarded;

  /// No description provided for @chatDetailForwardFailedAll.
  ///
  /// In tr, this message translates to:
  /// **'İletilemedi'**
  String get chatDetailForwardFailedAll;

  /// No description provided for @chatDetailForwardFailedSome.
  ///
  /// In tr, this message translates to:
  /// **'{count} sohbete iletilemedi'**
  String chatDetailForwardFailedSome(String count);

  /// No description provided for @chatDetailSearchInChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbette ara'**
  String get chatDetailSearchInChat;

  /// No description provided for @chatDetailClubPage.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sayfası'**
  String get chatDetailClubPage;

  /// No description provided for @chatDetailEventPage.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sayfası'**
  String get chatDetailEventPage;

  /// No description provided for @chatDetailMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler'**
  String get chatDetailMembers;

  /// No description provided for @chatDetailMedia.
  ///
  /// In tr, this message translates to:
  /// **'Medya'**
  String get chatDetailMedia;

  /// No description provided for @chatDetailSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get chatDetailSettings;

  /// No description provided for @chatDetailLeaveChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetten ayrıl'**
  String get chatDetailLeaveChat;

  /// No description provided for @chatDetailBlock.
  ///
  /// In tr, this message translates to:
  /// **'Engelle'**
  String get chatDetailBlock;

  /// No description provided for @chatDetailUnblock.
  ///
  /// In tr, this message translates to:
  /// **'Engeli kaldır'**
  String get chatDetailUnblock;

  /// No description provided for @chatDetailReportUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcıyı şikâyet et'**
  String get chatDetailReportUser;

  /// No description provided for @chatDetailLeaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetten ayrılınsın mı?'**
  String get chatDetailLeaveTitle;

  /// No description provided for @chatDetailLeaveBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbetten ayrılırsınız.'**
  String get chatDetailLeaveBody;

  /// No description provided for @chatDetailLeave.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get chatDetailLeave;

  /// No description provided for @chatDetailBlockTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellensin mi?'**
  String get chatDetailBlockTitle;

  /// No description provided for @chatDetailBlockBody.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğiniz kişiyle mesajlaşamazsınız.'**
  String get chatDetailBlockBody;

  /// No description provided for @chatDetailUserBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellendi'**
  String get chatDetailUserBlocked;

  /// No description provided for @chatDetailUserUnblocked.
  ///
  /// In tr, this message translates to:
  /// **'Engel kaldırıldı'**
  String get chatDetailUserUnblocked;

  /// No description provided for @chatDetailMembersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler ({count})'**
  String chatDetailMembersTitle(String count);

  /// No description provided for @chatDetailMembersLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Üye listesi alınamadı.'**
  String get chatDetailMembersLoadFailed;

  /// No description provided for @chatDetailAdmin.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get chatDetailAdmin;

  /// No description provided for @chatDetailBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get chatDetailBack;

  /// No description provided for @chatDetailOpenProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profili aç'**
  String get chatDetailOpenProfile;

  /// No description provided for @chatDetailChatInfo.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet bilgisi'**
  String get chatDetailChatInfo;

  /// No description provided for @chatDetailTyping.
  ///
  /// In tr, this message translates to:
  /// **'yazıyor…'**
  String get chatDetailTyping;

  /// No description provided for @chatDetailMenu.
  ///
  /// In tr, this message translates to:
  /// **'Menü'**
  String get chatDetailMenu;

  /// No description provided for @chatDetailCloseSearch.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı kapat'**
  String get chatDetailCloseSearch;

  /// No description provided for @chatDetailTypeToSearch.
  ///
  /// In tr, this message translates to:
  /// **'Aramak için yazın'**
  String get chatDetailTypeToSearch;

  /// No description provided for @chatDetailNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşme yok'**
  String get chatDetailNoMatch;

  /// No description provided for @chatDetailPrevMatch.
  ///
  /// In tr, this message translates to:
  /// **'Önceki eşleşme'**
  String get chatDetailPrevMatch;

  /// No description provided for @chatDetailNextMatch.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki eşleşme'**
  String get chatDetailNextMatch;

  /// No description provided for @chatDetailSearching.
  ///
  /// In tr, this message translates to:
  /// **'Aranıyor…'**
  String get chatDetailSearching;

  /// No description provided for @chatDetailSearchOlder.
  ///
  /// In tr, this message translates to:
  /// **'Daha eski mesajlarda ara'**
  String get chatDetailSearchOlder;

  /// No description provided for @chatDetailEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mesaj yok. İlk mesajı sen yaz.'**
  String get chatDetailEmpty;

  /// No description provided for @chatDetailScrollDown.
  ///
  /// In tr, this message translates to:
  /// **'En alta in'**
  String get chatDetailScrollDown;

  /// No description provided for @chatDetailScrollDownNew.
  ///
  /// In tr, this message translates to:
  /// **'En alta in, {count} yeni mesaj'**
  String chatDetailScrollDownNew(String count);

  /// No description provided for @chatDetailEditing.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj düzenleniyor'**
  String get chatDetailEditing;

  /// No description provided for @chatDetailAdd.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get chatDetailAdd;

  /// No description provided for @chatDetailWriteMessage.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj yaz'**
  String get chatDetailWriteMessage;

  /// No description provided for @chatDetailCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get chatDetailCamera;

  /// No description provided for @chatDetailSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get chatDetailSave;

  /// No description provided for @chatDetailSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get chatDetailSend;

  /// No description provided for @chatDetailClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get chatDetailClose;

  /// No description provided for @chatDetailReactionLabel.
  ///
  /// In tr, this message translates to:
  /// **'Tepki {emoji}'**
  String chatDetailReactionLabel(String emoji);

  /// No description provided for @chatInfoUnmute.
  ///
  /// In tr, this message translates to:
  /// **'Sesi aç'**
  String get chatInfoUnmute;

  /// No description provided for @chatInfoMute.
  ///
  /// In tr, this message translates to:
  /// **'Sessize al'**
  String get chatInfoMute;

  /// No description provided for @chatInfoUnarchive.
  ///
  /// In tr, this message translates to:
  /// **'Arşivden çıkar'**
  String get chatInfoUnarchive;

  /// No description provided for @chatInfoArchive.
  ///
  /// In tr, this message translates to:
  /// **'Arşivle'**
  String get chatInfoArchive;

  /// No description provided for @chatInfoDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get chatInfoDelete;

  /// No description provided for @chatInfoCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get chatInfoCancel;

  /// No description provided for @chatInfoSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get chatInfoSave;

  /// No description provided for @chatInfoMute8h.
  ///
  /// In tr, this message translates to:
  /// **'8 saat'**
  String get chatInfoMute8h;

  /// No description provided for @chatInfoMute1w.
  ///
  /// In tr, this message translates to:
  /// **'1 hafta'**
  String get chatInfoMute1w;

  /// No description provided for @chatInfoMuteForever.
  ///
  /// In tr, this message translates to:
  /// **'Her zaman'**
  String get chatInfoMuteForever;

  /// No description provided for @chatInfoDeleteConvTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet silinsin mi?'**
  String get chatInfoDeleteConvTitle;

  /// No description provided for @chatInfoDeleteConvGroup.
  ///
  /// In tr, this message translates to:
  /// **'Gruptan çıkıp bu sohbeti sileceksin.'**
  String get chatInfoDeleteConvGroup;

  /// No description provided for @chatInfoDeleteConvDirect.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbet yalnızca senin için silinecek. Karşı taraf etkilenmez.'**
  String get chatInfoDeleteConvDirect;

  /// No description provided for @chatInfoUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get chatInfoUser;

  /// No description provided for @chatInfoYou.
  ///
  /// In tr, this message translates to:
  /// **'Sen'**
  String get chatInfoYou;

  /// No description provided for @chatInfoAdmin.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get chatInfoAdmin;

  /// No description provided for @chatInfoRemoveFromGroup.
  ///
  /// In tr, this message translates to:
  /// **'Gruptan çıkar'**
  String get chatInfoRemoveFromGroup;

  /// No description provided for @chatInfoMembersCount.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler ({n})'**
  String chatInfoMembersCount(String n);

  /// No description provided for @chatInfoSearchMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye ara'**
  String get chatInfoSearchMember;

  /// No description provided for @chatInfoNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç yok.'**
  String get chatInfoNoResults;

  /// No description provided for @chatInfoOpenVideo.
  ///
  /// In tr, this message translates to:
  /// **'Videoyu aç'**
  String get chatInfoOpenVideo;

  /// No description provided for @chatInfoOpenImage.
  ///
  /// In tr, this message translates to:
  /// **'Görseli aç'**
  String get chatInfoOpenImage;

  /// No description provided for @chatInfoMedia.
  ///
  /// In tr, this message translates to:
  /// **'Medya'**
  String get chatInfoMedia;

  /// No description provided for @chatInfoRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get chatInfoRetry;

  /// No description provided for @chatInfoChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get chatInfoChat;

  /// No description provided for @chatInfoGroup.
  ///
  /// In tr, this message translates to:
  /// **'Grup'**
  String get chatInfoGroup;

  /// No description provided for @chatInfoUnmuted.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimlerin sesi açıldı'**
  String get chatInfoUnmuted;

  /// No description provided for @chatInfoMuted.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet sessize alındı'**
  String get chatInfoMuted;

  /// No description provided for @chatInfoUnarchived.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet arşivden çıkarıldı'**
  String get chatInfoUnarchived;

  /// No description provided for @chatInfoArchived.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet arşivlendi'**
  String get chatInfoArchived;

  /// No description provided for @chatInfoLeaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetten ayrılınsın mı?'**
  String get chatInfoLeaveTitle;

  /// No description provided for @chatInfoLeaveBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbetten ayrılırsınız.'**
  String get chatInfoLeaveBody;

  /// No description provided for @chatInfoLeave.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get chatInfoLeave;

  /// No description provided for @chatInfoUnblocked.
  ///
  /// In tr, this message translates to:
  /// **'Engel kaldırıldı'**
  String get chatInfoUnblocked;

  /// No description provided for @chatInfoBlockTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellensin mi?'**
  String get chatInfoBlockTitle;

  /// No description provided for @chatInfoBlockBody.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğiniz kişiyle mesajlaşamazsınız.'**
  String get chatInfoBlockBody;

  /// No description provided for @chatInfoBlock.
  ///
  /// In tr, this message translates to:
  /// **'Engelle'**
  String get chatInfoBlock;

  /// No description provided for @chatInfoBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellendi'**
  String get chatInfoBlocked;

  /// No description provided for @chatInfoUnblock.
  ///
  /// In tr, this message translates to:
  /// **'Engeli kaldır'**
  String get chatInfoUnblock;

  /// No description provided for @chatInfoReportUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcıyı şikâyet et'**
  String get chatInfoReportUser;

  /// No description provided for @chatInfoReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get chatInfoReport;

  /// No description provided for @chatInfoRemoveMemberTitle.
  ///
  /// In tr, this message translates to:
  /// **'Üye çıkarılsın mı?'**
  String get chatInfoRemoveMemberTitle;

  /// No description provided for @chatInfoRemoveMemberBody.
  ///
  /// In tr, this message translates to:
  /// **'{name} gruptan çıkarılır.'**
  String chatInfoRemoveMemberBody(String name);

  /// No description provided for @chatInfoRemove.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get chatInfoRemove;

  /// No description provided for @chatInfoPickGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get chatInfoPickGallery;

  /// No description provided for @chatInfoRemovePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get chatInfoRemovePhoto;

  /// No description provided for @chatInfoImageTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Görsel çok büyük, daha küçük bir görsel seçin.'**
  String get chatInfoImageTooLarge;

  /// No description provided for @chatInfoImageTypeOnly.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca JPEG, PNG veya WebP görseller kullanılabilir.'**
  String get chatInfoImageTypeOnly;

  /// No description provided for @chatInfoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet bilgisi'**
  String get chatInfoTitle;

  /// No description provided for @chatInfoNoMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üye listesi yok.'**
  String get chatInfoNoMembers;

  /// No description provided for @chatInfoClubRoom.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp odası'**
  String get chatInfoClubRoom;

  /// No description provided for @chatInfoEventRoom.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik odası'**
  String get chatInfoEventRoom;

  /// No description provided for @chatInfoMemberCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} üye'**
  String chatInfoMemberCount(String n);

  /// No description provided for @chatInfoChangePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı değiştir'**
  String get chatInfoChangePhoto;

  /// No description provided for @chatInfoEditName.
  ///
  /// In tr, this message translates to:
  /// **'Adı düzenle'**
  String get chatInfoEditName;

  /// No description provided for @chatInfoClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get chatInfoClub;

  /// No description provided for @chatInfoEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get chatInfoEvent;

  /// No description provided for @chatInfoSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get chatInfoSearch;

  /// No description provided for @chatInfoMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler'**
  String get chatInfoMembers;

  /// No description provided for @chatInfoMembersDot.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler · {n}'**
  String chatInfoMembersDot(String n);

  /// No description provided for @chatInfoNoMedia.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbette henüz görsel yok.'**
  String get chatInfoNoMedia;

  /// No description provided for @chatInfoSeeAllMedia.
  ///
  /// In tr, this message translates to:
  /// **'Tüm medyayı gör'**
  String get chatInfoSeeAllMedia;

  /// No description provided for @chatInfoMediaDot.
  ///
  /// In tr, this message translates to:
  /// **'Medya · {count}'**
  String chatInfoMediaDot(String count);

  /// No description provided for @chatInfoAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get chatInfoAll;

  /// No description provided for @chatInfoMuteOn.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get chatInfoMuteOn;

  /// No description provided for @chatInfoMutedAlways.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz · her zaman'**
  String get chatInfoMutedAlways;

  /// No description provided for @chatInfoMutedDays.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz · {n} gün sonra açılır'**
  String chatInfoMutedDays(String n);

  /// No description provided for @chatInfoMutedHours.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz · {n} saat sonra açılır'**
  String chatInfoMutedHours(String n);

  /// No description provided for @chatInfoMutedSoon.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz · birazdan açılır'**
  String get chatInfoMutedSoon;

  /// No description provided for @chatInfoMutedLabel.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz'**
  String get chatInfoMutedLabel;

  /// No description provided for @chatInfoOpenClubPage.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sayfasını aç'**
  String get chatInfoOpenClubPage;

  /// No description provided for @chatInfoOpenEventPage.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sayfasını aç'**
  String get chatInfoOpenEventPage;

  /// No description provided for @chatInfoViewProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profili görüntüle'**
  String get chatInfoViewProfile;

  /// No description provided for @chatInfoMuteNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimleri sessize al'**
  String get chatInfoMuteNotifications;

  /// No description provided for @chatInfoClosed.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbet kapalı'**
  String get chatInfoClosed;

  /// No description provided for @chatInfoClosedSub.
  ///
  /// In tr, this message translates to:
  /// **'Yeni mesaj gönderilemez'**
  String get chatInfoClosedSub;

  /// No description provided for @chatInfoLeaveChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetten çık'**
  String get chatInfoLeaveChat;

  /// No description provided for @chatInfoSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get chatInfoSettings;

  /// No description provided for @chatInfoGroupName.
  ///
  /// In tr, this message translates to:
  /// **'Grup adı'**
  String get chatInfoGroupName;

  /// No description provided for @chatMiscFilterAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get chatMiscFilterAll;

  /// No description provided for @chatMiscFilterPeople.
  ///
  /// In tr, this message translates to:
  /// **'Kişiler'**
  String get chatMiscFilterPeople;

  /// No description provided for @chatMiscFilterClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpler'**
  String get chatMiscFilterClubs;

  /// No description provided for @chatMiscFilterEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get chatMiscFilterEvents;

  /// No description provided for @chatMiscArchived.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet arşivlendi'**
  String get chatMiscArchived;

  /// No description provided for @chatMiscUnarchived.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet arşivden çıkarıldı'**
  String get chatMiscUnarchived;

  /// No description provided for @chatMiscChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get chatMiscChat;

  /// No description provided for @chatMiscArchive.
  ///
  /// In tr, this message translates to:
  /// **'Arşiv'**
  String get chatMiscArchive;

  /// No description provided for @chatMiscNewChat.
  ///
  /// In tr, this message translates to:
  /// **'Yeni sohbet'**
  String get chatMiscNewChat;

  /// No description provided for @chatMiscEmptyArchive.
  ///
  /// In tr, this message translates to:
  /// **'Arşivde sohbet yok'**
  String get chatMiscEmptyArchive;

  /// No description provided for @chatMiscEmptyNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen sohbet bulunamadı'**
  String get chatMiscEmptyNoMatch;

  /// No description provided for @chatMiscEmptyNone.
  ///
  /// In tr, this message translates to:
  /// **'Henüz sohbetiniz yok'**
  String get chatMiscEmptyNone;

  /// No description provided for @chatMiscUnarchiveAction.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get chatMiscUnarchiveAction;

  /// No description provided for @chatMiscArchiveAction.
  ///
  /// In tr, this message translates to:
  /// **'Arşivle'**
  String get chatMiscArchiveAction;

  /// No description provided for @chatMiscSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişi veya grup ara'**
  String get chatMiscSearchHint;

  /// No description provided for @chatMiscTagClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get chatMiscTagClub;

  /// No description provided for @chatMiscTagEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get chatMiscTagEvent;

  /// No description provided for @chatMiscMessageDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj silindi'**
  String get chatMiscMessageDeleted;

  /// No description provided for @chatMiscOnceText.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf (tek gösterimlik)'**
  String get chatMiscOnceText;

  /// No description provided for @chatMiscImage.
  ///
  /// In tr, this message translates to:
  /// **'Görsel'**
  String get chatMiscImage;

  /// No description provided for @chatMiscDayMon.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get chatMiscDayMon;

  /// No description provided for @chatMiscDayTue.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get chatMiscDayTue;

  /// No description provided for @chatMiscDayWed.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get chatMiscDayWed;

  /// No description provided for @chatMiscDayThu.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get chatMiscDayThu;

  /// No description provided for @chatMiscDayFri.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get chatMiscDayFri;

  /// No description provided for @chatMiscDaySat.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get chatMiscDaySat;

  /// No description provided for @chatMiscDaySun.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get chatMiscDaySun;

  /// No description provided for @chatMiscYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get chatMiscYesterday;

  /// No description provided for @chatMiscSendFailedRetry.
  ///
  /// In tr, this message translates to:
  /// **'{error} · Yeniden dene'**
  String chatMiscSendFailedRetry(String error);

  /// No description provided for @chatMiscSendFailed.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi'**
  String get chatMiscSendFailed;

  /// No description provided for @chatMiscThisMessageDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Bu mesaj silindi'**
  String get chatMiscThisMessageDeleted;

  /// No description provided for @chatMiscVideo.
  ///
  /// In tr, this message translates to:
  /// **'Video'**
  String get chatMiscVideo;

  /// No description provided for @chatMiscPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get chatMiscPhoto;

  /// No description provided for @chatMiscUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get chatMiscUser;

  /// No description provided for @chatMiscStatusSending.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor'**
  String get chatMiscStatusSending;

  /// No description provided for @chatMiscStatusSent.
  ///
  /// In tr, this message translates to:
  /// **'Gönderildi'**
  String get chatMiscStatusSent;

  /// No description provided for @chatMiscStatusDelivered.
  ///
  /// In tr, this message translates to:
  /// **'İletildi'**
  String get chatMiscStatusDelivered;

  /// No description provided for @chatMiscStatusRead.
  ///
  /// In tr, this message translates to:
  /// **'Okundu'**
  String get chatMiscStatusRead;

  /// No description provided for @chatMiscImageUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel kullanılamıyor'**
  String get chatMiscImageUnavailable;

  /// No description provided for @chatMiscVideoWithDuration.
  ///
  /// In tr, this message translates to:
  /// **'Video, {duration}'**
  String chatMiscVideoWithDuration(String duration);

  /// No description provided for @chatMiscClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get chatMiscClose;

  /// No description provided for @chatMiscImageLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel yüklenemedi.'**
  String get chatMiscImageLoadFailed;

  /// No description provided for @chatMiscOnceOpened.
  ///
  /// In tr, this message translates to:
  /// **'Açıldı'**
  String get chatMiscOnceOpened;

  /// No description provided for @chatMiscOnceSending.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf · Gönderiliyor'**
  String get chatMiscOnceSending;

  /// No description provided for @chatMiscOnceSent.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf · Gönderildi'**
  String get chatMiscOnceSent;

  /// No description provided for @chatMiscOnceTapToOpen.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf · Açmak için dokun'**
  String get chatMiscOnceTapToOpen;

  /// No description provided for @chatMiscOnceSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Tek gösterimlik fotoğraf. {label}'**
  String chatMiscOnceSemantics(String label);

  /// No description provided for @chatMiscEdited.
  ///
  /// In tr, this message translates to:
  /// **'düzenlendi'**
  String get chatMiscEdited;

  /// No description provided for @chatMiscContactsFind.
  ///
  /// In tr, this message translates to:
  /// **'Rehberden kişi bul'**
  String get chatMiscContactsFind;

  /// No description provided for @chatMiscContactsRationale.
  ///
  /// In tr, this message translates to:
  /// **'Rehberinizdeki Bingöl Üniversitesi kişilerini bulabilmemiz için rehbere erişmemiz gerekir. Rehberiniz sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir.'**
  String get chatMiscContactsRationale;

  /// No description provided for @chatMiscContactsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Bingöl Üniversitesi kişileri'**
  String get chatMiscContactsSubtitle;

  /// No description provided for @chatMiscContactsPermTitle.
  ///
  /// In tr, this message translates to:
  /// **'Rehber izni gerekli'**
  String get chatMiscContactsPermTitle;

  /// No description provided for @chatMiscContactsPermText.
  ///
  /// In tr, this message translates to:
  /// **'Rehberinizdeki kampüs kişilerini bulabilmemiz için rehbere erişim izni vermeniz gerekir.'**
  String get chatMiscContactsPermText;

  /// No description provided for @chatMiscContactsPermAction.
  ///
  /// In tr, this message translates to:
  /// **'İzin ver'**
  String get chatMiscContactsPermAction;

  /// No description provided for @chatMiscContactsNoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen kişi yok'**
  String get chatMiscContactsNoneTitle;

  /// No description provided for @chatMiscContactsNoneText.
  ///
  /// In tr, this message translates to:
  /// **'Rehberindeki kişilerden Bingöl Üniversitesi e-postasıyla uygulamayı kullanan kimse bulunamadı. Arkadaşların katıldıkça burada görünür.'**
  String get chatMiscContactsNoneText;

  /// No description provided for @chatMiscContactsSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Kişilerde ara'**
  String get chatMiscContactsSearchHint;

  /// No description provided for @chatMiscContactsTruncated.
  ///
  /// In tr, this message translates to:
  /// **'Saatlik istek sınırına ulaşıldı; kalan kişiler daha sonra eşleştirilecek.'**
  String get chatMiscContactsTruncated;

  /// No description provided for @chatMiscContactsNoSearchMatch.
  ///
  /// In tr, this message translates to:
  /// **'Aramanla eşleşen kişi yok.'**
  String get chatMiscContactsNoSearchMatch;

  /// No description provided for @chatMiscContactsCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} KİŞİ'**
  String chatMiscContactsCount(String n);

  /// No description provided for @chatMiscMessage.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj'**
  String get chatMiscMessage;

  /// No description provided for @chatMiscContactsPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Rehberin sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir.'**
  String get chatMiscContactsPrivacy;

  /// No description provided for @chatMiscGroupMax.
  ///
  /// In tr, this message translates to:
  /// **'Gruba en çok 50 kişi eklenebilir.'**
  String get chatMiscGroupMax;

  /// No description provided for @chatMiscGroupNameRequired.
  ///
  /// In tr, this message translates to:
  /// **'Grup adı girin.'**
  String get chatMiscGroupNameRequired;

  /// No description provided for @chatMiscUserSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ad veya e-posta ile ara'**
  String get chatMiscUserSearchHint;

  /// No description provided for @chatMiscCreateGroup.
  ///
  /// In tr, this message translates to:
  /// **'Grubu oluştur'**
  String get chatMiscCreateGroup;

  /// No description provided for @chatMiscStartChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet başlat'**
  String get chatMiscStartChat;

  /// No description provided for @chatMiscGroupCardTitle.
  ///
  /// In tr, this message translates to:
  /// **'Grup oluştur'**
  String get chatMiscGroupCardTitle;

  /// No description provided for @chatMiscSelectedCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} kişi seçildi'**
  String chatMiscSelectedCount(String n);

  /// No description provided for @chatMiscGroupName.
  ///
  /// In tr, this message translates to:
  /// **'Grup adı'**
  String get chatMiscGroupName;

  /// No description provided for @chatMiscMax50.
  ///
  /// In tr, this message translates to:
  /// **'en çok 50'**
  String get chatMiscMax50;

  /// No description provided for @chatMiscSearchMin.
  ///
  /// In tr, this message translates to:
  /// **'Kişi aramak için en az 2 karakter yazın.'**
  String get chatMiscSearchMin;

  /// No description provided for @chatMiscNoMatchPeople.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen kişi bulunamadı.'**
  String get chatMiscNoMatchPeople;

  /// No description provided for @chatMiscPeopleHeader.
  ///
  /// In tr, this message translates to:
  /// **'KİŞİLER'**
  String get chatMiscPeopleHeader;

  /// No description provided for @chatMiscForward.
  ///
  /// In tr, this message translates to:
  /// **'İlet'**
  String get chatMiscForward;

  /// No description provided for @chatMiscSearchChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet ara'**
  String get chatMiscSearchChat;

  /// No description provided for @chatMiscForwardMax.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {max} sohbet seçilebilir.'**
  String chatMiscForwardMax(String max);

  /// No description provided for @chatMiscSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get chatMiscSend;

  /// No description provided for @chatMiscSendCount.
  ///
  /// In tr, this message translates to:
  /// **'Gönder ({n})'**
  String chatMiscSendCount(String n);

  /// No description provided for @chatMiscChatNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet bulunamadı.'**
  String get chatMiscChatNotFound;

  /// No description provided for @chatMiscGalleryRationale.
  ///
  /// In tr, this message translates to:
  /// **'Galerindeki fotoğraf ve videoları gösterebilmemiz için erişim izni gerekir.'**
  String get chatMiscGalleryRationale;

  /// No description provided for @chatMiscVideoMax60.
  ///
  /// In tr, this message translates to:
  /// **'Video en fazla 60 saniye olabilir'**
  String get chatMiscVideoMax60;

  /// No description provided for @chatMiscPickMax.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {max} öğe seçebilirsin'**
  String chatMiscPickMax(String max);

  /// No description provided for @chatMiscAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get chatMiscAll;

  /// No description provided for @chatMiscGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeri'**
  String get chatMiscGallery;

  /// No description provided for @chatMiscLimitedNote.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca izin verdiğin öğeler görünüyor.'**
  String get chatMiscLimitedNote;

  /// No description provided for @chatMiscSelectMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla seç'**
  String get chatMiscSelectMore;

  /// No description provided for @chatMiscSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get chatMiscSettings;

  /// No description provided for @chatMiscGalleryDenied.
  ///
  /// In tr, this message translates to:
  /// **'Galeriye erişim izni verilmedi.'**
  String get chatMiscGalleryDenied;

  /// No description provided for @chatMiscOpenSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlardan aç'**
  String get chatMiscOpenSettings;

  /// No description provided for @chatMiscCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get chatMiscCamera;

  /// No description provided for @chatMiscPreviewCount.
  ///
  /// In tr, this message translates to:
  /// **'Önizle ({n})'**
  String chatMiscPreviewCount(String n);

  /// No description provided for @chatMiscCameraRationale.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf ve video çekebilmeniz için kameraya erişmemiz gerekir.'**
  String get chatMiscCameraRationale;

  /// No description provided for @chatMiscMicRationale.
  ///
  /// In tr, this message translates to:
  /// **'Video kaydederken sesi de alabilmemiz için mikrofona erişmemiz gerekir.'**
  String get chatMiscMicRationale;

  /// No description provided for @chatMiscPhotoFailed.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çekilemedi.'**
  String get chatMiscPhotoFailed;

  /// No description provided for @chatMiscVideoSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Video kaydedilemedi.'**
  String get chatMiscVideoSaveFailed;

  /// No description provided for @chatMiscCameraUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Kamera kullanılamıyor.'**
  String get chatMiscCameraUnavailable;

  /// No description provided for @chatMiscCameraHint.
  ///
  /// In tr, this message translates to:
  /// **'Dokun: fotoğraf · Basılı tut: video'**
  String get chatMiscCameraHint;

  /// No description provided for @chatMiscFlipCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamerayı çevir'**
  String get chatMiscFlipCamera;

  /// No description provided for @chatMiscOnceToast.
  ///
  /// In tr, this message translates to:
  /// **'Tek gönderimlik: alıcı yalnızca bir kez görebilir'**
  String get chatMiscOnceToast;

  /// No description provided for @chatMiscAddCaption.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama ekle…'**
  String get chatMiscAddCaption;

  /// No description provided for @chatMiscOnceSendLabel.
  ///
  /// In tr, this message translates to:
  /// **'Tek gönderimlik'**
  String get chatMiscOnceSendLabel;

  /// No description provided for @chatMiscOnceGone.
  ///
  /// In tr, this message translates to:
  /// **'Bu fotoğraf artık görüntülenemez.'**
  String get chatMiscOnceGone;

  /// No description provided for @chatMiscOnceOwn.
  ///
  /// In tr, this message translates to:
  /// **'Kendi gönderdiğiniz tek gösterimlik fotoğrafı açamazsınız.'**
  String get chatMiscOnceOwn;

  /// No description provided for @chatMiscOnceNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yüklenemedi. Bağlantınızı kontrol edin. Tek gösterimlik olduğu için yeniden açılamayabilir.'**
  String get chatMiscOnceNetwork;

  /// No description provided for @chatMiscOnceShowFailed.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf gösterilemedi. Tek gösterimlik olduğu için yeniden açılamayabilir.'**
  String get chatMiscOnceShowFailed;

  /// No description provided for @chatMiscOnceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tek gösterimlik'**
  String get chatMiscOnceTitle;

  /// No description provided for @chatMiscRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get chatMiscRetry;

  /// No description provided for @chatMiscSaveUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda desteklenmiyor.'**
  String get chatMiscSaveUnsupported;

  /// No description provided for @chatMiscSaveDenied.
  ///
  /// In tr, this message translates to:
  /// **'Galeri izni verilmedi.'**
  String get chatMiscSaveDenied;

  /// No description provided for @chatMiscSaveNoSpace.
  ///
  /// In tr, this message translates to:
  /// **'Cihazda yeterli alan yok.'**
  String get chatMiscSaveNoSpace;

  /// No description provided for @chatMiscImageSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel kaydedilemedi.'**
  String get chatMiscImageSaveFailed;

  /// No description provided for @chatMiscSavedToGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriye kaydedildi'**
  String get chatMiscSavedToGallery;

  /// No description provided for @chatMiscDownload.
  ///
  /// In tr, this message translates to:
  /// **'İndir'**
  String get chatMiscDownload;

  /// No description provided for @chatMiscPlayVideo.
  ///
  /// In tr, this message translates to:
  /// **'Videoyu oynat'**
  String get chatMiscPlayVideo;

  /// No description provided for @chatMiscVideoPlayFailed.
  ///
  /// In tr, this message translates to:
  /// **'Video oynatılamadı'**
  String get chatMiscVideoPlayFailed;

  /// No description provided for @clubWithdrawTitle.
  ///
  /// In tr, this message translates to:
  /// **'İsteği geri çek'**
  String get clubWithdrawTitle;

  /// No description provided for @clubWithdrawMessage.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteğiniz geri çekilsin mi?'**
  String get clubWithdrawMessage;

  /// No description provided for @clubWithdrawConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Geri çek'**
  String get clubWithdrawConfirm;

  /// No description provided for @clubImageTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Görsel çok büyük.'**
  String get clubImageTooLarge;

  /// No description provided for @clubImageUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.'**
  String get clubImageUnsupported;

  /// No description provided for @clubImageUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel okunamadı.'**
  String get clubImageUnreadable;

  /// No description provided for @clubImagePickFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel seçilemedi.'**
  String get clubImagePickFailed;

  /// No description provided for @clubImageUploadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel yüklenemedi.'**
  String get clubImageUploadFailed;

  /// No description provided for @clubDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp silindi.'**
  String get clubDeleted;

  /// No description provided for @clubChatClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sohbeti şu an kapalı.'**
  String get clubChatClosed;

  /// No description provided for @clubChatPreparing.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sohbeti hazırlanıyor, biraz sonra tekrar dene.'**
  String get clubChatPreparing;

  /// No description provided for @clubChat.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sohbeti'**
  String get clubChat;

  /// No description provided for @clubDeletePostTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi sil'**
  String get clubDeletePostTitle;

  /// No description provided for @clubDeletePostMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu gönderi kalıcı olarak silinsin mi?'**
  String get clubDeletePostMessage;

  /// No description provided for @clubCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get clubCancel;

  /// No description provided for @clubDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get clubDelete;

  /// No description provided for @clubReportClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulübü şikâyet et'**
  String get clubReportClub;

  /// No description provided for @clubReportPost.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi şikâyet et'**
  String get clubReportPost;

  /// No description provided for @clubMemberCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String clubMemberCount(String count);

  /// No description provided for @clubPrivate.
  ///
  /// In tr, this message translates to:
  /// **'Özel'**
  String get clubPrivate;

  /// No description provided for @clubPublic.
  ///
  /// In tr, this message translates to:
  /// **'Herkese açık'**
  String get clubPublic;

  /// No description provided for @clubTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get clubTitle;

  /// No description provided for @clubBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get clubBack;

  /// No description provided for @clubOptions.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp seçenekleri'**
  String get clubOptions;

  /// No description provided for @clubEdit.
  ///
  /// In tr, this message translates to:
  /// **'Kulübü düzenle'**
  String get clubEdit;

  /// No description provided for @clubRequestsWithCount.
  ///
  /// In tr, this message translates to:
  /// **'Başvurular ({count})'**
  String clubRequestsWithCount(String count);

  /// No description provided for @clubRequests.
  ///
  /// In tr, this message translates to:
  /// **'Başvurular'**
  String get clubRequests;

  /// No description provided for @clubManageMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üyeleri yönet'**
  String get clubManageMembers;

  /// No description provided for @clubChangeCover.
  ///
  /// In tr, this message translates to:
  /// **'Kapağı değiştir'**
  String get clubChangeCover;

  /// No description provided for @clubDeleteClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulübü sil'**
  String get clubDeleteClub;

  /// No description provided for @clubLeave.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpten ayrıl'**
  String get clubLeave;

  /// No description provided for @clubIsMember.
  ///
  /// In tr, this message translates to:
  /// **'Üyesin'**
  String get clubIsMember;

  /// No description provided for @clubRequestSent.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönderildi'**
  String get clubRequestSent;

  /// No description provided for @clubCannotJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katılamazsın'**
  String get clubCannotJoin;

  /// No description provided for @clubSendJoinRequest.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteği gönder'**
  String get clubSendJoinRequest;

  /// No description provided for @clubJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get clubJoin;

  /// No description provided for @clubTabPosts.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiler'**
  String get clubTabPosts;

  /// No description provided for @clubTabEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get clubTabEvents;

  /// No description provided for @clubTabMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler'**
  String get clubTabMembers;

  /// No description provided for @clubTabPolls.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get clubTabPolls;

  /// No description provided for @clubNoPosts.
  ///
  /// In tr, this message translates to:
  /// **'Henüz gönderi yok.'**
  String get clubNoPosts;

  /// No description provided for @clubNoEvents.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulübün yaklaşan etkinliği yok.'**
  String get clubNoEvents;

  /// No description provided for @clubNoMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üye bulunamadı.'**
  String get clubNoMembers;

  /// No description provided for @clubLoadFailedRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi, tekrar dene'**
  String get clubLoadFailedRetry;

  /// No description provided for @clubWriteHint.
  ///
  /// In tr, this message translates to:
  /// **'Kulübe bir şeyler yaz'**
  String get clubWriteHint;

  /// No description provided for @clubAddImage.
  ///
  /// In tr, this message translates to:
  /// **'Görsel ekle'**
  String get clubAddImage;

  /// No description provided for @clubShare.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get clubShare;

  /// No description provided for @clubRemoveImage.
  ///
  /// In tr, this message translates to:
  /// **'Görseli kaldır'**
  String get clubRemoveImage;

  /// No description provided for @clubPendingRequests.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen başvurular'**
  String get clubPendingRequests;

  /// No description provided for @clubPostActions.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi işlemleri'**
  String get clubPostActions;

  /// No description provided for @clubUnpin.
  ///
  /// In tr, this message translates to:
  /// **'Sabitlemeyi kaldır'**
  String get clubUnpin;

  /// No description provided for @clubPin.
  ///
  /// In tr, this message translates to:
  /// **'Sabitle'**
  String get clubPin;

  /// No description provided for @clubReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get clubReport;

  /// No description provided for @clubPinned.
  ///
  /// In tr, this message translates to:
  /// **'Sabit'**
  String get clubPinned;

  /// No description provided for @clubUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get clubUser;

  /// No description provided for @clubRoleOwner.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get clubRoleOwner;

  /// No description provided for @clubRoleModerator.
  ///
  /// In tr, this message translates to:
  /// **'Moderatör'**
  String get clubRoleModerator;

  /// No description provided for @clubDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler, etkinlikler ve sohbet silinir. Bu işlem geri alınamaz.'**
  String get clubDeleteBody;

  /// No description provided for @clubDeleteTypeName.
  ///
  /// In tr, this message translates to:
  /// **'Onaylamak için kulüp adını yaz: {name}'**
  String clubDeleteTypeName(String name);

  /// No description provided for @clubNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp adı'**
  String get clubNameHint;

  /// No description provided for @clubOwnerCannotLeave.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sahibi ayrılamaz. Önce sahipliği devret ya da kulübü sil.'**
  String get clubOwnerCannotLeave;

  /// No description provided for @clubCannotLeaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpten ayrılamazsın'**
  String get clubCannotLeaveTitle;

  /// No description provided for @clubOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get clubOk;

  /// No description provided for @clubThisClub.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulüp'**
  String get clubThisClub;

  /// No description provided for @clubLeaveMessage.
  ///
  /// In tr, this message translates to:
  /// **'{name} kulübünden ayrılmak istiyor musun? Kulüp sohbetinden de çıkarılacaksın ve sohbet listenden silinecek.'**
  String clubLeaveMessage(String name);

  /// No description provided for @clubLeaveConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get clubLeaveConfirm;

  /// No description provided for @clubMgmtJoinTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteği'**
  String get clubMgmtJoinTitle;

  /// No description provided for @clubMgmtJoinAdminsSee.
  ///
  /// In tr, this message translates to:
  /// **'{club} yöneticileri cevaplarını görecek.'**
  String clubMgmtJoinAdminsSee(String club);

  /// No description provided for @clubMgmtAnswerHint.
  ///
  /// In tr, this message translates to:
  /// **'Cevabın'**
  String get clubMgmtAnswerHint;

  /// No description provided for @clubMgmtQuestionRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bu soru zorunlu'**
  String get clubMgmtQuestionRequired;

  /// No description provided for @clubMgmtCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get clubMgmtCancel;

  /// No description provided for @clubMgmtSendRequest.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönder'**
  String get clubMgmtSendRequest;

  /// No description provided for @clubMgmtNoPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen başvuru yok.'**
  String get clubMgmtNoPending;

  /// No description provided for @clubMgmtMoreRequests.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla başvuru'**
  String get clubMgmtMoreRequests;

  /// No description provided for @clubMgmtRequestsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başvurular'**
  String get clubMgmtRequestsTitle;

  /// No description provided for @clubMgmtWaitingCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} bekliyor'**
  String clubMgmtWaitingCount(String count);

  /// No description provided for @clubMgmtUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get clubMgmtUser;

  /// No description provided for @clubMgmtReject.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get clubMgmtReject;

  /// No description provided for @clubMgmtApprove.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get clubMgmtApprove;

  /// No description provided for @clubMgmtBan.
  ///
  /// In tr, this message translates to:
  /// **'Yasakla'**
  String get clubMgmtBan;

  /// No description provided for @clubMgmtRemoveFromClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpten çıkar'**
  String get clubMgmtRemoveFromClub;

  /// No description provided for @clubMgmtBanMessage.
  ///
  /// In tr, this message translates to:
  /// **'{name} kulüpten çıkarılsın ve bir daha katılamasın mı?'**
  String clubMgmtBanMessage(String name);

  /// No description provided for @clubMgmtRemoveMessage.
  ///
  /// In tr, this message translates to:
  /// **'{name} kulüpten çıkarılsın mı? Kulüp sohbetinden de düşer.'**
  String clubMgmtRemoveMessage(String name);

  /// No description provided for @clubMgmtRemoveConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get clubMgmtRemoveConfirm;

  /// No description provided for @clubMgmtNoMembers.
  ///
  /// In tr, this message translates to:
  /// **'Üye bulunamadı.'**
  String get clubMgmtNoMembers;

  /// No description provided for @clubMgmtMembersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler'**
  String get clubMgmtMembersTitle;

  /// No description provided for @clubMgmtSearchMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye ara'**
  String get clubMgmtSearchMember;

  /// No description provided for @clubMgmtRoleManager.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get clubMgmtRoleManager;

  /// No description provided for @clubMgmtRoleModerator.
  ///
  /// In tr, this message translates to:
  /// **'Moderatör'**
  String get clubMgmtRoleModerator;

  /// No description provided for @clubMgmtMemberActions.
  ///
  /// In tr, this message translates to:
  /// **'Üye işlemleri'**
  String get clubMgmtMemberActions;

  /// No description provided for @clubMgmtMakeModerator.
  ///
  /// In tr, this message translates to:
  /// **'Moderatör yap'**
  String get clubMgmtMakeModerator;

  /// No description provided for @clubMgmtMakeMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye yap'**
  String get clubMgmtMakeMember;

  /// No description provided for @clubMgmtPendingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulübün onaya gönderildi'**
  String get clubMgmtPendingTitle;

  /// No description provided for @clubMgmtPendingBody.
  ///
  /// In tr, this message translates to:
  /// **'Yöneticiler incelediğinde kulüp yayına girecek. Durumu Kulüplerim bölümünden izleyebilirsin.'**
  String get clubMgmtPendingBody;

  /// No description provided for @clubMgmtOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get clubMgmtOk;

  /// No description provided for @clubMgmtImageTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Görsel çok büyük.'**
  String get clubMgmtImageTooLarge;

  /// No description provided for @clubMgmtImageUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.'**
  String get clubMgmtImageUnsupported;

  /// No description provided for @clubMgmtImageUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel okunamadı.'**
  String get clubMgmtImageUnreadable;

  /// No description provided for @clubMgmtImagePickFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel seçilemedi.'**
  String get clubMgmtImagePickFailed;

  /// No description provided for @clubMgmtNameMin.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp adı en az 3 karakter olmalı.'**
  String get clubMgmtNameMin;

  /// No description provided for @clubMgmtNameMax.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp adı en fazla 80 karakter olabilir.'**
  String get clubMgmtNameMax;

  /// No description provided for @clubMgmtDescMax.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama en fazla 1000 karakter olabilir.'**
  String get clubMgmtDescMax;

  /// No description provided for @clubMgmtCategoryMax.
  ///
  /// In tr, this message translates to:
  /// **'Kategori en fazla 40 karakter olabilir.'**
  String get clubMgmtCategoryMax;

  /// No description provided for @clubMgmtSavedWithWarning.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp kaydedildi ancak kapak ya da katılım soruları kaydedilemedi.'**
  String get clubMgmtSavedWithWarning;

  /// No description provided for @clubMgmtEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulübü düzenle'**
  String get clubMgmtEditTitle;

  /// No description provided for @clubMgmtCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp kur'**
  String get clubMgmtCreateTitle;

  /// No description provided for @clubMgmtNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp adı'**
  String get clubMgmtNameLabel;

  /// No description provided for @clubMgmtNameHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Robotik Kulübü'**
  String get clubMgmtNameHint;

  /// No description provided for @clubMgmtDescLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kısa açıklama'**
  String get clubMgmtDescLabel;

  /// No description provided for @clubMgmtDescHint.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp ne yapıyor?'**
  String get clubMgmtDescHint;

  /// No description provided for @clubMgmtCategoryLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kategori'**
  String get clubMgmtCategoryLabel;

  /// No description provided for @clubMgmtCategoryHint.
  ///
  /// In tr, this message translates to:
  /// **'Listeden seç ya da yaz (isteğe bağlı)'**
  String get clubMgmtCategoryHint;

  /// No description provided for @clubMgmtVisibility.
  ///
  /// In tr, this message translates to:
  /// **'Görünürlük'**
  String get clubMgmtVisibility;

  /// No description provided for @clubMgmtPublic.
  ///
  /// In tr, this message translates to:
  /// **'Herkese açık'**
  String get clubMgmtPublic;

  /// No description provided for @clubMgmtPrivate.
  ///
  /// In tr, this message translates to:
  /// **'Gizli'**
  String get clubMgmtPrivate;

  /// No description provided for @clubMgmtPrivateHint.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp içeriğini yalnızca üyeler görür; katılım onayla olur.'**
  String get clubMgmtPrivateHint;

  /// No description provided for @clubMgmtPublicHint.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp Keşfet listesinde görünür.'**
  String get clubMgmtPublicHint;

  /// No description provided for @clubMgmtJoinLabel.
  ///
  /// In tr, this message translates to:
  /// **'Katılım'**
  String get clubMgmtJoinLabel;

  /// No description provided for @clubMgmtOpenPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Serbest'**
  String get clubMgmtOpenPolicy;

  /// No description provided for @clubMgmtApprovalPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Onaylı'**
  String get clubMgmtApprovalPolicy;

  /// No description provided for @clubMgmtApprovalHint.
  ///
  /// In tr, this message translates to:
  /// **'Katılmak isteyenler başvuru gönderir, sen onaylarsın.'**
  String get clubMgmtApprovalHint;

  /// No description provided for @clubMgmtOpenHint.
  ///
  /// In tr, this message translates to:
  /// **'Herkes doğrudan katılabilir.'**
  String get clubMgmtOpenHint;

  /// No description provided for @clubMgmtQuestionsLabel.
  ///
  /// In tr, this message translates to:
  /// **'Katılım soruları (en çok {max})'**
  String clubMgmtQuestionsLabel(String max);

  /// No description provided for @clubMgmtQuestionHint.
  ///
  /// In tr, this message translates to:
  /// **'Soru {n}'**
  String clubMgmtQuestionHint(String n);

  /// No description provided for @clubMgmtRemoveQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Soruyu kaldır'**
  String get clubMgmtRemoveQuestion;

  /// No description provided for @clubMgmtAddQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Soru ekle'**
  String get clubMgmtAddQuestion;

  /// No description provided for @clubMgmtSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get clubMgmtSave;

  /// No description provided for @clubMgmtCreateButton.
  ///
  /// In tr, this message translates to:
  /// **'Kulübü oluştur'**
  String get clubMgmtCreateButton;

  /// No description provided for @clubMgmtChangeCover.
  ///
  /// In tr, this message translates to:
  /// **'Kapağı değiştir'**
  String get clubMgmtChangeCover;

  /// No description provided for @clubMgmtAddCover.
  ///
  /// In tr, this message translates to:
  /// **'Kapak ekle (isteğe bağlı)'**
  String get clubMgmtAddCover;

  /// No description provided for @clubMgmtClubsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpler'**
  String get clubMgmtClubsTitle;

  /// No description provided for @clubMgmtSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get clubMgmtSearch;

  /// No description provided for @clubMgmtSearchClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp ara'**
  String get clubMgmtSearchClub;

  /// No description provided for @clubMgmtTabDiscover.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get clubMgmtTabDiscover;

  /// No description provided for @clubMgmtTabMine.
  ///
  /// In tr, this message translates to:
  /// **'Kulüplerim'**
  String get clubMgmtTabMine;

  /// No description provided for @clubMgmtAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get clubMgmtAll;

  /// No description provided for @clubMgmtEmptyMine.
  ///
  /// In tr, this message translates to:
  /// **'Henüz hiçbir kulübe üye değilsin.'**
  String get clubMgmtEmptyMine;

  /// No description provided for @clubMgmtNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp bulunamadı.'**
  String get clubMgmtNotFound;

  /// No description provided for @clubMgmtMemberCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String clubMgmtMemberCount(String count);

  /// No description provided for @clubMgmtYouAreMember.
  ///
  /// In tr, this message translates to:
  /// **'Üyesin'**
  String get clubMgmtYouAreMember;

  /// No description provided for @clubMgmtRequestSent.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönderildi'**
  String get clubMgmtRequestSent;

  /// No description provided for @clubMgmtBanned.
  ///
  /// In tr, this message translates to:
  /// **'Engelli'**
  String get clubMgmtBanned;

  /// No description provided for @clubMgmtJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get clubMgmtJoin;

  /// No description provided for @commonBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get commonBack;

  /// No description provided for @commonSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get commonSearchHint;

  /// No description provided for @commonJustNow.
  ///
  /// In tr, this message translates to:
  /// **'şimdi'**
  String get commonJustNow;

  /// No description provided for @commonMinutesAgo.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk önce'**
  String commonMinutesAgo(String n);

  /// No description provided for @commonHoursAgo.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa önce'**
  String commonHoursAgo(String n);

  /// No description provided for @commonDaysAgo.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün önce'**
  String commonDaysAgo(String n);

  /// No description provided for @commonLongDate.
  ///
  /// In tr, this message translates to:
  /// **'{day} {month}, {weekday}'**
  String commonLongDate(String day, String month, String weekday);

  /// No description provided for @commonTypeNews.
  ///
  /// In tr, this message translates to:
  /// **'Haber'**
  String get commonTypeNews;

  /// No description provided for @commonTypeAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru'**
  String get commonTypeAnnouncement;

  /// No description provided for @commonTypeEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get commonTypeEvent;

  /// No description provided for @commonMonth1.
  ///
  /// In tr, this message translates to:
  /// **'Ocak'**
  String get commonMonth1;

  /// No description provided for @commonMonth2.
  ///
  /// In tr, this message translates to:
  /// **'Şubat'**
  String get commonMonth2;

  /// No description provided for @commonMonth3.
  ///
  /// In tr, this message translates to:
  /// **'Mart'**
  String get commonMonth3;

  /// No description provided for @commonMonth4.
  ///
  /// In tr, this message translates to:
  /// **'Nisan'**
  String get commonMonth4;

  /// No description provided for @commonMonth5.
  ///
  /// In tr, this message translates to:
  /// **'Mayıs'**
  String get commonMonth5;

  /// No description provided for @commonMonth6.
  ///
  /// In tr, this message translates to:
  /// **'Haziran'**
  String get commonMonth6;

  /// No description provided for @commonMonth7.
  ///
  /// In tr, this message translates to:
  /// **'Temmuz'**
  String get commonMonth7;

  /// No description provided for @commonMonth8.
  ///
  /// In tr, this message translates to:
  /// **'Ağustos'**
  String get commonMonth8;

  /// No description provided for @commonMonth9.
  ///
  /// In tr, this message translates to:
  /// **'Eylül'**
  String get commonMonth9;

  /// No description provided for @commonMonth10.
  ///
  /// In tr, this message translates to:
  /// **'Ekim'**
  String get commonMonth10;

  /// No description provided for @commonMonth11.
  ///
  /// In tr, this message translates to:
  /// **'Kasım'**
  String get commonMonth11;

  /// No description provided for @commonMonth12.
  ///
  /// In tr, this message translates to:
  /// **'Aralık'**
  String get commonMonth12;

  /// No description provided for @commonWeekday1.
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi'**
  String get commonWeekday1;

  /// No description provided for @commonWeekday2.
  ///
  /// In tr, this message translates to:
  /// **'Salı'**
  String get commonWeekday2;

  /// No description provided for @commonWeekday3.
  ///
  /// In tr, this message translates to:
  /// **'Çarşamba'**
  String get commonWeekday3;

  /// No description provided for @commonWeekday4.
  ///
  /// In tr, this message translates to:
  /// **'Perşembe'**
  String get commonWeekday4;

  /// No description provided for @commonWeekday5.
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get commonWeekday5;

  /// No description provided for @commonWeekday6.
  ///
  /// In tr, this message translates to:
  /// **'Cumartesi'**
  String get commonWeekday6;

  /// No description provided for @commonWeekday7.
  ///
  /// In tr, this message translates to:
  /// **'Pazar'**
  String get commonWeekday7;

  /// No description provided for @reportReasonSpam.
  ///
  /// In tr, this message translates to:
  /// **'Spam veya reklam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In tr, this message translates to:
  /// **'Taciz veya zorbalık'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In tr, this message translates to:
  /// **'Uygunsuz içerik'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonImpersonation.
  ///
  /// In tr, this message translates to:
  /// **'Başkasını taklit'**
  String get reportReasonImpersonation;

  /// No description provided for @reportReasonOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get reportReasonOther;

  /// No description provided for @reportTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get reportTitle;

  /// No description provided for @reportMessageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mesajı şikâyet et'**
  String get reportMessageTitle;

  /// No description provided for @reportThanks.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyetiniz alındı. Teşekkürler.'**
  String get reportThanks;

  /// No description provided for @reportPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Sebep seçin. Şikâyetiniz yöneticilere iletilir.'**
  String get reportPrompt;

  /// No description provided for @reportDetailsHint.
  ///
  /// In tr, this message translates to:
  /// **'Ek açıklama (isteğe bağlı)'**
  String get reportDetailsHint;

  /// No description provided for @reportSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get reportSend;

  /// No description provided for @permNotificationsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get permNotificationsTitle;

  /// No description provided for @permNotificationsText.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj, etkinlik ve duyurulardan anında haberdar olmak için bildirim göndermemize izin verin.'**
  String get permNotificationsText;

  /// No description provided for @permContactsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Rehber'**
  String get permContactsTitle;

  /// No description provided for @permContactsText.
  ///
  /// In tr, this message translates to:
  /// **'Rehberinizdeki Bingöl Üniversitesi kişilerini bulup sohbet başlatabilmeniz için gerekir. Rehberiniz sunucuya gönderilmez.'**
  String get permContactsText;

  /// No description provided for @permCameraTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get permCameraTitle;

  /// No description provided for @permCameraText.
  ///
  /// In tr, this message translates to:
  /// **'QR kod okutmak ve fotoğraf çekmek için kameraya erişmemiz gerekir.'**
  String get permCameraText;

  /// No description provided for @permMicrophoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Mikrofon'**
  String get permMicrophoneTitle;

  /// No description provided for @permMicrophoneText.
  ///
  /// In tr, this message translates to:
  /// **'Ses ve görüntü kaydı yapabilmeniz için mikrofona erişmemiz gerekir.'**
  String get permMicrophoneText;

  /// No description provided for @permPhotosTitle.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraflar'**
  String get permPhotosTitle;

  /// No description provided for @permPhotosText.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf seçip paylaşabilmeniz için galerinize erişmemiz gerekir.'**
  String get permPhotosText;

  /// No description provided for @permContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get permContinue;

  /// No description provided for @permNotNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi değil'**
  String get permNotNow;

  /// No description provided for @permDeniedText.
  ///
  /// In tr, this message translates to:
  /// **'{title} izni verilmedi, bu yüzden bu özellik kullanılamıyor. İzni Ayarlar > BÜ Kampüs bölümünden açabilirsiniz.'**
  String permDeniedText(String title);

  /// No description provided for @permOpenSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlardan aç'**
  String get permOpenSettings;

  /// No description provided for @permClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get permClose;

  /// No description provided for @permPageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Birkaç izin'**
  String get permPageTitle;

  /// No description provided for @permPageIntro.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı en iyi şekilde kullanabilmeniz için aşağıdaki izinleri isteriz. Hiçbirini şimdi vermek zorunda değilsiniz; sonradan Ayarlar’dan da değiştirebilirsiniz.'**
  String get permPageIntro;

  /// No description provided for @permStart.
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get permStart;

  /// No description provided for @permGranted.
  ///
  /// In tr, this message translates to:
  /// **'Verildi'**
  String get permGranted;

  /// No description provided for @permDenied.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get permDenied;

  /// No description provided for @permRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get permRetry;

  /// No description provided for @permAllow.
  ///
  /// In tr, this message translates to:
  /// **'İzin ver'**
  String get permAllow;

  /// No description provided for @coreErrNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.'**
  String get coreErrNetwork;

  /// No description provided for @coreErrTooMany.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla deneme. Lütfen biraz bekleyin.'**
  String get coreErrTooMany;

  /// No description provided for @coreErrGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir sorun oluştu. Lütfen tekrar deneyin.'**
  String get coreErrGeneric;

  /// No description provided for @coreIdEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Okul numaranızı veya e-posta adresinizi girin.'**
  String get coreIdEmpty;

  /// No description provided for @coreIdDomain.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bingol.edu.tr uzantılı adres kullanılabilir.'**
  String get coreIdDomain;

  /// No description provided for @coreIdNumber.
  ///
  /// In tr, this message translates to:
  /// **'Okul numarasını kontrol edin.'**
  String get coreIdNumber;

  /// No description provided for @coreOffline.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimdışı'**
  String get coreOffline;

  /// No description provided for @coreMaintenance.
  ///
  /// In tr, this message translates to:
  /// **'Sistem bakımda.'**
  String get coreMaintenance;

  /// No description provided for @coreOpen.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get coreOpen;

  /// No description provided for @eventFormJoinFull.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu. \"İlgileniyorum\" ile takipte kalabilirsin.'**
  String get eventFormJoinFull;

  /// No description provided for @eventFormLeaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılımdan ayrıl'**
  String get eventFormLeaveTitle;

  /// No description provided for @eventFormLeaveMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu etkinlik Etkinliklerim listenden çıkarılacak.'**
  String get eventFormLeaveMessage;

  /// No description provided for @eventFormLeaveConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get eventFormLeaveConfirm;

  /// No description provided for @eventFormRegsClosedToast.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar kapatıldı.'**
  String get eventFormRegsClosedToast;

  /// No description provided for @eventFormRegsReopenedToast.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar yeniden açıldı.'**
  String get eventFormRegsReopenedToast;

  /// No description provided for @eventFormCancelTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği iptal et'**
  String get eventFormCancelTitle;

  /// No description provided for @eventFormCancelMessage.
  ///
  /// In tr, this message translates to:
  /// **'Bu etkinlik tüm katılımcılar için iptal edilecek.'**
  String get eventFormCancelMessage;

  /// No description provided for @eventFormCancelAction.
  ///
  /// In tr, this message translates to:
  /// **'İptal et'**
  String get eventFormCancelAction;

  /// No description provided for @eventFormCancelledToast.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik iptal edildi.'**
  String get eventFormCancelledToast;

  /// No description provided for @eventFormScanTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama QR kodunu tara'**
  String get eventFormScanTitle;

  /// No description provided for @eventFormWrongEventCode.
  ///
  /// In tr, this message translates to:
  /// **'Bu kod başka bir etkinliğe ait.'**
  String get eventFormWrongEventCode;

  /// No description provided for @eventFormCheckedIn.
  ///
  /// In tr, this message translates to:
  /// **'Yoklaman alındı'**
  String get eventFormCheckedIn;

  /// No description provided for @eventFormChatSoon.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sohbeti yakında'**
  String get eventFormChatSoon;

  /// No description provided for @eventFormEventTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get eventFormEventTitle;

  /// No description provided for @eventFormNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik bulunamadı'**
  String get eventFormNotFound;

  /// No description provided for @eventFormRegsClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar kapalı'**
  String get eventFormRegsClosed;

  /// No description provided for @eventFormJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get eventFormJoin;

  /// No description provided for @eventFormInterested.
  ///
  /// In tr, this message translates to:
  /// **'İlgileniyorum'**
  String get eventFormInterested;

  /// No description provided for @eventFormBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get eventFormBack;

  /// No description provided for @eventFormManage.
  ///
  /// In tr, this message translates to:
  /// **'Yönet'**
  String get eventFormManage;

  /// No description provided for @eventFormEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get eventFormEdit;

  /// No description provided for @eventFormReopenRegs.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtları yeniden aç'**
  String get eventFormReopenRegs;

  /// No description provided for @eventFormCloseRegs.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtları kapat'**
  String get eventFormCloseRegs;

  /// No description provided for @eventFormReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get eventFormReport;

  /// No description provided for @eventFormReportEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği şikâyet et'**
  String get eventFormReportEvent;

  /// No description provided for @eventFormCancelledPill.
  ///
  /// In tr, this message translates to:
  /// **'İptal edildi'**
  String get eventFormCancelledPill;

  /// No description provided for @eventFormInMine.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklerimde'**
  String get eventFormInMine;

  /// No description provided for @eventFormOrganizedBy.
  ///
  /// In tr, this message translates to:
  /// **'Düzenleyen:'**
  String get eventFormOrganizedBy;

  /// No description provided for @eventFormCapacityFull.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu'**
  String get eventFormCapacityFull;

  /// No description provided for @eventFormCapacityCount.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan: {going} / {cap}'**
  String eventFormCapacityCount(String going, String cap);

  /// No description provided for @eventFormGoingLabel.
  ///
  /// In tr, this message translates to:
  /// **'katılıyor'**
  String get eventFormGoingLabel;

  /// No description provided for @eventFormInterestedLabel.
  ///
  /// In tr, this message translates to:
  /// **'ilgileniyor'**
  String get eventFormInterestedLabel;

  /// No description provided for @eventFormInterestedShort.
  ///
  /// In tr, this message translates to:
  /// **'İlgileniyor'**
  String get eventFormInterestedShort;

  /// No description provided for @eventFormFullHint.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu; yine de ilgilendiğini belirtebilirsin.'**
  String get eventFormFullHint;

  /// No description provided for @eventFormChat.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sohbeti'**
  String get eventFormChat;

  /// No description provided for @eventFormManageJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katılımı yönet'**
  String get eventFormManageJoin;

  /// No description provided for @eventFormCheckInLater.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama etkinlik saatinde açılır.'**
  String get eventFormCheckInLater;

  /// No description provided for @eventFormScanQr.
  ///
  /// In tr, this message translates to:
  /// **'QR kodu tara'**
  String get eventFormScanQr;

  /// No description provided for @eventFormEnterCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu elle gir'**
  String get eventFormEnterCode;

  /// No description provided for @eventFormEnterOrganizerCode.
  ///
  /// In tr, this message translates to:
  /// **'Organizatörün gösterdiği kodu gir'**
  String get eventFormEnterOrganizerCode;

  /// No description provided for @eventFormCheckInCode.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama kodu'**
  String get eventFormCheckInCode;

  /// No description provided for @eventFormSendCheckIn.
  ///
  /// In tr, this message translates to:
  /// **'Yoklamayı gönder'**
  String get eventFormSendCheckIn;

  /// No description provided for @eventFormCodePreparing.
  ///
  /// In tr, this message translates to:
  /// **'Kod hazırlanıyor…'**
  String get eventFormCodePreparing;

  /// No description provided for @eventFormCodeFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kod alınamadı.'**
  String get eventFormCodeFailed;

  /// No description provided for @eventFormQrHelp.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar bu QR kodunu uygulamadan taratır.'**
  String get eventFormQrHelp;

  /// No description provided for @eventFormCodeShortLived.
  ///
  /// In tr, this message translates to:
  /// **'Kod kısa süre geçerlidir.'**
  String get eventFormCodeShortLived;

  /// No description provided for @eventFormCodeExpires.
  ///
  /// In tr, this message translates to:
  /// **'Son kullanma: {time} · kod otomatik yenilenir'**
  String eventFormCodeExpires(String time);

  /// No description provided for @eventFormRefreshCode.
  ///
  /// In tr, this message translates to:
  /// **'Kodu yenile'**
  String get eventFormRefreshCode;

  /// No description provided for @eventFormNoAttendance.
  ///
  /// In tr, this message translates to:
  /// **'Henüz yoklama kaydı yok'**
  String get eventFormNoAttendance;

  /// No description provided for @eventFormAttendanceCount.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama: {present} / {total} kişi geldi'**
  String eventFormAttendanceCount(String present, String total);

  /// No description provided for @eventFormAttendees.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar'**
  String get eventFormAttendees;

  /// No description provided for @eventFormShowMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla göster'**
  String get eventFormShowMore;

  /// No description provided for @eventFormCoverCreatedFail.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik oluşturuldu, kapak yüklenemedi.{reason}'**
  String eventFormCoverCreatedFail(String reason);

  /// No description provided for @eventFormCoverFail.
  ///
  /// In tr, this message translates to:
  /// **'Kapak yüklenemedi.{reason}'**
  String eventFormCoverFail(String reason);

  /// No description provided for @eventFormRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get eventFormRetry;

  /// No description provided for @eventFormPickGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get eventFormPickGallery;

  /// No description provided for @eventFormTakePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çek'**
  String get eventFormTakePhoto;

  /// No description provided for @eventFormImgTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Görsel çok büyük, daha küçük bir görsel seçin.'**
  String get eventFormImgTooLarge;

  /// No description provided for @eventFormImgUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.'**
  String get eventFormImgUnsupported;

  /// No description provided for @eventFormImgUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel okunamadı.'**
  String get eventFormImgUnreadable;

  /// No description provided for @eventFormImgPickFail.
  ///
  /// In tr, this message translates to:
  /// **'Görsel seçilemedi. İzinleri kontrol edin.'**
  String get eventFormImgPickFail;

  /// No description provided for @eventFormTitleTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Başlık en az 3 karakter olmalı.'**
  String get eventFormTitleTooShort;

  /// No description provided for @eventFormEndBeforeStart.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş, başlangıçtan sonra olmalı.'**
  String get eventFormEndBeforeStart;

  /// No description provided for @eventFormCapInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan 1 veya daha büyük bir sayı olmalı.'**
  String get eventFormCapInvalid;

  /// No description provided for @eventFormCoverRemoveFail.
  ///
  /// In tr, this message translates to:
  /// **'Kapak kaldırılamadı. {reason}'**
  String eventFormCoverRemoveFail(String reason);

  /// No description provided for @eventFormCreated.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik oluşturuldu.'**
  String get eventFormCreated;

  /// No description provided for @eventFormEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği düzenle'**
  String get eventFormEditTitle;

  /// No description provided for @eventFormNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni etkinlik'**
  String get eventFormNewTitle;

  /// No description provided for @eventFormFieldTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get eventFormFieldTitle;

  /// No description provided for @eventFormTitleHint.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik başlığı'**
  String get eventFormTitleHint;

  /// No description provided for @eventFormFieldDesc.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama'**
  String get eventFormFieldDesc;

  /// No description provided for @eventFormDescHint.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik hakkında kısaca'**
  String get eventFormDescHint;

  /// No description provided for @eventFormStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get eventFormStart;

  /// No description provided for @eventFormStartSem.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç zamanı'**
  String get eventFormStartSem;

  /// No description provided for @eventFormEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get eventFormEnd;

  /// No description provided for @eventFormEndSem.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş zamanı'**
  String get eventFormEndSem;

  /// No description provided for @eventFormPlace.
  ///
  /// In tr, this message translates to:
  /// **'Mekân'**
  String get eventFormPlace;

  /// No description provided for @eventFormPlaceHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Konferans Salonu'**
  String get eventFormPlaceHint;

  /// No description provided for @eventFormCapacityLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan'**
  String get eventFormCapacityLabel;

  /// No description provided for @eventFormCapHint.
  ///
  /// In tr, this message translates to:
  /// **'Boş bırakırsan sınırsız'**
  String get eventFormCapHint;

  /// No description provided for @eventFormSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get eventFormSave;

  /// No description provided for @eventFormCreate.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği oluştur'**
  String get eventFormCreate;

  /// No description provided for @eventFormAddCover.
  ///
  /// In tr, this message translates to:
  /// **'Kapak fotoğrafı ekle'**
  String get eventFormAddCover;

  /// No description provided for @eventFormChangeCover.
  ///
  /// In tr, this message translates to:
  /// **'Kapağı değiştir'**
  String get eventFormChangeCover;

  /// No description provided for @eventFormRemoveCover.
  ///
  /// In tr, this message translates to:
  /// **'Kapağı kaldır'**
  String get eventFormRemoveCover;

  /// No description provided for @eventListTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get eventListTitle;

  /// No description provided for @eventListCreate.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik oluştur'**
  String get eventListCreate;

  /// No description provided for @eventListCheckin.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama'**
  String get eventListCheckin;

  /// No description provided for @eventListTabDiscover.
  ///
  /// In tr, this message translates to:
  /// **'Keşfet'**
  String get eventListTabDiscover;

  /// No description provided for @eventListTabMine.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklerim'**
  String get eventListTabMine;

  /// No description provided for @eventListTabCreated.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturduklarım'**
  String get eventListTabCreated;

  /// No description provided for @eventListLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor'**
  String get eventListLoading;

  /// No description provided for @eventListPrevMonth.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get eventListPrevMonth;

  /// No description provided for @eventListNextMonth.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get eventListNextMonth;

  /// No description provided for @eventListMonthYear.
  ///
  /// In tr, this message translates to:
  /// **'{month} {year}'**
  String eventListMonthYear(String month, String year);

  /// No description provided for @eventListLongDate.
  ///
  /// In tr, this message translates to:
  /// **'{day} {month}, {weekday}'**
  String eventListLongDate(String day, String month, String weekday);

  /// No description provided for @eventListFull.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu. \"İlgileniyorum\" ile takipte kalabilirsin.'**
  String get eventListFull;

  /// No description provided for @eventListLeaveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılımdan ayrıl'**
  String get eventListLeaveTitle;

  /// No description provided for @eventListLeaveMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu etkinlik Etkinliklerim listenden çıkarılacak.'**
  String get eventListLeaveMsg;

  /// No description provided for @eventListLeave.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıl'**
  String get eventListLeave;

  /// No description provided for @eventListLeft.
  ///
  /// In tr, this message translates to:
  /// **'Katılımdan ayrıldın.'**
  String get eventListLeft;

  /// No description provided for @eventListClosedDone.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar kapatıldı.'**
  String get eventListClosedDone;

  /// No description provided for @eventListReopenedDone.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar yeniden açıldı.'**
  String get eventListReopenedDone;

  /// No description provided for @eventListCancelTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliği iptal et'**
  String get eventListCancelTitle;

  /// No description provided for @eventListCancelMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu etkinlik tüm katılımcılar için iptal edilecek.'**
  String get eventListCancelMsg;

  /// No description provided for @eventListCancelConfirm.
  ///
  /// In tr, this message translates to:
  /// **'İptal et'**
  String get eventListCancelConfirm;

  /// No description provided for @eventListCancelledDone.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik iptal edildi.'**
  String get eventListCancelledDone;

  /// No description provided for @eventListScanTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama QR kodunu tara'**
  String get eventListScanTitle;

  /// No description provided for @eventListNotCode.
  ///
  /// In tr, this message translates to:
  /// **'Bu bir yoklama kodu değil.'**
  String get eventListNotCode;

  /// No description provided for @eventListCheckedIn.
  ///
  /// In tr, this message translates to:
  /// **'Yoklaman alındı.'**
  String get eventListCheckedIn;

  /// No description provided for @eventListEmptyDay.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için etkinlik yok.'**
  String get eventListEmptyDay;

  /// No description provided for @eventListEmptyMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay için etkinlik yok.'**
  String get eventListEmptyMonth;

  /// No description provided for @eventListPastMonth.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş ay: yalnızca görüntüleme.'**
  String get eventListPastMonth;

  /// No description provided for @eventListTruncated.
  ///
  /// In tr, this message translates to:
  /// **'Bu ayın tamamı gösterilemiyor; bazı etkinlikler listede yok.'**
  String get eventListTruncated;

  /// No description provided for @eventListUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get eventListUpcoming;

  /// No description provided for @eventListPast.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get eventListPast;

  /// No description provided for @eventListCreatedHint.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturduğun etkinlikleri buradan yönetebilirsin.'**
  String get eventListCreatedHint;

  /// No description provided for @eventListEmptyUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Katılacağın bir etkinlik yok.'**
  String get eventListEmptyUpcoming;

  /// No description provided for @eventListEmptyPast.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş etkinliğin yok.'**
  String get eventListEmptyPast;

  /// No description provided for @eventListEmptyCreated.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir etkinlik oluşturmadın.'**
  String get eventListEmptyCreated;

  /// No description provided for @eventListDiscover.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikleri keşfet'**
  String get eventListDiscover;

  /// No description provided for @eventListOfficial.
  ///
  /// In tr, this message translates to:
  /// **'Resmi'**
  String get eventListOfficial;

  /// No description provided for @eventListCancelled.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get eventListCancelled;

  /// No description provided for @eventListRegClosedTag.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt kapalı'**
  String get eventListRegClosedTag;

  /// No description provided for @eventListOpen.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get eventListOpen;

  /// No description provided for @eventListRegsClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar kapalı'**
  String get eventListRegsClosed;

  /// No description provided for @eventListJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get eventListJoin;

  /// No description provided for @eventListInterested.
  ///
  /// In tr, this message translates to:
  /// **'İlgileniyorum'**
  String get eventListInterested;

  /// No description provided for @eventListGoing.
  ///
  /// In tr, this message translates to:
  /// **'katılıyor'**
  String get eventListGoing;

  /// No description provided for @eventListOptions.
  ///
  /// In tr, this message translates to:
  /// **'Seçenekler'**
  String get eventListOptions;

  /// No description provided for @eventListAttendeeCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} katılımcı'**
  String eventListAttendeeCount(String count);

  /// No description provided for @eventListAttendees.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar'**
  String get eventListAttendees;

  /// No description provided for @eventListEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get eventListEdit;

  /// No description provided for @eventListReopen.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtları yeniden aç'**
  String get eventListReopen;

  /// No description provided for @eventListClose.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtları kapat'**
  String get eventListClose;

  /// No description provided for @eventListRegClosedError.
  ///
  /// In tr, this message translates to:
  /// **'Bu etkinliğin kayıtları kapalı.'**
  String get eventListRegClosedError;

  /// No description provided for @eventListAddedMine.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklerime eklendi'**
  String get eventListAddedMine;

  /// No description provided for @eventListDismiss.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get eventListDismiss;

  /// No description provided for @eventListInMine.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklerimde'**
  String get eventListInMine;

  /// No description provided for @eventListQrLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama QR kodu'**
  String get eventListQrLabel;

  /// No description provided for @eventListMonth1.
  ///
  /// In tr, this message translates to:
  /// **'Ocak'**
  String get eventListMonth1;

  /// No description provided for @eventListMonth2.
  ///
  /// In tr, this message translates to:
  /// **'Şubat'**
  String get eventListMonth2;

  /// No description provided for @eventListMonth3.
  ///
  /// In tr, this message translates to:
  /// **'Mart'**
  String get eventListMonth3;

  /// No description provided for @eventListMonth4.
  ///
  /// In tr, this message translates to:
  /// **'Nisan'**
  String get eventListMonth4;

  /// No description provided for @eventListMonth5.
  ///
  /// In tr, this message translates to:
  /// **'Mayıs'**
  String get eventListMonth5;

  /// No description provided for @eventListMonth6.
  ///
  /// In tr, this message translates to:
  /// **'Haziran'**
  String get eventListMonth6;

  /// No description provided for @eventListMonth7.
  ///
  /// In tr, this message translates to:
  /// **'Temmuz'**
  String get eventListMonth7;

  /// No description provided for @eventListMonth8.
  ///
  /// In tr, this message translates to:
  /// **'Ağustos'**
  String get eventListMonth8;

  /// No description provided for @eventListMonth9.
  ///
  /// In tr, this message translates to:
  /// **'Eylül'**
  String get eventListMonth9;

  /// No description provided for @eventListMonth10.
  ///
  /// In tr, this message translates to:
  /// **'Ekim'**
  String get eventListMonth10;

  /// No description provided for @eventListMonth11.
  ///
  /// In tr, this message translates to:
  /// **'Kasım'**
  String get eventListMonth11;

  /// No description provided for @eventListMonth12.
  ///
  /// In tr, this message translates to:
  /// **'Aralık'**
  String get eventListMonth12;

  /// No description provided for @eventListMon1.
  ///
  /// In tr, this message translates to:
  /// **'OCA'**
  String get eventListMon1;

  /// No description provided for @eventListMon2.
  ///
  /// In tr, this message translates to:
  /// **'ŞUB'**
  String get eventListMon2;

  /// No description provided for @eventListMon3.
  ///
  /// In tr, this message translates to:
  /// **'MAR'**
  String get eventListMon3;

  /// No description provided for @eventListMon4.
  ///
  /// In tr, this message translates to:
  /// **'NİS'**
  String get eventListMon4;

  /// No description provided for @eventListMon5.
  ///
  /// In tr, this message translates to:
  /// **'MAY'**
  String get eventListMon5;

  /// No description provided for @eventListMon6.
  ///
  /// In tr, this message translates to:
  /// **'HAZ'**
  String get eventListMon6;

  /// No description provided for @eventListMon7.
  ///
  /// In tr, this message translates to:
  /// **'TEM'**
  String get eventListMon7;

  /// No description provided for @eventListMon8.
  ///
  /// In tr, this message translates to:
  /// **'AĞU'**
  String get eventListMon8;

  /// No description provided for @eventListMon9.
  ///
  /// In tr, this message translates to:
  /// **'EYL'**
  String get eventListMon9;

  /// No description provided for @eventListMon10.
  ///
  /// In tr, this message translates to:
  /// **'EKİ'**
  String get eventListMon10;

  /// No description provided for @eventListMon11.
  ///
  /// In tr, this message translates to:
  /// **'KAS'**
  String get eventListMon11;

  /// No description provided for @eventListMon12.
  ///
  /// In tr, this message translates to:
  /// **'ARA'**
  String get eventListMon12;

  /// No description provided for @eventListDayShort1.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get eventListDayShort1;

  /// No description provided for @eventListDayShort2.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get eventListDayShort2;

  /// No description provided for @eventListDayShort3.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get eventListDayShort3;

  /// No description provided for @eventListDayShort4.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get eventListDayShort4;

  /// No description provided for @eventListDayShort5.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get eventListDayShort5;

  /// No description provided for @eventListDayShort6.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get eventListDayShort6;

  /// No description provided for @eventListDayShort7.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get eventListDayShort7;

  /// No description provided for @eventListDayLong1.
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi'**
  String get eventListDayLong1;

  /// No description provided for @eventListDayLong2.
  ///
  /// In tr, this message translates to:
  /// **'Salı'**
  String get eventListDayLong2;

  /// No description provided for @eventListDayLong3.
  ///
  /// In tr, this message translates to:
  /// **'Çarşamba'**
  String get eventListDayLong3;

  /// No description provided for @eventListDayLong4.
  ///
  /// In tr, this message translates to:
  /// **'Perşembe'**
  String get eventListDayLong4;

  /// No description provided for @eventListDayLong5.
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get eventListDayLong5;

  /// No description provided for @eventListDayLong6.
  ///
  /// In tr, this message translates to:
  /// **'Cumartesi'**
  String get eventListDayLong6;

  /// No description provided for @eventListDayLong7.
  ///
  /// In tr, this message translates to:
  /// **'Pazar'**
  String get eventListDayLong7;

  /// No description provided for @homeGreetNight.
  ///
  /// In tr, this message translates to:
  /// **'İyi geceler'**
  String get homeGreetNight;

  /// No description provided for @homeGreetMorning.
  ///
  /// In tr, this message translates to:
  /// **'Günaydın'**
  String get homeGreetMorning;

  /// No description provided for @homeGreetDay.
  ///
  /// In tr, this message translates to:
  /// **'İyi günler'**
  String get homeGreetDay;

  /// No description provided for @homeGreetEvening.
  ///
  /// In tr, this message translates to:
  /// **'İyi akşamlar'**
  String get homeGreetEvening;

  /// No description provided for @homeEventLoadFailedToast.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik yüklenemedi.'**
  String get homeEventLoadFailedToast;

  /// No description provided for @homeEventLoadFailedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik yüklenemedi'**
  String get homeEventLoadFailedTitle;

  /// No description provided for @homeQuotaFull.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu.'**
  String get homeQuotaFull;

  /// No description provided for @homeMaintenanceDefault.
  ///
  /// In tr, this message translates to:
  /// **'Sistem bakımda.'**
  String get homeMaintenanceDefault;

  /// No description provided for @homeSourceUnreachable.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak site şu an ulaşılamıyor; veriler güncel olmayabilir.'**
  String get homeSourceUnreachable;

  /// No description provided for @homeSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Haber, kulüp, etkinlik ara'**
  String get homeSearchHint;

  /// No description provided for @homeMyClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüplerimden'**
  String get homeMyClubs;

  /// No description provided for @homeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get homeAll;

  /// No description provided for @homeAgenda.
  ///
  /// In tr, this message translates to:
  /// **'Gündem'**
  String get homeAgenda;

  /// No description provided for @homeContentLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'İçerik yüklenemedi.'**
  String get homeContentLoadFailed;

  /// No description provided for @homeNoContent.
  ///
  /// In tr, this message translates to:
  /// **'Henüz içerik yok.'**
  String get homeNoContent;

  /// No description provided for @homeMyProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profilim'**
  String get homeMyProfile;

  /// No description provided for @homeFeaturedEvent.
  ///
  /// In tr, this message translates to:
  /// **'Öne çıkan etkinlik'**
  String get homeFeaturedEvent;

  /// No description provided for @homeNextEvent.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki etkinlik'**
  String get homeNextEvent;

  /// No description provided for @homeNoUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan etkinlik yok'**
  String get homeNoUpcoming;

  /// No description provided for @homeBrowseEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklere göz at'**
  String get homeBrowseEvents;

  /// No description provided for @homeOfficialEvent.
  ///
  /// In tr, this message translates to:
  /// **'Resmi etkinlik'**
  String get homeOfficialEvent;

  /// No description provided for @homeMostAttended.
  ///
  /// In tr, this message translates to:
  /// **'En çok katılım'**
  String get homeMostAttended;

  /// No description provided for @homeGoingCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kişi katılıyor'**
  String homeGoingCount(String count);

  /// No description provided for @homeBeFirst.
  ///
  /// In tr, this message translates to:
  /// **'İlk katılan sen ol'**
  String get homeBeFirst;

  /// No description provided for @homeInMyEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklerimde'**
  String get homeInMyEvents;

  /// No description provided for @homeFull.
  ///
  /// In tr, this message translates to:
  /// **'Dolu'**
  String get homeFull;

  /// No description provided for @homeRegClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt kapalı'**
  String get homeRegClosed;

  /// No description provided for @homeJoin.
  ///
  /// In tr, this message translates to:
  /// **'Katıl'**
  String get homeJoin;

  /// No description provided for @homeQuickEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get homeQuickEvent;

  /// No description provided for @homeQuickFood.
  ///
  /// In tr, this message translates to:
  /// **'Yemek'**
  String get homeQuickFood;

  /// No description provided for @homeQuickSupport.
  ///
  /// In tr, this message translates to:
  /// **'Destek'**
  String get homeQuickSupport;

  /// No description provided for @homeTodayMeal.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün yemeği'**
  String get homeTodayMeal;

  /// No description provided for @homeNoMenuToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün için liste yok'**
  String get homeNoMenuToday;

  /// No description provided for @homeNewMessages.
  ///
  /// In tr, this message translates to:
  /// **'yeni mesaj'**
  String get homeNewMessages;

  /// No description provided for @homeClubMemberships.
  ///
  /// In tr, this message translates to:
  /// **'kulüp üyeliği'**
  String get homeClubMemberships;

  /// No description provided for @homeMemberCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String homeMemberCount(String count);

  /// No description provided for @newsTypeNews.
  ///
  /// In tr, this message translates to:
  /// **'Haber'**
  String get newsTypeNews;

  /// No description provided for @newsTypeAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru'**
  String get newsTypeAnnouncement;

  /// No description provided for @newsTypeEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get newsTypeEvent;

  /// No description provided for @newsEventDateShort.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik: {date}'**
  String newsEventDateShort(String date);

  /// No description provided for @newsEventDate.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik tarihi: {date}'**
  String newsEventDate(String date);

  /// No description provided for @newsSaveRemove.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden çıkar'**
  String get newsSaveRemove;

  /// No description provided for @newsSaveAdd.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere ekle'**
  String get newsSaveAdd;

  /// No description provided for @newsLinkOpenFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı açılamadı.'**
  String get newsLinkOpenFailed;

  /// No description provided for @newsFullContent.
  ///
  /// In tr, this message translates to:
  /// **'İçeriğin tamamı için kaynak sayfayı açın.'**
  String get newsFullContent;

  /// No description provided for @newsOpenSource.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak sayfada aç'**
  String get newsOpenSource;

  /// No description provided for @newsMonth1.
  ///
  /// In tr, this message translates to:
  /// **'Ocak'**
  String get newsMonth1;

  /// No description provided for @newsMonth2.
  ///
  /// In tr, this message translates to:
  /// **'Şubat'**
  String get newsMonth2;

  /// No description provided for @newsMonth3.
  ///
  /// In tr, this message translates to:
  /// **'Mart'**
  String get newsMonth3;

  /// No description provided for @newsMonth4.
  ///
  /// In tr, this message translates to:
  /// **'Nisan'**
  String get newsMonth4;

  /// No description provided for @newsMonth5.
  ///
  /// In tr, this message translates to:
  /// **'Mayıs'**
  String get newsMonth5;

  /// No description provided for @newsMonth6.
  ///
  /// In tr, this message translates to:
  /// **'Haziran'**
  String get newsMonth6;

  /// No description provided for @newsMonth7.
  ///
  /// In tr, this message translates to:
  /// **'Temmuz'**
  String get newsMonth7;

  /// No description provided for @newsMonth8.
  ///
  /// In tr, this message translates to:
  /// **'Ağustos'**
  String get newsMonth8;

  /// No description provided for @newsMonth9.
  ///
  /// In tr, this message translates to:
  /// **'Eylül'**
  String get newsMonth9;

  /// No description provided for @newsMonth10.
  ///
  /// In tr, this message translates to:
  /// **'Ekim'**
  String get newsMonth10;

  /// No description provided for @newsMonth11.
  ///
  /// In tr, this message translates to:
  /// **'Kasım'**
  String get newsMonth11;

  /// No description provided for @newsMonth12.
  ///
  /// In tr, this message translates to:
  /// **'Aralık'**
  String get newsMonth12;

  /// No description provided for @newsDayLong1.
  ///
  /// In tr, this message translates to:
  /// **'Pazartesi'**
  String get newsDayLong1;

  /// No description provided for @newsDayLong2.
  ///
  /// In tr, this message translates to:
  /// **'Salı'**
  String get newsDayLong2;

  /// No description provided for @newsDayLong3.
  ///
  /// In tr, this message translates to:
  /// **'Çarşamba'**
  String get newsDayLong3;

  /// No description provided for @newsDayLong4.
  ///
  /// In tr, this message translates to:
  /// **'Perşembe'**
  String get newsDayLong4;

  /// No description provided for @newsDayLong5.
  ///
  /// In tr, this message translates to:
  /// **'Cuma'**
  String get newsDayLong5;

  /// No description provided for @newsDayLong6.
  ///
  /// In tr, this message translates to:
  /// **'Cumartesi'**
  String get newsDayLong6;

  /// No description provided for @newsDayLong7.
  ///
  /// In tr, this message translates to:
  /// **'Pazar'**
  String get newsDayLong7;

  /// No description provided for @newsDayShort1.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get newsDayShort1;

  /// No description provided for @newsDayShort2.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get newsDayShort2;

  /// No description provided for @newsDayShort3.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get newsDayShort3;

  /// No description provided for @newsDayShort4.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get newsDayShort4;

  /// No description provided for @newsDayShort5.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get newsDayShort5;

  /// No description provided for @newsDayShort6.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get newsDayShort6;

  /// No description provided for @newsDayShort7.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get newsDayShort7;

  /// No description provided for @discoverSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilenler'**
  String get discoverSaved;

  /// No description provided for @discoverScopeLatest.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get discoverScopeLatest;

  /// No description provided for @discoverScopePopular.
  ///
  /// In tr, this message translates to:
  /// **'Popüler'**
  String get discoverScopePopular;

  /// No description provided for @discoverScopeFollowing.
  ///
  /// In tr, this message translates to:
  /// **'Takip'**
  String get discoverScopeFollowing;

  /// No description provided for @discoverScopeDepartment.
  ///
  /// In tr, this message translates to:
  /// **'Bölümüm'**
  String get discoverScopeDepartment;

  /// No description provided for @discoverNoSaved.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kaydettiğiniz bir haber yok.'**
  String get discoverNoSaved;

  /// No description provided for @discoverNoCategory.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategoride henüz içerik yok.'**
  String get discoverNoCategory;

  /// No description provided for @discoverDeptHint.
  ///
  /// In tr, this message translates to:
  /// **'Bölümünü profilinden seçersen bölümündeki gönderileri burada görürsün.'**
  String get discoverDeptHint;

  /// No description provided for @discoverDeptEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bölümünden henüz gönderi yok.'**
  String get discoverDeptEmpty;

  /// No description provided for @discoverProfilePath.
  ///
  /// In tr, this message translates to:
  /// **'Profil > Profili düzenle'**
  String get discoverProfilePath;

  /// No description provided for @discoverPolls.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get discoverPolls;

  /// No description provided for @discoverSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get discoverSearch;

  /// No description provided for @discoverCompose.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi oluştur'**
  String get discoverCompose;

  /// No description provided for @discoverPosts.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiler'**
  String get discoverPosts;

  /// No description provided for @discoverNews.
  ///
  /// In tr, this message translates to:
  /// **'Haberler'**
  String get discoverNews;

  /// No description provided for @discoverSourceMaint.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak site şu an bakımda. Veriler güncel olmayabilir.'**
  String get discoverSourceMaint;

  /// No description provided for @menuTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yemek listesi'**
  String get menuTitle;

  /// No description provided for @menuStale.
  ///
  /// In tr, this message translates to:
  /// **'Yemek listesi güncellenemedi; son bilinen liste gösteriliyor.'**
  String get menuStale;

  /// No description provided for @menuPrevMonth.
  ///
  /// In tr, this message translates to:
  /// **'Önceki ay'**
  String get menuPrevMonth;

  /// No description provided for @menuNextMonth.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki ay'**
  String get menuNextMonth;

  /// No description provided for @menuTodayLabel.
  ///
  /// In tr, this message translates to:
  /// **'BUGÜN · {date}'**
  String menuTodayLabel(String date);

  /// No description provided for @menuNoMenuDay.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için yemek listesi yok.'**
  String get menuNoMenuDay;

  /// No description provided for @menuNoMenuMonth.
  ///
  /// In tr, this message translates to:
  /// **'Bu ay için yemek listesi henüz yayınlanmadı.'**
  String get menuNoMenuMonth;

  /// No description provided for @menuNoList.
  ///
  /// In tr, this message translates to:
  /// **'Yemek listesi yok.'**
  String get menuNoList;

  /// No description provided for @menuPhotoLabel.
  ///
  /// In tr, this message translates to:
  /// **'Günün menüsü fotoğrafı'**
  String get menuPhotoLabel;

  /// No description provided for @notifTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notifTitle;

  /// No description provided for @notifMarkAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü okundu yap'**
  String get notifMarkAll;

  /// No description provided for @notifEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bildiriminiz yok'**
  String get notifEmpty;

  /// No description provided for @notifUnread.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış bildirim'**
  String get notifUnread;

  /// No description provided for @notifGroupToday.
  ///
  /// In tr, this message translates to:
  /// **'BUGÜN'**
  String get notifGroupToday;

  /// No description provided for @notifGroupYesterday.
  ///
  /// In tr, this message translates to:
  /// **'DÜN'**
  String get notifGroupYesterday;

  /// No description provided for @notifGroupOlder.
  ///
  /// In tr, this message translates to:
  /// **'DAHA ESKİ'**
  String get notifGroupOlder;

  /// No description provided for @notifNow.
  ///
  /// In tr, this message translates to:
  /// **'şimdi'**
  String get notifNow;

  /// No description provided for @notifMinAgo.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk önce'**
  String notifMinAgo(String n);

  /// No description provided for @notifHourAgo.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa önce'**
  String notifHourAgo(String n);

  /// No description provided for @notifDayAgo.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün önce'**
  String notifDayAgo(String n);

  /// No description provided for @searchAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get searchAll;

  /// No description provided for @searchClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get searchClub;

  /// No description provided for @searchPost.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi'**
  String get searchPost;

  /// No description provided for @searchPerson.
  ///
  /// In tr, this message translates to:
  /// **'Kişi'**
  String get searchPerson;

  /// No description provided for @searchClassYear.
  ///
  /// In tr, this message translates to:
  /// **'{n}. sınıf'**
  String searchClassYear(String n);

  /// No description provided for @searchUserDefault.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get searchUserDefault;

  /// No description provided for @searchHint.
  ///
  /// In tr, this message translates to:
  /// **'Haber, kulüp, etkinlik, gönderi, kişi ara'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı temizle'**
  String get searchClear;

  /// No description provided for @searchPrompt.
  ///
  /// In tr, this message translates to:
  /// **'Haber, duyuru, kulüp, etkinlik veya kişi aramak için en az 2 karakter yazın.'**
  String get searchPrompt;

  /// No description provided for @searchRecent.
  ///
  /// In tr, this message translates to:
  /// **'SON ARAMALAR'**
  String get searchRecent;

  /// No description provided for @searchClearRecent.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get searchClearRecent;

  /// No description provided for @searchNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı.'**
  String get searchNoResults;

  /// No description provided for @searchResultCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} SONUÇ'**
  String searchResultCount(String count);

  /// No description provided for @searchTooMany.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla istek gönderildi, birkaç saniye bekleyin.'**
  String get searchTooMany;

  /// No description provided for @followButtonUnfollow.
  ///
  /// In tr, this message translates to:
  /// **'Takipten çık'**
  String get followButtonUnfollow;

  /// No description provided for @followButtonFollow.
  ///
  /// In tr, this message translates to:
  /// **'Takip et'**
  String get followButtonFollow;

  /// No description provided for @followButtonFollowing.
  ///
  /// In tr, this message translates to:
  /// **'Takipte'**
  String get followButtonFollowing;

  /// No description provided for @followersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Takipçiler'**
  String get followersTitle;

  /// No description provided for @followingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Takip edilenler'**
  String get followingTitle;

  /// No description provided for @followersEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz takipçi yok.'**
  String get followersEmpty;

  /// No description provided for @followingEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kimse takip edilmiyor.'**
  String get followingEmpty;

  /// No description provided for @followSuggestionsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Şimdilik önerilecek kişi yok.'**
  String get followSuggestionsEmpty;

  /// No description provided for @followSuggestionsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Önerilen kişiler'**
  String get followSuggestionsTitle;

  /// No description provided for @followFeedHint.
  ///
  /// In tr, this message translates to:
  /// **'Takip ettiklerinin gönderileri burada görünür.'**
  String get followFeedHint;

  /// No description provided for @followersCount.
  ///
  /// In tr, this message translates to:
  /// **'Takipçi'**
  String get followersCount;

  /// No description provided for @followingCount.
  ///
  /// In tr, this message translates to:
  /// **'Takip'**
  String get followingCount;

  /// No description provided for @qrScanTitle.
  ///
  /// In tr, this message translates to:
  /// **'QR kodu tara'**
  String get qrScanTitle;

  /// No description provided for @qrCameraRationale.
  ///
  /// In tr, this message translates to:
  /// **'QR kodu okutabilmek için kameraya erişmemiz gerekir.'**
  String get qrCameraRationale;

  /// No description provided for @qrManualLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kodu elle gir'**
  String get qrManualLabel;

  /// No description provided for @qrConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get qrConfirm;

  /// No description provided for @qrCameraDenied.
  ///
  /// In tr, this message translates to:
  /// **'Kamera izni verilmedi. Kodu elle girebilir ya da izin verip taramayı yeniden deneyebilirsiniz.'**
  String get qrCameraDenied;

  /// No description provided for @qrGrantCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera izni ver'**
  String get qrGrantCamera;

  /// No description provided for @qrDeniedSettings.
  ///
  /// In tr, this message translates to:
  /// **'Kamera izni verilmedi. Ayarlar > BÜ Kampüs bölümünden izin verebilir ya da kodu elle girebilirsiniz.'**
  String get qrDeniedSettings;

  /// No description provided for @qrCameraFailed.
  ///
  /// In tr, this message translates to:
  /// **'Kamera açılamadı. Kodu elle girebilirsiniz.'**
  String get qrCameraFailed;

  /// No description provided for @qrTorch.
  ///
  /// In tr, this message translates to:
  /// **'El feneri'**
  String get qrTorch;

  /// No description provided for @pollListTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get pollListTitle;

  /// No description provided for @pollClubPolls.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp anketleri'**
  String get pollClubPolls;

  /// No description provided for @pollTabOpen.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get pollTabOpen;

  /// No description provided for @pollTabMine.
  ///
  /// In tr, this message translates to:
  /// **'Katıldıklarım'**
  String get pollTabMine;

  /// No description provided for @pollTabClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapanan'**
  String get pollTabClosed;

  /// No description provided for @pollEmptyOpen.
  ///
  /// In tr, this message translates to:
  /// **'Şu an açık anket yok.'**
  String get pollEmptyOpen;

  /// No description provided for @pollEmptyMine.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir ankete katılmadınız.'**
  String get pollEmptyMine;

  /// No description provided for @pollEmptyClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapanan anket yok.'**
  String get pollEmptyClosed;

  /// No description provided for @pollLoadFailedRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi, tekrar dene'**
  String get pollLoadFailedRetry;

  /// No description provided for @pollCreate.
  ///
  /// In tr, this message translates to:
  /// **'Anket oluştur'**
  String get pollCreate;

  /// No description provided for @pollClubEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulübün anketi yok.'**
  String get pollClubEmpty;

  /// No description provided for @pollSeeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tüm anketleri gör'**
  String get pollSeeAll;

  /// No description provided for @pollMenuRateToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün menüsünü puanla'**
  String get pollMenuRateToday;

  /// No description provided for @pollYourRating.
  ///
  /// In tr, this message translates to:
  /// **'Puanınız: {rating}'**
  String pollYourRating(String rating);

  /// No description provided for @pollYourRatingAvg.
  ///
  /// In tr, this message translates to:
  /// **'Puanınız: {rating} · Ortalama {avg}'**
  String pollYourRatingAvg(String rating, String avg);

  /// No description provided for @pollTapStar.
  ///
  /// In tr, this message translates to:
  /// **'Yıldıza dokunarak puanla'**
  String get pollTapStar;

  /// No description provided for @pollNoVoteRight.
  ///
  /// In tr, this message translates to:
  /// **'Bu anket için oy hakkınız yok'**
  String get pollNoVoteRight;

  /// No description provided for @pollStars.
  ///
  /// In tr, this message translates to:
  /// **'{n} yıldız'**
  String pollStars(String n);

  /// No description provided for @pollSemPercent.
  ///
  /// In tr, this message translates to:
  /// **'{text}, yüzde {pct}'**
  String pollSemPercent(String text, String pct);

  /// No description provided for @pollVotes.
  ///
  /// In tr, this message translates to:
  /// **'{votes} oy'**
  String pollVotes(String votes);

  /// No description provided for @pollVotesWithScore.
  ///
  /// In tr, this message translates to:
  /// **'{votes} oy · {score} puan'**
  String pollVotesWithScore(String votes, String score);

  /// No description provided for @pollSemMine.
  ///
  /// In tr, this message translates to:
  /// **'seçiminiz'**
  String get pollSemMine;

  /// No description provided for @pollTypeSingle.
  ///
  /// In tr, this message translates to:
  /// **'Tek seçim'**
  String get pollTypeSingle;

  /// No description provided for @pollTypeMulti.
  ///
  /// In tr, this message translates to:
  /// **'Çoklu seçim'**
  String get pollTypeMulti;

  /// No description provided for @pollTypeRating.
  ///
  /// In tr, this message translates to:
  /// **'Puanlama'**
  String get pollTypeRating;

  /// No description provided for @pollTypeRanked.
  ///
  /// In tr, this message translates to:
  /// **'Sıralı seçim'**
  String get pollTypeRanked;

  /// No description provided for @pollAnonymous.
  ///
  /// In tr, this message translates to:
  /// **'Gizli oy'**
  String get pollAnonymous;

  /// No description provided for @pollVotedBadge.
  ///
  /// In tr, this message translates to:
  /// **'Oy verdiniz'**
  String get pollVotedBadge;

  /// No description provided for @pollClosedBadge.
  ///
  /// In tr, this message translates to:
  /// **'Kapandı'**
  String get pollClosedBadge;

  /// No description provided for @pollParticipants.
  ///
  /// In tr, this message translates to:
  /// **'{n} katılım'**
  String pollParticipants(String n);

  /// No description provided for @pollParticipationOf.
  ///
  /// In tr, this message translates to:
  /// **'{v} / {e} katılım'**
  String pollParticipationOf(String v, String e);

  /// No description provided for @pollSemPoll.
  ///
  /// In tr, this message translates to:
  /// **'Anket: {title}'**
  String pollSemPoll(String title);

  /// No description provided for @pollEnded.
  ///
  /// In tr, this message translates to:
  /// **'Sona erdi'**
  String get pollEnded;

  /// No description provided for @pollDaysLeft.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün kaldı'**
  String pollDaysLeft(String n);

  /// No description provided for @pollHoursLeft.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa kaldı'**
  String pollHoursLeft(String n);

  /// No description provided for @pollMinutesLeft.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk kaldı'**
  String pollMinutesLeft(String n);

  /// No description provided for @pollBlockedNotEligible.
  ///
  /// In tr, this message translates to:
  /// **'Bu ankete katılma yetkiniz yok.'**
  String get pollBlockedNotEligible;

  /// No description provided for @pollBlockedClosed.
  ///
  /// In tr, this message translates to:
  /// **'Bu anket kapandı. Oy verilemez.'**
  String get pollBlockedClosed;

  /// No description provided for @pollBlockedNotOpen.
  ///
  /// In tr, this message translates to:
  /// **'Bu anket henüz açılmadı.'**
  String get pollBlockedNotOpen;

  /// No description provided for @pollBlockedAlreadyVoted.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz kaydedildi; bu ankette oy değiştirilemez.'**
  String get pollBlockedAlreadyVoted;

  /// No description provided for @pollBlockedDefault.
  ///
  /// In tr, this message translates to:
  /// **'Bu ankette oy veremezsiniz.'**
  String get pollBlockedDefault;

  /// No description provided for @pollValTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık gerekli.'**
  String get pollValTitle;

  /// No description provided for @pollValMin2.
  ///
  /// In tr, this message translates to:
  /// **'En az 2 seçenek girin.'**
  String get pollValMin2;

  /// No description provided for @pollValMax12.
  ///
  /// In tr, this message translates to:
  /// **'En fazla 12 seçenek olabilir.'**
  String get pollValMax12;

  /// No description provided for @pollValDistinct.
  ///
  /// In tr, this message translates to:
  /// **'Seçenekler birbirinden farklı olmalı.'**
  String get pollValDistinct;

  /// No description provided for @pollValEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş zamanını seçin.'**
  String get pollValEnd;

  /// No description provided for @pollValFuture.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş zamanı gelecekte olmalı.'**
  String get pollValFuture;

  /// No description provided for @pollErrClosed.
  ///
  /// In tr, this message translates to:
  /// **'Bu anket kapandı.'**
  String get pollErrClosed;

  /// No description provided for @pollErrAlreadyVoted.
  ///
  /// In tr, this message translates to:
  /// **'Bu ankete zaten oy verdiniz.'**
  String get pollErrAlreadyVoted;

  /// No description provided for @pollErrForbidden.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem için yetkiniz yok.'**
  String get pollErrForbidden;

  /// No description provided for @pollErrNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Anket bulunamadı.'**
  String get pollErrNotFound;

  /// No description provided for @pollErrInvalidVote.
  ///
  /// In tr, this message translates to:
  /// **'Geçersiz seçim.'**
  String get pollErrInvalidVote;

  /// No description provided for @pollHeader.
  ///
  /// In tr, this message translates to:
  /// **'Anket'**
  String get pollHeader;

  /// No description provided for @pollStale.
  ///
  /// In tr, this message translates to:
  /// **'Güncellenemedi; son bilinen veri gösteriliyor.'**
  String get pollStale;

  /// No description provided for @pollVoteSaved.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz kaydedildi.'**
  String get pollVoteSaved;

  /// No description provided for @pollVoteRetracted.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz geri çekildi.'**
  String get pollVoteRetracted;

  /// No description provided for @pollRetractTitle.
  ///
  /// In tr, this message translates to:
  /// **'Oyu geri çek'**
  String get pollRetractTitle;

  /// No description provided for @pollRetractBody.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz silinecek. Devam edilsin mi?'**
  String get pollRetractBody;

  /// No description provided for @pollCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get pollCancel;

  /// No description provided for @pollRetractAction.
  ///
  /// In tr, this message translates to:
  /// **'Geri çek'**
  String get pollRetractAction;

  /// No description provided for @pollMaxChoicesSnack.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {n} seçenek işaretleyebilirsiniz.'**
  String pollMaxChoicesSnack(String n);

  /// No description provided for @pollSecretVote.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz gizlidir'**
  String get pollSecretVote;

  /// No description provided for @pollResultsAfterClose.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar anket kapanınca görünecek.'**
  String get pollResultsAfterClose;

  /// No description provided for @pollHintRanked.
  ///
  /// In tr, this message translates to:
  /// **'Tercih sırasına göre dokunun: ilk dokunduğunuz en çok tercih ettiğinizdir.'**
  String get pollHintRanked;

  /// No description provided for @pollHintMax.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {n} seçenek işaretleyin.'**
  String pollHintMax(String n);

  /// No description provided for @pollHintMulti.
  ///
  /// In tr, this message translates to:
  /// **'Birden fazla seçenek işaretleyebilirsiniz.'**
  String get pollHintMulti;

  /// No description provided for @pollVoteUpdate.
  ///
  /// In tr, this message translates to:
  /// **'Oyu güncelle'**
  String get pollVoteUpdate;

  /// No description provided for @pollVote.
  ///
  /// In tr, this message translates to:
  /// **'Oy ver'**
  String get pollVote;

  /// No description provided for @pollChangeVote.
  ///
  /// In tr, this message translates to:
  /// **'Oyu değiştir'**
  String get pollChangeVote;

  /// No description provided for @pollRatingCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} puan'**
  String pollRatingCount(String n);

  /// No description provided for @pollFieldTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get pollFieldTitle;

  /// No description provided for @pollTitleHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. Yeni dönem başkanı seçimi'**
  String get pollTitleHint;

  /// No description provided for @pollFieldDesc.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama (isteğe bağlı)'**
  String get pollFieldDesc;

  /// No description provided for @pollDescHint.
  ///
  /// In tr, this message translates to:
  /// **'Kısa bir açıklama'**
  String get pollDescHint;

  /// No description provided for @pollFieldType.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get pollFieldType;

  /// No description provided for @pollFieldOptions.
  ///
  /// In tr, this message translates to:
  /// **'Seçenekler (2-{max})'**
  String pollFieldOptions(String max);

  /// No description provided for @pollOptionHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçenek {n}'**
  String pollOptionHint(String n);

  /// No description provided for @pollRemoveOption.
  ///
  /// In tr, this message translates to:
  /// **'Seçeneği sil'**
  String get pollRemoveOption;

  /// No description provided for @pollAddOption.
  ///
  /// In tr, this message translates to:
  /// **'Seçenek ekle'**
  String get pollAddOption;

  /// No description provided for @pollAnonymousSub.
  ///
  /// In tr, this message translates to:
  /// **'Kimin ne oy verdiği kimseye gösterilmez.'**
  String get pollAnonymousSub;

  /// No description provided for @pollFieldEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş zamanı'**
  String get pollFieldEnd;

  /// No description provided for @pollDurDays.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün'**
  String pollDurDays(String n);

  /// No description provided for @pollPickDateTime.
  ///
  /// In tr, this message translates to:
  /// **'Tarih ve saat seç'**
  String get pollPickDateTime;

  /// No description provided for @pollChange.
  ///
  /// In tr, this message translates to:
  /// **'Değiştir'**
  String get pollChange;

  /// No description provided for @pollPublish.
  ///
  /// In tr, this message translates to:
  /// **'Yayınla'**
  String get pollPublish;

  /// No description provided for @postComposeErrBadResponse.
  ///
  /// In tr, this message translates to:
  /// **'Sunucudan beklenmeyen yanıt.'**
  String get postComposeErrBadResponse;

  /// No description provided for @postComposeErrPrepare.
  ///
  /// In tr, this message translates to:
  /// **'Medya hazırlanamadı.'**
  String get postComposeErrPrepare;

  /// No description provided for @postComposeErrImageTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Görsel çok büyük.'**
  String get postComposeErrImageTooLarge;

  /// No description provided for @postComposeErrImageUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu görsel biçimi desteklenmiyor.'**
  String get postComposeErrImageUnsupported;

  /// No description provided for @postComposeErrImageUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Görsel okunamadı.'**
  String get postComposeErrImageUnreadable;

  /// No description provided for @postComposeErrNetwork.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok, tekrar dene.'**
  String get postComposeErrNetwork;

  /// No description provided for @postComposeErrVideoTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Video çok büyük (en fazla 40 MB).'**
  String get postComposeErrVideoTooLarge;

  /// No description provided for @postComposeErrVideoTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Video en fazla 60 saniye olabilir.'**
  String get postComposeErrVideoTooLong;

  /// No description provided for @postComposeErrVideoInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Video biçimi desteklenmiyor.'**
  String get postComposeErrVideoInvalid;

  /// No description provided for @postComposeErrBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Bu içerik paylaşılamaz.'**
  String get postComposeErrBlocked;

  /// No description provided for @postComposeErrMediaInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Medya geçersiz, yeniden yükle.'**
  String get postComposeErrMediaInvalid;

  /// No description provided for @postComposeErrProfanity.
  ///
  /// In tr, this message translates to:
  /// **'Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin.'**
  String get postComposeErrProfanity;

  /// No description provided for @postComposeErrRate.
  ///
  /// In tr, this message translates to:
  /// **'Çok hızlı paylaşım yapıyorsun, biraz bekle.'**
  String get postComposeErrRate;

  /// No description provided for @postComposeErrFileTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Dosya çok büyük.'**
  String get postComposeErrFileTooLarge;

  /// No description provided for @postComposeErrGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Bir sorun oluştu, tekrar dene.'**
  String get postComposeErrGeneric;

  /// No description provided for @postComposeErrVideoUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda video hazırlanamıyor.'**
  String get postComposeErrVideoUnsupported;

  /// No description provided for @postComposeErrCancelled.
  ///
  /// In tr, this message translates to:
  /// **'İptal edildi.'**
  String get postComposeErrCancelled;

  /// No description provided for @postComposeErrVideoFailed.
  ///
  /// In tr, this message translates to:
  /// **'Video hazırlanamadı.'**
  String get postComposeErrVideoFailed;

  /// No description provided for @postComposeEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get postComposeEdit;

  /// No description provided for @postComposeDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get postComposeDelete;

  /// No description provided for @postComposeViewProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profili gör'**
  String get postComposeViewProfile;

  /// No description provided for @postComposeReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get postComposeReport;

  /// No description provided for @postComposeBlockUser.
  ///
  /// In tr, this message translates to:
  /// **'Bu kullanıcıyı engelle'**
  String get postComposeBlockUser;

  /// No description provided for @postComposeClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get postComposeClose;

  /// No description provided for @postComposeReportTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi şikâyet et'**
  String get postComposeReportTitle;

  /// No description provided for @postComposeDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi silinsin mi?'**
  String get postComposeDeleteTitle;

  /// No description provided for @postComposeDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz.'**
  String get postComposeDeleteBody;

  /// No description provided for @postComposeCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get postComposeCancel;

  /// No description provided for @postComposeDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi silindi'**
  String get postComposeDeleted;

  /// No description provided for @postComposeBlockTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellensin mi?'**
  String get postComposeBlockTitle;

  /// No description provided for @postComposeBlockBody.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğiniz kişinin gönderilerini görmezsiniz ve onunla mesajlaşamazsınız.'**
  String get postComposeBlockBody;

  /// No description provided for @postComposeBlock.
  ///
  /// In tr, this message translates to:
  /// **'Engelle'**
  String get postComposeBlock;

  /// No description provided for @postComposeBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellendi'**
  String get postComposeBlocked;

  /// No description provided for @postComposeEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi düzenle'**
  String get postComposeEditTitle;

  /// No description provided for @postComposeTextEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Metin boş olamaz.'**
  String get postComposeTextEmpty;

  /// No description provided for @postComposeProfanityFallback.
  ///
  /// In tr, this message translates to:
  /// **'Metin uygunsuz ifadeler içeriyor.'**
  String get postComposeProfanityFallback;

  /// No description provided for @postComposeHint.
  ///
  /// In tr, this message translates to:
  /// **'Ne düşünüyorsun?'**
  String get postComposeHint;

  /// No description provided for @postComposeSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get postComposeSave;

  /// No description provided for @postComposeMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla'**
  String get postComposeMore;

  /// No description provided for @postComposeMaxMedia.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {max} medya ekleyebilirsin'**
  String postComposeMaxMedia(String max);

  /// No description provided for @postComposeFailedCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} medya yüklenemedi. Yeniden deneyebilir ya da çıkarabilirsin.'**
  String postComposeFailedCount(String count);

  /// No description provided for @postComposeInvalidRetry.
  ///
  /// In tr, this message translates to:
  /// **'Medya geçersiz, yeniden yüklenecek. Paylaş düğmesine tekrar dokun.'**
  String get postComposeInvalidRetry;

  /// No description provided for @postComposeNetworkDraftKept.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok. Taslağın korundu, tekrar dene.'**
  String get postComposeNetworkDraftKept;

  /// No description provided for @postComposeShared.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşıldı'**
  String get postComposeShared;

  /// No description provided for @postComposeDiscardTitle.
  ///
  /// In tr, this message translates to:
  /// **'Taslağı silmek istiyor musun?'**
  String get postComposeDiscardTitle;

  /// No description provided for @postComposeDiscardBody.
  ///
  /// In tr, this message translates to:
  /// **'Yazdıkların ve seçtiğin medya silinecek.'**
  String get postComposeDiscardBody;

  /// No description provided for @postComposeContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get postComposeContinue;

  /// No description provided for @postComposeDiscardDraft.
  ///
  /// In tr, this message translates to:
  /// **'Taslağı sil'**
  String get postComposeDiscardDraft;

  /// No description provided for @postComposeNewPost.
  ///
  /// In tr, this message translates to:
  /// **'Yeni gönderi'**
  String get postComposeNewPost;

  /// No description provided for @postComposeShare.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get postComposeShare;

  /// No description provided for @postComposeDraftBanner.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı bir taslağın var.'**
  String get postComposeDraftBanner;

  /// No description provided for @postComposeRestoreDraft.
  ///
  /// In tr, this message translates to:
  /// **'Taslağı geri yükle'**
  String get postComposeRestoreDraft;

  /// No description provided for @postComposeRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get postComposeRetry;

  /// No description provided for @postComposeRemoveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Başarısızları çıkar'**
  String get postComposeRemoveFailed;

  /// No description provided for @postComposeRemove.
  ///
  /// In tr, this message translates to:
  /// **'Çıkar'**
  String get postComposeRemove;

  /// No description provided for @postComposeGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeri'**
  String get postComposeGallery;

  /// No description provided for @postComposeCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get postComposeCamera;

  /// No description provided for @postComposeSaveUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda desteklenmiyor.'**
  String get postComposeSaveUnsupported;

  /// No description provided for @postComposeSaveDenied.
  ///
  /// In tr, this message translates to:
  /// **'Galeri izni verilmedi.'**
  String get postComposeSaveDenied;

  /// No description provided for @postComposeSaveNoSpace.
  ///
  /// In tr, this message translates to:
  /// **'Cihazda yeterli alan yok.'**
  String get postComposeSaveNoSpace;

  /// No description provided for @postComposeImageSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel kaydedilemedi.'**
  String get postComposeImageSaveFailed;

  /// No description provided for @postComposeSavedToGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriye kaydedildi'**
  String get postComposeSavedToGallery;

  /// No description provided for @postComposeDownload.
  ///
  /// In tr, this message translates to:
  /// **'İndir'**
  String get postComposeDownload;

  /// No description provided for @postComposeImageLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Görsel yüklenemedi.'**
  String get postComposeImageLoadFailed;

  /// No description provided for @postComposeVideoPlayFailed.
  ///
  /// In tr, this message translates to:
  /// **'Video oynatılamadı'**
  String get postComposeVideoPlayFailed;

  /// No description provided for @postComposeVideoOf.
  ///
  /// In tr, this message translates to:
  /// **'Video {n} / {total}'**
  String postComposeVideoOf(String n, String total);

  /// No description provided for @postComposePhotoOf.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf {n} / {total}'**
  String postComposePhotoOf(String n, String total);

  /// No description provided for @postComposeVideoOfMore.
  ///
  /// In tr, this message translates to:
  /// **'Video {n} / {total}, +{more} daha'**
  String postComposeVideoOfMore(String n, String total, String more);

  /// No description provided for @postComposePhotoOfMore.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf {n} / {total}, +{more} daha'**
  String postComposePhotoOfMore(String n, String total, String more);

  /// No description provided for @postComposeVideo.
  ///
  /// In tr, this message translates to:
  /// **'Video'**
  String get postComposeVideo;

  /// No description provided for @postComposePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get postComposePhoto;

  /// No description provided for @postComposePlayVideo.
  ///
  /// In tr, this message translates to:
  /// **'Videoyu oynat'**
  String get postComposePlayVideo;

  /// No description provided for @postComposeUnmute.
  ///
  /// In tr, this message translates to:
  /// **'Sesi aç'**
  String get postComposeUnmute;

  /// No description provided for @postComposeMute.
  ///
  /// In tr, this message translates to:
  /// **'Sesi kapat'**
  String get postComposeMute;

  /// No description provided for @postComposeMentionAdd.
  ///
  /// In tr, this message translates to:
  /// **'Anma ekle {name}'**
  String postComposeMentionAdd(String name);

  /// No description provided for @postComposeTagAdd.
  ///
  /// In tr, this message translates to:
  /// **'Etiket ekle {tag}'**
  String postComposeTagAdd(String tag);

  /// No description provided for @postComposePostCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} gönderi'**
  String postComposePostCount(String count);

  /// No description provided for @postComposeUserLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı {name}'**
  String postComposeUserLabel(String name);

  /// No description provided for @postComposeTagLabel.
  ///
  /// In tr, this message translates to:
  /// **'Etiket {tag}'**
  String postComposeTagLabel(String tag);

  /// No description provided for @postComposeTagLabelCount.
  ///
  /// In tr, this message translates to:
  /// **'Etiket {tag}, {count} gönderi'**
  String postComposeTagLabelCount(String tag, String count);

  /// No description provided for @postViewReplyingTo.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtlıyor: @{name}'**
  String postViewReplyingTo(String name);

  /// No description provided for @postViewCancelReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtı iptal et'**
  String get postViewCancelReply;

  /// No description provided for @postViewWriteReplyHint.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtını yaz…'**
  String get postViewWriteReplyHint;

  /// No description provided for @postViewWriteCommentHint.
  ///
  /// In tr, this message translates to:
  /// **'Yorum yaz…'**
  String get postViewWriteCommentHint;

  /// No description provided for @postViewSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get postViewSend;

  /// No description provided for @postViewAgoNow.
  ///
  /// In tr, this message translates to:
  /// **'şimdi'**
  String get postViewAgoNow;

  /// No description provided for @postViewAgoMin.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk'**
  String postViewAgoMin(String n);

  /// No description provided for @postViewAgoHour.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa'**
  String postViewAgoHour(String n);

  /// No description provided for @postViewAgoDay.
  ///
  /// In tr, this message translates to:
  /// **'{n} g'**
  String postViewAgoDay(String n);

  /// No description provided for @postViewAgoWeek.
  ///
  /// In tr, this message translates to:
  /// **'{n} hf'**
  String postViewAgoWeek(String n);

  /// No description provided for @postViewAgoYear.
  ///
  /// In tr, this message translates to:
  /// **'{n} y'**
  String postViewAgoYear(String n);

  /// No description provided for @postViewAgoMinFull.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk önce'**
  String postViewAgoMinFull(String n);

  /// No description provided for @postViewAgoHourFull.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa önce'**
  String postViewAgoHourFull(String n);

  /// No description provided for @postViewAgoDayFull.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün önce'**
  String postViewAgoDayFull(String n);

  /// No description provided for @postViewRepliesLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtlar yüklenemedi · Yeniden dene'**
  String get postViewRepliesLoadFailed;

  /// No description provided for @postViewShowReplies.
  ///
  /// In tr, this message translates to:
  /// **'{n} yanıtı göster'**
  String postViewShowReplies(String n);

  /// No description provided for @postViewShowMoreReplies.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla yanıt göster'**
  String get postViewShowMoreReplies;

  /// No description provided for @postViewHideReplies.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtları gizle'**
  String get postViewHideReplies;

  /// No description provided for @postViewCommentsLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yorumlar yüklenemedi · Yeniden dene'**
  String get postViewCommentsLoadFailed;

  /// No description provided for @postViewCommentsLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yorumlar yükleniyor'**
  String get postViewCommentsLoading;

  /// No description provided for @postViewEdit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get postViewEdit;

  /// No description provided for @postViewDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get postViewDelete;

  /// No description provided for @postViewReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get postViewReport;

  /// No description provided for @postViewReportComment.
  ///
  /// In tr, this message translates to:
  /// **'Yorumu şikâyet et'**
  String get postViewReportComment;

  /// No description provided for @postViewDeleteCommentTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yorum silinsin mi?'**
  String get postViewDeleteCommentTitle;

  /// No description provided for @postViewCannotUndo.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz.'**
  String get postViewCannotUndo;

  /// No description provided for @postViewCancelAction.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get postViewCancelAction;

  /// No description provided for @postViewCommentDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Bu yorum silindi'**
  String get postViewCommentDeleted;

  /// No description provided for @postViewEdited.
  ///
  /// In tr, this message translates to:
  /// **'düzenlendi'**
  String get postViewEdited;

  /// No description provided for @postViewProfileOf.
  ///
  /// In tr, this message translates to:
  /// **'{name} profili'**
  String postViewProfileOf(String name);

  /// No description provided for @postViewSendFailedRetryA11y.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi, yeniden dene'**
  String get postViewSendFailedRetryA11y;

  /// No description provided for @postViewSendFailedRetry.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi · Yeniden dene'**
  String get postViewSendFailedRetry;

  /// No description provided for @postViewRemove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get postViewRemove;

  /// No description provided for @postViewSending.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor…'**
  String get postViewSending;

  /// No description provided for @postViewReplyToA11y.
  ///
  /// In tr, this message translates to:
  /// **'{name} kişisine yanıt ver'**
  String postViewReplyToA11y(String name);

  /// No description provided for @postViewReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtla'**
  String get postViewReply;

  /// No description provided for @postViewCommentOptions.
  ///
  /// In tr, this message translates to:
  /// **'Yorum seçenekleri'**
  String get postViewCommentOptions;

  /// No description provided for @postViewEditCommentHint.
  ///
  /// In tr, this message translates to:
  /// **'Yorumu düzenle'**
  String get postViewEditCommentHint;

  /// No description provided for @postViewCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get postViewCancel;

  /// No description provided for @postViewSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get postViewSave;

  /// No description provided for @postViewLikersWithCount.
  ///
  /// In tr, this message translates to:
  /// **'Beğenenler ({n})'**
  String postViewLikersWithCount(String n);

  /// No description provided for @postViewLikers.
  ///
  /// In tr, this message translates to:
  /// **'Beğenenler'**
  String get postViewLikers;

  /// No description provided for @postViewRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get postViewRetry;

  /// No description provided for @postViewNoLikers.
  ///
  /// In tr, this message translates to:
  /// **'Henüz beğenen yok'**
  String get postViewNoLikers;

  /// No description provided for @postViewUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get postViewUser;

  /// No description provided for @postViewLikeFailed.
  ///
  /// In tr, this message translates to:
  /// **'Beğeni kaydedilemedi'**
  String get postViewLikeFailed;

  /// No description provided for @postViewUnlike.
  ///
  /// In tr, this message translates to:
  /// **'Beğenmekten vazgeç'**
  String get postViewUnlike;

  /// No description provided for @postViewLike.
  ///
  /// In tr, this message translates to:
  /// **'Beğen'**
  String get postViewLike;

  /// No description provided for @postViewSavedAdded.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilenlere eklendi'**
  String get postViewSavedAdded;

  /// No description provided for @postViewSavedRemoved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilenlerden çıkarıldı'**
  String get postViewSavedRemoved;

  /// No description provided for @postViewUnsave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilenlerden çıkar'**
  String get postViewUnsave;

  /// No description provided for @postViewNoTagPosts.
  ///
  /// In tr, this message translates to:
  /// **'#{tag} etiketli gönderi yok.'**
  String postViewNoTagPosts(String tag);

  /// No description provided for @postViewSavedPostsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilen gönderiler'**
  String get postViewSavedPostsTitle;

  /// No description provided for @postViewNoSavedPosts.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kaydettiğin bir gönderi yok.'**
  String get postViewNoSavedPosts;

  /// No description provided for @postViewPosts.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiler'**
  String get postViewPosts;

  /// No description provided for @postViewSeeAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü gör'**
  String get postViewSeeAll;

  /// No description provided for @postViewPost.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi'**
  String get postViewPost;

  /// No description provided for @postViewMyPosts.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilerim'**
  String get postViewMyPosts;

  /// No description provided for @postViewNoPosts.
  ///
  /// In tr, this message translates to:
  /// **'Henüz gönderi yok'**
  String get postViewNoPosts;

  /// No description provided for @postViewReadMore.
  ///
  /// In tr, this message translates to:
  /// **'devamını oku'**
  String get postViewReadMore;

  /// No description provided for @postViewReportSent.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyetiniz iletildi.'**
  String get postViewReportSent;

  /// No description provided for @postViewMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla'**
  String get postViewMore;

  /// No description provided for @postViewFeedEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz gönderi yok. İlk gönderiyi sen paylaş!'**
  String get postViewFeedEmpty;

  /// No description provided for @postViewCommentsWithCount.
  ///
  /// In tr, this message translates to:
  /// **'Yorumlar ({n})'**
  String postViewCommentsWithCount(String n);

  /// No description provided for @postViewComments.
  ///
  /// In tr, this message translates to:
  /// **'Yorumlar'**
  String get postViewComments;

  /// No description provided for @postViewSortNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get postViewSortNew;

  /// No description provided for @postViewSortTop.
  ///
  /// In tr, this message translates to:
  /// **'Üst'**
  String get postViewSortTop;

  /// No description provided for @postViewFirstComment.
  ///
  /// In tr, this message translates to:
  /// **'İlk yorumu sen yaz'**
  String get postViewFirstComment;

  /// No description provided for @profileDeptRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bölümü seçin.'**
  String get profileDeptRequired;

  /// No description provided for @profileDiscardTitle.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklikler kaydedilmedi'**
  String get profileDiscardTitle;

  /// No description provided for @profileDiscardBody.
  ///
  /// In tr, this message translates to:
  /// **'Çıkarsanız yaptığınız değişiklikler kaybolacak.'**
  String get profileDiscardBody;

  /// No description provided for @profileKeepEditing.
  ///
  /// In tr, this message translates to:
  /// **'Düzenlemeye devam et'**
  String get profileKeepEditing;

  /// No description provided for @profileDiscardExit.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç ve çık'**
  String get profileDiscardExit;

  /// No description provided for @profileChangePhotoSemantic.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafını değiştir'**
  String get profileChangePhotoSemantic;

  /// No description provided for @profileUploading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor…'**
  String get profileUploading;

  /// No description provided for @profileChangePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı değiştir'**
  String get profileChangePhoto;

  /// No description provided for @profilePickGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get profilePickGallery;

  /// No description provided for @profileTakePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çek'**
  String get profileTakePhoto;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get profileRemovePhoto;

  /// No description provided for @profilePhotoTooLargeHint.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf en fazla 2 MB olabilir. Daha küçük bir fotoğraf seçin.'**
  String get profilePhotoTooLargeHint;

  /// No description provided for @profilePhotoUnsupported.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca JPG, PNG veya WebP fotoğraflar yüklenebilir.'**
  String get profilePhotoUnsupported;

  /// No description provided for @profilePhotoUnreadable.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen dosya okunamadı.'**
  String get profilePhotoUnreadable;

  /// No description provided for @profilePhotoTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf en fazla 2 MB olabilir.'**
  String get profilePhotoTooLarge;

  /// No description provided for @profileEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profili düzenle'**
  String get profileEditTitle;

  /// No description provided for @profileFullName.
  ///
  /// In tr, this message translates to:
  /// **'Ad soyad'**
  String get profileFullName;

  /// No description provided for @profileNameMin.
  ///
  /// In tr, this message translates to:
  /// **'Ad en az 2 karakter olmalı.'**
  String get profileNameMin;

  /// No description provided for @profileAbout.
  ///
  /// In tr, this message translates to:
  /// **'Hakkımda'**
  String get profileAbout;

  /// No description provided for @profileBioHint.
  ///
  /// In tr, this message translates to:
  /// **'Kendinizden kısaca bahsedin'**
  String get profileBioHint;

  /// No description provided for @profileShowEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-postamı diğer kullanıcılara göster'**
  String get profileShowEmail;

  /// No description provided for @profileSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get profileSave;

  /// No description provided for @profileUserDefault.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get profileUserDefault;

  /// No description provided for @profileGradeYear.
  ///
  /// In tr, this message translates to:
  /// **'{year}. sınıf'**
  String profileGradeYear(String year);

  /// No description provided for @profileBlockTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellensin mi?'**
  String get profileBlockTitle;

  /// No description provided for @profileBlockBody.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğiniz kişiyle mesajlaşamazsınız.'**
  String get profileBlockBody;

  /// No description provided for @profileCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get profileCancel;

  /// No description provided for @profileBlock.
  ///
  /// In tr, this message translates to:
  /// **'Engelle'**
  String get profileBlock;

  /// No description provided for @profileUnblock.
  ///
  /// In tr, this message translates to:
  /// **'Engeli kaldır'**
  String get profileUnblock;

  /// No description provided for @profileUnblocked.
  ///
  /// In tr, this message translates to:
  /// **'Engel kaldırıldı'**
  String get profileUnblocked;

  /// No description provided for @profileBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı engellendi'**
  String get profileBlocked;

  /// No description provided for @profileReportUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcıyı şikâyet et'**
  String get profileReportUser;

  /// No description provided for @profileOnline.
  ///
  /// In tr, this message translates to:
  /// **'Çevrimiçi'**
  String get profileOnline;

  /// No description provided for @profileLastSeenToday.
  ///
  /// In tr, this message translates to:
  /// **'Son görülme bugün {time}'**
  String profileLastSeenToday(String time);

  /// No description provided for @profileLastSeenYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Son görülme dün {time}'**
  String profileLastSeenYesterday(String time);

  /// No description provided for @profileLastSeenDate.
  ///
  /// In tr, this message translates to:
  /// **'Son görülme {date} {time}'**
  String profileLastSeenDate(String date, String time);

  /// No description provided for @profileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı bulunamadı'**
  String get profileNotFound;

  /// No description provided for @profileFaculty.
  ///
  /// In tr, this message translates to:
  /// **'Fakülte'**
  String get profileFaculty;

  /// No description provided for @profileDepartment.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm'**
  String get profileDepartment;

  /// No description provided for @profileGrade.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf'**
  String get profileGrade;

  /// No description provided for @profileEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get profileEmail;

  /// No description provided for @profileMessage.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj'**
  String get profileMessage;

  /// No description provided for @profileReport.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet et'**
  String get profileReport;

  /// No description provided for @profileAboutShort.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get profileAboutShort;

  /// No description provided for @profileSignOutTitle.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yapılsın mı?'**
  String get profileSignOutTitle;

  /// No description provided for @profileSignOutBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazdaki oturumunuz kapatılacak.'**
  String get profileSignOutBody;

  /// No description provided for @profileSignOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get profileSignOut;

  /// No description provided for @profileSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get profileSettings;

  /// No description provided for @profileStatClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get profileStatClubs;

  /// No description provided for @profileStatEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get profileStatEvents;

  /// No description provided for @profileStatSavedNews.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı haber'**
  String get profileStatSavedNews;

  /// No description provided for @profileMyPosts.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilerim'**
  String get profileMyPosts;

  /// No description provided for @profileSavedPosts.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilen gönderiler'**
  String get profileSavedPosts;

  /// No description provided for @profileSuggested.
  ///
  /// In tr, this message translates to:
  /// **'Önerilen kişiler'**
  String get profileSuggested;

  /// No description provided for @profileSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilenler'**
  String get profileSaved;

  /// No description provided for @profileAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Akademik'**
  String get profileAcademic;

  /// No description provided for @profileMyEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklerim'**
  String get profileMyEvents;

  /// No description provided for @profileMyClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüplerim'**
  String get profileMyClubs;

  /// No description provided for @profileReminders.
  ///
  /// In tr, this message translates to:
  /// **'Ders ve sınav hatırlatmaları'**
  String get profileReminders;

  /// No description provided for @profileSavedEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kaydettiğiniz bir haber yok. Haberlerdeki yer imi simgesine dokunun.'**
  String get profileSavedEmpty;

  /// No description provided for @profileRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get profileRetry;

  /// No description provided for @profileNewsCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} haber'**
  String profileNewsCount(String count);

  /// No description provided for @profileNewsCountMore.
  ///
  /// In tr, this message translates to:
  /// **'{count}+ haber'**
  String profileNewsCountMore(String count);

  /// No description provided for @profileLegalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşmeler'**
  String get profileLegalTitle;

  /// No description provided for @profileLegalEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Yayımlanmış sözleşme yok.'**
  String get profileLegalEmpty;

  /// No description provided for @profileLegalDocFallback.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşme'**
  String get profileLegalDocFallback;

  /// No description provided for @profileVersion.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version}'**
  String profileVersion(String version);

  /// No description provided for @profileVersionDate.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version} · {date}'**
  String profileVersionDate(String version, String date);

  /// No description provided for @profilePrefsDataCopied.
  ///
  /// In tr, this message translates to:
  /// **'Verileriniz panoya kopyalandı'**
  String get profilePrefsDataCopied;

  /// No description provided for @profilePrefsExportLimit.
  ///
  /// In tr, this message translates to:
  /// **'Günde en fazla 3 kez veri indirebilirsiniz.'**
  String get profilePrefsExportLimit;

  /// No description provided for @profilePrefsBlockedUsers.
  ///
  /// In tr, this message translates to:
  /// **'Engellenen kullanıcılar'**
  String get profilePrefsBlockedUsers;

  /// No description provided for @profilePrefsLegalPrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşmeler ve gizlilik'**
  String get profilePrefsLegalPrivacy;

  /// No description provided for @profilePrefsDownloadData.
  ///
  /// In tr, this message translates to:
  /// **'Verilerimi indir'**
  String get profilePrefsDownloadData;

  /// No description provided for @profilePrefsAccountMgmt.
  ///
  /// In tr, this message translates to:
  /// **'Hesap yönetimi'**
  String get profilePrefsAccountMgmt;

  /// No description provided for @profilePrefsDeleteMyAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı sil'**
  String get profilePrefsDeleteMyAccount;

  /// No description provided for @profilePrefsEnterPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifrenizi girin.'**
  String get profilePrefsEnterPassword;

  /// No description provided for @profilePrefsWrongPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre hatalı.'**
  String get profilePrefsWrongPassword;

  /// No description provided for @profilePrefsDeleteAccountTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabı sil'**
  String get profilePrefsDeleteAccountTitle;

  /// No description provided for @profilePrefsDeleteAccountBody.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınız ve kişisel verileriniz silinecek. Bu işlem geri alınamaz. Onaylamak için şifrenizi girin.'**
  String get profilePrefsDeleteAccountBody;

  /// No description provided for @profilePrefsPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get profilePrefsPassword;

  /// No description provided for @profilePrefsClubLeft.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpten ayrıldın.'**
  String get profilePrefsClubLeft;

  /// No description provided for @profilePrefsWithdrawTitle.
  ///
  /// In tr, this message translates to:
  /// **'İsteği geri çek'**
  String get profilePrefsWithdrawTitle;

  /// No description provided for @profilePrefsWithdrawBody.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteğiniz geri çekilsin mi?'**
  String get profilePrefsWithdrawBody;

  /// No description provided for @profilePrefsWithdrawConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Geri çek'**
  String get profilePrefsWithdrawConfirm;

  /// No description provided for @profilePrefsNoClubs.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir kulübe üye değilsiniz.'**
  String get profilePrefsNoClubs;

  /// No description provided for @profilePrefsClubsOwned.
  ///
  /// In tr, this message translates to:
  /// **'Kurduklarım'**
  String get profilePrefsClubsOwned;

  /// No description provided for @profilePrefsClubsMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye olduklarım'**
  String get profilePrefsClubsMember;

  /// No description provided for @profilePrefsClubsPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen başvurular'**
  String get profilePrefsClubsPending;

  /// No description provided for @profilePrefsMyClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüplerim'**
  String get profilePrefsMyClubs;

  /// No description provided for @profilePrefsCreateClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp kur'**
  String get profilePrefsCreateClub;

  /// No description provided for @profilePrefsMembersCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} üye'**
  String profilePrefsMembersCount(String count);

  /// No description provided for @profilePrefsAwaitingApproval.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get profilePrefsAwaitingApproval;

  /// No description provided for @profilePrefsAwaitingPublish.
  ///
  /// In tr, this message translates to:
  /// **'Yayın onayı bekleniyor'**
  String get profilePrefsAwaitingPublish;

  /// No description provided for @profilePrefsManage.
  ///
  /// In tr, this message translates to:
  /// **'Yönet'**
  String get profilePrefsManage;

  /// No description provided for @profilePrefsOptions.
  ///
  /// In tr, this message translates to:
  /// **'Seçenekler'**
  String get profilePrefsOptions;

  /// No description provided for @profilePrefsOpen.
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get profilePrefsOpen;

  /// No description provided for @profilePrefsManageEdit.
  ///
  /// In tr, this message translates to:
  /// **'Yönet: düzenle'**
  String get profilePrefsManageEdit;

  /// No description provided for @profilePrefsManageRequests.
  ///
  /// In tr, this message translates to:
  /// **'Yönet: başvurular'**
  String get profilePrefsManageRequests;

  /// No description provided for @profilePrefsManageMembers.
  ///
  /// In tr, this message translates to:
  /// **'Yönet: üyeler'**
  String get profilePrefsManageMembers;

  /// No description provided for @profilePrefsLeaveClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpten ayrıl'**
  String get profilePrefsLeaveClub;

  /// No description provided for @profilePrefsReminders.
  ///
  /// In tr, this message translates to:
  /// **'Ders ve sınav hatırlatmaları'**
  String get profilePrefsReminders;

  /// No description provided for @profilePrefsNotifNews.
  ///
  /// In tr, this message translates to:
  /// **'Haberler'**
  String get profilePrefsNotifNews;

  /// No description provided for @profilePrefsNotifAnnouncements.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get profilePrefsNotifAnnouncements;

  /// No description provided for @profilePrefsNotifEvents.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get profilePrefsNotifEvents;

  /// No description provided for @profilePrefsNotifCommunities.
  ///
  /// In tr, this message translates to:
  /// **'Topluluklar'**
  String get profilePrefsNotifCommunities;

  /// No description provided for @profilePrefsNotifMessages.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get profilePrefsNotifMessages;

  /// No description provided for @profilePrefsNotifPolls.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get profilePrefsNotifPolls;

  /// No description provided for @profilePrefsNotifAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Akademik duyurular'**
  String get profilePrefsNotifAcademic;

  /// No description provided for @profilePrefsNotifStories.
  ///
  /// In tr, this message translates to:
  /// **'Hikâyeler'**
  String get profilePrefsNotifStories;

  /// No description provided for @profilePrefsNotifMention.
  ///
  /// In tr, this message translates to:
  /// **'Etiketlenmeler'**
  String get profilePrefsNotifMention;

  /// No description provided for @profilePrefsNotifFollow.
  ///
  /// In tr, this message translates to:
  /// **'Yeni takipçiler'**
  String get profilePrefsNotifFollow;

  /// No description provided for @profilePrefsNotifLike.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi beğenileri'**
  String get profilePrefsNotifLike;

  /// No description provided for @profilePrefsNotifComment.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi yorumları'**
  String get profilePrefsNotifComment;

  /// No description provided for @profilePrefsNotifReply.
  ///
  /// In tr, this message translates to:
  /// **'Yorum yanıtları'**
  String get profilePrefsNotifReply;

  /// No description provided for @profilePrefsSocial.
  ///
  /// In tr, this message translates to:
  /// **'Sosyal'**
  String get profilePrefsSocial;

  /// No description provided for @profilePrefsOnThisDevice.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda'**
  String get profilePrefsOnThisDevice;

  /// No description provided for @profilePrefsTapToRetry.
  ///
  /// In tr, this message translates to:
  /// **'{error} Yeniden denemek için dokunun.'**
  String profilePrefsTapToRetry(String error);

  /// No description provided for @profilePrefsNotifTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get profilePrefsNotifTitle;

  /// No description provided for @profilePrefsNoBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğiniz kullanıcı yok.'**
  String get profilePrefsNoBlocked;

  /// No description provided for @profilePrefsUser.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get profilePrefsUser;

  /// No description provided for @profilePrefsUnblock.
  ///
  /// In tr, this message translates to:
  /// **'Engeli kaldır'**
  String get profilePrefsUnblock;

  /// No description provided for @profilePrefsBlockedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Engellenenler'**
  String get profilePrefsBlockedTitle;

  /// No description provided for @pickDepartment.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm'**
  String get pickDepartment;

  /// No description provided for @pickSelectDepartment.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm seçin'**
  String get pickSelectDepartment;

  /// No description provided for @pickLoading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor…'**
  String get pickLoading;

  /// No description provided for @pickListFailed.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm listesi yüklenemedi.'**
  String get pickListFailed;

  /// No description provided for @pickRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get pickRetry;

  /// No description provided for @pickGrade.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf'**
  String get pickGrade;

  /// No description provided for @pickSelectGrade.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf seçin'**
  String get pickSelectGrade;

  /// No description provided for @pickSearch.
  ///
  /// In tr, this message translates to:
  /// **'Ara'**
  String get pickSearch;

  /// No description provided for @pickNoResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı.'**
  String get pickNoResults;

  /// No description provided for @authStepOf.
  ///
  /// In tr, this message translates to:
  /// **'Adım {n}/{total}'**
  String authStepOf(String n, String total);

  /// No description provided for @authSectionPersonal.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel bilgiler'**
  String get authSectionPersonal;

  /// No description provided for @authSectionPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre belirleyin'**
  String get authSectionPassword;

  /// No description provided for @authHintAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Bölümünüzü ve sınıfınızı seçin.'**
  String get authHintAcademic;

  /// No description provided for @authHintPersonal.
  ///
  /// In tr, this message translates to:
  /// **'Adınızı ve okul e-postanızı girin.'**
  String get authHintPersonal;

  /// No description provided for @authHintPassword.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakterli bir şifre seçin.'**
  String get authHintPassword;

  /// No description provided for @authNext.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get authNext;

  /// No description provided for @authTermsAutoPrefix.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt olarak '**
  String get authTermsAutoPrefix;

  /// No description provided for @authTermsAutoSuffix.
  ///
  /// In tr, this message translates to:
  /// **' metinlerini kabul etmiş sayılırsınız.'**
  String get authTermsAutoSuffix;

  /// No description provided for @authPwMinErr.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 8 karakter olmalı.'**
  String get authPwMinErr;

  /// No description provided for @authPwMaxErr.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en çok 72 karakter olabilir.'**
  String get authPwMaxErr;

  /// No description provided for @authIdHelper.
  ///
  /// In tr, this message translates to:
  /// **'226051015 ya da ad.soyad@bingol.edu.tr'**
  String get authIdHelper;

  /// No description provided for @supportCatAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get supportCatAccount;

  /// No description provided for @supportCatTechnical.
  ///
  /// In tr, this message translates to:
  /// **'Teknik'**
  String get supportCatTechnical;

  /// No description provided for @supportCatContent.
  ///
  /// In tr, this message translates to:
  /// **'İçerik'**
  String get supportCatContent;

  /// No description provided for @supportCatOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get supportCatOther;

  /// No description provided for @supportFbBug.
  ///
  /// In tr, this message translates to:
  /// **'Hata'**
  String get supportFbBug;

  /// No description provided for @supportFbSuggestion.
  ///
  /// In tr, this message translates to:
  /// **'Öneri'**
  String get supportFbSuggestion;

  /// No description provided for @supportFbComplaint.
  ///
  /// In tr, this message translates to:
  /// **'Şikâyet'**
  String get supportFbComplaint;

  /// No description provided for @supportFbPraise.
  ///
  /// In tr, this message translates to:
  /// **'Teşekkür'**
  String get supportFbPraise;

  /// No description provided for @supportStNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get supportStNew;

  /// No description provided for @supportStInReview.
  ///
  /// In tr, this message translates to:
  /// **'İnceleniyor'**
  String get supportStInReview;

  /// No description provided for @supportStPlanned.
  ///
  /// In tr, this message translates to:
  /// **'Planlandı'**
  String get supportStPlanned;

  /// No description provided for @supportStDone.
  ///
  /// In tr, this message translates to:
  /// **'Tamamlandı'**
  String get supportStDone;

  /// No description provided for @supportStRejected.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get supportStRejected;

  /// No description provided for @supportStatusAnswered.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtlandı'**
  String get supportStatusAnswered;

  /// No description provided for @supportStatusClosed.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get supportStatusClosed;

  /// No description provided for @supportStatusOpen.
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get supportStatusOpen;

  /// No description provided for @supportTooManyRequests.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla istek gönderdiniz. Lütfen biraz bekleyip tekrar deneyin.'**
  String get supportTooManyRequests;

  /// No description provided for @supportLabelCategory.
  ///
  /// In tr, this message translates to:
  /// **'KATEGORİ'**
  String get supportLabelCategory;

  /// No description provided for @supportLabelSubject.
  ///
  /// In tr, this message translates to:
  /// **'KONU'**
  String get supportLabelSubject;

  /// No description provided for @supportLabelMessage.
  ///
  /// In tr, this message translates to:
  /// **'MESAJ'**
  String get supportLabelMessage;

  /// No description provided for @supportLabelMine.
  ///
  /// In tr, this message translates to:
  /// **'GÖNDERDİKLERİM'**
  String get supportLabelMine;

  /// No description provided for @supportHintSubject.
  ///
  /// In tr, this message translates to:
  /// **'Kısaca konu'**
  String get supportHintSubject;

  /// No description provided for @supportHintFeedback.
  ///
  /// In tr, this message translates to:
  /// **'Görüşünüzü yazın'**
  String get supportHintFeedback;

  /// No description provided for @supportHintIssue.
  ///
  /// In tr, this message translates to:
  /// **'Sorununuzu anlatın'**
  String get supportHintIssue;

  /// No description provided for @supportHintReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıt yazın'**
  String get supportHintReply;

  /// No description provided for @supportFillFields.
  ///
  /// In tr, this message translates to:
  /// **'Konu ve mesaj alanlarını doldurun.'**
  String get supportFillFields;

  /// No description provided for @supportFeedbackThanks.
  ///
  /// In tr, this message translates to:
  /// **'Geri bildiriminiz için teşekkürler.'**
  String get supportFeedbackThanks;

  /// No description provided for @supportFeedbackTitle.
  ///
  /// In tr, this message translates to:
  /// **'Geri bildirim'**
  String get supportFeedbackTitle;

  /// No description provided for @supportSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get supportSend;

  /// No description provided for @supportNoFeedback.
  ///
  /// In tr, this message translates to:
  /// **'Henüz geri bildirim göndermediniz.'**
  String get supportNoFeedback;

  /// No description provided for @supportMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla'**
  String get supportMore;

  /// No description provided for @supportTicketReceived.
  ///
  /// In tr, this message translates to:
  /// **'Destek talebiniz alındı.'**
  String get supportTicketReceived;

  /// No description provided for @supportNewTicketTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni talep'**
  String get supportNewTicketTitle;

  /// No description provided for @supportTitle.
  ///
  /// In tr, this message translates to:
  /// **'Destek'**
  String get supportTitle;

  /// No description provided for @supportFaqLabel.
  ///
  /// In tr, this message translates to:
  /// **'SIK SORULAN SORULAR'**
  String get supportFaqLabel;

  /// No description provided for @supportMyTickets.
  ///
  /// In tr, this message translates to:
  /// **'TALEPLERİM'**
  String get supportMyTickets;

  /// No description provided for @supportShareLabel.
  ///
  /// In tr, this message translates to:
  /// **'GÖRÜŞÜNÜZÜ PAYLAŞIN'**
  String get supportShareLabel;

  /// No description provided for @supportBoard.
  ///
  /// In tr, this message translates to:
  /// **'Öneri panosu'**
  String get supportBoard;

  /// No description provided for @supportCreateTicket.
  ///
  /// In tr, this message translates to:
  /// **'Destek talebi oluştur'**
  String get supportCreateTicket;

  /// No description provided for @supportNoFaq.
  ///
  /// In tr, this message translates to:
  /// **'Henüz sık sorulan soru yok.'**
  String get supportNoFaq;

  /// No description provided for @supportRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get supportRetry;

  /// No description provided for @supportNoTickets.
  ///
  /// In tr, this message translates to:
  /// **'Henüz destek talebiniz yok.'**
  String get supportNoTickets;

  /// No description provided for @supportSortTop.
  ///
  /// In tr, this message translates to:
  /// **'En çok oy'**
  String get supportSortTop;

  /// No description provided for @supportSortNew.
  ///
  /// In tr, this message translates to:
  /// **'En yeni'**
  String get supportSortNew;

  /// No description provided for @supportAddSuggestion.
  ///
  /// In tr, this message translates to:
  /// **'Öneri ekle'**
  String get supportAddSuggestion;

  /// No description provided for @supportNoSuggestions.
  ///
  /// In tr, this message translates to:
  /// **'Henüz yayımlanmış öneri yok. İlk öneriyi siz ekleyin.'**
  String get supportNoSuggestions;

  /// No description provided for @supportCloseTicketTitle.
  ///
  /// In tr, this message translates to:
  /// **'Talebi kapat'**
  String get supportCloseTicketTitle;

  /// No description provided for @supportCloseTicketBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu talep kapatılacak ve yeni yanıt yazamayacaksınız. Devam edilsin mi?'**
  String get supportCloseTicketBody;

  /// No description provided for @supportCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get supportCancel;

  /// No description provided for @supportClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get supportClose;

  /// No description provided for @supportTicketTitle.
  ///
  /// In tr, this message translates to:
  /// **'Talep'**
  String get supportTicketTitle;

  /// No description provided for @supportTicketClosedNote.
  ///
  /// In tr, this message translates to:
  /// **'Bu talep kapatıldı.'**
  String get supportTicketClosedNote;

  /// No description provided for @supportStaff.
  ///
  /// In tr, this message translates to:
  /// **'Destek ekibi'**
  String get supportStaff;

  /// No description provided for @storyVideoTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Hikâye videosu en fazla 30 saniye olabilir.'**
  String get storyVideoTooLong;

  /// No description provided for @storyCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hikâye oluştur'**
  String get storyCreateTitle;

  /// No description provided for @storyShare.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get storyShare;

  /// No description provided for @storyModeMedia.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf / Video'**
  String get storyModeMedia;

  /// No description provided for @storyModeText.
  ///
  /// In tr, this message translates to:
  /// **'Metin'**
  String get storyModeText;

  /// No description provided for @storyVisible24.
  ///
  /// In tr, this message translates to:
  /// **'Hikâyen 24 saat görünür'**
  String get storyVisible24;

  /// No description provided for @storyGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeri'**
  String get storyGallery;

  /// No description provided for @storyCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get storyCamera;

  /// No description provided for @storyCaptionHint.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama ekle…'**
  String get storyCaptionHint;

  /// No description provided for @storyTextHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler yaz…'**
  String get storyTextHint;

  /// No description provided for @storyBgColor.
  ///
  /// In tr, this message translates to:
  /// **'Arka plan rengi {n}'**
  String storyBgColor(String n);

  /// No description provided for @storyYours.
  ///
  /// In tr, this message translates to:
  /// **'Hikâyen'**
  String get storyYours;

  /// No description provided for @storyNewSemantics.
  ///
  /// In tr, this message translates to:
  /// **'{name}, yeni hikâye'**
  String storyNewSemantics(String name);

  /// No description provided for @storySemantics.
  ///
  /// In tr, this message translates to:
  /// **'{name}, hikâye'**
  String storySemantics(String name);

  /// No description provided for @storyDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hikâye silinsin mi?'**
  String get storyDeleteTitle;

  /// No description provided for @storyDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz.'**
  String get storyDeleteBody;

  /// No description provided for @storyCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get storyCancel;

  /// No description provided for @storyDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get storyDelete;

  /// No description provided for @storyRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get storyRetry;

  /// No description provided for @storyClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get storyClose;

  /// No description provided for @storyViewsSemantics.
  ///
  /// In tr, this message translates to:
  /// **'{count} görüntülenme, izleyenleri göster'**
  String storyViewsSemantics(String count);

  /// No description provided for @storyDeleteTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Hikâyeyi sil'**
  String get storyDeleteTooltip;

  /// No description provided for @storyBarSemantics.
  ///
  /// In tr, this message translates to:
  /// **'Hikâye {index} / {total}'**
  String storyBarSemantics(String index, String total);

  /// No description provided for @storyNoViewers.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kimse görüntülemedi.'**
  String get storyNoViewers;

  /// No description provided for @storyViewersTitle.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüleyenler ({count})'**
  String storyViewersTitle(String count);

  /// No description provided for @authForgotSub.
  ///
  /// In tr, this message translates to:
  /// **'Okul e-postanızı girin, size 6 haneli bir kod gönderelim.'**
  String get authForgotSub;

  /// No description provided for @authBackToLogin.
  ///
  /// In tr, this message translates to:
  /// **'Girişe dön'**
  String get authBackToLogin;

  /// No description provided for @authChangeEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-postayı değiştir'**
  String get authChangeEmail;

  /// No description provided for @authNewPwSub.
  ///
  /// In tr, this message translates to:
  /// **'Bu şifre eski şifrenizin yerine geçer. Tüm cihazlardaki oturumlar kapanır.'**
  String get authNewPwSub;

  /// No description provided for @authRuleLen.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter'**
  String get authRuleLen;

  /// No description provided for @authRuleMix.
  ///
  /// In tr, this message translates to:
  /// **'Harf ve rakam içerir'**
  String get authRuleMix;

  /// No description provided for @authStep1Title.
  ///
  /// In tr, this message translates to:
  /// **'Hangi bölümdesiniz?'**
  String get authStep1Title;

  /// No description provided for @authStep2Title.
  ///
  /// In tr, this message translates to:
  /// **'Sizi tanıyalım'**
  String get authStep2Title;

  /// No description provided for @welcomeHeadline.
  ///
  /// In tr, this message translates to:
  /// **'Kampüs artık\ncebinizde'**
  String get welcomeHeadline;

  /// No description provided for @welcomeSub.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular, yemek listesi, kulüpler ve etkinlikler tek uygulamada.'**
  String get welcomeSub;

  /// No description provided for @welcomeNews.
  ///
  /// In tr, this message translates to:
  /// **'Haberler ve duyurular'**
  String get welcomeNews;

  /// No description provided for @welcomeMenu.
  ///
  /// In tr, this message translates to:
  /// **'Günün yemek listesi'**
  String get welcomeMenu;

  /// No description provided for @welcomeClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpler ve etkinlikler'**
  String get welcomeClubs;

  /// No description provided for @welcomeNote.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca okul e-postası (bingol.edu.tr) ile kayıt olunabilir.'**
  String get welcomeNote;

  /// No description provided for @welcomeLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get welcomeLanguage;

  /// No description provided for @chatlistSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetlerde ara'**
  String get chatlistSearchHint;

  /// No description provided for @bildirimFilterAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get bildirimFilterAll;

  /// No description provided for @bildirimFilterUnread.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış'**
  String get bildirimFilterUnread;

  /// No description provided for @bildirimEmptyUnread.
  ///
  /// In tr, this message translates to:
  /// **'Okunmamış bildirimin yok'**
  String get bildirimEmptyUnread;

  /// No description provided for @bildirimAllCaughtUp.
  ///
  /// In tr, this message translates to:
  /// **'Hepsi bu kadar'**
  String get bildirimAllCaughtUp;

  /// No description provided for @bildirimSwipeHint.
  ///
  /// In tr, this message translates to:
  /// **'Silmek için bildirimi sola kaydır'**
  String get bildirimSwipeHint;

  /// No description provided for @bildirimDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get bildirimDelete;

  /// No description provided for @bildirimShortMin.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk'**
  String bildirimShortMin(String n);

  /// No description provided for @bildirimShortHour.
  ///
  /// In tr, this message translates to:
  /// **'{n} sa'**
  String bildirimShortHour(String n);

  /// No description provided for @bildirimShortDay.
  ///
  /// In tr, this message translates to:
  /// **'{n} g'**
  String bildirimShortDay(String n);

  /// No description provided for @bildirimYesterday.
  ///
  /// In tr, this message translates to:
  /// **'Dün'**
  String get bildirimYesterday;

  /// No description provided for @bildirimTypeNews.
  ///
  /// In tr, this message translates to:
  /// **'Haber'**
  String get bildirimTypeNews;

  /// No description provided for @bildirimTypeAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'Duyuru'**
  String get bildirimTypeAnnouncement;

  /// No description provided for @bildirimTypeEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik'**
  String get bildirimTypeEvent;

  /// No description provided for @bildirimTypeMessage.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet'**
  String get bildirimTypeMessage;

  /// No description provided for @bildirimTypeCommunity.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get bildirimTypeCommunity;

  /// No description provided for @bildirimTypePoll.
  ///
  /// In tr, this message translates to:
  /// **'Anket'**
  String get bildirimTypePoll;

  /// No description provided for @bildirimTypePost.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi'**
  String get bildirimTypePost;

  /// No description provided for @bildirimTypeOther.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim'**
  String get bildirimTypeOther;

  /// No description provided for @acadhubNextExam.
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki sınav'**
  String get acadhubNextExam;

  /// No description provided for @acadhubUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan tarihler'**
  String get acadhubUpcoming;

  /// No description provided for @acadhubCalendarLink.
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get acadhubCalendarLink;

  /// No description provided for @acadhubNoUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan tarih yok'**
  String get acadhubNoUpcoming;

  /// No description provided for @kuluplerAllClubs.
  ///
  /// In tr, this message translates to:
  /// **'Tüm kulüpler'**
  String get kuluplerAllClubs;

  /// No description provided for @kesfetSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Öğrencilerden gönderiler'**
  String get kesfetSubtitle;

  /// No description provided for @kesfetSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi veya kişi ara'**
  String get kesfetSearchHint;

  /// No description provided for @profil2PrivacyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik ve engellenenler'**
  String get profil2PrivacyTitle;

  /// No description provided for @profil2PrivacyIntro.
  ///
  /// In tr, this message translates to:
  /// **'Profilini kimlerin görebileceğini alan alan seç. Kendi profilini her zaman tam görürsün.'**
  String get profil2PrivacyIntro;

  /// No description provided for @profil2VisibilitySection.
  ///
  /// In tr, this message translates to:
  /// **'Profil görünürlüğü'**
  String get profil2VisibilitySection;

  /// No description provided for @profil2FieldAvatar.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafı'**
  String get profil2FieldAvatar;

  /// No description provided for @profil2FieldBio.
  ///
  /// In tr, this message translates to:
  /// **'Hakkımda'**
  String get profil2FieldBio;

  /// No description provided for @profil2FieldFaculty.
  ///
  /// In tr, this message translates to:
  /// **'Fakülte'**
  String get profil2FieldFaculty;

  /// No description provided for @profil2FieldDepartment.
  ///
  /// In tr, this message translates to:
  /// **'Bölüm'**
  String get profil2FieldDepartment;

  /// No description provided for @profil2FieldClassYear.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf'**
  String get profil2FieldClassYear;

  /// No description provided for @profil2VisEveryone.
  ///
  /// In tr, this message translates to:
  /// **'Herkes'**
  String get profil2VisEveryone;

  /// No description provided for @profil2VisShared.
  ///
  /// In tr, this message translates to:
  /// **'Ortak bağlam'**
  String get profil2VisShared;

  /// No description provided for @profil2VisOnlyMe.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca ben'**
  String get profil2VisOnlyMe;

  /// No description provided for @profil2SharedHintLead.
  ///
  /// In tr, this message translates to:
  /// **'Ortak bağlam:'**
  String get profil2SharedHintLead;

  /// No description provided for @profil2SharedHintBody.
  ///
  /// In tr, this message translates to:
  /// **'ortak kulüp, sohbet veya etkinliğin olduğu kişiler.'**
  String get profil2SharedHintBody;

  /// No description provided for @profil2ShowEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-postamı profilimde göster'**
  String get profil2ShowEmail;

  /// No description provided for @profil2ShowEmailSub.
  ///
  /// In tr, this message translates to:
  /// **'Kapalıyken yalnızca sen görürsün'**
  String get profil2ShowEmailSub;

  /// No description provided for @profil2BlockedSection.
  ///
  /// In tr, this message translates to:
  /// **'Engellenenler'**
  String get profil2BlockedSection;

  /// No description provided for @profil2BlockedHint.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğin kişiler seni göremez, sana yazamaz.'**
  String get profil2BlockedHint;

  /// No description provided for @profil2AvatarModerated.
  ///
  /// In tr, this message translates to:
  /// **'Profil fotoğrafın moderasyon nedeniyle gizlendi.'**
  String get profil2AvatarModerated;

  /// No description provided for @profil2SaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Değişiklik kaydedilemedi.'**
  String get profil2SaveFailed;

  /// No description provided for @profil2MyDataRow.
  ///
  /// In tr, this message translates to:
  /// **'Verilerim ve hesap'**
  String get profil2MyDataRow;

  /// No description provided for @profil2DataTitle.
  ///
  /// In tr, this message translates to:
  /// **'Verilerim'**
  String get profil2DataTitle;

  /// No description provided for @profil2DataIntro.
  ///
  /// In tr, this message translates to:
  /// **'KVKK kapsamında uygulamada sakladığımız kişisel verilerinin bir kopyasını indirebilirsin.'**
  String get profil2DataIntro;

  /// No description provided for @profil2DataFileSub.
  ///
  /// In tr, this message translates to:
  /// **'JSON dosyası olarak hazırlanır'**
  String get profil2DataFileSub;

  /// No description provided for @profil2DataContents.
  ///
  /// In tr, this message translates to:
  /// **'Dosyada neler var'**
  String get profil2DataContents;

  /// No description provided for @profil2DataItemProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil bilgilerin'**
  String get profil2DataItemProfile;

  /// No description provided for @profil2DataItemPrefs.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik ve bildirim tercihlerin'**
  String get profil2DataItemPrefs;

  /// No description provided for @profil2DataItemClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp ve etkinlik kayıtların'**
  String get profil2DataItemClubs;

  /// No description provided for @profil2DataItemSaved.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı haberler ve bildirimlerin'**
  String get profil2DataItemSaved;

  /// No description provided for @profil2DataItemSupport.
  ///
  /// In tr, this message translates to:
  /// **'Destek ve geri bildirim kayıtların'**
  String get profil2DataItemSupport;

  /// No description provided for @profil2DataLimit.
  ///
  /// In tr, this message translates to:
  /// **'Günde en fazla 3 kez indirebilirsin. Dosyayı güvenli sakla, içinde kişisel bilgiler var.'**
  String get profil2DataLimit;

  /// No description provided for @profil2DataOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get profil2DataOther;

  /// No description provided for @profil2DataKvkk.
  ///
  /// In tr, this message translates to:
  /// **'KVKK aydınlatma metni'**
  String get profil2DataKvkk;

  /// No description provided for @profil2DelWarnLead.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem geri alınamaz.'**
  String get profil2DelWarnLead;

  /// No description provided for @profil2DelWarnBody.
  ///
  /// In tr, this message translates to:
  /// **'Hesabın anonimleştirilir ve bir daha giriş yapamazsın.'**
  String get profil2DelWarnBody;

  /// No description provided for @profil2DelWhatHappens.
  ///
  /// In tr, this message translates to:
  /// **'Neler olur'**
  String get profil2DelWhatHappens;

  /// No description provided for @profil2DelItem1.
  ///
  /// In tr, this message translates to:
  /// **'Adın, e-postan, fotoğrafın ve profil bilgilerin silinir. Hesap Silinmiş kullanıcı olarak kalır.'**
  String get profil2DelItem1;

  /// No description provided for @profil2DelItem2.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimlerin, kayıtlı haberlerin, cihaz kayıtların ve tercihlerin silinir.'**
  String get profil2DelItem2;

  /// No description provided for @profil2DelItem3.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp üyeliklerin ve etkinlik katılımların kaldırılır.'**
  String get profil2DelItem3;

  /// No description provided for @profil2DelItem4.
  ///
  /// In tr, this message translates to:
  /// **'Tüm cihazlardaki oturumların kapanır.'**
  String get profil2DelItem4;

  /// No description provided for @profil2DelBackupHint.
  ///
  /// In tr, this message translates to:
  /// **'Dilersen silmeden önce verilerini indirebilirsin.'**
  String get profil2DelBackupHint;

  /// No description provided for @profil2DelAck.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımın kalıcı olarak silineceğini ve geri alınamayacağını anladım.'**
  String get profil2DelAck;

  /// No description provided for @profil2Continue.
  ///
  /// In tr, this message translates to:
  /// **'Devam et'**
  String get profil2Continue;

  /// No description provided for @profil2DelConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Silmeyi onayla'**
  String get profil2DelConfirmTitle;

  /// No description provided for @profil2DelConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Devam etmek için şifreni gir. Hesabın hemen anonimleştirilir ve tüm cihazlardan çıkış yapılır.'**
  String get profil2DelConfirmBody;

  /// No description provided for @profil2SecTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap ve güvenlik'**
  String get profil2SecTitle;

  /// No description provided for @profil2SecEmailFixed.
  ///
  /// In tr, this message translates to:
  /// **'Değiştirilemez'**
  String get profil2SecEmailFixed;

  /// No description provided for @profil2SecVerified.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulandı'**
  String get profil2SecVerified;

  /// No description provided for @profil2SecPwSection.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi güncelle'**
  String get profil2SecPwSection;

  /// No description provided for @profil2SecCurrentLabel.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut şifre'**
  String get profil2SecCurrentLabel;

  /// No description provided for @profil2SecCurrentHint.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut şifreniz'**
  String get profil2SecCurrentHint;

  /// No description provided for @profil2SecNewLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre'**
  String get profil2SecNewLabel;

  /// No description provided for @profil2SecNewHint.
  ///
  /// In tr, this message translates to:
  /// **'En az 8 karakter'**
  String get profil2SecNewHint;

  /// No description provided for @profil2SecRepeatLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre (tekrar)'**
  String get profil2SecRepeatLabel;

  /// No description provided for @profil2SecRepeatHint.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifreyi tekrarlayın'**
  String get profil2SecRepeatHint;

  /// No description provided for @profil2SecPwRule.
  ///
  /// In tr, this message translates to:
  /// **'8 ile 72 karakter. Harf ve rakam karıştırırsanız güçlenir.'**
  String get profil2SecPwRule;

  /// No description provided for @profil2SecPwButton.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi güncelle'**
  String get profil2SecPwButton;

  /// No description provided for @profil2SecMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifreler eşleşmiyor.'**
  String get profil2SecMismatch;

  /// No description provided for @profil2SecSame.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifre mevcut şifreyle aynı olamaz.'**
  String get profil2SecSame;

  /// No description provided for @profil2SecWrongCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut şifre hatalı.'**
  String get profil2SecWrongCurrent;

  /// No description provided for @profil2SecFailed.
  ///
  /// In tr, this message translates to:
  /// **'Şifre güncellenemedi. Lütfen daha sonra tekrar deneyin.'**
  String get profil2SecFailed;

  /// No description provided for @profil2SecUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Şifren güncellendi.'**
  String get profil2SecUpdated;

  /// No description provided for @profil2SecSessions.
  ///
  /// In tr, this message translates to:
  /// **'Oturumlar'**
  String get profil2SecSessions;

  /// No description provided for @profil1SecContent.
  ///
  /// In tr, this message translates to:
  /// **'İçeriklerim'**
  String get profil1SecContent;

  /// No description provided for @profil1SecAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get profil1SecAccount;

  /// No description provided for @profil1SecApp.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama'**
  String get profil1SecApp;

  /// No description provided for @profil1SecSupport.
  ///
  /// In tr, this message translates to:
  /// **'Destek ve hukuki'**
  String get profil1SecSupport;

  /// No description provided for @profil1AccountSecurity.
  ///
  /// In tr, this message translates to:
  /// **'Hesap ve güvenlik'**
  String get profil1AccountSecurity;

  /// No description provided for @profil1PrivacyBlocked.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik ve engellenenler'**
  String get profil1PrivacyBlocked;

  /// No description provided for @profil1MyData.
  ///
  /// In tr, this message translates to:
  /// **'Verilerim'**
  String get profil1MyData;

  /// No description provided for @profil1Notifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim tercihleri'**
  String get profil1Notifications;

  /// No description provided for @profil1Theme.
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get profil1Theme;

  /// No description provided for @profil1Support.
  ///
  /// In tr, this message translates to:
  /// **'Destek'**
  String get profil1Support;

  /// No description provided for @profil1Legal.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşmeler ve politikalar'**
  String get profil1Legal;

  /// No description provided for @profil1CorpEmail.
  ///
  /// In tr, this message translates to:
  /// **'Kurumsal e-posta'**
  String get profil1CorpEmail;

  /// No description provided for @profil1Remove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get profil1Remove;

  /// No description provided for @profil1PushTitle.
  ///
  /// In tr, this message translates to:
  /// **'Anlık bildirimler'**
  String get profil1PushTitle;

  /// No description provided for @profil1PushGranted.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihazda izin verildi'**
  String get profil1PushGranted;

  /// No description provided for @profil1PillOff.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get profil1PillOff;

  /// No description provided for @profil1WhatSection.
  ///
  /// In tr, this message translates to:
  /// **'Neler bildirilsin'**
  String get profil1WhatSection;

  /// No description provided for @profil1NotifClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpler'**
  String get profil1NotifClubs;

  /// No description provided for @profil1NewsSub.
  ///
  /// In tr, this message translates to:
  /// **'Üniversiteden yeni haberler'**
  String get profil1NewsSub;

  /// No description provided for @profil1AnnSub.
  ///
  /// In tr, this message translates to:
  /// **'Önemli duyurular'**
  String get profil1AnnSub;

  /// No description provided for @profil1EventsSub.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatma, değişiklik, kabul'**
  String get profil1EventsSub;

  /// No description provided for @profil1MsgSub.
  ///
  /// In tr, this message translates to:
  /// **'Kişi ve grup sohbetleri'**
  String get profil1MsgSub;

  /// No description provided for @profil1ClubsSub.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiler, rol ve katılım'**
  String get profil1ClubsSub;

  /// No description provided for @profil1Detailed.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıntılı tercihler'**
  String get profil1Detailed;

  /// No description provided for @profil1SubMsgDirect.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel mesajlar'**
  String get profil1SubMsgDirect;

  /// No description provided for @profil1SubMsgGroup.
  ///
  /// In tr, this message translates to:
  /// **'Grup mesajları'**
  String get profil1SubMsgGroup;

  /// No description provided for @profil1SubEventReminder.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik hatırlatmaları'**
  String get profil1SubEventReminder;

  /// No description provided for @profil1SubEventUpdate.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik değişiklikleri'**
  String get profil1SubEventUpdate;

  /// No description provided for @profil1SubEventAdmission.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik kabulleri'**
  String get profil1SubEventAdmission;

  /// No description provided for @profil1SubClubPost.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp gönderileri'**
  String get profil1SubClubPost;

  /// No description provided for @profil1SubClubRole.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp rol değişiklikleri'**
  String get profil1SubClubRole;

  /// No description provided for @profil1SubClubJoin.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp katılım istekleri'**
  String get profil1SubClubJoin;

  /// No description provided for @profil1QuietTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz saatler'**
  String get profil1QuietTitle;

  /// No description provided for @profil1QuietToggle.
  ///
  /// In tr, this message translates to:
  /// **'Sessiz saatleri aç'**
  String get profil1QuietToggle;

  /// No description provided for @profil1QuietSub.
  ///
  /// In tr, this message translates to:
  /// **'Bu saatlerde bildirim sesi çalmaz'**
  String get profil1QuietSub;

  /// No description provided for @profil1QuietStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get profil1QuietStart;

  /// No description provided for @profil1QuietEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get profil1QuietEnd;

  /// No description provided for @sohbetmedyaNext.
  ///
  /// In tr, this message translates to:
  /// **'İleri'**
  String get sohbetmedyaNext;

  /// No description provided for @sohbetmedyaSelectedOf.
  ///
  /// In tr, this message translates to:
  /// **'{n} / {max} seçildi'**
  String sohbetmedyaSelectedOf(String n, String max);

  /// No description provided for @sohbetmedyaRecent.
  ///
  /// In tr, this message translates to:
  /// **'Son eklenenler'**
  String get sohbetmedyaRecent;

  /// No description provided for @sohbetmedyaPhotoVideo.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf ve video'**
  String get sohbetmedyaPhotoVideo;

  /// No description provided for @sohbetmedyaLimitNote.
  ///
  /// In tr, this message translates to:
  /// **'En fazla {max} öğe seçebilirsiniz. Video en fazla 60 saniye olabilir.'**
  String sohbetmedyaLimitNote(String max);

  /// No description provided for @sohbetmedyaAddMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla ekle'**
  String get sohbetmedyaAddMore;

  /// No description provided for @sohbetmedyaSendItems.
  ///
  /// In tr, this message translates to:
  /// **'{n} öğeyi gönder'**
  String sohbetmedyaSendItems(String n);

  /// No description provided for @chatdSendingMedia.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiliyor…'**
  String get chatdSendingMedia;

  /// No description provided for @chatdPhotoLoading.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf yükleniyor…'**
  String get chatdPhotoLoading;

  /// No description provided for @chatdOnceLocked.
  ///
  /// In tr, this message translates to:
  /// **'Tek gösterimlik fotoğraf'**
  String get chatdOnceLocked;

  /// No description provided for @chatdOnceView.
  ///
  /// In tr, this message translates to:
  /// **'Görüntüle'**
  String get chatdOnceView;

  /// No description provided for @chatdOnceOpenedFull.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf · Açıldı'**
  String get chatdOnceOpenedFull;

  /// No description provided for @anasayfaHello.
  ///
  /// In tr, this message translates to:
  /// **'Merhaba, {name}'**
  String anasayfaHello(String name);

  /// No description provided for @anasayfaHelloNoName.
  ///
  /// In tr, this message translates to:
  /// **'Merhaba'**
  String get anasayfaHelloNoName;

  /// No description provided for @anasayfaMealLunch.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün yemeği · Öğle'**
  String get anasayfaMealLunch;

  /// No description provided for @anasayfaAnnouncements.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular'**
  String get anasayfaAnnouncements;

  /// No description provided for @anasayfaQuickAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Akademik'**
  String get anasayfaQuickAcademic;

  /// No description provided for @gonderiTextHint.
  ///
  /// In tr, this message translates to:
  /// **'Kısa bir not ekle (isteğe bağlı)'**
  String get gonderiTextHint;

  /// No description provided for @gonderiWordCount.
  ///
  /// In tr, this message translates to:
  /// **'{n}/{max} kelime'**
  String gonderiWordCount(String n, String max);

  /// No description provided for @gonderiWordLimit.
  ///
  /// In tr, this message translates to:
  /// **'En çok {max} kelime yazabilirsin.'**
  String gonderiWordLimit(String max);

  /// No description provided for @gonderiPickPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get gonderiPickPhoto;

  /// No description provided for @gonderiTakePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çek'**
  String get gonderiTakePhoto;

  /// No description provided for @gonderiPhotoRequired.
  ///
  /// In tr, this message translates to:
  /// **'Paylaşmak için bir fotoğraf seç.'**
  String get gonderiPhotoRequired;

  /// No description provided for @gonderiPhotoHint.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi tek bir fotoğraftan oluşur.'**
  String get gonderiPhotoHint;

  /// No description provided for @gonderiChangePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı değiştir'**
  String get gonderiChangePhoto;

  /// No description provided for @gonderiDiscardTitle.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiden vazgeçilsin mi?'**
  String get gonderiDiscardTitle;

  /// No description provided for @gonderiDiscardBody.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğin fotoğraf ve yazdıkların silinecek.'**
  String get gonderiDiscardBody;

  /// No description provided for @gonderiDiscardYes.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get gonderiDiscardYes;

  /// No description provided for @yemekLunch.
  ///
  /// In tr, this message translates to:
  /// **'Öğle yemeği'**
  String get yemekLunch;

  /// No description provided for @yemekTodaysMenu.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün menüsü'**
  String get yemekTodaysMenu;

  /// No description provided for @yemekToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get yemekToday;

  /// No description provided for @yemekPrevDay.
  ///
  /// In tr, this message translates to:
  /// **'Önceki gün'**
  String get yemekPrevDay;

  /// No description provided for @yemekNextDay.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki gün'**
  String get yemekNextDay;

  /// No description provided for @destekFaqHeading.
  ///
  /// In tr, this message translates to:
  /// **'Sıkça sorulan sorular'**
  String get destekFaqHeading;

  /// No description provided for @destekFaqSearchHint.
  ///
  /// In tr, this message translates to:
  /// **'Sorunuzu arayın'**
  String get destekFaqSearchHint;

  /// No description provided for @destekFaqAll.
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get destekFaqAll;

  /// No description provided for @destekFaqNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen soru bulunamadı.'**
  String get destekFaqNoMatch;

  /// No description provided for @destekSortMine.
  ///
  /// In tr, this message translates to:
  /// **'Benim'**
  String get destekSortMine;

  /// No description provided for @destekSortPopular.
  ///
  /// In tr, this message translates to:
  /// **'Popüler'**
  String get destekSortPopular;

  /// No description provided for @destekShareSuggestion.
  ///
  /// In tr, this message translates to:
  /// **'Öneri paylaş'**
  String get destekShareSuggestion;

  /// No description provided for @destekEffective.
  ///
  /// In tr, this message translates to:
  /// **'Yürürlük: {date}'**
  String destekEffective(String date);

  /// No description provided for @destekVoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Oy ver, şu an {count} oy'**
  String destekVoteLabel(String count);

  /// No description provided for @anketScopeGlobal.
  ///
  /// In tr, this message translates to:
  /// **'Genel'**
  String get anketScopeGlobal;

  /// No description provided for @anketScopeClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get anketScopeClub;

  /// No description provided for @anketScopeMenu.
  ///
  /// In tr, this message translates to:
  /// **'Yemek'**
  String get anketScopeMenu;

  /// No description provided for @anketSecretNote.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz gizli. Seçiminizi yalnızca siz görürsünüz; yöneticiler dahil kimse kimin ne seçtiğini göremez.'**
  String get anketSecretNote;

  /// No description provided for @anketSecretVoteNote.
  ///
  /// In tr, this message translates to:
  /// **'Oyunuz gizli kalır, kimse kimin ne seçtiğini göremez.'**
  String get anketSecretVoteNote;

  /// No description provided for @anketMineBadge.
  ///
  /// In tr, this message translates to:
  /// **'Seçiminiz'**
  String get anketMineBadge;

  /// No description provided for @anketRatingSummary.
  ///
  /// In tr, this message translates to:
  /// **'Puanlama özeti'**
  String get anketRatingSummary;

  /// No description provided for @anketResultsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar'**
  String get anketResultsTitle;

  /// No description provided for @anketFieldQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Soru'**
  String get anketFieldQuestion;

  /// No description provided for @anketVisTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sonuçlar ne zaman görünsün?'**
  String get anketVisTitle;

  /// No description provided for @anketVisAlways.
  ///
  /// In tr, this message translates to:
  /// **'Her zaman'**
  String get anketVisAlways;

  /// No description provided for @anketVisAfterVote.
  ///
  /// In tr, this message translates to:
  /// **'Oy verince'**
  String get anketVisAfterVote;

  /// No description provided for @anketVisAfterClose.
  ///
  /// In tr, this message translates to:
  /// **'Anket kapanınca'**
  String get anketVisAfterClose;

  /// No description provided for @anketNotifyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim gönder'**
  String get anketNotifyTitle;

  /// No description provided for @anketNotifySub.
  ///
  /// In tr, this message translates to:
  /// **'Hedef kitleye anket açıldı bildirimi'**
  String get anketNotifySub;

  /// No description provided for @icerikHidden.
  ///
  /// In tr, this message translates to:
  /// **'Gizli'**
  String get icerikHidden;

  /// No description provided for @icerikStatPosts.
  ///
  /// In tr, this message translates to:
  /// **'gönderi'**
  String get icerikStatPosts;

  /// No description provided for @icerikStatFollowers.
  ///
  /// In tr, this message translates to:
  /// **'takipçi'**
  String get icerikStatFollowers;

  /// No description provided for @icerikStatFollowing.
  ///
  /// In tr, this message translates to:
  /// **'takip'**
  String get icerikStatFollowing;

  /// No description provided for @icerikMessageSend.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj gönder'**
  String get icerikMessageSend;

  /// No description provided for @icerikReport.
  ///
  /// In tr, this message translates to:
  /// **'Raporla'**
  String get icerikReport;

  /// No description provided for @icerikMoreActions.
  ///
  /// In tr, this message translates to:
  /// **'Diğer işlemler'**
  String get icerikMoreActions;

  /// No description provided for @icerikUserMenu.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı işlemleri'**
  String get icerikUserMenu;

  /// No description provided for @icerikPostsHeading.
  ///
  /// In tr, this message translates to:
  /// **'GÖNDERİLER'**
  String get icerikPostsHeading;

  /// No description provided for @icerikOpenPost.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi aç'**
  String get icerikOpenPost;

  /// No description provided for @icerikPostPhoto.
  ///
  /// In tr, this message translates to:
  /// **'Gönderi fotoğrafı'**
  String get icerikPostPhoto;

  /// No description provided for @icerikNewsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haberler'**
  String get icerikNewsTitle;

  /// No description provided for @icerikNewsTypeTabs.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get icerikNewsTypeTabs;

  /// No description provided for @icerikNewsList.
  ///
  /// In tr, this message translates to:
  /// **'Haber listesi'**
  String get icerikNewsList;

  /// No description provided for @icerikNewsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu kategoride henüz içerik yok.'**
  String get icerikNewsEmpty;

  /// No description provided for @icerikFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favori haberler'**
  String get icerikFavorites;

  /// No description provided for @icerikMaintenance.
  ///
  /// In tr, this message translates to:
  /// **'Haber kaynağına şu an ulaşılamıyor. Son kaydedilen haberler gösteriliyor.'**
  String get icerikMaintenance;

  /// No description provided for @icerikOpenSource.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak sitede aç'**
  String get icerikOpenSource;

  /// No description provided for @icerikShare.
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get icerikShare;

  /// No description provided for @icerikLinkCopied.
  ///
  /// In tr, this message translates to:
  /// **'Haber bağlantısı kopyalandı.'**
  String get icerikLinkCopied;

  /// No description provided for @icerikSavedCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kayıtlı haber'**
  String icerikSavedCount(String count);

  /// No description provided for @icerikSavedMoreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla haberi kaydet'**
  String get icerikSavedMoreTitle;

  /// No description provided for @icerikSavedMoreBody.
  ///
  /// In tr, this message translates to:
  /// **'Haber detayındaki işaretle haberleri buraya ekleyebilirsin.'**
  String get icerikSavedMoreBody;

  /// No description provided for @icerikSavedList.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get icerikSavedList;

  /// No description provided for @icerikSearchTabs.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç türü'**
  String get icerikSearchTabs;

  /// No description provided for @icerikGroupNews.
  ///
  /// In tr, this message translates to:
  /// **'HABER'**
  String get icerikGroupNews;

  /// No description provided for @icerikGroupAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'DUYURU'**
  String get icerikGroupAnnouncement;

  /// No description provided for @icerikGroupEvent.
  ///
  /// In tr, this message translates to:
  /// **'ETKİNLİK'**
  String get icerikGroupEvent;

  /// No description provided for @icerikGroupClub.
  ///
  /// In tr, this message translates to:
  /// **'KULÜP'**
  String get icerikGroupClub;

  /// No description provided for @icerikGroupPerson.
  ///
  /// In tr, this message translates to:
  /// **'KİŞİ'**
  String get icerikGroupPerson;

  /// No description provided for @icerikGroupPost.
  ///
  /// In tr, this message translates to:
  /// **'GÖNDERİ'**
  String get icerikGroupPost;

  /// No description provided for @kulupdetayRequestsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılma istekleri'**
  String get kulupdetayRequestsTitle;

  /// No description provided for @kulupdetayPendingBanner.
  ///
  /// In tr, this message translates to:
  /// **'{count} bekleyen katılma isteği'**
  String kulupdetayPendingBanner(String count);

  /// No description provided for @kulupdetaySendRequest.
  ///
  /// In tr, this message translates to:
  /// **'İsteği gönder'**
  String get kulupdetaySendRequest;

  /// No description provided for @kulupdetayAnswerHint.
  ///
  /// In tr, this message translates to:
  /// **'Cevabını yaz'**
  String get kulupdetayAnswerHint;

  /// No description provided for @kulupdetayRequired.
  ///
  /// In tr, this message translates to:
  /// **'Bu soru zorunlu.'**
  String get kulupdetayRequired;

  /// No description provided for @kulupdetayApproving.
  ///
  /// In tr, this message translates to:
  /// **'Onaylanıyor...'**
  String get kulupdetayApproving;

  /// No description provided for @kulupdetayCreateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp oluştur'**
  String get kulupdetayCreateTitle;

  /// No description provided for @kulupdetayMembersSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'{club} · {count} üye'**
  String kulupdetayMembersSubtitle(String club, String count);

  /// No description provided for @akademik2DayHeadingToday.
  ///
  /// In tr, this message translates to:
  /// **'{day}, bugün'**
  String akademik2DayHeadingToday(String day);

  /// No description provided for @akademik2CourseCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} ders'**
  String akademik2CourseCount(String count);

  /// No description provided for @akademik2ExportLabel.
  ///
  /// In tr, this message translates to:
  /// **'Takvime aktar'**
  String get akademik2ExportLabel;

  /// No description provided for @akademik2CourseHours.
  ///
  /// In tr, this message translates to:
  /// **'Ders saati'**
  String get akademik2CourseHours;

  /// No description provided for @akademik2Instructor.
  ///
  /// In tr, this message translates to:
  /// **'Öğretim elemanı'**
  String get akademik2Instructor;

  /// No description provided for @akademik2Start.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get akademik2Start;

  /// No description provided for @akademik2End.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş'**
  String get akademik2End;

  /// No description provided for @akademik2EndOptional.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş (isteğe bağlı)'**
  String get akademik2EndOptional;

  /// No description provided for @akademik2RoomShort.
  ///
  /// In tr, this message translates to:
  /// **'Sınıf'**
  String get akademik2RoomShort;

  /// No description provided for @akademik2AddDay.
  ///
  /// In tr, this message translates to:
  /// **'Başka gün ekle'**
  String get akademik2AddDay;

  /// No description provided for @akademik2OfficialTag.
  ///
  /// In tr, this message translates to:
  /// **'Resmi'**
  String get akademik2OfficialTag;

  /// No description provided for @akademik2Passed.
  ///
  /// In tr, this message translates to:
  /// **'Geçti'**
  String get akademik2Passed;

  /// No description provided for @akademik2ExamTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sınav başlığı'**
  String get akademik2ExamTitle;

  /// No description provided for @akademik2Course.
  ///
  /// In tr, this message translates to:
  /// **'Ders'**
  String get akademik2Course;

  /// No description provided for @akademik2Place.
  ///
  /// In tr, this message translates to:
  /// **'Yer'**
  String get akademik2Place;

  /// No description provided for @akademik2NewTag.
  ///
  /// In tr, this message translates to:
  /// **'Yeni'**
  String get akademik2NewTag;

  /// No description provided for @akademik2Attachment.
  ///
  /// In tr, this message translates to:
  /// **'Ek dosya'**
  String get akademik2Attachment;

  /// No description provided for @akademik2RemindEach.
  ///
  /// In tr, this message translates to:
  /// **'Her ders öncesinde'**
  String get akademik2RemindEach;

  /// No description provided for @akademik2BeforeClassShort.
  ///
  /// In tr, this message translates to:
  /// **'Dersten önce'**
  String get akademik2BeforeClassShort;

  /// No description provided for @akademik2SemesterTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dönem seç'**
  String get akademik2SemesterTitle;

  /// No description provided for @sistemuiPermStep.
  ///
  /// In tr, this message translates to:
  /// **'Adım {current} / {total}'**
  String sistemuiPermStep(String current, String total);

  /// No description provided for @sistemuiPermNotifText.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj, etkinlik ve duyurulardan anında haberdar olmak için.'**
  String get sistemuiPermNotifText;

  /// No description provided for @sistemuiPermContactsText.
  ///
  /// In tr, this message translates to:
  /// **'Rehberinizdeki üniversite kişilerini bulup sohbet başlatmanız için. Rehberiniz sunucuya gönderilmez.'**
  String get sistemuiPermContactsText;

  /// No description provided for @sistemuiPermCameraTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kamera ve galeri'**
  String get sistemuiPermCameraTitle;

  /// No description provided for @sistemuiPermCameraText.
  ///
  /// In tr, this message translates to:
  /// **'QR kod okutmak, fotoğraf çekmek ve paylaşmak için.'**
  String get sistemuiPermCameraText;

  /// No description provided for @sistemuiOfflineTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı yok'**
  String get sistemuiOfflineTitle;

  /// No description provided for @sistemuiOfflineBody.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantınızı kontrol edip tekrar deneyin. Sunucuya şu an ulaşılamıyor olabilir.'**
  String get sistemuiOfflineBody;

  /// No description provided for @sistemuiErrorTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti'**
  String get sistemuiErrorTitle;

  /// No description provided for @sistemuiMaintTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sistem bakımda'**
  String get sistemuiMaintTitle;

  /// No description provided for @sistemuiMaintBody.
  ///
  /// In tr, this message translates to:
  /// **'Sizin için daha iyi hale getiriyoruz. Kısa süre sonra tekrar deneyin. Verileriniz güvende.'**
  String get sistemuiMaintBody;

  /// No description provided for @sistemuiMaintBand.
  ///
  /// In tr, this message translates to:
  /// **'Bazı özellikler geçici olarak kullanılamayabilir.'**
  String get sistemuiMaintBand;

  /// No description provided for @sistemuiUpdateVersions.
  ///
  /// In tr, this message translates to:
  /// **'Yüklü sürüm {current} · Gerekli sürüm {required}'**
  String sistemuiUpdateVersions(String current, String required);

  /// No description provided for @sistemuiBlockedCode.
  ///
  /// In tr, this message translates to:
  /// **'Hata kodu: ACCESS_BLOCKED'**
  String get sistemuiBlockedCode;

  /// No description provided for @sistemuiQrHint.
  ///
  /// In tr, this message translates to:
  /// **'QR kodunu çerçevenin içine getir'**
  String get sistemuiQrHint;

  /// No description provided for @sistemuiQrNotice.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama etkinlik saatinde açılır. Organizatörün gösterdiği kodu okut.'**
  String get sistemuiQrNotice;

  /// No description provided for @sistemuiQrOr.
  ///
  /// In tr, this message translates to:
  /// **'veya'**
  String get sistemuiQrOr;

  /// No description provided for @sistemuiQrManualHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn. K7M4QX'**
  String get sistemuiQrManualHint;

  /// No description provided for @sistemuiQrSubmit.
  ///
  /// In tr, this message translates to:
  /// **'Yoklamayı gönder'**
  String get sistemuiQrSubmit;

  /// No description provided for @profilyardBlockedNote.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğin kişiler profilini göremez, sana mesaj yazamaz ve seni takip edemez.'**
  String get profilyardBlockedNote;

  /// No description provided for @profilyardBlockedEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kimseyi engellemedin'**
  String get profilyardBlockedEmptyTitle;

  /// No description provided for @profilyardBlockedEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Rahatsız edici bir kullanıcıyı profilinden engelleyebilirsin.'**
  String get profilyardBlockedEmptyBody;

  /// No description provided for @profilyardUnblockOf.
  ///
  /// In tr, this message translates to:
  /// **'{name} engelini kaldır'**
  String profilyardUnblockOf(String name);

  /// No description provided for @profilyardClubsManaged.
  ///
  /// In tr, this message translates to:
  /// **'Yönettiklerim'**
  String get profilyardClubsManaged;

  /// No description provided for @profilyardClubsMember.
  ///
  /// In tr, this message translates to:
  /// **'Üyesi olduklarım'**
  String get profilyardClubsMember;

  /// No description provided for @profilyardClubsPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen istekler'**
  String get profilyardClubsPending;

  /// No description provided for @profilyardRoleOwner.
  ///
  /// In tr, this message translates to:
  /// **'Başkan'**
  String get profilyardRoleOwner;

  /// No description provided for @profilyardRoleFounder.
  ///
  /// In tr, this message translates to:
  /// **'Kurucu'**
  String get profilyardRoleFounder;

  /// No description provided for @profilyardRoleAdmin.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici'**
  String get profilyardRoleAdmin;

  /// No description provided for @profilyardRoleModerator.
  ///
  /// In tr, this message translates to:
  /// **'Moderatör'**
  String get profilyardRoleModerator;

  /// No description provided for @profilyardRoleMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye'**
  String get profilyardRoleMember;

  /// No description provided for @profilyardClubsEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir kulübün yok'**
  String get profilyardClubsEmptyTitle;

  /// No description provided for @profilyardClubsEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpleri keşfedip katılabilir ya da kendi kulübünü kurabilirsin.'**
  String get profilyardClubsEmptyBody;

  /// No description provided for @profilyardClubsDiscover.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpleri keşfet'**
  String get profilyardClubsDiscover;

  /// No description provided for @profilyardEventsAttended.
  ///
  /// In tr, this message translates to:
  /// **'Katıldıklarım'**
  String get profilyardEventsAttended;

  /// No description provided for @profilyardEventsCreated.
  ///
  /// In tr, this message translates to:
  /// **'Oluşturduklarım'**
  String get profilyardEventsCreated;

  /// No description provided for @profilyardEventsUpcoming.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan'**
  String get profilyardEventsUpcoming;

  /// No description provided for @profilyardEventsPast.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get profilyardEventsPast;

  /// No description provided for @profilyardEventGoing.
  ///
  /// In tr, this message translates to:
  /// **'Katılıyorum'**
  String get profilyardEventGoing;

  /// No description provided for @profilyardEventRequested.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönderildi'**
  String get profilyardEventRequested;

  /// No description provided for @profilyardEventInterested.
  ///
  /// In tr, this message translates to:
  /// **'İlgileniyorum'**
  String get profilyardEventInterested;

  /// No description provided for @profilyardEventPendingCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} bekleyen istek'**
  String profilyardEventPendingCount(String count);

  /// No description provided for @profilyardEventsEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz etkinliğin yok'**
  String get profilyardEventsEmptyTitle;

  /// No description provided for @profilyardEventsEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliklere göz at ya da kendi etkinliğini oluştur.'**
  String get profilyardEventsEmptyBody;

  /// No description provided for @profilyardFollowersTab.
  ///
  /// In tr, this message translates to:
  /// **'Takipçiler {count}'**
  String profilyardFollowersTab(String count);

  /// No description provided for @profilyardFollowingTab.
  ///
  /// In tr, this message translates to:
  /// **'Takip edilenler {count}'**
  String profilyardFollowingTab(String count);

  /// No description provided for @profilyardFollowersSearch.
  ///
  /// In tr, this message translates to:
  /// **'Takipçilerde ara'**
  String get profilyardFollowersSearch;

  /// No description provided for @profilyardFollowingSearch.
  ///
  /// In tr, this message translates to:
  /// **'Takip edilenlerde ara'**
  String get profilyardFollowingSearch;

  /// No description provided for @profilyardFollowMutual.
  ///
  /// In tr, this message translates to:
  /// **'Takipleşiyorsunuz'**
  String get profilyardFollowMutual;

  /// No description provided for @profilyardFollowsYou.
  ///
  /// In tr, this message translates to:
  /// **'Seni takip ediyor'**
  String get profilyardFollowsYou;

  /// No description provided for @profilyardFollowingYou.
  ///
  /// In tr, this message translates to:
  /// **'Takiptesin'**
  String get profilyardFollowingYou;

  /// No description provided for @profilyardFollowNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen kişi yok.'**
  String get profilyardFollowNoMatch;

  /// No description provided for @profilyardFbIntro.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı geliştirmemize yardım et. Önerini, karşılaştığın hatayı ya da düşüncelerini yaz.'**
  String get profilyardFbIntro;

  /// No description provided for @profilyardFbType.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get profilyardFbType;

  /// No description provided for @profilyardFbTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başlık'**
  String get profilyardFbTitle;

  /// No description provided for @profilyardFbMessage.
  ///
  /// In tr, this message translates to:
  /// **'Mesaj'**
  String get profilyardFbMessage;

  /// No description provided for @profilyardFbTitleHint.
  ///
  /// In tr, this message translates to:
  /// **'Kısaca özetle'**
  String get profilyardFbTitleHint;

  /// No description provided for @profilyardFbMessageHint.
  ///
  /// In tr, this message translates to:
  /// **'Ayrıntıları yaz'**
  String get profilyardFbMessageHint;

  /// No description provided for @profilyardFbCounter.
  ///
  /// In tr, this message translates to:
  /// **'{n} / {max}'**
  String profilyardFbCounter(String n, String max);

  /// No description provided for @sohbetyAddMember.
  ///
  /// In tr, this message translates to:
  /// **'Üye ekle'**
  String get sohbetyAddMember;

  /// No description provided for @sohbetyAddCount.
  ///
  /// In tr, this message translates to:
  /// **'Ekle ({n})'**
  String sohbetyAddCount(String n);

  /// No description provided for @sohbetyProfile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get sohbetyProfile;

  /// No description provided for @sohbetyNewGroup.
  ///
  /// In tr, this message translates to:
  /// **'Yeni grup'**
  String get sohbetyNewGroup;

  /// No description provided for @sohbetyNewGroupSub.
  ///
  /// In tr, this message translates to:
  /// **'En fazla 50 kişi'**
  String get sohbetyNewGroupSub;

  /// No description provided for @sohbetyGroupMin.
  ///
  /// In tr, this message translates to:
  /// **'Grup için en az 2 kişi seçin.'**
  String get sohbetyGroupMin;

  /// No description provided for @sohbetyTypePerson.
  ///
  /// In tr, this message translates to:
  /// **'Kişi'**
  String get sohbetyTypePerson;

  /// No description provided for @sohbetyFlash.
  ///
  /// In tr, this message translates to:
  /// **'Flaş'**
  String get sohbetyFlash;

  /// No description provided for @sohbetyStopRec.
  ///
  /// In tr, this message translates to:
  /// **'Kaydı durdur'**
  String get sohbetyStopRec;

  /// No description provided for @sohbetyTakePhoto.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çek'**
  String get sohbetyTakePhoto;

  /// No description provided for @sohbetyAddDone.
  ///
  /// In tr, this message translates to:
  /// **'Üyeler eklendi'**
  String get sohbetyAddDone;

  /// No description provided for @etkinlik2PolicyOpen.
  ///
  /// In tr, this message translates to:
  /// **'Herkes katılabilir'**
  String get etkinlik2PolicyOpen;

  /// No description provided for @etkinlik2PolicyApproval.
  ///
  /// In tr, this message translates to:
  /// **'İstek ile'**
  String get etkinlik2PolicyApproval;

  /// No description provided for @etkinlik2PolicyApprovalTag.
  ///
  /// In tr, this message translates to:
  /// **'İstek ile katılım'**
  String get etkinlik2PolicyApprovalTag;

  /// No description provided for @etkinlik2Organizer.
  ///
  /// In tr, this message translates to:
  /// **'Organizatör'**
  String get etkinlik2Organizer;

  /// No description provided for @etkinlik2JoinPolicyLabel.
  ///
  /// In tr, this message translates to:
  /// **'Katılım'**
  String get etkinlik2JoinPolicyLabel;

  /// No description provided for @etkinlik2PolicyApprovalHint.
  ///
  /// In tr, this message translates to:
  /// **'İstek ile seçersen katılımcıları sen onaylarsın.'**
  String get etkinlik2PolicyApprovalHint;

  /// No description provided for @etkinlik2FormClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp adına (isteğe bağlı)'**
  String get etkinlik2FormClub;

  /// No description provided for @etkinlik2ClubNone.
  ///
  /// In tr, this message translates to:
  /// **'Seçilmedi'**
  String get etkinlik2ClubNone;

  /// No description provided for @etkinlik2ClubSheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp seç'**
  String get etkinlik2ClubSheetTitle;

  /// No description provided for @etkinlik2ClubNoneOption.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp adına değil'**
  String get etkinlik2ClubNoneOption;

  /// No description provided for @etkinlik2ClubNoClubs.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik açabileceğin kulüp yok.'**
  String get etkinlik2ClubNoClubs;

  /// No description provided for @etkinlik2ChatAutoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sohbeti otomatik açılır'**
  String get etkinlik2ChatAutoTitle;

  /// No description provided for @etkinlik2ChatAutoBody.
  ///
  /// In tr, this message translates to:
  /// **'Katılanlar ve sen sohbete girersiniz. İstek ile katılımda yalnızca onaylananlar girer.'**
  String get etkinlik2ChatAutoBody;

  /// No description provided for @etkinlik2CapacityOptional.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan (isteğe bağlı)'**
  String get etkinlik2CapacityOptional;

  /// No description provided for @etkinlik2Unlimited.
  ///
  /// In tr, this message translates to:
  /// **'Sınırsız'**
  String get etkinlik2Unlimited;

  /// No description provided for @etkinlik2RegOpenSlots.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar açık · {n} yer kaldı'**
  String etkinlik2RegOpenSlots(String n);

  /// No description provided for @etkinlik2RegOpen.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar açık'**
  String get etkinlik2RegOpen;

  /// No description provided for @etkinlik2ApprovalByOrganizer.
  ///
  /// In tr, this message translates to:
  /// **'Katılımı organizatör onaylar'**
  String get etkinlik2ApprovalByOrganizer;

  /// No description provided for @etkinlik2SendRequest.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteği gönder'**
  String get etkinlik2SendRequest;

  /// No description provided for @etkinlik2RequestHint.
  ///
  /// In tr, this message translates to:
  /// **'Organizatör onaylayınca etkinlik sohbetine girersin.'**
  String get etkinlik2RequestHint;

  /// No description provided for @etkinlik2RequestSent.
  ///
  /// In tr, this message translates to:
  /// **'İstek gönderildi'**
  String get etkinlik2RequestSent;

  /// No description provided for @etkinlik2AwaitingReply.
  ///
  /// In tr, this message translates to:
  /// **'Yanıt bekleniyor'**
  String get etkinlik2AwaitingReply;

  /// No description provided for @etkinlik2Withdraw.
  ///
  /// In tr, this message translates to:
  /// **'Geri çek'**
  String get etkinlik2Withdraw;

  /// No description provided for @etkinlik2WithdrawTitle.
  ///
  /// In tr, this message translates to:
  /// **'İsteği geri çek'**
  String get etkinlik2WithdrawTitle;

  /// No description provided for @etkinlik2WithdrawMessage.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteğin geri çekilecek.'**
  String get etkinlik2WithdrawMessage;

  /// No description provided for @etkinlik2ChatLocked.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sohbeti · Onaylanınca açılır'**
  String get etkinlik2ChatLocked;

  /// No description provided for @etkinlik2RejectedTitle.
  ///
  /// In tr, this message translates to:
  /// **'İsteğin reddedildi'**
  String get etkinlik2RejectedTitle;

  /// No description provided for @etkinlik2RejectedBody.
  ///
  /// In tr, this message translates to:
  /// **'Organizatör bu etkinlik için isteğini kabul etmedi.'**
  String get etkinlik2RejectedBody;

  /// No description provided for @etkinlik2RequestSentToast.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteğin gönderildi.'**
  String get etkinlik2RequestSentToast;

  /// No description provided for @etkinlik2WithdrawnToast.
  ///
  /// In tr, this message translates to:
  /// **'İstek geri çekildi.'**
  String get etkinlik2WithdrawnToast;

  /// No description provided for @etkinlik2GoingInterested.
  ///
  /// In tr, this message translates to:
  /// **'{going} kişi katılıyor · {interested} ilgileniyor'**
  String etkinlik2GoingInterested(String going, String interested);

  /// No description provided for @etkinlik2GoingOnly.
  ///
  /// In tr, this message translates to:
  /// **'{going} kişi katılıyor'**
  String etkinlik2GoingOnly(String going);

  /// No description provided for @etkinlik2ManageRequests.
  ///
  /// In tr, this message translates to:
  /// **'Katılım istekleri'**
  String get etkinlik2ManageRequests;

  /// No description provided for @etkinlik2ManagePending.
  ///
  /// In tr, this message translates to:
  /// **'{n} bekleyen istek'**
  String etkinlik2ManagePending(String n);

  /// No description provided for @etkinlik2ManageNoPending.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen istek yok'**
  String get etkinlik2ManageNoPending;

  /// No description provided for @etkinlik2ManageAttendance.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar ve yoklama'**
  String get etkinlik2ManageAttendance;

  /// No description provided for @etkinlik2ManageSettings.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik ayarları'**
  String get etkinlik2ManageSettings;

  /// No description provided for @etkinlik2ManageSection.
  ///
  /// In tr, this message translates to:
  /// **'Yönetim'**
  String get etkinlik2ManageSection;

  /// No description provided for @etkinlik2ReqQuota.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan'**
  String get etkinlik2ReqQuota;

  /// No description provided for @etkinlik2ReqSlotsLeft.
  ///
  /// In tr, this message translates to:
  /// **'{n} yer kaldı'**
  String etkinlik2ReqSlotsLeft(String n);

  /// No description provided for @etkinlik2ReqNoLimit.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan sınırı yok'**
  String get etkinlik2ReqNoLimit;

  /// No description provided for @etkinlik2ReqFullBanner.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu; yeni istekler onaylanamaz. Yer açmak için kontenjanı artır.'**
  String get etkinlik2ReqFullBanner;

  /// No description provided for @etkinlik2ReqPendingHeader.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen · {n}'**
  String etkinlik2ReqPendingHeader(String n);

  /// No description provided for @etkinlik2ReqAnsweredHeader.
  ///
  /// In tr, this message translates to:
  /// **'Yanıtlananlar'**
  String get etkinlik2ReqAnsweredHeader;

  /// No description provided for @etkinlik2ReqNone.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen istek yok.'**
  String get etkinlik2ReqNone;

  /// No description provided for @etkinlik2Approve.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get etkinlik2Approve;

  /// No description provided for @etkinlik2Reject.
  ///
  /// In tr, this message translates to:
  /// **'Reddet'**
  String get etkinlik2Reject;

  /// No description provided for @etkinlik2ApproveSem.
  ///
  /// In tr, this message translates to:
  /// **'{name} isteğini onayla'**
  String etkinlik2ApproveSem(String name);

  /// No description provided for @etkinlik2RejectSem.
  ///
  /// In tr, this message translates to:
  /// **'{name} isteğini reddet'**
  String etkinlik2RejectSem(String name);

  /// No description provided for @etkinlik2ApprovedTag.
  ///
  /// In tr, this message translates to:
  /// **'Onaylandı'**
  String get etkinlik2ApprovedTag;

  /// No description provided for @etkinlik2RejectedTag.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get etkinlik2RejectedTag;

  /// No description provided for @etkinlik2ApprovedToast.
  ///
  /// In tr, this message translates to:
  /// **'İstek onaylandı.'**
  String get etkinlik2ApprovedToast;

  /// No description provided for @etkinlik2RejectedToast.
  ///
  /// In tr, this message translates to:
  /// **'İstek reddedildi.'**
  String get etkinlik2RejectedToast;

  /// No description provided for @etkinlik2SettingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik ayarları'**
  String get etkinlik2SettingsTitle;

  /// No description provided for @etkinlik2SettingsPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Katılım türü'**
  String get etkinlik2SettingsPolicy;

  /// No description provided for @etkinlik2SettingsCapMin.
  ///
  /// In tr, this message translates to:
  /// **'Şu an {n} kişi onaylı. Kontenjanı bundan aşağı çekemezsin.'**
  String etkinlik2SettingsCapMin(String n);

  /// No description provided for @etkinlik2SettingsCapTooLow.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan onaylı kişi sayısından ({n}) az olamaz.'**
  String etkinlik2SettingsCapTooLow(String n);

  /// No description provided for @etkinlik2SettingsRegChat.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt ve sohbet'**
  String get etkinlik2SettingsRegChat;

  /// No description provided for @etkinlik2SettingsRegOpen.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar açık'**
  String get etkinlik2SettingsRegOpen;

  /// No description provided for @etkinlik2SettingsRegHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapatırsan yeni istek ve katılım alınmaz.'**
  String get etkinlik2SettingsRegHint;

  /// No description provided for @etkinlik2SettingsChatOpen.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik sohbeti açık'**
  String get etkinlik2SettingsChatOpen;

  /// No description provided for @etkinlik2SettingsChatHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapatırsan mesajlar durur, geçmiş saklanır.'**
  String get etkinlik2SettingsChatHint;

  /// No description provided for @etkinlik2SettingsDanger.
  ///
  /// In tr, this message translates to:
  /// **'Tehlikeli bölge'**
  String get etkinlik2SettingsDanger;

  /// No description provided for @etkinlik2SettingsCancelBody.
  ///
  /// In tr, this message translates to:
  /// **'Katılan {n} kişiye bildirim gider ve sohbet kapanır. Bu işlem geri alınamaz.'**
  String etkinlik2SettingsCancelBody(String n);

  /// No description provided for @etkinlik2SettingsSaved.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar kaydedildi.'**
  String get etkinlik2SettingsSaved;

  /// No description provided for @etkinlik2QrManualCaption.
  ///
  /// In tr, this message translates to:
  /// **'KODU ELLE GİRMEK İÇİN'**
  String get etkinlik2QrManualCaption;

  /// No description provided for @etkinlik2QrRenewsIn.
  ///
  /// In tr, this message translates to:
  /// **'Kod {n} sn sonra yenilenir'**
  String etkinlik2QrRenewsIn(String n);

  /// No description provided for @etkinlik2AttendanceLabel.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama'**
  String get etkinlik2AttendanceLabel;

  /// No description provided for @etkinlik2PresentOf.
  ///
  /// In tr, this message translates to:
  /// **'{present} / {total} kişi geldi'**
  String etkinlik2PresentOf(String present, String total);

  /// No description provided for @etkinlik2FilterAll.
  ///
  /// In tr, this message translates to:
  /// **'Hepsi'**
  String get etkinlik2FilterAll;

  /// No description provided for @etkinlik2FilterPresent.
  ///
  /// In tr, this message translates to:
  /// **'Geldi'**
  String get etkinlik2FilterPresent;

  /// No description provided for @etkinlik2FilterAbsent.
  ///
  /// In tr, this message translates to:
  /// **'Gelmedi'**
  String get etkinlik2FilterAbsent;

  /// No description provided for @etkinlik2MarkSem.
  ///
  /// In tr, this message translates to:
  /// **'{name} geldi olarak işaretle'**
  String etkinlik2MarkSem(String name);

  /// No description provided for @etkinlik2MethodQr.
  ///
  /// In tr, this message translates to:
  /// **'QR'**
  String get etkinlik2MethodQr;

  /// No description provided for @etkinlik2MethodManual.
  ///
  /// In tr, this message translates to:
  /// **'Elle'**
  String get etkinlik2MethodManual;

  /// No description provided for @etkinlik2ShowQrSem.
  ///
  /// In tr, this message translates to:
  /// **'QR kodunu göster'**
  String get etkinlik2ShowQrSem;

  /// No description provided for @etkinlik2AttendanceEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Gösterilecek katılımcı yok.'**
  String get etkinlik2AttendanceEmpty;

  /// No description provided for @etkinlik2MarkFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama güncellenemedi.'**
  String get etkinlik2MarkFailed;

  /// No description provided for @etkinlik2ChatClosedToast.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet kapatıldı.'**
  String get etkinlik2ChatClosedToast;

  /// No description provided for @etkinlik2ChatOpenedToast.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet açıldı.'**
  String get etkinlik2ChatOpenedToast;

  /// No description provided for @etkinlik2NoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Organizatöre not (isteğe bağlı)'**
  String get etkinlik2NoteLabel;

  /// No description provided for @etkinlik2AnswerRequired.
  ///
  /// In tr, this message translates to:
  /// **'Tüm soruları yanıtlamalısın.'**
  String get etkinlik2AnswerRequired;

  /// No description provided for @etkinlik2ClubSemPrefix.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get etkinlik2ClubSemPrefix;

  /// No description provided for @cevrimdisiBekleyenMesaj.
  ///
  /// In tr, this message translates to:
  /// **'{n} mesaj bağlantı gelince gönderilecek'**
  String cevrimdisiBekleyenMesaj(String n);

  /// No description provided for @cevrimdisiGonderiliyor.
  ///
  /// In tr, this message translates to:
  /// **'{n} mesaj gönderiliyor…'**
  String cevrimdisiGonderiliyor(String n);

  /// No description provided for @cevrimdisiGonderilemedi.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilmedi'**
  String get cevrimdisiGonderilemedi;

  /// No description provided for @cevrimdisiSonGuncelleme.
  ///
  /// In tr, this message translates to:
  /// **'Son güncelleme: {zaman}'**
  String cevrimdisiSonGuncelleme(String zaman);

  /// No description provided for @cevrimdisiKayitliVeri.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı veriler gösteriliyor'**
  String get cevrimdisiKayitliVeri;

  /// No description provided for @cevrimdisiBekliyor.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get cevrimdisiBekliyor;

  /// No description provided for @cevrimdisiYenidenDene.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get cevrimdisiYenidenDene;

  /// No description provided for @cevrimdisiMedyaBaglanti.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı gelince tekrar deneyin'**
  String get cevrimdisiMedyaBaglanti;

  /// No description provided for @cevrimdisiInternetYok.
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı yok'**
  String get cevrimdisiInternetYok;

  /// No description provided for @bildirimmobilKanalChat.
  ///
  /// In tr, this message translates to:
  /// **'Mesajlar'**
  String get bildirimmobilKanalChat;

  /// No description provided for @bildirimmobilKanalEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler'**
  String get bildirimmobilKanalEvent;

  /// No description provided for @bildirimmobilKanalAnnouncement.
  ///
  /// In tr, this message translates to:
  /// **'Duyurular ve haberler'**
  String get bildirimmobilKanalAnnouncement;

  /// No description provided for @bildirimmobilKanalSocial.
  ///
  /// In tr, this message translates to:
  /// **'Sosyal (beğeni, takip)'**
  String get bildirimmobilKanalSocial;

  /// No description provided for @bildirimmobilKanalPoll.
  ///
  /// In tr, this message translates to:
  /// **'Anketler'**
  String get bildirimmobilKanalPoll;

  /// No description provided for @bildirimmobilKanalAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Ders ve sınav hatırlatmaları'**
  String get bildirimmobilKanalAcademic;

  /// No description provided for @evcLabelClub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp'**
  String get evcLabelClub;

  /// No description provided for @evcInfoInstant.
  ///
  /// In tr, this message translates to:
  /// **'Hemen yayınlanır.'**
  String get evcInfoInstant;

  /// No description provided for @evcInfoReview.
  ///
  /// In tr, this message translates to:
  /// **'Admin onayından sonra yayınlanır.'**
  String get evcInfoReview;

  /// No description provided for @evcClubRequiredHint.
  ///
  /// In tr, this message translates to:
  /// **'Önce bir kulüp seç.'**
  String get evcClubRequiredHint;

  /// No description provided for @evcEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın'**
  String get evcEmptyTitle;

  /// No description provided for @evcEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlikler kulüpler adına açılır. Bir kulübün yöneticisi olduğunda burada etkinlik oluşturabilirsin.'**
  String get evcEmptyBody;

  /// No description provided for @evcBrowseClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüplere göz at'**
  String get evcBrowseClubs;

  /// No description provided for @evcSubmittedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Onaya gönderildi'**
  String get evcSubmittedTitle;

  /// No description provided for @evcSubmittedBody.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğin admin onayından sonra yayınlanacak. Durumunu Oluşturduklarım sekmesinden takip edebilirsin.'**
  String get evcSubmittedBody;

  /// No description provided for @evcOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get evcOk;

  /// No description provided for @evcStatusPending.
  ///
  /// In tr, this message translates to:
  /// **'Onay bekliyor'**
  String get evcStatusPending;

  /// No description provided for @evcStatusRejected.
  ///
  /// In tr, this message translates to:
  /// **'Reddedildi'**
  String get evcStatusRejected;

  /// No description provided for @evcRejectReason.
  ///
  /// In tr, this message translates to:
  /// **'Neden: {reason}'**
  String evcRejectReason(String reason);

  /// No description provided for @evcErrClubRequired.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik bir kulüp adına oluşturulmalı. Bir kulüp seç.'**
  String get evcErrClubRequired;

  /// No description provided for @evcErrForbidden.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulüp adına etkinlik oluşturma yetkin yok.'**
  String get evcErrForbidden;

  /// No description provided for @evcErrClubNotActive.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulüp şu anda etkin değil.'**
  String get evcErrClubNotActive;

  /// No description provided for @evcErrPast.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik başlangıcı geçmişte olamaz.'**
  String get evcErrPast;

  /// No description provided for @evcErrDates.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş, başlangıçtan sonra olmalı.'**
  String get evcErrDates;

  /// No description provided for @evcErrProfanity.
  ///
  /// In tr, this message translates to:
  /// **'Metinde uygunsuz ifade var. Lütfen düzenle.'**
  String get evcErrProfanity;

  /// No description provided for @evdLabelDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get evdLabelDate;

  /// No description provided for @evdLabelTime.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç saati'**
  String get evdLabelTime;

  /// No description provided for @evdLabelDuration.
  ///
  /// In tr, this message translates to:
  /// **'Süre'**
  String get evdLabelDuration;

  /// No description provided for @evdChipToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get evdChipToday;

  /// No description provided for @evdChipTomorrow.
  ///
  /// In tr, this message translates to:
  /// **'Yarın'**
  String get evdChipTomorrow;

  /// No description provided for @evdChipWeekend.
  ///
  /// In tr, this message translates to:
  /// **'Bu hafta sonu'**
  String get evdChipWeekend;

  /// No description provided for @evdChipNextWeek.
  ///
  /// In tr, this message translates to:
  /// **'Gelecek hafta'**
  String get evdChipNextWeek;

  /// No description provided for @evdChipPickDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih seç'**
  String get evdChipPickDate;

  /// No description provided for @evdChipCustomTime.
  ///
  /// In tr, this message translates to:
  /// **'Özel saat'**
  String get evdChipCustomTime;

  /// No description provided for @evdDur1h.
  ///
  /// In tr, this message translates to:
  /// **'1 saat'**
  String get evdDur1h;

  /// No description provided for @evdDur2h.
  ///
  /// In tr, this message translates to:
  /// **'2 saat'**
  String get evdDur2h;

  /// No description provided for @evdDurHalfDay.
  ///
  /// In tr, this message translates to:
  /// **'Yarım gün'**
  String get evdDurHalfDay;

  /// No description provided for @evdChipCustomEnd.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş tarihi seç'**
  String get evdChipCustomEnd;

  /// No description provided for @evdErrStartPast.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç geçmişte olamaz.'**
  String get evdErrStartPast;

  /// No description provided for @evdErrEndBeforeStart.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş, başlangıçtan sonra olmalı.'**
  String get evdErrEndBeforeStart;

  /// No description provided for @evdEndAdjusted.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş, başlangıçtan 1 saat sonrasına otomatik ayarlandı.'**
  String get evdEndAdjusted;

  /// No description provided for @evdDescCounter.
  ///
  /// In tr, this message translates to:
  /// **'{count}/{max}'**
  String evdDescCounter(String count, String max);

  /// No description provided for @evdErrDescTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama en fazla {max} karakter olabilir.'**
  String evdErrDescTooLong(String max);

  /// No description provided for @evdErrDescTooLongServer.
  ///
  /// In tr, this message translates to:
  /// **'Açıklama çok uzun. Lütfen kısalt.'**
  String get evdErrDescTooLongServer;

  /// No description provided for @clubMgmtCategoryNone.
  ///
  /// In tr, this message translates to:
  /// **'Seçilmedi'**
  String get clubMgmtCategoryNone;

  /// No description provided for @clubMgmtCategoryInactive.
  ///
  /// In tr, this message translates to:
  /// **'{name} (kullanım dışı)'**
  String clubMgmtCategoryInactive(String name);

  /// No description provided for @clubMgmtCategoryInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Seçilen kategori geçerli değil. Listeden başka bir kategori seç.'**
  String get clubMgmtCategoryInvalid;

  /// No description provided for @errEmailAliasNotAllowed.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresinde + etiketi kullanılamaz. Adresinizi + işareti olmadan yazın.'**
  String get errEmailAliasNotAllowed;

  /// No description provided for @errPasswordTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Şifre çok uzun: en fazla 72 bayt olabilir (Türkçe ve Arapça karakterler birden çok bayt tutar).'**
  String get errPasswordTooLong;

  /// No description provided for @errPayloadTooLarge.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilen veri çok büyük. Daha küçük bir dosya ya da daha kısa bir metin deneyin.'**
  String get errPayloadTooLarge;

  /// No description provided for @errUploadBusy.
  ///
  /// In tr, this message translates to:
  /// **'Başka bir yüklemeniz sürüyor ya da sunucu yoğun. Biraz bekleyip tekrar deneyin.'**
  String get errUploadBusy;

  /// No description provided for @errUploadQuota.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla yükleme yaptınız. Biraz sonra tekrar deneyin.'**
  String get errUploadQuota;

  /// No description provided for @errMailQuota.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda doğrulama kodu gönderemiyoruz. Lütfen daha sonra tekrar deneyin.'**
  String get errMailQuota;

  /// No description provided for @errServiceBusy.
  ///
  /// In tr, this message translates to:
  /// **'Sistem şu an yoğun. Lütfen birkaç saniye sonra tekrar deneyin.'**
  String get errServiceBusy;

  /// No description provided for @errLegalReaccept.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşmeler güncellendi. Devam etmek için güncel sözleşmeleri onaylamanız gerekiyor.'**
  String get errLegalReaccept;

  /// No description provided for @coreErrRetryAfterSec.
  ///
  /// In tr, this message translates to:
  /// **'{n} sn sonra tekrar deneyin.'**
  String coreErrRetryAfterSec(String n);

  /// No description provided for @coreErrRetryAfterMin.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk sonra tekrar deneyin.'**
  String coreErrRetryAfterMin(String n);

  /// No description provided for @clubPostTextRequired.
  ///
  /// In tr, this message translates to:
  /// **'Görselle paylaşmak için bir yazı da ekleyin.'**
  String get clubPostTextRequired;

  /// No description provided for @etkinlik2QrExpired.
  ///
  /// In tr, this message translates to:
  /// **'Süresi doldu, yenileniyor…'**
  String get etkinlik2QrExpired;

  /// No description provided for @updateRequiredRecheck.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar kontrol et'**
  String get updateRequiredRecheck;

  /// No description provided for @legalReacceptTitle.
  ///
  /// In tr, this message translates to:
  /// **'Sözleşmeler güncellendi'**
  String get legalReacceptTitle;

  /// No description provided for @legalReacceptIntro.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım koşulları ve gizlilik metinlerinde değişiklik yaptık. Uygulamayı kullanmaya devam etmek için güncellenen belgeleri okuyup kabul etmeniz gerekiyor.'**
  String get legalReacceptIntro;

  /// No description provided for @legalReacceptIntroSoft.
  ///
  /// In tr, this message translates to:
  /// **'Bazı belgelerin yeni sürümü yayımlandı. Şimdi inceleyip kabul edebilir ya da daha sonraya bırakabilirsiniz; ilerleyen günlerde kabul etmeniz gerekecek.'**
  String get legalReacceptIntroSoft;

  /// No description provided for @legalReacceptListTitle.
  ///
  /// In tr, this message translates to:
  /// **'Güncellenen belgeler'**
  String get legalReacceptListTitle;

  /// No description provided for @legalReacceptTypeTerms.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get legalReacceptTypeTerms;

  /// No description provided for @legalReacceptTypePrivacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get legalReacceptTypePrivacy;

  /// No description provided for @legalReacceptTypeKvkk.
  ///
  /// In tr, this message translates to:
  /// **'KVKK Aydınlatma Metni'**
  String get legalReacceptTypeKvkk;

  /// No description provided for @legalReacceptTypeRules.
  ///
  /// In tr, this message translates to:
  /// **'Topluluk Kuralları'**
  String get legalReacceptTypeRules;

  /// No description provided for @legalReacceptNoteExplicit.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı açık rıza izinleri bu onaydan ayrıdır; bu işlemle verilmiş sayılmaz.'**
  String get legalReacceptNoteExplicit;

  /// No description provided for @legalReacceptCheck.
  ///
  /// In tr, this message translates to:
  /// **'Güncellenen belgeleri okudum ve kabul ediyorum'**
  String get legalReacceptCheck;

  /// No description provided for @legalReacceptAccept.
  ///
  /// In tr, this message translates to:
  /// **'Kabul et'**
  String get legalReacceptAccept;

  /// No description provided for @legalReacceptLater.
  ///
  /// In tr, this message translates to:
  /// **'Daha sonra'**
  String get legalReacceptLater;

  /// No description provided for @legalReacceptDecline.
  ///
  /// In tr, this message translates to:
  /// **'Kabul etmiyorum'**
  String get legalReacceptDecline;

  /// No description provided for @legalReacceptDeclineTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kabul etmeden devam edilemez'**
  String get legalReacceptDeclineTitle;

  /// No description provided for @legalReacceptDeclineBody.
  ///
  /// In tr, this message translates to:
  /// **'Güncel sözleşmeleri kabul etmezseniz uygulamayı kullanamazsınız. Hesabınızı silebilir ya da çıkış yapıp daha sonra tekrar karar verebilirsiniz.'**
  String get legalReacceptDeclineBody;

  /// No description provided for @legalReacceptDeleteAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabımı sil'**
  String get legalReacceptDeleteAccount;

  /// No description provided for @legalReacceptSignOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış yap'**
  String get legalReacceptSignOut;

  /// No description provided for @legalReacceptOutdated.
  ///
  /// In tr, this message translates to:
  /// **'Belgeler yeniden güncellendi. Lütfen yeni sürümleri inceleyip tekrar kabul edin.'**
  String get legalReacceptOutdated;

  /// No description provided for @authVerifyPasswordLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtta belirlediğiniz şifre'**
  String get authVerifyPasswordLabel;

  /// No description provided for @authVerifyPasswordNote.
  ///
  /// In tr, this message translates to:
  /// **'Güvenlik için, kayıt sırasında girdiğiniz şifreyi yeniden girin.'**
  String get authVerifyPasswordNote;

  /// No description provided for @authVerifyPasswordRequired.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtta belirlediğiniz şifreyi girin.'**
  String get authVerifyPasswordRequired;

  /// No description provided for @chatClosedBanner.
  ///
  /// In tr, this message translates to:
  /// **'Bu sohbet yönetici tarafından kapatıldı.'**
  String get chatClosedBanner;

  /// No description provided for @chatAdminRemovedMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu mesaj yönetici tarafından kaldırıldı'**
  String get chatAdminRemovedMsg;

  /// No description provided for @chatModRemovedMsg.
  ///
  /// In tr, this message translates to:
  /// **'Bu mesaj kaldırıldı'**
  String get chatModRemovedMsg;

  /// No description provided for @errCertificateRevoked.
  ///
  /// In tr, this message translates to:
  /// **'Bu sertifika yönetici tarafından iptal edildi.'**
  String get errCertificateRevoked;

  /// No description provided for @clubUnavailable.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp şu an kullanılamıyor.'**
  String get clubUnavailable;

  /// No description provided for @profil2DelItemUsage.
  ///
  /// In tr, this message translates to:
  /// **'Cihaz, IP ve kullanım (analitik) kayıtların anında silinir.'**
  String get profil2DelItemUsage;

  /// No description provided for @profil2DelItemClubOwner.
  ///
  /// In tr, this message translates to:
  /// **'Sahibi olduğun kulüpler yönetici üyeye devredilir; aday yoksa kulüp kapatılır.'**
  String get profil2DelItemClubOwner;

  /// No description provided for @settingsCrashReports.
  ///
  /// In tr, this message translates to:
  /// **'Hata raporu gönder'**
  String get settingsCrashReports;

  /// No description provided for @settingsCrashReportsDesc.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama hata verdiğinde veya kapandığında anonim bir hata raporu BÜ Kampüs sunucusuna gönderilir: uygulama sürümü, işletim sistemi, hata türü ve kişisel veri içermeyen teknik bir yığın izi. E-posta, şifre, mesaj içeriği veya kimliğiniz gönderilmez; üçüncü taraf hizmete aktarılmaz. İstediğiniz zaman kapatabilirsiniz.'**
  String get settingsCrashReportsDesc;

  /// No description provided for @welcomeChipNews.
  ///
  /// In tr, this message translates to:
  /// **'Haberler'**
  String get welcomeChipNews;

  /// No description provided for @welcomeChipMenu.
  ///
  /// In tr, this message translates to:
  /// **'Yemek'**
  String get welcomeChipMenu;

  /// No description provided for @welcomeChipClubs.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpler'**
  String get welcomeChipClubs;

  /// No description provided for @authLangTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dil seçin'**
  String get authLangTitle;

  /// No description provided for @authPaste.
  ///
  /// In tr, this message translates to:
  /// **'Yapıştır'**
  String get authPaste;

  /// No description provided for @authResetDoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şifreniz güncellendi'**
  String get authResetDoneTitle;

  /// No description provided for @authResetDoneBody.
  ///
  /// In tr, this message translates to:
  /// **'Yeni şifrenizle giriş yapabilirsiniz. Diğer cihazlardaki oturumlar kapatıldı.'**
  String get authResetDoneBody;

  /// No description provided for @authTrustAcademic.
  ///
  /// In tr, this message translates to:
  /// **'Bölümünüz, size uygun duyuru ve kulüpleri göstermek için kullanılır.'**
  String get authTrustAcademic;

  /// No description provided for @authTrustName.
  ///
  /// In tr, this message translates to:
  /// **'Adınız profilinizde ve sohbetlerde diğer öğrencilere görünür.'**
  String get authTrustName;

  /// No description provided for @authTrustPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifreniz yalnızca özeti alınarak saklanır; kimse göremez.'**
  String get authTrustPassword;

  /// No description provided for @authTrustCode.
  ///
  /// In tr, this message translates to:
  /// **'E-posta gelmediyse gereksiz (spam) klasörünü de kontrol edin.'**
  String get authTrustCode;

  /// No description provided for @authTrustSecure.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantınız şifreli ve güvenlidir.'**
  String get authTrustSecure;

  /// No description provided for @p00StepOf.
  ///
  /// In tr, this message translates to:
  /// **'Adım {current} / {total}'**
  String p00StepOf(String current, String total);

  /// No description provided for @p05NewsEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Yeni içerikler geldiğinde burada görünecek.'**
  String get p05NewsEmptyBody;

  /// No description provided for @p05SavedEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz favorin yok'**
  String get p05SavedEmptyTitle;

  /// No description provided for @p05SavedToast.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere eklendi'**
  String get p05SavedToast;

  /// No description provided for @p05UnsavedToast.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden çıkarıldı'**
  String get p05UnsavedToast;

  /// No description provided for @p05SearchIdleTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kampüste ara'**
  String get p05SearchIdleTitle;

  /// No description provided for @p05SearchNoResultsBody.
  ///
  /// In tr, this message translates to:
  /// **'Farklı bir kelime deneyin veya yazımı kontrol edin.'**
  String get p05SearchNoResultsBody;

  /// No description provided for @p05Source.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak'**
  String get p05Source;

  /// No description provided for @p05ReadMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{count} dk okuma'**
  String p05ReadMinutes(String count);

  /// No description provided for @p17WeekOf.
  ///
  /// In tr, this message translates to:
  /// **'Hafta {n} / {total}'**
  String p17WeekOf(String n, String total);

  /// No description provided for @p17SemesterName.
  ///
  /// In tr, this message translates to:
  /// **'Dönem adı'**
  String get p17SemesterName;

  /// No description provided for @p17NoClassesTitle.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık programın boş'**
  String get p17NoClassesTitle;

  /// No description provided for @p17ExamsEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz sınav yok'**
  String get p17ExamsEmptyTitle;

  /// No description provided for @p17OfficialEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Resmi program yayınlanmadı'**
  String get p17OfficialEmptyTitle;

  /// No description provided for @p17SemestersEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Dönem yok'**
  String get p17SemestersEmptyTitle;

  /// No description provided for @p17MaintenanceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bakım çalışması'**
  String get p17MaintenanceTitle;

  /// No description provided for @p17PreviewHint.
  ///
  /// In tr, this message translates to:
  /// **'Önizleme'**
  String get p17PreviewHint;

  /// No description provided for @p16QrCopy.
  ///
  /// In tr, this message translates to:
  /// **'Kodu kopyala'**
  String get p16QrCopy;

  /// No description provided for @p16QrCopied.
  ///
  /// In tr, this message translates to:
  /// **'Kod kopyalandı'**
  String get p16QrCopied;

  /// No description provided for @p16ReqNoneBody.
  ///
  /// In tr, this message translates to:
  /// **'Yeni katılma istekleri geldiğinde burada görünür.'**
  String get p16ReqNoneBody;

  /// No description provided for @p16AttEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar etkinliğe katıldıkça burada listelenir.'**
  String get p16AttEmptyBody;

  /// No description provided for @p16AttFilterEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu süzgece uyan kimse yok.'**
  String get p16AttFilterEmpty;

  /// No description provided for @p16PolicyOpenHint.
  ///
  /// In tr, this message translates to:
  /// **'Herkes istek göndermeden doğrudan katılır.'**
  String get p16PolicyOpenHint;

  /// No description provided for @p16AttPresentCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} geldi'**
  String p16AttPresentCount(String n);

  /// No description provided for @p10PageTitle.
  ///
  /// In tr, this message translates to:
  /// **'Medya ekle'**
  String get p10PageTitle;

  /// No description provided for @p10SheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get p10SheetTitle;

  /// No description provided for @p10SheetSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Sohbete ne göndermek istersin?'**
  String get p10SheetSubtitle;

  /// No description provided for @p10SourcePhotos.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf'**
  String get p10SourcePhotos;

  /// No description provided for @p10SourcePhotosHint.
  ///
  /// In tr, this message translates to:
  /// **'Galerinden bir ya da birkaç fotoğraf seç'**
  String get p10SourcePhotosHint;

  /// No description provided for @p10SourceVideo.
  ///
  /// In tr, this message translates to:
  /// **'Video'**
  String get p10SourceVideo;

  /// No description provided for @p10SourceVideoHint.
  ///
  /// In tr, this message translates to:
  /// **'Galerinden video seç (en fazla 60 sn)'**
  String get p10SourceVideoHint;

  /// No description provided for @p10SourceCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamera'**
  String get p10SourceCamera;

  /// No description provided for @p10SourceCameraHint.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf çek ya da video kaydet'**
  String get p10SourceCameraHint;

  /// No description provided for @p10PrivacyNote.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca seçtiğin öğelere erişilir; galerinin tamamı uygulamaya açılmaz.'**
  String get p10PrivacyNote;

  /// No description provided for @p10PickedHeader.
  ///
  /// In tr, this message translates to:
  /// **'Seçilenler'**
  String get p10PickedHeader;

  /// No description provided for @p10EmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz bir şey seçmedin'**
  String get p10EmptyTitle;

  /// No description provided for @p10EmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Yukarıdan fotoğraf, video ya da kamerayı seçerek başla.'**
  String get p10EmptyBody;

  /// No description provided for @p10Preview.
  ///
  /// In tr, this message translates to:
  /// **'Önizle'**
  String get p10Preview;

  /// No description provided for @p10Remove.
  ///
  /// In tr, this message translates to:
  /// **'Kaldır'**
  String get p10Remove;

  /// No description provided for @p10PickFailed.
  ///
  /// In tr, this message translates to:
  /// **'Seçici açılamadı. Lütfen tekrar dene.'**
  String get p10PickFailed;

  /// No description provided for @p14Today.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get p14Today;

  /// No description provided for @p14Tomorrow.
  ///
  /// In tr, this message translates to:
  /// **'Yarın'**
  String get p14Tomorrow;

  /// No description provided for @p14ClearDay.
  ///
  /// In tr, this message translates to:
  /// **'Tüm ay'**
  String get p14ClearDay;

  /// No description provided for @p14Ended.
  ///
  /// In tr, this message translates to:
  /// **'Sona erdi'**
  String get p14Ended;

  /// No description provided for @p14Live.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi'**
  String get p14Live;

  /// No description provided for @p14EventCount.
  ///
  /// In tr, this message translates to:
  /// **'{count, plural, other{{count} etkinlik}}'**
  String p14EventCount(int count);

  /// No description provided for @p14EmptyMonthBody.
  ///
  /// In tr, this message translates to:
  /// **'Başka bir aya göz at; yeni etkinlikler eklendikçe burada görünür.'**
  String get p14EmptyMonthBody;

  /// No description provided for @p14EmptyDayBody.
  ///
  /// In tr, this message translates to:
  /// **'Başka bir gün seç ya da tüm ayı gör.'**
  String get p14EmptyDayBody;

  /// No description provided for @p14EmptyUpcomingBody.
  ///
  /// In tr, this message translates to:
  /// **'Kulüplerin etkinliklerine katıl; katıldıkların burada toplanır.'**
  String get p14EmptyUpcomingBody;

  /// No description provided for @p14EmptyPastBody.
  ///
  /// In tr, this message translates to:
  /// **'Katıldığın etkinlikler bittikten sonra burada saklanır.'**
  String get p14EmptyPastBody;

  /// No description provided for @p14EmptyCreatedBody.
  ///
  /// In tr, this message translates to:
  /// **'Kulübün adına bir etkinlik oluştur; başvuruları ve yoklamayı buradan yönet.'**
  String get p14EmptyCreatedBody;

  /// No description provided for @p13SuppAskTitle.
  ///
  /// In tr, this message translates to:
  /// **'Size nasıl yardımcı olabiliriz?'**
  String get p13SuppAskTitle;

  /// No description provided for @p13SuppAskBody.
  ///
  /// In tr, this message translates to:
  /// **'Sık sorulan sorulara göz atın ya da destek ekibine yazın.'**
  String get p13SuppAskBody;

  /// No description provided for @p13TicketIntro.
  ///
  /// In tr, this message translates to:
  /// **'Sorununuzu kısaca anlatın; destek ekibi en kısa sürede yanıt verecek.'**
  String get p13TicketIntro;

  /// No description provided for @p13TicketsEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir sorun yaşarsanız yeni bir talep oluşturabilirsiniz.'**
  String get p13TicketsEmptyHint;

  /// No description provided for @p13FeedbackEmptyHint.
  ///
  /// In tr, this message translates to:
  /// **'Gönderdiğiniz öneri ve hata bildirimleri burada listelenir.'**
  String get p13FeedbackEmptyHint;

  /// No description provided for @p13SugEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Fikirler burada toplanır'**
  String get p13SugEmptyTitle;

  /// No description provided for @p13PollEmptyOpenHint.
  ///
  /// In tr, this message translates to:
  /// **'Yeni anketler açıldığında burada görünür.'**
  String get p13PollEmptyOpenHint;

  /// No description provided for @p13PollEmptyMineHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir ankete oy verdiğinizde burada listelenir.'**
  String get p13PollEmptyMineHint;

  /// No description provided for @p13PollEmptyClosedHint.
  ///
  /// In tr, this message translates to:
  /// **'Sona eren anketlerin sonuçları burada saklanır.'**
  String get p13PollEmptyClosedHint;

  /// No description provided for @p13Rate1.
  ///
  /// In tr, this message translates to:
  /// **'Çok kötü'**
  String get p13Rate1;

  /// No description provided for @p13Rate2.
  ///
  /// In tr, this message translates to:
  /// **'Kötü'**
  String get p13Rate2;

  /// No description provided for @p13Rate3.
  ///
  /// In tr, this message translates to:
  /// **'Orta'**
  String get p13Rate3;

  /// No description provided for @p13Rate4.
  ///
  /// In tr, this message translates to:
  /// **'İyi'**
  String get p13Rate4;

  /// No description provided for @p13Rate5.
  ///
  /// In tr, this message translates to:
  /// **'Çok iyi'**
  String get p13Rate5;

  /// No description provided for @p13Leading.
  ///
  /// In tr, this message translates to:
  /// **'Önde'**
  String get p13Leading;

  /// No description provided for @p08ItemOf.
  ///
  /// In tr, this message translates to:
  /// **'{n} / {total}'**
  String p08ItemOf(String n, String total);

  /// No description provided for @p08Pause.
  ///
  /// In tr, this message translates to:
  /// **'Duraklat'**
  String get p08Pause;

  /// No description provided for @p08Seek.
  ///
  /// In tr, this message translates to:
  /// **'Video konumu'**
  String get p08Seek;

  /// No description provided for @p08OnceHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapattığında bu fotoğraf bir daha açılamaz.'**
  String get p08OnceHint;

  /// No description provided for @p13TicketsHeading.
  ///
  /// In tr, this message translates to:
  /// **'Taleplerim'**
  String get p13TicketsHeading;

  /// No description provided for @p13ShareHeading.
  ///
  /// In tr, this message translates to:
  /// **'Görüşünüzü paylaşın'**
  String get p13ShareHeading;

  /// No description provided for @p13FeedbackMine.
  ///
  /// In tr, this message translates to:
  /// **'Gönderdiklerim'**
  String get p13FeedbackMine;

  /// No description provided for @p11ReadMore.
  ///
  /// In tr, this message translates to:
  /// **'Devamını göster'**
  String get p11ReadMore;

  /// No description provided for @p11ReadLess.
  ///
  /// In tr, this message translates to:
  /// **'Daha az göster'**
  String get p11ReadLess;

  /// No description provided for @p11TypeSingleHint.
  ///
  /// In tr, this message translates to:
  /// **'Tek bir seçenek işaretlenir'**
  String get p11TypeSingleHint;

  /// No description provided for @p11TypeMultiHint.
  ///
  /// In tr, this message translates to:
  /// **'Birden fazla seçenek işaretlenebilir'**
  String get p11TypeMultiHint;

  /// No description provided for @p11TypeRankedHint.
  ///
  /// In tr, this message translates to:
  /// **'Seçenekler tercih sırasına dizilir'**
  String get p11TypeRankedHint;

  /// No description provided for @p11TypeRatingHint.
  ///
  /// In tr, this message translates to:
  /// **'1-5 yıldızla puanlanır'**
  String get p11TypeRatingHint;

  /// No description provided for @p11RequestsEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Yeni katılma istekleri geldiğinde burada görünecek.'**
  String get p11RequestsEmptyBody;

  /// No description provided for @p06EmptyNoneBody.
  ///
  /// In tr, this message translates to:
  /// **'Arkadaşlarınızla, öğrenci kulüpleriyle veya etkinlik gruplarıyla mesajlaşmaya başlayın.'**
  String get p06EmptyNoneBody;

  /// No description provided for @p06NoMatchBody.
  ///
  /// In tr, this message translates to:
  /// **'“{q}” aramasıyla eşleşen kişi, kulüp veya mesaj bulunamadı.'**
  String p06NoMatchBody(String q);

  /// No description provided for @p06ResetSearch.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı sıfırla'**
  String get p06ResetSearch;

  /// No description provided for @p06ArchiveEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Arşivlediğiniz sohbetler burada saklanır ve mesaj kutunuzu sade tutar.'**
  String get p06ArchiveEmptyBody;

  /// No description provided for @p06BackToChats.
  ///
  /// In tr, this message translates to:
  /// **'Sohbetlere dön'**
  String get p06BackToChats;

  /// No description provided for @p06LoadFailedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi, tekrar dene'**
  String get p06LoadFailedTitle;

  /// No description provided for @p06LoadFailedBody.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet listesi güncellenirken bir bağlantı hatası oluştu. Lütfen bağlantınızı kontrol edin.'**
  String get p06LoadFailedBody;

  /// No description provided for @p06MenuDeleteChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbeti sil'**
  String get p06MenuDeleteChat;

  /// No description provided for @p08OnceSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bir kez görüntülenebilir'**
  String get p08OnceSubtitle;

  /// No description provided for @p08OnceSentSub.
  ///
  /// In tr, this message translates to:
  /// **'Tek seferlik görünüm'**
  String get p08OnceSentSub;

  /// No description provided for @p08ModerationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Moderasyon bildirimi'**
  String get p08ModerationTitle;

  /// No description provided for @p08Percent.
  ///
  /// In tr, this message translates to:
  /// **'%{n}'**
  String p08Percent(String n);

  /// No description provided for @p08PhotoLoadingSub.
  ///
  /// In tr, this message translates to:
  /// **'Sunucudan indiriliyor'**
  String get p08PhotoLoadingSub;

  /// No description provided for @p08Queued.
  ///
  /// In tr, this message translates to:
  /// **'Kuyrukta · Bekliyor'**
  String get p08Queued;

  /// No description provided for @p01ConfigTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yapılandırma hatası'**
  String get p01ConfigTitle;

  /// No description provided for @p01ConfigBody.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu adresi (API_BASE) güvenli (https) değil. Uygulamayı doğru adresle yeniden derleyin.'**
  String get p01ConfigBody;

  /// No description provided for @p01ConfigCode.
  ///
  /// In tr, this message translates to:
  /// **'HATA KODU • BUILD_ENV'**
  String get p01ConfigCode;

  /// No description provided for @p01UpdateNoticeLabel.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama Güncellemesi'**
  String get p01UpdateNoticeLabel;

  /// No description provided for @p01PushNow.
  ///
  /// In tr, this message translates to:
  /// **'şimdi'**
  String get p01PushNow;

  /// No description provided for @p01PushMore.
  ///
  /// In tr, this message translates to:
  /// **'+{n} yeni mesaj daha'**
  String p01PushMore(String n);

  /// No description provided for @p01PushReply.
  ///
  /// In tr, this message translates to:
  /// **'Cevaplamak için dokun'**
  String get p01PushReply;

  /// No description provided for @p01PermDeniedTitle.
  ///
  /// In tr, this message translates to:
  /// **'{title} izni verilmedi'**
  String p01PermDeniedTitle(String title);

  /// No description provided for @p01QrAttended.
  ///
  /// In tr, this message translates to:
  /// **'Yoklaman alındı'**
  String get p01QrAttended;

  /// No description provided for @p07ChatEmptyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Henüz mesaj yok'**
  String get p07ChatEmptyTitle;

  /// No description provided for @p07ChatEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'İlk mesajı sen yaz.'**
  String get p07ChatEmptyBody;

  /// No description provided for @p07ChatBlockedLine.
  ///
  /// In tr, this message translates to:
  /// **'Engellediğiniz kişiyle mesajlaşamazsınız.'**
  String get p07ChatBlockedLine;

  /// No description provided for @p02WelcomeNewsSub.
  ///
  /// In tr, this message translates to:
  /// **'Anlık bildirimler ve kampüs içi gelişmeler.'**
  String get p02WelcomeNewsSub;

  /// No description provided for @p02WelcomeMenuSub.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kalori ve detaylı öğün içerikleri.'**
  String get p02WelcomeMenuSub;

  /// No description provided for @p02WelcomeClubsSub.
  ///
  /// In tr, this message translates to:
  /// **'Topluluklar, atölyeler ve katılım yoklaması.'**
  String get p02WelcomeClubsSub;

  /// No description provided for @p02BrandSub.
  ///
  /// In tr, this message translates to:
  /// **'Bağımsız öğrenci uygulaması'**
  String get p02BrandSub;

  /// No description provided for @p02LoginBusy.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yapılıyor…'**
  String get p02LoginBusy;

  /// No description provided for @p02PwStrengthTitle.
  ///
  /// In tr, this message translates to:
  /// **'Şifre gücü'**
  String get p02PwStrengthTitle;

  /// No description provided for @p02TipTitle.
  ///
  /// In tr, this message translates to:
  /// **'İpucu'**
  String get p02TipTitle;

  /// No description provided for @p02FacultyCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} Bölüm'**
  String p02FacultyCount(String n);

  /// No description provided for @p02PendingTitle.
  ///
  /// In tr, this message translates to:
  /// **'E-postanı doğrula'**
  String get p02PendingTitle;

  /// No description provided for @p02PendingBody.
  ///
  /// In tr, this message translates to:
  /// **'Giriş yapabilmek için hesabının doğrulanması gerekir.'**
  String get p02PendingBody;

  /// No description provided for @p02ReplacedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Oturum sonlandırıldı'**
  String get p02ReplacedTitle;

  /// No description provided for @p01LgLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi, tekrar dene'**
  String get p01LgLoadFailed;

  /// No description provided for @p01LgMetaLine.
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version} · Yürürlük: {date}'**
  String p01LgMetaLine(String version, String date);

  /// No description provided for @p03MenuTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam'**
  String get p03MenuTotal;

  /// No description provided for @p03MenuTotalEnergy.
  ///
  /// In tr, this message translates to:
  /// **'Toplam enerji'**
  String get p03MenuTotalEnergy;

  /// No description provided for @p03MenuKcal.
  ///
  /// In tr, this message translates to:
  /// **'{n} kcal'**
  String p03MenuKcal(String n);

  /// No description provided for @p03MenuAtLeast.
  ///
  /// In tr, this message translates to:
  /// **'En az {n} kcal'**
  String p03MenuAtLeast(String n);

  /// No description provided for @p03MenuKcalMissing.
  ///
  /// In tr, this message translates to:
  /// **'Bazı yemeklerin kalorisi girilmemiş'**
  String get p03MenuKcalMissing;

  /// No description provided for @p03MenuKcalNone.
  ///
  /// In tr, this message translates to:
  /// **'Kalori girilmemiş'**
  String get p03MenuKcalNone;

  /// No description provided for @p03MenuNoList.
  ///
  /// In tr, this message translates to:
  /// **'Yemek listesi yok.'**
  String get p03MenuNoList;

  /// No description provided for @p03MenuMaintenance.
  ///
  /// In tr, this message translates to:
  /// **'Sistem bakımda.'**
  String get p03MenuMaintenance;

  /// No description provided for @p03NotifNewCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} yeni'**
  String p03NotifNewCount(String n);

  /// No description provided for @p03NotifEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp duyuruları, etkinlikler ve mesaj bildirimleriniz burada listelenir.'**
  String get p03NotifEmptyBody;

  /// No description provided for @p03NotifUnreadEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Harika! Tüm yeni bildirimleri okudunuz.'**
  String get p03NotifUnreadEmptyBody;

  /// No description provided for @p03NotifLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yüklenemedi, tekrar dene'**
  String get p03NotifLoadFailed;

  /// No description provided for @p03NotifLoadingMore.
  ///
  /// In tr, this message translates to:
  /// **'Daha fazla yükleniyor...'**
  String get p03NotifLoadingMore;

  /// No description provided for @p03HomeMealTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günün Menüsü'**
  String get p03HomeMealTitle;

  /// No description provided for @p03HomeNoMenuBody.
  ///
  /// In tr, this message translates to:
  /// **'Yemekhane menüsü sisteme henüz girilmedi.'**
  String get p03HomeNoMenuBody;

  /// No description provided for @p03HomeEventsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan Etkinlikler'**
  String get p03HomeEventsTitle;

  /// No description provided for @p03HomeNoEventBody.
  ///
  /// In tr, this message translates to:
  /// **'Şu anda planlanmış aktif bir kulüp etkinliği bulunmuyor.'**
  String get p03HomeNoEventBody;

  /// No description provided for @p05NewsOpenSource.
  ///
  /// In tr, this message translates to:
  /// **'Kaynak sayfada aç'**
  String get p05NewsOpenSource;

  /// No description provided for @p05NewsErrorTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti'**
  String get p05NewsErrorTitle;

  /// No description provided for @p05NewsErrorBody.
  ///
  /// In tr, this message translates to:
  /// **'İçerik yüklenirken bir sorun oluştu. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.'**
  String get p05NewsErrorBody;

  /// No description provided for @p05SearchCountFor.
  ///
  /// In tr, this message translates to:
  /// **'“{q}” araması için'**
  String p05SearchCountFor(String q);

  /// No description provided for @p05SearchFoundNews.
  ///
  /// In tr, this message translates to:
  /// **'{n} HABER BULUNDU'**
  String p05SearchFoundNews(String n);

  /// No description provided for @p05SearchFoundEvents.
  ///
  /// In tr, this message translates to:
  /// **'{n} ETKİNLİK BULUNDU'**
  String p05SearchFoundEvents(String n);

  /// No description provided for @p05SearchFoundClubs.
  ///
  /// In tr, this message translates to:
  /// **'{n} KULÜP BULUNDU'**
  String p05SearchFoundClubs(String n);

  /// No description provided for @p05SearchFoundPeople.
  ///
  /// In tr, this message translates to:
  /// **'{n} KİŞİ BULUNDU'**
  String p05SearchFoundPeople(String n);

  /// No description provided for @p05SearchFoundPosts.
  ///
  /// In tr, this message translates to:
  /// **'{n} GÖNDERİ BULUNDU'**
  String p05SearchFoundPosts(String n);

  /// No description provided for @p05SearchSeeAllN.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü gör ({n})'**
  String p05SearchSeeAllN(String n);

  /// No description provided for @p05SearchRemoveRecent.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı sil'**
  String get p05SearchRemoveRecent;

  /// No description provided for @p11PendingInfoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru değerlendiriliyor'**
  String get p11PendingInfoTitle;

  /// No description provided for @p11PendingInfoBody.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteğin kulüp yöneticilerinin onayını bekliyor. Sonuçlandığında bildirim alacaksın.'**
  String get p11PendingInfoBody;

  /// No description provided for @p11LockPrivateTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulüp özeldir'**
  String get p11LockPrivateTitle;

  /// No description provided for @p11LockPrivateBody.
  ///
  /// In tr, this message translates to:
  /// **'Gönderileri ve üye listesini yalnızca onaylı üyeler görebilir.'**
  String get p11LockPrivateBody;

  /// No description provided for @p11LockMembersTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerikler yalnızca üyelere açık'**
  String get p11LockMembersTitle;

  /// No description provided for @p11LockMembersBody.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp paylaşımları, isteğin onaylandıktan sonra görüntülenebilir.'**
  String get p11LockMembersBody;

  /// No description provided for @p11LockBannedTitle.
  ///
  /// In tr, this message translates to:
  /// **'İçerik görüntülenemiyor'**
  String get p11LockBannedTitle;

  /// No description provided for @p11LockBannedBody.
  ///
  /// In tr, this message translates to:
  /// **'Erişim kısıtlandığı için kulüp içeriği gizlendi.'**
  String get p11LockBannedBody;

  /// No description provided for @p11BannedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüpten uzaklaştırıldın'**
  String get p11BannedTitle;

  /// No description provided for @p11BannedBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu kulübe katılamaz ve etkinliklerine başvuramazsın.'**
  String get p11BannedBody;

  /// No description provided for @p11ApprovalNote.
  ///
  /// In tr, this message translates to:
  /// **'Katılma isteğin yöneticiler tarafından onaylandıktan sonra kulüp içeriği açılır.'**
  String get p11ApprovalNote;

  /// No description provided for @p11PostPinSub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp sayfasının en üstüne yerleştir'**
  String get p11PostPinSub;

  /// No description provided for @p11PostUnpinSub.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi normal sıraya döndür'**
  String get p11PostUnpinSub;

  /// No description provided for @p11PostDeleteSub.
  ///
  /// In tr, this message translates to:
  /// **'Gönderiyi kalıcı olarak akıştan kaldır'**
  String get p11PostDeleteSub;

  /// No description provided for @p11PostReportSub.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp kurallarının ihlalini bildir'**
  String get p11PostReportSub;

  /// No description provided for @p11PollsSub.
  ///
  /// In tr, this message translates to:
  /// **'Üye kararları ve seçimleri'**
  String get p11PollsSub;

  /// No description provided for @p11SearchEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'“{query}” aramasıyla eşleşen kulüp üyesi yok. İsmi kontrol edip tekrar dene.'**
  String p11SearchEmptyBody(String query);

  /// No description provided for @p11ClearSearch.
  ///
  /// In tr, this message translates to:
  /// **'Aramayı temizle'**
  String get p11ClearSearch;

  /// No description provided for @p11RequestsEmptyAll.
  ///
  /// In tr, this message translates to:
  /// **'Kulübüne gelen tüm başvurular yanıtlandı ya da henüz yeni başvuru yapılmadı.'**
  String get p11RequestsEmptyAll;

  /// No description provided for @p11LoadErrorBody.
  ///
  /// In tr, this message translates to:
  /// **'Bağlantı hatası oluştu. Bilgiler sunucudan alınamadı.'**
  String get p11LoadErrorBody;

  /// No description provided for @p12LogoAdd.
  ///
  /// In tr, this message translates to:
  /// **'Logo ekle'**
  String get p12LogoAdd;

  /// No description provided for @p12LogoChange.
  ///
  /// In tr, this message translates to:
  /// **'Logoyu değiştir'**
  String get p12LogoChange;

  /// No description provided for @p12LogoHint.
  ///
  /// In tr, this message translates to:
  /// **'Kare profil (1:1)'**
  String get p12LogoHint;

  /// No description provided for @p12CoverHint.
  ///
  /// In tr, this message translates to:
  /// **'16:9 yatay görsel önerilir'**
  String get p12CoverHint;

  /// No description provided for @p12QuestionsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Adaylara yöneltilecek mini form'**
  String get p12QuestionsSubtitle;

  /// No description provided for @p12QuestionPlaceholder.
  ///
  /// In tr, this message translates to:
  /// **'Sorunu yaz...'**
  String get p12QuestionPlaceholder;

  /// No description provided for @p12ConsentNote.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp oluşturarak topluluk ilkelerine ve öğrenci kurallarına uymayı kabul edersin.'**
  String get p12ConsentNote;

  /// No description provided for @p12PartialTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kısmi kayıt uyarısı'**
  String get p12PartialTitle;

  /// No description provided for @p12CategorySheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategori seç'**
  String get p12CategorySheetTitle;

  /// No description provided for @p12JoinNote.
  ///
  /// In tr, this message translates to:
  /// **'Talebin onaylandığında bildirim alacaksın.'**
  String get p12JoinNote;

  /// No description provided for @p12CountClubs.
  ///
  /// In tr, this message translates to:
  /// **'{count} kulüp'**
  String p12CountClubs(String count);

  /// No description provided for @p12CountRequests.
  ///
  /// In tr, this message translates to:
  /// **'{count} başvuru'**
  String p12CountRequests(String count);

  /// No description provided for @p15PublishRoleActive.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici yetkisi aktif'**
  String get p15PublishRoleActive;

  /// No description provided for @p15CoverOptional.
  ///
  /// In tr, this message translates to:
  /// **'İsteğe bağlı'**
  String get p15CoverOptional;

  /// No description provided for @p15CoverHint.
  ///
  /// In tr, this message translates to:
  /// **'16:9 yatay önerilir • En fazla 3 MB'**
  String get p15CoverHint;

  /// No description provided for @p15CoverChange.
  ///
  /// In tr, this message translates to:
  /// **'Değiştir'**
  String get p15CoverChange;

  /// No description provided for @p15CoverSheetTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kapak fotoğrafı'**
  String get p15CoverSheetTitle;

  /// No description provided for @p15CoverGallerySub.
  ///
  /// In tr, this message translates to:
  /// **'Cihazındaki albümlerden bir görsel belirle'**
  String get p15CoverGallerySub;

  /// No description provided for @p15CoverCameraSub.
  ///
  /// In tr, this message translates to:
  /// **'Kamerayı kullanarak anında çekim yap'**
  String get p15CoverCameraSub;

  /// No description provided for @p15CoverRemoveSub.
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan şablon görseline geri dön'**
  String get p15CoverRemoveSub;

  /// No description provided for @p15ErrBannerTitle.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen formdaki {n} hatayı düzelt.'**
  String p15ErrBannerTitle(String n);

  /// No description provided for @p15ErrBannerBody.
  ///
  /// In tr, this message translates to:
  /// **'Girdiğin bilgilerin bazıları eksik veya kurallara uymuyor. İşaretli alanları kontrol et.'**
  String get p15ErrBannerBody;

  /// No description provided for @p15ErrHint.
  ///
  /// In tr, this message translates to:
  /// **'Gerekli alanlar düzeltildiğinde oluşturma düğmesi otomatik olarak aktifleşir.'**
  String get p15ErrHint;

  /// No description provided for @p15ErrLocked.
  ///
  /// In tr, this message translates to:
  /// **'Önce {n} doğrulama hatasını gidermelisin'**
  String p15ErrLocked(String n);

  /// No description provided for @p15ErrForbiddenTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yetki kısıtlaması'**
  String get p15ErrForbiddenTitle;

  /// No description provided for @p15ErrInactiveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp durumu pasif'**
  String get p15ErrInactiveTitle;

  /// No description provided for @p15PickerSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Etkinliğin yayınlanacağı yetkili kulübün'**
  String get p15PickerSubtitle;

  /// No description provided for @p15PickerSearch.
  ///
  /// In tr, this message translates to:
  /// **'Kulüp ara…'**
  String get p15PickerSearch;

  /// No description provided for @p15PickerNoMatch.
  ///
  /// In tr, this message translates to:
  /// **'Eşleşen kulüp yok.'**
  String get p15PickerNoMatch;

  /// No description provided for @p15PickerMembers.
  ///
  /// In tr, this message translates to:
  /// **'{n} üye'**
  String p15PickerMembers(String n);

  /// No description provided for @p15PickerInfoTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yetki bilgilendirmesi'**
  String get p15PickerInfoTitle;

  /// No description provided for @p15PickerInfoBody.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici veya moderatör olduğun kulüplerde etkinlik hemen yayınlanır. Etkinlik yetkisi olan üyelerin etkinliği admin onayından sonra yayınlanır.'**
  String get p15PickerInfoBody;

  /// No description provided for @p15PickerEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Yönetici veya moderatör yetkisine sahip olduğun bir kulüp bulunmuyor.'**
  String get p15PickerEmptyBody;

  /// No description provided for @p15RefreshPerms.
  ///
  /// In tr, this message translates to:
  /// **'Yetkileri yenile'**
  String get p15RefreshPerms;

  /// No description provided for @p16ReqQuotaStatus.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan durumu'**
  String get p16ReqQuotaStatus;

  /// No description provided for @p16ReqRegistered.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı'**
  String get p16ReqRegistered;

  /// No description provided for @p16ReqUnlimitedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcı kotası'**
  String get p16ReqUnlimitedTitle;

  /// No description provided for @p16ReqPendingTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bekleyen istekler'**
  String get p16ReqPendingTitle;

  /// No description provided for @p16ReqNoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Başvuru notu'**
  String get p16ReqNoteLabel;

  /// No description provided for @p16ReqFullTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan doldu'**
  String get p16ReqFullTitle;

  /// No description provided for @p16ReqFullBody.
  ///
  /// In tr, this message translates to:
  /// **'Yeni istekler onaylanamaz. Yer açmak için kontenjanı artırabilir veya katılımcı listesini güncelleyebilirsin.'**
  String get p16ReqFullBody;

  /// No description provided for @p16ReqRaiseQuota.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjanı artır'**
  String get p16ReqRaiseQuota;

  /// No description provided for @p16ReqFullPeople.
  ///
  /// In tr, this message translates to:
  /// **'{a} / {b} kişi'**
  String p16ReqFullPeople(String a, String b);

  /// No description provided for @p16ReqCantApprove.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan yetersiz olduğu için onaylanamaz'**
  String get p16ReqCantApprove;

  /// No description provided for @p16ReqErrTitle.
  ///
  /// In tr, this message translates to:
  /// **'İstek listesi güncellenemedi.'**
  String get p16ReqErrTitle;

  /// No description provided for @p16ReqBackToEvent.
  ///
  /// In tr, this message translates to:
  /// **'Etkinlik detayına dön'**
  String get p16ReqBackToEvent;

  /// No description provided for @p16ReqEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Tüm katılım istekleri yanıtlandı veya yeni başvuru henüz gelmedi.'**
  String get p16ReqEmptyBody;

  /// No description provided for @p16SetApproved.
  ///
  /// In tr, this message translates to:
  /// **'{n} onaylı katılımcı'**
  String p16SetApproved(String n);

  /// No description provided for @p16SetOpenSub.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt olan herkes doğrudan onaylanır.'**
  String get p16SetOpenSub;

  /// No description provided for @p16SetApprovalSub.
  ///
  /// In tr, this message translates to:
  /// **'Her katılımcı isteği yönetici onayından geçer.'**
  String get p16SetApprovalSub;

  /// No description provided for @p16SetCapLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjan (kişi)'**
  String get p16SetCapLabel;

  /// No description provided for @p16SetCapCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut: {n} kişi'**
  String p16SetCapCurrent(String n);

  /// No description provided for @p16SetCapDec.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjanı azalt'**
  String get p16SetCapDec;

  /// No description provided for @p16SetCapInc.
  ///
  /// In tr, this message translates to:
  /// **'Kontenjanı artır'**
  String get p16SetCapInc;

  /// No description provided for @p16SetCancelNote.
  ///
  /// In tr, this message translates to:
  /// **'Katılan {n} kişiye anlık bildirim gönderilecek ve etkinlik listelerden kaldırılacaktır.'**
  String p16SetCancelNote(String n);

  /// No description provided for @p16QrStatusTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yoklama durumu'**
  String get p16QrStatusTitle;

  /// No description provided for @p16QrStatusSub.
  ///
  /// In tr, this message translates to:
  /// **'Anlık katılım kaydı'**
  String get p16QrStatusSub;

  /// No description provided for @p16QrList.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar listesi'**
  String get p16QrList;

  /// No description provided for @p16QrExpiredTitle.
  ///
  /// In tr, this message translates to:
  /// **'Süresi doldu'**
  String get p16QrExpiredTitle;

  /// No description provided for @p16QrRefreshing.
  ///
  /// In tr, this message translates to:
  /// **'Yenileniyor…'**
  String get p16QrRefreshing;

  /// No description provided for @p16QrErrBody.
  ///
  /// In tr, this message translates to:
  /// **'Sunucu ile bağlantı kurulamadı veya oturum zaman aşımına uğradı.'**
  String get p16QrErrBody;

  /// No description provided for @p16QrCopyBtn.
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get p16QrCopyBtn;

  /// No description provided for @p16AttTitle.
  ///
  /// In tr, this message translates to:
  /// **'Katılımcılar ve yoklama'**
  String get p16AttTitle;

  /// No description provided for @p16AttWaiting.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get p16AttWaiting;

  /// No description provided for @p16AttFilterEmptyBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu filtreye uygun katılımcı kaydı bulunamadı.'**
  String get p16AttFilterEmptyBody;

  /// No description provided for @p16AttMarkedToast.
  ///
  /// In tr, this message translates to:
  /// **'{name} yoklamaya eklendi ({method})'**
  String p16AttMarkedToast(String name, String method);

  /// No description provided for @p16AttUnmarkedToast.
  ///
  /// In tr, this message translates to:
  /// **'{name} yoklamadan çıkarıldı'**
  String p16AttUnmarkedToast(String name);

  /// No description provided for @p07ChatSearchClear.
  ///
  /// In tr, this message translates to:
  /// **'Temizle'**
  String get p07ChatSearchClear;
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
