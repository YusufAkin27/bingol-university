# ops modulu degisiklikleri (support, legal, moderation, appinfo, analytics, admin, export, media, common)

## 1. Liste sayfalama

Mevcut sayfali uclar (`/feedback/mine`, `/suggestions`, `/support/tickets`, `/admin/*` kuyruklari, `/admin/moderation/*`, audit, kullanici listesi, admin chat) zaten en cok 50 ile sinirli; degismedi.

Sinirsiz donen ve buyuyebilen iki uc **geriye uyumlu** sayfalandi: govde hala duz dizi; devam varsa `X-Next-Cursor` yanit basligi gelir.

| Uc | Sorgu | Not |
|---|---|---|
| `GET /api/users/me/blocks` | `?cursor=<n>&limit=<1..50>` | yeniden eskiye; varsayilan limit 50 |
| `GET /api/admin/faq` | `?cursor=<n>&limit=<1..50>` | lang, kategori, sira |

`cursor` opak sayfa numarasidir; bir sonraki istekte `X-Next-Cursor` degeri aynen verilir. Baslik yoksa liste bitmistir. limit 1..50 araligina cekilir (hata dondurmez).
Not: Tarayici (web paneli) basligi okuyacaksa `Access-Control-Expose-Headers: X-Next-Cursor, Retry-After` CORS ayarina eklenmeli (config paketi baska ajanda).

Bilincli olarak sayfalanmayanlar: `GET /api/faq` (yonetici kürate eder, dil basina kucuk, kategoriye gruplu yanit sozlesmesi), `/api/legal` ve `/legal/{type}/versions` (belge turu sayisi sabit, surum sayisi yilda birkac), `/legal/consents/mine` (belge turu x surum ile sinirli), `/appeals/mine` (zaten `Top50`), `/faculties` (appinfo ayari, <=1000 karakter), `/admin/moderation/reports/reason-templates` (sabit).

## 2. Indeksler (V180)
- `ix_ops_user_block_blocker_created`: engel listesi siralamasi.
- Destek kuyrugu icin ek indeks gerekmedi: mevcut `idx_ticket_admin (status, updated_at)` karsiliyor.
N+1: incelenen liste servislerinde (BlockController kullanicilari `findAllById` ile toplu cekiyor, destek/geri bildirim sayfalari tek sorgu) N+1 bulunmadi.

## 3. Hata govdeleri
- `ApiExceptionHandler` tum yanitlari `{code,message}` doner (dogrulandi).
- **429**: `RateLimiter` artik `RateLimitedException` firlatir; yanitta `Retry-After: <saniye>` basligi vardir (Redis anahtarinin kalan omru). Govde ve kod (`RATE_LIMITED`) ayni.
- **401 govdesi** (MOBILE_API_GUIDE 0.1): kimliksiz isteklerde bos govde `code` icermiyordu cunku SecurityConfig'te ozel `AuthenticationEntryPoint` yok. `common.ApiAuthenticationEntryPoint` bean'i hazir (`{"code":"UNAUTHORIZED","message":...}`, istek dilinde; `error.UNAUTHORIZED` anahtari mevcut). **config sahibi ajandan gereken tek satir** (SecurityConfig.filterChain):

```java
.exceptionHandling(e -> e.authenticationEntryPoint(apiAuthenticationEntryPoint))
```
(`ApiAuthenticationEntryPoint` constructor/parametre ile enjekte edilir; `httpBasic` satirinin yani.) Baglanana kadar 401 govdesi bos kalir; istemci `status == 401` ile calismali.

## 4. Uygulama bilgisi (mobil zorunlu guncelleme / bakim)
- `GET /api/app/info` -> `maintenance{enabled,message}`, `banner`, iletisim; acilista cagrilir.
- `GET /api/app/version?platform=android|ios&version=1.2.3` -> `{updateRequired, updateAvailable, latestVersion, storeUrl}`. Yonetici ayarlari (`PUT /api/admin/settings/{key}`): `min_version_android|ios`, `latest_version_android|ios`, `store_url_android|ios` (https zorunlu). iOS alanlari V5'ten beri mevcut; `AppInfoVersionCheckTest` ile dogrulandi. `updateRequired=true` ise engelleyici ekran + `storeUrl`.

## 5. Analitik olay alimi
`POST /api/analytics/events` (JWT, kullanici basina dakikada 30 istek, 204 doner):

```json
{"events":[
  {"name":"app_open","screen":"home","at":"2026-10-26T09:00:00Z"},
  {"name":"search_submit","screen":"search","props":{"results":12,"tab":"news"}}
]}
```
Sinirlar: istek basina <=50 olay; `name` ve `props` anahtari `[a-z0-9_]{1,40}`; `screen` `[A-Za-z0-9_./-]{1,60}`; en cok 5 `props`, deger skaler (string/sayi/bool) ve <=100 karakter; `at` son 7 gun/+5 dk disindaysa sunucu saati kullanilir. **PII reddi**: deger `@` icerirse veya 10+ ardisik rakam (telefon/TC kimlik no) icerirse tum istek `400 INVALID_EVENT` ile reddedilir (hicbiri kaydedilmez). Testler: `AnalyticsServiceTest`.


## V280 — Erisim engelleri (IP / CIDR / cihaz / kullanici)

Yonetici kullaniciyi, kayitsiz kisiyi (IP/CIDR) ya da mobil cihazi engeller; engelli taraf `/api/**` ve `/ws` ucuna giremez (anonim dahil), mevcut oturumlari kapanir. Tam uc sozlesmesi: [ADMIN_API.md](../ADMIN_API.md) "V280".

