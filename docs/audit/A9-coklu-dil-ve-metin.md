# A9 - Çoklu dil ve metin kalitesi denetimi

Tarih: 2026-10-31. Aşama: yalnız denetim (kod/metin DEĞİŞTİRİLMEDİ). Canlı sunucuya/siteye erişilmedi.
Dinamik doğrulama: A7 test yığını (`http://localhost:18081`), yalnız API yanıt dilleri için (25 senaryo x 3 dil + 12 `Accept-Language` varyantı). Not: dil varyantı testinin sonunda giriş ucunun IP hız sınırına takıldım (429, yığın ortak; kısa süreli).

## 0. Kapsam ve gerçek sayılar

| Alan | Kapsam | Yöntem |
|---|---|---|
| Mobil `app_tr/en/ar.arb` | 2736 anahtar x 3 dil = 8208 metin (anahtar eşitliği, yer tutucu, ICU, boşluk/noktalama, Latin/Türkçe karakter karışımı, rakam, yinelenen metin: tamamı otomatik) | Betik + insan okuması: TR ve EN yaklaşık 1100 metin (kimlik, sohbet, etkinlik, kulüp, anket, destek, ayarlar, bildirim, p21/p22, kamera, çevrimdışı, hata), AR yaklaşık 450 metin |
| Mobil Dart/Kotlin/iOS | `lib/` içi kullanıcıya görünen sabit metin taraması (Text, SnackBar, hint, tooltip, Semantics, throw), `LocalReminders.kt`, `Info.plist` | grep + okuma |
| Backend `i18n/*.properties` | 26 modül x 3 dil = 632 anahtar x 3 = 1896 metin; 392 `error.<KOD>` anahtarı; `ApiException` ile kullanılan 346 kodun hepsi çeviride var | Betik (anahtar eşitliği, `{0}` argüman uyumu, kesme işareti, tr ile aynı kalanlar) |
| E-posta | `mail*.properties` + `mail-templates/layout.html` + `MailRenderer/MailTransport` | okuma |
| Bildirim/push metinleri | 130+ `notif.*` anahtarı tr/en/ar tamamı okundu; `push*.properties` | okuma |
| Web `src/i18n` | Site kapsamı 813 anahtar x 3 dil (tr/en/ar eşit); yönetim paneli yalnız tr (~4160 anahtar, yalnız ASCII-yazım ve ham anahtar taraması); `t('...')` kullanımı 3241 benzersiz anahtar, sözlükte olmayan: 0 | betik |
| Dinamik | 25 hata senaryosu x tr/en/ar + `Accept-Language` çözümleme | curl/urllib |

Genel sonuç: yapısal bütünlük çok iyi (anahtar eşitliği, yer tutucu, ICU, argüman sayısı, tüm hata kodları 3 dilde). Sorunlar çoğunlukla üslup tutarsızlığı (sen/siz), terim tutarsızlığı, çoğul/tekil, iOS izin metinleri ve birkaç yanıltıcı/yanlış metin.

## 1. Bulgu özeti

| Şiddet | Adet |
|---|---|
| KRİTİK | 5 (A9-01..05) |
| YÜKSEK | 8 (A9-06..13) |
| ORTA | 19 (A9-14..32) |
| DÜŞÜK | 13 (A9-33..45) |
| Toplam | 45 |

En kritik 5: A9-01 (tüm cihazlardan çıkış metni "hesabınız kapatılacak"), A9-02 (`msg.forgot.sent` "bağlantı" diyor, kod gidiyor), A9-03 ("BU Kampüs" marka yazımı açılış ekranında), A9-04 ("Resmi" etiketi), A9-05 (blok/okunamayan mesaj yer tutucuları EN/AR kullanıcıya Türkçe).

---

## 2. KRİTİK

### A9-01 | KRİTİK | tr | Yanıltıcı: oturum kapatma "hesap kapatma" gibi söyleniyor
- Anahtar: `mobile/lib/l10n/app_tr.arb:61` `settingsLogoutAllBody`
- Mevcut: "Hesabınız tüm cihazlarda kapatılacak ve yeniden giriş yapmanız gerekecek."
- Sorun: Kullanıcı hesabının kapanacağını/silineceğini sanabilir (en: "You will be logged out on all devices", doğru). Aynı ekranın `p19LogoutAllSub` ("Diğer açık telefon ve tarayıcı oturumlarını kapatır") metni doğru.
- Önerilen: "Tüm cihazlardaki oturumlarınız kapatılacak ve yeniden giriş yapmanız gerekecek."

### A9-02 | KRİTİK | tr | Yanlış: "bağlantı" deniyor, e-postaya kod gidiyor
- Anahtar: `backend/src/main/resources/i18n/messages.properties:336` `msg.forgot.sent` (dinamik doğrulandı: `POST /api/auth/forgot-password` 202 gövdesi)
- Mevcut (tr): "Şifre sıfırlama bağlantısı için hesap uygunsa e-posta adresinize kod gönderildi."
- en/ar doğru ("a password reset code has been sent" / "رمز إعادة تعيين").
- Önerilen (tr): "Hesap uygunsa e-posta adresinize şifre sıfırlama kodu gönderildi."

### A9-03 | KRİTİK | tr | Marka yazımı: "BU Kampüs" / "BU KAMPÜS" (Ü yok)
Marka tek yazım: "BÜ Kampüs". Sapmalar:
- `mobile/lib/features/auth/welcome_page.dart:166` `Text('BU Kampüs', ...)` (ilk açılış/karşılama ekranı)
- `mobile/lib/features/home/home_parts.dart:498` `Text('BU KAMPÜS', ...)` (Ana Sayfa); doğrusu "BÜ KAMPÜS"
- `backend/.../event/extras/IcsService.java:42` `IcsWriter.calendar("BU Kampus", ...)` -> kullanıcının takvim uygulamasında görünen takvim adı (`X-WR-CALNAME`); `IcsWriter.java:25`, `academic/IcsBuilder.java:40` PRODID "BU Kampus"
- `backend/.../observability/SystemAlertService.java:111` yönetici e-posta konusu "[BU Kampus] Sistem uyarisi (CRIT): ..." (ASCII-leştirilmiş Türkçe de: "uyarisi", "gosterge")
- Önerilen: hepsi "BÜ Kampüs" (PRODID ve log gibi teknik alanlar ASCII kalabilir; kullanıcıya görünen takvim adı ve ekran metni değil).
- Doğru olanlar: ARB, web `index.html`, iOS `CFBundleDisplayName`, Android `app_name`, e-posta gönderen adı, `main.dart`.

