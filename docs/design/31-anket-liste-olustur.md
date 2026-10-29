# 31 - Anket listesi ve anket oluşturma

## Kapsam
- Envanter 65 `PollListPage`, 61 `PollFormPage`, A30 bitiş tarihi seçici, A31 bitiş saati seçici

## Istem
```text
Design 6 separate mobile screens (no bottom nav, header with back arrow).

1) Poll list, tab "Açık". Header "Anketler" and "+" button for club managers. Segmented tabs "Açık | Katıldıklarım | Kapanan". Poll cards: title "Yeni dönem yemek menüsü", scope chip ("Genel", "Kulüp", "Yemek"), type chip ("Tek seçim", "Çoklu seçim", "Puanlama", "Sıralı seçim"), lock chip "Gizli oy", time left "2 gün kaldı", "42 katılım", and a green pill "Oy verdiniz" on voted ones.

2) Poll list, tab "Kapanan" with closed cards: grey pill "Kapandı", text "Sona erdi", participation "128 katılım". Tab "Katıldıklarım" shown by a second small block underneath with a card carrying "Oy verdiniz".

3) Poll list empty and error states. Texts: "Şu an açık anket yok.", "Henüz bir ankete katılmadınız.", "Kapanan anket yok." Error row "Yüklenemedi, tekrar dene" with "Yeniden dene". Club variant header "Kulüp anketleri" with empty text "Bu kulübün anketi yok." and link "Tüm anketleri gör".

4) Create poll form, top half. Header "Anket oluştur". Fields: "Başlık" (hint "Örn. Yeni dönem başkanı seçimi"), "Açıklama (isteğe bağlı)", "Tür" as four selectable cards: "Tek seçim", "Çoklu seçim", "Puanlama", "Sıralı seçim", then "Seçenekler (2-12)" with two filled option fields "Seçenek 1/2", delete icons, "Seçenek ekle".

5) Create poll form, bottom half. "Bitiş zamanı" with duration chips "1 gün", "3 gün", "7 gün", button "Tarih ve saat seç" and chosen value with "Değiştir". "Sonuçlar ne zaman görünsün?" radio: "Her zaman", "Oy verince", "Anket kapanınca". Toggle "Gizli oy" with sub "Kimin ne oy verdiği kimseye gösterilmez." Toggle "Bildirim gönder" with sub "Hedef kitleye anket açıldı bildirimi". Validation texts: "Başlık gerekli.", "En az 2 seçenek girin.", "Seçenekler birbirinden farklı olmalı.", "Bitiş zamanını seçin.", "Bitiş zamanı gelecekte olmalı." Primary button "Yayınla".

6) Date and time pickers. Material 3 date picker dialog for end date (December 2026 calendar, selected 12) shown over the dimmed form; below it, as a second visual block, the Material 3 time picker dial with 18:00.
```

## Özellik kontrol listesi
- [ ] Liste: 3 sekme, kapsam çipi (Genel/Kulüp/Yemek), tür çipi, Gizli oy, kalan süre, katılım sayısı, Oy verdiniz / Kapandı
- [ ] Boş durumlar (3 sekme), hata, kulüp anketleri başlığı
- [ ] Form: başlık, açıklama, 4 tür, 2-12 seçenek, bitiş (hızlı süre + seçici), sonuç görünürlüğü (3 seçenek), Gizli oy, Bildirim gönder, doğrulama hataları, Yayınla
- [ ] Tarih ve saat seçicileri (M3)

## Dikkat
- Anket sonucu anlık "canlı izleyici sayısı", reklam, ödül yok.
- Gizli oy: oy veren kişi listesi hiçbir yerde gösterilmez.
