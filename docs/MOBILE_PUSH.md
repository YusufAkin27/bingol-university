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

1. **Firebase konsolu** > Proje ayarları > Uygulamalarınız > iOS uygulaması ekle. Bundle id = `edu.bingol.buKampus` (`ios/Runner.xcodeproj` içindeki `PRODUCT_BUNDLE_IDENTIFIER`; birebir aynı olmalı; **bundle id kararı bekliyor**: önerilen `tr.com.bukampus.app`, bkz. [IOS_RELEASE.md](IOS_RELEASE.md) K1 ve `scripts/ios/set-bundle-id.sh`). `GoogleService-Info.plist` dosyasını indirin.
2. Dosyayı `mobile/ios/Runner/GoogleService-Info.plist` yoluna koyun (`mobile/.gitignore` içinde, commitlenmez; macOS CI `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64` gizli değişkeninden `scripts/ios/prepare-ci.sh` ile yazar). Elle Xcode kaydı gerekmez: `Runner` hedefinde "Bundle GoogleService-Info.plist (optional)" adlı bir Run Script fazı dosyayı varsa `.app` paketine kopyalar, yoksa uyarı notu yazıp atlar (derleme kırılmaz).
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

## iOS doğrulama (macOS CI / gerçek cihaz; Windows'ta YAPILAMADI)

Dosya düzeyinde doğrulananlar (`python -I -X utf8 scripts/ios/check-ios-static.py`): `aps-environment` Debug/Profile=`development`, Release=`production`; pbxproj'ta `CODE_SIGN_ENTITLEMENTS` 3/3 yapılandırmada; `UIBackgroundModes=remote-notification`; `FirebaseAppDelegateProxyEnabled` tanımsız (swizzling açık); `AppDelegate` `UNUserNotificationCenter` delegesini atar. **CI güvenliği:** `BuPush.xcconfig` yoksa push yetkisi imzaya girmez; `prepare-ci.sh` dosyayı üretir ve `build-ipa.sh` arşivde `aps-environment` yoksa durur.

Dart tarafı iOS için incelendi: APNs belirteci beklenir, ön plan sistem şeridi kapalı + uygulama içi şerit, `getInitialMessage`/`onMessageOpenedApp` ile `targetType/targetId` yönlendirmesi, sessiz push yok. iOS'a özgü iki eksik giderildi:
- **Simge rozeti:** sunucu `badge`'i okunmamış bildirim sayısıyla gönderir; istemci okununca sıfırlamıyordu. `core/push/icon_badge.dart` `AppBadges.notifications`'ı `bu_kampus/badge` kanalıyla (`ios/Runner/BuNativeBridge.swift`, `setBadgeCount`) simgeye yansıtır; çıkışta 0.
- **Yerel ders/sınav hatırlatmaları:** `bu_kampus/notify` yalnız Android'deydi; `BuNativeBridge.swift` `UNUserNotificationCenter` ile zamanlar ve dokunuşu `onTap`/`takeLaunchPayload` ile iletir. Kendi yerel bildirimlerine (`buLocal`) yanıt verir, FCM bildirimlerine dokunmaz (çift tamamlayıcı çağrısı yok).

macOS'ta cihazda doğrulanacaklar: (1) TestFlight yapısında bildirim gelir (production APNs); (2) ön plan/arka plan/kapalı dokunuşları ilgili ekrana gider; (3) bir ders hatırlatması zamanında görünür ve dokunuşla Akademik'e gider; (4) bildirimleri okuyunca simge rozeti düşer; (5) `POST /api/devices` `platform=IOS` gitmiştir. Ayrıntı: [IOS_RELEASE.md](IOS_RELEASE.md) bölüm 3, 6, 9.

## Davranış
- Ön plan: sistem şeridi kapalı; uygulama içi SnackBar ("Aç" ile yönlendirir).
- Dokunuş (arka plan/soğuk açılış): `conversationId` > `eventId` > `communityId` > `newsId` > kampanya `target/value` > bildirim listesi.

## Android: kapalıyken teslim, kanallar, kayıt yaşam döngüsü (P2)

**Uygulama kapalıyken (kaydırılıp çıkılmış / süreç ölü) nasıl gelir:** sunucu her FCM mesajına `notification` bloğu (başlık/gövde) + Android `channel_id` + `tag` + `sound` koyar (`FirebaseFcmSender.android`). Böyle mesajı süreç ölüyken **sistem (Google Play Hizmetleri) kendisi gösterir**; Dart kodu çalışmaz, işleyici gerekmez. Bu yüzden teslimin güvenilirliği şunlara bağlıdır: (1) sunucuda jetonun kayıtlı olması, (2) bildirim kanalının cihazda var olması, (3) OS izni/kanal izni, (4) OEM'in uygulamayı "durdurmamış" olması.

