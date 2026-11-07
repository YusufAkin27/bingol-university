# 03 - Şifre sıfırlama

## Kapsam
- Envanter 24 `ForgotPasswordPage`, 25 `ResetCodePage`, 26 `NewPasswordPage`, 27 `ResetSuccessPage`

## Istem
```text
Design 5 separate mobile screens of the password reset flow (no bottom nav, back arrow top-left).

1) Forgot password. Title "Şifrenizi mi unuttunuz?", subtitle "Okul e-postanızı girin, size 6 haneli bir kod gönderelim." Email field with suffix "@bingol.edu.tr". Primary button "Kod gönder". Text link "Girişe dön". Neutral success note under the button after sending: "Kod gönderildi."

2) Enter reset code. Title "Kodu girin", subtitle "ad.soyad@bingol.edu.tr adresine gönderdiğimiz 6 haneli kodu girin." Six OTP boxes, text button "Yapıştır", label "6 haneli doğrulama kodu". Error variant text: "6 haneli kodu girin." Disabled link "Yeniden gönder (30 sn)", then active "Kodu yeniden gönder". Text button "E-postayı değiştir". Primary button "Doğrula".

3) New password. Title "Yeni şifre belirleyin", subtitle "Bu şifre eski şifrenizin yerine geçer. Tüm cihazlardaki oturumlar kapanır." Fields "Yeni şifre" and "Yeni şifre (tekrar)" with eye icons, strength bar "Güçlü", rule rows with check icons "En az 8 karakter", "Harf ve rakam içerir". One field in error: "Şifre en az 8 karakter olmalı." Primary button "Şifreyi güncelle".

4) Success. Centered green check illustration, title "Şifreniz güncellendi", body "Yeni şifrenizle giriş yapabilirsiniz. Diğer cihazlardaki oturumlar kapatıldı." Primary button "Girişe dön".

5) Forgot password error states stacked on one screen: email field with a banner "Süre doldu. Baştan başlayın." (session expired, warning tone) and below it a second inline error "Çok fazla deneme. Lütfen biraz bekleyin." with "60 sn sonra tekrar deneyin." and a third line "Sunucuya ulaşılamadı. Bağlantınızı kontrol edin."
```

## Özellik kontrol listesi
- [ ] Adım 1: e-posta alanı, Kod gönder, Girişe dön, genel (hesap var/yok sızdırmayan) onay metni
- [ ] Adım 2: OTP kutuları, Yapıştır, hata, yeniden gönder sayacı, E-postayı değiştir
- [ ] Adım 3: iki şifre alanı, göz, güç ölçer, kural satırları, doğrulama hatası, uyarı "tüm cihazlardaki oturumlar kapanır"
- [ ] Başarı ekranı + Girişe dön
- [ ] Hata durumları: oturum süresi doldu, hız sınırı, ağ hatası

## Dikkat
- "Bu e-posta kayıtlı değil" gibi hesap varlığını sızdıran metin YOK; yanıt her zaman genel.
- SMS ile kod, telefon numarası, güvenlik sorusu yok.
