# 42 - Etkinlik organizatör: QR yoklama kodu ve yoklama listesi

## Kapsam
- Envanter 78 `Etkinlik2QrPage`, 79 `Etkinlik2AttendancePage`

## Istem
```text
Design 5 separate mobile screens for event organizers (pushed pages, header with back arrow, no bottom nav).

1) Attendance QR page. Header "Yoklama kodu". Large white card with a big black-on-white QR code (always high contrast), below it the countdown ring with "Kod 18 sn sonra yenilenir", caption "Katılımcılar bu QR kodunu uygulamadan taratır." Small caps "KODU ELLE GİRMEK İÇİN" and the manual code "K7M4QX" in big monospace with copy button. Footer line "Yoklama: 18 / 42 kişi geldi" and button "Katılımcılar".

2) QR expired and error. QR area blurred with spinner and text "Süresi doldu, yenileniyor…". Second block: error card "Kod alınamadı." with buttons "Kodu yenile" and "Yeniden dene". Hint "Kod kısa süre geçerlidir."

3) Attendance list. Header "Katılımcılar ve yoklama". Summary card "18 / 42 kişi geldi" with progress bar. Filter chips "Hepsi | Geldi | Gelmedi". Rows: avatar, name, department; trailing switch "geldi" and a small tag "QR" or "Elle" indicating how attendance was recorded. FAB-like button "QR kodunu göster".

4) Attendance list, filtered empty. Chip "Gelmedi" selected with empty text "Gösterilecek katılımcı yok." Error row "Yoklama güncellenemedi." with retry; loading skeleton rows.

5) Attendance list manual mark. One row mid-toggle with a semantics hint "Elif Yıldız geldi olarak işaretle", row tag changes to "Elle" and a small success toast at the bottom.
```

## Özellik kontrol listesi
- [ ] QR (yüksek kontrast), geri sayım, yenilenme metni, elle kod + kopyala
- [ ] Süresi doldu / kod alınamadı / Kodu yenile
- [ ] Yoklama sayacı ve Katılımcılar düğmesi
- [ ] Katılımcı listesi: özet, süzgeç (Hepsi/Geldi/Gelmedi), anahtar, QR/Elle etiketi
- [ ] Boş, hata ve yükleniyor durumları

## Dikkat
- QR kodu rastgele dekoratif desen değil, gerçek QR görünümünde olsun; sahte "puan/ödül" yok.
- Sertifika indirme, rozet kazanma, yoklama PDF'i yok.
