# iOS yayın rehberi (TestFlight / App Store)

Bu belge, **Apple Developer hesabı açıldığında** uygulamanın TestFlight ve App Store'a çıkması için yapılacakları sıralar. Windows'ta Xcode yoktur: bu repoda yapılan her şey **dosya düzeyinde** doğrulandı; derleme, imzalama ve yükleme **macOS CI'da (GitHub Actions `macos-latest` ya da Codemagic)** ilk kez çalışacak. Dürüst durum tablosu bölüm 9'dadır. Paralel Android belgesi: [ANDROID_RELEASE.md](ANDROID_RELEASE.md). Push ayrıntısı: [MOBILE_PUSH.md](MOBILE_PUSH.md), [PUSH_SETUP.md](PUSH_SETUP.md). Mağaza metni ve gizlilik cevapları: [ios-store/](ios-store/README.md). Genel yayın sırası: [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md).

> Apple kuralları ve App Store Connect arayüzü sık değişir. Bu belge yazıldığı andaki bilgiye dayanır (2026-10); karşılaştığınız ifade farklıysa anlamca eşleştirin ve belgeyi güncelleyin.

## 1. Kararlar (KULLANICI KARARI gerekir)

| # | Konu | Öneri | Neden |
|---|---|---|---|
| K1 | **Bundle id** | `tr.com.bukampus.app` (Android `applicationId` ile aynı) | Şu an iOS'ta `edu.bingol.buKampus`. `edu.bingol` ters alan adı bize ait değil (Bingöl Üniversitesi'nin); Android zaten `tr.com.bukampus.app`. Tek kimlik Firebase, push ve mağaza yönetimini kolaylaştırır. **Henüz DEĞİŞTİRİLMEDİ.** Onayınızla tek komut: `scripts/ios/set-bundle-id.sh tr.com.bukampus.app` (pbxproj, codemagic.yaml, fastlane Appfile). Sonra Firebase'de iOS uygulamasını **yeni id ile** ekleyin ve yeni `GoogleService-Info.plist` indirin. **App Store Connect'e yükledikten sonra bundle id bir daha değişmez**; kararı hesap açılmadan verin |
| K2 | **iPad** | Yalnız iPhone (`TARGETED_DEVICE_FAMILY=1`, yapıldı) | Arayüz telefon için tasarlandı; iPad destekli olursa inceleme iPad'de yapılır, bozuk yerleşim 4.0/2.1 reddine yol açar, 13" iPad ekran görüntüsü gerekir. iPad'de uygulama "iPhone uyumluluk" kipinde açılır. Sonra açmak: pbxproj'da `TARGETED_DEVICE_FAMILY = "1,2"`, Info.plist'te iPad yönlendirmeleri zaten var, iPad ekran görüntüleri üretilir |
| K3 | **Uygulama adı / kurumsal bağlantı** | Ad "BÜ Kampüs", alt başlıkta "bağımsız/resmî olmayan" | Apple "resmî görünen" kurum uygulamalarının kurum tarafından gönderilmesini ister (4.1 taklit, 5.2 fikri mülkiyet). Üniversiteden **yazılı destek/izin mektubu** almak reddi en çok azaltan adımdır ([LEGAL_NOTES.md](LEGAL_NOTES.md) madde 1). Mektup yoksa ret gelirse ad "BU Kampus" yapılıp "BÜ"/üniversite adı yalnız açıklamada geçirilebilir |
| K4 | **Moderasyon taahhüdü (1.2)** | Bildirilen içeriğe **24 saat içinde** işlem | Apple UGC kuralı "zamanında yanıt" ister; panel var ama 7/24 değil ([MODERATION.md](MODERATION.md)). İnceleme notuna "24 saat" yazmadan önce bunu gerçekten üstlenebileceğinizi onaylayın |
| K5 | **İnceleme demo hesabı** | `scripts/ops/create-review-account.sh` ile hazır hesap | Kayıt yalnız `bingol.edu.tr` + e-posta kodu; inceleyici kayıt olamaz ([store/PLAY_REVIEW_ACCOUNT.md](store/PLAY_REVIEW_ACCOUNT.md) aynen geçerli; Apple için de aynı hesap kullanılabilir, parola repoya yazılmaz) |
| K6 | **Yaş derecelendirmesi** | Anketi dürüst doldurun; Apple hesaplasın | Kullanıcı içeriği + sohbet var. Bölüm 7.6 |
| K7 | **Hesap türü** | Bireysel (kişisel proje) | Bölüm 3, adım 1. Bireyselde **satıcı adı sizin adınız** olarak mağazada görünür; kurum hesabı D-U-N-S ister |
| K8 | **Dağıtım ülkeleri** | İlk sürümde yalnız Türkiye | AB mağazalarında "trader" (DSA) kimlik/adres/telefon bilgisi herkese açık yayımlanır; bireysel hesapta bu kişisel veridir |
| K9 | **İçerik hakkı beyanı** | App Store Connect "Content Rights: üçüncü taraf içerik içerir" = Evet | Haber/duyuru/yemek içeriği üniversite sitesinden alınır; haklar için K3'teki izin mektubu işe yarar |