- **Sema (V280):** `access_ban`, `user_device_log`, `blocked_attempt_log`, `ban280_anonymizer_range` (indeks onekleri `ban280_`).
- **Filtre sirasi:** `AccessBanFilter` (en erken; Spring Security'den once, `HIGHEST_PRECEDENCE + 20`) -> kapsam `/api/**` (admin haric) ve `/ws`, OPTIONS haric -> `ClientIp` ile IP, `X-Device-Id` HMAC ozeti -> muafiyet (loopback/ozel ag/`BAN_ALLOWLIST`: IP ve anonimlestirici kontrolu atlanir) -> siralama: IP/CIDR, cihaz, kullanici (filtrede kullanici yok), anonimlestirici (`BLOCK_ANONYMIZERS`). Eslesme: `403 {"code":"ACCESS_BLOCKED","message":...}` (istek dilinde; sebep yok). Kullanici engeli: `/api/auth/login|refresh|verify-email` (sifre dogruysa) ve kimlikli isteklerde `DeviceSeenInterceptor`; STOMP CONNECT'te `Rejected("ACCESS_BLOCKED")`.
- **Istemci basliklari:** `X-Device-Id` (8-128 kr, `[A-Za-z0-9._:-]`; aksi yok sayilir), `X-Device-Platform` (`ANDROID|IOS|WEB`), `X-App-Version`. STOMP CONNECT: `device-id`, `device-platform`, `app-version`. Baslik yoksa cihaz engeli uygulanamaz.
- **Oturumlar:** yeni engelde eslesen kullanicilar icin `AccessBlockedEvent` (WS'ye `{type:"access-blocked"}` olayi + `ACCESS_BLOCKED` kapanis kodu; FCM kayitlari silinir) ve ardindan `SessionService.revokeAll`. Yonetici rolleri kapatilmaz.
- **Performans:** `AccessBanCache` bellek ici goruntu (TTL 20 sn + yerel degisiklikte aninda), IP icin siralanmis aralik yapisi O(log n); vurus sayaci/deneme gunlugu bellekte birikir, 5 sn'de toplu yazilir.
- **KVKK:** cihaz kimligi yalniz HMAC ozeti; `user_device_log` + `blocked_attempt_log` 90 gun (`AccessBanRetentionJob`, 04:30, `SchedulerLock`); hesap silinince `AccountDataPurger` cihaz/IP kayitlarini siler; `DataExporter` bolumu `accessHistory`.
- **Ayarlar:** `DEVICE_HMAC_KEY`, `BAN_ALLOWLIST`, `BLOCK_ANONYMIZERS`, `BAN_CACHE_TTL_SECONDS`, `BAN_LOG_RETENTION_DAYS` (docs/DEPLOY.md bolum 3 ve 8.1).
- **Hata kodlari (tr/en/ar, `i18n/ops*.properties`):** `ACCESS_BLOCKED`, `BAN_SELF_LOCKOUT`, `BAN_INVALID_VALUE`, `BAN_NOT_FOUND`, `BAN_BULK_TOO_LARGE`.
- **Sinirlar:** `X-Device-Id` istemci tarafindan gonderilir ve sahtelenebilir (cihaz engeli en iyi cabadir; kalici cozum Play Integrity / App Attest ile cihaz dogrulama); VPN/proxy icin tam garanti yoktur (cihaz engeli VPN'den bagimsizdir, IP/CIDR ve yonetici yuklemeli anonimlestirici listesi tamamlayicidir); engel gonderilen 403 yaniti CORS basligi tasimaz (tarayici istemcisi ayrintiyi goremeyebilir).

## Uygunsuz ifade filtresi (V300, `moderation.profanity`)

- **Bileşenler:** `ProfanityMatcher` (derlenmiş, değişmez eşleyici; 10 KB < 5 ms), `ProfanityFilter` (yerleşik dosyalar + `profanity_term`; 30 sn TTL + yönetici değişikliğinde anında tazeleme), `ContentGuard.assertClean/assertChanged` (servis katmanı; `FieldApiException` → `{code,message,field}`), `ProfanityHitLogger` (ayrı işlemde istatistik; kelime saklanmaz; 90 gün), `ProfanityAdminController` (`/api/admin/profanity*`).
- **Normalizasyon:** küçük harf, aksan sadeleştirme (ç ğ ö ş ü; `ı` ayrı kalır, "sıkıntı" engellenmez), 3+ tekrar sıkıştırma (çift harfli kökler sert), ayırıcı/boşluk/alt çizgi ile harf aralama, tek harflik seri birleştirme, leet (0 1 3 4 5 7 @ $ !), sıfır genişlikli karakter, Kiril/Yunan benzer harfler; Arapça: hareke/tatweel, alef-ya-ta marbuta varyantları, Arapça-Hint rakamları, ön ek (ال و ف ب ل ك) ve ek soyma; URL/e-posta sözcükleri atlanır; ALLOW listesi (yerleşik + yönetici) yanlış pozitifleri önler.
- **Kaynak:** LDNOOBW (CC-BY-4.0) `scripts/fetch-profanity-lists.js` ile tek seferlik indirilip temizlenir (çalışma zamanında ağ çağrısı yok); atıf: `backend/src/main/resources/moderation/NOTICE.md`. Yeniden üretmek için `node scripts/fetch-profanity-lists.js`; blok dışındaki elle yazılmış girişler korunur.
- **Ayarlar:** `app.moderation.profanity.enabled` (`PROFANITY_ENABLED`, true), `mode` (`PROFANITY_MODE`, BLOCK|FLAG), `cache-ttl-seconds` (`PROFANITY_CACHE_TTL_SECONDS`, 30).
- **Hata kodları (tr/en/ar):** `CONTENT_PROFANITY` (422), `PROFANITY_TERM_INVALID` (400), `PROFANITY_TERM_EXISTS` (409), `PROFANITY_TERM_NOT_FOUND` (404).
- **Sınırlar:** büyük harfli ASCII `I` ("SIKISIK") belirsizdir ve `i` sayılır (izin listesine bilinen masum sözcükler eklenir); FLAG modu moderasyon rapor kuyruğuna kayıt düşürmez (yalnızca istatistik); Arapça yalnızca kök/ek eşleşmesi yapar.
- Duman: `scripts/smoke-profanity.sh`.

## Günün menüsüne isteğe bağlı fotoğraf (V390, `menu`)

- `menu_day.image_url VARCHAR(500) NULL`. `MenuResponse` artık `{date, items, imageUrl}` (eski alanlar aynı; `imageUrl` yoksa `null`; ETag gövdeden üretildiği için fotoğraf değişince değişir).
- Admin: `GET /api/admin/menu?from=&to=` (boşsa içinde bulunulan ay, en çok 366 gün), `PUT /api/admin/menu/{date}/image` (multipart `file`; `MediaService.storeImage(..., COVER)` ile doğrulama/yeniden kodlama/EXIF temizliği, `/files/covers/...`; eski dosya `release` ile silinir), `DELETE .../image` (204). Hız sınırı 60/saat. Satır yoksa 404 `MENU_DAY_NOT_FOUND` (satır uydurulmaz).
- `MenuSyncService` yalnız `items` günceller; `image_url` korunur. `menu_day.image_url` medya yetim temizliği referans sütunlarına eklendi.
- Hata kodları (tr/en/ar `ops*.properties`): `MENU_DAY_NOT_FOUND`, `MENU_DATE_INVALID`, `MENU_RANGE_INVALID`.
- Akşam yemeği: backend'de öğün/akşam kavramı yoktur (menü gün başına tek `items` listesidir); değişiklik gerekmedi.

## Yemek kalorisi (V870, `menu`)

- Yeni tablo `menu_item_calorie (menu_date, item_key, item_name, kcal, updated_at, updated_by)`; `UNIQUE (menu_date, item_key)` (`mc_item_calorie_uq`), `CHECK kcal 0..5000` (`mc_ck_kcal`). `item_key` = yemek adının normalize hali (`MenuItemKey.of`: NBSP/boşluklar tek, büyük/küçük harf ve Türkçe harf farkı yok sayılır: `I/İ/ı→i`, `ç/ş/ğ/ö/ü→c/s/g/o/u`; böylece kaynağın BÜYÜK HARFLİ adı ile yöneticinin yazdığı ad aynı yemeğe gider). Öğün kavramı yoktur (menü gün başına tek liste), bu yüzden anahtar (gün, yemek adı).
- **Senkron kaloriye dokunmaz:** `MenuSyncService` yalnız `menu_day.items` yazar. Kaynak ayda bir yeniden çekilse, gün satırı silinip yeniden yazılsa ya da yemek listesine yeni yemek eklense, aynı (gün, ad) için girilmiş kalori korunur ve yeniden uygulanır. Gün menüsünden çıkan yemeğin kalori satırı yetim kalır (zararsız; gün+ad geri gelirse yeniden kullanılır).
- Yanıt: `MenuResponse` = `{date, items, imageUrl, dishes[{name,kcal}], totalKcal, kcalComplete}` (eski alanlar aynı).
- Admin: `PUT /api/admin/menu/{date}/calories` (sıkı) ve `PUT /api/admin/menu/calories` (toplu, gevşek; `{updated, cleared, unchanged, skipped[]}`). Hız sınırı 300/saat; RBAC `content.write` (`AdminPermissionPolicy`'de açık kural; FULL ve EDITOR yazar, VIEWER okur); denetim `AuditInterceptor` ile otomatik (`AuditContext` hedef + özet).
- Hata kodları (tr/en/ar `ops*.properties`): `MENU_KCAL_INVALID`, `MENU_ITEM_NOT_FOUND`, `MENU_KCAL_LIMIT`.
- Web: yönetim paneli menü sayfasında satır içi kalori düzenleme + toplu yapıştırma (`tarih;yemek;kcal`). Duman: `scripts/smoke-menu-calories.sh`.

## Sistem durumu ve gözlemlenebilirlik (`observability`)

- Yeni paket `edu.bingol.backend.observability`: `SystemOverviewService` + `SystemOverviewController` (`GET /api/admin/system/overview`), `DeadLetterService` (DEAD mail/push listele, yeniden kuyruğa al, sil), `SystemAlertService` (OK→CRIT geçişinde yönetici bildirimi), `JobMonitor` (Spring zamanlayıcı gözlemi: `@Scheduled` metotlarına dokunmadan son başarı/hata), `BackupStatusProvider`, `RequestIdFilter`, `LogMasking`. Migration yok. Sözleşme: [ADMIN_API.md](../ADMIN_API.md) "Sistem durumu".
- Prometheus: `bu_system_status`, `bu_indicator_status{indicator}` (0 OK, 1 WARN, 2 CRIT, -1 UNKNOWN), `bu_indicator_value{indicator}`, `bu_scheduler_last_success_seconds{job}`, `bu_scheduler_errors_total{job}` (mevcut `bu_mail_outbox`, `bu_push_*`, `bu_websocket_*` aynen kalır). Göstergeler en çok 15 sn'de bir hesaplanır (kazıma DB'yi yormaz).
- **Yedek arayüzü:** `BackupStatusProvider` yalnız okur; yedek ajanı `${STORAGE_DIR}/../backups/last-success.json` (ya da `BACKUP_STATUS_FILE`) dosyasını atomik yazar: `{"lastSuccessAt":"2026-10-28T09:00:00Z"}` (ayrıca `timestamp`/`epochSeconds`/`time` alan adları ve düz unix sayısı kabul edilir). Dosya yoksa gösterge `UNKNOWN`. Konteynerde dosyanın backend'e salt okunur görünmesi gerekir.
- Yeni log deseni: `logging.pattern.level=%5p [%X{requestId:-}]`. `X-Request-Id` yanıt başlığı + hata gövdesinde `traceId`. Sentry'deki PII temizliği (`ObservabilitySentry`) aynen geçerli; `LogMasking.scrub` yönetici panelinde gösterilen hata metinlerini maskeler.
- i18n: `i18n/obs*.properties` (tr/en/ar), `spring.messages.basename`'e `i18n/obs` eklendi.
- Web: `/admin/system` ("Sistem durumu", `SystemStatusPage`).

## Veritabanı ölçek/saklama düzenlemesi (V520, `dbmaint`)

Ayrıntı ve tablo envanteri: [DATABASE.md](../DATABASE.md). Kısaca:
- **Migration `V520__dbscale_indexes_retention.sql`:** `analytics_event_daily` (günlük özet + geri doldurma), BRIN indeksler (`dbs520_*`), yinelenen `idx_message_created` ve `idx_analytics_event_name/created` düşürüldü, kısmi indeksler (okunmamış bildirim, mail SENT/DEAD), `event_attendance(user_id)`, tablo bazlı autovacuum/fillfactor, `pg_stat_statements` (yetki yoksa atlanır).
- **`edu.bingol.backend.dbmaint`:** `DbMaintenanceJob` (03:00, `SchedulerLock`, parçalı silme: `ChunkedDeleter`), `AnalyticsRollup`. Yeni saklama: bildirim okunmuş 30 / okunmamış 90 gün + kullanıcı başına 200, mail SENT 7 / DEAD 30 gün, `admin_audit` 365, `message_access_audit`/`club_audit` 730, `activity_daily` 400, ham analitik olay **45 gün** (önce 180; kalıcı özet tabloda). Ayarlar `app.dbmaint.*` / `app.notification.*`.
- **Analitik raporları:** `topEvents`, `screenViews`, `searchesPerDay` tamamlanmış günleri özetten okur; `topEvents.uniq` gün-tekil toplamıdır (anlam notu DATABASE.md bölüm 3). KVKK dışa aktarımı `retentionDays=45`. `ActivityTracker` son-görülme aralığı 5 → 15 dk.
- **Güvenlik ağı:** Hikari havuzu 30 (`DB_POOL_MAX`), `statement_timeout 8s`, `lock_timeout 3s`, `idle_in_transaction_session_timeout 30s`, Flyway ayrı bağlantı; zaman aşımı/havuz tükenmesi **503 `DB_TIMEOUT`** (`Retry-After: 5`, tr/en/ar). Hibernate `order_inserts/updates`, `default_batch_fetch_size=50`.
- **PostgreSQL ayarı:** `docker-compose.yml` ve `docker-compose.prod.yml` postgres `command:` (parametreli `PG_*`), yavaş sorgu logu, `pg_stat_statements`.
- **Sorgu koruması:** `QueryRulesTest` (izin listesi dışında `findAll()` yok). 20k sentetik veri: `scripts/perf/seed-20k.sql`.

## Kötüye kullanım / DoS dayanıklılığı (A2, denetim 2026-10-28)

- **İstek gövdesi sınırı:** `common/web/RequestBodyLimitFilter` (AccessBanFilter'dan sonra, Security'den önce). `/api/**` gövdeli yöntemler: varsayılan 64 KB (`app.http.max-body-bytes`), `/api/admin/**` 2 MB (`max-admin-body-bytes`), analitik 256 KB, yükleme allowlist'i (avatar, kapak, logo, gönderi/sohbet medyası, menü görseli) 55 MB (`max-upload-body-bytes`). `Content-Length` aşımı gövde okunmadan 413 `PAYLOAD_TOO_LARGE`; parçalı gövdede akış sayılır (`RequestBodyTooLargeException` -> 413). Multipart akışını kapsayıcı okur (Content-Length önkontrolü + `spring.servlet.multipart.*`).
- **Redis anahtar güvenliği (`RateLimiter`):** 80 karakter üstü anahtar SHA-256 ile kısaltılır (ham e-posta/başlık Redis'e girmez); her anahtara TTL; saatlik yeni-anahtar bütçesi (`app.ratelimit.max-new-keys-per-hour`, 200000) aşılırsa yeni anahtar yaratılmaz, ön ek başına ortak taşma kovasına (limit x `overflow-multiplier`) sayılır. **Öneri (A4/ops):** Redis `maxmemory-policy` `noeviction` yerine `volatile-lru` (yalnız TTL'li anahtarlar atılır; refresh token/kod anahtarlarının TTL'i var, kalıcı anahtar yok) ve bellek %70 uyarısı.
- **Mail kota koruması:** `MailService.requireCodeQuota()` artık kimliksiz kod bütçesini de denetler: kayıt/kod yenileme/destek günlük kotanın `app.mail.public-code-share` (0.6) payına, şifre sıfırlama `reset-code-share` (0.85) payına kadar; kalanı gerçek kullanıcı/güvenlik postalarına rezerv. Tür, istek yolundan (`forgot-password`/`reset-password` = sıfırlama) çıkarılır; `requireCodeQuota(CodeKind)` ile açıkça da verilebilir. IP başına günlük kod isteği (`max-code-requests-per-ip-per-day`, 100; IPv6 /64) -> 429. Alıcı başına günlük en çok `max-codes-per-email-per-day` (10) kod: aşımda posta sessizce gönderilmez (hesap varlığı sızmaz). `sendRich` başarılı gönderimleri artık kota sayacına yazılır.
- **Herkese açık destek:** doğrulama kodu postasında kullanıcı adı yok (gövde şablonu `mail.support.code.body` yalnız kod+süre), `safeName` ad içindeki URL/adres karakterlerini atar; gönderim `MailService.sendPublicCode` (kota + alıcı sınırı + sayaç); talepten önce IP günlük 15 + genel saatlik 100 tavanı ve `requireQuota()`.
- **Yükleme:** `media/UploadGuard`: video için işlem içi `Semaphore` (`app.media.max-concurrent-uploads`=3, dolu = 429 `UPLOAD_BUSY`), kullanıcı başına tek yükleme (Redis INCR; paralel istekler `app.media.user-wait-ms` kadar sıraya girer; bekleyen-medya sayısı kontrolü bu kilidin içinde, yarış kapalı), günlük sayı/bayt kotası (`max-uploads-per-day` 300, `max-bytes-per-day` 800 MB -> 429 `UPLOAD_QUOTA_EXCEEDED`). Görüntü bombası: `ImageProcessor` her okumada kaynak örnekleme (`sub = max(w,h)/maxDim`), eşzamanlı çözme 2 (`app.media.concurrency`).
- **Analitik:** kullanıcı başına günlük olay üst sınırı `app.analytics.max-events-per-day` (2000; aşan olaylar sessizce atılır). **Cihaz günlüğü:** kullanıcı başına en çok `app.security.max-devices-per-user` (50) farklı cihaz özeti ve 4 katı satır; aşımda en eski satır devralınır; kullanıcı başına saatte 30 yeni (cihaz,IP) anahtarı. **`/api/me/summary`:** rozet yalnız sessiz olmayan sohbetleri sayar, 100'de kesilir ("99+"), 12 sn Redis önbelleği.
- **Mesaj/WebSocket:** `MessageService.send/markRead/typing` DB sorgularından önce Redis-yalnız kaba kullanıcı sınırı (`msg:all` 120/dk — tekrarlı clientId dahil, `read:all`, `typing:all`); STOMP SEND çerçeve sınırı `app.ws.max-frames-per-second` (20; aşan atılır, 5 katı = bağlantı kapanır).
- Yeni hata kodları (tr/en/ar `messages*.properties`): `PAYLOAD_TOO_LARGE`, `UPLOAD_BUSY`, `UPLOAD_QUOTA_EXCEEDED`.

## Video donusturme kuyrugu sayaclari (P03)
- `GET /api/admin/ops/transcode/stats` (yalniz ADMIN, dakikada 60; `media.transcode.AdminTranscodeController`) -> `{enabled, pending, processing, failed, doneLast24h}`. Sayaclar `post_media.transcode_status` (PENDING/PROCESSING/FAILED/DONE) satirlarindan; `doneLast24h` `transcode_at` >= simdi-24sa. `enabled=false` (`app.media.transcode.enabled`) ise web paneli "donusturme kapali" uyarisi gosterir. Yonetim paneli Operasyon > Kuyruklar sekmesi okur; kuyrugu degistirmez.

## Yonetici toplu islemler ve kaynak durumu (P15)
- Yeni `admin/bulk/*` (`AdminBulkController`): `POST /api/admin/news/bulk`, `/academic/bulk`, `/menu/bulk-delete`, `/pending-registrations/bulk-cancel` (sebep >= 5, kismi basari raporu `{requested, done, skipped, failed, results[]}`, en cok 200 kayit / 62 gun), CSV (`news|academic|menu|pending-registrations/export.csv`, formul kacirma, <= 50.000 satir; bekleyen kayitta e-posta/ad maskeli), `GET /api/admin/sources/status` ve `POST /api/admin/sources/sync` (kaynak basina saatte 3, sebep zorunlu; scraper kurali: elle tetikleme istisnadir). Mevcut tekil uclar degismedi; migration yok.
- `AdminGuardPolicy`: `menu/bulk-delete`, `pending-registrations/bulk-cancel`, `sources/sync` sebep ister ve yikici sayilir (`news|academic/bulk` zaten `.../bulk` kuraliyla kapsanir).
- Yeni hata kodlari (tr/en/ar `i18n/bulkadmin*.properties`): `BULK_EMPTY`, `BULK_LIMIT_EXCEEDED`, `EXPORT_ENTITY_INVALID`. Ayrinti: docs/ADMIN_API.md "Toplu islemler, disa aktarma ve kaynak durumu (P15)".

## Yonetici rol ve izin matrisi (P16)
- V780: `app_user.admin_profile` (FULL/MODERATOR/SUPPORT/EDITOR/VIEWER; mevcut ADMIN'ler FULL) + `admin_profile_change` (iki kisi onayli degisiklik onerileri, indeksler `p16_*`). `Role` USER/ADMIN olarak kalir.
- Yeni `admin/rbac/*`: `PermissionMatrix`, `AdminPermissionPolicy`, `AdminPermissionInterceptor` (403 `ADMIN_PERMISSION_DENIED`), `AdminProfileResolver`, `PermissionAwareMasking`, `RbacService`/`RbacController` (`/api/admin/rbac/*`). JWT'ye `ap` talebi; profil degisince `rolechg:<id>` isareti eski token'i reddeder.
- Yeni hata kodlari (tr/en/ar `i18n/rbac*.properties`; `spring.messages.basename`'e `i18n/rbac` eklendi): `ADMIN_PERMISSION_DENIED`, `RBAC_SELF_CHANGE`, `RBAC_TARGET_NOT_ADMIN`, `RBAC_NO_CHANGE`, `RBAC_LAST_FULL`, `RBAC_APPROVAL_REQUIRED`, `RBAC_APPROVAL_NOT_NEEDED`, `RBAC_CHANGE_PENDING`, `RBAC_CHANGE_NOT_FOUND`, `RBAC_CHANGE_DECIDED`, `RBAC_CHANGE_EXPIRED`, `RBAC_SAME_APPROVER`, `RBAC_CHANGE_STALE`. Ayrinti: docs/ADMIN_API.md "Yonetici rol ve izin matrisi (P16)".
- Davranis degisikligi: panelden USER -> ADMIN yapilan hesap VIEWER profille baslar (eskiden tam yetkiliydi); `ADMIN_EMAILS` ile yukselen hesap FULL.

## 20 bin kullanıcı yük testi bulguları (paket LD, 2026-10-29)
- **V800** (`load_search_indexes`): `news_item.search_vec` (saklı `tsvector`, GIN `ld_news_search_vec`; `NewsRepository.VEC = n.search_vec`, haber/arama sorguları artık `ts_rank`'ı yeniden hesaplamaz: en kötü terimde 24 ms -> 1,4 ms) ve gönderi araması için `ld_post_body_fts` + `ld_post_body_trgm` (30 bin gönderide 562 ms paralel seq scan -> 8,6 ms). `ADD COLUMN ... GENERATED STORED` tabloyu bir kez yeniden yazar (news_item küçük). Not: V820 (sözleşme) repoda V800'den yüksek; `spring.flyway.out-of-order` prod'da kapalı olduğundan V800'ü V820'den ÖNCE dağıtın (ya da dağıtılmış bir veritabanında geçici `out-of-order=true`).
- **Parola özetleme bölmesi:** `config/BoundedPasswordEncoder` (bcrypt'i saran `Semaphore`; `app.security.password-hash-concurrency` = 0 -> çekirdek-1, en az 1; `-max-queue` = 32 bekleyen; `-wait-ms` = 10000). 500 eşzamanlı giriş artık tüm çekirdekleri doldurup okuma trafiğini boğmaz; sıra dolu ya da bekleme aşılırsa anında **429 `RATE_LIMITED` + `Retry-After: 3`** (bekleyen istek bir Tomcat iş parçacığı tutar; sınırsız sıra tüm trafiği durdururdu). Giriş, kayıt, şifre değiştirme ve silme doğrulaması aynı bölmeyi paylaşır; istemciler 429'da `Retry-After` kadar bekleyip yeniden denemeli. Env: `PASSWORD_HASH_CONCURRENCY`, `PASSWORD_HASH_MAX_QUEUE`, `PASSWORD_HASH_WAIT_MS`.
- **Anket oyu:** `PollVoteService.vote` kuralları/seçenekleri KİLİTSİZ doğrular, `PESSIMISTIC_WRITE` satır kilidini yalnız yazma için (ballot + oy + atomik sayaç) alır ve görünümü kilit bırakıldıktan sonra kurar (300 eşzamanlı oy: bekleyen oylar Hikari havuzunu dolduruyordu). `TransactionTemplate`; davranış/sözleşme aynı.
- **JDBC soket zaman aşımı:** `spring.datasource.hikari.data-source-properties.socketTimeout` = 30 sn (`DB_SOCKET_TIMEOUT_S`), `connectTimeout` = 10 sn, `tcpKeepAlive`. Veritabanı DONARSA (ağ/askı) `statement_timeout` işleyemez; bu sınır takılı isteği 503 `DB_TIMEOUT` ile bitirir.
- **JwtService:** `JwtParser` bir kez kurulur (her istekte yeniden kurmak CPU profilinde ~%4-6 idi).
- Yük paketi: `scripts/perf/load/` (k6, README), sonuçlar `docs/perf-results/2026-10-29/`, yorum `docs/PERFORMANCE.md` "20k yük testi".
- **Ölü mail yeniden deneme koruması (INT3):** mail DEAD olurken değişkenleri temizlendiğinden (`{}`), `POST /api/admin/system/dead-letters/mail/retry` ve `POST /api/admin/ops/mail-outbox/retry-dead` artık içeriği yeniden üretilemeyen (ACCOUNT_DELETED hariç) ve 10 dakikadan eski kod postalarını kuyruğa almaz; yanıt `{requeued, skipped}` (`skipped` = alınmayan DEAD sayısı). Kayıt başına `POST /api/admin/mail/outbox/{id}/retry` zaten aynı kuralı uygular (`MAILOPS_RETRY_NO_CONTENT`/`_STALE_CODE`). Testler: `DeadLetterServiceTest`, `MailRequeueDeadTest`.


## Veri saklama, dışa aktarma ve depolama uyarısı (DS1)
- **V830** (`data_retention`): `data_export_receipt` (tablo, aralık, satır sayısı, indirilen gzip'in SHA-256'sı, yönetici, durum) ve `data_purge_log` (elle temizlik meta kaydı: aralık, makbuz, silinen, en eski/en yeni kayıt zamanı, gerekçe, durum/nabız); ikisi de `DELETE`'e kapalı (tetikleyici), indeksler `ds_*`.
- Yeni `dbmaint.admin/*` ve `/api/admin/data-retention/**` + `GET /api/admin/system/storage`. Yeni izinler `data.retention.read` (FULL, VIEWER), `data.retention.export`, `data.retention.purge` (FULL). Makbuzsuz silme yalnız FULL + >= 20 karakter gerekçe. `ChunkedDeleter.deleteAll` (ilerleme geri çağrısı) eklendi; gece işi davranışı değişmedi.
- `SystemOverview`: yeni `storage` göstergesi ve `jobs.storage-alert`; `StorageAlertJob` (15 dk, `SchedulerLock`): doluluk >= %80 WARN, >= %90 CRIT, durum kötüleşince yöneticilere uygulama içi bildirim (günde en çok 1 tekrar), e-posta yok. Genel `SystemAlertService` OK→CRIT uyarısı `storage`'ı hariç tutar (çift bildirim yok).
- Ayarlar (env): `OBS_STORAGE_WARN_PERCENT`, `OBS_STORAGE_CRIT_PERCENT`, `OBS_STORAGE_CHECK_MS`, `STORAGE_DB_DISK_PATH`, `STORAGE_DB_DISK_CAPACITY_BYTES`, `STORAGE_RESERVED_BYTES`; `app.retention.export-max-rows` (2.000.000), `preview-count-cap` (1.000.000), `export-page-size`, `export-concurrency`. Docker compose (dev + prod) bu env'leri geçirir; `.env.example` açıklamalı.
- **Önemli:** konteyner PostgreSQL'in diskini göremeyebilir; veritabanı diski yüzdesi `STORAGE_DB_DISK_PATH` ile ölçülür, yoksa `STORAGE_DB_DISK_CAPACITY_BYTES` ile **hesaplanır**, ikisi de yoksa panel "bilinmiyor" der (uygulama diski yine ölçülür).
- `IdempotencyFilter`: `POST /api/admin/data-retention/exports` atlanır (akışlı büyük yanıt bellekte önbelleklenmesin); `CorsConfig`: `X-Export-Receipt-Id` açığa çıkar. Yeni hata kodları: `docs/ADMIN_API.md` "Veri saklama ve depolama doluluğu (DS1)". i18n: `i18n/retention*.properties` (basename'e `i18n/retention` eklendi), `obs*.properties` (`obs.storageWarn|storageCrit`, `obs.msg.STORAGE_*`).

## Çökme raporları, anonim ve kendi sunucumuzda (CR1)
- **V860** (`crash_reports`): `crash_group`, `crash_event`, `crash_group_version` (indeksler `cr_*`). Yeni `crash/*` paketi: `POST /api/app/crash-reports` (herkese açık, 16 KB, cihaz başına günde 20 / dakikada 6, IP başına günde 300), `CrashScrubber` (sunucu tarafı maskeleme + hata imzası), `CrashService` (imzaya göre gruplama, grup başına son 50 olay, sürüm dağılımı, çözülmüş grubu yeni sürümde yeniden açma), `CrashAdminController` (`/api/admin/crashes`, `/summary`, `/{id}`, `PATCH /{id}/status`, `DELETE /{id}`; izin `system.read|write`; durum ve silme gerekçe ister), `CrashAlertService` (yeni grup için yöneticilere EN ÇOK saatte bir özet bildirim).
- **Gizlilik:** kullanıcı kimliği, e-posta, jeton ve mesaj içeriği alınmaz/saklanmaz (kimlik hiç yazılmadığından `DataExporter` gerekmez). IP ve cihaz özeti yalnız Redis hız sınırı sayacında 24 saat yaşar. Üçüncü taraf yok. Saklama: olay 30 gün (`app.dbmaint.crash-days`), grup son görülmesinden 30 gün sonra gece 03:00 temizliğinde silinir. Hukuki metinlere eklenmesi gereken cümle için avukat notu: docs/LEGAL_NOTES.md bölüm 10 (yasal metin migration'ı DEĞİŞTİRİLMEDİ).
- Ayarlar: `app.crash.per-device-per-day` (20), `app.crash.max-events-per-group` (50), `app.crash.alert-interval-minutes` (60), `app.dbmaint.crash-days` (30). `RequestBodyLimitFilter`: `/api/app/crash-reports` için sabit 16 KB. `SecurityConfig`: POST `/api/app/crash-reports` permitAll. Yeni hata kodları (tr/en/ar `ops*.properties`): `CRASH_NOT_FOUND`, `CRASH_STATUS_INVALID`, `CRASH_FILTER_INVALID`; bildirim `crash.alert.*`.
- **Mobil:** `core/crash/crash_reporter.dart` (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`; yalnız release; maskeli yığın izi gönderilir, hata iletisi ve kimlik gönderilmez; çevrimdışıysa dosyada en çok 20 kayıt, bağlantı gelince `lib/core/api.dart` ile anonim gönderim; imza başına oturumda 1; Ayarlar > Gizlilik > "Hata raporu gönder" anahtarı, varsayılan açık, kapalıyken hiçbir şey kaydedilmez/gönderilmez ve bekleyenler silinir). Mevcut `ErrorLog` (yerel günlük + `app_error` analitik olayı) aynen kalır. Cihaz modeli şimdilik gönderilmez (`device_info_plus` bağımlılığı eklenmedi).

## Sunucu disk temizliği ve yedek saklama düzeltmesi (CLN1)
- **Sunucu zamanlayıcısı:** `bu-docker-cleanup.timer` (günlük 04:30, systemd; Spring `@Scheduled` DEĞİL) eski `bu-*` imajlarını (>7 gün, kullanılmayan, `:previous`/`:local` değil), build önbelleğini (>72 sa, 2 GB ayrılır), `current` + `.previous_release` hariç en yeni 2'den eski sürüm dizinlerini ve durmuş proje-dışı konteynerleri siler; **volume'lara hiç dokunmaz**. Betik `scripts/ops/docker-cleanup.sh`, kurulum `scripts/ops/install-cleanup.sh` (deploy.sh `6b/7`, `--skip-cleanup`). Ayrıntı: `docs/DEPLOY_SCRIPT.md` "Disk temizliği". Uygulama içi `StorageAlertJob` (%80/%90) doluluğu bildirir, bu temizlik dolmasını önlemeye çalışır.
- **Yedek saklama:** `prune "$dir" 0` her saat "prune sayisi gecersiz (0); silme yapilmadi" uyarısı basıyordu; bu, kapalı (0) haftalık/aylık katmanlar içindi (zararsız, yanlış alarm). Günlük (saatlik yedek) katmanında `BACKUP_KEEP_DAILY=3` ile silme zaten çalışıyordu. `scripts/backup/lib.sh prune` yeniden yazıldı: kapalı katman + boş dizin sessiz; yalnız GEÇERLİ (`SHA256SUMS` + `db.dump.age`) yedekler sayılır, geçerli yedek N'den azsa silme yok. Sınama: `scripts/backup/selftest-prune.sh`. Backup konteyner imajı bir sonraki dağıtımda yenilenir (davranış `.env.prod` anahtarlarına bağlı değildir).

## Sunucu okuma önbelleği (C1)

Davranış değişikliği yok (aynı gövde); yalnız ek: `GET /api/news`, `/api/news/{id}`, `/api/menu`, `/api/menu/today`, `/api/status`, `/api/app/info`, `/api/app/version`, `/api/faq`, `/api/legal`, `/api/legal/{type}` yanıtlarına `Cache-Control` (+ `Vary: Accept-Language`) ve ETag (app/info, app/version, faq, legal için yeni) eklendi. Anonim istek: `public, max-age=N, stale-while-revalidate=M`; `Authorization` başlıklı istek: `private, max-age=N`. Yönetici yazması (haber gizleme, menü kalorisi, ayar, SSS, sözleşme sürümü) sunucuda anında, tarayıcı/CDN'de en geç `max-age` sonra görünür. Acil kapatma: `CACHE_ENABLED=false`. Ayrıntı ve envanter: `docs/PERFORMANCE.md` "Sunucu önbelleği".

## Yönetici yetki sertleştirmesi (W1-B, T-010..T-017)

Ayrıntı: `docs/ADMIN_API.md` "Yönetici yetki sertleştirmesi (W1-B)". Migration yok. **Davranış değişiklikleri (web/mobil/duman betiklerini etkiler):**
- **Yüzde-kodlu yönetici yolu (T-010):** `/api/admin/**` yolunda `%40` dışında `%xx` varsa `400 ADMIN_PATH_INVALID` (`AdminPathGuardFilter`); izin/gerekçe/hız/denetim kararları tek çözümleyiciden (`AdminPaths`) gelir; HEAD, GET kurallarıyla değerlendirilir.
- **Yeni izin `users.verify` (T-011), yalnız FULL:** `POST /users/{id}/verify-email` ve `POST /pending-registrations/{email}/verify` eskiden `users.write` (MODERATOR dahil) idi, artık MODERATOR `403 ADMIN_PERMISSION_DENIED`. Gerekçe >= 5 zorunlu; `ADMIN_EMAILS` adresi kodsuz doğrulanamaz (`409 VERIFY_ADMIN_EMAIL_FORBIDDEN`); `AccountCreator.create(email, p, false)` kodsuz yolda yönetici terfisi yapmaz. Web nav/`GuardedAction` (W2-K) `users.verify` anahtarını izlemeli (sözleşme C8).
- **Rol düşürme/silme (T-012):** hedef FULL ise `409 RBAC_APPROVAL_REQUIRED` (önce RBAC iki kişi onayıyla FULL profili düşürün), son FULL ise `409 RBAC_LAST_FULL`.
- **Gerekçe kapsamı (T-013):** `PUT /settings/{key}` (tüm anahtarlar), kullanıcı askı/erişim engeli/hesap işlemleri, gönderi gizle/göster/sil, haber PATCH, erişim engeli ekleme, push/mail kampanya oluşturma-zamanlama-iptal, `crypto/rewrap`, itiraz kararı artık >= 5 karakter gerekçe ister (ve yıkıcı saatlik sınıra girer). `X-Admin-Reason` başlığında/`?reason=` içinde kontrol karakteri `400 REASON_INVALID`. **Web (W2-K) bu eylemlerde gerekçe sormalı**; `smoke-admin*.sh`, `smoke-posts.sh` (unhide), `smoke-push-outbox.sh` (kampanya) ve `smoke-access-ban.sh` (`adm`/`admcode` yardımcıları) gerekçe başlığıyla güncellendi (`smoke-support.sh` zaten varsayılan başlık ekliyordu).
- **Hiyerarşi (T-014):** MODERATOR (ve `users.write` sahibi FULL olmayan profil) yönetici hesabına oturum kapatma/şifre sıfırlama/profil/cihaz müdahalesi yapamaz: `403 ADMIN_TARGET_FORBIDDEN`.
- **Sohbet çözme (T-015):** saatlik istek kotası (`app.crypto.admin-decrypt-per-hour`, 30; aşım 429), tek çağrıda `admin-decrypt-max-messages`; `GET /chat-messages` ve `GET /chat-media` kullanıcı/gönderen/sohbet süzgeci olmadan `400 FEED_FILTER_REQUIRED`; sohbet içeriği açan uçların gerekçesi >= 20 karakter. **Yapılmadı (K-13 bekliyor):** rapor kimliği zorunluluğu, ikinci onay, hacim eşiğinde `SystemAlertService` uyarısı. `docs/ENCRYPTION.md` (satır 37-38, 67, 234: "kullanılmaz / sabit sistem gerekçesi") güncellenmeli (W3-D).
- **Denetim (T-016):** başarısız (`>= 400`) istekte özet `BASARISIZ: HTTP <kod>`; `users.pii` uçları, `users/{id}/strikes`, `support/tickets`, `mail/outbox` GET'leri denetlenir.
- **Ayar doğrulama (T-017):** e-posta/bağlantı ayarlarında biçim + satır sonu + `https://` denetimi, `400 SETTING_INVALID`.

## Dagitim hatti ve KRITIK metin duzeltmeleri (W1-J, T-122..T-124, T-136..T-138, T-144..T-147, T-153)

API sekli DEGISMEZ; yalniz dagitim/yapilandirma ve kullaniciya gorunen metinler.

- **Prod compose degisken iletimi (T-144):** `docker-compose.prod.yml` `backend.environment` artik `application*.properties`'in okudugu tum ortam degiskenlerini `AD:` (degersiz) satiri ile iletir: `.env.prod`'da TANIMLIYSA konteynere gecer, tanimsizsa hic gecmez (bos dize gecmez; Spring bos degeri varsayilanin ustune yazardi). Eskiden `LEGAL_ENFORCE_REACCEPT`, `FCM_CREDENTIALS_FILE`, `DB_POOL_*`, `OBS_ALERT_*`, `BLOCK_ANONYMIZERS`, `BAN_*`, `PUSH_*`, `CHAT_*`, `MEDIA_*`, `RL_*`, `CACHE_*`, `DBMAINT_*` vb. (~150 degisken) .env.prod'a yazilsa bile etkisizdi. Ek: `APP_MAIL_ALLOW_LOG_ONLY`, `BACKUP_REMOTE` (yalniz validator uyarisi icin). Yeni kapi: `scripts/ci/compose-env-check.sh` (statik: her `${AD` iletiliyor mu; dinamik: ornek degerler `docker compose config`'te backend'e geciyor mu; muaf: DB_URL, DB_USER, REDIS_HOST, REDIS_PORT). Kok `docker-compose.yml` kucuk bir alt kume iletir.
- **E-posta (T-145):** prod `MAIL_ENABLED=false` ile `APP_MAIL_ALLOW_LOG_ONLY=true` olmadan BASLAMAZ (davranis degismedi; belge duzeltildi). `scripts/deploy.sh` Brevo bilgisi (`DEPLOY_MAIL_USER/PASSWORD`) yoksa dagitimi HICBIR sey aktarmadan reddeder (cikis 2); sunucudaki .env.prod de derlemeden once denetlenir; bilincli log-only icin `DEPLOY_ALLOW_LOG_ONLY=1`.
- **Dagitim (T-146):** `deploy.sh` calisan surum varsa derlemeden ONCE `backup.sh` calistirir, basarisizsa DURUR (`--skip-backup` ile atlanir); bekleyen Flyway migration'lari UYARI olarak listelenir; `-h` tam yardim; backend saglik bekleme `HEALTH_WAIT_BACKEND` (varsayilan 600 sn, `update.sh` de) ve compose healthcheck `start_period` `BACKEND_START_PERIOD` (varsayilan 360s; soguk acilis 262-465 sn). `docs/DEPLOY.md` bolum 0/14 uretimde `deploy.sh`'i anlatir.
- **Yedek (T-136):** yerel saklama varsayilani saatlik 7 / haftalik 4 / aylik 3 (`BACKUP_KEEP_*`); `ProdSettingsValidator` YENI UYARILAR (hata degil): `BACKUP_REMOTE` bos, `ADMIN_EMAILS` < 2 adres (K-31/T-153), `SENTRY_DSN` dolu. `deploy.sh` `DEPLOY_BACKUP_REMOTE`/`DEPLOY_BACKUP_WEBHOOK_URL` esler, yoksa uyarir. ACIK: yonetici sistem durumunda `BACKUP_REMOTE` bossa KIRMIZI gosterge (observability paketi) bu is akisinin kapsami disinda kaldi. Bilinen sinirlama: `backup.sh` haftalik/aylik hardlink'i Pazar/ayin 1'inde her saatlik calismada uretir (gunde bir degil).
- **Anahtar emaneti (T-137):** `deploy.sh` yerel sir kopyasini AYRI yazar: `.deploy/generated-secrets.txt` (CRYPTO dahil) ve `.deploy/backup-age-private.key` (age ozel anahtari; yerel kopya dogrulanmadan sunucudan silinmez). RUNBOOK bolum 12'ye anahtar emanet dogrulama gunlugu sablonu.
- **Caddy erisim gunlugu (T-147):** sorgu dizisindeki `token/code/password/key/secret` `REDACTED` yazilir (destek takip baglantisi gunluge dusmez), Authorization/Cookie/Set-Cookie yazilmaz; saklama Docker json-file donusu (10 MB x 5) ile belirlenir, sabit gun vaadi yoktur (belgelendi).
- **Marka yazimi (T-124):** takvim adi (`IcsService.CALENDAR_NAME` = "BÜ Kampüs") ve sistem uyari e-postasi konusu (`SystemAlertService.alertSubject`) "BÜ Kampüs"; PRODID/log ASCII kaldi.
- Harici izleme (T-138): `docs/DEPLOY.md` "Harici izleme (ZORUNLU)" ve `docs/LAUNCH_CHECKLIST.md` adim 13.

## Backend performans: sorgu ve veri yolu (W2-A, T-068..T-073)

API sekli DEGISMEZ; yalniz davranis/performans. Olcum onceleri/sonralari: `docs/PERFORMANCE.md` "W2-A".

- **Gorsel isleme islem disinda (T-068):** avatar/kapak/logo/grup fotografi/menu fotografi yuklemede `media.storeImage` artik acik DB isleminde calismaz (`common/ShortTx`); yalniz URL yazimi (+ gorunum) kisa islemdedir, eski dosya commit'ten SONRA birakilir. Yetki/durum kisa islemde yeniden dogrulanir. Elle kurulan birim testlerinde islem yoneticisi yoksa cagri dogrudan calisir (`setTxManager` @Autowired(required=false)).
- **Anket oyu (T-069):** `PollVoteService.applyCounters` once secenek sayaclarini (artan kimlik), anket `voter_count` UPDATE'ini islemin SON ifadesi yapar; secmen sayisi degismeyen oy degisikliginde anket satirina dokunulmaz, "hala acik mi" kilitsiz sayimla (`PollRepository.countOpenAt`) dogrulanir (kalan pencere yalniz yonetici durum degisikligi). Kapanis hala ayni ifadede dogrulanir (yeni secmen / geri cekme). `voter_count`, `AccountDataPurger` sozlesmesi (hesap silinince korunur) nedeniyle COUNT'a cevrilmedi.
- **Takip akisi (T-070):** `SocialFeedRepository.followingFirst/After` imzasi `authors` listesi alir; `followeeIds` (en yeni 2000 takip) + kendisi. 2000'den fazla kisiyi takip edenlerde en eski takipler akista gorunmez (bilinen sinir, `MAX_FOLLOWED_AUTHORS`).
- **Gece bakimi (T-071):** `ChunkedDeleter` PostgreSQL'de parca basina `SET LOCAL statement_timeout` (`app.dbmaint.statement-timeout-ms`, 60000; 0 = kapali), agir tablolar `deleteHeavy` (`app.dbmaint.heavy-chunk-size`, 2000), `bu_dbmaint_chunk_failed_total{table}`; `DbMaintenanceJob.nightly()` parca hatasinda sonunda `IllegalStateException` firlatir (is "basarisiz" gorunur). Yeni ortam degiskeni zorunlu degil. Oneri (W2-A disi dosya): `SystemOverviewService.JOBS` listesine `DbMaintenanceJob.nightly` (NIGHTLY) eklenirse sistem durumunda gorunur.
- **Etkinlik listesi N+1 (T-072):** `CommunityService.standingsOf` / `ClubPermissions.standingsOfUser` / `ClubMemberGrantRepository.findByUserIdAndCommunityIdIn`; `EventService.manageableIds` kulup basina sorgu yapmaz.
- **Gereksiz indeksler (T-073):** `backend/src/main/resources/db/pending-k33/V961__prf9_drop_unused_indexes.sql` (+ `.conf`) HAZIR ama Flyway konumunda degil; K-33 onayi + 14 gun `pg_stat_user_indexes` dogrulamasi (H-08) sonra `db/migration` altina tasinir.
