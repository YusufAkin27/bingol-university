# 15 - Ana Sayfa, Yemek ve Bildirimler: durum ve özellik varyantları

## Kapsam
- Envanter 32 `HomeTab` (yükleniyor/hata/bakım/bayat/boş), 37 `MenuPage` (kcal, fotoğraflı/fotoğrafsız, puanlama, boş/bakım), 38 `NotificationsPage` (okunmamış süzgeci, kaydırarak sil)
- Normal görünümleri referans tasarımda var

## Istem
```text
Design 6 separate mobile screens.

1) Ana Sayfa loading, with floating bottom nav (Ana Sayfa selected). Greeting skeleton bar, grey search box, four grey quick-access tiles, a grey card for today's meal, a grey wide card for the featured event, two grey announcement rows. Shimmer style.

2) Ana Sayfa stale and empty. Amber strip "Kaynak site şu an ulaşılamıyor; veriler güncel olmayabilir." Greeting "Merhaba, Elif". Today's meal card shows "Bugün için liste yok". Event card shows "Yaklaşan etkinlik yok" with button "Etkinliklere göz at". Announcements area: "Henüz içerik yok." and a red retry row "İçerik yüklenemedi."

3) Yemek listesi (no bottom nav). Header "Yemek listesi". Horizontal day picker with weekday abbreviations and day numbers, today selected with soft-red pill. Label "BUGÜN · 29 Ekim". Card "Öğle yemeği" with a menu photo on top, then dish rows each with kcal on the right: "Mercimek çorbası 120 kcal", "Etli nohut 310 kcal", "Pirinç pilavı 280 kcal", "Cacık 70 kcal", "Meyve 60 kcal". Footer row "Toplam 840 kcal". Below a rating card "Bugünün menüsünü puanla" with 5 empty stars and text "Yıldıza dokunarak puanla".

4) Yemek listesi without photo and with missing kcal. Card with a plain tinted utensils illustration instead of a photo. Dishes: "Kuru fasulye 290 kcal", "Bulgur pilavı 260 kcal", "Turşu -" (no kcal shown as dash). Footer "En az 550 kcal" with small info text "Bazı yemeklerin kalorisi girilmemiş". Rating card after voting: 4 filled stars, "Puanınız: 4 · Ortalama 4,2".

5) Yemek listesi empty and stale. Day with no list: illustration and "Yemek listesi yok." Amber note above: "Yemek listesi güncellenemedi; son bilinen liste gösteriliyor." Maintenance variant text "Sistem bakımda."

6) Bildirimler with unread filter (no bottom nav). Header "Bildirimler", right text button "Tümünü okundu yap". Filter chips "Tümü | Okunmamış" (Okunmamış selected). Group headers "BUGÜN", "DÜN", "DAHA ESKİ". Rows: unread dot, circular type icon with label "Etkinlik", "Sohbet", "Kulüp", "Anket", "Duyuru", title, one-line body, time "5 dk". One row is swiped left revealing a red "Sil" action. Hint at bottom: "Silmek için bildirimi sola kaydır".
```

## Özellik kontrol listesi
- [ ] Ana Sayfa iskelet; bakım/bayat şeridi; "Bugün için liste yok"; "Yaklaşan etkinlik yok" + "Etkinliklere göz at"; "Henüz içerik yok." ve içerik hata satırı
- [ ] Yemek: gün seçici, BUGÜN etiketi, fotoğraflı menü kartı, yemek satırı + kcal, toplam kcal
- [ ] Yemek: fotoğrafsız kart, kalorisi girilmemiş yemek ("-"), "En az N kcal", puanlama (boş yıldız / verilmiş + ortalama)
- [ ] Yemek: liste yok, bayat uyarısı, bakım
- [ ] Bildirimler: Tümü/Okunmamış süzgeci, Tümünü okundu yap, tarih grupları, okunmamış noktası, tür simgesi/etiketi, sola kaydır -> Sil, ipucu

## Dikkat
- Yemek ekranında ödeme, bakiye, "kart bakiyesi", yemek rezervasyonu/sipariş YOK.
- kcal değerleri yönetici girer; makro (protein/karbonhidrat) tablosu uydurma.
- Ana Sayfa'da hava durumu, döviz, namaz vakti, "Resmi" rozeti yok.
