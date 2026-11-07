# 46 - Akademik diyaloglar ve tarih/saat seçiciler

## Kapsam
- Envanter A45 yeni dönem diyaloğu, A46 dönem tarih seçici, A47 ders oturumu saati, A48 sınav saati, A49 sınav tarihi, A50 ders/sınav/dönem silme onayı

## Istem
```text
Design 4 separate mobile screens, each an overlay on a dimmed academic screen (no bottom nav).

1) New semester dialog. Title "Yeni dönem", field "Dönem" with hint "2026-2027 Güz", two date fields "Başlangıç tarihi" and "Bitiş tarihi" (each with calendar icon and chosen date), error "Ad ve iki tarih de gerekli." and "Bitiş tarihi başlangıçtan sonra olmalı." Buttons "Vazgeç" and "Ekle".

2) Delete confirmation dialogs variants. One screen with the dialog for deleting a course: title "Dersi sil", body "\"Veri Yapıları\" dersi ve tüm oturumları silinecek.", buttons "Vazgeç" and "Sil" (red). Under it as a text hint list the other two bodies: exam "\"Veri Yapıları Vize 1\" silinecek." and semester "\"2026-2027 Güz\" silinecek. Dersler dönemsiz kalır."

3) Date picker. Material 3 date picker dialog (month grid for Kasım 2026, selected 12) used for semester dates and exam date, with buttons "Vazgeç" and "Seç".

4) Time picker. Material 3 time picker dial dialog with 10:00 selected, switch to keyboard icon, buttons "Vazgeç" and "Seç". Heading "Başlangıç saati".
```

## Özellik kontrol listesi
- [ ] Yeni dönem diyaloğu (ad, iki tarih, hata metinleri)
- [ ] Silme onayı: ders / sınav / dönem metinleri
- [ ] Tarih seçici (M3), saat seçici (M3), marka renkli

## Dikkat
- Seçicilerde seçili gün/saat kırmızı-marka tonu olmalı, varsayılan mor değil.