### A9-04 | KRİTİK (karar gerekir) | tr/en/ar | "Resmi" / "Official" etiketi
Kullanıcının yasaklı ifade listesi ("Resmi") ve `child-safety` sayfasındaki "üniversitenin resmî uygulaması değildir" beyanı ile çelişme riski. Düz etiket/rozet olarak geçen yerler:
- `app_tr.arb:1737` `eventListOfficial` = "Resmi" (en "Official", ar "رسمي"), `:1821` `homeOfficialEvent` = "Resmi etkinlik", `:3315` `akademik2OfficialTag` = "Resmi"
- Sekme/başlık: `acadExamsTabOfficial` "Resmi program", `acadTimeOfficialDefault` "Resmi dönem", `p17OfficialEmptyTitle` "Resmi program yayınlanmadı", `acadHubExamsSub`, `acadExamsEmptyOfficial`
- Gerçek bir kullanım (tatil türü "Resmi tatil" `acadEventKindPublicHoliday`) sorunsuz.
- Sorun: uygulama bağımsızdır; bir etkinlikte/duyuruda yalın "Resmi" rozeti "BÜ Kampüs resmi" ya da "üniversite onaylı" izlenimi verebilir.
- Önerilen: rozet "Üniversite" (en "University", ar "الجامعة"); akademik takvim/sınav için "Üniversite takvimi / sınav programı" ya da "Fakülte programı"; "Resmi tatil" kalabilir. Web'de "resmî sitelerden derlenir" (kaynak belirten ifade) doğru kullanım, korunabilir.
- Not: web "resmî" (düzeltme işaretli) yazıyor, mobil "resmi"; bkz. A9-34.

### A9-05 | KRİTİK | en/ar | Sohbet yer tutucuları kullanıcıya Türkçe
- `backend/.../messaging/dto/MessagingDtos.java:22` `BLOCKED_TEXT` = "Engellediğiniz kullanıcının mesajı gizlendi"; `:18` `UNREADABLE_TEXT` = "Bu mesaj görüntülenemiyor". Aynı sabitler `MessageViewAssembler.java:117,120` (yanıt önizlemesi) ve WS yükünde.
- Mobil `message_placeholder.dart` yalnız `kAdminRemovedText`, `kModRemovedText`, `kDeletedText` sabitlerini yerelleştiriyor; "tanınmayan metin olduğu gibi kalır" (kod yorumu). Sonuç: EN/AR kullanıcı bu iki durumda Türkçe cümle görür.
- Önerilen: sunucu ayrı bayrak (`blocked`, `unreadable`) göndersin, istemci `chat...` ARB anahtarıyla gösterin; ya da `kBlockedText`/`kUnreadableText` eşlemesi eklensin. Yeni ARB: tr "Engellediğiniz kullanıcının mesajı gizlendi", en "A message from a user you blocked is hidden", ar "رسالة من مستخدم قمت بحظره مخفية" (anadil incelemesi önerilir); tr "Bu mesaj görüntülenemiyor", en "This message cannot be displayed", ar "تعذر عرض هذه الرسالة".

---

## 3. YÜKSEK

### A9-06 | YÜKSEK | tr | Sen/siz hitabı karışık (aynı ekran ve akış içinde)
Kullanılan 2339 anahtarda yaklaşık 120 "siz" ve 90 "sen" metni var; kural belgelenmemiş. Aynı ekranda karışan örnekler:
- Giriş akışı: `loginSubtitle` "Okul e-postanızla giriş yapın." (siz) / `authUnverifiedNotice` "E-postanı doğrula. ... hesabının doğrulanması gerekir." (sen) / `loginReplacedNotice` "Hesabına başka bir cihazdan giriş yapıldı. Güvenliğin için..." (sen) / `authResetDoneBody` "Yeni şifrenizle giriş yapabilirsiniz." (siz). Satırlar: `app_tr.arb:73,123`.
- Güvenlik ayarı: `profil2SecCurrentHint` "Mevcut şifreniz" (siz) / `profil2SecUpdated` "Şifren güncellendi." (sen) / `profilePrefsEnterPassword` "Şifrenizi girin." (siz) / `profil2DelConfirmBody` "şifreni gir" (sen).
- Bildirim ayarları: `p21HelpPermOff` "alamazsınız" (siz) ve sonraki ekran `p22SaveGalleryDesc` "aldığın ve gönderdiğin ... galerine" (sen).
- Rehber: `chatMiscContactsRationale` "Rehberinizdeki" (siz) / `p23NoneText` "Rehberindeki" (sen) / `p23PrivacyShort` "Rehberiniz" (siz).
- Dağılım: auth, poll, p13, support, p21, perm, p19: siz; club, profil2, acad, event, p17, etkinlik2: sen; chat, post, profile: karışık.
- Sunucu: hata/bildirim metinleri "siz", yalnız `notif.post.like.body`/`notif.user.follow.body` "gönderini/seni" (sen) ("Gönderinizin metni..." ile karışıyor).
- Öneri: tek ton seçilmeli; "siz" önerilir (hukuk metni, e-posta, izin, hata ve sunucu bildirimleri zaten "siz"). Anahtar bazlı sen/siz listesi çıkarılıp ekran ekran toplu düzeltme yapılmalı.

