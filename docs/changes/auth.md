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
