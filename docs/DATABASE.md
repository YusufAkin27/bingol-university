# Veritabanı tasarımı, saklama ve ölçek (20 bin kullanıcı)

Hedef: 20.000 kayıtlı kullanıcıya kadar veri/log büyüse de veritabanı **cevap vermeye devam eder**, disk şişmez, hiçbir sorgu havuzu kilitlemez. Bu belge tablo envanterini, büyüme/saklama kararlarını, indeks denetimini, PostgreSQL/Redis ayarını ve **yeni kod için sorgu kurallarını** içerir. Migration: `V520__dbscale_indexes_retention.sql`; kod: `edu.bingol.backend.dbmaint`.

## 1. Varsayımlar (tüm tahminler bunlara dayanır)

| Varsayım | Değer |
|---|---|
| Kayıtlı kullanıcı | 20.000 |
| Günlük aktif (DAU) | %30 = 6.000 |
| Aktif kullanıcı başına günlük mesaj | 10 gönderilen (iyimser 4, kötümser 20) |
| Mobil analitik olayı | 25/gün/aktif kullanıcı (screen_view ağırlıklı) |
| Uygulama içi bildirim | 3/gün/kullanıcı (haber, etkinlik, mesaj, kulüp) |
| Cihaz | 1,3 / kullanıcı |
| Satır boyutları | PostgreSQL başlık 24 B + kolonlar; B-ağacı indeks girdisi ~40-50 B/satır |

Rakamlar **tahmindir**; gerçek boyut için `scripts/perf/seed-20k.sql` + `pg_total_relation_size` (bölüm 11).

## 2. Tablo envanteri ve büyüme/saklama

Satır büyümesi: K = kullanıcı başına (sınırlı), G = gün/olay başına (sınırsız artar). "1 yıl" = 20k kullanıcıda kararlı durum (saklama uygulanmış). Saklama işleri: `DbMaintenanceJob` (yeni, 03:00) ve mevcut işler.

### 2.1 Şişme riski taşıyan tablolar (en büyük 10 büyüme kaynağı)

| # | Tablo | Büyüme | 1 yıl (kararlı) | Saklama / çözüm |
|---|---|---|---|---|
| 1 | `message` (+ `message_attachment`, `message_reaction`, `message_revision`) | G: 6k×10 = 60k/gün | **22 M satır/yıl, ~6-14 GB** (şifreli gövde ~250 B + 9 indeks) | Sınırsız büyür (ürün gereği geçmiş). Yinelenen `idx_message_created` düşürüldü (V520). 100 M satıra yaklaşınca arşiv/bölümleme (bölüm 6). Silinmiş mesaj: `DeletedMessageRetention` |
| 2 | `analytics_event` | G: 6k×25 = 150k/gün | **Eskiden 180 gün = 27 M satır (~5 GB)**; şimdi 45 gün = **6,7 M satır, ~1,2 GB** | Ham olay **45 gün** (`app.dbmaint.analytics-raw-days`), kalıcı günlük özet `analytics_event_daily` (günde ~100-300 satır). Ad indeksi düşürüldü, `created_at` BRIN |
| 3 | `notification` | G: 60k/gün | Eskiden 90 gün = 5,4 M; şimdi okunmuş 30 gün + okunmamış 90 gün + **kullanıcı başına en çok 200** → ≤1,8 M, ~0,8 GB | `DbMaintenanceJob` parçalı silme; `app.notification.*-days`, `app.dbmaint.notification-per-user-cap` |
| 4 | `push_outbox` | G: ~80k/gün | SENT 7 gün → ~0,6 M satır, ~0,25 GB | `PushOutboxWorker.purgeOld` (SENT 7, DEAD 30 gün) |
| 5 | `mail_outbox` | G: ~500-2000/gün (kayıt kodu, sıfırlama, kampanya) | SENT 7 gün (önceden 30) → <20 k satır | `DbMaintenanceJob` SENT `app.dbmaint.mail-sent-days`=7, DEAD 30; `vars_json` ≤4000 B |
| 6 | `activity_daily` | G: 6k satır/gün | 2,2 M satır/yıl (~150 MB) | Önceden sınırsız → 400 gün sonrası silinir |
| 7 | `admin_audit` | G: yönetici yazma istekleri (~2k/gün) | 365 gün ≈ 0,7 M satır, ~0,15 GB | Önceden sınırsız → 365 gün (`app.dbmaint.admin-audit-days`) |
| 8 | `user_device_log` | (kullanıcı, cihaz, IP) tekil: ≈130 k | ~50 MB | 90 gün (`AccessBanRetentionJob`); güncelleme 30 dk'da bir kısıtlı |
| 9 | `message_access_audit`, `club_audit`, `event_moderation_log` | Yönetici/yönetim işlemi başına | Küçük (<100 MB) | Önceden sınırsız → ilk ikisi 730 gün (`app.dbmaint.audit-long-days`); `event_moderation_log` event paketi sahibi, dokunulmadı |
| 10 | `app_user` güncellemeleri (`last_seen_at`) | 6k kullanıcı × 5 dk | Ölü satır/bloat riski (indeksli kolon güncellemesi HOT değil) | Güncelleme aralığı 5 → **15 dk**; `fillfactor=85` + sık autovacuum (V520) |

