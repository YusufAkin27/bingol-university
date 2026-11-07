# 06 - İzin sayfası ve QR yoklama tarayıcı

## Kapsam
- Envanter 13 `PostLoginGate` (kapı), 14 `PermissionsPage`, 19 `QrScanPage`, alt sayfa A1 (izin reddedildi -> ayarlara git)

## Istem
```text
Design 6 separate mobile screens (no bottom nav).

1) Permissions intro, shown once after first login. Back-less screen. Title "Birkaç izin". Intro "Uygulamayı en iyi şekilde kullanabilmeniz için aşağıdaki izinleri isteriz. Hiçbirini şimdi vermek zorunda değilsiniz; sonradan Ayarlar'dan da değiştirebilirsiniz." Three-part progress bar and text "Adım 1 / 3". Three stacked cards, each with icon tile, title, one line and its own buttons: "Bildirimler" - "Mesaj, etkinlik ve duyurulardan anında haberdar olmak için." ; "Rehber" - "Rehberinizdeki üniversite kişilerini bulup sohbet başlatmanız için. Rehberiniz sunucuya gönderilmez." ; "Kamera ve galeri" - "QR kod okutmak, fotoğraf çekmek ve paylaşmak için." Each card has "İzin ver" (primary small) and "Şimdi değil" (text). Bottom: "Başla".

2) Same page, mixed results. Card 1 shows green pill "Verildi" with check. Card 2 shows red-tinted pill "Reddedildi" with "Tekrar dene" and "Ayarlardan aç" buttons. Card 3 not yet answered. Progress "Adım 3 / 3". Bottom primary "Devam".

3) Bottom sheet over dimmed screen: icon, title "Kamera izni verilmedi" text "Kamera izni verilmedi, bu yüzden bu özellik kullanılamıyor. İzni Ayarlar > BÜ Kampüs bölümünden açabilirsiniz." Buttons "Ayarlardan aç" (primary) and "Kapat" (text).

4) QR scanner, camera granted. Dark full-screen camera preview, rounded white corner marks around a square scan area, hint "QR kodunu çerçevenin içine getir". Top bar: back arrow, title "QR kodu tara", torch icon "El feneri". Bottom light panel with note "Yoklama etkinlik saatinde açılır. Organizatörün gösterdiği kodu okut.", divider "veya", text field "Kodu elle gir" with hint "Örn. K7M4QX", button "Yoklamayı gönder".

5) QR scanner, camera permission denied. Light background, camera-off illustration, text "Kamera izni verilmedi. Kodu elle girebilir ya da izin verip taramayı yeniden deneyebilirsiniz." Buttons "Kamera izni ver" and below the manual code field "Kodu elle gir" + "Onayla".

6) QR manual entry result states on the scanner panel: field value "K7M4QX" with red error text "Bu kod başka bir etkinliğe ait." and next to it a green success toast card "Yoklaman alındı" with check (show both as two stacked feedback examples above the field).
```

## Özellik kontrol listesi
- [ ] İzin sayfası: 3 kart (Bildirimler, Rehber, Kamera ve galeri), her kartta ayrı "İzin ver"/"Şimdi değil"
- [ ] 3 parçalı ilerleme + "Adım n / 3"
- [ ] Durum rozetleri: Verildi / Reddedildi
- [ ] "Tekrar dene", "Ayarlardan aç", "Devam", "Başla"
- [ ] Reddedildi alt sayfası (Ayarlardan aç, Kapat)
- [ ] QR: kamera önizleme, köşe işaretleri, ipucu, el feneri, bilgi notu
- [ ] QR: elle kod girişi her zaman ekranda (Örn. K7M4QX), "Yoklamayı gönder"
- [ ] QR: izin yok durumu + "Kamera izni ver"
- [ ] QR sonucu: başarı ("Yoklaman alındı") ve hata ("Bu kod başka bir etkinliğe ait." / "Bu bir yoklama kodu değil.")

## Dikkat
- QR yalnızca etkinlik yoklaması içindir; ödeme/kimlik/yemekhane QR'ı uydurmasın.
- İzin kartında konum, Bluetooth, mikrofon kartı eklemesin (mikrofon yalnız video çekerken sistem izni olarak istenir, bu sayfada yok).
- Rehberin sunucuya gönderilmediği cümlesi korunmalı.
