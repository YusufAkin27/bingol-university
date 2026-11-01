# İki faktörlü doğrulama (e-posta kodu): API sözleşmesi

İsteğe bağlı (kullanıcı kendisi açar). Açıkken **tanınmayan bir cihazdan** her girişte kayıtlı (`bingol.edu.tr`) e-postaya 6 haneli kod gider. **Daha önce doğrulanmış (güvenilen) cihazdan** çıkış-giriş yapınca kod istenmez. Cihaz kimliği mevcut `X-Device-Id` başlığıdır (`ClientContexts.hash`: HMAC özeti, ham kimlik saklanmaz). Başlık yoksa/geçersizse cihaz **tanınmayan** sayılır (her girişte kod). Mobil bu başlığı zaten gönderir (`mobile/lib/core/device_identity.dart`); web istemcisi (yönetici paneli) için tarayıcıda kalıcı rastgele kimlik üretilip gönderilmelidir.

## Kurallar

- Güvenilen cihaz = (a) 2FA'nın açıldığı cihaz, (b) kod doğrulayarak giriş yapılan cihaz. Kullanıcı başına en çok 10 güvenilen cihaz (en eski düşer). Güvenilen cihaz kaydı: `two_factor_device (user_id, device_hash, label (platform/sürüm), created_at, last_used_at)`.
- Şifre **sıfırlanınca**, `logout-all` yapılınca, 2FA kapatılınca ve yönetici kapatınca tüm güvenilen cihazlar silinir. Şifre değişimi (profil) de siler.
- Önce şifre doğrulanır; yanlış şifrede 2FA hiç devreye girmez (mevcut genel hata, enumerasyon yok). Askıya alınmış/erişim engelli hesap kuralları aynen geçerli (kod gönderilmeden reddedilir).
- Kod: 6 hane, hash'li (SHA-256), 10 dk, 5 deneme, kod başına ve kullanıcı/IP başına hız sınırı (mevcut `VerificationService` + `RateLimiter` kalıbı), yeniden gönderme en çok 3/10 dk. Kod yalnız `app.mail.enabled=false` iken log'a yazılır (CLAUDE.md güvenlik kuralı 7).
- `challengeToken`: opak, 10 dk, Redis'te (`2fa:<sha256>` → userId + deviceHash + client), tek kullanımlık; başarılı doğrulamada ya da 5 yanlış denemede silinir.
- Yeni giriş bildirimi (`NewLoginNotifier`) mevcut davranışını korur.

## Uçlar

### Giriş (değişen): `POST /api/auth/login`
2FA kapalı ya da cihaz güvenilir: **200** `TokenResponse` (değişmez). 2FA açık ve cihaz tanınmıyor: **202** (token YOK, e-posta gider):
```json
{"twoFactorRequired": true, "challengeToken": "…", "emailHint": "ay***@bingol.edu.tr", "expiresInSeconds": 600}
```
### `POST /api/auth/login/2fa` (herkese açık, hız sınırlı)
`{"challengeToken","code","trustDevice":true}` → **200** `TokenResponse` (cihaz güvenilir yapılır; `trustDevice=false` ise yapılmaz, varsayılan true). Hatalar: 400 `TWO_FACTOR_CODE_INVALID`, 400 `TWO_FACTOR_CHALLENGE_EXPIRED`, 429 `RATE_LIMITED`/`Retry-After`.
### `POST /api/auth/login/2fa/resend`
`{"challengeToken"}` → **202** `{"expiresInSeconds":600}` (genel cevap; sınırlar aşılırsa 429).

### Ayarlar (JWT gerekli)
- `GET /api/auth/2fa` → `{"enabled":bool,"trustedDeviceCount":n,"currentDeviceTrusted":bool}`
- `POST /api/auth/2fa/enable/request` → **202** (kod e-postaya gider; zaten açıksa 409 `TWO_FACTOR_ALREADY_ENABLED`)
- `POST /api/auth/2fa/enable/confirm` `{"code"}` → **200** `{"enabled":true}` (bu cihaz güvenilir olur)
- `POST /api/auth/2fa/disable` `{"password"}` → **200** `{"enabled":false}` (yanlış şifre 400 `INVALID_PASSWORD`; tüm güvenilen cihazlar silinir)
- `GET /api/auth/2fa/devices` → `[{"id","label","createdAt","lastUsedAt","current":bool}]`
- `DELETE /api/auth/2fa/devices/{id}` → 204 (o cihaz bir sonraki girişte kod ister; mevcut oturumu kapatmaz)

## Yönetici (`/api/admin/**`, RBAC)
- Kullanıcı listesi/ayrıntısı: `twoFactorEnabled: boolean`, ayrıntıda ek `twoFactorTrustedDeviceCount`, `twoFactorEnabledAt`. `GET /api/admin/users?twoFactor=true|false` süzgeci (izin: mevcut `users.read`).
- `GET /api/admin/two-factor/summary` → `{"enabledCount","totalActiveUsers","enabledPercent","enabledLast7Days","trustedDeviceTotal"}` (`users.read`).
- `GET /api/admin/two-factor/users?page&size&q` → 2FA açan kullanıcılar: `{content:[{userId,displayName,email(maskeli kural: PermissionAwareMasking),role,enabledAt,trustedDeviceCount,lastLoginAt}],totalElements,totalPages,number,size}`.
- `POST /api/admin/users/{id}/two-factor/disable` `{"reason"}` (zorunlu gerekçe, denetim kaydı; hesap kurtarma için; `users.write`): 2FA'yı kapatır, güvenilen cihazları siler; kullanıcıya bildirim/e-posta gider.

## Hata kodları (3 dilde çeviri zorunlu)
`TWO_FACTOR_CODE_INVALID`, `TWO_FACTOR_CHALLENGE_EXPIRED`, `TWO_FACTOR_ALREADY_ENABLED`, `TWO_FACTOR_NOT_ENABLED`; e-posta şablonu `TWO_FACTOR_CODE` (tr/en/ar, HTML + düz metin).