## 2. KULLANICIDAN GEREKENLER

| Gereken | Nerede kullanılır | Not |
|---|---|---|
| Apple Developer Program üyeliği (99 USD/yıl) ve Apple ID (2 adımlı doğrulama açık) | Her şey | Bireysel hesap birkaç saat-gün içinde açılır; kurum hesabı D-U-N-S ve doğrulama araması ister (haftalar) |
| **Team ID** (developer.apple.com > Membership; 10 karakter) | `IOS_TEAM_ID` | Sır değil, yine de depoya yazılmaz |
| **Bundle id kararı** (K1) | `set-bundle-id.sh`, Firebase, App ID | Öneri `tr.com.bukampus.app` |
| **APNs Authentication Key** `.p8` + **Key ID** | Firebase Console > Cloud Messaging | Bir kez indirilir; repoya girmez |
| **App Store Connect API anahtarı**: `.p8` + Key ID + Issuer ID | CI (`IOS_API_KEY_*`) | Users and Access > Integrations > App Store Connect API > **Team Keys**. Rol: bulut imzalama için Admin gerekebilir; "App Manager" ile sertifika izni hatası alırsanız Admin verin (doğrulanamadı). `.p8` bir kez indirilir |
| **Firebase iOS uygulaması** ve `GoogleService-Info.plist` | `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64` | Bölüm 3, adım 6-7 |
| Gizlilik politikası URL'i | App Store Connect | `https://bukampus.com.tr/tr/privacy` (3 dilde var, bölüm 7.4) |
| Destek URL'i ve destek e-postası | App Store Connect | Önerilen: `https://bukampus.com.tr/tr/contact` (iletişim sayfası; yardım: `/tr/help`) ve `ysufakin23@gmail.com` ([store/README.md](store/README.md)) |
| İnceleme demo hesabı (e-posta + parola) | App Store Connect > App Review Information | Parola yalnız Connect'e girilir |
| Telif satırı | App Store Connect > Copyright | Örn. `2026 <adınız>` |
| Yaş derecesi anketi cevapları | App Store Connect | Bölüm 7.6 |
| K3 üniversite destek mektubu (varsa) | İnceleme notu eki | İsteğe bağlı ama önerilir |
| Xcode'lu Mac ya da CI hesabı | İlk derleme | GitHub Actions (private depoda macOS dakikası ücretlidir/10x çarpan) veya Codemagic (aylık ücretsiz dakika) |

## 3. Apple Developer hesabı açıldığında: adım adım

