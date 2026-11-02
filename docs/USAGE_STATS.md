# Kullanım istatistikleri (USAGE)

Kullanıcıların uygulamada en çok hangi sayfalarda gezindiğini ve neler yaptığını **toplulaştırılmış, kimliksiz** olarak toplar; yönetim panelinde **Analitik > Kullanım** sekmesinde gösterir. Migration: `V1220__usage_stats.sql` (ayrılan aralık V1220-V1239).

## 1. Olay sözleşmesi (mobil → `POST /api/analytics/events`)

Gövde biçimi **değişmedi**: `{events:[{name, screen?, props?, at?}]}` (≤ 50 olay, dakikada 30 istek, kullanıcı başına günde 2000 olay). Eski istemciler çalışmaya devam eder.

| `name` | `screen` | `props` |
|---|---|---|
| `screen_view` | kararlı ekran anahtarı, `[a-z0-9_]{1,40}`. Mobil (`core/analytics_screens.dart`): alt sekmeler `home`, `discover`, `chat`, `clubs`, `profile`; sayfalar `news_list`, `news_detail`, `menu`, `events`, `event_detail`, `club_detail`, `chat_detail`, `search`, `settings`, `notifications`, `academic_hub`, `poll_list`, `support`, `login`, `register` vb.; eşlenmeyen sayfa `other` | `from` = önceki ekran anahtarı, `ms` = **önceki** ekranda geçen süre (milisaniye, tamsayı, istemci üst sınırı 30 dk) |
| `app_open` | - | - (oturum sayısı = `app_open` sayısı) |
| `app_background` | - | `dur` = oturum süresi (saniye, tamsayı) |
| eylem olayları. Mobilde gerçekten gönderilenler: `news_open`, `announcement_open`, `event_rsvp`, `event_checkin`, `event_create`, `event_apply`, `club_join`, `club_leave`, `club_create`, `post_like`, `post_create`, `message_send`, `chat_create`, `poll_vote`, `menu_view`, `share`, `favorite_add`, `exam_open`, `exam_add`, `course_add`, `timetable_open`, `user_follow`, `profile_edit`, `password_change`, `language_change`, `ticket_create`, `feedback_send`, `qr_scan_open`, `login_success`, `register_step` (props `step` 1-3), `register_done`, `search_query` (props `scope`; **sorgu metni gönderilmez**). Henüz mobilde yok: `map_place_open`, `notification_open` | isteğe bağlı | en çok 5 anahtar, skaler |

- `screen_view`, `app_open`, `app_background` ve `app_error` (istemci hata telemetrisi) dışındaki **her olay adı eylem sayılır** (sunucuda beyaz liste yok; ad deseni `[a-z0-9_]{1,40}`).
- **Platform / sürüm:** başlıklar `X-App-Platform` (yoksa `X-Device-Platform`, mobil bunu zaten gönderir: `android|ios`) ve `X-App-Version`; başlık yoksa olayın `props.p` / `props.v` değeri. Bu bilgi kişiye bağlanmaz; yalnız gece toplulaştırmasında kırılım için okunur. Sürüm kırılımında `+build` eki atılır (`2.0.6+20006` → `2.0.6`).
- **Doğrulama (ingest):** ad deseni, en çok 5 özellik, değer ≤ 100 karakter, `'@'` içeren ya da 10+ ardışık rakam içeren olay **tüm istek 400 `INVALID_EVENT`**. Tamsayı gibi gönderilen ondalık (`1500.0`) tamsayıya çevrilir.
- **Toplulaştırmada ek süzgeç (ham tabloya dokunmadan):** geçerli ekran anahtarı `^[a-z0-9_]{1,40}$` değilse (eski sürümlerin `/news` gibi rota adları) olay ekran raporlarına girmez; `props.from` aynı desende olmalı; `ms` yalnız `0..1.800.000` (30 dk üstü atılır); `dur` yalnız `0..86.400`.

## 2. Raporlar

`GET /api/admin/analytics/usage/*` — `from`/`to` (`yyyy-MM-dd`, Europe/Istanbul, varsayılan son 30 gün, en çok 366 gün; bozuk aralık 400 `INVALID_RANGE`). İzin: `analytics.read` (mevcut `/api/admin/analytics(/.*)?` kuralı kapsar). Yanıtlar `usage` ad alanında 5 dk önbelleklenir (`CacheService`, `CACHE_ENABLED=false` ile kapanır).

