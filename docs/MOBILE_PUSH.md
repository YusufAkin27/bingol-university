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

## Yapılacaklar (Firebase bilgisi geldikten sonra)
1. Firebase konsolunda iOS uygulaması ekle (bundle id = `ios/Runner.xcodeproj` içindeki `PRODUCT_BUNDLE_IDENTIFIER`); `GoogleService-Info.plist` indir.
2. Dosyayı `ios/Runner/GoogleService-Info.plist` yoluna koy ve uygulama paketine (Runner hedefi, Copy Bundle Resources) girmesini sağla. Xcode yoksa `ios/Runner.xcodeproj/project.pbxproj` içine PBXFileReference + PBXBuildFile + Resources build phase kaydı elle eklenmelidir. xcross bu kaydı işlemiyorsa dosya ppakete girmez ve `Firebase.initializeApp()` hata verir (servis bu durumda sessizce kapalı kalır). xcross'un kaynak dosyası kopyalama desteği ayrıca doğrulanmalıdır.
3. Apple Developer: App ID için Push Notifications yeteneği ve APNs Auth Key (.p8); anahtarı Firebase > Project Settings > Cloud Messaging > Apple app configuration alanına yükle.
4. `ios/Runner/Runner.entitlements` içinde `aps-environment` (development/production) ve imzalama profilinde Push yeteneği gerekir. Arka plan alımı için Info.plist `UIBackgroundModes` = `remote-notification` eklenmeli (bu iş Info.plist sahibine bırakıldı).
5. Sunucu: gerçek FCM servis hesabı (`FCM_CREDENTIALS_FILE`); bkz. docs/PUSH_SETUP.md (backend).

## Davranış
- Ön plan: sistem şeridi kapalı; uygulama içi SnackBar ("Aç" ile yönlendirir).
- Dokunuş (arka plan/soğuk açılış): `conversationId` > `eventId` > `communityId` > `newsId` > kampanya `target/value` > bildirim listesi.
