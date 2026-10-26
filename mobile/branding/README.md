# BÜ Kampüs — mobil marka varlıkları

Bu klasör `brand/build.js` ile üretilir (kaynak: `brand/source/logo.png`); elle düzenlemeyin.
Flutter bu makinede kurulu değil, bu yüzden `android/` ve `ios/` klasörleri yok: kaynaklar hazır tutulur.

## Platform klasörleri üretildikten sonra

```bash
cd mobile
flutter create --platforms=android,ios --project-name bu_kampus --org edu.bingol .   # android/ ve ios/ üretir (lib/ ve pubspec.yaml'a dokunmaz)
cp -r branding/android/res/. android/app/src/main/res/ && cp -r branding/ios/AppIcon.appiconset/. ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

Bu iki komut yeterlidir: adaptive + monochrome başlatıcı simgesi, eski/yuvarlak simgeler, bildirim simgesi
(`drawable-*/ic_stat_notification.png`), Android 12 açılış ikonu (`drawable/splash_icon.png`), `app_name` ("BÜ Kampüs")
ve iOS `AppIcon` seti yerleşir. Alternatif olarak `dart run flutter_launcher_icons` (yapılandırma `pubspec.yaml`'da) başlatıcı
simgelerini kendisi üretir; bildirim ve açılış ikonu için yine `res/` kopyası gerekir.

Elle bir kez yapılacaklar:
- `AndroidManifest.xml` → `<application android:label="@string/app_name" android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round">`
  ve FCM varsayılan bildirim simgesi: `<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat_notification"/>`
- Android 12 açılış ekranı (`res/values-v31/styles.xml`): `windowSplashScreenBackground` = `@color/ic_launcher_background`,
  `windowSplashScreenAnimatedIcon` = `@drawable/splash_icon`.
- iOS `ios/Runner/Info.plist`: `CFBundleDisplayName` = `BÜ Kampüs` (bkz. `ios/Info.plist.snippet.xml`).

## İçerik

| Yol | Ne |
|---|---|
| `android/res/mipmap-*/ic_launcher.png`, `ic_launcher_round.png` | Eski (API < 26) kare ve yuvarlak simgeler |
| `android/res/mipmap-*/ic_launcher_foreground.png` | Adaptive ön plan: 108 dp tuval, kırmızı kare 72 dp, harfler 66 dp güvenli dairenin içinde |
| `android/res/mipmap-*/ic_launcher_monochrome.png` | Android 13 temalı simge (yalnız harfler, alfa) |
| `android/res/mipmap-anydpi-v26/ic_launcher(_round).xml` | Adaptive tanım (arka plan + ön plan + monochrome) |
| `android/res/values/ic_launcher_background.xml`, `strings.xml` | Arka plan rengi `#F73A2E`; `app_name` = BÜ Kampüs |
| `android/res/drawable-*/ic_stat_notification.png` | Bildirim simgesi (beyaz, harfleri oyuk kare; 24 dp mdpi→xxxhdpi) |
| `android/res/drawable/splash_icon.png` | Android 12 açılış ikonu (288 dp tuval) |
| `store/play-store-512.png` | Play Store 512x512, köşesi yuvarlatılmamış tam kare |
| `store/feature-graphic-1024x500.png` | Play Store öne çıkan görsel (logo + "BÜ Kampüs" + "BİNGÖL ÜNİVERSİTESİ") |
| `ios/AppIcon.appiconset/` | iOS 1024 + tüm gerekli boyutlar, alfa kanalsız, `Contents.json` |
| `../assets/branding/` | Uygulama içi görseller (`logo_horizontal*.png`, `mark.png`) ve `flutter_launcher_icons` kaynakları |
