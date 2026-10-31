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
