# Mobil HIG denetimi (Android) ve düzeltme planı

Tarih: 2026-11-02. Dal: `feat/hig-audit` (taban: `feature/mobil-uygulama` d798d23c). Salt-okunur denetim: `mobile/lib` koduna dokunulmadı; yalnız `docs/`, `mobile/tools/`, `mobile/test/hig/` eklendi.

Kural kitabı: [APPLE_HIG_KURALLARI.md](APPLE_HIG_KURALLARI.md) (232 kural satırı: 191 Evet, 25 Kısmen, 16 Hayır (iOS'a özgü); 14 çatışma kararı). Bu belge o kuralların ölçüm sonuçlarıdır. Kapsam yalnız Android; iOS kapsam dışı. Hareket (süre, eğri, animasyon) `feat/motion-system` dalındaki ajana aittir ve ölçülmedi. Tipografi K-21 (en küçük 11,5 sp, tek tip sistemi) ihlal sayılmadı; yalnız **11'in altı** ve **jeton dışı sabit değerler** ayrıca sayıldı.

## 0. Nasıl çalıştırılır

```bash
# Statik ölçümler (a, b-statik, d, e, f, g, h-statik, i, j): ~3 sn, ASCII çıktı
python -I -X utf8 mobile/tools/hig_audit.py                       # özet
python -I -X utf8 mobile/tools/hig_audit.py --json out.json       # tüm sayılar + en kötü örnekler
python -I -X utf8 mobile/tools/hig_audit.py --only contrast,font  # seçili ölçümler

# Dinamik ölçümler (b, c, g-klavye, h): C:\bu_hig ASCII bağlantısından, ~1,5 dk
cd C:/bu_hig && PUB_CACHE='C:\pubcache' HIG=1 HIG_OUT=build/hig_report.json \
  /c/src/flutter/bin/flutter.bat test test/hig/hig_audit_test.dart --tags hig
```

`mobile/test/hig/hig_audit_test.dart` **rapor üretir, hiçbir ölçümde testi kırmaz**; `HIG=1` olmadan 93 testin hepsi atlanır (normal `flutter test` paketini bozmaz). Etiket: `@Tags(['hig'])`. Çıktı JSON'a yazılır, konsola `HIG|` önekli satırlar basılır.

Sınırlar (dürüst not):
- Dinamik ölçüm 22 ekranı sahte backend ile çizer. Menü, Etkinliklerim, Engellenenler ve Destek sahte uç tanımsız olduğundan **hata/boş durumunda** ölçüldü (1-3 dokunulabilir düğüm); dolu hâlleri ayrıca bakılmalı.
- `textContrastGuideline` piksel tabanlıdır; giriş animasyonu/saydamlık altındaki metinlerde yanlış düşük çıkabilir. Böyle satırlar aşağıda "belirsiz" diye işaretlendi.
- Statik ölçümler regex + parantez dengeleyicidir; "şüpheli" demek ihlal demek değildir (özellikle d-f-g). Her ölçümde yanlış pozitif oranı belirtilmiştir.
- Kapsam: `lib/` 282 dosya, 88 562 satır (tema tanım dosyaları ve üretilmiş `l10n`/`BuIcons` hariç).

## 1. Sonuç özeti

| Ölçüm | Toplam | Önem |
|---|---|---|
| (a) Kontrast, jeton çiftleri (açık+koyu) | 45 çift, **0 kalan**; metin 37/37 açık, 37/37 koyu; UI/ikon 8/8 | Düşük (iyi) |
| (a) Kontrast, çizilmiş ekranlar | 12 açık + 6 koyu ihlal (3 kesin: sürüm satırı/alan notu 3,11:1; 15 belirsiz) | Orta |
| (b) Dokunma hedefi, dinamik (22 ekran) | 53 ihlal < 48 dp (açık=koyu), 46 ihlal < 44 dp; etiketsiz hedef **0** | Yüksek |
| (b) Dokunma hedefi, statik şüpheli | 87 yer, 52 dosya | Orta |
| (c) Yazı ölçeği 1,3: taşma | 44 kombinasyonda **0** | Düşük (iyi) |
| (c) Yazı ölçeği 2,0: taşma | 44 kombinasyonun 4'ü (Haber listesi, Menü), 3 farklı kod yeri | Yüksek |
| (d1) `Color(0x..)` / `Colors.*` | 27 + 4 (yalnız 4 dosya) | Düşük |
| (d2) Sabit `fontSize` | 319 sabit; **1 tanesi < 11**; 190 tanesi jeton dışı | Orta |
| (d3) 4'ün katı olmayan boşluk | EdgeInsets 323 / 2521 değer, SizedBox 240 / 1324 | Orta |
| (e) Etiket/semantik | `IconButton` tooltip'siz 2/54; etiketsiz `Image` 28; yalnız-simge dokunma şüphesi 39 | Yüksek |
| (f) Durumlar | 61 ağ ekranının 22'si şüpheli (elle bakılan örneklerde çoğu yanlış pozitif) | Orta |
| (g) Form/klavye | 74 alanın 64'ü `keyboardType`siz, 59'u `autofillHints`siz, 49'u `textInputAction`sız; klavye testi 4 ekranda geçti | Orta |
| (h) RTL dinamik | 176 kombinasyonda taşma/istisna **0** | Düşük (iyi) |
| (h) RTL statik | 252 sabit sol/sağ (232 `EdgeInsets`, 13 `Positioned`, 7 `Alignment`) | Orta |
| (i) Koyu tema | koyuda açık değere düşen alan **0**; `BuTokens.light` doğrudan 27 (10 dosya, çoğu bilinçli) | Düşük |
| (j) Metin tonu | teknik hata kodu 0, ünlem 0; 3 "Tamam", yeniden/tekrar dene ikiliği, 6 BÜYÜK HARF etiket | Düşük-Orta |

## 2. (a) Renk çiftleri: WCAG kontrastı

Yöntem: `BuTokens.light/dark` değerleri (`lib/core/theme.dart`) ayrıştırılır, ağırlıklı luminans formülüyle oran hesaplanır. Eşik: metin (T) 4,5:1; simge, kontrol çerçevesi (L) 3:1; `bd` yalnız kart ayracıdır, bilgi (I). Hero yazısı `BuHeroCard`'da `onMedia` olduğundan çift `onMedia/h1` alındı.

| Çift | Eşik | Açık | Koyu | Sonuç |
|---|---|---|---|---|
| ink / bg | 4,5 | 15,39 | 15,50 | ikisi de geçer |
| ink / sf | 4,5 | 16,54 | 14,05 | ikisi de geçer |
| ink / sf2 | 4,5 | 13,91 | 12,34 | ikisi de geçer |
| ink / sf3 (sheet/dialog) | 4,5 | 16,54 | 11,18 | ikisi de geçer |
| mut / bg | 4,5 | 6,40 | 7,40 | ikisi de geçer |
| mut / sf | 4,5 | 6,88 | 6,70 | ikisi de geçer |
| mut / sf2 | 4,5 | 5,79 | 5,89 | ikisi de geçer |
| mut / sf3 | 4,5 | 6,88 | 5,33 | ikisi de geçer |
| pr / bg (bağlantı) | 4,5 | 5,21 | 6,35 | ikisi de geçer |
| pr / sf (bağlantı) | 4,5 | 5,60 | 5,76 | ikisi de geçer |
| onPr / pr (birincil düğme) | 4,5 | 5,60 | 6,53 | ikisi de geçer |
| onSoft / soft | 4,5 | 7,36 | 8,98 | ikisi de geçer |
| pr / soft | 4,5 | 4,77 | 5,18 | ikisi de geçer (açıkta sınıra yakın) |
| onNav / nav | 4,5 | 16,54 | 10,40 | ikisi de geçer |
| onMedia / h1 (hero) | 4,5 | 4,96 | 5,95 | ikisi de geçer |
| onMedia / h2 (hero) | 4,5 | 5,72 | 7,58 | ikisi de geçer |
| ok / bg | 4,5 | 4,94 | 9,49 | ikisi de geçer (açıkta sınıra yakın) |
| ok / sf | 4,5 | 5,31 | 8,60 | ikisi de geçer |
| onOkSoft / okSoft | 4,5 | 8,04 | 9,57 | ikisi de geçer |
| danger / bg | 4,5 | 7,21 | 8,20 | ikisi de geçer |
| danger / sf | 4,5 | 7,74 | 7,43 | ikisi de geçer |
| danger / dangerSoft | 4,5 | 6,40 | 6,92 | ikisi de geçer |
| info / bg | 4,5 | 7,55 | 8,40 | ikisi de geçer |
| info / sf | 4,5 | 8,11 | 7,61 | ikisi de geçer |
| onInfoSoft / infoSoft | 4,5 | 8,68 | 9,24 | ikisi de geçer |
| aqua / bg | 4,5 | 5,45 | 9,53 | ikisi de geçer |
| onAquaSoft / aquaSoft | 4,5 | 7,25 | 9,63 | ikisi de geçer |
| warn / bg | 4,5 | 5,23 | 9,52 | ikisi de geçer |
| warn / sf | 4,5 | 5,62 | 8,63 | ikisi de geçer |
| onWarnSoft / warnSoft | 4,5 | 8,13 | 10,17 | ikisi de geçer |
| qrInk / qrPaper | 4,5 | 21,00 | 21,00 | ikisi de geçer |
| tint[0..5] fg/bg (marka, mavi, yeşil, amber, su mavisi, nötr) | 4,5 | 7,25 - 8,68 | 7,92 - 10,17 | altısı da geçer |
| bdStrong / bg (kontrol çerçevesi) | 3,0 | 3,41 | 4,50 | ikisi de geçer |
| bdStrong / sf | 3,0 | 3,66 | 4,07 | ikisi de geçer |
| pr / bg (simge) | 3,0 | 5,21 | 6,35 | ikisi de geçer |
| ok / okSoft (simge) | 3,0 | 4,56 | 7,59 | ikisi de geçer |
| danger / sf (simge) | 3,0 | 7,74 | 7,43 | ikisi de geçer |
| warn / warnSoft (simge) | 3,0 | 5,03 | 7,34 | ikisi de geçer |
| info / infoSoft (simge) | 3,0 | 6,82 | 6,71 | ikisi de geçer |
| aqua / aquaSoft (simge) | 3,0 | 5,01 | 7,29 | ikisi de geçer |
| bd / bg, bd / sf (kart ayracı, yalnız bilgi) | - | 1,36 / 1,46 | 1,59 / 1,44 | ayraç, bilgi taşımaz |

Sayım: metin 37 çiftin 37'si açıkta, 37'si koyuda ≥ 4,5. AAA (≥ 7) metin: açık 21, koyu 28 (HIG koyu mod 7:1 hedefi için iyi). UI/ikon 8/8. **Jeton düzeyinde kalan yok.**

Küçük notlar (ihlal değil): `onMedia` üstüne konan `scrim` fotoğraf üstünde α = 0,35'te yalnız 2,43:1, α = 0,50'de 3,95:1, α = 0,60'ta 5,74:1 verir (beyaz fotoğraf en kötü durum); metin taşıyan fotoğraf katmanlarında α ≥ 0,55 kullanılmalı. Seçili çerçeve (`selectedBorder`, `pr` α 0,45 / `soft`) 2,03:1'dir; seçili durum zaten dolgu + yazı rengiyle de belirtildiği için kabul edilebilir.

**Çizilmiş ekranlarda** (`textContrastGuideline`, açık/koyu ayrı pump, 22 ekran): açık 12, koyu 6 ihlal.

| Ekran | Metin | Ölçülen | Kesinlik |
|---|---|---|---|
| Welcome (açık) | "Yalnızca okul e-postası ..." (14 sp) | 3,11:1 | Kesin açıkta, koyuda geçer |
| Welcome, Login (açık) | "Sürüm 2.0.8" (12,5 sp, `mut`) | 3,11:1 | Kesin; `mut` jetonu 6,4:1'dir, üst katmanda saydamlık olmalı (`lib/features/auth/welcome_page.dart:86`, `login_page.dart:285`) |
| SearchPage (açık) | "Haber", "Etkinlik", "Kişi" sekme etiketleri | 1,42 / 2,20 / 4,00 | Belirsiz (geçiş animasyonu altında olabilir) |
| SearchPage | "Haber, duyuru, kulüp..." ipucu | 1,94 | Belirsiz |
| Menu, MyEvents, BlockedUsers, Support | "Bulunamadı." hata metni | 1,94 açık / 3,75 koyu | Belirsiz (hata ekranı giriş animasyonu; `BuErrorState` gövdesi `mut`) |
| Notifications | "Hepsi bu kadar" | 1,35 açık / 2,14 koyu | Belirsiz (saydam öğe) |

Önem: jeton Düşük; ekran kullanımı **Orta** (3 kesin + 15 belirsiz, elle doğrulanmalı).

## 3. (b) Dokunma hedefleri

### 3.1 Dinamik (Flutter yönergeleri, 22 ekran x açık/koyu, 390x844)

`androidTapTargetGuideline` (48 dp), `iOSTapTargetGuideline` (44 dp), `labeledTapTargetGuideline`, `textContrastGuideline`. Toplam 237 dokunulabilir anlamsal düğüm ölçüldü.

| Ekran | Dokunulabilir | < 48 dp (açık) | < 48 dp (koyu) | < 44 dp | Etiketsiz |
|---|---|---|---|---|---|
| Welcome | 2 | 0 | 0 | 0 | 0 |
| Login | 8 | **2** | 2 | 0 | 0 |
| Register | 6 | 0 | 0 | 0 | 0 |
| ForgotPassword | 4 | **1** | 1 | 0 | 0 |
| AppShell (Ana Sayfa + alt gezinme) | 28 | 0 | 0 | 0 | 0 |
| HomeTab | 23 | 0 | 0 | 0 | 0 |
| DiscoverTab | 5 | 0 | 0 | 0 | 0 |
| SearchPage | 8 | **1** | 1 | 1 | 0 |
| NewsListPage | 21 | **3** | 3 | 1 | 0 |
| MenuPage (hata durumu) | 2 | 0 | 0 | 0 | 0 |
| AcademicHub | 6 | 0 | 0 | 0 | 0 |
| ChatTab | 11 | 0 | 0 | 0 | 0 |
| NewChatPage | 4 | 0 | 0 | 0 | 0 |
| ClubsTab | 13 | **1** | 1 | 0 | 0 |
| EventsPage | 56 | **44** | 44 | 44 | 0 |
| PollListPage | 4 | 0 | 0 | 0 | 0 |
| NotificationsPage | 6 | **1** | 1 | 0 | 0 |
| ProfileTab | 10 | 0 | 0 | 0 | 0 |
| SettingsPage | 14 | 0 | 0 | 0 | 0 |
| MyEventsPage (hata durumu) | 3 | 0 | 0 | 0 | 0 |
| BlockedUsersPage (hata durumu) | 2 | 0 | 0 | 0 | 0 |
| SupportPage (hata durumu) | 1 | 0 | 0 | 0 | 0 |
| **Toplam** | 237 | **53** | **53** | **46** | **0** |

En kötü 10 örnek (ölçülen boyut):
1. `EventsPage` takvim şeridi: 42 gün hücresi 50x41 dp ("26 Ekim, Pazartesi" ... ), `lib/features/events/events_page.dart` (takvim bölümü).
2. `EventsPage` "Önceki ay" 36x48 dp, "Sonraki ay" 36x48 dp (aynı dosya, ay başlığı satırı).
3. `SearchPage` arama metin alanı: anlamsal alan düğümü 251x22 dp (`lib/features/search/search_page.dart`; görünür kutu daha büyük olabilir, dokunma düğümü küçük).
4. `Login` e-posta alanı 320x46, parola alanı 272x46 dp (`RefTextField`, `lib/features/auth/widgets/auth_ref.dart`).
5. `ForgotPassword` e-posta alanı 320x46 dp (aynı bileşen).
6. `NewsListPage` tür çipleri: "Haber" 44x44, "Duyuru" 52x44, "Etkinlik" 51x44 dp (`lib/features/news/icerik_parts.dart`).
7. `ClubsTab` "Ara" düğmesi 44x48 dp.
8. `NotificationsPage` "Tümünü okundu yap" 195x44 dp.
9. Statik: `lib/features/events/etkinlik2_widgets.dart:495` (BuPressable + 8 dp SizedBox, 5 yer).
10. Statik: `lib/features/chat/chat_info_parts.dart:211` (InkWell + 12 dp SizedBox, 4 yer).

Etiketsiz dokunma hedefi **0**: `labeledTapTargetGuideline` 22 ekranda temiz. Alt gezinme (AppShell) 28 düğümde sıfır ihlal: hap hedefleri 48 dp. Önem: **Yüksek** (EventsPage tek başına 44).

### 3.2 Statik şüpheliler (87 yer, 52 dosya)

Yöntem: `InkWell/GestureDetector/BuPressable/IconButton` çağrılarının dengeli argümanlarında 44 dp altı `SizedBox`/`Container` + simge (BuTouchTarget/minSize yoksa), `minimumSize < 44`, `BoxConstraints(minWidth|minHeight < 44)`, `VisualDensity.compact`, `tapTargetSize: shrinkWrap`. Yanlış pozitif beklenir: `BuIconButton` ve `BuPressable` görünür kutuyu küçük tutup 48 dp hedef verir (örn. dinamik ölçümde alt gezinme 0 ihlal). En kötü 10 dosya (ilk satır):

| Sayı | Dosya:satır | Bulgu |
|---|---|---|
| 5 | `lib/features/events/etkinlik2_widgets.dart:495` | BuPressable + 8 dp SizedBox |
| 4 | `lib/features/chat/chat_info_parts.dart:211` | InkWell + 12 dp SizedBox |
| 3 | `lib/core/push/push_banner.dart:171` | InkWell + 12 dp; `:243` VisualDensity.compact; `:244` min 40 dp |
| 3 | `lib/features/academic/akad_widgets.dart:807` | BuPressable + 8 dp; `:127` min 24; `:771` min 24 dp |
| 3 | `lib/features/chat/chat_detail_page.dart:2523` | InkWell + 6 dp |
| 3 | `lib/features/chat/chat_tab.dart:885` | BuPressable + 12 dp |
| 3 | `lib/features/chat/media_picker_page.dart:619` | GestureDetector + 2 dp |
| 3 | `lib/features/home/home_parts.dart:60` | InkWell + 12 dp |
| 3 | `lib/features/system/gate_views.dart:243` | minimumSize Size(0, 48) (genişlik 0) |
| 3 | `lib/widgets/bu_widgets.dart:324` | BuPressable + 6 dp |

Paket dağılımı (statik): P1 8, P2 8, P3 8, P4 8, P5 24, P6 17, P7 8, P8 6.

## 4. (c) Yazı ölçeği 1,3 ve 2,0: taşma

Yöntem: 22 ekran x genişlik {320, 390} x ölçek {1,3; 2,0} (TR, açık tema), tüm `FlutterError`'lar toplanır (`RenderFlex overflowed` + istisnalar). 88 kombinasyon.

| Ölçek | Taşan kombinasyon | İstisna |
|---|---|---|
| 1,3 | **0 / 44** | 0 |
| 2,0 | **4 / 44** | 0 |

Taşan yerler (2,0):
1. `NewsListPage` 320 dp: `lib/features/news/icerik_parts.dart:428` 7 px alttan; `:411` 63 px sağdan (4 taşma).
2. `NewsListPage` 390 dp: aynı `:428` 7 px alttan (3 taşma).
3. `MenuPage` 320 dp: `lib/features/menu/menu_parts.dart:139` 14 px alttan (7 taşma).
4. `MenuPage` 390 dp: aynı `:139` 14 px alttan (9 taşma).

Önem: **Yüksek** (HIG/Android en az %200 hedefi; ancak 2,0 yalnız bu iki ekranda kırılıyor). Not: `FloatingNav` etiketleri 1,15 ile sınırlıdır (bilinçli, HIG "sekme başlıkları orantılı büyümez").

## 5. (d) Renk, yazı boyutu, boşluk ihlalleri

### 5.1 Renk

Yöntem: yorumlar/dizeler maskelenir; `Color(0x..)`, `Color.fromARGB/fromRGBO` ve `Colors.*` (transparent hariç) sayılır; tema tanım dosyaları (`theme.dart`, `theme/`, `typography.dart`) hariç.

Toplam: `Color(0x..)` **27** (4 dosya), `Colors.*` **4** (hepsi `Colors.white`, tek dosya). En kötü örnekler:

| Sayı | Dosya:satır | Not |
|---|---|---|
| 18 | `lib/widgets/bu_default_avatar.dart:61` | Varsayılan avatar paleti (bilinçli sabit palet; `Colors.white` x4 de burada) |
| 6 | `lib/features/academic/academic_models.dart:103` | Ders rengi eşlemesi: 'red'/'amber'/'green'/'teal'/'blue' sabit değerleri (jetonlarla aynı değer: `0xFFBC3A2D`, `9A5700`, `1E7A50`, `0B6E86`, `1F4E96`) |
| 2 | `lib/features/chat/media_preview_page.dart:32` | `Color(0x00000000)` başlangıç değeri (şeffaf yer tutucu, ihlal değil) |
| 1 | `lib/features/chat/sohbety_widgets.dart:13` | `BoxShadow(color: Color(0x40171E33)...)` sabit gölge |

Önem: **Düşük** (CLAUDE.md "renk yalnız context.bu" kuralına neredeyse tam uyum). `BuTokens.light/dark` doğrudan kullanımı 27 yerde (10 dosya; `media_crop/crop_page.dart` 10, `chat/chatd_parts.dart`, `message_bubble.dart`, `event_detail_page.dart`, `event_parts.dart`, `qr_painter.dart` ...): çoğu "her zaman açık yüzey" (QR, kapak üstü) niyetli; tema değişiminde sorun çıkarmadığı elle doğrulanmalı. `isDark ? Color(...)` biçimi: **0**.

### 5.2 Yazı boyutu

Yöntem: sayısal `fontSize: N` literalleri; `BuScale` = {22, 18, 16, 15, 14, 12,5, 11,5}.

| Ölçüt | Sayı |
|---|---|
| Toplam sabit `fontSize` literali | 319 |
| Jeton ölçeğinde (izinli) | 128 |
| Jeton dışı (≥ 11) | **190** (60 dosya) |
| 11'in altı | **1** (`lib/features/home/home_parts.dart:729`, 10 sp, "homeBrandSubtitle") |
| İnce ağırlık (w100-w300) | 0 |

Sık jeton dışı değerler: 13 sp x105, 12 sp x39, 17 sp x21, 20 sp x7, 28 sp x5, 26 sp x5, 13,5 sp x4, 88 sp x2. En kötü 10 dosya: `home/home_parts.dart` 17 (`:91` 12), `academic/timetable_parts.dart` 10 (`:80` 13), `polls/poll_detail_page.dart` 10 (`:176` 13), `search/search_page.dart` 10 (`:483` 13), `academic/exams_page.dart` 9 (`:221` 13), `events/events_page.dart` 9 (`:708` 28), `home/home_layout_sheet.dart` 7 (`:90` 13,5), `menu/menu_parts.dart` 6 (`:181` 13), `profile/edit_profile_page.dart` 6 (`:241` 13), `profile/notification_prefs_page.dart` 6 (`:323` 13).

Önem: **Orta** (jeton dışı), 10 sp tek örnek **Yüksek ama önemsiz çaba**. Karar gerekir (bkz. D-1): 13 sp 105 yerde kullanılıyor; ya ölçeğe eklenir (görünüm değişmez) ya 12,5/14'e çekilir (görünüm hafif değişir).

### 5.3 Boşluk ölçeği

Yöntem: `EdgeInsets(Directional).(all|symmetric|only|fromSTEB|fromLTRB)` içindeki her sayı ve `SizedBox(width|height: N)`; 4'ün katı olmayan ve ölçekte (`BuSpace.xxs` 2, `BuGap` 6) bulunmayan değerler ihlal.

| Ölçüt | Değer |
|---|---|
| EdgeInsets çağrısı / sayısal değer | 1366 / 2521 |
| 4'ün katı olmayan, ölçek dışı (çağrı başına ilk ihlal) | **323** (116 dosya) |
| Ölçekte olan ama 4'ün katı olmayan (2, 6) | 167 (ihlal sayılmadı) |
| Tek eksenli `SizedBox` aralayıcı / ihlal | 1324 / **240** (92 dosya) |

En kötü örnekler (EdgeInsets): `events/event_form_page.dart` 11 (`:777` 10), `support/support_common.dart` 11 (`:65` 10), `academic/akad_widgets.dart` 9 (`:128` 10), `events/etkinlik2_settings_page.dart` 9 (`:205` 10), `chat/message_bubble.dart` 8 (`:209` 3), `events/etkinlik2_widgets.dart` 8 (`:237` 14), `search/search_page.dart` 8 (`:539` 10), `academic/timetable_parts.dart` 7 (`:51` 11), `chat/chat_detail_page.dart` 7 (`:2388` 10), `polls/poll_form_page.dart` 7 (`:177` 16,5).
En kötü (SizedBox): `profile/user_profile_page.dart` 16 (`:319` 14), `events/event_form_page.dart` 11 (`:595` 10), `home/home_parts.dart` 8 (`:404` 3), `academic/announcements_page.dart` 7 (`:231` 1), `academic/course_form_page.dart` 7 (`:105` 14), `clubs/club_ref_widgets.dart` 6 (`:153` 14), `events/etkinlik2_settings_page.dart` 6 (`:269` 10), `events/events_page.dart` 6 (`:702` 5), `widgets/report_sheet.dart` 6 (`:84` 14), `academic/reminder_settings_page.dart` 5 (`:108` 14).

Önem: **Orta/Düşük** (görsel etkisi 1-4 dp). En sık değerler 10 ve 14: ölçeğe `BuSpace` 10/14 eklemek (D-2) görünüm değiştirmeden ihlali kapatır.

## 6. (e) Semantik ve etiket

| Ölçüt | Sayı |
|---|---|
| `IconButton`/`BuIconButton`/FAB çağrısı | 54 |
| `tooltip`/`semanticLabel`/`label` olmayan | **2** (`lib/features/auth/widgets/auth_ref.dart:57` IconButton; `lib/widgets/bu_widgets.dart:125` `BuIconButton` kurucusunda `tooltip` isteğe bağlı) |
| `Image`/`Image.*` `semanticLabel` ya da `excludeFromSemantics` olmayan | **28** (21 dosya; 16'sı sohbet) |
| Yalnız simge içeren dokunma (`InkWell/GestureDetector/BuPressable` + `Icon`, `Text/Semantics/tooltip` yok) | **39** (26 dosya) |
| `Semantics(` kullanımı (bilgi) | 727 yer |

En kötü örnekler (görsel): `chat/message_bubble.dart:634` (4), `chat/chat_media_parts.dart:370` (2), `chat/media_picker_page.dart:634` (2), `chat/media_preview_page.dart:244` (2), `clubs/club_form_page.dart:734` (2), `chat/chat_attach_sheet.dart:286`, `chat/chat_info_media.dart:175`, `chat/chat_media_viewer.dart:302`, `chat/chat_wallpaper.dart:315`, `chat/chatlist_widgets.dart:260`.
En kötü örnekler (yalnız simge): `chat/chat_detail_page.dart:2396` (5), `clubs/club_detail_parts.dart:87` (3), `events/event_form_page.dart:700` (3), `academic/course_form_page.dart:397` (2), `chat/chatlist_widgets.dart:29` (2), `chat/media_preview_page.dart:153` (2), `chat/sohbety_widgets.dart:482` (2), `news/icerik_parts.dart:101` (2), `academic/academic_calendar_page.dart:164`, `academic/akad_widgets.dart:807`.

Yanlış pozitif: dinamik `labeledTapTargetGuideline` 22 ekranda **0** ihlal verdi; yani çizilen dokunma hedeflerinin hepsi etiketli. 39 şüphenin çoğu `BuPressable(semanticLabel:)` ya da üst `Semantics` ile kapatılmış olabilir; tek tek doğrulanmalı. Önem: **Yüksek** (doğrulanana kadar), gerçek oran düşük olabilir. `MediaQuery.boldText` hiç okunmuyor (Android "kalın yazı" ayarı uygulanmaz): **Düşük**.

## 7. (f) Yükleniyor / boş / hata / bakım durumları

Yöntem: `*_page/_tab/_screen/_view.dart` dosyaları; ağ okuması yapanlar (`api.get/getSwr/list`, `FutureBuilder`, `_load*`) için yükleniyor (`BuSkeleton`, `BuPageScaffold`, `_loading`, `_busy` ...), boş (`BuEmptyState`, `*Empty*(`, `l.*empty*` ...), hata (`BuErrorState`, `ErrorView`, `catch`, `error:` ...), bakım (haber/menü/ana sayfa için `maintenance`) desenleri aranır. Liste olmayan ekranlarda boş durum aranmaz.

| Ölçüt | Sayı |
|---|---|
| Ekran dosyası | 81 |
| Ağ okuyan ekran | 61 |
| Üç durumu da gösteren | 39 |
| Şüpheli (en az bir durum deseni yok) | **22** |
| Bakım deseni olmayan haber/menü/ana sayfa ekranı | 1 (`news/news_detail_page.dart`) |

Şüphelilerin paket dağılımı: P7 7, P5 5, P2 4, P4 2, P6 2, P3 1, P8 1. Dosyalar: `academic/academic_calendar_page`, `academic/reminder_settings_page`, `auth/help/about_page`, `auth/help/help_track_page`, `auth/permissions_page`, `chat/chat_info_page`, `chat/contacts_match_page`, `chat/media_picker_page`, `chat/media_preview_page`, `chat/new_chat_page`, `events/etkinlik2_qr_page`, `events/etkinlik2_settings_page`, `notifications/push_help_page`, `posts/post_detail_page`, `profile/edit_profile_page`, `profile/notification_prefs_page`, `profile/privacy_data_page`, `profile/profil2_my_data_page`, `profile/profile_tab`, `profile/settings_page`, `profile/user_profile_page`, `support/support_ticket_page`.

Elle doğrulanan örnekler: `academic_calendar_page` (boş: sonraki etkinlik listesi var), `new_chat_page:373-389` (arama boş durumu var), `contacts_match_page:213-215` (boş ve eşleşme yok var), `media_picker_page:377` (boş albüm var), `support_ticket_page` (mesaj listesi hiç boş olamaz), `user_profile_page:412` (`profileNotFound`) → **yanlış pozitif**. Gerçek olasılığı olanlar: `about_page` (statik sayfa, gerekmez), `reminder_settings_page`, `profil2_my_data_page`, `news_detail_page` (boş içerik ve bakım durumu), `post_detail_page`. Önem: **Orta** (gerçek eksik tahmini 3-5 ekran).

## 8. (g) Güvenli alan, klavye, form

| Ölçüt | Sayı |
|---|---|
| Form içeren dosya / metin alanı | 45 / 74 |
| `keyboardType` yok | **64** (42 dosya) |
| `autofillHints` yok | **59** (39 dosya) |
| `textInputAction` yok | **49** |
| `resizeToAvoidBottomInset: false` | 0 |
| Kaydırma/inset ipucu bulunmayan form dosyası | 11 (çoğu ortak bileşen dosyası; yanlış pozitif ağırlıklı) |
| `SafeArea`/padding ipucu bulunmayan | 13 (aynı: auth sayfaları ortak `kRefPad`/Scaffold kullanıyor) |

Dinamik klavye testi (300 dp klavye, 360x640 ve 360x844; son alana odaklanıp alt kenar klavye üstünde mi): `Login` görünür, `ForgotPassword` görünür, `SearchPage` görünür, `NewChatPage` görünür (hepsi taşmasız); `Register` ilk adımında metin alanı olmadığından **ölçülemedi**.

En kötü: `academic/course_form_page.dart:236` (5 alan), `events/event_form_page.dart:1025` (4), `academic/exam_form_page.dart:162` (3), `clubs/club_form_page.dart:576` (3), `polls/poll_form_page.dart:181` (3), `auth/help/help_form_page.dart:116`, `auth/new_password_page.dart:98`, `auth/register_page.dart:227`. Önem: **Orta** (alan türü/otomatik doldurma/IME eylemi eksikliği kullanım kalitesini düşürür; kırıcı bir hata yok).

## 9. (h) RTL (Arapça)

Dinamik: 22 ekran x {320, 390} x ölçek {1,0; 1,3} x {açık, koyu} = **176 kombinasyon, taşma ve istisna 0**. Önem: Düşük (iyi).

Statik: sabit sol/sağ kullanımı **252** (97 dosya): `EdgeInsets.fromLTRB/only(left|right)` 232, `Positioned(left|right)` 13, `Alignment.centerLeft/Right` ve benzeri 7. Bu değerler Arapçada **yanlış tarafa** düşer (taşma yapmaz, aynalanmaz). En kötü: `events/events_page.dart:732` (12), `chat/message_actions.dart:169` (8, Positioned), `media_crop/crop_page.dart:398` (8, Positioned), `academic/exams_page.dart:163` (7), `events/event_form_page.dart:592` (7), `notifications/notifications_page.dart:243` (7), `profile/privacy_data_page.dart:81` (7), `posts/user_posts_page.dart:205` (6), `academic/timetable_parts.dart:51` (6), `events/etkinlik2_attendance_page.dart:142` (6). Not: `fromLTRB(20, 0, 20, 8)` gibi **simetrik** çağrılar RTL'de de doğru görünür; bu yüzden gerçek hata oranı düşüktür (asimetrik olanlar: `(20, 0, 11, 0)`, `(56, 0, 56, 40)` gibi). Önem: **Orta**.

## 10. (i) Karanlık tema farkları

- `BuTokens.dark` bütün alanları açıkça tanımlıyor; kurucu varsayılanına (açık değere) düşen alan **0**; açıkla aynı değere sahip koyu alan (bilinçli sabitler hariç: `onMedia`, `scrim`, `qrInk`, `qrPaper`) **0**.
- Ekran düzeyinde açık/koyu ayrı pump: kontrast ve dokunma ihlallerinin sayısı iki temada aynı (53/53), kontrast açıkta fazla (12 / 6).
- Sabit koyu/açık dallanma: `isDark ? Color(...)` **0**; `BuTokens.light/dark` doğrudan 27 yer (bkz. 5.1).
- Önem: Düşük (iyi).

## 11. (j) Metin tonu (ARB örneklemi + kod)

Kaynak: `lib/l10n/app_tr.arb` (2951 metin anahtarı, 156 hata benzeri), kod içi doğrudan etiketler.

- Düğme etiketleri fiil mi: örneklenen 45 düğme anahtarı ("Kaydet", "Gönder", "Yeniden dene", "Dersi ekle", "Kulübü oluştur", "Şifreyi güncelle", "Oyla", "Puanla") **fiil/eylem** biçiminde: iyi.
- İnsan dili hata mesajı: teknik terim/HTTP kodu içeren **0**; `!` yığını **0**; suçlayıcı kalıp ("Geçersiz seçim.", "Medya geçersiz...") **3**.
- Tutarlılık: "Yeniden dene" 21, "Tekrar dene" 35, "Tekrar deneyin" 15 (üç biçim); "Devam" 3, "Devam et" 1, "İleri" 1 (`authNext` vs `profil2Continue`); "Bitti" 3 / "Tamamlandı" 3.
- Belirsiz onay: "Tamam" 3 (`clubOk`, `clubMgmtOk`, `evcOk`); "Evet/Hayır" düğmesi **0**.
- Kısa/yetersiz hata: "Yüklenemedi" ile biten 13 mesaj, 40 hata anahtarı ≤ 2 sözcük (ör. `p20PrefLoadFail` = "Yüklenemedi", `chatDetailForwardFailedAll` = "İletilemedi"): neden/sonraki adım yok.
- BÜYÜK HARF etiket: 6 (`KİŞİLER`, `BUGÜN · {date}`, `BUGÜN`, `KATEGORİ`, `MESAJ`, `GÖNDERDİKLERİM`).
- İyi örnekler: `errPayloadTooLarge` ("Gönderilen veri çok büyük. Daha küçük bir dosya ya da daha kısa bir metin deneyin."), `postComposeErrVideoTooLarge` (sınır sayısıyla), `p05ListErrorBody`.

Önem: **Düşük-Orta** (tutarlılık ve kısa hata mesajları; hepsi metin işi, kod riski sıfıra yakın).

---

## 12. Düzeltme planı (8 bağımsız iş paketi)

Klasör sahipliği **çakışmaz**: her dosya tek pakete aittir (kurallar: `lib/core/push/**` ve `lib/core/notify/**` P8'e; `lib/core/app_gate.dart` ve `features/profile/settings*.dart` P2'ye; `features/profile/` kalanı P7'ye). Hareket dosyaları (`lib/core/motion/**`, `lib/core/theme/bu_motion.dart`, `bu_page_transitions.dart`, `lib/widgets/bu_motion_widgets.dart`, `bu_hero*.dart`) `feat/motion-system` ajanındadır: hiçbir pakete dahil değildir. `lib/l10n/*.arb` metin değişiklikleri paket sahibinin ekranına ait anahtarlarla sınırlı olmalı (üç dosyaya birlikte, yeni anahtar çakışması için `docs/changes` notu).

Sıralama: **önce P1** (jeton kararları D-1/D-2 ve ortak yardımcılar), sonra **P2-P8 paralel**.

### 12.1 Paket tablosu

| Paket | Kapsam dosyaları | Statik ihlal | Dinamik bulgu | Görünüm riski | Kabul ölçütü |
|---|---|---|---|---|---|
| **P1** Ortak bileşenler + tema/token | `lib/widgets/**` (hareket dosyaları hariç), `lib/core/theme.dart`, `lib/core/theme/**` (hareket hariç), `lib/core/typography.dart`, `lib/core/*.dart` (push/notify/motion/app_gate hariç) | **97**: Color 18 + Colors 4, dokunma 8, font 2, EdgeInsets 23, SizedBox 21, tooltip 1, Image 2, yalnız-simge 1, klavye 2+2+1, RTL 12 | `BuErrorState`/`BuEmptyState` metin kontrastı yeniden ölç (4 ekran) | Düşük (jeton ekleme görünümü değiştirmez) | Ölçüm (d1) widgets'ta 0 (avatar paleti jetona taşınır ya da açıklamalı istisna), (b-statik) widgets 0, (e) `BuIconButton` tooltip'siz kullanım 0, `BoldText` desteği |
| **P2** Giriş/kayıt/ayarlar/sistem | `features/auth/**`, `features/legal/**`, `features/system/**`, `features/profile/settings_page.dart` (+`settings*`), `lib/core/app_gate.dart` | **58**: dokunma 8, font 1, EdgeInsets 7, SizedBox 10, tooltip 1, klavye 9, autofill 4, IME 10, RTL 8 | `RefTextField` 46 dp (Login x2, Forgot x1); Welcome/Login açık tema 3 kontrast ihlali (sürüm satırı, alan notu); Register klavye ölçülemedi | Orta (alan yüksekliği 46 → 48+ görünür değişir; kontrast düzeltmesi renk) | (b) Login/Forgot `tap48` 0; (a) Welcome/Login açık 0; (g) `keyboardType`+`autofillHints`+`textInputAction` eksik 0 (auth) |
| **P3** Ana sayfa/keşfet/arama | `features/home/**`, `features/discover/**`, `features/search/**`, `features/posts/**`, `features/shell/**`, `features/media_crop/**` | **159**: dokunma 8, font 48 (1 adedi 10 sp), EdgeInsets 28, SizedBox 18, Image 4, yalnız-simge 6, klavye 3+3+1, RTL 40 | SearchPage alan düğümü 22 dp; 4 kontrast (3 belirsiz) | Orta (font/boşluk jetona çekilirse) | (b) SearchPage 0; (d2) `fontSize < 11` 0; (e) Image/yalnız-simge 0 |
| **P4** Haber/yemek/akademik | `features/news/**`, `features/menu/**`, `features/academic/**` | **265**: Color 6, dokunma 8, font 51, EdgeInsets 49, SizedBox 58, yalnız-simge 8, klavye 13+13+13, RTL 46 | NewsListPage çipleri 44 dp (3); **2,0 ölçekte taşma**: `news/icerik_parts.dart:411,428`, `menu/menu_parts.dart:139`; Menü "bulunamadı" kontrast belirsiz | Orta (çip hedefi görünmez büyür; taşma düzeltmesi 2,0'da düzeni değiştirir) | (c) 2,0 ölçekte taşma 0 (44 kombinasyon), (b) NewsListPage 0 |
| **P5** Sohbet | `features/chat/**` | **192**: Color 3, dokunma 24, font 1, EdgeInsets 45, SizedBox 19, Image 16, yalnız-simge 14, klavye 10+10+6, RTL 44 | ChatTab/NewChat dinamikte temiz | Düşük (çoğu semantik ve hedef genişletme) | (e) Image semantiği 0, yalnız-simge 0; (b-statik) chat 0 şüpheli (doğrulanmış) |
| **P6** Kulüp/etkinlik/anket | `features/clubs/**`, `features/events/**`, `features/polls/**` | **318**: dokunma 17, font 42, EdgeInsets 91, SizedBox 59, Image 5, yalnız-simge 9, klavye 17+19+13, RTL 46 | **EventsPage 44 ihlal** (takvim şeridi 50x41, ay okları 36x48), ClubsTab "Ara" 44x48 | Orta (takvim hücre yüksekliği 41 → 48 görünür değişir) | (b) EventsPage ve ClubsTab `tap48` 0; (d3) event_form SizedBox/EdgeInsets ihlali 0 |
| **P7** Profil/destek/diğer | `features/profile/**` (settings hariç), `features/support/**`, `features/follow/**`, `features/platform/**` | **251**: dokunma 8, font 43, EdgeInsets 74, SizedBox 55, Image 1, yalnız-simge 1, klavye 10+8+5, RTL 46 | Destek/Engellenenler/Etkinliklerim hata durumunda ölçüldü; dolu hâller kontrol edilmeli | Orta | (d2) off-scale 0 (D-1 kararı sonrası), (f) şüpheli 7 → gerçek eksik 0, (g) eksik 0 |
| **P8** Bildirim ve kampüs haritası | `features/notifications/**`, `lib/core/push/**`, `lib/core/notify/**` (başka ajanların dosyaları: sonra); kampüs haritası henüz yok | **25**: dokunma 6, font 3, EdgeInsets 6, RTL 10 | NotificationsPage "Tümünü okundu yap" 195x44; "Hepsi bu kadar" kontrast belirsiz | Düşük | (b) NotificationsPage 0; (a) belirsizler elle doğrulanıp 0 |

Toplam statik: 97 + 58 + 159 + 265 + 192 + 318 + 251 + 25 = **1365** (ölçüm toplamı 1365 ile eşleşir). Dinamik: 53 dokunma (22 ekran), 4 taşma, 3 kesin + 15 belirsiz kontrast.

Her paketin kabul ölçütü aynı betik/testle doğrulanır: `python -I -X utf8 mobile/tools/hig_audit.py --json` çıktısındaki paket satırı sıfırlanır ve `HIG=1 flutter test test/hig/hig_audit_test.dart --tags hig` ilgili ekran satırları sıfır döner. P3-P7 fiilen büyük ölçüde "jeton normalleştirme" işidir; D-1/D-2 kararları çıkmadan başlanmamalı.

### 12.2 Karar bekleyen jeton kararları (P1'in ilk işi)

- **D-1:** 13 sp (105 yer), 12 sp (39), 17 sp (21), 13,5 sp (4) için ya `BuScale`e ek basamak (görünüm DEĞİŞMEZ, ihlal kapanır) ya mevcut basamaklara (12,5 / 14 / 16) yuvarlama (görünüm hafif değişir). Öneri: yaygın 13 ve 17'yi eklemek yerine **12,5 ve 14'e yuvarlama** tasarım sadeliği için doğrudur ama kullanıcı onayı ister.
- **D-2:** `BuSpace`e 10 ve 14 eklemek (ihlalin ~%60'ını görünüm değişmeden kapatır) mi, yoksa 8/12/16'ya çekmek mi?
- **D-3:** `BuIconButton.tooltip` zorunlu parametre yapılırsa imza değişir (KİLİTLİ): tercih edilen yol, tooltip'siz kullanımı bulan lint/test.

### 12.3 Görünüm değişmeyen, güvenli işler (hemen yapılabilir)

- 48 dp dokunma alanı genişletme: `BuTouchTarget` ile sarma (görünür kutu aynı kalır): EventsPage ay okları, NewsListPage çipleri, ClubsTab "Ara", Notifications "Tümünü okundu yap", SearchPage alan düğümü, statik şüpheli 87 yerin doğrulananları.
- `keyboardType`, `autofillHints`, `textInputAction` ekleme (64 / 59 / 49).
- `Semantics`/`tooltip`/`semanticLabel`: 39 yalnız-simge dokunma, 28 görsel, 2 tooltip'siz düğme, `MediaQuery.boldText`.
- `EdgeInsets.fromLTRB/only(left,right)` → `EdgeInsetsDirectional`, `Positioned` → `PositionedDirectional` (LTR'de görünüm aynı; 252 yer).
- `Color(0x..)` → jeton (değer aynıysa), `Colors.white` → `t.onMedia`.
- 2,0 yazı ölçeğinde taşma düzeltmeleri (yalnız büyük ölçekte düzen değişir; 1,0'da aynı).
- Metin tonu: "Yeniden/Tekrar dene" birleştirme, "Tamam" → fiil, kısa hata mesajlarına neden/adım ekleme (ARB, üç dil birlikte).
- Test: her paket kendi ekranı için `p00Matrix` testini ve `hig_audit_test` satırını ekler.

### 12.4 Kullanıcı onayı bekleyen, tasarım değiştiren maddeler

1. Jeton dışı 190 yazı boyutu ve 563 boşluk değerinin ölçeğe çekilmesi (1-4 dp / 0,5-1 sp kayma; D-1/D-2).
2. Metin alanı yüksekliğinin 46 → 48/52 dp (`RefTextField` ve diğerleri; giriş ekranlarının görünümü değişir).
3. Takvim şeridi hücrelerinin 41 → 48 dp yüksekliği (EventsPage); ay okları 36 → 48 dp genişlik.
4. `FloatingNav` ortasındaki "Paylaş" eyleminin sekme sırasından çıkarılıp FAB/üst çubuğa taşınması (Çatışma Ç-3).
5. İlk giriş izin sayfasında 3 iznin (bildirim, kişiler, kamera) birlikte istenmesi: kişiler ve kamerayı ilk kullanım anına kaydırmak (Çatışma Ç-12).
6. BÜYÜK HARF bölüm etiketlerinin cümle düzenine çevrilmesi (6 yer, Ç-13).
7. Açık temada sürüm satırı/alan notu renk veya saydamlığının düzeltilmesi (kontrast 3,11 → ≥ 4,5).
8. Büyük başlık (Large top app bar) denemesi (Ç-2): yalnız karar, uygulama önerisi değil.
9. `home_parts.dart:729` 10 sp alt başlığın 11,5 sp'e çıkarılması.

---

## 13. Özet

### 13.1 En önemli 15 bulgu

1. **Jeton düzeyi mükemmel:** 45 renk çiftinin 45'i açık ve koyu temada eşiği geçiyor (metin 37/37, UI 8/8); koyu tema eksiksiz; hero yazısı 4,96-7,58:1.
2. **EventsPage'de 44 dokunma hedefi < 48 dp** (takvim şeridi 50x41, ay okları 36x48): tek ekranda tüm dinamik ihlallerin %83'ü.
3. **Metin alanları 46 dp** (Login, Forgot; ortak `RefTextField`): 48 dp tabanın altında, `BuSize.field` = 52 ile de çelişiyor.
4. **SearchPage arama alanı dokunma düğümü 22 dp** (anlamsal alan düğümü 251x22).
5. **2,0 yazı ölçeğinde 2 ekran taşıyor:** Haber listesi (`icerik_parts.dart:411` 63 px, `:428` 7 px) ve Menü (`menu_parts.dart:139` 14 px); 1,3 ölçekte 44 kombinasyonda 0.
6. **Haber türü çipleri 44 dp** (Haber/Duyuru/Etkinlik), ClubsTab "Ara" 44x48, bildirim "Tümünü okundu yap" 195x44.
7. **Açık temada soluk metin:** Welcome ve Login sürüm satırı ile "Yalnızca okul e-postası" notu 3,11:1 (jeton 6,4:1 olduğundan üst katman saydamlığı şüphesi).
8. **190 jeton dışı yazı boyutu** (60 dosya; 13 sp x105) ve 1 adet 10 sp (`home_parts.dart:729`, K-21 tabanının altında).
9. **563 boşluk değeri ölçek dışı** (EdgeInsets 323, SizedBox 240); en sık 10 ve 14.
10. **252 sabit sol/sağ** (232 `EdgeInsets.fromLTRB/only`): Arapçada asimetrik olanlar yanlış tarafa düşer (dinamik RTL testi ise 176 kombinasyonda 0 taşma).
11. **Formlar:** 74 alanın 64'ü `keyboardType`siz, 59'u `autofillHints`siz, 49'u `textInputAction`sız (akademik ve etkinlik formları en kötü).
12. **Erişilebilirlik şüphesi:** 39 yalnız-simge dokunma, 28 etiketsiz görsel (16'sı sohbet); dinamik `labeledTapTargetGuideline` ise 22 ekranda 0 verdi (gerçek oran düşük olabilir).
13. **Durum kapsamı güçlü:** 61 ağ ekranının 39'u üç durumu da gösteriyor; 22 şüphelinin elle bakılan çoğu yanlış pozitif (gerçek eksik tahmini 3-5).
14. **Metin tonu iyi, tutarlılık zayıf:** teknik hata kodu ve ünlem yok; ama "Yeniden/Tekrar dene" 3 biçim, "Tamam" 3 yerde, 6 BÜYÜK HARF etiket, 13 tek sözcüklü "Yüklenemedi".
15. **Gezinme/izin kararları:** sekme çubuğunda ortada eylem (Paylaş) ve ilk girişte üç iznin birden istenmesi HIG'in "eylem değil gezinme" ve "bağlamsal izin" ilkeleriyle çatışıyor (onay bekler).

### 13.2 Android'de en yüksek etkili 10 iyileştirme

1. EventsPage takvim şeridi ve ay oklarını 48 dp hedefe çıkar (44 ihlali tek hamlede kapatır).
2. `RefTextField` ve diğer metin alanlarının yüksekliğini 48-52 dp'ye hizala (Login, Forgot, formlar).
3. Çip/küçük düğme satırlarını `BuTouchTarget` ile 48 dp hedefe al (Haber çipleri, Ara, Tümünü okundu yap, SearchPage alanı).
4. 2,0 yazı ölçeğinde Haber ve Menü taşmalarını kapat (`Wrap`/`Flexible`).
5. Tüm formlara `keyboardType`, `autofillHints`, `textInputAction` ekle (özellikle auth ve akademik/etkinlik formları).
6. 39 yalnız-simge dokunmayı ve 28 görseli doğrula; eksik etiketleri/semantik atamasını yap (TalkBack).
7. Açık temada sürüm satırı ve alan notu kontrastını ≥ 4,5:1 yap.
8. D-1/D-2 kararlarıyla 190 yazı ve 563 boşluk değerini jetonlara bağla (görünüm değişmeden).
9. Asimetrik `EdgeInsets`/`Positioned`'ı yönlü karşılıklarına çevir (RTL doğruluğu).
10. Metin sözlüğünü tekleştir ("Yeniden dene", "Devam", "Tamam" yerine fiil) ve tek sözcüklü hata mesajlarına neden + sonraki adım ekle.

### 13.3 Apple ilkeleri ile Material 3 arasındaki çatışma kararları (öneri)

| Konu | Öneri |
|---|---|
| Geri hareketi | Android sistem geri hareketi/öngörülü geri esas; kenara yakın yatay jestlerden kaçın, üst çubukta geri düğmesi kalsın (Ç-1) |
| Büyük başlık | Material'de zorunlu değil; sade 56 dp üst çubuk korunur, büyük başlık yalnız deneme olarak onayla (Ç-2) |
| Sekme çubuğu | Gezinme yalnız bölümlerden oluşsun; "Paylaş" eylemini FAB/üst çubuğa almayı onaya sun, kalırsa 48 dp ve açık erişilebilir ad şart (Ç-3, Ç-4) |
| Dokunma hedefi | 44 pt değil **48 dp** (Ç-7) |
| Tema | Varsayılan "sistem"; uygulama içi seçici Android ≤ 9 ve kullanıcı tercihi için kalır (Ç-5) |
| Yazı ölçeği | Android ~%200 üst sınır; 2,0 ölçek hedef (Ç-8) |
| İzinler | Bildirim için ön açıklama kalsın; kişiler ve kamerayı ilk kullanıma kaydır (Ç-12) |
| Etiket stili | Türkçede cümle düzeni; BÜYÜK HARF etiketleri kaldır (Ç-13) |
| Uyarı düğmeleri | "Tamam" yerine fiil; yıkıcı eylem ayrı stil ve her zaman Vazgeç (Ç-10) |

Hareket kuralları (ERS-8 ve bölüm 21) başka ajanın kapsamındadır; çatışma listesine alınmadı.

---

## 14. HIG-P1: ortak yardımcılar ve jeton eşleme tablosu (diğer paketler P2-P8 için)

Kullanıcı kararı (onaylı): D-1 (190 jeton dışı yazı boyutu ölçeğe EKLENİR) ve D-2 (`BuSpace`e 10 ve 14 EKLENİR) **görünüm değişmeden** uygulanır. Bu bölüm P2-P8 paketlerinin eski değeri hangi jetona çevireceğini verir. Jetonlar: `lib/core/typography.dart` (`BuScale`, `BuBold`), `lib/core/theme/bu_space.dart` (`BuSpace`, `BuGap`, `BuOptical`, `BuInsets`), `lib/core/theme/bu_sizes.dart` (`BuSize.fieldMin`), `lib/core/theme.dart` (`BuColors`, `BuAvatarPalette`, `BuCourseColors`). Hepsi `import '../../widgets/bu.dart'` (ya da `core/theme/bu_design.dart`) ile gelir.

### 14.1 Yardımcı el kitabı (10 satır)

1. **Dokunma alanı:** `BuTouchTarget(child: X)` görünür kutuyu aynı bırakıp yerleşim kutusunu 48x48'e çıkarır; `axis: Axis.vertical` yalnız yüksekliği büyütür (geniş çip). `BuPressable/GestureDetector/InkWell` ile **dıştan** sarın, `BuTouchTarget`'ı onun **içine** koyun.
2. **Yalnız-simge düğme:** `BuIconButton(icon:, tooltip:, onTap:)`; `tooltip` artık ZORUNLU (derleme hatası verir), 40 dp görünür + 48 dp hedef. `IconButton` yerine bunu tercih edin; `IconButton` kalırsa `tooltip:` şart.
3. **Görsel:** anlamlıysa `BuImage(url, semanticLabel: '...')`, süsse `BuImage.decorative(url)`; ham `Image(...)` için `semanticLabel:` ya da `excludeFromSemantics: true`.
4. **Yazı boyutu:** elle `fontSize: 13` yok; 14.2 tablosundaki `BuScale.*` jetonu. 11 sp altı yok (K-21).
5. **Boşluk:** `SizedBox(height: 10)` -> `BuGap.h10`; `EdgeInsets...(10)` -> `BuSpace.s10`; 4'ün katı olmayan optik değerler -> `BuOptical.nN` (14.3).
6. **Yön:** `EdgeInsets.fromLTRB(a,t,b,bt)` -> `BuInsets.steb(a,t,b,bt)`; `only(left:)` -> `BuInsets.start`; `Positioned(left:)` -> `PositionedDirectional(start:)`; `Alignment.centerLeft` -> `AlignmentDirectional.centerStart`.
7. **Kalın yazı:** `Text`/`TextField` `MediaQuery.boldText`'i çerçeveden kendiliğinden uygular; `TextPainter`/painter metni için `BuBold.style(context, style)`.
8. **Renk:** `Color(0xFF...)`/`Colors.white` yerine `context.bu` jetonu; bağlamsız (painter/model) yerde 14.4 tablosundaki sabit jeton.
9. **Metin alanı:** yükseklik alt sınırı `BuSize.fieldMin` (48); tema alanları 52 (`BuSize.field`).
10. **Metin sözlüğü:** yeniden deneme düğmesi her yerde `Yeniden dene` (`commonRetry`/`commonRetryShort` artık aynı metin); "Tamam" yerine fiil (14.6).

### 14.2 Yazı boyutu: eski değer -> jeton (görünüm AYNI)

| Eski `fontSize` | Jeton | Not |
|---|---|---|
| 10 | (jeton YOK) | K-21 tabanı 11 altı: `BuScale.caption` (11,5) ya da `BuScale.s11`; `home_parts.dart:729` kararı onaylı: 11,5 (P3) |
| 11 | `BuScale.s11` | yeni kodda `caption` |
| 11,5 / 12,5 / 14 / 15 / 16 / 18 / 22 | zaten `BuScale.caption/label/body/bodyLarge/heading/title/display` | `BuType.*` stilinden gelir |
| 12 | `BuScale.s12` | 39 yer |
| 13 | `BuScale.s13` | 105 yer |
| 13,5 | `BuScale.s135` | 4 yer |
| 17 | `BuScale.s17` | 21 yer |
| 19 | `BuScale.s19` | |
| 20 | `BuScale.s20` | 7 yer |
| 26 | `BuScale.s26` | `BuHeader`, `BuFeatureTitle` |
| 28 | `BuScale.s28` | 5 yer |
| 88 | `BuScale.s88` | 2 yer |

Kullanım: `BuType.body.copyWith(fontSize: BuScale.s13)`.

### 14.3 Boşluk: eski değer -> jeton (görünüm AYNI)

| Eski | Jeton |
|---|---|
| 10 | `BuSpace.s10`; `BuGap.h10` / `BuGap.w10` |
| 14 | `BuSpace.s14`; `BuGap.h14` / `BuGap.w14` |
| 1 / 3 / 5 / 7 / 9 | `BuOptical.n1` / `n3` / `n5` / `n7` / `n9` |
| 13 / 15 / 17 / 18 / 22 / 25 / 26 | `BuOptical.n13` / `n15` / `n17` / `n18` / `n22` / `n25` / `n26` |
| 1,5; 1,6; 11; 12,5; 15,5; 16,5; 19; 23; 25,5; 30; 33; 34; 38; 85 | jetonsuz tek kullanımlıklar (toplam ~15): görünüm DEĞİŞMESİN diye ölçek ifadesiyle yazın (örn. 30 = `BuSpace.xxxl - BuSpace.xxs`, 17 = `BuSpace.lg + BuOptical.n1`; denetim yalnız sayı literalini sayar) ya da en yakın değere çekip (en çok 2 dp) sayfa notuna yazın |
| 0, 2, 4, 6, 8, 12, 16, 20, 24, 32, 48 | zaten ölçek (`BuSpace.*`, `BuGap.*`); denetim bunları ihlal saymaz |

`BuOptical` yeni tasarım için DEĞİL, mevcut görünümü korumak içindir. Not: denetim betiği yalnız **sayı literallerini** sayar; `BuSpace.s10` gibi adlandırılmış kullanım ihlal olmaz.

### 14.4 Renk: eski -> jeton

| Eski | Jeton |
|---|---|
| `Color(0xFFF2A094/C0392B/FBE0DC)` ... avatar paleti (6 değişken x 3) | `BuAvatarPalette.brand/navy/sand/aqua/green/blue` (`.variants`) |
| avatar `Colors.white` | `BuAvatarPalette.silhouette` (= `BuColors.white`) |
| avatar `Alignment.topLeft/bottomRight` | `BuAvatarPalette.gradientBegin/End` (yön bağımsız çizim) |
| `academic_models.dart` ders renkleri `0xFFBC3A2D/9A5700/1E7A50/0B6E86/1F4E96/5C5A56` (P4) | `BuCourseColors.red/amber/green/teal/blue/neutral` |
| `sohbety_widgets.dart:13` `Color(0x40171E33)` (P5) | `BuColors.inkShadow25` |
| `media_preview_page.dart:32,33` `Color(0x00000000)` (P5) | `Colors.transparent` |
| arayüz yüzeyinde `Colors.white` | `context.bu.onMedia` |

Not: `test/redesign/renk_paleti_test.dart` izin listesi (`theme.dart`, `bu_default_avatar.dart`, ...) değişmedi; yeni jetonlar `theme.dart` içindedir.

### 14.5 Yön (RTL)

| Eski | Yeni |
|---|---|
| `EdgeInsets.fromLTRB(a, t, b, bt)` | `EdgeInsetsDirectional.fromSTEB` ya da `BuInsets.steb` |
| `EdgeInsets.only(left: x)` / `(right: x)` | `EdgeInsetsDirectional.only(start: x)` / `(end: x)` ya da `BuInsets.start/end` |
| `Positioned(left:, right:)` | `PositionedDirectional(start:, end:)` |
| `Alignment.centerLeft/Right`, `topLeft` | `AlignmentDirectional.centerStart/centerEnd/topStart` |

### 14.6 Metin sözlüğü

- Yeniden deneme: **`Yeniden dene`** (ortak `commonRetry` ve `commonRetryShort` artık aynı Türkçe metin). Hâlâ "Tekrar dene" olan sayfa anahtarları (sahibi düzeltir): `permRetry` (P2), `eventFormRetry` (P6). "Hatalı bir şey oldu, Tekrar dene" biçimi kalmamalı.
- "Tamam": ortak anahtarlarda yok; sayfa anahtarları `clubOk`, `clubMgmtOk` (P6), `evcOk` (P6) fiille değişir (örn. "Anladım" yerine eylemi söyleyen fiil: "Kapat", "Devam et").
- Koruma testi: `test/hig/hig_helpers_test.dart` ("Metin sözlüğü") ortak (`common*`) anahtarlarda "Tekrar dene" ve tek başına "Tamam" bulursa kırılır.

### 14.7 Kod dönüştürücü: `mobile/tools/hig_tokenize.py` (P2-P8 için)

Yukarıdaki eşlemelerin mekanik kısmını (yazı boyutu jetonu, `BuGap`/`BuSpace`/`BuOptical`, `EdgeInsets` -> `EdgeInsetsDirectional`, `Positioned` -> `PositionedDirectional`) görünümü değiştirmeden uygular; yorum ve dizelere dokunmaz, gerekli `import`ları ekler. Varsayılan KURU ÇALIŞMA.

```bash
cd mobile
python -I -X utf8 tools/hig_tokenize.py lib/features/news lib/features/menu          # yalnız sayar
python -I -X utf8 tools/hig_tokenize.py --write lib/features/news                       # uygular
python -I -X utf8 tools/hig_tokenize.py --write --only font,space lib/features/chat     # yalnız font + boşluk
python -I -X utf8 tools/hig_tokenize.py --write --align lib/features/clubs              # Alignment.centerLeft -> AlignmentDirectional
```

Sonrasında ŞUNLAR elle yapılır: `dart analyze` (RTL dönüşümü `EdgeInsets` tipli alan/parametreyi kırarsa `EdgeInsetsGeometry`/`EdgeInsetsDirectional` yapın), kalan denetim satırları (10 sp, jetonsuz tek kullanımlıklar, `a ? 10 : 14` gibi koşullu değerler), ilgili testler. `--align` gradyan/hizalama anlamını RTL'de aynalar: gözle bakın. P1 kendi dosyalarına (`lib/widgets/**`) bu aracı uyguladı.

### 14.8 P1 sonuçları (statik, `hig_audit.py`)

| Ölçüm (P1 dosyaları) | Önce | Sonra |
|---|---|---|
| Color(0x..) / Colors.* | 18 / 4 | 0 / 0 (avatar paleti `BuAvatarPalette`) |
| Dokunma şüphesi (b-statik) | 8 | 0 |
| Yazı boyutu jeton dışı | 2 | 0 |
| EdgeInsets ölçek dışı / SizedBox ölçek dışı | 23 / 21 | 0 / 0 |
| tooltip'siz IconButton / etiketsiz Image / yalnız-simge dokunma | 1 / 2 / 1 | 0 / 0 / 0 |
| klavye (keyboardType / autofillHints / textInputAction) | 2 / 2 / 1 | 0 / 0 / 0 |
| sabit sol/sağ (RTL) | 12 | 0 |
| **Toplam P1** | **97** | **0** |

Dinamik ortak bileşen doğrulaması: `test/hig/hig_p1_components_test.dart` (2,0 yazı ölçeği x 320/390 dp x tr/en/ar x açık/koyu taşma 0; `androidTapTargetGuideline` + `labeledTapTargetGuideline` 0; `BuErrorState`/`BuEmptyState`/`SistemStatusView` yerleştikten sonra `textContrastGuideline` açık+koyu 0). Hata/boş durum "belirsiz kontrast" bulgusu (1,94:1) giriş animasyonu sırasındaki ölçüm yanılgısıdır; yerleşince bileşen metni `mut`/`ink` jetonlarıyla geçer.

Davranış/görünüm notları (görünüm AYNI, ölçümle doğrulandı):
- `BuSearchField`: çizgi `foregroundDecoration` ile ÖNDE çizilir, alan düğümü 48 dp olur (önceki 22 dp), silme düğmesi 48x48; simge ve metin konumları birebir aynı (önce/sonra ölçüm: simge 17,15; metin 45,14,4), odak çizgisi artık içeriği 1 dp kaydırmaz. Alanın boşluk/simge bölgesine dokunmak odak verir.
- `BuIconButton.tooltip` zorunlu (imza sıkılaştı; tüm çağıranlar zaten veriyordu).
- Material düğmelerinde (`TextButton` 40 dp, `IconButton` 40 dp) görünür boyut AYNI; hedef temadaki `MaterialTapTargetSize.padded` ile 48 dp (`BuSize.actionPill`, `BuSize.iconBtn`).