1. **Hesap türü.** Bireysel: ad-soyad, kimlik, 99 USD; D-U-N-S gerekmez; mağazada satıcı = kişisel ad. Kurum/dernek: tüzel kişilik + D-U-N-S (ücretsiz, Dun & Bradstreet üzerinden birkaç hafta) + hesap sahibinin yetki doğrulaması; eğitim kurumu/kâr amacı gütmeyen için ücret muafiyeti başvurusu olabilir. İlk sürüm için bireysel yeterlidir; sonra kuruma "app transfer" ile devredilebilir.
2. **Sözleşmeler.** App Store Connect > Business (Agreements, Tax, and Banking): ücretsiz uygulama için "Free Apps" sözleşmesi otomatik etkin olur; banka/vergi gerekmez. Yönetim (Users and Access) için ek kullanıcı eklenecekse rolünü verin.
3. **Team ID'yi not edin** (Membership details).
4. **Bundle id kararı (K1)** → gerekiyorsa `scripts/ios/set-bundle-id.sh <id>` ve commit.
5. **App ID (Identifier) oluşturun.** developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > App IDs > App > Explicit Bundle ID = karar verilen id; Capabilities: **Push Notifications** işaretli. (Alternatif: `fastlane create_app` hattı bunu ve Connect kaydını yapar, `mobile/ios/fastlane/Fastfile`.) Sertifika ve profili elle üretmeniz **gerekmez**: CI, API anahtarıyla Apple'ın bulut imzalamasını kullanır (`-allowProvisioningUpdates`).
6. **Firebase iOS uygulaması.** Firebase Console > Proje ayarları > Uygulamalarınız > iOS uygulaması ekle: Bundle ID = bölüm 1'deki id (birebir; büyük/küçük harf duyarlı). `GoogleService-Info.plist` indirin. Dosyayı repoya koymayın (`mobile/.gitignore` içinde); CI için base64'leyin: `base64 -w0 GoogleService-Info.plist` (macOS: `base64 -i GoogleService-Info.plist`) → GitHub Secret `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64`. Yerelde dene­mek için `mobile/ios/Runner/GoogleService-Info.plist` olarak koyabilirsiniz (gitignored). Karar: dosya sır değildir (API anahtarı bundle id ile kısıtlıdır) ama proje politikası gereği commitlenmez, CI yazar.
7. **APNs anahtarı.** developer.apple.com > Keys > yeni anahtar > **Apple Push Notifications service (APNs)** > indir `.p8`; **Key ID** ve **Team ID** not edin. Firebase Console > Proje ayarları > Cloud Messaging > Apple uygulaması yapılandırması > **APNs Authentication Key** olarak `.p8` + Key ID + Team ID yükleyin (hem geliştirme hem üretim için tek anahtar yeter). Ayrıntı: [PUSH_SETUP.md](PUSH_SETUP.md) bölüm 3.
8. **App Store Connect kaydı.** My Apps > + > New App: Platform iOS; Ad `BÜ Kampüs` (30 karakter sınırı, benzersiz olmalı; doluysa "BÜ Kampüs - Kampüs" benzeri); Birincil dil Türkçe; Bundle ID listeden; SKU `bu-kampus-ios`; Kullanıcı erişimi Full. Sonra bölüm 4'teki alanlar.
9. **App Store Connect API anahtarı** (CI için): Users and Access > Integrations > App Store Connect API > Team Keys > + > rol Admin (bkz. bölüm 2 notu). Key ID, Issuer ID, `.p8` → Secrets.
10. **CI Secrets (GitHub: Settings > Environments > production)**: `IOS_TEAM_ID`, `IOS_API_KEY_ID`, `IOS_API_ISSUER_ID`, `IOS_API_KEY_P8_BASE64` (`.p8` dosyasının base64'ü), `IOS_GOOGLE_SERVICE_INFO_PLIST_BASE64`. Değişken: `API_BASE` (varsayılan `https://bukampus.com.tr`). Codemagic: aynı değerler "bu_ios" grubunda + App Store Connect entegrasyonu (`codemagic.yaml` başı).
11. **İlk derleme.** Actions > "Release iOS" > Run workflow (`upload` kapalı): IPA artifact'ı üretilir. Hata ayıklama için bölüm 9'daki "ilk macOS koşusunda bakılacaklar". Sonra `upload` açık koşu ya da `bash scripts/ios/upload-testflight.sh`.
12. **TestFlight.** Yükleme işlendikten sonra (10-30 dk) Connect > TestFlight. *Dahili test* (App Store Connect kullanıcıları, 100'e kadar): inceleme gerekmez, anında. *Harici test* (e-posta/halka açık bağlantı, 10 000'e kadar): ilk yapı **Beta App Review** ister (genelde 1 gün); "Test Information" alanına demo hesap ve not girin. Yapılar 90 gün geçerlidir. Uyum sorusu çıkmaz (`ITSAppUsesNonExemptEncryption=false`, bölüm 4).
13. **Gerçek cihazda push testi** ([MOBILE_PUSH.md](MOBILE_PUSH.md) "iOS doğrulama"): TestFlight yapısı **production** APNs ortamını kullanır (`RunnerRelease.entitlements`); Firebase'e yüklenen tek `.p8` her ikisine de yeter.
14. **Mağaza sayfası.** [ios-store/](ios-store/README.md) metinlerini Connect'e girin; ekran görüntüleri (bölüm 7.7); App Privacy cevapları ([ios-store/APP_PRIVACY.md](ios-store/APP_PRIVACY.md)); yaş derecesi; Export Compliance (otomatik); inceleme notu ([ios-store/REVIEW_NOTES.md](ios-store/REVIEW_NOTES.md)).
15. **Sunucu ayarı.** Yönetici panelinde (`PUT /api/admin/settings/...`, kritik anahtarlar): `store_url_ios` (App Store bağlantısı, `https://apps.apple.com/...`), `min_version_ios`, `latest_version_ios`. Zorunlu güncelleme ekranı bu değerleri okur ([appinfo](../backend/src/main/java/edu/bingol/backend/appinfo/AppInfoService.java)). Mağaza bağlantısı olmadan "Güncelle" düğmesi görünmez.
16. **İncelemeye gönder.** Sürüm "Prepare for Submission" > yapıyı seçin > Submit for Review. İlk inceleme genelde 24-48 saat. Ret gelirse Resolution Center'dan yanıtlayın (bölüm 8).
17. **Yayın sonrası.** Çıkış sonrası aynı sürümün `symbols` klasörünü saklayın (çökme izleri çözmek için); pubspec sürümünü artırmadan yeni yükleme yapılamaz (bölüm 5).

## 4. Yapılandırma gerçekleri (dosya düzeyinde doğrulandı)

### 4.1 İzinler ve eklentiler

`permission_handler_apple` 9.6.4 **Swift Package Manager** kipinde `PERMISSION_*` makrolarını ilgili `NS*UsageDescription` anahtarı Info.plist'te varsa **kendisi** açar (paketin `Package.swift` dosyası ve README'si okunarak doğrulandı; Podfile bayrağı gerekmez, **Podfile yoktur**). Bu yüzden Info.plist'teki izin anahtarları aynı zamanda hangi izin kodunun derlendiğini belirler: kullanılmayan anahtar eklemeyin, kullanılan anahtarı silmeyin. Manifest yalnızca `flutter build`/`xcodebuild` uygulama dizininden başlatılırsa bulur (CI öyle çalışır); Xcode.app'ten elle derlenirse `launchctl setenv PERMISSION_HANDLER_INFO_PLIST <mutlak yol>/mobile/ios/Runner/Info.plist` verin ve DerivedData'yı silin.

