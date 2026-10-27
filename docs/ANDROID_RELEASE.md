# Android üretim (release) rehberi

Paket: `edu.bingol.bu_kampus`, ad "BÜ Kampüs". Tüm komutlar `C:\bu_mobile` (mobile/ klasörünün ASCII bağlantısı) içinde, PowerShell'de çalışır.

Ortam (her oturumda):

```powershell
$env:JAVA_HOME='C:\android\jdk17'; $env:ANDROID_HOME='C:\android\sdk'; $env:ANDROID_SDK_ROOT='C:\android\sdk'
$env:PUB_CACHE='C:\pubcache'; $env:GRADLE_USER_HOME='C:\gradlehome'
$env:PATH='C:\android\jdk17\bin;C:\android\sdk\platform-tools;C:\src\flutter\bin;C:\Program Files\Git\cmd;'+$env:PATH
Set-Location C:\bu_mobile
```

## 1. Sürüm

`pubspec.yaml` içindeki `version: 1.0.0+1` -> `versionName=1.0.0`, `versionCode=1`. **Her mağaza yüklemesinde `+N` artırılır** (Play aynı `versionCode`'u iki kez kabul etmez). Uygulama içi sürüm kontrolü (`/api/app/info`) için ayrıca `--dart-define=APP_VERSION=1.0.0` verin (pubspec ile aynı değer).

## 2. İmzalama (keystore)

Keystore'u **yalnızca siz üretirsiniz**; dosyayı ve şifreleri kimseyle paylaşmayın, git'e koymayın (`*.jks`, `android/key.properties` gitignore'dadır). Kaybederseniz Play uygulama imzası sıfırlama süreci gerekir; **yedekleyin** (parola yöneticisi + şifreli yedek).

```powershell
& 'C:\android\jdk17\bin\keytool.exe' -genkey -v -keystore C:\keys\bu-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sonra `android/key.properties.example` dosyasını `android/key.properties` olarak kopyalayıp `storeFile` (android/ klasörüne göre ya da mutlak yol, ör. `C:/keys/bu-upload.jks`), `storePassword`, `keyAlias`, `keyPassword` değerlerini doldurun.

**Karar:** `key.properties` yoksa release derlemesi durmaz, **debug anahtarıyla imzalanır ve Gradle net uyarı basar** ("release DEBUG anahtariyla imzalaniyor"). Bu çıktı elden test içindir, **Google Play'e yüklenemez**. Üretim derlemesinde uyarıyı görüyorsanız `key.properties` eksik demektir. Play App Signing kullanıldığında bu anahtar "upload key" olur.

## 3. Derleme komutları

**Üretim (Play, AAB)** — API adresi `https://` olmak ZORUNDA (aksi halde uygulama açılışta yapılandırma hatası ekranı gösterir; Android tarafı da cleartext'i kapalı tutar):

```powershell
flutter build appbundle --release --dart-define=API_BASE=https://api.ornek.edu.tr --dart-define=APP_VERSION=1.0.0
# çıktı: build\app\outputs\bundle\release\app-release.aab  (arm64-v8a, armeabi-v7a, x86_64 hepsi içinde)
```

Elden dağıtım için üretim APK'sı: `flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE=https://...`

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
- Cihaz veya diğer kimlikler: **FCM bildirim belirteci** (+ platform, uygulama sürümü, dil). Reklam kimliği yok. `X-Device-Id` mobilde henüz GÖNDERİLMİYOR (sunucu tarafı varsa mobil eksik; beyanda cihaz kimliği olarak yalnız FCM belirteci geçer).
- Konum: **toplanmaz** (izin kaldırıldı).
- Finansal bilgi, sağlık, web geçmişi, takvim, SMS: yok.

Mağaza gereksinimleri: hedef API 36 (karşılanıyor); 64-bit (arm64-v8a, AAB x86_64 + armeabi-v7a de içerir); gizlilik politikası URL'si (herkese açık web sitesindeki `/legal/privacy`; Play Console'a elle girilir); hesap silme: uygulama içinde mevcut, ayrıca web için silme talebi URL'si Play'in "Hesap silme" formunda istenir; içerik derecelendirme anketi (kullanıcı içeriği, sohbet) ve "kullanıcı tarafından oluşturulan içerik" moderasyon/raporlama açıklaması (uygulamada rapor/engelle var).

## 7. Bilinen sınırlar / riskler

- `google-services.json` git'te değildir; derleme makinesinde `mobile/android/app/google-services.json` bulunmalı, aksi halde push kapalı derlenir (uyarı basılır).
- Firebase, video_compress, photo_manager eklentileri Kotlin Gradle Plugin uyguluyor; Flutter ileride "built-in Kotlin" zorunlu kılacak (derleme uyarısı).
- Gerçek cihaz/R8 testi: üretim APK'sı kurulduktan sonra giriş, sohbet (STOMP), QR tarama, video seçip sıkıştırma, rehber eşleştirme, push alma elle denenmelidir (R8 yansıma çökmeleri ancak çalışırken görülür).
- Flutter test paketinde (visual_a erişilebilirlik) önceden var olan dokunma hedefi (44dp) hataları vardır; bu belgedeki değişikliklerle ilgili değildir.
