# 18 - Sohbet listesi: tüm satır türleri ve durumlar

## Kapsam
- Envanter 34 `ChatTab` (referansta yalnız mutlu yol var): okunmamış, sessiz, kulüp/etkinlik odası, kaydırarak arşivle, uzun basma menüsü, arşiv, boş, arama sonucu yok, iskelet, hata, çevrimdışı

## Istem
```text
Design 6 separate mobile screens of the Sohbet tab, all with the floating bottom nav (Sohbet selected, small red unread badge on its icon). Header: title "Sohbet", icon buttons "Arşiv" (archive box) and "Yeni sohbet" (+). Below: search field "Sohbetlerde ara", segmented chips "Tümü | Kişiler | Kulüpler | Etkinlikler".

1) Full list, 7 rows (avatar 52px, name, last-message preview, time on the right, badge). Row types: unread person chat (bold name and preview, red badge "3", time "14:32", green online dot on avatar); muted chat (small bell-off icon, grey badge "12"); read chat with preview "Sen: Tamamdır, yarın görüşürüz"; club room with small tag "Kulüp" and preview "Ahmet: Toplantı 18.00'de"; event room with tag "Etkinlik"; photo preview "Fotoğraf" with camera icon; deleted preview italic "Mesaj silindi"; time labels "Dün", "Pzt". Also a row where last message is "Video" and one "Fotoğraf (tek gösterimlik)".

2) One row swiped left revealing a coloured action area with archive icon and text "Arşivle" (the rest of the list unchanged).

3) Long-press menu: bottom sheet over dimmed list with the chat name as title and rows "Sessize al" (bell-off), "Arşivle" (archive), "Sil" (trash, red).

4) Archive view. Header "Arşiv" with back arrow. Two archived rows; a swipe action text "Çıkar". Below an empty variant text "Arşivde sohbet yok".

5) Empty states. Illustration with "Henüz sohbetiniz yok" and button "Yeni sohbet". Lower block: search typed "zzz" with the text "Eşleşen sohbet bulunamadı".

6) Loading, error and offline. Top strip "İnternet bağlantısı yok · Kayıtlı veriler gösteriliyor". Skeleton rows (grey avatar circle, two grey bars). Error card below: "Yüklenemedi, tekrar dene" with "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] Başlık, Arşiv ve Yeni sohbet düğmeleri, arama alanı, 4 segment (Tümü/Kişiler/Kulüpler/Etkinlikler)
- [ ] Okunmamış satır (kalın metin, kırmızı rozet, 99+), sessiz satır (zil-kapalı, gri rozet)
- [ ] Çevrimiçi noktası, Kulüp/Etkinlik etiketleri
- [ ] Son mesaj türleri: metin, "Sen: ...", Fotoğraf, Video, tek gösterimlik, "Mesaj silindi"
- [ ] Zaman biçimleri (saat, Dün, gün adı)
- [ ] Sola kaydır -> Arşivle; arşivde Çıkar
- [ ] Uzun basma menüsü: Sessize al / Arşivle / Sil
- [ ] Arşiv ekranı + "Arşivde sohbet yok"
- [ ] Boş liste + Yeni sohbet; arama sonucu yok
- [ ] İskelet, hata, çevrimdışı şeridi
- [ ] Alt gezinmede sohbet rozeti

## Dikkat
- Sabitlenmiş (pinned) sohbet, hikâye şeridi, sesli arama/görüntülü arama simgesi yok.
- "Gruplar" ayrı sekme değil; süzgeç adları tam olarak Tümü, Kişiler, Kulüpler, Etkinlikler.
