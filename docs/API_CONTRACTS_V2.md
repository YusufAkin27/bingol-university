# API sözleşmeleri (V2 turu)

Her backend ajanı kendi bölümünü ekler; bölüm başlığı `## [HAZIR] <özellik>`. Sözleşme değişirse bölümün sonuna `DEĞİŞİKLİK:` satırı eklenir.

---

## [HAZIR] Akademik

Ders programı, sınav takvimi, akademik takvim, bölüm duyuruları. Paket `edu.bingol.backend.academic`, migration `V320__academic.sql`, çeviri `i18n/academic*.properties`. Tüm uçlar JWT ister (`Authorization: Bearer`); `/api/admin/**` yalnız ADMIN. Hata gövdesi her yerde `{ "code": "KOD", "message": "<istek dilinde metin>" }`. Alanlara özgü küfür ihlali: 422 `CONTENT_PROFANITY` + `field`. Hız sınırı aşımı: 429 + `Retry-After`.

### Ortak biçimler
- Saat dilimi **Europe/Istanbul**. Gün-içi saat: `"HH:mm"` (24 saat, `"09:30"`). Tarih: `"YYYY-MM-DD"`. Anlık (sınav, takvim olayı, duyuru zamanı): ISO-8601 **ofsetli** `"2026-11-02T10:00:00+03:00"`; istekte ofsetsiz `"2026-11-02T10:00"` de kabul edilir (İstanbul varsayılır). Yanıtlar her zaman `+03:00` ofsetlidir.
- Gün: ISO `dayOfWeek` 1..7 (1=Pazartesi, 7=Pazar).
- Renk anahtarı (`color`): `red|orange|amber|green|teal|blue|indigo|purple|pink|gray` (boşsa sunucu dersin adına göre deterministik bir anahtar atar; yanıtta daima dolu).
- Sınav türü: `VIZE|FINAL|BUT|QUIZ|ODEV|DIGER`.
- Akademik takvim türü: `DONEM_BASLANGIC|DERS_KAYIT|VIZE|FINAL|BUT|TATIL|RESMI_TATIL|DIGER`.
- Silme: 204 gövdesiz. Bulunamayan/başkasına ait kayıt: 404 (varlık sızdırmaz).

### A) Ders programı (kişisel)

Sınırlar: kullanıcı başına en çok 40 ders, ders başına en çok 12 oturum, 8 dönem.

`GET /api/timetable?semesterId=` — dönem verilmezse **güncel dönem** (yoksa dönemsiz dersler + tüm dersler). Yanıt:
```json
{
  "semester": { "id": 3, "name": "2026-2027 Güz", "startDate": "2026-09-14", "endDate": "2027-01-15", "current": true },
  "courses": [
    { "id": 11, "name": "Veri Yapıları", "code": "BIL201", "instructor": "Dr. Ayşe Yılmaz", "color": "blue",
      "note": null, "semesterId": 3,
      "sessions": [
        { "id": 21, "dayOfWeek": 1, "start": "09:00", "end": "10:50", "room": "B-204" },
        { "id": 22, "dayOfWeek": 3, "start": "13:00", "end": "14:50", "room": "Lab-2" } ] }
  ]
}
```
`semester` null olabilir.

`POST /api/timetable/courses` → **201** `CourseView` (yukarıdaki `courses[]` öğesi). İstek (iki biçim):
```json
{ "name": "Veri Yapıları", "code": "BIL201", "instructor": "Dr. Ayşe Yılmaz", "color": "blue", "note": "Laptop getir",
  "semesterId": 3, "force": false,
  "sessions": [ { "dayOfWeek": 1, "start": "09:00", "end": "10:50", "room": "B-204" } ] }
```
Tek oturumluk kısa biçim: `sessions` yerine kök alanlar `dayOfWeek`, `startTime`, `endTime`, `room` (aynı anda ikisi verilirse `sessions` geçerli). Sınırlar: `name` ≤120 (zorunlu), `code` ≤20, `instructor` ≤120, `room` ≤60, `note` ≤500. `semesterId` yoksa güncel dönem (yoksa dönemsiz). `force=true` olmadıkça aynı kullanıcıda aynı dönemde zaman çakışması **409 `COURSE_CONFLICT`** (mesajda çakışan ders ve saat aralığı). Çakışma: aynı gün, `startA < endB && startB < endA` (bitişik dersler çakışmaz).

`PATCH /api/timetable/courses/{id}` — kısmi güncelleme (yalnız verilen alanlar; `sessions` verilirse **tüm oturumlar yer değiştirir**, `[]` yasak). Aynı çakışma/`force` kuralı. 200 `CourseView`. `DELETE /api/timetable/courses/{id}` → 204.

`POST /api/timetable/import` → **201** `{ "created": 4, "courses": [CourseView…] }`. İstek `{ "semesterId": 3, "replace": false, "force": false, "courses": [ {name, code, instructor, color, note, sessions:[…]} ] }`. Toplam oturum ≤60. Hepsi tek işlemde doğrulanır (biri hatalıysa hiçbiri yazılmaz). `replace=true` seçili dönemdeki mevcut dersleri siler. Kendi içindeki ve mevcutlarla çakışma `force` olmadıkça 409. 422 `IMPORT_TOO_LARGE` (>60 oturum).

`GET /api/timetable/today` (veya `?date=YYYY-MM-DD`):
```json
{ "date": "2026-11-02", "dayOfWeek": 1,
  "items": [ { "courseId": 11, "sessionId": 21, "name": "Veri Yapıları", "code": "BIL201", "instructor": "Dr. Ayşe Yılmaz",
               "room": "B-204", "color": "blue", "start": "09:00", "end": "10:50", "status": "ONGOING" } ],
  "next": { "date": "2026-11-02", "courseId": 12, "sessionId": 30, "name": "…", "start": "13:00", "end": "14:50", "room": "…", "color": "teal", "minutesUntil": 95 } }
```
`status`: `PAST|ONGOING|UPCOMING` (yalnız bugün için anlamlı; başka tarihte hepsi `UPCOMING`). `next`: şimdiden sonra başlayan ilk oturum (bugün yoksa sonraki 7 gün içinde), yoksa null. Yalnız dönem aralığına giren günlerin oturumları gelir.

