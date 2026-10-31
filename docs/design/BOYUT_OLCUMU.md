# BOYUT_OLCUMU: Stitch oranı ve gerçek telefon boyutu (SIZE-FIX)

Şikâyet: "Stitch'te güzel görünen sayfalar emülatörde/telefonda gelince düğmeler çok büyük görünüyor."

## 1. Kök neden

Flutter tarafında temel öğelerin yükseklikleri Stitch referanslarından büyüktü ve birkaç yerde **görünür kutu = dokunma
alanı** karışmıştı (görünür kutu 48-56 dp):

| Öğe | Kod (önce) | Not |
|---|---|---|
| `BuButton` (tam genişlik) | 54 dp, yazı `titleMedium` 16 / w700, köşe 16 | kök neden #1 |
| `RefButton` (kimlik akışı) | min 56 dp, köşe 20, 16 / w700 | |
| Kimlik giriş alanı (`RefTextField`) | tanımlı 56 ama **gerçek ~62 dp** (kapsayıcı dikey 8+8 + girdi dikey 12+12 + satır 22) | kök neden #2 |
| Tema `FilledButton`/`Outlined`/`Elevated` | `Size.fromHeight(54)` | |
| Tema `InputDecoration` | dikey 16 + `bodyLarge` ≈ 54 | |
| `BuChip` | görünür ≈ 35, hit 48 (doğru) | küçük ince ayar |
| Bildirim süzgeç çipi, Duyuru sekme çipi | görünür kutu 48 dp (hit = görünür) | |
| Alt gezinme hapı | 68 dp (+ boşluklar `kNavInset` 100) | |
| `BuIconButton` / yuvarlak düğmeler | görünür 44 | |
| `BuSegmented` | 52 dp | |
| `BuSearchField` | 50 dp | |
| Başlık yazısı `BuScale.display` | 24 / w800 | Stitch `headline-md` 22 / 600 |
| Profil kartı avatarı | 84 dp | |
| Ana Sayfa hızlı erişim karosu | simge 48, karo ~94 dp | |

## 2. Stitch ölçümü

Yöntem: `C:\bu_design\stitch\**\code.html` (437 ekran) içindeki Tailwind sınıfları, 390 dp çerçevede mutlak CSS px = dp
olarak sayıldı (`h-12` = 48). Ayrıca `00-referans-ana-ekranlar/giri/screen.png` üzerinde piksel analiziyle doğrulandı.

| Öğe | Stitch (390 dp çerçeve) | Kanıt |
|---|---|---|
| Birincil tam genişlik düğme | **48 dp** (`h-12`), oran 48/390 = **%12.3**; `rounded-full`, yazı 14 / 700 | giriş ekranı kodu; PNG'de düğme 84 px / 706 px genişlik = %11.9 |
| Giriş alanı | **48 dp** (20 örnek `h-12`, 11 örnek `h-11`), `rounded-xl` = 12 dp | 33 alan örneği |
| Yuvarlak simge düğmesi | **44 dp** (`w-11` 451), 40 (`w-10` 109), 36 (`w-9` 112), 32 (`w-8` 132) | 800+ örnek |
| Çip / küçük düğme | **32-36 dp** (`h-8` 170, `h-9` 95) | |
| Düğme genel dağılım | `h-12` 106, `h-11` 58, `h-14` 23 | `button` etiketleri |
| Alt gezinme | **64 dp** (`h-16`, 18 örnek) | `nav` etiketleri |
| Üst başlık çubuğu | **56 dp** (`h-14`) | `header` |
| Yazı (`design-system.txt`) | label-lg 14 / 600, body-md 14, body-lg 16, headline-md 22 / 600 | |

Gerçek telefon: Redmi 13C 720x1600 px, ~320 dpi = **360 dp genişlik**. 390 dp çerçeveli Stitch tasarımı bu telefona
aynı **mutlak dp** ile gelir; yani Stitch'teki 48 dp düğme telefonda da 48 dp (oransal %13.3) olmalıdır. Flutter'daki
54 dp + 16 sp / w700 yazı ve gerçek ~62 dp alan, 360 dp ekranda Stitch'e göre ~%13-30 büyük görünüyordu.

## 3. Hedef tablosu (uygulandı)

Tek yer: `mobile/lib/core/theme/bu_sizes.dart` (`BuSize`, `BuRadius.control`).

| Öğe | Önce (dp) | Sonra (dp) | Stitch |
|---|---|---|---|
| Tam genişlik düğme (`BuButton`, `RefButton`, tema Filled/Outlined/Elevated) | 54 / 56 | **48** | 48 |
| Satır içi (compact) düğme görünür / hit | 36 / 48 | **34 / 48** | 32-36 |
| Düğme yazısı | 16 / w700 | **15 / w600** | 14 / 600-700 |
| Düğme köşe | 16 / 20 | **14** | 12-full |
| Düğme simgesi | 18 | **16** | |
| Giriş alanı (kimlik akışı, gerçek) | ~62 (tanım 56) | **52** | 48 |
| Tema giriş alanı | ~54 | **52** (min) | 48 |
| OTP kutusu | 52 | **52** (BuSize.field) | |
| Arama kutusu | 50 | **48** | 44-48 |
| Çip görünür / hit | ~35 / 48 | **34 / 48** | 32-36 |
| Bildirim ve duyuru çipi görünür / hit | 48 / 48 | **34 / 48** | 32-36 |
| Segment kontrolü | 52 | **48** (öğe hit 44+) | |
| Yuvarlak simge düğmesi görünür / hit | 44 / 48 | **40 / 48** | 40-44 |
| `+` (FAB benzeri) görünür / hit | 44 / 48 | 44 / 48 (korundu) | 44 |
| Tema FAB | 56 | **48** | 48-56 |
| Alt gezinme hapı içerik | 68 | **64** | 64 |
| `kNavInset` (kaydırma alt payı) | 100 | **96** (`BuSize.navInset`) | |
| Nav simgesi / avatar | 24 / 24 | **22 / 22** | |
| Başlık çubuğu | 56 | 56 | 56 |
| Liste satırı min | 56 | 56 | 56 |
| Sayfa başlığı (`BuScale.display`) | 24 / w800 | **22 / w700** | 22 / 600 |
| AppBar başlığı (`BuScale.title`) | 19 / w800 | **18 / w700** | 18 / 600 |
| Profil avatarı (kart) | 84 | **76** | |
| Ana Sayfa hızlı erişim simge karosu | 48 | **44** | |
| Bölüm başlığı üst/alt boşluk | 22 / 10 | **18 / 6** | |

Korunanlar: tur 1'deki **en küçük yazı 11.5 sp** kuralı (`BuScale.caption`) değişmedi; renkler değişmedi; dokunma
alanı her etkileşimli öğede **>= 48 dp** (görünür kutu küçülürken `BuTouchTarget` / dış `ConstrainedBox(minHeight: 48)`).
Kart iç boşluğu `BuCard` varsayılan 14 dp kaldı (Stitch `p-4` = 16'dan küçük; büyütmek şikâyete ters olurdu).
Çip yazısı `BuScale.label` 12.5 sp kaldı (tek ölçek; Stitch 12-13).

## 4. Doğrulama

Aşağıdaki "Sonuç" bölümü uygulama sonrası ölçümlerle doldurulur.

