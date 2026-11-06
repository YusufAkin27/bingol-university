# BÜ Kampüs — mobil marka varlıkları

Marka logosu iki kaynak dosyadır (kalıcı, repo içinde): `brand/source/dark_logo.png` (siyah zemin, beyaz "BÜ") ve
`brand/source/light_logo.png` (beyaz zemin, siyah "BÜ"); ikisi de 1254x1254 RGB. Uygulamanın her yerinde **tema duyarlıdır**:
koyu temada dark_logo (beyaz glif), açık temada light_logo (siyah glif). Marka rengi kırmızı **kaldırıldı** (Premium
Black/White monochrome).

## Üretim

```bash
python -I -X utf8 mobile/tool/make_brand_assets.py     # repo kökünden; yalnız Pillow ister
```

Betik zeminli kaynaklardan parlaklığı alfaya çevirerek (eşikli, anti-alias) şeffaf glif üretir ve doğrudan gerçek
platform klasörlerine yazar (`android/`, `ios/` zaten repoda; `flutter create` / kopyalama adımı yok). Üretilenler:

| Yol | Ne |
|---|---|
| `assets/branding/logo_dark.png`, `logo_light.png` | Uygulama içi şeffaf glif (640 px genişlik, ortak tuval); Dart tarafı `BuLogo` (`lib/widgets/bu_widgets.dart`) |
| `assets/branding/icon_1024.png`, `adaptive_foreground.png`, `adaptive_monochrome.png` | `flutter_launcher_icons` yedek yolu kaynakları |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Eski (API < 26) simge = light_logo |
| `…/res/drawable-*/ic_launcher_foreground.png`, `ic_launcher_monochrome.png` | Adaptive ön plan + Android 13 temalı simge (siyah glif, 54 dp, güvenli daire içinde); arka plan `ic_launcher_background` = beyaz |
| `…/res/drawable-*/ic_stat_bu.png` | Bildirim küçük simgesi (beyaz glif) |
| `…/res/drawable-xxxhdpi/splash_icon(_dark).png` | Android 12+ açılış simgesi (288 dp tuval, 144 dp glif); `values-v31` / `values-night-v31` |
| `…/res/drawable-xxhdpi/splash_logo(_dark).png` | Android < 12 ve pencere arka planı (`drawable/`, `drawable-v21/`, `drawable-night/launch_background.xml`) |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | Tek boyut (Xcode 14+) 1024: açık = light_logo, koyu (iOS 18) = dark_logo, tinted = gri tonlu dark_logo; hepsi alfasız |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/`, `LaunchBackground.colorset/` | iOS açılış: açık/koyu zemin + 120 pt glif (`Base.lproj/LaunchScreen.storyboard`) |
| `store/play-store-512.png`, `store/feature-graphic-1024x500.png` | Play Store 512 (light_logo) ve öne çıkan görsel (koyu zemin, beyaz glif + "BÜ Kampüs") |

Renkler: açık zemin `#FFFFFF`, koyu zemin `#09090B` (`BuTokens.bg` ile aynı); bildirim vurgusu `#09090B`.

Uyarı: `brand/build.js` (eski kırmızı logo hattı, web için) artık mobil çıktıları ÜRETMEZ ve çalıştırılmamalıdır
(`mobile/branding/{android,ios}` ve `assets/branding/mark*` kaldırıldı).