| İzin / API | Info.plist anahtarı | Kullanan kod / eklenti |
|---|---|---|
| Kamera | `NSCameraUsageDescription` | `mobile_scanner` (QR yoklama), `camera` (sohbet kamerası), `image_picker` (kamera) |
| Mikrofon | `NSMicrophoneUsageDescription` | video kaydının ses kanalı (`camera`, `image_picker`) |
| Fotoğraf okuma | `NSPhotoLibraryUsageDescription` | `photo_manager` (sohbet galerisi), `image_picker` |
| Fotoğraf ekleme | `NSPhotoLibraryAddUsageDescription` | `gal` (görseli galeriye kaydet) |
| Rehber | `NSContactsUsageDescription` | `flutter_contacts` (e-posta SHA-256 özetiyle eşleştirme; isteğe bağlı) |
| Bildirim | (anahtar yok) | `firebase_messaging`; izin istemi `PermissionOnboarding` |
| Yerel ağ | `NSLocalNetworkUsageDescription` | **yalnız geliştirme**; yayın derlemesinde CI siler (`prepare-ci.sh`); anahtar yokken izin penceresi zaten tetiklenmez |

Metinler Türkçe (varsayılan), İngilizce ve Arapça (`ios/Runner/{tr,en,ar}.lproj/InfoPlist.strings`; Arapça taslaktır, anadil incelemesi ister). Konum, takip (ATT), Bluetooth, Face ID **kullanılmaz** ve anahtarları yoktur (`check-ios-static.py` yasak listesiyle denetler). `LSApplicationQueriesSchemes` gereksizdir: kodda yalnız `launchUrl(https)` vardır, `canLaunchUrl` yoktur. **Associated Domains / evrensel bağlantı yoktur**: uygulama gelen web bağlantısını işlemiyor; gerekirse taslak: entitlements'a `com.apple.developer.associated-domains = applinks:bukampus.com.tr`, sitede `/.well-known/apple-app-site-association` (JSON, `appID: <TeamID>.<bundleId>`) ve uygulamada bağlantı yönlendirmesi gerekir; ilk sürüm kapsamı dışındadır.

### 4.2 Şifreleme beyanı (`ITSAppUsesNonExemptEncryption = false`)

İstemcide **özel/standart dışı şifreleme yoktur**: ağ trafiği HTTPS/WSS (TLS), jetonlar Keychain'de (`flutter_secure_storage`), rehber eşleştirmede SHA-256 özeti (`package:crypto`, **hash**, şifreleme değil), mesaj zarf şifrelemesi **sunucudadır** ([ENCRYPTION.md](ENCRYPTION.md)) ve istemciden çalıştırılmaz. Yalnızca kimlik doğrulama/TLS/özet için standart algoritmalar kullanan uygulamalar ABD EAR kapsamında muaf sayılır; bu nedenle `false` doğrudur ve her yüklemede "ihracat uyumluluğu" sorusunu önler. Dikkat: Dart çalışma zamanı TLS'i kendi içinde taşır; bu da hâlâ "standart TLS" olarak muaf kategoridedir. Fransa için ayrı beyan gerekmez (muaf). Emin olunmayan durumda Connect'te sorulursa cevap: "Uses encryption: Yes → exempt: standard encryption/TLS only". Bu bir hukuki görüş değildir.

### 4.3 Push (APNs)

- Entitlements: `Runner.entitlements` = `development` (Debug/Profile), `RunnerRelease.entitlements` = `production` (Release). Bağlantı: pbxproj'ta üç yapılandırmada `CODE_SIGN_ENTITLEMENTS = "$(BU_PUSH_ENTITLEMENTS)"`, değer `ios/Flutter/BuPush.xcconfig` (örneğinden kopyalanır) ile gelir. Dosya yokken (ücretsiz Apple ID akışı) yetki eklenmez. **CI `prepare-ci.sh` dosyayı her zaman oluşturur** ve `build-ipa.sh` arşivde `aps-environment` olup olmadığını denetler (yoksa durur; yoksa TestFlight'ta bildirim sessizce gelmezdi).
- `AppDelegate.swift`: `UNUserNotificationCenter.delegate = self`; `FirebaseAppDelegateProxyEnabled` **eklenmemiştir** (swizzling açık; `firebase_messaging` 17 APNs belirtecini kendisi kaydeder; `check-ios-static.py` denetler).
- `UIBackgroundModes = remote-notification`: sunucu sessiz/`content-available` push **göndermez** (yalnız alert), bu mod şart değildir ama FCM eklentisi için standarttır ve inceleme sorunu değildir; gerekçe istenirse "uygulama kapalıyken gelen bildirimin tıklamasıyla açılışta mesajı işlemek".
- Dart tarafı iOS için ayrıca incelendi (bölüm 6).

### 4.4 Simge ve açılış

