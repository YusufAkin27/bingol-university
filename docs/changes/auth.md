# Auth degisiklikleri (guvenlik duzeltmeleri)

## Yeni uc

### POST /api/auth/logout-all
Kimlikli (Bearer). Tum cihazlardaki refresh token'lari siler ve eski access token'lari reddettirir.
Rate limit: kullanici basina 15 dk'da 5. Yanit: `204 No Content`. Hata: `401`, `429 RATE_LIMITED`.
Cagiran cihazin da oturumu kapanir; yeniden giris gerekir.

## Davranis degisiklikleri (sozlesme uyumlu)

- **Kayit (`/register`)**: Kayit verisi (sifre ozeti, ad, dil) e-posta dogrulanana kadar yalnizca Redis'te (`reg:<email>`, 1 saat) tutulur; DB'de hesap satiri olusmaz. Dogrulanmamis bir adresle tekrar kayit, mevcut veriyi ezmez; 60 sn bekleme suresindeyken `429 RESEND_COOLDOWN` doner. Gerekce: eski akis dogrulanmamis satirin sifresini ezdigi icin baskasinin e-postasiyla onceden kayit acip sahibi dogruladiktan sonra hesabi ele gecirmek mumkundu; Redis'te tutmak sema/migration degisikligi gerektirmez. Dogrulanmis e-posta icin `409 EMAIL_ALREADY_REGISTERED` aynen kalir.
- **`/verify-email`**: Hesap ancak dogru kodla acilir (ad/sifre kayit istegindeki verilerdir) ve sozlesme onayi o anda yazilir. Bekleyen kayit yoksa, kod yanlissa veya e-posta zaten dogrulanmissa ayni `400 INVALID_CODE`. Ek rate limit: e-posta basina 10 dk'da 10.
- **Kod deneme limiti**: 5 yanlis denemeden sonra kod silinmez, adres 10 dk kilitlenir (`429 TOO_MANY_ATTEMPTS`); `/resend-code` ya da yeni `/register` kilidi ve sayaci sifirlar. Dogru kod tek kullanimliktir (atomik silme).
- **`/resend-code`**: Bekleme suresi ve e-posta gonderim hatalari yutulur; her durumda ayni `202` cevabi (hesap varligi sizmaz).
- **`/login`**: Kullanici yokken de sahte hash ile `encoder.matches` calisir (sabit sure).
- **Access token iptali**: `JwtAuthFilter`, `pwchg:<uid>` (epoch sn) isaretinden once uretilen token'lari reddeder (`rolechg:` ile ayni mantik, TTL = access omru + 1 dk).
- **Refresh token indeksi**: `rtu:<uid>` kumesi; `RefreshTokenService.revokeAll(uid)`.

## Kayit dogrulamada parola kaniti (B3, 2026-10-28)

- **Sorun (A1 kalan risk):** gercek e-posta sahibi kayit olduktan sonra saldirgan ayni adrese yeniden `register` gonderirse bekleyen kayit "son yazan kazanir" ile ezilir ve sahibine yeni kod gider; sahip bu kodu girerse SALDIRGANIN parolasi etkinlesirdi.
- **Cozum:** `POST /api/auth/verify-email` govdesine `password` (<= 72) eklendi (`VerifyEmailRequest`; `verify-reset-code` eskisi gibi `VerifyRequest`). Istemci kayit adiminda girdigi parolayi dogrulama adiminda yeniden gonderir; `AuthService.verifyEmail` bunu bekleyen kayitta saklanan BCrypt ozetiyle karsilastirir (`encoder.matches`). Uyusmazsa/yoksa genel `400 INVALID_CODE` (enumerasyon yok) ve **yanlis deneme sayilir** (`VerificationService.recordWrongAttempt`: kodu TUKETMEZ, dogru kod yanmaz; 5 deneme/10 dk kilidi, kume ve saatlik toplam sinirlari gercek yanlis kodla ayni). Parola kontrolu kod dogrulamasindan ONCE yapilir.
- **Geriye uyumluluk:** `app.auth.verify-requires-password` (`AUTH_VERIFY_REQUIRES_PASSWORD`, varsayilan **true**). `false` iken `password` YOKSA kontrol atlanir (parola kanitini bilmeyen eski istemciler); `password` GELIRSE her durumda dogrulanir. Mobil ve yeni web surumleri her zaman gonderir. Eski istemciler yayilinca bayrak true kalmali; `false` yalniz gecis penceresi icindir ve A1 riskini geri acar.
- Mobil: kayit/giriste girilen parola bellekte tutulur ve dogrulamada gonderilir; uygulama yeniden acilip bellekte yoksa dogrulama ekraninda "Kayitta belirlediginiz sifre" alani cikar.
- Smoke/e2e betikleri (`scripts/*.sh|js`) `verify-email` govdesine `password` ekler.
- Testler: `AuthServiceTest` (uyusmazlik, eksik parola, IP kapsamli sayac, bayrak kapaliyken eski istemci, bayrak kapaliyken verilen yanlis parola), `VerificationServiceTest.recordWrongAttempt*`.
- Hata kodu degisikligi yok (mevcut `INVALID_CODE`).

## Yonetici e-postasi alan adi istisnasi (DEP2, 2026-10-29)

