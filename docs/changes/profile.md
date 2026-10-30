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
