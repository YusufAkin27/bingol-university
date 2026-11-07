# BIREBIR_FEED: Keşfet + Yeni gönderi (Stitch v3 yön A)

Referans: `C:\bu_design\stitch\v3_feed\SARTNAME.md` (KATEGORİ 1 Keşfet, KATEGORİ 2 Yeni gönderi), PNG'ler `kesfet\A_*.png`, `yeni-gonderi\0*.png` (780x1688 = 390x844 dp @2x). Uygulama: `features/discover/**`, `features/posts/**`.
Uygulama görüntüleri (önce/sonra): `C:\bu_qa\shots\tasarim\p3\feed\onceki|sonra\{kesfet,kesfet320,gonderi}`. Not: test render'ında fotoğraflar yer tutucu (düz sf2) olduğundan referanstaki gerçek fotoğraf yoktur; ölçüler yerleşimden karşılaştırıldı. Emülatör gezisi/ölçümü yapılmadı (paylaşımlı kilit kuyruğu, bkz. rapor).

## Keşfet (yön A)

| Öğe | Referans (dp) | Uygulama (dp) | Fark / not |
|---|---|---|---|
| Başlık "Keşfet" | 28 sp / 700 | 28 / 700 (`discover_tab.dart`) | 0 |
| Arama + "+" düğmeleri | 44 dp yuvarlak, arada 8 | `BuIconButton(size: 44)`, 8 | 0 (hit alanı 48) |
| Çipler | 36 dp yükseklik, 13 sp/500 | `BuChip` (ortak, 34 dp görünür / 48 hit) | -2 dp; `widgets/*` ortak ve kilitli: BuChip görünür yüksekliğinin 36'ya çıkması önerisi raporlandı |
| Yatay kenar | 20 | 20 (`BuSpace.page`) tüm parçalarda | 0 |
| Çipten ilk gönderiye | 16 | 16 (çip satırı alt 16) | 0 |
| Gönderiler arası | 24 | 24 | 0 |
| Görsel kartı | tam genişlik (350), köşe 24, 4:5/1:1/4:3, hafif gölge `0 1 2 .05`, kart sarmalayıcı yok | 350, `kDiscoverCardRadius = 24` (BuRadius.lg=20/xl=28 arasında, token yok: sabit), oran gönderi boyutundan 4:5..4:3 kıstırılır, aynı gölge (koyu temada yok), sarmalayıcı yok | 0 |
| Alt gradyan | alt %28, #000 %0 -> %25 -> %60 | `FractionallySizedBox(.28)`, `scrim` 0 -> .25 -> .6 | 0 |
| Avatar | 32 dp, 2 dp beyaz %40 halka | 28 + 2 dp halka = 32 | 0 |
| Ad | 15 sp / 600, beyaz, tek satır | 15 / 600 `onMedia`, ellipsis | 0 |
| "bölüm · zaman" | 12 sp / 500, beyaz %85 | 12 / 500 `onMedia` %85, ayraç " · ", tek satır (`PostMetaLine`) | 0 |
| Kalp hapı | 44 dp, yatay 14, #171E33 %50 + blur, kalp 20, sayı 13/600; beğenilince dolu BEYAZ kalp | 44 dp, başlangıç 14, `BuColors.ink` %50 (blur YOK: kaydırma listesinde BackdropFilter pahalı), kalp 20, sayı 13/600 tabular, beğenilince dolu beyaz | blur yok (gerekçeli); hit 44 (referansın kendisi 44) |
| Gönderi metni | görselin 10 dp altında tek satır 15 sp/500, yatay 4 | 10 dp, tek satır 15/500, 4 | 0 |
| ⋯ menü | referansta yok | sağ üstte yarı saydam daire (scrim %35), 48 dp hit | KASITLI: işlev (Şikâyet/Düzenle/Sil/Engelle) için kalıyor (onaylandı) |
| Çift dokunuş / basma | beyaz kalp 88 dp, basınca ölçek .98 | korundu; `BuPressable(scale: .98)` | 0 |
| Öneri şeridi | kartsız; öğe 104 dp, aralık 16, avatar 56, ad 14/600, bölüm 12 mut, "Takip et" ince çerçeveli hap 36 dp bdStrong 1 dp 13/600; başlık 16/600, "Tümü" 14/600 pr; üst 8 / alt 32 | aynı değerler; takipte `bd` çerçeve + `mut` metin; başlık/Tümü aynı | 0 |
| Yükleniyor | aynı oran, tonal blok, tek soluk metin çubuğu, parıltı yok | 2 x 4:5 `BuSkeleton` (24 köşe) + tek çubuk | baskın renk yer tutucu uygulanmadı (yerel ucuz hesap yok: nötr sf2; talimat böyle) |
| Boş | "Henüz gönderi yok" 18/600 + mut 15 ikinci cümle + 24 dp altta 48 dp pr düğme, illüstrasyon yok | aynı (ARB tek cümle "Henüz gönderi yok. İlk gönderiyi sen paylaş!" cümle sınırında bölünür) | 0 |
| Hata | "Yüklenemedi" 18/600 + mut açıklama + pr metin düğmesi | ARB güncellendi (tr/en/ar): başlık "Yüklenemedi", açıklama "Bağlantını kontrol edip tekrar dene." 15 mut, pr metin düğmesi 48 dp hedef | 0 |
| Çevrimdışı notu (warnSoft) | başlık/çip altında tam genişlik düz not: warnSoft, onWarnSoft 14/500, köşe 16, dolgu 12x16, ikonsuz, altta eski gönderiler | UYGULANDI (`_OfflineNote`): yalnız mevcut ağ hatası bilgisiyle (önbellekten çizilmiş akışta ağ hatası), yeni mantık yok; ağ dönünce kalkar; metin ARB `p64FeedOffline` tr/en/ar | 0. Bakım notu: akış için bakım durumu kaynağı yok, uygulanmadı |

