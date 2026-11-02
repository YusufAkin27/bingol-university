# İki faktörlü doğrulama (e-posta kodu): API sözleşmesi

İsteğe bağlı (kullanıcı kendisi açar). Açıkken **tanınmayan bir cihazdan** her girişte kayıtlı (`bingol.edu.tr`) e-postaya 6 haneli kod gider. **Daha önce doğrulanmış (güvenilen) cihazdan** çıkış-giriş yapınca kod istenmez. Cihaz kimliği mevcut `X-Device-Id` başlığıdır (`ClientContexts.hash`: HMAC özeti, ham kimlik saklanmaz). Başlık yoksa/geçersizse cihaz **tanınmayan** sayılır (her girişte kod). Mobil bu başlığı zaten gönderir (`mobile/lib/core/device_identity.dart`); web istemcisi (yönetici paneli) için tarayıcıda kalıcı rastgele kimlik üretilip gönderilmelidir.

## Kurallar

- Güvenilen cihaz = (a) 2FA'nın açıldığı cihaz, (b) kod doğrulayarak giriş yapılan cihaz. Kullanıcı başına en çok 10 güvenilen cihaz (en eski düşer). Güvenilen cihaz kaydı: `two_factor_device (user_id, device_hash, label (platform/sürüm), created_at, last_used_at)`.
- Şifre **sıfırlanınca**, `logout-all` yapılınca, 2FA kapatılınca ve yönetici kapatınca tüm güvenilen cihazlar silinir. Şifre değişimi (profil) de siler. Aynı şekilde **her tüm-oturum iptali** (`SessionService.revokeAll`: refresh yeniden kullanım tespiti, yönetici "oturumları kapat", erişim engeli, askıya alma) güvenilen cihazları siler (`SessionsRevokedEvent` dinleyicisi); yalnız bir istemci türünü kapatan olaylar (mobil tek cihaz kuralı) silmez.
- **Güvenilen cihaz süresi (HARDEN O2):** `last_used_at` üzerinden boşta **60 gün** (`app.twofactor.device-ttl-days`, 0 = sınırsız). Süresi dolmuş cihaz girişte güvenilmez sayılır ve silinir; gece 03:00 `DbMaintenanceJob` (`two_factor_device`) parçalı siler.
- **Challenge geçersizliği (O4):** challenge, açıldığı andaki şifre/oturum iptal işaretine (`pwchg:<uid>`) bağlıdır; şifre değişimi/sıfırlama, "tüm cihazlardan çık" ya da herhangi bir `revokeAll` sonrası eski challenge `TWO_FACTOR_CHALLENGE_EXPIRED` olur (kod doğru olsa bile). 2FA kapatılınca (kullanıcı ya da yönetici) açık challenge'lar da geçersizdir.
- **Kod challenge'a bağlıdır (D1):** her challenge kendi kodunu taşır (`tf:<uid>:<challenge özeti>`); başka bir challenge'ın ya da etkinleştirme kodunun kodu geçmez.
- **Yeni cihaz kilidi (D2):** 24 saatte 3 challenge tükenirse (her biri 5 yanlış kod) yeni cihazdan giriş 24 saat **429 `TWO_FACTOR_LOCKED`** olur; kullanıcıya (günde en çok 1) uygulama içi bildirim + e-posta gider. Güvenilen cihazdan giriş etkilenmez. Şifre sıfırlama/değişimi ya da başarılı bir doğrulama sayacı/kilidi temizler (doğrulama yalnız sayacı).
- **E-posta kotası (D3):** günlük sağlayıcı kotası tamamen dolduysa giriş/etkinleştirme/yeniden gönderme kod göndermeden **503 `MAIL_QUOTA_EXHAUSTED`** döner (kullanıcı 202 ile kilitli kalmaz).
- **Bildirimler (O1):** 2FA açılınca, kullanıcı kapatınca, yönetici kapatınca ve yeni cihaz kilidinde kullanıcıya **uygulama içi bildirim + e-posta** (şablon `SECURITY_TWO_FACTOR_NOTICE`; kullanıcının dilinde tr/en/ar) gider.
- Önce şifre doğrulanır; yanlış şifrede 2FA hiç devreye girmez (mevcut genel hata, enumerasyon yok). Askıya alınmış/erişim engelli hesap kuralları aynen geçerli (kod gönderilmeden reddedilir).
- Kod: 6 hane, hash'li (SHA-256), 10 dk, 5 deneme, kod başına ve kullanıcı/IP başına hız sınırı (mevcut `VerificationService` + `RateLimiter` kalıbı), yeniden gönderme en çok 3/10 dk. Kod yalnız `app.mail.enabled=false` iken log'a yazılır (CLAUDE.md güvenlik kuralı 7).
- `challengeToken`: opak, 10 dk, Redis'te (`2fa:<sha256>` → userId + deviceHash + client), tek kullanımlık; başarılı doğrulamada ya da 5 yanlış denemede silinir.
- Yeni giriş bildirimi (`NewLoginNotifier`) mevcut davranışını korur.

