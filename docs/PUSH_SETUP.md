# Push bildirim kurulumu (Firebase / FCM)

Firebase bilgileri verilene kadar sistem güvenle devre dışı çalışır: uygulama içi bildirim kutusu yazılır, push gönderilmez,
`/actuator/health` içinde `fcm.enabled=false` görünür.

## 1. Firebase projesi

1. https://console.firebase.google.com adresinde proje oluşturun (Analytics isteğe bağlı).
2. Proje ayarları, Cloud Messaging bölümünde "Firebase Cloud Messaging API (V1)" etkin olmalıdır.
3. Android ve iOS uygulamalarını ekleyin (paket adı / bundle id mobil ekiple aynı olmalı).

## 2. Servis hesabı anahtarı (backend)

Proje ayarları, Hizmet hesapları, "Yeni özel anahtar oluştur" ile JSON indirin. Bu dosya **sırdır**: repoya koymayın.

Backend iki yoldan okur (önce JSON, sonra dosya):

```bash
# a) Dosya (docker için volume ile bağlayın)
FCM_CREDENTIALS_FILE=/run/secrets/firebase.json

# b) Ortam değişkeni: ham JSON ya da base64 (önerilen, tek satır)
FCM_CREDENTIALS_JSON=$(base64 -w0 firebase.json)
```

Geçersiz/okunamayan kimlikte backend açılışı bozulmaz; uyarı yazılır (içerik yazılmaz) ve push devre dışı kalır.
Doğrulama: `curl localhost:8080/actuator/health` içinde `fcm.details.enabled` true olmalıdır.

## 3. iOS (APNs)

iOS push için ücretli Apple Developer hesabı gerekir.

1. developer.apple.com, Certificates/Identifiers & Profiles, Keys: "Apple Push Notifications service (APNs)" etkin yeni anahtar oluşturun, `.p8` dosyasını indirin (bir kez indirilir), Key ID ve Team ID'yi not edin.
2. Firebase konsolu, Proje ayarları, Cloud Messaging, "Apple uygulaması yapılandırması": APNs Authentication Key olarak `.p8`, Key ID ve Team ID'yi yükleyin.
3. Xcode'da Push Notifications ve Background Modes (Remote notifications) yeteneklerini ekleyin.

## 4. Mobil yerleşim

- Android: `google-services.json` dosyasını `mobile/android/app/` altına koyun.
- iOS: `GoogleService-Info.plist` dosyasını `mobile/ios/Runner/` altına koyun (Xcode'da hedefe ekleyin).
- Bu dosyalar sır değildir ancak ortama özeldir; commit edilip edilmeyeceğine ekip karar verir.
- Android 13+ için `POST_NOTIFICATIONS` izni istenmeli; kanallar `chat`, `event`, `announcement` oluşturulmalıdır.
- Token alındığında ve her açılışta `POST /api/devices` çağrılır, çıkışta `DELETE /api/devices/{token}`.
  Yük sözleşmesi: `docs/changes/push.md`.

## 5. Test adımları

1. Bir hesapla giriş yapıp cihazı kaydedin:
   ```bash
   curl -X POST localhost:8080/api/devices -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d '{"fcmToken":"<cihaz-token>","platform":"android","appVersion":"1.0.0","locale":"tr"}'
   ```
2. Yönetici kampanya ucundan test bildirimi gönderin; `SELF` hedef kitlesi yalnızca isteği yapan yöneticinin kendi
   cihazlarına gider (yönetici JWT'si ile; cihazı o hesapla kaydetmiş olmalısınız):
   ```bash
   curl -X POST localhost:8080/api/admin/push/campaigns -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"type":"ANNOUNCEMENT","audience":{"type":"SELF"},"tr":{"title":"Test","body":"Merhaba"}}'
   ```
   Ayrıntı: `docs/ADMIN_API.md`.
3. `GET /actuator/health` içinde `fcm.details.delivered` artmalı; `failures` artıyorsa backend log'unda neden yazar (token ve içerik yazılmaz).
4. Geçersiz token testi: eski/silinmiş bir token ile kayıt edip gönderin; cihaz kaydının otomatik silindiğini `GET /api/devices` ile doğrulayın.

## Sorun giderme

| Belirti | Neden |
|---|---|
| `enabled=false` | `FCM_CREDENTIALS_JSON`/`FILE` boş ya da geçersiz |
| Android geliyor, iOS gelmiyor | APNs anahtarı Firebase'e yüklenmemiş / bundle id uyuşmuyor |
| `failures` artıyor | FCM kotası/ağ; 3 yeniden denemeden sonra vazgeçilir |
| Bildirim kutusunda var, push yok | Sessiz saat, tercih kapalı ya da cihaz kaydı yok |