- **Sorun:** `register` yalniz `bingol.edu.tr` kabul ediyordu; uretimde `ADMIN_EMAILS=ysufakin23@gmail.com` oldugundan bu hesap hic olusturulamiyor, panele girilemiyordu.
- **Cozum:** `AuthService.register`, adres `app.admin.emails` (`AdminProperties.isAdminEmail`, buyuk/kucuk harf duyarsiz, TAM adres eslesmesi) listesindeyse alan adi kisitini atlar; baska hicbir adres icin gevsemez (liste bossa eski davranis, `400 EMAIL_DOMAIN_NOT_ALLOWED`). E-posta dogrulama kodu (parola kaniti dahil), parola kurallari, sozlesme kabulu, hiz siniri, genel `202` cevabi ve `+etiket` yasagi (`EMAIL_ALIAS_NOT_ALLOWED`) aynen gecerlidir. Rol/profil dogrulamada `AccountCreator` ve girişte `promoteIfAdmin` ile ADMIN/FULL olur (degismedi). Giris (`LoginIdentifier`: tam e-posta ya da okul numarasi kisayolu) ve sifre sifirlama akislari alan adina bakmaz, bu adresle de calisir.
- **Guvenlik:** yetki yukseltme yolu acilmaz: yonetici olmak icin adresin sunucu yapilandirmasinda (ADMIN_EMAILS) olmasi VE adres sahibinin kutusundaki kodu girmesi gerekir; listede olmayan adres okul disi alan adiyla kayit olamaz. Yonetici listesine adres eklemek yalniz dagitim ayaridir (API'den degistirilemez).
- **Web:** `/admin/register` (ya da ADMIN_PATH altindaki `register`): kayit -> e-posta kodu -> otomatik giris; istemcide alan adi kontrolu YOKTUR, karar sunucudadir. Mobil istemci okul alan adini istemcide dayatmaya devam eder (yonetici paneli webdedir).

## Diger modullerin kullanabilecegi servis

`auth.token.SessionService.revokeAll(userId)`: refresh token'lar + `pwchg` isareti. Sifre sifirlama/degistirme akislari bunu cagirmalidir.

## Hata kodlari
Yeni hata kodu yok (i18n degisikligi gerekmedi).

## Notlar
- Depoda sifre sifirlama / sifre degistirme ucu yok (bkz. CLAUDE.md "Sifre sifirlama yok"); bu yuzden `forgot-password` / `verify-reset-code` icin degisiklik yapilamadi. `VerificationService` kilit/tek kullanim mantigi ve `SessionService` hazir.
- Redis anahtarlari: `reg:<email>`, `vc:lock:<email>`, `rtu:<uid>`, `pwchg:<uid>`.


## Tek cihaz (tek oturum) kurali - mobil

- **Kapsam**: yalniz `client=mobile` girisleri. `POST /auth/login` (ve `verify-email`) govdesine opsiyonel `client` (`mobile|web`, varsayilan `web`, gecersiz = 400). Mobil giris, kullanicinin onceki MOBIL oturumlarini kapatir; web oturumlari birbirini ve mobili kapatmaz. Sifre sifirlama ve `logout-all` TUM istemcileri kapatmaya devam eder (`SessionService.revokeAll`).
- **Sira**: `AuthService.login` -> `SessionService.revokeClient(uid,"mobile",true)` (refresh'ler silinir, `pwchgm:<uid>` yazilir, 1 ms beklenir, `SessionsRevokedEvent` yayinlanir) -> yeni token'lar. Yeni access token'in `iatms` degeri isaretten kesin buyuktur, bu yuzden hemen kabul edilir.
- **Token'lar**: access JWT'ye `cl` (`mobile|web`; talepsiz eski token = web). Refresh kaydi `rt:<hash>` = `uid:client` (eski `uid` degeri web sayilir). `JwtAuthFilter`: `pwchg` tum token'lara, `pwchgm` yalniz `cl=mobile` token'lara uygulanir.
- **401 SESSION_REPLACED**: iptal yuzunden reddedilen (imzali, suresi dolmamis) access token'da filtre istek ozniteligi `auth.sessionReplaced` koyar; `ApiAuthenticationEntryPoint` `{"code":"SESSION_REPLACED","message":...}` yazar. `POST /auth/refresh`: iptal edilmis refresh token'in mezar tasi (`rtx:<sha256>` = uid, TTL refresh omru) varsa 401 `SESSION_REPLACED`; bilinmeyen/suresi dolmus/normal cikis yapilmis = `INVALID_REFRESH_TOKEN`.
- **WebSocket**: `TokenExpiryGuard` olayi dinler; etkilenen oturumlar olay aninda sabitlenir (sonradan baglanan yeni cihaz kapanmaz), her birine yalniz o oturuma `/user/queue/message-events` `{"type":"session-replaced","at":...}` gider, `app.session.close-delay-ms` (varsayilan 400) sonra close(1008, `SESSION_REPLACED`). `StompAuthInterceptor`: CONNECT'te iptal edilmis token `ERROR SESSION_REPLACED`; oturum niteligi `wsClient`.
- **Push/e-posta**: `notification.SessionDeviceCleaner` mobil yeni giriste kullanicinin tum `device` kayitlarini siler (sessiz veri bildirimi eklenmedi). `auth.NewLoginNotifier` eski mobil oturum varsa mevcut `SECURITY_NEW_LOGIN` sablonuyla (tr/en/ar, kuyruk) guvenlik e-postasi gonderir; hata girisi bozmaz.
- **Yeni anahtarlar**: Redis `pwchgm:<uid>` (ms, access omru + 1 dk), `rtx:<hash>`; i18n `error.SESSION_REPLACED` (`auth.properties`, `_en`, `_ar`); ayar `app.session.close-delay-ms`.
- **Bilinen sinirlar**: iptal sirasinda eszamanli calisan bir refresh istegi yeni token alabilir (dar yaris, en gec bir sonraki girisle kapanir); WS olayi/close yalniz o sunucudaki baglantilara gider (coklu ornekte Spring olayi yereldir, access token zaten 401 olur). Dogrulama: `scripts/smoke-single-session.sh`.

## Okul numarasiyla kimlik ve dogrulanmamis giris

- `auth/LoginIdentifier.normalize`: tum kimlik uclarinda `email` alani tam e-posta YA DA okul numarasi (6-12 rakam; bosluk/tire/nokta temizlenir) -> `<numara>@bingol.edu.tr`. Gecersiz = `400 VALIDATION_ERROR`. DTO'dan `@Email` kalkti (`@NotBlank @Size(max=254)`); `AuthService.normalizeEmail` buna delege eder.
- Bekleyen kayit TTL'i `app.auth.pending-registration-ttl` (`AuthProperties`, varsayilan 72h); yalniz kayitta verilir, resend/giris uzatmaz. Hash alanlari: `ca` (olusturma), `rc` (yeniden gonderim sayaci, `markResend`).
- `login`: hesap yoksa ve bekleyen kayit varsa bekleyen kaydin bcrypt ozetiyle karsilastirilir; dogruysa `403 EMAIL_NOT_VERIFIED`, yanlis/kayit yoksa genel `401 INVALID_CREDENTIALS` (sahte ozetle esit sure).
- `resend-code`: ek limit e-posta basina saatte 5 (IP 10); kayit yoksa genel 202.
- Yonetici: `GET /api/admin/pending-registrations?cursor&size` ve `DELETE /api/admin/pending-registrations/{email}` (bkz. `docs/ADMIN_API.md`).
- Yonetici dogrulama: `POST /api/admin/pending-registrations/{email}/verify` (kodsuz hesap olusturur, `AccountCreator` + sozlesme onayi), `/resend-code`, liste `q` suzgeci; `POST /api/admin/users/{id}/verify-email|send-reset|revoke-sessions` (`AdminAccountVerificationService`). Yeni hata kodlari: `PENDING_REGISTRATION_NOT_FOUND`, `USER_NOT_VERIFIED`.

## Sifre degistirme (oturum acikken)

### POST /api/auth/change-password
Kimlikli (Bearer). Govde `{currentPassword, newPassword}` (yeni sifre 8-72). Yanit **200 `TokenResponse`** (accessToken, refreshToken, expiresInSeconds, tokenType), 204 degil.
- Hatalar: `403 WRONG_PASSWORD` (hesap silme ile ayni kod), `422 PASSWORD_UNCHANGED` (yeni; tr/en/ar), `400 VALIDATION_ERROR`, `429 RATE_LIMITED`.
- Rate limit: kullanici basina saatte 5 (`chpw:user:<id>`), IP basina saatte 10 (`chpw:ip:<ip>`).
- Oturum iptali: `pwchg:<uid>` isareti tek bir cihazi koruyamaz (kullanicinin TUM eski token'larini reddeder), bu yuzden `SessionService.revokeAll` cagrilir (refresh kumesi + pwchg + WS kapatma olayi), 1 ms beklenir (yeni token'in `iatms` degeri isaretten buyuk olsun) ve cagiran istemci turunde (`cl` talebi) yeni access+refresh cifti doner.
- Basarida `MailService.sendPasswordChanged` (SECURITY_PASSWORD_CHANGED sablonu, kullanicinin dili) kuyruga yazilir; kuyruk hatasi islemi bozmaz.

## Kimlik dogrulama/oturum guvenligi (A1, guvenlik denetimi 2026-10-28)

- **H1 hesap devralma**: `register` bekleyen kayit varken artik SON YAZAN KAZANIR: kod gonderildikten SONRA bekleyen kayit (parola/ad) ezilir, eski kod gecersiz olur (`AuthService.register`). Kod bekleme suresi (60 sn) 429 verirse bekleyen kayit ezilmez. Cevap her durumda 202 (varlik sizmaz). Bilinen artik risk: adres sahibi kayit olduktan SONRA bir saldirgan ayni adresi yeniden kaydederse sahibine 2. kod gider; sahibi o kodu girerse hesap saldirganin parolasiyla acilir. Hafifletme: e-posta basina 5 kayit/saat + 20 kod postasi/gun (asagida). Kalici cozum istemci degisikligi ister: `verify-email` istegine parola eklenip bekleyen ozetle karsilastirilmasi (oneri, mobil bellekte parolayi zaten tutuyor).
- **E-posta basina limit** (`AuthController`): `register:email:<ozet>` 5/saat, `resend`/`forgot` 5/saat, ortak `codemail:day:<ozet>` 20/gun. Anahtarlar `+etiketsiz` kanonik e-postanin SHA-256 ozetidir (sabit uzunluk; Redis anahtar sisirme yok). IP limitleri kampus NAT'i icin genisletildi (register/resend/forgot 30/saat, login 200/15 dk, refresh 300/15 dk, verify 60/10 dk).
- **IPv6 /64**: `ClientIp.limitKey` (statik + istek) IPv6'yi /64'e indirger, IPv4-eslenik adresi IPv4'e cevirir; auth uclarinin tum IP anahtarlari bunu kullanir. `ClientIp.of` (log/denetim/engel) tam adresi korur.
- **Hedefli kilitleme yok**: giris limiti artik YALNIZ basarisiz denemeleri sayar (`LoginThrottle`): (e-posta ozeti, IP/64) cifti basina 10/15 dk + e-posta genelinde (istemciden bagimsiz) 60/15 dk ust sinir; basarili giris cift sayacini siler; kilit bcrypt'ten ONCE kontrol edilir. Dogrulama/sifirlama kodu yanlis denemeleri (e-posta, IP/64) cifti basinadir (`VerificationService.verify(email, code, scope)`), kod basina tum istemcilerden 20 deneme ust siniri ve yeni kodla SIFIRLANMAYAN saatlik toplam yanlis deneme siniri (60; asilirsa adres kilitli kalir, yeni kod kilidi acmaz). `consumeResetToken` once karsilastirir, yalniz eslesirse siler (yanlis jeton gercegini yakmaz).
- **Refresh**: deger `rt:<hash>` = `uid:client:authTimeMs` (eski degerler okunur, authTime=0). Rotasyonda authTime korunur; mutlak omur `app.auth.session-max-days` (90 gun) asilirsa 401 `INVALID_REFRESH_TOKEN`, yeni token TTL'i kalan omre kisitlanir. Tuketilen token `rtused:<hash>` (TTL `app.auth.refresh-reuse-window`, 6 sa) birakir; ayni token `app.auth.refresh-reuse-grace` (10 sn, agda kaybolan yanit) otesinde tekrar sunulursa CALINMA sayilir: kullanicinin tum oturumlari kapanir (`SessionService.revokeAll`), cevap yine `INVALID_REFRESH_TOKEN`. Cikis (`logout`) isaret birakmaz. `SessionService.revokeAll` isareti (`pwchg:`) refresh kumesini okumadan ONCE yazar; refresh, oturum zamani isaretten eskiyse reddeder ve tuketme/uretim arasina revokeAll girdiyse yeni cifti de kapatir (yaris kapandi).
- **ProdSettingsValidator**: `.env.example`/`.env.prod.example` yer tutucu parcalari (`degistir`, `YER_TUTUCU`, `en-az-32`, `change-me`, `dev-only`, ...) JWT_SECRET/DB_PASSWORD/ADMIN_PASSWORD/CRYPTO_MASTER_KEYS icin HATA; JWT_SECRET en az 10 farkli karakter; ADMIN_PASSWORD < 12 karakter artik HATA (Basic aciksa).
- **Admin Basic auth**: `app.security.admin-basic.enabled` (yerel varsayilan true; `application-prod.properties` `ADMIN_BASIC_ENABLED` varsayilan **false**: prod'da yalniz JWT ROLE_ADMIN). Kapaliyken `httpBasic` ve kisitlayici hic kurulmaz, ADMIN_PASSWORD gerekmez; `/api/admin/**` kimliksiz 401 `{code,message}`. Aciksa `BasicAuthThrottleFilter`: basarisiz deneme sayaci (IP/64 basina 10, sabit kullanici adi basina 30 / 15 dk, dolunca 429), Redis hatasinda FAIL-CLOSED (503); denetim kaydinda aktor `basic-admin`. Uretilen rastgele admin parolasi log'a YAZILMAZ (ADMIN_PASSWORD verilmezse Basic kullanilamaz).
- **Askiya alma / silme**: `UserModerationService.suspend` ve `AdminUserService.delete` `SessionService.revokeAll` cagirir (refresh kumesi silinir, geri acilinca eski oturum canlanmaz). Rol degisim isareti (`rolechg:<uid>`) artik ms hassasiyetinde ve islem COMMIT OLDUKTAN sonra yazilir (`JwtAuthFilter.tokenPredatesRoleChangeMs`; eski saniye degerleri okunur).
- **BCrypt 72 bayt**: parola uzunlugu bayt olarak denetlenir; `register`/`resetPassword`/`changePassword` -> `400 PASSWORD_TOO_LONG` (tr/en/ar, kod e-postasindan ONCE), `login`/mevcut parola asiri uzunsa genel `INVALID_CREDENTIALS`/`WRONG_PASSWORD` (500 yok).
- **+alias politikasi (karar)**: `bingol.edu.tr` icin yerel kisimda `+` KAYITTA REDDEDILIR (`400 EMAIL_ALIAS_NOT_ALLOWED`, tr/en/ar): tek posta kutusu = tek hesap (anket tek oy, kullanici basina kotalar buna dayanir). Kanonikleştirme yerine ret secildi (kullanicinin yazdigi adres ile saklanan adres ayrismaz, yeni sutun/migration gerekmez). Daha once `+` ile acilmis hesaplar giris yapabilir; hiz siniri anahtarlari `+etiketi` atip ayni sayaci paylasir (`LoginIdentifier.aliasKey`).
- **Giris zamanlamasi**: hesap yok/bekleyen/hesap var yollari ayni bcrypt maliyetini oder (`dummyHash`); zamanlama farki bulunmadi, degisiklik yapilmadi.

## Kampus NAT'i ve hiz siniri yeniden tasarimi (RL1, 2026-10-29)

Sorun: binlerce ogrenci kampus agindan AYNI genel IP ile cikar; IP basina `login` 200/15 dk, `refresh` 300/15 dk, kayit/kod 30/sa gibi sinirlar gercek kullanicilari 429'a dusuruyordu (yuk testi `a-auth.js` her kullaniciya ayri `X-Forwarded-For` verdigi icin bunu olcmuyordu; olcum: `scripts/perf/load/rl1/nat-login.mjs`).

Ilke: kaba kuvvet korumasi HESAP/E-POSTA ve CIHAZ (`X-Device-Id` HMAC ozeti) bazli ve sikidir; IP sinirlari yalnizca yuksek "toplu/NAT" tavanidir; refresh siniri token sahibi kullanici bazlidir. Esikler `app.rate-limit.*` (`RateLimitProperties`, ortam degiskenleri `RL_*`; `application.properties`):

| Anahtar | Varsayilan | Anlam |
|---|---|---|
| `login-ip-max` | 5000 / 15 dk | IP basina TOPLAM giris denemesi (eski 200) |
| `login-ip-fail-max` | 600 / 15 dk | IP basina BASARISIZ giris (credential stuffing tavani) |
| `login-device-fail-max` | 30 / 15 dk | cihaz basina basarisiz giris (farkli hesaplari tarayan cihaz) |
| `login-pair-fail-max` | 10 / 15 dk | (e-posta, cihaz) cifti basina basarisiz giris; cihaz kimligi yoksa (e-posta, IP) cifti — **degismedi** |
| `login-email-ip-fail-max` | 30 / 15 dk | (e-posta, IP) cifti, cihaz kimligi VARKEN (kimlik dondurerek tek IP'den deneme tavani) |
| `login-email-fail-max` | 60 / 15 dk | e-posta basina istemciden bagimsiz basarisiz giris — **degismedi** (hesap basina kesin tavan) |
| `refresh-ip-max` | 30000 / 15 dk | IP basina refresh (eski 300) |
| `refresh-user-max` | 60 / 15 dk | token SAHIBI kullanici basina refresh (`refresh:user:<id>`) |
| `refresh-invalid-ip-max` | 600 / 15 dk | IP basina gecersiz/tuketilmis refresh denemesi (`refresh:bad:<ip>`) |
| `code-ip-max` | 1000 / sa | IP basina register / resend-code / forgot-password (her biri ayri; eski 30) |
| `code-device-max` | 10 / sa | cihaz basina kod postasi isteyen istek (ortak `codereq:dev:<ozet>`) |
| `verify-ip-max` | 3000 / 10 dk | IP basina verify-email ve verify-reset-code (eski 60) |
| `reset-ip-max` | 3000 / 10 dk | IP basina reset-password (eski 40) |
| `change-password-ip-max` | 600 / sa | IP basina change-password (kullanici basina 5/sa sabit) |

Ayrica `app.mail.max-code-requests-per-ip-per-day` 100 -> 3000 (gunluk kod istegi IP kotasi de NAT'ta tukeniyordu; e-posta basina `max-codes-per-email-per-day` ve genel gunluk posta kotasi sabit).

Davranis:
- `LoginThrottle`: basarisiz deneme (e-posta, cihaz) cifti basina sayilir; ayni NAT'taki saldirgan kurbanin cihazini kilitleyemez (kurban baska cihazdan girer). Cihaz kimligi rastgele degistirilirse (e-posta, IP) cifti 30'da, e-posta genelinde 60'ta durur. X-Device-Id gondermeyen istemcide eski (e-posta, IP) cift kurali (10) aynen gecerlidir. Tek hesaba toplam deneme tavani (60/15 dk) ve bcrypt-oncesi kontrol aynidir.
- `refresh`: once IP toplu tavani, sonra token tuketilmeden (`RefreshTokenService.peekUserId`, tek GET) sahibi bulunur ve `refresh:user:<id>` sayilir; bilinmeyen/tuketilmis token `refresh:bad:<ip>` sayilir. Yanit ve hata kodlari degismedi (enumerasyon yok: gecersiz token da ayni 401).
- Anahtar bicimleri: `lgf:i:<ip>`, `lgf:d:<cihaz>`, `lgf:pd:<eposta-ozeti>:<cihaz>`, `lgf:p:<eposta-ozeti>:<ip>`, `lgf:e:<eposta-ozeti>`. Hepsi 15 dk TTL, ham e-posta tutulmaz.
- Risk notu: IP basarisiz-giris tavani (600) kampus icindeki kotu niyetli biri tarafindan doldurulursa ayni NAT'tan giris 15 dk 429 olur; eski sinir (200 toplam) bunu 3 kat daha kolay yapiyordu. Esik `RL_LOGIN_IP_FAIL_MAX` ile ayarlanir; admin `access-bans` ile IP/cihaz engellenebilir.

## Basic auth yonetici ve /api/admin/ops (RL1)
`AdminOpsController` hiz siniri anahtari icin `CurrentUser.id()` istiyordu; Basic auth yoneticisinde (kayitli kullanici yok, principal `Long` degil) bu 401 `UNAUTHORIZED` veriyordu. Artik anahtar `actorKey()`: JWT yoneticisinde kullanici id'si, Basic yoneticide sabit `basic` (`admin:ops:basic`). Yetki degismedi (`/api/admin/**` yalniz ADMIN; Basic prod'da kapali; RBAC'ta Basic = FULL); denetimde aktor `basic-admin`.

## Sifre sifirlama yanit metni (W1-J, T-123)

`POST /api/auth/forgot-password` 202 govdesindeki `msg.forgot.sent` (tr) artik e-postaya KOD gittigini soyler: "Hesap uygunsa e-posta adresinize şifre sıfırlama kodu gönderildi." (eskiden "bağlantı" diyordu; e-postaya bir bağlantı değil 6 haneli kod gider). Yalniz metin; alan/kod degismedi. en/ar zaten "code" diyordu.

## W1-A: kimlik, oturum, hesap yasam dongusu, hata zarfi (T-001..T-009, 2026-10-31)

Kapsam: `docs/audit/prompts/W1-A-kimlik-oturum.md`. Yeni Flyway migration YOK (V900-V909 kullanilmadi).

### Kayit: gorunen ad ve e-posta (T-001)
- `AuthService.register`, kod e-postasi GONDERILMEDEN once `DisplayNamePolicy.normalize` calistirir (gorunmez karakter, bidi, `<script>`, `@`, emoji siniri, karisik yazi, ayrilmis/taklit adlar: `RESERVED_DISPLAY_NAME`, bicim: `INVALID_DISPLAY_NAME`). `ADMIN_EMAILS` adresleri yalniz "ayrilmis ad" kisitindan muaf, bicim kurallarindan degil. Bekleyen kayda NORMALLESTIRILMIS ad yazilir.
- `DisplayNamePolicy`'ye baglanti/alan adi benzeri ad reddi eklendi (`bit.ly`, `www.x`, `http...`; yaygin TLD listesi): profil adi guncellemesi de ayni kuraldan gecer.
- Kayit e-postasi yerel kismi: `%` ve bas/son/ardisik nokta YASAK (`a%evil.com@bingol.edu.tr`, `a..b@...` -> 400 `EMAIL_DOMAIN_NOT_ALLOWED`). Mevcut hesaplar etkilenmez (yalniz kayit).
- Mevcut ihlalli adlar icin YALNIZ OKUMA rapor (silme yok), PostgreSQL:
  ```sql
  -- gorunmez/bidi/sifir genislikli karakter iceren adlar
  SELECT id, email, display_name FROM app_user
   WHERE status <> 'DELETED' AND display_name ~ '[​-‏‪-‮⁠-⁤﻿<>@/]';
  -- baglanti benzeri / taklit adaylari
  SELECT id, email, display_name FROM app_user
   WHERE status <> 'DELETED' AND (display_name ~* '(www\.|https?|\.(com|net|org|ly|gl|me|io|co)(\s|$))'
      OR lower(display_name) ~ '(rektor|rektör|yonetici|yönetici|admin|destek|bukampus|support)');
  ```

### Parola politikasi (T-005; kullanici icin GEVSETILDI, yonetici guclu)
- **Yonetici OLMAYAN hesaplar** (kayit, `reset-password`, `change-password`): yalniz **en az 6 karakter** (kod noktasi sayisi; `app.auth.password-min-length`, varsayilan 6; `PasswordPolicy.requireForUser`). Buyuk/kucuk harf, rakam, yaygin parola listesi, dizi/tekrar ve kisisel veri denetimi UYGULANMAZ (`123456`, `aaaaaa`, okul numarasi gecerlidir). Kisaysa `400 PASSWORD_TOO_SHORT` (tr/en/ar, `{0}` = alt sinir). Ust sinir aynen: `max = 72` ve 72 BAYT (`PASSWORD_TOO_LONG`).
- **Yonetici hesaplari** (rol ADMIN, `ADMIN_EMAILS` adresleri, `adminPortal` kaydi) ESKI guclu kuralda kalir: en az **12** karakter (`app.auth.password-min-length-admin`) + `PasswordPolicy.require` (asagidaki tum denetimler); zayifsa `400 PASSWORD_TOO_WEAK`.
- `giris` politikaya BAGLI DEGIL; hesap kilidi/giris yavaslatma (`LoginThrottle`) ve IP hiz siniri aynen. RISK: okul numarasi tahmin edilebilir ve sifre zayif olabilir; savunma `LoginThrottle` + hiz siniri + (varsa) erisim engelleridir.
- Yonetici icin guclu kural ayrintisi (`PasswordPolicy.require`): `auth/common-passwords.txt` (yaygin parola + kok kelime listesi; sondaki rakam/yil/sembol atilarak kok kelimeye de bakilir: `Galatasaray1905`, `Sifre1234567`), tek karakter tekrari / rakam dizisi / klavye yurumesi, e-posta kullanici adi + okul numarasi + gorunen ad sozcukleri (>= 4 harf, Turkce karakter katlanir). Karakter sinifi zorunlulugu YOK.
- Uygulandigi uclar: `POST /api/auth/register`, `POST /api/auth/reset-password`, `POST /api/auth/change-password`. DTO'larda `@Size(min)` yok; `max = 72`.
- Yaygin parola listesi (~27 bin satir) elle derlenmis kok kelime + ek kaliplarindan URETILDI (dis kaynak/rockyou kullanilmadi); ilk 10k hedefi asildi ama gercek sizinti listesi degildir. Gerekirse `backend/src/main/resources/auth/common-passwords.txt` ek satirlarla buyutulebilir (kucuk harf, aksansiz).
- **ETKI (smoke/e2e, yonetici icin gecerli; kullanici artik >= 6):** `Sifre1234` gibi 9 karakterlik test parolalari artik reddedilir. Yeni betik parolasi: `Zk7-Qmv-Lpx92w` (14 karakter, listede degil). Diger betikler tasinana kadar `APP_AUTH_PASSWORD_MIN_LENGTH`/yaygin liste engeline takilirlar (bkz. W1-A teslim raporu).
- `reset-password`: yeni parola mevcutla ayni olamaz (`422 PASSWORD_UNCHANGED`); zayif/ayni parola reddi sifirlama anahtarini TUKETMEZ (`VerificationService.checkResetToken`); basarili sifirlamada "sifren degisti" guvenlik e-postasi gider.

### Kayitta fakulte/bolum/sinif istege bagli; ad opsiyonel (eski istemci uyumu)
- Mobil kayit sayfasi `displayName` GONDERIR (ad soyad kayitta alinir, `DisplayNamePolicy` aynen); `faculty`/`department`/`grade` BOS gider ve e-posta dogrulandiktan sonra profil guncelleme ucuyla girilir. Sunucu ayrica `displayName` olmadan da kaydi kabul eder (`RegisterRequest.displayName` `@NotBlank` degil, `@Size(max=80)` kalir; eski/yeni istemciler icin zararsiz).
- `displayName` bos/yoksa sunucu **gecici ad** atar (`DisplayNamePolicy.temporaryFor`): e-postanin yerel kismi (kullanici adi) gorunen ad kurallarindan geciyorsa o, gecmiyorsa (okul numarasi yalniz rakamdir) sabit `"Öğrenci"`. Bekleyen kayit (`reg:<email>`), `verify-email` ve oturum akisi degismez. Gecici ad uygunsuz ifade filtresine sokulmaz; `PasswordPolicy.Context` (yalniz yonetici yolunda kullanilir) o adi alir.
- **Yonetici kaydi** (`ADMIN_EMAILS` adresi ya da `adminPortal=true`) icin ad ZORUNLU kalir: bos ad `400 INVALID_DISPLAY_NAME` (eski davranis).
- Bolum/sinif (ve ad verilmediyse ad) kayittan sonra mobilde tek seferlik zorunlu adimda **`PATCH /api/users/me`** ile TEK istekte girilir (hepsi istege bagli alanlar; yalniz gonderilenler yazilir): `{"displayName","faculty","department","grade"}` (+ istege bagli `classYear`, `bio`, `showEmail`, `language`). Bolum/sinif icin kota/bekleme YOKTUR (yalniz katalog dogrulamasi, `ACADEMIC_INVALID`). Gorunen ad 7 gunde bir degisir (`DISPLAY_NAME_COOLDOWN`) ANCAK gecici adin (hic degistirilmemis) ilk gercek adla degistirilmesi muaftir: bekleme baslatmaz, `display_name_history`'e yazilmaz (`ProfileService.isTemporaryName`). Ucta saatte 10 istek siniri.

### Sifremi unuttum: kayitsiz hesapta 404; kod suresi/bekleme (kullanici karari)
- **`POST /api/auth/forgot-password`**: e-posta/okul numarasi dogrulanmis ve aktif bir hesaba ait DEGILSE (kayitsiz, dogrulanmamis, askida, silinmis/anonimlestirilmis hepsi ayni) e-posta/kod GONDERILMEZ ve `404 ACCOUNT_NOT_FOUND` doner (tr/en/ar `auth*.properties`). Hesap varsa 202 (kod gider). Bu, CLAUDE.md madde 5 (enumerasyona karsi genel cevap) kuralindan BILINCLI, yalniz bu uca ozel istisnadir; `msg.forgot.sent` artik "Hesap uygunsa..." demez. Dogrulama kodu uclari (`verify-reset-code`, `reset-password`) genel `INVALID_CODE` ile aynen kalir.
- **Koruma:** mevcut IP/cihaz/e-posta sinirlari (`forgot:ip` saatte 1000, `codereq:dev`, `forgot:email` saatte 5, `codemail:day` gunluk 20) + `requireMailQuota` AYNEN; ek olarak IP basina dakikada **15** (`forgot:ipmin:<ip>`, kayitsiz adresler de sayilir; NAT arkasindaki kampus agina uygun). RISK: okul numaralari tahmin edilebilir; 404/202 farki hesap varligini ogrenmeye (numara taramasi) izin verir, sinirlar yalnizca hizi yavaslatir.
- **Kod suresi:** kayit dogrulama, sifre sifirlama (ve sifirlama anahtari) ve herkese acik destek formu kodu **tam 10 dk** (`VerificationService.CODE_TTL`, `PublicSupportService.CODE_TTL`; mail sablonuna 10 gecer).
- **Yeniden kod bekleme suresi 180 sn** (eskiden 60): `resend-code`, `forgot-password` ve ayni adrese tekrar `register` icin Redis `vc:cd:<e-posta>` / `pr:cd:<e-posta>` (TTL 180 sn; ilk gonderim beklemesiz). Erken istek `429 RESEND_COOLDOWN` + `Retry-After` (kalan saniye, `{0}` ceviri argumani; `RateLimitedException(code, msg, retryAfter, args)`), yeni kod uretilmez. `resend-code` artik bekleme 429'unu yutmaz; bekleyen kaydi olmayan adreste kod gonderilmez ama `vc:rcd:<e-posta>` (180 sn) ile ayni 429 uygulanir (kayit varligi sizmaz). Herkese acik destek formu: ayni e-postaya 180 sn'de bir talep (`pubsup:emcd:`, `429 RATE_LIMITED` + `Retry-After`). 5 deneme/kilit/`requireMailQuota` degismedi. Duman: `smoke-student-number.sh` resend'i 429 bekler; ardisik kod istegi gerekirse `redis-cli del vc:cd:<e-posta>`.

### Yonetici kendini silemez (T-002)
- `DELETE /api/users/me`: rol ADMIN ya da `ADMIN_EMAILS` adresi ise `409 ADMIN_CANNOT_SELF_DELETE` (once baska bir yonetici panelden rolu dusurmeli). Parola yanlissa `403 WRONG_PASSWORD` onceliklidir.
- Anonimlestirme (hesap silme ve panelden silme): `role=USER`, `adminProfile=null`; `suspended:<id>` isareti ve `sessions.revokeAll(id)` (refresh kumesi `rtu:<id>` temizlenir) **commit sonrasi** (`common/AfterCommit`).

### Redis devre kesici (T-003)
- `common/RedisBreaker`: ilk Redis baglanti/zaman asimi hatasinda 5 sn (`app.redis.breaker-ms` / `REDIS_BREAKER_MS`) acilir. Aciksa Redis'e gitmeden: `JwtAuthFilter` kimlik KOYMAZ ve kimlik isteyen uc `503 REDIS_UNAVAILABLE` + `Retry-After` alir (fail-closed: askiya alinmis/oturumu iptal edilmis kullanici Redis yokken gecmez); `RateLimiter.check` dogrudan `RedisUnavailableException` (503) atar; `ActivityTracker.touch` atlar. Herkese acik uclar (haber/menu/durum) Redis'siz 200 doner (Bearer ile gelseler de).
- Komut/baglanti zaman asimi her profilde `500ms`/`1s` (`REDIS_TIMEOUT`, `REDIS_CONNECT_TIMEOUT`); `application-prod.properties`'teki 2 sn degerleri kaldirildi.
- `BasicAuthThrottleFilter`: 429 yalniz `RateLimitedException`; devre kesici 503'u fail-closed dalina duser.

### Standart hata zarfi (T-004)
- Her hata `{code,message,traceId}` + `Content-Language` + `Vary: Accept-Language`: `ApiExceptionHandler` artik `ErrorResponse` (404 `NOT_FOUND`, 405 `METHOD_NOT_ALLOWED` + `Allow`, 406 `NOT_ACCEPTABLE`, 415 `UNSUPPORTED_MEDIA_TYPE`...) ve yakalanmamis istisnalar (500 `INTERNAL_ERROR`, ayrinti yalniz log'da) icin zarf uretir; Spring Security istisnalari guvenlik zincirine birakilir. `ApiErrorController` (yeni, `/error`) konteyner `sendError` yonlendirmelerini (guvenlik 403'u, Tomcat) ayni zarfa cevirir; Boot'un HTML `BasicErrorController`'i devre disi.
- `ApiAuthenticationEntryPoint` TEK giris noktasi (`/api/admin/**` dahil). `WWW-Authenticate: Basic` YALNIZ: Basic acik + `/api/admin/**` + `Authorization` basligi HIC yok + Accept `application/json` degil + `Sec-Fetch-Dest` yok/`document`. Bozuk/suresi dolmus Bearer ya da fetch/XHR (yonetim paneli) asla Basic penceresi acmaz.

### Kilit DoS ve kod kilidi (T-006)
- `LoginThrottle`: hesap geneli tavan (`lgf:e:*`, 60) YALNIZ hesapla daha once basarili giris yapmamis ("bilinmeyen") istemciler icin. Basarili giris `lgf:ok:<ozet>:<d|i>:<cihaz|IP>` isaretini 30 gun birakir; tanidik istemci tavana takilmaz ve hatalari tavani doldurmaz (kendi cift sayaci 10 aynen gecerli). Sahte cihaz kimligiyle hedefli kilitleme hesabin gercek sahibini kilitlemez.
- `VerificationService.issue`: kapsamli `ns:sc:<email>:<ip>:att|lock` sayac/kilitleri `ns:scopes:<email>` kumesi uzerinden yeni kodla sifirlanir (5 yanlis + yeni kod + dogru kod = basarili). Saatlik toplam tavan (60) yeni kodla sifirlanmaz (tahmin butcesi korunur).

### Refresh idempotansi (T-007)
- `AuthService.refresh` basarida `rtnext:<eski ozet>` kaydi yazar (45 sn): yeni token cifti **AES-GCM, anahtar = SHA-256(eski token)** ile sifreli (Redis'te yeni refresh token acik metin olmaz). Ayni eski token tekrar sunulursa (yanit kayboldu) ve yeni refresh hala gecerliyse AYNI cift doner, oturumlar kapanmaz. Yeni cift bu arada kullanilmis/iptal edilmisse replay yok; tolerans (10 sn) otesindeki yeniden kullanim yine tum oturumlari kapatir (calinti).
- Mobil taraf: T-084 (W1-G).

### Oturum iptalinde FCM cihaz kaydi (T-008)
- `SessionDeviceCleaner.onSessionsRevoked`: `client == null && !newLogin` (logout-all, sifre degisimi/sifirlama, askiya alma) olayinda kullanicinin TUM cihaz kayitlari silinir (kilit ekraninda bildirim surmesin). Etkin cihaz giris/yeni token sonrasi `POST /api/devices` ile kendini yeniden kaydetmelidir (sifre DEGISIMINDE istek yapan cihaz da dahil).

### Kimlik kucukleri (T-009)
- `refresh`: askidaki hesap `403 ACCOUNT_SUSPENDED` (eskiden iptal mezar tasi nedeniyle yaniltici `SESSION_REPLACED`); `RefreshTokenService.revokedOwner`.
- `UserModerationService.unsuspend`: yalniz ASKIDAKI hesapta calisir (silinmis hesabin `suspended:` isareti silinmez, aktif hesaba "yeniden acildi" bildirimi gitmez); `suspend` Redis isareti + `revokeAll` commit sonrasi.
- Dogrulama/sifirlama kodu ozeti `HMAC-SHA256(app.auth.code-pepper, e-posta:kod)`; pepper varsayilan `jwt.secret`. UYARI: `JWT_SECRET` degisirse o an bekleyen (10 dk) kodlar gecersiz olur.

### Yeni hata kodlari (auth*.properties, tr/en/ar)
`PASSWORD_TOO_WEAK`, `ADMIN_CANNOT_SELF_DELETE`, `REDIS_UNAVAILABLE`, `INTERNAL_ERROR`, `METHOD_NOT_ALLOWED`, `NOT_ACCEPTABLE`, `UNSUPPORTED_MEDIA_TYPE`.

## Kayitta tam e-posta zorunlu (REGMAIL, 2026-10-31)

- **Sorun:** kayit formu yalniz okul numarasi kabul edip `<numara>@bingol.edu.tr` adresine kod gonderiyordu; gercek posta kutusu bu bicimde olmayan ogrencilerde kod kayboluyordu.
- **Kural:** `POST /api/auth/register` govdesindeki `email` `@` icermiyorsa `400 EMAIL_FULL_REQUIRED` (`AuthService.register`, `normalizeEmail`'den ONCE; kod gitmez, bekleyen kayit yazilmaz). Bos deger eskisi gibi `VALIDATION_ERROR`. `+etiket` reddi, `bingol.edu.tr` kisiti ve `ADMIN_EMAILS` muafiyeti degismedi.
- **Degismeyenler:** `login`, `resend-code`, `forgot-password`, `verify-email`, `verify-reset-code`, `reset-password` numarayi (`LoginIdentifier.normalize`) kabul etmeye devam eder (mevcut hesaplar numarayla giris yapar). Numarayla acilmis bekleyen kayit `resend-code`/`verify-email` ile tamamlanabilir.
- Mobil: kayit alani `RefIdentifierField(allowStudentNumber: false)` + `validateRegisterEmail` (yalniz tam e-posta, `@bingol.edu.tr` hapi yok, yardimci metin e-posta ornegi). Giris ve sifre sifirlama alanlari degismedi.
- Yeni hata kodu: `EMAIL_FULL_REQUIRED` (`auth.properties`, `_en`, `_ar`).
- Testler: `AuthServiceTest.studentNumberAloneIsRejectedAtRegisterWithoutSendingCode`, `fullStudentEmailRegistersAsIs`; mobil `student_number_test.dart`.

## Yonetici portali kaydi yalniz ADMIN_EMAILS (ADMINREG, 2026-10-31)

- **Sorun:** yonetici kayit sayfasi (`/<ADMIN_PATH>/register`) normal kayit ucunu cagiriyordu; herhangi bir `bingol.edu.tr` adresi buradan USER hesabi acabiliyordu.
- **Cozum:** `RegisterRequest.adminPortal` (opsiyonel `Boolean`, varsayilan yok = false). YALNIZ daha siki davranis ister, hicbir kurali gevsetmez. `adminPortal=true` iken adres `AdminProperties.isAdminEmail` degilse (bingol.edu.tr dahil) `AuthService.register` sessizce doner: kod e-postasi YOK, `pending.save` YOK, hesap aranmaz/acilmaz, cevap yetkili adresle ayni `202 {message}`. Controller hiz sinirlari (IP/cihaz, `register:email`, `codemail:day`) ve `requireMailQuota` iki durumda da ayni tuketilir; log'da e-posta `LogMasking.email` ile maskelidir.
- **Sizinti kapatma (portalda yetkili/yetkisiz ayirt edilemez):** parola/ad/katalog/alias dogrulamalari iki durumda da YONETICI kurallariyla kosar (parola asgari 12, ayrilmis ad muafiyeti); yetkisizde de parola ozeti (bcrypt) hesaplanir (sure farki yok); yetkili ama zaten kayitli adreste `409 EMAIL_ALREADY_REGISTERED` yerine sessiz 202; yetkili adreste kod bekleme suresi `429 RESEND_COOLDOWN` yutulur (eski kod/kayit kalir). Yetkili ve henuz kayitsiz adreste akis aynen surer (alan adi istisnasi, +etiket reddi, parola politikasi, dogrulama kodu).
- **Degismeyenler:** `adminPortal` yok/false iken bugunku davranis birebir (yalniz bingol.edu.tr + ADMIN_EMAILS istisnasi, `EMAIL_DOMAIN_NOT_ALLOWED`, 409 vb.). Mobil kayit etkilenmez. `verify-email`, `resend-code`, `login` degismedi. Yeni uc/hata kodu/i18n anahtari yok.
- **Web:** `authApi.register({..., adminPortal: true})` yalniz `AdminRegisterPage`'den; form ve kod adiminda "Yalnizca yetkilendirilmis yonetici e-posta adresleri kayit olabilir. Kod gelmediyse adresiniz yetkili degildir." notu; istemci asgari parola 12 (sunucu yonetici asgarisiyle uyumlu).
- **Not:** `docs/openapi.json` yeniden uretilmeli (`RegisterRequest.adminPortal`).
- Testler: `AdminPortalRegisterTest` (yeni), `AuthControllerThrottleTest` (bayrak iletimi + ayni sayaclar), web `AdminRegisterPage.test.tsx`.

## Iki faktorlu dogrulama (2FA-BACKEND, V1060, 2026-11-01)

Sozlesme: `docs/TWO_FACTOR_API.md` (birebir uygulandi). Isteye bagli; kullanici kendisi acar. Acikken **tanimsiz cihazdan** her giriste kayitli e-postaya 6 haneli kod gider; **guvenilen cihazdan** kod istenmez. Cihaz = `X-Device-Id` basliginin `ClientContexts` HMAC ozeti (ham kimlik saklanmaz). Baslik yoksa/gecersizse cihaz tanimsiz sayilir (her giriste kod).

- **Sema (V1060):** `app_user.two_factor_enabled` (varsayilan FALSE), `two_factor_enabled_at`; `two_factor_device (user_id, device_hash, label, created_at, last_used_at)`, `UNIQUE (user_id, device_hash)`, indeks/kisit onegi `tf_`. Kullanici basina en cok 10 guvenilen cihaz (en eski duser).
- **Kod:** `auth.twofactor` paketi. `TwoFactorService` + `VerificationService`'e eklenen `issueTwoFactor/verifyTwoFactor/clearTwoFactor` (Redis anahtar alani `tf:<kullaniciId>`; hash'li HMAC, 10 dk, 5 deneme, istemci kapsamli sayac, saatlik toplam yanlis siniri AYNI kalip). Fark: 60 sn yeniden-gonderme beklemesi YOK (sifre dogrulanmis kullaniciya gider; sinir challenge basina 3/10 dk). Mail: `MailTemplate.TWO_FACTOR_CODE` (`mail.tpl.twofactor.*`, tr/en/ar, HTML + duz metin); kod postasi sabitleri (eski kod temizligi, DEAD yeniden deneme, gece `vars_json` silme, `isStaleCodeMail`) bu sablonu da kapsar. `MAIL_ENABLED=false` iken kod log'a `[DEV] <adres> icin iki faktorlu giris kodu: NNNNNN` yazilir.
- **Giris (`POST /api/auth/login`):** mevcut kontroller aynen (LoginThrottle, askiya alma, `AccessGuard`). Sifre dogru + 2FA acik + cihaz guvenilir degilse token URETILMEZ: `TwoFactorRequiredException` -> controller **202** `{twoFactorRequired, challengeToken, emailHint, expiresInSeconds}`. `challengeToken` opak 256 bit, Redis `2fa:<sha256>` (kullanici + cihaz ozeti + istemci + platform/surum), 10 dk, tek kullanimlik; 5 yanlis kodda silinir. 200 `TokenResponse` bicimi degismedi. Guvenilir cihazdan giriste `last_used_at` guncellenir. Oturum iptali (mobil tek cihaz), cihaz gunlugu ve `NewLoginNotifier` bildirimi kod dogrulandiktan SONRA calisir.
- **Uclar:** `POST /api/auth/login/2fa` (herkese acik; `{challengeToken, code, trustDevice=true}` -> 200 `TokenResponse`; 400 `TWO_FACTOR_CODE_INVALID` / `TWO_FACTOR_CHALLENGE_EXPIRED`; 429), `POST /api/auth/login/2fa/resend` (202 `{expiresInSeconds}`), JWT'li ayarlar: `GET /api/auth/2fa`, `POST /api/auth/2fa/enable/request` (202; aciksa 409 `TWO_FACTOR_ALREADY_ENABLED`), `POST /api/auth/2fa/enable/confirm` (200 `{enabled:true}`; bu cihaz guvenilir olur), `POST /api/auth/2fa/disable` (`{password}`; yanlis sifre 400 `INVALID_PASSWORD`; kapaliysa 409 `TWO_FACTOR_NOT_ENABLED`), `GET /api/auth/2fa/devices`, `DELETE /api/auth/2fa/devices/{id}` (204, idempotent; oturumu kapatmaz). `SecurityConfig`: `/api/auth/2fa`, `/api/auth/2fa/**` kimlik ister.
- **Guvenilen cihazlar silinir:** sifre sifirlama, sifre degisimi, `logout-all`, 2FA kapatma (kullanici/yonetici), hesap silme (`AccountDataPurger.DELETES`).
- **Hiz sinirlari:** `tf2:ip` / `tf2:ch` (dogrulama), `tf2r:ip` + `tf2:resend` (3/10 dk), `tf:code:user` (kullanici basina saatte 10 kod postasi), `tf:enreq|enconf|disable|status|devices|devdel` (ayar uclari).
- **KVKK:** `DataExporter` bolumu `twoFactor` (durum, `enabledAt`, guvenilen cihaz ETIKETLERI; ham/ozet kimlik YOK).
- **Yonetici:** `docs/ADMIN_API.md` "Iki faktorlu dogrulama (2FA)".
- **Yeni hata kodlari (auth*.properties, tr/en/ar):** `TWO_FACTOR_REQUIRED` (yalniz yedek: controller 202 doner), `TWO_FACTOR_CODE_INVALID`, `TWO_FACTOR_CHALLENGE_EXPIRED`, `TWO_FACTOR_ALREADY_ENABLED`, `TWO_FACTOR_NOT_ENABLED`, `INVALID_PASSWORD`; `msg.twofactor.code.sent`; yonetici bildirimi `notif.twofactor.disabled.*` (useradmin*.properties).
- **Bilinen sinirlar:** guvenilen cihaz suresiz (yalniz yukaridaki olaylarda silinir; sozlesme boyle); kod 10 dk'lik tek paylasimli kod (ayni kullanici icin yeni giris eski kodu gecersiz kilar); yonetici "oturumlari kapat" (`revoke-sessions`) guvenilen cihazlari silmez.
- **OpenAPI:** 11 yeni islem (`/api/auth/login/2fa*`, `/api/auth/2fa*`, `/api/admin/two-factor/*`, `POST /api/admin/users/{id}/two-factor/disable`); `docs/openapi.json` yeniden uretilmeli (`OpenApiExportTest -Dopenapi.out=...`; commit'teki belge baska degisikliklerden de geride oldugundan bu isde elle commit edilmedi).
- Testler: `TwoFactorServiceTest`, `AuthTwoFactorFlowTest` (controller -> servis uctan uca), `AdminTwoFactorMvcTest`; duman: `scripts/smoke-two-factor.sh`.

## HARDEN turu (2026-11-01): 2FA sertlestirme

- **Davranis degisiklikleri:** (O1) 2FA acma/kapatma kullaniciya bildirim + e-posta (`SECURITY_TWO_FACTOR_NOTICE`); istege bagli `closeOtherSessions` ile tum oturumlar kapanir ve yanitta `session` yeni cift gelir. (O2) guvenilen cihaz 60 gun bosta kalinca gecersiz (`app.twofactor.device-ttl-days`, gece temizligi `DbMaintenanceJob`). (O3) yonetici kapatmasi: izin `users.2fa` (yalniz FULL/SUPPORT), kendi hesabi 403 `ADMIN_SELF_FORBIDDEN`, FULL hedef 403 `TWO_FACTOR_ADMIN_FORBIDDEN`, oturumlar kapanir, e-posta gider. (O4) challenge sifre/oturum iptal isaretine baglidir. (D1) kod challenge basina. (D2) 3 tukenen challenge = 24 sa yeni cihaz kilidi (429 `TWO_FACTOR_LOCKED`) + gunde 1 bildirim. (D3) kota doluysa 503. (D4) `trustDevice` sunucu varsayilani false. (D5) her `revokeAll` guvenilen cihazlari siler (`SessionsRevokedEvent`). (D6) `TwoFactorService` zorunlu bean, yoksa 2FA hesabi girmez. (D7) e-posta maskesi. (D8) SKIPPED kod postalari da temizlenir.
- **Migration yok.** Yeni hata kodlari/bildirim anahtarlari tr/en/ar (`auth*`, `rbac*`, `mail*`, `useradmin*`).
- Testler: `TwoFactorHardeningTest`, `TwoFactorServiceTest`, `AuthTwoFactorFlowTest`, `AdminTwoFactorMvcTest`, `DbMaintenanceJobTest`; sozlesme: `docs/TWO_FACTOR_API.md`.

## FIX-P02 (2026-11-01): oturum yenileme, erisim engeli ve bekleyen kayit duzeltmeleri

Kaynak: backend inceleme raporu 01 (A01#2,#3,#5,#6,#7,#8,#10,#12,#13,#14) ve 08 (A08#2). Kullanici kararlari baglayicidir.

- **Refresh yarisi (A01#5, K1):** ayni refresh token ile es zamanli ikinci istek artik `401 INVALID_REFRESH_TOKEN` DEGIL: sunucu en cok 2 x 150 ms bekleyip rotasyon kaydini (`rtnext`) okur, bulursa AYNI cifti doner; bulamazsa **`409 REFRESH_IN_PROGRESS` + `Retry-After: 1`** (yeni hata kodu, `auth*.properties` tr/en/ar). "Suruyor" yalniz token tolerans icinde (`app.auth.refresh-reuse-grace`, 10 sn) tuketildiyse VE rotasyon kaydi yoksa sayilir; kayit varsa ama cift artik gecerli degilse (istemci zinciri ilerletti) 401 doner, istemci sonsuz 409 dongusune girmez.
- **Kayip yanit toleransi:** `rtnext` omru 45 sn -> **5 dk**. Kayit eski token'dan turetilen AES-GCM anahtariyla sifreli oldugundan uzamasi Redis sizintisinda yeni token vermez.
- **Calinti tepkisi (K1):** tolerans disi tuketilmis token yeniden sunulursa eskiden kullanicinin TUM oturumlari (`revokeAll`) kapanirdi; artik YALNIZ o **oturum ailesi** kapanir (ayni giriste, `authTimeMs`, uretilmis zincirin canli refresh token'i + mezar tasi). `rtused:<hash>` degeri `sahip:tuketimAni:istemci:girisAni` olur. Aile bilinmiyorsa (bu surumden onceki iki alanli kayit; en cok 6 sa) guvenli tarafta `revokeAll`. Ailenin access token'lari kendi omruyle (en cok 15 dk) biter.
- **`rtused` omru (A01#6):** 6 sa -> en cok **60 dk** (`RefreshTokenService.MAX_REUSE_WINDOW`; `AuthProperties.refreshReuseWindow` varsayilani P10'da 60 dk yapilmali, o zamana kadar servis kirpar). Redis `maxmemory 200mb` baskisi azalir.
- **`revokeAll` atomik (A01#10):** `rtu:<uid>` once `RENAME ... :revoking` ile yan anahtara alinir, sonra islenir; okuma ile silme arasinda `issue()`'nun ekledigi token dizinden dusmez. (Web token ozetlerinin ZSET'e cevrilip suresi dolanlarin temizlenmesi ertelendi.)
- **Sifre sifirlama/degistirme sirasi (A01#12):** `pwchg` access-iptal isareti DB kaydindan ONCE yazilir (`SessionService.markPasswordChanged`), sonra kayit, sonra `revokeAll`. Kayit sonrasi Redis kesilse de calinmis access token'lar acik kalmaz.
- **Erisim engeli (A01#2):** oturum kapatma ban kaydi COMMIT edildikten sonra (`AfterCommit`) yapilir; Redis cagrilari artik acik DB islemini tutmaz (`idle_in_transaction_session_timeout` ile ban geri alinip oturumlar iptal edilmis kalma tutarsizligi biter). Ilk 500 kullanici istek icinde, kalani **arka planda** 500'luk parcalarla kapanir. Tavan 5.000 -> **50.000** kullanici. Yeni `warnings` degerleri (`docs/ADMIN_API.md` V280 listesine eklenmeli): `SESSIONS_CLOSING_IN_BACKGROUND` (kalan arka planda kapaniyor; `sessionsClosedUsers` toplam kapatilacak sayidir), `SESSIONS_CLOSE_CAPPED` (tavan asildi). Tek kullanicinin Redis hatasi digerlerini durdurmaz (log.warn). CIDR/toplu engelde (PostgreSQL) kullanici eslemesi veritabaninda `CAST(ip AS inet) <<= ANY(...)` ile yapilir (eskiden son 7 gunun 200.000'e kadar satiri uygulamaya cekilirdi); H2/hata durumunda eski uygulama-ici yol.
- **Engel gunluk saklamasi (A01#3):** `AccessBanRetentionJob` `ChunkedDeleter.deleteHeavy` ile parcali siler (`user_device_log`, `blocked_attempt_log`; parca basina kisa islem, 60 sn parca zaman asimi). Parca hatasi artik yutulmaz: gorev basarisiz sayilir (JobMonitor son hata + `bu_scheduler_errors`), sonraki gece kaldigi yerden devam eder. KVKK 90 gun sozu 8 sn `statement_timeout`'a takilmaz.
- **AccessBanCache (A01#7):** yenileme tek ucustur (`tryLock`); yenileme surerken digerleri eski goruntuyle devam eder. Yukleme hatasinda `nextExpiry = simdi + TTL` (eskiden gecmis deger tasinir, her istek DB'ye giderdi).
- **Bekleyen kayit (A01#8, A08#2):** `save` gecici anahtara yazip `RENAME` ile ATOMIK degistirir (eski `fa/de/gr` alanlari birlesmez). Yonetici listesi `SCAN reg:*` yerine `regidx` ZSET dizininden (sozluk sirasi, ayni imlec sozlesmesi) okur; `regidxexp` suresi dolanlari ayiklar. Dizin yoksa bir kez mevcut anahtarlardan kurulur (`regidx:ready` isareti). Yeni Redis anahtarlari: `regtmp:<e-posta>` (anlik), `regidx`, `regidxexp`, `regidx:ready`.
- **Kucuk:** `LoginThrottle.check` tek `MGET` turu (A01#13); REFRESH cihaz gunlugu ayni (kullanici, cihaz, ip) icin 30 dk'da bir yazilir (A01#14); `Thread.sleep(1)` -> `MilliTick.awaitNext()`; `verifyEmail` bekleyen kayit yokken de sahte bcrypt calistirir (zamanlama yan kanali).
- **Istemci etkisi:** mobil/web `POST /api/auth/refresh` icin `409 REFRESH_IN_PROGRESS` + `Retry-After` yeni; istemci bunu oturum sonu saymamali (bkz. `docs/MOBILE_API_GUIDE.md` 1.5). Yanit kaybi sonrasi yeniden deneme penceresi 5 dk.
- **Ertelendi:** K9 (JWT sirrinin amaclara ayrilmasi), `rtu:` ZSET donusumu (A01#10 ikinci yarisi), ban basina tek Redis pipeline (A01#2 son cumle; `SessionService.revokeAll` ic yapisi). Migration yok (V1080-1089 kullanilmadi).
- Testler: `RefreshIdempotencyTest`, `RefreshTokenServiceTest`, `AuthServiceTest`, `PendingRegistrationStoreTest` (yeni), `LoginThrottleTest`, `DeviceLogCapTest`, `AccessBanServiceTest`, `AccessBanCacheOutageTest` (yeni).

## QT-BE (2026-11-05): kota asiminda ERTELENMIS e-posta dogrulama (kisitli mod)

Kullanici karari: gunluk kod e-postasi kotasi (saglayici ~300/gun) dolu iken kayit olan kisi 503 ile geri cevrilmez; **iceri alinir ama e-postasi DOGRULANMAMIS ve YALNIZ OKUR** kalir. Profil sayfasinda "E-postanizi dogrulayin" gosterilir; dogrulama kota bosalinca tamamlanir. Sozlesme (mobil bunu temel alir):

### Ne zaman devreye girer
- Yalniz `POST /api/auth/register` ve yalniz **kayit dogrulama kodu** icin: `VerificationService.requireMailQuota()` **503 `MAIL_QUOTA_EXHAUSTED`** firlatacaksa (saglayici kotasi doldu ya da kimliksiz kayit butcesi doldu). Sifre sifirlama (`forgot-password`), 2FA ve anonim `resend-code` davranisi **DEGISMEZ** (kota doluysa eskisi gibi 503). IP basina gunluk kod sayaci (429 `RATE_LIMITED`) ertelemeyi tetiklemez.
- Kota **dolu degilken** akis AYNEN: `202 {"message":...}` + e-posta kodu + Redis bekleyen kayit.
- ADMIN_EMAILS adresleri ve yonetici portali kaydi (`adminPortal=true`) **ertelenmez** (kimlik taklidi ile yonetici terfisi riski): kota doluysa eskisi gibi 503.
- Ayar: `app.auth.deferred-verification.enabled` (varsayilan `true`; `false` = eski davranis, 503).
- Tum kayit kurallari AYNEN: `bingol.edu.tr` alan adi, `+etiket` yasagi, parola politikasi, katalog, uygunsuz ad, ihlal defteri, `acceptTerms=true` (sozlesme onayi `legal_acceptance`'a yazilir), IP/e-posta hiz sinirlari.

### `POST /api/auth/register` (ertelenmis yanit)
Istek gövdesine **opsiyonel** `client` (`mobile|web`, varsayilan web) eklendi (jeton etiketi; `verify-email` ile ayni). Yanit **201 Created** (normal akis 202):
```json
{
  "message": "Hesabiniz olusturuldu. Dogrulama kodu su an gonderilemiyor; e-postanizi daha sonra dogrulayin.",
  "emailVerified": false,
  "verificationDeferred": true,
  "accessToken": "eyJ...", "refreshToken": "...", "expiresInSeconds": 900, "tokenType": "Bearer"
}
```
Normal 202 govdesi degismedi (`{"message":...}`; yeni alanlar yok). Istemci **HTTP durumuna degil `verificationDeferred===true` alanina** bakar. Ayni e-posta zaten dogrulanmissa `409 EMAIL_ALREADY_REGISTERED` (degismedi). Ayni e-posta icin dogrulanmamis satir varsa (onceki ertelenmis kayit) satir **yeniden kullanilir**: parola/ad ezilir ("son yazan kazanir", bekleyen kayitla ayni kural), eski oturumlari kapanir, yeni jetonlar verilir.

### Giris (`POST /api/auth/login`)
Ertelenmis hesap (`verification_deferred=true`, `email_verified=false`) dogru parolayla **girebilir**: `200` + `TokenResponse` ve ek alanlar `"emailVerified":false,"verificationDeferred":true` (alanlar yalniz ertelenmis hesapta vardir; normal giriste yoktur, geriye uyumlu). Diger dogrulanmamis hesap turleri (Redis bekleyen kayit, eski satirlar) **degismedi**: `403 EMAIL_NOT_VERIFIED`. `POST /api/auth/refresh` ertelenmis hesap icin de calisir (ayni ek alanlar). ADMIN_EMAILS terfisi dogrulanmamis hesapta **uygulanmaz** (`promoteIfAdmin` e-posta dogrulanana kadar atlanir).

### `GET /api/users/me` (profil)
`ProfileView` yanitina **her zaman** iki boolean eklendi: `emailVerified`, `verificationDeferred`. Mobil profil sayfasi `emailVerified==false && verificationDeferred==true` ise "E-postanizi dogrulayin" kartini gosterir. `GET /api/auth/me` (UserView) degismedi.

### Kisitli (yalniz okuma) mod
`legal.LegalReacceptFilter` kalibinda yeni `auth.UnverifiedWriteFilter`: kimligi dogrulanmis kullanici `verification_deferred AND NOT email_verified` ise `/api/**` altindaki **yazma** istekleri (POST/PUT/PATCH/DELETE) **403**:
```json
{"code":"EMAIL_VERIFICATION_REQUIRED","message":"Bu islem icin once e-posta adresinizi dogrulayin."}
```
(`message` istek dilinde tr/en/ar; `Cache-Control: no-store`.) Okuma (GET/HEAD/OPTIONS) serbesttir. Yazma **IZNI olanlar**: `/api/auth/**` (login/refresh/logout/logout-all/change-password ve yeni `verification/*`; **hariç** `/api/auth/2fa/**`), profil duzenleme `PATCH /api/users/me`, avatar `POST|DELETE /api/users/me/avatar`, hesap silme `DELETE /api/users/me`, `/api/legal/**` (sozlesme onayi), `/api/devices/**` (push token), `/api/analytics/**`, `/api/app/**`, `/api/support/**` (destek talebi), `/api/reports` (sikayet), `/api/notifications/**` (kendi bildirim durumu/tercihleri), `/api/public/**`. **Diger her yazma 403**: gonderi/begeni/takip, mesaj gonderme ve sohbet baslatma, kulup/etkinlik olusturma-katilma, basvuru, RSVP, anket oyu, medya yukleme, geri bildirim panosu vb. Gerekce: dogrulanmamis hesap baskasinin `@bingol.edu.tr` adresiyle girmis olabilir (kimlik taklidi); dogrulanana kadar topluluga yazamaz.
- Gorunmezlik: dogrulanmamis hesaplar kullanici aramasinda, onerilerde, Kesfet/takip listelerinde, bildirim/e-posta kitlelerinde ve baskasinin `GET /api/users/{id}` profilinde (404 `USER_NOT_FOUND`) **gorunmez** (mevcut `email_verified` suzgeci + profil kontrolu).
- Durum onbellegi: dogrulanmis sonucu bellekte tutulur; ertelenmis hesap her yazmada yeniden sorgulanir; dogrulama aninda aninda kalkar (ayni ornekte).

### Dogrulamayi tamamlama (kimlik dogrulamali; anonim `verify-email`/`resend-code` ayri ve aynen calisir)
Yeni uclar `SecurityConfig`'te `authenticated`; hepsi hiz sinirli.

| Yontem + yol | Govde | Basari | Hatalar |
|---|---|---|---|
| `GET /api/auth/verification/status` | - | `200 {"emailVerified":false,"verificationDeferred":true,"email":"a@bingol.edu.tr"}` | 401 |
| `POST /api/auth/verification/resend` | - | `202 {"message":"..."}` (kod 6 hane, 10 dk, e-postaya) | `429 RESEND_COOLDOWN` (180 sn, `Retry-After`), **`429 MAIL_QUOTA_EXCEEDED`** (gunluk kota dolu; `Retry-After` = kota sifirlanmasina kalan saniye; metin "yarin tekrar deneyin"), `409 EMAIL_ALREADY_VERIFIED`, `429 RATE_LIMITED` |
| `POST /api/auth/verification/verify` | `{"code":"482913"}` | `200 {"emailVerified":true,"verificationDeferred":false}` (idempotent: zaten dogrulanmissa da 200) | `400 INVALID_CODE`, `429 TOO_MANY_ATTEMPTS` (5 yanlis deneme: adres 10 dk kilit) |

- `verify` basarisinda `email_verified=true`, `verification_deferred=false`: kisitlar kalkar; **yeni jeton gerekmez** (rol/`ap` talepleri etkilenmez, mevcut oturum surer). ADMIN_EMAILS terfisi sonraki giriste yapilir (kayit-giris akisi degismedi).
- Kod ayni Redis `vc:<email>` alanini kullanir (hash'li HMAC, 10 dk, 5 deneme, saatlik toplam yanlis siniri); `resend` kota korumasini (gunluk kota/butce) **uygular**.
- Hiz sinirlari: `vresend:user:<id>` saatte 5 / gunde 10; `vverify:user:<id>` 10 dk'da 10; `vstatus:user:<id>` dakikada 30.

### Otomatik tamamlama isi (`DeferredVerificationJob`)
- `@Scheduled` (`app.auth.deferred-verification.poll-ms`, varsayilan 3 600 000 = saatlik; `SchedulerLock` `deferred-verification`). Kota bosalinca ertelenmis hesaplara, **en eski kayit once**, dogrulama kodunu e-posta kuyruguna ekler (`VerificationService.issue` -> `MailService`, hesap dilinde).
- **Kayit dogrulama postalari oncelikli kalir:** is yalniz kayit butcesinin **kalan** payinin `app.auth.deferred-verification.max-share-of-remaining` (0.5) kadarini kullanir (`kalan = publicCap(REGISTRATION) - publicUsed`); saglayici kotasi tamamen doluysa hic gonderilmez. Tek calismada en cok `max-per-run` (200).
- Kullanici basina **en cok kota gunu basina 1** posta (`app_user.verification_mailed_at`); el ile `resend` ayri sinirdir.
- Saklama: `app.auth.deferred-verification.retention-days=14`. Gece 03:20 (`Europe/Istanbul`) 14 gunden eski, hala dogrulanmamis ertelenmis hesaplar **hesap silme (anonimlestirme) yolundan** (`ProfileService.anonymizeAccount` -> `AccountDataPurger` kapsami; KVKK) temizlenir; e-posta adresi serbest kalir.

### Sema (V1260)
`app_user.verification_deferred BOOLEAN NOT NULL DEFAULT FALSE`, `app_user.verification_mailed_at TIMESTAMPTZ NULL`, kismi indeks `qd_app_user_deferred_idx (created_at) WHERE verification_deferred AND NOT email_verified`.

### Yonetici
`GET /api/admin/users` satirlarina ve detaya `verificationDeferred` (boolean) eklendi; "dogrulanmamis" suzgeci (`verified=false`) ertelenmis hesaplari dondurur. Yonetici elle dogrulama (`POST /api/admin/users/{id}/verify`) ertelenmis isareti de kaldirir. Redis "bekleyen kayitlar" listesi (`/api/admin/pending-registrations`) degismedi (ertelenmisler Redis'te degil, kullanici satirindadir).

### Yeni hata kodlari / metinler (tr/en/ar, auth*.properties)
`EMAIL_VERIFICATION_REQUIRED` (403), `MAIL_QUOTA_EXCEEDED` (429), `EMAIL_ALREADY_VERIFIED` (409); `msg.register.deferred`, `msg.verification.sent`.
