# L10N-ENUM envanteri: katalog / enum / sabit değerlerin dile göre gösterimi

Tarih: 2026-10-31. Şikâyet: "departman gibi alanların İngilizcesi/Arapçası yok, dile göre getirilmiyor". Kapsam: kullanıcıya gösterilen
katalog değerleri, enum'lar ve sabit etiketler. Doğrulama düzeyi "koddan okundu" demektir (uçtan uca cihazda denenmedi).

## Temel kural (bozulmaz)

Fakülte / bölüm / sınıf **Türkçe kanonik değerle** saklanır ve eşleştirilir (kullanıcı kaydı, `AudienceKey`/`AudienceMatch`, duyuru ve anket
kapsamı, kulüp/etkinlik süzgeçleri, DB metni). Bu değerler ve API sözleşmesi DEĞİŞMEDİ; yalnız **gösterim** dile göre çevrilir.
Katalogdaki kanonik adlar `backend/src/test/resources/catalog/academic-canonical.txt` ile birebir kilitlidir (`CatalogServiceTest.canonicalTurkishNamesAreUnchanged`).

## Özet

| Durum | Sayı | Not |
|---|---|---|
| Çevirisi eksikti, DÜZELDİ | 5 alan grubu | fakülte (26), bölüm (744 satır / 613 benzersiz ad), sınıf (9), bölüm/fakülte gösteren ~30 mobil satır, kampanya e-postasındaki `{{bolum}}`/`{{fakulte}}` |
| Zaten çevriliyordu (koddan okundu) | ~25 alan | tablo B |
| Kaldı | 4 madde | tablo C |

## A. Akademik katalog (asıl şikâyet)

| Alan | Nerede tutuluyor | API'de | Önceden | Şimdi |
|---|---|---|---|---|
| Fakülte (26) | `backend/src/main/resources/catalog/academic.json` (`name` kanonik TR); kullanıcıda `app_user.faculty` metni | `GET /api/catalog/academic` -> `name` + yeni `nameEn`, `nameAr`; profil/kullanıcı yanıtlarında kanonik TR metin | yalnız TR | EN + AR (istemci kanonik değerden katalog aramasıyla çevirir) |
| Bölüm (744 satır, 613 benzersiz ad) | aynı JSON; `app_user.department` | aynı + `/api/catalog/departments` isabetleri `departmentEn/Ar`, `facultyEn/Ar` | yalnız TR | EN + AR |
| Sınıf (PREP,1..6,MASTER,PHD) | JSON `grades` + mobil ARB (`acadGrade*`) | `id` anahtar (kanonik), `name`, `nameEn`, `nameAr` | mobilde ARB ile 3 dil; sunucu adı yalnız TR | JSON'a da EN/AR eklendi (web/başka istemci için); mobil ARB'yi kullanmaya devam eder |
| Kampanya e-postası `{{bolum}}`, `{{fakulte}}` | `MailCampaignSupport.recipientVars` | e-posta gövdesi | alıcı dilinden bağımsız TR | alıcının kayıtlı dilinde |
| Duyuru / sınav / akademik takvim kapsamı (`department`, `faculty`) | `department_announcement`, sınav, takvim satırları (kanonik TR, eşleştirme anahtarı) | kanonik TR metin | ekranda TR | mobil gösterimde çevrilir; veri/eşleşme değişmedi |

Katalog `version` 1 -> 2. İstemci önbelleği ETag ile 24 saatte bir doğrular; eski v1 yanıtında çeviri alanı yoksa istemci Türkçeye düşer (hata vermez).

Mobil gösterim yerleri (hepsi `context.departmentName / facultyName / departmentOrFacultyName` ya da `catalog.departmentLabel`): profil sekmesi, kullanıcı profili,
profil düzenleme + kayıt + `AcademicFields` seçicileri, bölüm seçici (arama TR + seçili dil), sohbet bilgisi/üyeler/yeni sohbet/üye ekleme, kişi eşleşme,
kulüp üye kartı, Keşfet gönderi + öneri kartı, takip listesi/kartı, engellenenler, etkinlik yoklama/başvuru listeleri, genel arama kullanıcı sonucu,
duyuru kapsam çipleri, sınav ve akademik takvim kapsam satırları, gönderi kartı.

## B. Zaten çevrilen enum / sabitler (koddan okundu)

