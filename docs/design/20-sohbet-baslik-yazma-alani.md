# 20 - Sohbet konuşması: başlık, yazma alanı, arama ve oda türleri

## Kapsam
- Envanter 47 `ChatDetailPage` üst/alt bölümleri: çevrimiçi/yazıyor, kulüp ve etkinlik odası başlıkları, sohbette ara, yanıt/düzenleme modu, boş sohbet, çevrimdışı

## Istem
```text
Design 6 separate mobile screens of the open chat conversation (no bottom nav).

1) Direct chat header states. Header: back arrow, 40px avatar with green dot, name "Elif Yıldız", status line "yazıyor…" (typing, in red text). Below header a few messages and at the bottom the composer "Mesaj yaz". Second header example above it in the same screen: status "Çevrimiçi"; third: "Son görülme: bugün 14:20".

2) Club room chat. Header with club logo, name "Robotik Kulübü", subtitle "Kulüp odası · 86 üye", right "⋯" menu. Tiny pinned chip under the header "Kulüp sayfası". Group messages from several senders.

3) Event room chat. Header with calendar-tinted avatar, name "Bahar Şenliği", subtitle "Etkinlik odası · 42 üye", chip "Etkinlik sayfası".

4) Search in chat mode. Header replaced by a search field "Sohbette ara" with close "x". Matching words highlighted in yellow inside bubbles, a bar showing "2 / 5" with up and down arrows ("Önceki eşleşme", "Sonraki eşleşme"). Empty variants as text rows: "Aramak için yazın", "Aranıyor…", "Eşleşme yok", and a text button "Daha eski mesajlarda ara".

5) Composer modes. Above the text field a reply bar: left red bar, "Mehmet Kaya" and quoted text, close "x". Second variant stacked below: editing bar "Mesaj düzenleniyor" with close and a check send button. Composer buttons: "+" (Ekle), camera (Kamera), text field "Mesaj yaz", red circular send arrow "Gönder".

6) Empty conversation. Centered soft illustration with text "Henüz mesaj yok. İlk mesajı sen yaz." Composer at bottom. Also show a user-blocked variant line: composer replaced by "Engellediğiniz kişiyle mesajlaşamazsınız." with a text button "Engeli kaldır".
```

## Özellik kontrol listesi
- [ ] Başlık: avatar + çevrimiçi noktası, ad, durum (yazıyor… / Çevrimiçi / Son görülme)
- [ ] Kulüp odası ve etkinlik odası başlığı (üye sayısı, Kulüp sayfası / Etkinlik sayfası bağlantısı)
- [ ] "⋯" sohbet menüsü düğmesi
- [ ] Sohbette ara: alan, vurgulama, N / M sayacı, önceki/sonraki, boş/aranıyor/eşleşme yok, daha eski mesajlarda ara
- [ ] Yazma alanı: Ekle (+), Kamera, Gönder; yanıt çubuğu; düzenleme çubuğu
- [ ] Boş sohbet metni
- [ ] Engelli kişi satırı + Engeli kaldır

## Dikkat
- Arama/görüntülü görüşme düğmeleri, mikrofon, emoji klavye düğmesi (özel) çizmesin.
- Kulüp/etkinlik odası kalıcı olarak grup türüdür; yalnız başlık metni farklıdır.
