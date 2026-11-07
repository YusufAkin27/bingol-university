# NAV: alt gezinme yeniden tasarımı ("Cam hap")

Durum: TASARIM, uygulanmadı; kullanıcı onayı bekleniyor. Üretim koduna (features/shell, widgets) dokunulmadı.
Prototip + ölçüm testi: `mobile/test/redesign/nav_secenek_shots_test.dart` (yalnız test dosyası; üretim kodunu içe aktarmaz,
yalnız `BuCountBadge`, `ChatlistAvatar`, `BuMotion`, `buHaptic`, `BuTokens`'ı olduğu gibi kullanır).
Ekran görüntüleri: `C:\bu_qa\shots\tasarim\nav\` (aşağıda dosya listesi). Stitch mockup'ı üretilmedi (Flutter prototipleri yeterli).

Not: İlk görevde 3 seçenek (Sakin hap / Düz çubuk / Ada) istenmişti; kullanıcı referans görselle yönü seçti
(iOS tarzı yüzen cam hap, yalnız ikon, kayan oval, dolu seçili ikon). Bu belge yalnız o yönü anlatır.

## 1. Referans görsel analizi

Referans (13.png, 1170x215 px): koyu gri yarı saydam, tam yuvarlak uçlu uzun hap; 5 sekme yalnız ikon (ev, oynat,
gönder, ara, profil), etiket yok.

| Özellik | Referansta ölçülen | Bizdeki karşılığı |
|---|---|---|
| Hap oranı | ~875 x 150 px = 5.8:1, uçlar tam yarım daire | 320 x 64 dp = 5:1, `RoundedSuperellipseBorder(r = yükseklik/2)` |
| Zemin | koyu gri, arkadaki gri zeminden belirgin ayrışır ama altı seçilir (buzlu cam) | `sf3` (koyu) / `sf` (açık) yarı saydam dolgu (%80-82) + ic parlama gradyanı; BackdropFilter YOK |
| Kenar | üstte ince açık "ışık" çizgisi, aşağı doğru solar | 1 dp gradyan kenar: üst `onMedia` %40 (koyu) / %95 (açık), alt %6 / %30 |
| Seçili zemin | açık gri OVAL (yumurta), yüksekliği hapın ~%83'ü, genişliği ~1.5x yükseklik, komşu sekme alanına hafif taşar | oval 58 x 44 dp (hap 64), sekme alanı 62 dp |
| Seçili ikon | DOLU beyaz (oynat içi kesik), diğerleri beyaz çizgi (outline) | dolu = Lucide geometrisi dolgulu, iç ayrıntı "oyuk" renginde |
| İkon boyutu / aralık | ~28 dp, aralar ferah | 28 dp ikon, 62 dp sekme aralığı |
| Gölge | belirsiz/çok hafif | tek gölge, dışa doğru (alttan sızmaz) |

## 2. Ana tasarım: "Cam hap"

```
 20 dp          320 dp (en çok), ekranın ortasında            20 dp
|--|  ( home   [oval: dolu compass]   chat   users   avatar )  |--|
        64 dp yüksek, uçlar tam yuvarlak, güvenli alandan 12 dp yukarıda yüzer
```

Sekmeler (sıra aynı): Ana Sayfa `house`, Keşfet `compass`, Sohbet `message-circle` (+ okunmamış rozeti), Kulüpler `users`,
Profil = kullanıcının avatarı (halka). Hepsi yalnız ikon; etiket yok (erişilebilirlik adı Semantics'te kalır).

### 2.1 Ölçüler

| Öğe | Değer |
|---|---|
| Hap yüksekliği | 64 dp (yazı ölçeğinden bağımsız: etiket yok) |
| Hap genişliği | `min(320, ekran - 40)`: 390 dp'de 320, 360 dp'de 320 (kenar 20), 320 dp'de 280 |
| Sekme alanı | `(genişlik - 10) / 5` = 62 dp (320 dp ekranda 54), yükseklik 64: dokunma hedefi >= 54 x 64 (kural 48 x 48) |
| Seçili oval | 58 x 44 dp, süper-elips, sekme merkezinde |
| İkon | 28 dp (Lucide 24 birimlik viewBox, çizgi 2 -> 2.33 dp) |
| Avatar (Profil) | 28 dp halka (çizgi 1.75, seçiliyken 2.25) + 22 dp fotoğraf |
| Alt boşluk | `max(güvenliAlan - 12, 12)`: iPhone (34) 22 dp, Android/jest (0) 12 dp |
| Toplam alt alan | 64 + alt boşluk = iPhone 86 dp, Android 76 dp (mevcut, ölçüldü: iPhone 98 dp, Android 80 dp) |

Not: "güvenli alandan 12 dp yukarı" literal alınırsa iPhone'da alt boşluk 46 dp olur (toplam 110 dp, mevcuttan 12 dp FAZLA).
Önerim: ev göstergesi güvenli alanın alt ~13 dp'sinde durur; hapı 22 dp'ye (göstergenin 9 dp üstüne) indirmek yeterlidir.
Tek sabit (`ProtoNav.bottomGap`): literal istenirse `inset + 12` yapılır.

### 2.2 Cam yüzey (BackdropFilter olmadan)

Katmanlar (tek `CustomPainter`, `RepaintBoundary` içinde, ~5 çizim çağrısı):
1. Gölge: yalnız şeklin DIŞINA (kırpılmış), tek gölge: 5 kademeli yarı saydam halka (açık: `shadow` %14, y 8; koyu: `scrim` %38). MaskFilter blur kullanılmaz (hem ucuz hem test/Skia yazılım çiziminde de yumuşak; ilk denemede `BoxShadow.toPaint` testte sert kenarlı çıktı).
2. Dolgu: koyu `sf3` %80, açık `sf` %82 (arkadaki fotoğraf/metin hafifçe seçilir, "buzlu" izlenimi).
3. İç parlama: üstten alta `onMedia` gradyanı (koyu %9, açık %65), %62'de kaybolur.
4. Dış çizgi (yalnız açık tema): `bd` %85, 1 dp.
5. Üst ışık kenarı: 1 dp, dikey gradyan çizgi (üst parlak, alt silik).

Gerçek `BackdropFilter(blur)` farkı: arkadaki içeriği gerçekten bulanıklaştırır (metin/görsel okunmaz olur), yarı saydam dolgu
ile bu mümkün değil: içerik hap altında net ama silik görünür. Bunu dengelemek için dolgu opaklığı %80+ tutuldu. Blur
her karede arkadaki katmanı yeniden örnekler (kaydırılan liste altında); bu uygulamada Keşfet masonry gibi ağır
listelerin altında düşük/orta cihazlarda kare süresini artırır. Mevcut FloatingNav de blur (sigma 16) kullanıyor:
yeni tasarımla birlikte KALDIRILMASI iyi bir performans kazancıdır. İsteğe bağlı blur: varsayılan KAPALI; açılırsa tek
`bool kNavBlur` ile; ölçmeden açmayın (bu çalışmada cihazda ölçüm YAPILMADI, "doğrulanamadı").

### 2.3 İkon ailesi ve "dolu" seçili ikon

Lucide'de dolu varyant yok (yalnız çizgi ağırlıkları 100-600). Çözüm, aile karışmasın diye AYNI Lucide geometrisini
çizmek: dört ikonun SVG yolları (lucide_icons_flutter 4.0.1 kaynak SVG'si) `Path` olarak çizilir:
- çizgi hali: çizgi 2, dolgu yok (fonttaki ikonla birebir aynı şekil);
- dolu hali: kapalı gövde dolgulu + çizgi; iç ayrıntı "oyuk" (oval zemin rengi): ev kapısı, pusula ibresi; sohbet balonu ve
  kulüp (iki kişi) düz dolgu.
- geçiş: dolgu alfa 0 -> 1 (150 ms), renk `ink` -> `pr`: "çapraz solma".
Üretimde 4 yol sabiti + küçük `LucideFillPainter` (~80 satır) yeterli; SVG ayrıştırıcı için `path_parsing` (zaten `flutter_svg`
bağımlılığı olarak pubspec.lock'ta) ya da yolların elle `Path` komutlarına çevrilmesi (4 ikon, ~15 komut).
Alternatif (daha basit, daha az "dolu"): `Lucide600` ağırlığı (kalın çizgi 2.4+) fontu; ek font varlığı gerekir.

### 2.4 Renk/vurgu varyantları (ikisi de prototipte)

| | K: kırmızı tint oval | N: nötr oval |
|---|---|---|
| Seçili oval | `soft` (marka kırmızısının yumuşak tonu) | açık: `ink` %8, koyu: `onMedia` %16 (gri) |
| Seçili ikon | `pr` dolu | `pr` dolu |
| Seçili olmayan ikon | `ink` çizgi | `ink` çizgi |
| Hover/basılı ayna oval | oval rengi %40 / %70 | oval rengi %40 / %70 |

Her iki varyantta tek vurgu = marka kırmızısı, yeni renk yok.

### 2.5 Durum tasarımı (her sekme için)

| Durum | Oval | İkon | Süre |
|---|---|---|---|
| Normal | yok | çizgi, `ink` | |
| Hover (fare/emülatör) | ayna oval %40 | çizgi, ölçek 1 | 150 ms |
| Basılı | ayna oval %70 | çizgi, ölçek 0.92 | 100 ms |
| Seçili | kayan oval tam | DOLU, `pr` | oval 250 ms, dolgu 150 ms |
| Seçili + basılı | oval tam + `ink` %7 koyulaşma | dolu, ölçek 0.92 | 100 ms |
| Rozetli (Sohbet, seçili değil) | | ikon + `BuCountBadge` (sağ üst, `-10/-8`) ya da 11 dp nokta (hap rengiyle 2 dp çerçeve) | |
| Rozetli + seçili | | rozet GİZLENİR (kullanıcı zaten sohbette), mevcut davranış | 250 ms ölçek |
| Devre dışı | yok (sekme hiç devre dışı olmaz) | | |

Rozet kuralı önerisi: sayı varsayılan (99+ üst sınır); nokta = yalnız sessize alınmış sohbetlerde okunmamış var (sayı
sızdırmamak için) ve küçülmüş (kaydırınca) halde sayı yerine nokta.
Hover yalnız fare/emülatör içindir (`MouseRegion`); dokunmatikte "basılı" durumu hover görevini görür.

### 2.6 Seçim geçiş animasyonu

- Oval: eski sekmeden yenisine KAYAR; tek `TweenAnimationBuilder<double>` + `Transform.translate` (yalnız transform), 250 ms,
  `Curves.easeOutCubic` (`BuMotion.decelerate`). Hafif yaylanma isteniyorsa `Curves.easeOutBack` (sınır dışına ~%3 taşar:
  önerilmez, hap kenarında kırpılır). RTL'de x yönü aynalanır.
- İkon dolgusu 150 ms alfa geçişi (çapraz solma), renk `ink` -> `pr`; basılıyken ölçek .92 (100 ms, easeOut).
- Haptic: `buHaptic(BuHaptic.selection)` yalnız sekme DEĞİŞİNCE (aynı sekmeye dokunmak değiştirmez).
- Aynı sekmeye dokunma: mevcut davranış (listeyi başa kaydırma) korunur.
- "Animasyonları azalt" açıkken: süreler 0 (`BuMotion.of`), oval anında yerinde.
- Sekme içeriği geçişi (`_TabFade`) değişmez.
- Bütçe: kayan oval + 2 ikon dolgusu + 1 ölçek = kare başı ~4 küçük çizim; Gaussian bulanıklık yok.

### 2.7 Kaydırma ve klavye

- Aşağı kaydırınca: hap `scale .86` (alt-orta çıpalı) + `translateY ~4 dp`, 250 ms `standard`; yukarı kaydırınca (ya da
  liste başında/sonunda) geri 1.0. Yalnız transform; YER AYIRMA sabit kalır (liste zıplamaz). Küçülmüş sekme hedefi
  62 x .86 = 53 dp (>= 48 kuralını korur). Kapatılabilir (tek bayrak); varsayılan AÇIK önerilir.
  Uygulama: `NotificationListener<UserScrollNotification>` kabukta (derinlik 0, yalnız dikey), `ValueNotifier<bool> navCompact`.
  Sohbet ve Profil gibi kısa içerikte tetiklenmez (kaydırma eşiği 24 dp).
- Klavye açıkken: hap gizlenir (mevcut `AnimatedSize` davranışı), yer ayırma 0.
- Ekran okuyucu odağı hap üzerindeyken küçülme/gizleme uygulanmaz.

### 2.8 İçeriğin alt boşluğu (tek kaynak)

`Scaffold(extendBody: true)` gövdeye `MediaQuery.padding.bottom` olarak çubuğun GERÇEK ölçülü yüksekliğini verir
(testle doğrulandı: gövde payı = ölçülen çubuk alanı, 0.6 dp tolerans). Bu nedenle sabit `kNavInset` kalkar:

```dart
/// widgets/bu_scroll_padding.dart
abstract final class BuScrollPadding {
  static const double breath = 12;
  /// Kaydırılabilir gövdenin altına bırakılacak pay: bar alanı (Scaffold ölçer) + 12 dp nefes.
  static double bottom(BuildContext c) => MediaQuery.paddingOf(c).bottom + breath;
}
```
Kullanım: `EdgeInsets.only(bottom: BuScrollPadding.bottom(context))`. Çubuk yüksekliği/güvenli alan/klavye değişince otomatik
doğru (klavye açıkken çubuk 0 yer tutar). `kNavInset` ve `BuSize.nav/navGap/navInset` bu yardımcıya yönlendirilir
(9 dosya, 12 kullanım: bu_widgets.dart:961, app_gate.dart:243, chat_tab x2, clubs_tab x2, discover_masonry, home_tab,
home_parts, profile_tab, bu_page_scaffold doc yorumu).

## 3. Ölçümler (prototip testi, doğrulandı)

| Senaryo | Alt alan (ölçülen) | Scaffold gövde payı | Hap genişliği / kenar | Sekme hedefi |
|---|---|---|---|---|
| MEVCUT FloatingNav, güvenli alan 0 | 80 dp (hap 64 + 16) | - | tam genişlik - 32 | 57+ x 64 |
| MEVCUT FloatingNav, güvenli alan 34 | 98 dp (hap 64 + 34) | - | tam genişlik - 32 | 57+ x 64 |
| YENİ 360 dp, güvenli alan 0 | 76 dp | 76 dp (= bar alanı) | 320 / kenar 20 | 62 x 64 |
| YENİ 360 dp, güvenli alan 34 | 86 dp | 86 dp | 320 / kenar 20 | 62 x 64 |
| YENİ 390 dp, güvenli alan 0 | 76 dp | 76 dp | 320 / kenar 35 | 62 x 64 |
| YENİ 390 dp, güvenli alan 34 | 86 dp | 86 dp | 320 / kenar 35 | 62 x 64 |
| YENİ 320 dp, yazı x1.3, güvenli alan 34 | 86 dp | - | 280 / kenar 20 | 54 x 64, taşma yok |

Her iki varyant (K, N) için sonuçlar aynıdır. Yeni sabit `BuScrollPadding.bottom` = bar alanı + 12: iPhone 98 dp, Android 88 dp
(mevcut `BuSize.navInset` 96 dp sabit; HEAD `kNavInset` 100 dp: iPhone'da gerçek alan 98, Android'de 80 olduğundan
Android'de 16 dp gereksiz boşluk, iPhone'da 2 dp yetersiz kalıyordu).

Test sonucu: `flutter test test/redesign/nav_secenek_shots_test.dart` -> 39 test geçti (görüntü üretimi + ölçüm + semantics + hover/basılı
+ klavye + "animasyonları azalt" + 320 dp x1.3). Doğrulanamayanlar: gerçek cihazda kare süresi, gerçek `BackdropFilter` maliyeti,
haptic hissi, TalkBack/VoiceOver okuma sırası (yalnız Semantics ağacı test edildi).

## 4. Erişilebilirlik

- Her sekme tek Semantics düğümü: etiket ("Sohbet, 3 okunmamış"), `selected`, `inMutuallyExclusiveGroup`, "Tab n of 5",
  `onTap`. Görsel ikon/rozet `ExcludeSemantics`. Etiket görünmese de ekran okuyucuda var.
- Dokunma hedefi >= 54 x 64 dp (320 dp ekran + 1.3x yazı: 54 dp; yazı ölçeği hapı etkilemez).
- Renk: seçili durum yalnız renge bağlı değil (dolu ikon + oval). Açık tema `pr` ikon / `soft` oval kontrastı tasarım
  sisteminin mevcut seçili-çip eşleşmesiyle aynı. Koyu tema `ink` çizgi ikon / cam kontrastı yüksek.
- Etiket yok: ilk kullanımda öğrenilebilirlik riski var (aşağıda artı/eksi). Uzun basışta ipucu (tooltip) önerilir
  (`Tooltip` ile sekme adı; 500 ms), ek maliyet yok.

## 5. Artı / eksi

| | |
|---|---|
| + | Çok sade, tek vurgu; içerik alanı kazancı iPhone 12 dp (98 -> 86), Android 4 dp (80 -> 76) + kNavInset hatası giderilir; blur kalkar (performans); kayan oval + dolu ikon "canlı" his; iOS ve Android'de aynı görünür |
| - | Etiket yok: Keşfet/Kulüpler ikonları ilk kullanımda belirsiz olabilir (pusula ve iki kişi yaygın, ama "Kulüpler" için tooltip + Semantics gerek); Profil avatar fotoğrafına bağlı; gerçek cam bulanıklığı yok (yarı saydam dolgu) |
| Risk | Dolu ikon çizicisi yeni kod (4 ikon); 360 dp'de hap 320 dp = kenar 20 dp tam sınır; kaydırma küçülmesi kısa içerikte yanlış tetiklenmemeli |

## 6. Önerim

**Varyant K (kırmızı tint oval + kırmızı dolu ikon).** Neden: (1) seçili durum hem oval hem renk hem dolu ikonla üç kanaldan okunur,
nötr ovalde (N) açık temada oval gri-beyaz cam üzerinde neredeyse kaybolur (hover/basılı ayna oval de neredeyse görünmez);
(2) uygulamanın seçili çip/filtre dili (`soft` zemin + `pr` yazı: "Tümü" çipi) ile birebir tutarlı; (3) koyu temada `soft`
karanlık kırmızı oval, cam üzerinde sıcak bir vurgu verir ve referanstaki "açık oval" hissine yakındır. N daha sakin ama marka
kimliğini zayıflatır ve hover/basılı durumları ayırt edilemez. İkisinin farkı tek satır (`_NavColors.oval`), kullanıcı isterse N'ye
geçmek ücretsizdir.

Genel öneri: bu tasarımı uygulayın; mevcut barın `BackdropFilter`ını (sigma 16) kaldırmak performansı iyileştirir, içerik alanı
iPhone'da 12 dp artar, `kNavInset` uyuşmazlığı (T-115) tek yardımcıyla kapanır. Tek ödün: etiketlerin kalkması; Semantics etiketleri
ve uzun basış ipucu ile telafi edilir. Cam hissi için istenirse varsayılan KAPALI `kNavBlur` bayrağı eklenebilir.

## 7. Uygulama planı (onaydan sonra; bu görevde YAPILMADI)

| Adım | Dosya | Not |
|---|---|---|
| 1. İkon çizici | yeni `mobile/lib/features/shell/nav_icons.dart` (`LucideFillPainter`, 4 yol) | ortak widget değil, shell'e özel; `path_parsing` ya da elle Path |
| 2. Hap | `features/shell/floating_nav.dart` yeniden yaz (sınıf adı + parametreler aynı kalır: `index, onChanged, chatBadge, avatarUrl, avatarName`) | BackdropFilter kalkar, `compact` yeni isteğe bağlı parametre |
| 3. Boyutlar | `core/theme/bu_sizes.dart`: `nav = 64`, `navGap` kalkar ya da 12, `navInset` kalkar | tek kaynak: bar kendi yüksekliğini ölçtürür |
| 4. Alt pay | yeni `widgets/bu_scroll_padding.dart` (`BuScrollPadding.bottom`); `kNavInset` (bu_widgets.dart:961) önce `@Deprecated` ve yeni yardımcıya yönlendirme, sonra 9 dosyada değişim | T-115 kapanır |
| 5. Kabuk | `features/shell/app_shell.dart`: `NotificationListener` + `navCompact`; `extendBody` zaten açık | Sohbet sekmesinde rozet mantığı değişmez |
| 6. Testler | `test/` altında mevcut `floating_nav` testleri güncellenir (etiket aramaları kalkar, Semantics kalır); bu prototipin ölçüm testleri üretim sınıfına taşınır | güvenli alan 0/34, 320 dp x1.3, klavye, RTL |
| 7. Doküman | `docs/MOBILE_DESIGN_SYSTEM.md` alt gezinme bölümü, `docs/design/UYGULANMAZ.md` ("yüzen hap" kuralı: etiket yok olarak güncelle) | |

Tahmini risk: ORTA-DÜŞÜK (tek widget + 9 dosyada sabit değişimi; API/ağ yok). En riskli yer ikon çizici ve kaydırma
küçülmesi (liste zıplaması: yer ayırma sabit tutularak önlenir). Tahmini iş: 1 ajan, ~yarım gün; `flutter analyze` + ilgili
widget testleri + Keşfet/Ana Sayfa/Sohbet emülatör kontrolü.

## 8. Dosyalar

PNG'ler (`C:u_qa\shots	asarim
av\`):
- Ana ekran üstünde (Keşfet): `nav_{K|N}_{light|dark}_{390|360}.png` (390: güvenli alan 34, 360: güvenli alan 0)
- Ana Sayfa üstünde: `nav_{K|N}_{light|dark}_390_home.png` (Ana Sayfa seçili, Sohbet rozeti 12)
- Kaydırınca küçülmüş hal: `nav_{K|N}_{light|dark}_390_kucuk.png`
- Durum tablosu (normal/hover/basılı/seçili/seçili+basılı/rozet sayı-nokta-99+/avatar): `nav_durumlar_{K|N}_{light|dark}.png`
- Oval kayma kareleri (0-250 ms, Ana Sayfa -> Kulüpler): `nav_kayma_{K|N}_{light|dark}.png`
- Önce (mevcut FloatingNav): `nav_mevcut_{light|dark}_390.png`

Üretim: `NAV_OUT='C:/bu_qa/shots/tasarim/nav' flutter test test/redesign/nav_secenek_shots_test.dart` (ASCII kopyada, `flutter-lock` altında).