`AppIcon.appiconset`: tüm boyutlar mevcut, **1024x1024 alfasız** (PNG renk türü RGB, `check-ios-static.py` ile doğrulandı); `flutter_launcher_icons` `remove_alpha_ios: true`. iOS 18 koyu/tinted varyantları zorunlu değildir (yok). `LaunchScreen.storyboard`: zemin `#C62A20` (Android `splash_bg` ile aynı), `LaunchImage` 1x1 saydam yer tutucu (varsayılan Flutter logosu değil); Flutter ilk karesi aynı renkte marka ekranını çizer, geçiş kesintisizdir.

### 4.5 Yerelleştirme ve yönlendirme

`CFBundleLocalizations = tr, en, ar`; geliştirme bölgesi `en` (desteklenmeyen cihaz dillerinde yedek İngilizce). iPhone yönlendirmesi yalnız dikey (`main.dart` telefonda zaten kilitler). Arapça sağdan sola düzen Flutter tarafındadır. Dinamik yazı boyutu: Flutter sistem ölçeğini izler; büyük yazıda yerleşimler `MediaQuery.textScalerOf` ile uyarlanır (ör. zaman çizelgesi, kulüp kartları) ama tüm ekranlar iOS'ta gözle sınanmadı.

## 5. Sürüm numaralandırma

`pubspec.yaml` `version: 2.0.3+20003` → `CFBundleShortVersionString = 2.0.3` (`FLUTTER_BUILD_NAME`), `CFBundleVersion = 20003` (`FLUTTER_BUILD_NUMBER`). Aynı kural Android ile ortaktır (MOB3: `kod = major*10000 + minor*100 + patch`). Apple kuralı: **aynı sürüm numarası için her yükleme daha büyük `CFBundleVersion`** olmalıdır; yeni mağaza sürümü için `CFBundleShortVersionString` da artmalıdır. TestFlight'a yalnız yapı numarasını artırarak aynı `2.0.3` için yeniden yükleyebilirsiniz (örn. `2.0.3+20004`, ama Android kuralını bozar; tercih: patch artır). `build-ipa.sh` sürümü pubspec'ten okur ve `--build-name/--build-number` ile verir; `--dart-define=APP_VERSION` sürüm adıyla aynı olur (uygulama içi sürüm kontrolü, push cihaz kaydı). Koddaki varsayılan `APP_VERSION` (`core/app_gate.dart`, `core/push/push_service.dart`) sürüm artınca birlikte güncellenir.

## 6. iOS davranış denetimi (kod okunarak; cihazda DENENMEDİ)

