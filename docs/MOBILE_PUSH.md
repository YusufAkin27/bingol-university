# Mobil push (FCM) kurulumu

Kod hazır: `lib/core/push/push_service.dart`, `push_router.dart`. Firebase yapılandırılmamışsa servis sessizce devre dışı kalır.

## Bağlama (main.dart / AppLifecycleHooks sahibi)
```dart
final push = PushService(session);
push.attach(onSignedIn: hooks.onSignedIn, onSignedOut: hooks.onSignedOut);
// MaterialApp(navigatorKey: rootNavigatorKey)
```
- Uygulama oturum açık başlıyorsa (`restore()` sonrası) `push.onSignedIn()` bir kez elle çağrılmalıdır.
- `onSignedOut` kancası, token'lar silinmeden ÖNCE çalışmalıdır (`DELETE /api/devices/{token}` Bearer ister). Geç kalırsa istek sessizce başarısız olur; sunucu geçersiz token'ı FCM `UNREGISTERED` dönünce kendisi siler.
- Platform değeri sunucu desenine uygun `IOS`/`ANDROID` gönderilir.

## iOS anahtarlarını nasıl ekleriz (adım adım)
Kod ve proje ayarları hazırdır; anahtarlar geldiğinde **kod değişikliği gerekmez**. Anahtarlar yokken uygulama çökmeden çalışır, push sessizce kapalı kalır (`Firebase.initializeApp` hatası yakalanır).

1. **Firebase konsolu** > Proje ayarları > Uygulamalarınız > iOS uygulaması ekle. Bundle id = `edu.bingol.buKampus` (`ios/Runner.xcodeproj` içindeki `PRODUCT_BUNDLE_IDENTIFIER`; birebir aynı olmalı). `GoogleService-Info.plist` dosyasını indirin.
2. Dosyayı `mobile/ios/Runner/GoogleService-Info.plist` yoluna koyun. Elle Xcode kaydı gerekmez: `Runner` hedefinde "Bundle GoogleService-Info.plist (optional)" adlı bir Run Script fazı dosyayı varsa `.app` paketine kopyalar, yoksa uyarı notu yazıp atlar (derleme kırılmaz).
3. **Apple Developer** (ücretli hesap şart) > Certificates, Identifiers & Profiles:
   - Identifiers > `edu.bingol.buKampus` App ID > **Push Notifications** yeteneğini işaretleyin.
   - Keys > yeni anahtar > **Apple Push Notifications service (APNs)** > `.p8` dosyasını indirin (bir kez indirilir). **Key ID** ve **Team ID**'yi not edin. `.p8` repoya girmez.
4. Firebase konsolu > Proje ayarları > **Cloud Messaging** > "Apple uygulaması yapılandırması" > APNs Authentication Key: `.p8`, Key ID ve Team ID'yi yükleyin.
5. **Push yetkisini imzaya ekleyin**: `powershell -File scripts/check-ios-push.ps1 -Enable` (veya `ios/Flutter/BuPush.xcconfig.example` dosyasını `BuPush.xcconfig` olarak kopyalayın). Bu, `Runner.entitlements` (Debug/Profile: `aps-environment=development`) ve `RunnerRelease.entitlements` (Release: `production`) dosyalarını imzaya bağlar. Dosya yokken push yetkisi istenmez; böylece ücretsiz Apple ID ile derleme bozulmaz. Push yeteneği ücretsiz Apple ID ile **verilemez**.
6. Yetenekler: Push Notifications (entitlements ile) ve Background Modes > Remote notifications (`Info.plist` `UIBackgroundModes=remote-notification`, eklendi). Xcode'dan yetenek ekleme gerekmez; xcross/Xcode otomatik imzada App ID'ye yetkiyi kendisi tanımlar.
7. `scripts/check-ios-push.ps1` çalıştırın: plist var mı, bundle id eşleşiyor mu, entitlements, Info.plist anahtarları (sır değerleri yazdırılmaz).
8. Derleyip gerçek cihaza kurun (iOS simülatörü APNs almaz).

### Test (gerçek cihaz)
- **Ön plan**: sistem şeridi çıkmaz (`setForegroundNotificationPresentationOptions` hepsi kapalı), uygulama içi şerit görünür; açık sohbetin mesajı bastırılır.
- **Arka plan**: sistem bildirimi gelir; dokunuş `onMessageOpenedApp` ile ilgili ekrana gider.
- **Kapalı (kaydırıp çıkılmış)**: bildirim gelir; dokunuşla soğuk açılışta `getInitialMessage` yönlendirir.
- Giriş sonrası `POST /api/devices` `platform=IOS` gitmiş olmalı; sunucu günlüğünde `UNREGISTERED`/`THIRD_PARTY_AUTH_ERROR` görülürse APNs anahtarı/Team ID yanlıştır.

### Davranış ve sınırlar
- iOS'ta FCM jetonu APNs belirtecinden önce istenirse null döner; `fetchPushToken` (`push_service.dart`) APNs belirtecini en çok 10 sn bekler, FCM jetonunu 3 kez dener, yine yoksa `onTokenRefresh` ile sonradan kaydeder.
- Bildirim izni: açılışta izin sayfası (`PermissionOnboarding`) sistem istemini yönetir; provisional izin kullanılmaz.
- `FirebaseAppDelegateProxyEnabled` tanımsız (proxy açık) bırakılmıştır: APNs belirteci kaydı Firebase eklentisi tarafından yapılır; `AppDelegate.swift` yalnız `UNUserNotificationCenter` delegesini atar. Anahtarı `NO` yaparsanız belirteç elle aktarılmalıdır.
- xcross (Windows'tan derleme): Run Script fazının, `#include?` xcconfig'in ve entitlements imzalamasının xcross tarafından işlendiği **doğrulanmadı** (macOS/Xcode'da standarttır). Çalışmazsa dosyayı `Runner.app` içine elle kopyalamak veya gerçek Xcode ile derlemek gerekir. Ücretsiz Apple ID imzası 7 gün geçerlidir.
- Sunucu APNs yükü (`FirebaseFcmSender.apns`): `apns-push-type=alert`, `apns-priority` 10 (yüksek) / 5, `sound=default`, `mutable-content=1`, isteğe bağlı `badge`, `thread-id`, `category`, `apns-collapse-id`. `content-available` gönderilmez (sessiz/veri push'u kullanılmıyor); alert push'ları arka planda bunsuz da iletilir.

## Davranış
- Ön plan: sistem şeridi kapalı; uygulama içi SnackBar ("Aç" ile yönlendirir).
- Dokunuş (arka plan/soğuk açılış): `conversationId` > `eventId` > `communityId` > `newsId` > kampanya `target/value` > bildirim listesi.
