# 11 - Gönderi menüleri, diyaloglar ve kullanıcı gönderileri

## Kapsam
- Envanter A7 gönderi ⋯ menü katmanı, A8 metin düzenleme, A9 silme onayı, 91 `UserPostsPage` (+ boş/hata, gönderi bulunamadı); engelleme onayı A10 için `51-ortak-sheetler.md`

## Istem
```text
Design 6 separate mobile screens. Background of screens 1-5 is the Keşfet two-column masonry grid of photo cards (each card: photo, tiny author name, heart + count) dimmed by a scrim.

1) Post menu overlay for MY OWN post. The selected card is lifted above the scrim; next to it a floating white menu card with rows: "Düzenle" (pencil), "Sil" (trash, red). Nothing else.

2) Post menu overlay for SOMEONE ELSE'S post. Same lifted card; menu rows: "Profili gör", "Şikâyet et" (flag), "Bu kullanıcıyı engelle" (block icon, red).

3) Edit post text dialog (centered, rounded 28px). Title "Gönderiyi düzenle", multiline field with current caption "Bahar geldi kampüse", counter "4/7 kelime". Error state text under the field in red: "Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin." Buttons "Vazgeç" and "Kaydet". Small note "Metin boş olamaz." as another validation message example.

4) Delete confirmation dialog. Title "Gönderi silinsin mi?", body "Bu işlem geri alınamaz.", buttons "Vazgeç" and "Sil" (red). After success a snackbar example at bottom: "Gönderi silindi".

5) Report sheet for a post (bottom sheet) titled "Gönderiyi şikâyet et" with prompt "Sebep seçin. Şikâyetiniz yöneticilere iletilir." and radio rows "Spam veya reklam", "Taciz veya zorbalık", "Uygunsuz içerik", "Başkasını taklit", "Diğer"; optional field "Ek açıklama (isteğe bağlı)"; button "Gönder". Success toast "Şikâyetiniz alındı. Teşekkürler."

6) User's posts list (profile "Gönderilerim" / someone's posts), header "Gönderiler". 3-column photo grid with small heart counts. Below the grid a stacked empty-state card "Henüz gönderi yok" with camera illustration and button "Gönderi oluştur", and an error row "Yüklenemedi, tekrar dene". A skeleton post card (grey 4:5 block, two grey lines, grey heart) and a final small card "Gönderi bulunamadı" (deleted or hidden post state). Tapping a grid tile opens the single post page where double-tap like also works.
```

## Özellik kontrol listesi
- [ ] Kendi gönderi menüsü: Düzenle, Sil
- [ ] Başkasının menüsü: Profili gör, Şikâyet et, Bu kullanıcıyı engelle
- [ ] Düzenleme diyaloğu: sayaç, küfür hatası, boş metin hatası, Vazgeç/Kaydet
- [ ] Silme onayı + "Gönderi silindi" bildirimi
- [ ] Şikâyet sheet (5 neden, ek açıklama, Gönder, teşekkür)
- [ ] Kullanıcı gönderileri ızgarası, boş durum, hata satırı, gönderi iskeleti, silinmiş/gizlenmiş gönderi ("Gönderi bulunamadı")

## Dikkat
- Menüde "Kaydet", "Bağlantıyı kopyala", "Paylaş", "İlgilenmiyorum", "Bildirimleri aç" YOK.
- Şikâyet nedenleri yukarıdaki 5 madde; yeni neden uydurmasın.
