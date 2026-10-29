# 45 - Akademik takvim, bölüm duyuruları ve hatırlatmalar

## Kapsam
- Envanter 85 `AcademicCalendarPage`, 86 `AnnouncementsPage`, 87 `AnnouncementDetailPage`, 88 `ReminderSettingsPage`

## Istem
```text
Design 6 separate mobile screens (pushed pages, header with back arrow, no bottom nav).

1) Academic calendar, month view. Header "Akademik takvim". Month title "Ekim 2026" with arrows ("Önceki ay", "Sonraki ay"), weekday header, colored dots under days that have important dates, today marked "bugün", selected day filled. Below: heading "Ekim ayı önemli tarihleri" and "6 önemli tarih" list with colored kind tags "Dönem başlangıcı", "Ders kaydı", "Tatil", "Resmi tatil" (public holiday), date range and title.

2) Academic calendar, selected empty day and next dates. Text "Bu günde önemli tarih yok." and section "Sıradaki önemli tarihler" with 3 rows. Empty month variant: "Bu ay için kayıtlı önemli tarih yok." Error/maintenance: "Akademik hizmetler bakımda. Daha sonra tekrar deneyin."

3) Department announcements list. Header "Bölüm duyuruları" with text button "Tümünü okundu işaretle". Segmented chips "Bölümüm | Tümü". Rows: pinned ones with pin icon and tag "Sabitlenmiş"; unread ones with red dot and tag "Okunmamış"; audience tag "Tüm üniversite" on university-wide items; title, 2-line summary, date. Empty texts: "Bölümünle ilgili duyuru yok." / "Henüz duyuru yok."

4) Announcement detail. Header "Duyuru". Tags (pinned, audience), title "2026-2027 Güz Dönemi Final Programı Yayınlandı", date, body paragraphs, attachment row with paperclip and button "Eki aç". Error text "Bağlantı açılamadı."

5) Reminder settings. Header "Hatırlatmalar". Intro "Bildirimler cihazında zamanlanır; internet gerekmez. Ders programın veya sınavların değişince yenilenir." Section "Ders hatırlatması": toggle plus chips "Ders başlamadan önce: 10 dk | 15 dk | 30 dk | 1 saat". Section "Sınav hatırlatmaları": toggles "1 gün önce" and "1 saat önce".

6) Reminder settings, notification permission off. Amber card "Bildirim izni verilmedi" with button "Ayarlardan aç" and the toggles disabled grey.
```

## Özellik kontrol listesi
- [ ] Takvim: ay gezinme, nokta göstergeleri, bugün, seçili gün, önemli tarih türleri
- [ ] Boş gün/ay, sıradaki önemli tarihler, bakım
- [ ] Duyurular: Bölümüm/Tümü, sabitlenmiş, okunmamış, kitle etiketi, Tümünü okundu işaretle, boş
- [ ] Duyuru detayı: etiketler, metin, ek (Eki aç), bağlantı hatası
- [ ] Hatırlatma ayarları: ders hatırlatması + dakika seçenekleri, sınav hatırlatmaları (1 gün/1 saat önce)
- [ ] Bildirim izni kapalı durumu

## Dikkat
- Not durumu, transkript, ders kayıt başvurusu yok.
- Duyuru yazarı olarak gerçek kişi/dekan adı uydurma; "Bilgisayar Mühendisliği Bölümü" gibi birim adı yeter.
