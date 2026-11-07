# 16 - Haber detayı varyantları ve bildirim boş/hata durumları

## Kapsam
- Envanter 42 `NewsDetailPage` (etkinlik türü, görselsiz duyuru, favori, yükleniyor/hata), 38 `NotificationsPage` (boş, hata, sayfalama)

## Istem
```text
Design 5 separate mobile screens (no bottom nav).

1) News detail, type "Etkinlik", saved. Hero cover image with back arrow and two round icon buttons on it: bookmark (filled, tooltip "Favorilerden çıkar") and share ("Paylaş"). Green badge "Etkinlik", title "Üniversitemizde Kariyer Günleri Düzenleniyor", line "Etkinlik tarihi: 14 Kasım 2026", article body paragraphs, note "İçeriğin tamamı için kaynak sayfayı açın." and outlined button "Kaynak sayfada aç". Snackbar example at bottom: "Haber bağlantısı kopyalandı."

2) News detail, type "Duyuru" without cover image. Plain header with back arrow, amber badge "Duyuru", title, publish date "26 Ekim 2026", text body, button "Kaynak sayfada aç". Red inline message under the button: "Bağlantı açılamadı." Bookmark outline (tooltip "Favorilere ekle").

3) News detail loading and error. Top half: skeleton (grey image block, grey title lines). Bottom half: error card "Bir şeyler ters gitti" with "Yeniden dene".

4) Bildirimler empty. Header "Bildirimler", filter chips "Tümü | Okunmamış". Bell illustration and "Henüz bildiriminiz yok". Below, the unread-filter empty variant text: "Okunmamış bildirimin yok".

5) Bildirimler error and end of list. Top: error card "Yüklenemedi, tekrar dene" with "Yeniden dene". Bottom of a long list: loading spinner row (more pages loading) and final text "Hepsi bu kadar".
```

## Özellik kontrol listesi
- [ ] Haber detay: kapak, favori (dolu/boş), paylaş, tür rozeti, etkinlik tarihi, metin, "Kaynak sayfada aç", bağlantı kopyalandı, bağlantı açılamadı
- [ ] Görselsiz duyuru düzeni
- [ ] Yükleniyor iskeleti ve hata
- [ ] Bildirimler: boş, okunmamış boş, hata, sayfalama, "Hepsi bu kadar"

## Dikkat
- Haber detayında yorum, beğeni, "ilgili haberler", yazar kartı yok.
- Haber metni uzun uydurma resmi açıklamalar olmasın; 3-4 kısa paragraf.
