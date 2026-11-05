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

1. **Firebase konsolu** > Proje ayarları > Uygulamalarınız > iOS uygulaması ekle (Android uygulamasıyla **aynı proje**). Bundle id = `tr.com.bukampus.app` (kullanıcı kararı 2026-10-31; `ios/Runner.xcodeproj` içindeki `PRODUCT_BUNDLE_IDENTIFIER` ile birebir aynı; Android `applicationId` ile aynı). `GoogleService-Info.plist` dosyasını indirin ve `bash scripts/ios/install-firebase-plist.sh <dosya>` ile doğrulayıp yerleştirin (BUNDLE_ID / PROJECT_ID / iOS uygulama kimliği / gitignore / Xcode fazı denetlenir; yanlış dosyayı reddeder).
2. Dosyayı `mobile/ios/Runner/GoogleService-Info.plist` yoluna koyun (`mobile/.gitignore` içinde, commitlenmez; macOS CI `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64` gizli değişkeninden `scripts/ios/prepare-ci.sh` ile yazar). Elle Xcode kaydı gerekmez: `Runner` hedefinde "Bundle GoogleService-Info.plist (optional)" adlı bir Run Script fazı dosyayı varsa `.app` paketine kopyalar, yoksa uyarı notu yazıp atlar (derleme kırılmaz).
3. **Apple Developer** (ücretli hesap şart) > Certificates, Identifiers & Profiles:
   - Identifiers > `tr.com.bukampus.app` App ID > **Push Notifications** yeteneğini işaretleyin.
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

## iOS'ta bildirim nasıl görünür (kod okunarak; cihazda DENENMEDİ)

Windows'ta iOS derlenemez/çalıştırılamaz; aşağısı sunucu yükü (`FirebaseFcmSender.apns`, `PushMessages`) ve `ios/Runner` dosyalarından çıkarılan **beklenen** görünümdür. Gerçek görünüm macOS + iPhone (TestFlight) ister; bu yüzden iOS için maket/PNG üretilmemiştir.

| Durum | Beklenen görünüm | Dayanak |
|---|---|---|
| Uygulama kapalı/arka planda | Üstten inen sistem şeridi: **uygulama simgesi** (köşeleri yuvarlak; Android'deki tek renkli küçük simge yoktur), kalın başlık, gövde (şeritte 2-3 satır, uzun basışta/genişletince daha fazla), "şimdi". Ses `default`. Başlık sohbet için kişi/grup adı, gövde varsayılan "Yeni mesaj" (önizleme tercihi kapalıysa) | `aps.alert{title,body}`, `sound=default`, `apns-push-type=alert`, `apns-priority=10` (mesaj/sistem/etkinlik başvuru sonucu; diğerleri 5) |
| Kilit ekranı / Bildirim Merkezi | Aynı kart; aynı sohbetin bildirimleri **tek yığında** toplanır ("N bildirim daha"). Yığın başlığı iOS tarafından uygulama adıdır | `aps.thread-id` = `conv:<id>` (sohbet), `community-<id>`, `event-<id>`, `post-<id>`, yoksa tür adı |
| Aynı sohbetten art arda gelenler | Yığın büyür (iOS'ta Android'deki `tag` ile yerine koyma YOK); `apns-collapse-id` yalnız sunucu `collapseKey` verirse (haber/gruplanmış bildirim) eskiyi değiştirir | `apns-collapse-id` (64 bayt sınırı) |
| Sosyal (beğeni/takip) | Ekranı uyandırmadan, sessizce Bildirim Merkezi'ne düşer | `interruption-level=passive` (yalnız `social` kanalı, yüksek öncelikli değilse) |
| Simge rozeti | Okunmamış bildirim sayısı; bildirimler okununca düşer, çıkışta 0 | `aps.badge` + `icon_badge.dart` / `BuNativeBridge.setBadgeCount` |
| Uygulama ön planda | **Sistem şeridi çıkmaz**; Android'dekiyle aynı uygulama içi `PushBanner` kartı görünür | `setForegroundNotificationPresentationOptions(alert/badge/sound: false)` + `FirebaseMessaging.onMessage` |
| Yerel ders/sınav hatırlatması | Aynı sistem şeridi, ön planda da gösterilir (`.banner,.list,.sound`); `threadIdentifier` = hatırlatma grubu | `BuNativeBridge.willPresent` (yalnız `buLocal` işaretli) |
| Dokunma | Soğuk açılış `getInitialMessage`, arka plan `onMessageOpenedApp`; yerel hatırlatma `onTap`/`takeLaunchPayload`. Hepsi Android'le aynı `resolvePushTarget` | `push_service.dart`, `push_targets.dart` |
| Arapça | iOS satır yönünü metnin diline ve cihaz diline göre kendisi belirler; uygulama bir şey yapmaz | sistem |

Küçük farklar (bilinçli): iOS'ta kanal kavramı yoktur (kanal adı/önem düzeyi Android'e özgü; iOS'ta kullanıcı ayarı uygulama başına tek anahtar + "Anında teslim/Zamanlanmış özet"); `category` (MESSAGE, EVENT...) şu an hiçbir eylem düğmesine bağlı değildir; `mutable-content=1` gönderilir ama Notification Service Extension yoktur (zararsız, ileride görsel eklemek için hazır). Bildirim izni sistem istemiyle istenir; metni iOS üretir (Info.plist'te bildirim izin açıklaması anahtarı yoktur), uygulamanın kendi ön izin ekranı (`PermissionOnboarding`) üç dillidir.

