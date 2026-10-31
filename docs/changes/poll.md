# Anket ve oylama (poll)

Paket `edu.bingol.backend.poll`, migration `V330__polls.sql` (önek `pol330_`), çeviri `i18n/poll*.properties` (tr/en/ar; `spring.messages.basename` listesine eklendi). Sözleşme: `docs/API_CONTRACTS_V2.md` → "Anket ve oylama".

## Davranış özeti
- **Türler:** `SINGLE`, `MULTI` (`maxChoices`), `RATING` (1–5 yıldız; 5 sabit seçenek), `RANKED` (sıralı seçim; 1. tercih sayısı + Borda puanı).
- **Kapsamlar:** `GLOBAL` (yalnız ADMIN oluşturur), `COMMUNITY` (kulüp yöneticisi/sahibi; yalnız aktif üyeler görür/oy verir; varsayılan gizli oy = kulüp seçimi), `MENU` (yemek listesi günü; `GET /api/polls/menu/today` ilk istekte otomatik oluşturur, her gece 00:05 de önceden oluşturulur).
- **Gizli oy:** `poll_vote.user_id` yalnız tekillik/değiştirme için tutulur; hiçbir API/yönetici/CSV bunu göstermez. Kullanıcı yalnız kendi oyunu (`myVote`) ve `GET /api/users/me/export` → `polls` bölümünde görür.
- **Sonuç görünürlüğü:** `ALWAYS | AFTER_VOTE | AFTER_CLOSE`; yönetici uçları her zaman görür.
- **Hedef kitle:** `audience {faculty, department, grade}` profil alanlarıyla büyük/küçük harf duyarsız eşleşir.
- **Yarış güvenliği (RL1b):** oy/değiştirme/geri çekme **anket satırını kilitlemez** (eski `PESSIMISTIC_WRITE`: tek ankete 300-600 eş zamanlı oy sıraya girip `lock_timeout` aşıyor, 503 `DB_TIMEOUT` veriyor ve Hikari bağlantılarını tutuyordu). Kural denetimi ve seçenek çözümleme işlem DIŞINDA yapılır; aynı kullanıcının istekleri kendi `poll_ballot` satırında (yeni seçmen: `(poll_id,user_id)` UNIQUE) sıraya girer, farklı kullanıcılar birbirini beklemez; ballot + oy satırları önce, sayaçlar EN SON ve seçenek kimliğine göre sıralı atomik `UPDATE ... SET x = x + :d` ile yazılır (sıcak satır kilidi yalnız bu birkaç ifade ile commit arasında; sabit kilit sırası = kilitlenme yok). Anketin hâlâ açık olduğu `PollRepository.addVotersIfOpen` ile aynı ifadede doğrulanır (okuma-yazma arası kapanırsa işlem geri alınır, 409 `POLL_CLOSED`/`POLL_NOT_OPEN`). Eşzamanlı ilk iki istek tekillik kısıtında çarpışırsa yeniden denenir (idempotent/değişiklik yolu); sıcak sayaçta `lock_timeout` olursa işlem geri alınmıştır, en çok 2 kez kısa beklemeyle yeniden denenir, yine olmazsa 503 `DB_TIMEOUT`. `(poll_id,user_id,option_id)` UNIQUE son savunmadır. Ölçüm: `docs/perf-results/rl1/README.md` (önce 600 eş zamanlı oyda 10 adet 503 ve p95 35 sn; sonra 0 hata, p95 17 sn; veri bütünlüğü her turda tam).
- **Kapanış işi** (`PollCloseJob`, varsayılan her 10 dk, `app.poll.close-cron`; `SchedulerLock "poll-close"`): süresi dolan anketleri `CLOSED` yapar, "anket açıldı" (`notify=true`) ve "24 saat kaldı" (yalnız oy vermemiş uygun kullanıcılara) bildirimlerini gönderir.
- **Bildirim:** `GLOBAL` → `ANNOUNCEMENT`, `COMMUNITY` → `COMMUNITY` türü (kullanıcı tercihi kapalıysa gitmez); alıcı dilinde (`notif.poll.opened.*`, `notif.poll.closing.*`); push `target=POLL`.
- **Küfür filtresi** başlık/açıklama/seçeneklerde (`CONTENT_PROFANITY` + `field`).
- **Hız sınırları:** oy 60/dk, oluşturma 10/saat, okuma 120/dk, diğer yazma 60/dk, yönetici 120/dk.

## KVKK
- `AccountDataPurger`: `poll_ballot` silinir; `poll_vote.user_id` NULL (anonimleşir, sayaçlar `poll_option.vote_count` / `poll.voter_count` korunur); `poll.created_by` NULL.
- `DataExporter` `polls`: kullanıcının oyları (seçenek metniyle, gizli ankette de) ve oluşturduğu anketler.

