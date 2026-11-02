# Apple HIG kural kitabı (BÜ Kampüs, Android uyarlaması)

İç kullanım belgesidir. Kaynak: Apple Human Interface Guidelines'ın yerel metin kopyası (171 sayfa). Apple'ın metni kopyalanmamıştır; kurallar bu projenin ihtiyacına göre **kendi cümlelerimizle** özetlenmiştir, köşeli parantezdeki ad kaynak sayfayı gösterir. Kapsam: **yalnız Android**; iOS'a özgü kurallar "Hayır (iOS'a özgü)" olarak listelenir ve uygulama önerisi içermez. iOS şimdilik kapsam dışıdır.

Birlikte okunacak: [MOBILE_DESIGN_SYSTEM.md](MOBILE_DESIGN_SYSTEM.md) (Material 3 + BuTokens, KİLİTLİ arayüz), [MOBILE_UI.md](MOBILE_UI.md), [MOBILE_HIG_AUDIT.md](MOBILE_HIG_AUDIT.md) (bu kuralların ölçüm sonuçları ve düzeltme planı).

Kapsam dışı ve kabul edilmiş kararlar (ihlal sayılmaz):
- **Tipografi K-21 kabul edildi:** en küçük yazı 11,5 sp (`BuScale.caption`), tek tip sistemi (`BuScale`/`BuType`/`BuTextTheme`). Apple'ın iOS için önerdiği 17 pt varsayılan gövde Android'e birebir taşınmaz.
- **Hareket (süre, eğri, animasyon):** `feat/motion-system` dalında başka ajan çalışıyor. Bu kitapta hareket kuralları yalnız not olarak durur ve denetlenmez.
- Dokunma hedefi tabanı Android için **48 dp**'dir (`BuSize.touch`); Apple'ın 44 pt değeri değil.

Ölçüm sütunu: **Oto** = `mobile/tools/hig_audit.py` ya da `mobile/test/hig/hig_audit_test.dart` ile sayılır; **Yarı** = betik şüphelileri bulur, insan doğrular; **Elle** = cihazda ya da ekran görüntüsünde gözle bakılır. `M-a` ... `M-j` harfleri MOBILE_HIG_AUDIT.md bölümleridir.

Android sütunu yazımı: `Evet`, `Kısmen (nasıl)`, `Hayır (iOS'a özgü: neden)`.

---