Diğer log tabloları: `profanity_hit_log`, `blocked_attempt_log` (90 gün, mevcut işler), `mail_campaign_recipient` (kampanya silinince), `support_track_token` + herkese açık talep (365 gün, `PublicSupportService`), `legal_acceptance` (kullanıcı × belge sürümü; hukuki kanıt, silinmez, ~20 k × 4 satır).

### 2.2 Kullanıcıya/içeriğe bağlı sınırlı tablolar

| Grup | Tablolar | Büyüme modeli | 1 yıl, 20k | Saklama |
|---|---|---|---|---|
| Kimlik | `app_user` | K=1 | 20 k satır, ~25 MB | Hesap silme = anonimleştirme |
| Cihaz | `device` | K≈1,3 | 26 k satır | 60 gün görülmeyen token gece silinir (`DeviceCleanupJob`) |
| Tercih | `notification_pref`, `notification_subtype_pref`, `profile_privacy`, `user_follow_stats` | K=1 | 20 k satır her biri | Kullanıcıyla |
| Sohbet | `conversation`, `conversation_member`, `conversation_key`, `chat_room_link` | Konuşma başına; birebir ≈ 3/kullanıcı | ~50 k konuşma, ~100 k üye | Okunmamış sayacı **saklanmaz**, `last_read_message_id` imlecinden hesaplanır (kısmi indeks ile) |
| Moderasyon | `report`, `moderation_*`, `blocked_content_hash`, `user_block`, `suspend_recommendation` | Olay başına | <100 k | Kalıcı (denetim) |
| Topluluk/etkinlik | `community*`, `club_*`, `user_event`, `event_rsvp`, `event_attendance`, `event_*` | Etkinlik başına RSVP (üst sınır: kapasite) | <1 M | Etkinlik/kulüp ile |
| Gönderi/keşfet | `post`, `post_media`, `post_like`, `post_save`, `post_mention`, `user_follow`, `poll*` | Kullanıcı etkileşimi | `post_like`/`user_follow` birkaç M | `PostRetentionJob` (silinmişler); kaldırılan özellik tabloları (`story*`, `post_comment`, `hashtag`, `post_hashtag`) V470 ile DROP edilir — burada dokunulmadı |
| İçerik | `news_item`, `menu_day`, `menu_item_calorie`, `academic_event`, `tt_*`, `department_announcement`, `announcement_read` | Kaynak sitede ≤20/tür/gün; **yinelenen çekilmez** (URL UNIQUE) | `news_item` ~3 k/yıl; `content` TEXT (TOAST, ortalama 8-20 KB) ≈ 60 MB | Kalıcı; `announcement_read` kullanıcı×duyuru |
| Destek | `support_ticket`, `support_message`, `feedback*`, `faq_item`, `support_track_token` | Talep başına | <50 k | Herkese açık talep 365 gün |
| Yapılandırma | `app_setting`, `legal_document`, `profanity_term`, `mail_template_custom*`, `mail_suppression`, `access_ban*` | Sabit/küçük | <10 k | Kalıcı |
| Oturum | `refresh token` | **Redis** (`rt:*`, `rtu:*`), PostgreSQL'de yok | — | TTL 30 gün |

Büyük metin/JSON/bytea kolonları: `news_item.content` (TEXT; tek kopya, ham HTML saklanıp düz metin çift kopya tutulmuyor — arama vektörü ayrı türetilmiş), `message.body_ciphertext` (BYTEA, plaintext şifrelemeden sonra NULL: çift kopya yok), `analytics_event.props` (JSONB; istemci doğrulamalı, olay başına ≤ birkaç yüz bayt), `notification.data` (VARCHAR 1000), `mail_outbox.vars_json` (VARCHAR 4000). Hepsi TOAST ile satır dışı saklanır; liste sorguları bu kolonları seçmemeli (bölüm 9 kural 5).

