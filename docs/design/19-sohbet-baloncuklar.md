# 19 - Sohbet konuşması: mesaj baloncukları ve mesaj durumları

## Kapsam
- Envanter 47 `ChatDetailPage` / `MessageBubble`: yanıt önizlemesi, "düzenlendi", herkes için silindi, yönetici kaldırdı, emoji tepkileri, durum tikleri, fotoğraf/video mesajı, tek gösterimlik, gönderilemedi, çevrimdışı kuyruk

## Istem
```text
Design 6 separate mobile screens of the open chat conversation (no bottom nav). Each shows the chat header (back arrow, avatar, name, status line) and the message composer at the bottom ("Mesaj yaz", attach "+" button, camera, send). My bubbles are red (#C62A20) with white text on the right; others are white on the left. Date separator pills like "Bugün", "Dün".

1) Direct chat, text features. Show: a reply bubble with a quoted block (left colored bar, sender "Mehmet", quoted text "Yarın sınav kaçta?") above the reply "Saat 10.00'da"; a message with tiny grey label "düzenlendi"; my messages with status ticks and time: one "Gönderiliyor" (clock), one "Gönderildi" (single tick), one "İletildi" (double grey tick), one "Okundu" (double blue-white tick).

2) Group chat. Other senders show a colored name above the bubble ("Ahmet Demir", "Zeynep Arslan") and avatar. Emoji reaction chips under bubbles (small pill: 👍 3, ❤️ 1; my own reaction highlighted with soft-red outline). A grey italic bubble "Bu mesaj silindi" (deleted for everyone) and another "Bu mesaj yönetici tarafından kaldırıldı".

3) Media messages. A photo bubble with rounded corners, timestamp over the image, caption below; a video bubble with a centered white play button and duration chip "0:42" top-left; a photo being uploaded with a circular progress ring and up-arrow; a bubble "Fotoğraf yükleniyor…" placeholder.

4) View-once photos. Received locked bubble: dark rounded tile with a "1" in a dashed circle icon, "Fotoğraf · Açmak için dokun", button "Görüntüle". An opened one: grey pill "Fotoğraf · Açıldı". My sent one: "Fotoğraf · Gönderildi" pill.

5) Failure and offline. My bubble in error style (red outline) with text under it "Gönderilemedi · Yeniden dene". Top amber strip "2 mesaj bağlantı gelince gönderilecek". Another bubble with status "Bekliyor". Banner at the very top: "İnternet bağlantısı yok".

6) Closed conversation. Messages above; instead of the composer a grey banner "Bu sohbet yönetici tarafından kapatıldı." Also a small floating round button "En alta in" with a red badge "3 yeni mesaj".
```

## Özellik kontrol listesi
- [ ] Yanıt önizlemesi (alıntı bloğu)
- [ ] "düzenlendi" etiketi
- [ ] Durum tikleri: Gönderiliyor / Gönderildi / İletildi / Okundu
- [ ] Gönderen adı + avatar (grup), renkli ad
- [ ] Emoji tepki çipleri, kendi tepkim vurgulu
- [ ] Herkes için silindi baloncuğu ("Bu mesaj silindi"), yönetici kaldırdı
- [ ] Fotoğraf baloncuğu, yükleme halkası, video baloncuğu (oynat + süre)
- [ ] Tek gösterimlik: kilitli / açıldı / gönderildi
- [ ] Gönderilemedi · Yeniden dene; çevrimdışı kuyruk şeridi
- [ ] Kapalı sohbet bandı (yazma alanı yok)
- [ ] Tarih ayırıcılar; "En alta in" + yeni mesaj sayacı

## Dikkat
- Sesli mesaj (mikrofon düğmesi), GIF/çıkartma, konum paylaşımı, "görüldü" avatarları, canlı konum YOK.
- Okundu tiki mavi değil; kırmızı baloncuk üstünde beyazımsı çift tik olabilir.
- Mesaj yazma alanı: yalnızca metin, "+" (medya) ve kamera; mikrofon yok.
