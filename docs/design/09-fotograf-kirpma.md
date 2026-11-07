# 09 - Fotoğraf kırpma ekranları (YENİ mobil özellik)

> Kodda şu an hiçbir kırpma ekranı yok (kullanıcı isteği: "belli formatta tek kırpılacak"). Bu istem yeni bir özelliği tasarlatır; ayrıntı ve backend notu `EKSTRA-backend.md` içinde.

## Kapsam
- Yeni: Profil fotoğrafı (envanter 94 `EditProfilePage` avatar akışı, A54), Gönderi fotoğrafı (39 `ComposePostPage`), Kulüp logosu (62 `ClubFormPage`), Kulüp/etkinlik kapağı (62, 75 `EventFormPage`, A38), Sohbet görseli (56 `MediaPreviewPage`), Kaynak seçimi alt sayfası + izin reddi (A54, A38, A23, A1)

## Istem
```text
Design 6 separate mobile screens for a new photo-cropping feature (no bottom nav). Flow everywhere: pick photo -> crop -> preview -> save. Crop editors use a dark full-screen canvas with the photo, a fixed-ratio white frame with rounded corner handles, a rule-of-thirds grid, a dimmed outside area, pinch-to-zoom and drag hint text "Sürükle ve yakınlaştır".

1) Profile photo crop. Top bar: close "x", title "Fotoğrafı kırp". Under it a light panel "Profilde böyle görünecek" with a 96px circle preview and a 40px small avatar preview (same photo, updates live). Canvas: fixed 1:1 square frame, circular mask overlay. Toolbar icons with labels: "Döndür" (90 degrees), "Sıfırla". Zoom slider. Bottom buttons: "Vazgeç" (outline) and "Kaydet" (primary red).

2) Post photo crop. Title "Gönderi fotoğrafı". Canvas with fixed 4:5 portrait frame and 3x3 grid. Below the canvas a mini feed-card preview "Akışta böyle görünecek": small white card with author row (avatar, "Elif Yıldız"), the cropped 4:5 image, heart with "0" and a caption "Kütüphane önünde güzel bir gün". Single photo only, link "Fotoğrafı değiştir". Buttons "Vazgeç" and "Kırp".

3) Club logo crop. Title "Kulüp logosu". Fixed 1:1 frame with circular guide. Previews row: large circle with caption "Kulüp sayfası", small rounded square "Kulüp kartı" showing the club name "Robotik Kulübü". Buttons "Vazgeç" and "Kaydet".

4) Cover photo crop (club cover and event cover). Title "Kapak fotoğrafı". Fixed 16:9 landscape frame. Preview below: an event card with the cropped 16:9 cover on top, title "Bahar Şenliği", date chip "23 Mayıs", club name "Müzik Kulübü". Buttons "Vazgeç" and "Kaydet". Show a link "Kapağı kaldır" under the preview.

5) Chat image edit before sending (extends the chat media preview). Photo large on dark canvas, free (not locked) frame. Ratio chips row: "Orijinal" (selected) and "Serbest". Toolbar "Döndür", "Kırp". Below: caption field "Açıklama ekle…", toggle "Tek gönderimlik", small chat bubble preview of the result, send button "Gönder" (red circle).

6) Photo source bottom sheet over a dimmed edit screen. Handle bar, title "Fotoğraf", rows with icons: "Galeriden seç", "Fotoğraf çek", "Fotoğrafı kaldır" (danger color). A second card below shows the permission-denied state: "Galeri izni verilmedi." with "Ayarlardan aç" button, and an inline error "Fotoğraf en fazla 2 MB olabilir. Daha küçük bir fotoğraf seçin."
```

## Özellik kontrol listesi
- [ ] Profil: 1:1 sabit çerçeve, daire maske, canlı daire önizleme (96 px) + küçük avatar (40 px), sürükle/yakınlaştır, döndür, sıfırla, Vazgeç/Kaydet
- [ ] Gönderi: 4:5 dikey sabit çerçeve, 3x3 ızgara, akış kartı önizlemesi, tek fotoğraf, Fotoğrafı değiştir
- [ ] Kulüp logosu: 1:1, daire önizleme + kulüp kartı önizlemesi
- [ ] Kapak: 16:9 sabit çerçeve, etkinlik kartı önizlemesi, Kapağı kaldır
- [ ] Sohbet görseli: Orijinal/Serbest, döndür, kırp (isteğe bağlı), açıklama, Tek gönderimlik, gönderim önizlemesi
- [ ] Kaynak sheet: Galeriden seç / Fotoğraf çek / Fotoğrafı kaldır
- [ ] İzin reddi ve boyut hatası durumları
- [ ] Akış: seç -> kırp -> önizleme -> kaydet (başlıkta adım yok, sade)

## Dikkat
- Oranlar sabit: profil 1:1, gönderi 4:5, logo 1:1, kapak 16:9. Serbest oran yalnız sohbet görselinde.
- Filtre, çıkartma, metin ekleme, çizim, müzik eklememeli (yalnız kırp + döndür).
- Gönderi kırpmada çoklu fotoğraf/karusel ve video yok.
- Instagram/WhatsApp logosu veya markasını taklit etmesin.