Cihazda doğrulanacak: yukarıdaki tablonun her satırı (özellikle yığınlama, `passive`, ön plan şeridinin sistem şeridini bastırması, Arapça hizalama). Android karşılığının ekran görüntüleri: [design/BILDIRIM_GORUNUMU.md](design/BILDIRIM_GORUNUMU.md).

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
- **Mesaj önizlemesi:** tercih yoktur; mesaj metni (gönderen adı + gövde) her kullanıcıda her zaman bildirimde ve kilit ekranında gösterilir (Android `VISIBILITY_PUBLIC`, kilit ekranı için ayrı "Yeni bildirim" sürümü yok). Eski `messagePreview` anahtarı kaldırıldı; istemci çizmez ve göndermez.

### "Bildirimler çalışmıyor mu?" yardım ekranı
`Profil > Bildirim tercihleri` push kartının altındaki bağlantı -> `features/notifications/push_help_page.dart`. Satırlar: sistem izni, kapatılmış kanallar (`chat/event/announcement`; `social` bilerek kapatılabilir sayılır), cihaz kaydı (+ "Yeniden kaydet"), pil/otomatik başlatma ipucu (Android; Xiaomi/Huawei/Samsung/OPPO/vivo... için ayrı metin). Eylemler yalnız ayar sayfası açar (`openNotificationSettings`: uygulama bildirim ayarları; `openBatterySettings`: uygulama bilgisi, olmazsa pil optimizasyonu listesi). **`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` KULLANILMAZ** (Play politikası). Android 14 tam ekran/exact alarm gerekmez (hatırlatmalar `setAndAllowWhileIdle`).

### Sınırlar ve karar notları
- **Sistem tarafından gösterilen bildirimde büyük ikon (gönderen fotoğrafı), eylem düğmeleri (Yanıtla/Okundu) ve özel stil YOKTUR:** uygulama kapalıyken FCM `notification` mesajını Dart/Kotlin koduna uğratmadan sistem çizer. FCM SDK gövdeyi BigText olarak genişletir; aynı sohbet `tag` ile tek bildirimde birleşir; küçük ikon + vurgu rengi meta-data'dan gelir. Büyük ikon/eylem için sunucunun **yalnız-veri (data-only) + yüksek öncelik** göndermesi ve `FirebaseMessagingService` ile yerel bildirim çizmesi gerekir: bu, OEM/Doze'da teslim güvenilirliğini düşürür (veri mesajları durdurulmuş/kısıtlı uygulamalara geç ya da hiç gitmez) ve yeni paket/servis ister; **önerilmez** (bkz. docs/design/SORULAR.md P2).
- Kilit ekranı: gövde her zaman gösterilir; kanal kilit ekranı görünürlüğü kullanıcının genel ayarına bırakılmıştır.
- Uygulama içi bildirim kutusu ve ön plan şeridi (`push_banner.dart`) değişmedi.

