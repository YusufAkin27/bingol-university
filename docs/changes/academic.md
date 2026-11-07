# akademik modul (academic): ders programi, sinav takvimi, akademik takvim, (bolum duyurulari KALDIRILDI)

> **2026-11-05 (V1251):** "bolum duyurulari" (`DepartmentAnnouncementService`, `AnnouncementNotifier`, `/api/announcements*`, `/api/admin/announcements*`) ve "resmi sinav programi" (`exam_schedule`, `GET /api/exams/official`, `/api/admin/academic/exams*`) ozellikleri kaldirildi; `department_announcement`, `announcement_read`, `exam_schedule` tablolari dusuruldu. Asagidaki duyuru/resmi sinav notlari TARIHSEL kayittir. Kalanlar: kisisel ders/sinav, akademik takvim, resmi ders programi, sinav hatirlatmasi (`academic_announcements` bayragi ile).

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

## FIX-P08: sinav listesi, duyuru bildirimi, saklama (P08)
- **`GET /api/exams/official` (ISTEMCI ETKISI):** yayinli resmi sinavlar artik **SQL'de** suzulur (kapsam `AudienceKey` ile, ayni kural), en cok 500 satir doner ve **bitisi (yoksa baslangici) 30 gunden eski sinavlar listeden duser** (`scope=all` dahil). Eskiden `scope=all` en ESKI 500 kaydi donduruyordu; 500'den cok yayinli sinav birikince yeni sinavlar hic gorunmezdi. Gecmis sinav gosteren bir ekran varsa 30 gun ile sinirlidir (plan karari K21). Siralama `starts_at, id` artan, yanit sekli ayni.
- **Duyuru bildirimi (`AnnouncementNotifier`):** `POST/PATCH/publish` istegi toplu bildirimi artik **beklemez**: gonderim yazan islem COMMIT olduktan sonra tek iscilik sinirli yurutucuda calisir (geri alinmis duyuru bildirmez); kuyruk dolarsa dakikalik zamanlayici (`notified_at IS NULL`) yakalar. Hedef kitle cozumlenemezse sahiplenme geri alinir. Bildirim "hemen" yerine birkac saniye gecikmeli ulasabilir; istemci degisikligi gerekmez.
- `GET /api/admin/announcements/audience-count` `SELECT COUNT(*)` kullanir ve dakikada 60 istekle sinirlidir (`acd:audcount:<adminId>`); 429 `Retry-After` ile doner.
- **Cakisma denetimi:** guncel donemin ders programi "donem = guncel VEYA donem yok" derslerini birlikte gosterdigi icin cakisma da ayni kumede aranir (donemsiz + donemli ders artik cakisir -> 409 `COURSE_CONFLICT`, `force=true` ile gecilir).
- **Saklama (`AcademicRetentionJob`, K23):** gece 03:30 (`app.academic.retention-cron`), `ChunkedDeleter` ile parcali: suresi `app.academic.read-retention-days` (90) gun once dolmus duyurularin okundu satirlari; `app.academic.retention-days` (365) gunden eski suresi dolmus duyurular, bitmis resmi sinav/akademik takvim kayitlari, kisisel sinavlar (`tt_exam`) ve bitis tarihi 365 gunden eski donemler (dersleri/oturumlariyla). `0` = o grup kapali.
- **Migration:** `V1140__grade_backfill.sql` (`class_year` dolu `grade` bos kullanicilarda `grade` turetilir; sinif hedefli duyuru/sinav kapsami artik bu kullanicilari da kapsar; gecmis duyurular tekrar bildirilmez), `V1141__account_delete_indexes.sql` (hesap silme icin 4 indeks).
- **FINAL-ALL (ertelenen kalemler tamamlandi):** `AnnouncementNotifier.send` artik `sendTemplatedBulk` kullanir (sablon `notif.academic.announcement`, alt tur `ACADEMIC_ANNOUNCEMENT`: ana `announcements` AND `academic_announcements` bayragi - onceki `prefColumn` ile ayni karar; ek olarak sessiz saat ve PushGate uygulanir). `ExamReminderJob` ISTISNA: her sinav tek kisiye, kisiye ozgu baslik/saat/salon/birlesme anahtariyla gider; toplu API ayni metni ister, bu yuzden alici basina tek-kullanicilik yol (sabit sorgu) korundu; iz geri alma `sendTemplate` istisna sizdirmadigi icin pratikte tetiklenmez (K22 sessiz saat karari hala acik).
