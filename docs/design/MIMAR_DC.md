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