## 3. Saklama özeti (yapılandırılabilir)

| Anahtar | Varsayılan | Etki |
|---|---|---|
| `app.dbmaint.enabled` / `cron` | true / `0 0 3 * * *` | Gece 03:00 İstanbul, `SchedulerLock` ile tek örnek |
| `app.dbmaint.chunk-size` / `chunk-pause-ms` / `max-chunks-per-table` | 5000 / 50 / 400 | Parçalı silme: her parça ayrı işlem, en çok 2 M satır/tablo/gece, kalanı ertesi gece |
| `app.dbmaint.analytics-raw-days` | 45 | Ham analitik olay |
| `app.notification.retention-days` / `unread-retention-days` | 30 / 90 | Okunmuş / okunmamış bildirim |
| `app.dbmaint.notification-per-user-cap` | 200 | Kullanıcı başına en yeni N bildirim |
| `app.dbmaint.mail-sent-days` / `mail-dead-days` | 7 / 30 | Mail kuyruğu |
| `app.dbmaint.admin-audit-days` | 365 | Yönetici işlem kaydı |
| `app.dbmaint.audit-long-days` | 730 | `message_access_audit`, `club_audit` |
| `app.dbmaint.activity-daily-days` | 400 | Günlük açılış sayacı |

İzleme: `bu_dbmaint_deleted_total{table}` (Micrometer), log satırı `dbmaint tamam: {...}`; iş sağlığı mevcut `JobMonitor`/`SystemOverview` ile (`DbMaintenanceJob.nightly`).

### Analitik: ham olay + günlük özet
- `analytics_event_daily(day, name, screen, events, users)` her gece `AnalyticsRollup` ile dolar (İstanbul günü, idempotent upsert); migration mevcut ham olaylardan geri doldurur.
- Raporlar (`topEvents`, `screenViews`, `searchesPerDay`): tamamlanmış günler (bugün−2 öncesi) özetten, son 2 gün ham tablodan okunur. **Anlam değişikliği:** `topEvents.uniq` artık gün başına tekil kullanıcıların toplamıdır (aralık boyunca tekil kişi değil; 7+ günlük aralıkta üst tahmin). Tekil aktif kullanıcılar (DAU/WAU/MAU) `activity_daily`'den gelmeye devam eder, etkilenmez.
- KVKK dışa aktarım (`analyticsEvents`) yalnızca ham (45 gün) olayları verir; `retentionDays` 45.

## 4. İndeks denetimi

### 4.1 Eklenen / değiştirilen (V520)
| İşlem | İndeks | Gerekçe |
|---|---|---|
| ADD (kısmi) | `dbs520_notification_unread_created (created_at) WHERE read_at IS NULL` | Okunmamış bildirim yaş silmesi (önceden tam tarama) |
| ADD | `dbs520_attendance_user (user_id)` | `UNIQUE(event_id,user_id)` ikinci kolonu kapsamaz; "benim yoklamalarım" + CASCADE |
| ADD (BRIN) | `dbs520_analytics_event_created_brin`, `dbs520_message_access_audit_created_brin`, `dbs520_club_audit_created_brin` | Yalnız-ekleme zaman kolonu: B-ağacına göre ~1000× küçük, aralık silme/okuma için yeterli |
| ADD (kısmi) | `dbs520_mail_sent_at WHERE status='SENT'`, `dbs520_mail_dead_created WHERE status='DEAD'` | Temizlik yalnız ilgili satırlara bakar |
| DROP | `idx_message_created` | `adm270_message_created (created_at,id)` önekini zaten kapsar; en çok yazılan tabloda her indeks yazma maliyeti |
| DROP | `idx_analytics_event_created` (→ BRIN), `idx_analytics_event_name` | Ham tabloda yalnız 45 gün, ad bazlı raporlar özetten; yazma maliyeti ve ~%40 boyut |

