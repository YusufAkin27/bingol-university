# 21 - Sohbet: mesaj uzun basma menüsü, sohbet menüsü, silme ve iletme

## Kapsam
- Envanter A14 onay diyaloğu, A15 sohbet menüsü, A17 mesaj uzun basma katmanı (tepki çubuğu + eylemler), A18 iletme alt sayfası, A16 üyeler alt sayfası

## Istem
```text
Design 6 separate mobile screens, each over a dimmed chat conversation (no bottom nav).

1) Long-press overlay on someone else's message. The pressed bubble stays sharp and lifted. Above it a floating pill with 6 emoji reactions (👍 ❤️ 😂 😮 😢 🙏) where my current reaction (❤️) has a soft-red circle. Below the bubble a white action card with rows: "Yanıtla", "Kopyala", "İlet", "Şikâyet et" (red).

2) Long-press overlay on MY message. Same reaction pill. Action card rows: "Yanıtla", "Kopyala", "Düzenle", "İlet", "Herkesten sil" (red). Small toast example at bottom: "Kopyalandı".

3) Long-press overlay on my failed message (red outline). No reaction pill. Rows: "Yeniden gönder", "Sil" (red).

4) Chat menu bottom sheet (from the "⋯" button). Rows with icons: "Sohbette ara", "Üyeler", "Medya", "Kulüp sayfası" (for club rooms; for event rooms "Etkinlik sayfası"), "Ayarlar", "Sohbet bilgisi", "Sohbetten ayrıl" (red), and for direct chats "Engelle" (red), "Kullanıcıyı şikâyet et" (red).

5) Delete message confirmation dialog. Title "Mesaj silinsin mi?", body "Bu mesaj herkes için silinir.", buttons "Vazgeç" and "Sil" (red). Under it, small example toast "İletildi".

6) Forward bottom sheet, full height. Title "İlet", search field "Sohbet ara", list of conversations with circular checkboxes (2 selected), limit hint "En fazla 5 sohbet seçilebilir." bottom sticky button "Gönder (2)". Failure example row: "2 sohbete iletilemedi".
```

## Özellik kontrol listesi
- [ ] Tepki çubuğu (emoji hapı), kendi tepkim vurgulu
- [ ] Başkasının mesajı eylemleri: Yanıtla, Kopyala, İlet, Şikâyet et
- [ ] Kendi mesajım: Yanıtla, Kopyala, Düzenle, İlet, Herkesten sil
- [ ] Gönderilemeyen mesaj: Yeniden gönder, Sil
- [ ] Sohbet menüsü satırları (ara, üyeler, medya, kulüp/etkinlik sayfası, ayarlar, bilgi, ayrıl, engelle, şikâyet)
- [ ] "Mesaj silinsin mi?" (herkes için)
- [ ] İletme sheet: arama, çoklu seçim, sınır uyarısı, Gönder (N), başarısız iletme mesajı
- [ ] Kopyalandı / İletildi bildirimleri

## Dikkat
- "Yıldızla", "Sabitle", "Bilgi/Mesaj bilgisi", "Sesli ilet" yok.
- Silme "yalnızca benden sil" seçeneği sunmaz; metin "herkes için silinir".