## Yeni gönderi

| Öğe | Referans | Uygulama | Fark / not |
|---|---|---|---|
| Üst çubuk | 56 dp, çizgisiz, sol "x" 24 dp (48 hit), ortada 17/600, sağ "Paylaş" pr hap 36 dp, yatay 16, 14/600 beyaz, hazır değilken %40 opak | aynı; hap görünür 36 / hit 48; hazır değilken `AnimatedOpacity(.4)` 150 ms; paylaşılırken aynı hapta 16 dp spinner (anlamsal etiket "Paylaşılıyor") | 0 |
| 01 Başlangıç | 20 dp kenar, boş 4:5, köşe 24, sf2, çerçeve/kesikli yok; tek pr "Fotoğraf seç" 48 dp + 12 dp altta mut "Kamera" | aynı; birincil düğme "Fotoğraf seç" (ARB güncellendi, tr/en/ar), "Kamera" 12 dp altta mut metin düğmesi (doğrudan kamera) | 0 |
| 02 Kaynak sheet | alt sayfa, tutamaç, iki satır 56 dp ("Galeriden seç", "Fotoğraf çek"), 24 dp ince çizgi simge, 1 dp ayırıcı, başlık/açıklama yok | UYGULANDI: `showPhotoSourceSheet(simple: true)` (paylaşımlı sheet'in ek sade varyantı; diğer kullanımlar değişmedi); "Fotoğraf seç" onu açar, seçim `_pick`'e gider; kamera izni `ImageService` içinde tek istem (`ensurePermission direct`) | 0 |
| 03 Kırpma | koyu tuval, sabit 4:5 çerçeve (beyaz 1.5 dp), köşe tutamaçları, 3x3 kılavuz (beyaz %35, .5 dp), çerçeve dışı %55 karartma, sol üstte x, altta 72 dp çubuk: "Vazgeç" 15/500 + beyaz "Bitti" hapı (40 dp, siyah 15/600); başlık/döndür/sıfırla yok | UYGULANDI yalnız `CropKind.post` için (`_postScaffold`, `_PostStage`, `_PostFramePainter`): çerçeve 390 dp'de 312 x 390, yan boşluk 39, çizgi kalınlıkları ekranda sabit; "Bitti" ARB `p64CropDone` tr/en/ar. Profil/kulüp/kapak/sohbet kırpma DEĞİŞMEDİ (k4_posts_test profil+kapak testleri geçiyor) | 0; döndürme jesti post kırpmada kalktı (controller'da duruyor) |
| 04 Önizleme/yazma | 20 dp, 4:5 köşe 24 hafif gölge, 16 dp altta tek satır alan: sf, 1 dp bdStrong, köşe 16, 52 dp yükseklik, 16 dp iç, sağda sessiz sayaç 12 sp mut | aynı (`BuSize.field` 52 min, `BuRadius.md` 16, `bdStrong` 1 dp, sayaç 12 sp) | yer tutucu "Birkaç kelime yaz…" (ARB güncellendi); fotoğraf çerçeveyi TAM kaplar (BoxFit.cover), beyaz bant yok |
| Sayaç | yalnız sınırda danger | 7/7 ink-kalın, aşımda danger + alan çerçevesi danger 1.5 dp (150 ms) | 0 |
| 05 Paylaşılıyor | görsel %60 opak, alan pasif | görsel üstü `bg` %40 örtü, alan `enabled:false`, hap spinner | 0 |
| 06 Uyarılar | danger sayaç/çerçeve, danger altı metin, dangerSoft moderasyon notu | mevcut hata satırları korundu (davranış değişmez); çerçeve/sayaç danger | moderasyon kutusu mevcut stil (çerçeveli kart) |

