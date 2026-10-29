# 38 - Etkinlik detayı: katılım ve kontenjan durumları

## Kapsam
- Envanter 74 `EventDetailPage` (referans: standart görünüm). Bu istem: RSVP durumları, dolu, kayıtlar kapalı, iptal edildi

## Istem
```text
Design 6 separate mobile screens of the same event detail page for different states (pushed page, hero cover with back arrow, "⋯" report menu, no bottom nav). Common content: cover image, title "Bahar Şenliği", organizer line "Düzenleyen: Müzik Kulübü" (tappable club chip), date and time "23 Mayıs 2026 · 14:00 - 17:00", place "Açık Hava Sahnesi", description, capacity row "Kontenjan: 34 / 50" with progress bar, "34 kişi katılıyor · 12 ilgileniyor", row "Etkinlik sohbeti".

1) Not responded, registration open. Info "Kayıtlar açık · 16 yer kaldı". Bottom sticky actions: primary "Katıl" and secondary "İlgileniyorum".

2) Going. Green pill "Etkinliklerimde" and small "katılıyor" chip. Primary becomes a tonal button "Katılımdan ayrıl". Chat row active "Etkinlik sohbeti" with open arrow. Attendance box below: "Yoklama etkinlik saatinde açılır."

3) Interested. Pill "İlgileniyor" and the buttons "Katıl" (primary) and a tonal selected "İlgileniyorum" that can be toggled off.

4) Full capacity. Capacity row "Kontenjan doldu" with full bar, hint "Kontenjan doldu; yine de ilgilendiğini belirtebilirsin." Only "İlgileniyorum" button is active; "Katıl" is disabled grey.

5) Registrations closed. Grey pill "Kayıtlar kapalı", disabled buttons, chat row visible for members only.

6) Cancelled. Red pill "İptal edildi" under the title, title slightly muted, no action buttons, chat row hidden, a notice "Bu etkinlik iptal edildi."
```

## Özellik kontrol listesi
- [ ] Katıl + İlgileniyorum (hiç yanıt yok)
- [ ] Katılıyorum durumu (Etkinliklerimde) + Katılımdan ayrıl
- [ ] İlgileniyor durumu
- [ ] Kontenjan satırı ve ilerleme çubuğu; dolu uyarısı
- [ ] Kayıtlar kapalı; İptal edildi
- [ ] Katılım ve ilgi sayacı, "Düzenleyen: <kulüp>"
- [ ] Etkinlik sohbeti satırı (üye/aktif)
- [ ] Yoklama kutusu (saatten önce)
- [ ] Rapor menüsü "Etkinliği şikâyet et"

## Dikkat
- Bilet, fiyat veya ödeme akışı yok; "Resmi etkinlik" rozeti yok.
- Katılımcı listesi herkese açık isim listesi olarak gösterilmez (yalnız sayaç; liste organizatörde).
