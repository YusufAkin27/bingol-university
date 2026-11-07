# 25 - Sohbet: galeri seçici, önizleme, kamera ve video hazırlama

## Kapsam
- Envanter 55 `MediaPickerPage`, 56 `MediaPreviewPage`, 57 `MediaCameraPage`, A13 video hazırlanıyor penceresi, A24 albüm seçici, A25 ortak alt sayfa çerçevesi
- Kırpma/döndürme düzenleme ekranı: `09-fotograf-kirpma.md` ekran 5

## Istem
```text
Design 6 separate mobile screens (no bottom nav).

1) Gallery picker. Header: close "x", centered album dropdown "Son eklenenler" with chevron, right "İleri". Square 4-column photo/video grid; first tile is a camera tile "Kamera". Selected tiles show red numbered circles (1, 2, 3) and a dim overlay; videos show duration chips "0:23". Bottom bar: "3 / 10 seçildi" and button "Önizle (3)". Note under header: "En fazla 10 öğe seçebilirsiniz. Video en fazla 60 saniye olabilir."

2) Gallery picker, limited and denied access. Top block (limited): grid with note "Yalnızca izin verdiğin öğeler görünüyor." and buttons "Daha fazla seç", "Ayarlar". Bottom block (denied): illustration, text "Galeriye erişim izni verilmedi." and button "Ayarlardan aç".

3) Album bottom sheet. Title "Albüm". Rows with thumbnail, name, count: "Son eklenenler", "Kamera", "Ekran görüntüleri", "İndirilenler". Selected album has a check.

4) Preview before sending. Dark background, large current photo, page dots "1 / 3", thumbnail strip at the bottom with the current one outlined, caption field "Açıklama ekle…", pill toggle "Tek gönderimlik" (with small "1" icon and toast text "Tek gönderimlik: alıcı yalnızca bir kez görebilir"), round red send button with label "3 öğeyi gönder".

5) Camera. Full-screen viewfinder, top: close, "Flaş" toggle; bottom: gallery shortcut, big white shutter ring, flip button "Kamerayı çevir". Hint "Dokun: fotoğraf · Basılı tut: video". Second state: recording with red timer "0:12 / 1:00", shutter ring filling red and "Kaydı durdur".

6) Video preparing dialog and errors. Centered dialog over the preview: linear progress, title "Video hazırlanıyor… %45", button "İptal". Under it error toasts stacked: "Video en fazla 60 saniye olabilir", "Video çok büyük, daha kısa bir video seçin", "Videolar büyük olduğu için birden fazla mesaj olarak gönderilecek".
```

## Özellik kontrol listesi
- [ ] Galeri ızgarası, ilk karo kamera, sayılı çoklu seçim, video süre çipi, 10 öğe ve 60 sn sınırı notu
- [ ] Sınırlı erişim notu + Daha fazla seç + Ayarlar; izin yok durumu
- [ ] Albüm seçici sheet
- [ ] Önizleme: sayfa sayfa gezme, küçük resim şeridi, açıklama, Tek gönderimlik, "N öğeyi gönder"
- [ ] Kamera: dokun=fotoğraf, bas-tut=video, sayaç, flaş, çevir, kaydı durdur
- [ ] Video hazırlama penceresi (ilerleme + İptal), boyut/süre hataları, çoklu mesaja bölme uyarısı
- [ ] Düzenleme (döndür/kırp): `09-fotograf-kirpma.md`

## Dikkat
- Filtre, çıkartma, çizim, metin kaplama, müzik, GIF yok.
- Albüm adlarında üçüncü taraf uygulama markası kullanmasın.
- Videoda 60 sn sınırı vardır; gönderide video yok (bu yalnız sohbet).