| Uç | İçerik |
|---|---|
| `summary` | toplam oturum / ekran görüntüleme, ortalama günlük aktif, ortalama oturum süresi (sn), en çok gezilen ekran, en çok yapılan eylem, günlük seri |
| `top-screens` | ilk 20 ekran: `views`, `userDays`, `avgDailyUsers`, `avgSeconds`, `medianSeconds`, `exitPercent`, `trend[]` (günlük görüntüleme, `dates[]` ile aynı uzunluk) |
| `top-actions` | ilk 20 eylem: `count`, `userDays`, `adoptionPercent`, `trend[]` |
| `flow` | en çok 30 geçiş kenarı `{from,to,count}` + `totalTransitions` |
| `hourly` | 168 hücre `{dow 1..7 (1=Pzt), hour 0..23, sessions, views}` + en yoğun hücre (`peak`) |
| `segments` | `platforms`, `versions`, `faculties`, `departments` (+ `kAnonymity`) |
| `features` | haber, yemek, etkinlik, kulüp, sohbet, harita, anket, akademik, arama: son 30 gün kullanan tekil kullanıcı / MAU |
| `POST refresh` | 202 `{refreshedDay}`: bugünün kısmi özetini hemen yeniden hesaplar (dakikada en çok 2); duman betiği ve "şimdi tazele" için; izin `system.write` (yalnız FULL), `analytics.read` yetmez |

Tanımlar:
- **userDays** = günlük tekil kullanıcıların aralık boyunca toplamı (tekil kişi sayısı **değil**; ham tablo taranmadan tekil kişi hesaplanamaz). `avgDailyUsers = userDays / veri olan gün`.
- **Süre:** bir ekranın süresi, o ekrandan çıkıp **sonraki** `screen_view`'in `from`/`ms` değerinden gelir ve önceki ekrana yazılır. Medyan, 11 kovalı histogramdan (`UsageBuckets`, 0-1-2-5-10-20-30-60-120-300-600-1800 sn) kova içi doğrusal ara değerle bulunur: ham süre saklanmaz.
- **Çıkış oranı** = `(görüntüleme - o ekrandan çıkan geçiş) / görüntüleme`, yani ardından başka ekrana geçilmeyen ziyaret yüzdesi.
- **Benimseme** = eylemi yapan günlük kullanıcıların toplamı / olay gönderen günlük kullanıcıların toplamı (`an_users`; olay göndermeyen eski sürümler paydaya girmez).
- **Özellik eşlemesi** `UsageFeatures` (ekran/eylem anahtarı öneki → özellik); yeni ekran/eylem anahtarı eklenince yalnız orası güncellenir. `features` yalnız **tamamlanmış** gün için, gece hesaplanır (30 günlük pencerede tekil kullanıcı; ham tablo 45 gün tuttuğu için hesap yalnız son günler için yapılabilir). İlk gece öncesi `asOf = null`, `items = []`.

## 3. Depolama ve toplulaştırma

Günlük özet tabloları (hepsi **kalıcı**, hiçbirinde kullanıcı kimliği sütunu **yok**):

`analytics_usage_day`, `analytics_screen_daily`, `analytics_screen_dur_daily`, `analytics_action_daily`, `analytics_flow_daily`, `analytics_hour_daily`, `analytics_segment_daily`, `analytics_feature_snapshot`. Ham `analytics_event` tablosuna yalnız `platform`, `app_version` sütunları eklendi (45 gün saklama değişmedi, `app.dbmaint.analytics-raw-days`).

- **Gece (03:00, `DbMaintenanceJob` → `UsageRollup.rollUpMissingDays`):** `complete = true` olmayan günler + son `app.analytics.usage-recompute-days` (2) gün yeniden yazılır (geç gelen olaylar); ilk çalışmada 44 güne kadar geri doldurma. Özellik anlık görüntüsü yalnız dünün için. Toplulaştırma başarısızsa **ham olay silme atlanır** (veri kaybı önlemi, mevcut kural).
- **Bugün:** `UsageRollup.refreshToday` `app.analytics.usage-live-ms` (900000 = 15 dk; 0 = kapalı) aralıkla bugünün kısmi satırlarını (`complete = false`) tazeler; `SchedulerLock("usage-live")`.
- Bir gün **tek taramada** ham tablodan geçici tabloya (`ON COMMIT DROP`) alınır, tüm özetler ondan türetilir; satırlar silinip yeniden yazılır (idempotent). Sorgular PostgreSQL'e özeldir (jsonb, `FILTER`, `starts_with`); H2 testlerinde çalışmaz, bkz. Doğrulama.
- Raporlar **yalnız** bu özet tablolarını okur (ham tablo taranmaz), parametreli `NamedParameterJdbcTemplate`, `statement_timeout` 8 sn içinde (aralık ≤ 366 gün × ≤ 20 ekran).
- Bu tablolar `RetentionTables` (şişen log tabloları için dışa aktarma/temizleme beyaz listesi) listesine **alınmadı**: günlük birkaç yüz satır, kimliksiz ve kalıcı özet olarak tasarlandı (bkz. `docs/DATABASE.md` §18). Büyüme tahmini: gün başına ≈ 20 ekran + 25 eylem + 500 kenar (üst sınır) + 24 saat + 30 kırılım + 11 kova × ekran ≈ ≤ 1,5 bin satır/gün ≈ ≤ 0,5 milyon satır/yıl.