### A9-07 | YÜKSEK | en/ar | iOS izin açıklamaları yalnız Türkçe
- `mobile/ios/Runner/Info.plist:78-87` `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSContactsUsageDescription`, `NSMicrophoneUsageDescription`: tek dil (tr). `InfoPlist.strings` (en/ar) yok, `CFBundleLocalizations` yok.
- Uygulama içi dil EN/AR seçilse de iOS sistem izin penceresi Türkçe (cihaz dili de EN/AR ise yine Türkçe). App Store incelemesinde de risk.
- Önerilen: `ios/Runner/{tr,en,ar}.lproj/InfoPlist.strings` + Info.plist'e `CFBundleLocalizations`; metinler ARB'deki `permCameraText`, `permPhotosText`, `chatMiscContactsRationale`, `permMicrophoneText` ile aynı sözlükten.

### A9-08 | YÜKSEK | en/ar | Çoğul/tekil işlenmiyor (2736 anahtarda yalnız 2 ICU plural)
Yalnız `p14EventCount` ve `p02FacultyCount` plural. Diğerleri sabit çoğul:
- EN (19+ anahtar): `homeMemberCount` "{count} members", `p12CountClubs` "{count} clubs", `p12CountRequests`, `p15PickerMembers`, `p11LikeCount`/`p04LikeCount`/`p05SearchLikes` "{n} likes", `p13PollDone` "{n} votes", `p13PollArchiveCount` "{n} Polls Archived", `p17DayPlanned` "{n} classes scheduled", `p10AlbumCount`, `p20RangeDays/Weeks`, `p03HomeLunchCount` "Lunch • {n} dishes", `p15CodeChars`, `acadCountdownHours`, `p16SetCancelNote` "{n} attendees..." -> n=1: "1 members", "1 likes", "1 classes scheduled".
- AR: `p17DayPlanned` "{n} محاضرات مجدولة" (n=1: "1 محاضرات"; 11+ yanlış), `p13PollArchiveCount` "{n} استطلاعات", `p20RangeDays` "{n} أيام" (11+ "يومًا"), `p20RangeWeeks` "{n} أسابيع", `p03HomeLunchCount` "{n} أصناف", `commonDaysAgo` "منذ {n} يوم" (3-10: "أيام").
- Backend AR: `messages_ar.properties:204` `notif.mod.reporter.restricted.body` "{0} أيام"; `:74-76` `notif.news.many.*` "{0} أخبار/إعلانات/فعاليات جديدة"; `notif.message.many` "{0} رسائل جديدة" (11+ için "رسالة"). Arapça için ICU/MessageFormat `choice` ya da cümleyi sayı-dostu yeniden kurmak gerekir.
- TR etkilenmez (sayıdan sonra tekil). Öneri: EN/AR için `{n, plural, ...}` (ar: zero/one/two/few/many/other); yer tutucu adı sabit kalsın.

### A9-09 | YÜKSEK | tr/en/ar | Terim: Kulüp / Topluluk (Club / Community / نادي / مجتمع)
Mobil ve backend "Kulüp/Club/نادي" (123 / 76 kullanım), web site ve yönetim "Topluluk/Community/مجتمع":
- Web: `site.feat.communities.title` "Topluluklar" / "Communities" / "المجتمعات" (ad. özellik adı) ve "öğrenci toplulukları" (`site.ts:34,68`), `pg.help.cat.features.title` "Mesajlar ve topluluklar", `admin.nav.communities` "Topluluklar". Mobilde aynı özellik "Kulüpler".
- Mobil içinde: `p11UnavailableBody` "Bu topluluk geçici olarak dondurulmuştur" (kulüp ekranında), `p12ConsentNote/Bold` "topluluk ilkelerine", `p13PollNoMoreBody`, `profilePrefsNotifCommunities` "Topluluklar" (bildirim tercihi), `p20PrefClubsGroupSub` "Topluluk hareketleri", `p02WelcomeClubsSub`.
- Backend AR: `messages_ar.properties:290` `notif.community.transferDeclined.body` "...للمجتمع "{1}"" (kulüp: "للنادي"); diğer 38 yerde "النادي".
- Öneri: kullanıcıya görünen her yerde tek terim "Kulüp / Club / نادي". "Topluluk Kuralları / Community Rules / قواعد المجتمع" belge adı olarak kalabilir (ayrı kavram).

### A9-10 | YÜKSEK | tr | Terim: Şikâyet (mobil) / Rapor (backend, web)
- Mobil düğme/ekran: "Şikâyet et" (21 yerde), "Şikâyetiniz alındı".
- Sunucu: `messages.properties:35` `ALREADY_REPORTED` "Bu içeriği zaten raporladınız.", `CANNOT_REPORT_SELF` "raporlayamazsınız", `notif.report.warn.body` "İçeriğiniz raporlandı", `notif.mod.reporter.*` "Raporunuz değerlendirildi", `REPORT_NOT_FOUND`, `TARGET_NOT_FOUND` "Raporlanan içerik". Web `pg.guidelines` "raporlayabilirsiniz".
- Kullanıcı "Şikâyet et" der, hata mesajı "raporladınız" der. AR "بلاغ" ve EN "report" tutarlı.
- Öneri: tr'de "Şikâyet / şikâyet etmek" (kullanıcıya görünen); yönetici panelinde "Rapor kuyruğu" teknik ad olarak kalabilir.

### A9-11 | YÜKSEK | tr/en | Android bildirim kanalı varsayılan adları ASCII-leştirilmiş Türkçe
- `mobile/android/.../LocalReminders.kt:136-143` `defaultNames/defaultDescs`: "Sosyal (begeni, takip)", "Ders ve sinav hatirlatmalari", "Birebir ve grup sohbet mesajlari.", "Etkinlik hatirlatmalari ve degisiklikler.", "Haber, duyuru, kulup ve sistem bildirimleri." vb.
- Dart ilk açılışta `setNames` ile yerelleştirir, ancak uygulama hiç açılmadan FCM geldiğinde (yeni kurulum, `Application.onCreate`) ve her zaman en/ar kullanıcı için ilk push anında kanallar bu ASCII Türkçe adlarla oluşur; sistem ayarında "Bildirim kategorileri" altında böyle görünür. ARB'de doğru karşılıklar: `bildirimmobilKanal*`, `p21Chan*Desc`.
- Önerilen: Kotlin varsayılanlarını doğru Türkçe diakritiklerle yaz (UTF-8 sorun değil) veya Android `res/values{,-en,-ar}/strings.xml` ile yerelleştir.

