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

iOS push için ücretli Apple Developer hesabı gerekir. Adım adım kurulum (plist, `.p8`, imza anahtarı, test): [MOBILE_PUSH.md](MOBILE_PUSH.md) "iOS anahtarlarını nasıl ekleriz". Hazırlık kontrolü: `powershell -File scripts/check-ios-push.ps1`.

1. developer.apple.com, Certificates/Identifiers & Profiles, Keys: "Apple Push Notifications service (APNs)" etkin yeni anahtar oluşturun, `.p8` dosyasını indirin (bir kez indirilir), Key ID ve Team ID'yi not edin.
2. Firebase konsolu, Proje ayarları, Cloud Messaging, "Apple uygulaması yapılandırması": APNs Authentication Key olarak `.p8`, Key ID ve Team ID'yi yükleyin.
3. Push Notifications ve Background Modes (Remote notifications) yetenekleri projeye eklidir (`Runner.entitlements`, `Info.plist`); imzaya bağlamak için `scripts/check-ios-push.ps1 -Enable`.

## 4. Mobil yerleşim

- Android: `google-services.json` dosyasını `mobile/android/app/` altına koyun.
- iOS: `GoogleService-Info.plist` dosyasını `mobile/ios/Runner/` altına koyun (Xcode'a elle eklemek gerekmez; build fazı dosya varsa pakete kopyalar).
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

## Akıllı bildirim ve doğrulama

- Kimlik doğrulaması: yönetici olarak `POST /api/admin/push/fcm/validate` (kuru çalıştırma, cihaza gitmez). `validated=true` kimlik+proje+yetkinin geçerli olduğunu gösterir; `error` kodu (`UNAUTHENTICATED`, `PERMISSION_DENIED`...) nedeni verir. `GET .../status` yalnız kimliğin yüklenip yüklenmediğini ve Firebase proje kimliğini söyler.
- Android kanalları: `chat`, `event`, `announcement`, `poll`, `social`; sohbet bastırma için istemci `PUT/DELETE /api/conversations/{id}/viewing` ve `PUT /api/devices/{fcmToken}/state` çağırır. Ayrıntı: `docs/changes/push.md`.
- Ayarlar: `app.push.message-window-seconds` (20), `app.push.max-per-minute` (10), `app.push.message-preview` (false).

## 6. `google-services.json` API anahtarını kısıtlama (Google Cloud Console)

`mobile/android/app/google-services.json` repoda **izlenir** (Firebase proje kimliği `bu-kamp`, paket `tr.com.bukampus.app`; MOB2'den sonra, bkz. ANDROID_RELEASE.md 8.4). İçindeki `current_key` (Android API anahtarı) bir **sır değildir** ama uygulama paketine gömülüdür ve apk'dan çıkarılabilir; kısıtlanmazsa başkası bu anahtarla projenizin kotasını/faturasını kullanabilir. Yayından **önce** kısıtlayın (SİZ, Google Cloud hesabıyla; **doğrulanmadı**: Console arayüzü zamanla değişir, aşağıdaki adlar yazıldığı andaki yapıya göredir).

1. https://console.cloud.google.com adresinde Firebase ile **aynı projeyi** seçin (`bu-kamp`). Üst çubuktaki proje seçicide Firebase projesinin Cloud projesi olarak göründüğünü doğrulayın.
2. **API'ler ve Hizmetler > Kimlik Bilgileri (Credentials) > API anahtarları**. Anahtarı bulun: `google-services.json` içindeki `current_key` değeriyle eşleşen (genellikle "Android key (auto created by Firebase)"). Hangi anahtar olduğunu görmek için dosyada `"current_key"` satırına bakın (sır olmadığından Console'daki "Show key" ile karşılaştırabilirsiniz).
3. Anahtarı açın. **Uygulama kısıtlamaları (Application restrictions) > Android uygulamaları**:
   - "Paket adı ve parmak izi ekle": paket `tr.com.bukampus.app`.
   - **SHA-1 parmak izleri**, **üç ayrı** anahtar için (her biri ayrı satır; eksik olan anahtarla imzalı sürümde push kaydı ve Firebase çağrıları sessizce `API_KEY_ANDROID_APP_BLOCKED` ile reddedilir):
     1. **Upload key** (kendi ürettiğiniz keystore; Play'e yüklediğiniz AAB bununla imzalanır): `keytool -list -v -keystore <bu-upload.jks> -alias upload` çıktısındaki `SHA1:`.
     2. **Play App Signing anahtarı** (Google'ın kullanıcıya dağıttığı APK'yı imzalayan; **mağazadan kurulan uygulamada geçerli olan budur**): Play Console > uygulama > **Kurulum (Setup) > Uygulama bütünlüğü (App integrity) > Uygulama imzalama** altındaki "Uygulama imzalama anahtarı sertifikası" SHA-1 (ilk AAB yüklenip App Signing etkinleştikten sonra görünür).
     3. **Debug** anahtarı (yalnızca geliştirici cihazı; yayın anahtarı kısıtına dahil etmek zorunlu değil ama kendi testleriniz için): `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android` ya da `cd mobile/android && gradlew signingReport`.
   - Aynı SHA-1/SHA-256 değerlerini **Firebase Console > Proje ayarları > Android uygulaması > SHA sertifika parmak izleri** bölümüne de ekleyin (bazı Firebase özellikleri bunu ister; FCM tek başına şart koşmaz).
4. **API kısıtlamaları (API restrictions) > Anahtarı kısıtla** ve yalnızca uygulamanın çağırdıklarını seçin. Push için tipik küme: **Firebase Installations API** ve **Firebase Cloud Messaging Registration API** (gerekirse **Cloud Messaging**/**Firebase Cloud Messaging API**). Hangi API'lerin gerektiğini öğrenmek için: kısıtı uyguladıktan sonra release derlemesinde giriş yapıp `POST /api/devices` ile token kaydını deneyin; `logcat` içinde `API_NOT_ENABLED` / `blocked` görürseniz hatada adı geçen API'yi listeye ekleyin. Gereksiz API eklemeyin.
5. Kaydedin (yayılması birkaç dakika sürer). Doğrulama: ① Play kapalı test sürümünden kurulan uygulamada giriş sonrası token kaydı başarılı ve [bölüm 5](#5-test-adımları) adım 2 test bildirimi geliyor; ② `adb logcat` çıktısında `Requests from this Android client application ... are blocked` yok.
6. **Fatura/kötüye kullanım koruması:** Cloud Console > Faturalandırma > **Bütçeler ve uyarılar** altında düşük bir bütçe uyarısı (örn. aylık 5 USD) kurun; Spark (ücretsiz) planda kalın. Beklenmedik trafik görürseniz anahtarı **yeniden oluşturup** (yeni `google-services.json` indirip) uygulamayı güncelleyin.
7. **Sunucu kimliği ayrıdır:** kısıtlama yalnız istemci API anahtarını kapsar. Backend, Firebase **servis hesabı JSON**'u (`FCM_CREDENTIALS_JSON`) ile gönderir; bu dosya gerçek bir sırdır ve asla repoya girmez (bölüm 2). Servis hesabına yalnız "Firebase Cloud Messaging API Yöneticisi" benzeri asgari rolü verin.

Kontrol listesine bağlantı: [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) Aşama 4.
