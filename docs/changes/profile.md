# profile modulu: API degisiklikleri

Tum degisiklikler geriye uyumludur (yalnizca ekleme).

## GET /api/search (giris gerekli)
Yeni parametreler: `type`, `cursor`, `limit`.

- `type` yok: onceki gruplu ozet (`limit` 1-20, varsayilan 5). `nextCursor` her zaman `null`.
- `type` var: tek tur sayfali liste (`limit` 1-50, varsayilan 5). Devam icin yanittaki `nextCursor` degeri `cursor` olarak gonderilir.
  `cursor` atlanacak sonuc sayisidir (0-1000); disindaki deger 400 `VALIDATION_ERROR`.

```
GET /api/search?q=kampus&type=NEWS&limit=20
{ "q":"kampus", "groups":[{"type":"NEWS","items":[ ... ]}], "nextCursor": 20 }
GET /api/search?q=kampus&type=NEWS&limit=20&cursor=20   // son sayfada nextCursor = null
```
Hata kodlari: 400 `VALIDATION_ERROR` (kisa sorgu / gecersiz imlec), 429 `RATE_LIMITED` (60/dk).

## GET /api/users/search (giris gerekli)
`?q=&size=&cursor=` — yanit `{ "items":[PublicProfile...], "nextCursor": 20|null }`.

- `q` en az 2 karakter (400 `QUERY_TOO_SHORT`), `size` 1-20, `cursor` 0-200 (400 `VALIDATION_ERROR`).
- Siralama (ad, id) deterministik. Kendisi, engel iliskisi olanlar, askidaki/silinmis hesaplar donmez.
- Alanlar profil gizlilik ayarina gore dolar; e-posta yalnizca `showEmail=true` ise.
- Limitler: dakikada 60 istek ve gunluk 500 istek/kullanici (429 `RATE_LIMITED`).

## GET /api/me/summary (yeni, giris gerekli)
```
{ "communities": 3, "events": 1, "bookmarks": 12, "unreadNotifications": 4, "unreadMessages": 7 }
```
- `communities`: aktif uyelik sayisi; `events`: katilacagim (GOING) ve bitmemis etkinlikler;
  `bookmarks`: kayitli haberler; `unreadNotifications`, `unreadMessages`: okunmamis toplamlari.
- Rate limit: dakikada 120.

## GET /api/users/{id}
Kendi id'niz icin `email` alani `showEmail` ayarindan bagimsiz doner.

## Hesap silme (DELETE /api/users/me, yonetici silmesi)
Anonimlestirmeye ek olarak: cihazlar (FCM token), bildirim kutusu, bildirim tercihleri (genel + alt tur),
kayitli haberler, kulup basvuru yanitlari ve topluluk uyelikleri (sahip ve BANNED kayitlari haric) silinir;
sohbet odalarindan cikis yapilir (mesaj gecmisi baskalarina ait oldugundan korunur).

## POST /api/users/me/avatar
Degisiklik yok. Medya hatti (`MediaService`) zaten tur/boyut dogrulamasi, yeniden kodlama (EXIF temizligi),
sunucuda uretilen icerik-ozeti dosya adi ve saatte 10 yukleme limiti uygular.