### A9-12 | YÜKSEK | en/ar | Backend "yönetici/moderatör/admin" Arapça'da tek kelimeye ("مشرف") düşüyor
- AR notif: "مشرف" hem sistem yöneticisi (`notif.community.adminClosed.body` "من قبل مشرف"; `chatadmin`) hem kulüp moderatörü (`notif.community.moderator.title` "أصبحت مشرفًا"); `event_ar` "المسؤول"; mobil AR "مديرو النادي" / "مسؤولو النادي" / "الإدارة" / "مشرف". Dört farklı karşılık.
- Anadil incelemesi önerilir. Öneri: Sistem yöneticisi = "المسؤول/المسؤولون" (ya da "الإدارة"), kulüp yöneticisi = "مدير النادي", moderatör = "مشرف".
- EN'de de: "admin", "administrator", "manager", "owner" birbirine karışıyor (mobil `chatDetailAdmin` "Admin", `clubMgmtRoleManager` "Manager"; backend "administrator").

### A9-13 | YÜKSEK | tr | `Admin onayı` ile `Yönetici` karışık
- `app_tr.arb`: `evcInfoReview` "Admin onayından sonra yayınlanır.", `evcSubmittedBody` "Etkinliğin admin onayından sonra yayınlanacak.", `p15PickerInfoBody` "...admin onayından sonra yayınlanır." Aynı kavram başka yerde "yönetici" (24 kullanım). "Admin" ham İngilizce.
- Öneri: "yönetici onayı".

---

## 4. ORTA

### A9-14 | ORTA | tr | Aynı eylem için iki terim: "Tek gösterimlik" / "Tek gönderimlik"
- `app_tr.arb:1195` `chatMiscOnceToast` "Tek gönderimlik: alıcı yalnızca bir kez görebilir", `:1197` `chatMiscOnceSendLabel` "Tek gönderimlik" ve `chatMiscOnceTitle`, `chatdOnceLocked`, `p26OnceCaption` hep "Tek gösterimlik" (en tutarlı "View once"). Öneri: "Tek gösterimlik".

### A9-15 | ORTA | tr | "İptal" / "Vazgeç" karışık (iletişim kutusu düğmesi)
- 15 yerde "Vazgeç" (`commonCancel`), 3 yerde "İptal": `chatDetailCancel` (:738), `postViewCancel` (:2430), `p19Cancel` (:4583). ("İptal" etkinlik iptali anlamında doğru, ancak bu üçü diyalog düğmesi.) Öneri: düğme = "Vazgeç", eylem = "İptal et".

### A9-16 | ORTA | tr/en/ar | Doğrulama hatası yanıtında ham alan adı
- Dinamik: `POST /api/auth/register` boş ad -> `VALIDATION_ERROR` "displayName: boş değer olamaz" (en "displayName: must not be blank", ar "displayName: لا يمكن أن تكون فارغة"); `POST /api/events` -> "title: boyut '3' ile '150' arasında olmalı"; "startsAt: must not be null"; ar "endsAt: لا يمكن أن يكون منعدم" (Hibernate Validator varsayılan Arapça: "منعدم" ile bozuk).
- `ApiExceptionHandler.validation` `alan: ileti` biçimini döndürüyor; mobil `errorText` (`core/session.dart:377`) `e.message`'ı olduğu gibi gösterir (yedek yol) -> kullanıcıda "displayName: ..." teknik görünüm.
- Öneri: `field` ayrı alan olarak dönsün (`FieldApiException` var), `message` yalnız yerelleştirilmiş cümle ("Ad boş olamaz"); alan adları için çevrilmiş etiket sözlüğü ya da `ValidationMessages_{tr,en,ar}.properties` ile özel mesajlar.

### A9-17 | ORTA | tr/en/ar | Kullanıcıya sızan teknik metinler
- Mobil: `sistemuiBlockedCode` "Hata kodu: ACCESS_BLOCKED" (:3357; bilerek destek kodu olabilir, ancak ham sabit), `p01ConfigCode` "Hata kodu • BUILD_ENV" (:3968), `p01ConfigBody`/`configError` "(API_BASE) ... (https)" (yapılandırma hatası ekranı: yalnız derleme sorununda görünür).
- Backend (kulüp yöneticisi/kullanıcı görür): `error.INVALID_ROLE` "Yalnızca MODERATOR veya MEMBER atanabilir." (`messages.properties:122`), `MANAGE_ROLES_ADMIN_ONLY` "(ADMIN) rolündeki", `INVALID_RANGE` "Biçim yyyy-MM-dd olmalı", `CALENDAR_RANGE_INVALID` "month ya da from/to verin", `EXPORT_ENTITY_INVALID` "(CALENDAR, EXAM, ANNOUNCEMENT)", `MAILOPS_*` DEAD/SKIPPED (yönetici paneli: kabul).
- Öneri: kullanıcıya dönenlerde rol adlarını yerelleştir ("Moderatör veya Üye"), biçim örneğini "GG.AA.YYYY" gibi anlaşılır yaz.

### A9-18 | ORTA | tr | ICS içe aktarma: takvim adı Türkçe sabit
- `backend/.../academic/IcsBuilder.java:42` `X-WR-CALNAME:Ders Programı` hangi dilde olursa olsun Türkçe; dışa aktarılan sınav özeti `academic_models.dart:646` `examTypeLabel` yedeği ("Vize", "Bütünleme") `l == null` iken. Öneri: dile göre ad ("Class timetable" / "جدول المحاضرات"), `Accept-Language`'den.

