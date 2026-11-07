# 26 - Sohbet: tam ekran görsel, video ve tek gösterimlik görüntüleyiciler

## Kapsam
- Envanter 48 `ChatMediaViewer`, 49 `ChatVideoPlayerPage`, 50 `ViewOnceViewer`, 51 `ChatImageViewer`

## Istem
```text
Design 6 separate full-screen mobile screens on black backgrounds (no bottom nav).

1) Image viewer. Black background, photo centered, top bar with close "x" (left), page indicator "2 / 5" (center) and a download icon "İndir" (right). Thin thumbnail dots bottom. Swipe hint implied by neighbor edge.

2) Image viewer feedback. Photo zoomed in (pinch scale ~2x, partly cropped). Bottom dark toast "Galeriye kaydedildi". Error variants as stacked small text on the dark overlay: "Görsel kaydedilemedi.", "Galeri izni verilmedi.", "Cihazda yeterli alan yok.", "Görsel yüklenemedi."

3) Video poster page inside the viewer. Poster frame with a large white circular play button "Videoyu oynat" and duration chip "0:42", same top bar with "3 / 5".

4) Video player playing. Full-screen video frame, tap-to-pause overlay with pause icon, bottom progress bar with elapsed "0:18" and total "0:42", close "x" top-left.

5) Video player failed. Black screen, centered icon, text "Video oynatılamadı", button "Yeniden dene", close "x".

6) View-once photo. Black background, the photo centered, top bar with close "x" and a small pill "Tek gösterimlik" with the "1" icon, bottom caption "Bu fotoğrafı yalnızca bir kez görebilirsin." Below it stacked state texts: "Bu fotoğraf artık görüntülenemez.", "Kendi gönderdiğiniz tek gösterimlik fotoğrafı açamazsınız.", "Fotoğraf yüklenemedi. Bağlantınızı kontrol edin. Tek gösterimlik olduğu için yeniden açılamayabilir."
```

## Özellik kontrol listesi
- [ ] Görsel görüntüleyici: kapat, sayfa göstergesi, indir, yatay gezinme, yakınlaştırma
- [ ] Kaydetme sonucu: Galeriye kaydedildi + hata metinleri (izin, alan, kaydedilemedi, yüklenemedi)
- [ ] Video poster sayfası (oynat + süre)
- [ ] Video oynatıcı: otomatik oynat, dokununca durdur, ilerleme çubuğu, süre
- [ ] Oynatılamadı + Yeniden dene
- [ ] Tek gösterimlik: kopyala/kaydet/paylaş YOK, tüketildi, kendi gönderdiğim, ağ hatası

## Dikkat
- Tek gösterimlik görüntüleyicide indir/kaydet/paylaş düğmesi olmamalı (yalnız kapat).
- Beğeni, yorum, "ilet" düğmesi görüntüleyicide yok.
- "Ekran görüntüsü uyarısı" gibi metin uydurmasın.
