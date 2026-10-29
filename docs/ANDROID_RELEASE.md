# Android üretim (release) rehberi

Paket (applicationId): `tr.com.bukampus.app`, ad "BÜ Kampüs". Kaynak paketi/`namespace` bilerek `edu.bingol.bu_kampus` kalır (Kotlin `MainActivity` vb.; manifestte `.MainActivity` göreli yazılıdır, dış kimliği etkilemez). iOS bundle id (`edu.bingol.buKampus`) bu değişiklikte değişmedi, ayrı karardır. Tüm komutlar `C:\bu_mobile` (mobile/ klasörünün ASCII bağlantısı) içinde, PowerShell'de çalışır.

Ortam (her oturumda):

```powershell
$env:JAVA_HOME='C:\android\jdk17'; $env:ANDROID_HOME='C:\android\sdk'; $env:ANDROID_SDK_ROOT='C:\android\sdk'
$env:PUB_CACHE='C:\pubcache'; $env:GRADLE_USER_HOME='C:\gradlehome'
$env:PATH='C:\android\jdk17\bin;C:\android\sdk\platform-tools;C:\src\flutter\bin;C:\Program Files\Git\cmd;'+$env:PATH
Set-Location C:\bu_mobile
```

## 1. Sürüm

`pubspec.yaml` içindeki `version: <ad>+<kod>` -> `versionName=<ad>`, `versionCode=<kod>`. Play aynı `versionCode`'u iki kez kabul etmez ve düşük koda inemez. **Kural (MOB3):** `kod = major*10000 + minor*100 + patch` (2.0.2 -> `20002`, 2.1.0 -> `20100`, 3.0.0 -> `30000`). Her Play yüklemesi yeni bir sürüm adı (en az patch artışı) ister; böylece kod hep benzersiz ve büyük kalır, `+N` elle oynanmaz (patch en çok 99, minor en çok 99). Dosya adı sürümü değiştirmez: AAB'yi yeniden adlandırmak `versionCode`'u değiştirmez, kod yalnız `pubspec.yaml`'dan gelir. Uygulama içi sürüm kontrolü (`/api/app/version`, ayarlar "Sürüm" satırı, push cihaz kaydı) için `--dart-define=APP_VERSION=<ad>` verin (pubspec'in ad kısmıyla aynı); koddaki varsayılanlar (`core/app_gate.dart`, `core/push/push_service.dart`) da aynı adı taşır, sürüm artınca üçünü birlikte güncelleyin.

## 2. İmzalama (keystore)

Upload keystore'u **MOB1'de üretildi** (bölüm 8.1). Dosya ve parolalar repo ve OneDrive dışındadır, git'e girmez (`*.jks`, `android/key.properties` gitignore'dadır; `git check-ignore -v mobile/android/key.properties` ile doğrulandı). **Yedekleyin** (parola yöneticisi + şifreli çevrimdışı kopya).