### A9-19 | ORTA | tr/en/ar | E-posta tarih biçimi tek ve saat dilimi etiketsiz
- `NewLoginNotifier.java:23` ve `AuthService.java:264` `dd.MM.yyyy HH:mm` her dilde (EN okuyucu için `10.11.2026` belirsiz), saat dilimi (Europe/Istanbul) yazılmıyor. Öneri: EN "10 Nov 2026, 14:05 (UTC+3)"; AR için yerel ay adı; hepsine saat dilimi.

### A9-20 | ORTA | tr/en/ar | E-posta içerik/teslimat gözlemleri (kod e-postası okul adresine ulaşmıyor sorunu)
Metin düzeyinde spam tetikleyici bulunmadı: konu "BÜ Kampüs - E-posta doğrulama kodu" (kod konuda yok, iyi), HTML+düz metin çok parçalı, harici bağlantı/izleme pikseli yok, tek gömülü logo (CID), `Auto-Submitted` var. Gözlemler:
- Alt bilgi "Lütfen bu iletiyi yanıtlamayın" (`mail.tpl.footer`) iken `Reply-To` ayarlı (`MailTransport.applyHeaders` -> `props.replyTo()`): çelişki; ya "yanıtlayabilirsiniz (destek)" ya `Reply-To` kaldır.
- Gönderen yerel kısmı `noreply@...` (`docs/changes/mail.md`): bazı kurumsal filtreler (özellikle Exchange Online) `noreply` + yeni alan adı kombinasyonuna daha sıkı bakar; `bildirim@`/`destek@` gibi gerçek bir adres düşünülebilir (A8 ile birlikte).
- Gövde çok kısa (2 cümle + kod + logo). Görsel/metin oranı için hesap bağlamını artıran 1 satır (ör. "Bu kodu yalnızca BÜ Kampüs uygulamasında kullanın; kimseyle paylaşmayın.") hem güvenlik hem filtre açısından iyi olur.
- Konu ayırıcıları tutarsız: şablon konuları " - " (tire), destek e-postaları "–" (en dash) (`mail.support.*`).
- EN yazımı: `mail.properties` "E-mail" (7 yer) / `messages_en.properties` "email" / mobil "email".
- Kopya anahtar kümeleri: `messages.properties` `mail.verification.*`/`mail.reset.*` ile `mail.properties` `mail.tpl.verification.*` aynı metin iki yerde (yalnız biri kullanılıyorsa diğeri ölü; kullanılırsa sürüklenme riski).
- 3 dil e-posta: tr/en/ar tamam; AR için `dir="rtl"` ve `lang` ayarlı; kod bloğu `dir="ltr"` doğru.

### A9-21 | ORTA | tr | Kalan sabit Türkçe/yerelleştirilmemiş kullanıcı metinleri (çoğu ölü kod)
- `features/auth/auth_widgets.dart:9-20` `validateEmail`, `validateNewPassword`: sabit Türkçe; çağıran yok (yerine `core/identifier.dart` ve `newPasswordValidator`). Ölü.
- `features/events/event_parts.dart:57` `eventErrorText` yedek metin "Bu etkinliğin kayıtları kapalı." (`e.message` boşsa Türkçe) - 4 çağrı noktası var, EN/AR'de yedek yolda Türkçe çıkar.
- `features/academic/academic_models.dart`: `dayNames`, `dayShort`, ay adları, `colorLabel`, `eventKindLabel`, `countdownText` ("gün kaldı"), `examTypeLabel` - çoğu çağrısız veya yalnız `l == null` yedeği.
- `features/profile/settings_page.dart:131-133` dil seçici açıklamaları sabit: 'Uygulama dili Türkçe', 'Interface and notifications in English', 'الواجهة والإشعارات باللغة العربية' (bilinçli: her dil kendi dilinde; sorun yok, bilgi olarak).
- `widgets/report_sheet.dart:14-18` `reasons` sabit Türkçe etiketler ama kullanım `reasonLabel` ile yerelleşiyor (ölü alan).
- `chat_media_viewer.dart:68,109` `Exception('Video indirilemedi.')` kullanıcıya gitmiyor (`chatVideoSaveErrorText` eşler), sorun yok.
- Öneri: ölü yardımcıları sil, `eventErrorText` yedeğini `l.eventListRegClosedError` ile değiştir.

### A9-22 | ORTA | tr/en/ar | Hukuk bağlamlı mobil metin: kullanılmayan uzun hata raporu açıklaması
- `settingsCrashReportsDesc` (tam KVKK/şeffaflık metni: tr 318 karakter) ARB'de var ama kodda kullanılmıyor; ekranda yalnız kısa `p19CrashReportsShort` görünüyor. Kullanıcıya "hangi veriler gönderilir/gönderilmez" cümlesi kayboldu. Hukuki/şeffaflık için (A8 ile) ilgili ekranda uzun metin ya da "Ayrıntı" bağlantısı olmalı.

### A9-23 | ORTA | tr | Silme/anonimleştirme anlatımı tutarsız (ölü ama yanıltıcı anahtar)
- `profilePrefsDeleteAccountBody` (tr) "Hesabınız ve kişisel verileriniz silinecek..." (ölü anahtar); canlı akış (`profil2DelWarnBody`, `mail.tpl.deleted.body`) "anonimleştirilir". Ölü anahtarı sil (yanlışlıkla bağlanma riski).

### A9-24 | ORTA | tr/en | Doğru olmayan EN çeviri/TR-EN anlam sapması
- `homeGreetDay` tr "İyi günler" / en "Good afternoon" (günün hangi saatinde? bkz. `homeGreetMorning`/`Evening`: gece/sabah/gün/akşam; 'Good day' ya da "İyi öğlenler" ile eşleştir).
- `chatDetailLeaveBody`/`chatInfoLeaveBody` tr "Bu sohbetten ayrılırsınız." (bilgi cümlesi değil) / en "You will no longer receive messages from this chat." Öneri tr: "Bu sohbetten ayrılırsanız yeni mesaj almazsınız."
- `loginReplacedNotice` en "Your account was logged in on another device" -> "Your account was signed in on another device, so this session was closed for your security." (tr/ar doğru).
- `chatMiscStatusDelivered` "İletildi" (Delivered) ile `chatDetailForwarded` "İletildi" (Forwarded) aynı sözcük; Delivered = "Teslim edildi".
- `errUploadQuota` en "You have uploaded too much." -> "You have made too many uploads."
- `notif.news.many.HABER` en "{0} new news items" -> "{0} new news articles".