| Konu | Bulgu / yapılan |
|---|---|
| Push yaşam döngüsü | `PushService` iOS'u zaten ele alır: APNs belirteci beklenir (`fetchPushToken`), ön plan sunumu kapalı (uygulama içi şerit), `getInitialMessage`/`onMessageOpenedApp` ile `targetType/targetId` yönlendirmesi (`PushRouter`), sessiz push yok. Düzeltme gerekmedi |
| **Simge rozeti (DÜZELTİLDİ)** | Sunucu APNs `badge` alanına okunmamış bildirim sayısını yazıyor ama istemci okununca rozeti hiç sıfırlamıyordu → iOS'ta rozet takılı kalırdı. Yeni: `lib/core/push/icon_badge.dart` (`AppBadges.notifications` → `bu_kampus/badge` kanalı), `BuNativeBridge.swift` (`UNUserNotificationCenter.setBadgeCount`). Çıkışta 0. Testli (`test/icon_badge_test.dart`) |
| **Yerel ders/sınav hatırlatmaları (EKLENDİ)** | `bu_kampus/notify` kanalı yalnız Android'deydi; iOS'ta hatırlatma ayarı sessizce hiçbir şey yapmıyordu. `BuNativeBridge.swift` `UNUserNotificationCenter` ile zamanlar (mutlak süreli tetikleyici, 64 sınırı Dart'ta 60'a kısıtlı), dokunuşu Dart'a `onTap`/`takeLaunchPayload` ile iletir. **Windows'ta derlenemedi** (yalnız `swiftc -parse` + sahte modüllerle tip denetimi geçti); macOS'ta ilk derlemede doğrulayın. Android'e özgü yöntemler (`setChannelNames`, `pushDiagnostics`, pil ayarı) bilerek yok: Dart `MissingPluginException`'ı yakalıyor, çökme yok |
| **Keychain yeniden kurulumda kalır (DÜZELTİLDİ)** | iOS Keychain kayıtları uygulama silinse de kalır → yeniden kurulumda eski `access/refresh` jetonlarıyla otomatik giriş. Yeni: `lib/core/platform/fresh_install.dart` (`FreshInstallGuard`): uygulama kapsayıcısındaki işaret dosyası yoksa yalnız oturum anahtarlarını siler; `device_id` bilerek korunur (cihaz yasağı aşılmasın). Testli (`test/fresh_install_test.dart`) |
| Video | `video_compress` yalnız Android kopyasıdır (iOS'ta CocoaPods gerekir); iOS'ta sıkıştırma ve poster karesi **yok** (`video_service.dart` gated). Süre/boyut `video_player` ile okunur. Sınır 60 sn/40 MB: kamera kaydı `image_picker` ile orta kalitede (yaklaşık 15-30 MB), **galeriden seçilen uzun/yüksek çözünürlüklü video 40 MB'ı aşarsa kullanıcı "çok büyük" hatası alır**. Bilinen sınırlama; çözüm AVAssetExportSession köprüsü (yapılmadı) |
| Ekran görüntüsü engeli | Android `FLAG_SECURE` karşılığı iOS'ta yoktur (engellenemez). İsteğe bağlı: uygulama değiştiricide içeriği bulanıklaştırma (yapılmadı; gizlilik açısından zorunlu değil, KVKK riski düşük) |
| İzin akışı | `SystemPermissionService` `permission_handler` ile iOS'ta çalışır (`restricted` ve `limited` ele alınır); `photos` durumu `limited`'i granted sayar. Kalıcı ret → "Ayarlar'ı aç" (`openAppSettings`) |
| Güvenli alan / Dynamic Island / klavye | Flutter `SafeArea`/`MediaQuery.viewPadding` kullanıyor; kilitli tasarımda çentik özel işlenmedi, **cihazda gözle doğrulanmalı** (bölüm 9) |
| Geri kaydırma (swipe-back) | `bu_page_transitions.dart` iOS için `CupertinoPageTransitionsBuilder` kullanır; kenardan geri hareketi çalışır. Ekran içi `PopScope`/`BackButton` davranışı `test/back_navigation_test.dart` ile Android için sınanır; iOS'ta elle sınayın |
| Güncelleme kapısı | `openStore` yalnız `https` bağlantı açar; iOS için `store_url_ios` ayarı gerekir (bölüm 3, adım 15) |
| Cihaz platformu | `X-Device-Platform: ios` ve push kaydı `platform=IOS` gider (`device_identity.dart`, `push_service.dart`) |
| Native varlıklar | `image_picker_ios`, `camera_avfoundation`, `mobile_scanner`, `photo_manager`, `gal`, `flutter_contacts`, `firebase_*`, `flutter_secure_storage_darwin`, `url_launcher_ios`, `video_player_avfoundation`, `permission_handler_apple`: **hepsi SwiftPM destekli** (`Package.swift` mevcut, pub önbelleğinde doğrulandı); Podfile/CocoaPods yok. `path_provider_foundation` saf FFI (native assets: `objective_c` paketi macOS'ta clang ile derlenir) |

## 7. App Review uyumu

1. **1.2 Kullanıcı içeriği (UGC).** Apple'ın dört şartı ve karşılıkları: (a) *uygunsuz içerik filtresi*: herkese açık metinlerde `ProfanityFilter` (sohbet hariç), görsel hash engel listesi (`ContentBlocklist`); (b) *raporlama + zamanında yanıt*: gönderi/mesaj/kullanıcı/kulüp/etkinlik raporu (`ReportSheet`, `post_actions.dart` ve 9 diğer çağrı yeri; `POST /api/reports`), yönetici kuyruğu, 3 bağımsız rapor → otomatik gizleme, karar bildirimi ([MODERATION.md](MODERATION.md)); *24 saat taahhüdü K4'tür*; (c) *kullanıcı engelleme*: `POST/DELETE /users/{id}/block` (profil, gönderi menüsü, sohbet bilgisi, `blocked_users_page.dart`); (d) *iletişim bilgisi*: uygulama içi Destek + web destek sayfası + destek e-postası. Topluluk Kuralları sözleşme olarak kayıtta onaylatılır.
2. **5.1.1(v) Hesap silme.** Uygulama içi: Profil > Verilerim ve hesap > Hesabı sil (`profil2_delete_account_page.dart`, `DELETE /api/users/me`, anonimleştirme); web: `https://bukampus.com.tr/tr/delete-account`. Apple "hesap silme bağlantısı"nı inceleme notunda görmek ister (REVIEW_NOTES'ta var).
3. **4.8 Sign in with Apple.** **Gerekmez**: üçüncü taraf/sosyal giriş yok (yalnız kurum e-postası + parola; `pubspec.yaml`'da `google_sign_in` vb. yok). Yeni bir sosyal giriş eklenirse bu kural devreye girer.
4. **5.1.1 / 5.1.2 Gizlilik.** Gizlilik politikası URL'i zorunlu: `https://bukampus.com.tr/tr/privacy` (`web/src/routes.tsx` rotası `privacy`, 3 dil; canlı sayfa yalnızca kodda doğrulandı, **canlıya istek atılmadı**, yayın öncesi tarayıcıdan açın). İzin metinleri amaç belirtir; izinler isteğe bağlıdır (rehber reddedilirse özellik gizlenir). Üçüncü taraf: Firebase Cloud Messaging/APNs (bildirim iletimi, [legal/privacy_tr.md](legal/privacy_tr.md)). İzleme (ATT) yok.
5. **2.1 Demo hesabı / 5.1.1(vi)?** Kayıt yalnız `bingol.edu.tr` olduğundan K5'teki hazır hesap şart. Hesap oluşturma: `bash scripts/ops/create-review-account.sh` (canlıda), `--delete` ile inceleme bitince silin. Aynı hesapla iki cihazdan girilirse eski oturum kapanır (tek oturum kuralı): inceleyici ile siz aynı anda kullanmayın.
6. **Yaş derecesi.** 2025'ten beri Apple'ın yeni soru seti (13+/16+/18+ dahil): içerik türleri "yok" (uygulama içerik üretmiyor), **"Kullanıcı tarafından oluşturulan içerik" = Evet, "Mesajlaşma ve sohbet" = Evet, "Kontrolsüz web erişimi" = Hayır** (haber bağlantıları dış tarayıcıda), reklam = Hayır, kumar = Hayır. Sistem 13+ veya 16+ civarı hesaplar (kesin sonuç Apple'ındır). Kullanım Koşulları 18 yaş altına yalnız yasal temsilci izniyle izin veriyor ([LEGAL_NOTES.md](LEGAL_NOTES.md) madde 10); Connect'te daha yüksek asgari yaş seçilebiliyorsa "16+" ya da hedef kitle üniversite olduğundan "18+" tercih etmek 1.2 incelemesini kolaylaştırır. **Karar K6.**
7. **Ekran görüntüleri.** iPhone-only: yalnız **6.9" iPhone** (1320x2868; ya da 1290x2796) grubu zorunlu; diğer boyutlar Apple tarafından ölçeklenir (Connect'in o günkü zorunlu listesini kontrol edin). Üretim: ekran görüntüsü testi Play için 1080x1920 üretir (`test/store_shots_test.dart`, boyut/oran Apple'a uymaz); Apple için **iOS simülatörü** (iPhone 17 Pro Max) + `scripts/ios/simulator-shots.sh` (9:41 durum çubuğu); sahte tohum veri ([DEV_SEED.md](DEV_SEED.md)), gerçek kişi yok, üniversite logosu yok. Ayrıntı: [ios-store/SCREENSHOTS.md](ios-store/SCREENSHOTS.md).
8. **4.1 Taklit / resmî değil beyanı.** Mağaza açıklamasının ilk paragrafında "bağımsız ve resmî olmayan" yazar (ios-store metinleri). **Uygulama içinde** yalnız "Bağımsız öğrenci uygulaması" alt başlığı (`p02BrandSub`, giriş/ana ekran) vardır; Ayarlar/Hakkında'da açık "Bingöl Üniversitesi ile kurumsal bağlantısı yoktur" cümlesi **yok**. Öneri (yapılmadı: ARB ortak dosya, başka ajanlar yazıyor): `Profil > Hakkında` sayfasına üç dilli bir satır. App Review notuna da yazıldı.

## 8. Red riskleri ve önlemler

| Risk | Olasılık | Önlem |
|---|---|---|
| Kurum adı/marka (4.1, 5.2) | Orta-yüksek | Alt başlıkta "bağımsız"; açıklamada resmî olmadığı; üniversite logosu yok; **destek mektubu (K3)**; yedek ad "BU Kampus" |
| Demo hesap çalışmıyor (2.1) | Yüksek (en sık ret) | K5; incelemeden hemen önce `create-review-account.sh --status`; inceleme notunda e-posta/parola; tek oturum uyarısı |
| UGC moderasyon yanıt süresi (1.2) | Orta | K4; yönetici panelinde rapor kuyruğu günlük izlenir; inceleme notunda akışlar ve ekran yolları |
| Kısıtlı kitle ("yalnız bingol.edu.tr") | Orta | Notta açıkça: üniversite topluluğu uygulaması; kayıt açık ama alan adıyla sınırlı; demo hesap sağlanır. Gerekirse "Unlisted App" (bağlantı ile dağıtım) başvurusu alternatif |
| İzin metni / gereksiz izin (5.1.1) | Düşük | Metinler amaç + veri akışını söyler; kullanılmayan izin yok (otomatik denetim) |
| Gizlilik etiketi uyumsuz (5.1.2) | Orta | `PrivacyInfo.xcprivacy` ile Connect cevapları birebir aynı ([ios-store/APP_PRIVACY.md](ios-store/APP_PRIVACY.md)); IP adresi günlüğü (90 gün) "konum" olarak beyan edilmedi: güvenlik amaçlı, hukuk görüşü alın |
| Push çalışmıyor (kabul testi) | Orta | TestFlight'ta gerçek cihazla doğrulayın (bölüm 3, adım 13); `aps-environment` arşiv denetimi CI'da |
| Çökme (2.1) | Düşük-orta | Yeni Swift köprüsü derlenmedi: ilk macOS koşusunu inceleme gönderiminden ÖNCE yapın; `CrashReporter` iOS'ta da çalışır |
| Arapça çeviri kalitesi | Düşük | Arapça mağaza metni ve izin metinleri taslak; incelemeden önce anadil kontrolü ya da ilk sürümde yalnız tr+en |
| İçerik hakkı (üçüncü taraf içerik, 5.2) | Orta | K9; kaynağı belirtin; izin mektubu |
| Eski Xcode | Düşük | `build-ipa.sh` Xcode 26+ ister; `macos-latest` görüntüsü eskiyse `maxim-lobanov/setup-xcode` ile sabitleyin |

## 9. Bu repoda yapılanlar / yapılamayanlar

| Madde | Durum | Kanıt / not |
|---|---|---|
| `PrivacyInfo.xcprivacy` + Xcode projesine bağlama | YAPILDI, dosya düzeyinde doğrulandı | `scripts/ios/check-ios-static.py` (plist ayrışır, neden kodları geçerli, Resources fazında). Xcode'da derlenmedi |
| Eklenti gizlilik manifestleri | İNCELENDİ | `firebase_messaging` (UserDefaults CA92.1), `permission_handler_apple` (1C8F.1), `photo_manager` (FileTimestamp C617.1) ve çoğu SwiftPM eklentisi kendi manifestini taşır; `firebase_core` manifesti pub paketinde yok (Firebase iOS SDK kendi manifestini getirir). Uygulama düzeyinde FileTimestamp C617.1 (disk önbelleği) + SystemBootTime 35F9.1 (Dart zamanlayıcıları) bildirildi. Birleşik rapor Xcode > Product > Archive > "Generate Privacy Report" ile macOS'ta alınmalı |
| Info.plist denetimi, 3 dilli izin metinleri, şifreleme beyanı, iPhone-only | YAPILDI | bölüm 4 |
| Entitlements bağlama (Debug/Profile=development, Release=production) | DOĞRULANDI (dosya) | pbxproj 3/3; CI arşiv denetimi eklendi |
| `GoogleService-Info.plist` CI yazımı | YAPILDI (macOS'ta çalışmadı) | `scripts/ios/prepare-ci.sh`; gitignore: `mobile/.gitignore` |
| Simge alfasız, açılış ekranı marka tutarlı | DOĞRULANDI | PNG kanal türü okundu |
| iOS'a özgü kod hataları | 3 DÜZELTME | rozet, yerel hatırlatma köprüsü, Keychain temizliği (bölüm 6); 2 yeni test dosyası geçti, `push_*` ve `robustness` testleri geçti |
| Swift köprüsü derlemesi | **YAPILAMADI** | `swiftc -parse` temiz; sahte modüllerle `-typecheck` temiz; gerçek UIKit/Flutter/UserNotifications ile derlenmedi |
| macOS CI hatları | YAZILDI, **ÇALIŞTIRILMADI** | `.github/workflows/ios-release.yml` ve `codemagic.yaml` YAML geçerli (`scripts/check-workflows.js`); `build-ipa.sh`, `upload-testflight.sh`, `prepare-ci.sh` `bash -n` temiz; fastlane Ruby'si denenmedi (Windows'ta ruby yok) |
| Archive/İmza/IPA/TestFlight/App Store Connect | **YAPILAMADI** | macOS + Apple hesabı gerekir |
| Cihazda: çentik/Dynamic Island, swipe-back, klavye, yazı ölçeği, izin akışı, push | **YAPILAMADI** | gerçek iPhone gerekir ([DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md)'e iOS satırı ekleyin) |
| Mağaza metni, App Privacy, inceleme notu, ekran görüntüsü kılavuzu | YAZILDI | [ios-store/](ios-store/README.md) (tr/en/ar) |
| Bundle id değişikliği | **YAPILMADI** (karar bekliyor) | K1 |

**İlk macOS koşusunda bakılacaklar** (en olası ilk hatalar): (1) `permission_handler_apple` manifesti uygulama dizinini bulamazsa tüm izinler "denied" döner → CI çıktısında `PERMISSION_HANDLER_VERBOSE=1`; (2) `BuNativeBridge.swift` derleme hatası (Flutter 3.47 şablonuna göre `FlutterImplicitEngineBridge` imzaları) → `didInitializeImplicitFlutterEngine` içindeki `registrar(forPlugin:)` satırı; (3) bulut imzalama izni (API anahtarı rolü); (4) Xcode sürümü; (5) `flutter build ios --config-only` bayrak uyumu; (6) native assets (`objective_c`) derlemesi.

## 10. Doğrulama komutları

```bash
# Windows/macOS/Linux (Python 3): dosya düzeyi kontrol, 0 hata beklenir
python -I -X utf8 scripts/ios/check-ios-static.py
# İş akışı YAML'ı
node scripts/check-workflows.js
# Testler (Windows, C:\bu_mobile ASCII bağlantısından)
flutter test test/icon_badge_test.dart test/fresh_install_test.dart test/push_service_test.dart
# macOS: izin makrolarının çözümü
cd mobile && PERMISSION_HANDLER_VERBOSE=1 flutter build ios --config-only --release
# macOS: arşivdeki yetkiler (aps-environment=production bekleniyor)
codesign -d --entitlements :- mobile/build/ios-release/Runner.xcarchive/Products/Applications/Runner.app
```