`GET /api/timetable/week?date=YYYY-MM-DD` (tarih opsiyonel; o haftanın Pazartesi'sinden başlar): `{ "weekStart": "2026-11-02", "days": [ { "dayOfWeek": 1, "date": "2026-11-02", "items": [ …today.items biçimi… ] }, … 7 gün ] }`.

`GET /api/timetable/reminders?days=7` (1..14) — mobilin **yerel bildirim** planlaması için: `{ "generatedAt": "...", "sessions": [ { "courseId","sessionId","name","room","startsAt":"2026-11-02T09:00:00+03:00","endsAt":"…" } ], "exams": [ ExamView… ] }` zamana göre sıralı. Sunucu ders/sınav hatırlatma bildirimi **göndermez**.

`GET /api/timetable/export.ics?semesterId=` — `text/calendar; charset=utf-8`, ek dosya (`bu-ders-programi.ics`). `VTIMEZONE Europe/Istanbul` (+03:00, DST yok), her oturum için ilk geçerli güne düşen `VEVENT` + `RRULE:FREQ=WEEKLY;UNTIL=<dönem bitişi, UTC>`; dönem yoksa 16 hafta. `SUMMARY` ders adı, `LOCATION` oda, `DESCRIPTION` hoca/kod. Kişisel sınavlar da (tekrarsız) eklenir.

#### Dönemler
- `GET /api/timetable/semesters` → `{ "items": [Semester…], "officialCurrent": { "name": "2026-2027 Güz", "startDate": "…", "endDate": "…" } | null }`. `officialCurrent`, resmi akademik takvimdeki (`DONEM_BASLANGIC`, yayında) bugünü kapsayan ya da en yakın dönemdir.
- `POST /api/timetable/semesters` → 201 `{ name (≤60, zorunlu), startDate, endDate (endDate>startDate), current? }`. `current=true` ise öncekinin bayrağı kalkar; ilk dönem otomatik güncel olur.
- `POST /api/timetable/semesters/from-official` → 201: resmi akademik takvimden kullanıcı dönemi oluşturur ve güncel yapar; resmî dönem yoksa 404 `NO_OFFICIAL_SEMESTER`.
- `PATCH /api/timetable/semesters/{id}` (ad/tarih/current), `DELETE …/{id}` → 204 (dersleri dönemsiz kalır).

### B) Sınav takvimi

`ExamView`:
```json
{ "id": 5, "courseId": 11, "courseName": "Veri Yapıları", "title": "Vize 1", "type": "VIZE",
  "startsAt": "2026-11-10T10:00:00+03:00", "endsAt": "2026-11-10T11:30:00+03:00", "room": "B-204", "note": null }
```
- `POST /api/timetable/exams` → 201 `{ courseId?, title (≤120, zorunlu), type, startsAt, endsAt? (>startsAt), room? (≤60), note? (≤500) }`. `courseId` kullanıcının dersi olmalı.
- `GET /api/timetable/exams?from=&to=` (tarih, opsiyonel) → `{ "items": [ExamView…] }` zamana göre.
- `GET /api/timetable/exams/upcoming?days=30` (1..365) → `{ "items": […] }` yalnız bitmemiş sınavlar.
- `PATCH /api/timetable/exams/{id}` (200 ExamView), `DELETE` → 204.
- **Resmi sınav programı:** `GET /api/exams/official` → kullanıcının profilindeki fakülte/bölüm/sınıfa uyanlar (alan boşsa herkese): `{ "items": [ { "id","title","type","term":"2026-2027 Güz","courseCode":"BIL201","department":"Bilgisayar Mühendisliği"|null,"faculty":…|null,"grade":"2"|null,"startsAt","endsAt","room","note" } ], "profileComplete": true }`. Profilde bölüm yoksa `profileComplete=false` ve yalnız herkese açık satırlar döner. `?scope=all` tümünü getirir.

### C) Akademik takvim (resmi)

`AcademicEventView`: `{ "id": 7, "kind": "VIZE", "title": "Ara sınav haftası", "startsAt": "2026-11-09T00:00:00+03:00", "endsAt": "2026-11-13T23:59:00+03:00", "allDay": true, "scopeDepartment": null, "note": null }` (`published` yalnız admin görünümünde).
- `GET /api/academic/calendar?month=2026-11` ya da `?from=2026-11-01&to=2026-11-30` (en çok 366 gün; 422 `CALENDAR_RANGE_INVALID`) → `{ "from","to","items":[…] }` yalnız yayında olanlar; `scopeDepartment` null veya kullanıcının bölümü. Aralıkla kesişenler gelir.
- `GET /api/academic/calendar/next?limit=5` (1..20) → `{ "items": [...] }` bitmemiş, sıradaki önemli tarihler.

Yönetici (`/api/admin/academic/events`): `GET ?page=0&size=20&kind=&q=&published=` → `{ items, page, size, total }`; `POST` (201 `{kind,title≤150,startsAt,endsAt?,allDay,scopeDepartment?,note≤500,published}`), `GET /{id}`, `PATCH /{id}`, `DELETE /{id}` (204), `POST /{id}/publish`, `POST /{id}/unpublish`, `POST /import` `{ "text": "...", "publish": false }` — satır biçimi `KIND;Başlık;başlangıç;bitiş?;bölüm?` (tarih `YYYY-MM-DD` ⇒ tüm gün, ya da `YYYY-MM-DDTHH:mm`; boş satır ve `#` yorum atlanır; en çok 200 satır). Yanıt `{ "created": 12, "errors": [ { "line": 4, "message": "…" } ] }` (geçerli satırlar yazılır).

Resmi sınav programı yönetimi (`/api/admin/academic/exams`): aynı kalıp (liste/POST/GET/PATCH/DELETE + `publish|unpublish`); alanlar `{ title, type, term, courseCode?, faculty?, department?, grade?, startsAt, endsAt?, room?, note?, published }`.

### D) Bölüm duyuruları

`AnnouncementView`:
```json
{ "id": 9, "title": "Staj başvuruları", "body": "…", "department": "Bilgisayar Mühendisliği", "faculty": null, "grade": null,
  "pinned": true, "publishAt": "2026-10-20T09:00:00+03:00", "expiresAt": null, "attachmentUrl": "https://…", "read": false, "createdAt": "…" }
```
Liste öğelerinde `body` en çok 200 karaktere kısaltılır (`bodyTruncated: true`); `GET /{id}` tam metni verir.
- `GET /api/announcements?scope=mine|all&cursor=&size=20` (size 1..50, varsayılan 20; `scope` varsayılan `mine`). `mine`: `department`/`faculty`/`grade` alanı boş **veya** kullanıcının değeriyle eşleşen (büyük-küçük harf duyarsız) duyurular. `all`: görünür tüm duyurular. Görünür = `published` ∧ `publishAt ≤ şimdi` ∧ (`expiresAt` boş ∨ `> şimdi`). Sıra: sabitlenmiş önce, sonra `publishAt` azalan, `id` azalan. Yanıt `{ "items": [...], "nextCursor": "1.1730000000.0.9" (biçim pin.saniye.nano.id; istemci ayrıştırmaz) | null }` — **imleç opak string**, sonraki istek `?cursor=<nextCursor>`; geçersiz imleç 422 `ANNOUNCEMENT_CURSOR_INVALID`.
- `GET /api/announcements/{id}` — görünür değilse 404; açınca **okundu** işaretlenir.
- `POST /api/announcements/{id}/read` → 204 (idempotent); `POST /api/announcements/read-all` → 204 (kullanıcının `mine` görünür duyurularının hepsi).
- `GET /api/announcements/unread-count` → `{ "count": 3 }` (yalnız `mine` kapsamı).

Yönetici (`/api/admin/announcements`):
- `GET ?page=0&size=20&status=all|draft|scheduled|active|expired&q=` → `{ items:[AdminAnnouncementView], page, size, total }` (`AnnouncementView` + `published`, `notify`, `notifiedAt`, `createdBy`, `readCount`).
- `POST` → 201: `{ title≤150, body≤4000, department?, faculty?, grade?, pinned, publishAt? (boşsa şimdi), expiresAt? (>publishAt), attachmentUrl? (yalnız https, ≤500), published (varsayılan true), notify (varsayılan false) }`. `grade`: `PREP|1..6|MASTER|PHD`.
- `GET /{id}`, `PATCH /{id}` (kısmi; sabitleme `pinned`), `DELETE /{id}` (204), `POST /{id}/publish`, `POST /{id}/unpublish`.
- `GET /audience-count?department=&faculty=&grade=` → `{ "count": 412 }` (aktif, silinmemiş kullanıcılar; boş alan = kısıtsız).
- `notify=true`: duyuru **görünür olduğunda** (hemen ya da `publishAt` geldiğinde; en geç 1 dk) hedef kitleye bir kez `ANNOUNCEMENT` türünde bildirim (uygulama içi + push; `data: { targetType: "ANNOUNCEMENT", targetId: "<id>" }`) gider; `notifiedAt` dolar, tekrar gönderilmez. Kullanıcının duyuru bildirim tercihi kapalıysa atlanır.
- Gelecek (bölüm yöneticisi): `app_user.role`'e `DEPT_ADMIN` ve `dept_admin_scope(user_id, department)` eklenir; admin uçları `DEPT_ADMIN` için yalnız kendi bölümünü hedefleyen duyurulara açılır. Şimdilik yalnız ADMIN.

### Hata kodları
| Kod | HTTP | Anlam |
|---|---|---|
| `COURSE_NOT_FOUND` / `EXAM_NOT_FOUND` / `SEMESTER_NOT_FOUND` / `ANNOUNCEMENT_NOT_FOUND` / `ACADEMIC_EVENT_NOT_FOUND` / `EXAM_SCHEDULE_NOT_FOUND` | 404 | Kayıt yok ya da size ait değil |
| `COURSE_CONFLICT` | 409 | Zaman çakışması (`force=true` ile geçilir) |
| `COURSE_INVALID` / `COURSE_FIELD_TOO_LONG` / `COURSE_INVALID_TIME` / `COURSE_INVALID_DAY` / `COURSE_COLOR_INVALID` / `COURSE_SESSIONS_REQUIRED` | 422 | Alan doğrulama |
| `COURSE_LIMIT` / `SESSION_LIMIT` / `SEMESTER_LIMIT` | 422 | Üst sınır |
| `IMPORT_TOO_LARGE` | 422 | >60 oturum |
| `SEMESTER_INVALID` / `EXAM_INVALID` / `ANNOUNCEMENT_INVALID` / `ACADEMIC_EVENT_INVALID` / `ANNOUNCEMENT_URL_INVALID` / `DATE_INVALID` / `CALENDAR_RANGE_INVALID` / `ANNOUNCEMENT_CURSOR_INVALID` | 422 | Doğrulama |
| `NO_OFFICIAL_SEMESTER` | 404 | Resmi dönem tanımlı değil |
| `CONTENT_PROFANITY` | 422 | Küfür filtresi (`field`) |

### Hız sınırları
Yazma (ders/sınav/dönem) 60/saat, içe aktarma 5/saat, okuma 120/dk, `.ics` 20/saat, yönetici yazma 120/dk (kullanıcı başına).

### KVKK
Dönem/ders/oturum/sınav kayıtları `GET /api/users/me/export` içinde (`timetable` bölümü) ve hesap silinince silinir. Duyuru okundu kayıtları da silinir. Resmi veriler kişisel değildir.

---

## [HAZIR] Anket ve oylama

Paket `edu.bingol.backend.poll`, migration `V330__polls.sql` (önek `pol330_`), çeviri `i18n/poll*.properties`. Tüm uçlar JWT ister; `/api/admin/**` yalnız ADMIN. Hata gövdesi `{ "code", "message" }`; küfür: 422 `CONTENT_PROFANITY` + `field` (başlık `title`, açıklama `description`, seçenekler `options[i]`). Anlıklar ISO-8601 (`+03:00` ofsetli yanıt; istekte ofsetsiz `2026-11-02T10:00` İstanbul varsayılır).

### Kavramlar
- `type`: `SINGLE` (tek seçim), `MULTI` (çoklu, `maxChoices` 1..seçenek sayısı; varsayılan seçenek sayısı), `RATING` (1–5 yıldız; sunucu 5 seçenek üretir: `text` "1".."5", `position` 1..5), `RANKED` (sıralı seçim: `optionIds` SIRASI tercih sırasıdır, ilk = en çok tercih; en çok `maxChoices` adet, varsayılan hepsi).
- `scope`: `GLOBAL` (üniversite geneli; yalnız ADMIN oluşturur), `COMMUNITY` (`communityId` zorunlu; kulüp sahibi/yöneticisi (rol ADMIN/OWNER) ya da sistem ADMIN'i oluşturur; **yalnız aktif üyeler** görür ve oy verir; kulüp seçimi = aday seçenekleri + `anonymous=true`), `MENU` (`menuDate` = yemek listesi günü; RATING; ADMIN ya da otomatik "bugünkü menüyü puanla").
- `status`: `DRAFT` (yalnız oluşturan/yönetici görür), `OPEN`, `CLOSED`, `CANCELLED`. Etkin açıklık: `status=OPEN` ∧ `opensAt ≤ şimdi` ∧ (`closesAt` boş ∨ `> şimdi`); kapanış işi `closesAt` geçenleri `CLOSED` yapar ama oy anında da süre kontrol edilir. `state` (yalnız bilgi): `SCHEDULED|OPEN|CLOSED|CANCELLED|DRAFT`.
- `showResults`: `ALWAYS` | `AFTER_VOTE` (oy verdikten sonra ya da kapandıktan sonra) | `AFTER_CLOSE`. Sistem ADMIN'i her zaman görür (yönetici uçları).
- `anonymous=true` (gizli oy): oy kaydı yalnız tekillik için kullanıcıyla eşleşir; **hiçbir yanıtta/yönetici ekranında/CSV'de kim ne oy verdi görünmez**. Kullanıcı yalnız kendi oyunu (`myVote`) ve kendi dışa aktarımında görür. Anonim olmayan ankette de yanıtlarda seçenek bazında kişi listesi yoktur (yalnız toplamlar); `anonymous` alanı yalnız "oy kimliği yönetici/ihracatta saklı mı" bilgisini verir (bu sürümde hiçbir yanıt kişi listesi döndürmez).
- `audience`: `{ "faculty": "...", "department": "...", "grade": "2" } | null` (null = herkes). Boş alan kısıtsız; dolu alan kullanıcı profilindeki değerle büyük-küçük harf duyarsız eşleşmelidir (profilinde değer yoksa eşleşmez). Uygun olmayan kullanıcı listede görmez; `GET /{id}`'de `canVote=false, voteBlockedReason="NOT_ELIGIBLE"`.

### PollView
```json
{
  "id": 5, "title": "Kulüp başkanlığı seçimi", "description": "…", "type": "SINGLE", "scope": "COMMUNITY",
  "communityId": 12, "communityName": "Müzik Kulübü", "menuDate": null,
  "options": [ { "id": 31, "text": "Ayşe Y.", "position": 1 }, { "id": 32, "text": "Mehmet K.", "position": 2 } ],
  "maxChoices": 1, "anonymous": true, "allowChangeVote": false, "showResults": "AFTER_CLOSE", "notify": true,
  "opensAt": "2026-11-01T09:00:00+03:00", "closesAt": "2026-11-05T18:00:00+03:00", "audience": null,
  "status": "OPEN", "state": "OPEN", "createdAt": "…", "closedAt": null,
  "createdBy": { "id": 7, "displayName": "Ali V." } ,
  "canVote": true, "voteBlockedReason": null, "canManage": false,
  "myVote": { "optionIds": [31], "rating": null, "votedAt": "…" } ,
  "resultsVisible": false, "results": null, "totalVotes": null, "turnout": null, "average": null, "ratingCount": null
}
```
- `createdBy` null olabilir (otomatik menü anketi veya silinmiş hesap). `myVote` null = oy yok; RATING'de `rating` 1..5 ve `optionIds` tek öğe; RANKED'de `optionIds` tercih sırasındadır.
- `voteBlockedReason`: `NOT_ELIGIBLE|CLOSED|NOT_OPEN|ALREADY_VOTED` (canVote=false iken; boşsa null). `canVote=true` iken kullanıcı oy değiştirebilir de (`allowChangeVote`).
- `resultsVisible=true` ise `results: [ { "optionId": 31, "count": 14, "percent": 56.0 } ]` (seçenek sırasıyla; RANKED'de `count` = 1. tercih sayısı ve ek `score` Borda puanı = Σ(n − sıra + 1); `percent` = oy veren kişi başına (MULTI'de toplam oy veren kişiye göre, birden çok seçenek yüzdesi toplamı >100 olabilir)), `totalVotes` (oy veren kişi sayısı), `turnout` `{ "voted": 25, "eligible": 140, "percent": 17.9 }` (`eligible` yalnız COMMUNITY'de (aktif üye sayısı) ve GLOBAL+audience'sız ya da hesaplanabilir olduğunda dolu; hesaplanamıyorsa `null`, `turnout` yine `{voted, eligible:null, percent:null}`). RATING: `average` (1 ondalık, örn. 4.2) ve `ratingCount`. Görünmezse `results/totalVotes/turnout/average/ratingCount` = null.

### Kullanıcı uçları
- `GET /api/polls?scope=open|mine|closed|community:{id}&cursor=&size=` — `scope` varsayılan `open`. `open`: etkin açık ve bana uygun (GLOBAL/MENU + üyesi olduğum kulüpler + audience'a uyan). `mine`: oluşturduklarım (DRAFT dahil) **ve** oy verdiklerim. `closed`: kapanmış (CLOSED) bana görünür olanlar. `community:{id}`: o kulübün anketleri (yalnız aktif üye ya da ADMIN; değilse 403 `POLL_NOT_ELIGIBLE`; DRAFT yalnız yöneticiye). Sıra `id` azalan; **imleç sayısal** `nextCursor` (null = son), sonraki istek `?cursor=<nextCursor>`; `size` 1..50 (varsayılan 20). Yanıt `{ "items": [PollView], "nextCursor": 5 | null }` (listede `results` görünürlük kuralına göre dolar).
- `GET /api/polls/{id}` → PollView. Bulunamayan, silinen, üyesi olunmayan kulüp anketi, başkasının DRAFT'ı: 404 `POLL_NOT_FOUND`.
- `POST /api/polls` → **201** PollView. İstek:
```json
{ "title": "…≤150", "description": "…≤1000", "type": "SINGLE|MULTI|RATING|RANKED", "scope": "GLOBAL|COMMUNITY|MENU",
  "communityId": 12, "menuDate": "2026-11-02", "options": ["Ayşe Y.", "Mehmet K."], "maxChoices": 2,
  "anonymous": false, "allowChangeVote": true, "showResults": "ALWAYS", "notify": false,
  "opensAt": null, "closesAt": "2026-11-05T18:00", "audience": null, "draft": false }
```
Kurallar: `options` 2..12 öğe, her biri ≤100 ve benzersiz (RATING'de `options` verilmez/yok sayılır); `closesAt` > `opensAt` (boş `opensAt` = şimdi) ve geçmişte olamaz; `draft=true` → DRAFT. Varsayılanlar: `anonymous=false, allowChangeVote=true, showResults=ALWAYS, notify=false`. `scope=COMMUNITY` + `anonymous` boşsa **true**. Yetkisiz: 403 `POLL_FORBIDDEN`. Kulüp aktif değilse 404 `POLL_NOT_FOUND`. MENU: aynı gün için tek anket (var olan 409 `POLL_MENU_EXISTS`; o günün yemek listesi yoksa 404 `POLL_MENU_NOT_FOUND`).
- `POST /api/polls/{id}/vote` → 200 PollView (güncel). İstek: `{ "optionIds": [31] }` (SINGLE: 1; MULTI: 1..maxChoices; RANKED: 1..maxChoices sıralı) **veya** `{ "rating": 4 }` (RATING). **İdempotent**: aynı oy tekrar gönderilirse 200 ve değişiklik olmaz. Hatalar: 409 `POLL_CLOSED` (kapalı/iptal/süresi dolmuş), 409 `POLL_NOT_OPEN` (henüz açılmadı/taslak), 409 `POLL_ALREADY_VOTED` (oy var, farklı oy, `allowChangeVote=false`), 403 `POLL_NOT_ELIGIBLE`, 400 `POLL_INVALID_VOTE` (seçenek bu ankete ait değil/tekrarlı/sayı kuralı).
- `DELETE /api/polls/{id}/vote` → 200 PollView (oy geri çekildi). Oy yoksa idempotent 200. `allowChangeVote=false` ise 409 `POLL_ALREADY_VOTED`; kapalıysa 409 `POLL_CLOSED`.
- `GET /api/polls/menu/today` → bugünkü menü anketi PollView; bugünün yemek listesi varsa anket yoksa **otomatik oluşturulur** (RATING, ALWAYS sonuç, değişiklik izinli, gün sonu 23:59 kapanır); yemek listesi yoksa **204**. Menü anketi PollView'ında ek alan `menuItems: ["Mercimek çorbası", …]`.
- `PATCH /api/polls/{id}` → PollView (oluşturan, kulüp yöneticisi ya da ADMIN): DRAFT iken tüm alanlar (title, description, options, type, maxChoices, anonymous, allowChangeVote, showResults, notify, opensAt, closesAt, audience); açıkken ve **oy yokken** aynısı; **oy varken** yalnız `title, description, closesAt (ileri), showResults, notify` (diğeri 409 `POLL_LOCKED`). `draft:false` ile DRAFT yayınlanır. Kapalı/iptal 409 `POLL_CLOSED`.
- `POST /api/polls/{id}/close` → PollView: erken kapatır (oluşturan/kulüp yöneticisi/ADMIN). Zaten kapalıysa idempotent.
- `DELETE /api/polls/{id}` → 204 (oluşturan/kulüp yöneticisi/ADMIN): anket, seçenekler ve oylar kalıcı silinir.
- `GET /api/polls/{id}/export.csv` → CSV (oluşturan/kulüp yöneticisi/ADMIN): sütunlar `optionId,text,count,percent,score` (`score` yalnız RANKED'de dolu); **hiçbir kullanıcı kimliği yok** (anonim olsun olmasın).

### Yönetici uçları (`/api/admin/polls`, yalnız ADMIN; denetim kaydı yazılır)
- `GET /api/admin/polls?status=&scope=&q=&page=0&size=20` → `{ "items": [AdminPollRow], "page", "size", "total" }`; satır: `id,title,type,scope,communityId,status,state,anonymous,totalVotes,opensAt,closesAt,createdAt,createdBy`.
- `GET /api/admin/polls/{id}` → PollView (sonuçlar **her zaman** görünür, `resultsVisible=true`).
- `POST /api/admin/polls/{id}/close`, `POST /api/admin/polls/{id}/cancel` (iptal: oy kapanır, sonuçlar korunur; CANCELLED) , `DELETE /api/admin/polls/{id}`.
- `POST /api/admin/polls/bulk` `{ "ids": [1,2], "action": "CLOSE|CANCEL|DELETE" }` → `{ "done": 2, "skipped": 0 }` (en çok 100).
- `GET /api/admin/polls/stats` → `{ "total", "open", "closed", "draft", "cancelled", "totalVotes", "byScope": {"GLOBAL":n,"COMMUNITY":n,"MENU":n}, "avgTurnoutPercent" }`.
- `GET /api/admin/polls/{id}/export.csv` → kullanıcı kimliksiz sonuç CSV (hücre kaçışlı).

### Bildirimler
`notify=true` ise anket **açıldığında** (oluşturma anı ya da `opensAt`) ve **kapanışa 24 saat kala** (henüz oy vermemiş uygun kullanıcılara) bildirim gider: GLOBAL → `ANNOUNCEMENT` türü, COMMUNITY → `COMMUNITY` türü (yalnız o kulübün aktif üyeleri; tercih kapalıysa gitmez). Yük `data`: `{"pollId":"5","communityId":"12"?}`; push `target=POLL`, `targetType=POLL`, `targetId=<pollId>`. Metinler alıcının dilinde (tr/en/ar). MENU anketleri bildirim göndermez.

### Hata kodları
| Kod | HTTP | Anlam |
|---|---|---|
| `POLL_NOT_FOUND` | 404 | Yok / görünmez |
| `POLL_FORBIDDEN` | 403 | Oluşturma/yönetme yetkisi yok |
| `POLL_NOT_ELIGIBLE` | 403 | Oy/görüntüleme için uygun değil (üye değil, audience dışı) |
| `POLL_CLOSED` | 409 | Kapalı/iptal/süresi dolmuş |
| `POLL_NOT_OPEN` | 409 | Henüz açılmadı / taslak |
| `POLL_ALREADY_VOTED` | 409 | Oy var, değiştirme kapalı |
| `POLL_LOCKED` | 409 | Oy alınmış ankette bu alan değiştirilemez |
| `POLL_MENU_EXISTS` | 409 | O gün için menü anketi var |
| `POLL_MENU_NOT_FOUND` | 404 | O gün yemek listesi yok |
| `POLL_INVALID_VOTE` | 400 | Geçersiz seçenek/sayı/puan |
| `POLL_INVALID` | 400 | Başlık/seçenek sayısı/süre/tür-kapsam uyumsuz (mesaj ayrıntı verir) |
| `POLL_SCOPE_INVALID` | 400 | Bilinmeyen `scope` sorgusu |
| `CONTENT_PROFANITY` | 422 | Küfür filtresi (`field`) |

### Hız sınırları (kullanıcı başına)
Oy (ver/geri çek) 60/dk, oluşturma 10/saat, okuma 120/dk, yönetici yazma 120/dk.

### KVKK
Hesap silinince oylar anonimleştirilir (kullanıcı bağı kaldırılır, seçenek sayaçları ve toplam oy korunur); oluşturduğu anketlerde `createdBy` boşalır. `GET /api/users/me/export` içinde `polls` bölümü: kullanıcının oyları (gizli ankette hangi seçeneğe oy verdiği **yalnız burada**), oluşturduğu anketler.

---

## [HAZIR] Kalıcı push kuyruğu

Mobil/web API'sini değiştirmez; yalnız yönetici uçları ve sağlık/metrik eklenir. Migration `V350__push_outbox.sql` (`pso350_`), paket `edu.bingol.backend.notification.outbox`.
- `GET /api/admin/push/outbox/stats` → `{ "enabled": true, "holdWhenDisabled": false, "pending": 3, "sending": 0, "failed": 1, "dead": 0, "sentLast24h": 120, "oldestPendingAgeSeconds": 12 | null, "oldestPendingAt": "…" | null }`.
- `POST /api/admin/push/outbox/retry-dead` → `{ "requeued": 4 }` (DEAD kayıtlar PENDING'e döner, deneme sayacı sıfırlanır).
- Sağlık: `/actuator/health` → `pushQueue` (`pending`, `dead`, `oldestPendingAgeSeconds`; ölü kayıt ya da 15 dk'dan eski bekleyen varsa `WARN`). Metrikler: `push.outbox.enqueued|sent|failed|dead|skipped` sayaçları, `push.outbox.pending` ölçeri.
- Ayarlar: `app.push.outbox.enabled` (varsayılan true), `.poll-ms` (5000), `.batch-size` (500), `.max-attempts` (6), `.hold-when-disabled` (false: FCM kimliği yokken kayıt yazılmaz/`skipped` sayılır; true: PENDING'de bekler).

## İSTEK(web→backend): Operasyon paneli (`/admin/ops`)
`İSTEK(web→backend):` Panel `/actuator/health` ayrıntısına ulaşamaz (prod'da `show-details=never`, nginx yalnız `/api`,`/files`,`/ws` vekiller). Aşağıdaki uçlar yoksa sayfa ilgili kartta "veri yok" gösterir (404/501 zarifçe karşılanır); hepsi `ADMIN`.
- `GET /api/admin/ops/health` -> `{ "status": "UP|DOWN|WARN", "components": { "db": {"status":"UP"}, "redis": {...}, "mailQueue": {"status":"UP","details":{"pending":0,"dead":0}}, "fcm": {...}, "pushQueue": {...} } }` (`/actuator/health` bileşenleri, ayrıntı dahil; `details` düz anahtar-değer).
- `GET /api/admin/ops/mail-outbox/stats` -> `{ "pending": 0, "sending": 0, "dead": 0, "sentLast24h": 0, "oldestPendingAgeSeconds": null }`; `POST /api/admin/ops/mail-outbox/retry-dead` -> `{ "requeued": 0 }` (isteğe bağlı).
- `GET /api/admin/ops/backup-status` -> `{ "status": "OK|FAILED|UNKNOWN", "lastSuccessAt": "…"|null, "lastAttemptAt": "…"|null, "sizeBytes": 123|null, "message": "…"|null }` (BE2 durum dosyasından okunur).
- `GET /api/admin/ops/transcode/stats` (isteğe bağlı) -> `{ "pending": 0, "processing": 0, "failed": 0, "doneLast24h": 0 }`.
- Dış bağlantılar: yönetici ayarları `ops_sentry_url`, `ops_grafana_url` (yalnız `https://`; `PUT /api/admin/settings/{key}` ile, panel okur ve yazar).
- Push kuyruğu için mevcut `GET /api/admin/push/outbox/stats` ve `POST .../retry-dead` kullanılır (BE4 bölümü).

---

## [HAZIR] Mobil ortak yerel hatırlatma servisi (`lib/core/notify/local_reminders.dart`)

Mobil-içi ortak servis (backend API'si yok). Akademik UI (M2) ders/sınav hatırlatmalarında kullanır:
- `LocalReminders.instance.replaceGroup(group, List<LocalReminder>)`: grubu tek seferde değiştirir (eskiler silinir, geçmiştekiler atılır, en yakın 60 tutulur). `schedule(group, r)` tek kayıt ekler/günceller; `cancel(group, id)`, `cancelGroup(group)`, `cancelAll()` (çıkışta otomatik çağrılır).
- `LocalReminder(id, at, title, body, channel = ReminderChannel.academic, payload = {targetType: ..., targetId: ...})`; `id` grup içinde benzersiz int. Dokunuşta `payload` push ile aynı yönlendirici tablosundan geçer (bilinmeyen -> Bildirimler).
- `registerProvider(group, () async => [...])` + `rescheduleAll()`: açılışta/ders programı değişince çağrılır. Cihaz yeniden başlayınca native taraf kayıtlı alarmları kendisi yeniden kurar.
- Kanal kimlikleri: `academic`, `social`, `poll`, `event`. Eski `ReminderService` (`bu_kampus/academic` -> `replaceReminders`) native tarafta 'academic' grubuna eşlenir, değişiklik gerekmez.
- iOS'ta native kod yoktur: sessizce no-op.

Push `targetType` yönlendirme tablosu (mobil, `lib/core/push/push_targets.dart`): CONVERSATION/MESSAGE, EVENT*, COMMUNITY, NEWS/ANNOUNCEMENT (haber), ANNOUNCEMENT_DEPT (bölüm duyurusu), POST/POST_LIKE/POST_COMMENT/COMMENT_REPLY/POST_MENTION (+`commentId`), USER/USER_FOLLOW (profil), POLL/POLL_* , STORY (`targetId` = hikâye sahibinin kullanıcı kimliği), TICKET, FEEDBACK, EXAM/TIMETABLE/ACADEMIC_*; diğerleri Bildirimler listesi.

İSTEK(mobil→backend): (1) Bölüm duyurusu bildirimi şu an `targetType: "ANNOUNCEMENT"` gönderiyor ve haber duyurusuyla çakışıyor; bölüm duyuruları için `targetType: "ANNOUNCEMENT_DEPT"` (+`targetId`) gönderilsin. (2) Bildirim tercihleri `GET/PUT /api/notifications/preferences` yalnız `news, announcements, events, messages, communities` (+`subtypes`) tanıyor; mobil ekran yeni kategoriler için `subtypes.POST_MENTION`, `subtypes.USER_FOLLOW` kullanır. Anket (`polls`), akademik duyuru (`academicAnnouncements`) ve hikâye (`stories`) için ana bayrak anahtarları eklenirse mobil otomatik gösterir (yanıtta anahtar yoksa satır gizlenir). (3) STORY bildirimi için `targetType: "STORY"`, `targetId: <hikâye sahibi userId>`.

- `[HAZIR] BE1:` `/api/admin/ops/health`, `/mail-outbox/stats`, `/mail-outbox/retry-dead`, `/backup-status` uygulandi (`admin/AdminOpsController`); yanitlar yukaridaki sema ile ayni (`sending` her zaman 0: ayri SENDING durumu yok; `mail-outbox/stats.pending` = PENDING+FAILED). `transcode/stats` YOK (404). Yedek durum dosyasi: `app.ops.backup-status-file` (varsayilan `/var/backups/last_success`; icinde `backup_last_success_timestamp_seconds <sn>` satiri ya da dosya mtime), `app.ops.backup-max-age-hours` (36).

## [HAZIR] Gönderi sosyal

> **Güncelleme 2026-10-28:** kaydet, #etiket, @bahsetme, trend etiket, hikâyeler ve beğenenler listesi kaldırıldı (uçlar `410 FEATURE_REMOVED`); yalnız takip/akış kapsamları kalır. Geçerli sözleşme: POSTS_DESIGN.md başındaki kutu.

Paketler: `post/social` (kaydet, @etiket, #etiket), `post/follow` (takip), `post/story` (hikâye). Migration `V340__post_social.sql` (önek `soc340_`). Hepsi JWT ister. Hata gövdesi `{code,message}`. Sayfalama: `?cursor=&size=` -> `{items, nextCursor}`. Ayrıntı: `docs/changes/post.md`, `docs/MOBILE_API_GUIDE.md`.

### 1. Kaydetme
- `PUT /api/posts/{id}/save` -> 200 `{saved:true}` (idempotent). `DELETE /api/posts/{id}/save` -> 200 `{saved:false}`. Dakikada 120. Gizli/silinmiş/engelli gönderi -> 404 `POST_NOT_FOUND` (kaydı kaldırma her zaman 200).
- `GET /api/posts/saved?cursor&size` (size<=20) -> `{items:[PostView], nextCursor}`; yalnız kendi listem, kaydetme zamanına göre yeni->eski; gizlenen/silinen gönderiler listeden düşer. Kaydeden sayısı YOK.
- PostView yeni alanlar (geriye uyumlu): `savedByMe: bool`, `mentions:[{id,displayName}]`, `hashtags:["etiket"]`.

### 2. @Etiketleme (mention)
- Metin biçimi (istemci yazar): `@[Ad Soyad](uid:123)`. Sunucu ayrıştırır, en çok 10 (11+ -> 400 `MENTION_TOO_MANY`); aktif+doğrulanmış olmayan ya da engel ilişkisindeki kullanıcı `mentions` listesinden sessizce düşer (metin korunur). `text` alanında biçim aynen korunur.
- PostView ve CommentView: `mentions:[{id,displayName}]` (geçerli olanlar; bakanla engel ilişkisi olanlar çıkarılır).
- Bildirim `POST_MENTION` ("X seni bir gönderide/yorumda etiketledi"), `targetType:"POST"`, `targetId`, `data.commentId` (yorum için). Kendi etiketi, engelli ilişki ve düzenlemede zaten etiketli olan için yok.
- `GET /api/users/mention-suggest?q=&postId=&size=8` (size<=8, `q` <=40; boş q = yalnız öncelikli kişiler) -> `[{id,displayName,avatarUrl,department}]`. Öncelik: gönderi sahibi/yorumcular (postId verilirse), takip ettiklerim, sohbet ettiklerim, aynı bölüm; yalnız aktif doğrulanmış; engeller hariç. Dakikada 60.

### 3. #Etiket
- Metindeki `#etiket` (Türkçe harf/rakam/_; 2-40 karakter; yalnız rakam olmaz; en çok 10, fazlası yok sayılır). Normalize: Türkçe kurallı küçük harf (I->ı, İ->i); arama anahtarı aksansız (ı->i, ş->s, ğ->g, ü->u, ö->o, ç->c). Yasaklı etiket (`ContentGuard`) -> 422 `CONTENT_PROFANITY` (`field:"hashtag"`). Düzenlemede etiketler güncellenir.
- `GET /api/hashtags/trending?size=10` (<=20; son 48 saat gönderi sayısı, 1 saat önbellek) -> `[{tag, display, postCount}]`.
- `GET /api/hashtags/{tag}/posts?cursor&size` -> `{items:[PostView], nextCursor}` (yeni->eski; silinen/gizli yok; engelliler gizli). `{tag}` aksanlı ya da aksansız; geçersiz -> 400 `HASHTAG_INVALID`; bilinmeyen -> boş liste.
- `GET /api/hashtags/suggest?q=` -> `[{tag, display, postCount}]` (en çok 8). Dakikada 60.

### 4. Takip
- `POST /api/users/{id}/follow` -> 200 `{following:true, followerCount}` (idempotent). `DELETE /api/users/{id}/follow` -> 200 `{following:false, followerCount}`. Kendini takip: 400 `FOLLOW_SELF`. Engel ilişkisi / yok / pasif: 404 `USER_NOT_FOUND`. Dakikada 60.
- `GET /api/users/{id}/followers|following?cursor&size` (<=30, varsayılan 20) -> `{items:[{id,displayName,avatarUrl,department,followedByMe}], nextCursor}`; engel ilişkisindeki kişiler listelenmez, engelli kullanıcının listesi boştur. (Profil gizlilik ayarında takipçi listesi seçeneği yoktur.)
- `GET /api/users/me/follow-suggestions?size=10` -> `[{id,displayName,avatarUrl,department,reason:"CLUB"|"GRADE"|"DEPARTMENT"}]` (zaten takip edilenler ve engeller hariç).
- Profil (`GET /api/users/{id}`) yeni alanlar: `followerCount`, `followingCount`, `followedByMe` (diğer PublicProfile kullanımlarında null).
- Bildirim `USER_FOLLOW` ("X seni takip etti"), `targetType:"USER"`, `targetId:<takipçi id>`; yalnız gerçek yeni takipte (tekrar istek bildirim üretmez); alt tür tercihi `USER_FOLLOW` ile kapatılabilir (mevcut alt tür tercih ucu).

### 5. Akış kapsamları
- `GET /api/feed?scope=latest|popular|following|department&cursor&size`. `following` = takip ettiklerim + kendim (yeni->eski). `department` = profil bölümüm ile aynı bölümdeki kullanıcıların gönderileri; bölüm yoksa `items:[]` ve `hint:"NO_DEPARTMENT"` (FeedPage'e eklenen opsiyonel alan; diğer kapsamlarda null). Bilinmeyen kapsam 400 `FEED_SCOPE_INVALID`.

### 6. Hikâyeler (24 saat)
- Medya: mevcut `POST /api/posts/media` ile yüklenir (id; saatte 30 yükleme kotası). Video <= `app.story.video-max-seconds` (30 sn).
- `POST /api/stories` `{mediaId?, text?, caption?, background?}` -> 201 StoryView. Tür: mediaId varsa IMAGE/VIDEO; yoksa `text` zorunlu (TEXT; `background` `#RRGGBB`, yoksa `#1B4F9C`, geçersiz -> 400 `STORY_BACKGROUND_INVALID`). `caption` <=200, `text` <=200 (`STORY_TOO_LONG`). Saatte 20. Küfür filtresi 422. Video 30 sn üzeri 400 `STORY_VIDEO_TOO_LONG`. Medya yalnız kendi, bağlanmamış (aksi 400 `POST_MEDIA_INVALID`). Hiçbiri yoksa 400 `STORY_EMPTY`.
- `GET /api/stories/tray` -> `[{user:{id,displayName,avatarUrl}, hasUnseen, latestAt, count, mine}]` (kendim + takip ettiklerim; kendim her zaman ilk ve hikâyem yoksa listede yok, sonra görülmemiş, sonra latestAt azalan).
- `GET /api/users/{id}/stories` -> `[StoryView]` (aktif, eskiden yeniye). Engel ilişkisinde boş.
- `POST /api/stories/{id}/view` -> 204 (idempotent; sahibi için sayılmaz; görünmez/süresi dolmuş -> 404 `STORY_NOT_FOUND`). `GET /api/stories/{id}/viewers?cursor&size` (<=30; yalnız sahip, aksi 403 `STORY_FORBIDDEN`) -> `{items:[{id,displayName,avatarUrl,viewedAt}], nextCursor, total}`. `DELETE /api/stories/{id}` -> 204 (sahibi ya da ADMIN, başkası 403).
- StoryView: `{id, author:{id,displayName,avatarUrl}, kind:"IMAGE"|"VIDEO"|"TEXT", media:{id,kind,url,thumbUrl,width,height,durationMs}|null, text, caption, background, createdAt, expiresAt, viewedByMe, viewCount (yalnız sahibe, aksi null), mine}`. Medya `GET /api/posts/media/{id}` ile akar.
- 24 saat dolunca görünmez; `StoryCleanupJob` bitişten 24 saat sonra kalıcı siler. Yanıt/tepki YOK.

### 7. Moderasyon / yönetici / KVKK
- Rapor: `POST /api/reports` `targetType:"STORY"`.
- `GET /api/admin/stories?cursor&size&q&hidden=`, `POST /api/admin/stories/{id}/hide` `{reason}`, `POST /api/admin/stories/{id}/unhide`, `DELETE /api/admin/stories/{id}`.
- KVKK: dışa aktarım bölümleri `savedPosts`, `follows`, `stories`; hesap silmede temizlenir.

### Hata kodları
`MENTION_TOO_MANY` 400, `FOLLOW_SELF` 400, `FEED_SCOPE_INVALID` 400, `HASHTAG_INVALID` 400, `STORY_NOT_FOUND` 404, `STORY_FORBIDDEN` 403, `STORY_EMPTY` 400, `STORY_TOO_LONG` 400, `STORY_VIDEO_TOO_LONG` 400, `STORY_BACKGROUND_INVALID` 400; mevcut: `POST_NOT_FOUND`, `USER_NOT_FOUND`, `POST_MEDIA_INVALID`, `CONTENT_PROFANITY`, 429.

## [HAZIR] Medya dönüştürme ve gönderi videosu şifreleme (BE2, V360)

İstemci sözleşmesi **değişmedi**: `POST /api/posts/media`, `GET /api/posts/media/{id}[?thumb=true]` (Range 206/416, ETag), `Uploaded`/`MediaView` şemaları aynı. Davranış farkları (istemci için görünür olanlar):
- Yüklenen video arka planda 720p/H.264'e dönüştürülebilir; dönüşüm bitince `url` **aynı kalır** ama içerik (boyut, süre, çözünürlük, ETag) değişir. İstemci `ETag` ile tazeler; `width/height/durationMs` sonraki gönderi görünümlerinde güncel gelir. Yükleme yanıtındaki `bytes` orijinal boyuttur.
- Poster gönderilmediyse ffmpeg ilk anlamlı kareden üretir; yükleme yanıtında `thumbUrl` yine `null` olabilir, **sonraki görünümlerde dolu** gelir (istemci `thumbUrl == null` durumunu zaten işlemeli).
- Gönderi videosu diskte şifrelidir (istemciye etkisi yok).
- İsteğe bağlı CDN modu (varsayılan **kapalı**): açık ve `MEDIA_CDN_REDIRECT=true` ise `GET /api/posts/media/{id}` `302` + `Location: https://<cdn>/files/cdn/post/{id}?t=0|1&exp=&sig=` dönebilir (`Cache-Control: no-store`). İstemci yönlendirmeyi izlemeli ve `Authorization` başlığını **yeni kökene taşımamalıdır**. Mobil/web ekipleri bunu bilmeden açılmaz; bayrak yalnız operasyon tarafından açılır.

DEĞİŞİKLİK: yok (şema aynı). `status` alanı eklenmedi; gerekirse `transcodeStatus` (`PENDING|DONE|FAILED|null`) `Uploaded`/`MediaView`'e geriye uyumlu eklenebilir.