## Kısıtlar / notlar
- Menü anketi için bir gün = bir anket (`UNIQUE menu_date`); öğün ayrımı yok (menü modülü günlük tek satır tutar). Silinmeden aynı gün yeniden oluşturulamaz.
- `RANKED` yüzdesi 1. tercih sayısına göredir; sıralama için `score` (Borda) kullanın.
- Kapanış işi PostgreSQL/H2 farkı gerektirmez; ancak `FOR UPDATE` kilidi ve kısmi indeksler gerçek PostgreSQL'de `scripts/smoke-poll.sh` ile doğrulanır.

## B1: liste sayaçları

`GET /api/polls` yanıtı (`PollPage`) iki opsiyonel alan taşır: `totalCount` (istenen `scope` için toplam kayıt) ve `openCount` (kullanıcıya görünen açık anket sayısı). Tek `COUNT` sorgusu (`PollRepository.countOpen/countClosed/countMine/countOfCommunity`); açık/kapanan sayımlarında kulüp üyeliği ve hedef kitle (fakülte/bölüm/sınıf, küçük harf+kırpılmış karşılaştırma) SQL'de uygulanır, bu yüzden sayı liste süzgeciyle uyumludur (yönetim istisnası olan kendi hedefli anketleri sayıma dahil değildir). Migration yok.

## W1-F: hedef kitle eşlemesi, ID ile erişim, kulüp silinince anket, CSV, sistem yöneticisi izni (T-040/042/046/047/048)

- **Hedef kitle eşlemesi tek kural (T-042).** `academic/AudienceKey`: boşluk kırpma + `İ I ı` ve Türkçe harfler (`ç ğ ö ş ü â î û`) ASCII'ye indirgenir + birleştirici nokta silinir + küçük harf; **Java (`AudienceKey.of`) ve SQL (`lower(translate(trim(kolon), ...))`) aynı tabloyu kullanır** (PostgreSQL ve H2'de doğrulandı; locale'den bağımsız). Eskiden `LOWER(...)`/`equalsIgnoreCase` "İşletme", "İktisat", "İlahiyat" gibi büyük İ ile başlayan ad/fakülteleri eşlemiyordu: anket sayaçları (`totalCount/openCount`), `turnout.eligible`, bildirim alıcıları (`audienceUserIds`) ve bölüm duyurusu kapsamı sessizce boş kalıyordu. Kullanılan yerler: `PollAccess` (Java eşleme, `eligibleCount`, `audienceUserIds`), `PollRepository.countOpen/countClosed` (JPQL `FUNCTION('translate')`), `DepartmentAnnouncementService`, `AudienceMatch` (sınav), `AcademicCalendarService.scope`.
- Sınıf (`audience.grade`) artık katalog kümesinden olmalı (`PREP, 1..6, MASTER, PHD`; büyük harfe normalize edilir), aksi `422 POLL_INVALID`. Liste sayaçları oluşturanın kendi anketini de sayar (liste = sayaç mantığı).
- **Hedef kitle yalnız listede değil ID ile de geçerli (T-046).** `GET /api/polls/{id}` (ve yönetim dışı tüm erişimler) kitle dışı kullanıcıya `404 POLL_NOT_FOUND`; oluşturan/kulüp yöneticisi/content.write'lı sistem yöneticisi etkilenmez. **Bölüm/fakülte duyurusu (K-19 önerisi (b)):** `GET /api/announcements/{id}` ve `POST /announcements/{id}/read` kapsam dışı kullanıcıya `404 ANNOUNCEMENT_NOT_FOUND`; `GET /api/announcements?scope=all` ("Tümü") **yalnız kapsamsız** (bölüm/fakülte/sınıf boş) duyuruları listeler, başkasının bölüm duyurusu sızmaz. `scope=mine` aynı kuralla (artık büyük İ'li adlarda da) çalışır.
- **Kulüp silinince (T-047):** `PollClubDeletedListener` (`ClubDeletedEvent`, commit sonrası) kulübün `OPEN`/`DRAFT` anketlerini `CANCELLED` yapar (oylar kapanır, sonuçlar kalır; açılış/kapanış bildirim sorguları yalnız `OPEN` taradığı için bildirim durur). Ek olarak `PollAccess.memberCommunityIds` yalnız **yayındaki (ACTIVE)** kulüplerin üyeliğini döner: olay kaçsa da silinmiş kulübün anketi üyeye görünmez/oylanamaz.
- **CSV sonuç görünürlüğü (T-048):** `GET /api/polls/{id}/export.csv` artık `showResults` kuralına uyar: `AFTER_CLOSE` kapanmadan, `AFTER_VOTE` yönetici oy vermeden/kapanmadan `409 POLL_RESULTS_HIDDEN` (yeni kod, `poll*.properties` tr/en/ar). Yönetici paneli ucu (`/api/admin/polls/{id}/export.csv`) ayrıdır ve değişmedi.
- **Sistem yöneticisi izni (T-040):** GLOBAL/MENU anket oluşturma ve başkasının anketini düzenleme/kapatma/silme için `content.write` gerekir (VIEWER → 403); görünürlük için `content.read`. Müdahale `admin_audit`'e (`target_type=POLL`) düşer.