## Uçlar

### Giriş (değişen): `POST /api/auth/login`
2FA kapalı ya da cihaz güvenilir: **200** `TokenResponse` (değişmez). 2FA açık ve cihaz tanınmıyor: **202** (token YOK, e-posta gider):
```json
{"twoFactorRequired": true, "challengeToken": "…", "emailHint": "ay***@bingol.edu.tr", "expiresInSeconds": 600, "resendAfterSeconds": 180}
```
### `POST /api/auth/login/2fa` (herkese açık, hız sınırlı)
`{"challengeToken","code","trustDevice":true}` → **200** `TokenResponse` (cihaz güvenilir yapılır; `trustDevice=false` ise yapılmaz). **Sunucu varsayılanı `false`** (HARDEN D4): alan hiç gönderilmezse cihaz güvenilir yapılmaz. İstemciler alanı **açıkça** gönderir (mobil `Session.loginTwoFactor` ve web `verifyTwoFactorLogin` zaten gönderir; "Bu cihaza güven" kutusu arayüzde varsayılan işaretli kalabilir, ama bu artık istemci kararıdır). Hatalar: 400 `TWO_FACTOR_CODE_INVALID`, 400 `TWO_FACTOR_CHALLENGE_EXPIRED`, 429 `RATE_LIMITED`/`Retry-After`.
### `POST /api/auth/login/2fa/resend`
`{"challengeToken"}` → **202** `{"expiresInSeconds":600,"resendAfterSeconds":180}`. **Yeniden kod isteme beklemesi 180 sn** (tek kaynak `app.auth.code-resend-cooldown-seconds`; kod geçerliliği 10 dk DEĞİŞMEZ): ilk gönderim (giriş) beklemeyi başlatır; süre dolmadan istek **429 `RESEND_COOLDOWN`** + `Retry-After: <kalan sn>` + gövdede `retryAfterSeconds` döner. Bekleme challenge başına tutulur (Redis `vcool:tf:<özet>`); diğer sınırlar (challenge başına 3/10 dk, kullanıcı başına saatte 10 kod) aynen sürer ve bekleme bunlardan ÖNCE alınır (erken istek onları tüketmez). İstemci "Yeniden gönder (2:59)" geri sayımını `resendAfterSeconds`/`Retry-After` ile başlatır.

