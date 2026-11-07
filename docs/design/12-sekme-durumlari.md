# 12 - Keşfet, Kulüpler, Profil sekme durumları

## Kapsam
- Envanter 33 `DiscoverTab`, 35 `ClubsTab`, 36 `ProfileTab` için yükleniyor / boş / hata durumları (normal görünümler referans tasarımda var)

## Istem
```text
Design 6 separate mobile screens, all with the floating bottom navigation (5 tabs, the relevant tab selected).

1) Keşfet loading. Header "Keşfet", subtitle "Öğrencilerden gönderiler", round "+" compose button, search field "Gönderi veya kişi ara". Below: two-column masonry of grey shimmering skeleton cards of different heights (photo block + two text lines).

2) Keşfet empty. Same header. Centered illustration (camera) and text "Henüz gönderi yok. İlk gönderiyi sen paylaş!" with button "Gönderi oluştur".

3) Keşfet error and offline. Slim grey strip "İnternet bağlantısı yok · Kayıtlı veriler gösteriliyor"; centered error card "Sunucuya ulaşılamadı. Bağlantınızı kontrol edin." and button "Yeniden dene".
4) Kulüpler tab, "Kulüplerim" segment with no memberships. Header "Kulüpler", segmented control "Keşfet | Kulüplerim", search icon, "+" create-club button. Empty state: illustration and "Henüz hiçbir kulübe üye değilsin." with button "Tüm kulüpler".

5) Kulüpler tab search with no result. Search field contains "xyz", category chips row "Tümü" and others, message "Kulüp bulunamadı."

6) Profil tab loading and error. Top: grey skeleton avatar circle, name bar, stat bars; below grey skeleton grouped setting rows. A red-tinted error card on top of the list: "Yüklenemedi, tekrar dene" with "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] Keşfet: iskelet masonry, boş durum + CTA, hata + çevrimdışı şeridi
- [ ] Kulüpler: "Kulüplerim" boş durumu, arama sonuç yok ("Kulüp bulunamadı.")
- [ ] Profil: iskelet ve hata kartı + Yeniden dene
- [ ] Doğru sekme seçili, alt gezinme görünür

## Dikkat
- Boş durumlarda sahte gönderi/kulüp önermesin (boş kalmalı).
- Keşfet başlığında "Hikâyeler" şeridi YOK.
