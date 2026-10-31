# İkon seti önerisi: Lucide → Hugeicons (ÖNİZLEME aşaması)

Durum: **öneri / görsel önizleme; kod değişikliği YOK.** Kullanıcı tahtayı onaylarsa geçiş ayrı görev olarak yapılır.
Tarih: 2026-11-01 · Kapsam: `mobile/` (paket `bu_kampus`, bugün `lucide_icons_flutter ^4.0.1` + az sayıda Material `Icons.*`).
Görsel tahtalar (PNG, repoda yok): `C:\bu_design\icons\board_*.png`, özet `C:\bu_design\icons\ozet.md`.

## 1. Özet

- Hugeicons Flutter paketi (`hugeicons` **4.4.0**, 2026-10-30) **MIT** lisanslıdır; ticari/mobil kullanım serbesttir. Ücretsiz küme **yalnız stroke-rounded** (6.065 ikon); solid/duotone/bulk/twotone stilleri Pro ve pakette **yoktur**.
- 167 Lucide + 25 Material ikonunun **190'ının** ücretsiz kümede karşılığı var: **131 birebir, 59 yakın, 2 zayıf/karşılıksız** (`delete` = geri-sil/backspace, `keyboard`).
- **Büyük fark:** Hugeicons bir *yazı tipi/IconData* değil; çalışma anında **SVG dizgisi üretip `flutter_svg` ile çizen bir widget**'tır (`HugeIcon`). `Icon(IconData)` yerine geçmez, `IconData` tipli 73 dosyadaki API (`BuIconButton(icon: IconData)` vb.) değişir.
- Bugünkü alt çubuğun **dolu/ince** ikon çifti (Material `*_rounded` ↔ `*_outlined`) ve beğeni/kaydet/yıldız **dolu** hâlleri ücretsiz kümede karşılıksızdır; etkin durum için 3 öneri tahtada (`board_10`).
- Öneri: **şartlı evet** (bkz. bölüm 8): görünümü beğenirseniz geçiş yapılabilir, merkezî `BuIcons` sözlüğü ile geri döndürülebilir; ama bu mekanik ama geniş bir değişikliktir (137 + 73 dosya, 48 test dosyası).

## 2. Envanter (kaynak: `mobile/lib`, betik `work/inventory.py`)

| Kalem | Değer |
|---|---|
| `LucideIcons.*` | 167 benzersiz ad, 887 kullanım, 137 dosya |
| Material `Icons.*` | 25 benzersiz ad, 34 kullanım (alt çubuk 8, beğeni/yıldız/kaydet/oynat/durum) |
| `CupertinoIcons` | yok · özel SVG ikon: yok (`flutter_svg` yalnız marka `mark.svg` için) |
| `IconData` tipli API | 73 dosya, 188 geçiş (`BuIconButton.icon`, `BuButton.icon`, `ClubMenuEntry`, `MessageAction`, `NcStateCard`, ...) |
| RTL yön ikonları | `buDirIcon` (`bu_widgets.dart`): `arrowLeft/Right`, `chevronLeft/Right` elle değiştirilir; `Transform.flip` ile `send` aynalanır |
| Testlerde ikon | 48 test dosyası, 193 geçiş, **121 `find.byIcon`** |
| Anlamsal etiket | Çoğu ikon `ExcludeSemantics` içinde veya düğmenin `tooltip`'inde; ikon kendi etiketini taşımaz |

Bileşen varsayılan ikon boyutları (dp): `BuIconButton` 20 (düğme 40 × .5), `BuButton` 14/16, arama alanı 18, liste öncül 19 / ok 18, durum kartı 28/34, çubuk simgesi (alt bar) 22 (28 dp yuva). En sık kullanılan 10 ikon: `x` 49, `chevronRight` 40, `trash2` 33, `check` 33, `circleAlert` 30, `arrowLeft` 24, `image` 23, `clock` 23, `info` 23, `users`/`lock` 20.

**Alt bar** (`floating_nav.dart`): 4 sekme Material ikonu, 5. sekme avatar. Pasif: `home_outlined`, `explore_outlined`, `chat_bubble_outline_rounded`, `people_outline_rounded` (rengi `t.mut`); etkin: `*_rounded` DOLU hâl (rengi `t.pr`, ölçek 1.06). Hugeicons'ta dolu hâl olmadığı için etkin durum yeniden tasarlanmalıdır.

## 3. Paket incelemesi (doğrulananlar)