### 4.2 Denetim bulguları (değiştirilmedi, gerekçeli)
- `mail110_due (next_attempt_at,id)` ile `mls420_outbox_prio_due (priority,next_attempt_at,id)` büyük olasılıkla yinelenen: mail ajanı bölgesi, **kullanılmayan indeks adayı** (V420/V421 sahibi doğrulayıp düşürsün; `pg_stat_user_indexes.idx_scan = 0` ile).
- `rcp230_message_conv_sender` ve `idx_perf_message_unread` (kısmi, kapsayıcı) `idx_message_conversation` ile kısmen örtüşür; okundu bilgisi/okunmamış sayacı sorgularında kullanıldıkları için bırakıldı. `pg_stat_user_indexes` ile 2 hafta sonra `idx_scan` bakılmalı.
- Tüm FK kolonları taraması (betik): kritik olanlar kapalı; kalanlar küçük tablolarda (`tt_exam.course_id`, `support_message.author_id`, `conversation.created_by` vb.). Kullanıcı silme = anonimleştirme olduğundan CASCADE nadir; eklenmedi.
- `EXPLAIN` bölüm 11'deki seed ile alınır; kod analizi: Keşfet `post_rank` (V410 `post_rank_score` + `PostScoreJob`), sohbet listesi (`idx_conv_member_user`, `idx_message_conversation`), bildirim listesi (`idx_notification_user (user_id,id DESC)` keyset) indeksle desteklenir.
- Partial indeks fırsatları kullanıldı: outbox `PENDING/FAILED` (V110/V350), `notification` okunmamış (V160), mail SENT/DEAD (V520).

### 4.3 Autovacuum (V520, tablo bazlı)
- Çok güncellenen: `conversation_member`, `conversation`, `app_user`, `device`, `user_device_log` → `fillfactor 85-90` (HOT güncelleme) + `autovacuum_vacuum_scale_factor 0,05`.
- Kuyruk/bildirim (`mail_outbox`, `push_outbox`, `notification`): `scale_factor 0,02`, `cost_limit 1000` (sürekli ekle-sil, ölü satır hızlı birikir).
- Yalnız-ekleme (`analytics_event`, `message`, `admin_audit`): `autovacuum_vacuum_insert_scale_factor 0,05` (görünürlük haritası, dondurma).

## 5. Kısıtlar ve tipler
- Zaman: tüm olay zamanları `TIMESTAMPTZ`; durum/enum kolonları `VARCHAR` + `CHECK` (JPA `EnumType.STRING`, `smallint` enum **kullanılmaz**: okunabilirlik/yeniden sıralama güvenliği).
- `varchar(n)` sınırları mevcut (örn. `analytics_event.name 40`, `screen 60`); sınırsız `text` yalnız içerik gövdesinde (`news_item.content`). `VARCHAR(255)` varsayılanı yok.
- Yeni tablo kuralı: NOT NULL + CHECK + FK `ON DELETE` kararı (kullanıcı verisi → CASCADE veya anonimleştirme), tarih kolonu + saklama süresi (bölüm 9).
- Uygulanmış migration değiştirilmez; `ddl-auto=validate` entity ile birebir.

## 6. Bölümleme (partitioning) kararı: **uygulanmadı**

