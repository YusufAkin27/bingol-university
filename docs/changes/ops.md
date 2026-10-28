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
