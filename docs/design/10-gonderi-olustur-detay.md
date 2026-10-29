# 10 - Gönderi oluşturma ve gönderi detayı

## Kapsam
- Envanter 39 `ComposePostPage` (+ A6 vazgeç onayı), 40 `PostDetailPage`
- Kırpma akışı (seç -> 4:5 kırp -> önizleme -> paylaş) bkz. `09-fotograf-kirpma.md`

## Istem
```text
Design 6 separate mobile screens (no bottom nav). A post is exactly ONE photo plus an optional short caption (max 7 words, 60 characters) and likes. No comments, no video, no hashtags.

1) New post, empty. Top bar: close "x", title "Yeni gönderi", right button "Paylaş" (disabled grey). Large dashed 4:5 placeholder with camera icon and two buttons "Galeriden seç" and "Fotoğraf çek". Helper "Gönderi tek bir fotoğraftan oluşur." Caption field "Kısa bir not ekle (isteğe bağlı)" with counter "0/7 kelime".

2) New post, photo chosen and cropped to 4:5. Photo fills the placeholder with two small overlay buttons: "Fotoğrafı değiştir" and a crop icon "Yeniden kırp". Caption "Kütüphane önünde güzel bir gün" with counter "5/7 kelime". "Paylaş" active red.

3) New post, validation and sending states on one filled screen: counter turns red "8/7 kelime" with message "En çok 7 kelime yazabilirsin."; below a profanity error card "Bu alanda uygunsuz ifade kullanılamaz. Lütfen metni düzenleyin."; a rate-limit line "Çok hızlı paylaşım yapıyorsun, biraz bekle."; network line "Bağlantı yok, tekrar dene."; the "Paylaş" button shown in busy state. Also a hint when no photo: "Paylaşmak için bir fotoğraf seç."

4) Discard confirmation dialog over dimmed screen 2. Title "Gönderiden vazgeçilsin mi?", body "Seçtiğin fotoğraf ve yazdıkların silinecek.", buttons "Devam" (primary) and "Vazgeç" (danger text).

5) Post detail of someone else's post. Header "Gönderi" with back arrow. Large 4:5 photo with rounded corners. Author row: avatar, "Mehmet Kaya", department "Makine Mühendisliği", time "2 sa önce"; right "⋯" menu button. Heart outline with count "128". Caption "Bahar geldi kampüse". Tiny grey "düzenlendi" label. Double-tap on the photo likes it: show the moment with a large white heart (about 88px, soft shadow) centered on the photo, photo slightly dimmed, and the small heart below already red with count "129".

6) Post detail of my own post. Same layout, heart filled red (liked), count "129", caption, "⋯" menu. Pull-to-refresh indicator at the top. This is the same detail page opened from a profile photo grid tile (back arrow returns to the grid); the like button and double-tap behave exactly as in screen 5. NO comment icon or comment count anywhere.
```

## Özellik kontrol listesi
- [ ] Boş oluşturma: fotoğraf alanı (Galeriden seç, Fotoğraf çek), tek-fotoğraf ipucu, 0/7 kelime sayacı
- [ ] Kırpılmış fotoğraf: Fotoğrafı değiştir, yeniden kırp, sayaç, Paylaş etkin
- [ ] Doğrulama: kelime sınırı, küfür 422 hatası, hız sınırı, ağ hatası, fotoğraf zorunlu, Paylaş meşgul
- [ ] Vazgeç diyaloğu (Devam / Vazgeç)
- [ ] Detay: büyük fotoğraf, yazar (avatar, ad, bölüm), zaman, "düzenlendi", beğeni kalbi + sayı, kısa metin
- [ ] Kendi gönderim: beğenilmiş kalp, "⋯" menü düğmesi; başkası: aynı menü
- [ ] Fotoğrafa çift dokunma: ortada büyük beyaz kalp animasyon anı
- [ ] Profil ızgarasından açılan detay aynı davranış (geri ok ızgaraya döner)
- [ ] Yenilemek için çekme

## Dikkat
- Yorum alanı, yorum sayısı, paylaş/gönder ok simgesi, kaydet yer imi, video oynat simgesi YOK.
- Konum/etiket/kişi etiketleme alanı yok.
- Metin en çok 7 kelime; uzun paragraf yazmasın.
