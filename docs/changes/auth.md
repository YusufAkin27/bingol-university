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


## Tek cihaz (tek oturum) kurali - mobil (ESKI: yalniz `app.auth.single-mobile-session=true`; varsayilan coklu oturum, asagida "Coklu oturum + Cihazlarim")

- **Kapsam**: yalniz `client=mobile` girisleri. `POST /auth/login` (ve `verify-email`) govdesine opsiyonel `client` (`mobile|web`, varsayilan `web`, gecersiz = 400). Mobil giris, kullanicinin onceki MOBIL oturumlarini kapatir; web oturumlari birbirini ve mobili kapatmaz. Sifre sifirlama ve `logout-all` TUM istemcileri kapatmaya devam eder (`SessionService.revokeAll`).
- **Sira**: `AuthService.login` -> `SessionService.revokeClient(uid,"mobile",true)` (refresh'ler silinir, `pwchgm:<uid>` yazilir, 1 ms beklenir, `SessionsRevokedEvent` yayinlanir) -> yeni token'lar. Yeni access token'in `iatms` degeri isaretten kesin buyuktur, bu yuzden hemen kabul edilir.
- **Token'lar**: access JWT'ye `cl` (`mobile|web`; talepsiz eski token = web). Refresh kaydi `rt:<hash>` = `uid:client` (eski `uid` degeri web sayilir). `JwtAuthFilter`: `pwchg` tum token'lara, `pwchgm` yalniz `cl=mobile` token'lara uygulanir.
- **401 SESSION_REPLACED**: iptal yuzunden reddedilen (imzali, suresi dolmamis) access token'da filtre istek ozniteligi `auth.sessionReplaced` koyar; `ApiAuthenticationEntryPoint` `{"code":"SESSION_REPLACED","message":...}` yazar. `POST /auth/refresh`: iptal edilmis refresh token'in mezar tasi (`rtx:<sha256>` = uid, TTL refresh omru) varsa 401 `SESSION_REPLACED`; bilinmeyen/suresi dolmus/normal cikis yapilmis = `INVALID_REFRESH_TOKEN`.
- **WebSocket**: `TokenExpiryGuard` olayi dinler; etkilenen oturumlar olay aninda sabitlenir (sonradan baglanan yeni cihaz kapanmaz), her birine yalniz o oturuma `/user/queue/message-events` `{"type":"session-replaced","at":...}` gider, `app.session.close-delay-ms` (varsayilan 400) sonra close(1008, `SESSION_REPLACED`). `StompAuthInterceptor`: CONNECT'te iptal edilmis token `ERROR SESSION_REPLACED`; oturum niteligi `wsClient`.
- **Push/e-posta**: `notification.SessionDeviceCleaner` mobil yeni giriste kullanicinin tum `device` kayitlarini siler (sessiz veri bildirimi eklenmedi). `auth.NewLoginNotifier` eski mobil oturum varsa mevcut `SECURITY_NEW_LOGIN` sablonuyla (tr/en/ar, kuyruk) guvenlik e-postasi gonderir; hata girisi bozmaz.
- **Yeni anahtarlar**: Redis `pwchgm:<uid>` (ms, access omru + 1 dk), `rtx:<hash>`; i18n `error.SESSION_REPLACED` (`auth.properties`, `_en`, `_ar`); ayar `app.session.close-delay-ms`.
- **Bilinen sinirlar**: iptal sirasinda eszamanli calisan bir refresh istegi yeni token alabilir (dar yaris, en gec bir sonraki girisle kapanir); WS olayi/close yalniz o sunucudaki baglantilara gider (coklu ornekte Spring olayi yereldir, access token zaten 401 olur). Dogrulama: `scripts/smoke-single-session.sh`.

## Coklu oturum + Cihazlarim (MULTISESSION, 2026-11-06, V1460)

Kullanici karari: tek cihaz kurali KALKTI. Varsayilan artik **coklu oturum**: bir kullanici ayni anda istedigi kadar cihazdan (mobil/web) giris yapabilir, girisler birbirini kapatmaz. Eski davranis `app.auth.single-mobile-session=true` (`AUTH_SINGLE_MOBILE_SESSION=true`) ile geri gelir; ustteki "Tek cihaz" bolumu yalniz bu bayrak acikken gecerlidir.

- **Oturum kimligi (sid):** her gercek giris (login, 2FA ikinci adim, verify-email, ertelenmis kayit, sifre degisimi/2FA sonrasi yeniden duzenleme) `user_session` tablosunda bir satir ve 32 karakterlik rastgele hex `sid` uretir. `sid` access JWT'de `sid` talebi, refresh kaydinda 4. alan (`rt:<hash>` = `uid:client:authTimeMs:sid`; sid'siz eski kayitlar 3 alanli okunur) olarak tasinir ve refresh rotasyonunda KORUNUR. Cok oturum oncesi acilmis zincirler ilk refresh'te DEVRALINIR (yeni sid, kayit olusur; bildirim uretmez).
- **Tablo `user_session`:** `sid` (PK), `user_id` (FK CASCADE), `client`, `platform`, `device_name` (<=80), `device_hash` (X-Device-Id HMAC ozeti), `app_version`, `ip_masked` (IPv4 `a.b.*.*`, IPv6 ilk iki grup + `:*`; ham IP ve konum YOK), `auth_time_ms`, `created_at`, `last_used_at` (her refresh'te), `revoked_at`. Indeksler `usess_*`. Saklama: son kullanimdan `app.dbmaint.session-days` (100) gun sonra `DbMaintenanceJob` (`user_session`, parcali) siler; hesap silinince `AccountDataPurger` + FK; KVKK disa aktarim bolumu `sessions`.
- **Cihaz adi:** istemci `X-Device-Name` basligi (temizlenir, <=80); yoksa User-Agent'tan ("Chrome / Windows", "Android"); yoksa `X-Device-Platform`'dan ("Android"/"iPhone"/"Web"). `ClientContext.deviceName` (`accessban/DeviceNames`).
- **Acik oturum:** `revoked_at` bos, `last_used_at` refresh omru (`jwt.refresh-ttl-days`, 30) icinde, `created_at` mutlak omur (`app.auth.session-max-days`, 90) icinde. En cok 50 satir listelenir.
- **Yeni uclar (kimlik gerekir, `SecurityConfig` authenticated):**
  - `GET /api/auth/sessions` -> `[{id, client, platform, deviceName, appVersion, ipMasked, createdAt, lastUsedAt, current}]`; istegi yapan oturum (`current:true`) basta, gerisi son kullanima gore. Limit: kullanici basina dakikada 60.
  - `DELETE /api/auth/sessions/{sid}` -> 204. Siralama: Redis `sessrev:<sid>` (TTL access omru + 1 dk; o sid'li access token'lar aninda 401 `SESSION_REPLACED`), refresh token silme + mezar tasi (`rtx:`; refresh 401 `SESSION_REPLACED`), `user_session.revoked_at`, `SessionRevokedEvent` (o sid'li WebSocket baglantilari `session-replaced` + close; o oturumdan kaydolmus FCM cihazi silinir). Baskasinin/olmayan/gecersiz sid: 404 `SESSION_NOT_FOUND` (varlik sizmaz). Kendi oturumu da silinebilir. Limit: 15 dkda 20.
  - `POST /api/auth/logout-all` aynen (tum oturumlar + tum FCM kayitlari + guvenilen 2FA cihazlari). `POST /api/auth/logout` artik yalniz o cihazin access token'ini da hemen gecersiz kilar ve `user_session` kaydini kapatir.
- **Yeni cihaz girisi uyarisi (`auth.session.NewDeviceNotifier`):** yeni sid acilinca kullanicinin BASKA acik oturumu varsa (ve cihaz ozeti daha once baska bir oturumda gorulmediyse; ayni cihaz icin 10 dk icinde ikinci uyari yok: Redis `newdev:<uid>:<cihaz>`) uygulama ici bildirim + push gider: `NotificationType.SYSTEM` (tercihlerden ve sessiz saatten bagimsiz), anahtar `notif.session.newdevice.title|body` (tr/en/ar; `{0}` cihaz adi, `{1}` zaman), veri `target=SECURITY`, `value=devices`, `securityKind=NEW_DEVICE`, `sessionId`. Mevcut `SECURITY_NEW_LOGIN` e-postasi da gider (tek mobil oturum bayragi aciksa e-postayi eski `NewLoginNotifier` gonderir, ikiye katlanmaz). Yenileme/devralma/sifre degisimi sonrasi yeniden duzenleme bildirim uretmez.
- **Push (cok oturum):** `device` kayitlari kullanici basina cok (FCM token benzersiz, kullanici basina en cok 10); `NotificationService` kullanicinin TUM kayitlarina gonderir. `device.session_id` kaydi yapan oturumu tutar (`POST /api/devices` access JWT'deki sid'i yazar). `SessionDeviceCleaner` yeni girisde FCM kayitlarini ARTIK SILMEZ (yalniz tek mobil oturum bayragi aciksa); logout-all/sifre/askiya alma/erisim engelinde tum kayitlar, tek cihazdan cikista yalniz o oturumun kaydi silinir.
- **Yeni ayarlar:** `app.auth.single-mobile-session` (`AUTH_SINGLE_MOBILE_SESSION`, false), `app.dbmaint.session-days` (`DBMAINT_SESSION_DAYS`, 100). **Yeni i18n:** `notif.session.newdevice.title|body` (`auth*.properties`); 404 kodu `SESSION_NOT_FOUND` yönetici oturum ucuyla ortaktır, çevirisi `useradmin*.properties`'te durur. Yönetici oturum listesi/kapatma (`AdminUserSessionService`) sid'li refresh değerini tanır; tek oturum kapatınca access token de anında kesilir.
- **Bilinen sinirlar:** `last_used_at` access token degil refresh ile ilerler (kaba, ~15 dk); cikis isteginin hic ulasmadigi cihaz refresh omru (30 gun) dolana dek listede kalir (kullanici silebilir); `sessrev:` isareti yalniz access omru kadar yasar, sonrasinda refresh zaten silinmistir; eski (sid'siz) access token'lar yenilenene dek `current` isaretlenmez; WS kapatma yalniz o sunucudaki baglantilara gider. Dogrulama: `scripts/smoke-multi-session.sh` (eski kural: `smoke-single-session.sh`, `AUTH_SINGLE_MOBILE_SESSION=true` ister).

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

## Google / Apple ile giris + profil tamamlama (OAUTH, V1450)

Ozellik bayragi **`app.auth.oauth.enabled`** (env `AUTH_OAUTH_ENABLED`, **varsayilan false**): kapaliyken asagidaki TUM uclar `404 OAUTH_DISABLED` (yapilandirma gelmeden guvenle dagitilir). Yapilandirma: `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_IDS` (virgullu `aud` beyaz listeleri); bayrak acikken ikisi de bossa `ProdSettingsValidator` uygulamayi **baslatmaz** (yalniz biri bossa uyari; o saglayici tum token'lari reddeder). Dis kurulum adimlari: [../OAUTH_SETUP.md](../OAUTH_SETUP.md). Mobil sozlesme: [../MOBILE_API_GUIDE.md](../MOBILE_API_GUIDE.md) bolum 1.10.

### Kurallar (ozet)
- **Eslesme anahtari `provider + subject`** (`auth_identity`); e-posta tek basina hesap kaniti DEGILDIR. Kimlik tanimiyor ama ayni e-posta mevcut bir hesapta varsa **otomatik birlestirme YOK**: `409 OAUTH_LINK_REQUIRED {code,message,provider,emailMasked}`; kullanici once e-posta+sifreyle girer, `POST /api/auth/oauth/link` ile **sifresini yeniden dogrulayarak** baglar.
- Yeni kullanici: hesap acilir (`email_verified=true`: saglayici dogruladi; yonetici terfisi YOK), **parola yok** (`password_hash = "!oauth:<uuid>"`: bcrypt degil, hicbir parolayla eslesmez; parola ile giris `INVALID_CREDENTIALS`; `forgot-password` -> `verify-reset-code` -> `reset-password` ile sonradan parola belirlenebilir, akis bozulmaz), `profile_completed_at = NULL`, ad/soyad saglayicidan **on doldurulur** (Google `given_name/family_name`, Apple istemcinin ilk yetkilendirmede aldigi `firstName/lastName`; kurallardan gecmezse gecici ad). Sozlesme onayi hesap acilirken YAZILMAZ, onboarding'de alinir.
- **Sunucu tarafi kapi** (`ProfileIncompleteWriteFilter`, `UnverifiedWriteFilter` kalibi): `profile_completed_at IS NULL` iken `/api/**` altindaki tum YAZMA istekleri (POST/PUT/PATCH/DELETE) `403 PROFILE_INCOMPLETE`. Serbest: `PUT /api/users/me/onboarding`, avatar (`POST|DELETE /api/users/me/avatar`), hesap silme (`DELETE /api/users/me`), `/api/auth/**` (cikis, baglama, refresh...), `/api/legal/**`, `/api/devices/**`, `/api/analytics/**`, `/api/app/**`, `/api/support/**`, `/api/public/**` ve tum GET/HEAD/OPTIONS. **STOMP `SEND`** da reddedilir (`ERROR` cercevesi `PROFILE_INCOMPLETE`, `StompAuthInterceptor`). Tamamlanmamis hesap baskalarina gorunmez (`GET /api/users/{id}` 404, kullanici aramasi). Tamamlandi sonucu 1 saat bellekte tutulur, tamamlanmamis sonuc onbelleklenmez (onboarding biter bitmez kapi acilir). Acil kapatma: `AUTH_PROFILE_GATE_ENABLED=false`.
- **Mevcut kullanicilar kilitlenmez:** migration `profile_completed_at = created_at` atar; kolon DB varsayilani `now()`, `new User()` varsayilani "tamamlanmis"; yalniz OAuth hesap acma bilincli NULL yazar (ham `INSERT` yapan betikler/tohum verisi etkilenmez). **Parola ile kaydolanlar** mevcut akista (kayit -> dogrulama -> profil guncelleme) **tamamlanmis acilir** (eski mobil surumler bozulmaz); `AUTH_PASSWORD_SIGNUPS_NEED_ONBOARDING=true` ile yeni parola kayitlari da onboarding'den gecirilebilir (mobil onboarding'i parola kaydi icin de yayinlayinca acin; mevcut satirlar/ertelenmis dogrulama hesaplari etkilenmez).
- **2FA:** hesabin 2FA'si aciksa OAuth girisi de `202 {challenge}` akisina girer (`TwoFactorRequiredException`, token YOK); ikinci adim mevcut `POST /api/auth/login/2fa` (yanit `TokenResponse`; `profileCompleted` icin `GET /api/users/me`). Yeni hesapta 2FA kapalidir.
- **Tek cihaz kurali:** OAuth girisi `client` (varsayilan **mobile**; `web` secilebilir) ile mevcut kurala tabidir (yeni mobil giriste eski mobil oturumlar duser).
- **Yonetici terfisi:** OAuth girisi/hesap acma `ADMIN_EMAILS` terfisi YAPMAZ (yalniz e-posta kodu/parola yolu).

### Uclar
| Yontem + yol | Govde | Basari | Hatalar |
|---|---|---|---|
| `POST /api/auth/oauth/google` | `{idToken, deviceName?, client?}` | `200 {accessToken, refreshToken, expiresInSeconds, tokenType, profileCompleted, isNewUser}`; 2FA'li hesapta `202` challenge | `400 OAUTH_TOKEN_INVALID` (imza/aud/iss/exp/alg), `400 OAUTH_EMAIL_MISSING`, `403 OAUTH_EMAIL_UNVERIFIED`, `409 OAUTH_LINK_REQUIRED`, `404 OAUTH_DISABLED`, `403 ACCOUNT_SUSPENDED`, `429` |
| `POST /api/auth/oauth/apple` | `{identityToken, nonce, firstName?, lastName?, deviceName?, client?}` (`nonce` HAM; Apple'a `SHA-256(ham)` hex verilir, token'daki `nonce` talebi buna esit olmali) | ayni | ayni (+ nonce uyusmazligi `OAUTH_TOKEN_INVALID`) |
| `POST /api/auth/oauth/link` (KIMLIKLI) | `{provider:"GOOGLE"\|"APPLE", token, nonce?, password, reauthProvider?, reauthToken?, reauthNonce?}` | `200 {linked:true}` (ayni baglama tekrari idempotent) | `403 WRONG_PASSWORD`, `403 OAUTH_REAUTH_REQUIRED`, `409 OAUTH_IDENTITY_TAKEN` (sub baska hesapta), `409 OAUTH_PROVIDER_ALREADY_LINKED`, `400 OAUTH_TOKEN_INVALID` |
| `DELETE /api/auth/oauth/link/{provider}` (KIMLIKLI) | - | `200 {linked:false}` | `409 OAUTH_LAST_LOGIN_METHOD` (parolasi olmayan hesapta tek kimlik), `404 OAUTH_IDENTITY_NOT_FOUND` |
| `GET /api/auth/oauth/identities` (KIMLIKLI) | - | `200 [{provider,email,emailPrivate,linkedAt}]` | `404 OAUTH_DISABLED` |
| `GET /api/users/username-available?u=` (KIMLIKLI) | - | `200 {available:boolean, reason?:"TAKEN"\|"INVALID"\|"RESERVED"}` (kendi adin = musait) | `429` (dakikada 30) |
| `PUT /api/users/me/onboarding` (KIMLIKLI) | asagida | `200 {profileCompleted:true, user:ProfileView}` | `409 USERNAME_TAKEN {field:"username"}`, `422 USERNAME_INVALID/USERNAME_RESERVED/ACADEMIC_INVALID/PROFILE_FIELD_REQUIRED/CONTENT_PROFANITY`, `400 TERMS_REQUIRED` |
| `PUT /api/users/me/username` (KIMLIKLI) | `{username}` | `200 ProfileView` (eski hesaplara istege bagli atama; ilk atama serbest, degisim 30 gunde bir) | `409 USERNAME_TAKEN`, `429 USERNAME_COOLDOWN`, `422` |
| `GET /api/users/me` | - | yanita `profileCompleted`, `username`, `firstName`, `lastName`, `universityName`, `authProviders[]` (`["GOOGLE","APPLE"]`; parola girisi her zaman ayri) eklendi (eski istemci yok sayar) | - |

- Baglama yeniden dogrulamasi: **parolasi olan** hesapta `password`; **parolasiz (yalniz OAuth)** hesapta zaten bagli bir saglayicinin TAZE token'i (`reauthProvider/reauthToken/reauthNonce`, `sub` kendi kimligiyle eslesmeli). Hesap silme de ayni mantiktadir: `DELETE /api/users/me` govdesi `{password}` ya da (parolasiz hesap) `{provider, token, nonce?}` (`password` artik zorunlu degil; parolali hesap yine parola ister, bos parola `403 WRONG_PASSWORD`).
- Apple: gizli e-posta (`@privaterelay.appleid.com`) KABUL (`email_is_private`); e-posta hic gelmezse (Apple sonraki girislerde vermez) saglayici kimligiyle eslesen hesap kullanilir, yeni kullanicida e-posta yoksa `400 OAUTH_EMAIL_MISSING`. Apple adi yalniz ilk yetkilendirmede gelir: istemci `firstName/lastName` gonderirse yeni hesapta saklanir.
- Hiz sinirlari: giris `oauth:ip:<ip>` (`app.rate-limit.login-ip-max`/15 dk) + `oauth:dev:<cihaz>` 60/15 dk; baglama `oauthlink:user` 10/sa; kaldirma 10/sa; liste 30/dk; musaitlik 30/dk + 600/gun; onboarding 20/sa; kullanici adi atama 10/sa.

### Onboarding govdesi (`PUT /api/users/me/onboarding`): alanlar KULLANICI BEYANIDIR ("dogrulanmis ogrenci" degildir)
`{firstName, lastName, username, universityName?, facultyId|facultyName, departmentId|departmentName, classYear, bio?, acceptTerms?}`
- `username`: 3-24 karakter, `[a-z0-9._]`, harfle baslar, ardisik nokta/alt cizgi ve nokta/alt cizgiyle bitis yok, buyuk-kucuk harf duyarsiz (kucuk harfe cevrilip saklanir; benzersiz indeks `au1450_app_user_username_uq`), ayrilmis kelimeler (admin, destek, bukampus, support, moderator ... ve `admin*`/`bukampus*` oneki; nokta/alt cizgi hileleri iskelet uzerinden), `ContentGuard` (`422 CONTENT_PROFANITY`). **Eszamanli iki istek ayni adi alirsa benzersiz indeks ikincisini reddeder: `409 USERNAME_TAKEN`** (test: `OnboardingServiceTest.concurrentOnboardingForTheSameUsernameLetsExactlyOneWin`).
- `firstName`/`lastName`: bosluk sadelestirilir, her biri <= 60; `displayName = "ad soyad"` olarak `DisplayNamePolicy` kurallarindan gecer (ayrilmis/taklit ad reddedilir). `bio` <= 300 kod noktasi.
- `universityName`: bos = **Bingol Universitesi**. Bingol ise fakulte/bolum **katalogla** (`GET /api/catalog/academic`: kimlik veya TR/EN/AR ad) dogrulanir, gecersiz = `422 ACADEMIC_INVALID`; **baska universite** secilirse fakulte/bolum serbest metin (Bingol katalogu anlamsiz).
- Fakulte/bolum `classYear=OTHER` disinda zorunlu (`422 PROFILE_FIELD_REQUIRED {field}`).
- `classYear`: `PREP` (Hazirlik), `Y1`..`Y6`, `POSTGRAD` (Lisansustu = `MASTER`), `MASTER`, `PHD`, `OTHER` (sinif bilgisi yok). Mevcut `grade`/`class_year` modeline eslenir (`Y3` -> `grade="3"`, `class_year=3`; `PREP` -> `grade="PREP"`, `class_year=0`; `POSTGRAD` -> `grade="MASTER"`; `OTHER` -> ikisi de null). **Bolume gore sinif suzmesi bu surumde yok** (katalogda bolum suresi verisi yok; istemci isterse kendi listesini daraltir).
- `acceptTerms`: `true` ise `LegalService.recordSignupConsent` ile kayit sozlesmeleri (`legal_acceptance`) yazilir. Gonderilmezse bekleyen sozlesme onayi `POST /api/legal/accept` ile onceden verilmis olmali, yoksa `400 TERMS_REQUIRED`. Kapatma: `AUTH_OAUTH_REQUIRE_TERMS=false` (onerilmez: guvenlik kurali 2).
- **Idempotent:** yalniz `profile_completed_at IS NULL` iken tam yazma yapar; tamamlanmis hesapta ayni/farkli govde ile tekrar cagri mevcut veriyi EZMEZ ve `200 {profileCompleted:true,user}` doner. Hata alan istek hicbir sey yazmaz. Tamamlandiktan sonraki degisiklikler `PATCH /api/users/me` ve `PUT /api/users/me/username` ile.
- Avatar: mevcut `POST /api/users/me/avatar` (onboarding sirasinda serbest).

### Sema (V1450)
`app_user` + `first_name`, `last_name`, `username VARCHAR(24)` (+ `CHECK` + benzersiz indeks `au1450_app_user_username_uq`; NULL'lar serbest), `username_set_at`, `university_name`, `profile_completed_at TIMESTAMPTZ DEFAULT now()` (+ `UPDATE ... = created_at`); yeni `auth_identity(id, user_id, provider, subject, email, email_is_private, created_at, last_login_at)` + benzersiz `(provider, subject)` ve `(user_id, provider)` (`au1450_auth_identity_*`). Yalniz ekleme; mevcut kullanicilar tamamlanmis, kullanici adi bos.

### Guvenlik (token dogrulama, `OAuthTokenVerifier`)
Yalniz **RS256** (`none`/HS* reddedilir; algoritma karistirma korumasi), anahtar `kid` ile JWKS'ten (Google `https://www.googleapis.com/oauth2/v3/certs`, Apple `https://appleid.apple.com/auth/keys`: SABIT adresler, istemci girdisi URL'e girmez, yonlendirme yok, 3 sn zaman asimi, 64 KB sinir, **1 saat onbellek**, bilinmeyen `kid` icin en cok 30 sn'de bir TEK yenileme, ulasilamazsa eldeki anahtarlar kullanilir / hic yoksa fail-closed), `iss` (Google `accounts.google.com` ya da `https://accounts.google.com`; Apple `https://appleid.apple.com`), `aud` beyaz liste (bos liste = hicbir token gecmez), `exp` ve `iat` (60 sn saat sapmasi toleransi), Google `email_verified=true` zorunlu (`403 OAUTH_EMAIL_UNVERIFIED`), Apple `nonce`. E-posta kucuk harfe normallestirilir. Token'lar ve alt dizeleri LOG'A YAZILMAZ (yalniz `OAuth token reddedildi: <neden kodu>`). Hata nedeni istemciye sizdirilmaz (hepsi `OAUTH_TOKEN_INVALID`).

### KVKK / hesap silme
`AccountDataPurger.DELETES` `auth_identity` satirlarini siler (`EMAIL_KEYED`: `auth_identity.email`); `ProfileService.anonymize` ad/soyad/kullanici adi/universiteyi temizler (kullanici adi baskasinin alabilecegi sekilde bosalir). Disa aktarim: `authIdentities` bolumu (saglayici, saglayicidaki e-posta, zamanlar; saglayici `sub` degeri VERILMEZ) + `profile` bolumune yeni alanlar. **Apple token revoke: yapilandirma bekliyor** (iptal icin Apple client secret/`.p8` anahtari ve yetkilendirme kodu takasi gerekir; bu surumde YOK. Hesap silinince Apple tarafinda uygulama erisimi kullanici tarafindan Ayarlar > Apple Kimligi > Apple ile Giris'ten kaldirilabilir). Gizlilik metni guncellemesi hukuk incelemesine bekler.

### Yeni hata kodlari (tr/en/ar: `auth*.properties`, `profile*.properties`)
`OAUTH_DISABLED` (404), `OAUTH_TOKEN_INVALID` (400), `OAUTH_EMAIL_UNVERIFIED` (403), `OAUTH_EMAIL_MISSING` (400), `OAUTH_LINK_REQUIRED` (409), `OAUTH_IDENTITY_TAKEN` (409), `OAUTH_PROVIDER_ALREADY_LINKED` (409), `OAUTH_IDENTITY_NOT_FOUND` (404), `OAUTH_LAST_LOGIN_METHOD` (409), `OAUTH_REAUTH_REQUIRED` (403), `PROFILE_INCOMPLETE` (403); `USERNAME_INVALID` (422), `USERNAME_RESERVED` (422), `USERNAME_TAKEN` (409), `USERNAME_COOLDOWN` (429, `{0}` gun), `PROFILE_FIELD_REQUIRED` (422), `TERMS_REQUIRED` (400). Hata govdesine ek alan yazabilmek icin `common.ExtraBody` (ApiExceptionHandler): `OAUTH_LINK_REQUIRED` -> `{code,message,provider,emailMasked,traceId?}`.

### Yeni ayarlar
`AUTH_OAUTH_ENABLED` (false), `GOOGLE_CLIENT_IDS`, `APPLE_CLIENT_IDS`, `AUTH_OAUTH_REQUIRE_TERMS` (true), `AUTH_PASSWORD_SIGNUPS_NEED_ONBOARDING` (false), `AUTH_PROFILE_GATE_ENABLED` (true), `AUTH_REAL_EMAIL_GATE_ENABLED` (true; V1472), `USERNAME_COOLDOWN_DAYS` (30). Compose/`.env.example`'a iletilir; bkz. DEPLOY.md.

### Bilinen sinirlar (OAuth surumu)
- **Apple token revoke yok** (yapilandirma bekliyor; yukarida). **Apple gizli e-posta** (relay) adresli hesap artik GERCEK e-posta ister: ayrintilar "Gercek e-posta (role) dogrulamasi" bolumunde (AE1472); relay adresine posta gonderilmesi gerekmez (Apple gonderici alan adi kaydi yalniz istege bagli; docs/OAUTH_SETUP.md bolum 2.5).
- Parolasiz (yalniz OAuth) hesap 2FA'yi acabilir ama **kapatmak parola ister** (`TwoFactorService.disable`); once `forgot-password` ile parola belirlemelidir. Parola degistirme (`change-password`) de mevcut parolayi ister: parolasiz hesapta `403 WRONG_PASSWORD`, yol `forgot-password`.
- Bolume gore sinif suzmesi yok (katalogda bolum suresi verisi yok); onboarding `OTHER` sinifi fakulte/bolumsuz kabul eder.
- Gercek Google/Apple token'i ile uctan uca duman BU SURUMDE DOGRULANMADI (yapilandirma yok); dogrulama yerel RSA anahtarli birim/MVC testleriyle yapildi (`scripts/smoke-oauth.sh` yalniz bayrak/dogrulama/kullanici adi).

## Gercek e-posta (role) dogrulamasi (AE1472, V1472, 2026-11-06)

**Sorun:** Sign in with Apple'da kullanici "E-postami gizle" derse Apple `xxxx@privaterelay.appleid.com` verir; hesap e-postasi bu olurdu (sifre sifirlama, 2FA, bildirim postasi ulasmaz ya da anlamsiz bir adres gorunur). Apple tarafinda kullaniciyi gercek e-posta paylasmaya ZORLAMAK mumkun degildir; cozum bizim tarafimizda: role adresli hesapta kullanicidan gercek, aktif adres istenir, 6 haneli kodla dogrulanir ve hesabin TEK e-postasi olur. Role adresine HICBIR ZAMAN posta gonderilmez.

### Tasarim kararlari
- **Role tespiti:** `RelayEmails.isRelay` (alan adi listesi bilerek kisa: `privaterelay.appleid.com`; yeni bir role alan adi cikarsa `RELAY_DOMAINS` + bu belge guncellenir). `icloud.com` gizli takma adlari gercek posta kutusudur, role degildir. Yeni Apple hesabinda ayrica kimlik jetonunun `is_private_email` bayragi da sayilir (`OAuthClaims.emailPrivate`).
- **Kapi mi, onboarding adimi mi? Ikisi de, kime gore:** YENI role hesapta (bu surumden sonra acilan) `real_email_required=true` = sunucu kapisi: gercek adres dogrulanana kadar yazma uclari `403 REAL_EMAIL_REQUIRED` (kalip `ProfileIncompleteWriteFilter`; `RealEmailRequiredWriteFilter` + STOMP SEND `RealEmailGate`). MEVCUT canli role hesaplar (migration yalniz `email_relay=true` isaretler, `real_email_required=false` birakir) KILITLENMEZ: yalniz yumusak adim (mobil "Gercek e-postani ekle", atlanabilir). Gerekce: canli kullaniciyi bir gecede kilitlemek kabul edilemez; yeni hesapta ise sorun ilk andan cozulur ve role adresli "hayalet" hesap birikmez.
- **Serbest uclar (kapida da calisir):** `/api/users/me/email/**`, `PUT /api/users/me/onboarding`, avatar, `PATCH /api/users/me`, `DELETE /api/users/me`, `/api/auth/**` (cikis dahil), `/api/legal`, `/api/support`, `/api/public`, `/api/analytics`, `/api/app`, `/api/devices`, `/api/reports`, `/api/notifications` ve tum okuma uclari. Profil kapisi (`PROFILE_INCOMPLETE`) ile bagimsiz calisir, sirasi onemsizdir; `ProfileIncompleteWriteFilter` da `/api/users/me/email/**` yolunu serbest birakir.
- **Acil kapatma:** `app.auth.real-email-gate.enabled` (`AUTH_REAL_EMAIL_GATE_ENABLED=false`): yeni hesap bayragi yazilmaz, filtre/STOMP kapisi devre disi. Akis uclari ve `emailNeedsReal` yanitlari yine calisir.

### Uclar (KIMLIKLI; kapida da erisilebilir)
- `POST /api/users/me/email/start` `{"email","password?","reauthProvider?","reauthToken?","reauthNonce?"}` -> `200 {"sent":true,"emailMasked":"g***@gmail.com","expiresInSeconds":600,"resendInSeconds":180}`. Kod YENI adrese gider (`VerificationService` "ce" alani: hash'li, 10 dk, 5 deneme, istemci kapsami, 180 sn yeniden gonderim beklemesi `429 RESEND_COOLDOWN`; kod adrese baglidir, adres degisirse eski kod gecersiz). Hatalar: `400 VALIDATION_ERROR` (bicim; okul numarasi kisayolu YOK), `400 EMAIL_ALIAS_NOT_ALLOWED` (+etiket), `400 EMAIL_RELAY_NOT_ALLOWED` (role adresi), `400 EMAIL_UNCHANGED`, `403 EMAIL_CHANGE_NOT_ALLOWED` (yonetici hesabi), `403 WRONG_PASSWORD` / `OAUTH_REAUTH_REQUIRED` (yalniz role OLMAYAN hesapta), `429`, `503 MAIL_QUOTA_EXHAUSTED`. Hiz siniri: kullanici basina saatte 5, hedef adres basina saatte 5, IP basina saatte 30.
- `POST /api/users/me/email/verify` `{"code":"123456"}` -> `200 {"email","emailVerified":true,"emailNeedsReal":false,"realEmailRequired":false}`. Hatalar: `400 INVALID_CODE` (yanlis/suresi dolmus/bekleyen yok), `429 TOO_MANY_ATTEMPTS`, `409 EMAIL_UNAVAILABLE` (adres baska hesapta kayitli ya da `ADMIN_EMAILS` adresi). Hiz siniri: kullanici basina 15 dk'da 20, IP basina 60.
- **Enumerasyon yok:** adres baska hesapta kayitli olsa da `start` ayni `200` ile kod gonderir (posta kutusu sahibi kodu gorur); cakisma YALNIZ dogru kod girildikten sonra `409 EMAIL_UNAVAILABLE` olarak bildirilir.
- **Yanitlara eklenen alanlar:** `GET /api/users/me` ve `POST /api/auth/oauth/{google|apple}` -> `emailNeedsReal` (hesap e-postasi role: uygulama "gercek e-posta" adimini gosterir) ve `realEmailRequired` (yeni role hesapta ZORUNLU kapi; mevcutlarda `false`).

### Dogrulamada olanlar
Hesap e-postasi gercek adrese cevrilir (`email_verified=true`, `verification_deferred=false`, `email_relay=false`, `real_email_required=false`, `real_email_verified_at=now`; `email_sha256` rehber ozeti otomatik guncellenir). KVKK: eski role adresi saklanmaz: Apple `auth_identity.email` bosaltilir (yalniz `sub` kalir) ve sonraki Apple girislerinde role adresi hesaba/kimlige geri YAZILMAZ. Bekleyen adres (`rem:<uid>`), kod/sayac anahtarlari ve ayni adres icin acik kayit dogrulama kodu/bekleyen kayit temizlenir. Denetim: yonetici denetim kaydi degil, uygulama gunlugu (maskeli adres; `RealEmailService`). Mevcut oturumlar KAPANMAZ (access JWT'deki `email` talebi bayat kalir; yalniz yonetici profili cozumunde kullanilir ve yonetici hesaplari bu ucu kullanamaz).

### Role olmayan hesapta "e-posta degistir" (zorunlu degil)
Ayni uclar parola/Google hesabinda da calisir ama hesap ele gecirme riskine karsi **yeniden dogrulama sart**: parolali hesapta `password`, parolasiz (Google) hesapta bagli saglayicinin taze token'i (`reauth*`). Role hesapta (kapi/yumusak adim) yeniden dogrulama istenmez: hesabin tek ve kullanilamaz adresi duzeltiliyor ve Apple oturumu az once acildi. **Yonetici hesaplari (ADMIN rolu / `ADMIN_EMAILS`) bu uctan adres degistiremez** ve kimse `ADMIN_EMAILS` adresine tasinamaz (yonetici terfisi e-posta adresine baglidir).

### Sema (V1472)
`app_user.email_relay`, `app_user.real_email_required` (BOOLEAN NOT NULL DEFAULT FALSE), `app_user.real_email_verified_at`. Geriye donuk: e-postasi `@privaterelay.appleid.com` olanlar (ve Apple kimligi "gizli" + ayni adres olanlar) `email_relay=true`. **Dagitim sirasi:** V1470/V1471 (`deploy/legal-20261106`, hukuki metin) ONCE canliya inmelidir; bu dal V1472'dir (`out-of-order=false`, bkz. docs/DEPLOY.md bolum 8).

### Yeni hata kodlari (tr/en/ar: `auth*.properties`)
`REAL_EMAIL_REQUIRED`, `EMAIL_UNCHANGED`, `EMAIL_RELAY_NOT_ALLOWED`, `EMAIL_UNAVAILABLE`, `EMAIL_CHANGE_NOT_ALLOWED`. E-posta kodu sablonu mevcut `verification` (metin "hesabi etkinlestirmek" yerine genel "e-posta adresini dogrulamak" olarak guncellendi, tr/en/ar).

### Bilinen sinirlar
- Apple tarafinda kullaniciyi gercek e-posta paylasmaya zorlamak mumkun degildir; yeni hesap kapiyla, mevcut hesap yumusak adimla yonlendirilir.
- Role hesapta e-posta degisiminde diger cihazlarin oturumlari kapatilmaz (yeniden dogrulama istenmez); eski role adresine "adresiniz degisti" postasi gonderilmez (ulasmaz).
- Gercek Apple jetonuyla uctan uca dogrulanmadi (yapilandirma yok); testler yerel RSA anahtarli MVC/birim testleridir, canli e-posta kodu `scripts/smoke-real-email.sh` ile PostgreSQL'de dogrulanir.
