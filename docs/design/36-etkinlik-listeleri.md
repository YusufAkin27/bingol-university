# 36 - Etkinlik listeleri: Keşfet takvimi, Etkinliklerim, Oluşturduklarım

## Kapsam
- Envanter 72 `EventsPage` (4 mod), 73 `MyEventsPage`

## Istem
```text
Design 6 separate mobile screens. Screens 1-5 are the Etkinlikler page, opened from Ana Sayfa as a pushed page: header with back arrow, NO bottom nav. Header: title "Etkinlikler", icon button "Yoklama" (QR scan) and a "+" button "Etkinlik oluştur". Fixed segmented control: "Keşfet | Etkinliklerim | Oluşturduklarım".

1) "Keşfet": month calendar card with month title "Ekim 2026" and prev/next arrows, weekday header (Pzt-Paz), days with small dots on event days, selected day 29 filled red. Below, long date "29 Ekim, Perşembe" and event cards for that day: date block "29 EKİ", title "Bahar Şenliği Hazırlık Toplantısı", time "14:00", place "Konferans Salonu", club name "Müzik Kulübü", "34 katılımcı", buttons "Katıl" and "İlgileniyorum".

2) "Keşfet" empty day and truncation. Selected day with empty text for the day and amber note "Bu ayın tamamı gösterilemiyor; bazı etkinlikler listede yok." Cards show tags: "Kayıt kapalı", "İptal" (struck-through title, red pill) and "Kontenjan doldu".

3) "Etkinliklerim" with sub-segment "Yaklaşan | Geçmiş" (Yaklaşan selected): cards with pill "Etkinliklerimde" or "katılıyor", trailing options "⋯" ("Seçenekler"). Empty text for the tab: "Katılacağın bir etkinlik yok." with button "Etkinlikleri keşfet".

4) "Etkinliklerim" - "Geçmiş" selected: greyed cards, past dates, empty text "Geçmiş etkinliğin yok."

5) "Oluşturduklarım": hint "Oluşturduğun etkinlikleri buradan yönetebilirsin." Cards with status pills: "Açık" (green), "Onay bekliyor" (amber), "Reddedildi" (red) with text "Neden: Açıklama yetersiz". Options menu opened on one card: "Düzenle", "Kayıtları kapat" (or "Kayıtları yeniden aç"), "İptal et" (red). Empty: "Henüz bir etkinlik oluşturmadın."

6) Profile > Etkinliklerim page (pushed, header "Etkinliklerim"): segmented "Katıldıklarım | Oluşturduklarım", sub-chips "Yaklaşan | Geçmiş". Cards with status "Katılıyorum", "İstek gönderildi", "İlgileniyorum" and for created ones "2 bekleyen istek". Empty: "Henüz etkinliğin yok" with "Etkinliklere göz at ya da kendi etkinliğini oluştur."
```

## Özellik kontrol listesi
- [ ] Başlık, Yoklama (QR) ve Etkinlik oluştur düğmeleri, 3 sabit segment
- [ ] Takvim: ay başlığı + önceki/sonraki, nokta göstergeleri, seçili gün, uzun tarih
- [ ] Kart: tarih bloğu, başlık, saat, yer, kulüp adı, katılımcı sayısı, Katıl / İlgileniyorum
- [ ] Etiketler: Kayıt kapalı, İptal, Kontenjan doldu, Etkinliklerimde, katılıyor
- [ ] Ay kısaltma uyarısı (liste kesildi)
- [ ] Yaklaşan / Geçmiş ve boş durumlar
- [ ] Oluşturduklarım: Açık / Onay bekliyor / Reddedildi (+neden), seçenekler (Düzenle, Kayıtları kapat/aç, İptal et)
- [ ] Profil > Etkinliklerim: Katıldıklarım / Oluşturduklarım, durum etiketleri, bekleyen istek sayısı

## Dikkat
- Her etkinlik kartında kulüp adı olmalı (etkinlik kulüp adına açılır).
- Bilet fiyatı, ödeme, "Satın al" düğmesi yok.
- "Resmi etkinlik" rozeti kullanılmasın.
