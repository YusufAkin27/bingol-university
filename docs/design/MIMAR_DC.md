# MIMAR_DC: Keşfet, gönderi, haber, arama, sohbet (sayfa sayfa mimar cilası)

Kapsam: `docs/MOBILE_PAGES.md` bölüm E (39-44) ve F (45-57) + alt sayfalar. Davranış/API/ağ katmanı değişmedi; yalnız görünüm.
Ekran görüntüleri: `C:\bu_qa\shots\tasarim\dc\onceki|sonra\` (tr390 açık/koyu/x1.3, tr320 x1.3, ar390). Üretim: mevcut `test/redesign` shots testlerinin (k5, k5b, k4_yeni, p05, k6) kopyaları, genişlik `DC_W` ile (320/390).

## Ekran bazında

| No / ekran | Bulgu | Öneri / uygulanan | Durum |
|---|---|---|---|
| 47/Sohbet listesi (`ChatTab`, T-114) | 320 dp ya da 1.3x yazıda tür çipi + saat başlığı 3 harfe sıkıştırıyordu ("Fotoğraf…", "Kariyer Gü…"); birebir başlıklar da "Zeynep D…" kesiliyordu | Dar (<250 dp sütun) ya da büyük yazıda: tür çipi kalkar (avatar rozeti türü zaten gösteriyor; ekran okuyucu "başlık, Kulüp" okur), başlık her tür için 2 satıra açılır; geniş ekranda değişmez | Uygulandı |
| 47/Sohbet başlığı "yazıyor" (`ChatDetailPage` üst çubuğu, yalnız görünüm) | "yazıyor…" ile durum metni arasında ani değişim, durağan metin | Sondaki "…" yerine üç noktalı nabız (`ChatTypingDots`, yalnız opacity, hareket azaltılmışsa durağan); durum/yazıyor geçişi kısa solma ile | Uygulandı |
| 45/Yeni sohbet kişi satırı (`NcPersonRow`) | Sağdaki "Sohbet başlat" hapı genişlik yiyor, bölüm adı tek satırda kesiliyordu ("Makine Mühendisliği…") | Alt metin 2 satıra iner (hap korunur; test `Sohbet başlat` metnini bekliyor) | Uygulandı |
| 41/Haber listesi | Sekme (Haber/Duyuru/Etkinlik) türü söylerken her satırda aynı tür rozeti tekrarlanıyordu | `NewsTile(showType: false)` listede; favoriler karışık tür olduğundan rozeti korur | Uygulandı |
| 39/Gönderi oluştur | (a) Seçici → önizleme anında zıpladı; (b) kelime sayacı hep kalın/koyu ("5/7"), gürültü; (c) fotoğraf üstündeki "Fotoğrafı değiştir/Yeniden kırp" hapları Material gölgesiyle koyu halka gibi görünüyordu | (a) `AnimatedSwitcher` (BuMotion.medium, azaltılmışsa anlık); (b) sayaç normalde `mut`/normal ağırlık, yalnız sınırda (7/7) koyu-kalın, aşımda `danger`; (c) ortak `BuElevation` yumuşak gölgesi | Uygulandı |
| 40/Gönderi detayı | Fotoğraf ekran kenarına dayalı ama köşeleri yuvarlaktı (kenarda bozuk); kalp ile sayı arasında ~18 dp boşluk | Detayda fotoğraf köşesi 0 (kenarsız); sayaç kalp kutusunun boş payına 12 dp kayar (kalp 44 dp dokunma kutusu aynı, sayaç da dokunma alanı); boşluk ~18 dp → ~6 dp | Uygulandı |
| 42/Haber detayı | Kapak + yuvarlak kenarlı içerik kartı, okuma tipografisi (`bodyLarge`, satır 1.6) zaten düzgün | Değişiklik gerekmedi | Uygulanmadı (yeterli) |
| 44/Arama | Son aramalar/sonuç grupları ve iskelet zaten tutarlı; yeni bulgu çıkmadı | - | Uygulanmadı |
| 47/Balonlar, medya, tek gösterimlik | Balon köşe/kuyruk, gruplama, yükleme halkası, hata-yeniden dene satırı tutarlı | - | Uygulanmadı |
| Keşfet (D2) | D2'nin 4:5 kart/çipli üst alan/ertelenen öneri şeridi korunur | Yalnızca `PostCard` ortak parçaları (detay kenarsız) etkilendi; Keşfet akışı aynı | Korundu |

## Uygulanmayan öneriler ve nedenleri
- Yeni sohbet kişi satırında hapı simgeye indirmek: `sohbety_design_test` "Sohbet başlat" metnini bekliyor ve görünür etiket daha anlaşılır; 2 satırlı alt metin yeterli.
- Alınan mesaj balonlarındaki ince çerçeveyi kaldırmak: zeminle beyaz balon kontrastı düşük, çerçeve gerekli.
- `chat_detail_page.dart` mesaj gönderim animasyonu / klavye geçişi: davranış katmanı (liste kaydırma, outbox) ile iç içe; görünüm tarafında güvenle eklenecek ek animasyon bulunmadı.

## Ortak dosyalarda gereken değişiklik (öneri)
- `widgets/bu_widgets.dart` `BuChipRow`: 1.3x yazıda son çip ekran kenarında kesik görünür (kaydırılabilir; bir "fade" kenarı ya da ilk render'da hafif kaydırma ipucu eklenebilir).

## Testler
`mobile/test/redesign/dc_test.dart`: sohbet listesi T-114 (390/320, 1.0/1.3), haber listesi rozet tekrarı, `ChatTypingDots` (hareket azaltılmışsa durağan).

## Emülatör bulguları (gerçek veri, Android 15 edge-to-edge) - düzeltildi
| Ekran | Bulgu | Düzeltme |
|---|---|---|
| Sohbet sekmesi | Başlık ve "+" düğmesi durum çubuğuna biniyordu (üst güvenli alan yok sayılıyordu) | Başlık satırı üst padding = `MediaQuery.paddingOf(context).top + 12` (BuHeader ile aynı kalıp); arşiv görünümü BuHeader zaten inset alıyor. Test: status bar 24/36/48 dp |
| Kulüpler kategori çipleri | `SizedBox(height: 34)` içinde 48 dp BuChip: "Technology" yazısı alttan kırpılıyordu | Kutu 48 dp (üst boşluk 14 → 8, ritim aynı). Keşfet (Row) ve Sohbet (BuChipRow 52 dp) etkilenmiyor |
| Ana Sayfa boş menü | ~180 dp'lik başlık + kutu + simge kartı | `HomeEmptyCard(compact: true)`: tek satır (simge + "Bugün için liste yok" + alt metin + ok); dolu menü ve diğer boş kartlar aynı |
| Ana Sayfa Hızlı Erişim | "Timetable" karo kenarına çok yakın | Karo arası boşluk 8 → 6 dp (karo başına ~1.6 dp iç genişlik). 390 dp'de Türkçe etiketler zaten sınırda olduğundan 3+2 eşiği sıkılaştırılmadı (db_redesign_test 5 karo tek satır bekliyor) |

---

# Tur 2 (P2-DC): ince detay + animasyon (Keşfet, gönderi, sohbet)

Kural: yalnız transform/opacity, 150-250 ms (tek seferlik büyük kalp 520 ms), sürekli döngü yok, kaydırırken yok, "animasyonları azalt"ta anında. Ortak parçalar yalnız kullanıldı (BuStaggerItem/Scope, BuHero, BuPop, BuPressable, BuMotion); `widgets/*`, `core/motion/*`, `chat_detail_page.dart` ve stomp/outbox DEĞİŞMEDİ. Yeni renk, yeni metin (ARB), yeni istek yok. Testler: `mobile/test/redesign/p2dc_test.dart`.

| Ekran / öğe | Önce | Sonra (uygulanan) | Dosya |
|---|---|---|---|
| Keşfet akışı girişi | Tüm liste tek parça `SliverAnimatedOpacity` ile soluyordu | İlk 6 kart kademeli (BuStaggerItem, 40 ms arayla, solma + yükselme); kaydırınca/yenilemede/çip değişmeyen durumda tekrar yok (kapsam anahtarı yalnız Tümü/Popüler değişince artar, kaydırma durumu GlobalKey ile korunur); boş/hata kartı yükselerek belirir | `discover_masonry.dart` |
| Yeni gönderi listeye giriş | Liste anında kayıyordu | Oluşturulan gönderi başa eklenince kendi kartı solarak + 16 dp yükselerek girer (`_EntryRise`), liste en üste kayar | `discover_masonry.dart` |
| Beğeni kalbi / sayı | Kalp patlaması vardı; "azalt"ta bile oynuyordu; sayı proportional rakam; kalp rengi anlık | "Azalt"ta kalp/sayı animasyonu yok, çift dokunuşta büyük kalp yalnız belirip solar (ölçek yok); beğeni = lightImpact, vazgeç = selectionClick (BuHaptics ile sınırlı); kalp rengi 150 ms geçer; sayı tabular rakam; büyük kalp 700 -> 520 ms | `like_button.dart` |
| Fotoğraf yükleme | Yer tutucu -> tam boy fade vardı; küçük resim sert beliriyordu | Küçük resim de fade ile gelir (renk -> küçük resim -> tam boy); önbellekteyse anında | `post_card.dart` |
| Kart -> detay | Düz sayfa geçişi | Fotoğraf Hero (BuHero: uçuşta köşe yarıçapı 8 -> 0); detay küçük resmi de kullanır (uçuşta boş kare yok); etiket `discover-post-<id>` (Keşfet) / `post-card-<id>` (liste) | `post_card.dart`, `post_routes.dart`, `post_detail_page.dart` |
| Detayda fotoğraf | Dokunma işlevsizdi | Dokununca tam ekran görüntüleyici: iki parmak yakınlaştırma, çift dokunuş 2.5x (animasyonlu, titreşimli), yakınlaştırılmamışken sürükleyerek kapatma (110 dp ya da hız eşiği; arka plan sürükledikçe açılır, eşik altında geri yaylanır); yakınlaştırılmışken Hero etiketi değişir (yanlış kareye geri uçmaz); kapat düğmesi 48 dp | `post_photo_viewer.dart` (yeni) |
| Gönderi oluştur | Sayaç rengi anlık; uyarı satırı sert açılıyordu; Paylaş düğmesi dolgusu/metni anlık | Sayaç AnimatedDefaultTextStyle 150 ms (renk + ağırlık, tabular rakam); uyarı/hata satırları AnimatedSize + solarak; Paylaş dolgusu 150 ms renk geçişi, metin <-> "Paylaşılıyor" çapraz geçiş | `compose_post_page.dart` |
| Sohbet listesi | Satırlar anında; basma yalnız dalga | İlk 8 satır kademeli (kapsam: her indeks bir kez); satır basılınca %1 küçülür (BuPressable); okunmamış rozeti sayı değişince BuPop; saat ve rozette tabular rakam | `chat_tab.dart` |
| Mesaj balonu girişi | Anında | Taze gönderilen balon alttan 14 dp + solma (220 ms), taze alınan balon yalnız solma (150 ms); "taze" = yerel bekleyen/başarısız ya da 3 sn içinde oluşmuş; geçmiş yüklenirken/kaydırırken animasyon ve controller yok; alt durum satır anahtarıyla korunur | `bubble_entry.dart` (yeni), `message_bubble.dart` |
| Gönderim durum ikonu | Çapraz solma | Solma + %70 -> %100 ölçek (saat -> tek tik -> çift tik) | `message_bubble.dart` |
| Mesaj menüsü | Sabit 180 ms | "Azalt"ta anında | `message_actions.dart` |

## Uygulanmayanlar
- Sohbet "en alta in" düğmesi belirme animasyonu, tarih ayırıcı yapışkan başlık ve liste -> konuşma avatar Hero'su: üçü de `chat_detail_page.dart` içinde (sınırlı dosya); öneri: düğmeyi `AnimatedScale`/`AnimatedOpacity` ile `ValueListenableBuilder` içinde göstermek, üst çubuk avatarına `BuHero(tag: 'chat-avatar-<id>')`, listedeki `ChatlistAvatar`'ı aynı etiketle sarmak.
- Seçici -> kırpma -> önizleme geçişleri: kırpma rotası platform tema geçişini kullanıyor (`fullscreenDialog`), önizleme tur 1'de AnimatedSwitcher aldı; ek değişiklik gerekmedi.
- Sohbet medya görüntüleyici (`ChatZoomImage`): pinch, çift dokunuş yakınlaştırma (animasyonlu) ve çıkış zaten var; sürükleyerek kapatma eklenmedi (davranış katmanına yakın, ayrı karar).

## Tur 2 doğrulama
- Widget testi: `mobile/test/redesign/p2dc_test.dart` 18 test (başlangıç/ara kare/bitiş, "azalt"ta anında, tekrar oynamama, 44-48 dp hedef); ilgili 21 mevcut dosya (637 test) yeşil; `flutter analyze` posts/discover/chat 0 sorun.
- Ara kare görüntüleri (gerçek render, tr390 açık+koyu): `C:\bu_qa\shots\tasarim\p2\dc\` (`kesfet_giris_70|110|180|600ms`, `cift_dokunus_kalp|sonra`, `gorunturu_acik|surukleme|zoom`, `sohbet_balon_60|110|400ms`, `sohbet_liste_80|160|700ms`); üretim: `test/redesign/p2dc_shots_test.dart` (`P2DC_OUT`, `P2DC_MODES`, `P2DC_LANG`).
- Emülatör gezisi ve gfxinfo ölçümü YAPILMADI (paylaşımlı ağır makine, başka ajanların derlemesi sürüyordu); gerçek cihazda (Redmi 13C, iPhone) akıcılık ölçülemedi.

---

# Tur 3 (P3-FEED, minimal): Keşfet, gönderi, kırpma

Kapsam: `features/discover/**`, `features/posts/**`, `features/media_crop/**`. Ortak dosyalara, ARB'ye, API/ağ katmanına dokunulmadı; yeni renk, yeni metin, yeni istek yok. Ürün kuralı korunur (1 fotoğraf + en çok 7 kelime/60 karakter + beğeni). Önce/sonra: `C:\bu_qa\shots\tasarim\p3\feed\onceki|sonra\{kesfet,kesfet320,gonderi}` (tr390 açık, koyu, x1.3, ar390; kesfet320 = 320 dp x1.3). Üretim: gerçek render (yer tutucu fotoğraflı) `d2_kesfet_shots_test` + `k4_yeni_shots_test`.

| Ekran | Kaldırılan | Sadeleşen | Renk (vurgu) önce -> sonra |
|---|---|---|---|
| Keşfet akışı + üst alan | Kart kenarı 16 dp (başlıktan farklıydı) | Yatay kenar her yerde 20 dp (başlık, çipler, kartlar, iskelet, öneri şeridi); çip satırı alt boşluğu 4 -> 8 | kırmızı: `+`, seçili çip (değişmedi) |
| Keşfet kartı (`DiscoverPostCard`) | Ayrı birleştirilmiş "bölüm • zaman" metni | `PostMetaLine`: tek satır, sığmazsa sondan kırpılır; fotoğraf öncelikli düzen, tek gölge, çerçeve yok (korundu) | 1 -> 1 |
| Tanıyor olabilirsin | 10 adede kadar aynı anda dolgulu kırmızı "Takip et" düğmesi | Takip et = yumuşak zemin (`soft`/`onSoft`), takipte nötr; zemin 150 ms geçer | kırmızı dolgu 10 -> 0 (tek birincil `+` kalır) |
| Keşfet boş | Kart yüzeyi + gölge, düğmede kamera simgesi, 96 dp daire | Sayfa zemininde: 80 dp yumuşak daire + tek cümle + tek düğme | soft + kırmızı düğme -> soft + kırmızı düğme (kart/gölge yok) |
| Keşfet hata/çevrimdışı | Kart + gölge, açıklama cümlesi ("Bağlantınızı kontrol edin..."), düğmede simge | Nötr daire + tek cümle ("Sunucuya ulaşılamadı") + Yeniden dene; açık hata kırmızısı yok | kırmızı daire simgesi -> nötr |
| Gönderi kartı / detay (`PostCard`) | "Düzenlendi" rozet kutusu; 44 dp avatar + `titleLarge` ad; bölüm 2 satır; detayda 16 dp yan boşluk | Ad `titleSmall`, avatar 40, meta tek satır (düzenlendi satır içi sade metin, anahtar `post-edited`), detay yan boşluğu 20 dp | 2 -> 1 (rozet zemini kalktı) |
| Gönderi oluştur | Fotoğraf üstünde "4:5" rozeti, önizleme altında bilgi satırı (simge + cümle), çerçeveli kamera dairesi, fotoğraf yok + metin yazılı durumunda 3 ayrı başlık/yardım metni, kalın sayaç | Boş seçicide yalın kamera simgesi + iki seçenek + gri tek ipucu; metin var/fotoğraf yok: tek cümle; sayaç `labelMedium` normal ağırlık (yalnız sınırda/aşımda vurgulanır); yan boşluk 20 dp; tek birincil düğme = Paylaş | 1 -> 1 (nötr + Paylaş) |
| Gönderi bulunamadı | Kart + gölge + bilgi simgeli satır | Ortalanmış simge + tek cümle | nötr |
| Gönderilerim | Boş: kart+gölge+3 öğe; hata: kart + kırmızı dolgulu daire; kenar 16 dp | Boş: simge + tek cümle (+ kendi gönderilerimde tek düğme); hata: tek cümle + 48 dp yenile; kenar 20 dp | hata kırmızı daire -> nötr |
| Gönderi menüleri/diyaloglar | Menü satırı kalın (w700), Sil/Engelle düğmesinde ikinci simge, Düzenle diyaloğunda yinelenen kapat (X) dairesi (Vazgeç var), sayaçta hep kalın | Satır w600; düğmeler yalnız metin; Vazgeç tek çıkış; sayaç yalnız aşımda kalın | kırmızı yalnız tehlike eylemi (değişmedi) |
| Fotoğraf kırpma | Ölçek satırında süs simgesi + kırmızı değer; önizleme kartında dikey üç nokta | Ölçek değeri sessiz (tabular rakam, `mut`); önizleme gerçek karttaki gibi yatay üç nokta | 2 -> 1 vurgu |

Uygulanmayanlar: (1) Keşfet üst alanının başlık + çiplerini tek satıra birleştirmek: 390 dp'de başlık + iki çip + iki düğme sığmaz, 320 dp x1.3'te kesinlikle taşar; bunun yerine eylem satırı tek satır, çipler tek satır kaldı. (2) Gönderi ızgarası (Gönderilerim) alt gradyanı: yazı okunurluğu için gerekli. (3) "Kaydedilenler": ürün kuralı gereği (kaydet kaldırıldı) ekran yok. (4) Kırpma sayfası düzeni: kilitli, yalnız süs/renk sadeleştirmesi yapıldı.

Ortak parça notu: Keşfet kartı ve `PostCard` ortak "meta satırı" gereksinimi `post_card.dart` içindeki `PostMetaLine` ile çözüldü (ortak widget gerekmedi).

Testler: `mobile/test/redesign/p3feed_test.dart` (PostMetaLine tek satır + taşma, boş/hata sadeliği, öneri düğmesi yumuşak zemin, oluştur sadeliği, bulunamadı/Gönderilerim boş, 320/390 dp x1.3 açık+koyu taşma matrisi). Kenar 16 -> 20 değişikliği için `discover_masonry_test` (kart sol kenarı 20, genişlik 350) ve `k4_states_test` (iskelet 20) güncellendi (gevşetilmedi, yeni kural).

---

# Tur 3 (P3-CHAT, minimal): sohbet listesi, yeni sohbet, konuşma ekranı, arka plan, giriş çubuğu, galeri

Kapsam: `features/chat/**` (+ çıkış temizleyicisi için tek satır `core/user_data.dart`, varlık klasörü için `pubspec.yaml`). Davranış/ağ/stomp/outbox DEĞİŞMEDİ; yeni uç/istek yok. Yeni metinler ARB `p67*` (tr/en/ar). Sabit yükseklik yerine `BuSize` jetonları kullanıldı.

| Ekran | Kaldırılan | Sadeleşen | Renk (vurgu) önce -> sonra |
|---|---|---|---|
| Sohbet listesi satırı | Kart zemini; avatar üstündeki kulüp (lacivert) / etkinlik (yeşil) rozeti | Stitch v3 (`2_liste/01`): kartsız satır, okunmamış satır tam genişlik `sf` yüzey + başlık w700 + saat `pr` + kırmızı sayı rozeti, satırlar arası ince `bd` çizgi (avatar sonrası), tür yalnız nötr etiketle, avatar Hero (`chat-avatar-<id>`) | kırmızı + lacivert + yeşil -> kırmızı (okunmamış) |
| Liste başlığı / arama | Kırmızı gölgeli dolgulu "+" + çerçeveli arşiv dairesi | Arşiv ve "+" düz 24 dp çizgi ikon (Stitch), arama 52 dp `bdStrong` çerçeve | 2 kırmızı -> 0 (tek birincil eylem boş durum düğmesi) |
| Liste kaydırma eylemi / iskelet / boş | Lacivert arka plan + kırmızı daire; kartlı iskelet; boş/arşiv/eşleşme yok durumlarında ikinci açıklama cümlesi | Nötr zeminde simge + kısa etiket; kartsız satır iskeleti; tek cümle + tek eylem | kırmızı + lacivert -> nötr |
| Yeni sohbet | Her kişi satırı kart; eylem kartlarında renkli karo + yuvarlak ok; her satırda kırmızı tonlu "Sohbet başlat" hapı + simge; bilgi satırı simgesi; kırmızı noktalar; kart içinde kart (seçilen/ad kartları) | Kartsız satır, nötr karo, düz ok, nötr hap (simgesiz), kenar 20 dp, bölüm başlığı sade | soft kırmızı x N + renkli karolar -> nötr (birincil: "Grup oluştur") |
| Rehberden kişi bul | `t.tint` renkli karo; büyük başlık kartı + kırmızı simge; 112 dp durum kartı | Düz arama alanı, kartsız satırlar/iskelet, 80 dp sade durum | çok renkli -> nötr |
| Konuşma üst çubuğu | `titleLarge`, avatar sağ uçta (daire), dikey üç nokta, gölge | 64 dp, geri + 40 dp squircle avatar (listeyle aynı `ChatlistAvatar`, Hero) + ad (`titleMedium` w600) + durum (w400) + yatay üç nokta; gölge yerine alt 1 dp `bd` çizgi | - |
| Konuşma gövdesi | Boş sohbette ikinci açıklama cümlesi; tarih hapı zemin `sf2`; liste kenarı 16 | Tek cümle; tarih hapı dolu yüzey + 1 dp çizgi; kenar 20 dp | - |
| Balonlar | Grupta kişi başına renkli gönderen adı; yanıt alıntısında yeşil/kırmızı çizgi; seçili tepkide 1.4 dp kırmızı çerçeve | Gönderen adı nötr (`mut` w600), alıntı çizgisi nötr, tepki hapı yumuşak zemin (çerçevesiz, tabular sayı) | çok renkli -> nötr (giden balon kırmızı kaldı) |
| "En alta in" düğmesi | Anında belirir, gölge | 150 ms solma + %80->%100 ölçek (AnimatedSwitcher), gölgesiz, kenar 20 dp | - |
| Giriş çubuğu | 48 dp kırmızı gölgeli Gönder her zaman görünür; yanıt çubuğunda üç kırmızı öğe | Tek "+" (44 dp beyaz yuvarlatılmış kare, menü açıkken 45 derece dönüp "x"), 24 dp hap metin alanı (1-5 satır), Gönder (44 dp kırmızı yuvarlatılmış kare, yukarı ok) YALNIZ metin varken belirir (ölçek+solma 150 ms, basınca küçülür; 2000 sınırı aşılınca soluk + devre dışı); üstte 1 dp `bd` çizgi, gölge yok | 2 kırmızı -> 1 (yalnız yazınca) |
| "+" menüsü (yeni, `24_arti_menusu`) | Eski: doğrudan tam ekran galeri | Alt sayfa: Galeri + Kamera 100 dp karoları (`bg` + 1 dp `bd`, 16 dp köşe), "Son fotoğraflar" + `pr` "Tümü", 72 dp şerit (en çok 10), tek gösterimlik ipucu; izin yoksa tek satır + `pr` "İzin ver" (menü açılırken izin İSTENMEZ) | nötr + kırmızı (Tümü) |
| Galeri seçici (`4_galeri`) | 4 sütun, kare köşe; "İleri" hapı + alt "Önizle (n)" çubuğu; bilgi kutusu; lacivert kamera karosu | 3 sütun, 2 dp aralık, 10 dp köşe; ilk karo Kamera (`sf2`); seçili: 3 dp `pr` çerçeve + %15 kararma + 22 dp dolu daire (sayı; tekil seçimde onay işareti), kare %94 küçülür; üstte `pr` "Gönder (n)" metni; alt çubuk yok, altta düz 12 sp not | lacivert + kırmızı -> kırmızı (seçim) |
| Sohbet arka planı (yeni, `00_duvar_kagidi`) | Düz zemin | VARSAYILAN: Stitch "Kampüs doodle" duvar kağıdı varlık olarak (`assets/chat_wallpapers/wp_a_light|dark.png`, 1170x2532, ~115 KB, `BoxFit.cover`, `cacheWidth` = genişlik x dpr, ayrı `RepaintBoundary`, kaydırmada sabit, 150 ms solarak gelir, yüklenemezse düz zemin); yalnız mesaj alanının arkasında (üst çubuk, yazma alanı düz); kişi/grup/kulüp/etkinlik odalarının hepsinde; Hafif/Orta = yordamsal `ink` %4.5/%11 doku (tek sefer üretilir, önbellek), Düz; tercih cihazda, çıkışta silinir (`registerUserDataCleaners`) | nötr |

Uygulanmayanlar / sapmalar (Stitch v3 `C:u_design\stitch3_chat\`): (1) yapışkan tarih başlığı: ters sıralı liste + yapışkan başlık davranış katmanına dokunmadan güvenilir yapılamadı; (2) gönderilirken ince ilerleme: görünüm katmanında gönderim durumu yok; (3) "Sohbet arka planı" ekranı Stitch'teki segment + Uygula düzeninde DEĞİL: Desen / Hafif / Orta / Düz seçenek satırları + canlı önizleme (anında uygulanır); (4) Stitch 20-23 giriş durumları (balon altında saat, 14 dp balon) ile 01 (saat balon içinde) çelişir: ana referans 01 uygulandı; (5) sohbet bilgisi/üyeler/medya (`5_bilgi`), mesaj menüsü/ilet (`30-32`), arşiv ve yeni sohbet kişi satırı ayırıcıları bu turda Stitch'e göre yeniden çizilmedi (yalnız minimal sadeleştirme + 16 dp kenar); (6) Stitch artıkları (profil dairesi, uydurma etiketler, kamera düğmesi, bilgi bandı) uygulanmadı.

Testler: `p3chat_test.dart`, `p3chat_bg_test.dart`, `p3chat_input_test.dart` (+ güncellenen k6/media_picker/chat_extras/chat_status_video/p2dc/pages_b/a15); ilgili 17 dosya 360 test yeşil, `flutter analyze lib` bu alandan 0 sorun. Ekran görüntüleri: `C:/bu_qa/shots/tasarim/chat_bg/` (ref, onceki, sonra, liste).
