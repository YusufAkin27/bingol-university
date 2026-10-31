# BIREBIR_HOME: Ana Sayfa + özelleştirme (Stitch v3, kategori 1)

Referans (kanun): `C:\bu_design\stitch\v3_home\1_ana_sayfa\*.png`, şartname `C:\bu_design\stitch\v3_home\SARTNAME.md` bölüm 1, tam ölçülü HTML `_kaynak_html\B_ana_sayfa_ozellestirme\...\code.html` (Tailwind, px = dp).
Uygulama: `mobile/lib/features/home/` (`home_tab.dart`, `home_parts.dart`, `home_layout.dart`, `home_layout_sheet.dart`). Karşılaştırma görüntüleri (aynı içerik/sahte veri, 390 dp): `C:\bu_qa\shots\tasarim\p3\home\birebir\` (`01_ana_sayfa`, `02_iskelet`, `03_tum_gizli`, `05_duzenle`, `07_secici`; `_koyu`; `sonra320\` 320 dp x1.3). Üretim: `test/redesign/p3_home_shots_test.dart` (`P3H_OUT=... P3H_W=390 P3H_LANG=tr P3H_MODES=light,dark,x13`).

## 01 Ana Sayfa (390 dp)

| Öğe | Referans (HTML) | Uygulama | Fark |
|---|---|---|---|
| Yatay kenar | `px-5` = 20 | 20 | 0 |
| Başlık üst/alt | `pt-8` 32 / `pb-4` 16 | durum çubuğu + 12 / 16 | üst boşluk gerçek cihazda durum çubuğu üstüne eklenir (referans çerçevede durum çubuğu yok) |
| Selamlama | 13/400 `muted`; "Merhaba, Ad" 30/700 ink, `leading-tight`, en çok 2 satır | 13/400 `mut`; 30/700 `ink`, satır 1.15, en çok 2 satır | 0 |
| Kalem + zil | 40x40 daire, beyaz, 1 dp `bd`, aralık 8, simge 18 | `BuIconButton` 40x40, aralık 8, simge 20 (`size*.5`) | simge +2 dp (ortak bileşen), dokunma alanı 48 |
| Zil noktası | 8 dp `pr`, 2 dp beyaz halka | `BuIconButton.badge` 9 dp, 2 dp halka | +1 dp (ortak bileşen) |
| Arama | h 48, köşe 16, `px-4`, simge 16, boşluk 12, metin muted | 48 (`BuSize.search`), 16, 16, 16, 12, 15 sp muted | 0 |
| Bölüm başlığı | 17/600 ink, `mb-2.5` 10; bölümler arası `gap-6` 24 | 17/600 ink; satır 48 dp (metin ortada) + bölüm üst boşluğu 12 | metin-içerik arası 12 (ref. 10): 48 dp dokunma hedefi için satır 48 |
| Bağlantı | 13/500 (`Menüyü aç` `pr`, `Tümü` muted); metin sağ kenara yaslı | 13/500, sağ kenara yaslı, sol tarafa taşan 48 dp dokunma alanı | 0 |
| Bugün yüzeyi | beyaz, 1 dp `bd`, köşe 16, satırlar `py-3 px-4` 14 sp, çizgi `bd`; etiket muted, değer 14/500 (yemek 13.5) sağa hizalı | aynı; etiket sarmaz (en çok %45 genişlik, sonra kırpar), değer en çok 2 satır, satır >= 48 | satır 48 (ref. ~44) |
| Hızlı erişim karosu | 5 sütun, `gap-2` 8, `py-3 px-1`, köşe 16, 1 dp `bd`, ikon 20 ink, etiket 12/500 | 5 sütun, aralık **6**, `py 12 px 2`, 16, 1 dp, 20 ink, 12/500 (11.5'e kadar küçülür) | aralık -2 dp: "Etkinlikler" tek satıra sığsın diye; sığmazsa 3+2 |
| Günün menüsü | `p-4`; satır aralığı 10; ad 14/400, kcal 12 muted; çizgi `pb-3`/`pt-3`; toplam 13 | aynı; kcal yoksa "–", hiç kcal yoksa sütun ve toplam gizli | 0 |
| Bugünkü dersler | saat sütunu `w-12` 14/600; ad 15/500; alt 13 muted; `p-4`; başlık sağda gün adı 13 muted | aynı; ders yoksa bölüm hiç çizilmez | 0 |
| Haber kartı | 240 genişlik, `p-3`, görsel `h-28` 112 köşe 10, başlık 14/500 (2 satır), tarih 12 `mt-3` | aynı (şerit yüksekliği kart ölçüsüne göre hesaplanır, yazı ölçeği <= 1.5) | 0 |
| Yaklaşan etkinlik | satır `p-4`; ay 11/700 büyük harf + gün 19/700 `w-12`; başlık 15/500; alt 13 muted | aynı | liste yerine tek satır: yalnız `GET /events/featured` var, yeni uç yok |
| Duyurular | satır `12/16`, başlık 15/400 (2 satır), tarih 12 muted, çizgiler | aynı (<= 3 satır) | 0 |
| Alt gezinme | yüzen hap | mevcut `FloatingNav` (kabuk) | 0 |

Renkler: yalnız `context.bu` (bg `#F7F5F2`, sf `#FFFFFF`, ink `#171E33`, mut `#6B665F`, bd `#E4E0DA`, pr `#C0392B`; koyu RENK-1 koyu sütunu). Stitch'in lavanta zemini/koyu kırmızısı uygulanmadı (UYARI).

