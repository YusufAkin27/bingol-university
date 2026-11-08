// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get chatReactionPickerTitle => 'Tepki seç';

  @override
  String get chatReactionKeyboardHint => 'Klavyenden bir emoji seç';

  @override
  String get chatReactionOneEmoji => 'Tek bir emoji seçin.';

  @override
  String get chatReactionSearchHint => 'Emoji ara';

  @override
  String get chatReactionNoResults => 'Sonuç bulunamadı';

  @override
  String get chatReactionRecent => 'Son kullanılan';

  @override
  String get chatReactionFrequent => 'Sık kullanılan';

  @override
  String get chatReactionCatFaces => 'Yüzler';

  @override
  String get chatReactionCatPeople => 'İnsanlar';

  @override
  String get chatReactionCatNature => 'Hayvanlar ve doğa';

  @override
  String get chatReactionCatFood => 'Yemek ve içecek';

  @override
  String get chatReactionCatActivities => 'Aktivite';

  @override
  String get chatReactionCatTravel => 'Seyahat';

  @override
  String get chatReactionCatObjects => 'Nesneler';

  @override
  String get chatReactionCatSymbols => 'Semboller';

  @override
  String get chatReactionCatFlags => 'Bayraklar';

  @override
  String get chatReactionUnsupported => 'Bu emoji şu an desteklenmiyor';

  @override
  String get chatReactionLimit =>
      'Bu mesajda daha fazla farklı emoji kullanılamaz';

  @override
  String get chatMessageInfoTitle => 'Mesaj bilgisi';

  @override
  String get chatMessageSent => 'Gönderildi';

  @override
  String get chatMessageDelivered => 'İletildi';

  @override
  String get chatMessageRead => 'Okundu';

  @override
  String get chatMessageTimeUnknown => 'Zaman kaydı bulunmuyor';

  @override
  String get chatMessageWaiting => 'Henüz gerçekleşmedi';

  @override
  String get chatMessageReplies => 'Bu mesaja yanıtlar';

  @override
  String get chatMessageNoReplies => 'Bu mesaja henüz yanıt verilmedi.';

  @override
  String get chatMessageReactions => 'Tepkiler';

  @override
  String get chatMessageEditedNote => 'Bu mesaj düzenlendi';

  @override
  String get chatPremiumAllPhotos => 'Tüm fotoğraflar';

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
  String get settingsSectionAppearance => 'Görünüm';

  @override
  String get settingsSectionNotifications => 'Bildirimler';

  @override
  String get settingsSectionPrivacy => 'Gizlilik ve hesap';

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
  String get settingsPrivacyData => 'Gizlilik ve veriler';

  @override
  String get settingsSupport => 'Destek ve SSS';

  @override
  String get settingsLogoutAll => 'Tüm cihazlardan çıkış yap';

  @override
  String get settingsLogoutAllTitle => 'Tüm cihazlardan çıkış';

  @override
  String get settingsLogoutAllBody =>
      'Tüm cihazlardaki oturumlarınız kapatılacak ve yeniden giriş yapmanız gerekecek.';

  @override
  String get settingsLogoutAllConfirm => 'Çıkış yap';

  @override
  String settingsVersion(String version) {
    return 'BÜ Kampüs · Sürüm $version';
  }

  @override
  String get loginWelcome => 'Hoş geldiniz';

  @override
  String get loginSubtitle => 'E-posta adresinizle giriş yapın.';

  @override
  String get loginReplacedNotice =>
      'Bu cihazdaki oturum kapatıldı. Başka bir cihazdan çıkış yaptırılmış olabilir; devam etmek için yeniden giriş yap.';

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
  String get authIdHint => 'E-posta';

  @override
  String get loginSubtitleNumber => 'E-posta adresinizle giriş yapın.';

  @override
  String get authVerify => 'Doğrula';

  @override
  String get authResendCode => 'Kodu yeniden gönder';

  @override
  String authResendInTime(String time) {
    return 'Yeniden gönder ($time)';
  }

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
    return '$email adresine gönderdiğimiz 6 haneli kodu girin.';
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
  String get authResetTitle => 'Şifrenizi mi unuttunuz?';

  @override
  String get authSendCode => 'Kod gönder';

  @override
  String get authNewPasswordTitle => 'Yeni şifre belirleyin';

  @override
  String get authNewPasswordLabel => 'Yeni şifre';

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
  String get authPasswordMin8 => 'Şifre (en az 6 karakter)';

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
  String get acadMonth1 => 'Ocak';

  @override
  String get acadMonth2 => 'Şubat';

  @override
  String get acadMonth3 => 'Mart';

  @override
  String get acadMonth4 => 'Nisan';

  @override
  String get acadMonth5 => 'Mayıs';

  @override
  String get acadMonth6 => 'Haziran';

  @override
  String get acadMonth7 => 'Temmuz';

  @override
  String get acadMonth8 => 'Ağustos';

  @override
  String get acadMonth9 => 'Eylül';

  @override
  String get acadMonth10 => 'Ekim';

  @override
  String get acadMonth11 => 'Kasım';

  @override
  String get acadMonth12 => 'Aralık';

  @override
  String get acadDay1 => 'Pazartesi';

  @override
  String get acadDay2 => 'Salı';

  @override
  String get acadDay3 => 'Çarşamba';

  @override
  String get acadDay4 => 'Perşembe';

  @override
  String get acadDay5 => 'Cuma';

  @override
  String get acadDay6 => 'Cumartesi';

  @override
  String get acadDay7 => 'Pazar';

  @override
  String get acadDayShort1 => 'Pzt';

  @override
  String get acadDayShort2 => 'Sal';

  @override
  String get acadDayShort3 => 'Çar';

  @override
  String get acadDayShort4 => 'Per';

  @override
  String get acadDayShort5 => 'Cum';

  @override
  String get acadDayShort6 => 'Cmt';

  @override
  String get acadDayShort7 => 'Paz';

  @override
  String get acadColorRed => 'Kırmızı';

  @override
  String get acadColorOrange => 'Turuncu';

  @override
  String get acadColorAmber => 'Sarı';

  @override
  String get acadColorGreen => 'Yeşil';

  @override
  String get acadColorTeal => 'Turkuaz';

  @override
  String get acadColorBlue => 'Mavi';

  @override
  String get acadColorIndigo => 'Çivit';

  @override
  String get acadColorPurple => 'Mor';

  @override
  String get acadColorPink => 'Pembe';

  @override
  String get acadColorGray => 'Gri';

  @override
  String get acadExamTypeVize => 'Vize';

  @override
  String get acadExamTypeFinal => 'Final';

  @override
  String get acadExamTypeBut => 'Bütünleme';

  @override
  String get acadExamTypeQuiz => 'Quiz';

  @override
  String get acadExamTypeOdev => 'Ödev';

  @override
  String get acadExamTypeDiger => 'Diğer';

  @override
  String get acadEventKindSemesterStart => 'Dönem başlangıcı';

  @override
  String get acadEventKindRegistration => 'Ders kaydı';

  @override
  String get acadEventKindHoliday => 'Tatil';

  @override
  String get acadEventKindPublicHoliday => 'Resmi tatil';

  @override
  String acadCountdownDays(String n) {
    return '$n gün kaldı';
  }

  @override
  String acadCountdownHours(String n) {
    return '$n saat kaldı';
  }

  @override
  String acadCountdownMinutes(String n) {
    return '$n dk kaldı';
  }

  @override
  String get acadGradePrep => 'Hazırlık';

  @override
  String get acadGradeMaster => 'Yüksek lisans';

  @override
  String get acadGradePhd => 'Doktora';

  @override
  String acadGradeN(String n) {
    return '$n. sınıf';
  }

  @override
  String get acadSave => 'Kaydet';

  @override
  String get acadDelete => 'Sil';

  @override
  String get acadCancel => 'Vazgeç';

  @override
  String get acadRetry => 'Yeniden dene';

  @override
  String get acadSelect => 'Seç';

  @override
  String get acadMaintenance =>
      'Akademik hizmetler bakımda. Daha sonra tekrar deneyin.';

  @override
  String get acadAll => 'Tümü';

  @override
  String get acadHubTitle => 'Akademik';

  @override
  String get acadHubReminders => 'Hatırlatmalar';

  @override
  String get acadHubAddCourses => 'Derslerini ekle';

  @override
  String get acadHubNoClassWeek => 'Bu hafta ders yok';

  @override
  String acadHubNext(String course, String time) {
    return 'Sıradaki: $course $time';
  }

  @override
  String get acadHubNoExam => 'Yaklaşan sınav yok';

  @override
  String acadHubExamCount(String n) {
    return '$n yaklaşan sınav';
  }

  @override
  String get acadHubTimetable => 'Ders programı';

  @override
  String get acadHubTimetableSub => 'Haftalık ders programın';

  @override
  String get acadHubExamsSub => 'Sınav takvimin ve resmi program';

  @override
  String get acadHubCalendarSub => 'Dönem, kayıt ve sınav tarihleri';

  @override
  String get acadExamsTitle => 'Sınavlar';

  @override
  String get acadExamsAdd => 'Sınav ekle';

  @override
  String get acadExamsTabOfficial => 'Resmi program';

  @override
  String get acadExamsEmptyMine =>
      'Kişisel sınav eklemedin.\nVize, final ya da quiz tarihlerini buradan takip et.';

  @override
  String get acadExamsUpcoming => 'Yaklaşan';

  @override
  String get acadExamsNoUpcoming => 'Yaklaşan sınavın yok.';

  @override
  String get acadExamsPast => 'Geçmiş';

  @override
  String acadExamsSemantic(String type, String title, String date) {
    return '$type: $title. $date. Düzenlemek için dokun.';
  }

  @override
  String acadExamsSemanticCd(
      String type, String title, String date, String countdown) {
    return '$type: $title. $date. $countdown. Düzenlemek için dokun.';
  }

  @override
  String get acadFormErrTitle => 'Sınav başlığı gerekli.';

  @override
  String get acadFormErrDate => 'Sınav tarihini seç.';

  @override
  String get acadFormErrEnd => 'Bitiş saati başlangıçtan sonra olmalı.';

  @override
  String get acadFormDeleteTitle => 'Sınavı sil';

  @override
  String acadFormDeleteText(String title) {
    return '\"$title\" silinecek.';
  }

  @override
  String get acadFormEdit => 'Sınavı düzenle';

  @override
  String get acadFormNew => 'Yeni sınav';

  @override
  String get acadFormTitleLabel => 'Başlık';

  @override
  String get acadFormTitleHint => 'Örn. Veri Yapıları Vize 1';

  @override
  String get acadFormType => 'Tür';

  @override
  String get acadFormCourseOpt => 'Ders (isteğe bağlı)';

  @override
  String get acadFormNone => 'Yok';

  @override
  String get acadFormDateTime => 'Tarih ve saat';

  @override
  String get acadFormExamDate => 'Sınav tarihi';

  @override
  String get acadFormPickDate => 'Tarih seç';

  @override
  String get acadFormStartTime => 'Başlangıç saati';

  @override
  String get acadFormEndTime => 'Bitiş saati';

  @override
  String get acadFormEndHint => 'Bitiş (ops.)';

  @override
  String get acadFormRoom => 'Derslik';

  @override
  String get acadFormRoomHint => 'Örn. B-204';

  @override
  String get acadFormNote => 'Not';

  @override
  String get acadFormNoteHint => 'İsteğe bağlı';

  @override
  String get acadFormAdd => 'Sınavı ekle';

  @override
  String get acadAnnOpenAttachment => 'Eki aç';

  @override
  String get acadCalTitle => 'Akademik takvim';

  @override
  String get acadCalPrev => 'Önceki ay';

  @override
  String get acadCalNext => 'Sonraki ay';

  @override
  String get acadCalToday => 'bugün';

  @override
  String acadCalEventCount(String n) {
    return '$n önemli tarih';
  }

  @override
  String acadCalMonthHeading(String month) {
    return '$month ayı önemli tarihleri';
  }

  @override
  String get acadCalNoMonth => 'Bu ay için kayıtlı önemli tarih yok.';

  @override
  String get acadCalNoDay => 'Bu günde önemli tarih yok.';

  @override
  String get acadCalNextHeading => 'Sıradaki önemli tarihler';

  @override
  String get acadTimeDay1 => 'Pazartesi';

  @override
  String get acadTimeDay2 => 'Salı';

  @override
  String get acadTimeDay3 => 'Çarşamba';

  @override
  String get acadTimeDay4 => 'Perşembe';

  @override
  String get acadTimeDay5 => 'Cuma';

  @override
  String get acadTimeDay6 => 'Cumartesi';

  @override
  String get acadTimeDay7 => 'Pazar';

  @override
  String get acadTimeDayShort1 => 'Pzt';

  @override
  String get acadTimeDayShort2 => 'Sal';

  @override
  String get acadTimeDayShort3 => 'Çar';

  @override
  String get acadTimeDayShort4 => 'Per';

  @override
  String get acadTimeDayShort5 => 'Cum';

  @override
  String get acadTimeDayShort6 => 'Cmt';

  @override
  String get acadTimeDayShort7 => 'Paz';

  @override
  String get acadTimeColorRed => 'Kırmızı';

  @override
  String get acadTimeColorOrange => 'Turuncu';

  @override
  String get acadTimeColorAmber => 'Sarı';

  @override
  String get acadTimeColorGreen => 'Yeşil';

  @override
  String get acadTimeColorTeal => 'Turkuaz';

  @override
  String get acadTimeColorBlue => 'Mavi';

  @override
  String get acadTimeColorIndigo => 'Çivit';

  @override
  String get acadTimeColorPurple => 'Mor';

  @override
  String get acadTimeColorPink => 'Pembe';

  @override
  String get acadTimeColorGray => 'Gri';

  @override
  String get acadTimeExamVize => 'Vize';

  @override
  String get acadTimeExamFinal => 'Final';

  @override
  String get acadTimeExamBut => 'Bütünleme';

  @override
  String get acadTimeExamQuiz => 'Quiz';

  @override
  String get acadTimeExamOdev => 'Ödev';

  @override
  String get acadTimeExamOther => 'Diğer';

  @override
  String acadTimeRemClass(String min, String time, String room) {
    return '$min dk sonra başlıyor ($time$room)';
  }

  @override
  String acadTimeRemExamLabel(String type, String title) {
    return '$type: $title';
  }

  @override
  String acadTimeRemExamTomorrow(String time, String room) {
    return 'Yarın $time$room';
  }

  @override
  String acadTimeRemExamHour(String room) {
    return '2 saat sonra başlıyor$room';
  }

  @override
  String get acadTimeExportNone => 'Dışa aktarılacak ders yok.';

  @override
  String get acadTimeExportCopied => 'Takvim (.ics) metni panoya kopyalandı.';

  @override
  String get acadTimeTitle => 'Ders programı';

  @override
  String get acadTimeExportTooltip => 'Takvime aktar (.ics)';

  @override
  String get acadTimeAddCourse => 'Ders ekle';

  @override
  String get acadTimeStale => 'Güncellenemedi, son veriler gösteriliyor.';

  @override
  String get acadTimePickSemester => 'Dönem seç';

  @override
  String acadTimeMyCourses(String count) {
    return 'Derslerim ($count)';
  }

  @override
  String get acadTimeEmptyText =>
      'Henüz ders eklemedin.\nHaftalık programını oluşturmak için derslerini ekle.';

  @override
  String get acadTimeAddFirst => 'İlk dersini ekle';

  @override
  String get acadTimeNowInClass => 'Şu an derste';

  @override
  String acadTimeMinLeft(String name, String min) {
    return '$name · $min dk kaldı';
  }

  @override
  String get acadTimeNextClass => 'Sıradaki ders';

  @override
  String acadTimeWhenMin(String min) {
    return '$min dk sonra';
  }

  @override
  String acadTimeWhenHours(String h) {
    return '$h sa sonra';
  }

  @override
  String acadTimeWhenHoursMin(String h, String min) {
    return '$h sa $min dk sonra';
  }

  @override
  String acadTimeWhenDay(String day, String time) {
    return '$day $time';
  }

  @override
  String get acadTimeToday => 'Bugün';

  @override
  String get acadTimeNoMoreWeek => 'Bu hafta başka dersin yok.';

  @override
  String get acadTimeTodayNone => 'Bugün kalan ders yok';

  @override
  String acadTimeTodayLeft(String count) {
    return 'Bugün $count ders kaldı';
  }

  @override
  String acadTimeDayToday(String day) {
    return '$day, bugün';
  }

  @override
  String acadTimeNoClassDay(String day) {
    return '$day günü dersin yok.';
  }

  @override
  String get acadTimeOutOfRange => 'Bu tarih dönem aralığı dışında.';

  @override
  String get acadTimeStatusNow => 'Şu an';

  @override
  String get acadTimeStatusDone => 'Bitti';

  @override
  String acadTimeSlotSemantic(
      String name, String day, String start, String end) {
    return '$name, $day $start ile $end arası';
  }

  @override
  String acadTimeCourseSemantic(String name, String days) {
    return '$name. $days. Düzenlemek için dokun.';
  }

  @override
  String get acadTimeNoSessions => 'Oturum yok';

  @override
  String get acadTimeNameRequired => 'Ders adı gerekli';

  @override
  String get acadTimeEndAfterStart => 'Bitiş saati başlangıçtan sonra olmalı.';

  @override
  String get acadTimeOwnConflict => 'Bu dersin kendi oturumları çakışıyor';

  @override
  String get acadTimeConflictTitle => 'Ders çakışması';

  @override
  String acadTimeConflictText(String lines) {
    return 'Şu derslerle saatler çakışıyor:\n$lines\n\nYine de kaydedilsin mi?';
  }

  @override
  String acadTimeConflictServerText(String message) {
    return '$message\n\nYine de kaydedilsin mi?';
  }

  @override
  String get acadTimeSaveAnyway => 'Yine de kaydet';

  @override
  String get acadTimeDeleteCourse => 'Dersi sil';

  @override
  String acadTimeDeleteCourseText(String name) {
    return '\"$name\" dersi ve tüm oturumları silinecek.';
  }

  @override
  String get acadTimeDelete => 'Sil';

  @override
  String get acadTimeEditCourse => 'Dersi düzenle';

  @override
  String get acadTimeNewCourse => 'Yeni ders';

  @override
  String get acadTimeCourseName => 'Ders adı';

  @override
  String get acadTimeNameHint => 'Örn. Veri Yapıları';

  @override
  String get acadTimeCourseCode => 'Ders kodu';

  @override
  String get acadTimeInstructor => 'Öğretim üyesi';

  @override
  String get acadTimeInstructorHint => 'Dr. Ayşe Yılmaz';

  @override
  String get acadTimeColor => 'Renk';

  @override
  String acadTimeColorSemantic(String color) {
    return 'Renk $color';
  }

  @override
  String get acadTimeColorAuto => 'Seçmezseniz otomatik atanır.';

  @override
  String get acadTimeDaysAndTimes => 'Gün ve saatler';

  @override
  String get acadTimeAddSession => 'Başka gün/saat ekle';

  @override
  String get acadTimeNote => 'Not';

  @override
  String get acadTimeNoteHint => 'İsteğe bağlı (örn. laptop getir)';

  @override
  String get acadTimeSave => 'Kaydet';

  @override
  String get acadTimeAddCourseBtn => 'Dersi ekle';

  @override
  String acadTimeSessionN(String n) {
    return '$n. oturum';
  }

  @override
  String get acadTimeRemoveSession => 'Oturumu kaldır';

  @override
  String get acadTimeStartTime => 'Başlangıç saati';

  @override
  String get acadTimeEndTime => 'Bitiş saati';

  @override
  String get acadTimeRoomHint => 'Derslik (örn. B-204)';

  @override
  String get acadTimeSemester => 'Dönem';

  @override
  String get acadTimeNoSemester =>
      'Henüz dönem yok. Bir dönem ekleyerek derslerini düzenleyebilirsin.';

  @override
  String get acadTimeAddSemester => 'Yeni dönem ekle';

  @override
  String acadTimeOfficial(String name) {
    return '$name (akademik takvimden)';
  }

  @override
  String get acadTimeOfficialDefault => 'Resmi dönem';

  @override
  String get acadTimeClose => 'Kapat';

  @override
  String get acadTimeCurrent => 'Güncel';

  @override
  String get acadTimeMakeCurrent => 'Güncel dönem yap';

  @override
  String get acadTimeDeleteSemester => 'Dönemi sil';

  @override
  String acadTimeDeleteSemesterText(String name) {
    return '\"$name\" silinecek. Dersler dönemsiz kalır.';
  }

  @override
  String get acadTimeNewSemester => 'Yeni dönem';

  @override
  String get acadTimeSemesterHint => '2026-2027 Güz';

  @override
  String get acadTimeStartDate => 'Başlangıç tarihi';

  @override
  String get acadTimeEndDate => 'Bitiş tarihi';

  @override
  String get acadTimeCancel => 'Vazgeç';

  @override
  String get acadTimeSemesterNeedAll => 'Ad ve iki tarih de gerekli.';

  @override
  String get acadTimeSemesterEndAfter =>
      'Bitiş tarihi başlangıçtan sonra olmalı.';

  @override
  String get acadTimeAdd => 'Ekle';

  @override
  String get acadTimeRemindersTitle => 'Hatırlatmalar';

  @override
  String get acadTimeRemindersIntro =>
      'Bildirimler cihazında zamanlanır; internet gerekmez. Ders programın veya sınavların değişince yenilenir.';

  @override
  String get acadTimeClassReminder => 'Ders hatırlatması';

  @override
  String get acadTimeBeforeClass => 'Ders başlamadan önce';

  @override
  String get acadTimeOneHour => '1 saat';

  @override
  String acadTimeMinutes(String m) {
    return '$m dk';
  }

  @override
  String get acadTimeExamReminders => 'Sınav hatırlatmaları';

  @override
  String get acadTimeDayBefore => '1 gün önce';

  @override
  String get acadTimeHourBefore => 'Sınavdan 2 saat önce (bildirim)';

  @override
  String get authRestEnterCode => '6 haneli kodu girin.';

  @override
  String get authRestCodeLabel => '6 haneli doğrulama kodu';

  @override
  String chatDetailVideoPreparing(String pct) {
    return 'Video hazırlanıyor… %$pct';
  }

  @override
  String get chatDetailCancel => 'İptal';

  @override
  String get chatDetailUserFallback => 'Kullanıcı';

  @override
  String get chatDetailYou => 'Sen';

  @override
  String get chatDetailChatFallback => 'Sohbet';

  @override
  String get chatDetailGroupFallback => 'Grup';

  @override
  String get chatDetailVideoTooLong => 'Video en fazla 60 saniye olabilir';

  @override
  String get chatDetailVideoTooLarge =>
      'Video çok büyük, daha kısa bir video seçin';

  @override
  String get chatDetailVideoUnsupported => 'Bu cihazda video gönderilemiyor.';

  @override
  String get chatDetailVideoFailed => 'Video hazırlanamadı.';

  @override
  String get chatDetailVideosSplit =>
      'Videolar büyük olduğu için birden fazla mesaj olarak gönderilecek';

  @override
  String get chatDetailImageTooLarge =>
      'Görsel çok büyük, daha küçük bir görsel seçin.';

  @override
  String get chatDetailImageTypes =>
      'Yalnızca JPEG, PNG veya WebP görseller gönderilebilir.';

  @override
  String get chatDetailImageUnreadable => 'Görsel okunamadı.';

  @override
  String get chatDetailVideoUnreadable => 'Video okunamadı.';

  @override
  String get chatDetailSavedToGallery => 'Galeriye kaydedildi';

  @override
  String get chatDetailDeleteTitle => 'Mesaj silinsin mi?';

  @override
  String get chatDetailDeleteBody => 'Bu mesaj herkes için silinir.';

  @override
  String get chatDetailDelete => 'Sil';

  @override
  String get chatDetailMsgDeleted => 'Bu mesaj silindi';

  @override
  String get chatDetailNevermind => 'Vazgeç';

  @override
  String get chatDetailToday => 'Bugün';

  @override
  String get chatEncNoticeDirect =>
      'Mesajların aktarım sırasında ve sunucuda şifrelenir.';

  @override
  String get chatEncNoticeGroup =>
      'Bu sohbetteki mesajlar aktarım sırasında ve sunucuda şifrelenir. Mesajları sohbetteki tüm üyeler görebilir.';

  @override
  String get chatEncNoticeRoom =>
      'Bu odadaki mesajlar aktarım sırasında ve sunucuda şifrelenir. Mesajları odadaki tüm üyeler görebilir.';

  @override
  String get chatEncMore => 'Daha fazla bilgi';

  @override
  String get chatEncPageTitle => 'Sohbet güvenliği';

  @override
  String get chatEncHeroTitle => 'Mesajların şifreli';

  @override
  String get chatEncHeroBody =>
      'Mesajların aktarım sırasında ve sunucuda şifrelenir. Neyin nasıl korunduğunu ve nelere dikkat etmen gerektiğini aşağıda açıkça anlattık.';

  @override
  String get chatEncSecHow => 'Nasıl korunuyor';

  @override
  String get chatEncTlsTitle => 'Aktarım sırasında şifreli';

  @override
  String get chatEncTlsBody =>
      'Mesajların ve sohbet fotoğraflarının uygulama ile sunucu arasındaki yolculuğu şifreli bağlantıdan (TLS/WSS) geçer.';

  @override
  String get chatEncRestTitle => 'Sunucuda şifreli saklama';

  @override
  String get chatEncRestBody =>
      'Mesajlar her sohbet için ayrı bir anahtarla AES-256-GCM ile şifrelenerek saklanır; sohbet fotoğrafları ve videoları da şifreli saklanır. Anahtarlar veritabanında değil, sunucu ortamında ayrı tutulur. Bu, veritabanı yedeği ele geçirilse bile mesajların okunmasını zorlaştırır.';

  @override
  String get chatEncAuditTitle => 'Yönetici erişimi kayıt altında';

  @override
  String get chatEncAuditBody =>
      'Yazışmalarına yalnızca yetkili yöneticiler bakabilir; bu da şikâyet incelemesi, güvenlik ve yasal talepler gibi gerekçelerle olur. Her görüntüleme, içerik gösterilmeden önce silinemeyen bir erişim kaydına yazılır.';

  @override
  String get chatEncBlockTitle => 'Engelle ve şikâyet et';

  @override
  String get chatEncBlockBody =>
      'İstemediğin kişiyi engelleyebilir, uygunsuz mesaj ve kullanıcıları şikâyet edebilirsin. Engellediğin kişinin mesajları sana iletilmez.';

  @override
  String get chatEncOnceTitle => 'Tek gösterimlik fotoğraf';

  @override
  String get chatEncOnceBody =>
      'Tek gösterimlik fotoğrafı alıcı yalnızca bir kez açabilir; açtıktan sonra yeniden göremez.';

  @override
  String get chatEncDeleteTitle => 'Mesajı herkes için sil';

  @override
  String get chatEncDeleteBody =>
      'Kendi mesajını herkes için silebilirsin; diğer kişiler mesaj yerine silindiği bilgisini görür.';

  @override
  String get chatEncExifTitle => 'Fotoğraflardan konum temizlenir';

  @override
  String get chatEncExifBody =>
      'Gönderdiğin fotoğraflar sunucuda yeniden kodlanır ve konum gibi EXIF bilgileri temizlenir.';

  @override
  String get chatEncDataTitle => 'Verilerin sende';

  @override
  String get chatEncDataBody =>
      'Profil bölümünden verilerini indirebilir ya da hesabını silebilirsin.';

  @override
  String get chatEncNoSellTitle => 'Satılmaz, reklam için paylaşılmaz';

  @override
  String get chatEncNoSellBody =>
      'Verilerini satmayız ve reklam amacıyla üçüncü kişilerle paylaşmayız.';

  @override
  String get chatEncSecKnow => 'Bilmen gerekenler';

  @override
  String get chatEncNotE2eeTitle => 'Uçtan uca şifreli değildir';

  @override
  String get chatEncNotE2eeBody =>
      'Bu uygulamadaki mesajlar uçtan uca şifreli değildir. Şifreleme anahtarları sunucuda tutulur, bu yüzden sistem gerektiğinde mesajları çözebilir. Bunu bilerek kullan.';

  @override
  String get chatEncRetainTitle => 'Silinen içerik saklanabilir';

  @override
  String get chatEncRetainBody =>
      'Herkes için silinen mesajların şifreli kopyası, düzenleme geçmişi ve tek gösterimlik fotoğrafların şifreli kopyası güvenlik incelemesi için sunucuda saklanabilir. Süreler Gizlilik Politikasında yazılıdır.';

  @override
  String get chatEncMembersTitle => 'Gruplarda herkes görür';

  @override
  String get chatEncMembersBody =>
      'Grup, kulüp ve etkinlik odalarındaki mesajları odadaki tüm üyeler görebilir.';

  @override
  String get chatEncScreenshotTitle => 'Ekran görüntüsü engellenemez';

  @override
  String get chatEncScreenshotBody =>
      'Karşındaki kişi mesajı ekran görüntüsüyle ya da başka bir cihazla kaydedip paylaşabilir. Tek gösterimlik fotoğraflarda da bunu tamamen engelleyemeyiz.';

  @override
  String get chatEncAccountTitle => 'Hesabı silince mesajlar kalır';

  @override
  String get chatEncAccountBody =>
      'Hesabını silersen kişisel bilgilerin anonimleştirilir; gönderdiğin mesajlar sohbetin parçası olarak anonim yazarla kalır.';

  @override
  String get chatEncSecHelp => 'Şikâyet et ve engelle';

  @override
  String chatEncHelpMessage(String report) {
    return 'Bir mesajı şikâyet etmek için mesaja basılı tut ve $report seçeneğine dokun.';
  }

  @override
  String chatEncHelpPerson(String block, String report) {
    return 'Birebir sohbette kişiyi engellemek ya da şikâyet etmek için üstteki ada dokun; sohbet bilgisinde $block veya $report seçeneğini kullan.';
  }

  @override
  String get chatEncSecRead => 'Daha fazlası';

  @override
  String get chatEncPrivacyLink => 'Gizlilik Politikası';

  @override
  String get chatEncRulesLink => 'Topluluk Kuralları';

  @override
  String get chatEncInfoRow => 'Şifreleme ve güvenlik';

  @override
  String get chatEncFootnote =>
      'Mesajların aktarım sırasında ve sunucuda şifrelenir.';

  @override
  String get chatDetailYesterday => 'Dün';

  @override
  String get chatDetailMonth1 => 'Ocak';

  @override
  String get chatDetailMonth2 => 'Şubat';

  @override
  String get chatDetailMonth3 => 'Mart';

  @override
  String get chatDetailMonth4 => 'Nisan';

  @override
  String get chatDetailMonth5 => 'Mayıs';

  @override
  String get chatDetailMonth6 => 'Haziran';

  @override
  String get chatDetailMonth7 => 'Temmuz';

  @override
  String get chatDetailMonth8 => 'Ağustos';

  @override
  String get chatDetailMonth9 => 'Eylül';

  @override
  String get chatDetailMonth10 => 'Ekim';

  @override
  String get chatDetailMonth11 => 'Kasım';

  @override
  String get chatDetailMonth12 => 'Aralık';

  @override
  String get chatDetailOnline => 'çevrimiçi';

  @override
  String chatDetailLastSeenToday(String time) {
    return 'Son görülme: bugün $time';
  }

  @override
  String chatDetailLastSeenYesterday(String time) {
    return 'Son görülme: dün $time';
  }

  @override
  String chatDetailLastSeenOn(String date) {
    return 'Son görülme: $date';
  }

  @override
  String chatDetailClubRoomMembers(String count) {
    return 'Kulüp odası · $count üye';
  }

  @override
  String chatDetailEventRoomMembers(String count) {
    return 'Etkinlik odası · $count üye';
  }

  @override
  String chatDetailMembersCount(String count) {
    return '$count üye';
  }

  @override
  String get chatDetailClubEventRoom => 'Kulüp/etkinlik odası';

  @override
  String get chatDetailResend => 'Yeniden gönder';

  @override
  String get chatDetailReply => 'Yanıtla';

  @override
  String get chatDetailCopy => 'Kopyala';

  @override
  String get chatDetailForward => 'İlet';

  @override
  String get chatDetailEdit => 'Düzenle';

  @override
  String get chatDetailDeleteForAll => 'Herkesten sil';

  @override
  String get chatDetailDeleteMessage => 'Mesajı sil';

  @override
  String get chatDetailReport => 'Şikâyet et';

  @override
  String get chatDetailCopied => 'Kopyalandı';

  @override
  String get chatDetailForwarded => 'İletildi';

  @override
  String get chatDetailForwardFailedAll => 'İletilemedi';

  @override
  String chatDetailForwardFailedSome(String count) {
    return '$count sohbete iletilemedi';
  }

  @override
  String get chatDetailSearchInChat => 'Sohbette ara';

  @override
  String get chatDetailClubPage => 'Kulüp sayfası';

  @override
  String get chatDetailEventPage => 'Etkinlik sayfası';

  @override
  String get chatDetailMembers => 'Üyeler';

  @override
  String get chatDetailMedia => 'Medya';

  @override
  String get chatDetailSettings => 'Ayarlar';

  @override
  String get chatDetailLeaveChat => 'Sohbetten ayrıl';

  @override
  String get chatDetailBlock => 'Engelle';

  @override
  String get chatDetailUnblock => 'Engeli kaldır';

  @override
  String get chatDetailReportUser => 'Kullanıcıyı şikâyet et';

  @override
  String get chatDetailLeaveTitle => 'Sohbetten ayrılınsın mı?';

  @override
  String get chatDetailLeaveBody => 'Bu sohbetten ayrılırsınız.';

  @override
  String get chatDetailLeave => 'Ayrıl';

  @override
  String get chatDetailBlockTitle => 'Kullanıcı engellensin mi?';

  @override
  String get chatDetailBlockBody => 'Engellediğiniz kişiyle mesajlaşamazsınız.';

  @override
  String get chatDetailUserBlocked => 'Kullanıcı engellendi';

  @override
  String get chatDetailUserUnblocked => 'Engel kaldırıldı';

  @override
  String chatDetailMembersTitle(String count) {
    return 'Üyeler ($count)';
  }

  @override
  String get chatDetailMembersLoadFailed => 'Üye listesi alınamadı.';

  @override
  String get chatDetailAdmin => 'Yönetici';

  @override
  String get chatDetailBack => 'Geri';

  @override
  String get chatDetailOpenProfile => 'Profili aç';

  @override
  String get chatDetailChatInfo => 'Sohbet bilgisi';

  @override
  String get chatDetailTyping => 'yazıyor…';

  @override
  String get chatDetailMenu => 'Menü';

  @override
  String get chatDetailCloseSearch => 'Aramayı kapat';

  @override
  String get chatDetailTypeToSearch => 'Aramak için yazın';

  @override
  String get chatDetailNoMatch => 'Eşleşme yok';

  @override
  String get chatDetailPrevMatch => 'Önceki eşleşme';

  @override
  String get chatDetailNextMatch => 'Sonraki eşleşme';

  @override
  String get chatDetailSearching => 'Aranıyor…';

  @override
  String get chatDetailSearchOlder => 'Daha eski mesajlarda ara';

  @override
  String get chatDetailEmpty => 'Henüz mesaj yok. İlk mesajı sen yaz.';

  @override
  String get chatDetailScrollDown => 'En alta in';

  @override
  String chatDetailScrollDownNew(String count) {
    return 'En alta in, $count yeni mesaj';
  }

  @override
  String get chatDetailEditing => 'Mesaj düzenleniyor';

  @override
  String get chatDetailAdd => 'Ekle';

  @override
  String get chatDetailWriteMessage => 'Mesaj yaz';

  @override
  String get chatDetailCamera => 'Kamera';

  @override
  String get chatDetailSave => 'Kaydet';

  @override
  String get chatDetailSend => 'Gönder';

  @override
  String get chatDetailClose => 'Kapat';

  @override
  String chatDetailReactionLabel(String emoji) {
    return 'Tepki $emoji';
  }

  @override
  String get chatInfoUnmute => 'Sesi aç';

  @override
  String get chatInfoMute => 'Sessize al';

  @override
  String get chatInfoUnarchive => 'Arşivden çıkar';

  @override
  String get chatInfoArchive => 'Arşivle';

  @override
  String get chatInfoDelete => 'Sil';

  @override
  String get chatInfoCancel => 'Vazgeç';

  @override
  String get chatInfoSave => 'Kaydet';

  @override
  String get chatInfoMute8h => '8 saat';

  @override
  String get chatInfoMute1w => '1 hafta';

  @override
  String get chatInfoMuteForever => 'Her zaman';

  @override
  String get chatInfoDeleteConvTitle => 'Sohbet silinsin mi?';

  @override
  String get chatInfoDeleteConvGroup => 'Gruptan çıkıp bu sohbeti sileceksin.';

  @override
  String get chatInfoDeleteConvDirect =>
      'Bu sohbet yalnızca senin için silinecek. Karşı taraf etkilenmez.';

  @override
  String get chatInfoUser => 'Kullanıcı';

  @override
  String get chatInfoYou => 'Sen';

  @override
  String get chatInfoAdmin => 'Yönetici';

  @override
  String get chatInfoRemoveFromGroup => 'Gruptan çıkar';

  @override
  String chatInfoMembersCount(String n) {
    return 'Üyeler ($n)';
  }

  @override
  String get chatInfoSearchMember => 'Üye ara';

  @override
  String get chatInfoNoResults => 'Sonuç yok.';

  @override
  String get chatInfoOpenVideo => 'Videoyu aç';

  @override
  String get chatInfoOpenImage => 'Görseli aç';

  @override
  String get chatInfoMedia => 'Medya';

  @override
  String get chatInfoRetry => 'Yeniden dene';

  @override
  String get chatInfoChat => 'Sohbet';

  @override
  String get chatInfoGroup => 'Grup';

  @override
  String get chatInfoUnmuted => 'Bildirimlerin sesi açıldı';

  @override
  String get chatInfoMuted => 'Sohbet sessize alındı';

  @override
  String get chatInfoUnarchived => 'Sohbet arşivden çıkarıldı';

  @override
  String get chatInfoArchived => 'Sohbet arşivlendi';

  @override
  String get chatInfoLeaveTitle => 'Sohbetten ayrılınsın mı?';

  @override
  String get chatInfoLeaveBody => 'Bu sohbetten ayrılırsınız.';

  @override
  String get chatInfoLeave => 'Ayrıl';

  @override
  String get chatInfoUnblocked => 'Engel kaldırıldı';

  @override
  String get chatInfoBlockTitle => 'Kullanıcı engellensin mi?';

  @override
  String get chatInfoBlockBody => 'Engellediğiniz kişiyle mesajlaşamazsınız.';

  @override
  String get chatInfoBlock => 'Engelle';

  @override
  String get chatInfoBlocked => 'Kullanıcı engellendi';

  @override
  String get chatInfoUnblock => 'Engeli kaldır';

  @override
  String get chatInfoReportUser => 'Kullanıcıyı şikâyet et';

  @override
  String get chatInfoReport => 'Şikâyet et';

  @override
  String get chatInfoRemoveMemberTitle => 'Üye çıkarılsın mı?';

  @override
  String chatInfoRemoveMemberBody(String name) {
    return '$name gruptan çıkarılır.';
  }

  @override
  String get chatInfoRemove => 'Çıkar';

  @override
  String get chatInfoPickGallery => 'Galeriden seç';

  @override
  String get chatInfoRemovePhoto => 'Fotoğrafı kaldır';

  @override
  String get chatInfoImageTooLarge =>
      'Görsel çok büyük, daha küçük bir görsel seçin.';

  @override
  String get chatInfoImageTypeOnly =>
      'Yalnızca JPEG, PNG veya WebP görseller kullanılabilir.';

  @override
  String get chatInfoTitle => 'Sohbet bilgisi';

  @override
  String get chatInfoNoMembers => 'Üye listesi yok.';

  @override
  String get chatInfoClubRoom => 'Kulüp odası';

  @override
  String get chatInfoEventRoom => 'Etkinlik odası';

  @override
  String chatInfoMemberCount(String n) {
    return '$n üye';
  }

  @override
  String get chatInfoChangePhoto => 'Fotoğrafı değiştir';

  @override
  String get chatInfoEditName => 'Adı düzenle';

  @override
  String get chatInfoClub => 'Kulüp';

  @override
  String get chatInfoEvent => 'Etkinlik';

  @override
  String get chatInfoSearch => 'Ara';

  @override
  String get chatInfoMembers => 'Üyeler';

  @override
  String chatInfoMembersDot(String n) {
    return 'Üyeler · $n';
  }

  @override
  String get chatInfoNoMedia => 'Bu sohbette henüz görsel yok.';

  @override
  String get chatInfoSeeAllMedia => 'Tümünü gör';

  @override
  String chatInfoMediaDot(String count) {
    return 'Medya · $count';
  }

  @override
  String get chatInfoAll => 'Tümü';

  @override
  String get chatInfoMuteOn => 'Açık';

  @override
  String get chatInfoMutedAlways => 'Sessiz · her zaman';

  @override
  String chatInfoMutedDays(String n) {
    return 'Sessiz · $n gün sonra açılır';
  }

  @override
  String chatInfoMutedHours(String n) {
    return 'Sessiz · $n saat sonra açılır';
  }

  @override
  String get chatInfoMutedSoon => 'Sessiz · birazdan açılır';

  @override
  String get chatInfoMutedLabel => 'Sessiz';

  @override
  String get chatInfoOpenClubPage => 'Kulüp sayfasını aç';

  @override
  String get chatInfoOpenEventPage => 'Etkinlik sayfasını aç';

  @override
  String get chatInfoViewProfile => 'Profili görüntüle';

  @override
  String get chatInfoMuteNotifications => 'Bildirimleri sessize al';

  @override
  String get chatInfoClosed => 'Bu sohbet kapalı';

  @override
  String get chatInfoClosedSub => 'Yeni mesaj gönderilemez';

  @override
  String get chatInfoLeaveChat => 'Sohbetten çık';

  @override
  String get chatInfoSettings => 'Ayarlar';

  @override
  String get chatInfoGroupName => 'Grup adı';

  @override
  String get chatInfoSearchInChat => 'Sohbette ara';

  @override
  String get chatInfoMediaFiles => 'Medya ve dosyalar';

  @override
  String get chatInfoTabPhotos => 'Fotoğraflar';

  @override
  String get chatInfoTabVideos => 'Videolar';

  @override
  String get chatInfoTabFiles => 'Dosyalar';

  @override
  String get chatInfoNoPhotos => 'Bu sohbette henüz fotoğraf yok.';

  @override
  String get chatInfoNoVideos => 'Bu sohbette henüz video yok.';

  @override
  String get chatInfoFilesUnsupportedTitle => 'Dosya paylaşımı desteklenmiyor';

  @override
  String get chatInfoFilesUnsupportedBody =>
      'Bu sohbette şimdilik yalnızca fotoğraf ve video paylaşılabiliyor.';

  @override
  String get chatInfoReported => 'Şikâyet edildi';

  @override
  String get chatMiscFilterAll => 'Tümü';

  @override
  String get chatMiscFilterPeople => 'Kişiler';

  @override
  String get chatMiscFilterClubs => 'Kulüpler';

  @override
  String get chatMiscFilterEvents => 'Etkinlikler';

  @override
  String get chatMiscArchived => 'Sohbet arşivlendi';

  @override
  String get chatMiscUnarchived => 'Sohbet arşivden çıkarıldı';

  @override
  String get chatMiscChat => 'Sohbet';

  @override
  String get chatMiscArchive => 'Arşiv';

  @override
  String get chatMiscNewChat => 'Yeni sohbet';

  @override
  String get chatMiscEmptyArchive => 'Arşivde sohbet yok';

  @override
  String get chatMiscEmptyNoMatch => 'Eşleşen sohbet bulunamadı';

  @override
  String get chatMiscEmptyNone => 'Henüz sohbetiniz yok';

  @override
  String get chatMiscUnarchiveAction => 'Çıkar';

  @override
  String get chatMiscArchiveAction => 'Arşivle';

  @override
  String get chatMiscSearchHint => 'Kişi veya grup ara';

  @override
  String get chatMiscTagClub => 'Kulüp';

  @override
  String get chatMiscTagEvent => 'Etkinlik';

  @override
  String get chatMiscMessageDeleted => 'Mesaj silindi';

  @override
  String get chatMiscOnceText => 'Fotoğraf (tek gösterimlik)';

  @override
  String get chatMiscImage => 'Görsel';

  @override
  String get chatMiscDayMon => 'Pzt';

  @override
  String get chatMiscDayTue => 'Sal';

  @override
  String get chatMiscDayWed => 'Çar';

  @override
  String get chatMiscDayThu => 'Per';

  @override
  String get chatMiscDayFri => 'Cum';

  @override
  String get chatMiscDaySat => 'Cmt';

  @override
  String get chatMiscDaySun => 'Paz';

  @override
  String get chatMiscYesterday => 'Dün';

  @override
  String chatMiscSendFailedRetry(String error) {
    return '$error · Yeniden dene';
  }

  @override
  String get chatMiscSendFailed => 'Gönderilemedi';

  @override
  String get chatMiscThisMessageDeleted => 'Bu mesaj silindi';

  @override
  String get chatMiscVideo => 'Video';

  @override
  String get chatMiscPhoto => 'Fotoğraf';

  @override
  String get chatMiscUser => 'Kullanıcı';

  @override
  String get chatMiscStatusSending => 'Gönderiliyor';

  @override
  String get chatMiscStatusSent => 'Gönderildi';

  @override
  String get chatMiscStatusDelivered => 'İletildi';

  @override
  String get chatMiscStatusRead => 'Okundu';

  @override
  String get chatStatusSending => 'Gönderiliyor…';

  @override
  String get chatStatusSent => 'Gönderildi';

  @override
  String get chatStatusSeen => 'Görüldü';

  @override
  String get chatMiscImageUnavailable => 'Görsel kullanılamıyor';

  @override
  String chatMiscVideoWithDuration(String duration) {
    return 'Video, $duration';
  }

  @override
  String get chatMiscClose => 'Kapat';

  @override
  String get chatMiscImageLoadFailed => 'Görsel yüklenemedi.';

  @override
  String get chatMiscOnceOpened => 'Açıldı';

  @override
  String get chatMiscOnceSending => 'Fotoğraf · Gönderiliyor';

  @override
  String get chatMiscOnceSent => 'Fotoğraf · Gönderildi';

  @override
  String get chatMiscOnceTapToOpen => 'Fotoğraf · Açmak için dokun';

  @override
  String chatMiscOnceSemantics(String label) {
    return 'Tek gösterimlik fotoğraf. $label';
  }

  @override
  String get chatMiscEdited => 'düzenlendi';

  @override
  String get chatMiscGroupMax => 'Gruba en çok 50 kişi eklenebilir.';

  @override
  String get chatMiscGroupNameRequired => 'Grup adı girin.';

  @override
  String get chatMiscUserSearchHint => 'Ad veya e-posta ile ara';

  @override
  String get chatMiscCreateGroup => 'Grubu oluştur';

  @override
  String get chatMiscStartChat => 'Sohbet başlat';

  @override
  String get chatMiscGroupCardTitle => 'Grup oluştur';

  @override
  String chatMiscSelectedCount(String n) {
    return '$n kişi seçildi';
  }

  @override
  String get chatMiscGroupName => 'Grup adı';

  @override
  String get chatMiscMax50 => 'en çok 50';

  @override
  String get chatMiscSearchMin => 'Kişi aramak için en az 2 karakter yazın.';

  @override
  String get chatMiscNoMatchPeople => 'Eşleşen kişi bulunamadı.';

  @override
  String get chatMiscPeopleHeader => 'KİŞİLER';

  @override
  String get chatMiscForward => 'İlet';

  @override
  String get chatMiscSearchChat => 'Sohbet ara';

  @override
  String chatMiscForwardMax(String max) {
    return 'En fazla $max sohbet seçilebilir.';
  }

  @override
  String get chatMiscSend => 'Gönder';

  @override
  String chatMiscSendCount(String n) {
    return 'Gönder ($n)';
  }

  @override
  String get shareTitle => 'Paylaş';

  @override
  String get shareSendTo => 'Kişiye gönder';

  @override
  String get shareRecent => 'Son sohbetler';

  @override
  String get shareSearchHint => 'Kişi veya sohbet ara';

  @override
  String get shareNoteHint => 'Not ekle (isteğe bağlı)';

  @override
  String get shareCopyLink => 'Bağlantıyı kopyala';

  @override
  String get shareLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get shareMoreApps => 'Diğer uygulamalar';

  @override
  String get shareExternalFailed => 'Paylaşım sayfası açılamadı';

  @override
  String get shareSentOne => 'Gönderildi';

  @override
  String shareSentMany(String n) {
    return '$n sohbete gönderildi';
  }

  @override
  String get shareQueued => 'Bağlantı yok; çevrimiçi olunca gönderilecek';

  @override
  String get shareFailedAll => 'Gönderilemedi. Tekrar deneyin.';

  @override
  String shareFailedSome(String n) {
    return '$n sohbete gönderilemedi';
  }

  @override
  String get shareKindPost => 'Gönderi';

  @override
  String get shareKindReel => 'Reels';

  @override
  String get shareKindNews => 'Haber';

  @override
  String get shareKindAnnouncement => 'Duyuru';

  @override
  String get shareKindEvent => 'Etkinlik';

  @override
  String get shareUnavailable => 'Bu içerik artık görüntülenemiyor';

  @override
  String get shareChatPostShared => 'Gönderi paylaştı';

  @override
  String get shareChatReelShared => 'Reels paylaştı';

  @override
  String get shareChatNewsShared => 'Haber paylaştı';

  @override
  String get shareChatAnnouncementShared => 'Duyuru paylaştı';

  @override
  String get shareChatEventShared => 'Etkinlik paylaştı';

  @override
  String get forumActivityAnonBadge => 'Anonim';

  @override
  String get forumActivityAnonBadgeLong =>
      'Anonim paylaşım: yalnız sen görürsün';

  @override
  String get forumActivityAnonymous => 'Anonim';

  @override
  String get forumActivityCommentDeleted => 'Bu yorum silindi';

  @override
  String forumActivityCounts(String likes, String comments) {
    return '$likes beğeni, $comments yorum';
  }

  @override
  String get forumActivityEmptyCommentsBody =>
      'Yazdığın yorumlar burada görünür.';

  @override
  String get forumActivityEmptyCommentsTitle => 'Henüz yorumun yok';

  @override
  String get forumActivityEmptyFollowingBody =>
      'Bir konuyu takip edersen yeni yorumlardan haberdar olursun.';

  @override
  String get forumActivityEmptyFollowingTitle => 'Takip ettiğin konu yok';

  @override
  String get forumActivityEmptyTopicsBody =>
      'Açtığın konular burada listelenir. Anonim paylaştıkların yalnız sana görünür.';

  @override
  String get forumActivityEmptyTopicsTitle => 'Henüz konu açmadın';

  @override
  String get forumActivityRemoved => 'Bu konu kaldırıldı';

  @override
  String get forumActivitySection => 'Forum';

  @override
  String get forumActivityTabComments => 'Yorumlarım';

  @override
  String get forumActivityTabCommentsPublic => 'Yorumlar';

  @override
  String get forumActivityTabFollowing => 'Takip ettiklerim';

  @override
  String get forumActivityTabSaved => 'Kaydedilenler';

  @override
  String get forumActivityTabTopics => 'Açtığım konular';

  @override
  String get forumActivityTabTopicsPublic => 'Konular';

  @override
  String get forumActivityTitle => 'Forum faaliyetim';

  @override
  String get forumActivityUserEmptyComments => 'Henüz herkese açık yorum yok';

  @override
  String get forumActivityUserEmptyTopics => 'Henüz herkese açık konu yok';

  @override
  String forumActivityUserTitle(String name) {
    return '$name kişisinin forum faaliyeti';
  }

  @override
  String get forumPrefsAll => 'Tüm forum bildirimleri';

  @override
  String get forumPrefsAllSub =>
      'Kapatırsan aşağıdaki bildirimlerin hepsi durur.';

  @override
  String get forumPrefsFollowed => 'Takip ettiğim konular';

  @override
  String get forumPrefsLikes => 'Beğeni bildirimleri';

  @override
  String get forumPrefsModerationNote =>
      'Moderasyon bildirimleri (ör. içeriğinin kaldırılması) güvenliğin için kapatılamaz.';

  @override
  String get forumPrefsMutedEmpty => 'Kimseyi sessize almadın.';

  @override
  String get forumPrefsMutedSection => 'Sessize aldıkların';

  @override
  String get forumPrefsNotifLabel => 'Forum';

  @override
  String get forumPrefsReplies => 'Yorum yanıtları';

  @override
  String get forumPrefsRowSub => 'Konu, yanıt ve beğeni bildirimleri';

  @override
  String get forumPrefsRowTitle => 'Forum bildirimleri';

  @override
  String get forumPrefsTitle => 'Forum bildirimleri';

  @override
  String get forumPrefsTopicComments => 'Konu bildirimleri';

  @override
  String get forumPrefsUnmute => 'Sessizden çıkar';

  @override
  String get forumPrefsUnmuted => 'Sessizden çıkarıldı';

  @override
  String get forumReportAlready => 'Bu içeriği zaten bildirmiştin.';

  @override
  String get forumReportAlsoBlock => 'Bu yazarı da engelle';

  @override
  String get forumReportAlsoBlockHint =>
      'İçerikleri sana görünmez. Kimliği gösterilmez.';

  @override
  String get forumReportBlockBody =>
      'Bu yazarın forumdaki tüm konu ve yorumları sana görünmez olur. Yazar anonim olsa da kimliğini öğrenmezsin.';

  @override
  String get forumReportBlockConfirm => 'Engelle';

  @override
  String get forumReportBlockTitle => 'Yazar engellensin mi?';

  @override
  String get forumReportBlocked => 'Yazar engellendi.';

  @override
  String forumReportMuteBody(String name) {
    return '$name kişisinin forum içerikleri sana görünmez. Sohbet ve profil etkileşimleri etkilenmez. Ayarlardan geri alabilirsin.';
  }

  @override
  String get forumReportMuteConfirm => 'Sessize al';

  @override
  String get forumReportMuteTitle => 'Sessize alınsın mı?';

  @override
  String get forumReportMuted => 'Sessize alındı.';

  @override
  String get forumReportNoteHint =>
      'Eklemek istediğin bir not var mı? (isteğe bağlı)';

  @override
  String get forumReportReasonHarassment => 'Hakaret veya taciz';

  @override
  String get forumReportReasonInappropriate => 'Uygunsuz içerik';

  @override
  String get forumReportReasonOther => 'Diğer';

  @override
  String get forumReportReasonPersonalInfo => 'Kişisel bilgi paylaşımı';

  @override
  String get forumReportReasonSpam => 'Spam veya reklam';

  @override
  String get forumReportThanks => 'Teşekkürler, bildirimin ekibimize iletildi.';

  @override
  String get forumReportTitle => 'Şikâyet et';

  @override
  String get forumSavedEmptyBody =>
      'Konu ve yorumlardaki kaydet simgesine dokunarak buraya ekleyebilirsin.';

  @override
  String get forumSavedEmptyTitle => 'Henüz kaydettiğin bir şey yok';

  @override
  String get forumSavedRemove => 'Kaydı kaldır';

  @override
  String get forumSavedRemoved => 'Kaydedilenlerden çıkarıldı';

  @override
  String get forumSavedTitle => 'Kaydedilenler';

  @override
  String get forumSearchAllCategories => 'Tümü';

  @override
  String get forumSearchClearAll => 'Temizle';

  @override
  String forumSearchEmptyBody(String q) {
    return '“$q” için eşleşen konu bulunamadı. Farklı bir kelime ya da kategori dene.';
  }

  @override
  String get forumSearchEmptyTitle => 'Sonuç bulunamadı';

  @override
  String get forumSearchHint => 'Forumda ara';

  @override
  String get forumSearchMatchBody => 'Açıklamada';

  @override
  String get forumSearchMatchCategory => 'Kategoride';

  @override
  String get forumSearchMatchComment => 'Yorumda';

  @override
  String get forumSearchMatchTitle => 'Başlıkta';

  @override
  String get forumSearchMinChars => 'En az 2 karakter yaz.';

  @override
  String get forumSearchPopular => 'Popüler konular';

  @override
  String get forumSearchPopularEmpty => 'Şu an öne çıkan konu yok.';

  @override
  String get forumSearchRecent => 'Son aramalar';

  @override
  String get forumSearchRemoveRecent => 'Aramayı sil';

  @override
  String get forumSearchSortNewest => 'En yeni';

  @override
  String get forumSearchSortPopular => 'Popüler';

  @override
  String get forumSearchSortRelevance => 'İlgili';

  @override
  String get forumSearchStartBody =>
      'Konu başlığı, açıklama, yorum ya da kategori adıyla ara.';

  @override
  String get forumSearchStartTitle => 'Forumda ara';

  @override
  String get forumSearchTitle => 'Forum araması';

  @override
  String get forumShareChatCommentShared => 'Forum yorumu paylaştı';

  @override
  String get forumShareChatTopicShared => 'Forum konusu paylaştı';

  @override
  String get forumShareKindComment => 'Forum yorumu';

  @override
  String get forumShareKindTopic => 'Forum';

  @override
  String get sharePrivateHint =>
      'Gizli hesabın gönderisi yalnızca kişilere mesajla paylaşılabilir.';

  @override
  String get shareNotFoundTitle => 'İçerik bulunamadı';

  @override
  String get shareNoChats => 'Sohbet bulunamadı. Aramayla kişi bulabilirsiniz.';

  @override
  String get chatMiscChatNotFound => 'Sohbet bulunamadı.';

  @override
  String get chatMiscGalleryRationale =>
      'Galerindeki fotoğraf ve videoları gösterebilmemiz için erişim izni gerekir.';

  @override
  String get chatMiscVideoMax60 => 'Video en fazla 60 saniye olabilir';

  @override
  String chatMiscPickMax(String max) {
    return 'En fazla $max öğe seçebilirsin';
  }

  @override
  String get chatMiscAll => 'Tümü';

  @override
  String get chatMiscGallery => 'Galeri';

  @override
  String get chatMiscLimitedNote => 'Yalnızca izin verdiğin öğeler görünüyor.';

  @override
  String get chatMiscSelectMore => 'Daha fazla seç';

  @override
  String get chatMiscSettings => 'Ayarlar';

  @override
  String get chatMiscGalleryDenied => 'Galeriye erişim izni verilmedi.';

  @override
  String get chatMiscOpenSettings => 'Ayarlardan aç';

  @override
  String get chatMiscCamera => 'Kamera';

  @override
  String chatMiscPreviewCount(String n) {
    return 'Önizle ($n)';
  }

  @override
  String get chatMiscCameraRationale =>
      'Fotoğraf ve video çekebilmeniz için kameraya erişmemiz gerekir.';

  @override
  String get chatMiscMicRationale =>
      'Video kaydederken sesi de alabilmemiz için mikrofona erişmemiz gerekir.';

  @override
  String get chatMiscPhotoFailed => 'Fotoğraf çekilemedi.';

  @override
  String get chatMiscVideoSaveFailed => 'Video kaydedilemedi.';

  @override
  String get chatMiscCameraUnavailable => 'Kamera kullanılamıyor.';

  @override
  String get chatMiscCameraHint => 'Dokun: fotoğraf · Basılı tut: video';

  @override
  String get chatMiscFlipCamera => 'Kamerayı çevir';

  @override
  String get chatMiscOnceToast =>
      'Tek gönderimlik: alıcı yalnızca bir kez görebilir';

  @override
  String get chatMiscAddCaption => 'Açıklama ekle…';

  @override
  String get chatMiscOnceSendLabel => 'Tek gönderimlik';

  @override
  String get chatMiscOnceGone => 'Bu fotoğraf artık görüntülenemez.';

  @override
  String get chatMiscOnceOwn =>
      'Kendi gönderdiğiniz tek gösterimlik fotoğrafı açamazsınız.';

  @override
  String get chatMiscOnceNetwork =>
      'Fotoğraf yüklenemedi. Bağlantınızı kontrol edin. Tek gösterimlik olduğu için yeniden açılamayabilir.';

  @override
  String get chatMiscOnceShowFailed =>
      'Fotoğraf gösterilemedi. Tek gösterimlik olduğu için yeniden açılamayabilir.';

  @override
  String get chatMiscOnceTitle => 'Tek gösterimlik';

  @override
  String get chatMiscRetry => 'Yeniden dene';

  @override
  String get chatMiscSaveUnsupported => 'Bu cihazda desteklenmiyor.';

  @override
  String get chatMiscSaveDenied => 'Galeri izni verilmedi.';

  @override
  String get chatMiscSaveNoSpace => 'Cihazda yeterli alan yok.';

  @override
  String get chatMiscImageSaveFailed => 'Görsel kaydedilemedi.';

  @override
  String get chatMiscSavedToGallery => 'Galeriye kaydedildi';

  @override
  String get chatMiscDownload => 'İndir';

  @override
  String get chatMiscPlayVideo => 'Videoyu oynat';

  @override
  String get chatMiscVideoPlayFailed => 'Video oynatılamadı';

  @override
  String get clubWithdrawTitle => 'İsteği geri çek';

  @override
  String get clubWithdrawMessage => 'Katılma isteğiniz geri çekilsin mi?';

  @override
  String get clubWithdrawConfirm => 'Geri çek';

  @override
  String get clubImageTooLarge => 'Görsel çok büyük.';

  @override
  String get clubImageUnsupported =>
      'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.';

  @override
  String get clubImageUnreadable => 'Görsel okunamadı.';

  @override
  String get clubImagePickFailed => 'Görsel seçilemedi.';

  @override
  String get clubImageUploadFailed => 'Görsel yüklenemedi.';

  @override
  String get clubDeleted => 'Kulüp silindi.';

  @override
  String get clubChatClosed => 'Kulüp sohbeti şu an kapalı.';

  @override
  String get clubChatPreparing =>
      'Kulüp sohbeti hazırlanıyor, biraz sonra tekrar dene.';

  @override
  String get clubChat => 'Kulüp sohbeti';

  @override
  String get clubDeletePostTitle => 'Gönderiyi sil';

  @override
  String get clubDeletePostMessage => 'Bu gönderi kalıcı olarak silinsin mi?';

  @override
  String get clubCancel => 'Vazgeç';

  @override
  String get clubDelete => 'Sil';

  @override
  String get clubReportClub => 'Kulübü şikâyet et';

  @override
  String get clubReportPost => 'Gönderiyi şikâyet et';

  @override
  String clubMemberCount(String count) {
    return '$count üye';
  }

  @override
  String get clubPrivate => 'Özel';

  @override
  String get clubPublic => 'Herkese açık';

  @override
  String get clubTitle => 'Kulüp';

  @override
  String get clubBack => 'Geri';

  @override
  String get clubOptions => 'Kulüp seçenekleri';

  @override
  String get clubEdit => 'Kulübü düzenle';

  @override
  String clubRequestsWithCount(String count) {
    return 'Başvurular ($count)';
  }

  @override
  String get clubRequests => 'Başvurular';

  @override
  String get clubManageMembers => 'Üyeleri yönet';

  @override
  String get clubChangeCover => 'Kapağı değiştir';

  @override
  String get clubDeleteClub => 'Kulübü sil';

  @override
  String get clubLeave => 'Kulüpten ayrıl';

  @override
  String get clubIsMember => 'Üyesin';

  @override
  String get clubRequestSent => 'İstek gönderildi';

  @override
  String get clubCannotJoin => 'Katılamazsın';

  @override
  String get clubSendJoinRequest => 'Katılma isteği gönder';

  @override
  String get clubJoin => 'Katıl';

  @override
  String get clubTabPosts => 'Gönderiler';

  @override
  String get clubTabEvents => 'Etkinlikler';

  @override
  String get clubTabMembers => 'Üyeler';

  @override
  String get clubTabPolls => 'Anketler';

  @override
  String get clubNoPosts => 'Henüz gönderi yok.';

  @override
  String get clubNoEvents => 'Bu kulübün yaklaşan etkinliği yok.';

  @override
  String get clubNoMembers => 'Üye bulunamadı.';

  @override
  String get clubLoadFailedRetry => 'Yüklenemedi, tekrar dene';

  @override
  String get clubWriteHint => 'Kulübe bir şeyler yaz';

  @override
  String get clubAddImage => 'Görsel ekle';

  @override
  String get clubShare => 'Paylaş';

  @override
  String get clubRemoveImage => 'Görseli kaldır';

  @override
  String get clubPendingRequests => 'Bekleyen başvurular';

  @override
  String get clubPostActions => 'Gönderi işlemleri';

  @override
  String get clubUnpin => 'Sabitlemeyi kaldır';

  @override
  String get clubPin => 'Sabitle';

  @override
  String get clubReport => 'Şikâyet et';

  @override
  String get clubPinned => 'Sabit';

  @override
  String get clubUser => 'Kullanıcı';

  @override
  String get clubRoleOwner => 'Yönetici';

  @override
  String get clubRoleModerator => 'Moderatör';

  @override
  String get clubDeleteBody =>
      'Üyeler, etkinlikler ve sohbet silinir. Bu işlem geri alınamaz.';

  @override
  String clubDeleteTypeName(String name) {
    return 'Onaylamak için kulüp adını yaz: $name';
  }

  @override
  String get clubNameHint => 'Kulüp adı';

  @override
  String get clubOwnerCannotLeave =>
      'Kulüp sahibi ayrılamaz. Önce sahipliği devret ya da kulübü sil.';

  @override
  String get clubCannotLeaveTitle => 'Kulüpten ayrılamazsın';

  @override
  String get clubOk => 'Tamam';

  @override
  String get clubThisClub => 'Bu kulüp';

  @override
  String clubLeaveMessage(String name) {
    return '$name kulübünden ayrılmak istiyor musun? Kulüp sohbetinden de çıkarılacaksın ve sohbet listenden silinecek.';
  }

  @override
  String get clubLeaveConfirm => 'Ayrıl';

  @override
  String get clubMgmtJoinTitle => 'Katılma isteği';

  @override
  String clubMgmtJoinAdminsSee(String club) {
    return '$club yöneticileri cevaplarını görecek.';
  }

  @override
  String get clubMgmtAnswerHint => 'Cevabın';

  @override
  String get clubMgmtQuestionRequired => 'Bu soru zorunlu';

  @override
  String get clubMgmtCancel => 'Vazgeç';

  @override
  String get clubMgmtSendRequest => 'İstek gönder';

  @override
  String get clubMgmtNoPending => 'Bekleyen başvuru yok.';

  @override
  String get clubMgmtMoreRequests => 'Daha fazla başvuru';

  @override
  String get clubMgmtRequestsTitle => 'Başvurular';

  @override
  String clubMgmtWaitingCount(String count) {
    return '$count bekliyor';
  }

  @override
  String get clubMgmtUser => 'Kullanıcı';

  @override
  String get clubMgmtReject => 'Reddet';

  @override
  String get clubMgmtApprove => 'Onayla';

  @override
  String get clubMgmtBan => 'Yasakla';

  @override
  String get clubMgmtRemoveFromClub => 'Kulüpten çıkar';

  @override
  String clubMgmtBanMessage(String name) {
    return '$name kulüpten çıkarılsın ve bir daha katılamasın mı?';
  }

  @override
  String clubMgmtRemoveMessage(String name) {
    return '$name kulüpten çıkarılsın mı? Kulüp sohbetinden de düşer.';
  }

  @override
  String get clubMgmtRemoveConfirm => 'Çıkar';

  @override
  String get clubMgmtNoMembers => 'Üye bulunamadı.';

  @override
  String get clubMgmtMembersTitle => 'Üyeler';

  @override
  String get clubMgmtSearchMember => 'Üye ara';

  @override
  String get clubMgmtRoleManager => 'Yönetici';

  @override
  String get clubMgmtRoleModerator => 'Moderatör';

  @override
  String get clubMgmtMemberActions => 'Üye işlemleri';

  @override
  String get clubMgmtMakeModerator => 'Moderatör yap';

  @override
  String get clubMgmtMakeMember => 'Üye yap';

  @override
  String get clubMgmtPendingTitle => 'Kulübün onaya gönderildi';

  @override
  String get clubMgmtPendingBody =>
      'Yöneticiler incelediğinde kulüp yayına girecek. Durumu Kulüplerim bölümünden izleyebilirsin.';

  @override
  String get clubMgmtOk => 'Tamam';

  @override
  String get clubMgmtImageTooLarge => 'Görsel çok büyük.';

  @override
  String get clubMgmtImageUnsupported =>
      'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.';

  @override
  String get clubMgmtImageUnreadable => 'Görsel okunamadı.';

  @override
  String get clubMgmtImagePickFailed => 'Görsel seçilemedi.';

  @override
  String get clubMgmtNameMin => 'Kulüp adı en az 3 karakter olmalı.';

  @override
  String get clubMgmtNameMax => 'Kulüp adı en fazla 80 karakter olabilir.';

  @override
  String get clubMgmtDescMax => 'Açıklama en fazla 1000 karakter olabilir.';

  @override
  String get clubMgmtCategoryMax => 'Kategori en fazla 40 karakter olabilir.';

  @override
  String get clubMgmtSavedWithWarning =>
      'Kulüp kaydedildi ancak kapak ya da katılım soruları kaydedilemedi.';

  @override
  String get clubMgmtEditTitle => 'Kulübü düzenle';

  @override
  String get clubMgmtCreateTitle => 'Kulüp kur';

  @override
  String get clubMgmtNameLabel => 'Kulüp adı';

  @override
  String get clubMgmtNameHint => 'Örn. Robotik Kulübü';

  @override
  String get clubMgmtDescLabel => 'Kısa açıklama';

  @override
  String get clubMgmtDescHint => 'Kulüp ne yapıyor?';

  @override
  String get clubMgmtCategoryLabel => 'Kategori';

  @override
  String get clubMgmtCategoryHint => 'Listeden seç ya da yaz (isteğe bağlı)';

  @override
  String get clubMgmtVisibility => 'Görünürlük';

  @override
  String get clubMgmtPublic => 'Herkese açık';

  @override
  String get clubMgmtPrivate => 'Gizli';

  @override
  String get clubMgmtPrivateHint =>
      'Kulüp içeriğini yalnızca üyeler görür; katılım onayla olur.';

  @override
  String get clubMgmtPublicHint => 'Kulüp Keşfet listesinde görünür.';

  @override
  String get clubMgmtJoinLabel => 'Katılım';

  @override
  String get clubMgmtOpenPolicy => 'Serbest';

  @override
  String get clubMgmtApprovalPolicy => 'Onaylı';

  @override
  String get clubMgmtApprovalHint =>
      'Katılmak isteyenler başvuru gönderir, sen onaylarsın.';

  @override
  String get clubMgmtOpenHint => 'Herkes doğrudan katılabilir.';

  @override
  String clubMgmtQuestionsLabel(String max) {
    return 'Katılım soruları (en çok $max)';
  }

  @override
  String clubMgmtQuestionHint(String n) {
    return 'Soru $n';
  }

  @override
  String get clubMgmtRemoveQuestion => 'Soruyu kaldır';

  @override
  String get clubMgmtAddQuestion => 'Soru ekle';

  @override
  String get clubMgmtSave => 'Kaydet';

  @override
  String get clubMgmtCreateButton => 'Kulübü oluştur';

  @override
  String get clubMgmtChangeCover => 'Kapağı değiştir';

  @override
  String get clubMgmtAddCover => 'Kapak ekle (isteğe bağlı)';

  @override
  String get clubMgmtClubsTitle => 'Kulüpler';

  @override
  String get clubMgmtSearch => 'Ara';

  @override
  String get clubMgmtSearchClub => 'Kulüp ara';

  @override
  String get clubMgmtTabDiscover => 'Keşfet';

  @override
  String get clubMgmtTabMine => 'Kulüplerim';

  @override
  String get clubMgmtAll => 'Tümü';

  @override
  String get clubMgmtEmptyMine => 'Henüz hiçbir kulübe üye değilsin.';

  @override
  String get clubMgmtNotFound => 'Kulüp bulunamadı.';

  @override
  String clubMgmtMemberCount(String count) {
    return '$count üye';
  }

  @override
  String get clubMgmtYouAreMember => 'Üyesin';

  @override
  String get clubMgmtRequestSent => 'İstek gönderildi';

  @override
  String get clubMgmtBanned => 'Engelli';

  @override
  String get clubMgmtJoin => 'Katıl';

  @override
  String get commonBack => 'Geri';

  @override
  String get commonSearchHint => 'Ara';

  @override
  String get commonJustNow => 'şimdi';

  @override
  String commonMinutesAgo(String n) {
    return '$n dk önce';
  }

  @override
  String commonHoursAgo(String n) {
    return '$n sa önce';
  }

  @override
  String commonDaysAgo(String n) {
    return '$n gün önce';
  }

  @override
  String commonLongDate(String day, String month, String weekday) {
    return '$day $month, $weekday';
  }

  @override
  String get commonTypeNews => 'Haber';

  @override
  String get commonTypeAnnouncement => 'Duyuru';

  @override
  String get commonTypeEvent => 'Etkinlik';

  @override
  String get commonMonth1 => 'Ocak';

  @override
  String get commonMonth2 => 'Şubat';

  @override
  String get commonMonth3 => 'Mart';

  @override
  String get commonMonth4 => 'Nisan';

  @override
  String get commonMonth5 => 'Mayıs';

  @override
  String get commonMonth6 => 'Haziran';

  @override
  String get commonMonth7 => 'Temmuz';

  @override
  String get commonMonth8 => 'Ağustos';

  @override
  String get commonMonth9 => 'Eylül';

  @override
  String get commonMonth10 => 'Ekim';

  @override
  String get commonMonth11 => 'Kasım';

  @override
  String get commonMonth12 => 'Aralık';

  @override
  String get commonWeekday1 => 'Pazartesi';

  @override
  String get commonWeekday2 => 'Salı';

  @override
  String get commonWeekday3 => 'Çarşamba';

  @override
  String get commonWeekday4 => 'Perşembe';

  @override
  String get commonWeekday5 => 'Cuma';

  @override
  String get commonWeekday6 => 'Cumartesi';

  @override
  String get commonWeekday7 => 'Pazar';

  @override
  String get reportReasonSpam => 'Spam veya reklam';

  @override
  String get reportReasonHarassment => 'Taciz veya zorbalık';

  @override
  String get reportReasonInappropriate => 'Uygunsuz içerik';

  @override
  String get reportReasonImpersonation => 'Başkasını taklit';

  @override
  String get reportReasonOther => 'Diğer';

  @override
  String get reportTitle => 'Şikâyet et';

  @override
  String get reportMessageTitle => 'Mesajı şikâyet et';

  @override
  String get reportThanks => 'Şikâyetiniz alındı. Teşekkürler.';

  @override
  String get reportPrompt => 'Sebep seçin. Şikâyetiniz yöneticilere iletilir.';

  @override
  String get reportDetailsHint => 'Ek açıklama (isteğe bağlı)';

  @override
  String get reportSend => 'Gönder';

  @override
  String get permNotificationsTitle => 'Bildirimler';

  @override
  String get permNotificationsText =>
      'Mesaj, etkinlik ve duyurulardan anında haberdar olmak için bildirim göndermemize izin verin.';

  @override
  String get permCameraTitle => 'Kamera';

  @override
  String get permCameraText =>
      'QR kod okutmak ve fotoğraf çekmek için kameraya erişmemiz gerekir.';

  @override
  String get permMicrophoneTitle => 'Mikrofon';

  @override
  String get permMicrophoneText =>
      'Ses ve görüntü kaydı yapabilmeniz için mikrofona erişmemiz gerekir.';

  @override
  String get permPhotosTitle => 'Fotoğraflar';

  @override
  String get permPhotosText =>
      'Fotoğraf seçip paylaşabilmeniz için galerinize erişmemiz gerekir.';

  @override
  String get permContinue => 'Devam';

  @override
  String get permNotNow => 'Şimdi değil';

  @override
  String permDeniedText(String title) {
    return '$title izni verilmedi, bu yüzden bu özellik kullanılamıyor. İzni Ayarlar > BÜ Kampüs bölümünden açabilirsiniz.';
  }

  @override
  String get permOpenSettings => 'Ayarlardan aç';

  @override
  String get permClose => 'Kapat';

  @override
  String get permPageTitle => 'Birkaç izin';

  @override
  String get permPageIntro =>
      'Dilediğiniz izni şimdi verebilir, diğerlerini sonra Ayarlar’dan açabilirsiniz.';

  @override
  String get permStart => 'Başla';

  @override
  String get permGranted => 'Verildi';

  @override
  String get permDenied => 'Reddedildi';

  @override
  String get permRetry => 'Tekrar dene';

  @override
  String get permAllow => 'İzin ver';

  @override
  String get coreErrNetwork =>
      'Sunucuya ulaşılamadı. Bağlantınızı kontrol edin.';

  @override
  String get coreErrTooMany => 'Çok fazla deneme. Lütfen biraz bekleyin.';

  @override
  String get coreErrGeneric => 'Bir sorun oluştu. Lütfen tekrar deneyin.';

  @override
  String get coreIdEmpty => 'E-posta adresinizi girin.';

  @override
  String get coreIdEmail => 'Geçerli bir e-posta adresi girin.';

  @override
  String get coreOffline => 'Çevrimdışı';

  @override
  String get coreMaintenance => 'Sistem bakımda.';

  @override
  String get coreOpen => 'Aç';

  @override
  String get eventFormJoinFull =>
      'Kontenjan doldu. \"İlgileniyorum\" ile takipte kalabilirsin.';

  @override
  String get eventFormLeaveTitle => 'Katılımdan ayrıl';

  @override
  String get eventFormLeaveMessage =>
      'Bu etkinlik Etkinliklerim listenden çıkarılacak.';

  @override
  String get eventFormLeaveConfirm => 'Ayrıl';

  @override
  String get eventFormRegsClosedToast => 'Kayıtlar kapatıldı.';

  @override
  String get eventFormRegsReopenedToast => 'Kayıtlar yeniden açıldı.';

  @override
  String get eventFormCancelTitle => 'Etkinliği iptal et';

  @override
  String get eventFormCancelMessage =>
      'Bu etkinlik tüm katılımcılar için iptal edilecek.';

  @override
  String get eventFormCancelAction => 'İptal et';

  @override
  String get eventFormCancelledToast => 'Etkinlik iptal edildi.';

  @override
  String get eventFormScanTitle => 'Yoklama QR kodunu tara';

  @override
  String get eventFormWrongEventCode => 'Bu kod başka bir etkinliğe ait.';

  @override
  String get eventFormCheckedIn => 'Yoklaman alındı';

  @override
  String get eventFormChatSoon => 'Etkinlik sohbeti yakında';

  @override
  String get eventFormEventTitle => 'Etkinlik';

  @override
  String get eventFormNotFound => 'Etkinlik bulunamadı';

  @override
  String get eventFormRegsClosed => 'Kayıtlar kapalı';

  @override
  String get eventFormJoin => 'Katıl';

  @override
  String get eventFormInterested => 'İlgileniyorum';

  @override
  String get eventFormBack => 'Geri';

  @override
  String get eventFormManage => 'Yönet';

  @override
  String get eventFormEdit => 'Düzenle';

  @override
  String get eventFormReopenRegs => 'Kayıtları yeniden aç';

  @override
  String get eventFormCloseRegs => 'Kayıtları kapat';

  @override
  String get eventFormReport => 'Şikâyet et';

  @override
  String get eventFormReportEvent => 'Etkinliği şikâyet et';

  @override
  String get eventFormCancelledPill => 'İptal edildi';

  @override
  String get eventFormInMine => 'Etkinliklerimde';

  @override
  String get eventFormOrganizedBy => 'Düzenleyen:';

  @override
  String get eventFormCapacityFull => 'Kontenjan doldu';

  @override
  String eventFormCapacityCount(String going, String cap) {
    return 'Kontenjan: $going / $cap';
  }

  @override
  String get eventFormGoingLabel => 'katılıyor';

  @override
  String get eventFormInterestedLabel => 'ilgileniyor';

  @override
  String get eventFormInterestedShort => 'İlgileniyor';

  @override
  String get eventFormFullHint =>
      'Kontenjan doldu; yine de ilgilendiğini belirtebilirsin.';

  @override
  String get eventFormChat => 'Etkinlik sohbeti';

  @override
  String get eventFormManageJoin => 'Katılımı yönet';

  @override
  String get eventFormCheckInLater => 'Yoklama etkinlik saatinde açılır.';

  @override
  String get eventFormScanQr => 'QR kodu tara';

  @override
  String get eventFormEnterCode => 'Kodu elle gir';

  @override
  String get eventFormEnterOrganizerCode => 'Organizatörün gösterdiği kodu gir';

  @override
  String get eventFormCheckInCode => 'Yoklama kodu';

  @override
  String get eventFormSendCheckIn => 'Yoklamayı gönder';

  @override
  String get eventFormCodePreparing => 'Kod hazırlanıyor…';

  @override
  String get eventFormCodeFailed => 'Kod alınamadı.';

  @override
  String get eventFormQrHelp =>
      'Katılımcılar bu QR kodunu uygulamadan taratır.';

  @override
  String get eventFormCodeShortLived => 'Kod kısa süre geçerlidir.';

  @override
  String eventFormCodeExpires(String time) {
    return 'Son kullanma: $time · kod otomatik yenilenir';
  }

  @override
  String get eventFormRefreshCode => 'Kodu yenile';

  @override
  String get eventFormNoAttendance => 'Henüz yoklama kaydı yok';

  @override
  String eventFormAttendanceCount(String present, String total) {
    return 'Yoklama: $present / $total kişi geldi';
  }

  @override
  String get eventFormAttendees => 'Katılımcılar';

  @override
  String get eventFormShowMore => 'Daha fazla göster';

  @override
  String eventFormCoverCreatedFail(String reason) {
    return 'Etkinlik oluşturuldu, kapak yüklenemedi.$reason';
  }

  @override
  String eventFormCoverFail(String reason) {
    return 'Kapak yüklenemedi.$reason';
  }

  @override
  String get eventFormRetry => 'Tekrar dene';

  @override
  String get eventFormPickGallery => 'Galeriden seç';

  @override
  String get eventFormTakePhoto => 'Fotoğraf çek';

  @override
  String get eventFormImgTooLarge =>
      'Görsel çok büyük, daha küçük bir görsel seçin.';

  @override
  String get eventFormImgUnsupported =>
      'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.';

  @override
  String get eventFormImgUnreadable => 'Görsel okunamadı.';

  @override
  String get eventFormImgPickFail =>
      'Görsel seçilemedi. İzinleri kontrol edin.';

  @override
  String get eventFormTitleTooShort => 'Başlık en az 3 karakter olmalı.';

  @override
  String get eventFormEndBeforeStart => 'Bitiş, başlangıçtan sonra olmalı.';

  @override
  String get eventFormCapInvalid =>
      'Kontenjan 1 veya daha büyük bir sayı olmalı.';

  @override
  String eventFormCoverRemoveFail(String reason) {
    return 'Kapak kaldırılamadı. $reason';
  }

  @override
  String get eventFormCreated => 'Etkinlik oluşturuldu.';

  @override
  String get eventFormEditTitle => 'Etkinliği düzenle';

  @override
  String get eventFormNewTitle => 'Yeni etkinlik';

  @override
  String get eventFormFieldTitle => 'Başlık';

  @override
  String get eventFormTitleHint => 'Etkinlik başlığı';

  @override
  String get eventFormFieldDesc => 'Açıklama';

  @override
  String get eventFormDescHint => 'Etkinlik hakkında kısaca';

  @override
  String get eventFormStart => 'Başlangıç';

  @override
  String get eventFormStartSem => 'Başlangıç zamanı';

  @override
  String get eventFormEnd => 'Bitiş';

  @override
  String get eventFormEndSem => 'Bitiş zamanı';

  @override
  String get eventFormPlace => 'Mekân';

  @override
  String get eventFormPlaceHint => 'Örn. Konferans Salonu';

  @override
  String get eventFormCapacityLabel => 'Kontenjan';

  @override
  String get eventFormCapHint => 'Boş bırakırsan sınırsız';

  @override
  String get eventFormSave => 'Kaydet';

  @override
  String get eventFormCreate => 'Etkinliği oluştur';

  @override
  String get eventFormAddCover => 'Kapak fotoğrafı ekle';

  @override
  String get eventFormChangeCover => 'Kapağı değiştir';

  @override
  String get eventFormRemoveCover => 'Kapağı kaldır';

  @override
  String get eventListTitle => 'Etkinlikler';

  @override
  String get eventListCreate => 'Etkinlik oluştur';

  @override
  String get eventListCheckin => 'Yoklama';

  @override
  String get eventListTabDiscover => 'Keşfet';

  @override
  String get eventListTabMine => 'Etkinliklerim';

  @override
  String get eventListTabCreated => 'Oluşturduklarım';

  @override
  String get eventListLoading => 'Yükleniyor';

  @override
  String get eventListPrevMonth => 'Önceki ay';

  @override
  String get eventListNextMonth => 'Sonraki ay';

  @override
  String eventListMonthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String eventListLongDate(String day, String month, String weekday) {
    return '$day $month, $weekday';
  }

  @override
  String get eventListFull =>
      'Kontenjan doldu. \"İlgileniyorum\" ile takipte kalabilirsin.';

  @override
  String get eventListLeaveTitle => 'Katılımdan ayrıl';

  @override
  String get eventListLeaveMsg =>
      'Bu etkinlik Etkinliklerim listenden çıkarılacak.';

  @override
  String get eventListLeave => 'Ayrıl';

  @override
  String get eventListLeft => 'Katılımdan ayrıldın.';

  @override
  String get eventListClosedDone => 'Kayıtlar kapatıldı.';

  @override
  String get eventListReopenedDone => 'Kayıtlar yeniden açıldı.';

  @override
  String get eventListCancelTitle => 'Etkinliği iptal et';

  @override
  String get eventListCancelMsg =>
      'Bu etkinlik tüm katılımcılar için iptal edilecek.';

  @override
  String get eventListCancelConfirm => 'İptal et';

  @override
  String get eventListCancelledDone => 'Etkinlik iptal edildi.';

  @override
  String get eventListScanTitle => 'Yoklama QR kodunu tara';

  @override
  String get eventListNotCode => 'Bu bir yoklama kodu değil.';

  @override
  String get eventListShortCodeNeedsEvent =>
      'Şu an yoklaması açık bir etkinliğin yok. Kısa kodu, etkinlik sayfasındaki “Kodu elle gir” alanına yaz.';

  @override
  String get eventListCheckedIn => 'Yoklaman alındı.';

  @override
  String get eventListEmptyDay => 'Bu gün için etkinlik yok.';

  @override
  String get eventListEmptyMonth => 'Bu ay için etkinlik yok.';

  @override
  String get eventListPastMonth => 'Geçmiş ay: yalnızca görüntüleme.';

  @override
  String get eventListTruncated =>
      'Bu ayın tamamı gösterilemiyor; bazı etkinlikler listede yok.';

  @override
  String get eventListUpcoming => 'Yaklaşan';

  @override
  String get eventListPast => 'Geçmiş';

  @override
  String get eventListCreatedHint =>
      'Oluşturduğun etkinlikleri buradan yönetebilirsin.';

  @override
  String get eventListEmptyUpcoming => 'Katılacağın bir etkinlik yok.';

  @override
  String get eventListEmptyPast => 'Geçmiş etkinliğin yok.';

  @override
  String get eventListEmptyCreated => 'Henüz bir etkinlik oluşturmadın.';

  @override
  String get eventListDiscover => 'Etkinlikleri keşfet';

  @override
  String get eventListOfficial => 'Resmi';

  @override
  String get eventListCancelled => 'İptal';

  @override
  String get eventListRegClosedTag => 'Kayıt kapalı';

  @override
  String get eventListOpen => 'Açık';

  @override
  String get eventListRegsClosed => 'Kayıtlar kapalı';

  @override
  String get eventListJoin => 'Katıl';

  @override
  String get eventListInterested => 'İlgileniyorum';

  @override
  String get eventListGoing => 'katılıyor';

  @override
  String get eventListOptions => 'Seçenekler';

  @override
  String eventListAttendeeCount(String count) {
    return '$count katılımcı';
  }

  @override
  String get eventListAttendees => 'Katılımcılar';

  @override
  String get eventListEdit => 'Düzenle';

  @override
  String get eventListReopen => 'Kayıtları yeniden aç';

  @override
  String get eventListClose => 'Kayıtları kapat';

  @override
  String get eventListRegClosedError => 'Bu etkinliğin kayıtları kapalı.';

  @override
  String get eventListAddedMine => 'Etkinliklerime eklendi';

  @override
  String get eventListDismiss => 'Vazgeç';

  @override
  String get eventListInMine => 'Etkinliklerimde';

  @override
  String get eventListQrLabel => 'Yoklama QR kodu';

  @override
  String get eventListMonth1 => 'Ocak';

  @override
  String get eventListMonth2 => 'Şubat';

  @override
  String get eventListMonth3 => 'Mart';

  @override
  String get eventListMonth4 => 'Nisan';

  @override
  String get eventListMonth5 => 'Mayıs';

  @override
  String get eventListMonth6 => 'Haziran';

  @override
  String get eventListMonth7 => 'Temmuz';

  @override
  String get eventListMonth8 => 'Ağustos';

  @override
  String get eventListMonth9 => 'Eylül';

  @override
  String get eventListMonth10 => 'Ekim';

  @override
  String get eventListMonth11 => 'Kasım';

  @override
  String get eventListMonth12 => 'Aralık';

  @override
  String get eventListMon1 => 'OCA';

  @override
  String get eventListMon2 => 'ŞUB';

  @override
  String get eventListMon3 => 'MAR';

  @override
  String get eventListMon4 => 'NİS';

  @override
  String get eventListMon5 => 'MAY';

  @override
  String get eventListMon6 => 'HAZ';

  @override
  String get eventListMon7 => 'TEM';

  @override
  String get eventListMon8 => 'AĞU';

  @override
  String get eventListMon9 => 'EYL';

  @override
  String get eventListMon10 => 'EKİ';

  @override
  String get eventListMon11 => 'KAS';

  @override
  String get eventListMon12 => 'ARA';

  @override
  String get eventListDayShort1 => 'Pzt';

  @override
  String get eventListDayShort2 => 'Sal';

  @override
  String get eventListDayShort3 => 'Çar';

  @override
  String get eventListDayShort4 => 'Per';

  @override
  String get eventListDayShort5 => 'Cum';

  @override
  String get eventListDayShort6 => 'Cmt';

  @override
  String get eventListDayShort7 => 'Paz';

  @override
  String get eventListDayLong1 => 'Pazartesi';

  @override
  String get eventListDayLong2 => 'Salı';

  @override
  String get eventListDayLong3 => 'Çarşamba';

  @override
  String get eventListDayLong4 => 'Perşembe';

  @override
  String get eventListDayLong5 => 'Cuma';

  @override
  String get eventListDayLong6 => 'Cumartesi';

  @override
  String get eventListDayLong7 => 'Pazar';

  @override
  String get homeGreetNight => 'İyi geceler';

  @override
  String get homeGreetMorning => 'Günaydın';

  @override
  String get homeGreetDay => 'İyi günler';

  @override
  String get homeGreetEvening => 'İyi akşamlar';

  @override
  String get homeEventLoadFailedToast => 'Etkinlik yüklenemedi.';

  @override
  String get homeEventLoadFailedTitle => 'Etkinlik yüklenemedi';

  @override
  String get homeQuotaFull => 'Kontenjan doldu.';

  @override
  String get homeMaintenanceDefault => 'Sistem bakımda.';

  @override
  String get homeSourceUnreachable =>
      'Kaynak siteye ulaşılamıyor; veriler eski olabilir.';

  @override
  String get homeSearchHint => 'Kampüste ara';

  @override
  String get homeMyClubs => 'Kulüplerimden';

  @override
  String get homeAll => 'Tümü';

  @override
  String get homeAgenda => 'Gündem';

  @override
  String get homeContentLoadFailed => 'İçerik yüklenemedi.';

  @override
  String get homeNoContent => 'İçerik yok.';

  @override
  String get homeMyProfile => 'Profilim';

  @override
  String get homeFeaturedEvent => 'Öne çıkan etkinlik';

  @override
  String get homeNextEvent => 'Sıradaki etkinlik';

  @override
  String get homeNoUpcoming => 'Yaklaşan etkinlik yok';

  @override
  String get homeBrowseEvents => 'Etkinliklere göz at';

  @override
  String get homeOfficialEvent => 'Resmi etkinlik';

  @override
  String get homeMostAttended => 'En çok katılım';

  @override
  String homeGoingCount(String count) {
    return '$count kişi katılıyor';
  }

  @override
  String get homeBeFirst => 'İlk katılan sen ol';

  @override
  String get homeInMyEvents => 'Etkinliklerimde';

  @override
  String get homeFull => 'Dolu';

  @override
  String get homeRegClosed => 'Kayıt kapalı';

  @override
  String get homeJoin => 'Katıl';

  @override
  String get homeQuickEvent => 'Etkinlik';

  @override
  String get homeQuickFood => 'Yemek';

  @override
  String get homeQuickSupport => 'Destek';

  @override
  String get homeTodayMeal => 'Bugünün yemeği';

  @override
  String get homeNoMenuToday => 'Bugün için liste yok';

  @override
  String get homeNewMessages => 'yeni mesaj';

  @override
  String get homeClubMemberships => 'kulüp üyeliği';

  @override
  String homeMemberCount(String count) {
    return '$count üye';
  }

  @override
  String get newsTypeNews => 'Haber';

  @override
  String get newsTypeAnnouncement => 'Duyuru';

  @override
  String get newsTypeEvent => 'Etkinlik';

  @override
  String newsEventDateShort(String date) {
    return 'Etkinlik: $date';
  }

  @override
  String newsEventDate(String date) {
    return 'Etkinlik tarihi: $date';
  }

  @override
  String get newsSaveRemove => 'Favorilerden çıkar';

  @override
  String get newsSaveAdd => 'Favorilere ekle';

  @override
  String get newsLinkOpenFailed => 'Bağlantı açılamadı.';

  @override
  String get newsFullContent => 'İçeriğin tamamı için kaynak sayfayı açın.';

  @override
  String get newsOpenSource => 'Kaynak sayfada aç';

  @override
  String get newsMonth1 => 'Ocak';

  @override
  String get newsMonth2 => 'Şubat';

  @override
  String get newsMonth3 => 'Mart';

  @override
  String get newsMonth4 => 'Nisan';

  @override
  String get newsMonth5 => 'Mayıs';

  @override
  String get newsMonth6 => 'Haziran';

  @override
  String get newsMonth7 => 'Temmuz';

  @override
  String get newsMonth8 => 'Ağustos';

  @override
  String get newsMonth9 => 'Eylül';

  @override
  String get newsMonth10 => 'Ekim';

  @override
  String get newsMonth11 => 'Kasım';

  @override
  String get newsMonth12 => 'Aralık';

  @override
  String get newsDayLong1 => 'Pazartesi';

  @override
  String get newsDayLong2 => 'Salı';

  @override
  String get newsDayLong3 => 'Çarşamba';

  @override
  String get newsDayLong4 => 'Perşembe';

  @override
  String get newsDayLong5 => 'Cuma';

  @override
  String get newsDayLong6 => 'Cumartesi';

  @override
  String get newsDayLong7 => 'Pazar';

  @override
  String get newsDayShort1 => 'Pzt';

  @override
  String get newsDayShort2 => 'Sal';

  @override
  String get newsDayShort3 => 'Çar';

  @override
  String get newsDayShort4 => 'Per';

  @override
  String get newsDayShort5 => 'Cum';

  @override
  String get newsDayShort6 => 'Cmt';

  @override
  String get newsDayShort7 => 'Paz';

  @override
  String get discoverSaved => 'Kaydedilenler';

  @override
  String get discoverScopeLatest => 'Yeni';

  @override
  String get discoverScopePopular => 'Popüler';

  @override
  String get discoverScopeFollowing => 'Takip';

  @override
  String get discoverScopeDepartment => 'Bölümüm';

  @override
  String get discoverNoSaved => 'Henüz kaydettiğiniz bir haber yok.';

  @override
  String get discoverNoCategory => 'Bu kategoride henüz içerik yok.';

  @override
  String get discoverDeptHint =>
      'Bölümünü profilinden seçersen bölümündeki gönderileri burada görürsün.';

  @override
  String get discoverDeptEmpty => 'Bölümünden henüz gönderi yok.';

  @override
  String get discoverProfilePath => 'Profil > Profili düzenle';

  @override
  String get discoverPolls => 'Anketler';

  @override
  String get discoverSearch => 'Ara';

  @override
  String get discoverCompose => 'Gönderi oluştur';

  @override
  String get discoverPosts => 'Gönderiler';

  @override
  String get discoverNews => 'Haberler';

  @override
  String get discoverSourceMaint =>
      'Kaynak site şu an bakımda. Veriler güncel olmayabilir.';

  @override
  String get menuTitle => 'Yemek listesi';

  @override
  String get menuStale =>
      'Yemek listesi güncellenemedi; son bilinen liste gösteriliyor.';

  @override
  String get menuTopUpTitle => 'Yemek kartı bakiyesi';

  @override
  String get menuTopUpBody =>
      'Bakiyen bittiyse yukle.al üzerinden yemekhane kartına güvenle bakiye yükleyebilirsin.';

  @override
  String get menuTopUpAction => 'Bakiye yükle';

  @override
  String get menuTopUpFailed =>
      'Bağlantı açılamadı. Lütfen tarayıcından yukle.al adresine git.';

  @override
  String get menuPrevMonth => 'Önceki ay';

  @override
  String get menuNextMonth => 'Sonraki ay';

  @override
  String menuTodayLabel(String date) {
    return 'BUGÜN · $date';
  }

  @override
  String get menuNoMenuDay => 'Bu gün için yemek listesi yok.';

  @override
  String get menuNoMenuMonth => 'Bu ay için yemek listesi henüz yayınlanmadı.';

  @override
  String get menuNoList => 'Yemek listesi yok.';

  @override
  String get menuPhotoLabel => 'Günün menüsü fotoğrafı';

  @override
  String get notifTitle => 'Bildirimler';

  @override
  String get notifMarkAll => 'Tümünü okundu yap';

  @override
  String get notifEmpty => 'Henüz bildiriminiz yok.';

  @override
  String get activityTitle => 'Hareketler';

  @override
  String get activityFilterLikes => 'Beğeniler';

  @override
  String get activityFilterComments => 'Yorumlar';

  @override
  String get activityFilterFollows => 'Takip ve İstekler';

  @override
  String get notifFilterEvents => 'Etkinlikler';

  @override
  String get notifFilterAnnouncements => 'Duyurular';

  @override
  String get notifFilterSystem => 'Sistem';

  @override
  String get activityRequestStale =>
      'Bu başvuru artık beklemiyor; daha önce sonuçlanmış olabilir.';

  @override
  String get activityEmpty =>
      'Henüz hareket yok. Beğeniler, yorumlar, yeni takipçiler ve istekler burada görünür.';

  @override
  String get notifTargetOpenFailed => 'Bu bildirimin hedefi açılamadı.';

  @override
  String get notifUnread => 'Okunmamış bildirim';

  @override
  String get notifGroupToday => 'BUGÜN';

  @override
  String get notifGroupYesterday => 'DÜN';

  @override
  String get notifGroupOlder => 'DAHA ESKİ';

  @override
  String get notifNow => 'şimdi';

  @override
  String notifMinAgo(String n) {
    return '$n dk önce';
  }

  @override
  String notifHourAgo(String n) {
    return '$n sa önce';
  }

  @override
  String notifDayAgo(String n) {
    return '$n gün önce';
  }

  @override
  String get searchAll => 'Tümü';

  @override
  String get searchClub => 'Kulüp';

  @override
  String get searchPost => 'Gönderi';

  @override
  String get searchPerson => 'Kişi';

  @override
  String searchClassYear(String n) {
    return '$n. sınıf';
  }

  @override
  String get searchUserDefault => 'Kullanıcı';

  @override
  String get searchHint => 'Haber, kulüp, etkinlik, gönderi, kişi ara';

  @override
  String get searchClear => 'Aramayı temizle';

  @override
  String get srLoadMore => 'Daha fazla göster';

  @override
  String get srSearchHint => 'Kullanıcı veya gönderi ara';

  @override
  String get srTabUsers => 'Kullanıcılar';

  @override
  String get srTabPosts => 'Gönderiler';

  @override
  String get srTabReels => 'Reels';

  @override
  String get srSearchTabsLabel => 'Arama sonucu türleri';

  @override
  String get srSearchPrompt =>
      'Kullanıcı, gönderi veya reels aramak için en az 2 karakter yazın.';

  @override
  String get srSeeAll => 'Tümünü gör';

  @override
  String get srReelsUnavailable => 'Reels araması şu an kullanılamıyor.';

  @override
  String get srPrivateAccount => 'Gizli hesap';

  @override
  String srLikeCount(String count) {
    return '$count beğeni';
  }

  @override
  String srOpenProfileOf(String name) {
    return '$name profilini aç';
  }

  @override
  String srPostByAuthor(String name) {
    return '$name gönderisi';
  }

  @override
  String get srVideoBadge => 'Video';

  @override
  String get srProfileTabsLabel => 'Profil içeriği';

  @override
  String get srProfilePostsEmpty => 'Henüz gönderi yok.';

  @override
  String get srProfileReelsEmpty => 'Henüz reels yok.';

  @override
  String srViewCount(String count) {
    return '$count görüntülenme';
  }

  @override
  String get srPhotoViewerTitle => 'Profil fotoğrafı';

  @override
  String get srPhotoViewerError => 'Fotoğraf yüklenemedi';

  @override
  String get srPhotoViewerClose => 'Önizlemeyi kapat';

  @override
  String get srAvatarLongPressHint => 'Büyük fotoğrafı görmek için uzun bas';

  @override
  String get searchPrompt =>
      'Haber, duyuru, kulüp, etkinlik veya kişi aramak için en az 2 karakter yazın.';

  @override
  String get searchRecent => 'Son aramalar';

  @override
  String get searchClearRecent => 'Temizle';

  @override
  String get searchNoResults => 'Sonuç bulunamadı.';

  @override
  String searchResultCount(String count) {
    return '$count sonuç';
  }

  @override
  String get searchTooMany =>
      'Çok fazla istek gönderildi, birkaç saniye bekleyin.';

  @override
  String get followButtonUnfollow => 'Takipten çık';

  @override
  String get followButtonFollow => 'Takip et';

  @override
  String get followButtonFollowing => 'Takip ediliyor';

  @override
  String get followersTitle => 'Takipçiler';

  @override
  String get followingTitle => 'Takip edilenler';

  @override
  String get followersEmpty => 'Henüz takipçi yok.';

  @override
  String get followingEmpty => 'Henüz kimse takip edilmiyor.';

  @override
  String get followSuggestionsEmpty => 'Şimdilik önerilecek kişi yok.';

  @override
  String get followSuggestionsTitle => 'Önerilen kişiler';

  @override
  String get followReasonClub => 'Ortak kulüp';

  @override
  String get followReasonGrade => 'Aynı sınıf';

  @override
  String get followReasonDepartment => 'Aynı bölüm';

  @override
  String get followFeedHint => 'Takip ettiklerinin gönderileri burada görünür.';

  @override
  String get followersCount => 'Takipçi';

  @override
  String get followingCount => 'Takip';

  @override
  String get qrScanTitle => 'QR kodu tara';

  @override
  String get qrCameraRationale =>
      'QR kodu okutabilmek için kameraya erişmemiz gerekir.';

  @override
  String get qrManualLabel => 'Kodu elle gir';

  @override
  String get qrConfirm => 'Onayla';

  @override
  String get qrCameraDenied =>
      'Kamera izni verilmedi. Kodu elle girebilir ya da izin verip taramayı yeniden deneyebilirsiniz.';

  @override
  String get qrGrantCamera => 'Kamera izni ver';

  @override
  String get qrDeniedSettings =>
      'Kamera izni verilmedi. Ayarlar > BÜ Kampüs bölümünden izin verebilir ya da kodu elle girebilirsiniz.';

  @override
  String get qrCameraFailed => 'Kamera açılamadı. Kodu elle girebilirsiniz.';

  @override
  String get qrTorch => 'El feneri';

  @override
  String get pollListTitle => 'Anketler';

  @override
  String get pollClubPolls => 'Kulüp anketleri';

  @override
  String get pollTabOpen => 'Açık';

  @override
  String get pollTabMine => 'Katıldıklarım';

  @override
  String get pollTabClosed => 'Kapanan';

  @override
  String get pollEmptyOpen => 'Şu an açık anket yok.';

  @override
  String get pollEmptyMine => 'Henüz bir ankete katılmadınız.';

  @override
  String get pollEmptyClosed => 'Kapanan anket yok.';

  @override
  String get pollLoadFailedRetry => 'Yüklenemedi, tekrar dene';

  @override
  String get pollCreate => 'Anket oluştur';

  @override
  String get pollClubEmpty => 'Henüz anket yok.';

  @override
  String get pollSeeAll => 'Tüm anketleri gör';

  @override
  String get pollMenuRateToday => 'Bugünün menüsünü puanla';

  @override
  String pollYourRating(String rating) {
    return 'Puanınız: $rating';
  }

  @override
  String pollYourRatingAvg(String rating, String avg) {
    return 'Puanınız: $rating · Ortalama $avg';
  }

  @override
  String get pollTapStar => 'Yıldıza dokunarak puanla';

  @override
  String get pollNoVoteRight => 'Bu anket için oy hakkınız yok';

  @override
  String pollStars(String n) {
    return '$n yıldız';
  }

  @override
  String pollSemPercent(String text, String pct) {
    return '$text, yüzde $pct';
  }

  @override
  String pollVotes(String votes) {
    return '$votes oy';
  }

  @override
  String pollVotesWithScore(String votes, String score) {
    return '$votes oy · $score puan';
  }

  @override
  String get pollSemMine => 'seçiminiz';

  @override
  String get pollTypeSingle => 'Tek seçim';

  @override
  String get pollTypeMulti => 'Çoklu seçim';

  @override
  String get pollTypeRating => 'Puanlama';

  @override
  String get pollTypeRanked => 'Sıralı seçim';

  @override
  String get pollAnonymous => 'Gizli oy';

  @override
  String get pollVotedBadge => 'Oy verdiniz';

  @override
  String get pollClosedBadge => 'Kapandı';

  @override
  String pollParticipants(String n) {
    return '$n katılım';
  }

  @override
  String pollParticipationOf(String v, String e) {
    return '$v / $e katılım';
  }

  @override
  String pollSemPoll(String title) {
    return 'Anket: $title';
  }

  @override
  String get pollEnded => 'Sona erdi';

  @override
  String pollDaysLeft(String n) {
    return '$n gün kaldı';
  }

  @override
  String pollHoursLeft(String n) {
    return '$n sa kaldı';
  }

  @override
  String pollMinutesLeft(String n) {
    return '$n dk kaldı';
  }

  @override
  String get pollBlockedNotEligible => 'Bu ankete katılma yetkiniz yok.';

  @override
  String get pollBlockedClosed => 'Bu anket kapandı. Oy verilemez.';

  @override
  String get pollBlockedNotOpen => 'Bu anket henüz açılmadı.';

  @override
  String get pollBlockedAlreadyVoted =>
      'Oyunuz kaydedildi; bu ankette oy değiştirilemez.';

  @override
  String get pollBlockedDefault => 'Bu ankette oy veremezsiniz.';

  @override
  String get pollValTitle => 'Başlık gerekli.';

  @override
  String get pollValMin2 => 'En az 2 seçenek girin.';

  @override
  String get pollValMax12 => 'En fazla 12 seçenek olabilir.';

  @override
  String get pollValDistinct => 'Seçenekler birbirinden farklı olmalı.';

  @override
  String get pollValEnd => 'Bitiş zamanını seçin.';

  @override
  String get pollValFuture => 'Bitiş zamanı gelecekte olmalı.';

  @override
  String get pollErrClosed => 'Bu anket kapandı.';

  @override
  String get pollErrAlreadyVoted => 'Bu ankete zaten oy verdiniz.';

  @override
  String get pollErrForbidden => 'Bu işlem için yetkiniz yok.';

  @override
  String get pollErrNotFound => 'Anket bulunamadı.';

  @override
  String get pollErrInvalidVote => 'Geçersiz seçim.';

  @override
  String get pollHeader => 'Anket';

  @override
  String get pollStale => 'Güncellenemedi; son bilinen veri gösteriliyor.';

  @override
  String get pollVoteSaved => 'Oyunuz kaydedildi.';

  @override
  String get pollVoteRetracted => 'Oyunuz geri çekildi.';

  @override
  String get pollRetractTitle => 'Oyu geri çek';

  @override
  String get pollRetractBody => 'Oyunuz silinecek. Devam edilsin mi?';

  @override
  String get pollCancel => 'Vazgeç';

  @override
  String get pollRetractAction => 'Geri çek';

  @override
  String pollMaxChoicesSnack(String n) {
    return 'En fazla $n seçenek işaretleyebilirsiniz.';
  }

  @override
  String get pollSecretVote => 'Oyunuz gizlidir';

  @override
  String get pollResultsAfterClose => 'Sonuçlar anket kapanınca görünecek.';

  @override
  String get pollHintRanked =>
      'Tercih sırasına göre dokunun: ilk dokunduğunuz en çok tercih ettiğinizdir.';

  @override
  String pollHintMax(String n) {
    return 'En fazla $n seçenek işaretleyin.';
  }

  @override
  String get pollHintMulti => 'Birden fazla seçenek işaretleyebilirsiniz.';

  @override
  String get pollVoteUpdate => 'Oyu güncelle';

  @override
  String get pollVote => 'Oy ver';

  @override
  String get pollChangeVote => 'Oyu değiştir';

  @override
  String pollRatingCount(String n) {
    return '$n puan';
  }

  @override
  String get pollFieldTitle => 'Başlık';

  @override
  String get pollTitleHint => 'Örn. Yeni dönem başkanı seçimi';

  @override
  String get pollFieldDesc => 'Açıklama (isteğe bağlı)';

  @override
  String get pollDescHint => 'Kısa bir açıklama';

  @override
  String get pollFieldType => 'Tür';

  @override
  String pollFieldOptions(String max) {
    return 'Seçenekler (2-$max)';
  }

  @override
  String pollOptionHint(String n) {
    return 'Seçenek $n';
  }

  @override
  String get pollRemoveOption => 'Seçeneği sil';

  @override
  String get pollAddOption => 'Seçenek ekle';

  @override
  String get pollAnonymousSub => 'Kimin ne oy verdiği kimseye gösterilmez.';

  @override
  String get pollFieldEnd => 'Bitiş zamanı';

  @override
  String pollDurDays(String n) {
    return '$n gün';
  }

  @override
  String get pollPickDateTime => 'Tarih ve saat seç';

  @override
  String get pollChange => 'Değiştir';

  @override
  String get pollPublish => 'Yayınla';

  @override
  String get postComposeErrBadResponse => 'Sunucudan beklenmeyen yanıt.';

  @override
  String get postComposeErrPrepare => 'Medya hazırlanamadı.';

  @override
  String get postComposeErrImageTooLarge => 'Görsel çok büyük.';

  @override
  String get postComposeErrImageUnsupported =>
      'Bu görsel biçimi desteklenmiyor.';

  @override
  String get postComposeErrImageUnreadable => 'Görsel okunamadı.';

  @override
  String get postComposeErrNetwork => 'Bağlantı yok, tekrar dene.';

  @override
  String get postComposeErrVideoTooLarge => 'Video çok büyük (en fazla 40 MB).';

  @override
  String get postComposeErrVideoTooLong => 'Video en fazla 60 saniye olabilir.';

  @override
  String get postComposeErrVideoInvalid => 'Video biçimi desteklenmiyor.';

  @override
  String get postComposeErrBlocked => 'Bu içerik paylaşılamaz.';

  @override
  String get postComposeErrMediaInvalid => 'Medya geçersiz, yeniden yükle.';

  @override
  String get postComposeErrProfanity =>
      'Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin.';

  @override
  String get postComposeErrRate =>
      'Çok hızlı paylaşım yapıyorsun, biraz bekle.';

  @override
  String get postComposeErrFileTooLarge => 'Dosya çok büyük.';

  @override
  String get postComposeErrGeneric => 'Bir sorun oluştu, tekrar dene.';

  @override
  String get postComposeErrVideoUnsupported =>
      'Bu cihazda video hazırlanamıyor.';

  @override
  String get postComposeErrCancelled => 'İptal edildi.';

  @override
  String get postComposeErrVideoFailed => 'Video hazırlanamadı.';

  @override
  String get postComposeEdit => 'Düzenle';

  @override
  String get postComposeDelete => 'Sil';

  @override
  String get postComposeViewProfile => 'Profili gör';

  @override
  String get postComposeReport => 'Şikâyet et';

  @override
  String get postComposeBlockUser => 'Bu kullanıcıyı engelle';

  @override
  String get postComposeClose => 'Kapat';

  @override
  String get postComposeReportTitle => 'Gönderiyi şikâyet et';

  @override
  String get postComposeDeleteTitle => 'Gönderi silinsin mi?';

  @override
  String get postComposeDeleteBody => 'Bu işlem geri alınamaz.';

  @override
  String get postComposeCancel => 'Vazgeç';

  @override
  String get postComposeDeleted => 'Gönderi silindi';

  @override
  String get postComposeBlockTitle => 'Kullanıcı engellensin mi?';

  @override
  String get postComposeBlockBody =>
      'Engellediğiniz kişinin gönderilerini görmezsiniz ve onunla mesajlaşamazsınız.';

  @override
  String get postComposeBlock => 'Engelle';

  @override
  String get postComposeBlocked => 'Kullanıcı engellendi';

  @override
  String get postComposeEditTitle => 'Gönderiyi düzenle';

  @override
  String get postComposeTextEmpty => 'Metin boş olamaz.';

  @override
  String get postComposeProfanityFallback =>
      'Metin uygunsuz ifadeler içeriyor.';

  @override
  String get postComposeHint => 'Ne düşünüyorsun?';

  @override
  String get postComposeSave => 'Kaydet';

  @override
  String get postComposeMore => 'Daha fazla';

  @override
  String postComposeMaxMedia(String max) {
    return 'En fazla $max medya ekleyebilirsin';
  }

  @override
  String postComposeFailedCount(String count) {
    return '$count medya yüklenemedi. Yeniden deneyebilir ya da çıkarabilirsin.';
  }

  @override
  String get postComposeInvalidRetry =>
      'Medya geçersiz, yeniden yüklenecek. Paylaş düğmesine tekrar dokun.';

  @override
  String get postComposeNetworkDraftKept =>
      'Bağlantı yok. Taslağın korundu, tekrar dene.';

  @override
  String get postComposeShared => 'Paylaşıldı';

  @override
  String get postComposeDiscardTitle => 'Taslağı silmek istiyor musun?';

  @override
  String get postComposeDiscardBody =>
      'Yazdıkların ve seçtiğin medya silinecek.';

  @override
  String get postComposeContinue => 'Devam';

  @override
  String get postComposeDiscardDraft => 'Taslağı sil';

  @override
  String get postComposeNewPost => 'Yeni gönderi';

  @override
  String get postPickerCameraHint =>
      'Fotoğraf için dokun, video için basılı tut';

  @override
  String get postPickerLimitedBody =>
      'Yalnızca izin verdiğin fotoğraf ve videolar görünüyor. Paylaşmak istediklerini ekleyebilirsin.';

  @override
  String get postPickerDeniedBody =>
      'Gönderi paylaşmak için galerine erişim izni vermelisin. İstersen sistemin kendi galerisinden de seçebilirsin.';

  @override
  String get postPickerUseSystem => 'Sistem galerisini kullan';

  @override
  String get postComposeShare => 'Paylaş';

  @override
  String get postComposeDraftBanner => 'Kayıtlı bir taslağın var.';

  @override
  String get postComposeRestoreDraft => 'Taslağı geri yükle';

  @override
  String get postComposeRetry => 'Yeniden dene';

  @override
  String get postComposeRemoveFailed => 'Başarısızları çıkar';

  @override
  String get postComposeRemove => 'Çıkar';

  @override
  String get postComposeGallery => 'Galeri';

  @override
  String get postComposeCamera => 'Kamera';

  @override
  String get postComposeSaveUnsupported => 'Bu cihazda desteklenmiyor.';

  @override
  String get postComposeSaveDenied => 'Galeri izni verilmedi.';

  @override
  String get postComposeSaveNoSpace => 'Cihazda yeterli alan yok.';

  @override
  String get postComposeImageSaveFailed => 'Görsel kaydedilemedi.';

  @override
  String get postComposeSavedToGallery => 'Galeriye kaydedildi';

  @override
  String get postComposeDownload => 'İndir';

  @override
  String get postComposeImageLoadFailed => 'Görsel yüklenemedi.';

  @override
  String get postComposeVideoPlayFailed => 'Video oynatılamadı';

  @override
  String postComposeVideoOf(String n, String total) {
    return 'Video $n / $total';
  }

  @override
  String postComposePhotoOf(String n, String total) {
    return 'Fotoğraf $n / $total';
  }

  @override
  String postComposeVideoOfMore(String n, String total, String more) {
    return 'Video $n / $total, +$more daha';
  }

  @override
  String postComposePhotoOfMore(String n, String total, String more) {
    return 'Fotoğraf $n / $total, +$more daha';
  }

  @override
  String get postComposeVideo => 'Video';

  @override
  String get postComposePhoto => 'Fotoğraf';

  @override
  String get postComposePlayVideo => 'Videoyu oynat';

  @override
  String get postComposeUnmute => 'Sesi aç';

  @override
  String get postComposeMute => 'Sesi kapat';

  @override
  String postComposeMentionAdd(String name) {
    return 'Anma ekle $name';
  }

  @override
  String postComposeTagAdd(String tag) {
    return 'Etiket ekle $tag';
  }

  @override
  String postComposePostCount(String count) {
    return '$count gönderi';
  }

  @override
  String postComposeUserLabel(String name) {
    return 'Kullanıcı $name';
  }

  @override
  String postComposeTagLabel(String tag) {
    return 'Etiket $tag';
  }

  @override
  String postComposeTagLabelCount(String tag, String count) {
    return 'Etiket $tag, $count gönderi';
  }

  @override
  String postViewReplyingTo(String name) {
    return 'Yanıtlıyor: @$name';
  }

  @override
  String get postViewCancelReply => 'Yanıtı iptal et';

  @override
  String get postViewWriteReplyHint => 'Yanıtını yaz…';

  @override
  String get postViewWriteCommentHint => 'Yorum yaz…';

  @override
  String get postViewSend => 'Gönder';

  @override
  String get postViewAgoNow => 'şimdi';

  @override
  String postViewAgoMin(String n) {
    return '$n dk';
  }

  @override
  String postViewAgoHour(String n) {
    return '$n sa';
  }

  @override
  String postViewAgoDay(String n) {
    return '$n g';
  }

  @override
  String postViewAgoWeek(String n) {
    return '$n hf';
  }

  @override
  String postViewAgoYear(String n) {
    return '$n y';
  }

  @override
  String postViewAgoMinFull(String n) {
    return '$n dk önce';
  }

  @override
  String postViewAgoHourFull(String n) {
    return '$n sa önce';
  }

  @override
  String postViewAgoDayFull(String n) {
    return '$n gün önce';
  }

  @override
  String get postViewRepliesLoadFailed => 'Yanıtlar yüklenemedi · Yeniden dene';

  @override
  String postViewShowReplies(String n) {
    return '$n yanıtı göster';
  }

  @override
  String get postViewShowMoreReplies => 'Daha fazla yanıt göster';

  @override
  String get postViewHideReplies => 'Yanıtları gizle';

  @override
  String get postViewCommentsLoadFailed =>
      'Yorumlar yüklenemedi · Yeniden dene';

  @override
  String get postViewCommentsLoading => 'Yorumlar yükleniyor';

  @override
  String get postViewEdit => 'Düzenle';

  @override
  String get postViewDelete => 'Sil';

  @override
  String get postViewReport => 'Şikâyet et';

  @override
  String get postViewReportComment => 'Yorumu şikâyet et';

  @override
  String get postViewDeleteCommentTitle => 'Yorum silinsin mi?';

  @override
  String get postViewCannotUndo => 'Bu işlem geri alınamaz.';

  @override
  String get postViewCancelAction => 'Vazgeç';

  @override
  String get postViewCommentDeleted => 'Bu yorum silindi';

  @override
  String get postViewEdited => 'düzenlendi';

  @override
  String postViewProfileOf(String name) {
    return '$name profili';
  }

  @override
  String get postViewSendFailedRetryA11y => 'Gönderilemedi, yeniden dene';

  @override
  String get postViewSendFailedRetry => 'Gönderilemedi · Yeniden dene';

  @override
  String get postViewRemove => 'Kaldır';

  @override
  String get postViewSending => 'Gönderiliyor…';

  @override
  String postViewReplyToA11y(String name) {
    return '$name kişisine yanıt ver';
  }

  @override
  String get postViewReply => 'Yanıtla';

  @override
  String get postViewCommentOptions => 'Yorum seçenekleri';

  @override
  String get postViewEditCommentHint => 'Yorumu düzenle';

  @override
  String get postViewCancel => 'İptal';

  @override
  String get postViewSave => 'Kaydet';

  @override
  String postViewLikersWithCount(String n) {
    return 'Beğenenler ($n)';
  }

  @override
  String get postViewLikers => 'Beğenenler';

  @override
  String get postViewRetry => 'Yeniden dene';

  @override
  String get postViewNoLikers => 'Henüz beğenen yok';

  @override
  String get postViewUser => 'Kullanıcı';

  @override
  String get postViewLikeFailed => 'Beğeni kaydedilemedi';

  @override
  String get postViewUnlike => 'Beğenmekten vazgeç';

  @override
  String get postViewLike => 'Beğen';

  @override
  String get postViewSavedAdded => 'Kaydedilenlere eklendi';

  @override
  String get postViewSavedRemoved => 'Kaydedilenlerden çıkarıldı';

  @override
  String get postViewUnsave => 'Kaydedilenlerden çıkar';

  @override
  String postViewNoTagPosts(String tag) {
    return '#$tag etiketli gönderi yok.';
  }

  @override
  String get postViewSavedPostsTitle => 'Kaydedilen gönderiler';

  @override
  String get postViewNoSavedPosts => 'Henüz kaydettiğin bir gönderi yok.';

  @override
  String get postViewPosts => 'Gönderiler';

  @override
  String get postViewSeeAll => 'Tümünü gör';

  @override
  String get postViewPost => 'Gönderi';

  @override
  String get postViewMyPosts => 'Gönderilerim';

  @override
  String get postViewNoPosts => 'Henüz gönderi yok';

  @override
  String get postViewReadMore => 'devamını oku';

  @override
  String get postViewReportSent => 'Şikâyetiniz iletildi.';

  @override
  String get postViewMore => 'Daha fazla';

  @override
  String get postViewFeedEmpty =>
      'Henüz gönderi yok. İlk gönderiyi sen paylaş!';

  @override
  String postViewCommentsWithCount(String n) {
    return 'Yorumlar ($n)';
  }

  @override
  String get postViewComments => 'Yorumlar';

  @override
  String get postViewSortNew => 'Yeni';

  @override
  String get postViewSortTop => 'Üst';

  @override
  String get postViewFirstComment => 'İlk yorumu sen yaz';

  @override
  String get profileDeptRequired => 'Bölümü seçin.';

  @override
  String get profileChangePhotoSemantic => 'Profil fotoğrafını değiştir';

  @override
  String get profileUploading => 'Yükleniyor…';

  @override
  String get profilePickGallery => 'Galeriden seç';

  @override
  String get profileTakePhoto => 'Fotoğraf çek';

  @override
  String get profileRemovePhoto => 'Fotoğrafı kaldır';

  @override
  String get profilePhotoTooLargeHint =>
      'Fotoğraf en fazla 2 MB olabilir. Daha küçük bir fotoğraf seçin.';

  @override
  String get profilePhotoUnsupported =>
      'Yalnızca JPG, PNG veya WebP fotoğraflar yüklenebilir.';

  @override
  String get profilePhotoUnreadable => 'Seçilen dosya okunamadı.';

  @override
  String get profilePhotoTooLarge => 'Fotoğraf en fazla 2 MB olabilir.';

  @override
  String get profileFullName => 'Ad soyad';

  @override
  String get profileEditNameSemantic => 'Ad soyadı düzenle';

  @override
  String get profileEditBioSemantic => 'Hakkımda alanını düzenle';

  @override
  String get profileEditDeptSemantic => 'Bölümü değiştir';

  @override
  String get profileEditGradeSemantic => 'Sınıfı değiştir';

  @override
  String get profileBioEmptyCta => 'Kendini tanıt';

  @override
  String get profileSavingSemantic => 'Kaydediliyor';

  @override
  String get profileNameMin => 'Ad en az 2 karakter olmalı.';

  @override
  String get profileAbout => 'Hakkımda';

  @override
  String get profileBioHint => 'Kendinizden kısaca bahsedin';

  @override
  String get profileMenuTitle => 'Menü';

  @override
  String get profileSave => 'Kaydet';

  @override
  String get profileUserDefault => 'Kullanıcı';

  @override
  String profileGradeYear(String year) {
    return '$year. sınıf';
  }

  @override
  String get profileBlockTitle => 'Kullanıcı engellensin mi?';

  @override
  String get profileBlockBody => 'Engellediğiniz kişiyle mesajlaşamazsınız.';

  @override
  String get profileCancel => 'Vazgeç';

  @override
  String get profileBlock => 'Engelle';

  @override
  String get profileUnblock => 'Engeli kaldır';

  @override
  String get profileUnblocked => 'Engel kaldırıldı';

  @override
  String get profileBlocked => 'Kullanıcı engellendi';

  @override
  String get profileReportUser => 'Kullanıcıyı şikâyet et';

  @override
  String get profileOnline => 'Çevrimiçi';

  @override
  String profileLastSeenToday(String time) {
    return 'Son görülme bugün $time';
  }

  @override
  String profileLastSeenYesterday(String time) {
    return 'Son görülme dün $time';
  }

  @override
  String profileLastSeenDate(String date, String time) {
    return 'Son görülme $date $time';
  }

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileNotFound => 'Kullanıcı bulunamadı';

  @override
  String get profileFaculty => 'Fakülte';

  @override
  String get profileDepartment => 'Bölüm';

  @override
  String get profileGrade => 'Sınıf';

  @override
  String get profileEmail => 'E-posta';

  @override
  String get profileMessage => 'Mesaj';

  @override
  String get profileReport => 'Şikâyet et';

  @override
  String get profileAboutShort => 'Hakkında';

  @override
  String get profileSignOutTitle => 'Çıkış yapılsın mı?';

  @override
  String get profileSignOutBody => 'Bu cihazdaki oturumunuz kapatılacak.';

  @override
  String get profileSignOut => 'Çıkış yap';

  @override
  String get profileSettings => 'Ayarlar';

  @override
  String get profileStatClubs => 'Kulüp';

  @override
  String get profileStatEvents => 'Etkinlik';

  @override
  String get profileStatSavedNews => 'Kayıtlı haber';

  @override
  String get profileMyPosts => 'Gönderilerim';

  @override
  String get profileSavedPosts => 'Kaydedilen gönderiler';

  @override
  String get profileSaved => 'Kayıtlı haberler';

  @override
  String get profileLiked => 'Beğendiklerim';

  @override
  String get likedAll => 'Tümü';

  @override
  String get likedEmpty => 'Henüz beğendiğin bir gönderi yok.';

  @override
  String get likedEmptyReels => 'Henüz beğendiğin bir Reels yok.';

  @override
  String get profileAcademic => 'Akademik';

  @override
  String get profileMyEvents => 'Etkinliklerim';

  @override
  String get profileMyClubs => 'Kulüplerim';

  @override
  String get profileReminders => 'Ders ve sınav hatırlatmaları';

  @override
  String get profileSavedEmpty =>
      'Henüz kaydettiğiniz bir haber yok. Haberlerdeki yer imi simgesine dokunun.';

  @override
  String get profileRetry => 'Yeniden dene';

  @override
  String profileNewsCount(String count) {
    return '$count haber';
  }

  @override
  String profileNewsCountMore(String count) {
    return '$count+ haber';
  }

  @override
  String get profileLegalTitle => 'Sözleşmeler';

  @override
  String get profileLegalEmpty => 'Yayımlanmış sözleşme yok.';

  @override
  String get profileLegalDocFallback => 'Sözleşme';

  @override
  String profileVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String profileVersionDate(String version, String date) {
    return 'Sürüm $version · $date';
  }

  @override
  String get profilePrefsDataCopied => 'Verileriniz panoya kopyalandı';

  @override
  String get profilePrefsExportLimit =>
      'Günde en fazla 3 kez veri indirebilirsiniz.';

  @override
  String get profilePrefsBlockedUsers => 'Engellenen kullanıcılar';

  @override
  String get profilePrefsLegalPrivacy => 'Sözleşmeler ve gizlilik';

  @override
  String get profilePrefsDownloadData => 'Verilerimi indir';

  @override
  String get profilePrefsAccountMgmt => 'Hesap yönetimi';

  @override
  String get profilePrefsDeleteMyAccount => 'Hesabımı sil';

  @override
  String get profilePrefsEnterPassword => 'Şifrenizi girin.';

  @override
  String get profilePrefsWrongPassword => 'Şifre hatalı.';

  @override
  String get profilePrefsDeleteAccountTitle => 'Hesabı sil';

  @override
  String get profilePrefsDeleteAccountBody =>
      'Hesabınız ve kişisel verileriniz silinecek. Bu işlem geri alınamaz. Onaylamak için şifrenizi girin.';

  @override
  String get profilePrefsPassword => 'Şifre';

  @override
  String get profilePrefsClubLeft => 'Kulüpten ayrıldın.';

  @override
  String get profilePrefsWithdrawTitle => 'İsteği geri çek';

  @override
  String get profilePrefsWithdrawBody => 'Katılma isteğiniz geri çekilsin mi?';

  @override
  String get profilePrefsWithdrawConfirm => 'Geri çek';

  @override
  String get profilePrefsNoClubs => 'Henüz bir kulübe üye değilsiniz.';

  @override
  String get profilePrefsClubsOwned => 'Kurduklarım';

  @override
  String get profilePrefsClubsMember => 'Üye olduklarım';

  @override
  String get profilePrefsClubsPending => 'Bekleyen başvurular';

  @override
  String get profilePrefsMyClubs => 'Kulüplerim';

  @override
  String get profilePrefsCreateClub => 'Kulüp kur';

  @override
  String profilePrefsMembersCount(String count) {
    return '$count üye';
  }

  @override
  String get profilePrefsAwaitingApproval => 'Onay bekliyor';

  @override
  String get profilePrefsAwaitingPublish => 'Yayın onayı bekleniyor';

  @override
  String get profilePrefsManage => 'Yönet';

  @override
  String get profilePrefsOptions => 'Seçenekler';

  @override
  String get profilePrefsOpen => 'Aç';

  @override
  String get profilePrefsManageEdit => 'Yönet: düzenle';

  @override
  String get profilePrefsManageRequests => 'Yönet: başvurular';

  @override
  String get profilePrefsManageMembers => 'Yönet: üyeler';

  @override
  String get profilePrefsLeaveClub => 'Kulüpten ayrıl';

  @override
  String get profilePrefsReminders => 'Ders ve sınav hatırlatmaları';

  @override
  String get profilePrefsNotifNews => 'Haberler';

  @override
  String get profilePrefsNotifAnnouncements => 'Duyurular';

  @override
  String get profilePrefsNotifEvents => 'Etkinlikler';

  @override
  String get profilePrefsNotifCommunities => 'Topluluklar';

  @override
  String get profilePrefsNotifMessages => 'Mesaj bildirimleri (push)';

  @override
  String get profilePrefsNotifPolls => 'Anketler';

  @override
  String get profilePrefsNotifStories => 'Hikâyeler';

  @override
  String get profilePrefsNotifMention => 'Etiketlenmeler';

  @override
  String get profilePrefsNotifFollow => 'Yeni takipçiler';

  @override
  String get profilePrefsNotifLike => 'Gönderi beğenileri';

  @override
  String get profilePrefsNotifComment => 'Gönderi yorumları';

  @override
  String get profilePrefsNotifReply => 'Yorum yanıtları';

  @override
  String get profilePrefsSocial => 'Sosyal';

  @override
  String get profilePrefsOnThisDevice => 'Bu cihazda';

  @override
  String profilePrefsTapToRetry(String error) {
    return '$error Yeniden denemek için dokunun.';
  }

  @override
  String get profilePrefsNotifTitle => 'Bildirimler';

  @override
  String get profilePrefsNoBlocked => 'Engellediğiniz kullanıcı yok.';

  @override
  String get profilePrefsUser => 'Kullanıcı';

  @override
  String get profilePrefsUnblock => 'Engeli kaldır';

  @override
  String get profilePrefsBlockedTitle => 'Engellenenler';

  @override
  String get pickDepartment => 'Bölüm';

  @override
  String get pickSelectDepartment => 'Bölüm seçin';

  @override
  String get pickLoading => 'Yükleniyor…';

  @override
  String get pickListFailed => 'Bölüm listesi yüklenemedi.';

  @override
  String get pickRetry => 'Yeniden dene';

  @override
  String get pickGrade => 'Sınıf';

  @override
  String get pickSelectGrade => 'Sınıf seçin';

  @override
  String get pickSearch => 'Ara';

  @override
  String get pickNoResults => 'Sonuç bulunamadı.';

  @override
  String get authSectionPersonal => 'Kişisel bilgiler';

  @override
  String get authHintPersonal => 'Adınızı ve e-posta adresinizi girin.';

  @override
  String get authNext => 'Devam';

  @override
  String get authTermsAutoPrefix => 'Kayıt olarak ';

  @override
  String get authTermsAutoSuffix => ' kabul etmiş sayılırsınız.';

  @override
  String get oaHeadline => 'Kampüsün burada.';

  @override
  String get oaSub => 'Paylaş, keşfet ve topluluğuna katıl.';

  @override
  String get oaContinueGoogle => 'Google ile devam et';

  @override
  String get oaContinueApple => 'Apple ile devam et';

  @override
  String get oaContinueEmail => 'E-posta ile devam et';

  @override
  String get oaOr => 'veya';

  @override
  String get oaLegalLead => 'Devam ederek şunları kabul etmiş olursun:';

  @override
  String get oaTermsLink => 'Kullanım Koşulları';

  @override
  String get oaPrivacyLink => 'Gizlilik Politikası';

  @override
  String get oaProviderGoogle => 'Google';

  @override
  String get oaProviderApple => 'Apple';

  @override
  String get oaLinkTitle => 'Bu e-posta ile zaten bir hesabın var';

  @override
  String oaLinkBody(String provider) {
    return 'Önce e-posta ve şifrenle giriş yap, sonra Hesap ve güvenlik bölümünden $provider hesabını bağla.';
  }

  @override
  String oaLinkMasked(String email) {
    return 'Hesap: $email';
  }

  @override
  String get oaErrFailed => 'Giriş tamamlanamadı. Lütfen tekrar dene.';

  @override
  String get oaErrTokenInvalid => 'Giriş doğrulanamadı. Lütfen tekrar dene.';

  @override
  String get oaErrEmailUnverified =>
      'Bu hesabın e-posta adresi sağlayıcıda doğrulanmamış. Önce adresi doğrula ya da e-posta ile devam et.';

  @override
  String get oaErrEmailMissing =>
      'Hesabından e-posta adresi alınamadı. E-posta ile devam edebilirsin.';

  @override
  String get oaErrDisabled =>
      'Bu giriş yöntemi şu an kullanılamıyor. E-posta ile devam edebilirsin.';

  @override
  String get oaErrLastMethod =>
      'Bu, hesabına giriş yapabildiğin tek yöntem. Kaldırmadan önce bir şifre belirlemelisin.';

  @override
  String get oaErrProfileIncomplete =>
      'Devam etmeden önce profilini tamamlamalısın.';

  @override
  String get oaOb1Title => 'Önce tanışalım.';

  @override
  String get oaOb1Sub => 'BÜKampüs profilini birkaç adımda oluşturalım.';

  @override
  String get oaFirstName => 'Ad';

  @override
  String get oaLastName => 'Soyad';

  @override
  String get oaFirstRequired => 'Adını yaz.';

  @override
  String get oaLastRequired => 'Soyadını yaz.';

  @override
  String get oaUsername => 'Kullanıcı adı';

  @override
  String get oaUserRule => '3-24 karakter; a-z, 0-9, nokta ve alt çizgi.';

  @override
  String get oaUserChecking => 'Kontrol ediliyor…';

  @override
  String get oaUserAvail => 'Kullanıcı adı müsait.';

  @override
  String get oaUserTaken => 'Bu kullanıcı adı alınmış.';

  @override
  String get oaUserInvalid =>
      'Kullanıcı adı 3-24 karakter olmalı; yalnız a-z, 0-9, nokta ve alt çizgi kullanılabilir.';

  @override
  String get oaUserReserved => 'Bu kullanıcı adı kullanılamaz.';

  @override
  String get oaUserRequired => 'Bir kullanıcı adı seç.';

  @override
  String get oaPhotoOptional => 'Profil fotoğrafı (isteğe bağlı)';

  @override
  String get oaPhotoAdd => 'Fotoğraf ekle';

  @override
  String get oaPhotoChange => 'Fotoğrafı değiştir';

  @override
  String oaStepOf(String a, String b) {
    return 'Adım $a / $b';
  }

  @override
  String get oaOb2Title => 'Kampüste neredesin?';

  @override
  String get oaOb2Sub => 'Bölümünü seç, sana uygun toplulukları keşfet.';

  @override
  String get oaUniversity => 'Üniversite';

  @override
  String get oaUniversityName => 'Bingöl Üniversitesi';

  @override
  String get oaFaculty => 'Fakülte';

  @override
  String get oaPickFaculty => 'Fakülte seç';

  @override
  String get oaPickFacultyFirst => 'Önce fakülteni seç';

  @override
  String get oaSelectFaculty => 'Fakültenizi seçin.';

  @override
  String get oaClassPostgrad => 'Lisansüstü';

  @override
  String get oaClassOther => 'Diğer';

  @override
  String get oaBio => 'Kısa biyografi (isteğe bağlı)';

  @override
  String get oaBioHint => 'Kendini birkaç kelimeyle anlat';

  @override
  String get oaDeclareNote =>
      'Seçtiğin bilgiler kendi beyanındır; profilinden istediğin zaman değiştirebilirsin.';

  @override
  String get oaJoin => 'BÜKampüs\'e katıl';

  @override
  String get oaLinkedTitle => 'Bağlı hesaplar';

  @override
  String get oaLinkedYes => 'Bağlı';

  @override
  String get oaLinkedNo => 'Bağlı değil';

  @override
  String get oaLinkAction => 'Bağla';

  @override
  String get oaUnlinkAction => 'Bağlantıyı kaldır';

  @override
  String get oaLinkPwTitle => 'Şifreni doğrula';

  @override
  String oaLinkPwBody(String provider) {
    return '$provider hesabını bağlamak için mevcut şifreni gir.';
  }

  @override
  String get oaPasswordLabel => 'Şifre';

  @override
  String oaLinkDone(String provider) {
    return '$provider hesabı bağlandı.';
  }

  @override
  String get oaUnlinkTitle => 'Bağlantı kaldırılsın mı?';

  @override
  String oaUnlinkBody(String provider) {
    return '$provider ile giriş kaldırılır; hesabına başka bir yöntemle girmen gerekir.';
  }

  @override
  String oaUnlinkDone(String provider) {
    return '$provider bağlantısı kaldırıldı.';
  }

  @override
  String get oaLinkedFailed => 'Bağlı hesaplar yüklenemedi.';

  @override
  String get authPwMinErr => 'Şifre en az 6 karakter olmalı.';

  @override
  String get authPwMaxErr => 'Şifre en çok 72 karakter olabilir.';

  @override
  String get authRegIdEmpty => 'E-posta adresinizi girin.';

  @override
  String get authRegIdFull => 'E-posta adresinizin tamamını yazın.';

  @override
  String get supportCatAccount => 'Hesap';

  @override
  String get supportCatTechnical => 'Teknik';

  @override
  String get supportCatContent => 'İçerik';

  @override
  String get supportCatOther => 'Diğer';

  @override
  String get supportFbBug => 'Hata';

  @override
  String get supportFbSuggestion => 'Öneri';

  @override
  String get supportFbComplaint => 'Şikâyet';

  @override
  String get supportFbPraise => 'Teşekkür';

  @override
  String get supportStNew => 'Yeni';

  @override
  String get supportStInReview => 'İnceleniyor';

  @override
  String get supportStPlanned => 'Planlandı';

  @override
  String get supportStDone => 'Tamamlandı';

  @override
  String get supportStRejected => 'Reddedildi';

  @override
  String get supportStatusAnswered => 'Yanıtlandı';

  @override
  String get supportStatusClosed => 'Kapalı';

  @override
  String get supportStatusOpen => 'Açık';

  @override
  String get supportTooManyRequests =>
      'Çok fazla istek gönderdiniz. Lütfen biraz bekleyip tekrar deneyin.';

  @override
  String get supportLabelCategory => 'KATEGORİ';

  @override
  String get supportLabelSubject => 'KONU';

  @override
  String get supportLabelMessage => 'MESAJ';

  @override
  String get supportLabelMine => 'GÖNDERDİKLERİM';

  @override
  String get supportHintSubject => 'Kısaca konu';

  @override
  String get supportHintFeedback => 'Görüşünüzü yazın';

  @override
  String get supportHintIssue => 'Sorununuzu anlatın';

  @override
  String get supportHintReply => 'Yanıt yazın';

  @override
  String get supportFillFields => 'Konu ve mesaj alanlarını doldurun.';

  @override
  String get supportFeedbackThanks => 'Geri bildiriminiz için teşekkürler.';

  @override
  String get supportFeedbackTitle => 'Geri bildirim';

  @override
  String get supportSend => 'Gönder';

  @override
  String get supportNoFeedback => 'Henüz geri bildirim göndermediniz.';

  @override
  String get supportMore => 'Daha fazla';

  @override
  String get supportTicketReceived => 'Destek talebiniz alındı.';

  @override
  String get supportNewTicketTitle => 'Yeni talep';

  @override
  String get supportTitle => 'Destek';

  @override
  String get supportFaqLabel => 'SIK SORULAN SORULAR';

  @override
  String get supportMyTickets => 'TALEPLERİM';

  @override
  String get supportShareLabel => 'GÖRÜŞÜNÜZÜ PAYLAŞIN';

  @override
  String get supportBoard => 'Öneri panosu';

  @override
  String get supportCreateTicket => 'Destek talebi oluştur';

  @override
  String get supportNoFaq => 'Henüz sık sorulan soru yok.';

  @override
  String get supportRetry => 'Yeniden dene';

  @override
  String get supportNoTickets => 'Henüz destek talebiniz yok.';

  @override
  String get supportSortTop => 'En çok oy';

  @override
  String get supportSortNew => 'En yeni';

  @override
  String get supportAddSuggestion => 'Öneri ekle';

  @override
  String get supportNoSuggestions =>
      'Henüz yayımlanmış öneri yok. İlk öneriyi siz ekleyin.';

  @override
  String get supportCloseTicketTitle => 'Talebi kapat';

  @override
  String get supportCloseTicketBody =>
      'Bu talep kapatılacak ve yeni yanıt yazamayacaksınız. Devam edilsin mi?';

  @override
  String get supportCancel => 'Vazgeç';

  @override
  String get supportClose => 'Kapat';

  @override
  String get supportTicketTitle => 'Talep';

  @override
  String get supportTicketClosedNote => 'Bu talep kapatıldı.';

  @override
  String get supportStaff => 'Destek ekibi';

  @override
  String get storyVideoTooLong => 'Hikâye videosu en fazla 30 saniye olabilir.';

  @override
  String get storyCreateTitle => 'Hikâye oluştur';

  @override
  String get storyShare => 'Paylaş';

  @override
  String get storyModeMedia => 'Fotoğraf / Video';

  @override
  String get storyModeText => 'Metin';

  @override
  String get storyVisible24 => 'Hikâyen 24 saat görünür';

  @override
  String get storyGallery => 'Galeri';

  @override
  String get storyCamera => 'Kamera';

  @override
  String get storyCaptionHint => 'Açıklama ekle…';

  @override
  String get storyTextHint => 'Bir şeyler yaz…';

  @override
  String storyBgColor(String n) {
    return 'Arka plan rengi $n';
  }

  @override
  String get storyYours => 'Hikâyen';

  @override
  String storyNewSemantics(String name) {
    return '$name, yeni hikâye';
  }

  @override
  String storySemantics(String name) {
    return '$name, hikâye';
  }

  @override
  String get storyDeleteTitle => 'Hikâye silinsin mi?';

  @override
  String get storyDeleteBody => 'Bu işlem geri alınamaz.';

  @override
  String get storyCancel => 'Vazgeç';

  @override
  String get storyDelete => 'Sil';

  @override
  String get storyRetry => 'Yeniden dene';

  @override
  String get storyClose => 'Kapat';

  @override
  String storyViewsSemantics(String count) {
    return '$count görüntülenme, izleyenleri göster';
  }

  @override
  String get storyDeleteTooltip => 'Hikâyeyi sil';

  @override
  String storyBarSemantics(String index, String total) {
    return 'Hikâye $index / $total';
  }

  @override
  String get storyNoViewers => 'Henüz kimse görüntülemedi.';

  @override
  String storyViewersTitle(String count) {
    return 'Görüntüleyenler ($count)';
  }

  @override
  String get authForgotSubNumber =>
      'E-posta adresinizi girin. 6 haneli kodu e-posta adresinize göndereceğiz.';

  @override
  String get authForgotSub =>
      'E-posta adresinizi girin, size 6 haneli bir kod gönderelim.';

  @override
  String get authBackToLogin => 'Girişe dön';

  @override
  String get realEmailTitle => 'Gerçek e-posta adresiniz';

  @override
  String get realEmailSubtitle =>
      'Gizli Apple adresiniz bildirimleri ve şifre sıfırlama e-postalarını alamaz. Aktif olarak kullandığınız e-posta adresinizi girin; hesabınızın tek e-postası bu olacak.';

  @override
  String get realEmailSoftNote =>
      'Bu adım zorunlu değil ama şifre sıfırlama ve bildirimler için önerilir.';

  @override
  String get realEmailSendCode => 'Kod gönder';

  @override
  String get realEmailLater => 'Şimdi değil';

  @override
  String get realEmailCodeTitle => 'Kodu girin';

  @override
  String get realEmailNoCodeHint =>
      'Kod gelmediyse spam klasörüne bakın. Adres başka bir hesapta kayıtlıysa doğrulama tamamlanamaz; o hesapla giriş yapın ya da başka bir adres deneyin.';

  @override
  String get realEmailDoneTitle => 'E-postanız güncellendi';

  @override
  String realEmailDoneBody(String email) {
    return 'Hesabınızın e-postası artık $email. Bildirimler ve şifre sıfırlama bu adrese gelecek.';
  }

  @override
  String get realEmailContinue => 'Devam et';

  @override
  String get realEmailErrRelay =>
      'Gizli (geçici) bir adres kullanılamaz. Aktif olarak kullandığınız gerçek e-posta adresinizi yazın.';

  @override
  String get realEmailErrUnavailable =>
      'Bu e-posta adresi kullanılamıyor. Başka bir adres deneyin ya da bu adresle açılmış hesaba giriş yapın.';

  @override
  String get realEmailErrUnchanged =>
      'Bu adres zaten hesabınızın e-posta adresi.';

  @override
  String get realEmailErrRequired =>
      'Devam etmeden önce gerçek ve aktif e-posta adresinizi ekleyip doğrulayın.';

  @override
  String get authChangeEmail => 'E-postayı değiştir';

  @override
  String get authNewPwSub =>
      'Bu şifre eski şifrenizin yerine geçer. Tüm cihazlardaki oturumlar kapanır.';

  @override
  String get welcomeHeadline => 'Kampüs artık\ncebinizde';

  @override
  String get welcomeSub =>
      'Duyurular, yemek listesi, kulüpler ve etkinlikler tek uygulamada.';

  @override
  String get welcomeNews => 'Haberler ve duyurular';

  @override
  String get welcomeMenu => 'Günün yemek listesi';

  @override
  String get welcomeClubs => 'Kulüpler ve etkinlikler';

  @override
  String get welcomeNote =>
      'Gmail, Outlook, Hotmail, Yahoo ve diğer e-posta adresleriyle kayıt olabilirsiniz.';

  @override
  String get welcomeLanguage => 'Dil';

  @override
  String get chatlistSearchHint => 'Sohbetlerde ara';

  @override
  String get bildirimFilterAll => 'Tümü';

  @override
  String get bildirimFilterUnread => 'Okunmamış';

  @override
  String get bildirimEmptyUnread => 'Okunmamış bildiriminiz yok.';

  @override
  String get bildirimAllCaughtUp => 'Hepsi bu kadar';

  @override
  String get bildirimSwipeHint => 'Silmek için bildirimi sola kaydır';

  @override
  String get bildirimDelete => 'Sil';

  @override
  String bildirimShortMin(String n) {
    return '$n dk';
  }

  @override
  String bildirimShortHour(String n) {
    return '$n sa';
  }

  @override
  String bildirimShortDay(String n) {
    return '$n g';
  }

  @override
  String get bildirimYesterday => 'Dün';

  @override
  String get bildirimTypeNews => 'Haber';

  @override
  String get bildirimTypeAnnouncement => 'Duyuru';

  @override
  String get bildirimTypeEvent => 'Etkinlik';

  @override
  String get bildirimTypeCommunity => 'Kulüp';

  @override
  String get bildirimTypePoll => 'Anket';

  @override
  String get bildirimTypePost => 'Gönderi';

  @override
  String get bildirimTypeOther => 'Bildirim';

  @override
  String get acadhubNextExam => 'Sıradaki sınav';

  @override
  String get acadhubUpcoming => 'Yaklaşan tarihler';

  @override
  String get acadhubCalendarLink => 'Takvim';

  @override
  String get acadhubNoUpcoming => 'Yaklaşan tarih yok';

  @override
  String get kuluplerAllClubs => 'Tüm kulüpler';

  @override
  String get kesfetSubtitle => 'Öğrencilerden gönderiler';

  @override
  String get kesfetSearchHint => 'Gönderi veya kişi ara';

  @override
  String get kesSegPosts => 'Gönderiler';

  @override
  String get kesSegReels => 'Reels';

  @override
  String get kesPickVideo => 'Video seç';

  @override
  String get kesRecordVideo => 'Video çek';

  @override
  String get kesVideoLimits => 'Video en fazla 60 saniye ve 50 MB olabilir.';

  @override
  String kesVideoPreparing(String pct) {
    return 'Video hazırlanıyor… $pct';
  }

  @override
  String kesVideoUploading(String pct) {
    return 'Video yükleniyor… $pct';
  }

  @override
  String get kesVideoChange => 'Videoyu değiştir';

  @override
  String get kesErrVideoTooLarge => 'Video çok büyük (en fazla 50 MB).';

  @override
  String get kesFullscreen => 'Tam ekran izle';

  @override
  String get kesReelsEmptyTitle => 'Henüz reel yok';

  @override
  String get kesReelsEmptyBody => 'İlk videoyu sen paylaş.';

  @override
  String get kesReelsDoneTitle => 'Şimdilik tüm videoları gördün';

  @override
  String get kesReelsDoneBody => 'Yeni videolar geldikçe burada olacak.';

  @override
  String get kesReelsReplay => 'Tekrar izle';

  @override
  String get kesReelsToPosts => 'Keşfet gönderilerine bak';

  @override
  String get kesActionComments => 'Yorumlar';

  @override
  String get kesActionSave => 'Kaydet';

  @override
  String get kesActionSaved => 'Kaydedildi';

  @override
  String get kesNotInterested => 'İlgilenmiyorum';

  @override
  String get kesNotInterestedDone => 'Bu video artık önerilmeyecek.';

  @override
  String get kesMore => 'Diğer işlemler';

  @override
  String kesViews(String count) {
    return '$count izlenme';
  }

  @override
  String get kesCoverTitle => 'Kapak karesi';

  @override
  String get kesCoverHint => 'Videodan bir kare seç.';

  @override
  String get kesComposeMenuPhoto => 'Fotoğraf paylaş';

  @override
  String get kesComposeMenuVideo => 'Video / Reels paylaş';

  @override
  String get kesCommentsTitle => 'Yorumlar';

  @override
  String get kesCommentsEmpty => 'Henüz yorum yok.';

  @override
  String get kesCommentsWrite => 'Yorum yaz…';

  @override
  String get kesCommentsSend => 'Gönder';

  @override
  String get kesCommentsReply => 'Yanıtla';

  @override
  String kesCommentsReplyingTo(String name) {
    return '$name kişisine yanıt';
  }

  @override
  String kesCommentsMoreReplies(String count) {
    return '$count yanıtı gör';
  }

  @override
  String get kesCommentsLoadFailed => 'Yorumlar yüklenemedi.';

  @override
  String get kesCommentsDelete => 'Yorumu sil';

  @override
  String get kesAvatarPreview => 'Profil fotoğrafı';

  @override
  String get kesCommentsSortTop => 'En iyi';

  @override
  String get kesCommentsSortNew => 'Yeni';

  @override
  String get kesCommentsAuthorBadge => 'Yazar';

  @override
  String get profil2PrivacyTitle => 'Gizlilik ve engellenenler';

  @override
  String get profil2PrivacyIntro =>
      'Profilini kimlerin görebileceğini alan alan seç. Kendi profilini her zaman tam görürsün.';

  @override
  String get profil2VisibilitySection => 'Profil görünürlüğü';

  @override
  String get profil2FieldAvatar => 'Profil fotoğrafı';

  @override
  String get profil2FieldBio => 'Hakkımda';

  @override
  String get profil2FieldFaculty => 'Fakülte';

  @override
  String get profil2FieldDepartment => 'Bölüm';

  @override
  String get profil2FieldClassYear => 'Sınıf';

  @override
  String get profil2VisEveryone => 'Herkes';

  @override
  String get profil2VisShared => 'Tanıdıklarım';

  @override
  String get profil2VisOnlyMe => 'Yalnızca ben';

  @override
  String get profil2SharedHintLead => 'Tanıdıklarım:';

  @override
  String get profil2SharedHintBody =>
      'seninle aynı kulüpte, sohbette veya etkinlikte olan kişiler.';

  @override
  String get profil2ShowEmail => 'E-postamı diğer kullanıcılara göster';

  @override
  String get profil2ShowEmailSub => 'Kapalıyken yalnızca sen görürsün';

  @override
  String get profil2BlockedSection => 'Engellenenler';

  @override
  String get profil2BlockedHint =>
      'Engellediğin kişiler seni göremez, sana yazamaz.';

  @override
  String get profil2AvatarModerated =>
      'Profil fotoğrafın moderasyon nedeniyle gizlendi.';

  @override
  String get profil2SaveFailed => 'Değişiklik kaydedilemedi.';

  @override
  String get profil2MyDataRow => 'Verilerim ve hesap';

  @override
  String get profil2DataTitle => 'Verilerim';

  @override
  String get profil2DataIntro =>
      'KVKK kapsamında uygulamada sakladığımız kişisel verilerinin bir kopyasını indirebilirsin.';

  @override
  String get profil2DataFileSub => 'JSON dosyası olarak hazırlanır';

  @override
  String get profil2DataContents => 'Dosyada neler var';

  @override
  String get profil2DataItemProfile => 'Profil bilgilerin';

  @override
  String get profil2DataItemPrefs => 'Gizlilik ve bildirim tercihlerin';

  @override
  String get profil2DataItemClubs => 'Kulüp ve etkinlik kayıtların';

  @override
  String get profil2DataItemSaved => 'Kayıtlı haberler ve bildirimlerin';

  @override
  String get profil2DataItemSupport => 'Destek ve geri bildirim kayıtların';

  @override
  String get profil2DataLimit =>
      'Günde en fazla 3 kez indirebilirsin. Dosyayı güvenli sakla, içinde kişisel bilgiler var.';

  @override
  String get profil2DataOther => 'Diğer';

  @override
  String get profil2DataKvkk => 'KVKK aydınlatma metni';

  @override
  String get profil2DelWarnLead => 'Bu işlem geri alınamaz.';

  @override
  String get profil2DelWarnBody =>
      'Hesabın anonimleştirilir ve bir daha giriş yapamazsın.';

  @override
  String get profil2DelWhatHappens => 'Neler olur';

  @override
  String get profil2DelItem1 =>
      'Adın, e-postan, fotoğrafın ve profil bilgilerin silinir. Hesap Silinmiş kullanıcı olarak kalır.';

  @override
  String get profil2DelItem2 =>
      'Bildirimlerin, kayıtlı haberlerin, cihaz kayıtların ve tercihlerin silinir.';

  @override
  String get profil2DelItem3 =>
      'Kulüp üyeliklerin ve etkinlik katılımların kaldırılır.';

  @override
  String get profil2DelItem4 => 'Tüm cihazlardaki oturumların kapanır.';

  @override
  String get profil2DelBackupHint =>
      'Dilersen silmeden önce verilerini indirebilirsin.';

  @override
  String get profil2DelAck =>
      'Hesabımın kalıcı olarak silineceğini ve geri alınamayacağını anladım.';

  @override
  String get profil2Continue => 'Devam et';

  @override
  String get profil2DelConfirmTitle => 'Silmeyi onayla';

  @override
  String get profil2DelConfirmBody =>
      'Devam etmek için şifreni gir. Hesabın hemen anonimleştirilir ve tüm cihazlardan çıkış yapılır.';

  @override
  String get profil2SecTitle => 'Hesap ve güvenlik';

  @override
  String get profil2SecEmailFixed => 'Değiştirilemez';

  @override
  String get profil2SecVerified => 'Doğrulandı';

  @override
  String get profil2SecPwSection => 'Şifreyi güncelle';

  @override
  String get profil2SecCurrentLabel => 'Mevcut şifre';

  @override
  String get profil2SecCurrentHint => 'Mevcut şifreniz';

  @override
  String get profil2SecNewLabel => 'Yeni şifre';

  @override
  String get profil2SecNewHint => 'En az 6 karakter';

  @override
  String get profil2SecRepeatLabel => 'Yeni şifre (tekrar)';

  @override
  String get profil2SecRepeatHint => 'Yeni şifreyi tekrarlayın';

  @override
  String get profil2SecPwRule =>
      'En az 6 karakter. Harf ve rakam karıştırırsanız güçlenir.';

  @override
  String get profil2SecPwButton => 'Şifreyi güncelle';

  @override
  String get profil2SecMismatch => 'Şifreler eşleşmiyor.';

  @override
  String get profil2SecSame => 'Yeni şifre mevcut şifreyle aynı olamaz.';

  @override
  String get profil2SecWrongCurrent => 'Mevcut şifre hatalı.';

  @override
  String get profil2SecFailed =>
      'Şifre güncellenemedi. Lütfen daha sonra tekrar deneyin.';

  @override
  String get profil2SecUpdated => 'Şifren güncellendi.';

  @override
  String get profil2SecSessions => 'Oturumlar';

  @override
  String get profil1SecContent => 'İçeriğim';

  @override
  String get profil1SecAccount => 'Hesap';

  @override
  String get profil1SecApp => 'Uygulama';

  @override
  String get profil1SecSupport => 'Destek ve hukuki';

  @override
  String get profil1AccountSecurity => 'Hesap ve güvenlik';

  @override
  String get profil1PrivacyBlocked => 'Gizlilik ve engellenenler';

  @override
  String get profil1MyData => 'Verilerim';

  @override
  String get profil1Notifications => 'Bildirim tercihleri';

  @override
  String get profil1Theme => 'Tema';

  @override
  String get profil1Support => 'Yardım ve destek';

  @override
  String get profil1Legal => 'Sözleşmeler ve politikalar';

  @override
  String get profil1Remove => 'Kaldır';

  @override
  String get profil1PushTitle => 'Anlık bildirimler';

  @override
  String get profil1PushGranted => 'Bu cihazda izin verildi';

  @override
  String get profil1PillOff => 'Kapalı';

  @override
  String get profil1WhatSection => 'Neler bildirilsin';

  @override
  String get profil1NotifClubs => 'Kulüpler';

  @override
  String get profil1NewsSub => 'Üniversiteden yeni haberler';

  @override
  String get profil1AnnSub => 'Önemli duyurular';

  @override
  String get profil1EventsSub => 'Hatırlatma, değişiklik, kabul';

  @override
  String get profil1MsgSub => 'Kişi ve grup sohbetleri';

  @override
  String get profil1ClubsSub => 'Gönderiler, rol ve katılım';

  @override
  String get profil1Detailed => 'Ayrıntılı tercihler';

  @override
  String get profil1SubMsgDirect => 'Kişisel mesajlar';

  @override
  String get profil1SubMsgGroup => 'Grup mesajları';

  @override
  String get profil1SubEventReminder => 'Etkinlik hatırlatmaları';

  @override
  String get profil1SubEventUpdate => 'Etkinlik değişiklikleri';

  @override
  String get profil1SubEventAdmission => 'Etkinlik kabulleri';

  @override
  String get profil1SubClubPost => 'Kulüp gönderileri';

  @override
  String get profil1SubClubRole => 'Kulüp rol değişiklikleri';

  @override
  String get profil1SubClubJoin => 'Kulüp katılım istekleri';

  @override
  String get profil1QuietTitle => 'Sessiz saatler';

  @override
  String get profil1QuietToggle => 'Sessiz saatleri aç';

  @override
  String get profil1QuietSub => 'Bu saatlerde bildirim sesi çalmaz';

  @override
  String get profil1QuietStart => 'Başlangıç';

  @override
  String get profil1QuietEnd => 'Bitiş';

  @override
  String get sohbetmedyaNext => 'İleri';

  @override
  String sohbetmedyaSelectedOf(String n, String max) {
    return '$n / $max seçildi';
  }

  @override
  String get sohbetmedyaRecent => 'Son eklenenler';

  @override
  String get sohbetmedyaPhotoVideo => 'Fotoğraf ve video';

  @override
  String sohbetmedyaLimitNote(String max) {
    return 'En fazla $max öğe seçebilirsiniz. Video en fazla 60 saniye olabilir.';
  }

  @override
  String get sohbetmedyaAddMore => 'Daha fazla ekle';

  @override
  String sohbetmedyaSendItems(String n) {
    return '$n öğeyi gönder';
  }

  @override
  String get chatdSendingMedia => 'Gönderiliyor…';

  @override
  String get chatdPhotoLoading => 'Fotoğraf yükleniyor…';

  @override
  String get chatdOnceLocked => 'Tek gösterimlik fotoğraf';

  @override
  String get chatdOnceView => 'Görüntüle';

  @override
  String get chatdOnceOpenedFull => 'Fotoğraf · Açıldı';

  @override
  String anasayfaHello(String name) {
    return 'Merhaba, $name';
  }

  @override
  String get anasayfaHelloNoName => 'Merhaba';

  @override
  String get anasayfaMealLunch => 'Bugünün yemeği · Öğle';

  @override
  String get anasayfaAnnouncements => 'Duyurular';

  @override
  String get anasayfaQuickAcademic => 'Akademik';

  @override
  String get gonderiTextHint => 'Bir şeyler yaz…';

  @override
  String gonderiWordCount(String n, String max) {
    return '$n/$max kelime';
  }

  @override
  String gonderiWordLimit(String max) {
    return 'En çok $max kelime yazabilirsin.';
  }

  @override
  String get composeTrimTitle => 'Videoyu kırp';

  @override
  String get composeTrimDone => 'Bitti';

  @override
  String get composeTrimEdit => 'Düzenle';

  @override
  String get composeTrimCta => 'Videoyu kırp';

  @override
  String get composeTrimming => 'Video kırpılıyor…';

  @override
  String composeTrimSelected(String dur) {
    return 'Seçilen süre $dur';
  }

  @override
  String composeTrimHint(String max) {
    return 'Tutamaçları sürükleyerek bir bölüm seç. En çok $max.';
  }

  @override
  String composeTrimTooLong(String max) {
    return 'Video çok uzun. Paylaşmak için en çok $max uzunluğunda bir bölüm seç.';
  }

  @override
  String get composeTrimStart => 'Başlangıç';

  @override
  String get composeTrimEnd => 'Bitiş';

  @override
  String get composeTrimPlay => 'Oynat';

  @override
  String get composeTrimPause => 'Duraklat';

  @override
  String get composeTooLongTitle => 'Video çok uzun';

  @override
  String composeTooLongBody(String dur, String max) {
    return 'Bu video $dur uzunluğunda. En çok $max paylaşabilirsin, bu yüzden önce kırpman gerekiyor.';
  }

  @override
  String get composeTooLongOther => 'Başka video seç';

  @override
  String composeVideoLimitsHint(String n) {
    return 'Video en fazla $n saniye; uzunsa kırpabilirsin.';
  }

  @override
  String get composeTagPerson => 'Kişi etiketle';

  @override
  String composeTagRemove(String name) {
    return '$name etiketini kaldır';
  }

  @override
  String get composeMentionSearch => 'Takip ettiklerinde ara';

  @override
  String get composeMentionEmpty => 'Etiketlemek için kişileri takip et';

  @override
  String get composeMentionNoMatch => 'Eşleşen kişi yok';

  @override
  String composeMentionMax(String max) {
    return 'En çok $max kişi etiketleyebilirsin.';
  }

  @override
  String get composeMentionDone => 'Tamam';

  @override
  String postMentionOpen(String name) {
    return '$name profilini aç';
  }

  @override
  String get postComposeErrTextTooLong =>
      'Gönderi metni çok uzun. Biraz kısaltıp tekrar dene.';

  @override
  String get gonderiPickPhoto => 'Fotoğraf seç';

  @override
  String get gonderiTakePhoto => 'Fotoğraf çek';

  @override
  String get gonderiPhotoRequired => 'Paylaşmak için bir fotoğraf seç.';

  @override
  String get gonderiPhotoHint => 'Gönderi tek bir fotoğraftan oluşur.';

  @override
  String get gonderiChangePhoto => 'Fotoğrafı değiştir';

  @override
  String get gonderiDiscardTitle => 'Gönderiden vazgeçilsin mi?';

  @override
  String get gonderiDiscardBody =>
      'Seçtiğin fotoğraf ve yazdıkların silinecek.';

  @override
  String get gonderiDiscardYes => 'Vazgeç';

  @override
  String get yemekLunch => 'Öğle yemeği';

  @override
  String get yemekTodaysMenu => 'Bugünün menüsü';

  @override
  String get yemekToday => 'Bugün';

  @override
  String get yemekPrevDay => 'Önceki gün';

  @override
  String get yemekNextDay => 'Sonraki gün';

  @override
  String get destekFaqHeading => 'Sıkça sorulan sorular';

  @override
  String get destekFaqSearchHint => 'Sorunuzu arayın';

  @override
  String get destekFaqAll => 'Tümü';

  @override
  String get destekFaqNoMatch => 'Eşleşen soru bulunamadı.';

  @override
  String get destekSortMine => 'Benim';

  @override
  String get destekSortPopular => 'Popüler';

  @override
  String get destekShareSuggestion => 'Öneri paylaş';

  @override
  String destekEffective(String date) {
    return 'Yürürlük: $date';
  }

  @override
  String destekVoteLabel(String count) {
    return 'Oy ver, şu an $count oy';
  }

  @override
  String get anketScopeGlobal => 'Genel';

  @override
  String get anketScopeClub => 'Kulüp';

  @override
  String get anketScopeMenu => 'Yemek';

  @override
  String get anketSecretNote =>
      'Oyunuz gizli. Seçiminizi yalnızca siz görürsünüz; yöneticiler dahil kimse kimin ne seçtiğini göremez.';

  @override
  String get anketSecretVoteNote =>
      'Oyunuz gizli kalır, kimse kimin ne seçtiğini göremez.';

  @override
  String get anketMineBadge => 'Seçiminiz';

  @override
  String get anketRatingSummary => 'Puanlama özeti';

  @override
  String get anketResultsTitle => 'Sonuçlar';

  @override
  String get anketFieldQuestion => 'Soru';

  @override
  String get anketVisTitle => 'Sonuçlar ne zaman görünsün?';

  @override
  String get anketVisAlways => 'Her zaman';

  @override
  String get anketVisAfterVote => 'Oy verince';

  @override
  String get anketVisAfterClose => 'Anket kapanınca';

  @override
  String get anketNotifyTitle => 'Bildirim gönder';

  @override
  String get anketNotifySub => 'Hedef kitleye anket açıldı bildirimi';

  @override
  String get icerikHidden => 'Gizli';

  @override
  String get icerikStatPosts => 'Gönderi';

  @override
  String get icerikStatFollowers => 'Takipçi';

  @override
  String get icerikStatFollowing => 'Takip';

  @override
  String get icerikMessageSend => 'Mesaj gönder';

  @override
  String get icerikReport => 'Raporla';

  @override
  String get icerikMoreActions => 'Diğer işlemler';

  @override
  String get icerikUserMenu => 'Kullanıcı işlemleri';

  @override
  String get icerikPostsHeading => 'GÖNDERİLER';

  @override
  String get icerikOpenPost => 'Gönderiyi aç';

  @override
  String get icerikPostPhoto => 'Gönderi fotoğrafı';

  @override
  String get icerikNewsTitle => 'Haberler';

  @override
  String get icerikNewsTypeTabs => 'Tür';

  @override
  String get icerikNewsList => 'Haber listesi';

  @override
  String get icerikNewsEmpty => 'Bu kategoride henüz içerik yok.';

  @override
  String get icerikFavorites => 'Favori haberler';

  @override
  String get icerikMaintenance =>
      'Haber kaynağına şu an ulaşılamıyor. Son kaydedilen haberler gösteriliyor.';

  @override
  String get icerikOpenSource => 'Kaynak sitede aç';

  @override
  String get icerikShare => 'Paylaş';

  @override
  String get icerikLinkCopied => 'Haber bağlantısı kopyalandı.';

  @override
  String icerikSavedCount(String count) {
    return '$count kayıtlı haber';
  }

  @override
  String get icerikSavedMoreTitle => 'Daha fazla haberi kaydet';

  @override
  String get icerikSavedMoreBody =>
      'Haber detayındaki işaretle haberleri buraya ekleyebilirsin.';

  @override
  String get icerikSavedList => 'Favoriler';

  @override
  String get icerikSearchTabs => 'Sonuç türü';

  @override
  String get icerikGroupNews => 'HABER';

  @override
  String get icerikGroupAnnouncement => 'DUYURU';

  @override
  String get icerikGroupEvent => 'ETKİNLİK';

  @override
  String get icerikGroupClub => 'KULÜP';

  @override
  String get icerikGroupPerson => 'KİŞİ';

  @override
  String get icerikGroupPost => 'GÖNDERİ';

  @override
  String get kulupdetayRequestsTitle => 'Katılma istekleri';

  @override
  String kulupdetayPendingBanner(String count) {
    return '$count bekleyen katılma isteği';
  }

  @override
  String get kulupdetaySendRequest => 'İsteği gönder';

  @override
  String get kulupdetayAnswerHint => 'Cevabını yaz';

  @override
  String get kulupdetayRequired => 'Bu soru zorunlu.';

  @override
  String get kulupdetayApproving => 'Onaylanıyor...';

  @override
  String get kulupdetayCreateTitle => 'Kulüp oluştur';

  @override
  String kulupdetayMembersSubtitle(String club, String count) {
    return '$club · $count üye';
  }

  @override
  String akademik2DayHeadingToday(String day) {
    return '$day, bugün';
  }

  @override
  String akademik2CourseCount(String count) {
    return '$count ders';
  }

  @override
  String get akademik2ExportLabel => 'Takvime aktar';

  @override
  String get akademik2CourseHours => 'Ders saati';

  @override
  String get akademik2Instructor => 'Öğretim elemanı';

  @override
  String get akademik2Start => 'Başlangıç';

  @override
  String get akademik2End => 'Bitiş';

  @override
  String get akademik2EndOptional => 'Bitiş (isteğe bağlı)';

  @override
  String get akademik2RoomShort => 'Sınıf';

  @override
  String get akademik2AddDay => 'Başka gün ekle';

  @override
  String get akademik2OfficialTag => 'Resmi';

  @override
  String get akademik2Passed => 'Geçti';

  @override
  String get akademik2ExamTitle => 'Sınav başlığı';

  @override
  String get akademik2Course => 'Ders';

  @override
  String get akademik2Place => 'Yer';

  @override
  String get akademik2NewTag => 'Yeni';

  @override
  String get akademik2Attachment => 'Ek dosya';

  @override
  String get akademik2RemindEach => 'Her ders öncesinde';

  @override
  String get akademik2BeforeClassShort => 'Dersten önce';

  @override
  String get akademik2SemesterTitle => 'Dönem seç';

  @override
  String sistemuiPermStep(String current, String total) {
    return 'Adım $current / $total';
  }

  @override
  String get sistemuiPermNotifText =>
      'Mesaj, etkinlik ve duyurulardan anında haberdar olmak için.';

  @override
  String get sistemuiPermCameraTitle => 'Kamera ve galeri';

  @override
  String get sistemuiPermCameraText =>
      'QR kod okutmak, fotoğraf çekmek ve paylaşmak için.';

  @override
  String get sistemuiOfflineTitle => 'Bağlantı yok';

  @override
  String get sistemuiOfflineBody =>
      'İnternet bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get sistemuiErrorTitle => 'Bir şeyler ters gitti';

  @override
  String get sistemuiMaintTitle => 'Sistem bakımda';

  @override
  String get sistemuiMaintBody =>
      'Kısa süre sonra tekrar deneyin. Verileriniz güvende.';

  @override
  String get sistemuiMaintBand =>
      'Bazı özellikler geçici olarak kullanılamayabilir.';

  @override
  String sistemuiUpdateVersions(String current, String required) {
    return 'Yüklü sürüm $current · Gerekli sürüm $required';
  }

  @override
  String get sistemuiBlockedCode => 'Hata kodu: ACCESS_BLOCKED';

  @override
  String get sistemuiQrHint => 'QR kodunu çerçevenin içine getir';

  @override
  String get sistemuiQrNotice =>
      'Yoklama etkinlik saatinde açılır. Organizatörün gösterdiği kodu okut.';

  @override
  String get sistemuiQrOr => 'veya';

  @override
  String get sistemuiQrManualHint => 'Örn. K7M4QX';

  @override
  String get sistemuiQrSubmit => 'Yoklamayı gönder';

  @override
  String get profilyardBlockedNote =>
      'Engellediğin kişiler profilini göremez, sana mesaj yazamaz ve seni takip edemez.';

  @override
  String get profilyardBlockedEmptyTitle => 'Kimseyi engellemedin';

  @override
  String get profilyardBlockedEmptyBody =>
      'Rahatsız edici bir kullanıcıyı profilinden engelleyebilirsin.';

  @override
  String profilyardUnblockOf(String name) {
    return '$name engelini kaldır';
  }

  @override
  String get profilyardClubsManaged => 'Yönettiklerim';

  @override
  String get profilyardClubsMember => 'Üyesi olduklarım';

  @override
  String get profilyardClubsPending => 'Bekleyen istekler';

  @override
  String get profilyardRoleOwner => 'Başkan';

  @override
  String get profilyardRoleFounder => 'Kurucu';

  @override
  String get profilyardRoleAdmin => 'Yönetici';

  @override
  String get profilyardRoleModerator => 'Moderatör';

  @override
  String get profilyardRoleMember => 'Üye';

  @override
  String get profilyardClubsEmptyTitle => 'Henüz bir kulübe katılmadın.';

  @override
  String get profilyardClubsEmptyBody =>
      'Kulüpleri keşfedip katılabilir ya da kendi kulübünü kurabilirsin.';

  @override
  String get profilyardClubsDiscover => 'Kulüpleri keşfet';

  @override
  String get profilyardEventsAttended => 'Katıldıklarım';

  @override
  String get profilyardEventsCreated => 'Oluşturduklarım';

  @override
  String get profilyardEventsUpcoming => 'Yaklaşan';

  @override
  String get profilyardEventsPast => 'Geçmiş';

  @override
  String get profilyardEventGoing => 'Katılıyorum';

  @override
  String get profilyardEventRequested => 'İstek gönderildi';

  @override
  String get profilyardEventInterested => 'İlgileniyorum';

  @override
  String profilyardEventPendingCount(String count) {
    return '$count bekleyen istek';
  }

  @override
  String get profilyardEventsEmptyTitle =>
      'Henüz katılacağın bir etkinlik yok.';

  @override
  String get profilyardEventsEmptyBody =>
      'Etkinliklere göz at ya da kendi etkinliğini oluştur.';

  @override
  String profilyardFollowersTab(String count) {
    return 'Takipçiler $count';
  }

  @override
  String profilyardFollowingTab(String count) {
    return 'Takip edilenler $count';
  }

  @override
  String get profilyardFollowersSearch => 'Takipçilerde ara';

  @override
  String get profilyardFollowingSearch => 'Takip edilenlerde ara';

  @override
  String get profilyardFollowMutual => 'Takipleşiyorsunuz';

  @override
  String get profilyardFollowsYou => 'Seni takip ediyor';

  @override
  String get profilyardFollowingYou => 'Takiptesin';

  @override
  String get profilyardFollowNoMatch => 'Eşleşen kişi yok.';

  @override
  String get profilyardFbIntro =>
      'Uygulamayı geliştirmemize yardım et. Önerini, karşılaştığın hatayı ya da düşüncelerini yaz.';

  @override
  String get profilyardFbType => 'Tür';

  @override
  String get profilyardFbTitle => 'Başlık';

  @override
  String get profilyardFbMessage => 'Mesaj';

  @override
  String get profilyardFbTitleHint => 'Kısaca özetle';

  @override
  String get profilyardFbMessageHint => 'Ayrıntıları yaz';

  @override
  String profilyardFbCounter(String n, String max) {
    return '$n / $max';
  }

  @override
  String get sohbetyAddMember => 'Üye ekle';

  @override
  String sohbetyAddCount(String n) {
    return 'Ekle ($n)';
  }

  @override
  String get sohbetyProfile => 'Profil';

  @override
  String get sohbetyNewGroup => 'Yeni grup';

  @override
  String get sohbetyNewGroupSub => 'En fazla 50 kişi';

  @override
  String get sohbetyGroupMin => 'Grup için en az 2 kişi seçin.';

  @override
  String get sohbetyTypePerson => 'Kişi';

  @override
  String get sohbetyFlash => 'Flaş';

  @override
  String get sohbetyStopRec => 'Kaydı durdur';

  @override
  String get sohbetyTakePhoto => 'Fotoğraf çek';

  @override
  String get sohbetyAddDone => 'Üyeler eklendi';

  @override
  String get etkinlik2PolicyOpen => 'Herkes katılabilir';

  @override
  String get etkinlik2PolicyApproval => 'İstek ile';

  @override
  String get etkinlik2PolicyApprovalTag => 'İstek ile katılım';

  @override
  String get etkinlik2Organizer => 'Organizatör';

  @override
  String get etkinlik2JoinPolicyLabel => 'Katılım';

  @override
  String get etkinlik2PolicyApprovalHint =>
      'İstek ile seçersen katılımcıları sen onaylarsın.';

  @override
  String get etkinlik2FormClub => 'Kulüp adına (isteğe bağlı)';

  @override
  String get etkinlik2ClubNone => 'Seçilmedi';

  @override
  String get etkinlik2ClubSheetTitle => 'Kulüp seç';

  @override
  String get etkinlik2ClubNoneOption => 'Kulüp adına değil';

  @override
  String get etkinlik2ClubNoClubs => 'Etkinlik açabileceğin kulüp yok.';

  @override
  String get etkinlik2ChatAutoTitle => 'Etkinlik sohbeti otomatik açılır';

  @override
  String get etkinlik2ChatAutoBody =>
      'Katılanlar ve sen sohbete girersiniz. İstek ile katılımda yalnızca onaylananlar girer.';

  @override
  String get etkinlik2CapacityOptional => 'Kontenjan (isteğe bağlı)';

  @override
  String get etkinlik2Unlimited => 'Sınırsız';

  @override
  String etkinlik2RegOpenSlots(String n) {
    return 'Kayıtlar açık · $n yer kaldı';
  }

  @override
  String get etkinlik2RegOpen => 'Kayıtlar açık';

  @override
  String get etkinlik2ApprovalByOrganizer => 'Katılımı organizatör onaylar';

  @override
  String get etkinlik2SendRequest => 'Katılma isteği gönder';

  @override
  String get etkinlik2RequestHint =>
      'Organizatör onaylayınca etkinlik sohbetine girersin.';

  @override
  String get etkinlik2RequestSent => 'İstek gönderildi';

  @override
  String get etkinlik2AwaitingReply => 'Yanıt bekleniyor';

  @override
  String get etkinlik2Withdraw => 'Geri çek';

  @override
  String get etkinlik2WithdrawTitle => 'İsteği geri çek';

  @override
  String get etkinlik2WithdrawMessage => 'Katılma isteğin geri çekilecek.';

  @override
  String get etkinlik2ChatLocked => 'Etkinlik sohbeti · Onaylanınca açılır';

  @override
  String get etkinlik2RejectedTitle => 'İsteğin reddedildi';

  @override
  String get etkinlik2RejectedBody =>
      'Organizatör bu etkinlik için isteğini kabul etmedi.';

  @override
  String get etkinlik2RequestSentToast => 'Katılma isteğin gönderildi.';

  @override
  String get etkinlik2WithdrawnToast => 'İstek geri çekildi.';

  @override
  String etkinlik2GoingInterested(String going, String interested) {
    return '$going kişi katılıyor · $interested ilgileniyor';
  }

  @override
  String etkinlik2GoingOnly(String going) {
    return '$going kişi katılıyor';
  }

  @override
  String get etkinlik2ManageRequests => 'Katılım istekleri';

  @override
  String etkinlik2ManagePending(String n) {
    return '$n bekleyen istek';
  }

  @override
  String get etkinlik2ManageNoPending => 'Bekleyen istek yok';

  @override
  String get etkinlik2ManageAttendance => 'Katılımcılar ve yoklama';

  @override
  String get etkinlik2ManageSettings => 'Etkinlik ayarları';

  @override
  String get etkinlik2ManageSection => 'Yönetim';

  @override
  String get etkinlik2ReqQuota => 'Kontenjan';

  @override
  String etkinlik2ReqSlotsLeft(String n) {
    return '$n yer kaldı';
  }

  @override
  String get etkinlik2ReqNoLimit => 'Kontenjan sınırı yok';

  @override
  String get etkinlik2ReqFullBanner =>
      'Kontenjan doldu; yeni istekler onaylanamaz. Yer açmak için kontenjanı artır.';

  @override
  String etkinlik2ReqPendingHeader(String n) {
    return 'Bekleyen · $n';
  }

  @override
  String get etkinlik2ReqAnsweredHeader => 'Yanıtlananlar';

  @override
  String get etkinlik2ReqNone => 'Bekleyen istek yok.';

  @override
  String get etkinlik2Approve => 'Onayla';

  @override
  String get etkinlik2Reject => 'Reddet';

  @override
  String etkinlik2ApproveSem(String name) {
    return '$name isteğini onayla';
  }

  @override
  String etkinlik2RejectSem(String name) {
    return '$name isteğini reddet';
  }

  @override
  String get etkinlik2ApprovedTag => 'Onaylandı';

  @override
  String get etkinlik2RejectedTag => 'Reddedildi';

  @override
  String get etkinlik2ApprovedToast => 'İstek onaylandı.';

  @override
  String get etkinlik2RejectedToast => 'İstek reddedildi.';

  @override
  String get etkinlik2SettingsTitle => 'Etkinlik ayarları';

  @override
  String get etkinlik2SettingsPolicy => 'Katılım türü';

  @override
  String etkinlik2SettingsCapMin(String n) {
    return 'Şu an $n kişi onaylı. Kontenjanı bundan aşağı çekemezsin.';
  }

  @override
  String etkinlik2SettingsCapTooLow(String n) {
    return 'Kontenjan onaylı kişi sayısından ($n) az olamaz.';
  }

  @override
  String get etkinlik2SettingsRegChat => 'Kayıt ve sohbet';

  @override
  String get etkinlik2SettingsRegOpen => 'Kayıtlar açık';

  @override
  String get etkinlik2SettingsRegHint =>
      'Kapatırsan yeni istek ve katılım alınmaz.';

  @override
  String get etkinlik2SettingsChatOpen => 'Etkinlik sohbeti açık';

  @override
  String get etkinlik2SettingsChatHint =>
      'Kapatırsan mesajlar durur, geçmiş saklanır.';

  @override
  String get etkinlik2SettingsDanger => 'Tehlikeli bölge';

  @override
  String etkinlik2SettingsCancelBody(String n) {
    return 'Katılan $n kişiye bildirim gider ve sohbet kapanır. Bu işlem geri alınamaz.';
  }

  @override
  String get etkinlik2SettingsSaved => 'Ayarlar kaydedildi.';

  @override
  String get etkinlik2QrManualCaption => 'KODU ELLE GİRMEK İÇİN';

  @override
  String etkinlik2QrRenewsIn(String n) {
    return 'Kod $n sn sonra yenilenir';
  }

  @override
  String get etkinlik2AttendanceLabel => 'Yoklama';

  @override
  String etkinlik2PresentOf(String present, String total) {
    return '$present / $total kişi geldi';
  }

  @override
  String get etkinlik2FilterAll => 'Hepsi';

  @override
  String get etkinlik2FilterPresent => 'Geldi';

  @override
  String get etkinlik2FilterAbsent => 'Gelmedi';

  @override
  String etkinlik2MarkSem(String name) {
    return '$name geldi olarak işaretle';
  }

  @override
  String get etkinlik2MethodQr => 'QR';

  @override
  String get etkinlik2MethodManual => 'Elle';

  @override
  String get etkinlik2ShowQrSem => 'QR kodunu göster';

  @override
  String get etkinlik2AttendanceEmpty => 'Gösterilecek katılımcı yok.';

  @override
  String get etkinlik2MarkFailed => 'Yoklama güncellenemedi.';

  @override
  String get etkinlik2ChatClosedToast => 'Sohbet kapatıldı.';

  @override
  String get etkinlik2ChatOpenedToast => 'Sohbet açıldı.';

  @override
  String get etkinlik2NoteLabel => 'Organizatöre not (isteğe bağlı)';

  @override
  String get etkinlik2AnswerRequired => 'Tüm soruları yanıtlamalısın.';

  @override
  String get etkinlik2ClubSemPrefix => 'Kulüp';

  @override
  String cevrimdisiBekleyenMesaj(String n) {
    return '$n mesaj bağlantı gelince gönderilecek';
  }

  @override
  String cevrimdisiGonderiliyor(String n) {
    return '$n mesaj gönderiliyor…';
  }

  @override
  String get cevrimdisiGonderilemedi => 'Gönderilmedi';

  @override
  String cevrimdisiSonGuncelleme(String zaman) {
    return 'Son güncelleme: $zaman';
  }

  @override
  String get cevrimdisiKayitliVeri => 'Kayıtlı veriler gösteriliyor';

  @override
  String get cevrimdisiBekliyor => 'Bekliyor';

  @override
  String get cevrimdisiYenidenDene => 'Yeniden dene';

  @override
  String get cevrimdisiMedyaBaglanti => 'Bağlantı gelince tekrar deneyin';

  @override
  String get cevrimdisiInternetYok => 'İnternet bağlantısı yok';

  @override
  String get bildirimmobilKanalChat => 'Mesajlar';

  @override
  String get bildirimmobilKanalEvent => 'Etkinlikler';

  @override
  String get bildirimmobilKanalAnnouncement => 'Duyurular ve haberler';

  @override
  String get bildirimmobilKanalSocial => 'Sosyal (beğeni, takip)';

  @override
  String get bildirimmobilKanalPoll => 'Anketler';

  @override
  String get bildirimmobilKanalAcademic => 'Ders ve sınav hatırlatmaları';

  @override
  String get evcLabelClub => 'Kulüp';

  @override
  String get evcInfoInstant => 'Hemen yayınlanır.';

  @override
  String get evcInfoReview => 'Admin onayından sonra yayınlanır.';

  @override
  String get evcClubRequiredHint => 'Önce bir kulüp seç.';

  @override
  String get evcEmptyTitle =>
      'Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın';

  @override
  String get evcEmptyBody =>
      'Etkinlikler kulüpler adına açılır. Bir kulübün yöneticisi olduğunda burada etkinlik oluşturabilirsin.';

  @override
  String get evcBrowseClubs => 'Kulüplere göz at';

  @override
  String get evcSubmittedTitle => 'Onaya gönderildi';

  @override
  String get evcSubmittedBody =>
      'Etkinliğin admin onayından sonra yayınlanacak. Durumunu Oluşturduklarım sekmesinden takip edebilirsin.';

  @override
  String get evcOk => 'Tamam';

  @override
  String get evcStatusPending => 'Onay bekliyor';

  @override
  String get evcStatusRejected => 'Reddedildi';

  @override
  String evcRejectReason(String reason) {
    return 'Neden: $reason';
  }

  @override
  String get evcErrClubRequired =>
      'Etkinlik bir kulüp adına oluşturulmalı. Bir kulüp seç.';

  @override
  String get evcErrForbidden => 'Bu kulüp adına etkinlik oluşturma yetkin yok.';

  @override
  String get evcErrClubNotActive => 'Bu kulüp şu anda etkin değil.';

  @override
  String get evcErrPast => 'Etkinlik başlangıcı geçmişte olamaz.';

  @override
  String get evcErrDates => 'Bitiş, başlangıçtan sonra olmalı.';

  @override
  String get evcErrProfanity => 'Metinde uygunsuz ifade var. Lütfen düzenle.';

  @override
  String get evdLabelDate => 'Tarih';

  @override
  String get evdLabelTime => 'Başlangıç saati';

  @override
  String get evdLabelDuration => 'Süre';

  @override
  String get evdChipToday => 'Bugün';

  @override
  String get evdChipTomorrow => 'Yarın';

  @override
  String get evdChipWeekend => 'Bu hafta sonu';

  @override
  String get evdChipNextWeek => 'Gelecek hafta';

  @override
  String get evdChipPickDate => 'Tarih seç';

  @override
  String get evdChipCustomTime => 'Özel saat';

  @override
  String get evdDur1h => '1 saat';

  @override
  String get evdDur2h => '2 saat';

  @override
  String get evdDurHalfDay => 'Yarım gün';

  @override
  String get evdChipCustomEnd => 'Bitiş tarihi seç';

  @override
  String get evdErrStartPast => 'Başlangıç geçmişte olamaz.';

  @override
  String get evdErrEndBeforeStart => 'Bitiş, başlangıçtan sonra olmalı.';

  @override
  String get evdEndAdjusted =>
      'Bitiş, başlangıçtan 1 saat sonrasına otomatik ayarlandı.';

  @override
  String evdDescCounter(String count, String max) {
    return '$count/$max';
  }

  @override
  String evdErrDescTooLong(String max) {
    return 'Açıklama en fazla $max karakter olabilir.';
  }

  @override
  String get evdErrDescTooLongServer => 'Açıklama çok uzun. Lütfen kısalt.';

  @override
  String get clubMgmtCategoryNone => 'Seçilmedi';

  @override
  String clubMgmtCategoryInactive(String name) {
    return '$name (kullanım dışı)';
  }

  @override
  String get clubMgmtCategoryInvalid =>
      'Seçilen kategori geçerli değil. Listeden başka bir kategori seç.';

  @override
  String get errEmailAliasNotAllowed =>
      'E-posta adresinde + etiketi kullanılamaz.';

  @override
  String get errPasswordTooLong =>
      'Şifre çok uzun: en fazla 72 bayt olabilir (Türkçe ve Arapça karakterler birden çok bayt tutar).';

  @override
  String get errPayloadTooLarge =>
      'Gönderilen veri çok büyük. Daha küçük bir dosya ya da daha kısa bir metin deneyin.';

  @override
  String get errUploadBusy =>
      'Başka bir yüklemeniz sürüyor ya da sunucu yoğun. Biraz bekleyip tekrar deneyin.';

  @override
  String get errUploadQuota =>
      'Çok fazla yükleme yaptınız. Biraz sonra tekrar deneyin.';

  @override
  String get errMailQuota =>
      'Şu anda doğrulama kodu gönderemiyoruz. Lütfen daha sonra tekrar deneyin.';

  @override
  String get errServiceBusy =>
      'Sistem şu an yoğun. Lütfen birkaç saniye sonra tekrar deneyin.';

  @override
  String get errLegalReaccept =>
      'Sözleşmeler güncellendi. Devam etmek için güncel sözleşmeleri onaylamanız gerekiyor.';

  @override
  String coreErrRetryAfterSec(String n) {
    return '$n sn sonra tekrar deneyin.';
  }

  @override
  String coreErrRetryAfterMin(String n) {
    return '$n dk sonra tekrar deneyin.';
  }

  @override
  String get clubPostTextRequired =>
      'Görselle paylaşmak için bir yazı da ekleyin.';

  @override
  String get etkinlik2QrExpired => 'Süresi doldu, yenileniyor…';

  @override
  String get updateRequiredRecheck => 'Tekrar kontrol et';

  @override
  String get updateRequiredFromStore => 'Mağazadan güncelleyin';

  @override
  String get legalReacceptTitle => 'Sözleşmeler güncellendi';

  @override
  String get legalReacceptIntro =>
      'Kullanım koşulları ve gizlilik metinlerinde değişiklik yaptık. Uygulamayı kullanmaya devam etmek için güncellenen belgeleri okuyup kabul etmeniz gerekiyor.';

  @override
  String get legalReacceptIntroSoft =>
      'Bazı belgelerin yeni sürümü yayımlandı. Şimdi inceleyip kabul edebilir ya da daha sonraya bırakabilirsiniz; ilerleyen günlerde kabul etmeniz gerekecek.';

  @override
  String get legalReacceptListTitle => 'Güncellenen belgeler';

  @override
  String get legalReacceptTypeTerms => 'Kullanım Koşulları';

  @override
  String get legalReacceptTypePrivacy => 'Gizlilik Politikası';

  @override
  String get legalReacceptTypeKvkk => 'KVKK Aydınlatma Metni';

  @override
  String get legalReacceptTypeRules => 'Topluluk Kuralları';

  @override
  String get legalReacceptNoteExplicit =>
      'İsteğe bağlı açık rıza izinleri bu onaydan ayrıdır; bu işlemle verilmiş sayılmaz.';

  @override
  String get legalReacceptCheck =>
      'Güncellenen belgeleri okudum ve kabul ediyorum';

  @override
  String get legalReacceptAccept => 'Kabul et';

  @override
  String get legalReacceptLater => 'Daha sonra';

  @override
  String get legalReacceptDecline => 'Kabul etmiyorum';

  @override
  String get legalReacceptDeclineTitle => 'Kabul etmeden devam edilemez';

  @override
  String get legalReacceptDeclineBody =>
      'Güncel sözleşmeleri kabul etmezseniz uygulamayı kullanamazsınız. Hesabınızı silebilir ya da çıkış yapıp daha sonra tekrar karar verebilirsiniz.';

  @override
  String get legalReacceptDeleteAccount => 'Hesabımı sil';

  @override
  String get legalReacceptSignOut => 'Çıkış yap';

  @override
  String get legalReacceptOutdated =>
      'Belgeler yeniden güncellendi. Lütfen yeni sürümleri inceleyip tekrar kabul edin.';

  @override
  String get authVerifyPasswordLabel => 'Kayıtta belirlediğiniz şifre';

  @override
  String get authVerifyPasswordNote =>
      'Güvenlik için, kayıt sırasında girdiğiniz şifreyi yeniden girin.';

  @override
  String get authVerifyPasswordRequired =>
      'Kayıtta belirlediğiniz şifreyi girin.';

  @override
  String get chatClosedBanner => 'Bu sohbet yönetici tarafından kapatıldı.';

  @override
  String get chatRealtimeLost =>
      'Canlı bağlantı kesildi; mesajlar kısa aralıklarla yenileniyor.';

  @override
  String get chatAdminRemovedMsg => 'Bu mesaj yönetici tarafından kaldırıldı';

  @override
  String get chatModRemovedMsg => 'Bu mesaj kaldırıldı';

  @override
  String get errCertificateRevoked =>
      'Bu sertifika yönetici tarafından iptal edildi.';

  @override
  String get clubUnavailable => 'Kulüp şu an kullanılamıyor.';

  @override
  String get profil2DelItemUsage =>
      'Cihaz, IP ve kullanım (analitik) kayıtların anında silinir.';

  @override
  String get profil2DelItemClubOwner =>
      'Sahibi olduğun kulüpler yönetici üyeye devredilir; aday yoksa kulüp kapatılır.';

  @override
  String get settingsCrashReports => 'Hata raporu gönder';

  @override
  String get settingsCrashReportsDesc =>
      'Uygulama hata verdiğinde veya kapandığında anonim bir hata raporu BÜ Kampüs sunucusuna gönderilir: uygulama sürümü, işletim sistemi, hata türü ve kişisel veri içermeyen teknik bir yığın izi. E-posta, şifre, mesaj içeriği veya kimliğiniz gönderilmez; üçüncü taraf hizmete aktarılmaz. İstediğiniz zaman kapatabilirsiniz.';

  @override
  String get welcomeChipNews => 'Haberler';

  @override
  String get welcomeChipMenu => 'Yemek';

  @override
  String get welcomeChipClubs => 'Kulüpler';

  @override
  String get authLangTitle => 'Dil seçin';

  @override
  String get authPaste => 'Yapıştır';

  @override
  String get authResetDoneTitle => 'Şifreniz güncellendi';

  @override
  String get authResetDoneBody =>
      'Yeni şifrenizle giriş yapabilirsiniz. Diğer cihazlardaki oturumlar kapatıldı.';

  @override
  String get authTrustAcademic =>
      'Bölümünüz, size uygun duyuru ve kulüpleri göstermek için kullanılır.';

  @override
  String get authTrustName =>
      'Adınız profilinizde ve sohbetlerde diğer öğrencilere görünür.';

  @override
  String get authTrustPassword =>
      'Şifreniz yalnızca özeti alınarak saklanır; kimse göremez.';

  @override
  String get authTrustCode =>
      'E-posta gelmediyse gereksiz (spam) klasörünü de kontrol edin.';

  @override
  String get authTrustSecure => 'Bağlantınız şifreli ve güvenlidir.';

  @override
  String p00StepOf(String current, String total) {
    return 'Adım $current / $total';
  }

  @override
  String get p05NewsEmptyBody => 'Yeni içerikler geldiğinde burada görünecek.';

  @override
  String get p05SavedEmptyTitle => 'Henüz favorin yok';

  @override
  String get p05SavedToast => 'Favorilere eklendi';

  @override
  String get p05UnsavedToast => 'Favorilerden çıkarıldı';

  @override
  String get p05SearchIdleTitle => 'Kampüste ara';

  @override
  String get p05SearchNoResultsBody => 'Farklı bir kelime deneyin.';

  @override
  String get p05Source => 'Kaynak';

  @override
  String p05ReadMinutes(String count) {
    return '$count dk okuma';
  }

  @override
  String p17WeekOf(String n, String total) {
    return 'Hafta $n / $total';
  }

  @override
  String get p17SemesterName => 'Dönem adı';

  @override
  String get p17NoClassesTitle => 'Haftalık programın boş';

  @override
  String get p17ExamsEmptyTitle => 'Henüz sınav yok';

  @override
  String get p17OfficialEmptyTitle => 'Resmi program yayınlanmadı';

  @override
  String get p17SemestersEmptyTitle => 'Dönem yok';

  @override
  String get p17MaintenanceTitle => 'Bakım çalışması';

  @override
  String get p17PreviewHint => 'Önizleme';

  @override
  String get p16QrCopy => 'Kodu kopyala';

  @override
  String get p16QrCopied => 'Kod kopyalandı';

  @override
  String get p16ReqNoneBody =>
      'Yeni katılma istekleri geldiğinde burada görünür.';

  @override
  String get p16AttEmptyBody =>
      'Katılımcılar etkinliğe katıldıkça burada listelenir.';

  @override
  String get p16AttFilterEmpty => 'Bu süzgece uyan kimse yok.';

  @override
  String get p16PolicyOpenHint => 'Herkes istek göndermeden doğrudan katılır.';

  @override
  String p16AttPresentCount(String n) {
    return '$n geldi';
  }

  @override
  String get p10PageTitle => 'Medya ekle';

  @override
  String get p10SheetTitle => 'Ekle';

  @override
  String get p10SheetSubtitle => 'Sohbete ne göndermek istersin?';

  @override
  String get p10SourcePhotos => 'Fotoğraf';

  @override
  String get p10SourcePhotosHint => 'Galerinden bir ya da birkaç fotoğraf seç';

  @override
  String get p10SourceVideo => 'Video';

  @override
  String get p10SourceVideoHint => 'Galerinden video seç (en fazla 60 sn)';

  @override
  String get p10SourceCamera => 'Kamera';

  @override
  String get p10SourceCameraHint => 'Fotoğraf çek ya da video kaydet';

  @override
  String get p10PrivacyNote =>
      'Yalnızca seçtiğin öğelere erişilir; galerinin tamamı uygulamaya açılmaz.';

  @override
  String get p10PickedHeader => 'Seçilenler';

  @override
  String get p10EmptyTitle => 'Henüz bir şey seçmedin';

  @override
  String get p10EmptyBody =>
      'Yukarıdan fotoğraf, video ya da kamerayı seçerek başla.';

  @override
  String get p10Preview => 'Önizle';

  @override
  String get p10Remove => 'Kaldır';

  @override
  String get p10PickFailed => 'Seçici açılamadı. Lütfen tekrar dene.';

  @override
  String get p14Today => 'Bugün';

  @override
  String get p14Tomorrow => 'Yarın';

  @override
  String get p14ClearDay => 'Tüm ay';

  @override
  String get p14Ended => 'Sona erdi';

  @override
  String get p14Live => 'Şimdi';

  @override
  String p14EventCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Etkinlik',
    );
    return '$_temp0';
  }

  @override
  String get p14EmptyMonthBody =>
      'Başka bir aya göz at; yeni etkinlikler eklendikçe burada görünür.';

  @override
  String get p14EmptyDayBody => 'Başka bir gün seç ya da tüm ayı gör.';

  @override
  String get p14EmptyUpcomingBody =>
      'Kulüplerin etkinliklerine katıl; katıldıkların burada toplanır.';

  @override
  String get p14EmptyPastBody =>
      'Katıldığın etkinlikler bittikten sonra burada saklanır.';

  @override
  String get p14EmptyCreatedBody =>
      'Kulübün adına bir etkinlik oluştur; başvuruları ve yoklamayı buradan yönet.';

  @override
  String get p13SuppAskTitle => 'Size nasıl yardımcı olabiliriz?';

  @override
  String get p13SuppAskBody =>
      'Sık sorulan sorulara göz atın ya da destek ekibine yazın.';

  @override
  String get p13TicketIntro =>
      'Sorununuzu kısaca anlatın; destek ekibi en kısa sürede yanıt verecek.';

  @override
  String get p13TicketsEmptyHint =>
      'Bir sorun yaşarsanız yeni bir talep oluşturabilirsiniz.';

  @override
  String get p13FeedbackEmptyHint =>
      'Gönderdiğiniz öneri ve hata bildirimleri burada listelenir.';

  @override
  String get p13SugEmptyTitle => 'Fikirler burada toplanır';

  @override
  String get p13PollEmptyOpenHint =>
      'Yeni anketler açıldığında burada görünür.';

  @override
  String get p13PollEmptyMineHint =>
      'Bir ankete oy verdiğinizde burada listelenir.';

  @override
  String get p13PollEmptyClosedHint =>
      'Sona eren anketlerin sonuçları burada saklanır.';

  @override
  String get p13Rate1 => 'Çok kötü';

  @override
  String get p13Rate2 => 'Kötü';

  @override
  String get p13Rate3 => 'Orta';

  @override
  String get p13Rate4 => 'İyi';

  @override
  String get p13Rate5 => 'Çok iyi';

  @override
  String get p13Leading => 'Önde';

  @override
  String p08ItemOf(String n, String total) {
    return '$n / $total';
  }

  @override
  String get p08Pause => 'Duraklat';

  @override
  String get p08Seek => 'Video konumu';

  @override
  String get p08OnceHint => 'Kapattığında bu fotoğraf bir daha açılamaz.';

  @override
  String get p13TicketsHeading => 'Taleplerim';

  @override
  String get p13ShareHeading => 'Görüşünüzü paylaşın';

  @override
  String get p13FeedbackMine => 'Gönderdiklerim';

  @override
  String get p11ReadMore => 'Devamını göster';

  @override
  String get p11ReadLess => 'Daha az göster';

  @override
  String get p11TypeSingleHint => 'Tek bir seçenek işaretlenir';

  @override
  String get p11TypeMultiHint => 'Birden fazla seçenek işaretlenebilir';

  @override
  String get p11TypeRankedHint => 'Seçenekler tercih sırasına dizilir';

  @override
  String get p11TypeRatingHint => '1-5 yıldızla puanlanır';

  @override
  String get p11RequestsEmptyBody =>
      'Yeni katılma istekleri geldiğinde burada görünecek.';

  @override
  String get p06EmptyNoneBody =>
      'Arkadaşlarınızla, öğrenci kulüpleriyle veya etkinlik gruplarıyla mesajlaşmaya başlayın.';

  @override
  String p06NoMatchBody(String q) {
    return '“$q” aramasıyla eşleşen kişi, kulüp veya mesaj bulunamadı.';
  }

  @override
  String get p06ResetSearch => 'Aramayı sıfırla';

  @override
  String get p06ArchiveEmptyBody =>
      'Arşivlediğiniz sohbetler burada saklanır ve mesaj kutunuzu sade tutar.';

  @override
  String get p06BackToChats => 'Sohbetlere dön';

  @override
  String get p06LoadFailedTitle => 'Yüklenemedi, tekrar dene';

  @override
  String get p06LoadFailedBody =>
      'Sohbet listesi güncellenirken bir bağlantı hatası oluştu. Lütfen bağlantınızı kontrol edin.';

  @override
  String get p06MenuDeleteChat => 'Sohbeti sil';

  @override
  String get p08OnceSubtitle => 'Yalnızca bir kez görüntülenebilir';

  @override
  String get p08OnceSentSub => 'Tek seferlik görünüm';

  @override
  String get p08ModerationTitle => 'Moderasyon bildirimi';

  @override
  String p08Percent(String n) {
    return '%$n';
  }

  @override
  String get p08PhotoLoadingSub => 'Sunucudan indiriliyor';

  @override
  String get p08Queued => 'Kuyrukta · Bekliyor';

  @override
  String get p01ConfigTitle => 'Yapılandırma hatası';

  @override
  String get p01ConfigBody =>
      'Sunucu adresi (API_BASE) güvenli (https) değil. Uygulamayı doğru adresle yeniden derleyin.';

  @override
  String get p01ConfigCode => 'HATA KODU • BUILD_ENV';

  @override
  String get p01UpdateNoticeLabel => 'Uygulama Güncellemesi';

  @override
  String get p01PushNow => 'şimdi';

  @override
  String p01PushMore(String n) {
    return '+$n yeni mesaj daha';
  }

  @override
  String get p01PushReply => 'Cevaplamak için dokun';

  @override
  String p01PermDeniedTitle(String title) {
    return '$title izni verilmedi';
  }

  @override
  String get p01QrAttended => 'Yoklaman alındı';

  @override
  String get p07ChatEmptyTitle => 'Henüz mesaj yok';

  @override
  String get p07ChatEmptyBody => 'İlk mesajı sen yaz.';

  @override
  String get p07ChatBlockedLine => 'Engellediğiniz kişiyle mesajlaşamazsınız.';

  @override
  String get p02WelcomeNewsSub => 'Anlık bildirimler ve kampüs içi gelişmeler.';

  @override
  String get p02WelcomeMenuSub => 'Günlük kalori ve detaylı öğün içerikleri.';

  @override
  String get p02WelcomeClubsSub =>
      'Topluluklar, atölyeler ve katılım yoklaması.';

  @override
  String get p02BrandSub => 'Bağımsız öğrenci uygulaması';

  @override
  String get p02LoginBusy => 'Giriş yapılıyor…';

  @override
  String get p02TipTitle => 'İpucu';

  @override
  String p02FacultyCount(int n) {
    return '$n Bölüm';
  }

  @override
  String get p02PendingTitle => 'E-postanı doğrula';

  @override
  String get p02PendingBody =>
      'Giriş yapabilmek için hesabının doğrulanması gerekir.';

  @override
  String get p02ReplacedTitle => 'Oturum sonlandırıldı';

  @override
  String get p01LgLoadFailed => 'Yüklenemedi, tekrar dene';

  @override
  String p01LgMetaLine(String version, String date) {
    return 'Sürüm $version · Yürürlük: $date';
  }

  @override
  String get p03MenuTotal => 'Toplam';

  @override
  String get p03MenuTotalEnergy => 'Toplam enerji';

  @override
  String p03MenuKcal(String n) {
    return '$n kcal';
  }

  @override
  String p03MenuAtLeast(String n) {
    return 'En az $n kcal';
  }

  @override
  String get p03MenuKcalMissing => 'Bazı yemeklerin kalorisi girilmemiş.';

  @override
  String get p03MenuKcalNone => 'Kalori girilmemiş';

  @override
  String get p03MenuNoList => 'Yemek listesi yok.';

  @override
  String get p03MenuMaintenance => 'Sistem bakımda.';

  @override
  String p03NotifNewCount(String n) {
    return '$n yeni';
  }

  @override
  String get p03NotifEmptyBody =>
      'Kulüp, etkinlik ve mesaj bildirimleri burada görünür.';

  @override
  String get p03NotifUnreadEmptyBody => 'Hepsini okudun.';

  @override
  String get p03NotifLoadFailed => 'Yüklenemedi, tekrar dene';

  @override
  String get p03NotifLoadingMore => 'Daha fazla yükleniyor...';

  @override
  String get p03HomeMealTitle => 'Günün menüsü';

  @override
  String get p03HomeNoMenuBody => 'Yemekhane menüsü sisteme henüz girilmedi.';

  @override
  String get p03HomeEventsTitle => 'Yaklaşan Etkinlikler';

  @override
  String get p03HomeNoEventBody =>
      'Şu anda planlanmış aktif bir kulüp etkinliği bulunmuyor.';

  @override
  String get p05NewsOpenSource => 'Kaynak sayfada aç';

  @override
  String get p05NewsErrorTitle => 'İçerik yüklenemedi';

  @override
  String get p05NewsErrorBody =>
      'İçerik yüklenirken bir sorun oluştu. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String p05SearchCountFor(String q) {
    return '“$q” araması için';
  }

  @override
  String p05SearchFoundNews(String n) {
    return '$n HABER BULUNDU';
  }

  @override
  String p05SearchFoundEvents(String n) {
    return '$n ETKİNLİK BULUNDU';
  }

  @override
  String p05SearchFoundClubs(String n) {
    return '$n KULÜP BULUNDU';
  }

  @override
  String p05SearchFoundPeople(String n) {
    return '$n KİŞİ BULUNDU';
  }

  @override
  String p05SearchFoundPosts(String n) {
    return '$n GÖNDERİ BULUNDU';
  }

  @override
  String p05SearchSeeAllN(String n) {
    return 'Tümünü gör ($n)';
  }

  @override
  String get p05SearchRemoveRecent => 'Aramayı sil';

  @override
  String get p11PendingInfoTitle => 'Başvuru değerlendiriliyor';

  @override
  String get p11PendingInfoBody =>
      'Katılma isteğin kulüp yöneticilerinin onayını bekliyor. Sonuçlandığında bildirim alacaksın.';

  @override
  String get p11LockPrivateTitle => 'Bu kulüp özeldir';

  @override
  String get p11LockPrivateBody =>
      'Gönderileri ve üye listesini yalnızca onaylı üyeler görebilir.';

  @override
  String get p11LockMembersTitle => 'İçerikler yalnızca üyelere açık';

  @override
  String get p11LockMembersBody =>
      'Kulüp paylaşımları, isteğin onaylandıktan sonra görüntülenebilir.';

  @override
  String get p11LockBannedTitle => 'İçerik görüntülenemiyor';

  @override
  String get p11LockBannedBody =>
      'Erişim kısıtlandığı için kulüp içeriği gizlendi.';

  @override
  String get p11BannedTitle => 'Kulüpten uzaklaştırıldın';

  @override
  String get p11BannedBody =>
      'Bu kulübe katılamaz ve etkinliklerine başvuramazsın.';

  @override
  String get p11ApprovalNote =>
      'Katılma isteğin yöneticiler tarafından onaylandıktan sonra kulüp içeriği açılır.';

  @override
  String get p11PostPinSub => 'Kulüp sayfasının en üstüne yerleştir';

  @override
  String get p11PostUnpinSub => 'Gönderiyi normal sıraya döndür';

  @override
  String get p11PostDeleteSub => 'Gönderiyi kalıcı olarak akıştan kaldır';

  @override
  String get p11PostReportSub => 'Kulüp kurallarının ihlalini bildir';

  @override
  String get p11PollsSub => 'Üye kararları ve seçimleri';

  @override
  String p11SearchEmptyBody(String query) {
    return '“$query” aramasıyla eşleşen kulüp üyesi yok. İsmi kontrol edip tekrar dene.';
  }

  @override
  String get p11ClearSearch => 'Aramayı temizle';

  @override
  String get p11RequestsEmptyAll =>
      'Kulübüne gelen tüm başvurular yanıtlandı ya da henüz yeni başvuru yapılmadı.';

  @override
  String get p11LoadErrorBody =>
      'Bağlantı hatası oluştu. Bilgiler sunucudan alınamadı.';

  @override
  String get p12LogoAdd => 'Logo ekle';

  @override
  String get p12LogoChange => 'Logoyu değiştir';

  @override
  String get p12LogoHint => 'Kare profil (1:1)';

  @override
  String get p12CoverHint => '16:9 yatay görsel önerilir';

  @override
  String get p12QuestionsSubtitle => 'Adaylara yöneltilecek mini form';

  @override
  String get p12QuestionPlaceholder => 'Sorunu yaz...';

  @override
  String get p12ConsentNote =>
      'Kulüp oluşturarak topluluk ilkelerine ve öğrenci kurallarına uymayı kabul edersin.';

  @override
  String get p12PartialTitle => 'Kısmi kayıt uyarısı';

  @override
  String get p12CategorySheetTitle => 'Kategori seç';

  @override
  String get p12JoinNote => 'Talebin onaylandığında bildirim alacaksın.';

  @override
  String p12CountClubs(String count) {
    return '$count kulüp';
  }

  @override
  String p12CountRequests(String count) {
    return '$count başvuru';
  }

  @override
  String get p15PublishRoleActive => 'Yönetici yetkisi aktif';

  @override
  String get p15CoverOptional => 'İsteğe bağlı';

  @override
  String get p15CoverHint => '16:9 yatay önerilir • En fazla 3 MB';

  @override
  String get p15CoverChange => 'Değiştir';

  @override
  String get p15CoverSheetTitle => 'Kapak fotoğrafı';

  @override
  String get p15CoverGallerySub => 'Cihazındaki albümlerden bir görsel belirle';

  @override
  String get p15CoverCameraSub => 'Kamerayı kullanarak anında çekim yap';

  @override
  String get p15CoverRemoveSub => 'Varsayılan şablon görseline geri dön';

  @override
  String p15ErrBannerTitle(String n) {
    return 'Lütfen formdaki $n hatayı düzelt.';
  }

  @override
  String get p15ErrBannerBody =>
      'Girdiğin bilgilerin bazıları eksik veya kurallara uymuyor. İşaretli alanları kontrol et.';

  @override
  String get p15ErrHint =>
      'Gerekli alanlar düzeltildiğinde oluşturma düğmesi otomatik olarak aktifleşir.';

  @override
  String p15ErrLocked(String n) {
    return 'Önce $n doğrulama hatasını gidermelisin';
  }

  @override
  String get p15ErrForbiddenTitle => 'Yetki kısıtlaması';

  @override
  String get p15ErrInactiveTitle => 'Kulüp durumu pasif';

  @override
  String get p15PickerSubtitle => 'Etkinliğin yayınlanacağı yetkili kulübün';

  @override
  String get p15PickerSearch => 'Kulüp ara…';

  @override
  String get p15PickerNoMatch => 'Eşleşen kulüp yok.';

  @override
  String p15PickerMembers(String n) {
    return '$n üye';
  }

  @override
  String get p15PickerInfoTitle => 'Yetki bilgilendirmesi';

  @override
  String get p15PickerInfoBody =>
      'Yönetici veya moderatör olduğun kulüplerde etkinlik hemen yayınlanır. Etkinlik yetkisi olan üyelerin etkinliği admin onayından sonra yayınlanır.';

  @override
  String get p15PickerEmptyBody =>
      'Yönetici veya moderatör yetkisine sahip olduğun bir kulüp bulunmuyor.';

  @override
  String get p15RefreshPerms => 'Yetkileri yenile';

  @override
  String get p16ReqQuotaStatus => 'Kontenjan durumu';

  @override
  String get p16ReqRegistered => 'Kayıtlı';

  @override
  String get p16ReqUnlimitedTitle => 'Katılımcı kotası';

  @override
  String get p16ReqPendingTitle => 'Bekleyen istekler';

  @override
  String get p16ReqNoteLabel => 'Başvuru notu';

  @override
  String get p16ReqFullTitle => 'Kontenjan doldu';

  @override
  String get p16ReqFullBody =>
      'Yeni istekler onaylanamaz. Yer açmak için kontenjanı artırabilir veya katılımcı listesini güncelleyebilirsin.';

  @override
  String get p16ReqRaiseQuota => 'Kontenjanı artır';

  @override
  String p16ReqFullPeople(String a, String b) {
    return '$a / $b kişi';
  }

  @override
  String get p16ReqCantApprove => 'Kontenjan yetersiz olduğu için onaylanamaz';

  @override
  String get p16ReqErrTitle => 'İstek listesi güncellenemedi.';

  @override
  String get p16ReqBackToEvent => 'Etkinlik detayına dön';

  @override
  String get p16ReqEmptyBody =>
      'Tüm katılım istekleri yanıtlandı veya yeni başvuru henüz gelmedi.';

  @override
  String p16SetApproved(String n) {
    return '$n onaylı katılımcı';
  }

  @override
  String get p16SetOpenSub => 'Kayıt olan herkes doğrudan onaylanır.';

  @override
  String get p16SetApprovalSub =>
      'Her katılımcı isteği yönetici onayından geçer.';

  @override
  String get p16SetCapLabel => 'Kontenjan (kişi)';

  @override
  String p16SetCapCurrent(String n) {
    return 'Mevcut: $n kişi';
  }

  @override
  String get p16SetCapDec => 'Kontenjanı azalt';

  @override
  String get p16SetCapInc => 'Kontenjanı artır';

  @override
  String p16SetCancelNote(String n) {
    return 'Katılan $n kişiye anlık bildirim gönderilecek ve etkinlik listelerden kaldırılacaktır.';
  }

  @override
  String get p16QrStatusTitle => 'Yoklama durumu';

  @override
  String get p16QrStatusSub => 'Anlık katılım kaydı';

  @override
  String get p16QrList => 'Katılımcılar listesi';

  @override
  String get p16QrExpiredTitle => 'Süresi doldu';

  @override
  String get p16QrRefreshing => 'Yenileniyor…';

  @override
  String get p16QrErrBody =>
      'Sunucu ile bağlantı kurulamadı veya oturum zaman aşımına uğradı.';

  @override
  String get p16QrCopyBtn => 'Kopyala';

  @override
  String get p16AttTitle => 'Katılımcılar ve yoklama';

  @override
  String get p16AttWaiting => 'Bekliyor';

  @override
  String get p16AttFilterEmptyBody =>
      'Bu filtreye uygun katılımcı kaydı bulunamadı.';

  @override
  String p16AttMarkedToast(String name, String method) {
    return '$name yoklamaya eklendi ($method)';
  }

  @override
  String p16AttUnmarkedToast(String name) {
    return '$name yoklamadan çıkarıldı';
  }

  @override
  String get p07ChatSearchClear => 'Temizle';

  @override
  String get p17DailyFlow => 'Günlük akış';

  @override
  String p17DayPlanned(String n) {
    return '$n ders planlandı';
  }

  @override
  String get p17SlotWaiting => 'Bekliyor';

  @override
  String p17RoomLabel(String room) {
    return 'Derslik $room';
  }

  @override
  String p17HoursPerWeek(String n) {
    return '$n saat / hafta';
  }

  @override
  String get p17NoSemesterTitle => 'Henüz dönem yok';

  @override
  String get p17NoSemesterBody =>
      'Bir dönem ekleyerek derslerini düzenleyebilirsin.';

  @override
  String get p17NoCourseTitle => 'Henüz ders eklemedin';

  @override
  String get p17NoCourseBody =>
      'Haftalık ders programını oluşturmak için ilk dersini kaydet.';

  @override
  String get p17DayFreeBody =>
      'Günü dinlenmeye, kütüphanede çalışmaya ya da kampüste kahveye ayırabilirsin!';

  @override
  String get p17TodayDoneBody =>
      'Günün tüm derslerini tamamladın, iyi dinlenmeler.';

  @override
  String get p17WeekDoneBody =>
      'Haftalık program bitti. Gelecek haftaya hazırsın!';

  @override
  String get p17OutOfRangeBody =>
      'Seçilen gün akademik takvim dışında kalıyor.';

  @override
  String get p17LoadErrTitle => 'Ders programı yüklenirken bir sorun oluştu.';

  @override
  String p17SemesterCount(String n) {
    return '$n kayıtlı dönem';
  }

  @override
  String get p17CheckFields => 'Lütfen aşağıdaki alanları kontrol et:';

  @override
  String get p17ExamDetail => 'Detay';

  @override
  String get p17ExamsNoUpcomingBody =>
      'Tebrikler! Şu an için yaklaşan vize, final veya quiz bulunmuyor.';

  @override
  String get p17ExamsEmptyMineTitle => 'Kişisel sınav eklemedin.';

  @override
  String get p17ExamsEmptyMineBody =>
      'Sınav takvimini oluşturmak ve geri sayımı takip etmek için ilk sınavını ekle.';

  @override
  String get p17CourseInfoSemantic => 'Ders bilgileri';

  @override
  String get p20HubExamPlan => 'Oturum planı';

  @override
  String get p20HubTimetableEmptyBody =>
      'Haftalık akışını takip etmek ve sınıf takvimini oluşturmak için derslerini ekle.';

  @override
  String get p20HubExamBadge => 'Vize & Final';

  @override
  String get p20HubExamEmptyBody =>
      'Tebrikler! Takviminde şu an için planlanmış bir vize veya final görünmüyor.';

  @override
  String get p20HubCalEmptySub => 'Dönem içi işlem aralıkları tamamlandı';

  @override
  String get p20HubAnnEmptyTitle => 'Okunmamış duyuru yok';

  @override
  String get p20HubAnnEmptyBody =>
      'Bölüm sekreterliği veya danışmanından yeni bir bildirim paylaşıldığında burada listelenecek.';

  @override
  String get p20HubDateTime => 'Tarih & saat';

  @override
  String p20CalToday(String date) {
    return 'Bugün: $date';
  }

  @override
  String get p20CalSelected => 'Seçili';

  @override
  String get p20CalImportant => 'Önemli tarih';

  @override
  String get p20Yesterday => 'Dün';

  @override
  String get p20AnnFooterTitle => 'Bölümünle ilgili başka duyuru yok.';

  @override
  String get p20AnnFooterBody =>
      'Yeni akademik takvim ve sınav bildirimleri yayınlandığında bildirim alacaksın.';

  @override
  String get p20RemPermTitle => 'Bildirim izni verilmedi';

  @override
  String get p20RemPermBody =>
      'Ders ve sınav hatırlatıcılarının zamanında çalabilmesi için sistem bildirim iznine ihtiyaç vardır.';

  @override
  String get p20RemOpenSettings => 'Ayarlardan aç';

  @override
  String p13PollArchiveCount(String n) {
    return '$n Anket Arşivde';
  }

  @override
  String get p13PollArchiveHeading => 'Sonuçlanan Anketler';

  @override
  String p13PollAvgOutOf(String avg) {
    return '5 üzerinden $avg puan';
  }

  @override
  String get p13PollAvgTitle => 'Ortalama Memnuniyet';

  @override
  String get p13PollChangeNote =>
      'Oy verdikten sonra fikrinizi değiştirebilirsiniz.';

  @override
  String get p13PollClosingSoon => 'Bitiyor';

  @override
  String get p13PollClubEmptyBody =>
      'Kulüp yöneticileri henüz oylamaya sunulmuş bir gündem paylaşmadı.';

  @override
  String get p13PollDateTime => 'Tarih ve saat';

  @override
  String get p13PollEditMode => 'Oyu değiştirme modu';

  @override
  String get p13PollEditNote =>
      'Seçiminizi değiştirdiğinizde önceki oyunuz otomatik olarak iptal edilir ve yeni tercihiniz işlenir.';

  @override
  String get p13PollEmptyClosedBody => 'Sonuçlanan oylamalar arşive taşınır.';

  @override
  String get p13PollEmptyMineBody =>
      'Oy kullandığınız anketler burada toplanır.';

  @override
  String get p13PollEmptyOpenBody =>
      'Yeni anketler açıldığında burada listelenecektir.';

  @override
  String get p13PollErrBody => 'Sunucu bağlantısı kurulamadı';

  @override
  String get p13PollFormType => 'Anket türü';

  @override
  String get p13PollHowTo => 'Nasıl oy kullanılır?';

  @override
  String get p13PollMin2 => 'En az 2 seçenek';

  @override
  String get p13PollOptionsTitle => 'Seçenekler';

  @override
  String get p13PollPickEndDate => 'Bitiş tarihi seç';

  @override
  String get p13PollPickEndTime => 'Bitiş saati seç';

  @override
  String get p13PollPrefs => 'Katılım tercihleri';

  @override
  String get p13PollPrevChoice => 'Önceki seçiminiz';

  @override
  String get p13PollQuick => 'Hızlı süre';

  @override
  String p13PollRankLabel(String n) {
    return '$n. Tercih';
  }

  @override
  String get p13PollRankReset =>
      'Sıralamayı sıfırlamak için seçeneğe tekrar dokunun.';

  @override
  String get p13PollRankTap => 'Seçmek için dokunun';

  @override
  String get p13PollRateCta => 'Puanla';

  @override
  String get p13PollSecretBody =>
      'Kimliğiniz hiçbir yönetici, kulüp temsilcisi veya öğrenci tarafından görüntülenemez.';

  @override
  String p13PollSelectedCount(String n, String max) {
    return '$n / $max seçildi';
  }

  @override
  String get p13PollTopOption => 'En çok oy alan seçenek';

  @override
  String get p13PollTypeMultiHint => 'Birden fazla seçenek işaretlenebilir';

  @override
  String get p13PollTypeRankedHint => 'Tercih sırasına göre dizme';

  @override
  String get p13PollTypeRatingHint => '1-5 yıldız ile puanlama';

  @override
  String get p13PollTypeSingleHint => 'Yalnızca tek bir seçenek belirlenebilir';

  @override
  String get p13PollVisAfterCloseSub =>
      'Süre dolana kadar hiçbir veri gösterilmez';

  @override
  String get p13PollVisAfterVoteSub =>
      'Kullanıcı oyunu kullandıktan sonra açılır';

  @override
  String get p13PollVisAlwaysSub => 'Tüm oylar canlı olarak izlenebilir';

  @override
  String get p13PollYourScore => 'Puanınız';

  @override
  String get p17MyCourses => 'Derslerim';

  @override
  String p11LikeCount(String count) {
    return '$count beğeni';
  }

  @override
  String get p11CaseSensitive => 'Büyük/küçük harf duyarlıdır';

  @override
  String get p12BasicInfo => 'Temel bilgiler';

  @override
  String get p12VisibilityAndJoin => 'Görünürlük ve katılım';

  @override
  String get p17ConflictIntro => 'Şu derslerle saatler çakışıyor:';

  @override
  String p17ColorSelected(String name) {
    return 'Seçili: $name';
  }

  @override
  String get p17WeekDay => 'Haftanın günü';

  @override
  String get p13PollViewAll => 'Tümünü Gör';

  @override
  String get p13PollReview => 'Oyu İncele';

  @override
  String get p13PollOpenBadge => 'Açık anket';

  @override
  String get p13PollClosedKicker => 'Kapanan anket';

  @override
  String p13PollDone(String n) {
    return 'Tamamlandı · $n oy';
  }

  @override
  String p13PollWinner(String name, String pct) {
    return 'Kazanan: $name (%$pct)';
  }

  @override
  String get p13PollOneVote => 'Tek oylu';

  @override
  String get p13PollHiddenResults => 'Gizli sonuçlar';

  @override
  String get p13PollVoteCta => 'Oyla';

  @override
  String get p13PollNoMoreActive => 'Bu kulübün başka aktif anketi yok.';

  @override
  String get p13PollNoMoreBody =>
      'Topluluk kararları ve etkinlik tercihleri burada yayımlanır.';

  @override
  String get p04DiscoverSub => 'Kampüsün nabzını ve anlık paylaşımları yakala';

  @override
  String get p04SearchHint => 'Kampüste ara: kulüpler, etkinlikler, kişiler...';

  @override
  String get p04ChipAll => 'Tümü';

  @override
  String get p04SuggestTitle => 'Tanıyor Olabilirsin';

  @override
  String get p04SuggestSeeAll => 'Tümünü Gör';

  @override
  String get p04FollowAction => 'Takip Et';

  @override
  String get p04FollowingState => 'Takiptesin';

  @override
  String get p04FeedTitle => 'Öğrenci Akışı';

  @override
  String p04LikeCount(String count) {
    return '$count beğeni';
  }

  @override
  String get p11UnavailableBody =>
      'Bu topluluk geçici olarak dondurulmuştur veya inceleme altındadır.';

  @override
  String get p11UnderReview => 'İncelemede';

  @override
  String get p12ConsentBold => 'topluluk ilkelerine';

  @override
  String get p03NotifLoadFailedBody =>
      'Son güncellemeler sunucu ile eşitlenemedi. Lütfen bağlantınızı kontrol edin.';

  @override
  String p03NotifShortDay(String n) {
    return '$n gün';
  }

  @override
  String p05SearchLikes(String n) {
    return '$n beğeni';
  }

  @override
  String get p05SearchErrorTitle => 'Yüklenemedi';

  @override
  String get p05SearchErrorBody =>
      'Arama sonuçları alınırken bir bağlantı hatası oluştu.';

  @override
  String get p13PollDistribution => 'Seçenek Dağılımı';

  @override
  String get p13PollWinnerOption => 'Kazanan Seçenek';

  @override
  String get p13PollRatingSummary => 'Puanlama özeti';

  @override
  String get p13PollOutOf5 => '5 üzerinden';

  @override
  String get p13MenuRated => 'Değerlendirmeniz kaydedildi. Teşekkürler!';

  @override
  String get p04CropProfileTitle => 'Fotoğrafı kırp';

  @override
  String get p04CropPostTitle => 'Gönderi fotoğrafı';

  @override
  String get p04CropLogoTitle => 'Kulüp logosu';

  @override
  String get p04CropCoverTitle => 'Kapak fotoğrafı';

  @override
  String get p04CropChatTitle => 'Sohbet görseli';

  @override
  String get p04CropHint => 'Sürükle ve yakınlaştır';

  @override
  String get p04CropRotate => 'Döndür';

  @override
  String get p04CropReset => 'Sıfırla';

  @override
  String get p04CropScale => 'Fotoğraf ölçeği';

  @override
  String get p04CropCrop => 'Kırp';

  @override
  String get p04CropError => 'Fotoğraf işlenemedi. Başka bir fotoğraf dene.';

  @override
  String get p04CropPreviewProfile => 'Profilde böyle görünecek';

  @override
  String get p04CropPreviewFeed => 'Akışta böyle görünecek';

  @override
  String get p04CropPreviewTitle => 'Önizleme';

  @override
  String get p04CropPreviewClubPage => 'Kulüp sayfası';

  @override
  String get p04CropPreviewClubCard => 'Kulüp kartı';

  @override
  String get p04CropRemoveCover => 'Kapağı kaldır';

  @override
  String get p04SrcTitle => 'Fotoğraf';

  @override
  String get p04SrcGallery => 'Galeriden seç';

  @override
  String get p04SrcCamera => 'Fotoğraf çek';

  @override
  String get p04SrcRemove => 'Fotoğrafı kaldır';

  @override
  String get p04Recrop => 'Yeniden kırp';

  @override
  String get p04PostNotFound =>
      'Gönderi bulunamadı (silinmiş veya gizlenmiş olabilir)';

  @override
  String get p04PostSharing => 'Paylaşılıyor...';

  @override
  String get p04PostPhotoNone => 'Görsel seçilmedi';

  @override
  String get p04PostFormatHint => '4:5 dikey format önerilir';

  @override
  String get p04ContentWarning => 'İçerik uyarısı';

  @override
  String get p23AddPeople => 'Kişi ekle';

  @override
  String get p23Selected => 'Seçilen katılımcılar';

  @override
  String get p23MinTwo => 'En az 2 kişi';

  @override
  String get p26OnceCaption => 'Bu fotoğrafı yalnızca bir kez görebilirsin.';

  @override
  String p09BlockNamed(String name) {
    return '$name Engelle';
  }

  @override
  String get p09MemberOptions => 'Üye seçenekleri';

  @override
  String p09MemberRemoved(String name) {
    return '$name gruptan çıkarıldı';
  }

  @override
  String get p09MediaLoading => 'Yükleniyor...';

  @override
  String get p09MediaEmptyBody =>
      'Paylaşılan fotoğraflar ve videolar burada görünür.';

  @override
  String get p09MediaErrorTitle => 'Hata oluştu';

  @override
  String get p09MediaErrorBody => 'Medya yüklenemedi.';

  @override
  String get p09ClubPageSub => 'Etkinlikler ve projeler';

  @override
  String get p09MembersLoadFailed => 'Üye listesi alınamadı.';

  @override
  String get p10AlbumTitle => 'Albüm';

  @override
  String p10AlbumCount(String n) {
    return '$n albüm';
  }

  @override
  String get p10ItemUnit => 'öğe';

  @override
  String get p10LimitedBody =>
      'Sohbete göndermek için kütüphanenden ek fotoğraflar seçebilirsin.';

  @override
  String get p10DeniedBody =>
      'Fotoğraf ve video gönderebilmek için uygulama ayarlarından galeri erişimine izin vermelisin.';

  @override
  String get p10GalleryEmpty => 'Galeride fotoğraf ya da video yok.';

  @override
  String p10SelCount(String n, String max) {
    return '$n / $max';
  }

  @override
  String get p10SelWord => 'seçildi';

  @override
  String p10TileSelected(String n) {
    return 'Seçildi, sıra $n';
  }

  @override
  String get p10VideoPrepareSub => 'Sıkıştırılıyor ve önbelleğe alınıyor';

  @override
  String get p10CloseNotice => 'Bildirimi kapat';

  @override
  String get p01LgReview => 'Sözleşmeleri tekrar incele';

  @override
  String get p14ErrorTitle => 'Yüklenemedi, tekrar dene';

  @override
  String get p14ErrorBody => 'Sunucuyla bağlantı kurulurken bir sorun oluştu.';

  @override
  String get p14OfflineStrip =>
      'İnternet bağlantısı yok · Kayıtlı veriler gösteriliyor';

  @override
  String get p14EmptyUpcomingBody2 =>
      'Kampüsteki kulüp etkinliklerini inceleyip hemen katılabilirsin.';

  @override
  String get p14EmptyPastBody2 =>
      'Daha önce katıldığın veya tamamlanan etkinlikler burada arşivlenir.';

  @override
  String get p14EmptyCreatedBody2 =>
      'Kulübünle planladığın atölye, seminer veya buluşmaları buradan yönet.';

  @override
  String get p14Detail => 'Detay';

  @override
  String get p14Attended => 'Katıldın';

  @override
  String get p14WithdrawRequest => 'İsteği geri çek';

  @override
  String get p14StatusGoing => 'Katılıyor';

  @override
  String p18ClassYear(String n) {
    return '$n. Sınıf';
  }

  @override
  String get p18FollowErrorTitle => 'Bağlantı hatası';

  @override
  String get p18FollowersEmptyBody =>
      'Profiliniz aktifleştikçe arkadaşlarınız sizi burada takip etmeye başlayacak.';

  @override
  String get p18FollowingEmptyBody =>
      'İlginizi çeken öğrencileri ve kulüp üyelerini takip edin, kampüsteki paylaşımları kaçırmayın.';

  @override
  String get p18FollowNoMatchBody =>
      'Aramanızla eşleşen kullanıcı bulunamadı. Yazımı kontrol edip tekrar arayabilirsiniz.';

  @override
  String p18AllFollowers(String n) {
    return 'Tüm takipçiler ($n)';
  }

  @override
  String p18AllFollowing(String n) {
    return 'Takip edilenler ($n)';
  }

  @override
  String get p19AcademicInfo => 'Akademik Bilgiler';

  @override
  String get p19ShowEmailDesc =>
      'Profilinizi ziyaret eden öğrenciler e-posta adresinizi görebilir.';

  @override
  String get p19LangSystemDesc => 'Cihazınızın varsayılan dilini kullanır';

  @override
  String get p19CrashReportsShort =>
      'Uygulama hata verdiğinde anonim bir hata raporu gönderilir.';

  @override
  String get p19LogoutAllSub =>
      'Diğer açık telefon ve tarayıcı oturumlarını kapatır.';

  @override
  String get p05NewsLoadingMore => 'Yükleniyor';

  @override
  String get p05SavedDiscover => 'Haberleri Keşfet';

  @override
  String get p05SavedEmptyTitle2 => 'Henüz kaydettiğiniz bir haber yok.';

  @override
  String get p05SavedEmptyBody2 =>
      'Haber detayındaki işaretle haberleri buraya ekleyebilirsiniz.';

  @override
  String get p05ListErrorTitle => 'Yüklenemedi, tekrar dene';

  @override
  String get p05ListErrorBody =>
      'Sunucuyla bağlantı kurulurken bir sorun oluştu. Lütfen internet bağlantınızı kontrol edin.';

  @override
  String get p13SuppLoadFailed => 'Yüklenemedi';

  @override
  String get p13SuppFaqEmptyBody => 'Bu kategori için henüz makale eklenmedi.';

  @override
  String get p13SuppFaqNoMatchBody =>
      'Arama kriterlerinize uygun sonuç bulunamadı.';

  @override
  String get p13SuppTicketsEmptyBody =>
      'Aktif veya geçmiş bir destek kaydınız bulunmuyor.';

  @override
  String get p13SuppFeedbackSub => 'Uygulama deneyiminizi puanlayın';

  @override
  String get p13SuppBoardSub => 'Yeni özellik fikirlerinizi iletin';

  @override
  String get p02IdLabel => 'E-posta / Öğrenci No';

  @override
  String get p17PickDateHelp => 'Tarih seçin';

  @override
  String get p20ProfileTitle => 'Profil';

  @override
  String get p20AboutNoBio => 'Biyografi belirtilmemiş.';

  @override
  String get p20AcademicInfo => 'Akademik Bilgiler';

  @override
  String get p20AvatarHidden =>
      'Profil fotoğrafın moderasyon nedeniyle gizlendi. Kampüs kurallarına uygun yeni bir portre yükleyene kadar adının baş harfleri görüntülenir.';

  @override
  String get p20BlockInfo =>
      'Engellediğiniz kişinin gönderilerini görmezsiniz ve onunla mesajlaşamazsınız.';

  @override
  String get p20ReportSendHint => 'Durumu kısaca açıklayabilirsiniz...';

  @override
  String get p20PrefPollsSub => 'Öğrenci ve personel anketleri';

  @override
  String get p20PrefDetailHead =>
      'Kategorilere ait alt bildirim türlerini tek tek yönetin. Ana anahtarı kapattığınızda ilgili alt bildirimler sessize alınır.';

  @override
  String get p20PrefDetailSub => 'Alt kategoriler ve bildirim türleri';

  @override
  String get p20PrefOffTag => 'Devre dışı';

  @override
  String get p20PrefMsgGroupSub => 'Anlık haberleşme';

  @override
  String get p20PrefEventsGroupSub => 'Takvim ve buluşmalar';

  @override
  String get p20PrefClubsGroupSub => 'Topluluk hareketleri';

  @override
  String get p20PrefSubDirect => 'Birebir özel sohbetler';

  @override
  String get p20PrefSubGroup => 'Ders ve kulüp grup konuşmaları';

  @override
  String get p20PrefSubEventReminder => 'Başlamadan 1 saat önce';

  @override
  String get p20PrefSubEventUpdate => 'Tarih, saat veya konum güncellemeleri';

  @override
  String get p20PrefSubEventAdmission => 'Kulüp etkinlik katılım onayları';

  @override
  String get p20PrefSubClubPost =>
      'Kulüplerin paylaştığı duyuru ve fotoğraflar';

  @override
  String get p20PrefSubClubRole => 'Yönetim ve üyelik yetkilendirmeleri';

  @override
  String get p20PrefSubClubJoin => 'Katılım istekleri ve yanıtları';

  @override
  String get p20PrefLoadFail => 'Yüklenemedi';

  @override
  String get p20PrefTapRetry => 'Yeniden denemek için dokunun.';

  @override
  String p20PrefRemSub(String m) {
    return 'Ders başlamadan $m dk önce yerel alarm/bildirim';
  }

  @override
  String get p20QuietPickHelp => 'Saat seçin';

  @override
  String get p20ThemeSystemSub => 'Cihaz ayarlarına göre otomatik';

  @override
  String get p20HalfDay => 'Yarım gün';

  @override
  String get p20AllDay => 'Tam gün';

  @override
  String p20RangeDays(String n) {
    return '$n gün';
  }

  @override
  String p20RangeWeeks(String n) {
    return '$n hafta';
  }

  @override
  String get p20RemDaySub => 'Sınavdan bir gün önce hatırlat';

  @override
  String get p20RemHourSub =>
      'Uygulama kapalıyken de gelir; Akademik duyuru tercihine bağlıdır';

  @override
  String get p13SugSortTop => 'En çok oy';

  @override
  String get p13SugAdd => 'Öneri ekle';

  @override
  String get p13SugApprovalNote =>
      'Öneriler yönetici onayından sonra yayımlanır.';

  @override
  String get p13SugVoteHint => 'Oy vermek için dokun';

  @override
  String get p13SugVoted => 'Oyunu kaydettin';

  @override
  String get p04PostsEmptyBody => 'Paylaştığın fotoğraflar burada listelenir.';

  @override
  String get p04PostsLoadFail => 'Yüklenemedi, tekrar dene';

  @override
  String get p04FeedErrTitle => 'Yüklenemedi';

  @override
  String get p04FeedErrBody => 'Bağlantını kontrol edip tekrar dene.';

  @override
  String get p09ForwardDirect => 'Bireysel sohbet';

  @override
  String get p03HomeBrandSub => 'Bağımsız öğrenci uygulaması';

  @override
  String get p03HomeQuickTitle => 'Hızlı erişim';

  @override
  String get p03HomeQuickEvents => 'Etkinlikler';

  @override
  String get p03HomeQuickSchedule => 'Program';

  @override
  String get p03HomeFeaturedNews => 'Öne çıkan haberler';

  @override
  String get p03HomeUpcoming => 'Yaklaşan etkinlikler';

  @override
  String get p03HomeMealHeroTitle => 'Günün Yemek Menüsü';

  @override
  String p03HomeLunchCount(String n) {
    return 'Öğle Yemeği • $n çeşit';
  }

  @override
  String get p03HomeMenuDetail => 'Menü Detayı';

  @override
  String p03HomeHosts(String club) {
    return '$club Düzenliyor';
  }

  @override
  String get p04CropCenter => 'Ortala';

  @override
  String get p04SrcSizeTitle => 'Dosya boyutu yüksek';

  @override
  String get p18ProfileTitle => 'Profilim';

  @override
  String get p18ProfileLoadFailed => 'Yüklenemedi, tekrar dene';

  @override
  String p15PercentFull(String n) {
    return '%$n dolu';
  }

  @override
  String get p15ChatSub => 'Katılımcılarla ve organizatörle tanış';

  @override
  String get p15ChatLockedSub => 'Yalnızca onaylı katılımcılara özel';

  @override
  String get p15AboutTitle => 'Etkinlik hakkında';

  @override
  String get p15AttOpenHint =>
      'Yoklamanın alınması için salondaki QR kodunu tara ya da organizatörün duyurduğu kodu gir.';

  @override
  String get p15CheckedInBody => 'Etkinliğe katılımın kaydedildi.';

  @override
  String get p15CancelledNotice => 'Bu etkinlik iptal edildi.';

  @override
  String get p15StatusInterested => 'İlgileniyor';

  @override
  String p15AttendeesLine(String going, String interested) {
    return '$going kişi katılıyor · $interested ilgileniyor';
  }

  @override
  String get p13SuppFaqHeading => 'Sık sorulan sorular';

  @override
  String get p13SuppToday => 'Bugün';

  @override
  String get p23GroupNameHint => 'Örn. Mühendislik Proje Ekibi...';

  @override
  String p09GradeYear(String n) {
    return '$n. Sınıf';
  }

  @override
  String get p14UpcomingOther => 'Yaklaşan diğer günler';

  @override
  String get p14ErrorBodyCache =>
      'Sunucuyla bağlantı kurulurken bir sorun oluştu. Çevrimdışı önbellek listeleniyor.';

  @override
  String get p14Completed => 'Tamamlandı';

  @override
  String get p15LockedBadge => 'Kilitli';

  @override
  String get p15CancelledBody => 'Katılımcılara bildirim gönderilir.';

  @override
  String get eventEndedNotice => 'Bu etkinlik sona erdi.';

  @override
  String get eventEndedBody => 'Katılım ve başvurular kapandı.';

  @override
  String get notifEventEnded => 'Sona erdi';

  @override
  String get notifEventCancelled => 'İptal edildi';

  @override
  String get p15WontHappen => 'Gerçekleşmeyecek';

  @override
  String get p15AnswerHint => 'Kısaca bahset...';

  @override
  String get p15NoteHint => 'Varsa iletmek istediğin ek bir not...';

  @override
  String p15CodeChars(String n) {
    return '$n karakter';
  }

  @override
  String get p15LeaveHint =>
      'İstediğin zaman katılım durumunu değiştirebilirsin.';

  @override
  String get p15SettingsSub => 'Katılım türü, kontenjan ve kayıtlar';

  @override
  String get p15ClearField => 'Temizle';

  @override
  String get p18SecPrefs => 'Uygulama tercihleri';

  @override
  String get p18SecAccount => 'Hesap & Güvenlik';

  @override
  String get p18SecAbout => 'Hakkında & Destek';

  @override
  String get p18CounterClubs => 'Kulüp';

  @override
  String get p18CounterEvents => 'Etkinlik';

  @override
  String get p18ClearSearch => 'Aramayı temizle';

  @override
  String p18NavUnread(String n) {
    return '$n okunmamış';
  }

  @override
  String get p19PushOffShort => 'Kapalı';

  @override
  String get p19SaveFailedSub => 'Bağlantı hatası oluştu.';

  @override
  String get p20GradeLevel => 'Sınıf Düzeyi';

  @override
  String get p21ChanChatDesc =>
      'Birebir ve grup sohbet mesajları. Ses ve titreşimle gelir.';

  @override
  String get p21ChanEventDesc =>
      'Etkinlik hatırlatmaları, değişiklikler ve katılım sonuçları.';

  @override
  String get p21ChanAnnouncementDesc =>
      'Haber, duyuru, kulüp ve sistem bildirimleri.';

  @override
  String get p21ChanSocialDesc => 'Beğeni ve takip bildirimleri. Sessiz gelir.';

  @override
  String get p21ChanPollDesc => 'Yeni anketler ve sonuçları.';

  @override
  String get p21ChanAcademicDesc =>
      'Ders ve sınav saatinden önceki yerel hatırlatmalar.';

  @override
  String get p21HelpTitle => 'Bildirimler çalışmıyor mu?';

  @override
  String get p21HelpLink => 'Bildirimler çalışmıyor mu?';

  @override
  String get p21HelpAllGood => 'Bu cihazda her şey yolunda görünüyor.';

  @override
  String get p21HelpSomeIssue =>
      'Bildirim almanızı engelleyen bir şey var. Aşağıdaki adımlara bakın.';

  @override
  String get p21HelpPermTitle => 'Bildirim izni';

  @override
  String get p21HelpPermOk => 'Uygulama bildirimleri açık.';

  @override
  String get p21HelpPermOff =>
      'Bildirimler sistem ayarlarından kapatılmış. Açmadan bildirim alamazsınız.';

  @override
  String get p21HelpChanTitle => 'Bildirim kategorileri';

  @override
  String get p21HelpChanChat =>
      'Mesajlar kategorisi sistem ayarlarından kapatılmış. Açın, yoksa yeni mesaj bildirimi gelmez.';

  @override
  String get p21HelpChanOther =>
      'Bazı bildirim kategorileri sistem ayarlarından kapatılmış. İstediklerinizi açın.';

  @override
  String get p21HelpDeviceTitle => 'Bu cihazın kaydı';

  @override
  String get p21HelpDeviceOk => 'Cihazınız bildirim göndermemiz için kayıtlı.';

  @override
  String get p21HelpDeviceBad =>
      'Cihazınız henüz kayıtlı değil. İnternet bağlantınızı kontrol edip yeniden kaydedin.';

  @override
  String get p21HelpDeviceUnsupported =>
      'Bu sürümde anlık bildirim yapılandırılmamış.';

  @override
  String get p21HelpDeviceRetry => 'Yeniden kaydet';

  @override
  String get p21HelpBatteryTitle => 'Pil ve arka plan';

  @override
  String get p21HelpBatteryOem =>
      'Telefonunuz pili korumak için uygulamayı kapatabilir. Uygulama kapalıyken bildirim gelmiyorsa pil ayarlarında BÜ Kampüs için kısıtlamayı kaldırın, varsa Otomatik başlatma iznini açın ve uygulamayı son uygulamalardan kilitleyin.';

  @override
  String get p21HelpBatteryGeneric =>
      'Uygulama kapalıyken bildirim gelmiyorsa pil ayarlarında BÜ Kampüs için kısıtlamayı kaldırın. Uygulamayı son uygulamalardan kaydırarak kapatmak bazı telefonlarda bildirimleri durdurur.';

  @override
  String get p21HelpBatteryOpen => 'Pil ayarlarını aç';

  @override
  String get p21HelpFooter =>
      'Sessiz saatler ve bildirim tercihleri de bildirimi engelleyebilir. Bunları Bildirim tercihlerinden kontrol edin.';

  @override
  String get p22SaveGalleryTitle => 'Fotoğrafları galeriye kaydet';

  @override
  String get p22SaveGalleryDesc =>
      'Sohbette aldığın ve gönderdiğin fotoğraflar galerine kaydedilir; tek gösterimlik fotoğraflar kaydedilmez.';

  @override
  String get p22SaveGalleryCloud =>
      'Galerin bulut yedeklemesi açıksa fotoğraflar oraya da gidebilir.';

  @override
  String get p22SaveDeniedToast =>
      'Fotoğraflar galeriye kaydedilemedi: izin verilmedi. Ayarlardan izin verebilirsin.';

  @override
  String get p22OpenSettings => 'Ayarlar';

  @override
  String get p26PrefPollsNeedsParents =>
      'Duyurular veya Kulüpler kapalıysa ilgili anket bildirimleri gelmez';

  @override
  String get p32ExportShareFailed =>
      'Verileriniz paylaşım için hazırlanamadı. Lütfen tekrar deneyin.';

  @override
  String get p31ChatPlaceholderBlocked =>
      'Engellediğiniz kullanıcının mesajı gizlendi';

  @override
  String get p31ChatPlaceholderUnreadable => 'Bu mesaj görüntülenemiyor';

  @override
  String p31ChatMsgTooLong(String max) {
    return 'Mesaj en fazla $max karakter olabilir.';
  }

  @override
  String get p31ChatRemovedToast => 'Bu sohbetten çıkarıldınız.';

  @override
  String get p30AutosaveConsentTitle => 'Fotoğraflar galeriye kaydedilsin mi?';

  @override
  String get p30AutosaveConsentBody =>
      'Birebir sohbetlerde aldığın ve gönderdiğin fotoğraflar telefonunun galerisine (BU Kampus albümü) kaydedilir. Tek gösterimlik fotoğraflar kaydedilmez. Bunu istediğin zaman buradan kapatabilirsin.';

  @override
  String get p30AutosaveConsentOk => 'Aç';

  @override
  String get p60EditHome => 'Ana sayfayı düzenle';

  @override
  String get p60EditHint =>
      'Bölümleri sürükleyerek sıralayın, anahtarla gösterin veya gizleyin.';

  @override
  String get p60Done => 'Bitti';

  @override
  String get p60ResetDefault => 'Varsayılana dön';

  @override
  String get p60SectionClasses => 'Bugünkü dersler';

  @override
  String p60MoveUp(String name) {
    return '$name bölümünü yukarı taşı';
  }

  @override
  String p60MoveDown(String name) {
    return '$name bölümünü aşağı taşı';
  }

  @override
  String get p60Shortcuts => 'Kısayolları seç';

  @override
  String p60ShortcutsCount(String n) {
    return '$n kısayol';
  }

  @override
  String get p60ShortcutsHint =>
      'En fazla 5 kısayol seçin; sırayı sürükleyerek değiştirin.';

  @override
  String get p60EmptyTitle => 'Ana sayfan boş';

  @override
  String get p60EmptyAction => 'Bölüm ekle';

  @override
  String get p60NoClassesToday => 'Bugün dersin yok';

  @override
  String get p60NoTimetable => 'Ders programı eklenmemiş';

  @override
  String get p60ShortSearch => 'Arama';

  @override
  String get p67ChatBgTitle => 'Sohbet arka planı';

  @override
  String get p67ChatBgPattern => 'Desen';

  @override
  String get p67ChatBgSoft => 'Hafif';

  @override
  String get p67ChatBgStrong => 'Orta';

  @override
  String get p67ChatBgPlain => 'Düz';

  @override
  String get p67ChatBgPreviewIn => 'Selam, derste görüşürüz.';

  @override
  String get p67ChatBgPreviewOut => 'Tamam, görüşürüz.';

  @override
  String get p67SettingsChats => 'Sohbetler';

  @override
  String get p67AttachAllowPhotos => 'Fotoğraflara erişime izin ver';

  @override
  String p67PickerSend(String n) {
    return 'Gönder ($n)';
  }

  @override
  String get p66HelpPrompt => 'Giriş yapamıyor musunuz?';

  @override
  String get p66HelpAction => 'Yardım al';

  @override
  String get p66HelpSub =>
      'Giriş yapamıyorsanız bize yazın. Doğrulama kodunu e-postanıza göndereceğiz.';

  @override
  String get p66FieldName => 'Ad soyad';

  @override
  String get p66FieldEmail => 'E-posta';

  @override
  String get p66FieldTopic => 'Konu';

  @override
  String get p66FieldMessage => 'Mesajınız';

  @override
  String get p66ErrName => 'Ad soyadınızı girin.';

  @override
  String get p66ErrEmail => 'Geçerli bir e-posta adresi girin.';

  @override
  String get p66ErrMsgShort => 'Mesaj en az 10 karakter olmalı.';

  @override
  String get p66ErrMsgLong => 'Mesaj en fazla 2000 karakter olabilir.';

  @override
  String get p66ReplyNote => 'Yanıtı e-postanıza göndeririz.';

  @override
  String get p66CodeSix => '6 haneli kodu girin.';

  @override
  String get p66CodeBad => 'Kod hatalı veya süresi dolmuş.';

  @override
  String get p66TrackTitle => 'Talebiniz';

  @override
  String get p66TrackYou => 'Siz';

  @override
  String get p66TrackStaff => 'Destek ekibi';

  @override
  String get p66TrackHint => 'Yanıtınızı yazın';

  @override
  String get p66TrackSend => 'Gönder';

  @override
  String get p66TrackClosed => 'Bu talep kapatıldı.';

  @override
  String get p66MyTicket => 'Talebim';

  @override
  String get p66AboutBody =>
      'Bingöl Üniversitesi öğrencileri ve personeli için geliştirilen bağımsız bir öğrenci uygulamasıdır.';

  @override
  String get p67AttachRecent => 'Son fotoğraflar';

  @override
  String get p67AttachOnceHint =>
      'Tek gösterimlik göndermek için fotoğrafı seçtikten sonra 1 simgesine dokunun.';

  @override
  String get p67AttachGrant => 'İzin ver';

  @override
  String get p51ClubsEmpty => 'Henüz kulüp yok.';

  @override
  String get p51ClubsLoadFailed => 'Yüklenemedi, tekrar dene';

  @override
  String get p51Managed => 'Yönettiklerim';

  @override
  String get p51RoleMember => 'Üye';

  @override
  String get p51AwaitingReply => 'Yanıt bekleniyor';

  @override
  String p51ApplyDate(String date) {
    return 'Başvuru tarihi: $date';
  }

  @override
  String get p51AboutFounded => 'Kuruluş';

  @override
  String get p51CreateClubTitle => 'Kulüp oluştur';

  @override
  String get p51Create => 'Oluştur';

  @override
  String get p51JoinApproval => 'İstek ile';

  @override
  String get p51DescLabel => 'Açıklama';

  @override
  String get p51DescHint =>
      'Kulübünüzün amacını ve hedeflerini kısaca anlatın…';

  @override
  String get p51AddJoinQuestion => 'Katılma sorusu ekle';

  @override
  String get p64CropDone => 'Bitti';

  @override
  String get p64FeedOffline =>
      'Çevrimdışısın. Gösterilen gönderiler eski olabilir.';

  @override
  String get p67ChatBgDensity => 'Yoğunluk';

  @override
  String get p67ChatBgApply => 'Uygula';

  @override
  String get p67ChatBgReset => 'Varsayılana dön';

  @override
  String get p67ChatBgStyleCampus => 'Kampüs';

  @override
  String get p67ChatBgStyleStudy => 'Ders';

  @override
  String get p67ChatBgStyleSocial => 'Sosyal';

  @override
  String get p67ChatBgStyleScience => 'Bilim';

  @override
  String get p67ChatBgStyleGeometry => 'Geometri';

  @override
  String get p67ChatBgStyleLabel => 'Desen';

  @override
  String p67PickerLimit(String max) {
    return 'En fazla $max öğe seçebilirsiniz.';
  }

  @override
  String get p51EvEmptyDayBody => 'Başka bir gün seç ya da kulüplere göz at.';

  @override
  String get p51EvBrowseAll => 'Tüm kulüpleri keşfet';

  @override
  String get p51EvOffline => 'Çevrimdışısın. Kayıtlı etkinlikler gösteriliyor.';

  @override
  String get p69WeeklyFlow => 'Haftalık Akış';

  @override
  String p69WeekN(String n) {
    return '$n. Hafta';
  }

  @override
  String get p69Done => 'Tamamlandı';

  @override
  String get p69LastSession => 'Son oturum';

  @override
  String p69Hours(String h) {
    return '$h saat';
  }

  @override
  String p69TodayTotal(String n, String hours) {
    return 'Bugün toplam $n oturum ($hours)';
  }

  @override
  String get p69ExamCalendar => 'Sınav Takvimi';

  @override
  String get p69Now => 'Şimdi';

  @override
  String get p69ExamName => 'Sınav adı';

  @override
  String get p69ExamNameHint => 'Örn. Veri Yapıları Vize';

  @override
  String get p69ExamNameErr => 'Sınav adı gerekli.';

  @override
  String get p69PickCourse => 'Ders seçin';

  @override
  String get p69DateLabel => 'Tarih';

  @override
  String get p69TimeLabel => 'Saat';

  @override
  String get p69ExamNote =>
      'Sınavdan 1 gün önce yerel, 2 saat önce push bildirimi alırsın.';

  @override
  String p69SemesterTerm(String name) {
    return '$name yarıyılı';
  }

  @override
  String get p69TodayJump => 'Güne Dön';

  @override
  String get p69Events => 'Akademik Olaylar';

  @override
  String p69Records(String n) {
    return '$n Kayıt';
  }

  @override
  String get p69ExamReminder => 'Sınav hatırlatması';

  @override
  String get p69ExamReminderSub =>
      'Sınavdan 1 gün önce telefonunda, 2 saat önce bildirim olarak.';

  @override
  String p69ClassReminderSub(String n) {
    return 'Dersten $n dakika önce.';
  }

  @override
  String get p69Duration => 'Süre';

  @override
  String get p69Classes => 'Dersler';

  @override
  String get p69RemindersFooter => 'Hatırlatmalar bu telefonda oluşturulur.';

  @override
  String get p69PermOff =>
      'Bildirim izni kapalı. Hatırlatma almak için ayarlardan izin ver.';

  @override
  String get p69NoExams => 'Henüz sınav eklemedin.';

  @override
  String get p68New => 'Yeni';

  @override
  String get p68FormKind => 'Tür';

  @override
  String get p68OptionsLabel => 'Seçenekler (2-12)';

  @override
  String get p68PickDate => 'Tarih seç';

  @override
  String get p68Retract => 'Oyumu geri çek';

  @override
  String get p68MyVote => 'Senin oyun';

  @override
  String p68TicketNo(String n) {
    return 'Bilet #$n';
  }

  @override
  String get p68Required => 'Zorunlu';

  @override
  String get p68SubjectLabel => 'Konu';

  @override
  String get p68SubjectHint => 'Kısaca ne oldu?';

  @override
  String get p68SubjectMin => 'Konu en az 3 karakter olmalı.';

  @override
  String get p68MessageLabel => 'Mesaj';

  @override
  String get p68MessageHint => 'Sorunu veya talebini adım adım detaylandır…';

  @override
  String get p68ReplyNote => 'Yanıtı bildirim ve e-posta ile alırsın.';

  @override
  String get p68CategoryLabel => 'Kategori';

  @override
  String get p68ReplyHint => 'Yanıtını yaz';

  @override
  String get p68Staff => 'Destek';

  @override
  String get p68NoTickets => 'Henüz talebin yok.';

  @override
  String get p68SugTitle => 'Öneriler';

  @override
  String get p68SugSend => 'Öneri gönder';

  @override
  String get p68SugTop => 'En çok oylanan';

  @override
  String get p68SugNew => 'Yeni';

  @override
  String get p68SugEmpty => 'Henüz öneri yok.';

  @override
  String get p51EvAttOpen => 'Yoklama açık';

  @override
  String get p51EvScanQr => 'QR ile yoklama ver';

  @override
  String get p51EvGoingYou => 'Katılıyorsun';

  @override
  String get p51EvLblDate => 'Tarih';

  @override
  String get p51EvLblTime => 'Saat';

  @override
  String get p51EvLblPlace => 'Yer';

  @override
  String get p51EvLblAttendees => 'Katılımcı';

  @override
  String p51EvPeople(String count) {
    return '$count kişi';
  }

  @override
  String get p51EvQrTitle => 'Yoklama QR';

  @override
  String get p51EvReqTitle => 'Başvurular';

  @override
  String get p51EvTabPending => 'Bekleyen';

  @override
  String get p51EvTabApproved => 'Onaylanan';

  @override
  String get p51EvTabRejected => 'Reddedilen';

  @override
  String p51EvQuota(String cap, String going) {
    return 'Kontenjan $cap · $going onaylı';
  }

  @override
  String p51EvQuotaGoing(String n) {
    return '$n onaylı';
  }

  @override
  String get p51EvQuotaNote => 'Kontenjan dolduğunda yeni istek onaylanamaz.';

  @override
  String p51EvPresentAbsent(String present, String absent) {
    return '$present geldi · $absent gelmedi';
  }

  @override
  String p51EvTotalPeople(String count) {
    return 'Toplam $count kişi';
  }

  @override
  String get p68TypeMulti => 'Çoklu';

  @override
  String get p68TypeRanked => 'Sıralı';

  @override
  String get p51EvAttList => 'Yoklama listesi';

  @override
  String get p51EvClubOnly => 'Etkinlikler kulüpler adına açılır.';

  @override
  String get p60Today => 'Bugün kampüste';

  @override
  String get p60NextClass => 'Sıradaki ders';

  @override
  String get p60UpcomingExam => 'Yaklaşan sınav';

  @override
  String get p60OpenMenu => 'Menüyü aç';

  @override
  String get p60NoNews => 'Henüz haber yok.';

  @override
  String get p60NoAnnouncements => 'Henüz duyuru yok.';

  @override
  String p60Classroom(String room) {
    return 'Derslik $room';
  }

  @override
  String get p60EmptySub => 'Gösterilecek bir bölüm seçmediniz.';

  @override
  String get p60Selected => 'Seçilen kısayollar (sıralama)';

  @override
  String get p60AllShortcuts => 'Tüm kısayollar';

  @override
  String p60Remove(String name) {
    return 'Kaldır: $name';
  }

  @override
  String get p60ShortScheduleFull => 'Ders programı';

  @override
  String p63NewsLastUpdate(String when) {
    return 'Son güncelleme: $when';
  }

  @override
  String get frqPrivateTitle => 'Gizli hesap';

  @override
  String get frqPrivateSub =>
      'Gizli hesapta yalnız onayladığın kişiler gönderilerini ve takipçi listeni görür. Mevcut takipçilerin kalır.';

  @override
  String get frqPrivateOffTitle => 'Hesap herkese açılsın mı?';

  @override
  String get frqPrivateOffBody =>
      'Bekleyen takip istekleri otomatik kabul edilir. Gönderilerini ve takipçi listeni herkes görebilir.';

  @override
  String get frqPrivateOffConfirm => 'Herkese aç';

  @override
  String get frqFollowRequested => 'İstek gönderildi';

  @override
  String get frqSemRequested =>
      'Takip isteği gönderildi. Geri çekmek için dokun';

  @override
  String get frqUnfollowTitle => 'Takibi bırak?';

  @override
  String get frqUnfollowBody => 'Bu kişiyi artık takip etmeyeceksin.';

  @override
  String get frqUnfollowBodyPrivate =>
      'Bu hesap gizli. Takibi bırakırsan yeniden istek göndermen gerekir.';

  @override
  String get frqUnfollowConfirm => 'Takibi bırak';

  @override
  String get frqCancelReqTitle => 'İsteği geri çek?';

  @override
  String get frqCancelReqBody =>
      'Takip isteğin geri çekilir. İstersen daha sonra yeniden gönderebilirsin.';

  @override
  String get frqCancelReqConfirm => 'İsteği geri çek';

  @override
  String get frqLockedTitle => 'Bu hesap gizli';

  @override
  String get frqLockedBody => 'Gönderilerini görmek için takip isteği gönder.';

  @override
  String get frqLockedBodyRequested =>
      'İsteğin onaylanınca gönderileri görebilirsin.';

  @override
  String get frqReqTitle => 'Takip istekleri';

  @override
  String frqReqRow(String n) {
    return 'Takip istekleri ($n)';
  }

  @override
  String frqReqPending(String n) {
    return 'Bekleyen istekler ($n)';
  }

  @override
  String get frqReqAccept => 'Onayla';

  @override
  String get frqReqDecline => 'Sil';

  @override
  String frqReqAcceptSem(String name) {
    return '$name isteğini onayla';
  }

  @override
  String frqReqDeclineSem(String name) {
    return '$name isteğini sil';
  }

  @override
  String get frqReqEmpty => 'Bekleyen takip isteği yok.';

  @override
  String get frqNotifTypeFollow => 'Takip';

  @override
  String frqMsgReqRow(String n) {
    return 'Mesaj istekleri ($n)';
  }

  @override
  String get frqMsgReqTitle => 'Mesaj istekleri';

  @override
  String get frqMsgReqInfo =>
      'Seninle ortak kulübü ya da etkinliği olmayan, takip etmediğin kişilerden gelen mesajlar burada görünür. Kabul edene kadar gönderen mesajlarının okunup okunmadığını görmez. Yanıt yazarsan istek otomatik kabul edilir.';

  @override
  String get frqMsgReqAccept => 'Kabul et';

  @override
  String get frqMsgReqDecline => 'Sil';

  @override
  String get frqMsgReqGroupInvite => 'Grup daveti';

  @override
  String get frqMsgReqEmpty => 'Bekleyen mesaj isteği yok.';

  @override
  String get frqMsgReqDeclineGroupTitle => 'Grup daveti silinsin mi?';

  @override
  String get frqMsgReqDeclineGroupBody =>
      'Gruptan ayrılırsın ve seni ekleyen kişi bir daha ekleyemez.';

  @override
  String get frqMsgReqDeclineGroupConfirm => 'Daveti sil';

  @override
  String get homeBrandSubtitle => 'Bingöl Üniversitesi Kampüs Uygulaması';

  @override
  String get homeLibrary => 'Kütüphane';

  @override
  String get homeFeaturedSchedule => 'Ders Programı';

  @override
  String get homeFeaturedMenu => 'Yemek Menüsü';

  @override
  String get homeMenuRate => 'Menüyü puanla';

  @override
  String get homeMenuPhotoPending => 'Yeni görsel bekliyor';

  @override
  String get homeSearchFilters => 'Arama filtreleri';

  @override
  String get homeMore => 'Diğer';

  @override
  String get homeViewAll => 'Tümünü gör';

  @override
  String get homeJoinedEvents => 'Katıldığım etkinlikler';

  @override
  String get regTitle => 'Hesap oluşturun';

  @override
  String get regSubtitle =>
      'Adınızı, e-posta adresinizi ve şifrenizi girin. Doğrulama kodunuz e-posta adresinize gönderilir.';

  @override
  String get profileSetupTitle => 'Bölümünüzü seçin';

  @override
  String get profileSetupSubtitle =>
      'Bölümünüzü ve sınıfınızı bir kez girin; sonradan profilinizden değiştirebilirsiniz.';

  @override
  String get photoSetupTitle => 'Profil fotoğrafı eklemek ister misiniz?';

  @override
  String get photoSetupSubtitle =>
      'Diğer öğrenciler sizi daha kolay tanır. İstediğiniz zaman profilinizden ekleyebilir ya da değiştirebilirsiniz.';

  @override
  String get photoSetupPick => 'Fotoğraf seç';

  @override
  String get photoSetupChange => 'Değiştir';

  @override
  String get photoSetupSkip => 'Şimdilik atla';

  @override
  String get photoSetupAvatarSemantic => 'Profil fotoğrafı seç';

  @override
  String get avatarEdTitle => 'Fotoğrafı düzenle';

  @override
  String get avatarEdCancel => 'İptal';

  @override
  String get avatarEdDone => 'Bitti';

  @override
  String get avatarEdUndo => 'Geri al';

  @override
  String get avatarEdRedo => 'Yinele';

  @override
  String get avatarEdTabCrop => 'Kırp';

  @override
  String get avatarEdTabBg => 'Zemin';

  @override
  String get avatarEdTabFilter => 'Filtre';

  @override
  String get avatarEdTabAdjust => 'Ayarla';

  @override
  String get avatarEdRotateLeft => 'Sola döndür';

  @override
  String get avatarEdRotateRight => 'Sağa döndür';

  @override
  String get avatarEdMirror => 'Aynala';

  @override
  String get avatarEdReset => 'Sıfırla';

  @override
  String get avatarEdZoom => 'Yakınlaştırma';

  @override
  String get avatarEdAngle => 'Açı';

  @override
  String get avatarEdBgBlur => 'Bulanık';

  @override
  String get avatarEdBgWhite => 'Beyaz';

  @override
  String get avatarEdBgBlack => 'Siyah';

  @override
  String get avatarEdBgBrand => 'Marka';

  @override
  String get avatarEdBgNavy => 'Lacivert';

  @override
  String get avatarEdBgSand => 'Kum';

  @override
  String get avatarEdBgHint =>
      'Fotoğraf çerçeveden küçükse boşluk bu zeminle dolar.';

  @override
  String get avatarEdFOriginal => 'Orijinal';

  @override
  String get avatarEdFVivid => 'Canlı';

  @override
  String get avatarEdFCool => 'Soğuk';

  @override
  String get avatarEdFWarm => 'Sıcak';

  @override
  String get avatarEdFMono => 'Siyah-beyaz';

  @override
  String get avatarEdFFaded => 'Solgun';

  @override
  String get avatarEdBrightness => 'Parlaklık';

  @override
  String get avatarEdContrast => 'Kontrast';

  @override
  String get avatarEdSaturation => 'Doygunluk';

  @override
  String get avatarEdWarmth => 'Sıcaklık';

  @override
  String get avatarEdVignette => 'Vinyet';

  @override
  String get avatarEdStageSemantic =>
      'Fotoğraf düzenleme alanı. Sürükleyin, iki parmakla yakınlaştırın veya uzaklaştırın, çift dokunarak sığdırın.';

  @override
  String get photoEdTabRatio => 'Oran';

  @override
  String get photoEdRatioFree => 'Serbest';

  @override
  String get photoEdRatioHint =>
      'Çerçeve oranını seçin; fotoğraf buna göre kırpılır. Serbest, fotoğrafın kendi oranını korur.';

  @override
  String get avatarSheetTitle => 'Profil fotoğrafı';

  @override
  String get avatarRemoveTitle => 'Profil fotoğrafınız kaldırılsın mı?';

  @override
  String get avatarRemoveBody =>
      'Varsayılan görsel gösterilir. İstediğiniz zaman yeniden fotoğraf ekleyebilirsiniz.';

  @override
  String get avatarRemoveConfirm => 'Kaldır';

  @override
  String get avatarCropTitle => 'Fotoğrafı konumlandır';

  @override
  String get avatarCropConfirm => 'Onayla';

  @override
  String get avatarCropCancel => 'İptal';

  @override
  String get avatarCropHint =>
      'Yakınlaştırmak için iki parmakla sıkıştırın, konumlandırmak için sürükleyin. Profilde böyle görünür.';

  @override
  String get avatarUpdated => 'Profil fotoğrafınız güncellendi.';

  @override
  String get avatarRemoved => 'Profil fotoğrafınız kaldırıldı.';

  @override
  String get campusAbout => 'Hakkında';

  @override
  String get campusSort => 'Sırala';

  @override
  String get settingsAnalytics => 'Kullanım analizi';

  @override
  String get settingsAnalyticsSub =>
      'Uygulamayı iyileştirmek için ekranlarda geçirilen süre ve yapılan eylemler gibi kullanım bilgileri gönderilir. Mesaj içeriği, arama metni ve kişisel bilgiler gönderilmez. Kapatınca toplama durur, bekleyenler silinir.';

  @override
  String get chatSecureCaptured =>
      'Ekran kaydı sırasında bu içerik görüntülenemez.';

  @override
  String get chatSecureScreenshot =>
      'Ekran görüntüsü algılandı. Görüntü kapatıldı.';

  @override
  String get chatSecureProtectedTitle => 'Ekran yakalama koruması';

  @override
  String get chatSecureProtectedBody =>
      'Bu fotoğraf yalnızca bir kez görüntülenebilir ve korunmaktadır.';

  @override
  String get chatSecureUnsupportedTitle => 'Bu cihazda güvenli açılamıyor';

  @override
  String get chatSecureUnsupportedBody =>
      'Ekran yakalama koruması kurulamadığı için tek gösterimlik fotoğraf açılmadı ve görüntüleme hakkın kullanılmadı.';

  @override
  String get chatSecureRevokedBody =>
      'Ekran yakalama koruması devre dışı kaldığı için fotoğraf kapatıldı.';

  @override
  String get verifyEmailBannerTitle => 'E-postanızı doğrulayın';

  @override
  String get verifyEmailBannerBody =>
      'Doğrulanana kadar bazı işlemler (gönderi, mesaj, takip...) kapalıdır.';

  @override
  String get verifyEmailBannerCta => 'Kodu gir';

  @override
  String get verifySheetTitle => 'E-postanızı doğrulayın';

  @override
  String get verifySheetBody => 'E-postanıza gelen 6 haneli kodu girin.';

  @override
  String get verifyQuotaInfo =>
      'Doğrulama e-postası şu an gönderilemiyor, en kısa sürede göndereceğiz. Kod gelince buraya girebilirsiniz.';

  @override
  String get verifyDone => 'E-postanız doğrulandı';

  @override
  String get errEmailVerificationRequired =>
      'Bu işlem için e-postanızı doğrulayın';

  @override
  String get notifActionAck => 'Anladım';

  @override
  String get notifActionQuickReply => 'Hızlı Yanıtla';

  @override
  String get notifActionOpenAll => 'Tümünü Aç';

  @override
  String get notifActionProgram => 'Program Detayı';

  @override
  String notifKcalTotal(String n) {
    return 'Toplam $n kcal';
  }

  @override
  String notifOldTime(String time) {
    return 'Eski saat: $time';
  }

  @override
  String notifNewTime(String time) {
    return 'Yeni saat $time';
  }

  @override
  String get notifBadgeImportant => 'ÖNEMLİ';

  @override
  String get notifSourceModeration => 'Moderasyon';

  @override
  String notifAgoMin(String n) {
    return '$n dk önce';
  }

  @override
  String notifAgoHour(String n) {
    return '$n sa önce';
  }

  @override
  String notifAgoDay(String n) {
    return '$n gün önce';
  }

  @override
  String notifYesterdayAt(String time) {
    return 'Dün $time';
  }

  @override
  String notifNewCount(String n) {
    return '$n Yeni';
  }

  @override
  String notifGroupUnread(String n) {
    return '$n okunmamış';
  }

  @override
  String get notifPrefMealMenu => 'Günlük menü';

  @override
  String get notifPrefMealMenuSub =>
      'Günün yemek listesi bildirimi. Varsayılan olarak kapalıdır.';

  @override
  String get notifExamAlarmOn => 'Hatırlatıcı açık';

  @override
  String get notifExamAlarmOff => 'Hatırlatıcı kapalı';

  @override
  String notifCapacityFull(String n) {
    return 'Kapasite: %$n dolu';
  }

  @override
  String get alarmClockNote =>
      'Alarmlar telefonunuzun Saat uygulamasına eklenir. Silmek için Saat uygulamasını açın.';

  @override
  String get alarmIosNote =>
      'iPhone, Saat uygulamasına alarm eklemeye izin vermez. Bu bildirim alarm yerine geçer; sessiz modda çalmayabilir.';

  @override
  String get alarmUnavailable => 'Bu cihazda Saat uygulaması bulunamadı.';

  @override
  String get alarmNotifOff =>
      'Bildirim izni kapalı. Hatırlatma için Ayarlar > BÜ Kampüs > Bildirimler iznini açın.';

  @override
  String get alarmExamAction => 'İlk sınav alarmlarını kur';

  @override
  String get alarmExamActionIos => 'Sınavları bildirimle hatırlat';

  @override
  String get alarmExamSheetTitle => 'Sınav günü alarmları';

  @override
  String get alarmExamSheetTitleIos => 'Sınav günü bildirimleri';

  @override
  String get alarmExamSheetSub =>
      'Her günün yalnız ilk sınavı için, başlangıçtan 1 saat önceye tek seferlik.';

  @override
  String alarmExamRow(String exam, String alarm) {
    return 'Sınav $exam → Alarm $alarm';
  }

  @override
  String alarmExamSkipped(String times) {
    return '$times sınavı için alarm yok';
  }

  @override
  String get alarmExamNone => 'Alarm kurulacak yaklaşan sınav yok.';

  @override
  String alarmExamDeferred(String n) {
    return '$n alarm ileri tarihli. Android Saat uygulaması ileri tarihli tek seferlik alarmı desteklemez; sınav gününden önceki akşam size bildirimle hatırlatırız, tek dokunuşla kurarsınız.';
  }

  @override
  String get alarmExamDeferredRow => 'Sınavdan önceki akşam hatırlatılır';

  @override
  String alarmSetCount(String n) {
    return '$n alarmı kur';
  }

  @override
  String alarmNotifyCount(String n) {
    return '$n bildirimi kur';
  }

  @override
  String alarmDoneSet(String n) {
    return '$n alarm kuruldu. Saat uygulamasından kontrol edin.';
  }

  @override
  String alarmDoneNotif(String n) {
    return '$n bildirim kuruldu.';
  }

  @override
  String alarmDoneDeferred(String n) {
    return '$n alarm sınav gününden önce hatırlatılacak.';
  }

  @override
  String alarmDoneFail(String n) {
    return '$n alarm kurulamadı.';
  }

  @override
  String alarmDueBanner(String n) {
    return '$n sınav alarmı kurulmaya hazır.';
  }

  @override
  String get alarmDueAction => 'Şimdi kur';

  @override
  String get alarmNudgeTitle => 'Sınav alarmını kur';

  @override
  String alarmNudgeBody(String title, String time) {
    return '$title: $time alarmı hazır. Dokunup Sınavlar sayfasından kurun.';
  }

  @override
  String alarmExamLabel(String time, String title) {
    return 'Sınav $time: $title';
  }

  @override
  String get alarmExamNotifTitle => 'Alarm: Sınav 1 saat sonra';

  @override
  String get alarmClassAction => 'Sabah alarmlarını kur';

  @override
  String get alarmClassActionIos => 'Sabah dersleri için bildirim kur';

  @override
  String get alarmClassSheetTitle => 'Sabah ders alarmları';

  @override
  String get alarmClassSheetTitleIos => 'Sabah ders bildirimleri';

  @override
  String get alarmClassSheetSub =>
      'Günün ilk dersi öğleden önce başlıyorsa, 1 saat önceye ve her hafta tekrarlı.';

  @override
  String alarmClassRow(String classTime, String alarm) {
    return 'Ders $classTime → Alarm $alarm · her hafta';
  }

  @override
  String alarmClassSkipped(String days) {
    return '$days: ilk ders öğleden sonra, alarm yok';
  }

  @override
  String get alarmClassNone => 'Sabah dersi yok; alarm kurulmayacak.';

  @override
  String alarmClassLabel(String time) {
    return 'Ders alarmı · ilk ders $time';
  }

  @override
  String get alarmClassNotifTitle => 'Alarm: Ders 1 saat sonra';

  @override
  String alarmClassNotifBody(String time) {
    return 'Günün ilk dersi $time saatinde başlıyor.';
  }

  @override
  String alarmRepeatWarn(String date) {
    return 'Bu alarmlar $date tarihinde kuruldu. Yeniden kurarsanız Saat uygulamasında çift alarm olabilir.';
  }

  @override
  String get alarmSetAnyway => 'Yine de kur';

  @override
  String alarmDoneClassSet(String n) {
    return '$n tekrarlı alarm kuruldu. Saat uygulamasından kontrol edin; silmek de oradan.';
  }

  @override
  String get calSyncRowTitle => 'Cihaz takvimine ekle';

  @override
  String get calSyncRowSub =>
      'Tüm akademik takvim, o gün sabah 08:00 hatırlatıcıyla';

  @override
  String calSyncRowDone(String n) {
    return 'Cihaz takviminde · $n etkinlik';
  }

  @override
  String get calSyncRowDoneSub => 'Güncelle ya da kaldır';

  @override
  String get calSyncSheetBody =>
      'Önümüzdeki 12 ayın akademik takvimi etkinlik olarak yazılır. Tüm gün kayıtlara o gün 08:00 hatırlatıcı eklenir; bildirimi takvim uygulamanız gönderir. Yalnız BÜ Kampüs etkinlikleri eklenir ve silinir.';

  @override
  String get calSyncTarget => 'Eklenecek takvim';

  @override
  String get calSyncNewLocal => 'BÜ Kampüs (yeni yerel takvim)';

  @override
  String get calSyncAdd => 'Takvime ekle';

  @override
  String get calSyncUpdate => 'Güncelle';

  @override
  String get calSyncRemove => 'Takvimden kaldır';

  @override
  String get calSyncRemoveTitle => 'BÜ Kampüs etkinlikleri kaldırılsın mı?';

  @override
  String calSyncRemoveBody(String n) {
    return 'Takviminize bu uygulamanın eklediği $n etkinlik silinir. Diğer etkinlikleriniz etkilenmez.';
  }

  @override
  String calSyncResult(String added, String updated, String same) {
    return '$added etkinlik eklendi, $updated güncellendi, $same aynı kaldı.';
  }

  @override
  String calSyncRemovedN(String n) {
    return '$n kaldırıldı.';
  }

  @override
  String calSyncFailedN(String n) {
    return '$n yazılamadı.';
  }

  @override
  String get calSyncRationale =>
      'Akademik takvimi cihaz takviminize yazmak için takvim erişimi gerekir. Yalnızca BÜ Kampüs etkinlikleri eklenir ve silinir; başka etkinliklerinize dokunulmaz.';

  @override
  String get calSyncDenied =>
      'Takvim izni kapalı. Ayarlar > BÜ Kampüs > Takvim iznini açın.';

  @override
  String get calSyncOpenSettings => 'Ayarları aç';

  @override
  String get calSyncNoCalendar =>
      'Cihazda yazılabilir takvim yok. BÜ Kampüs adlı yerel bir takvim oluşturulacak.';

  @override
  String get calSyncFetchError =>
      'Akademik takvim alınamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get calSyncEmpty => 'Yazılacak güncel akademik takvim kaydı yok.';

  @override
  String get calSyncUnavailable => 'Bu cihazda takvim erişimi desteklenmiyor.';

  @override
  String calSyncRemoveDone(String n) {
    return '$n etkinlik takvimden kaldırıldı.';
  }

  @override
  String get calSyncCreateFail => 'Takvim oluşturulamadı.';

  @override
  String get calSyncWorking => 'Takvime yazılıyor…';

  @override
  String get tfTitle => 'İki faktörlü doğrulama';

  @override
  String get tfSecSection => 'Giriş güvenliği';

  @override
  String get tfOn => 'Açık';

  @override
  String get tfOff => 'Kapalı';

  @override
  String get tfToggleSubOff =>
      'Kapalı. Tanımadığın bir cihazdan girişte e-postana kod gönderilir.';

  @override
  String get tfToggleSubOn =>
      'Açık. Tanımadığın bir cihazdan girişte e-postana gönderilen kod istenir.';

  @override
  String get tfIntro =>
      'Hesabına tanımadığın bir cihazdan girildiğinde e-postana 6 haneli bir kod gönderilir. Güvendiğin cihazlarda kod istenmez.';

  @override
  String get tfDevicesSection => 'Güvenilen cihazlar';

  @override
  String get tfDevicesEmpty =>
      'Henüz güvenilen cihaz yok. Girişte Bu cihaza güven seçeneğini açarsan cihaz burada listelenir.';

  @override
  String get tfDeviceThis => 'Bu cihaz';

  @override
  String get tfDeviceUnnamed => 'Cihaz';

  @override
  String tfDeviceLastUsed(String date) {
    return 'Son kullanım $date';
  }

  @override
  String get tfDeviceRemove => 'Cihazı kaldır';

  @override
  String get tfDeviceRemoveTitle => 'Cihaz kaldırılsın mı?';

  @override
  String get tfDeviceRemoveBody =>
      'Bu cihazdan bir sonraki girişte yeniden kod istenir. Açık oturum kapanmaz.';

  @override
  String get tfDeviceRemoveConfirm => 'Kaldır';

  @override
  String get tfDeviceRemoved => 'Cihaz kaldırıldı.';

  @override
  String get tfEnabledToast => 'İki faktörlü doğrulama açıldı.';

  @override
  String get tfDisabledToast => 'İki faktörlü doğrulama kapatıldı.';

  @override
  String tfEnableSubtitle(String email) {
    return 'Açmak için $email adresine gönderilen 6 haneli kodu girin. Kod 10 dakika geçerlidir.';
  }

  @override
  String get tfEnableSubtitleNoMail =>
      'Açmak için e-posta adresinize gönderilen 6 haneli kodu girin. Kod 10 dakika geçerlidir.';

  @override
  String get tfDisableTitle => 'İki faktörlü doğrulama kapatılsın mı?';

  @override
  String get tfDisableBody =>
      'Şifreni girerek onayla. Güvenilen tüm cihazlar silinir ve hesabın yalnız şifreyle korunur.';

  @override
  String get tfDisableConfirm => 'Kapat';

  @override
  String get tfWrongPassword => 'Şifre hatalı.';

  @override
  String tfLoginSubtitle(String email) {
    return 'Giriş için $email adresine gönderilen 6 haneli kodu girin. Kod 10 dakika geçerlidir.';
  }

  @override
  String get tfLoginSubtitleNoMail =>
      'Giriş için e-posta adresinize gönderilen 6 haneli kodu girin. Kod 10 dakika geçerlidir.';

  @override
  String get tfTrustLabel => 'Bu cihaza güven';

  @override
  String get tfTrustHint =>
      'Bu cihazdan sonraki girişlerde kod istenmez. Yalnız kendi telefonunda aç.';

  @override
  String get tfBackToLogin => 'Girişe dön';

  @override
  String get tfErrCodeInvalid => 'Doğrulama kodu geçersiz veya süresi dolmuş.';

  @override
  String get tfErrChallengeExpired =>
      'Doğrulama oturumunun süresi doldu. Lütfen tekrar giriş yapın.';

  @override
  String get tfErrLocked =>
      'Çok sayıda hatalı doğrulama kodu girildi; yeni cihazdan giriş 24 saat kilitlendi. Güvenilen bir cihazdan girebilir ya da şifrenizi sıfırlayabilirsiniz.';

  @override
  String get tfErrAlreadyEnabled => 'İki faktörlü doğrulama zaten açık.';

  @override
  String get tfErrNotEnabled => 'İki faktörlü doğrulama açık değil.';

  @override
  String get chatArchiveBarTitle => 'Arşivlenenler';

  @override
  String chatArchiveBarCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bildirim',
    );
    return '$_temp0';
  }

  @override
  String chatArchiveBarSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bildirim',
    );
    return 'Arşivlenenler, $_temp0';
  }

  @override
  String forumCommentLikeSemantic(String n) {
    return 'Beğen, $n beğeni';
  }

  @override
  String forumCommentUnlikeSemantic(String n) {
    return 'Beğenmekten vazgeç, $n beğeni';
  }

  @override
  String get forumCommentReadMore => 'Devamını oku';

  @override
  String get forumCommentReadLess => 'Daha az göster';

  @override
  String get forumDetailDeletedAccount => 'Silinmiş hesap';

  @override
  String get forumCommentDeletedPlaceholder => 'Bu yorum silindi';

  @override
  String get forumCommentAuthorBadge => 'Yazar';

  @override
  String get forumCommentEdited => 'Düzenlendi';

  @override
  String get forumCommentReply => 'Yanıtla';

  @override
  String get forumCommentMore => 'Diğer işlemler';

  @override
  String get forumCommentLockedHint => 'Bu konu kilitli, yorum yazılamaz.';

  @override
  String get forumCommentEditingBanner => 'Yorumunu düzenliyorsun';

  @override
  String forumCommentReplyingTo(String name) {
    return '$name kişisine yanıt veriyorsun';
  }

  @override
  String get forumCommentCancelTarget => 'Yanıtı veya düzenlemeyi iptal et';

  @override
  String get forumCommentHint => 'Yorum yaz…';

  @override
  String get forumCommentHintReply => 'Yanıtını yaz…';

  @override
  String get forumCommentAnonLabel => 'Anonim yaz';

  @override
  String forumCommentCounter(String n, String max) {
    return '$n / $max';
  }

  @override
  String get forumCommentSend => 'Gönder';

  @override
  String get forumCommentSaveEdit => 'Kaydet';

  @override
  String forumCommentShowReplies(String n) {
    return '$n yanıtı göster';
  }

  @override
  String get forumCommentHideReplies => 'Yanıtları gizle';

  @override
  String forumCommentMoreReplies(String n) {
    return '$n yanıt daha';
  }

  @override
  String get forumCommentMoreRepliesGeneric => 'Daha fazla yanıt';

  @override
  String forumCommentOpenChain(String n) {
    return 'Yanıt zincirini aç ($n)';
  }

  @override
  String get forumCommentRepliesFailed => 'Yanıtlar yüklenemedi.';

  @override
  String get forumCommentActionEdit => 'Düzenle';

  @override
  String get forumCommentActionDelete => 'Sil';

  @override
  String get forumCommentActionCopy => 'Metni kopyala';

  @override
  String get forumCommentActionShare => 'Bağlantıyı paylaş';

  @override
  String get forumCommentActionLike => 'Beğen';

  @override
  String get forumCommentActionUnlike => 'Beğenmekten vazgeç';

  @override
  String get forumCommentActionSave => 'Kaydet';

  @override
  String get forumCommentActionUnsave => 'Kaydedilenlerden çıkar';

  @override
  String get forumCommentActionReport => 'Şikâyet et';

  @override
  String get forumCommentActionBlock => 'Kullanıcıyı engelle';

  @override
  String get forumCommentCopied => 'Metin kopyalandı';

  @override
  String get forumCommentDeleted => 'Yorum silindi';

  @override
  String get forumCommentDeleteTitle => 'Yorum silinsin mi?';

  @override
  String get forumCommentDeleteBody => 'Bu işlem geri alınamaz.';

  @override
  String get forumCommentDeleteConfirm => 'Sil';

  @override
  String get forumCommentBlockTitle => 'Bu kullanıcı engellensin mi?';

  @override
  String get forumCommentBlockBody =>
      'Engellediğin kişinin içeriklerini artık görmezsin. Anonim yazarlarda kimlik açığa çıkmaz.';

  @override
  String get forumCommentBlockConfirm => 'Engelle';

  @override
  String get forumCommentBlocked => 'Kullanıcı engellendi';

  @override
  String get forumCommentSaved => 'Kaydedildi';

  @override
  String get forumCommentUnsaved => 'Kaydedilenlerden çıkarıldı';

  @override
  String get forumCommentGone => 'Bu yorum artık yok. Liste yenilendi.';

  @override
  String get forumCommentConflict =>
      'Yorum başka bir yerde değişti. Liste yenilendi.';

  @override
  String get forumCommentSent => 'Yorumun gönderildi';

  @override
  String get forumCommentReplySent => 'Yanıtın gönderildi';

  @override
  String get forumCommentEditDone => 'Yorum güncellendi';

  @override
  String get forumCommentLinkNotFound => 'Bağlantıdaki yorum bulunamadı';

  @override
  String get forumDetailSortBest => 'En iyi';

  @override
  String get forumDetailSortNewest => 'En yeni';

  @override
  String get forumDetailSortOldest => 'En eski';

  @override
  String forumDetailCommentsHeader(String n) {
    return 'Yorumlar ($n)';
  }

  @override
  String get forumDetailNoComments => 'Henüz yorum yok';

  @override
  String get forumDetailNoCommentsBody => 'İlk yorumu sen yaz.';

  @override
  String get forumDetailCommentsError => 'Yorumlar yüklenemedi';

  @override
  String get forumDetailSlow => 'Bağlantı yavaş, biraz daha bekleyin…';

  @override
  String get forumDetailSemanticTitle => 'Konu';

  @override
  String get forumDetailNotFoundTitle => 'Bu konu artık yok';

  @override
  String get forumDetailNotFoundBody =>
      'Silinmiş ya da yayından kaldırılmış olabilir.';

  @override
  String get forumDetailRemovedTitle => 'Bu konu kaldırıldı';

  @override
  String get forumDetailRemovedBody =>
      'Topluluk kuralları gereği yayından kaldırıldı.';

  @override
  String get forumDetailLockedBanner =>
      'Bu konu kilitli. Yeni yorum yazılamaz.';

  @override
  String get forumDetailPinned => 'Sabitlendi';

  @override
  String get forumDetailEdited => 'Düzenlendi';

  @override
  String get forumDetailLikeAction => 'Beğen';

  @override
  String get forumDetailUnlikeAction => 'Beğenmekten vazgeç';

  @override
  String get forumDetailSaveAction => 'Kaydet';

  @override
  String get forumDetailUnsaveAction => 'Kaydedilenlerden çıkar';

  @override
  String get forumDetailFollowAction => 'Takip et';

  @override
  String get forumDetailUnfollowAction => 'Takibi bırak';

  @override
  String get forumDetailShareAction => 'Paylaş';

  @override
  String get forumDetailCommentsAction => 'Yorumlara git';

  @override
  String forumDetailCommentCount(String n) {
    return '$n yorum';
  }

  @override
  String forumDetailLikeCount(String n) {
    return '$n beğeni';
  }

  @override
  String get forumDetailMenu => 'Konu seçenekleri';

  @override
  String get forumDetailMenuEdit => 'Konuyu düzenle';

  @override
  String get forumDetailMenuDelete => 'Konuyu sil';

  @override
  String get forumDetailMenuNotificationsOff => 'Bildirimleri kapat';

  @override
  String get forumDetailMenuNotificationsOn => 'Bildirimleri aç';

  @override
  String get forumDetailMenuShare => 'Bağlantıyı paylaş';

  @override
  String get forumDetailMenuPin => 'Konuyu sabitle';

  @override
  String get forumDetailMenuUnpin => 'Sabitlemeyi kaldır';

  @override
  String get forumDetailMenuLock => 'Yorumları kilitle';

  @override
  String get forumDetailMenuUnlock => 'Kilidi aç';

  @override
  String get forumDetailMenuReport => 'Şikâyet et';

  @override
  String get forumDetailMenuBlock => 'Yazarı engelle';

  @override
  String get forumDetailDeleteTitle => 'Konu silinsin mi?';

  @override
  String get forumDetailDeleteBody =>
      'Konu ve altındaki yorumlar kaldırılır. Bu işlem geri alınamaz.';

  @override
  String get forumDetailDeleteConfirm => 'Sil';

  @override
  String get forumDetailDeleted => 'Konu silindi';

  @override
  String get forumDetailBlockTitle => 'Yazar engellensin mi?';

  @override
  String get forumDetailBlockBody =>
      'Bu yazarın içeriklerini artık görmezsin. Anonim ise kimliği açığa çıkmaz.';

  @override
  String get forumDetailBlockConfirm => 'Engelle';

  @override
  String get forumDetailBlocked => 'Yazar engellendi';

  @override
  String get forumDetailNotificationsOffDone =>
      'Bu konunun bildirimleri kapatıldı';

  @override
  String get forumDetailNotificationsOnDone => 'Bu konunun bildirimleri açıldı';

  @override
  String get forumDetailPinnedDone => 'Konu sabitlendi';

  @override
  String get forumDetailUnpinnedDone => 'Sabitleme kaldırıldı';

  @override
  String get forumDetailLockedDone => 'Yorumlar kilitlendi';

  @override
  String get forumDetailUnlockedDone => 'Yorumların kilidi açıldı';

  @override
  String forumDetailImageIndex(String i, String n) {
    return '$i / $n';
  }

  @override
  String forumDetailImageSemantic(String i, String n) {
    return 'Konu görseli $i / $n';
  }

  @override
  String get forumDetailChainRoot => 'Yanıt zinciri';

  @override
  String get forumDetailFollowing => 'Konu takip ediliyor';

  @override
  String get forumDetailUnfollowed => 'Konu takibi bırakıldı';

  @override
  String get forumDetailSaved => 'Konu kaydedildi';

  @override
  String get forumDetailUnsaved => 'Kaydedilenlerden çıkarıldı';

  @override
  String get forumDetailLockedChip => 'Kilitli';

  @override
  String get forumComposeClose => 'Kapat';

  @override
  String get forumComposePublish => 'Yayınla';

  @override
  String get forumComposePublishing => 'Yayınlanıyor';

  @override
  String get forumComposeTitleHint => 'Başlık';

  @override
  String get forumComposeBodyHint => 'Ne konuşmak istiyorsun?';

  @override
  String get forumComposeCategoryLabel => 'Kategori';

  @override
  String get forumComposeCategoryPick => 'Kategori seç';

  @override
  String get forumComposeCategoryLoading => 'Kategoriler yükleniyor';

  @override
  String get forumComposeCategoryError => 'Kategoriler yüklenemedi';

  @override
  String get forumComposeRetry => 'Tekrar dene';

  @override
  String get forumComposeAddImage => 'Görsel ekle';

  @override
  String forumComposeImageCount(int count, int max) {
    return '$count/$max görsel';
  }

  @override
  String get forumComposeGallery => 'Galeriden seç';

  @override
  String get forumComposeCamera => 'Fotoğraf çek';

  @override
  String get forumComposeImageRemove => 'Görseli kaldır';

  @override
  String get forumComposeImageUploading => 'Görsel yükleniyor';

  @override
  String get forumComposeImageRetry => 'Görseli yeniden yükle';

  @override
  String get forumComposeImagesPending =>
      'Görseller yüklenince yayınlayabilirsin.';

  @override
  String get forumComposeImageFailedHint =>
      'Bir görsel yüklenemedi. Yeniden dene ya da kaldır.';

  @override
  String get forumComposeErrImageTooLarge => 'Görsel çok büyük.';

  @override
  String get forumComposeErrImageType =>
      'Yalnızca JPEG, PNG ve WebP görseller eklenebilir.';

  @override
  String get forumComposeErrImageRead => 'Görsel okunamadı.';

  @override
  String get forumComposeErrImageUpload => 'Görsel yüklenemedi.';

  @override
  String get forumComposePollAdd => 'Anket ekle';

  @override
  String get forumComposeAnonymous => 'Anonim paylaş';

  @override
  String get forumComposeAnonymousDesc => 'Adın diğer öğrencilere gösterilmez.';

  @override
  String get forumComposeAnonymousNote =>
      'Moderatörler kötüye kullanımı görebilir.';

  @override
  String get forumComposeNeedTitle => 'Bir başlık yaz.';

  @override
  String get forumComposeNeedBody => 'Bir açıklama yaz.';

  @override
  String get forumComposeNeedCategory => 'Bir kategori seç.';

  @override
  String get forumComposeNeedPoll => 'Ankette en az 2 dolu seçenek olmalı.';

  @override
  String get forumComposeDraftRestored => 'Taslak geri yüklendi';

  @override
  String get forumComposeDraftSheetTitle => 'Taslağı kaydedelim mi?';

  @override
  String get forumComposeDraftSheetBody =>
      'Yazdıkların bir sonraki sefer geri gelir.';

  @override
  String get forumComposeDraftSave => 'Taslağı kaydet';

  @override
  String get forumComposeDraftDelete => 'Sil';

  @override
  String get forumComposeDraftContinue => 'Devam et';

  @override
  String get forumComposeErrNetwork =>
      'İnternet bağlantısı yok. Yazdıkların korundu.';

  @override
  String get forumComposeErrRate =>
      'Çok sık paylaşım yaptın. Biraz bekleyip tekrar dene.';

  @override
  String get forumComposeErrDuplicate => 'Aynı içeriği az önce paylaştın.';

  @override
  String get forumComposeErrProfanity =>
      'Metinde uygunsuz ifade var. Düzenleyip tekrar dene.';

  @override
  String get forumComposeErrCategory =>
      'Bu kategori artık kullanılamıyor. Başka bir kategori seç.';

  @override
  String get forumComposeErrInvalid =>
      'İçerik geçersiz. Başlığı ve açıklamayı kontrol et.';

  @override
  String get forumComposeErrGeneric =>
      'Konu yayınlanamadı. Yazdıkların korundu, tekrar dene.';

  @override
  String get forumComposeEditSave => 'Kaydet';

  @override
  String get forumComposeEditSaving => 'Kaydediliyor';

  @override
  String get forumComposeEditLocked => 'Bu konu kilitli, düzenlenemez.';

  @override
  String get forumComposeEditGone => 'Bu konu artık yok.';

  @override
  String get forumComposeEditNotOwner =>
      'Bu konuyu yalnızca sahibi düzenleyebilir.';

  @override
  String get forumComposeEditSaved => 'Düzenlendi';

  @override
  String get forumComposeEditNote =>
      'Görseller ve anket sonradan değiştirilemez.';

  @override
  String get forumPollQuestionHint => 'Soru (isteğe bağlı)';

  @override
  String forumPollOptionHint(int n) {
    return 'Seçenek $n';
  }

  @override
  String get forumPollAddOption => 'Seçenek ekle';

  @override
  String get forumPollRemoveOption => 'Seçeneği kaldır';

  @override
  String forumPollMaxOptions(int max) {
    return 'En çok $max seçenek eklenebilir.';
  }

  @override
  String get forumPollEndsAt => 'Bitiş';

  @override
  String get forumPollEndsNone => 'Süresiz';

  @override
  String forumPollEndsDays(int n) {
    return '$n gün';
  }

  @override
  String get forumPollEndsPickDate => 'Tarih seç';

  @override
  String forumPollEndsOn(String date) {
    return '$date tarihinde biter';
  }

  @override
  String get forumPollAllowChange => 'Oy değiştirilebilir';

  @override
  String get forumPollRemove => 'Anketi kaldır';

  @override
  String forumPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oy',
      one: '1 oy',
      zero: 'Oy yok',
    );
    return '$_temp0';
  }

  @override
  String forumPollPercent(String p) {
    return '%$p';
  }

  @override
  String get forumPollMine => 'Oyun';

  @override
  String get forumPollEnded => 'Anket sona erdi';

  @override
  String forumPollLeftDays(int n) {
    return '$n gün kaldı';
  }

  @override
  String forumPollLeftHours(int n) {
    return '$n saat kaldı';
  }

  @override
  String forumPollLeftMinutes(int n) {
    return '$n dakika kaldı';
  }

  @override
  String get forumPollCanChange => 'Oyunu değiştirebilirsin';

  @override
  String get forumPollLocked => 'Oy verdikten sonra değiştirilemez';

  @override
  String get forumPollUndo => 'Oyumu geri al';

  @override
  String forumPollSemantics(String text, String percent, String votes) {
    return '$text, $percent, $votes';
  }

  @override
  String get forumPollSelected => 'Seçili';

  @override
  String get forumPollErrClosed => 'Anket sona erdi.';

  @override
  String get forumPollErrAlready =>
      'Bu ankette oyun zaten kayıtlı ve değiştirilemez.';

  @override
  String get forumPollErrNetwork => 'İnternet bağlantısı yok. Oy verilemedi.';

  @override
  String get forumPollErrRate => 'Çok sık oy işlemi yaptın. Biraz bekle.';

  @override
  String get forumPollErrGone => 'Bu konu ya da anket artık yok.';

  @override
  String get forumPollErrForbidden => 'Bu ankete oy verme iznin yok.';

  @override
  String get forumPollErrGeneric => 'Oy işlemi yapılamadı. Tekrar dene.';

  @override
  String get forumPollTitle => 'Anket';

  @override
  String get forumComposeDiscardTitle => 'Değişiklikler atılsın mı?';

  @override
  String get forumComposeDiscardConfirm => 'At';

  @override
  String get forumComposeDiscardKeep => 'Düzenlemeye devam';

  @override
  String get forumComposeCategorySheetEmpty =>
      'Şu an seçilebilir kategori yok.';

  @override
  String get forumComposeEditErrGeneric =>
      'Değişiklikler kaydedilemedi. Tekrar dene.';

  @override
  String get forumHomeA11y => 'Kampüs Forum';

  @override
  String get forumHomeHint => 'Kampüste herkesin konuştuğu yer';

  @override
  String get forumHomeSearch => 'Forumda ara';

  @override
  String get forumHomeNotifications => 'Bildirimler';

  @override
  String get forumHomeNewTopic => 'Yeni konu';

  @override
  String get forumHomeSortTitle => 'Sırala';

  @override
  String get forumHomeSortForYou => 'Sana özel';

  @override
  String get forumHomeSortNewest => 'En yeni';

  @override
  String get forumHomeSortPopular => 'Popüler';

  @override
  String get forumHomeSortMostCommented => 'En çok yorumlanan';

  @override
  String get forumHomeSortFollowing => 'Takip ettiklerim';

  @override
  String get forumHomeCategoryAll => 'Tümü';

  @override
  String get forumHomeCategories => 'Kategoriler';

  @override
  String get forumHomePinned => 'Sabitlenmiş';

  @override
  String get forumHomeLocked => 'Kilitli';

  @override
  String get forumHomePoll => 'Anket';

  @override
  String get forumHomeEdited => 'düzenlendi';

  @override
  String forumHomeCommentsA11y(String n) {
    return '$n yorum';
  }

  @override
  String forumHomeLikesA11y(String n) {
    return '$n beğeni';
  }

  @override
  String get forumHomeOpenComments => 'Yorumları aç';

  @override
  String get forumHomeLike => 'Beğen';

  @override
  String get forumHomeUnlike => 'Beğenmekten vazgeç';

  @override
  String get forumHomeSave => 'Kaydet';

  @override
  String get forumHomeUnsave => 'Kaydı kaldır';

  @override
  String get forumHomeShare => 'Paylaş';

  @override
  String get forumHomeMore => 'Diğer işlemler';

  @override
  String get forumHomeMenuCopyLink => 'Bağlantıyı kopyala';

  @override
  String get forumHomeMenuReport => 'Şikâyet et';

  @override
  String get forumHomeMenuMute => 'Kullanıcıyı sessize al';

  @override
  String get forumHomeMenuBlock => 'Yazarı engelle';

  @override
  String get forumHomeBlockTitle => 'Yazar engellensin mi?';

  @override
  String get forumHomeBlockBody =>
      'Bu yazarın konuları ve yorumları artık sana görünmez. Yazar anonimse kimliği açığa çıkmaz.';

  @override
  String get forumHomeBlockConfirm => 'Engelle';

  @override
  String get forumHomeMuteTitle => 'Kullanıcı sessize alınsın mı?';

  @override
  String get forumHomeMuteBody =>
      'Bu kullanıcının içerikleri sana gösterilmez. İstediğin zaman geri alabilirsin.';

  @override
  String get forumHomeMuteConfirm => 'Sessize al';

  @override
  String get forumHomeBlocked => 'Yazar engellendi';

  @override
  String get forumHomeMuted => 'Kullanıcı sessize alındı';

  @override
  String get forumHomeLinkCopied => 'Bağlantı kopyalandı';

  @override
  String get forumHomeLikeFailed => 'Beğeni kaydedilemedi';

  @override
  String get forumHomeSaveFailed => 'Kaydetme işlemi yapılamadı';

  @override
  String get forumHomeEmptyTitle => 'Henüz konu yok';

  @override
  String get forumHomeEmptyBody =>
      'İlk konuyu sen aç; kampüs seninle konuşsun.';

  @override
  String get forumHomeEmptyAction => 'Konu aç';

  @override
  String get forumHomeEmptyCategoryTitle => 'Bu kategoride konu yok';

  @override
  String get forumHomeEmptyCategoryBody =>
      'Başka bir kategoriye bak ya da ilk konuyu sen aç.';

  @override
  String get forumHomeEmptyFollowingTitle => 'Takip ettiğin konu yok';

  @override
  String get forumHomeEmptyFollowingBody =>
      'Bir konuyu takip edersen yeni yorumlar burada öne çıkar.';

  @override
  String get forumHomeLoadMoreFailed => 'Daha fazlası yüklenemedi';

  @override
  String get forumHomeStripSub => 'Kampüste herkesin konuştuğu yer';

  @override
  String get forumHomeTalkedTitle => 'Kampüste konuşulanlar';

  @override
  String get forumHomeTalkedAll => 'Tümü';

  @override
  String get forumStateOffline =>
      'İnternet bağlantısı yok. Bağlanınca tekrar dene.';

  @override
  String get forumStateServerError =>
      'Sunucuya şu an ulaşılamıyor. Biraz sonra tekrar dene.';

  @override
  String get forumStateSessionExpired =>
      'Oturum süren doldu. Yeniden giriş yap.';

  @override
  String get forumStateNotFound => 'Bu içerik bulunamadı ya da kaldırılmış.';

  @override
  String get forumStateTopicRemoved => 'Bu konu kaldırıldı.';

  @override
  String get forumStateCommentRemoved => 'Bu yorum kaldırıldı.';

  @override
  String get forumStateCommentDeleted => 'Bu yorum silindi.';

  @override
  String get forumStateLocked => 'Bu konu yorumlara kapatıldı.';

  @override
  String get forumStateNotOwner => 'Bu işlem için yetkin yok.';

  @override
  String get forumStateRateLimited =>
      'Çok hızlı gidiyorsun. Biraz bekleyip tekrar dene.';

  @override
  String get forumStateDuplicate => 'Aynı içeriği kısa süre önce gönderdin.';

  @override
  String get forumStateProfanity =>
      'Metinde uygunsuz ifade var. Düzenleyip tekrar dene.';

  @override
  String get forumStatePollClosed => 'Bu anket sona erdi.';

  @override
  String get forumStateAlreadyVoted => 'Bu ankette zaten oy kullandın.';

  @override
  String get forumStateEmptyContent => 'Boş içerik gönderilemez.';

  @override
  String get forumStateNoAccess => 'Bu içeriğe erişemiyorsun.';

  @override
  String get forumStateGeneric => 'Bir sorun oluştu. Tekrar dene.';

  @override
  String get forumHomeMenuSaved => 'Kaydedilen konular';

  @override
  String get forumHomeMenuActivity => 'Forum faaliyetim';

  @override
  String get forumHomeMenuPrefs => 'Forum bildirim ayarları';

  @override
  String get notif2SocialSection => 'Sosyal etkileşimler';

  @override
  String get notif2LikeSub => 'Gönderin beğenildiğinde';

  @override
  String get notif2CommentSub => 'Gönderine yorum yapıldığında';

  @override
  String get notif2ReplySub => 'Yorumuna yanıt geldiğinde';

  @override
  String get notif2MentionSub => 'Bir gönderide etiketlendiğinde';

  @override
  String get notif2FollowSub => 'Biri seni takip etmeye başladığında';

  @override
  String get notif2FollowRequestTitle => 'Takip istekleri';

  @override
  String get notif2FollowRequestSub => 'Sana takip isteği geldiğinde';

  @override
  String get notif2FollowAcceptedTitle => 'Kabul edilen istekler';

  @override
  String get notif2FollowAcceptedSub => 'Takip isteğin kabul edildiğinde';

  @override
  String get notif2AcademicTitle => 'Akademik duyurular';

  @override
  String get notif2AcademicSub => 'Sınav hatırlatmaları ve akademik duyurular';

  @override
  String get notif2AcademicNeedsAnnouncements =>
      'Duyurular kapalıysa akademik bildirimler gelmez';

  @override
  String get notif2PreviewSection => 'Önizleme';

  @override
  String get notif2HidePreviewTitle => 'Mesaj içeriğini gizle';

  @override
  String get notif2HidePreviewSub =>
      'Açıkken bildirimde mesaj metni yerine Yeni mesaj yazar; kilit ekranında içerik görünmez.';

  @override
  String get notif2SystemSection => 'Sistem ve güvenlik';

  @override
  String get notif2SystemSettingsTitle => 'Sistem bildirim ayarları';

  @override
  String get notif2SystemSettingsSub =>
      'Ses, titreşim ve bildirim kategorileri cihaz ayarlarından yönetilir.';

  @override
  String get notif2SecurityNote =>
      'Hesap güvenliği, oturum ve yönetici bildirimleri bu tercihlerden bağımsız olarak her zaman gelir.';

  @override
  String get devTitle => 'Cihazlarım';

  @override
  String get devIntro =>
      'Hesabına giriş yapılmış cihazlar. Tanımadığın bir cihaz görürsen oradan çıkış yap ve şifreni değiştir.';

  @override
  String get devSection => 'Açık oturumlar';

  @override
  String get devThisDevice => 'Bu cihaz';

  @override
  String devLastUsed(String when) {
    return 'Son kullanım: $when';
  }

  @override
  String get devNameAndroid => 'Android cihaz';

  @override
  String get devNameIos => 'iPhone';

  @override
  String get devNameWeb => 'Web tarayıcı';

  @override
  String get devNameUnknown => 'Bilinmeyen cihaz';

  @override
  String get devSignOut => 'Çıkış yap';

  @override
  String get devSignOutTitle => 'Bu cihazdan çıkış yapılsın mı?';

  @override
  String devSignOutBody(String device) {
    return '$device cihazındaki oturum kapatılacak. Tekrar kullanmak için yeniden giriş yapılması gerekir.';
  }

  @override
  String get devSignOutThisBody =>
      'Bu cihazdaki oturumun kapatılacak ve giriş ekranına döneceksin.';

  @override
  String devSignedOut(String device) {
    return '$device cihazından çıkış yapıldı.';
  }

  @override
  String get devGone => 'Bu oturum zaten kapatılmış.';

  @override
  String get devEmpty => 'Listelenecek açık oturum yok.';

  @override
  String get devAllSection => 'Tüm cihazlar';

  @override
  String get devAllHint =>
      'Bu cihaz dahil, tüm cihazlardaki oturumlar kapatılır.';

  @override
  String get devPlatformAndroid => 'Android';

  @override
  String get devPlatformIos => 'iOS';

  @override
  String get devPlatformWeb => 'Web';

  @override
  String get pwRowLabel => 'Şifre';

  @override
  String get pwRowSub => 'Şifreni güncelle';

  @override
  String get pwpIntro => 'Mevcut şifreni girerek yeni bir şifre belirle.';

  @override
  String get pwpForgotTitle => 'Şifreni mi unuttun?';

  @override
  String get pwpForgotBody =>
      'Hesabındaki e-posta adresine 6 haneli bir doğrulama kodu gönderelim; kodu girince yeni şifreni belirleyebilirsin.';

  @override
  String pwpForgotTo(String email) {
    return 'Kod $email adresine gönderilir.';
  }

  @override
  String get pwpForgotButton => 'Doğrulama kodu gönder';

  @override
  String get pwpExpired => 'Doğrulama süresi doldu. Yeni bir kod iste.';

  @override
  String get pwpDoneTitle => 'Şifren güncellendi';

  @override
  String get pwpDoneBody =>
      'Güvenlik için tüm cihazlardaki oturumlar, bu cihaz dahil kapatıldı. Yeni şifrenle yeniden giriş yapabilirsin.';

  @override
  String get cplLockTitle => 'Anketleri görmek için kulübe katıl';

  @override
  String get cplLockBody => 'Kulüp anketleri yalnızca üyelere açıktır.';

  @override
  String get cplLockBodyApproval =>
      'Kulüp anketleri yalnızca üyelere açıktır. Katılma isteğin onaylanınca burada görünür.';

  @override
  String get cplPendingTitle => 'Üyelik isteğin onay bekliyor';

  @override
  String get cplPendingBody =>
      'Onaylandığında kulüp anketlerini burada göreceksin.';

  @override
  String get cplEmptyManagerBody =>
      'Üyelerin fikrini almak için ilk anketi oluştur.';

  @override
  String get chcEmptyTitle => 'Henüz kulüp yok';

  @override
  String get chcEmptyBody => 'İlk kulübü sen kur, arkadaşlarını davet et.';

  @override
  String get chcLoadFailed => 'Kulüpler yüklenemedi.';

  @override
  String clsSortLabel(String name) {
    return 'Sırala: $name';
  }

  @override
  String get clsSortTitle => 'Sıralama';

  @override
  String get clsSortPopular => 'Popüler';

  @override
  String get clsSortNewest => 'Yeni';

  @override
  String get clsSortAz => 'A-Z';

  @override
  String clsCount(String count) {
    return '$count kulüp';
  }

  @override
  String get forumCatAll => 'Tüm kategoriler';

  @override
  String get forumCatPickerA11y => 'Kategori seçici';

  @override
  String get forumCatSearchHint => 'Kategori ara';

  @override
  String get forumCatEmptyTitle => 'Kategori bulunamadı';

  @override
  String forumCatEmptyBody(String q) {
    return '“$q” ile eşleşen kategori yok. Başka bir kelime dene.';
  }

  @override
  String forumCatTopicCount(int count) {
    return '$count konu';
  }

  @override
  String get forumCatLoadFailed => 'Kategoriler yüklenemedi';

  @override
  String get cplSendRequest => 'İstek gönder';

  @override
  String get evtQrScanTitle => 'QR okut';

  @override
  String get evtQrScanHint => 'Katılımcının QR kodunu çerçeveye alın.';

  @override
  String evtQrScanMarked(String name) {
    return '$name katıldı';
  }

  @override
  String evtQrScanAlready(String name) {
    return '$name zaten katıldı';
  }

  @override
  String get evtQrMyTitle => 'QR kodum';

  @override
  String get evtQrMyHint =>
      'Girişte bu kodu etkinlik görevlisine okutun. Kod kısa sürede yenilenir.';

  @override
  String get evtQrMyNotApproved =>
      'QR kodun, katılımın onaylanınca burada görünür.';

  @override
  String get evtQrMyBeforeStart =>
      'Yoklama etkinlik saatinde açılır; kodu şimdiden hazır tutabilirsin.';

  @override
  String get evtQrScanClosed => 'Yoklama henüz açılmadı veya kapandı.';

  @override
  String get evtAttOpenTitle => 'Yoklama açık';

  @override
  String get evtAttOpenSub =>
      'Açıkken katılımcılar QR kodlarını gösterir; siz ve moderatörler okutur.';

  @override
  String get evtAttOpenYou => 'Yoklama açık: giriş için QR kodunu göster.';

  @override
  String get evtModTitle => 'Moderatörler';

  @override
  String get evtModSub =>
      'Kulüp üyelerinden seç; yetkileri tek tek aç veya kapat.';

  @override
  String get evtModAdd => 'Moderatör ekle';

  @override
  String get evtModEmpty => 'Henüz moderatör yok.';

  @override
  String get evtModRemove => 'Moderatörlüğü kaldır';

  @override
  String get evtModSearch => 'Üye ara';

  @override
  String get evtModOwnerNote =>
      'Etkinliği kapatma, iptal, yoklamayı açıp kapatma ve moderatör yönetimi yalnız sahiptedir.';

  @override
  String get evtModRole => 'Moderatör';

  @override
  String get evtModNoMembers => 'Eklenebilecek kulüp üyesi bulunamadı.';

  @override
  String get evtPermTakeAttendance => 'Yoklama al';

  @override
  String get evtPermTakeAttendanceSub => 'QR okut ve elle yoklama işaretle.';

  @override
  String get evtPermManageRequests => 'Katılım isteklerini yönet';

  @override
  String get evtPermManageRequestsSub => 'İstekleri onayla veya reddet.';

  @override
  String get evtPermViewAttendees => 'Katılımcı listesini gör';

  @override
  String get evtPermViewAttendeesSub =>
      'Katılanları ve yoklama durumunu görüntüle.';

  @override
  String get evtPermSendAnnouncement => 'Duyuru gönder';

  @override
  String get evtPermSendAnnouncementSub =>
      'Katılımcılara etkinlik duyurusu gönder.';

  @override
  String get evtPermEditInfo => 'Bilgileri düzenle';

  @override
  String get evtPermEditInfoSub => 'Başlık, açıklama ve yeri değiştir.';

  @override
  String get evtPermEditSchedule => 'Tarih ve saati düzenle';

  @override
  String get evtPermEditScheduleSub => 'Başlangıç ve bitiş zamanını değiştir.';

  @override
  String get evtModManageTitle => 'Moderatör yetkilerin';

  @override
  String get evtModManageNone => 'Bu etkinlikte sana verilmiş bir yetki yok.';

  @override
  String get evtAttClosedNote => 'Yoklama şu an kapalı.';

  @override
  String get evtQrOwnerClosed => 'Yoklama kapalı: katılımcılar QR gösteremez.';

  @override
  String get evtQrOwnerOpenAction => 'Yoklamayı aç';

  @override
  String get evtQrOwnerOutside =>
      'Yoklama etkinlik saatleri dışında; başlangıçtan 30 dk önce kendiliğinden açılır. İstersen şimdi açabilirsin.';

  @override
  String get evtQrMyOwnerTitle => 'Bu etkinliğin organizatörüsün';

  @override
  String get evtQrMyOwnerBody =>
      'Yoklamayı katılımcıların QR kodlarını okutarak alırsın.';

  @override
  String get evtQrMyOwnerScan => 'QR okut';

  @override
  String get evtQrMyOwnerJoin => 'Katılımcı olarak da katıl';

  @override
  String get evtAtt2ToolTitle => 'Yoklama aracı';

  @override
  String get evtAtt2ToolSub => 'QR okut, listeden işaretle';

  @override
  String get evtAtt2ScanQr => 'QR okut';

  @override
  String get evtAtt2Search => 'Katılımcı ara';

  @override
  String get evtAtt2Pending => 'Bekliyor';

  @override
  String evtAtt2Counter(String present, String absent, String pending) {
    return '$present geldi · $absent gelmedi · $pending bekliyor';
  }

  @override
  String get evtAtt2MarkPresent => 'Geldi';

  @override
  String get evtAtt2MarkAbsent => 'Gelmedi';

  @override
  String get evtAtt2MarkReset => 'Sıfırla (bekliyor)';

  @override
  String evtAtt2SheetTitle(String name) {
    return '$name için yoklama';
  }

  @override
  String get evtAtt2BulkRest => 'Kalanları gelmedi işaretle';

  @override
  String get evtAtt2BulkTitle => 'Kalanlar gelmedi işaretlensin mi?';

  @override
  String evtAtt2BulkBody(String count) {
    return '$count kişi \"Gelmedi\" olarak işaretlenecek. Sonra tek tek değiştirebilirsin.';
  }

  @override
  String evtAtt2BulkDone(String count) {
    return '$count kişi gelmedi işaretlendi';
  }

  @override
  String get evtAtt2SrcQr => 'QR';

  @override
  String get evtAtt2SrcManual => 'Elle';

  @override
  String evtAtt2ByScanner(String name) {
    return 'Okutan: $name';
  }

  @override
  String evtAtt2ByMarker(String name) {
    return 'İşaretleyen: $name';
  }

  @override
  String get evtAtt2ViewOnly =>
      'Listeyi yalnız görüntüleyebilirsin; işaretleme yetkin yok.';

  @override
  String get evtAtt2NoMatch => 'Aramana uyan katılımcı yok.';

  @override
  String get evtAtt2ListEmpty => 'Henüz onaylı katılımcı yok.';

  @override
  String evtAtt2ToastAbsent(String name) {
    return '$name gelmedi olarak işaretlendi';
  }

  @override
  String evtAtt2ToastPresent(String name) {
    return '$name geldi olarak işaretlendi';
  }

  @override
  String evtAtt2ToastReset(String name) {
    return '$name sıfırlandı';
  }

  @override
  String get evtAtt2StaffNoQr =>
      'Yoklamayı alanların kişisel QR kodu yoktur; katılımcıların QR kodunu okutursun.';

  @override
  String get evtAtt2ParticipantHint =>
      'Yoklama alınırken görevliye bu kodu göster. Başka bir şey yapman gerekmez.';

  @override
  String get evtAtt2StatusArrived => 'Yoklaman alındı';

  @override
  String get evtMeetLabel => 'Buluşma noktası';

  @override
  String get evtMeetHint => 'Örn. Mühendislik Fakültesi önü, ana giriş';

  @override
  String get evtMeetHelp =>
      'Katılımcıların toplanacağı yer (etkinlik yerinden ayrıdır).';

  @override
  String get evtMeetOpenMap => 'Haritada aç';

  @override
  String get evtMeetMapFail => 'Harita açılamadı.';

  @override
  String get evtMeetLat => 'Enlem (isteğe bağlı)';

  @override
  String get evtMeetLng => 'Boylam (isteğe bağlı)';

  @override
  String get evtMeetCoordInvalid =>
      'Enlem -90 ile 90, boylam -180 ile 180 arasında olmalı ve ikisi birlikte girilmeli.';

  @override
  String get evtEditEndedNote =>
      'Etkinlik sona erdi: yalnız açıklama düzenlenebilir.';

  @override
  String get unitNewsTitle => 'Bölümüm';

  @override
  String get unitNewsSemantic => 'Bölümümün duyuruları';

  @override
  String get unitNewsAttachments => 'Ekler';

  @override
  String get unitNewsError => 'Duyuru yüklenemedi.';

  @override
  String get qa1DelReauthBody =>
      'Hesabın Google veya Apple ile açıldığı için şifren yok. Silmek için bağlı hesabınla kimliğini yeniden doğrula. Bu işlem geri alınamaz.';

  @override
  String get qa1DelReauthAction => 'Kimliği doğrula ve hesabı sil';

  @override
  String get qa1NoPasswordNote =>
      'Hesabın Google veya Apple ile açıldığı için şifren yok. İstersen e-postana gelen kodla bir şifre belirleyebilirsin; sonra e-posta ve şifreyle de girebilirsin.';

  @override
  String get qa1PwSetButton => 'Şifre belirle';

  @override
  String get qa1TfNeedPassword =>
      'İki adımlı doğrulamayı kapatmak şifre ister. Hesabının şifresi yok: önce Şifre ekranından e-postana gelen kodla bir şifre belirle.';

  @override
  String get qa1TfDisableReauthBody =>
      'Hesabın şifresiz olduğu için Google veya Apple ile kimliğini doğrulayarak onayla. Güvenilen tüm cihazlar silinir.';

  @override
  String get widgetsRowTitle => 'Ana ekran widgetları';

  @override
  String get widgetsInfoTitle => 'Ana ekran widgetları';

  @override
  String get widgetsIntro =>
      'Yemek, ders, etkinlik, duyuru, anket ve sosyal özet bilgilerini uygulamayı açmadan ana ekranından gör.';

  @override
  String get widgetsListTitle => 'Hangi widgetlar var';

  @override
  String get widgetsList =>
      'Yemek menüsü, Ders programı, Yaklaşan etkinlikler, Kampüs duyuruları, Günün anketi, Hızlı erişim ve Sosyal özet.';

  @override
  String get widgetsIosTitle => 'iPhone';

  @override
  String get widgetsIosSteps =>
      'Ana ekranda boş bir yere uzun bas, sol üstteki + düğmesine dokun, BÜ Kampüs uygulamasını seç ve istediğin widgetı ekle.';

  @override
  String get widgetsAndroidTitle => 'Android';

  @override
  String get widgetsAndroidSteps =>
      'Ana ekranda boş bir yere uzun bas, Widgetlar seçeneğine dokun, BÜ Kampüs uygulamasını bul ve istediğin widgetı ana ekrana sürükle.';

  @override
  String get widgetsRefreshTitle => 'Yenilenme';

  @override
  String get widgetsRefresh =>
      'Bilgiler uygulamayı açtığında, bir şey değiştiğinde ve düzenli aralıklarla yenilenir. Widgeta dokununca ilgili ekran açılır.';

  @override
  String get widgetsPrivacyTitle => 'Gizlilik';

  @override
  String get widgetsPrivacy =>
      'Widgetlarda başka kullanıcıların adı, mesajı veya fotoğrafı görünmez; sosyal özet yalnızca sayıları gösterir. Çıkış yapınca widgetlardaki bilgiler silinir ve Giriş yap durumuna döner.';

  @override
  String get chatLongShowMore => 'Devamını gör';

  @override
  String get chatLongShowLess => 'Daha az göster';

  @override
  String get evtLiveCheckedInTitle => 'Okutuldu';

  @override
  String get evtLiveCheckedInBody => 'Yoklaman alındı.';

  @override
  String evtLiveCheckedInAt(String time) {
    return 'Saat $time';
  }

  @override
  String evtLiveLastScanned(String name) {
    return 'Son okutan: $name';
  }

  @override
  String evtLiveScanCount(String name) {
    return '$name okuttu';
  }

  @override
  String get settingsFindContacts => 'Rehberden kişi bul';

  @override
  String get chatMiscContactsFind => 'Rehberden kişi bul';

  @override
  String get chatMiscContactsRationale =>
      'Rehberinizdeki Bingöl Üniversitesi kişilerini bulabilmemiz için rehbere erişmemiz gerekir. Rehberiniz sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir.';

  @override
  String get chatMiscContactsSubtitle => 'Bingöl Üniversitesi kişileri';

  @override
  String get chatMiscContactsPermTitle => 'Rehber izni gerekli';

  @override
  String get chatMiscContactsPermText =>
      'Rehberinizdeki kampüs kişilerini bulabilmemiz için rehbere erişim izni vermeniz gerekir.';

  @override
  String get chatMiscContactsPermAction => 'İzin ver';

  @override
  String get chatMiscContactsNoneTitle => 'Eşleşen kişi yok';

  @override
  String get chatMiscContactsNoneText =>
      'Rehberindeki kişilerden uygulamayı kullanan kimse bulunamadı. Arkadaşların katıldıkça burada görünür.';

  @override
  String get chatMiscContactsSearchHint => 'Kişilerde ara';

  @override
  String get chatMiscContactsTruncated =>
      'Saatlik istek sınırına ulaşıldı; kalan kişiler daha sonra eşleştirilecek.';

  @override
  String get qa4ContactsConsentTitle => 'Rehberden bulunabilirim';

  @override
  String get qa4ContactsConsentText =>
      'Rehberindeki kişileri bulmak için önce bu ayarı açman gerekir. Eşleşme karşılıklıdır: yalnız bu ayarı açmış kişileri bulursun, onlar da seni yalnız bu ayar açıkken bulabilir. İstediğin zaman kapatabilirsin.';

  @override
  String get qa4ContactsConsentAction => 'Aç ve devam et';

  @override
  String get qa4ContactsConsentOff => 'Rehberden bulunabilirliği kapat';

  @override
  String get chatMiscContactsNoSearchMatch => 'Aramanla eşleşen kişi yok.';

  @override
  String chatMiscContactsCount(String n) {
    return '$n KİŞİ';
  }

  @override
  String get chatMiscMessage => 'Mesaj';

  @override
  String get chatMiscContactsPrivacy =>
      'Rehberin sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir.';

  @override
  String get permContactsTitle => 'Rehber';

  @override
  String get permContactsText =>
      'Rehberinizdeki Bingöl Üniversitesi kişilerini bulup sohbet başlatabilmeniz için gerekir. Rehberiniz sunucuya gönderilmez.';

  @override
  String get sistemuiPermContactsText =>
      'Rehberinizdeki üniversite kişilerini bulup sohbet başlatmanız için. Rehberiniz sunucuya gönderilmez.';

  @override
  String get p23PrivacyShort => 'Rehberiniz sunucuya gönderilmez.';

  @override
  String get p23NoneText =>
      'Rehberindeki kişilerden uygulamayı kullanan kimse bulunamadı.';

  @override
  String get liveTrackStart => 'Canlı takip et';

  @override
  String get liveTrackStop => 'Canlı takibi bitir';

  @override
  String get liveTrackStarted => 'Canlı takip başladı';

  @override
  String get liveTrackFailed => 'Canlı takip başlatılamadı';

  @override
  String get liveTrackDisabled =>
      'Canlı Etkinlikler kapalı. Ayarlardan açabilirsiniz.';

  @override
  String get liveLabelStartsIn => 'Başlamasına';

  @override
  String get liveLabelEndsIn => 'Bitmesine';

  @override
  String get liveChannelName => 'Canlı güncellemeler';

  @override
  String get hubSumClubs => 'Kulüp';

  @override
  String get hubSumEvents => 'Yaklaşan etkinlik';

  @override
  String get hubSumPending => 'Bekleyen başvuru';

  @override
  String get hubSumManaged => 'Yönettiğim';

  @override
  String get hubPanel => 'Yönetim Paneli';

  @override
  String get hubViewEvents => 'Etkinliklerini gör';

  @override
  String get hubUpcomingHead => 'Yaklaşan etkinliklerim';

  @override
  String get hubManageTitle => 'Kulüp yönetimi';

  @override
  String get hubStatMembers => 'Toplam üye';

  @override
  String get hubActEvents => 'Etkinlikleri yönet';

  @override
  String get hubActEventsSub => 'Düzenle, katılımcıları ve yoklamayı yönet';

  @override
  String get hubActAnnounce => 'Duyuru oluştur';

  @override
  String get hubActPosts => 'Kulüp gönderilerini yönet';

  @override
  String get hubActRoles => 'Yönetici yetkilerini yönet';

  @override
  String get hubSwitchClub => 'Kulüp değiştir';

  @override
  String get hubNoAccess => 'Bu kulüpte yönetim yetkin yok.';

  @override
  String get hubSubPlanned => 'Katılacaklarım';

  @override
  String get hubSubRequests => 'Başvurularım';

  @override
  String get hubNoRequests => 'Bekleyen başvurun yok.';

  @override
  String get hubNoPast => 'Geçmiş etkinliğin yok.';

  @override
  String get profileClubHub => 'Kulüp ve Etkinliklerim';

  @override
  String get hubOpenManage => 'Kulübümü yönet';

  @override
  String get shareUnavailablePost =>
      'Bu gönderi görüntülenemiyor. Gizli bir hesaba ait olabilir.';

  @override
  String postPhotoOfTotal(String n, String total) {
    return 'Fotoğraf $n/$total';
  }

  @override
  String get postMultiBadgeLabel => 'Çok fotoğraflı gönderi';

  @override
  String composePhotoCount(String n, String max) {
    return '$n/$max fotoğraf';
  }

  @override
  String get composeAddPhotos => 'Fotoğraf ekle';

  @override
  String get composeAddPhotosShort => 'Ekle';

  @override
  String get composeRemovePhoto => 'Fotoğrafı kaldır';

  @override
  String get composeReorderHint => 'Sıralamak için basılı tutup sürükle';

  @override
  String composeUploadingN(String n, String total) {
    return 'Yükleniyor $n/$total';
  }

  @override
  String get postComposeErrMediaLimit =>
      'Bir gönderiye en çok 10 fotoğraf eklenebilir.';

  @override
  String get postComposeErrMediaMix =>
      'Video gönderisi tek başına olmalı; fotoğrafla karıştırılamaz.';

  @override
  String get evCalRow => 'Takvime ekle ve hatırlat';

  @override
  String get evCalRowDone => 'Takvimde · hatırlatıcı açık';

  @override
  String get evCalSheetTitle => 'Takvime ekle';

  @override
  String get evCalBody =>
      'Etkinlik cihaz takviminize eklenir; hatırlatıcıyı takvim uygulamanız gönderir. Yalnız BÜ Kampüs etkinlikleri eklenir ve silinir.';

  @override
  String get evCalPromptBody =>
      'Katılımınız alındı. Etkinliği takviminize ekleyip hatırlatalım mı? Önerilen: 1 saat önce.';

  @override
  String get evCalRemind => 'Hatırlatma';

  @override
  String get evCalLead15 => '15 dakika önce';

  @override
  String get evCalLead60 => '1 saat önce';

  @override
  String get evCalLead1440 => '1 gün önce';

  @override
  String get evCalAdd => 'Takvime ekle';

  @override
  String get evCalUpdate => 'Güncelle';

  @override
  String get evCalRemove => 'Takvimden kaldır';

  @override
  String get evCalLater => 'Şimdi değil';

  @override
  String get evCalNever => 'Bir daha sorma';

  @override
  String get evCalAdded => 'Etkinlik takvime eklendi';

  @override
  String get evCalUpdated => 'Takvim kaydı güncellendi';

  @override
  String get evCalRemoved => 'Takvimden kaldırıldı';

  @override
  String get evCalFailed => 'Takvime yazılamadı.';

  @override
  String get evCalPast => 'Başlamış etkinlik takvime eklenmez.';

  @override
  String clubShareMsg(String name, String link) {
    return '$name kulübüne BÜ Kampüs uygulamasında göz at: $link';
  }

  @override
  String offlineStripWithTime(String zaman) {
    return 'Çevrimdışı · son güncelleme $zaman';
  }

  @override
  String get offlineStripNoTime => 'Çevrimdışı · kayıtlı veriler gösteriliyor';

  @override
  String get menuRemTitle => 'Günlük menü hatırlatıcısı';

  @override
  String get menuRemSub =>
      'Her gün seçtiğin saatte bugünün menüsünü hatırlatır';

  @override
  String get menuRemTime => 'Hatırlatma saati';

  @override
  String get menuRemNotifTitle => 'Bugünün menüsü';

  @override
  String get menuRemNotifBody => 'Yemekhane menüsüne göz at.';

  @override
  String get menuRemPermNeeded => 'Hatırlatıcı için bildirim izni gerekli.';

  @override
  String get searchForum => 'Forum';

  @override
  String get icerikGroupForum => 'FORUM';

  @override
  String get searchSuggestionsLabel => 'Arama önerileri';

  @override
  String searchForumLikes(String n) {
    return '$n beğeni';
  }

  @override
  String get svTitle => 'Kaydedilenler';

  @override
  String get svFilterAll => 'Tümü';

  @override
  String get svFilterNews => 'Haberler';

  @override
  String get svFilterEvents => 'Etkinlikler';

  @override
  String get svFilterClubs => 'Kulüpler';

  @override
  String get svFilterPolls => 'Anketler';

  @override
  String get svFilterPosts => 'Gönderiler';

  @override
  String get svFilterForum => 'Forum';

  @override
  String get svEmptyTitle => 'Henüz kaydettiğin bir şey yok';

  @override
  String get svEmptyBody =>
      'Haber, etkinlik, kulüp, anket, gönderi ve forum konularındaki yer imi simgesiyle kaydedebilirsin.';

  @override
  String get svEmptyFilterTitle => 'Bu türde kayıt yok';

  @override
  String get svEmptyFilterBody =>
      'Başka bir tür seç ya da bu türden bir içeriği kaydet.';

  @override
  String get svErrorTitle => 'Kaydedilenler yüklenemedi';

  @override
  String get svRemoved => 'Kayıttan çıkarıldı';

  @override
  String get svRemoveAction => 'Kaydı kaldır';

  @override
  String get svOpenFailed => 'Bu içerik artık açılamıyor';

  @override
  String get svSave => 'Kaydet';

  @override
  String get svUnsave => 'Kaydı kaldır';

  @override
  String get svSavedToast => 'Kaydedildi';

  @override
  String get svTypeNews => 'Haber';

  @override
  String get svTypeEvent => 'Etkinlik';

  @override
  String get svTypeCommunity => 'Kulüp';

  @override
  String get svTypePoll => 'Anket';

  @override
  String get svTypeAcademic => 'Akademik';

  @override
  String get svTypePost => 'Gönderi';

  @override
  String get svTypeTopic => 'Forum konusu';

  @override
  String get svTypeComment => 'Forum yorumu';

  @override
  String get svMenuRow => 'Kaydedilenler';

  @override
  String get muteAction => 'Bildirimleri sessize al';

  @override
  String get muteActionOff => 'Bildirimleri aç';

  @override
  String get muteOnToast => 'Bildirimler sessize alındı';

  @override
  String get muteOffToast => 'Bildirimler açıldı';

  @override
  String get muteCriticalNote =>
      'İptal, kabul, rol ve katılım gibi önemli bildirimler sessize alsan da gelir.';

  @override
  String get mutedRowTitle => 'Sessize alınanlar';

  @override
  String get mutedRowSub => 'Sessize aldığın kulüpler ve etkinlikler';

  @override
  String get mutedClubs => 'Kulüpler';

  @override
  String get mutedEvents => 'Etkinlikler';

  @override
  String get mutedEmptyTitle => 'Sessize aldığın bir şey yok';

  @override
  String get mutedEmptyBody =>
      'Kulüp ya da etkinlik sayfasındaki menüden bildirimleri sessize alabilirsin.';

  @override
  String get mutedErrorTitle => 'Liste yüklenemedi';

  @override
  String get mutedUnmute => 'Aç';

  @override
  String mutedClubFallback(String id) {
    return 'Kulüp $id';
  }

  @override
  String mutedEventFallback(String id) {
    return 'Etkinlik $id';
  }

  @override
  String get reportsMineTitle => 'Şikayetlerim';

  @override
  String get reportsMineSub => 'Gönderdiğin şikayetlerin durumu';

  @override
  String get reportsMineNote =>
      'Gizlilik için yalnızca genel durum gösterilir.';

  @override
  String get reportsStatusOpen => 'Açık';

  @override
  String get reportsStatusResolved => 'Sonuçlandı';

  @override
  String get reportsEmptyTitle => 'Henüz şikayet etmedin';

  @override
  String get reportsEmptyBody =>
      'Bir içeriği şikayet ettiğinde burada genel durumunu görürsün.';

  @override
  String get reportsErrorTitle => 'Şikayetler yüklenemedi';

  @override
  String reportsResolvedOn(String date) {
    return 'Sonuçlanma: $date';
  }

  @override
  String get reportsTypeUser => 'Kullanıcı';

  @override
  String get reportsTypeMessage => 'Mesaj';

  @override
  String get reportsTypePost => 'Gönderi';

  @override
  String get reportsTypeCommunity => 'Kulüp';

  @override
  String get reportsTypeEvent => 'Etkinlik';

  @override
  String get reportsTypeTopic => 'Forum konusu';

  @override
  String get reportsTypeComment => 'Forum yorumu';

  @override
  String get reportsTypeOther => 'İçerik';

  @override
  String get reportsReasonPersonalInfo => 'Kişisel bilgi paylaşımı';

  @override
  String get chatSeenAgoNow => 'az önce';

  @override
  String chatSeenAgoMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n dakika önce',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n saat önce',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n gün önce',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoWeeks(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hafta önce',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ay önce',
    );
    return '$_temp0';
  }

  @override
  String chatSeenAgoYears(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n yıl önce',
    );
    return '$_temp0';
  }

  @override
  String chatStatusSentAt(String when) {
    return 'Gönderildi · $when';
  }

  @override
  String chatStatusSeenAt(String when) {
    return 'Görüldü · $when';
  }

  @override
  String get pcmWriteHint => 'Yorum ekle…';

  @override
  String get pcmEmptyTitle => 'İlk yorumu sen yaz';

  @override
  String get pcmEmptyBody => 'Düşüncelerini paylaş, sohbeti başlat.';

  @override
  String pcmReplyingTo(String name) {
    return '$name kişisine yanıt veriliyor';
  }

  @override
  String get pcmHideReplies => 'Yanıtları gizle';

  @override
  String get pcmSendFailed => 'Gönderilemedi';

  @override
  String get pcmRetry => 'Yeniden dene';

  @override
  String get pcmSending => 'Gönderiliyor…';

  @override
  String get pcmDeleted => 'Bu yorum silindi';

  @override
  String get pcmMenuDelete => 'Sil';

  @override
  String get pcmMenuReport => 'Şikayet et';

  @override
  String get pcmMenuCopy => 'Metni kopyala';

  @override
  String get pcmCopied => 'Kopyalandı';

  @override
  String get pcmMoreActions => 'Yorum seçenekleri';

  @override
  String get pcmLikeA11y => 'Yorumu beğen';

  @override
  String get pcmUnlikeA11y => 'Beğenmekten vazgeç';

  @override
  String pcmLikeCountA11y(String count) {
    return '$count beğeni';
  }

  @override
  String pcmCommentCountA11y(String count) {
    return '$count yorum';
  }

  @override
  String pcmViewAll(String count) {
    return '$count yorumun tümünü gör';
  }

  @override
  String get pcmViewAllPlain => 'Yorumları gör';

  @override
  String get pcmErrTooLong => 'Yorum en çok 500 karakter olabilir.';

  @override
  String get pcmErrPostGone => 'Bu gönderi artık yok.';

  @override
  String get pcmErrParent => 'Yanıtladığın yorum artık yok.';

  @override
  String get pcmErrRate =>
      'Çok hızlı yorum yapıyorsun. Biraz sonra tekrar dene.';

  @override
  String get pcmMoreReplies => 'Daha fazla yanıt';

  @override
  String get pcmSortLabel => 'Sırala';

  @override
  String pcmCharsLeft(String n) {
    return '$n karakter kaldı';
  }

  @override
  String get postSettingsAdvanced => 'Gelişmiş ayarlar';

  @override
  String get postSettingsHideLikes => 'Beğeni sayısını gizle';

  @override
  String get postSettingsHideLikesDesc =>
      'Başkaları bu gönderinin beğeni sayısını göremez. Sen görmeye devam edersin.';

  @override
  String get postSettingsCommentsOff => 'Yorum yapmayı kapat';

  @override
  String get postSettingsCommentsOffDesc =>
      'Kimse bu gönderiye yorum yapamaz. Mevcut yorumlar görünür kalır.';

  @override
  String get postHideLikesHint => 'Beğeni sayısı başkalarına gizli';

  @override
  String get pcmCommentsDisabled => 'Bu gönderide yorumlar kapalı';

  @override
  String get postMenuHideLikes => 'Beğeni sayısını gizle';

  @override
  String get postMenuShowLikes => 'Beğeni sayısını göster';

  @override
  String get postMenuCommentsOff => 'Yorumları kapat';

  @override
  String get postMenuCommentsOn => 'Yorumları aç';

  @override
  String get postSettingsLikesHiddenDone => 'Beğeni sayısı gizlendi';

  @override
  String get postSettingsLikesShownDone => 'Beğeni sayısı gösteriliyor';

  @override
  String get postSettingsCommentsOffDone => 'Yorumlar kapatıldı';

  @override
  String get postSettingsCommentsOnDone => 'Yorumlar açıldı';

  @override
  String get postSettingsFailed => 'Ayar değiştirilemedi. Tekrar dene.';

  @override
  String get pcmDeleteOthersTitle => 'Yorum silinsin mi?';

  @override
  String get pcmDeleteOthersBody =>
      'Bu yorum herkes için kaldırılır. Bu işlem geri alınamaz.';

  @override
  String get accTitle => 'Hesaplar';

  @override
  String get accSwitch => 'Hesap değiştir';

  @override
  String get accAdd => 'Hesap ekle';

  @override
  String get accActive => 'Etkin hesap';

  @override
  String get accExpired => 'Oturum süresi doldu';

  @override
  String get accOptions => 'Hesap seçenekleri';

  @override
  String get accRemove => 'Bu cihazdan kaldır';

  @override
  String get accRemoveTitle => 'Hesap kaldırılsın mı?';

  @override
  String accRemoveBody(String name) {
    return '$name hesabının oturumu bu cihazda kapatılır. Hesap silinmez; istediğin zaman tekrar giriş yapabilirsin.';
  }

  @override
  String get accRemoveConfirm => 'Kaldır';

  @override
  String get accLimit => 'Bu cihaza en fazla 5 hesap eklenebilir.';

  @override
  String get accPushNote => 'Bildirimler yalnızca etkin hesaba gelir.';

  @override
  String accSwitchedTo(String name) {
    return '$name hesabına geçildi';
  }

  @override
  String accExpiredSwitched(String name) {
    return '$name oturumu sona erdi, başka hesaba geçildi.';
  }

  @override
  String get accExpiredSwitchedAnon =>
      'Oturum sona erdi, başka hesaba geçildi.';

  @override
  String get accSignOutAll => 'Tüm hesaplardan çık';

  @override
  String accSignOutAllBody(String count) {
    return 'Bu cihazdaki $count hesabın hepsinden çıkış yapılır.';
  }

  @override
  String get accAddSub =>
      'Başka bir hesapla giriş yap ya da yeni hesap oluştur. Mevcut hesabın açık kalır.';

  @override
  String accReloginHint(String mail) {
    return 'Oturum süresi doldu. Yeniden giriş yap: $mail';
  }

  @override
  String get accBusy =>
      'Hesap şu an değiştirilemiyor. Biraz sonra tekrar dene.';

  @override
  String get accAccountNoName => 'Hesap';

  @override
  String get postPeekOpen => 'Gönderiyi aç';

  @override
  String get clubAudienceLabel => 'Önerilecek bölümler';

  @override
  String get clubAudienceHint => 'Seçilmedi (isteğe bağlı)';

  @override
  String get clubAudienceSheetTitle => 'Kulüp kime önerilsin?';

  @override
  String get clubAudienceSheetHint =>
      'Yalnızca öneri sıralamasını etkiler; kulüp herkese görünür kalır.';

  @override
  String get clubAudienceSearchHint => 'Fakülte veya bölüm ara';

  @override
  String get clubAudienceNoMatch => 'Eşleşen fakülte veya bölüm yok';

  @override
  String get clubAudienceRetry => 'Tekrar dene';

  @override
  String get clubAudienceClear => 'Temizle';

  @override
  String get clubAudienceExpand => 'Bölümleri göster';

  @override
  String get clubAudienceCollapse => 'Bölümleri gizle';

  @override
  String clubAudienceDeptCount(int count) {
    return '$count bölüm';
  }

  @override
  String clubAudienceSelected(int count) {
    return '$count hedef seçildi';
  }

  @override
  String clubAudienceDone(int count) {
    return 'Tamam ($count)';
  }

  @override
  String get clubRecommendedTitle => 'Bölümüne uygun kulüpler';

  @override
  String get clubRecommendedAll => 'Tüm kulüpler';

  @override
  String get eventRecommendedTitle => 'Bölümüne uygun etkinlikler';
}