| Konu | Bulgu | Kaynak |
|---|---|---|
| Sürüm | `hugeicons 4.4.0`, 2026-10-30; sürüm numarası artık ikon kitaplığının sürümünü izliyor (1.2.0 → 4.4.0; API kaldırılmadı). Bağımlılık: `flutter_svg ^2.0.9` (uygulamada zaten `^2.3.0` var) | pub.dev API, `CHANGELOG.md` |
| Lisans | **MIT**. Pakette `LICENSE`: "Copyright (c) 2024 Halal Labs"; repoda `LICENSE.md`: "Copyright (c) 2025 Hugeicons". README: "personal and commercial projects", "attribution appreciated" (MIT yalnız telif/izin notunun kopyalarda korunmasını şart koşar; ayrı atıf zorunluluğu yok) | paket `LICENSE`/`README.md`, `github.com/hugeicons/hugeicons` `README.md` "Free & Pro" |
| Ücretsiz küme | **yalnız Stroke Rounded**; 6.065 ikon (`6055` güncel sabit + `38` kullanımdan kalkan ad = 6093 sabit). `lib/styles/` altında yalnız `stroke_rounded.dart` var | `CHANGELOG 4.4.0`, `lib/` ağacı |
| Pro | 60.000+ ikon, 10 stil (Solid, Bulk, Duotone, Twotone × yuvarlak/keskin/standart), ayrı "Pro License" (`hugeicons.com/license-agreement`); "unlimited end products" ama indirilebilir şablon/açık kaynakta yeniden dağıtım yok. Flutter için Pro paket adı/yolu bu incelemede **doğrulanamadı** | repo `README.md` |
| Çizim biçimi | İkonlar Dart `const List<List<dynamic>>` (SVG öğe sözlükleri; `stroke: currentColor`, `strokeWidth: 1.5`). Yazı tipi **değil** | `lib/styles/stroke_rounded.dart` |
| Çizim yolu | `HugeIcon` (StatefulWidget) her renk/kalınlık değişiminde SVG **dizgisi üretir**, `SvgPicture.string` ile çizer; son dizgiyi widget içinde önbelleğe alır. Rengi `color` → `IconTheme.color` → yazı rengi sırasıyla çözer | paket `lib/hugeicons.dart` |
| Çizgi kalınlığı | `strokeWidth` parametresi **var** (`HugeIcon(strokeWidth:)`); varsayılan 1.5 (Lucide 2.0 çizer). Önizlemede tek kalınlık **1.75** kullanıldı | kaynak + `board_11` |
| `IconTheme` | Rengi ve saydamlığı (devre dışı düğme) **okur**; ama `size` varsayılanı 24.0 olduğundan **`IconTheme.size` yok sayılır** (her çağrıda `size:` verilmeli) | kaynak (`size = 24.0`) |
| Erişilebilirlik | `HugeIcon`'da `semanticLabel`/`Semantics` **yok**; etiket çağıran sarmalayıcıda verilmeli (uygulama zaten çoğunlukla `ExcludeSemantics` + düğme `tooltip`) | kaynak |
| RTL aynalama | Otomatik **yok** (`matchTextDirection` benzeri parametre yok); `buDirIcon` ile Chevron/Arrow çiftleri elle değiştirilir (Hugeicons'ta `ChevronLeft/Right`, `ArrowLeft02/Right02` var; sabitler `==` ile ayırt edilir) | kaynak |
| İkon türü | `Icon(IconData)` kabul etmez; `IconData` yerine `List<List<dynamic>>` taşınır. Bu yüzden `BuIconData` sarmalayıcı tipi gerekir | kaynak |

### 3.1 Çizim maliyeti (flutter test, ölçüldü; **cihaz ölçümü değil**)

Yöntem: `C:\bu_design\icons\work\probe\test\bench_test.dart`; `flutter test` (debug/JIT, başsız, yazılım rasterleştirme), Flutter 3.47.8, Windows; ısınmış sayılar. Mutlak değerler anlamsızdır, **oranlar yol göstericidir**. Makine meşgul olduğundan ±%20 gürültü olabilir.

| Ölçüt | Lucide `Icon` | `HugeIcon` |
|---|---|---|
| İkon başına alt-ağaç widget sayısı | 5 | 8 |
| 500 satırlık sütunda toplam Element | 6.176 | 7.676 (+%24) |
| 500 ikon ilk kurulum (ms, 2. tur) | 246 | 336 |
| Kaydırma, 60 kare `ListView.builder` (kare başına ms, kurulum+yerleşim) | 10,6 – 12,8 | 19,1 – 19,7 (~1,5-1,8×) |
| 500 ikonlu sütunun `toImage` süresi (ms, CPU) | 41 – 44 | 56 – 57 (~1,3×) |
| İlk karede çizim | var | **var** (ilk karede, yüklenince ve yeniden kurulunca aynı boyalı piksel sayısı: boş ilk kare gözlenmedi; yalnız test ortamı) |

Yorum: HugeIcon ikon başına daha çok widget/dizgi işi yapar; gerçek cihazda 60/120 fps altında fark görülür mü **doğrulanamadı** (profil modu cihaz ölçümü gerekir). Sık kaydırılan uzun listelerde (sohbet, haber) satır başına 1-3 ikon vardır; risk düşük ama ölçülmelidir. Sürümde `vector_graphics_compiler` (165 KB kod) çalışma anında SVG'yi ayrıştırır; uygulama `flutter_svg`'yi zaten kullanıyor (mark.svg), yani bu bağımlılık yeni değil.

### 3.2 Paket boyutu (release APK, arm64, `--analyze-size`; ölçüldü)

Deney: `probe/lib/size_{a,b,c,d}.dart` (4 ayrı küçük uygulama). Değerler `app-release.apk` bayt:

| Uygulama | APK | Not |
|---|---|---|
| D: ikon paketi yok (`Icons.add`) | 16,89 MB | taban (ilk derleme; **D > A tutarsızlığı açıklanamadı**, ±0,4 MB gürültü payı) |
| A: Lucide, 167 ikon | 16,49 MB | `lucide.ttf` 930 KB → **65 KB** (167 glif, simge ağacı budaması çalışıyor) |
| C: Hugeicons, **1** ikon | 17,34 MB | `flutter_svg` + `vector_graphics_compiler` + `xml` + `petitparser` kodu dahil |
| B: Hugeicons, **166** ikon | 17,48 MB | C'ye göre +131 KB ⇒ ~0,8 KB/ikon |

Sonuçlar: (1) **Ağaç budaması çalışıyor**: 6.000+ ikonun tamamı pakete girmez; yalnız başvurulanlar girer (166 ikon ⇒ +131 KB). (2) Uygulama `flutter_svg`'yi zaten taşıdığı için gerçek fark ≈ `B − C` ≈ **+0,1 MB** eksi Lucide yazı tipinin ~65 KB'ı ⇒ net **~+0,07 MB**. Tablodaki B − A = +0,98 MB farkı, yalnızca SVG kitaplığının *yeni* girdiği prob uygulama içindir. (3) Geliştirme maliyeti: `hugeicons.dart` 0,7 MB + `stroke_rounded.dart` **9,8 MB** Dart kaynağı; IDE/analiz sunucusu yükü ve ilk `flutter analyze` süresi **ölçülmedi/doğrulanamadı** (kıyas için sağlıklı taban yok).

## 4. Görsel tahta (nasıl bakılır)

Hepsi `C:\bu_design\icons\` altında (ASCII ad, PNG; repoda yok):

| Dosya | İçerik |
|---|---|
| `board_10_alt_bar_etkin_pasif.png` (+ `_koyu`) | **Önce buna bakın:** alt çubuk bugünkü Material dolu/ince ↔ Hugeicons 3 etkin-durum önerisi, 6 ikon yan yana |
| `board_09_mini_onizleme.png` (+ `_koyu`) | Üst çubuk, ayarlar satırları, sohbet giriş çubuğu, takip/istek satırı, boş ekran/durum: Lucide ve Hugeicons yan yana (üst/alt) |
| `board_01…08_*.png` | 192 çiftin alanlara göre ÖNCE → SONRA tablosu (alt bar/gezinti, üst çubuk, sohbet, kulüp/etkinlik, profil, giriş/güvenlik, durum/boş ekran) |
| `board_11_boyut_kalinlik.png` (+ `_koyu`) | 12/16/20/24 dp ızgarası, çizgi kalınlığı 1.5/1.75/2.0, 48 dp büyütme |
| `board_12/13_genis_karsilastirma_*.png` (+ `_koyu`) | 1280 px geniş, tüm 192 çift tek bakışta |
| `work\cand_*.png` | Kararsız ikonlar için aday sayfaları (arrow/compass/lock/eyeOff vb. seçimi) |

Bulgular (tahtalardan): Hugeicons daha ince/yuvarlak ve glif kutuyu Lucide'den ~%8 az doldurur (aynı dp'de biraz küçük görünür; 12 dp'de belirgin incelir). 16-24 dp okunaklı. `strokeWidth` 1.75 Lucide 2.0'a en yakın görsel ağırlık; 1.5 daha zarif ama küçük boyutta silik. Hugeicons'ta ok ikonları `ArrowLeft01` bir *chevron*'dur; Lucide `arrowLeft` karşılığı **`ArrowLeft02`** seçildi. Hugeicons `Compass` bir kronometre gibi okunur; keşfet sekmesi için **`DiscoverCircle`** seçildi.

## 5. Etkin durum (alt bar, beğeni, kaydet, yıldız)

Bugün dolu/ince çift: ücretsiz kümede **dolu stil yok**. Üç seçenek (`board_10`):

1. **Renk + kalınlık 2.0** (`t.pr`, `t.mut`): en sade, ek bileşen gerekmez; dolu hâlden daha az "basılı" hissi verir.
2. **Renk + yumuşak hap zemin (`t.soft`)**: yeni renk yok, kalıcı etkin göstergesi; alt çubuk için önerilen.
3. **Dolgu simülasyonu** (kapalı şekillere `fill`): ev/sohbet/kalp/yıldız/kaydet'te iyi; `DiscoverCircle` (pusula) dolunca iğne kaybolur ve düz daire olur ⇒ pusulada kullanılmaz. Ayrı bir `BuIcon(filled: true)` çizim yolu gerekir (kendi SVG üreticisi).

Öneri: alt çubuk 2 (hap + renk), beğeni/kaydet/yıldız 3 (dolgu), diğer her yer 1.

## 6. Eşleme (tam liste)

Güven: **birebir** = aynı kavram ve aynı çizim dili; **yakın** = aynı kavram, ayrıntı farklı; **zayıf** = karşılık yok/okunmuyor. "Alternatif" sütunu paketteki ikinci aday sabit adıdır. Tüm adlar paketin `lib/hugeicons.dart` listesinde doğrulandı (betik `work/mapping.py`). "Boyut" = ikondan sonra aynı/sonraki 2 satırda `size:` ile bulunan en sık değerler (yaklaşık; bileşen varsayılanı olanlarda "bileşen").

### 6.1 Lucide → Hugeicons (167)

| # | Kaynak | Kullanım | Alanlar | Boyut (dp) | Hugeicons sabiti (`HugeIcons.`) | Güven | Alternatif | Not |
|---|---|---|---|---|---|---|---|---|
| 1 | `LucideIcons.x` | 49 | sohbet, etkinlik, profil | 16, 18, 20 | `strokeRoundedCancel01` | birebir | `X` |  |
| 2 | `LucideIcons.chevronRight` | 40 | profil, etkinlik, sohbet | 16, 18, 20 | `strokeRoundedChevronRight` | birebir | `ArrowRight01` |  |
| 3 | `LucideIcons.check` | 33 | sohbet, etkinlik, giriş | 15, 16, 18 | `strokeRoundedTick02` | birebir | `Check` |  |
| 4 | `LucideIcons.trash2` | 33 | sohbet, kulüp, akademik | 16, 18, 24 | `strokeRoundedDelete02` | birebir | `Trash` |  |
| 5 | `LucideIcons.circleAlert` | 30 | sohbet, akademik, etkinlik | 14, 18, 20 | `strokeRoundedAlertCircle` | birebir | `Alert02` |  |
| 6 | `LucideIcons.arrowLeft` | 24 | sohbet, kulüp, haber | 24 | `strokeRoundedArrowLeft02` | birebir | `ArrowLeft01` |  |
| 7 | `LucideIcons.clock` | 23 | akademik, profil, takip | 14, 15, 20 | `strokeRoundedClock01` | birebir | `Clock02` |  |
| 8 | `LucideIcons.image` | 23 | sohbet, çekirdek, kulüp | 20, 22, 24 | `strokeRoundedImage02` | birebir | `Image01` |  |
| 9 | `LucideIcons.info` | 23 | sohbet, giriş, etkinlik | 14, 16, 18 | `strokeRoundedInformationCircle` | birebir | `Info` |  |
| 10 | `LucideIcons.lock` | 20 | sohbet, kulüp, etkinlik | 14, 16, 18 | `strokeRoundedLockKeyhole` | yakın | `LockPassword` | kilit gövdesi anahtar deliği ile |
| 11 | `LucideIcons.users` | 20 | sohbet, etkinlik, profil | 13, 14, 24 | `strokeRoundedUserGroup` | yakın | `Users` | iki halkalı grup çizimi; kişi sayısı/oran farklı |
| 12 | `LucideIcons.search` | 19 | sohbet, kulüp, ana sayfa | 18, 20, 22 | `strokeRoundedSearch01` | birebir | `Search02` |  |
| 13 | `LucideIcons.refreshCw` | 18 | sohbet, profil, giriş | 13, 16, 18 | `strokeRoundedRefreshCw` | birebir | `Refresh` |  |
| 14 | `LucideIcons.camera` | 17 | sohbet, çekirdek, medya | 18, 20, 28 | `strokeRoundedCamera01` | birebir | `Camera02` |  |
| 15 | `LucideIcons.logOut` | 16 | sohbet, profil, kulüp | 18 | `strokeRoundedLogout01` | birebir | `LogOut` |  |
| 16 | `LucideIcons.triangleAlert` | 16 | etkinlik, akademik, profil | 22, 28, 44 | `strokeRoundedAlert01` | birebir | `TriangleAlert` |  |
| 17 | `LucideIcons.ban` | 14 | sohbet, kulüp, profil | 15, 16, 22 | `strokeRoundedBan` | birebir | `Blocked` |  |
| 18 | `LucideIcons.calendar` | 14 | akademik, sohbet, kulüp | 14, 22, 24 | `strokeRoundedCalendar04` | birebir | `Calendar05` |  |
| 19 | `LucideIcons.userPlus` | 14 | takip, sohbet, profil | bileşen | `strokeRoundedUserAdd01` | yakın | `UserPlus` | gövde daha açık; ek simge sağ altta |
| 20 | `LucideIcons.chevronDown` | 13 | akademik, sohbet, destek | 16, 18, 20 | `strokeRoundedChevronDown` | birebir | `ArrowDown01` |  |
| 21 | `LucideIcons.calendarDays` | 11 | sohbet, etkinlik, çekirdek | 20, 40, 44 | `strokeRoundedCalendarDays` | birebir | `Calendar02` |  |
| 22 | `LucideIcons.circleCheck` | 11 | destek, akademik, bildirim | 16, 24, 26 | `strokeRoundedCheckmarkCircle02` | birebir | `CircleCheck` |  |
| 23 | `LucideIcons.pencil` | 10 | sohbet, etkinlik, profil | 14, 18, 20 | `strokeRoundedPen01` | birebir | `PencilEdit01` |  |
| 24 | `LucideIcons.plus` | 10 | sohbet, etkinlik, profil | 16, 18, 24 | `strokeRoundedAdd01` | birebir | `Plus` |  |
| 25 | `LucideIcons.wifiOff` | 9 | takip, sohbet, ortak | 18, 20 | `strokeRoundedWifiOff01` | birebir | `WifiDisconnected01` |  |
| 26 | `LucideIcons.bell` | 8 | sohbet, çekirdek, ana sayfa | bileşen | `strokeRoundedNotification01` | birebir | `Bell` |  |
| 27 | `LucideIcons.calendarX` | 8 | etkinlik, profil | bileşen | `strokeRoundedCalendarX` | birebir | `CalendarRemove01` |  |
| 28 | `LucideIcons.ellipsis` | 8 | kulüp, profil, sohbet | 22, 24, 40 | `strokeRoundedMoreHorizontal` | birebir | `Ellipsis` |  |
| 29 | `LucideIcons.images` | 8 | sohbet, medya, etkinlik | 32, 44 | `strokeRoundedImages` | birebir | `Image02` |  |
| 30 | `LucideIcons.arrowUp` | 7 | sohbet, destek | 20, 22, 24 | `strokeRoundedArrowUp02` | birebir | `ArrowUp01` |  |
| 31 | `LucideIcons.bellOff` | 7 | sohbet, ortak | 13, 20 | `strokeRoundedNotificationOff01` | birebir | `BellOff` |  |
| 32 | `LucideIcons.ellipsisVertical` | 7 | etkinlik, kulüp, sohbet | 20, 22 | `strokeRoundedMoreVertical` | birebir | `EllipsisVertical` |  |
| 33 | `LucideIcons.flag` | 7 | sohbet, kulüp, etkinlik | 18 | `strokeRoundedFlag02` | birebir | `Flag01` |  |
| 34 | `LucideIcons.graduationCap` | 7 | sohbet, çekirdek, akademik | 16 | `strokeRoundedGraduationCap` | birebir | `Mortarboard01` |  |
| 35 | `LucideIcons.imageOff` | 7 | sohbet, medya, profil | 36, 43 | `strokeRoundedImageOff` | birebir | `ImageDelete01` |  |
| 36 | `LucideIcons.settings` | 7 | sohbet, etkinlik, çekirdek | 18 | `strokeRoundedSettings01` | birebir | `Settings02` |  |
| 37 | `LucideIcons.user` | 7 | çekirdek, giriş, kulüp | 28 | `strokeRoundedUser` | birebir | `UserCircle` |  |
| 38 | `LucideIcons.userMinus` | 7 | sohbet, kulüp, takip | 18 | `strokeRoundedUserMinus01` | yakın | `UserMinus02` | gövde daha açık; ek simge sağ altta |
| 39 | `LucideIcons.cloudOff` | 6 | ana sayfa, akademik, giriş | 16, 32 | `strokeRoundedCloudOff` | birebir | `NoInternet` |  |
| 40 | `LucideIcons.eyeOff` | 6 | profil, giriş, sohbet | 20, 22 | `strokeRoundedEyeOff` | birebir | `ViewOff` |  |
| 41 | `LucideIcons.megaphone` | 6 | çekirdek, ana sayfa, haber | bileşen | `strokeRoundedMegaphone02` | birebir | `Megaphone01` |  |
| 42 | `LucideIcons.messageCircle` | 6 | çekirdek, sohbet, ana sayfa | 9 | `strokeRoundedMessageCircle` | birebir | `BubbleChat` |  |
| 43 | `LucideIcons.shield` | 6 | kulüp, profil, sohbet | 11, 20 | `strokeRoundedShield01` | birebir | `Shield02` |  |
| 44 | `LucideIcons.arrowRight` | 5 | sohbet, ortak, durum | 14 | `strokeRoundedArrowRight02` | birebir | `ArrowRight01` |  |
| 45 | `LucideIcons.bookmark` | 5 | haber, ana sayfa, ortak | 20 | `strokeRoundedBookmark01` | birebir | `Bookmark02` |  |
| 46 | `LucideIcons.chevronLeft` | 5 | ortak, akademik, etkinlik | 26 | `strokeRoundedChevronLeft` | birebir | `ArrowLeft01` |  |
| 47 | `LucideIcons.circleX` | 5 | sohbet, kulüp, etkinlik | 14, 18, 20 | `strokeRoundedCancelCircle` | birebir | `CircleX` |  |
| 48 | `LucideIcons.download` | 5 | sohbet, durum | 18 | `strokeRoundedDownload01` | birebir | `Download02` |  |
| 49 | `LucideIcons.heart` | 5 | kulüp, çekirdek, arama | 16, 20 | `strokeRoundedFavourite` | birebir | `Heart` |  |
| 50 | `LucideIcons.lockOpen` | 5 | etkinlik, profil, takip | 18 | `strokeRoundedLockOpen` | birebir | `LockKeyholeOpen` |  |
| 51 | `LucideIcons.star` | 5 | akademik, sohbet, kulüp | 11 | `strokeRoundedStar` | birebir | - |  |
| 52 | `LucideIcons.userCheck` | 5 | etkinlik, sohbet, takip | 40 | `strokeRoundedUserCheck01` | yakın | `UserCheck02` | gövde daha açık; ek simge sağ altta |
| 53 | `LucideIcons.video` | 5 | sohbet, QR | 12, 14, 36 | `strokeRoundedVideo01` | yakın | `Video02` | kamera gövdesi yuvarlak, mercek çıkıntısı |
| 54 | `LucideIcons.archive` | 4 | sohbet | 22 | `strokeRoundedArchive` | birebir | `Archive02` |  |
| 55 | `LucideIcons.bookOpen` | 4 | akademik, sohbet, kulüp | bileşen | `strokeRoundedBookOpen01` | birebir | `BookOpen02` |  |
| 56 | `LucideIcons.calendarCheck` | 4 | akademik, etkinlik, destek | bileşen | `strokeRoundedCalendarCheck01` | yakın | `CalendarCheck` | takvim üst bilekleri farklı |
| 57 | `LucideIcons.checkCheck` | 4 | sohbet, akademik | bileşen | `strokeRoundedTickDouble01` | yakın | `CheckCheck` | çift tik biraz eğik |
| 58 | `LucideIcons.circleHelp` | 4 | kulüp, etkinlik, ortak | 14, 28 | `strokeRoundedHelpCircle` | birebir | - |  |
| 59 | `LucideIcons.eye` | 4 | profil, giriş, sohbet | 16, 20, 22 | `strokeRoundedView` | birebir | `Eye` |  |
| 60 | `LucideIcons.hourglass` | 4 | giriş, etkinlik, keşfet | 22 | `strokeRoundedHourglass` | birebir | - |  |
| 61 | `LucideIcons.imagePlus` | 4 | kulüp, sohbet | 20 | `strokeRoundedImageAdd01` | yakın | `ImagePlus` | artı sağ üstte; çerçeve yuvarlak |
| 62 | `LucideIcons.play` | 4 | sohbet | 10, 26 | `strokeRoundedPlay` | birebir | - |  |
| 63 | `LucideIcons.rotateCw` | 4 | akademik, sohbet, medya | 20 | `strokeRoundedRedo` | yakın | `Refresh` | Undo/Redo: çember ok (yön doğrulandı) |
| 64 | `LucideIcons.send` | 4 | sohbet, kulüp, destek | 20 | `strokeRoundedSent` | birebir | `Send` |  |
| 65 | `LucideIcons.shieldAlert` | 4 | sohbet, kulüp, durum | 15, 40 | `strokeRoundedShieldAlert` | birebir | - |  |
| 66 | `LucideIcons.userSearch` | 4 | sohbet, takip | bileşen | `strokeRoundedUserSearch01` | yakın | `UserRoundSearch` | gövde daha açık; ek simge sağ altta |
| 67 | `LucideIcons.wrench` | 4 | çekirdek, akademik, destek | bileşen | `strokeRoundedWrench01` | yakın | `Wrench02` | tutuş ağzı farklı |
| 68 | `LucideIcons.calendarPlus` | 3 | kulüp, etkinlik, profil | bileşen | `strokeRoundedCalendarAdd01` | yakın | `CalendarPlus` | takvim üst bilekleri farklı |
| 69 | `LucideIcons.cameraOff` | 3 | QR, çekirdek | 30, 40 | `strokeRoundedCameraOff01` | birebir | `CameraOff02` |  |
| 70 | `LucideIcons.history` | 3 | akademik, sohbet, kulüp | 16 | `strokeRoundedHistory` | birebir | - |  |
| 71 | `LucideIcons.idCard` | 3 | akademik, sohbet, ortak | bileşen | `strokeRoundedIdCard` | birebir | `IdentityCard` |  |
| 72 | `LucideIcons.inbox` | 3 | sohbet, ana sayfa | bileşen | `strokeRoundedInbox` | yakın | - | aynı kavram, iç detay farklı |
| 73 | `LucideIcons.mapPin` | 3 | akademik, kulüp, profil | 14 | `strokeRoundedLocation01` | birebir | `MapPin` |  |
| 74 | `LucideIcons.messageSquare` | 3 | etkinlik, profil, ortak | bileşen | `strokeRoundedMessageSquare` | yakın | `Message01` | köşeleri daha yuvarlak balon |
| 75 | `LucideIcons.newspaper` | 3 | ana sayfa, haber, arama | bileşen | `strokeRoundedNewspaper` | yakın | - | aynı kavram, iç detay farklı |
| 76 | `LucideIcons.reply` | 3 | sohbet | 14, 15 | `strokeRoundedReply` | birebir | `MailReply01` |  |
| 77 | `LucideIcons.undo2` | 3 | profil, etkinlik | 16 | `strokeRoundedUndo03` | birebir | `Undo02` |  |
| 78 | `LucideIcons.archiveRestore` | 2 | sohbet | 22 | `strokeRoundedArchiveRestore` | birebir | `ArchiveArrowUp` |  |
| 79 | `LucideIcons.arrowLeftRight` | 2 | akademik, profil | bileşen | `strokeRoundedArrowLeftRight` | birebir | - |  |
| 80 | `LucideIcons.arrowUpRight` | 2 | sohbet | 14, 18 | `strokeRoundedArrowUpRight01` | birebir | `ArrowUpRight02` |  |
| 81 | `LucideIcons.building2` | 2 | ortak | 12.5, 20 | `strokeRoundedBuilding02` | yakın | `Building03` | aynı kavram, iç detay farklı |
| 82 | `LucideIcons.chevronUp` | 2 | sohbet, ana sayfa | bileşen | `strokeRoundedChevronUp` | birebir | - |  |
| 83 | `LucideIcons.circlePlus` | 2 | akademik | 20 | `strokeRoundedAddCircle` | birebir | `CirclePlus` |  |
| 84 | `LucideIcons.compass` | 2 | profil | bileşen | `strokeRoundedDiscoverCircle` | birebir | `Compass` |  |
| 85 | `LucideIcons.contact` | 2 | çekirdek, sohbet | bileşen | `strokeRoundedContact01` | yakın | `Contact` | aynı kavram, iç detay farklı |
| 86 | `LucideIcons.crop` | 2 | medya, keşfet | bileşen | `strokeRoundedCrop` | birebir | - |  |
| 87 | `LucideIcons.fileText` | 2 | destek, ortak | bileşen | `strokeRoundedFileText` | birebir | `File01` |  |
| 88 | `LucideIcons.globe` | 2 | kulüp, etkinlik | bileşen | `strokeRoundedGlobe02` | birebir | `Global` |  |
| 89 | `LucideIcons.gripVertical` | 2 | ana sayfa | 16, 20 | `strokeRoundedGripVertical` | birebir | `Drag01` |  |
| 90 | `LucideIcons.headset` | 2 | ana sayfa, destek | 14 | `strokeRoundedHeadset` | birebir | `CustomerSupport` |  |
| 91 | `LucideIcons.landmark` | 2 | anket, profil | bileşen | `strokeRoundedLandmark` | birebir | `Bank` |  |
| 92 | `LucideIcons.mic` | 2 | çekirdek | bileşen | `strokeRoundedMic01` | birebir | `Mic02` |  |
| 93 | `LucideIcons.minus` | 2 | etkinlik, medya | 18 | `strokeRoundedMinus` | birebir | `MinusSign` |  |
| 94 | `LucideIcons.music` | 2 | sohbet, kulüp | bileşen | `strokeRoundedMusic02` | birebir | `MusicNote01` |  |
| 95 | `LucideIcons.palette` | 2 | sohbet, kulüp | bileşen | `strokeRoundedPalette` | birebir | - |  |
| 96 | `LucideIcons.pin` | 2 | kulüp | 12 | `strokeRoundedPin` | yakın | `Pin02` | iğne açısı farklı |
| 97 | `LucideIcons.share2` | 2 | sohbet, haber | bileşen | `strokeRoundedShare08` | birebir | `Share02` |  |
| 98 | `LucideIcons.shieldCheck` | 2 | kulüp, etkinlik | bileşen | `strokeRoundedShieldCheck` | birebir | - |  |
| 99 | `LucideIcons.squarePen` | 2 | keşfet, profil | bileşen | `strokeRoundedSquarePen` | birebir | `Edit02` |  |
| 100 | `LucideIcons.textAlignStart` | 2 | akademik, profil | 18 | `strokeRoundedTextAlignStart` | birebir | `TextAlignLeft` |  |
| 101 | `LucideIcons.trophy` | 2 | sohbet, kulüp | bileşen | `strokeRoundedTrophy` | birebir | `Award01` |  |
| 102 | `LucideIcons.userX` | 2 | kulüp, profil | 36 | `strokeRoundedUserX` | yakın | `UserRemove01` | gövde daha açık; ek simge sağ altta |
| 103 | `LucideIcons.utensils` | 2 | ana sayfa, anket | bileşen | `strokeRoundedUtensils` | yakın | `KitchenUtensils` | ayrıntı farklı |
| 104 | `LucideIcons.alarmClock` | 1 | etkinlik | bileşen | `strokeRoundedAlarmClock` | birebir | - |  |
| 105 | `LucideIcons.atSign` | 1 | profil | bileşen | `strokeRoundedAtSign` | birebir | `MailAtSign01` |  |
| 106 | `LucideIcons.atom` | 1 | sohbet | bileşen | `strokeRoundedAtom02` | birebir | `Atom01` |  |
| 107 | `LucideIcons.backpack` | 1 | sohbet | bileşen | `strokeRoundedBackpack01` | yakın | - | kavram aynı, çizim ayrıntısı farklı |
| 108 | `LucideIcons.bellRing` | 1 | sohbet | bileşen | `strokeRoundedBellRing` | birebir | - |  |
| 109 | `LucideIcons.calendarClock` | 1 | ana sayfa | bileşen | `strokeRoundedCalendarClock` | yakın | - | takvim üst bilekleri farklı |
| 110 | `LucideIcons.chartPie` | 1 | etkinlik | bileşen | `strokeRoundedPieChart` | birebir | `PieChart01` |  |
| 111 | `LucideIcons.circleDot` | 1 | anket | bileşen | `strokeRoundedCircleDot` | birebir | - |  |
| 112 | `LucideIcons.circlePause` | 1 | kulüp | bileşen | `strokeRoundedPauseCircle` | birebir | - |  |
| 113 | `LucideIcons.circlePlay` | 1 | sohbet | bileşen | `strokeRoundedPlayCircle` | birebir | `PlayCircle02` |  |
| 114 | `LucideIcons.clapperboard` | 1 | sohbet | 26 | `strokeRoundedClapperboard` | yakın | - | kavram aynı, çizim ayrıntısı farklı |
| 115 | `LucideIcons.clipboardCheck` | 1 | etkinlik | bileşen | `strokeRoundedClipboardCheck` | birebir | - |  |
| 116 | `LucideIcons.clipboardList` | 1 | çekirdek | bileşen | `strokeRoundedClipboardList` | birebir | - |  |
| 117 | `LucideIcons.coffee` | 1 | sohbet | bileşen | `strokeRoundedCoffee02` | birebir | `Coffee01` |  |
| 118 | `LucideIcons.copy` | 1 | sohbet | bileşen | `strokeRoundedCopy01` | birebir | `Copy` |  |
| 119 | `LucideIcons.cpu` | 1 | kulüp | bileşen | `strokeRoundedCpu` | yakın | `Chip` | kavram aynı, çizim ayrıntısı farklı |
| 120 | `LucideIcons.delete` | 1 | takip | bileşen | `strokeRoundedDelete01` | zayıf | - | geri-sil (backspace) ikonu YOK; Lucide'de bırak ya da özel SVG |
| 121 | `LucideIcons.doorOpen` | 1 | akademik | bileşen | `strokeRoundedDoorOpen` | yakın | - | ayrıntı farklı |
| 122 | `LucideIcons.fileSearch` | 1 | sohbet | bileşen | `strokeRoundedFileSearch` | birebir | - |  |
| 123 | `LucideIcons.flashlight` | 1 | QR | 16 | `strokeRoundedFlashlight` | birebir | - |  |
| 124 | `LucideIcons.flashlightOff` | 1 | QR | 16 | `strokeRoundedFlashlightOff` | birebir | - |  |
| 125 | `LucideIcons.focus` | 1 | medya | bileşen | `strokeRoundedFocus` | yakın | `FocusPoint` | tek ok halkası / köşe işareti farklı |
| 126 | `LucideIcons.forward` | 1 | sohbet | bileşen | `strokeRoundedRedo01` | yakın | `ArrowTurnForward` | Redo01: kıvrımlı ok; Lucide'deki düz kıvrım |
| 127 | `LucideIcons.hand` | 1 | medya | 14 | `strokeRoundedHand` | yakın | - | kavram aynı, çizim ayrıntısı farklı |
| 128 | `LucideIcons.hash` | 1 | akademik | bileşen | `strokeRoundedHash` | birebir | `Hashtag` |  |
| 129 | `LucideIcons.imageDown` | 1 | profil | bileşen | `strokeRoundedImageDown` | birebir | `ImageDownload` |  |
| 130 | `LucideIcons.keyboard` | 1 | QR | 20 | `strokeRoundedKeyboard` | zayıf | - | Keyboard çizimi klavye gibi okunmuyor; özel SVG/Lucide |
| 131 | `LucideIcons.laptop` | 1 | sohbet | bileşen | `strokeRoundedLaptop` | birebir | - |  |
| 132 | `LucideIcons.library` | 1 | sohbet | bileşen | `strokeRoundedLibrary` | yakın | - | kavram aynı, çizim ayrıntısı farklı |
| 133 | `LucideIcons.lightbulb` | 1 | sohbet | bileşen | `strokeRoundedLightbulb` | birebir | `Idea` |  |
| 134 | `LucideIcons.listChecks` | 1 | anket | bileşen | `strokeRoundedListChecks` | birebir | - |  |
| 135 | `LucideIcons.listOrdered` | 1 | anket | bileşen | `strokeRoundedListOrdered` | birebir | - |  |
| 136 | `LucideIcons.lockKeyhole` | 1 | sohbet | 22 | `strokeRoundedLockKeyhole` | birebir | `Locked` |  |
| 137 | `LucideIcons.mailCheck` | 1 | kulüp | bileşen | `strokeRoundedMailCheck` | birebir | - |  |
| 138 | `LucideIcons.messageSquareText` | 1 | sohbet | 18 | `strokeRoundedMessageSquareText` | yakın | - | köşeleri daha yuvarlak balon |
| 139 | `LucideIcons.micOff` | 1 | çekirdek | bileşen | `strokeRoundedMicOff01` | birebir | `MicOff02` |  |
| 140 | `LucideIcons.notebookPen` | 1 | sohbet | bileşen | `strokeRoundedNotebookPen` | yakın | `NoteEdit` | kavram aynı, çizim ayrıntısı farklı |
| 141 | `LucideIcons.octagonAlert` | 1 | sohbet | bileşen | `strokeRoundedOctagonAlert` | birebir | - |  |
| 142 | `LucideIcons.pencilLine` | 1 | kulüp | bileşen | `strokeRoundedPencilLine` | birebir | `PencilEdit02` |  |
| 143 | `LucideIcons.pinOff` | 1 | kulüp | bileşen | `strokeRoundedPinOff` | yakın | - | iğne açısı farklı |
| 144 | `LucideIcons.qrCode` | 1 | etkinlik | bileşen | `strokeRoundedQrCode` | yakın | `QrCode01` | ayrıntı farklı |
| 145 | `LucideIcons.refreshCcw` | 1 | ortak | bileşen | `strokeRoundedRefreshCcw` | birebir | - |  |
| 146 | `LucideIcons.repeat` | 1 | medya | bileşen | `strokeRoundedRepeat` | yakın | `RepeatOne02` | tek ok halkası / köşe işareti farklı |
| 147 | `LucideIcons.repeat2` | 1 | takip | 13 | `strokeRoundedRepeat` | yakın | - | tek ok halkası / köşe işareti farklı |
| 148 | `LucideIcons.rotateCcw` | 1 | medya | bileşen | `strokeRoundedUndo` | yakın | `RotateLeft01` | Undo/Redo: çember ok (yön doğrulandı) |
| 149 | `LucideIcons.save` | 1 | etkinlik | bileşen | `strokeRoundedSave` | birebir | `FloppyDisk` |  |
| 150 | `LucideIcons.searchX` | 1 | ortak | bileşen | `strokeRoundedSearchX` | birebir | `SearchRemove` |  |
| 151 | `LucideIcons.shieldBan` | 1 | profil | 20 | `strokeRoundedShieldBan` | birebir | - |  |
| 152 | `LucideIcons.shieldX` | 1 | durum | bileşen | `strokeRoundedShieldX` | birebir | - |  |
| 153 | `LucideIcons.slidersHorizontal` | 1 | profil | bileşen | `strokeRoundedSlidersHorizontal` | birebir | - |  |
| 154 | `LucideIcons.smartphone` | 1 | sohbet | bileşen | `strokeRoundedSmartphone` | birebir | `SmartPhone01` |  |
| 155 | `LucideIcons.squareArrowOutUpRight` | 1 | profil | bileşen | `strokeRoundedSquareArrowOutUpRight` | birebir | `LinkSquare01` |  |
| 156 | `LucideIcons.squareTerminal` | 1 | durum | 16 | `strokeRoundedSquareTerminal` | birebir | `Terminal` |  |
| 157 | `LucideIcons.switchCamera` | 1 | sohbet | bileşen | `strokeRoundedSwitchCamera` | yakın | `CameraRotated01` | kavram aynı, çizim ayrıntısı farklı |
| 158 | `LucideIcons.tag` | 1 | kulüp | bileşen | `strokeRoundedTag01` | birebir | `Tag02` |  |
| 159 | `LucideIcons.thumbsUp` | 1 | anket | 44 | `strokeRoundedThumbsUp` | birebir | - |  |
| 160 | `LucideIcons.timerOff` | 1 | giriş | bileşen | `strokeRoundedTimerOff` | birebir | - |  |
| 161 | `LucideIcons.userCog` | 1 | kulüp | bileşen | `strokeRoundedUserCog` | yakın | `UserSettings01` | gövde daha açık; ek simge sağ altta |
| 162 | `LucideIcons.videoOff` | 1 | sohbet | 26 | `strokeRoundedVideoOff` | birebir | - |  |
| 163 | `LucideIcons.volleyball` | 1 | sohbet | bileşen | `strokeRoundedVolleyball` | birebir | - |  |
| 164 | `LucideIcons.vote` | 1 | ana sayfa | bileşen | `strokeRoundedVote` | yakın | - | kavram aynı, çizim ayrıntısı farklı |
| 165 | `LucideIcons.wandSparkles` | 1 | etkinlik | 18 | `strokeRoundedWandSparkles` | birebir | `MagicWand01` |  |
| 166 | `LucideIcons.zap` | 1 | sohbet | bileşen | `strokeRoundedZap` | birebir | `Flash` |  |
| 167 | `LucideIcons.zapOff` | 1 | sohbet | bileşen | `strokeRoundedZapOff` | birebir | `FlashOff` |  |

### 6.2 Material → Hugeicons (25)

| # | Kaynak | Kullanım | Alanlar | Boyut (dp) | Hugeicons sabiti (`HugeIcons.`) | Güven | Alternatif | Not |
|---|---|---|---|---|---|---|---|---|
| 1 | `Icons.check_rounded` | 3 | çekirdek, sohbet, anket | 16, 18 | `strokeRoundedTick02` | birebir | `Check` |  |
| 2 | `Icons.favorite` | 3 | keşfet | 14, 88 | `strokeRoundedFavourite` | yakın | `Heart` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 3 | `Icons.play_arrow_rounded` | 3 | sohbet | 22, 44 | `strokeRoundedPlay` | yakın | - | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 4 | `Icons.bookmark` | 2 | haber | 20 | `strokeRoundedBookmark01` | yakın | `Bookmark02` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 5 | `Icons.favorite_border` | 2 | medya, keşfet | 20 | `strokeRoundedFavourite` | birebir | `Heart` |  |
| 6 | `Icons.more_horiz` | 2 | medya, keşfet | 18, 24 | `strokeRoundedMoreHorizontal` | birebir | - |  |
| 7 | `Icons.add` | 1 | akademik | 22 | `strokeRoundedAdd01` | birebir | `Plus` |  |
| 8 | `Icons.chat_bubble_outline_rounded` | 1 | alt bar | bileşen | `strokeRoundedBubbleChat` | yakın | `Chat01` | dolu hâl yok (etkin durum: renk+kalınlık / hap / dolgu simülasyonu) |
| 9 | `Icons.chat_bubble_rounded` | 1 | alt bar | bileşen | `strokeRoundedBubbleChat` | yakın | `Chat01` | dolu hâl yok (etkin durum: renk+kalınlık / hap / dolgu simülasyonu) |
| 10 | `Icons.check_circle` | 1 | QR | 24 | `strokeRoundedCheckmarkCircle02` | yakın | `CircleCheck` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 11 | `Icons.check_circle_rounded` | 1 | anket | 14 | `strokeRoundedCheckmarkCircle02` | yakın | `CircleCheck` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 12 | `Icons.construction` | 1 | ortak | bileşen | `strokeRoundedWrench01` | yakın | `Construction` | baret/uyarı yerine anahtar |
| 13 | `Icons.error` | 1 | QR | 22 | `strokeRoundedAlertCircle` | yakın | `Alert02` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 14 | `Icons.explore_outlined` | 1 | alt bar | bileşen | `strokeRoundedDiscoverCircle` | yakın | `Compass` | dolu hâl yok (etkin durum: renk+kalınlık / hap / dolgu simülasyonu) |
| 15 | `Icons.explore_rounded` | 1 | alt bar | bileşen | `strokeRoundedDiscoverCircle` | yakın | `Compass` | dolu hâl yok (etkin durum: renk+kalınlık / hap / dolgu simülasyonu) |
| 16 | `Icons.home_outlined` | 1 | alt bar | bileşen | `strokeRoundedHome01` | yakın | `Home02` | çatı biçimi farklı; dolu hâl yok |
| 17 | `Icons.home_rounded` | 1 | alt bar | bileşen | `strokeRoundedHome01` | yakın | `Home02` | çatı biçimi farklı; dolu hâl yok |
| 18 | `Icons.image_outlined` | 1 | ortak | bileşen | `strokeRoundedImage02` | yakın | `Image01` | Image02 |
| 19 | `Icons.info_outline` | 1 | ortak | bileşen | `strokeRoundedInformationCircle` | birebir | `Info` |  |
| 20 | `Icons.pause_rounded` | 1 | sohbet | 44 | `strokeRoundedPause` | yakın | `PauseCircle` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 21 | `Icons.people_outline_rounded` | 1 | alt bar | bileşen | `strokeRoundedUserGroup` | yakın | `Users` | dolu hâl yok (etkin durum: renk+kalınlık / hap / dolgu simülasyonu) |
| 22 | `Icons.people_rounded` | 1 | alt bar | bileşen | `strokeRoundedUserGroup` | yakın | `Users` | dolu hâl yok (etkin durum: renk+kalınlık / hap / dolgu simülasyonu) |
| 23 | `Icons.star_outline_rounded` | 1 | anket | bileşen | `strokeRoundedStar` | birebir | - |  |
| 24 | `Icons.star_rounded` | 1 | anket | bileşen | `strokeRoundedStar` | yakın | - | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |
| 25 | `Icons.warning_rounded` | 1 | profil | 30 | `strokeRoundedAlert01` | yakın | `TriangleAlert` | Material DOLU; Hugeicons ücretsiz kümede dolu stil yok |

### 6.3 Aynı Hugeicons ikonuna giden birden çok kaynak

| Hugeicons | Kaynaklar |
|---|---|
| `strokeRoundedAdd01` | `Lucide plus`, `Material add` |
| `strokeRoundedAlert01` | `Lucide triangleAlert`, `Material warning_rounded` |
| `strokeRoundedAlertCircle` | `Lucide circleAlert`, `Material error` |
| `strokeRoundedBookmark01` | `Lucide bookmark`, `Material bookmark` |
| `strokeRoundedBubbleChat` | `Material chat_bubble_rounded`, `Material chat_bubble_outline_rounded` |
| `strokeRoundedCheckmarkCircle02` | `Lucide circleCheck`, `Material check_circle_rounded`, `Material check_circle` |
| `strokeRoundedDiscoverCircle` | `Lucide compass`, `Material explore_rounded`, `Material explore_outlined` |
| `strokeRoundedFavourite` | `Lucide heart`, `Material favorite`, `Material favorite_border` |
| `strokeRoundedHome01` | `Material home_rounded`, `Material home_outlined` |
| `strokeRoundedImage02` | `Lucide image`, `Material image_outlined` |
| `strokeRoundedInformationCircle` | `Lucide info`, `Material info_outline` |
| `strokeRoundedLockKeyhole` | `Lucide lock`, `Lucide lockKeyhole` |
| `strokeRoundedMoreHorizontal` | `Lucide ellipsis`, `Material more_horiz` |
| `strokeRoundedPlay` | `Lucide play`, `Material play_arrow_rounded` |
| `strokeRoundedRepeat` | `Lucide repeat2`, `Lucide repeat` |
| `strokeRoundedStar` | `Lucide star`, `Material star_rounded`, `Material star_outline_rounded` |
| `strokeRoundedTick02` | `Lucide check`, `Material check_rounded` |
| `strokeRoundedUserGroup` | `Lucide users`, `Material people_rounded`, `Material people_outline_rounded` |
| `strokeRoundedWrench01` | `Lucide wrench`, `Material construction` |

## 7. Karşılığı olmayanlar / sorunlular

| İkon | Durum | Öneri |
|---|---|---|
| `LucideIcons.delete` (backspace, 1 kullanım) | Ücretsiz kümede geri-sil ikonu yok (`Delete01` çöp kutusu) | Lucide'de bırak (yalnız `BuIconData.font`) ya da özel SVG |
| `LucideIcons.keyboard` (1) | `Keyboard` çizimi klavye gibi okunmuyor (robot yüzü) | Lucide'de bırak ya da özel SVG |
| Dolu stiller (alt bar 4 + beğeni/yıldız/kaydet/oynat/durum 15) | Dolu stil Pro | bölüm 5 |
| Hugeicons `Compass` | Kronometre gibi okunur | `DiscoverCircle` kullanıldı |
| Hugeicons `Lock` | Daire içinde anahtar deliği (kilit gövdesi değil) | `LockKeyhole` kullanıldı (yakın) |
| ≤ 13 dp küçük kullanımlar | İnce çizgi silikleşir (ör. `play` 10, `star` 11, `shield` 11, `pin` 12, `video` 12, `building2` 12.5, `repeat2` 13, `messageCircle` 9) | 14 dp'ye çıkar veya ağırlığı 2.0 yap |

Bu iki ikon için tek paket politikası tercih edilirse özel SVG (`assets/icons/*.svg` + `BuIconData.svg`) 30 dk'lık iştir; Lucide'i yalnız 2 ikon için bağımlılık olarak tutmak (+65 KB yazı tipi) önerilmez.

## 8. Geçiş planı (onaylanırsa)

1. **Merkezî sözlük**: `lib/core/icons/bu_icons.dart` — `BuIcons` (ad = bugünkü Lucide adı: `BuIcons.trash2`, `BuIcons.chevronRight` ...), değer `BuIconData` (`HugeIcons.strokeRounded…` + isteğe bağlı `filledVariant`). Eşleme tablosu bölüm 6'dan **üretilir** (`work/mapping.py` → Dart). Tek yerden değiştirilir; Lucide'e geri dönüş de burada.
2. **`BuIcon` widget'ı**: `HugeIcon`'ı sarar; `size` (zorunlu varsayılan), renk `IconTheme`/`context.bu`, `strokeWidth` 1.75 sabit, `semanticLabel`, `filled`, RTL aynalama (`matchTextDirection`), satırlar arası paylaşılan SVG dizgisi önbelleği (ikon+renk+kalınlık anahtarı; `HugeIcon` yalnız widget başına önbellekler). Bu tek yerde yapılırsa 887 çağrı noktası dokunulmadan düzelir.
3. **Mekanik dönüşüm** (betikle): `LucideIcons.x` → `BuIcons.x` (137 dosya); `Icon(` → `BuIcon(` (yalnız ikon çağrıları); `IconData` → `BuIconData` (73 dosya, 188 geçiş); Material 25 ikon elle (alt çubuk yeniden tasarım; beğeni `like_button.dart`; yıldız `poll_parts.dart`).
4. **`buDirIcon`**: `==` kıyası `BuIconData` üzerinde kalır (const listeler kimlik karşılaştırılır; `ChevronLeft` ≠ `ChevronRight`).
5. **Testler**: 48 dosya, 121 `find.byIcon`: yardımcı `findBuIcon(BuIcons.x)` (`byWidgetPredicate`); anlamsal testler değişmez. `flutter test` tamamı koşulmalı; sürüm iç dönüş yok.
6. **Golden/görsel doğrulama**: `docs/MOBILE_DESIGN_SYSTEM.md` (KİLİTLİ arayüz) güncellemesi + etkin durum kararı; alt çubuk ve ayarlar için `golden` testleri.
7. **Lisans metni**: uygulamada açık kaynak lisans sayfası **yok** (`showLicensePage`/`LicenseRegistry` kullanımı bulunamadı; Lucide için de aynı eksik). MIT notunu görünür kılmak için Ayarlar > Hakkında > "Açık kaynak lisansları" eklenmesi önerilir (Flutter `LicenseRegistry` pub paket LICENSE dosyalarını otomatik toplar).
8. **Sürüm sabitleme**: `hugeicons: 4.4.0` (kesin); 4.4.0 sürümünde 798 ikon yeniden çizildi (bookmark/folder/message ailesi) ve adlar kullanımdan kalktı; otomatik `^` güncellemesi görünümü sessizce değiştirir.

### Tahmini iş

| Adım | Süre |
|---|---|
| `BuIcons` sözlüğü + `BuIcon` widget + betik üretimi | 0,5 gün |
| Mekanik dönüşüm (137+73 dosya) + derleme düzeltmeleri | 1 gün |
| Alt çubuk + beğeni/kaydet/yıldız/oynat yeniden tasarımı (25 Material) | 0,5 gün |
| Test uyarlama (48 dosya) + golden | 0,5-1 gün |
| Cihaz üzerinde kare süresi/RTL/koyu tema denetimi (iOS+Android) | 0,5 gün |
| **Toplam** | **~3 – 3,5 iş günü** |

## 9. Riskler

- **Görünüm riski:** daha ince ve yuvarlak, glif ~%8 küçük; küçük boyutlarda (12-14 dp) zayıf. Marka kırmızısı ağırlığı etkin durumda dolu ikonun gücünü kaybeder.
- **Performans:** ikon başına SVG dizgisi + `SvgPicture` (8 widget vs 5); test ortamında ~1,5-1,8× yavaş. Cihazda **ölçülmedi**.
- **Mimari:** `IconData` tipi 73 dosyada değişir; üçüncü taraf widget'lara (`NavigationBar.icon` gibi `Icon` bekleyenler) sarmalayıcı gerekir.
- **Bağımlılık:** kendi başına sürümlenen küçük bir paket (4.4.0 sürümü 2026-10-30; 1.x → 4.x sürüm atlaması); yeniden adlandırma/yeniden çizim riski ⇒ kesin sürüm sabitle.
- **Erişilebilirlik/RTL:** paket vermiyor; `BuIcon` sarmalayıcısı şart.
- **Lisans:** MIT: telif notu görünür kılınmalı (bugün hiçbir paket için yok).
- **Kapsam kayması:** 2 ikon karşılıksız ⇒ ya iki paket ya özel SVG.

## 10. Öneri

**Şartlı evet.** Görsel olarak tutarlı ve sosyal uygulama diline uygun (yuvarlak uçlar, bol ikon), %99 kapsama ve ağaç budaması çalışıyor, boyut etkisi ihmal edilebilir. Ancak: (a) dolu hâlleri kaybetmek alt çubuk/beğeni tasarımını yeniden düşünmeyi gerektirir, (b) `IconData` tabanlı API ve 48 test dosyası değişir, (c) SVG çizim yolu Lucide yazı tipinden pahalıdır, cihazda doğrulanmadı. **Önce** tahtadaki "alt bar etkin/pasif" ve "mini önizleme" sayfalarını onaylayın; onaydan sonra geçiş `BuIcons` sözlüğü üzerinden tek dalda yapılır, kare süresi ölçümü kabul koşulu olur (profil modu, 500 satırlık sohbet/haber listesi).

## 11. Uygulama kararı (font yöntemi) — ICONS-MIGRATE 1. faz

Durum: **araç hattı, font ve sözlük hazır; kod geçişi (2. faz) yapılmadı.** Tarih: 2026-11-01.

### 11.1 Neden `HugeIcon` widget'ı değil, kendi yazı tipimiz

Bölüm 3.1'deki ölçüm (SVG dizgisi + `SvgPicture`, ikon başına 8 widget, ~1,5-1,8x yavaş) kullanıcının "telefonu zorlamayan, ucuz render" kuralıyla çelişir. Çözüm: Hugeicons **glif verisinden** statik bir yazı tipi (`mobile/assets/fonts/BuIcons.ttf`) üretmek.

| Özellik | Font (seçilen) | `HugeIcon` |
|---|---|---|
| Çizim maliyeti | Lucide ile aynı (statik glif, `Icon` = 1 `RichText`) | SVG ayrıştırma + widget ağacı |
| `IconData` tipi | **değişmez** (73 dosyada tip değişikliği yok) | `BuIconData` sarmalayıcı gerekir |
| `IconTheme` (boyut/renk/opaklık), `semanticLabel`, RTL, ağaç budaması | çalışır | boyut yok sayılır, etiket yok |
| Çalışma zamanı bağımlılığı | yok (`hugeicons` uygulamada YOK) | `hugeicons` + `flutter_svg` kod yolu |
| Boyut | 182 glif ≈ 118 KB ham; ağaç budamasıyla kullanılanlar kadar (Lucide 930 KB -> 65 KB gibi) | +0,1 MB |

Sonuç: `Icon(BuIcons.home, size: 22, color: ...)`; `BuIconButton.icon`, `ClubMenuEntry` vb. `IconData` kalır. 2. faz **salt yeniden adlandırmadır**.

### 11.2 Üretim hattı

`mobile/tools/icons/` (ayrıntı ve komutlar `README.md`): `parse_doc_map.py` (bu belge bölüm 6 -> `icon_map.json`) -> `extract_hugeicons.py` (`hugeicons` **4.4.0** tarball'ından yalnız kullanılan 166 ikon, `hugeicons_subset.json`) -> `build_icons.py` (skia-pathops ile stroke'u kontura çevirir: **strokeWidth 1.75**, öğe başına cap/join; birleştirir; TTF `unitsPerEm` 2400, ascent = em, descent = 0 -> glif `Icon` kutusunda SVG ile birebir oturur; `bu_icons.dart`). Kod noktaları `icon_codepoints.json` ile ekleme-yalnız sabitlenir (0xE000...).

Sürüm sabitleme: yalnız `hugeicons-4.4.0` (tarball'dan indirilir; alt küme repoda). 4.x sürümleri ikonları yeniden çizebilir; yükseltme bilinçli yapılır (`VERSION` + `extract_hugeicons.py` + `build_icons.py` + tahta bakışı).

Üretimde bulunan ve çözülen tuzaklar (aynı hataya düşmemek için): (1) Skia stroker offset eğrilerini kaba kuadratik yaklaşıklar, 24 birimlik koordinatta daire kareye kayar -> geometri 100x büyütülüp stroke edilir; (2) `OpBuilder` ile çok operandli UNION, butt uçlu çizgi halka ile kesişince parça kaybeder (Share08) -> parçalar normalize edilip tek yolda toplanır, `simplify` yalnız alan doğrulamasından geçerse uygulanır, aksi hâlde örtüşen konturlar bırakılır (TrueType nonzero boyar); (3) çok alt yollu tek stroke'u birleştirirken parça kaybı (UserCog) -> alt yollar ayrı stroke edilir; (4) `SquareArrowOutUpRight` oku Skia `simplify` için dejeneredir -> yukarıdaki geri düşüş.

### 11.3 Glif kalitesi (ölçüldü)

Bağımsız referans: aynı SVG, `resvg` ile (stroke 1.75). Aday: `BuIcons.ttf`, FreeType (PIL). `verify_icons.py`, 182 glif:

| Ölçü | Sonuç |
|---|---|
| 24 dp @8x (192 px) kapsama IoU | ortalama 0,987; en düşük 0,942 (zapOff) |
| 16 / 20 / 24 dp (8x üst örnek, kutu süzgeci) ortalama mutlak fark | 0,0070 / 0,0065 / 0,0030; en kötü 0,023 (qrCode, 16 dp) |
| Mürekkep oranı font/referans (16 dp) | 0,984 – 1,018 (kalınlık sapması ≤ %2) |
| Eşik dışı (IoU < 0,93, mürekkep ±%5, 24 dp farkı > 0,03) | yok |
| Boş/yarım/delikli glif | yok (flutter test: 182 glif 24 dp'de boş değil, ortalı, kutuya taşmıyor) |

Lucide ile karşılaştırma (165 ortak ad): sınırlayıcı kutu oranı BuIcons/Lucide **medyan 0,989** (p10 0,933, p90 1,047); yani bölüm 4'teki "~%8 küçük" gözlemi font yöntemiyle **doğrulanmadı**, boyut yaklaşık aynıdır. Mürekkep oranı medyan **0,877**: 1.75 çizgi Lucide 2.0'dan ~%12 daha az boyayı kullanır (daha hafif görünüm). Bu yüzden **em-ölçek katsayısı uygulanmadı** (`build_icons.py --scale 1.0` varsayılan); ağırlığı artırmak isterseniz `bu_icon_lib.STROKE_WIDTH` (1.75 -> 2.0) ve yeniden üretim tek yerdir. 14 dp altı kullanımlar (15 yer, bkz. 11.6) yine ince görünür; `BuIconSize.minLegible = 14` öneri sabitidir.

Kontrol tahtaları (`C:\bu_design\icons\`): `migrate_kontrol_01..07_referans_font.png` (her glif: referans SVG | font | fark, 24 ve 16 dp, 4x), `migrate_kontrol_lucide_karsilastirma_1..4.png` (Lucide solda, BuIcons sağda, 24/16 dp), `migrate_kontrol_dolu_haller.png`, `migrate_kontrol_alt_bar.png`.

### 11.4 Dolu hâller

Ücretsiz küme yalnız çizgi stilidir; dolu glifler çizgi verisinden **kapalı şekillerin dolgusu + iç ayrıntının oyulması** ile üretildi (`bu_icon_lib.FILLED_RECIPES`): `heartFilled`, `starFilled`, `bookmarkFilled`, `bellFilled`, `homeFilled`, `chatFilled` (noktalar oyuk), `usersFilled`, `discoverFilled` (ibre oyuk), `circleCheckFilled` (tik oyuk), `circleAlertFilled`, `triangleAlertFilled`, `playFilled`, `pauseFilled` (13/13 üretildi). Alt bar önerisi (tahta 10 ile uyumlu): ana yöntem **renk + yumuşak hap zemin** (çizgi glif), dolu glif isteğe bağlı ikinci seçenektir (`migrate_kontrol_alt_bar.png` her iki satırı gösterir). Pusula doluyken ibre oyuk kalır (tahta 10'daki "iğne kaybolur" sorunu yok).

### 11.5 Lisans

MIT metni `mobile/assets/licenses/hugeicons-MIT.txt` (pubspec varlığı). Uygulamada lisans sayfası yoktu; `lib/core/icons/bu_icon_licenses.dart` `registerBuIconLicenses()` ile `LicenseRegistry`'ye kaydeder (2. fazda `main()` içinden bir kez çağrılır; Ayarlar > Hakkında > lisanslar sayfası ayrı iştir). Lucide (ISC) için de aynı eksik hâlâ geçerli.

### 11.6 2. faz planı (mekanik değişim)

Kuru çalıştırma (`python -I -X utf8 mobile/tools/icons/migrate_usages.py --dry-run`, 2026-11-01 ağacı):

| Ölçü | Sayı |
|---|---|
| Taranan / değişecek dosya | 507 / 187 (lib 145, test 42) |
| Değişim | `LucideIcons` 1082 + `Icons` 47 = **1129** |
| Sınıf | `Icon(` doğrudan 350, `IconData` taşıyan parametre/liste 660, `==` karşılaştırma 10 (`buDirIcon`), `find.byIcon` 109 |
| `IconData` tipi geçen dosya | 78 (**tip değişmez**) |
| `widgets/bu.dart` ihracıyla gelecek (import eklenmez) / import eklenecek | 155 / 29 |
| Lucide'de kalan (karşılıksız) kullanım | `delete` 3, `keyboard` 3 (`BuIcons.delete`/`keyboard` Lucide'e işaret eder) |
| Eşlemede olmayan (atlanır, yalnız test dosyalarında) | Lucide: mail, house, flame, moon, paperclip, terminal, gavel, key, signal, wifi, batteryFull; Material: 20 ad (bookmark_border, mode_comment_outlined, send, share, ...) |

Adımlar: (1) `widgets/bu.dart`'a `export '../core/icons/bu_icons.dart';` ekle; (2) `migrate_usages.py --apply`; (3) `bu_widgets.dart` `buDirIcon`'u `buIconDirection`'a yönlendir (veya bırak; `BuIcons` sabitleriyle zaten çalışır); (4) `main()`'e `registerBuIconLicenses()`; (5) `floating_nav.dart`, `like_button.dart`, `poll_parts.dart` gibi Material çiftli yerleri elle gözden geçir (script "elle gözden geçirilecek" listesi: alt bar `home`/`homeFilled` vb.); (6) `flutter analyze` + `flutter test` tamamı; (7) `lucide_icons_flutter` yalnız `BuIcons.delete/keyboard` için kalır; ayrı iş: o iki ikonu özel SVG/glifle çıkarıp bağımlılığı kaldırmak.
Not: belge bölüm 8-9'daki `BuIcon` widget'ı, `BuIconData`, SVG önbelleği, 48 test dosyasında `findBuIcon` yardımcısı gereksizdir; `find.byIcon(BuIcons.x)` aynen çalışır.