### A9-25 | ORTA | en | "log in / sign in / register / sign up", "Log out / Sign out" karışık
- "Log in" 7, "sign in" 2 (`authResetDoneBody`, `legalReacceptDeclineBody`); "Log out" 5, "Sign out" 2 (`legalReacceptSignOut`); "Register" ("Registered" `p16ReqRegistered`), "Sign up". Öneri: Log in / Log out / Sign up; web "Sign in".

### A9-26 | ORTA | tr | Yayımla / yayınla, resmi / resmî
- `supportNoSuggestions` "yayımlanmış", `legalReacceptIntroSoft` "yayımlandı" vs `acadExamsEmptyOfficial` "yayınlanmış", `menuNoMenuMonth` "yayınlanmadı", `p17OfficialEmptyTitle` "yayınlanmadı". TDK "yayımlamak"; tek biçim.
- Mobil "resmi" / web "resmî"; mobil "şikâyet/hikâye" düzeltme işaretli ama "resmi" değil. Tek biçim.

### A9-27 | ORTA | tr/en/ar | Konuşma / Sohbet
- Backend `CONVERSATION_NOT_FOUND` "Konuşma bulunamadı.", `CANNOT_MESSAGE_SELF` "Kendinizle konuşma başlatamazsınız.", `DECRYPT_RANGE_INVALID` "Konuşma veya mesaj aralığı" (en "Conversation"); mobil her yerde "Sohbet/chat". Öneri: "Sohbet" (en "Chat"; AR "المحادثة" tutarlı).

### A9-28 | ORTA | tr | Düzenleyen / Organizatör ve Paylaşım / Gönderi / Yazı
- Mobil `eventFormOrganizedBy` "Düzenleyen:" vs `etkinlik2Organizer` "Organizatör" (9) ; backend `EVENT_OWNER_PROTECTED`/`EVENT_LAST_ORGANIZER` "düzenleyen" vs `notif.event.announcement.body` "organizatörü". Öneri: "Organizatör".
- Backend `clubadmin`: `notif.community.postAdminEdited.title` "Paylaşımınız düzenlendi" (kulüp gönderisi) vs `post`: "Gönderiniz düzenlendi"; `PIN_LIMIT` "yazı sabitlenebilir" (mobil/diğer "gönderi"). Öneri: "gönderi".

### A9-29 | ORTA | tr/en/ar | Hata kodu başlıklarında Content-Language/Vary yok; /api/* bilinmeyen yol İngilizce Spring JSON
- Dinamik: tüm hata yanıtlarında `Content-Language` başlığı yok, `Vary` içinde `accept-language` yok (önbellek/proxy aynı hatayı farklı dile verebilir; yalnız hata yanıtları için düşük risk).
- `GET /api/nonexistent-path` -> `{"timestamp":..,"status":404,"error":"Not Found","path":..}` (ApiException biçimi değil); `GET /api/news/999999` -> 404 boş gövde (kod/mesaj yok; mobil `errorText` yedek metne düşer). Öneri: 404 için `NEWS_NOT_FOUND` + 3 dil.
- Olumlu: `Accept-Language` çözümlemesi doğru: `ar-SA`->ar, `en-GB`->en, `en-US,en;q=0.9,tr;q=0.8`->en, `ar;q=0.5,en;q=0.9`->en, `de-DE,de;q=0.9,en;q=0.8`->en, bilinmeyen (`fr`,`zh`)->tr, boş/`*`->tr.

### A9-30 | ORTA | tr/en/ar | Web ErrorBoundary Arapça yok
- `web/src/components/ErrorBoundary.tsx:20-25` iki dilli "Bir sorun oluştu / Something went wrong" (tr/en); Arapça kullanıcı Arapça görmez. Öneri: ar satırı ("حدث خطأ ما") ekle.

### A9-31 | ORTA | en | Web ve mobil EN yazım standardı farklı (US/UK) ve terim
- Mobil "organizer", "anonymized", "canceled/cancelled" karışık; web "organiser", "anonymised". Menü: web "dining menu" / mobil "Meal menu". Web `site.feat.chat.text` "Chat one-to-one" (gruplar/kulüp sohbetleri var). Öneri: tek yazım (US) ve "meal menu".

### A9-32 | ORTA | tr/en | Başlık büyük harf düzeni (Title Case) 90+ metinde
- EN ve TR'de p03/p04/p13 grubunda başlık stili: "Menu of the Day", "Concluded Polls", "Average Satisfaction", "Option Distribution", "People You May Know", "Sonuçlanan Anketler", "Ortalama Memnuniyet", "Seçenek Dağılımı", "Oyu İncele", "Tümünü Gör". Diğer ekranlar cümle düzeni ("Sentence case"). Türkçe'de Title Case yazım kuralına aykırı. Öneri: cümle düzeni.

---

## 5. DÜŞÜK

### A9-33 | DÜŞÜK | tr/en/ar | 397 ölü ARB anahtarı (%14,5)
Kullanılmayan ve kaldırılan özelliklere ait: `story*` (25), `postView*`/`postCompose*` yorum/hikâye/etiket (100+), `profilePrefsNotifMention/Comment/Reply/Stories`, `profileStat*`... Çevirmen yükü ve yanlışlıkla yeniden bağlanma riski. Bkz. A9-22/23. (Listeyi isteğe bağlı çıkarabilirim.)