## 1. Renk ve kontrast
Kaynak: [Color], [Accessibility], [Dark Mode].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| REN-1 | Aynı rengi iki farklı anlamda kullanma. Marka rengi "dokunulabilir" demekse, dokunulmayan metni aynı renge boyama. | Evet | `t.pr` yalnız eylem/bağlantı; seçili durum tek stil (`soft`+`onSoft`+`selectedBorder`) | Yarı (M-d1 + elle) |
| REN-2 | Her özel rengin açık ve koyu varyantı olsun; uygulama tek görünümlüyse bile ikisini tanımla. | Evet | `BuTokens.light` / `BuTokens.dark`, `ThemeMode.system` varsayılan | Oto (M-i) |
| REN-3 | Sistem "artırılmış kontrast" ayarı açıkken renk farkları belirginleşsin. | Kısmen (Android 14+ kontrast düzeyi ve "yüksek kontrastlı metin"; M3 `ColorScheme` kontrast düzeyi) | Karşılığı yok | Elle |
| REN-4 | Bilgiyi yalnız renkle taşıma; durum için ikon, şekil ya da etiket ekle. | Evet | Kategori ayrımı simge + etiket (`BuTint`), durumlar ikonlu | Yarı (M-e, M-d1) |
| REN-5 | Metin kontrastı 4,5:1 (17 pt'e kadar her ağırlık); 18 pt ve üstü ya da kalın metin 3:1. | Evet (WCAG 2.x ile aynı eşik) | `ink`/`mut`/`onX` çiftleri, `textContrastGuideline` | Oto (M-a, M-b) |
| REN-6 | Koyu zeminde küçük metin için mümkünse 7:1'e yaklaş; asgari 4,5:1. | Evet | Koyu `mut`, `onSoft` aileleri | Oto (M-a AAA sayısı) |
| REN-7 | Kontrol çerçevesi, simge ve grafik öğe zemine karşı en az 3:1 (WCAG 1.4.11; HIG'in kontrast ilkesinin tamamlayıcısı). | Evet | `bdStrong` (kontrol), `bd` yalnız kart ayracı (bilgi taşımaz) | Oto (M-a) |
| REN-8 | Renkleri koda sabit gömme; amaçlarına göre adlandırılmış (anlamsal) renkleri kullan. | Kısmen (Android'de karşılığı M3 `ColorScheme` ve dinamik renk; BU kendi anlamsal jetonlarını kullanır) | `context.bu` (BuTokens) | Oto (M-d1) |
| REN-9 | Anlamsal rengi başka amaçla kullanma (hata rengini süs, zemin rengini metin yapma). | Evet | `danger` yalnız hata, `ok` yalnız başarı, `warn` yalnız uyarı | Elle |
| REN-10 | Renklerin kültürel çağrışımını düşün; kırmızı her yerde "tehlike" değildir. | Evet | Marka kırmızısı (`pr`) ile hata tonu (`danger`) ayrı | Elle |
| REN-11 | Renkli ya da fotoğraflı zemin üstündeki kontrol/yazı okunur kalsın (varsayılan hâlde de). | Evet | `onMedia` + `scrim` | Yarı (M-a medya) |
| REN-12 | Renk şemasını farklı ışık koşullarında ve farklı cihazlarda dene. | Kısmen (gerçek Android cihazlarda; AMOLED/LCD farkı) | — | Elle |
| REN-13 | Görsellere renk profili göm; geniş gamut (Display P3) için P3 varlık kullan. | Hayır (iOS'a özgü: Display P3 varlık kataloğu akışı) | — | — |
| REN-14 | Renkli Liquid Glass kontrolleri ve renkli arka plan üstünde cam etiket kuralları. | Hayır (iOS'a özgü: Liquid Glass malzemesi) | — | — |
| REN-15 | Sistem renk seçicisini tercih et (renk seçtiriyorsan). | Kısmen (Android'de sistem renk seçici yok; uygulama içi seçici kullanılır) | Renk seçtirilmiyor | — |

## 2. Tipografi ve Dinamik Yazı Boyutu
Kaynak: [Typography], [Accessibility], [Layout], [Labels].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| TIP-1 | Platformun önerdiği varsayılan ve asgari yazı boyutlarına uy (iOS: 17/11 pt). | Kısmen (Android karşılığı gövde 14-16 sp; BU gövde 14, en küçük 11,5 = K-21 kabul) | `BuScale` (22/18/16/15/14/12,5/11,5) | Oto (M-d2) |
| TIP-2 | İnce (Ultralight/Thin/Light) ağırlıklardan kaçın; Regular ve üstü. | Evet | Gövde w400, vurgu w600/w700 | Oto (M-d2 ince ağırlık) |
| TIP-3 | Hiyerarşiyi ağırlık, boyut ve renkle kur; yazı büyüdüğünde bu hiyerarşi bozulmasın. | Evet | `BuType`/`BuTextTheme` rolleri | Elle + Oto (M-c) |
| TIP-4 | Az sayıda yazı tipi ailesi kullan. | Evet | Tek aile: Inter | Oto (pubspec) |
| TIP-5 | Hazır metin stillerini kullan; yazı boyutunu ekranda elle yazma. | Evet | `Theme.textTheme`, `BuType` | Oto (M-d2: sabit `fontSize`) |
| TIP-6 | Sistem yazı boyutu ayarına uyum: düzen her boyutta çalışmalı; en az %200'e kadar büyütülebilmeli. | Evet (Android "yazı boyutu" en çok ~%200) | Testler 1,3 ve 2,0 ölçek | Oto (M-c) |
| TIP-7 | Anlam taşıyan ikonlar da yazıyla birlikte büyüsün. | Kısmen (Flutter ikonları otomatik ölçeklenmez; `Icon(size:)` elle ölçeklenir) | Kısmi (`BuTouchTarget`, ölçekli hap) | Elle |
| TIP-8 | Büyük yazıda kesilmeyi en aza indir; kaydırılan alanda metni "…" ile gizleme (açılabiliyorsa hariç). | Evet | `maxLines` kullanımı, uzun içerikte detay sayfası | Yarı (M-c taşma + `maxLines:1` sayısı) |
| TIP-9 | Büyük yazıda yan yana öğeleri alt alta yığ; saat/simge metni sıkıştırmasın. | Evet | `narrow` dalları (`textScalerOf`) | Oto (M-c) |
| TIP-10 | Sekme/gezinme başlıkları gibi öğeler tüm ekranla orantılı büyümek zorunda değil; önemli içeriği önceliklendir. | Evet | `FloatingNav` etiketleri 1,15 ile sınırlı | Elle |
| TIP-11 | Özel yazı tipi, sistemin "kalın metin" gibi erişilebilirlik ayarlarını da uygulasın. | Kısmen (Android `MediaQuery.boldText`/yazı ağırlığı düzeltmesi) | Uygulanmıyor | Yarı (M-e) |
| TIP-12 | Satır yüksekliğini okunabilirlik için ayarla; geniş sütunda satır aralığını artır. | Evet | `height` 1,3-1,45; Arapçada +%12 | Elle |
| TIP-13 | SF/New York sistem yazı tipleri, optik boyut, değişken yazı tipi ayarı. | Hayır (iOS'a özgü: San Francisco ailesi) | — | — |
| TIP-14 | Dynamic Type'ın erişilebilirlik boyutları (AX1-AX5, %300+). | Hayır (iOS'a özgü: iOS boyut kademeleri; Android üst sınırı ~%200) | — | — |

## 3. Yerleşim ve boşluk
Kaynak: [Layout], [Scroll views], [Disclosure controls].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| YER-1 | İçeriği önem sırasına koy: en önemli öğe üstte ve başlangıç (leading) tarafta. | Evet | Ana sayfa kartları sırası | Elle |
| YER-2 | Hizalama ve girintiyi bilinçli kullan; hizalı öğeler ilişkili sanılır. | Evet | `BuSpace.page` (20) kenar boşluğu | Elle |
| YER-3 | İlişkili öğeleri boşluk, kap şekli ya da ayraçla grupla. | Evet | `BuGroup`, `BuCard`, `BuSectionHeader` | Elle |
| YER-4 | Aşamalı açma: ayrıntıyı menü, açılır bölüm ya da alt görünümle gizle. | Evet | `BuSheet`, detay sayfaları | Elle |
| YER-5 | Kontrolleri içerikten ayrıştır (iOS 26: cam malzeme ve kaydırma kenarı efekti). | Hayır (iOS'a özgü: Liquid Glass ve scroll edge effect) | — | — |
| YER-6 | Ekran boyutu, yön, çoklu pencere ve yazı boyutu değişimine uyum; boyut sınıflarına göre düzen kur. | Evet (Android pencere boyut sınıfları, katlanabilir, çoklu pencere) | Testler 320/390/430 dp, yalnız telefon | Yarı (M-c; tablet/katlanabilir elle) |
| YER-7 | Alanın büyüklüğüne göre işlev değiştirme; yalnız görünen miktarı değiştir. | Evet | — | Elle |
| YER-8 | Uzun metinde satır uzunluğunu okunabilir genişlikle sınırla. | Evet | Tablet için henüz yok (telefon odaklı) | Elle |
| YER-9 | Boşluk ölçeği tutarlı olsun (tek ölçekten seç). | Evet (Apple belirli bir sayı dayatmaz; BU kuralı 4 katları) | `BuSpace` (2/4/8/12/16/20/24/32/48), `BuGap` | Oto (M-d3) |
| YER-10 | Arka plan görselini en-boy oranını bozmadan ölçekle; kırpılsa da doldursun. | Evet | `BuImage` (cover) | Elle |
| YER-11 | İç içe aynı yönde kaydırma görünümü kurma; kaydırılabilirliği belli et (yarım görünen öğe). | Evet | Yatay çip/şerit satırları | Elle |
| YER-12 | Sağdan sola dillerde düzeni ve metin hizasını aynala; mantıksal (başlangıç/bitiş) özellikleri kullan. | Evet | `EdgeInsetsDirectional`, `buDirIcon` | Oto (M-h) |

## 4. Güvenli alanlar
Kaynak: [Layout], [Virtual keyboards], [Status bars].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| GUV-1 | İçerik ve kontroller güvenli alanda kalsın; sistem arayüzü (çentik, durum çubuğu, hareket çubuğu) bir şeyin üstünü örtmesin. | Evet (hedef SDK 36'da kenardan kenara zorunlu; ekran kesiği, durum ve gezinme çubuğu, hareket alanı) | `SafeArea`, `MediaQuery.paddingOf`, `BuPageScaffold` | Yarı (M-g) |
| GUV-2 | Klavye açılınca odaktaki alan ve gönder düğmesi görünür kalsın. | Evet | `resizeToAvoidBottomInset`, `viewInsets` | Yarı (M-g) |
| GUV-3 | Alt gezinme/alt çubuk kaydırılan içeriği örtmesin; içeriğe alt pay bırak. | Evet | `BuSize.navInset` | Elle |
| GUV-4 | Önemli kontrolü sistem hareket alanına (alt kenar) çok yaklaştırma. | Evet (Android hareket gezintisi alt kenardır) | Yüzen hap alt boşluk 16 dp | Elle |
| GUV-5 | Dynamic Island ve kamera çentiği çevresine yerleşim. | Hayır (iOS'a özgü: Dynamic Island) | — | — |

## 5. Dokunma hedefleri ve hareketler
Kaynak: [Accessibility], [Buttons], [Gestures].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| DOK-1 | Kontrol boyu rahat dokunulabilecek kadar olsun (iOS: 44x44 pt, asgari 28). | Evet (Android: 48x48 dp) | `BuSize.touch` = 48, `BuTouchTarget` | Oto (M-b) |
| DOK-2 | Komşu hedefler arasında yeterli boşluk bırak (çerçeveli ~12, çerçevesiz ~24 pt). | Kısmen (Android: komşu hedefler arası ≥ 8 dp) | — | Elle |
| DOK-3 | Her özel düğmede basılı durum görünsün. | Evet | `BuPressable`, M3 ripple | Yarı (M-b statik) |
| DOK-4 | Sık işlemler için en basit hareketi kullan; çok parmaklı özel hareketten kaçın. | Evet | — | Elle |
| DOK-5 | Her harekete ekranda görünür bir alternatif sun (kaydırma yerine düğme). | Evet | Uzun basma/kaydırma eylemlerinin düğme karşılığı | Elle |
| DOK-6 | Sistem hareketleriyle çakışma (kenardan kaydırma). | Evet (Android sistem geri hareketi, bkz. Çatışmalar) | `PopScope`, öngörülü geri etkin | Elle |
| DOK-7 | Özel hareketi yalnız gerektiğinde ekle, öğretilebilir kıl, standardın yerine koyma. | Evet | — | Elle |
| DOK-8 | Hareket kullanılamıyorsa nedenini belirt (donmuş sanılmasın). | Evet | — | Elle |
| DOK-9 | Ses ile denetim ve anahtarla erişim araçları için öğeleri doğru etiketle. | Kısmen (Android karşılığı Voice Access ve Switch Access) | `Semantics` etiketleri | Oto (M-b etiket yönergesi) |
| DOK-10 | Klavye ile tam gezinme (Full Keyboard Access). | Kısmen (Android'de harici klavye odak gezintisi; telefonda nadir) | — | Elle |

## 6. Gezinme
Kaynak: [Tab bars], [Modality], [Sheets], [Launching].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| GEZ-1 | Sekme çubuğu yalnız bölümler arası gezinme içindir, eylem düğmesi taşımasın. | Evet | `FloatingNav` (ortada "Paylaş" eylemi var: bkz. Çatışmalar) | Elle |
| GEZ-2 | Alt bölümlere gezerken sekme çubuğu görünür kalsın; kullanıcı nerede olduğunu kaybetmesin. | Evet | `AppShell` | Elle |
| GEZ-3 | Sekme sayısını makul tut (iPhone'da 5); taşan sekme "Diğer"e düşmesin. | Evet | 4 sekme + merkez eylem | Elle |
| GEZ-4 | Boş olsa bile sekmeyi gizleme ya da devre dışı bırakma. | Evet | Tüm sekmeler hep açık | Elle |
| GEZ-5 | Her sekmede etiket göster (tek sözcük tercih). | Evet | Etiketler her zaman görünür | Elle |
| GEZ-6 | Kritik yeni bilgi için rozet kullan (sayı ya da ünlem). | Evet | `BuCountBadge`, sohbet rozeti | Elle |
| GEZ-7 | Sekme çubuğunda renkli içerik üstünde aynı tonu kullanma (okunurluk). | Evet | `nav`/`onNav` | Oto (M-a) |
| GEZ-8 | Sekmeler arası durumu koru (her sekme kendi yığınını hatırlasın). | Evet | `IndexedStack`/yığın | Elle |
| GEZ-9 | Modal görünümü yalnız net fayda varsa kullan; kısa ve odaklı tut. | Evet | `BuSheet`, tam ekran formlar | Elle |
| GEZ-10 | Modal görünümden çıkış yolu açık olsun (kapat/iptal); aynı anda tek modal. | Evet | Sayfa kapatma, `BuSheet` | Elle |
| GEZ-11 | Kaydedilmemiş değişiklik varken kapatmadan önce onay iste. | Evet | `BuConfirmSheet` (form sayfaları) | Elle |
| GEZ-12 | Modal görünüm başlığı görevi anlatsın. | Evet | `BuHeader` başlığı | Elle |
| GEZ-13 | Uygulama yeniden açılınca önceki konumu geri yükle. | Evet | Oturum/sekme geri yükleme | Elle |
| GEZ-14 | Sayfa başlığı kenardan kaydırarak geri dönüşü destekle. | Hayır (iOS'a özgü: kenardan geri kaydırma; Android'in sistem geri hareketi/düğmesi vardır, bkz. Çatışmalar) | — | — |

## 7. Başlıklar ve çubuklar (üst çubuk, araç çubuğu)
Kaynak: [Toolbars], [Tab bars], [Scroll views].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| BAS-1 | Her ekranın anlamlı, benzersiz bir başlığı olsun; kullanıcı konumunu bilsin. | Evet | `BuHeader`, AppBar 56 dp | Yarı (M-e) |
| BAS-2 | Üst çubukta yalnız sık kullanılan öğeleri tut; fazlası "Daha fazla" menüsüne. | Evet | Overflow menüsü | Elle |
| BAS-3 | Çubuk arka planını ve renkli kontrolleri en aza indir; standart bileşen kullan. | Evet | `BuIconButton` (40 dp görünür, 48 dp hedef) | Elle |
| BAS-4 | Başlıkta yalnız simge varsa çıkış/eylem etiketi (erişilebilir ad) ver. | Evet | `tooltip` / `Semantics` | Oto (M-e) |
| BAS-5 | Büyük, kaydırınca küçülen başlık. | Kısmen (Material 3 "büyük üst çubuk" karşılığı; zorunlu değil, bkz. Çatışmalar) | `headlineLarge` rolü tanımlı | Elle |
| BAS-6 | Dikkat dağıtmayan okuma için çubukları bağlama göre gizle. | Evet | Sohbet/medya görüntüleyici | Elle |
| BAS-7 | Kaydırma kenarı efekti (içeriğin çubuk altından geçerken ayrışması). | Hayır (iOS'a özgü: scroll edge effect; Android karşılığı M3 `scrolledUnderElevation` BU'da ayrı konu) | — | — |
| BAS-8 | Durum çubuğu stilini içeriğe göre ayarla (iOS durum çubuğu). | Hayır (iOS'a özgü: iOS durum çubuğu; Android durum çubuğu ikon rengi GUV-1 kapsamında) | — | — |

## 8. Listeler ve tablolar
Kaynak: [Lists and tables], [Collections], [Disclosure controls], [Pickers].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| LIS-1 | Metinli içerik için liste tercih et; görsel ağırlıklı içerikte ızgara. | Evet | `BuListTile`, `discover_masonry` | Elle |
| LIS-2 | Satır metnini kısa tut; uzunsa kesme yerine ayrıntı sayfasına yönlendir. | Evet | — | Yarı (M-c) |
| LIS-3 | Seçilince geri bildirim ver (gezinmede satırı vurgula, anahtarlarda durumu göster). | Evet | `BuPressable`, ripple | Yarı (M-b) |
| LIS-4 | Gruplu/başlıklı liste stilini veriye uygun seç. | Evet | `BuSectionHeader`, `BuGroup`, `BuSettingsTile` | Elle |
| LIS-5 | Ayrıntı bilgisi düğmesi yalnız bilgi içindir; alt hiyerarşiye geçiş için ayırıcı ok kullan. | Evet | `BuListTile` trailing chevron | Elle |
| LIS-6 | Satır sayısını sınırlı tut; uzun listeyi parçalara böl. | Evet | `CursorPage` sayfalama, `ListView.builder` | Yarı (kod incelemesi) |
| LIS-7 | Kaydırmalı listede liste öğesinin tamamı tek dokunma hedefi olsun. | Evet | Satır `InkWell` | Oto (M-b) |
| LIS-8 | Liste düzenleme (sıralama, silme) için açık bir düzenleme kipi. | Evet | Sohbet seçim modu | Elle |
| LIS-9 | İndeks çubuğu/alfabetik hızlı atlama. | Hayır (iOS'a özgü: tablo indeksi) | — | — |
| LIS-10 | Satır kaydırma eylemleri (sağa/sola) yalnız ek kısayol olsun. | Kısmen (Android'de `Dismissible`; DOK-5 gereği düğme alternatifi şart) | Sohbet/bildirim eylemleri | Elle |
| LIS-11 | Seçici (picker) kullanırken bağlam değiştirme; alanın yakınında göster. | Kısmen (Android: tarih/saat seçici dialog/sheet) | `acad_picker`, saat seçici | Elle |

## 9. Formlar ve klavye
Kaynak: [Text fields], [Entering data], [Virtual keyboards], [Toggles], [Segmented controls].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| FRM-1 | Alanın ne istediğini göster: ipucu + ayrı etiket (ipucu yazınca kaybolur). | Evet | `RefTextField`, `AkadTextField` etiket + ipucu | Elle |
| FRM-2 | Gizli veri için gizli alan; parolayı asla önceden doldurma. | Evet | `RefPasswordField` | Elle |
| FRM-3 | Alan boyu beklenen metne uysun; alanlar aralıklı ve hizalı. | Evet | `BuSize.field` 52 | Elle |
| FRM-4 | İçerik türüne uygun klavye (e-posta, sayı, URL, telefon). | Evet | `keyboardType` | Oto (M-g) |
| FRM-5 | Alanlar arası odak sırası mantıklı; klavyede Sonraki/Bitti eylemi doğru. | Evet | `textInputAction` | Oto (M-g) |
| FRM-6 | Sistemden alınabilecek bilgiyi isteme; otomatik doldurma ve yapıştırmayı destekle. | Evet | `autofillHints` | Oto (M-g) |
| FRM-7 | Mümkünse yazdırmak yerine seçenek sun. | Evet | Seçici/çip/segment | Elle |
| FRM-8 | Anlık doğrulama: hatayı alanın yanında, yazılırken/ayrılınca bildir. | Evet | `errorText`, `RefBanner` | Elle |
| FRM-9 | Zorunlu alanlar belli olsun; Devam düğmesi hazır olunca etkinleşsin. | Evet | Form düğmesi durumu | Elle |
| FRM-10 | Silme/temizle (X) düğmesi alanın sonunda. | Evet | `BuSearchField` temizle | Elle |
| FRM-11 | Anahtar (switch) yalnız liste satırında; liste dışında anahtar gibi davranan düğme kullan. | Evet | `BuSettingsTile` anahtarı | Elle |
| FRM-12 | Anahtarın iki durumu belirgin ayrışsın; ne açtığı satırdan anlaşılsın. | Evet | M3 Switch | Oto (M-a 3:1) |
| FRM-13 | Bölümlü denetim: birbirine yakın 2-5 seçenek, tutarlı genişlik, ya yalnız metin ya yalnız simge. | Evet | `BuSegmented` | Elle |
| FRM-14 | Kaydedilmemiş girdiyi kaybettirme (klavye kapanınca/ geri dönünce). | Evet | `w1g_autosave` mantığı | Elle |
| FRM-15 | Alan sınırlarını göster (uzun metni kes/sar). | Evet | `maxLength` sayaçları | Elle |

## 10. Düğmeler
Kaynak: [Buttons], [Toggles], [Pop-up buttons], [Pull-down buttons].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| DUG-1 | Düğmeler etraflarından ayrışsın ve çevresinde yeterli boşluk olsun. | Evet | `BuButton` 48 dp | Oto (M-b) |
| DUG-2 | Görünümde en olası eylem için belirgin (dolgulu) stil; tercih stille ayrışsın, boyutla değil. | Evet | `BuButtonKind.primary/outline/soft/text/danger` | Elle |
| DUG-3 | Aynı gruptaki seçenekler aynı boyutta olsun. | Evet | İki düğmeli satırlar | Elle |
| DUG-4 | Düğme amacını anlatsın: kısa metin ya da tanıdık simge; metin fiil ile başlasın. | Evet | `BuButton(label:)` | Yarı (M-j) |
| DUG-5 | Yıkıcı eylemi birincil (varsayılan) yapma; yıkıcı stil ayrı olsun. | Evet | `BuButtonKind.danger`, `BuDialogActionKind.destructive` | Elle |
| DUG-6 | Eylem sürüyorsa düğme içinde ilerleme göstergesi göster. | Evet | Düğme içi çember | Yarı (M-f) |
| DUG-7 | Tanıdık eylemlere tanıdık simge (paylaş, ara, kapat). | Kısmen (Android'in ortak simge dili; SF Symbols sembolleri kullanılmaz) | `BuIcons` (Hugeicons) | Elle |
| DUG-8 | Üç nokta (…) ek girdi isteyen eylemin başlığına eklenir. | Kısmen (Android menü kuralı değil; isteğe bağlı) | — | Elle |
| DUG-9 | Düğme etiketleri tutarlı sözlük kullansın (Kaydet/Gönder/Yeniden dene). | Evet | ARB sözlüğü | Yarı (M-j) |

## 11. Menüler, sheet, diyalog
Kaynak: [Menus], [Context menus], [Alerts], [Action sheets], [Sheets], [Popovers], [Modality].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| MNU-1 | Menü satırı etiketi eylemi kısa ve fiille anlatsın; erişilemeyen öğe soluk gösterilsin. | Evet | `PopupMenuButton`/`BuSheet` satırları | Elle |
| MNU-2 | Menü simgelerini tutumlu ve grup içinde tutarlı kullan. | Evet | — | Elle |
| MNU-3 | Uyarı (alert) seyrek kullan: yalnız kritik ve eyleme dönük bilgi için. | Evet | `BuDialog` | Elle |
| MNU-4 | Salt bilgi için uyarı gösterme; bağlam içinde sun. | Evet | `BuToast`, satır içi bildirim | Elle |
| MNU-5 | Geri alınabilir sık eylemler için uyarı çıkarma. | Evet | `BuToast` + geri al | Elle |
| MNU-6 | Açılışta uyarı gösterme; sorun varsa başka yolla anlat. | Evet | `BuOfflineBanner`, bakım bandı | Elle |
| MNU-7 | Uyarı başlığı durumu açık ve doğrudan anlatsın; tonu nötr ve yardımsever olsun. | Evet | ARB başlıkları | Yarı (M-j) |
| MNU-8 | Düğme başlıkları 1-2 sözcük, fiil tabanlı olsun; "Tamam"ı yalnız salt bilgi uyarısında kullan. | Evet | `BuDialogAction` | Oto (M-j) |
| MNU-9 | Varsayılan (en olası) düğme sonda/üstte; iptal başlangıç tarafta; yıkıcı eylem ayrı stil. | Evet | `BuDialogActionKind` | Elle |
| MNU-10 | Yıkıcı eylemde Cancel/Vazgeç düğmesi ver; Vazgeç varsayılan olmasın. | Evet | `BuConfirmSheet` | Elle |
| MNU-11 | Eylemle ilgili seçenekler için uyarı yerine eylem sayfası (action sheet) kullan. | Kısmen (Android karşılığı alt sayfa/ `BuSheet`) | `BuSheet` | Elle |
| MNU-12 | Aynı anda tek sheet; sheet içinden sheet açma. | Evet | — | Elle |
| MNU-13 | Sheet'te Tamam yerine İptal/Geri alternatifi; üç düğmeyi birlikte gösterme. | Evet | `BuBottomSheet` | Elle |
| MNU-14 | Yeniden boyutlanır sheet'te tutamaç (grabber) olsun; aşağı kaydırarak kapatma desteklensin. | Evet | `BuBottomSheet` tutamaç | Elle |
| MNU-15 | Sheet içeriği kısa ve odaklı olsun; karmaşık akış için tam ekran sayfa. | Evet | — | Elle |
| MNU-16 | Kaydırılan uyarı/eylem sayfasından kaçın (başlıkları kısa tut). | Evet | — | Yarı (M-c 2,0 ölçek) |
| MNU-17 | Popover (ok işaretli baloncuk) kuralları. | Hayır (iOS'a özgü: iPad/iPhone popover bileşeni; Android'de menü/ipucu balonu ayrı) | — | — |
| MNU-18 | Bağlam menüsü (uzun basma) kısayol olsun, tek yol olmasın. | Kısmen (Android uzun basma menüsü; DOK-5 geçerli) | Sohbet mesajı eylem menüsü | Elle |
| MNU-19 | Menü çubuğu, dock menüsü, düzenleme menüsü. | Hayır (iOS'a özgü: macOS/iPadOS menü çubuğu bileşenleri) | — | — |

## 12. Arama
Kaynak: [Search fields], [Searching].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| ARA-1 | İpucu metni neyin aranabileceğini söylesin. | Evet | `BuSearchField(hint:)` | Elle |
| ARA-2 | Yazarken aramaya başla (anlık sonuç). | Evet | `SearchPage` | Elle |
| ARA-3 | Son aramalar ve öneriler göster. | Evet | `recent_searches.dart` | Elle |
| ARA-4 | Sonuçları sadeleştir: en alakalıyı üste, kategorilere ayır. | Evet | `SearchProvider` türleri | Elle |
| ARA-5 | Kapsam çubuğu ile filtreleme; geniş kapsamla başla. | Evet | Sekme/çip kapsamı | Elle |
| ARA-6 | Arama alanında temizle düğmesi ve boş sonuç durumu. | Evet | `BuSearchField`, `BuEmptyState` | Yarı (M-f) |
| ARA-7 | Arama alanı dokunma hedefi rahat olsun (48 dp). | Evet | `BuSize.search` 48 | Oto (M-b) |

## 13. Geri bildirim, yükleme, boş durum, hata
Kaynak: [Feedback], [Loading], [Progress indicators], [Alerts], [Offering help].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| GBD-1 | Hiçbir şey göstermeden bekletme; yer tutucu/iskelet hemen çıksın. | Evet | `BuSkeleton` | Yarı (M-f) |
| GBD-2 | Bekleme sırasında kullanıcı başka işler yapabilsin (arka planda yükle). | Evet | `getSwr` önbellek-önce | Elle |
| GBD-3 | Süresi bilinen işte belirli (determinate) ilerleme; bilinmeyende spinner. | Evet | Yükleme çubuğu/spinner | Elle |
| GBD-4 | Yükleme göstergesi tutarlı yerde ve sürekli hareketli olsun; takılı kaldıysa durumu açıkla. | Evet | — | Elle |
| GBD-5 | Dairesel göstergeden çubuğa (ya da tersi) geçme. | Evet | — | Elle |
| GBD-6 | Mümkünse iptal edilebilsin; iptalin sonucunu söyle. | Evet | Yükleme iptali (gönderi/medya) | Elle |
| GBD-7 | Çek-yenile desteği; ayrıca otomatik yenileme. | Evet | `BuRefresh` | Elle |
| GBD-8 | Geri bildirim birden çok kanaldan gelsin (renk + metin + ses/haptik). | Evet | `BuToast` + `BuHaptics` | Elle |
| GBD-9 | Durum bilgisini ilgili yerde göster (satır içi). | Evet | `StaleBanner`, bakım bandı | Elle |
| GBD-10 | Önemli işlem tamamlanınca onayla; sıradan işlemde gürültü yapma. | Evet | `BuToast` | Elle |
| GBD-11 | Yapılamayan komutta nedenini söyle. | Evet | `error.<KOD>` i18n mesajları | Yarı (M-j) |
| GBD-12 | Her veri ekranında dört durum: yükleniyor, boş, hata, bakım (CLAUDE.md zorunlu kılar). | Evet | `BuViewState`, `BuEmptyState`, `BuErrorState`, bakım bandı | Yarı (M-f) |
| GBD-13 | Hata ekranında yeniden dene eylemi ve anlaşılır neden. | Evet | `BuErrorState(onRetry)` | Yarı (M-f, M-j) |
| GBD-14 | Hata mesajını bildirim olarak gösterme; uyarı/satır içi kullan. | Evet | — | Elle |
| GBD-15 | Beklenmedik ve geri alınamaz veri kaybını önceden uyar. | Evet | `BuConfirmSheet` | Elle |
| GBD-16 | Yardım ipuçları kısa, eyleme dönük ve gerekmedikçe tekrarlanmasın. | Evet | `push_help_page` | Elle |

## 14. Erişilebilirlik
Kaynak: [Accessibility], [VoiceOver], [Inclusion], [Motion].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| ERS-1 | Ekran okuyucu için tüm etkileşimli ve anlamlı öğelere etiket ver (VoiceOver = Android TalkBack). | Evet | `Semantics`, `tooltip`, `labeledTapTargetGuideline` | Oto (M-b, M-e) |
| ERS-2 | Anlamlı görselleri betimle; süs görsellerini okuyucudan çıkar. | Evet | `BuImage(semanticLabel)` (varsayılan süs) | Oto (M-e) |
| ERS-3 | Başlık ve alt başlıkları belirt; her ekranın ilk okunan bilgisi benzersiz başlık olsun. | Evet | `Semantics(header: true)` | Yarı (M-e) |
| ERS-4 | Okuma sırası ve gruplama görsel sırayla uyuşsun (RTL dahil). | Evet | `MergeSemantics`, `sortKey` | Elle |
| ERS-5 | Yazı boyutu büyütmeyi destekle (en az %200). | Evet | Bkz. TIP-6 | Oto (M-c) |
| ERS-6 | Bilgiyi renk dışında bir yolla da ver (sembolsüz bilgi: ikon, metin). | Evet | Bkz. REN-4 | Yarı |
| ERS-7 | Kontrast eşiklerini sağla. | Evet | Bkz. REN-5 | Oto (M-a) |
| ERS-8 | Hareketi azalt ayarına uy: otomatik, tekrarlayan hareketleri sadeleştir; hareket tek bilgi yolu olmasın. | Evet (Android "animasyonları kaldır") | `BuMotion.reduced` | Not (hareket denetim dışı) |
| ERS-9 | Süreye bağlı kaybolan öğelerden kaçın; kapatma eylemi açık olsun. | Evet | `BuToast` süresi, banner kapat | Elle |
| ERS-10 | Otomatik oynayan ses/video'yu kontrolsüz bırakma. | Evet | Video oynatıcı | Elle |
| ERS-11 | Yanıp sönen ışığa duyarlı kullanıcıyı gözet. | Evet | — | Elle |
| ERS-12 | Sadeleştirilmiş arayüz kipi (Assistive Access). | Hayır (iOS'a özgü: Assistive Access) | — | — |
| ERS-13 | Kapsayıcı dil: sade, jargonsuz, kişiyi doğrudan "sen/siz" ile anan metin. | Evet | ARB tonu | Yarı (M-j) |
| ERS-14 | Ekran okuyucuyla grafik/infografik betimlemesi. | Evet | Anket sonuç çubukları | Elle |

## 15. Karanlık mod
Kaynak: [Dark Mode], [Color].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| KAR-1 | Sistemin görünüm tercihine uy; uygulamaya özel görünüm ayarı sunma (aksi hâlde kullanıcı iki ayarla uğraşır). | Kısmen (Android 10+ sistem karanlık tema; bkz. Çatışmalar: BU'da uygulama içi tema seçici var) | `ThemeController` (sistem/açık/koyu) | Elle |
| KAR-2 | Uygulama her iki görünümde de iyi görünsün; "Otomatik" gün içinde değişebilir. | Evet | Her ekran çift temalı test | Oto (M-b, M-i) |
| KAR-3 | Koyu zemin: daha koyu zemin, daha parlak ön plan; renkler yalnızca ters çevrilmez. | Evet | `BuTokens.dark` | Oto (M-a) |
| KAR-4 | Saf siyah/beyaz yerine yumuşak tonlar; beyaz zeminli görseli hafif karart. | Evet | `bg` 0xFF171819 | Elle |
| KAR-5 | Anlamsal renkleri kullan; sabit renk gömme. | Evet | `context.bu` | Oto (M-d1, M-i) |
| KAR-6 | Katmanlı yüzeylerde yükseltilmiş (daha açık) zemin kullan. | Evet | `sf`, `sf2`, `sf3` | Elle |
| KAR-7 | Her iki görünümde tüm metin kontrastı ≥ 4,5:1; küçük metinde 7:1'e yaklaş. | Evet | Bkz. REN-5/6 | Oto (M-a) |
| KAR-8 | İkon ve görseller iki görünümde de iyi görünsün; gerekirse ayrı varlık. | Evet | `BuIcons` tek renk jetonu | Elle |
| KAR-9 | Yalnız-koyu görünüm yalnızca medya odaklı özel durumlarda. | Evet | Medya görüntüleyici (`scrim`) | Elle |

## 16. Simgeler ve görseller
Kaynak: [Icons], [Images], [Image views], [SF Symbols], [App icons].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| SIM-1 | Simge sade olsun, tek kavram anlatsın, tanıdık olsun. | Evet | Hugeicons `BuIcons` | Elle |
| SIM-2 | Tüm arayüz simgeleri tutarlı boyut, ayrıntı ve çizgi kalınlığında olsun. | Evet | `BuIcons` tek aile | Elle |
| SIM-3 | Simge ağırlığı yanındaki metinle uyumlu olsun. | Evet | — | Elle |
| SIM-4 | Seçili durum simgesini yalnız gerekirse ayrıca sun. | Evet | Gezinmede seçili/çizgili ayrımı | Elle |
| SIM-5 | Optik hizalama için gerekirse dolgu ekle. | Evet | — | Elle |
| SIM-6 | Simgede metin yalnız zorunluysa; kapsayıcı ve kültürler arası anlaşılır figürler. | Evet | — | Elle |
| SIM-7 | Vektör biçim (SVG/PDF) kullan; bitmap'te her yoğunluk için varlık sun. | Kısmen (Android: vektör ya da mdpi-xxxhdpi; Flutter 1x/2x/3x) | `BuIcons` yazı tipi, `assets/` | Elle |
| SIM-8 | Görsel üstüne yazı bindirirken okunurluğu koru. | Evet | `scrim` + `onMedia` | Yarı (M-a medya) |
| SIM-9 | Görselleri farklı gerçek cihazlarda test et (bulanıklık/kırpma). | Evet | `BuImage` | Elle |
| SIM-10 | Uygulama simgesi: tek net kavram, metinsiz. | Kısmen (Android uyarlanabilir simge, katmanlı) | `branding/` | Elle |
| SIM-11 | SF Symbols kullanımı, animasyonlu semboller, işleme kipleri. | Hayır (iOS'a özgü: SF Symbols) | — | — |

## 17. Yazma ve dil tonu (UX writing)
Kaynak: [Writing], [Inclusion], [Alerts], [Buttons], [Onboarding].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| YAZ-1 | Uygulamanın sesini belirle; ton bağlama göre değişsin (ciddi durumda doğrudan, kutlamada samimi). | Evet | Türkçe düz, nazik ton | Yarı (M-j) |
| YAZ-2 | Açık ol: gereksiz sözcüğü at, yüksek sesle oku. | Evet | — | Yarı (M-j) |
| YAZ-3 | Düğme ve bağlantı etiketleri fiil ile başlasın (eylem odaklı, etken çatı). | Evet | `Kaydet`, `Gönder`, `Yeniden dene` | Yarı (M-j) |
| YAZ-4 | Kalıp ve sözlük tutarlılığı: aynı eylem hep aynı adla anılsın. | Evet | ARB'de "Yeniden/Tekrar dene" ikiliği | Oto (M-j tutarlılık) |
| YAZ-5 | Büyük/küçük harf kuralını belirle ve tutarlı uygula (Türkçede cümle düzeni). | Kısmen (HIG kuralları İngilizce başlık düzenine göre; Türkçede cümle düzeni) | Büyük harf etiketler (`KİŞİLER` gibi) | Oto (M-j) |
| YAZ-6 | Çok adımlı akışta adımları aynı sözcüklerle adlandır (Devam/İleri). | Evet | `authNext` vs `profil2Continue` | Oto (M-j) |
| YAZ-7 | Hata mesajı: ne oldu, neden, ne yapmalı; suçlayıcı ve belirsiz olmasın. | Evet | `error.<KOD>` i18n | Yarı (M-j) |
| YAZ-8 | Uyarıda belirsiz "Tamam" yerine sonucu anlatan fiil. | Evet | `Tamam` 3 yerde | Oto (M-j) |
| YAZ-9 | Kullanıcıya "siz/sen" ile seslen; "kullanıcı" deme. | Evet | — | Elle |
| YAZ-10 | Jargon ve deyimlerden kaçın; teknik hata kodu gösterme. | Evet | Hata kodu gösterilmiyor | Oto (M-j) |
| YAZ-11 | Ardışık ünlem ve TAMAMI BÜYÜK metinden kaçın. | Evet | — | Oto (M-j) |
| YAZ-12 | Yerelleştirmeye hazır yaz (metin uzaması, kesme işareti, sayılar). | Evet | tr/en/ar ARB | Oto (M-c, M-h) |

## 18. Gizlilik ve izin istemleri
Kaynak: [Privacy], [Managing accounts], [Settings].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| GZL-1 | Yalnız gerçekten gerekli veriyi/izni iste. | Evet | `AppPermission` bağlamsal istek | Elle |
| GZL-2 | İzni, ilgili özelliğe ilk gereksinim anında iste; açılışta toplu isteme. | Evet (Android 13+ bildirim izni çalışma zamanında) | `PostLoginGate` ilk girişte 3 izni birden anlatır | Elle |
| GZL-3 | İzin gerekçesini açık yaz: uygulama bu veriyi neden kullanır. | Evet | `sistemuiPerm*Text` | Elle |
| GZL-4 | Kullanıcının izin kararına saygı göster; reddedilince özellik zarifçe çalışsın ve ayara yönlendir. | Evet | `PermState.permanentlyDenied` yolu | Elle |
| GZL-5 | Veriyi cihazda işle; topladığını şeffaf anlat. | Evet | KVKK ekranları, `DataExporter` | Elle |
| GZL-6 | Bildirim içeriğine hassas bilgi koyma. | Evet | Mesaj önizleme ayarı | Elle |
| GZL-7 | Kimlik doğrulama yöntemini adıyla belirt; yalnız mevcut yöntemden söz et. | Kısmen (Android biyometrik kapsamı BU'da yok) | — | — |
| GZL-8 | Hesap oluşturmaya izin veriyorsan uygulama içinden silmeyi de sun. | Evet | `profil2_delete_account_page` | Elle |
| GZL-9 | Sistem düzeyindeki ayarı uygulama içinde kopyalama (gereksiz yinelenen ayar). | Evet | Bkz. Çatışmalar (tema/dil) | Elle |
| GZL-10 | Apple ile Giriş, Apple'a özgü gizlilik etiketleri. | Hayır (iOS'a özgü: Sign in with Apple, App Store gizlilik etiketleri) | — | — |

## 19. Giriş ve kayıt akışları
Kaynak: [Managing accounts], [Onboarding], [Launching], [Entering data].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| GKA-1 | Hesabı yalnız çekirdek işlev gerektiriyorsa iste; mümkünse girişi ertele. | Kısmen (BU hesap zorunlu: kurumsal e-posta) | `AppGate` | Elle |
| GKA-2 | Hesabın faydasını ve nasıl oluşturulacağını kısaca anlat. | Evet | `WelcomePage` | Elle |
| GKA-3 | Kayıt formunu kısa tut; sistemden alınabilen bilgiyi isteme. | Evet | `RegisterPage` | Elle |
| GKA-4 | Doğrulama kodu girişinde otomatik odak, yapıştırma ve yeniden gönderme. | Evet | `OtpCodeBoxes` | Elle |
| GKA-5 | Parolayı göster/gizle; yönetici/parola yöneticisi ile otomatik doldur. | Evet | `RefPasswordField`, `autofillHints` | Oto (M-g) |
| GKA-6 | Açılış hızlı olsun; açılış ekranı ilk ekrana benzesin, metin ve reklam içermesin. | Kısmen (Android 12+ sistem açılış ekranı simgesi) | `splash_screen.dart` | Elle |
| GKA-7 | Tanıtım (onboarding) kısa, etkileşimli ve atlanabilir olsun; lisans metnini içine gömme. | Evet | İzin sayfası + `legal` | Elle |
| GKA-8 | Gerekmeyen kurulumu sonraya bırak, makul varsayılan ver. | Evet | — | Elle |
| GKA-9 | Oturum süresi dolunca bağlamı kaybetmeden yeniden doğrulat. | Evet | `authSessionExpired` | Elle |
| GKA-10 | Hata durumlarında numaralandırmaya (enumeration) yol açma; genel mesaj (güvenlik kuralı, CLAUDE.md). | Evet | Genel cevaplar | Elle |
| GKA-11 | Sözleşme onayı açıkça ve ayrı bir adımda, metin okunabilir. | Evet | `acceptTerms` | Elle |

## 20. Bildirimler
Kaynak: [Notifications], [Managing notifications].

| Kod | Kural | Android | BU karşılığı | Ölçüm |
|---|---|---|---|---|
| BIL-1 | İzin almadan bildirim gönderme; izin isteğini bağlama oturt. | Evet | `PostLoginGate`, `push_help_page` | Elle |
| BIL-2 | Bildirim kısa, bilgilendirici olsun; aynı şey için tekrar bildirim gönderme. | Evet | `PushDispatcher` toplulaştırma | Elle |
| BIL-3 | Aciliyeti dürüst belirt (zaman duyarlı yalnız anlık durumlar için). | Kısmen (Android bildirim kanalı önem düzeyi) | Android kanalları | Elle |
| BIL-4 | Bildirimde "uygulamada şunu yap" diye görev yükleme. | Evet | — | Elle |
| BIL-5 | Hata mesajını bildirim olarak verme; uyarı kullan. | Evet | — | Elle |
| BIL-6 | Uygulama açıkken gelen bildirimi zarifçe işle (banner). | Evet | `push_banner.dart` | Elle |
| BIL-7 | Hassas/kişisel bilgiyi bildirim metnine koyma. | Evet | Mesaj önizleme varsayılanı | Elle |
| BIL-8 | Pazarlama bildirimi için açık onay al. | Evet | Kampanya tercihleri | Elle |
| BIL-9 | Bildirim kategorileri için ayrı tercih; kullanıcı kontrolü. | Evet | `notification_prefs_page` | Elle |
| BIL-10 | Focus modları, zaman duyarlı kesinti seviyeleri, Live Activities, widget. | Hayır (iOS'a özgü: Focus ve Live Activities) | — | — |

## 21. Hareket (yalnız not)
Kaynak: [Motion]. Denetim kapsamı dışı (başka ajan `feat/motion-system` dalında). Yalnız çapraz kural: hareket amaçlı, isteğe bağlı ve iptal edilebilir olsun; "animasyonları azalt" ayarına uyulsun (ERS-8).

## 22. iOS'a özgü kurallar (listelenir, uygulanmaz)
Aşağıdakiler Android'e taşınmaz ve bu projede uygulama önerisi yazılmaz:
- SF Symbols, sembol renk modları ve animasyonlu semboller [SF Symbols, Icons]
- San Francisco/New York sistem yazı tipleri, Dynamic Type erişilebilirlik kademeleri [Typography]
- Kenardan geri kaydırma hareketi, kaydırma kenarı efekti, Liquid Glass malzemesi [Gestures, Materials, Toolbars]
- Dynamic Island, Live Activities, Always-On, karmaşalar (complications), Kontrol Merkezi, Action button [Live Activities, Always-on, Action button]
- Haptik motor tasarımı (Taptic Engine) [Playing haptics] (Android'de `HapticFeedback` ayrı, basit tutulur)
- App Clips, Sign in with Apple, Apple Pay, Wallet, HealthKit, HomeKit, CarPlay, Siri/Kısayollar, SharePlay, AirPlay [ilgili sayfalar]
- visionOS, watchOS, tvOS, macOS ve iPadOS'a özgü bileşenler (sidebar, menü çubuğu, ornament, Digital Crown, odak sistemi) [designing-for-*]

---

## Çatışmalar: Apple ilkesi ile Android/Material 3 davranışı arasında

| # | Apple ilkesi | Android/Material 3 gerçeği | BU'nun bugünkü durumu | Öneri |
|---|---|---|---|---|
| Ç-1 | Kenardan geri kaydırma, başlık çubuğunda geri düğmesi | Sistem geri hareketi/düğmesi (öngörülü geri, Android 13+) tüm uygulamalarda; uygulama kenar hareketlerini sahiplenmemeli | `enableOnBackInvokedCallback` açık, `PopScope` 16 dosyada, `back_navigation_test` | Kenara yakın yatay kaydırma gerektiren bileşenleri (şerit, çekmece) kenardan ≥ 24 dp içeri çek; üst çubukta geri düğmesi kalsın |
| Ç-2 | Büyük başlık (kaydırınca küçülür) | M3 "Large top app bar" isteğe bağlı; küçük üst çubuk yaygındır | `headlineLarge` rolü tanımlı, ekranlar çoğunlukla 56 dp üst çubuk | Mevcut sade üst çubuk korunur; büyük başlık yalnız üst düzey sekmelerde denemelik (kullanıcı onayı) |
| Ç-3 | Sekme çubuğu yalnız gezinme içindir, eylem taşımaz | M3 `NavigationBar` + ayrı FAB; ortada eylem düğmesi Material'de FAB olarak ayrı durur | `FloatingNav` ortasında "Paylaş" eylemi var | Eylemi sekme sırasından çıkarıp FAB/üst çubuk eylemine taşımak (görünüm değişir, kullanıcı onayı); aksi hâlde erişilebilir adı ve 48 dp hedefi korunsun |
| Ç-4 | Sekme çubuğu zemine tam oturur, malzeme (cam) üzerinde | M3 `NavigationBar` tam genişlik, sistem gezinme alanı üstünde | Yüzen hap (kenarlardan 16 dp) | Hap kalabilir; alt boşluk sistem hareket alanıyla çakışmamalı (GUV-4) ve içerik payı korunmalı |
| Ç-5 | Uygulamaya özel görünüm (tema) ayarı sunma | Android 10+ sistem teması var; birçok uygulama yine de tema seçici sunar | `ThemeController` sistem/açık/koyu | Varsayılan "sistem" kalsın; seçiciyi Ayarlar'da tut (Android 9 ve altı için gerekli); kullanıcıya zarar vermez |
| Ç-6 | Sistem ayarını uygulamada kopyalama | Android 13+ uygulama başına dil ayarı var | Uygulama içi dil seçici | Uygulama içi dil kalsın ya da `LocaleManager` ile birleştir (bu iş kapsam dışı, teknik karar) |
| Ç-7 | Dokunma hedefi 44 pt | Material 48 dp | `BuSize.touch` 48 | 48 dp'yi koru (yönerge Android'de daha sıkı) |
| Ç-8 | Dynamic Type erişilebilirlik kademeleri | Android yazı ölçeği üst sınırı ~%200 | Testler 1,3 ve 2,0 | 2,0 ölçek asgari hedef olarak kalsın |
| Ç-9 | Anahtar yalnız liste satırında | M3 Switch aynı kuralı izler | Uygun | Çatışma yok |
| Ç-10 | Uyarıda "OK" kaçın, fiil kullan | Material de özel fiil önerir | `Tamam` 3 yerde | Fiille değiştir (görünüm değişimi az, güvenli metin işi) |
| Ç-11 | Açılışta marka/metin içeren ekran gösterme | Android 12+ simge tabanlı açılış ekranı zorunlu | Özel `splash_screen.dart` | Sistem açılış ekranı + hızlı ilk kare; özel ekran kısa kalsın |
| Ç-12 | Bildirim izni bağlamda istenir | Android 13+ aynı | İlk girişte 3 izin (bildirim, kişiler, kamera) birden | Kişiler ve kamerayı ilk kullanım anına kaydır; bildirim izni için ön açıklama kalsın (kullanıcı onayı) |
| Ç-13 | Tamamı büyük harf etiketlerden kaçın (Türkçede ek sorun: İ/I) | Material etiketleri genellikle cümle düzeni | `KİŞİLER`, `BUGÜN` gibi bölüm etiketleri | Cümle düzenine çevir (görünüm değişir, kullanıcı onayı) |
| Ç-14 | Satır kaydırma eylemi tek yol olmasın | Android uzun basma/menü yaygın | Uygun | Her eylemin düğme/menü karşılığını doğrula (DOK-5) |