### Ayarlar (JWT gerekli)
- `GET /api/auth/2fa` → `{"enabled":bool,"trustedDeviceCount":n,"currentDeviceTrusted":bool}`
- `POST /api/auth/2fa/enable/request` → **202** `{"message","resendAfterSeconds":180}` (kod e-postaya gider; zaten açıksa 409 `TWO_FACTOR_ALREADY_ENABLED`; 180 sn dolmadan yeniden istek 429 `RESEND_COOLDOWN` + `Retry-After`; onay başarılı olunca bekleme kalkar)
- `POST /api/auth/2fa/enable/confirm` `{"code","closeOtherSessions"?}` → **200** `{"enabled":true}` (bu cihaz güvenilir olur; kullanıcıya bildirim + e-posta)
- `POST /api/auth/2fa/disable` `{"password","closeOtherSessions"?}` → **200** `{"enabled":false}` (yanlış şifre 400 `INVALID_PASSWORD`; tüm güvenilen cihazlar silinir; kullanıcıya bildirim + e-posta)
- **`closeOtherSessions` (isteğe bağlı, varsayılan `false`, HARDEN O1):** `true` ise kullanıcının TÜM oturumları kapanır (2FA öncesi açılmış, çalınmış olabilecek refresh token'lar dahil) ve yanıta bu cihaz için yeni çift eklenir: `{"enabled":true,"session":{"accessToken","refreshToken","expiresInSeconds","tokenType"}}`; istemci yeni çifti **saklamalıdır** (`change-password` ile aynı kural). Alan yoksa/`false` ise oturumlar kapanmaz ve `session` alanı yanıtta bulunmaz (eski istemciler bozulmaz). Web paneli bu alanı kullanır; mobil istemci henüz göndermez (mobil sürümde ayrı iş: yeni çifti `ApiClient.setTokens` ile saklamak).
- `GET /api/auth/2fa/devices` → `[{"id","label","createdAt","lastUsedAt","current":bool}]`
- `DELETE /api/auth/2fa/devices/{id}` → 204 (o cihaz bir sonraki girişte kod ister; mevcut oturumu kapatmaz)

## Yönetici (`/api/admin/**`, RBAC)
- Kullanıcı listesi/ayrıntısı: `twoFactorEnabled: boolean`, ayrıntıda ek `twoFactorTrustedDeviceCount`, `twoFactorEnabledAt`. `GET /api/admin/users?twoFactor=true|false` süzgeci (izin: mevcut `users.read`).
- `GET /api/admin/two-factor/summary` → `{"enabledCount","totalActiveUsers","enabledPercent","enabledLast7Days","trustedDeviceTotal"}` (`users.read`).
- `GET /api/admin/two-factor/users?page&size&q` → 2FA açan kullanıcılar: `{content:[{userId,displayName,email(maskeli kural: PermissionAwareMasking),role,enabledAt,trustedDeviceCount,lastLoginAt}],totalElements,totalPages,number,size}`.
- `POST /api/admin/users/{id}/two-factor/disable` `{"reason"}` (zorunlu gerekçe, denetim kaydı; hesap kurtarma için; izin **`users.2fa`: yalnız FULL ve SUPPORT**, MODERATOR yapamaz; HARDEN O3): 2FA'yı kapatır, güvenilen cihazları siler, kullanıcının **tüm oturumlarını kapatır**; kullanıcıya bildirim + e-posta gider. Kurallar: **kendi hesabı 403 `ADMIN_SELF_FORBIDDEN`** (kendi 2FA'sını kullanıcı ucundan şifreyle kapatır); **FULL yönetici hedef 403 `TWO_FACTOR_ADMIN_FORBIDDEN`** (iki kişi onayı gerektireceği için panelden hiç kapatılamaz; sunucu yöneticisi veritabanından yapar); FULL olmayan yönetici hedefi yalnız FULL kapatabilir (403 `ADMIN_TARGET_FORBIDDEN`).

## Hata kodları (3 dilde çeviri zorunlu)
`TWO_FACTOR_CODE_INVALID`, `TWO_FACTOR_CHALLENGE_EXPIRED`, `TWO_FACTOR_ALREADY_ENABLED`, `TWO_FACTOR_NOT_ENABLED`, `TWO_FACTOR_LOCKED` (429), `ADMIN_SELF_FORBIDDEN`, `TWO_FACTOR_ADMIN_FORBIDDEN`, `MAIL_QUOTA_EXHAUSTED` (503); e-posta şablonları `TWO_FACTOR_CODE` ve `SECURITY_TWO_FACTOR_NOTICE` (tr/en/ar, HTML + düz metin).

## Dağıtım notu (HARDEN)
Yeni migration yok. `TwoFactorService` artık `AuthService` için zorunlu bean'dir (yoksa açılış başarısız; 2FA sessizce kapanmaz). `e-posta maskesi` ≤2 karakterli yerel kısımda da en az 1 karakter gizler. Bekleyen challenge'lar dağıtım sırasında kesilmez (eski 5 alanlı biçim okunur), ancak giriş kodları artık challenge'a bağlıdır: dağıtımdan önce gönderilmiş kod, dağıtımdan sonra bir challenge'ı **geçmez** (kullanıcı yeniden giriş yapıp yeni kod ister; 10 dk pencere).