## 02-04 Durumlar
- İskelet: yeni yerleşimle birebir (başlık, arama, Bugün, hızlı erişim, menü, haber), tek paylaşılan parıltı, metin/spinner yok; `BuSwapIn` ile içeriğe.
- Boş: menü yoksa başlık + soluk "Bugün için liste yok."; haber/duyuru "Henüz haber yok." / "Henüz duyuru yok."; etkinlik yoksa tek satır yüzey "Yaklaşan etkinlik yok" + `pr` bağlantı "Etkinliklere göz at"; ders/sınav yoksa satır/bölüm gizli.
- Hata/bayat: mevcut uyarı bantları `warnSoft`; etkinlik hatası tek satır + `pr` "Tekrar dene". **Uygulanmadı:** "Çevrimdışısınız. Son kaydedilen içerik gösteriliyor." satırı: uygulamada çevrimdışı durumunu veren tek bir kaynak yok (yeni istek/izleyici eklemek kapsam dışı); bayat veri bantları (bakım, kaynak ulaşılamıyor) çalışır.

## 05 Ana sayfayı düzenle (tam sayfa, `HomeLayoutPage`)
| Öğe | Referans | Uygulama | Fark |
|---|---|---|---|
| Başlık | geri daire 40 + 20/700 başlık + `Bitti` 15/600 `pr` | `BuHeader` (başlık ortak bileşen: display 24) + `Bitti` 15/600 `pr` | başlık +4 sp (ortak başlık bileşeni; sistem genelinde aynı) |
| Açıklama | 13.5 muted | 13.5 muted | 0 |
| Yüzey | beyaz, 1 dp `bd`, köşe 16, 6 satır, çizgiler | aynı | 0 |
| Satır | `p-4`, 60 dp; tutamaç 16, ad 15/500, ok düğmeleri 28 çerçevesiz soluk 14 simge, anahtar 44x24 | min 60; tutamaç 16 (40x48 dokunma), ad 15/500, çerçevesiz soluk 16 ok (44x48 dokunma), anahtar .85 ölçek (~44x27) | dokunma alanları 48 dp için büyük (görünüm aynı); anahtar +3 dp |
| Hızlı erişim satırı | altında 12 muted "Kısayolları seç" + ok | aynı | 0 |
| Gizli satır | ad/simge %45, anahtar canlı | aynı | 0 |
| Varsayılana dön | ortalı 15 muted, onaysız | aynı | 0 |
| Kalıcılık | SharedPreferences | güvenli depo `home_layout` (kullanıcı kimlikli; çıkışta `registerUserDataCleaners` ile silinir, KVKK) | `shared_preferences` bağımlılığı yok; projedeki kullanıcıya özel depo kalıbı |

