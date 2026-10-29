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
- Cihaz veya diğer kimlikler (**"Device or other IDs" işaretlenir**): (1) **FCM bildirim belirteci** (+ platform, uygulama sürümü, dil); (2) **uygulama-özel rastgele cihaz tanımlayıcısı**: mobil, ilk açılışta ürettiği rastgele UUID'yi (Keychain/Keystore'da durur; IMEI/ANDROID_ID/reklam kimliği OKUNMAZ) her istekte `X-Device-Id` başlığı ve STOMP `device-id` ile gönderir. Amaç yalnızca güvenlik: kötüye kullanım önleme ve yasaklı kullanıcıların cihaz engelini dolanmasını engelleme (`accessban`). Sunucu ham değeri saklamaz; HMAC-SHA256 özetini (`ClientContexts`) `user_device_log` tablosunda **90 gün** tutar. Reklam/izleme/analitik amacıyla kullanılmaz, üçüncü taraflarla paylaşılmaz. Data Safety: Veri türü "Device or other IDs" = toplanır, paylaşılmaz, amaç "Fraud prevention, security, and compliance" (+ bildirimler için "App functionality"); zorunlu (kullanıcı kapatamaz). Apple App Privacy'de de "Device ID" = "Not linked to tracking", amaç "App functionality / security" olarak beyan edilir ve gizlilik politikasında anılır (bkz. `docs/legal/privacy_tr.md` bölüm 6).
- Konum: **toplanmaz** (izin kaldırıldı).
- Finansal bilgi, sağlık, web geçmişi, takvim, SMS: yok.

Mağaza gereksinimleri: hedef API 36 (karşılanıyor); 64-bit (arm64-v8a, AAB x86_64 + armeabi-v7a de içerir); gizlilik politikası URL'si (herkese açık web sitesindeki `/legal/privacy`; Play Console'a elle girilir); hesap silme: uygulama içinde mevcut, ayrıca web için silme talebi URL'si Play'in "Hesap silme" formunda istenir; içerik derecelendirme anketi (kullanıcı içeriği, sohbet) ve "kullanıcı tarafından oluşturulan içerik" moderasyon/raporlama açıklaması (uygulamada rapor/engelle var).

## 7. Bilinen sınırlar / riskler

- `google-services.json` git'te değildir; derleme makinesinde `mobile/android/app/google-services.json` bulunmalı, aksi halde push kapalı derlenir (uyarı basılır).
- Firebase, video_compress, photo_manager eklentileri Kotlin Gradle Plugin uyguluyor; Flutter ileride "built-in Kotlin" zorunlu kılacak (derleme uyarısı).
- Gerçek cihaz/R8 testi: üretim APK'sı kurulduktan sonra giriş, sohbet (STOMP), QR tarama, video seçip sıkıştırma, rehber eşleştirme, push alma elle denenmelidir (R8 yansıma çökmeleri ancak çalışırken görülür).
- Flutter test paketinde (visual_a erişilebilirlik) önceden var olan dokunma hedefi (44dp) hataları vardır; bu belgedeki değişikliklerle ilgili değildir.

## 8. Upload keystore, Play App Signing ve kapalı test adımları (REL1)

> **Keystore'u ben ÜRETMEDİM ve repoda üretilmemelidir.** Aşağıdaki adımları yalnız siz, kendi makinenizde yaparsınız. Yapılandırma hazırdır: `android/key.properties` varsa release o anahtarla imzalanır, yoksa debug anahtarıyla (uyarıyla) imzalanır ve **Play'e yüklenemez** (bölüm 2). `.gitignore` kontrolü yapıldı: `mobile/android/key.properties`, `*.jks`, `*.keystore`, `*.age.key`, `.env.prod` ignore listesindedir (`git check-ignore -v <dosya>` ile doğrulanır); `scripts/agent-push.sh` ayrıca `*.jks`/`*.keystore`/`*.aab`/`*.apk` yollarını reddeder.

### 8.1 Upload keystore üretimi (SİZ)

