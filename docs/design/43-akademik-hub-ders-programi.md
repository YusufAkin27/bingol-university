# 43 - Akademik merkez ve ders programı

## Kapsam
- Envanter 84 `AcademicHubPage`, 80 `TimetablePage`, A44 dönem alt sayfası

## Istem
```text
Design 6 separate mobile screens (pushed pages, header with back arrow, no bottom nav).

1) Academic hub with data. Header "Akademik" and a text/icon button "Hatırlatmalar". Top highlight card "Sıradaki sınav": "Veri Yapıları Vize" with countdown pill "3 gün kaldı". Row of upcoming dates "Yaklaşan tarihler" with link "Takvim". Four cards: "Ders programı" ("Haftalık ders programın", sub "Sıradaki: Veri Yapıları 10:00"), "Sınavlar" ("Sınav takvimin ve resmi program", "2 yaklaşan sınav"), "Akademik takvim" ("Dönem, kayıt ve sınav tarihleri"), "Bölüm duyuruları" ("Bölümüne özel duyurular", badge "3 okunmamış").

2) Academic hub empty. Same cards with empty subtitles: "Derslerini ekle" (instead of next class), "Bu hafta ders yok", "Yaklaşan sınav yok", "Yaklaşan tarih yok". A note card when the profile has no department: "Profilinde bölüm bilgisi yok" with link to edit profile. Maintenance variant text: "Akademik hizmetler bakımda. Daha sonra tekrar deneyin."

3) Timetable (weekly). Header "Ders programı" with semester button "2026-2027 Güz" and an export icon "Takvime aktar (.ics)". Day strip Pzt Sal Çar Per Cum Cmt Paz with today highlighted ("Per, bugün"). Card "Şu an derste": "Veri Yapıları · 25 dk kaldı" with progress. Card "Sıradaki ders": "Algoritma Analizi · 45 dk sonra". Timeline for the selected day: colored course blocks (course name, time "10:00 - 11:50", room "B-204", instructor). Status tags "Şu an", "Bitti". Bottom: "Bugün 2 ders kaldı". Section "Derslerim (6)". Floating button "Ders ekle".

4) Timetable empty states. No semester: "Henüz dönem yok. Bir dönem ekleyerek derslerini düzenleyebilirsin." with "Yeni dönem ekle". No courses: "Henüz ders eklemedin." and button "İlk dersini ekle". Day empty: "Çarşamba günü dersin yok." Others: "Bugün kalan ders yok", "Bu hafta başka dersin yok.", "Bu tarih dönem aralığı dışında."

5) Timetable stale or error. Amber strip "Güncellenemedi, son veriler gösteriliyor." Error card with "Yeniden dene". Toast "Takvim (.ics) metni panoya kopyalandı." and "Dışa aktarılacak ders yok."

6) Semester bottom sheet. Title "Dönem seç". Rows: "2026-2027 Güz" with pill "Güncel", "2025-2026 Bahar", "Resmi dönem" style row "2026-2027 Güz (akademik takvimden)". Row actions: "Güncel dönem yap", "Dönemi sil" (red). Button "Yeni dönem ekle", text "Kapat".
```

## Özellik kontrol listesi
- [ ] Merkez: Hatırlatmalar, sıradaki sınav geri sayımı, yaklaşan tarihler + Takvim, 4 kart (alt metinleri durumlu), okunmamış rozeti
- [ ] Merkez boş / bölüm yok / bakım
- [ ] Ders programı: dönem düğmesi, .ics dışa aktar, gün şeridi, Şu an derste, Sıradaki ders, zaman çizelgesi, durum etiketleri, Derslerim sayısı, Ders ekle
- [ ] Boş: dönem yok, ders yok, gün boş, dönem dışı
- [ ] Bayat veri / hata, dışa aktarma bildirimleri
- [ ] Dönem sheet'i: güncel, resmi dönem, güncel yap, sil, yeni dönem

## Dikkat
- Not (GPA/AKTS) hesaplama, devamsızlık takibi, ders kaydı (OBS) ekranı yok.
- Derslik/öğretim üyesi örnekleri uydurma olabilir ama gerçek kişi adı kullanma.