### A9-34 | DÜŞÜK | ar | Tenvin yazımı karışık
- `اً` (alif öncesi) ve `ًا` (alif sonrası) karışık: ARB 7/157, backend 12/89, web 0/312. Örnek: `p21HelpFooter` "أيضاً", `chatadmin_ar` "مجدداً" vs "جدًا". Tek biçim (`ًا`). Anadil incelemesi önerilir.

### A9-35 | DÜŞÜK | tr/en/ar | "..." ve "…" karışık
- tr 11 "..." / 19 "…" (`p04PostSharing`, `p09MediaLoading`, `kulupdetayApproving`, ...). Tek biçim "…".

### A9-36 | DÜŞÜK | tr | Küçük TR yazım/ifade
- `authTermsLink` "Kullanım koşulları" büyük K, `authPrivacyLink` küçük "gizlilik politikasını" (ek içinde); tutarsız büyük/küçük harf.
- `reportReasonImpersonation` "Başkasını taklit" (eksik: "Başkasını taklit etme").
- `followingEmpty` "Henüz kimse takip edilmiyor." (edilgen), `p18FollowersEmptyBody` "aktifleştikçe" düzensiz.
- `bildirimShortMin` "{n} m" (en; "m" dakika mı ay mı) ve `commonMinutesAgo` "{n} min ago" farklı; `bildirimShortDay` "g".
- `p15PickerSubtitle` "Etkinliğin yayınlanacağı yetkili kulübün" (cümle parçası).
- `chatInfoLeaveChat` "Sohbetten çık" vs `chatDetailLeaveChat` "Sohbetten ayrıl".
- `chatInfoMuteOn` "Açık" (sessize alma açık mı, bildirim açık mı belirsiz).

### A9-37 | DÜŞÜK | tr/en | Kontenjan / kota / kapasite karışık
- `kontenjan` (çoğu), `Katılımcı kotası` (`p16ReqUnlimitedTitle`), `Kapasite` (`CAPACITY_TOO_LOW` backend). EN "Capacity"/"Quota"/"Capacity (people)". Tek terim: Kontenjan / Capacity.

### A9-38 | DÜŞÜK | tr | Hitap çıkışı (backend)
- `notif.post.like.body` "{0} gönderini beğendi", `notif.user.follow.body` "{0} seni takip etti" (sen) - diğer bildirimler (siz): bkz. A9-06.

### A9-39 | DÜŞÜK | ar | Sayı birimi çoğulu `منذ {n} يوم` / `د` / `س` kısaltmaları
- `commonMinutesAgo` "منذ {n} د", `commonHoursAgo` "منذ {n} س", `commonDaysAgo` "منذ {n} يوم" (3-10 için "أيام"). Kısaltmalar Arapça'da yaygın değil; düz "قبل 5 دقائق" biçimi anadil incelemesi gerektirir.

### A9-40 | DÜŞÜK | tr/en/ar | `{reason}`/sunucu metni birleştirme
- `eventFormCoverFail` + " {sunucu mesajı}": sunucu mesajı farklı dilde gelirse (istek dili aynı olduğundan sorun yok) boşluk ve noktalama bitişik; Arapçada işaretler RTL/LTR karışabilir. Bilgi.

### A9-41 | DÜŞÜK | tr | CLAUDE.md güncel değil
- Bölüm 8: "Uygulama içi EN/AR çeviri henüz yok" - mobilde tr/en/ar 2736 anahtar tam. Belge güncellenmeli.

### A9-42 | DÜŞÜK | tr/en/ar | Sözleşme metinleri
- Bilinen: V99/V480/V620 yalnız Türkçe; EN/AR sözleşme sunulmuyor (web `legal.ts` yalnız sayfa başlığı/özet çevirisi). `legalReacceptIntro*` EN/AR metni kullanıcıya İngilizce/Arapça söylüyor ama onaylanan belge Türkçe: dil uyarısı eklenebilir ("Belgelerin bağlayıcı sürümü Türkçedir").

### A9-43 | DÜŞÜK | en | EN yapı: iki nokta üst üste ile sayım
- "Members: {count}", "Going: {count}", "Capacity: {going} / {cap}", "Messages waiting to send: {n}" (Türkçe düz "{count} üye"). EN doğal biçim "{count} members" (plural ile birlikte A9-08).

### A9-44 | DÜŞÜK | tr/en | Karışık büyük harf düğmeleri
- `notifGroupToday` "BUGÜN" vs `bildirimYesterday` "Dün" (iki farklı anahtar kümesi aynı kavram, farklı büyük/küçük). Yapı kaynaklı; sadeleştirilebilir.

### A9-45 | DÜŞÜK | tr/en/ar | Sürüm metinleri
- Mobil `settingsVersion` "BÜ Kampüs · Sürüm {version}", `profileVersionDate` "Version {version} · {date}"; web `pg.changelog` sürüm notları ay bazlı ("Ekim 2026") ve uygulama sürümü (2.0.3+20003) ile eşlenmiyor; sürüm numarası görünmüyor. Bilgi.

---

## 6. Olumlu bulgular (sorun yok)

