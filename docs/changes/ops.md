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
