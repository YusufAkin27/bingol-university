# 44 - Ders ve sınav formları, sınav listesi

## Kapsam
- Envanter 81 `CourseFormPage`, 82 `ExamsPage`, 83 `ExamFormPage`

## Istem
```text
Design 6 separate mobile screens (pushed pages, header with back arrow, no bottom nav).

1) Add course form. Header "Yeni ders". Fields: "Ders adı" (hint "Örn. Veri Yapıları"), "Ders kodu", "Öğretim üyesi" (hint "Dr. Ayşe Yılmaz"). "Renk" row of 10 color dots (Kırmızı, Turuncu, Sarı, Yeşil, Turkuaz, Mavi, Çivit, Mor, Pembe, Gri) with helper "Seçmezseniz otomatik atanır." Section "Gün ve saatler": session card "1. oturum" with weekday chips (Pzt Sal Çar Per Cum Cmt Paz), "Başlangıç saati" and "Bitiş saati" fields, "Derslik (örn. B-204)", remove icon "Oturumu kaldır"; button "Başka gün/saat ekle". "Not" (hint "İsteğe bağlı (örn. laptop getir)"). Button "Dersi ekle".

2) Course conflict dialog. Title "Ders çakışması", body "Şu derslerle saatler çakışıyor:" with list "Algoritma Analizi · Per 10:00-11:50", buttons "Vazgeç" and "Yine de kaydet". Validation lines: "Ders adı gerekli", "Bitiş saati başlangıçtan sonra olmalı.", "Bu dersin kendi oturumları çakışıyor".

3) Exams, tab "Sınavlarım". Header "Sınavlar" and button "Sınav ekle". Segmented "Sınavlarım | Resmi program". Section "Yaklaşan": cards with type chip (Vize, Final, Bütünleme, Quiz, Ödev, Diğer), title "Veri Yapıları Vize 1", date/time, room, countdown "3 gün kaldı" / "5 saat kaldı". Section "Geçmiş": greyed cards with "Geçti".

4) Exams, tab "Resmi program". Cards with a small tag "Resmi program", course, date/time, room. Info note: "Profilinde bölüm bilgisi yok; yalnız herkese açık sınavlar gösteriliyor. Profili düzenleyerek bölümünü ekleyebilirsin."

5) Add exam form. Header "Yeni sınav". Fields: "Başlık" (hint "Örn. Veri Yapıları Vize 1"), "Tür" chips, "Ders (isteğe bağlı)" select with "Yok", "Sınav tarihi" ("Tarih seç"), "Başlangıç saati", "Bitiş (ops.)", "Derslik" (hint "Örn. B-204"), "Not" (hint "İsteğe bağlı"). Errors "Sınav başlığı gerekli.", "Sınav tarihini seç.", "Bitiş saati başlangıçtan sonra olmalı." Button "Sınavı ekle". In edit mode title "Sınavı düzenle" with a delete icon.

6) Exams empty states. "Kişisel sınav eklemedin." with button "Sınav ekle"; "Yaklaşan sınavın yok."; official tab "Henüz yayınlanmış resmi sınav programı yok."; amber "Akademik hizmetler bakımda. Daha sonra tekrar deneyin."
```

## Özellik kontrol listesi
- [ ] Ders formu: ad, kod, öğretim üyesi, renk (10), çoklu oturum (gün/saat/derslik), oturum kaldır, başka gün ekle, not, Dersi ekle/Kaydet
- [ ] Çakışma diyaloğu (Yine de kaydet) ve doğrulama hataları
- [ ] Sınavlar: Sınavlarım / Resmi program, Yaklaşan/Geçmiş, tür çipleri, geri sayım, Geçti
- [ ] Resmi program etiketi + profil eksik uyarısı
- [ ] Sınav formu alanları, hata satırları, düzenleme/silme
- [ ] Boş ve bakım durumları

## Dikkat
- "Resmi program" yalnız sınav programı sekmesinin adıdır; markalama alanında "Resmi" ibaresi kullanılmaz.
- Not girişi (vize notu) alanı yok.