## iOS bildirim kartı (2.1.4, NB-IOS; macOS'ta DENENMEDİ)
- **Kategori:** sunucu `aps.category = BU_<style>` gönderir (`docs/changes/push.md` "Bildirim tasarımı yük sözleşmesi"). `NotificationService` yedek olarak kategori `BU_` ile başlamıyorsa yükteki `style`'dan düzeltir. Kayıtlı kategoriler (`AppDelegate.registerPushCategories`) == `NotificationContent/Info.plist` listesi (21; `check-ios-static.py` eşitliği denetler). Kayıtsız kategori = sistem kartı, aksiyonsuz.
- **Kart (`NotificationViewController`):** "BU Kampüs · kaynak (`sourceName` ya da stil etiketi)", göreli zaman, avatar (`senderAvatarUrl` eki) ya da kategori karosu, sohbette sayı rozeti / sosyalde kalp-kişi-kilit-onay rozeti, `badgeText` çipi, `important` -> "ÖNEMLİ", `severity=critical` -> kırmızı üst şerit, `eventStartsAt`+`location` çipi (Bugün/Yarın HH:mm, Europe/Istanbul), `oldStartsAt`/`newStartsAt` (yeni saat kalın, eski saat üstü çizili), `totalKcal` çipi, küçük resim sağda (sohbet fotoğrafı altta geniş). Yalnız yükte olan alan çizilir.
- **Aksiyonlar (yalnız işlevi olanlar):** sohbet (Yanıtla satır içi, Okundu İşaretle, 1 Saat Sessize Al, Görüntüle), etkinlik (Takvime Ekle, Haritada Gör; güncelleme: Anladım = yalnız kapatır + Program Detayı; kabul: Giriş Kartı), Sınav Detayı, Oy ver, Menüyü Gör, Takip et/Onayla/Reddet, Profili Gör, güvenlik: "Bu ben değilim" (yıkıcı stil, Hesap Güvenliği sayfasını açar), destek: Talebi Görüntüle. Beğeni (`LIKE`) ve yorum (`SOCIAL`) aksiyonsuz. Tasarımdaki "QR ile Giriş", "Okundu Say", "Hemen Doldur", "Adaylar", "Hemen Sıfırla", "2FA Aç", "Cihazı Çıkar", "İade Durumu", "Ekip" iOS'ta YOK (işlev/veri yok ya da Dart eşlemesi yok).
- **Kesinti düzeyi:** `NotificationService` sınav (`BU_EXAM`), güvenlik (`BU_SECURITY`) ve `severity=critical` bildirimlerini `time-sensitive` yapar (iOS 15+; sunucu `interruption-level` yollamışsa yükseltmez/düşürmez, yalnız `active`ı yükseltir; sosyal `passive` kalır). Uygulamaya `com.apple.developer.usernotifications.time-sensitive` yetkisi eklendi (`Runner.entitlements`, `RunnerRelease.entitlements`); CI imzası `-allowProvisioningUpdates` (bulut imzalama) ile App ID yeteneğini kendisi açar, elle profil kullanılırsa App ID'de "Time Sensitive Notifications" açılmalı ve profil yenilenmelidir.
- **Görsel indirme:** `NotificationService` `imageUrl`/`senderAvatarUrl`'ı yalnız https, kullanıcı bilgisiz, varsayılan port, IP/yerel olmayan ana makineden indirir (sunucu zaten yalnız `PUBLIC_WEB_URL` ana makinesi/`*.bingol.edu.tr` gönderir), yönlendirme aynı makineyle sınırlı, 1 MB, 5 sn; başarısızlıkta metin aynen gider.

## Android zengin bildirim kartı: tamamen native (2.1.4, NB-AND)

Kart (kaynak etiketi, rozet/çip, ikon karosu/avatar + köşe rozeti, sağ küçük resim, kritik şerit, aksiyon düğmeleri) uygulama **kapalıyken ve arka plandayken** sistem bildirimi olarak çizilir; Flutter motoru / Dart isolate'ı AÇILMAZ.