| Alan | Kaynak | API | Mobil gösterim | Çevrili mi |
|---|---|---|---|---|
| Kulüp kategorisi | tablo `community_category` (`name_tr/en/ar`, V550) | `GET /communities/categories` `name` istek dilinde | sunucu adı | evet (sunucu) |
| Kulüp rolü OWNER/ADMIN/MODERATOR/MEMBER | `CommunityMember.Role` | anahtar | `clubRole*` ARB | evet |
| Kulüp üyelik durumu, katılım politikası | `Community.JoinPolicy/Status/Visibility` | anahtar | ARB | evet |
| Etkinlik durumu / RSVP (GOING, INTERESTED..) | `UserEvent.Status`, `EventRsvp.Status` | anahtar | ARB (events_page, my_events) | evet |
| Etkinlik başvuru durumu / kabul modu | `EventApplication.Status`, `EventAdmission.Mode` | anahtar | ARB; `WAITLISTED`/`CANCELLED` için ayrı etiket yok (bkz. C) | kısmen |
| Yoklama yöntemi QR/MANUAL | `EventAttendance.Method` | anahtar | ARB | evet |
| Anket türü (SINGLE/MULTI/RATING/RANKED), durum, kapsam | `Poll.*` | anahtar | `pollTypeLabel(l, ...)`, `pollBlocked*` ARB | evet |
| Destek talebi kategori/durum | `SupportTicket.Category/Status` | anahtar | `support_common.dart` ARB | evet |
| Geri bildirim kategori/durum | `Feedback.Category/Status` | anahtar | ARB | evet |
| Rapor sebepleri | `ReportReason` | anahtar | `ReportSheet.reasonLabel(l, code)` ARB | evet (sabit TR liste yalnız yedek) |
| Bildirim türü | `NotificationType` | anahtar | `notifications_page._typeLabel` ARB | evet |
| Bildirim/e-posta gövdeleri | `i18n/push*.properties`, `mail*.properties` | metin alıcı dilinde | olduğu gibi | evet |
| Haber türü (HABER/DUYURU/ETKINLIK) | `news.ContentType` | anahtar | `newsTypeLabel(context, ..)` ARB | evet |
| Sınav türü, takvim etkinlik türü | akademik paket (metin kodu) | anahtar | `examTypeLabelL`, `eventKindLabelL` ARB | evet |
| Takvim renk adı, ay/gün adları | istemci | - | `colorLabelL`, `monthNameL`, `dayNameL` ARB | evet |
| Gizlilik hedef kitlesi (EVERYONE/SHARED_CONTEXT..) | `profile.privacy.Audience` | anahtar | `privacy_data_page` ARB | evet |
| Sohbet kaldırma yer tutucuları | sunucu metni TR sabit | metin | `message_placeholder.dart` TR sabiti ARB'ye eşler | evet |
| Hata metinleri | `error.<KOD>` (tr/en/ar) | istek dilinde | olduğu gibi | evet |
| Uygulama dili adı | `_langNames` | - | endonim (Türkçe/English/العربية) kasıtlı | bilerek sabit |

## C. Kalan / bilinçli bırakılanlar

1. **Menü yemek adları ve haber/duyuru/etkinlik başlıkları**: kaynak sitelerden kazınan içerik; çevrilmez (ürün kararı, `CLAUDE.md` içerik kuralı).
2. **Ders adları, kulüp/etkinlik adları ve kulüp kategorisi anahtarları**: kullanıcı/yönetici girdisi; çeviri ürün kararı (kategori adları zaten 3 dilli yönetilir).
3. **Etkinlik başvurusunda `WAITLISTED`/`CANCELLED`** mobilde ayrı etikete bağlı değil (yönetici ekranı yok sayıyor); ürün kararı bekliyor.
4. **Eski (L'siz) yedek etiket işlevleri** (`examTypeLabel`, `eventKindLabel`, `countdownText`, `fmtWallDate`, `eventErrorText`): Türkçe sabit; `eventErrorText`
   yalnız `event_detail_page.dart`/`etkinlik2_settings_page.dart`'ta 409 `EVENT_REGISTRATION_CLOSED` + boş mesaj durumunda Türkçe yedek verir (sunucu mesajı normalde istek dilindedir).
   `event_detail_page.dart` başka bir ajanın aktif dosyasıdır; `eventErrorTextL`'ye geçiş sonraya bırakıldı.
5. Web herkese açık site akademik kataloğu kullanmıyor (admin paneli Türkçe kalır); `web/src/api/generated/schema.d.ts` ve `docs/openapi.json` bir sonraki `OpenApiExportTest`/üretimle yeni alanları alır.

## D. Çeviri kalitesi notları

Fakülte/bölüm adlarının İngilizcesi Türkçe akademik terimlerin standart karşılıklarıdır; **Bingöl Üniversitesi'nin resmî İngilizce sayfaları (bingol.edu.tr/en) kontrol edilmedi** (istek atılmadı).
Arapça adlar standart akademik terimlerle yazıldı ve **anadil incelemesi ister**. Doğrulanması gerekenler:

- Fakülte: "Fen-Edebiyat Fakültesi" = Faculty of Arts and Sciences / كلية العلوم والآداب; "İlahiyat Fakültesi" = Faculty of Theology / كلية الإلهيات (resmî EN "Divinity" olabilir);
  "Denizcilik Fakültesi" = Faculty of Maritime Studies; "Devlet Konservatuvarı" = State Conservatory / المعهد الموسيقي الحكومي; "Hemşirelik Yüksekokulu" = School of Nursing; "Meslek Yüksekokulu" = Vocational School.
- Bölüm (resmî adı farklı olabilir): Güverte Mühendisliği (Deck Engineering), Harita Mühendisliği (Geomatics Engineering), Gemi İnşaatı ve Gemi Makineleri Mühendisliği (Naval Architecture and Marine Engineering),
  Özel Yetenek Öğretmenliği (Special Talent Teaching), Perfüzyon (Perfusion Technology), Bağlama / Kanun / Kemençe / Ney / Ud (çalgı adları, Arapçada yerel yazım), Çini (Tile Art), Optisyenlik (Opticianry),
  Sınıf Öğretmenliği (Classroom Teaching), Eğitimde Eğitim Programları ve Öğretim (Curriculum and Instruction in Education), Zootekni (Animal Science), Kriminalistik (Criminalistics),
  Denizcilik İşletmeleri / Denizcilik İşletmeleri Yönetimi (Maritime Enterprises / Maritime Enterprise Management), Ortaöğretim ... Öğretmenliği (Secondary School ... Teaching).
- "Öğretmenliği" -> "... Teaching", "Teknikerliği" -> "... Technician", "İşletmeciliği" -> "... Management" kalıbı tüm programlarda tutarlı uygulandı; üniversite farklı kalıp (ör. "Education") kullanıyorsa topluca değiştirilir.