## Test / doğrulama
`mobile/test/redesign/p3feed_test.dart` (ölçü testleri: kart 350 dp tam genişlik, 4:5, 24 köşe, gradyan .28, ad onMedia 15, hap 44, metin tek satır, öneri düğmesi çerçeve/36 dp, boş/hata, compose, 320/390 dp x1.3 açık+koyu taşma matrisi).

## Gönderi detayı + tam ekran fotoğraf + menüler (Stitch v3 kategori 3)

Referans: `C:\bu_design\stitch\v3_feed\gonderi-detay\01..06` + SARTNAME "KATEGORİ 3". Uygulama: `post_card.dart` (`_buildDetail`), `post_detail_page.dart`, `post_photo_viewer.dart`, `post_actions.dart`, `like_button.dart`.

| Öğe | Referans | Uygulama | Fark / not |
|---|---|---|---|
| Üst çubuk | 56 dp, geri + "Gönderi" 18/600, sağda avatar YOK | mevcut `BuHeader` (ortak, `widgets/*`) | başlık boyutu ortak bileşenden gelir (kilitli) |
| Yazar satırı | 20 dp kenar, dikey 8, avatar 40, ad 15/600, "bölüm · zaman" 13 mut tek satır, sağda ⋯ 24 dp (48 hit) | aynı (`PostMetaLine` ayraç " · ", `bodySmall` 13 mut) | 0 |
| Fotoğraf | 20 dp kenar içinde 4:5, köşe 16, kart/gölge yok | `Padding(pageH)` + `PostPhoto(radius: 16)`; kart yüzeyi kalktı | 0 |
| Alt satır | kalp 22 + sayı 15/600 + "·" + metin 15; "düzenlendi" 12 mut 6 dp altta | `LikeButton(detail: true, size: 22)`: beğenilmemiş ink çizgi kalp, beğenilince dolu pr; metin kaydırılır (1 satıra sığmazsa sarar, kırpılmaz); "düzenlendi" ayrı satır, anahtar `post-edited` | metin kırpma yok (referans tek satır; detayda tam metin önceliği) |
| Beğeni animasyonu | 1 -> 1.38 -> 1, tabular sayı | aynı (eski .92 geri vuruşu kaldırıldı) | 0 |
| Çift dokunuş | foto %15 kararır, 88 dp beyaz dolu kalp gölgesiz, ölçek .9 -> 1.1 -> 1.0, sonra fade | aynı (`DoubleTapLike`: karartma .15, gölge kaldırıldı, ölçek .9/1.1/1.0); Keşfet kartı da aynı davranışı kullanır | 0 |
| Tam ekran | saf siyah, tek sol üst beyaz "x" 24 dp (48 hit); pinch, çift dokunuş, sürükle-kapat | zemin `scrim` (siyah) alfa 1 -> sürüklenince açılır; "x" 24 dp `onMedia`, yuvarlak zemin kalktı, sol üst; jestler aynı | 0 |
| Menü (kendi/başkası) | alt sayfa, her satır 56 dp, 24 dp yatay iç boşluk, 16/500, ikon 24, 1 dp bd ayırıcı, danger satırı danger renk | `BuSheet` + `_SheetRow` (anahtarlar `post-act-*` aynı); eski ⋯ altında açılan kart + karartma deliği kaldırıldı | 0 |
| Düzenle diyaloğu | köşe 24, iç 24, başlık 20/600, alan 16 köşe 1 dp bdStrong min 72 dp iç 16x14, sayaç altta sağda 12 mut (aşımda danger), Vazgeç metin + Kaydet pr 48 dp, hata danger 13 ikonsuz | aynı (`_EditDialog`, `_DialogShell` 24) | 0 |
| Silme/engelleme onayı | aynı diyalog kalıbı, ikon yok, Vazgeç + Sil (danger dolu) | ikon karoları kalktı, düğmeler 48 dp, eşit genişlik | 0 |
| Şikâyet sheet'i | mevcut `BuSheet` (Stitch üretemedi) | UYGULANMADI: `widgets/report_sheet.dart` ortak dosya | ortak dosyada değişiklik gerekir (raporlandı) |
| Yükleniyor | 4:5 blok + yazar iskeleti | `PostCardSkeleton` kartsız, blok köşe 16 | baskın renk blok yok (sf2) |
| Bulunamadı | "Gönderi bulunamadı" 18/600 + mut "Silinmiş ya da gizlenmiş olabilir." | ARB'deki tek cümle parantezden bölünür (başlık + soluk "silinmiş veya gizlenmiş olabilir"), simge/kart yok | ikinci satır ARB metniyle (referanstan sözcük farkı) |

