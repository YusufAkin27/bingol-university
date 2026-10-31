# BIREBIR_FEED: Keşfet + Yeni gönderi (Stitch v3 yön A)

Referans: `C:\bu_design\stitch\v3_feed\SARTNAME.md` (KATEGORİ 1 Keşfet, KATEGORİ 2 Yeni gönderi), PNG'ler `kesfet\A_*.png`, `yeni-gonderi\0*.png` (780x1688 = 390x844 dp @2x). Uygulama: `features/discover/**`, `features/posts/**`.
Uygulama görüntüleri (önce/sonra): `C:\bu_qa\shots\tasarim\p3\feed\onceki|sonra\{kesfet,kesfet320,gonderi}`. Not: test render'ında fotoğraflar yer tutucu (düz sf2) olduğundan referanstaki gerçek fotoğraf yoktur; ölçüler yerleşimden karşılaştırıldı. Emülatör gezisi/ölçümü yapılmadı (paylaşımlı kilit kuyruğu, bkz. rapor).

## Keşfet (yön A)

| Öğe | Referans (dp) | Uygulama (dp) | Fark / not |
|---|---|---|---|
| Başlık "Keşfet" | 28 sp / 700 | 28 / 700 (`discover_tab.dart`) | 0 |
| Arama + "+" düğmeleri | 44 dp yuvarlak, arada 8 | `BuIconButton(size: 44)`, 8 | 0 (hit alanı 48) |
| Çipler | 36 dp yükseklik, 13 sp/500 | `BuChip` (ortak, 34 dp görünür / 48 hit) | -2 dp; ortak bileşen, `widgets/*` kilitli, raporda öneri |
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
| ⋯ menü | referansta yok | sağ üstte yarı saydam daire (scrim %35), 48 dp hit | SAPMA: Şikâyet/Düzenle/Sil/Engelle erişimi için gerekli; uzun basma da açar |
| Çift dokunuş / basma | beyaz kalp 88 dp, basınca ölçek .98 | korundu; `BuPressable(scale: .98)` | 0 |
| Öneri şeridi | kartsız; öğe 104 dp, aralık 16, avatar 56, ad 14/600, bölüm 12 mut, "Takip et" ince çerçeveli hap 36 dp bdStrong 1 dp 13/600; başlık 16/600, "Tümü" 14/600 pr; üst 8 / alt 32 | aynı değerler; takipte `bd` çerçeve + `mut` metin; başlık/Tümü aynı | 0 |
| Yükleniyor | aynı oran, tonal blok, tek soluk metin çubuğu, parıltı yok | 2 x 4:5 `BuSkeleton` (24 köşe) + tek çubuk | baskın renk yer tutucu uygulanmadı (yerel ucuz hesap yok: nötr sf2; talimat böyle) |
| Boş | "Henüz gönderi yok" 18/600 + mut 15 ikinci cümle + 24 dp altta 48 dp pr düğme, illüstrasyon yok | aynı (ARB tek cümle "Henüz gönderi yok. İlk gönderiyi sen paylaş!" cümle sınırında bölünür) | 0 |
| Hata | "Yüklenemedi" 18/600 + mut açıklama + pr metin düğmesi | başlık 18/600 (mevcut ARB "Sunucuya ulaşılamadı") + pr metin düğmesi "Yeniden dene" 48 dp; açıklama cümlesi YOK | metin farkı (ARB kilidi) |
| Çevrimdışı/Bakım notu (warnSoft) | akış üstünde uyarı notu | UYGULANMADI | yeni metin + durum gerektirir (ARB p64 + akış mantığı); sonraki iş |

## Yeni gönderi

| Öğe | Referans | Uygulama | Fark / not |
|---|---|---|---|
| Üst çubuk | 56 dp, çizgisiz, sol "x" 24 dp (48 hit), ortada 17/600, sağ "Paylaş" pr hap 36 dp, yatay 16, 14/600 beyaz, hazır değilken %40 opak | aynı; hap görünür 36 / hit 48; hazır değilken `AnimatedOpacity(.4)` 150 ms; paylaşılırken aynı hapta 16 dp spinner (anlamsal etiket "Paylaşılıyor") | 0 |
| 01 Başlangıç | 20 dp kenar, boş 4:5, köşe 24, sf2, çerçeve/kesikli yok; tek pr "Fotoğraf seç" 48 dp + 12 dp altta mut "Kamera" | aynı yerleşim; çerçevesiz sf2, köşe 24; pr düğme etiketi "Galeriden seç" (ARB `gonderiPickPhoto`), "Kamera" metin düğmesi | etiket farkı: "Fotoğraf seç" yeni ARB metni ister; ARB kilidi ve çift dokunuş yerine ertelendi |
| 02 Kaynak sheet | alt sayfa, iki satır 56 dp, başlıksız | UYGULANMADI: iki seçenek (galeri / kamera) zaten 01'de görünür; sheet ek bir dokunuş eklerdi | `showPhotoSourceSheet` diğer akışlarla paylaşımlı; sade varyantı sonraki iş |
| 03 Kırpma | koyu tuval, sabit 4:5 çerçeve, Vazgeç/Bitti alt çubuk, dönder/sıfırla yok | UYGULANMADI (yalnız ölçek değeri ve önizleme "⋯" sadeleşti) | `crop_page.dart` profil/kulüp/kapak ile paylaşımlı; dönder/önizleme satırını kaldırmak ürün kararı ve mevcut testleri (k4_posts_test) değiştirir |
| 04 Önizleme/yazma | 20 dp, 4:5 köşe 24 hafif gölge, 16 dp altta tek satır alan: sf, 1 dp bdStrong, köşe 16, 52 dp yükseklik, 16 dp iç, sağda sessiz sayaç 12 sp mut | aynı (`BuSize.field` 52 min, `BuRadius.md` 16, `bdStrong` 1 dp, sayaç 12 sp) | yer tutucu "Kısa bir not ekle (isteğe bağlı)" (ARB), referans "Birkaç kelime yaz…"; fotoğraf çerçeveyi TAM kaplar (BoxFit.cover), beyaz bant yok |
| Sayaç | yalnız sınırda danger | 7/7 ink-kalın, aşımda danger + alan çerçevesi danger 1.5 dp (150 ms) | 0 |
| 05 Paylaşılıyor | görsel %60 opak, alan pasif | görsel üstü `bg` %40 örtü, alan `enabled:false`, hap spinner | 0 |
| 06 Uyarılar | danger sayaç/çerçeve, danger altı metin, dangerSoft moderasyon notu | mevcut hata satırları korundu (davranış değişmez); çerçeve/sayaç danger | moderasyon kutusu mevcut stil (çerçeveli kart) |

## Test / doğrulama
`mobile/test/redesign/p3feed_test.dart` (ölçü testleri: kart 350 dp tam genişlik, 4:5, 24 köşe, gradyan .28, ad onMedia 15, hap 44, metin tek satır, öneri düğmesi çerçeve/36 dp, boş/hata, compose, 320/390 dp x1.3 açık+koyu taşma matrisi).