## 4. Gizlilik ve k-anonimlik (KVKK)

- Hiçbir uçta ve tabloda **tek kullanıcıya inen kırılım ya da gezinti geçmişi yok**. Kullanıcı kimliği yalnız ham tabloda (45 gün) durur; hesap silinirse oradan da silinir (`ActivityRepository.purgeUser`).
- **K-anonimlik:** `faculty`, `department` ve `version` kırılımlarında gün içinde **tekil kullanıcısı `k`'dan az** olan gruplar **yazılırken** `other` altında birleştirilir; `other` de `k`'dan azsa **hiç yazılmaz**. `k = app.analytics.k-anonymity` (`ANALYTICS_K_ANONYMITY`, varsayılan **10**, taban **5**: daha düşük değer 5'e yükseltilir). Platform (2-3 değer) muaftır. Kırılım rapor aşamasında ayrıca en çok 12 öğe gösterir, kuyruk `other`'a katılır. Fakülte/bölüm, `app_user`'ın **güncel** değeridir.
- Arama sorguları metin olarak **gönderilmez/saklanmaz** (`search_query` yalnız `scope`).
- Kullanıcı verilerimi indir (`analyticsEvents`) ham olayları zaten içerir; `platform`/`app_version` ham satırda saklandığından dışa aktarmaya `EventRow` değişmeden girmez (kullanıcı kendi cihaz sürümünü zaten bilir; eklenmedi).

### Gizlilik metninde belirtilmesi önerilir (metne dokunulmadı)

`docs/LEGAL_NOTES.md` ve sözleşme metinleri **değiştirilmedi** (sürümlü sözleşme yeniden onay tetikler). Hukuk danışmanı onayıyla bir sonraki sözleşme sürümüne şu eklemeler önerilir: (1) uygulamada gezinilen ekranların, ekranda geçirilen sürenin ve yapılan eylemlerin (arama sorgusu metni **hariç**) hizmeti iyileştirmek amacıyla toplandığı; (2) bu verilerin 45 gün sonra ham olarak silindiği, sonrasında yalnız kimliksiz toplulaştırılmış özet olarak tutulduğu; (3) cihaz platformu ve uygulama sürümünün teknik uyumluluk için işlendiği; (4) fakülte/bölüm bazlı özetlerin 10 kişiden küçük gruplar için gösterilmediği.

## 5. Doğrulama

- Birim testleri (H2 gerekmez): `UsageBucketsTest`, `UsageFeaturesTest`, `UsageReportServiceTest`, `UsageRollupTest`, `AnalyticsServiceTest` (platform/sürüm/ondalık).
- **PostgreSQL testi:** `UsageRollupPostgresTest` gerçek PostgreSQL 16'da V1220 + toplulaştırma SQL'ini + rapor sorgularını koşar; `USAGE_PG_URL` (`USAGE_PG_USER`, `USAGE_PG_PASSWORD`) tanımlı değilse atlanır. Örnek: `docker network create usage-net; docker run -d --name usage-pg --network usage-net -e POSTGRES_PASSWORD=postgres postgres:16`, ardından Maven konteynerini `--network usage-net -e USAGE_PG_URL=jdbc:postgresql://usage-pg:5432/postgres` ile çalıştırın.
- Duman: `BASE=http://localhost:8080 ADMIN_EMAIL=... ./scripts/smoke-usage-stats.sh` (olay gönder → `POST /usage/refresh` → 7 rapor, yetki, aralık, gizlilik).
- Web: `AnalyticsPage` `?tab=usage`; testler `pages/admin/analytics/usage/*.test.*`, `search/usage.test.ts`.

## 6. Ayarlar

| Anahtar | Varsayılan | Anlam |
|---|---|---|
| `app.analytics.k-anonymity` (`ANALYTICS_K_ANONYMITY`) | 10 (taban 5) | k-anonimlik eşiği |
| `app.analytics.usage-live-ms` (`ANALYTICS_USAGE_LIVE_MS`) | 900000 | bugünün kısmi özetini tazeleme (0 = kapalı) |
| `app.analytics.usage-recompute-days` (`ANALYTICS_USAGE_RECOMPUTE_DAYS`) | 2 | gece yeniden hesaplanan son gün sayısı |
| `app.dbmaint.analytics-raw-days` | 45 | ham olay saklama (değişmedi) |
