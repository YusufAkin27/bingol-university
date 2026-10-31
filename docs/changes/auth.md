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

### Parola politikasi (T-005, K-09 varsayilani)
- `auth/PasswordPolicy`: en az **10** karakter (yonetici hesaplari **12**; `app.auth.password-min-length`, `app.auth.password-min-length-admin`), `auth/common-passwords.txt` (yaygin parola + kok kelime listesi; sondaki rakam/yil/sembol atilarak kok kelimeye de bakilir: `Galatasaray1905`, `Sifre1234567`), tek karakter tekrari / rakam dizisi / klavye yurumesi, e-posta kullanici adi + okul numarasi + gorunen ad sozcukleri (>= 4 harf, Turkce karakter katlanir). Karakter sinifi zorunlulugu YOK.
- Uygulandigi uclar: `POST /api/auth/register`, `POST /api/auth/reset-password`, `POST /api/auth/change-password`. Hata: `400 PASSWORD_TOO_WEAK` (tr/en/ar, `{0}` = en az uzunluk). `giris` politikaya BAGLI DEGIL (eski parolalar girebilir). DTO'lardaki `@Size(min = 8)` kaldirildi (kisa parola da `PASSWORD_TOO_WEAK` olur); `max = 72` ve 72 BAYT siniri (`PASSWORD_TOO_LONG`) aynen.
- Yaygin parola listesi (~27 bin satir) elle derlenmis kok kelime + ek kaliplarindan URETILDI (dis kaynak/rockyou kullanilmadi); ilk 10k hedefi asildi ama gercek sizinti listesi degildir. Gerekirse `backend/src/main/resources/auth/common-passwords.txt` ek satirlarla buyutulebilir (kucuk harf, aksansiz).
- **ETKI (smoke/e2e):** `Sifre1234` gibi 9 karakterlik test parolalari artik reddedilir. Yeni betik parolasi: `Zk7-Qmv-Lpx92w` (14 karakter, listede degil). Diger betikler tasinana kadar `APP_AUTH_PASSWORD_MIN_LENGTH`/yaygin liste engeline takilirlar (bkz. W1-A teslim raporu).
- `reset-password`: yeni parola mevcutla ayni olamaz (`422 PASSWORD_UNCHANGED`); zayif/ayni parola reddi sifirlama anahtarini TUKETMEZ (`VerificationService.checkResetToken`); basarili sifirlamada "sifren degisti" guvenlik e-postasi gider.

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
