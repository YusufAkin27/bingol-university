// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get commonRetry => 'Yeniden dene';

  @override
  String get commonRetryShort => 'Tekrar dene';

  @override
  String get commonCancel => 'Vazgeç';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonLoading => 'Yükleniyor';

  @override
  String get commonUpdate => 'Güncelle';

  @override
  String get commonOpenInStore => 'Mağazada aç';

  @override
  String get commonSomethingWentWrong => 'Bir şeyler ters gitti';

  @override
  String get configError =>
      'Yapılandırma hatası: sunucu adresi (API_BASE) güvenli (https) değil. Uygulamayı doğru adresle yeniden derleyin.';

  @override
  String get exitAgainHint => 'Çıkmak için tekrar geri basın';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navDiscover => 'Keşfet';

  @override
  String get navChat => 'Sohbet';

  @override
  String get navClubs => 'Kulüpler';

  @override
  String get navProfile => 'Profil';

  @override
  String get updateRequiredTitle => 'Güncelleme gerekli';

  @override
  String get updateRequiredBody =>
      'Uygulamayı kullanmaya devam etmek için yeni sürüme güncellemeniz gerekiyor.';

  @override
  String get updateAvailable => 'Yeni sürüm mevcut.';

  @override
  String updateAvailableVersion(String version) {
    return 'Yeni sürüm mevcut ($version).';
  }

  @override
  String get accessBlockedTitle => 'Erişim kapatıldı';

  @override
  String get accessBlockedBody =>
      'Bu cihaza veya ağa erişim kapatıldı. Hatalı olduğunu düşünüyorsan destek ile iletişime geç.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsSectionAppearance => 'GÖRÜNÜM';

  @override
  String get settingsSectionNotifications => 'BİLDİRİMLER';

  @override
  String get settingsSectionPrivacy => 'GİZLİLİK VE HESAP';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsLanguageHint => 'Arayüz, bildirim ve e-posta dili';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get pushPermission => 'Bildirim izni (push)';

  @override
  String get pushNotConfigured => 'Henüz yapılandırılmadı';

  @override
  String get pushOn => 'Açık';

  @override
  String get pushOff => 'Kapalı (sistem ayarlarından açın)';

  @override
  String get pushNotGranted => 'İzin verilmedi';

  @override
  String get pushOnToast => 'Anlık bildirimler açık.';

  @override
  String pushStatusToast(String status) {
    return 'Anlık bildirimler: $status';
  }

  @override
  String get settingsShowEmail => 'E-postamı diğerlerine göster';

  @override
  String get settingsFindContacts => 'Rehberden kişi bul';

  @override
  String get settingsPrivacyData => 'Gizlilik ve veriler';

  @override
  String get settingsSupport => 'Destek ve SSS';

  @override
  String get settingsLogoutAll => 'Tüm cihazlardan çıkış yap';

  @override
  String get settingsLogoutAllTitle => 'Tüm cihazlardan çıkış';

  @override
  String get settingsLogoutAllBody =>
      'Hesabınız tüm cihazlarda kapatılacak ve yeniden giriş yapmanız gerekecek.';

  @override
  String get settingsLogoutAllConfirm => 'Çıkış yap';

  @override
  String settingsVersion(String version) {
    return 'BÜ Kampüs · Sürüm $version';
  }

  @override
  String get loginWelcome => 'Hoş geldiniz';

  @override
  String get loginSubtitle => 'Bingöl Üniversitesi hesabınızla giriş yapın.';

  @override
  String get loginReplacedNotice =>
      'Hesabına başka bir cihazdan giriş yapıldı. Güvenliğin için bu cihazdaki oturum kapatıldı.';

  @override
  String get loginPasswordRequired => 'Şifrenizi girin.';

  @override
  String get loginForgotPassword => 'Şifremi unuttum';

  @override
  String get loginSubmit => 'Giriş yap';

  @override
  String get loginNoAccount => 'Hesabınız yok mu?';

  @override
  String get loginRegister => 'Kayıt ol';

  @override
  String get loginCompleteVerification => 'Doğrulamayı tamamla';

  @override
  String get authBack => 'Geri';

  @override
  String get authShowPassword => 'Şifreyi göster';

  @override
  String get authHidePassword => 'Şifreyi gizle';

  @override
  String get authPasswordLabel => 'Şifre';

  @override
  String get authIdHint => 'Okul numarası veya e-posta';

  @override
  String get authVerify => 'Doğrula';

  @override
  String get authResendCode => 'Kodu yeniden gönder';

  @override
  String authResendIn(String seconds) {
    return 'Yeniden gönder ($seconds sn)';
  }

  @override
  String authNewCodeIn(String seconds) {
    return 'Yeni kod için $seconds sn bekleyin';
  }

  @override
  String get authCodeSent => 'Kod gönderildi.';

  @override
  String get authNewCodeSent => 'Yeni kod gönderildi.';

  @override
  String get authEnterCode => 'Kodu girin';

  @override
  String authCodeSentTo(String email) {
    return '$email adresine kod gönderildi.';
  }

  @override
  String get authVerifyEmailTitle => 'E-postanızı doğrulayın';

  @override
  String authVerifySubtitle(String email) {
    return 'Kod $email adresine gönderildi. 10 dakika geçerlidir.';
  }

  @override
  String get authUnverifiedNotice =>
      'E-postanı doğrula. Giriş yapabilmek için hesabının doğrulanması gerekir.';

  @override
  String get authUseOtherAccount => 'Başka hesapla giriş yap';

  @override
  String get authResetTitle => 'Şifreni sıfırla';

  @override
  String get authSendCode => 'Kod gönder';

  @override
  String get authNewPasswordTitle => 'Yeni şifre';

  @override
  String get authNewPasswordLabel => 'Yeni şifre (en az 8 karakter)';

  @override
  String get authUpdatePassword => 'Şifreyi güncelle';

  @override
  String get authPasswordUpdated => 'Şifre güncellendi.';

  @override
  String get authSessionExpired => 'Süre doldu. Baştan başlayın.';

  @override
  String get authCreateAccount => 'Hesap oluştur';

  @override
  String get authSelectDepartment => 'Bölümünüzü seçin.';

  @override
  String get authSelectGrade => 'Sınıfınızı seçin.';

  @override
  String get authDepartmentsLoadFailed =>
      'Bölüm listesi yüklenemedi. Yeniden deneyin.';

  @override
  String get authNameRequired => 'Adınızı ve soyadınızı girin.';

  @override
  String get authNameHint => 'Ad soyad';

  @override
  String get authPasswordMin8 => 'Şifre (en az 8 karakter)';

  @override
  String get authTermsPrefix => '';

  @override
  String get authTermsLink => 'Kullanım koşulları';

  @override
  String get authTermsSep => ' ve ';

  @override
  String get authPrivacyLink => 'gizlilik politikasını';

  @override
  String get authTermsSuffix => ' kabul ediyorum';

  @override
  String get authMustAccept => 'Devam etmek için kabul etmelisiniz.';

  @override
  String get authHaveAccount => 'Zaten hesabınız var mı?';

  @override
  String get authRegisterSubtitle => 'Birkaç adımda kampüse katılın.';

  @override
  String get authSectionAcademic => 'Akademik bilgiler';

  @override
  String get authSectionAccount => 'Hesap bilgileri';

  @override
  String get authPwWeak => 'Zayıf';

  @override
  String get authPwFair => 'Orta';

  @override
  String get authPwStrong => 'Güçlü';
}
