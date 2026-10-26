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
- `ix_ops_ticket_queue (status, id) WHERE email_verified`: yonetici destek kuyrugu (id imecli).
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