- **Kanallar** (`android/.../LocalReminders.kt` içinde `Channels`, kimlikler sunucu sözleşmesiyle aynı; ayrıca `lib/core/push/push_channels.dart`):

  | Kimlik | Ad (tr) | Önem | Kullanan |
  |---|---|---|---|
  | `chat` | Mesajlar | HIGH (ses + titreşim + ışık + başlık üstü) | MESSAGE |
  | `event` | Etkinlikler | DEFAULT | EVENT |
  | `announcement` | Duyurular ve haberler | DEFAULT | NEWS, ANNOUNCEMENT, COMMUNITY, SYSTEM, kulüp gönderisi |
  | `poll` | Anketler | DEFAULT | yükte `pollId` olanlar |
  | `social` | Sosyal | LOW (sessiz, rozet yok) | beğeni, takip |
  | `academic` | Ders ve sınav hatırlatmaları | HIGH | yalnız yerel hatırlatma (`ReminderReceiver`) |

  Ad ve açıklama 3 dilde (`bildirimmobilKanal*`, `p21Chan*Desc`); `PushService._syncChannelNames` girişte ve ön plana dönüşte `setChannelNames` ile gönderir, native taraf SharedPreferences'a (`bu_channels`) yazar. Önem kanal ilk oluşturulduğunda sabitlenir (kod sonradan yükseltemez/düşüremez; kullanıcı ayarı korunur).