- **Giriş noktası:** `BuMessagingService` (`FlutterFirebaseMessagingService` alt sınıfı; manifestte eklentinin servisi `tools:node="remove"` ile değiştirildi). `onMessageReceived`: `notification` bloğu OLMAYAN ve `richNotification=1`/`richChat=1` ya da (`style` + `title`) taşıyan veri-only mesaj + uygulama ön planda DEĞİL -> `BuRichRender.render` -> `RichPushNotifications.show(awaitMedia=true)`. Ön plandayken dokunmaz (Dart ön plan şeridi çizer). Rich olmayan her şey eklentinin varsayılan yoluna gider. `BuFcmReceiver` (eklentinin alıcısının alt sınıfı) rich + arka plan mesajda eklentinin arka plan Dart motorunu BAŞLATMAZ.
- **Kanallar** `BuApplication.onCreate` içinde (Dart'tan önce, süreç FCM ile doğunca) kurulur.
- **Çizim planı:** `PushSpec` + `PushRenderPlan` (android/Flutter'dan bağımsız, birim testli: `android/app/src/test/.../PushRenderPlanTest.kt`) yükten tüm kararları verir; `RichPushNotifications` yalnız planı RemoteViews'a çizer. `style` yalnız sunucudan (eski yük için tür/hedeften türetilir); aksiyonlar `style` + `securityKind` + kimlik anahtarlarından türetilir ve yalnız karşılığında gerçek işlev olanlar gösterilir.
- **Görsel indirme:** native iş parçacığında, kısa zaman aşımı (1,8 sn/istek, toplam ~3 sn beklenir), yalnız https + `*.bingol.edu.tr` ya da `PUBLIC_WEB_URL` ana makinesi (Dart `authorize` ile `imageHost` yollar), yönlendirme yok, 1 MB sınırı. Başarısızsa kart görselsiz ama tam metinle çizilir.
- **Hata dayanıklılığı:** zengin çizim istisna atarsa `showPlain` (düz başlık/gövde kartı) çizilir; bildirim kaybolmaz.
- **Aksiyonlar:** sohbet: sistem `Notification.Action` + `RemoteInput` (gerçek satır içi yanıt). Flutter motoru hazırsa (uygulama arka planda ama süreç yaşıyor) metin ekran açılmadan `PushActions` ile gönderilir ve bildirim kaldırılır; motor yoksa (süreç öldürülmüş) sahte başarı gösterilmez: bildirim "Yanıt gönderilemedi, göndermek için dokunun" kartına döner ve dokununca uygulama aynı `actionId` (`clientId`) ile gönderir. Android 12+ bildirim aktarma (trampoline) kısıtı nedeniyle alıcıdan etkinlik başlatılamaz. "Anladım" tamamen native (bildirimi kaldırır). Diğerleri imzalı `PendingIntent` ile uygulamayı açar ve `PushActions` işler. Aynı kanalda >= 2 bildirim varsa `setGroup` + özet.
- **Yerel ders/sınav hatırlatması** aynı kartı kullanır (`CLASS`/`EXAM` stili; sınav yükünde `eventStartsAt` + `location` varsa "Yarın 10:00 · B-204" çipi).
- **Uygulama kapalıyken ne zaman ÇALIŞMAZ (dürüst sınırlar):** kullanıcı uygulamayı "Zorla durdur" yaptıysa Android, uygulama yeniden açılana dek FCM yayınlarını iletmez; Xiaomi/Huawei/Oppo/Vivo/Samsung gibi üreticilerin agresif pil/otomatik başlatma kısıtları süreci başlatmayı geciktirebilir ya da engelleyebilir (bkz. "Bildirimler çalışmıyor mu?" yardım ekranı); bildirim izni ya da kanal kapalıysa hiçbir kart gösterilemez; veri-only mesaj yüksek öncelikli olmalıdır (sunucu böyle gönderir), normal öncelikli veri mesajı Doze'da geç gelir; cihazda Google Play Hizmetleri yoksa FCM yoktur.
### Takvime ekle ve alarm (akademik)
- **Akademik takvim > "Cihaz takvimine ekle"**: core/platform/device_calendar.dart (kanal u_kampus/calendar; Android BuCalendar.kt CalendarContract, iOS BuCalendarAlarmBridge.swift EventKit). Izin calisma zamaninda istenir (Android READ/WRITE_CALENDAR, iOS tam erisim). Sonraki 365 gun yazilir; tum gun kayitlar tum gun etkinlik + o gun 08:00 hatirlatici (bildirimi takvim uygulamasi verir, uygulama ayrica yerel bildirim KURMAZ: cift bildirim yok). Etkinlik kimlikleri saklanir (calendar_sync.dart): ikinci calistirma gunceller, "Takvimden kaldir" yalniz bizimkileri siler.
- **Sinavlar > "Ilk sinav alarmlarini kur"**: gunun yalniz ilk sinavi, baslangictan 60 dk once, tek seferlik. Android Saat uygulamasi (AlarmClock.ACTION_SET_ALARM, BuAlarm.kt, kanal u_kampus/alarm) TARIH bilmez: alarm 24 saat icindeyse dogrudan kurulur, daha ilerideyse alarm ertelenir (kayit + onceki aksam 20:00 yerel "alarmi kur" bildirimi, Sinavlar sayfasinda "Simdi kur" bandi). iOS: Saat'e alarm eklenemez; tarihli zamana duyarli yerel bildirim.
- **Ders programi > "Sabah alarmlarini kur"**: her gunun en erken dersi 12:00'den once ise 60 dk once, haftalik tekrarli (EXTRA_DAYS); ayni saatteki gunler tek alarm. Android'de kurulan alarmlar Saat uygulamasindan silinir (silme API'si yok); ayni plan tekrar kurulurken cift alarm uyarisi cikar. Plan hesabi saf Dart: larm_planner.dart; kurulum: larm_service.dart; arayuz: larm_sheets.dart, calendar_sync_sheet.dart.
