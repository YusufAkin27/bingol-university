# BÜ Kampüs — marka kılavuzu

Ürün adı **BÜ Kampüs** (büyük/küçük harf aynen; Arapçada da çevrilmez). Kurum olarak "Bingöl Üniversitesi" yalnızca kurumdan söz eden metinlerde geçer.

Logo **monokromdur**: açık tema siyah glif / beyaz zemin, koyu tema beyaz glif / siyah zemin. Marka/vurgu kırmızısı YOKTUR
(eski kırmızı kare logo ve ondan üretilen `brand/dist`, `build.js`, `source/logo.png` kaldırıldı).

## Kaynaklar

- `source/light_logo.png`: beyaz zemin, siyah BÜ. `source/dark_logo.png`: siyah zemin, beyaz BÜ (tam kare, köşeleri karo renginde dolu).
- `source/original_*.png`: kullanıcının yüklediği özgün dosyalar. `normalize_sources.py` bunlardan yukarıdakileri üretir.

## Çıktılar nasıl üretilir

| Hedef | Komut |
|---|---|
| Mobil (Android/iOS/splash/mağaza) | `python -I -X utf8 mobile/tool/make_brand_assets.py` (bkz. `mobile/branding/README.md`) |
| Web (favicon.svg/ico/png, apple-touch, PWA, og, `web/public/brand`) | `python -I -X utf8 web/scripts/build-brand.py` |

Web sekme simgesi `favicon.svg` temaya duyarlıdır (`prefers-color-scheme`); `web/index.html` bağlantılarında `?v=` sürümü vardır:
simge değişince sürümü artırın (tarayıcılar favicon'u agresif önbelleğe alır).

## Renkler

Açık zemin `#FFFFFF`, koyu zemin `#09090B`, glif `#09090B` / `#FFFFFF`. Kırmızı yalnız hata/tehlike durumlarında kullanılır, logoda asla.

## Kurallar

- Koruma alanı: ikon yüksekliğinin %25'i. En küçük boyut: ikon 16 px.
- Yasaklar: glifi/şekli değiştirmek, döndürmek, gölge-parlama eklemek, gerdirmek, renklendirmek, yoğun/renkli zeminde koymak (tek renk kontrastlı sürüm kullanın).
- Koyu zemin: beyaz glif; açık zemin: siyah glif. Web'de `Logo` bileşeni `tone="auto"` ile temaya göre seçer.

## Hangi dosya nerede

| Yer | Dosya |
|---|---|
| README üstü | `docs/brand/logo-mark.png` |
| Web üst çubuk / giriş / yan menü / alt bilgi | `web/src/assets/brand/*.png` (`web/src/components/brand/Logo.tsx`) |
| Web favicon, apple-touch, PWA, OG | `web/public/favicon.svg`, `favicon.ico`, `favicon-{light,dark}.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `icon-maskable-512.png`, `og.png`, `site.webmanifest` |
| E-posta | `backend/src/main/resources/mail-templates/logo-{light,dark}.png` |
| Android / iOS / Play Store | `mobile/android/.../res/`, `mobile/ios/Runner/Assets.xcassets/`, `mobile/branding/store/` |
| Flutter içi | `mobile/assets/branding/` |