Testler: `p3feed_test.dart` grup "Gonderi detayi (Stitch v3 kategori 3)" (yerleşim, tam ekran, menü, düzenle/sil diyalogları, bulunamadı, 320/390 dp x1.3 taşma); `k4_posts_test` menü testleri alt sayfaya göre güncellendi.


## Keşfet v2: masonry (blok blok) + kaydırmalı gönderi sayfası (Stitch v3 kesfet2, seçenek A)

Referans: `C:\bu_design\stitch\v3_kesfet2\` (`SARTNAME.md`, `01..10` PNG, 780x1688 = 390x844 dp @2x; kullanıcı onayı: A, kutuda yalnız sol altta yazar avatarı + ad, sağ altta kalp + sayı; metin yalnız gönderi sayfasında). Uygulama: `features/discover/{discover_masonry,discover_box,masonry_layout,discover_suggestions,discover_tab}.dart`, `features/posts/{post_detail_page,post_stream,post_card,like_button,post_routes}.dart`. Yan yana görüntüler (sol referans, sağ uygulama; tr açık/koyu, x1.3, ar): `C:\bu_qa\shots\tasarim\kesfet2\` (üretim: `test/redesign/kesfet2_shots_test.dart`, `STORE_SHOTS_OUT=... K2_MODES=light,dark,x13 K2_LANG=tr|ar`). Test render'ında fotoğraflar üretilmiş soyut sahnedir (referanstaki gerçek fotoğraflar değil) ve alt bar (FloatingNav, değişmedi) sağ tarafta yoktur.

Ölçü tablosu: referans PNG'den (piksel / 2) ve SARTNAME'den okunan değerler, uygulama `test/redesign/kesfet2_birebir_test.dart` ile ölçülür (her satır ±2 dp ile doğrulanır; test tablo satırlarını basar). Dikey ölçüler başlık satırına göre göreli verilir: mutlak üst ofset (durum çubuğu + güvenli alan) tüm sekme başlıklarında ortaktır (`safe + 8`) ve referans HTML render'ında 6-7 dp daha aşağıdadır; bu kasıtlı olarak karşılaştırılmaz.

| Ölçü | Referans dp | Uygulama dp | Fark |
|---|---|---|---|
| Başlık punto (sp) | 28.0 | 28.0 | +0.0 |
| Arama düğmesi görünür boyut | 44.0 | 44.0 | +0.0 |
| İlk kutu üstü - başlık merkezi (dikey) | 76.0 | 76.0 | +0.0 |
| Yan kenar (sol) | 12.0 | 12.0 | +0.0 |
| Yan kenar (sağ) | 12.0 | 12.0 | +0.0 |
| Sütun genişliği | 179.0 | 179.0 | +0.0 |
| Sütun arası | 8.0 | 8.0 | +0.0 |
| Satır arası (sütun içi) | 8.0 | 8.0 | +0.0 |
| Kutu yüksekliği 3:4 | 238.7 | 238.7 | -0.0 |
| Kutu yüksekliği 1:1 | 179.0 | 179.0 | +0.0 |
| Kutu yüksekliği 2:3 | 268.5 | 268.5 | +0.0 |
| Kutu yüksekliği 4:5 | 223.8 | 223.8 | -0.1 |
| Kutu yüksekliği 1:1 (5.) | 179.0 | 179.0 | +0.0 |
| Köşe yarıçapı | 16.0 | 16.0 | +0.0 |
| Gradyan yüksekliği (% kutu) | 42.0 | 42.0 | +0.0 |
| Gradyan alfa üst (%) | 0.0 | 0.0 | +0.0 |
| Gradyan alfa orta (%) | 28.0 | 28.0 | +0.0 |
| Gradyan alfa alt (%) | 62.0 | 62.0 | +0.0 |
| Avatar boyutu (halka dahil) | 29.0 | 29.0 | +0.0 |
| Avatar sol boşluk | 9.0 | 9.0 | +0.0 |
| Avatar merkezi alttan | 22.0 | 22.0 | +0.0 |
| Ad punto (sp) | 13.0 | 13.0 | +0.0 |
| Ad başlangıcı (kutu soluna) | 42.0 | 43.0 | +1.0 |
| Ad merkezi alttan | 22.0 | 22.0 | +0.0 |
| Kalp boyutu | 20.0 | 20.0 | +0.0 |
| Kalp merkezi alttan | 22.0 | 22.0 | +0.0 |
| Sayı punto (sp) | 13.0 | 13.0 | +0.0 |
| Sayı sağ boşluk | 10.0 | 10.0 | +0.0 |
| Kalp ile sayı arası | 5.0 | 4.0 | -1.0 |
| Beğeni dokunma yüksekliği (≥44) | 44.0 | 44.0 | +0.0 |
| Yazar dokunma yüksekliği (≥44) | 44.0 | 44.0 | +0.0 |
| İskelet sol sütun 1. kutu | 238.7 | 238.7 | -0.0 |
| İskelet sağ sütun 1. kutu | 179.0 | 179.0 | +0.0 |
| İskelet sol sütun 2. kutu | 223.8 | 223.8 | -0.1 |
| İskelet sağ sütun 2. kutu | 268.5 | 268.5 | +0.0 |
| İskelet sol sütun 3. kutu | 238.7 | 238.7 | -0.0 |
| İskelet sağ sütun 3. kutu | 179.0 | 179.0 | +0.0 |
| İskelet sol kenar | 12.0 | 12.0 | +0.0 |
| İskelet köşe | 16.0 | 16.0 | +0.0 |
| Bant genişliği | 390.0 | 390.0 | +0.0 |
| Bant başlık punto (sp) | 16.0 | 16.0 | +0.0 |
| Bant avatar boyutu | 56.0 | 56.0 | +0.0 |
| Takip et yüksekliği | 36.0 | 36.0 | +0.0 |
| Önceki kutu altı -> bant başlığı merkezi | 28.0 | 30.0 | +2.0 |
| Bant başlığı merkezi -> avatar üstü | 22.0 | 22.0 | +0.0 |
| Takip et altı -> sonraki kutu | 24.0 | 24.0 | +0.0 |
| Başlık punto (sp) | 18.0 | 18.0 | +0.0 |
| Başlık sol (x) | 60.0 | 60.0 | +0.0 |
| Başlık merkezi (y) | 29.0 | 28.0 | -1.0 |
| Geri düğmesi dokunma alanı | 48.0 | 48.0 | +0.0 |
| Yazar avatar boyutu | 40.0 | 40.0 | +0.0 |
| Yazar avatar sol | 20.0 | 20.0 | +0.0 |
| Yazar avatar üstü | 64.0 | 64.0 | +0.0 |
| Yazar adı punto (sp) | 15.0 | 15.0 | +0.0 |
| Yazar adı sol | 72.0 | 72.0 | +0.0 |
| Foto sol | 20.0 | 20.0 | +0.0 |
| Foto genişliği | 350.0 | 350.0 | +0.0 |
| Foto yüksekliği (4:5) | 437.0 | 437.5 | +0.5 |
| Foto üstü | 120.0 | 120.0 | +0.0 |
| Kalp satırı merkezi (foto altından) | 25.0 | 25.0 | +0.0 |
| Ayırıcı (foto altından) | 61.0 | 61.0 | +0.0 |
| Ayırıcı kalınlığı | 1.0 | 1.0 | +0.0 |
| Ayırıcı sol | 20.0 | 20.0 | +0.0 |
| Ayırıcı -> sonraki avatar üstü | 32.5 | 32.0 | -0.5 |
| Gönderi aralığı (avatar üstü -> avatar üstü) | 586.0 | 587.5 | +1.5 |
| Geri dairesi çapı | 40.0 | 40.0 | +0.0 |
| Geri dairesi sol | 9.0 | 10.0 | +1.0 |
| Geri dairesi üst | 8.5 | 8.0 | -0.5 |
| Daire zemin opaklığı (%) | 94.0 | 94.0 | +0.0 |


### Mimari

- **Masonry**: paketsiz. `masonry_layout.dart`: açgözlü iki sütun yerleşimi (`masonryPlace`) + `SliverGrid` için `MasonryGridDelegate` (tembel; üst ofsetler azalmayan dizi olduğundan görünür aralık ikili aramayla bulunur, RTL'de sütunlar aynalanır). Kutu yüksekliği = sütun genişliği / oran önceden bilindiğinden fotoğraf çözülünce kutular ZIPLAMAZ. Oran: `PostMedia.width/height` (mevcut medya meta alanı) 1:1 ile 2:3 arasına kıstırılır; yatay fotoğraf 1:1 kırpılır; boyut yoksa güvenli varsayılan 4:5 (gönderi kırpması 4:5 olduğundan en olası değer); fotoğrafsız eski kayıt kare.
- **Kutu** (`DiscoverPostBox`): `PostPhoto(thumbOnly)` yalnız `thumbUrl` yükler (yoksa tam boy; masonry'de tam boy hiç indirilmez), alt %42 gradyan TEK `DecoratedBox` (blur/gölge yok), `LikeButton(tile: true)` sıkı kalp+sayı satırı (görünür 20 dp, dokunma alanı satırın tamamı ≥44 dp, beğenilmiş kutuda dolu beyaz kalp; iyimser + hata geri alma + "Tekrar dene" mevcut mantık), `BuHero` ile paylaşılan öğe geçişi (`discoverHeroTag`). Uzun basma = mevcut ⋯ alt sayfası (kutuda ⋯ düğmesi yoktur).
- **"Tanıyor olabilirsin"**: `masonrySplitIndex` ilk 4 kutudan sonra (sütun yükseklikleri farkı ≤16 dp olan en erken nokta, yoksa ≤10 kutu içinde farkı en küçük nokta) ızgarayı böler; öneri yok/yüklenemezse (`onUnavailable`) bölme kalkar, masonry kesintisiz tek ızgara olur.
- **Gönderi sayfası** (`PostDetailPage` + `PostStreamSeed`): tıklanan gönderi ilk, altında masonry'nin o kutudan SONRAKİ gönderileri ve aynı imleç (sonsuz kaydırma, `GET /feed`), mevcut `PostCard(detail: true)` yeniden kullanılır (kopya yok). Push/derin bağlantı: `PostStreamSeed.fresh()` (önce `GET /posts/{id}`, sonra akışın ilk sayfası; akış alınamazsa yalnız o gönderi, hata gösterilmez). Beğeni/düzenleme/silme `onChanged`/`onDeleted` ile masonry'ye anında yansır; dönüş değeri hâlâ açılan gönderinin `Post?` hâlidir. Geri dönünce masonry kaydırma konumu değişmez (aynı sekme, aynı `ScrollController`; testle doğrulandı).
- Yeni backend ucu, yeni paket, yeni ARB anahtarı YOK.

### Referanstan bilinçli sapmalar

| Konu | Not |
|---|---|
| Çift dokunuşla beğeni kutuda yok | SARTNAME 10 "isteğe bağlı" dedi; `DoubleTapLike` tek dokunuşa ~300 ms gecikme ekler, masonry'de ana eylem açmaktır. Gönderi sayfasında (88 dp beyaz kalp, %15 kararma) mevcut. |
| Çip görünür yüksekliği 34 | Ortak `BuChip` (kilitli); referans 34 ile aynı. Seçili çipin ince çerçevesi ortak bileşenden gelir. |
| Gönderi sayfası başlığı | Referans 18/600 (ortak `BuHeader` değil, sayfa içi başlık): `BuHeader` büyük ekran başlığı boyutunda; geri düğmesi sabit katman, başlık içerikle kayar. |
| Bant yüksekliği 148 (`172` idi) | Referans 07'de "Takip et" düğmesi meta satırının 10 dp altında; Arapça satır yüksekliği için 3 dp pay. |
| Kutuda ad sınırı | Referanstaki "Zeynep Ar…" gibi: ad sütunu esnek, kalp+sayı asla kırpılmaz (test: 12345 beğeni + uzun ad). |
| Bakım şeridi (06b) | Akış için bakım durumu kaynağı yok; uygulanmadı (SARTNAME de "bugün koddan beslenmez" diyor). |

### Detay sayfası ritmi için `PostCard(detail)` ayarı (08 piksel eşlemesi)

Yazar satırı üst 4 / alt 12 (satır 48 dp, avatar 40 dp ortada: avatar üstü 64 dp), kalp satırı fotoğraf altından 3 dp, kart alt boşluğu 14 dp, ayırıcı altında 24 dp: gönderi aralığı referansla 1,5 dp içinde. Detay kartını kullanan diğer ekranlar aynı ritmi alır.

### Testler

`test/kesfet2_test.dart` (birim: yerleşim/oran/bölme noktası/RTL/tembel çizim; davranış: oran dizilimi, bant, yazar dokunma, beğeni iyimser+geri alma, uzun basma, kaydırma konumu korunması, gönderi sayfası akışı, sonsuz kaydırma `cursor=p2` tek istek, sayfa sonu iskeleti, hata+yeniden dene, sabit geri düğmesi, beğeni/silme yansıması, derin bağlantı, akış hatasında tek gönderi, 404; tr/en/ar x açık/koyu x 390/320 dp x x1.0/x1.3 taşma matrisi), `test/redesign/kesfet2_birebir_test.dart` (yukarıdaki ölçü tablosu). Güncellenen eski testler: `discover_masonry_test`, `d2_kesfet_test`, `redesign/{k4_states,p2dc,p3feed}_test` (tek sütun kart varsayımları masonry kutusuna göre yeniden yazıldı; çift dokunuş testi gönderi sayfasına taşındı, küçük resim katmanı testi masonry (yalnız küçük resim) + detay (küçük resim + tam boy) olarak ikiye bölündü).