Anahtar kaydı (MOB1): `C:\Users\Toprak Çevik\bu-secrets\bu-upload-keystore.jks` (PKCS12, RSA 4096, alias `bu-upload`, geçerlilik 2054-03-16). Parolalar ve parmak izleri aynı klasörde `android-signing.txt` içindedir. `mobile/android/key.properties` bu dosyayı mutlak yolla gösterir (yerel, gitignore'da). Şablon: `android/key.properties.example` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`). Gradle `key.properties`'i **UTF-8** okur (yol `Çevik` gibi Türkçe karakter içerebilir); dosyada alan eksikse ya da `storeFile` yoksa derleme **hata ile durur** (sessizce debug'a düşmez).

**Karar:** `key.properties` yoksa release derlemesi durmaz, **debug anahtarıyla imzalanır ve Gradle net uyarı basar** ("release DEBUG anahtariyla imzalaniyor"). Bu çıktı elden test içindir, **Google Play'e yüklenemez**. Üretim derlemesinde uyarıyı görüyorsanız `key.properties` eksik demektir. Play App Signing kullanıldığında bu anahtar "upload key" olur.

## 3. Derleme komutları

**Üretim (Play, AAB)** — API adresi `https://` olmak ZORUNDA (aksi halde uygulama açılışta yapılandırma hatası ekranı gösterir; Android tarafı da cleartext'i kapalı tutar):

```powershell
# --split-debug-info dizini ASCII olmalı (Dart AOT, yolda "Ç" varsa dosya yazamaz); sonra bu-secrets'e kopyalanır
flutter build appbundle --release --obfuscate --split-debug-info=C:\bu_symbols_1.0.0 `
  --dart-define=API_BASE=https://bukampus.com.tr --dart-define=APP_VERSION=1.0.0
flutter build apk --release --obfuscate --split-debug-info=C:\bu_symbols_1.0.0 `
  --dart-define=API_BASE=https://bukampus.com.tr --dart-define=APP_VERSION=1.0.0
# çıktılar: build\app\outputs\bundle\release\app-release.aab  ve  build\app\outputs\flutter-apk\app-release.apk
# (arm64-v8a + armeabi-v7a + x86_64 hepsi içinde; fat APK büyüktür, telefona elden kurulum için yeter)
```

WebSocket adresi ayrı bir define değildir: `API_BASE`'ten türetilir (`https` -> `wss://bukampus.com.tr/ws`, `ChatRealtime`).

Derlemeden sonra: AAB/APK'yı `C:\Users\Toprak Çevik\bu-release\bu-kampus-<ad>+<kod>.aab|.apk` olarak kopyalayın; `C:\bu_symbols_<ad>` içeriğini (`app.android-*.symbols`) ve `build\app\outputs\mapping\release\mapping.txt` dosyasını `C:\Users\Toprak Çevik\bu-secrets\symbols-<ad>\` altına koyun (çökme yığın izlerini çözmek için; **kaybetmeyin**, yedekleyin). Bu klasörler repoda değildir.

**Yerel test / staging (elden kurulum, http)** — cleartext yalnızca bu bayrakla açılır:

```powershell
flutter build apk --release --target-platform android-arm64 `
  --dart-define=API_BASE=http://192.168.1.220:8080 --dart-define=ALLOW_INSECURE_API=true --dart-define=APP_VERSION=1.0.0
```

`ALLOW_INSECURE_API=true` hem Dart tarafındaki https denetimini gevşetir hem Gradle'da manifest yer tutucusunu `usesCleartext=true` yapar (aynı bayrak `-Pbu.cleartext=true` ile de verilebilir). Bayrak yoksa cleartext KAPALIDIR. Debug/profile derlemelerinde `src/debug|profile/res/xml/network_security_config.xml` yerel geliştirme için cleartext'e izin verir; release'te bu dosya yoktur.

Çıktıları sembol/haritalamayla yayımlamak için (isteğe bağlı): `--obfuscate --split-debug-info=build\symbols` ekleyin ve `build\symbols` klasörünü saklayın.

## 4. Sertleştirme özeti

- R8 + kaynak küçültme açık (`proguard-rules.pro`: Flutter, Firebase, ML Kit, camera/media3, video_compress, secure storage, permission_handler vb.).
- `allowBackup=false`, `dataExtractionRules` + `fullBackupContent` her şeyi dışarıda bırakır (token'lar secure storage'da, yedekten geri yüklenmez).
- `FLAG_SECURE` (MainActivity) korunur; `debuggable=false`.
- `targetSdk=36` (Android 16), `compileSdk=37`, `minSdk` Flutter varsayılanı (24). Edge-to-edge, öngörülü geri (`enableOnBackInvokedCallback`) açık. Tablet (>=600dp) yönlendirmesi serbest, telefonda dikey kilit (`main.dart`).
- Push: `chat` / `event` / `announcement` bildirim kanalları `MainActivity` içinde oluşturulur (sunucu bu kimlikleri gönderir); varsayılan kanal `announcement`, küçük simge `ic_stat_bu`. `google-services.json` yoksa Gradle eklentisi uygulanmaz ve push sessizce kapalı kalır (uygulama çökmez; `PushService` try/catch).
- Android 12+ sistem açılış ekranı marka renginde (`values-v31/styles.xml`).

## 5. İzinler

| İzin | Neden |
|---|---|
| `INTERNET` | API, WebSocket, görseller |
| `POST_NOTIFICATIONS` | Push bildirimi (Android 13+) |
| `READ_CONTACTS` | Rehber eşleştirme (yalnız e-posta özetleri/hash sunucuya gider) |
| `CAMERA` | QR yoklama, fotoğraf/video çekimi |
| `RECORD_AUDIO` | Video/ses kaydı |
| `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO` | Sohbet galeri seçici (Android 13+) |
| `READ_EXTERNAL_STORAGE` (<=32) | Aynı, Android 12 ve altı |
| `WRITE_EXTERNAL_STORAGE` (<=28) | Görseli galeriye kaydetme, Android 9 ve altı |

Kaldırıldı: `ACCESS_COARSE_LOCATION` (kodda konum özelliği yoktu) ve konum izni satırı/`AppPermission.location`. `video_compress` eklentisinin kendi manifestindeki kısıtsız `WRITE_EXTERNAL_STORAGE` de kaldırıldı (uygulama-özel dizin kullanır, izin gerekmez). `uses-feature` camera, autofocus, microphone, touchscreen `required=false`.

Hukuk notu (dokunulmadı): `docs/legal/explicit_consent_tr.md` "Madde 2. Yaklaşık konum" bölümü ve `privacy_tr.md` içindeki konum satırı artık uygulamada bulunmayan bir izni anlatıyor; metin gözden geçirilmelidir (EN sürümleri dahil).

## 6. Play Console "Veri güvenliği" beyanı için veri listesi

Toplanan/paylaşılan veriler (hepsi aktarımda şifreli, HTTPS; hesap silme uygulama içinde var):

- Kişisel bilgiler: ad-soyad, e-posta (bingol.edu.tr), okul numarası, bölüm; profil fotoğrafı.
- Mesajlar: sohbet mesajları ve gönderilen fotoğraf/video (sunucuda zarf şifreleme ile saklanır).
- Fotoğraf ve videolar: kullanıcının seçtiği/çektiği içerikler (gönderi, sohbet, profil).
- Kişiler: rehberden yalnızca e-posta özetleri (hash) eşleştirme için gönderilir, saklanmaz; ham rehber sunucuya gitmez.
- Uygulama etkinliği/analitik: toplulaştırılmış kullanım olayları (180 gün), çökme türü (içerik/kişisel veri yok).
- Cihaz veya diğer kimlikler (**"Device or other IDs" işaretlenir**): (1) **FCM bildirim belirteci** (+ platform, uygulama sürümü, dil); (2) **uygulama-özel rastgele cihaz tanımlayıcısı**: mobil, ilk açılışta ürettiği rastgele UUID'yi (Keychain/Keystore'da durur; IMEI/ANDROID_ID/reklam kimliği OKUNMAZ) her istekte `X-Device-Id` başlığı ve STOMP `device-id` ile gönderir. Amaç yalnızca güvenlik: kötüye kullanım önleme ve yasaklı kullanıcıların cihaz engelini dolanmasını engelleme (`accessban`). Sunucu ham değeri saklamaz; HMAC-SHA256 özetini (`ClientContexts`) `user_device_log` tablosunda **90 gün** tutar. Reklam/izleme/analitik amacıyla kullanılmaz, üçüncü taraflarla paylaşılmaz. Data Safety: Veri türü "Device or other IDs" = toplanır, paylaşılmaz, amaç "Fraud prevention, security, and compliance" (+ bildirimler için "App functionality"); zorunlu (kullanıcı kapatamaz). Apple App Privacy'de de "Device ID" = "Not linked to tracking", amaç "App functionality / security" olarak beyan edilir ve gizlilik politikasında anılır (bkz. `docs/legal/privacy_tr.md` bölüm 6).
- Konum: **toplanmaz** (izin kaldırıldı).
- Finansal bilgi, sağlık, web geçmişi, takvim, SMS: yok.

Mağaza gereksinimleri: hedef API 36 (karşılanıyor); 64-bit (arm64-v8a, AAB x86_64 + armeabi-v7a de içerir); gizlilik politikası URL'si (herkese açık web sitesindeki `/legal/privacy`; Play Console'a elle girilir); hesap silme: uygulama içinde mevcut, ayrıca web için silme talebi URL'si Play'in "Hesap silme" formunda istenir; içerik derecelendirme anketi (kullanıcı içeriği, sohbet) ve "kullanıcı tarafından oluşturulan içerik" moderasyon/raporlama açıklaması (uygulamada rapor/engelle var).

## 7. Bilinen sınırlar / riskler

- `google-services.json` git'te değildir; derleme makinesinde `mobile/android/app/google-services.json` bulunmalı, aksi halde push kapalı derlenir (uyarı basılır).
- Firebase, video_compress, photo_manager eklentileri Kotlin Gradle Plugin uyguluyor; Flutter ileride "built-in Kotlin" zorunlu kılacak (derleme uyarısı).
- Gerçek cihaz/R8 testi: üretim APK'sı kurulduktan sonra giriş, sohbet (STOMP), QR tarama, video seçip sıkıştırma, rehber eşleştirme, push alma elle denenmelidir (R8 yansıma çökmeleri ancak çalışırken görülür).
- Flutter test paketinde (visual_a erişilebilirlik) önceden var olan dokunma hedefi (44dp) hataları vardır; bu belgedeki değişikliklerle ilgili değildir.

## 8. Upload keystore, Play App Signing ve kapalı test (MOB1)

Play Console adımları sırayla: [store/PLAY_CONSOLE_STEPS.md](store/PLAY_CONSOLE_STEPS.md).

### 8.1 Upload keystore (MOB1'de üretildi)

- Dosya: `C:\Users\Toprak Çevik\bu-secrets\bu-upload-keystore.jks` (OneDrive dışı), alias `bu-upload`, PKCS12, RSA 4096, geçerlilik 2026-10-29 .. 2054-03-16. Parola ve parmak izi kaydı: aynı klasörde `android-signing.txt` (gizli, **yedekleyin**; repoya/rapora/e-postaya yazmayın). `generated-secrets.txt` bu işle ilgisizdir.
- Upload sertifikası parmak izleri (açık bilgi; Firebase/Play karşılaştırması için):
  - SHA-1: `A9:8E:0A:5A:B3:96:03:E2:FC:DD:11:46:7A:A9:F8:97:DB:91:ED:BC`
  - SHA-256: `87:84:5C:AD:76:62:18:44:1F:02:DD:4F:C0:8E:37:70:23:05:41:1A:9D:87:CC:2A:E7:D8:79:3E:7B:CC:50:11`
- **Play App Signing** kullanılır: siz AAB'yi bu upload anahtarıyla imzalarsınız, Google dağıtım APK'larını kendi anahtarıyla yeniden imzalar. Upload anahtarı kaybolursa Play Console'dan "upload key sıfırlama" talep edilir (günler sürer); yine de yedeği tutun. PKCS12'de `keyPassword` = `storePassword` olmalıdır.
- Mağazadan kurulan sürümün gerçek imzası Play'in "app signing key" sertifikasıdır (Console > Kurulum > Uygulama bütünlüğü). **Bu SHA-1/SHA-256'yı** Firebase Android uygulamasına ve (kısıt varsa) Google Cloud API anahtarına ekleyin ([PUSH_SETUP.md](PUSH_SETUP.md) bölüm 6); aksi halde mağaza sürümünde push/Firebase çağrıları bloklanabilir. Elden kurulan APK ise yukarıdaki upload parmak iziyle imzalıdır (Firebase'e o da eklenebilir).
- Yeni makinede yeniden üretme gerekirse: `keytool -genkeypair -keystore <yol>.jks -storetype PKCS12 -alias bu-upload -keyalg RSA -keysize 4096 -validity 10000` (parolaları kendiniz seçin); Play'e daha önce başka anahtarla yüklediyseniz anahtar değiştirilemez, sıfırlama gerekir.

### 8.2 Sürüm artırma
`mobile/pubspec.yaml` `version: 1.0.0+1`: her yeni yüklemede `+N` artar (ad değişmese de), `APP_VERSION` define'ı ad ile aynı olur (sunucu `GET /api/app/version` zorunlu sürüm denetimi bunu kullanır).

### 8.3 Üretim derlemesi (MOB1, 2026-10-29, koşturulan komutlar)

Bölüm 3'teki iki komut, `C:\bu_mobile` içinde, `key.properties` ile. Sonuç:

| Çıktı | Boyut | Konum |
|---|---|---|
| AAB | 83.424.605 bayt (79,6 MB) | `C:\Users\Toprak Çevik\bu-release\bu-kampus-1.0.0+1.aab` |
| APK (fat, 3 ABI) | 92.406.626 bayt (88,1 MB) | `C:\Users\Toprak Çevik\bu-release\bu-kampus-1.0.0+1.apk` |
| Hata ayıklama sembolleri + R8 eşleme | ~16 MB | `C:\Users\Toprak Çevik\bu-secrets\symbols-1.0.0\` |

Doğrulananlar:
- AAB: `keytool -printcert -jarfile` -> `Owner: CN=BU Kampus Upload`, SHA-1/SHA-256 yukarıdakiyle aynı.
- APK: `apksigner verify --print-certs` -> `Verifies`, v2 şeması (minSdk 24 için yeter), sertifika SHA-256 `87845cad...5011` = keystore.
- `aapt2 dump badging` (ilk derleme, ESKİ paket adı `edu.bingol.bu_kampus`; Play reddetti, bkz. 8.4): `versionCode=1`, `versionName=1.0.0`, `minSdk=24`, `targetSdk=36`, `compileSdk=37`, etiket "BÜ Kampüs".
- Manifest: `usesCleartextTraffic=false`, `allowBackup=false`; izinler bölüm 5 + eklentilerden gelen `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `RECEIVE_BOOT_COMPLETED`, `com.google.android.c2dm.permission.RECEIVE` (FCM) ve `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; konum izni yok.
- `libapp.so` (3 ABI) içinde `https://bukampus.com.tr` ve `https://bukampus.com.tr/api` var; `10.0.2.2`, `192.168.*`, `localhost`, `127.0.0.1` yok.
- Firebase (ilk derleme, eski paket adıyla): `google-services.json` paket adı o günkü `edu.bingol.bu_kampus` ile uyumluydu, eklenti release'de uygulandı (APK kaynaklarında `google_app_id`, `gcm_defaultSenderId`, proje kimliği var). **FCM sunucu kimliği sunucuya girilmeden push gitmez** ([PUSH_SETUP.md](PUSH_SETUP.md)).
- Canlı uçlar (salt-okur, `Accept-Language`, `X-Device-Id` ile): `GET /api/status`, `/api/app/version?platform=android&version=1.0.0`, `/api/app/info`, `/api/menu/today` = 200; `wss://bukampus.com.tr/ws` WebSocket yükseltmesi 101 döndü.
- `flutter analyze`: sorun yok; `flutter test`: 3300 test geçti (hata yok).

**Doğrulanmadı:** APK'nın gerçek bir telefonda/emülatörde çalıştırılması (giriş, sohbet, QR, video sıkıştırma, rehber, R8 yansıma çökmeleri), gerçek push alımı, AAB'nin Play'e yüklenmesi.

Derleme notları: `--split-debug-info` yolu ASCII olmalıdır (aksi halde "Unable to write file ... app.android-arm.symbols"); `key.properties` yolunda Türkçe karakter UTF-8 okunur (build.gradle.kts). `mobile/android/build/` yerel Gradle çıktısıdır, commit'lenmez.

### 8.4 Paket adı değişikliği (MOB2, 2026-10-29)

Play Console'da uygulama **`tr.com.bukampus.app`** adıyla oluşturuldu; MOB1 AAB'si `edu.bingol.bu_kampus` taşıdığı için Play reddetti ("paket adı tr.com.bukampus.app olmalı"). Yapılanlar:

- `mobile/android/app/build.gradle.kts`: `applicationId = "tr.com.bukampus.app"`. `namespace` ve Kotlin kaynak paketi (`edu/bingol/bu_kampus/`) **değişmedi** (R sınıfı ve `.MainActivity`/`.ReminderReceiver`/`.BootReceiver` göreli adları namespace'e çözülür; dış kimlik applicationId'dir).
- `LocalReminders.kt`: yerel hatırlatma intent eylemi `edu.bingol.bu_kampus.REMINDER` -> `tr.com.bukampus.app.REMINDER` (yalnız uygulama içi, açık hedefli broadcast; Play'e hiç yüklenmediği için geriye uyum gerekmez).
- Başka paket adına bağlı Android öğesi yok: FileProvider/ContentProvider/App Links/derin bağlantı yok; bildirim kanal kimlikleri paket önekli değil; `proguard-rules.pro` paket adı geçirmez.
- Sürüm `1.0.0+1` kalır (Play'e hiç yüklenmedi).
- **Firebase:** Firebase konsolunda (proje `bu-kamp`) Android uygulaması **`tr.com.bukampus.app`** olarak eklenmeli (SHA-1/SHA-256: Play App Signing sonrası Play Console > Uygulama bütünlüğü sayfasındaki uygulama imzalama sertifikası parmak izleri de eklenir; yükleme anahtarı parmak izi de eklenebilir). Yeni `google-services.json` indirilip `mobile/android/app/google-services.json` üstüne konur (eski istemci içinde kalabilir). Dosya paket adıyla eşleşmezse google-services eklentisi derlemeyi reddeder ("No matching client found for package name"). API anahtarı kısıtlaması da yeni paket adı için güncellenir ([PUSH_SETUP.md](PUSH_SETUP.md)).
- Derleme komutları bölüm 3'tekiyle aynıdır; çıktı adları değişmez, eski paket adlı dosyalar üstüne yazılır.

**Yeniden derleme sonucu (MOB2, `tr.com.bukampus.app`, bölüm 3'teki iki komut koşturuldu):**

| Çıktı | Boyut | Konum |
|---|---|---|
| AAB | 83.425.713 bayt (79,6 MB) | `C:\Users\Toprak Çevik\bu-release\bu-kampus-1.0.0+1.aab` |
| APK (fat, 3 ABI) | 92.406.654 bayt (88,1 MB) | `C:\Users\Toprak Çevik\bu-release\bu-kampus-1.0.0+1.apk` |
| Semboller + `r8-mapping.txt` | ~66 MB | `C:\Users\Toprak Çevik\bu-secrets\symbols-1.0.0\` |

Doğrulananlar: `aapt2 dump badging`: paket `tr.com.bukampus.app`, `versionCode=1`, `versionName=1.0.0`, `targetSdk=36`, etiket "BÜ Kampüs". Birleşik manifestte `package="tr.com.bukampus.app"`, `usesCleartextTraffic=false`, `allowBackup=false`; sınıf adları namespace'ten tam çözülür (`edu.bingol.bu_kampus.MainActivity`, `...ReminderReceiver`). AAB manifestinde (ham tarama) yeni paket adı var; `bundletool` makinede yok, AAB manifesti onunla dump edilmedi. APK `apksigner verify`: `Verifies` (v2); AAB `keytool -printcert -jarfile` ve APK sertifika SHA-256 = yükleme anahtarı `87:84:5C:AD:...:CC:50:11`. `libapp.so` (3 ABI): `https://bukampus.com.tr` ve `/api` var; `http://localhost`, `http://10.`, `192.168.`, `127.0.0.1`, `10.0.2.2` yok (çıplak `localhost` dizgisi Flutter çerçevesinden gelir, MOB1 derlemesinde de aynı). Firebase kaynakları (APK): `google_app_id` = `1:247885082799:android:041c27e2...` (yeni istemci), `project_id` = `bu-kamp`, `gcm_defaultSenderId` = `247885082799`; eski istemci kimliği pakette yok. `flutter analyze`: sorun yok; `flutter test`: 3300 test geçti.

Not: izlenen `google-services.json` artık yalnız `tr.com.bukampus.app` istemcisini içerir. Eski adla (`edu.bingol.bu_kampus`) derleme gerekirse eklenti "No matching client" hatası verir; geliştirmede de yeni `applicationId` kullanılır (emülatörde eski kurulu uygulama ayrı bir uygulama olarak kalır, kaldırın).

**Doğrulanmadı:** cihazda/emülatörde çalıştırma, Play'in yeni AAB'yi kabul etmesi, gerçek push alımı (FCM sunucu kimliği ve Play App Signing parmak izlerinin Firebase'e eklenmesi sizde).

### 8.5 Sürüm kodu düzeltmesi (MOB3, 2026-10-29)

Play Console, yüklenen AAB için "1 sürüm kodu daha önce kullanıldı" dedi: dosya `bu-kampus-2.0.2.aab` adına çevrilmişti ama içi `1.0.0+1` idi (dosya adı sürümü değiştirmez). Sürüm `2.0.2+20002` yapıldı (kural bölüm 1), ayarlar ekranındaki sabit "1.0.0" `appVersion` sabitine bağlandı, `APP_VERSION` varsayılanları `2.0.2` oldu.