## Migration
`V160__profile_search_perf.sql`: `prf160_news_title_trgm` (haber basligi ILIKE icin pg_trgm GIN),
`prf160_notification_unread` (okunmamis bildirim sayimi icin kismi indeks). Yeni extension gerekmez.
Kullanici adi aramasi mevcut `idx_perf_user_name_trgm` indeksini kullanir (sorgu `ILIKE`'a cevrildi).

## Akademik katalog ve sinif (V200)
`catalog` paketi: `GET /api/catalog/academic` (tum katalog, ETag + 1 gun onbellek) ve `GET /api/catalog/departments?q=&limit=` (bolum arama, en cok 30). Kaynak: `resources/catalog/academic.json`.
`app_user.grade` (V200, VARCHAR 8: PREP, 1..6, MASTER, PHD). `ProfileView` ve `PATCH /api/users/me` `grade` icerir; `faculty`/`department`/`grade` yazilirken katalogla dogrulanir (400 `ACADEMIC_INVALID`), bos metin temizler. Mevcut serbest metin degerlere dokunulmaz. `POST /api/auth/register` ayni alanlari opsiyonel alir (bekleyen kayit `reg:<email>` icinde tasinir, hesap olusurken yazilir).

### Katalog goruntu adlari: EN/AR (L10N-ENUM, katalog `version` 2)
`academic.json` her fakulte/bolum/sinif icin `nameEn` ve `nameAr` tasir; Turkce `name` KANONIK anahtar olarak aynen kalir (DB'de saklanan ve
eslestirilen deger: kullanici profili, duyuru/anket kapsami, kulup/etkinlik suzgecleri). Veri gocu yok, yalniz **gosterim** cevrilir.
`GET /api/catalog/academic` yaniti `nameEn`/`nameAr` ekler (alan ekleme geriye uyumlu; eski istemciler yok sayar), `version` 1 -> 2.
`GET /api/catalog/departments` isabetleri `facultyEn/facultyAr/departmentEn/departmentAr` ekler; arama TR + EN + AR adlarda aksan/buyuk-kucuk harf duyarsiz calisir.
Eksik/bos ceviri `CatalogService` kayit kurucusunda Turkce `name`'e duser (guvenli yedek). Profil/kullanici/kulup/etkinlik yanitlari degismedi:
istemci kanonik Turkce degeri katalog aramasiyla cevirir. Sunucu metinlerinde bolum/fakulte adi: kampanya e-postasi `{{bolum}}`/`{{fakulte}}`
alicinin kayitli dilinde yazilir (`MailCampaignSupport`, `CatalogService.facultyName/departmentName`).
Cevirilerin Arapca kismi anadil incelemesi ister; dogrulanacak adlar `docs/design/L10N_ENUM_ENVANTERI.md` bolum D.

## Rehber eslestirme (V240)
`POST /api/users/contacts/match` `{"hashes":[sha256 hex...]}` (en cok 500, asim 400 `CONTACTS_TOO_MANY`; yinelenen/bozuk hash yok sayilir).
Hash = rehberdeki e-postanin kirpilmis, kucuk harfe cevrilmis halinin SHA-256 hex'i. Yanit `{matches:[{hash,userId,displayName,avatarUrl,faculty,department}]}`.
Yalnizca aktif, dogrulanmis, bingol.edu.tr (alt alan dahil) hesaplar; kendisi ve iki yonlu engel iliskisi olanlar cikarilir; avatar/fakulte/bolum
alan bazli gizlilige (`PublicProfileMapper`) uyar. Rate limit: kullanici basina 6/saat, IP basina 30/saat. Hash ve sonuclar saklanmaz/loglanmaz.
`app_user.email_sha256` (VARCHAR 64) + indeks `usr240_email_sha256`: `User` entity'sinin `@PrePersist/@PreUpdate` kancasi doldurur,
silinmis (anonimlestirilmis) hesapta NULL. `ProfileView`/KVKK dis aktarimi bu sutunu icermez. Not: profilde "dizinde gorunme" ayari yoktur; uygulanmadi.

## KVKK hesap silme / veri indirme tamlığı (B1, 2026-10-28)

- **Hesap silme** (`ProfileService.anonymize` → `UserAccountDeletedEvent`, commit sonrası dinleyiciler, hata silmeyi etkilemez):
  - `CommunityAccountListener`: kullanıcı kulüp **sahibi**ysa sahiplik en eski aktif ADMIN (yoksa MODERATOR) üyeye devredilir (3 kulüp sınırını aşmayan, aktif hesap; `club_audit` `OWNER_AUTO_TRANSFERRED`, bildirim `notif.community.ownerAutoTransferred`); aday yoksa kulüp kapatılır (`CommunityService.delete`: üyelere haber, bağlı gelecek etkinlikler iptal). Kullanıcının gönderi görselleri alandan kaldırılıp diskten silinir (`CommunityPostMedia`); kulüp silinince de aynı.
  - `EventAccountListener`: kulübe bağlı olmayan, bitmemiş etkinlikleri iptal; açık başvurular (PENDING/WAITLISTED/ACCEPTED) kapanır; serbest kalan koltuklarda bekleme listesi terfi eder (`EventAdmissionHooks.onUserDeleted`).
  - Kulüp gönderisi silinince (`CommunityPostService.delete`, rapor "gizle") `image_url` boşaltılır ve dosya (başka kayıt kullanmıyorsa) silinir.
- **`GET /api/users/me/export`**: yeni bölümler `bookmarks`, `communityMemberships`, `communityPosts`, `eventRsvps`, `eventAttendance`, `createdEvents`, `mailCampaigns`, `feedbackVotes`, `conversationMemberships` (`export/ExtraExporters`). Bir bölüm hata verirse çıktı 500 olmaz; o bölümde `{"error":"SECTION_UNAVAILABLE"}` görünür.
- **`GET /api/app/info`**: `operatorName` (`legal.controller.name`) ve `kvkkEmail` (`legal.controller.email`) alanları eklendi (ayar boşsa `null`; adres/kimlik gelmez). Web hesap silme sayfası "Geliştirici" satırını buradan okur.
- **Sözleşme yeniden onayı**: bkz. `docs/LEGAL_NOTES.md` bölüm 8 (`GET /api/legal/acceptance-status`, `POST /api/legal/accept`, 403 `LEGAL_REACCEPT_REQUIRED`).

## B1: profil ve engeller

- `GET /api/users/me`: `avatarHidden` (`ProfilePrivacy.avatarHidden`, moderasyon bayrağı); diğer `ProfileView` dönen uçlarda alan yoktur.
- `GET /api/users/me/blocks`: `X-Total-Count` başlığı (`UserBlockRepository.countByBlockerId`, PK öneki).
- Takip listeleri ve `follow-suggestions`: `classYear` (`PublicProfileMapper` gizliliğiyle).
- `GET /api/users/{id}`: `PublicProfile.blockedByMe` (`NON_NULL`; başkasının profilinde `BlockService.hasBlocked` tek yönlü PK araması; karşı tarafın engeli sızdırılmaz; kendi profilimde yok).

## W2-F: rehber gizliliği, hesap silme kapsamı, saklama, genel destek formu (T-061..T-065)

**Rehber eşleştirme (T-061, V995, K-16 b).** `profile_privacy.contacts_discoverable` (varsayılan **false**, satırı olmayan da kapalı).
- `GET|PUT /api/users/contacts/discoverable` (`{"enabled":bool}`; PUT 20/sa) "Rehberden bulunabilirim" anahtarını okur/yazar.
- `POST /api/users/contacts/match` artık **karşılıklıdır**: kendisi bulunabilir değilse 403 `CONTACTS_DISCOVERABLE_REQUIRED` (3 dilde çeviri); yanıtta yalnız bulunabilir demiş kullanıcılar döner (ad/`userId`/profil yalnız karşılıklı eşleşmede). `numara@bingol.edu.tr` (yerel kısmı tamamen rakam) adresleri eşleşmeden çıkarılır.
- Hesap başına **günlük tekil aday tavanı** `app.contacts.daily-candidate-cap` (2000, Redis `cm:day:<uid>:<gün>`): aşılırsa 429 + `Retry-After`, aşan istek sayılmaz. Saatlik 6 istek/kullanıcı + 30/IP sınırı değişmedi.
- Mobil: izin ilk kullanımda istenmeli ve anahtar ayarlarda gösterilmeli (W2-I/W3-G). Aydınlatmaya `email_sha256` (tuzsuz SHA-256, kalıcı) eklenmeli (hukuk; `docs/legal/internal/01` bölüm 7).

**Hesap silme kapsamı (T-063).** `AccountDataPurger` yeni DELETES: `blocked_attempt_log`, `profanity_hit_log`, `message_attachment_view`, `message_reaction`, `club_member_grant`, `conversation_add_ban` (iki yön), `event_co_organizer`; `purge(userId, oldEmail)` ile `mail_outbox.to_address` eşleşmeli silme (`ProfileService` bu iki parametreli çağrıya geçirilmeli; geçene kadar aşağıdaki gece ağı çalışır). Her kullanıcı sütununun kararı `AccountDataPurger.DELETES|SCRUBS|HANDLED_ELSEWHERE|RETAINED`; `AccountDataPurgerCoverageTest` migration'ları tarar, kararı olmayan yeni sütunda kırılır. Matris: `docs/DATABASE.md` bölüm 16.
`DbMaintenanceJob` yeni işler: `mail_code_scrub` (+ saatlik `hourlyMailCodeScrub`: SENT/DEAD kod postalarında `vars_json='{}'`, 1 saat sonra), `mail_orphan_address` (hesabı olmayan adreslere giden >1 gün eski SENT satırları), `profanity_hit_log` (artık `app.dbmaint.log-days`=90 uygulanıyor), `deleted_owner_rows` (silinmiş hesabın kalan OWNER üyelik satırı). İndeksler `kvk9_attempt_user`, `kvk9_prf_hit_user`.
**PG'de doğrulanmadı:** `NOT EXISTS (... u.email = LOWER(m.to_address))` ve `UPDATE ... WHERE id IN (SELECT ... LIMIT)` sözdizimi H2 PostgreSQL modunda sınandı; gerçek PostgreSQL'de çalıştırılmadı.

**Saklama ve silme defteri (T-064, K-14 b).** Varsayılanlar: `app.chat.deleted-retention-days` 0→**90**, `app.chat.edit-window-minutes` 0→**1440**, `app.chat.media.view-once-retention-days` 365→**7** (silme penceresi sınırsız kaldı). Tek gösterimlik: alıcı yalnız ilk 24 saatte açabildiği için oluşturmadan 7 gün = açıldıktan en çok ~7 gün; "kullanılmamış 30 gün" ayrımı için `MessageAttachmentService` değişikliği gerekir (yapılmadı). Silme defteri: `app.privacy.deletion-ledger-file` (`DELETION_LEDGER_FILE`, boş = kapalı) doluysa `DeletionLedger` commit sonrası `<id>\t<an>\t<hesap-oluşturma-sn>` ekler (kişisel veri yok); `DeletionLedgerReapplier` açılışta ve her gece 03:50 geri yüklenmiş hesapları (hâlâ DELETED değil ve oluşturma saniyesi eşleşiyorsa) `ProfileService.anonymizeAccount` ile yeniden anonimleştirir. Dosya yedek DIŞI hacimde olmalı (`docs/BACKUP_RESTORE.md` bölüm 5 adım 7).

**Genel destek formu (T-062).** Yeni `GET /api/public/support/form-token` → `{formToken, minFillSeconds}` (IP başına 60/sa). Gönderimde `SubmitRequest.formToken` zorunlu (`app.support.form-token-required`, varsayılan true): sunucu HMAC imzalı, zaman damgalı jeton; `elapsedMs` artık dikkate alınmaz (jetonsuz/sahte/çok hızlı/2 saatten eski gönderim eskisi gibi sessizce 202 genel yanıtla düşürülür; jeton başına en çok 3 gönderim). Ortak `pubsup:global` 100/sa tavanı **kaldırıldı**; koruma `mail.requireCodeQuota(SUPPORT)` kod bütçesi + IP 5/sa, 15/gün, e-posta 5/gün. İzleme bağlantısı `app.support.track-token-days` (90) sonra ve talep kapandıktan `track-closed-grace-days` (14) sonra geçersiz (404); gece temizliği süresi dolan `support_track_token` satırlarını siler. **Web formu açılışta form-token alıp gönderimde `formToken` yollamalıdır** (yoksa gönderimler sessizce düşer).

**Yönetici sohbet çözme / Sentry (T-065).** `ProdSettingsValidator`: `SENTRY_DSN` AB (de.sentry.io) bölgesinde değilse uyarı eklendi (ADMIN_EMAILS ≥ 2 ve DSN uyarısı önceden vardı; `send-default-pii` kodda sabit false). K-13 (c) "rapor kimliği zorunlu" kısmı `admin/chat` ve `crypto` modüllerinde olup bu akışın dosyalarında değildir; yapılmadı (saatlik kota `app.crypto.admin-decrypt-per-hour=30` mevcut).