## 06 Sürükleme
Tutamaç 48x48'den sürükleme; sürüklenen satır: 1.02 ölçek, 1 dp `pr` %40 çerçeve, tek gölge (blur 16, y 4, %12); diğer satırlar %55 opaklık; bırakınca `selectionClick`. **Uygulanmadı:** kesik çizgili bırakma yuvası ("<Bölüm> taşınıyor"): `ReorderableListView` bırakma yerini çizmeye izin vermiyor (özel sürükleme motoru gerekir); referans notunda metin opsiyonel, ekleme çizgisi zaten çizilmiyor.

## 07 Hızlı erişim seçici (alt sayfa)
Başlık 20/700 + `soft` hap "5/5" (13/600 `pr`) aynı satırda; açıklama 13 muted; "SEÇİLEN KISAYOLLAR (SIRALAMA)" 12/600 muted büyük harf (harf aralığı .6); seçili liste `bg` zeminli yüzey (tutamaç, sıra no 13/700, ad 14/500, x); "TÜM KISAYOLLAR" onay kutulu 11 satır (20x20 `pr` dolu, köşe 6, beyaz tik); 5/5 iken seçilmeyenler %40 ve dokunulamaz; sabit birincil "Bitti" 48 dp. Seçici etiketi: "Ders programı" (karoda "Program"). Satır yüksekliği referans 40/44 dp; uygulama >= 48 (dokunma hedefi kuralı).

## 08 Tüm bölümler gizli
Başlık + arama + (veri varsa) Bugün yüzeyi kalır; altında "Ana sayfan boş" 18/600, "Gösterilecek bir bölüm seçmediniz." muted, `pr` dolu "Bölüm ekle", metin düğmesi "Varsayılana dön"; illüstrasyon yok.

## Davranış / ağ (yeni uç yok)
- Gizli bölümün verisi istenmez (etkinlik, haber, duyuru); "Bugün" yüzeyi gizlenemez, bu yüzden `GET /menu/today`, `GET /timetable`, `GET /timetable/exams/upcoming` hep istenir (ders/sınav ilk boyamadan sonra arka planda, hata sessiz).
- Ana sayfadaki "Katıl" düğmesi, katılımcı avatarları ve menü fotoğrafı kaldırıldı (katılma etkinlik detayında, menü fotoğrafı Yemek sayfasında).
- Kısayol havuzu hedefleri mevcut ekranlar (Haberler, Yemek, Etkinlikler, Anketler, Program, Kulüpler/Sohbet sekmeleri, Destek, Arama, Bildirimler, Favoriler).
- Animasyon: bölüm gizle/ekle `AnimatedSize` + fade 220 ms (animasyonları azalt: anında); ilk 4 blok `BuStaggerItem`; iskelet -> içerik `BuSwapIn`.

## Testler
`test/home_layout_test.dart` (model, depo, çıkışta silinme, kullanıcı değişimi, bozuk kayıt, gizli bölüm istek atmaz, sıralama, gizleme, varsayılana dön, kısayol seçici, reduce-motion, a11y düğmeleri, 320 dp x1.3 / tr-en-ar / açık-koyu taşma), `home_redesign_test.dart`, `db_redesign_test.dart`, `p49_motion_test.dart`, `menu_photo_test.dart`, `pages_a_test.dart`, `events_cover_test.dart`, `events_page_test.dart`, `w1j_brand_texts_test.dart` (güncellendi).
Gerçek cihazda (Redmi 13C, iPhone) akıcılık ve emülatörde gerçek veriyle gezinti ölçülemedi.