Gerekçe (20k kullanıcı):
- `analytics_event`: ham 45 gün ≈ 6,7 M satır; parçalı DELETE (5000'lik) + BRIN indeks gecede birkaç dakikada biter; kalıcı veri özet tablosunda. Aylık bölümleme `DROP PARTITION` ile silmeyi bedavaya getirir ama: (a) PK `(id)` bölüm anahtarını içermek zorunda → JPA/JDBC kodunu ve `GENERATED` kimlik davranışını değiştirir, (b) H2 testleri bozulur, (c) 6,7 M satırda kazanç ölçülebilir değil.
- `admin_audit`, `message_access_audit`: yıllık <1 M satır.
- `message`: referanslı (`reply_to_message_id`, `message_attachment`, `message_reaction`, `message_revision` FK'leri); bölümleme FK'leri parçalar. 22 M satır/yıl tek tabloda `(conversation_id, id DESC)` indeksiyle sorunsuz.
- **Yeniden değerlendirme eşiği:** `analytics_event` ham >50 M satır veya `message` >100 M satır (≈ 5 yıl) ya da parçalı silme gece penceresine sığmazsa. O zaman `message` için `conversation_id` hash bölümleme (FK'ler bozulmadan) veya soğuk mesajları arşiv tablosuna taşıma önerilir.

## 7. PostgreSQL ayarı

`docker-compose.yml` ve `docker-compose.prod.yml` postgres servisi `command:` ile ayarlanır (ortam değişkenleriyle parametreli):

| Ayar | Prod varsayılan (2 GB sınırı) | 4 GB'lik makine | Not |
|---|---|---|---|
| `shared_buffers` | 512MB (`PG_SHARED_BUFFERS`) | 1GB | RAM'in ~%25'i (konteyner sınırı üzerinden) |
| `effective_cache_size` | 1280MB | 2560MB | Planlayıcı ipucu |
| `work_mem` | 8MB (`PG_WORK_MEM`) | 8-16MB | `max_connections`×sıralama düğümü ile çarpılır; 100×8MB×2 = 1,6 GB üst sınır riskli → büyük sorgu zaten `statement_timeout` ile kesilir |
| `maintenance_work_mem` | 128MB | 256MB | Vacuum/indeks kurma |
| `max_connections` | 100 | 100 | Uygulama havuzu 30 + yedek/yönetici/psql payı |
| `max_wal_size`/`min_wal_size` | 2GB / 256MB | aynı | Silme turlarında WAL patlaması kontrollü |
| `checkpoint_completion_target` | 0,9 | | |
| `random_page_cost` / `effective_io_concurrency` | 1,1 / 200 | | SSD varsayımı |
| `autovacuum_max_workers`/`naptime`/`cost_limit` | 4 / 30s / 800 | | Tablo bazlı ayarlar V520'de |
| `shared_preload_libraries` | `pg_stat_statements` | | V520 `CREATE EXTENSION` (yetki yoksa atlanır) |
| `log_min_duration_statement` | 500 ms (`PG_LOG_MIN_DURATION_MS`) | | Yavaş sorgu logu |
| `log_lock_waits`, `log_temp_files=10MB`, `temp_file_limit=2GB`, `track_io_timing`, `log_autovacuum_min_duration=1s` | açık | | |

Uygulama tarafı güvenlik ağı (`application.properties`, `DB_*` ortam değişkenleriyle):
- Hikari `maximum-pool-size=30` (`DB_POOL_MAX`): 300-500 eşzamanlı HTTP isteğinde her istek veritabanında ortalama 5-20 ms tutar (çoğu istek zamanının büyük kısmı Redis/ağ/serileştirme); 30 bağlantı ≈ 1500-3000 sorgu/sn taşır, yani 500 eşzamanlı istek kuyruklanmadan geçer. Tomcat 200 iş parçacığı (prod) havuzdan daha fazladır: fazlası `connection-timeout=5s` içinde bağlantı bekler, aşarsa 503 `DB_TIMEOUT`.
- `connection-timeout 5s`, `max-lifetime 25 dk`, `leak-detection-threshold 30 s`.
- Sunucu tarafı oturum sınırları (`options`): `statement_timeout=8s`, `lock_timeout=3s`, `idle_in_transaction_session_timeout=30s`.
- Flyway havuzdan değil kendi bağlantısıyla, zaman aşımsız çalışır (uzun indeks kurma/geri doldurma).
- `spring.jpa.open-in-view=false` (zaten kapalı); `hibernate.jdbc.batch_size=20`, `order_inserts/updates`, `default_batch_fetch_size=50`, `in_clause_parameter_padding`.
- Zaman aşımı → `ApiExceptionHandler.dbTimeout`: **503 `DB_TIMEOUT`** + `Retry-After: 5` (tr/en/ar); süreç çökmez.
- Not: admin raporları/CSV dışa aktarımı da 8 sn sınırına tabidir; gerçek veride aşılırsa `DB_STATEMENT_TIMEOUT_MS` yükseltin (ya da raporu özet tabloya taşıyın). Bakım işleri parçalı olduğundan 8 sn yeter.

## 8. Redis anahtar TTL denetimi

Kod taraması (`opsFor*().set/add/increment`): tüm anahtarların TTL'i vardır **şu istisnalar dışında**, ve bunlar bilinçlidir:
- `suspended:<uid>` (askı/silme işareti, kasıtlı kalıcı; kullanıcı sayısıyla sınırlı, askı kalkınca silinir).
- `alert state` (`SystemAlertService.STATE_KEY`, tek anahtar).
- `rl:*`: `increment` sonra `expire` iki adım; çökme anında TTL'siz kalabilir ama `RateLimiter` `getExpire<0` ise yeniden TTL koyar (kendini onarır). `vc:att:*` ve `PushGate.incr` aynı kalıpta, ilk artışta TTL; bir çökme penceresi riski çok küçük, anahtar başına bayt düzeyinde.
- `presence:*`, `lastseen:*`, `seen:*`, `act:*`, `rt:*`, `rtu:*`, `pwchg:*`, `rolechg:*`, `reg:*`, `vc:*` TTL'lidir.

20k kullanıcıda bellek tahmini: `rt:*` + `rtu:*` ~20k×2×(~200 B) ≈ 8 MB; presence/lastseen ≈ 6k×2×100 B ≈ 1 MB; `rl:*` anlık yüzlerce; toplam **<50 MB** (prod sınırı 200 MB).

Politika önerisi: prod `maxmemory 200mb` + `noeviction` mevcut; Redis dolarsa **yazmalar hata verir (giriş/mesajlaşma durur)**. Kalıcı tutulması gereken anahtar azdır (`suspended:*`); geri kalan hep TTL'li olduğundan **`volatile-lru`** önerilir (`allkeys-lru` DEĞİL: `suspended:*` ve `schedlock:*` gibi TTL'siz/kritik anahtarlar sessizce silinmesin). `volatile-lru` dolulukta en eski TTL'li anahtarı (çoğunlukla `rl:`/`seen:`) atar; refresh token'lar (`rt:`) da TTL'li olduğundan en kötü durumda kullanıcı yeniden giriş yapar, servis durmaz. `docker-compose.prod.yml` Redis satırı yedek/redis sahibine bırakıldı (değiştirilmedi), değişiklik önerisi: `--maxmemory-policy volatile-lru` + `used_memory` %70 uyarısı.

## 9. Sorgu kuralları (yeni kod için ZORUNLU)

1. **Sınırsız sorgu yok.** `findAll()` ve `LIMIT`'siz `List<..>` yalnız küçük sabit tablolarda (`app_setting`, `sync_status`, yasaklı aralıklar). Otomatik koruma: `QueryRulesTest` izin listesi dışındaki `.findAll()` çağrısını ve parametresiz `List<..> findAll()` bildirimini reddeder.
2. **Sayfalama keyset/cursor** (`CursorPage`, `id < :cursor ORDER BY id DESC LIMIT n+1`). Derin `OFFSET` yok (admin listeleri sınırlı sayfa sayısıyla istisna). Sayfa boyutu **en çok 50** (`CursorPage.clampSize`, `SlicePaging.limit`); yeni uç `size`'ı kıskaçlamadan kabul etmez.
3. **Toplu işlem parçalı:** tek işlemde yüzbinlerce satır güncelleme/silme yok. Silme için `ChunkedDeleter` (5000'lik, her parça ayrı işlem, arada 50 ms). Toplu bildirim/kampanya alıcıları 500-1000'lik parçalar (`PushOutboxService` CHUNK, `activeUserIdsAfter` keyset). `IN (...)` listesi ≤1000 öğe.
4. **Her `@Scheduled` toplu iş** `SchedulerLock` + parçalı + hata yutan (log) olmalı; log/olay tablosu eklenirse **saklama süresi + silme işi + `created_at` indeksi (BRIN veya B-ağacı)** aynı PR'de gelir.
5. **Dar projeksiyon:** liste uçlarında `SELECT *`/tam entity yerine DTO/proje edilmiş sorgu; `TEXT`/`BYTEA`/`JSONB` kolonları (`news_item.content`, `message.body_ciphertext`, `analytics_event.props`) yalnız detayda seçilir.
6. **`COUNT(*)` büyük tabloda yok:** sayaç kolonu/önbellek ya da `LIMIT N+1` ile "daha var mı". Sayaçlar mevcut: `post` sayaçları (+ `PostCounterRepairJob`), okunmamış = imleçten.
7. **`LIKE '%x%'` yok:** arama `pg_trgm` GIN (`V190`) veya Türkçe tam metin (`search`); kullanıcı girdisi `\ % _` kaçışlı.
8. **N+1 yok:** ilişkili veriyi `IN (:ids)` ile tek sorguda (`findByMessageIdIn`, `default_batch_fetch_size=50`); döngüde sorgu yok.
9. **Sıralama indeksli alanda:** `ORDER BY` kolonu için indeks (keyset anahtarı + sıralama). Dinamik sıralama beyaz liste.
10. **Uzun işlem yok:** FCM/SMTP/HTTP çağrısı `@Transactional` içinde yapılmaz (outbox deseni: işlemde satır yaz, işçi gönderir). `idle_in_transaction_session_timeout=30s` bunu zorlar.
11. **Zaman aşımı beklenir:** `statement_timeout=8s`; yavaş sorgu 503 `DB_TIMEOUT` döner, çökmez. İstemci `Retry-After` ile yeniden dener. Rapor/dışa aktarım gerçekten uzunsa özet tabloya taşıyın, zaman aşımını gevşetmek son çaredir.
12. **Native/PostgreSQL'e özel SQL** H2'de çalışmaz: duman betiği + `EXPLAIN (ANALYZE, BUFFERS)` ile doğrulayın (bölüm 11).
13. Parametre bağlayın, string birleştirme yok (tablo adı yalnız sabit beyaz listeden).

## 10. Bakım

- **VACUUM/ANALYZE:** autovacuum tablo bazlı ayarlı (bölüm 4.3). Büyük silme sonrası (ör. ilk kez saklama uygulanınca) elle `VACUUM (ANALYZE) <tablo>` önerilir; `VACUUM FULL` **yalnız bakım penceresinde** (tabloyu kilitler).
- **REINDEX:** `REINDEX INDEX CONCURRENTLY <ad>` (PG16) şişen indeksler için; `message`/`notification` 6 ayda bir `pgstattuple`/`pg_stat_user_indexes` ile bakılır.
- **İzleme sorguları:** `SELECT query, calls, mean_exec_time, total_exec_time FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;` — kullanılmayan indeks: `SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0 ORDER BY pg_relation_size(indexrelid) DESC;`.
- **Disk uyarısı:** veritabanı hacmi >%70 ise `SystemOverview` uyarısı ve bu belgedeki 1. sıradaki `message` büyümesi için arşiv planı.
- **Yedek ilişkisi (`docs/BACKUP_RESTORE.md`, saatlik, 3 tutulur):** 1. yıl sonu tahmini DB boyutu 10-18 GB (mesaj ağırlıklı) → `pg_dump -Fc` sıkıştırılmış ~%25-35 ≈ **3-5 GB/saatlik dosya, 3 kopya ≈ 9-15 GB**; dump süresi birkaç dakika ve bu sürede IO yükü. 1. yıldan sonra öneri: `--exclude-table-data=analytics_event` (ham olay, özet kalır), `push_outbox`, `mail_outbox`; veya WAL arşivi/`pg_basebackup` + günlük tam yedek. Yedek betiği (yedek ajanı) bu belge tarafından değiştirilmedi.

## 11. Ölçek testi: `scripts/perf/seed-20k.sql`

Yalnız geliştirme/test veritabanı (koruma: `-v confirm=I_AM_DEV_ONLY` ve ≤50 gerçek kullanıcı kuralı). Ayrıntı ve çalıştırma: `docs/PERFORMANCE.md` "20k ölçek". **Gerçek PostgreSQL 16'da denendi:** tüm migration zinciri (V520 dahil) temiz uygulandı, seed 3 dk 14 sn, ana sorgular 0,1-0,3 ms; eski `topEvents` ham sorgusu 3 M satırda 2,6 sn iken özet tablolu yenisi 0,28 sn (ayrıntı PERFORMANCE.md). Ölçüm ışığında mesaj satırı ≈ 410 B (1,2 M satır: 188 MB yığın + 307 MB indeks), şifreli gövdeyle ≈ 500 B → 22 M mesaj/yıl ≈ 11 GB (bölüm 2.1 tahmini doğrulandı).

## 12. Kapasite tahmini (20 bin kullanıcı, 1. yıl sonu)

| Kalem | Tahmin |
|---|---|
| Toplam veritabanı | **10-18 GB** (mesaj 6-14 GB baskın; analitik ham ~1,2 GB; bildirim ~0,8 GB; diğer ~1-2 GB) |
| Bellek | `shared_buffers` 512MB-1GB + işletim sistemi önbelleği; sıcak çalışma kümesi (son 30 gün mesaj/indeksler) ~2-3 GB → 4 GB makine yeter |
| Bağlantı | Havuz 30, PostgreSQL `max_connections` 100 |
| Gecelik bakım | ~2-6 dakika (parçalı silme, ~1 M satır/gece) |
| Yazma | Zirvede ~100-200 INSERT/sn (mesaj+olay+bildirim); tek VPS'te rahat |
| İlk darboğaz adayı | `message` tablosu >50 GB veya 100 M satır → bölüm 6 |

## 13. Doğrulanamayanlar / açık maddeler
- Backend uygulaması gerçek PostgreSQL'e karşı **ayağa kaldırılıp** API p95 ölçülmedi (yalnız migration + SQL düzeyi doğrulandı); `scripts/perf/perf-api.js` seed'li yığına karşı çalıştırılmalı.
- `statement_timeout`/`lock_timeout`/`options` Hikari ayarı gerçek JDBC bağlantısıyla (uygulama içinden) doğrulanmadı; birim testi yalnız 503 `DB_TIMEOUT` eşlemesini kapsar. İlk dağıtımda `SHOW statement_timeout;` ile uygulama oturumunda kontrol edin (`pg_stat_activity.application_name='bu-backend'`).
- BRIN, `created_at` ekleme sırasına yakın olduğu varsayımına dayanır (istemci `at` değeri geç gelebilir); `SELECT correlation FROM pg_stats WHERE tablename='analytics_event' AND attname='created_at'` <0,9 ise B-ağacına dönün.
- Kullanılmayan indeks adayları (`mail110_due`, `rcp230_message_conv_sender`, `idx_perf_message_unread`) başka ajanların bölgesi; 2 hafta `idx_scan` izlenmeden düşürülmedi.
- Sınırsız/ağır sorgu taraması bulguları (düzeltilmedi, başka ajan paketi): `EventModerationService` katılım sayımı için `attendance.findByEventId(...)` ile tüm yoklamayı çekiyor (sayım sorgusu olmalı); `AttendanceService` katılımcı listesi ve `EventChatService` `findByEventIdAndStatus` tüm GOING listesini belleğe alır (üst sınır etkinlik kapasitesi; kapasitesiz etkinlikte 20k'ya çıkabilir → sayfalanmalı); `AccessBanService.usersInRange` 200 000 satırlık sınır (yönetici işlemi).
- Yedek betiği ve Redis `maxmemory-policy` (volatile-lru) önerisi uygulanmadı (başka ajan bölgesi).

## 14. Yük testi sonrası notlar (paket LD, 2026-10-29)
- Uygulama gerçek PostgreSQL 16 ve 20k seed ile ayağa kaldırılıp k6 ile ölçüldü (bölüm 13 ilk madde kapandı): `docs/PERFORMANCE.md` "20k yük testi", ham sonuçlar `docs/perf-results/2026-10-29/`.
- `statement_timeout`/`lock_timeout` uygulama oturumunda doğrulandı (kilit testi 3,0 sn; bölüm 13 ikinci madde kapandı). Eklendi: JDBC `socketTimeout` 30 sn / `connectTimeout` 10 sn.
- V800: `news_item.search_vec` (saklı tsvector + GIN `ld_news_search_vec`) ve gönderi arama indeksleri `ld_post_body_fts`, `ld_post_body_trgm`. Büyük `post` tablosunda üretimde `CREATE INDEX CONCURRENTLY` ile elle kurulabilir.
- PostgreSQL 2 CPU / 2 GB ile 360 RPS okuma karışımında PG CPU ~1,6 çekirdek, tablo önbellek isabeti %99,9; WAL/disk darboğazı görülmedi.


## 15. Elle saklama ve depolama doluluk izleme (DS1, V830)
- Gece işi (`DbMaintenanceJob`) bölüm 3'teki süreleri uygular; **yönetici paneli** (`/admin/data-retention`) ek olarak şişen log tablolarını **makbuzlu dışa aktarıp** elle temizler. Beyaz liste `dbmaint.admin.RetentionTables`: `admin_audit`, `message_access_audit` (yalnız dışa aktarma), `club_audit`, `analytics_event`, `notification` (okunmuş), `mail_outbox`/`push_outbox` (SENT/DEAD), `user_device_log`, `blocked_attempt_log`, `profanity_hit_log`. **Yeni log tablosu eklenirken** (bölüm 9 kural 4) saklama süresi + gece işi + bu listeye kayıt aynı PR'de gelir.
- `data_export_receipt` / `data_purge_log` (V830, indeks öneki `ds_`): kanıt tabloları, `DELETE` tetikleyiciyle engelli; saklama işi dokunmaz. Elle silme `ChunkedDeleter.deleteAll` (parçalı, ilerleme) kullanır; aralık en geç `bugün - asgari saklama` (denetim kayıtları >= 90 gün, `message_access_audit` 365, diğerleri >= 7-30 gün).
- Doluluk: `GET /api/admin/system/storage` (`StorageUsageService`): `pg_database_size`, `pg_total_relation_size` en büyük 15 tablo, uygulama diskleri `statfs`. Veritabanı sunucusu diski yalnız `app.storage.db-disk-path` (ölçülen) ya da `app.storage.db-disk-capacity-bytes` (hesaplanan) ile bilinir; yoksa UNKNOWN. Eşikler `app.observability.storage-warn-percent=80` / `storage-crit-percent=90`; `StorageAlertJob` 15 dk'da bir yöneticilere uygulama içi bildirim (e-posta yok).
- Büyük silme sonrası `ANALYZE` otomatik; alanı işletim sistemine geri vermek için bakım penceresinde `VACUUM FULL <tablo>` (bölüm 10) çalıştırın.