- **Kanallar süreç başlarken kurulur:** `BuApplication.onCreate` -> `Channels.ensure` (uygulama kapalıyken FCM süreci başlatsa bile; eskiden yalnız `MainActivity.onCreate`'te kuruluyordu, güncellemeyle eklenen kanallar uygulama hiç açılmadan eksik kalabiliyordu). `MainActivity` yine çağırır (idempotent).
- **Manifest meta-data** (`AndroidManifest.xml`): `default_notification_channel_id=announcement`, `default_notification_icon=@drawable/ic_stat_bu` (monokrom beyaz silüet, 24-96 px), `default_notification_color=@color/notification_accent` (#F73B2E). Sunucu `channel_id` göndermeyen mesaj bu varsayılana düşer.
- **Arka plan işleyicisi:** `firebaseMessagingBackgroundHandler` üst düzey + `@pragma('vm:entry-point')`; `PushService.prepare()` `main()` içinde `runApp`'ten ÖNCE çağrılır (Firebase + işleyici kaydı, oturumdan bağımsız; eskiden yalnız ilk girişten sonra kaydediliyordu). Şu an yük işlemez (sunucu `notification` bloklu gönderir).
- **Bildirim izni (Android 13+):** `POST_NOTIFICATIONS` manifestte; çalışma zamanında ilk giriş izin sayfası (`PermissionsPage`) ve `PushService.onSignedIn` -> `requestPermission` ister. Reddedilirse jeton **kaydedilmez** (sunucu boşuna göndermesin) ve `PushService.permissionDenied` true olur; kullanıcı sistem ayarından açıp uygulamaya dönünce `didChangeAppLifecycleState(resumed)` -> `refresh()` izni yeniden okur ve jetonu kaydeder (uygulamayı yeniden başlatmak gerekmez).

### Jeton kaydı (`PushRegistrar`, `push_registrar.dart`)
- Giriş sonrası / her açılış (`restore` sonrası `onSignedIn`) / jeton yenilenince (`onTokenRefresh`) / ön plana dönüşte (kayıt 6 saatten eskiyse; sunucu hız sınırı 30/saat) `POST /api/devices {fcmToken, platform, appVersion, locale}`. Her çağrı sunucuda `lastSeenAt`'i yeniler (60 gün temizliği).
- **Yeniden deneme:** ağ/5xx/429 hatasında 15 sn, 1 dk, 5 dk, 15 dk; hak biterse `failed` ve bir sonraki ön plana dönüş/yardım ekranı "Yeniden kaydet" tekrar dener. 4xx (400/403...) kalıcı sayılır. Eskiden tek deneme vardı: ilk girişte ağ yoksa jeton sunucuya hiç ulaşmaz ve kullanıcı "bana hiç bildirim gelmiyor" derdi.
- **Jeton alma:** Android'de de 3 deneme (2 sn arayla; `SERVICE_NOT_AVAILABLE` gibi geçici hatalar), iOS'ta APNs beklenir. Jeton değişmediği için `onTokenRefresh` tetiklenmez; bu yüzden tek deneme jetonu kaybettirebiliyordu.
- **Çıkış:** `POST /api/auth/logout` gövdesine `fcmToken` eklenir (`Session.pushToken`; erişim jetonu süresi dolmuş olsa bile sunucu kaydı siler; P1 sözleşmesi), `DELETE /api/devices/{token}` (oturum kapanmadan, `beforeSignOut`) de denenir, ardından `FirebaseMessaging.deleteToken()` HER durumda (kayıt başarısız olsa bile eski jeton FCM'de geçersizlenir; sunucudaki kalıntı `UNREGISTERED` ile temizlenir). Başka kullanıcı girince aynı cihazın yeni jetonu yeni kullanıcıya kaydolur.
- Dokunuşla yönlendirme: dinleyiciler ve `getInitialMessage` artık izin/jeton adımlarından ÖNCE bağlanır (izin sayfası bekleyen/reddedilmiş kullanıcıda ve yavaş ağda soğuk açılış yönlendirmesi kaybolmaz), süreç başına bir kez işlenir.

- **Ön plan mesaj push'u:** sunucu artık WS bağlı/ön plandaki kullanıcıya da push gönderir (güvenlik ağı). `PushService.handleForeground`: açık sohbetin push'u yok sayılır; aynı `data.messageId` ikinci kez şerit çıkarmaz (son 60 kimlik); aksi halde uygulama içi şerit. Sistem şeridi yalnız Android'de ön planda hiç çıkmaz, iOS'ta `setForegroundNotificationPresentationOptions` kapalıdır.
- **Mesaj önizlemesi:** `Bildirim tercihleri` içinde "Bildirimde mesaj önizlemesi" anahtarı (`PUT /api/notifications/preferences {"messagePreview":bool}`; yalnız sunucu `messagePreview` alanını döndürürse görünür; varsayılan kapalı, açıklama: metin kilit ekranında görünür ve Google/Apple sunucularından geçer).

### "Bildirimler çalışmıyor mu?" yardım ekranı
`Profil > Bildirim tercihleri` push kartının altındaki bağlantı -> `features/notifications/push_help_page.dart`. Satırlar: sistem izni, kapatılmış kanallar (`chat/event/announcement`; `social` bilerek kapatılabilir sayılır), cihaz kaydı (+ "Yeniden kaydet"), pil/otomatik başlatma ipucu (Android; Xiaomi/Huawei/Samsung/OPPO/vivo... için ayrı metin). Eylemler yalnız ayar sayfası açar (`openNotificationSettings`: uygulama bildirim ayarları; `openBatterySettings`: uygulama bilgisi, olmazsa pil optimizasyonu listesi). **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` KULLANILMAZ** (Play politikası). Android 14 tam ekran/exact alarm gerekmez (hatırlatmalar `setAndAllowWhileIdle`).

### Sınırlar ve karar notları
- **Sistem tarafından gösterilen bildirimde büyük ikon (gönderen fotoğrafı), eylem düğmeleri (Yanıtla/Okundu) ve özel stil YOKTUR:** uygulama kapalıyken FCM `notification` mesajını Dart/Kotlin koduna uğratmadan sistem çizer. FCM SDK gövdeyi BigText olarak genişletir; aynı sohbet `tag` ile tek bildirimde birleşir; küçük ikon + vurgu rengi meta-data'dan gelir. Büyük ikon/eylem için sunucunun **yalnız-veri (data-only) + yüksek öncelik** göndermesi ve `FirebaseMessagingService` ile yerel bildirim çizmesi gerekir: bu, OEM/Doze'da teslim güvenilirliğini düşürür (veri mesajları durdurulmuş/kısıtlı uygulamalara geç ya da hiç gitmez) ve yeni paket/servis ister; **önerilmez** (bkz. docs/design/SORULAR.md P2).
- Kilit ekranı: gövde sunucuda "Yeni mesaj" + gönderen adıdır (önizleme ayarı sunucuda `app.push.message-preview`); kanal kilit ekranı görünürlüğü kullanıcının genel ayarına bırakılmıştır.
- Uygulama içi bildirim kutusu ve ön plan şeridi (`push_banner.dart`) değişmedi.