- ARB: tr/en/ar 2736 anahtar eşit; tüm yer tutucular uyumlu (tek istisna ICU plural alanları beklenen), ICU söz dizimi geçerli, kesme işareti sorunu yok (`l10n.yaml` `use-escaping` kapalı, ASCII `'` literal), BOM yok; üretilmiş `app_localizations_*.dart` ARB ile eşzamanlı.
- tr'de ASCII-leştirilmiş Türkçe yok; ı/İ, ş/ç/ğ/ö/ü kullanımı doğru; büyük harfli metinlerde `İ` doğru; sayı/sınır değerleri (72 bayt, 3/gün, 2 MB, 60 sn, 50 kişi, 10 dk) tr/en/ar ve backend ile tutarlı.
- Arapça: Latin virgül/soru işareti yok (`،` 75, `؟` 37), "Latin karışımı" yalnız marka/teknik (JPEG, PNG, QR, KVKK, kcal, API_BASE, BUILD_ENV); çeviri kalıntısı ("TODO", "Test", boş) yok; kalite genel olarak yüksek (çoğul biçimler `p14EventCount` ve `p02FacultyCount` doğru kuruldu).
- tr ile birebir aynı kalan EN metinler yalnız sayı/kısaltma/özel ad (22: "Quiz", "Final", "Video", "QR", `{n} / {max}`); AR'de 9 (hepsi biçim şablonu).
- Backend: 392 `error.*` anahtarının 3 dilde de karşılığı var; koddaki 346 `ApiException` kodunun hepsi çeviride; `{0}` argüman sayıları 3 dilde eşit; mesaj biçimi argümanlarında kesme işareti sorunu yok; çeviri argümanları `String.valueOf` ile geçilmiş (Arapça rakam/binlik ayırıcı riski yok); 25 senaryoda yanıt dili `Accept-Language`'e uyuyor.
- Push modülü: `push*.properties` yalnız başlık (boş); tüm `notif.*` anahtarları üç dilde. Push önizleme (`p21Preview*`) ve kanal yardım ekranı (`p21*`) metinleri tr/en/ar doğru.
- Web: site kapsamı 813 anahtar tr/en/ar eşit, yer tutucu uyumsuzluğu yok, `t()` ile kullanılan 3241 anahtarın hepsi sözlükte (ham anahtar görünümü yok), yönetim paneli sözlüğünde ASCII-leştirilmiş Türkçe yok, mantıksal CSS (RTL) site tarafında tek istisna dışında kullanılıyor.
- E-posta: üç dilde şablon, RTL alanı, düz metin + HTML, abonelikten çıkma yalnız duyuru kategorisinde.

## 7. Terim sözlüğü ve önerilen tek terim

| Kavram | Mobil (tr / en / ar) | Backend | Web / e-posta | Sorun | Öneri (tr / en / ar) |
|---|---|---|---|---|---|
| Kulüp | Kulüp / Club / نادي | Kulüp / club / النادي (bir yerde المجتمع) | Topluluk / Community / مجتمع (site, admin nav) | A9-09 | Kulüp / Club / نادي (Topluluk Kuralları belge adı hariç) |
| Sohbet | Sohbet / Chat / محادثة | Konuşma + sohbet / Conversation / المحادثة | Sohbet, mesajlaşma, konuşma | A9-27 | Sohbet / Chat / محادثة; "Mesaj" yalnız tek ileti |
| Şikâyet | Şikâyet / Report / بلاغ | Rapor / report / بلاغ | Rapor, şikâyet | A9-10 | Şikâyet (tr), Report, بلاغ |
| Gönderi | Gönderi / Post / منشور | Gönderi, paylaşım, yazı | Gönderi, paylaşım | A9-28 | Gönderi / Post / منشور |
| Yönetici | Yönetici + Admin / Admin, Manager / مدير, مشرف, الإدارة | Yönetici / administrator / مشرف, مسؤول | Yönetici / Administrator / مسؤول | A9-12, A9-13 | Yönetici (sistem) / Administrator / المسؤول; kulüp: Kulüp yöneticisi / Club manager / مدير النادي; moderatör / Moderator / مشرف |
| Organizatör | Organizatör + Düzenleyen / organizer / منظم | organizatör + düzenleyen | düzenleyen | A9-28 | Organizatör / Organizer / منظم |
| Yoklama | Yoklama / Check-in (Attendance) / حضور | Yoklama / check-in | Yoklama / attendance | küçük: EN karışık | Yoklama / Attendance (check-in) / تسجيل الحضور |
| Giriş | Giriş yap / Log in + Sign in / تسجيل الدخول | Giriş / sign in | Giriş yap / Sign in | A9-25 | Giriş yap / Log in / تسجيل الدخول |
| İptal düğmesi | Vazgeç + İptal / Cancel | - | Vazgeç | A9-15 | Vazgeç (diyalog), İptal et (eylem) |
| Tek gösterimlik | Tek gösterimlik + Tek gönderimlik / View once | Tek gösterimlik | - | A9-14 | Tek gösterimlik |
| Resmi | Resmi / Official | resmi (tatil, takvim) | resmî (kaynak) | A9-04, A9-26 | rozet: Üniversite; "resmi tatil" kalır |
| E-posta | E-posta / email / البريد الإلكتروني | e-posta / email | E-posta / E-mail (mail şablonu) | A9-20 | E-posta / email |
| Marka | BÜ Kampüs (2 yerde BU) | BÜ Kampüs (ICS, alert: BU Kampus) | BÜ Kampüs | A9-03 | BÜ Kampüs |
| Hitap | sen + siz karışık | siz (çoğu) | siz | A9-06 | tek ton (siz önerilir) |

## 8. Bakılamayanlar / sınırlar

- Arapça için yalnızca yapısal/belirgin hata taraması ve yaklaşık 450 metinlik okuma yapıldı; anadil incelemesi gerekir (özellikle A9-08, A9-12, A9-34, A9-39 önerileri).
- Cihaz/ekran taşma testi yapılmadı (yalnız uzun metin listesi: >230 karakterli 2 metin `settingsCrashReportsDesc`, `p21HelpBatteryOem`; en uzun TR 318 karakter).
- Gerçek e-posta teslimi test edilmedi (`MAIL_ENABLED=false` yığın; yalnız şablon/başlık kodu okundu); okul adresine kod gitmeme sorunu için A8 altyapı (SPF/DKIM/DMARC) belgesine bakın.
- Push metinleri FCM gönderimi olmadan (FCM kapalı yığın) yalnız şablon düzeyinde incelendi; Android/iOS gerçek bildirim görünümü doğrulanmadı.
- Web admin paneli (yalnız tr) yazım kalitesi yalnız ASCII-leştirme/ham anahtar taramasıyla (okuma örneklemesi yok).
- Sözleşme metinleri (V99/V480/V620) içerik olarak incelenmedi.
- Yönetim paneli dışındaki `docs/*.md` ve mağaza metinleri kapsam dışı.
- Betikler `scratchpad` altında; repoya kod/metin değişikliği yapılmadı.