```powershell
# repo DIŞINDA bir klasör (örn. C:\keys); parola yöneticisinden güçlü parola seçin, bu komut sizden iki parola ve kimlik bilgileri ister
New-Item -ItemType Directory -Force C:\keys | Out-Null
& 'C:\android\jdk17\bin\keytool.exe' -genkeypair -v -keystore C:\keys\bu-upload.jks -storetype PKCS12 `
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
# kontrol (parola sorar; SHA-1/SHA-256 parmak izlerini yazdırır, PUSH_SETUP.md bölüm 6 için gerekir)
& 'C:\android\jdk17\bin\keytool.exe' -list -v -keystore C:\keys\bu-upload.jks -alias upload
```

Sonra `mobile/android/key.properties.example` dosyasını `mobile/android/key.properties` olarak kopyalayıp doldurun (`storeFile=C:/keys/bu-upload.jks` gibi mutlak yol; `storePassword`, `keyAlias=upload`, `keyPassword`). **PKCS12 anahtar deposunda `keyPassword` ile `storePassword` aynı olmalıdır** (farklı verirseniz Gradle imzalama hatası alırsınız).

**Nerede saklanır:**
- `bu-upload.jks` ve parolalar: parola yöneticisi + **ikinci bir çevrimdışı kopya** (şifreli USB / şifreli arşiv). Dosyayı e-postayla, sohbetle, buluta açık göndermeyin; repoya asla koymayın.
- Kaybederseniz uygulama kaybolmaz: **Play App Signing** etkinse Google gerçek imzalama anahtarını tutar, siz Play Console'dan "upload key sıfırlama" talep edersiniz (birkaç gün sürer). Ancak Play App Signing'i **ilk yüklemede etkin bırakmak** zorunludur (yeni uygulamalarda varsayılan ve zorunludur).
- Sunucudaki `.env.prod`/age/CRYPTO anahtarlarından **ayrı** tutun ([KEY_MANAGEMENT.md](KEY_MANAGEMENT.md)); bu anahtar sunucu verisini açmaz, yalnız uygulama yayınlama yetkisi verir.

### 8.2 Play App Signing (Google imzalar, siz yüklersiniz)

1. Play Console'da uygulamayı oluşturun (paket adı **`edu.bingol.bu_kampus`**, bir kez seçilir, sonra değişmez).
2. İlk AAB'yi yüklerken **Play App Signing'e katılın** (varsayılan). Siz AAB'yi *upload key* ile imzalarsınız; Google kullanıcıya dağıttığı APK'ları kendi *app signing key* ile yeniden imzalar.
3. **Parmak izleri:** Play Console > Kurulum > Uygulama bütünlüğü > Uygulama imzalama: "App signing key certificate" (SHA-1/SHA-256) mağazadan kurulan sürümün gerçek imzasıdır. Bu SHA-1'i **Google Cloud API anahtarı kısıtına ekleyin** ([PUSH_SETUP.md](PUSH_SETUP.md) bölüm 6), yoksa mağazadan kurulan sürümde push/Firebase çağrıları bloklanır.
4. İleride Google oturum açma/App Links kullanılırsa aynı parmak izleri gerekir (şu an kullanılmıyor).

### 8.3 AAB derleme (üretim)

```powershell
# C:\bu_mobile içinde, ortam: bu belgenin başı
flutter build appbundle --release --dart-define=API_BASE=https://bukampus.net --dart-define=APP_VERSION=1.0.0
# çıktı: build\app\outputs\bundle\release\app-release.aab
```

- `API_BASE` **https olmak zorunda**; `ALLOW_INSECURE_API` üretimde verilmez. `APP_VERSION` pubspec `version:` ile aynı olsun.
- Her yüklemede `pubspec.yaml` `version: 1.0.0+N` içindeki `N` artırılır.
- İmza kontrolü (Play'e yüklemeden önce): `& 'C:\android\jdk17\bin\keytool.exe' -printcert -jarfile build\app\outputs\bundle\release\app-release.aab` çıktısındaki SHA-1, **upload key** parmak izinizle aynı olmalı. Debug anahtarıyla imzalanmışsa `Owner: CN=Android Debug` görürsünüz: yüklemeyin (`key.properties` eksik).
- Sembolleştirme (isteğe bağlı): `--obfuscate --split-debug-info=build\symbols`; `build\symbols` saklanır.

**REL1 doğrulama notu:** `flutter build appbundle --release` bu bölümdeki komutla **imzasız `key.properties` (debug imzalı)** olarak denendi; sonuç ve süre aşağıdaki "Derleme kaydı"ndadır. Gerçek upload anahtarıyla imzalı derleme ve Play yüklemesi **doğrulanmadı** (keystore/hesap kullanıcıda).

### 8.4 Play Console: kapalı test (closed testing) adımları

1. **Hesap:** Play Console geliştirici hesabı (tek seferlik ücret; kişisel hesapta ad ve adres herkese görünebilir: [LEGAL_NOTES.md](LEGAL_NOTES.md) gizlilik uyarısı). Kimlik doğrulaması günler sürebilir; yayın sürecinin ilk işi olarak başlatın.
2. **Uygulamayı oluştur** > varsayılan dil Türkçe > "Uygulama" > "Ücretsiz".
3. **Mağaza girişi:** [store/store_tr.md](store/store_tr.md), [store/store_en.md](store/store_en.md), görseller [store/screenshots.md](store/screenshots.md).
4. **Uygulama içeriği bölümü:** gizlilik politikası URL'si (`https://bukampus.net/tr/privacy`), uygulama erişimi (inceleyici hesabı), reklamlar (yok), içerik derecelendirme ([store/content_rating.md](store/content_rating.md)), hedef kitle (18+), Veri güvenliği ([store/data_safety.md](store/data_safety.md)), hesap silme URL'si (`https://bukampus.net/tr/delete-account`), hassas izin beyanları (READ_CONTACTS; READ_MEDIA_*: [store/data_safety.md](store/data_safety.md) bölüm 4).
5. **Test > Kapalı test > Yeni kanal:** AAB'yi yükleyin, test kullanıcı listesi (e-posta listesi) oluşturun, sürüm notu yazın, incelemeye gönderin. Test kullanıcıları katılım bağlantısıyla kabul eder ve Play'den kurar.
6. **Koşul (değişebilir, Console'da doğrulayın):** yeni kişisel geliştirici hesaplarında üretime çıkmadan önce kapalı testte **en az 12 test kullanıcısının 14 gün kesintisiz katılımı** istenmektedir; bu süre ve sayıyı hesabınız için Play Console "Üretime çık" bölümünde kontrol edin. Test kullanıcılarını (arkadaş, kulüp üyesi) bu sebeple erken toplayın.
7. **Kapalı test sürümüyle** [DEVICE_TEST_PLAN.md](DEVICE_TEST_PLAN.md)'i koşturun; geri bildirimi düzeltip `N+1` yükleyin.
8. Üretime geçişte **aşamalı yayın** (%10 -> %50 -> %100) kullanın; `LEGAL_ENFORCE_REACCEPT` ve `min_version_android` sırası: [DEPLOY.md](DEPLOY.md) 14.4.
9. Her mağaza sürümünde `pubspec` `+N` artar, sürüm notları tr/en yazılır, `google-services.json` derleme makinesinde bulunur (yoksa push kapalı derlenir).

### Derleme kaydı (REL1, 2026-10-29)

`flutter build appbundle --release --dart-define=API_BASE=https://bukampus.net --dart-define=APP_VERSION=1.0.0` komutu **commitli kaynaktan** (`git archive HEAD mobile` ile `C:\bu_rel1_aab` kopyası; başka ajanların bitmemiş değişiklikleri dışarıda) çalıştırıldı: **başarılı**, `app-release.aab` **85,4 MB**, soğuk Gradle önbelleğiyle 1159 sn (~19 dk; sonraki derlemeler çok daha kısa). `key.properties` olmadığı için **debug anahtarıyla imzalıdır** (`keytool -printcert -jarfile ...` çıktısı `CN=Android Debug`); bu dosya Play'e **yüklenemez**, yalnız derleme hattının çalıştığını gösterir. Upload anahtarıyla imzalı derleme, Play yüklemesi ve gerçek cihaz/R8 çalışma testi **doğrulanmadı**.
