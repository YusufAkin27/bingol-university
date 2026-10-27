# akademik modul (academic): ders programi, sinav takvimi, akademik takvim, bolum duyurulari

Tam uc sozlesmesi: `docs/API_CONTRACTS_V2.md` "Akademik". Paket `edu.bingol.backend.academic`, migration `V320__academic.sql` (indeks oneki `acd320_`), ceviri `i18n/academic*.properties`.

## Tablolar
`tt_semester`, `tt_course`, `tt_session` (kisisel); `tt_exam` (kisisel sinav); `exam_schedule` (resmi sinav programi); `academic_event` (resmi takvim); `department_announcement`, `announcement_read` (duyurular).

## Tasarim notlari
- Duz SQL (`JdbcTemplate`, H2/PostgreSQL ortak alt kume) kullanilir; entity yok. Testlerde sema `AcademicTestSchema` ile V320 dosyasindan H2'ye uyarlanarak kurulur.
- Saat dilimi Europe/Istanbul. `dayOfWeek` ISO 1..7. Anliklar yanitta `+03:00` ofsetli; istekte ofsetsiz yerel de kabul edilir. Yalniz tarih (`YYYY-MM-DD`) verilen takvim bitisi gun sonu (23:59) sayilir.
- Cakisma: ayni kullanici + ayni donem (donemsiz dersler kendi aralarinda), `start < otherEnd && otherStart < end`; `force=true` ile gecilir. Toplu iceri aktarma tek islemde dogrulanir/yazilir (hata = geri alma).
- Hatirlatma bildirimi sunucuda YOK; `GET /api/timetable/reminders` mobilin yerel bildirimi icin liste verir.
- Kapsam suzgeci: duyuru/sinav `department`/`faculty`/`grade` alani bos = herkes; doluysa kullanicinin profilindeki deger ile buyuk-kucuk harf duyarsiz esit olmali. Profilde bolum bos olan kullaniciya yalniz kapsamsiz kayitlar gelir.
- Duyuru gorunurlugu: `published` ve `publishAt <= simdi` ve (`expiresAt` bos veya gelecekte). Siralama: sabitlenmis > `publishAt` > `id`; imec opak string (`pin.epochSec.nano.id`).
- `notify=true`: `AnnouncementNotifier` gorunur olunca hedef kitleye bir kez `NotificationService.sendBulk` (tur `ANNOUNCEMENT`, `target=ANNOUNCEMENT`). Sahiplenme `notified_at IS NULL` kosullu UPDATE ile (cok ornekte tekrar yok). Zamanlanmis duyurular `app.academic.notify-poll-ms` (varsayilan 60000) ile taranir.
- Bolum yoneticisi (gelecek): `DEPT_ADMIN` rolu + `dept_admin_scope(user_id, department)`; admin uclari bu rol icin yalniz kendi bolumunu hedefleyen duyurulara acilir. Simdilik yalniz ADMIN.

## KVKK
`DataExporter` bolumu `timetable`; hesap silmede `AcademicAccountPurger` (`AccountDataPurger.purge` icinden) kisisel kayitlari siler.

## Ayarlar
`app.academic.notify-poll-ms` (60000). Yeni ortam degiskeni yok.
