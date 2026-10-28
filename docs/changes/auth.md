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
