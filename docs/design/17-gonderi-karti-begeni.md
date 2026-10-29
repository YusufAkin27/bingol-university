# 17 - Gönderi kartı: beğeni, çift dokunma ve menü varyantları

## Kapsam
- Envanter 33 `DiscoverTab` ve 40 `PostDetailPage` içindeki gönderi kartı (`PostCard`, `LikeButton`, `DoubleTapLike`), A7 menü; aynı kart tek-gönderi sayfasında ve profil ızgarasından açılan detayda da kullanılır
- Mevcut mobil kodda bulunanlar: kalp doldurma animasyonu (ölçek 1 -> 1.38 -> 1), kalp çevresinde küçük nokta patlaması, sayaç artışı, hafif titreşim, iyimser güncelleme (250 ms birleştirme, hata olursa geri alma), fotoğrafa çift dokunma ile beğeni (ortada büyük beyaz kalp). Beğenen kişiler listesi YOK (sunucu uç noktası kaldırıldı); yorum YOK.

## Istem
```text
Design 6 separate mobile screens, each showing the SAME full-width post card (white card, 20px radius) on a light grey page with a "Gönderi" header and back arrow (no bottom nav). Card anatomy: author row (avatar, name, department, relative time), a 4:5 photo, then below the photo only: a heart icon with like count, and the caption (max 7 words). There is NO comment icon, NO comment count, NO share, NO bookmark.

1) Not liked. Author "Mehmet Kaya", "Makine Mühendisliği", "2 sa önce". Grey outline heart with "127". Caption "Bahar geldi kampüse". Right of the author row a "⋯" button.

2) Liked, animation moment. Heart is filled red and slightly enlarged (about 1.4x), a ring of 8 tiny red dots bursts around it, count shows "128" with a small upward count-change feel (old number fading).

3) Double-tap on the photo. The photo is slightly dimmed and a big white heart (about 88px, soft dark shadow, slightly scaled up) appears in the exact center of the photo. The small heart under the photo is already red, count "128". No other overlay.

4) Undo like and error. Heart back to grey outline, count "127" (decreased). A bottom snackbar example: "Beğeni kaydedilemedi" in warning style (shown when the server call fails and the heart returns to its previous state).

5) My own post with the menu open. Author row shows me ("Elif Yıldız"), small label "düzenlendi". A white dropdown card from the "⋯" button with two rows: "Düzenle" (pencil), "Sil" (trash, red). Heart red filled "129".

6) Someone else's post with the menu open. Dropdown rows: "Profili gör", "Şikâyet et" (flag), "Bu kullanıcıyı engelle" (block, red). Place a loading skeleton card (grey avatar circle, grey 4:5 block, grey heart + count bar) below it on the same screen.
```

## Özellik kontrol listesi
- [ ] Beğenilmemiş kart (gri çizgi kalp + sayaç)
- [ ] Beğenilmiş kart (kırmızı dolu kalp)
- [ ] Beğeni animasyon anı: kalp büyür, çevresinde küçük nokta patlaması, sayaç artar
- [ ] Çift dokunma anı: fotoğraf ortasında büyük beyaz kalp (gölgeli), fotoğraf hafif kararır
- [ ] Beğeniyi geri alma: sayaç azalır, kalp çizgiye döner
- [ ] Beğeni kaydedilemedi (iyimser geri alma) bildirimi
- [ ] Kendi gönderim: "⋯" Düzenle / Sil; "düzenlendi" etiketi
- [ ] Başkasının gönderisi: Profili gör / Şikâyet et / Bu kullanıcıyı engelle
- [ ] Yükleniyor iskelet kartı
- [ ] Silinmiş/gizlenmiş gönderi durumu: `11-gonderi-menuleri-ve-liste.md` ekran 6
- [ ] Yorum simgesi/sayacı hiçbir yerde yok
- [ ] Aynı davranış tek-gönderi sayfasında ve profil ızgarası detayında: `10-gonderi-olustur-detay.md` ekran 5-6

## Dikkat
- YORUM yok: sayaç, ikon, "Yorum yaz" alanı, "Tüm yorumları gör" bağlantısı eklemesin.
- "Beğenenler" listesi/alt sayfası yok; sayaç dokunulabilir bir liste açmaz.
- Çift dokunma kalbi beyazdır (kırmızı değil); küçük kalp kırmızıdır.
- Paylaş/gönder oku, kaydet yer imi, video oynat simgesi yok.
