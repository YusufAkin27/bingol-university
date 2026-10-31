# A2 — Backend performans ve sağlamlık denetimi (yalnız bulgu; kod değiştirilmedi)

Tarih: 2026-10-31. Denetçi: A2. Kapsam: veritabanı, Redis/önbellek (C1), uygulama (iş parçacığı/zamanlayıcı/bellek), yük/gecikme, sağlamlık.
Üretim sunucusuna (77.83.37.160 / bukampus.com.tr) **hiç erişilmedi**. Tüm ölçümler yerel, yalıtılmış `qa2` Docker yığınında yapıldı.

## 0. Yöntem ve ölçüm koşulları (sonuçları yorumlamadan önce okuyun)

- **Yığın:** `docker compose -p qa2` — PostgreSQL 16 (`pg_stat_statements` açık, üretimdeki ayarlar), Redis 7, backend `qa-backend:latest` (HEAD b405782, C1 dahil), **`SPRING_PROFILES_ACTIVE=prod`** (ProdSettingsValidator geçerli), Hikari 30, 2 CPU / 1 GB. A7'nin ortak yığınına (18081) dokunulmadı; ağır yük (k6 tam senaryo) yapılmadı; en çok 250 eşzamanlı istek (yalnız Redis kesintisi testinde, <15 sn), diğer testlerde ≤ 50.
- **Veri:** `scripts/perf/seed-20k.sql` + `scripts/perf/load/seed-load-extra.sql`: 20.006 kullanıcı, 1,2 M mesaj (+60 bin oda mesajı), 60 bin konuşma, 800 bin bildirim, 3 M analitik olay, 30 bin gönderi / 90 bin beğeni / 300 bin takip, 3000 haber, 100 kulüp / 5100 üyelik, 201 etkinlik, 21 anket. Veritabanı 1,6 GB.
- **Araçlar:** kendi Node betiklerim (JWT test sırrıyla üretilir; kayıt/giriş yok), `pg_stat_statements` (istek başına SQL sayısı), `redis-cli info stats` (istek başına Redis komutu), `EXPLAIN (ANALYZE, BUFFERS)`, `kill -3` iş parçacığı dökümü, `docker pause/stop`.
- **BÜYÜK UYARI — ana makine paylaşımlı ve çok yüklüydü.** Aynı 12 çekirdekte diğer ajanlar (auth1, rel1, a7-mvn, qa) bazen toplam ~%700 CPU kullandı. Bu yüzden mutlak süreler **hem şişmiş hem dalgalı**: aynı SQL yüklü makinede 9–14 sn, sakin makinede 0,23–0,31 sn sürdü (A2-01). Her bulguda hangi koşulda ölçüldüğü yazılıdır; karşılaştırmalar (önbellek açık/kapalı, sorgu sayısı, plan, ölçeklenme eğrisi) göreli olduğu için güvenilirdir. Mutlak p95'ler için VPS'te yeniden ölçüm gerekir. Aynı yüzden "başlangıç süresi 166 sn" gibi sayılar yorum dışıdır.
- **TAHMİN** etiketi = ölçülmedi, koddan/akıştan çıkarım.

## 1. Özet tablo

| ID | Şiddet | Konu | Kanıt |
|---|---|---|---|
| A2-01 | YÜKSEK | Takip önerileri (`FollowService.suggestions`) her çağrıda tüm kullanıcıları + kulüp öz-birleşimini 3 kez tarıyor | sakin makinede 234–311 ms/çağrı, c=20'de 8,4 rps, p95 4,6 sn; yüklüyken 246/300 istek 503 |
| A2-02 | YÜKSEK | 500 üyeli odada mesaj bildirim dağıtımı ~115 bildirim/sn ile sınırlı, kuyruk gecikmesi saniyeler | 8 mesaj x 499 üye: bildirimler son mesajdan 22 sn sonra bitti |
| A2-03 | YÜKSEK | Redis kesilince kimlikli tüm istekler 2 sn sonra HTTP 500; eşzamanlı yükte iş parçacıkları tükeniyor | 250 eşzamanlı: 600/600 → 500; herkese açık `/api/news` ilk isteği 11,8 sn |
| A2-04 | ORTA | WebSocket teslimi alıcı sayısıyla doğrusal (alıcı başına sıralı Redis çağrısı) | 150 alıcı p50 442 / p95 1988 ms; 300 alıcı p50 560 / p95 1152 / maks 1553 ms |
| A2-05 | ORTA | Avatar/kapak/logo yükleme **DB işlemi ve Hikari bağlantısı içinde** görüntü işliyor | 24 eşzamanlı yüklemede 24 bağlantı "idle in transaction"; yüklüyken 83 sn → 500 |
| A2-06 | ORTA | Tek ankete oy: sıcak satır tavanı ~30 oy/sn, p95 2,6–2,9 sn (c=50) | `update poll set voter_count` ort. 477 ms |
| A2-07 | ORTA | "Takip ettiklerim" akışı gönderi sayısıyla doğrusal tarıyor | 21 satır için 28.440 satır elendi, 26,3 bin tampon/çağrı |
| A2-08 | ORTA | Gece bakımında 5000'lik silme parçası `statement_timeout` (8 sn) sınırına yakın | bildirim parçası 5,4 sn / 4,3 sn |
| A2-09 | ORTA | `/api/events` kulüp başına 1 sorgu (N+1) | 30 SQL/istek; 19 x `community_member` |
| A2-10 | ORTA | FCM istemcisinde bağlantı/okuma zaman aşımı yok; push gönderimi paylaşılan zamanlayıcıda koşuyor | SDK varsayılanı + kod (TAHMİN: FCM yanıt vermezse) |
| A2-11 | ORTA | `@Scheduled` işleri WebSocket `MessageBroker` havuzunu paylaşıyor, boyutu = CPU (2) | iş parçacığı dökümü |
| A2-12 | ORTA | Kullanılmayan/gereksiz indeksler hot tablolarda; `app_user.last_seen_at` indeksi HOT'u engelliyor | `idx_scan=0`, 100 MB `message` indeksi |
| A2-13 | DÜŞÜK | `spring.data.redis.timeout` yalnız `prod` profilinde; diğerlerinde 60 sn | `dev` profilinde `menu/today` 60 sn zaman aşımı |
| A2-14 | DÜŞÜK | `PostRankService` her 5 dk tüm pencere gönderilerini yeniden yazıyor (bilinen risk, ölçüldü) | 21.511 UPDATE/tur, HOT %0,2 |
| A2-15 | DÜŞÜK | C1 önbellek geçersiz kılması Redis kesintisinde kayboluyor (L2'de eski sürüm geri gelir) | kod (TAHMİN) |
| A2-16 | DÜŞÜK | Kimlikli istek başına 2–8 Redis komutu; presence yenilemesi kullanıcı başına 2 sıralı SET | `info stats` farkı |
| A2-17 | DÜŞÜK | Depolama raporu dakikada bir yeniden hesaplanıyor (önbellek 30 sn < alarm aralığı 60 sn) | ort. 626 ms, maks 3,6 sn (yüklüyken) |
| A2-18 | DÜŞÜK | Jsoup `timeout(20_000)` okuma başına; yavaş kaynak site zamanlayıcıyı dakikalarca tutabilir | kod (TAHMİN) |
| A2-19 | DÜŞÜK | Sohbet listesi sayfadaki tüm odaların tüm üyelerini yüklüyor | kod; tek 500'lük odada fark ölçülmedi (TAHMİN) |

Toplam 19 bulgu: **3 YÜKSEK, 9 ORTA, 7 DÜŞÜK** (KRİTİK yok: veri bütünlüğü ve güvenlik ihlali bulunmadı).

En yavaş 5 uç/sorgu (ölçümle): (1) takip önerileri — sakin makinede seri p50 398 ms, c=20'de p50 2,2 sn / p95 4,6 sn, 8,4 rps; (2) bildirim silme parçası 5000 satır = 4,3–5,4 sn; (3) `update poll set voter_count` sıcak satır, ort. 477 ms (c=50'de oy p50 1,2–1,5 sn); (4) `GET /api/events` — 30 SQL/istek, c=20'de p50 239 ms, 78 rps; (5) `GET /api/conversations` — ~20 SQL/istek, c=20'de p50 298 ms, 64 rps (altı mesaj `SELECT body` seed'in eski düz metin satırlarının sonucu, üretimde yok).

## 2. Bulgular

### A2-01 — YÜKSEK — Takip önerileri sorgusu O(kullanıcı x kulüp²)

- **Yer:** `backend/src/main/java/edu/bingol/backend/post/follow/FollowService.java:214-245` (`GET /api/users/me/follow-suggestions`).
- **Sorun:** Sorgu `app_user u, app_user me` kartezyen çarpımında **tüm aktif kullanıcılar** üzerinde, her biri için `EXISTS (community_member a JOIN community_member b ...)` hesaplıyor. `CASE` ifadesi (aynı alt sorgu) `WHERE`, `ORDER BY` ve `SELECT`'te ayrı ayrı değerlendirildiğinden planda **3 adet hashed SubPlan** var; her biri 5100 üyelik satırının kendisiyle öz-birleşimini (260.100 satır) kuruyor. Ek olarak `user_block` için 3373 kez Seq Scan döngüsü ve kullanıcı başına `user_follow_stats` alt sorgusu var. Kulüp büyüdükçe öz-birleşim kare büyür (500 üyeli kulüp tek başına 250 bin çift).
- **Ölçüm:**
  - Sakin makine, 3 tekrar, düz SQL: **234 / 290 / 312 ms**. HTTP seri (n=10): p50 **398 ms**; `pg_stat_statements` ort. 353 ms.
  - c=20, 200 istek (sakin): **8,4 rps, p50 2200 ms, p95 4600 ms, p99 5047 ms**.
  - Yüklü makine, c=20, 300 istek: **246'sı 503 `DB_TIMEOUT`**, p50 8,6 sn; `pg_stat_statements`: 94 çağrı, ort. 4251 ms, maks 7782 ms (8 sn `statement_timeout`'a değiyor). Aynı SQL yüklüyken 9,0–14,6 sn.
  - `EXPLAIN`: `Planning Time: 280 ms`, `Hash Join (actual rows=260100)` x3, `Seq Scan on app_user u (rows=20007)`, `Seq Scan on user_block (loops=3373)`, 11.524 tampon.
- **Tekrar:** `psql` içinde kullanıcı 5000 için sorguyu `EXPLAIN (ANALYZE,BUFFERS)` ile çalıştırın; ya da 20 eşzamanlı `GET /api/users/me/follow-suggestions` (farklı kullanıcı tokenları).
- **Öneri:** (a) "benim kulüplerim" CTE'si (`SELECT community_id FROM community_member WHERE user_id = :me AND status='ACTIVE'`) ile **aday kümesini** daralt: aday = `community_member WHERE community_id IN (benim) AND user_id <> me` (indeks `(community_id, user_id)` zaten var) + aynı bölüm/sınıf için `app_user (department, class_year)` indeksiyle en çok ~300 aday; sonra bu adaylara `NOT EXISTS follow/block` uygula ve sırala. (b) `CASE`'i bir kez hesapla (`LATERAL` ya da alt sorgu). (c) Sonucu kullanıcı başına 10–30 dk Redis/L2'de sakla (öneri taze olmak zorunda değil) ve `size`'a göre kes. (d) `user_block` için `(blocker_id, blocked_id)` ve `(blocked_id, blocker_id)` indeksleri (boş tabloda Seq Scan masum, dolunca değil).
- **Beklenen kazanç:** çağrı başına ~250–350 ms → ~10–25 ms (≥10x); c=20'de 503 ortadan kalkar. 1500 çevrimiçi kullanıcıda Keşfet açılışında 5 çağrı/sn = ~1,5 DB çekirdeği yükü ortadan kalkar.

### A2-02 — YÜKSEK — Çok üyeli odada bildirim dağıtımı dar boğaz (alıcı başına çok sorgu, 2 iş parçacığı)

- **Yer:** `messaging/MessagingFanoutConfig.java:16-24` (`ThreadPoolExecutor(2, 4, ..., LinkedBlockingQueue<>(2000))`); `messaging/MessageService.java:339,393-443` (`notifyOffline`); `notification/NotificationService.java:145-226` (`doSend`, alıcı başına).
- **Sorun:** Mesaj başına bir görev kuyruğa girer; görev **alıcıları sırayla** işler. `doSend` alıcı başına: `canReceive`, `prefs.findById`, alt tür tercihi, `collapseKey` araması, `notification` ekle/güncelle (+ FCM açıksa `devices.findByUserId`, `countByUserIdAndReadAtIsNull`, outbox ekleme) — **≥ 6–8 gidiş-dönüş**. Havuz çekirdek 2 / max 4 ama kuyruk 2000 olduğundan ikinci eşik pratikte hiç devreye girmez: **fiilen 2 iş parçacığı**. Kuyruk dolarsa bildirim yalnızca `log.warn` ile atlanır.
- **Ölçüm** (500 üyeli grup, 300 çevrimiçi, FCM kapalı bu yüzden FCM yolu yok = alt sınır): 8 mesaj x 499 alıcı = 3992 bildirim. Mesajlar 00:17:02,9 → 00:17:15,2 arasında gönderildi (REST gönderim 77–209 ms, ilki 1486 ms). Bildirim satırlarının son güncellemesi **00:17:37,7** → son mesajdan **22 sn sonra**, toplam 34,8 sn = **~115 bildirim/sn** (kanıt: `notification.created_at` aralığı, `collapse_key='conv:60001'`). Yani her ek 500 üyeli mesaj ≈ 4,3 sn iş; ardışık mesajlar birikir. FCM açıkken alıcı başına en az 3 ek sorgu → ~2x yavaş (TAHMİN).
- **Tekrar:** 500 üyeli bir GROUP satırı oluşturun (SQL ile), 8 mesajı REST ile gönderin, `max(created_at)` farkına bakın.
- **Öneri:** (1) Alıcı listesini parçalara bölüp **toplu** işle: tercih/aktiflik tek `IN (...)` sorgusu; `notification` için çok satırlı `INSERT ... ON CONFLICT (user_id, collapse_key) WHERE read_at IS NULL DO UPDATE SET group_count = group_count + 1` (kısmi benzersiz indeks gerekir; yeni V9xx migration); token'lar tek sorguda; outbox satırları `saveAll`/toplu. (2) Aynı sohbete ait bekleyen görevleri birleştir (coalesce): kuyrukta zaten bekleyen konuşma için ikinci görev ekleme, sadece "son mesaj" ile güncelle. (3) Havuz: çekirdek = max = 4, kuyruk boyutu alıcı değil iş sayısına göre izlenir; `RejectedExecutionException` yerine `CallerRuns` değil (gönderici bloke olmasın) ama metrik/uyarı ekleyin.
- **Beklenen kazanç:** 500 alıcılı mesaj ~4,3 sn → <0,5 sn; sürekli kapasite ~115 → >2000 bildirim/sn.

### A2-03 — YÜKSEK — Redis kesilince kimlikli API 500 + iş parçacığı tükenmesi

- **Yer:** `auth/jwt/JwtAuthFilter.java:73-80` (`check`: `redis.opsForValue().multiGet(...)` istisna yakalamıyor); `common/RateLimiter.java`, `analytics/ActivityTracker.java`.
- **Ölçüm (prod profili, `spring.data.redis.timeout=2s`):** Redis durdurulunca `GET /api/users/me`, `/api/conversations`, `/api/notifications/unread-count` → **HTTP 500, ~2,1 sn** (503 değil, `Retry-After` yok); `/actuator/health` → 503 (2,3 sn). Herkese açık, önbellekli `/api/news`, `/api/status`, `/api/menu/today` ilk istekte 2 sn, sonra 50–130 ms ile **çalışıyor** (C1 `redisDownUntil` mekanizması doğru işliyor). Redis geri gelince ilk istekte normale dönüyor.
  - Fırtına: Redis kapalıyken **250 eşzamanlı** kimlikli istek (600 adet): **600/600 → 500**, p50 3,0 sn, p95 13,7 sn, rps 34. Aynı anda gönderilen herkese açık `/api/news` **ilk isteği 11,8 sn** sürdü (Tomcat 200 iş parçacığı bekleyen isteklerle doldu), sonraki yoklamalar normal.
- **Sorun:** Redis her kimlikli istekte zorunlu (askı/rol/oturum kontrolü, hız sınırı, etkinlik izi). Kesintide her istek 2 sn iş parçacığı tutuyor ve hızlıca başarısız olmuyor; yükte iş parçacığı havuzu dolup **Redis'ten bağımsız uçlar bile** etkileniyor. CLAUDE.md "Redis yoksa auth çalışmaz" kararı kabul edilmiş olsa da hata biçimi (500, 2 sn bekleme, devre kesici yok) iyileştirilebilir. Fail-closed güvenlik tercihi korunabilir.
- **Tekrar:** `docker stop qa2-redis-1`; 250 eşzamanlı `GET /api/users/me`; yan yana `GET /api/news` süresini ölçün.
- **Öneri:** Redis çağrılarına **devre kesici** (ilk hatada `redisDownUntil = now+5 sn`; bu aralıkta Redis'e gitmeden hemen 503 `REDIS_UNAVAILABLE` + `Retry-After: 5`); `JwtAuthFilter` için hata yakalayıp `ApiAuthenticationEntryPoint` ile 503 üretin; `ActivityTracker`/`RateLimiter` zaten ayrı fail-open/closed kararlarına bağlansın. Komut zaman aşımını 2 sn → 500 ms'ye indirmeyi değerlendirin. Docker sağlık denetimi `redis` kesintisinde `DOWN` döndüğünden, orkestratörün konteyneri gereksiz yeniden başlatmadığını doğrulayın.
- **Beklenen kazanç:** kesintide istek başına 2 sn → ~ms; tomcat iş parçacığı tükenmesi ortadan kalkar; mobil istemci 503/`Retry-After` ile düzgün geri çekilir.

### A2-04 — ORTA — WebSocket teslimi alıcı sayısıyla doğrusal

- **Yer:** `messaging/ws/ChatEventBus.java:64-70, 82-91` (`deliverLocal`: her alıcı için `suspended(uid)` → ayrı Redis `hasKey`, sıralı; `convertAndSendToUser`).
- **Ölçüm** (500 üyeli oda, ana makine yüklü): 150 çevrimiçi alıcı — 1200/1200 teslim, **p50 442 / p95 1988 / maks 2247 ms**; 300 alıcı — 1800/1800 teslim, **p50 560 / p95 1152 / maks 1553 ms**. Teslim kaybı yok. REST gönderim yanıtı 77–209 ms (teslim asenkron).
- **Sorun:** Alıcı başına tek Redis gidiş-dönüşü (~1,5–2 ms yüklü ortamda) + `SimpMessagingTemplate` işi, Redis dinleyici iş parçacığında sıralı.
- **Öneri:** Zarf başına **tek `MGET`** (`suspended:<id>` listesi) ya da askı kümesini 5–10 sn'lik bellek içi önbellekte tutun (askı zaten `JwtAuthFilter`'da ayrı doğrulanıyor); yalnız `registry.getUser(name) != null` olan yerel kullanıcılar için sorgulayın.
- **Beklenen kazanç:** 500 çevrimiçi alıcıda en yavaş teslim ~1 sn → <100 ms; alıcı sayısından bağımsız ~1 RTT.

### A2-05 — ORTA — Görsel işleme DB işlemi (ve bağlantı) içinde

- **Yer:** `profile/ProfileService.java:175-187` (`@Transactional setAvatar`: `get(id)` sonra `media.storeImage`), ayrıca `community/CommunityService.java:329,345` (`setCover`, `setLogo`), `event/EventService.java:385` (`setCover`), `messaging/ConversationService.java:242` (`setAvatar`), `menu/MenuAdminService.java:60`. (Sohbet/gönderi medyası ayrı yoldan, işlem dışında: sorun yok.)
- **Sorun:** `storeImage` (okuma + `ImageProcessor` semaforu en çok **15 sn** bekler + çözme/kodlama + dosya yazımı) açık işlem içinde; Hikari bağlantısı ve PostgreSQL oturumu "idle in transaction". `idle_in_transaction_session_timeout=30s` aşılırsa sunucu bağlantıyı koparır.
- **Ölçüm:**
  - 24 eşzamanlı 12 MP avatar yüklemesi (sakin): toplam 3,2 sn; **eşzamanlı "idle in transaction" bağlantı sayısı 24** (havuz 30). 30+ eşzamanlı yükleme tüm API'yi bağlantı beklemeye sokar (ölçülmedi; kural gereği daha fazla yük verilmedi).
  - Tek 12 MP: sakin makinede 0,3–1,7 sn; **yüklü makinede (CPU yarışı) 83 sn → HTTP 500**: günlükte `PSQLException: FATAL: terminating connection due to idle-in-transaction timeout`, ardından `Connection is closed`.
  - Görüntü bombası/CPU: 12 MP gürültü JPEG (1,8 MB) sakin makinede 292 ms'de işlendi, `ImageProcessor` altörnekleme çalışıyor — DoS bulgusu **çıkmadı**.
- **Öneri:** İşlemi küçült: önce `media.storeImage(...)` (işlem dışı), sonra kısa `@Transactional` blokta `u.setAvatarUrl(...)`; sınıf düzeyinde `@Transactional` yerine `TransactionTemplate`. Aynı desen 5 yerde.
- **Beklenen kazanç:** yükleme sırasında bağlantı tutma süresi saniyeler → ~ms; havuz tükenmesi ve 30 sn'lik kopma riski kalkar.

### A2-06 — ORTA — Tek ankete oy: sıcak satır tavanı

- **Yer:** `poll/PollVoteService.java:157-173` (`applyCounters`: `polls.addVotersIfOpen` → `update poll set voter_count = voter_count + 1 ...`, ardından seçenek sayaçları, commit'e kadar kilit).
- **Ölçüm** (aynı ankete 100 farklı kullanıcı, prod profili): c=10 → 16 oy/sn, p50 561 ms; **c=50 → 28–31 oy/sn, p50 1231–1516 ms, p95 2598–2995 ms**; c=100 → 27 oy/sn, p50 2973 ms. Bütünlük **doğru**: her koşuda 100 ballot / 100 oy toplamı / `voter_count`=100. `pg_stat_statements`: `update poll ... voter_count` **ort. 477 ms** (kilit bekleme), `insert poll_ballot` 1,6 ms, `poll_vote` 1,3 ms.
- **Sorun:** `poll` satırı kilidi, ardından gelen 3 seçenek güncellemesi ve commit süresince tutuluyor; tek satırlı seri iş → tavan ~30 oy/sn. Kampüs genelinde duyurulan bir anket (20 bin kişi / 5 dk = 67 oy/sn) tavanı aşar; `lock_timeout` 3 sn dolunca oylar 503 döner ve havuz dolar (önceki rapor kalan risk #1 ile uyumlu).
- **Öneri:** `voter_count`'u oy yazımından çıkarın (gerektiğinde `COUNT(*) FROM poll_ballot` ya da 30 sn'lik önbellek / asenkron toplu güncelleme), ya da sayaçları N parçalı (`poll_counter_shard`) tutun; en azından `poll` UPDATE'ini işlemin **son** ifadesi yapın (seçenekler önce).
- **Beklenen kazanç:** oy/sn tavanı ≥ 5–10x; p95 <300 ms hedefi.

### A2-07 — ORTA — "Takip ettiklerim" akışı gönderi sayısıyla doğrusal tarıyor

- **Yer:** `post/social/SocialFeedRepository.java:20-22,28-34` (`FOLLOWING = "(p.authorId = :viewer OR EXISTS (SELECT 1 FROM UserFollow f ...))"`).
- **Ölçüm:** 15 kişiyi takip eden kullanıcı için `EXPLAIN`: `Index Scan using post310_feed_idx ... Rows Removed by Filter: 28440` — **21 satır bulmak için 28.461 gönderi** gezildi; **28.824 tampon, 115 ms** (30 bin gönderi). `pg_stat_statements`: ort. **61,6 ms, 26.301 tampon/çağrı** (diğer kapsamlar 0,3–3,7 ms, 60–600 tampon). `OR` yüzünden yazar indeksi (`post310_author_idx`) kullanılamıyor; tarama zaman tersine tüm tabloyu geziyor.
- **Sorun:** Maliyet toplam gönderi sayısıyla (kaç tanesinin takip ettiğiniz kişilere ait olduğu oranıyla) doğrusal: 300 bin gönderide ~1,1 sn, birkaç milyonda `statement_timeout` (8 sn) (TAHMİN: doğrusal ekstrapolasyon). Az kişi takip eden yeni kullanıcılar en kötü durum.
- **Öneri:** `UNION ALL` ile takip edilen yazar başına `post310_author_idx (author_id, created_at DESC)` üzerinden `LIMIT` + dış sıralama (en çok N yazar), ya da takip/hızlı akış için kullanıcı başına "gelen kutusu" tablosu (yazarken dağıtım) / son N gönderi önbelleği. Bölüm kapsamı (605 tampon) zaten kabul edilebilir.
- **Beklenen kazanç:** çağrı başına tampon 26k → <500; maliyet gönderi sayısından bağımsız.

### A2-08 — ORTA — Gece bakımı parça süresi `statement_timeout`'a yakın

- **Yer:** `dbmaint/DbMaintenanceJob.java:137-147` + `dbmaint/ChunkedDeleter.java:55-78` (parça 5000 satır; hata durumunda döngü sessizce kesilir; her parça normal havuz bağlantısında, `statement_timeout=8000`).
- **Ölçüm** (`BEGIN; EXPLAIN ANALYZE DELETE ... LIMIT 5000; ROLLBACK`, 800 bin bildirimli tablo, 8 indeks): okunmuş bildirim parçası **5431 ms**, okunmamış **4283 ms** (≈1 ms/satır; plan doğru: `ntf73_read_at`/`dbs520_notification_unread_created` indeks taraması). Analitik ham olay parçası 49 ms; `notifCap` keşfi 298 ms; bir günün analitik özeti 1,7 sn (rastgele seed zamanları BRIN'i devre dışı bıraktı; üretimde sıralı olduğundan daha hızlı beklenir).
- **Sorun:** 8 sn sınırı ile bildirim parçası arasındaki pay dar. IO baskısı (gece yedek/vacuum) altında parça >8 sn olursa `57014` ile iptal olur; `ChunkedDeleter.loop` hatayı yutar ve tablo o gece hiç temizlenmez, ertesi gece de aynı. Bildirim tablosunda 8 indeks (A2-12) silme maliyetini artırıyor.
- **Öneri:** Bakım bağlantısı için `SET LOCAL statement_timeout = 60000` (ya da ayrı kısa-ömürlü `DataSource`), parça boyutu bildirim/mail için 1000–2000; başarısız parçada `log.warn` yanında metrik (`bu_dbmaint_chunk_failed_total`) ve JobMonitor uyarısı. Ayrıca gereksiz indeksleri azaltın (A2-12).
- **Beklenen kazanç:** zaman aşımı riski ortadan kalkar; silme maliyeti ~%20–30 düşer (indeks sayısına bağlı, TAHMİN).

### A2-09 — ORTA — `GET /api/events` kulüp başına bir sorgu

- **Yer:** `event/EventService.java:894-917` (`manageableIds`): "kulüp başına bir kez" hesaplanıyor ama kulüp başına `communities.can(a, c, MANAGE_EVENTS)` → tek `community_member WHERE community_id=? AND user_id=?` sorgusu. `CommunityMemberRepository.findByUserIdAndCommunityIdIn` hazır duruyor.
- **Ölçüm:** seri 20 istek: `community_member ... community_id=$1 and user_id=$2` **19 kez/istek** (20 etkinlik, 19 farklı kulüp); toplu bench: **30–33 SQL/istek**, c=20'de **78 rps, p50 239 ms** (ön sayfa/etkinlik sekmesi). `me/events` 11,5 SQL/istek.
- **Öneri:** `manageableIds` içinde bir kez `findByUserIdAndCommunityIdIn(a.id(), clubIds)` çekip rol/izin haritasını bellekte çözün (kulüp-izin matrisi bellek içi).
- **Beklenen kazanç:** 30 → ~11 SQL/istek; rps ~%2x (TAHMİN).

### A2-10 — ORTA — FCM istemcisinde zaman aşımı yok; push gönderimi paylaşılan zamanlayıcıda

- **Yer:** `notification/fcm/FirebaseFcmSender.java:41` (`FirebaseOptions.builder().setCredentials(creds)` — `setConnectTimeout/setReadTimeout` yok); `notification/outbox/PushOutboxWorker.java:112-115` (`@Scheduled poll → processDue → process → sendPool.invokeAll`, zamanlayıcı iş parçacığı sonucu bekler) ve `:60` (`sendPool` 4 iş parçacığı).
- **Sorun (TAHMİN; FCM kimliği olmadığı için ölçülemedi):** firebase-admin 9.4.1'de bağlantı/okuma zaman aşımları açıkça verilmezse 0 (sınırsız) kalır. FCM yanıt vermezse (ağ kesintisi, yarı açık bağlantı) `invokeAll` süresiz bekler; `poll()` zamanlayıcı iş parçacığını (A2-11) tutar, `nudge` yolu da takılır, kuyruk SENDING/lease içinde kalır, her tur yeniden denemeye düşer (6 deneme sonra DEAD).
- **Öneri:** `FirebaseOptions.Builder.setConnectTimeout(5000).setReadTimeout(10000)`, `invokeAll(tasks, 30, SECONDS)`; push işini ayrı yürütücüde (zamanlayıcıyı bloke etmeden) çalıştırın; FCM çağrı süresi için metrik.
- **Beklenen kazanç:** FCM kesintisinde diğer zamanlanmış işler (posta kuyruğu, presence, bakım) etkilenmez.

### A2-11 — ORTA — `@Scheduled` havuzu WebSocket broker havuzu; boyutu CPU sayısı

- **Yer:** `BingolBackendApplication` `@EnableScheduling`; `application*.properties` içinde `spring.task.scheduling.pool.size` yok. `@EnableWebSocketMessageBroker` varsayılan `messageBrokerTaskScheduler` `TaskScheduler` bean'ini tanımladığından Spring Boot kendi zamanlayıcısını oluşturmuyor ve **tüm `@Scheduled` işler bu havuzda** koşuyor.
- **Ölçüm:** `kill -3` iş parçacığı dökümü: zamanlayıcı iş parçacıkları `MessageBroker-1`, `MessageBroker-2` (yalnız 2; `cpus: 2` konteynerinde `availableProcessors()=2`; prod compose `BACKEND_CPUS` varsayılanı 2); `scheduling-*` yok. 40’tan fazla `@Scheduled` iş aynı 2 iş parçacığında.
- **Sorun:** İki uzun iş aynı anda koşunca (gece 00:00 haber senkronu ≥ 500 ms x (3 x 20 detay + retry) ≈ 30–60 sn+, 03:00–03:40 arası bakım/temizlik işleri, `MessageEncryptionMigrator.migrateAll` kalan düz metin satır bitene dek döngü, A2-10 FCM beklemesi) hızlı döngüler — posta kuyruğu (5 sn), push outbox (5 sn), presence yenileme (10 sn; 30 sn TTL), `AccessBanHits` yazımı, `TokenExpiryGuard` — gecikir. Presence yenilemesi 30 sn'den fazla gecikirse tüm kullanıcılar "çevrimdışı" görünür ve gereksiz push gider. Bunu doğrudan tetikleyen bir üretim senaryosunu ölçmedim (yapay engelleme yapılmadı) — yapısal risk; havuz boyutu ölçüldü.
- **Öneri:** `spring.task.scheduling.pool.size=8` (ya da `SchedulingConfigurer` ile ayrı `ThreadPoolTaskScheduler`, `thread-name-prefix=sched-`); hızlı döngüler (presence/mail/push) ayrı küçük havuza; uzun işler `SchedulerLock` + kendi yürütücüsünde.
- **Beklenen kazanç:** uzun işlerin hızlı döngüleri aç bırakması engellenir; ek maliyet yok.

### A2-12 — ORTA — Kullanılmayan/gereksiz indeksler (yazma maliyeti, disk) ve HOT'u engelleyen indeks

- **Kanıt:** `pg_stat_user_indexes` (benim yük karışımımdan sonra; tüm okuma uçları ve yazma yolları gezildi; üretimde 2 hafta izleyip doğrulayın):

| Tablo.indeks | Boyut | `idx_scan` |
|---|---:|---:|
| `message.idx_perf_message_unread` | 66 MB | **0** |
| `message.idx_perf_message_visible_created` | 34 MB | **0** |
| `message.idx_message_unencrypted` | 26 MB | 0 (üretimde kısmi: yalnız şifrelenmemiş satırlar, küçük) |
| `message.rcp230_message_conv_sender` | 66 MB | 487 |
| `notification.ntf73_user_type` | 43 MB | **0** |
| `notification.p14_notif_created` | 20 MB | 1 |
| `analytics_event.idx_analytics_event_user` | **133 MB** (tablonun %32'si) | 1 |
| `app_user.idx_app_user_last_seen` | 1 MB | 0 |
| `post.post310_score_idx` | 5 MB | 0 |

  `message` tablosunda 13 indeks, toplam indeks 405 MB / yığın 187 MB (indeks yığının 2,2 katı); `notification` 8 indeks (148 MB).
- **HOT:** `app_user` güncellemelerinin yalnız %17,7'si HOT, `post` %0,2, `conversation_member` %0, `notification` %0 (`n_tup_hot_upd/n_tup_upd`). `ActivityTracker` `UPDATE app_user SET last_seen_at` ve `PostRankService` `UPDATE post SET rank_score` indeksli kolonları güncellediği için HOT olamıyor (12 / 7 indeks yeniden yazılıyor). V520'deki `fillfactor=85` bu yüzden etkisiz.
- **Öneri (yeni migration, V9xx; uygulanmış migration'a dokunmayın; her biri `DROP INDEX CONCURRENTLY`, önce `pg_stat_user_indexes` ile üretimde doğrulayın):** `idx_perf_message_unread` ve `idx_perf_message_visible_created` (en sıcak yazma tablosunda ~100 MB, ~%25 indeks yazma yükü), `ntf73_user_type`, `p14_notif_created`, `idx_app_user_last_seen` (HOT için), `post310_score_idx`. `idx_analytics_event_user` (KVKK dışa aktarma/silme için) kısmi/`BRIN`+zaman filtresi ya da gece silmeyle birlikte geçici oluşturma düşünülebilir.
- **Beklenen kazanç:** mesaj/bildirim ekleme ve silme maliyeti ~%15–25 (TAHMİN), disk ~100 MB `message` + 63 MB `notification` (20k ölçeği; 22 M mesaj/yıl için GB mertebesi), `app_user` HOT oranı yükselir.

### A2-13 — DÜŞÜK — Redis komut zaman aşımı yalnız `prod` profilinde

- **Yer:** `application-prod.properties` (`spring.data.redis.timeout=2s`, `connect-timeout=2s`); `application.properties`'te yok → Lettuce varsayılanı **60 sn**.
- **Ölçüm:** `dev` (profilsiz) yığında Redis durdurulunca `GET /api/menu/today` (herkese açık, önbellekli bile) ve `GET /api/news`, `/api/status`, `/unread-count` **60 sn'de zaman aşımına uğradı** (istemci 60 sn bekledi, yanıt gelmedi); `prod` profilinde 2 sn (A2-03).
- **Etki:** staging/QA/ön yayın ortamı `prod` profili kullanmıyorsa kesinti testi yanıltıcı; C1 "Redis yoksa L1" iddiası orada 60 sn'lik tek istek gecikmesiyle başlar.
- **Öneri:** Zaman aşımlarını `application.properties`'e taşıyın (`prod` yalnız ezer).

### A2-14 — DÜŞÜK — `PostRankService` tam yeniden yazım (bilinen risk #6, ölçüldü)

- **Yer:** `post/PostRankService.java:78-110`. **Ölçüm:** 30 bin gönderide 5 dakikalık tur başına `update post set rank_score=$1 where id=$2` **21.511 çağrı, toplam 19,7 sn DB süresi** (~%6,5 DB çekirdeği sürekli), `post` HOT oranı %0,2; ek olarak saatlik `PostScoreJob.zeroOld` tek ifadede 23.009 satır 7,9 sn (8 sn sınırına değiyor; seed'in ilk çalıştırması, kararlı durumda küçük).
- **Öneri:** Yalnızca puanı eşik üstünde değişen satırları yazın (`WHERE abs(rank_score - :new) > :eps`), tek `UPDATE ... FROM (VALUES ...)` ya da `unnest`; `zeroOld` için parçalı UPDATE.

### A2-15 — DÜŞÜK — C1 geçersiz kılma Redis kesintisinde kayboluyor (TAHMİN)

- **Yer:** `common/cache/CacheService.java:298-320` (`invalidateNow`: Redis yazımı hatalıysa yalnız yerel sürüm + L1 temizlenir, `log.warn`).
- **Sorun:** Kesinti sırasında bir yazma (ör. haber gizleme) L2 sürüm sayacını artırmaz; Redis geri gelince eski sürümün anahtarları (`stable` 6 sa, `daily` 20 dk TTL) yeniden erişilebilir olur ve **geçersiz kılınmış veri** sunulur. Çok örnekli çalışmada da diğer örnekler görmez. (Kod okumasından; kesinti + yazma birleşimi ölçülmedi.)
- **Öneri:** Kesinti sırasında kaçırılan geçersiz kılmayı bellekte işaretleyip Redis dönünce `INCR` ile telafi edin (`pendingInvalidate` kümesi), ya da L2 yazarken `localVer`'i anahtara dahil edin.

### A2-16 — DÜŞÜK — Kimlikli istek başına Redis komutları

- **Ölçüm** (`redis-cli info stats` farkı / istek): temel kimlikli uç (`users/me`, `notifications`, `me/communities`) **2**; hız sınırlı uçlar 4–5; `me/summary` 7, `users/search` 8. Kaynak: `JwtAuthFilter` (1 MGET) + `ActivityTracker` (1 `SETNX`) + `RateLimiter.check` (**INCR + her çağrıda `getExpire` = 2**) + mesaj gönderme yolunda 2 sınır (`msg:all`, `msg:user`).
- **Presence:** `PresenceService.refreshLocal` (`PresenceService.java:199`) her 10 sn bağlı her kullanıcı için **2 sıralı SET** (`presence:`, `lastseen:`). 5000 bağlantıda 10.000 sıralı gidiş-dönüş/10 sn, tek zamanlayıcı iş parçacığında; `lastseen` yalnız çıkışta gerekli.
- **Öneri:** `RateLimiter`'ı tek Lua betiğine (`INCR`+`EXPIRE NX`) ya da `INCR` sonrası `getExpire` yalnız `n==1`'de; presence'ı `executePipelined`/tek `MSET`'e alın, `lastseen`'i bağlantı kapanışında yazın.

### A2-17 — DÜŞÜK — Depolama raporu dakikada bir yeniden hesaplanıyor

- **Yer:** `observability/StorageUsageService.java:38` (`REPORT_TTL_MS=30_000`) ↔ `SystemAlertService.scheduled` (60 sn): her dakika `pg_total_relation_size` tüm ilişkiler + `pg_database_size`.
- **Ölçüm:** 11 çağrı, `pg_class` sorgusu ort. **626 ms**, maks 3,6 sn (yüklü makine); `pg_database_size` ort. 190 ms; `SELECT COUNT(*) FROM app_user WHERE status` ort. 230 ms (tam tarama, 1100 tampon). 20 bin kullanıcıda küçük ama doğrusal büyür; zamanlayıcı iş parçacığını (A2-11) tutar.
- **Öneri:** Rapor TTL'ini ≥ 5 dk yapın (alarm yine her dakika, önbellekten); kullanıcı sayısı için `reltuples`/önbellek.

### A2-18 — DÜŞÜK — Kaynak site yavaşsa haber senkronu zamanlayıcıyı uzun tutar (TAHMİN)

- **Yer:** `news/NewsScraper.java:128`, `menu/MenuScraper.java:26` (`Jsoup...timeout(20_000)` **okuma başına** zaman aşımıdır, toplam değil); `news/NewsSyncService.java:123-138,166-173` (her yeni kayıt için `Thread.sleep(500)` + detay isteği, ardışık).
- **Sorun:** Kaynak site her bayt için 19 sn ile yanıt verirse tek istek dakikalarca sürebilir; 3 tür x 20 kayıt + tekrar denemeler ≈ 60–80 ardışık istek → nightly iş onlarca dakika zamanlayıcı iş parçacığı tutar (A2-11). `scraper hatasında 500'e düşmez` kuralı korunuyor (istek yolunu etkilemez).
- **Öneri:** Toplam süre bütçesi (ör. iş başına 5 dk, aşılırsa `markMaintenance`), ayrı yürütücü. (Ölçülmedi: kaynak siteye istek yasak/yapay yavaş sunucu kurulmadı.)

### A2-19 — DÜŞÜK — Sohbet listesi sayfadaki tüm odaların tüm üyelerini yüklüyor (TAHMİN)

- **Yer:** `messaging/ConversationService.java:450-453` (`members.findByConversationIdInAndLeftAtIsNull(ids)`, ardından `ms.size()`, `mine`, `peerOf`).
- **Sorun:** 20 odalık sayfada her biri 500 üyeli kulüp/etkinlik odasıysa 10.000 `ConversationMember` varlığı yüklenir (yalnız üye sayısı + kendi satırı + DIRECT'te karşı taraf gerekli). Ölçüm: 500 üyeli **tek** odanın üyesi için liste 75–203 ms (yüklü ortam; fark gözlenmedi). Çoklu büyük oda ölçülmedi.
- **Öneri:** Grup odaları için `count`/`groupBy` projeksiyonu ve yalnız kullanıcının kendi satırı; DIRECT için karşı taraf sorgusu.

## 3. Kontrol edilip sorun çıkmayanlar (olumlu bulgular)

- **C1 sunucu önbelleği etkisi (prod profili, 5 uç, 800 istek, c=30):** önbellek açık → kapalı (aynı JVM ısınmış, ikinci geçiş): `news HABER p0` **681 → 106 rps** (p50 37 → 227 ms), `menu/today` **790 → 113 rps** (p50 21 → 216 ms), `menu month` **488 → 80 rps** (67 → 319 ms), `app/info` **698 → 122 rps** (28 → 209 ms), `faq` **565 → 202 rps** (54 → 119 ms). SQL/istek 2–4,5 → ~0 (`pg_stat_statements`). Önbellek açıkken Redis komutu ~0/istek (L1). 3,0–7,2x verim artışı, ölçülen p50'de 5–10x düşüş.
  Gözlem: ham SQL ile eklenen veri (seed) `NAMESPACES` geçersiz kılmasını tetiklemez; seed sonrası boş `news` listesi 20 dk önbellekte kaldı (belgelenmiş sınırlama; migration/SQL ile veri değişiminde `cache:<ns>:v` artırılmalı).
- **Veritabanı kesintisi:** `docker pause` ile PostgreSQL 15 sn donduruldu: kimlikli uçlar **5,0 sn'de 503 `DB_TIMEOUT`** (Hikari connection-timeout), herkese açık önbellekli uçlar (news, menu) **200 / 13–21 ms** (stale-while-error/L1), `/actuator/health` 503; çözülünce ilk istekte normale dönüş (76 ms). Havuz kilitlenmesi/yeniden başlatma yok.
- **N+1:** akış (latest/top/following/department ~6–8 sorgu/istek, toplu), bildirim listesi (4), anketler (~9), topluluklar (3–5), `me/summary` (4), arama (5 sağlayıcı, 76 ms p50), kullanıcı arama (3), mesaj geçmişi (şifreli mesajlarla 30 mesaj p50 99 ms; çözme ek sorgu üretmiyor) toplu ve düzgün. Konuşma listesi planı indeksli (`chf92_member_archived`, `conversation_pkey`); okunmamış sayacı 60.000 okunmamış mesajda bile `unread-count` p50 77 ms.
- **Görüntü hattı:** 12 MP gürültü/gradyan JPEG'ler 0,3–1,7 sn, 12–24 eşzamanlı yükleme 1,2–3,2 sn; semafor (2) ve altörnekleme çalışıyor; bellek tepesi OOM üretmedi (konteyner 880 MiB/1 GiB'de dengeli).
- **Redis anahtarları:** taranan 1227 anahtarda TTL'siz olanlar yalnız `obs:state`, `ds:storage:state` (küçük, tasarım gereği); `cache:*:v` 7 gün TTL; kullanım 1,4 MB; `volatile-lru` ile uyumlu. Presence/rate limit anahtarları TTL'li.
- **Anket doğruluğu:** 3 koşuda (c=10/50/100) çift oy / sayaç ihlali **yok**.
- **Günlük hacmi:** prod profili INFO'da 29 uçlu tüm karşılaştırma ve oda testleri boyunca konteyner günlüğü yalnız ~190 satır; istek başına günlük yok, kişisel veri sızıntısı gözlenmedi (`ADMIN_VERIFY ... email` yönetici eylemi, kabul edilebilir).
- **Sıkıştırma:** `server.compression` JSON'da çalışıyor; ETag'li herkese açık uçlar (news/menu...) Tomcat'in "güçlü ETag → sıkıştırma yok" kuralı yüzünden backend'den sıkıştırılmıyor ama üretimde Caddy `encode zstd gzip` (deploy/Caddyfile:42) bunu karşılıyor.
- **WebSocket:** 300 bağlantı + 500 üyeli oda: 1800/1800 teslim, bağlantı hatası 0.

## 4. Bakılamayan / sınırlar

- **Mutlak p95/p99:** ana makine paylaşımlı olduğundan yalnız göreli sonuçlar güvenilir (bkz. bölüm 0); VPS'te `scripts/perf/load/run-load.sh` ile yeniden ölçülmeli.
- **FCM ve SMTP:** kimlik bilgisi yok → push outbox işleme hızı, FCM yanıtsızlığı (A2-10), outbox `SENDING` kurtarma ölçülemedi; mail kuyruğu SMTP zaman aşımı yalnız okundu.
- **Kaynak site (scraper) yanıtsızlığı** ve ffmpeg/video dönüştürme (yığında ffmpeg yok) ölçülemedi.
- **Yük sınırı:** k6 tam senaryo, 20k eşzamanlı WebSocket, uzun süreli (saatler) bellek/diskte büyüme izlenemedi. `message` yılda ~22 M satır büyümesinin plan eğrisi 1,2 M satırda ölçüldü (indeksler iyi), 22 M'de değil.
- **Hikari havuz tükenmesi** gerçek 30+ eşzamanlı yüklemeyle denenmedi (kurala uygun olarak 24'te durduruldu).
- **Zamanlayıcı tıkanması** (A2-11) doğrudan tetiklenmedi; yalnız havuz boyutu iş parçacığı dökümüyle doğrulandı.
- **Graceful shutdown** (30 sn) ve konteyner yeniden başlatma altında uçuş halindeki istekler test edilmedi.
- **Şifreli veriyle büyük geçmiş okuması:** 28 yeni (şifreli) + 2 eski mesaj ölçüldü; yüzlerce şifreli mesaj/çok anahtarlı DEK önbelleği ölçülmedi.

## 5. Tekrar için kısa tarif

1. İzole yığın: `docker compose -p qa2 ... up -d` (qa-backend imajı, `SPRING_PROFILES_ACTIVE=prod`, `INITIAL_FILL=false`, `CRYPTO_MIGRATE_MESSAGES=false`, postgres `shared_preload_libraries=pg_stat_statements`).
2. `psql ... -v confirm=I_AM_DEV_ONLY -f scripts/perf/seed-20k.sql` sonra `scripts/perf/load/seed-load-extra.sql` (≈ 45 dk yüklü makinede); `ANALYZE`; `SELECT pg_stat_statements_reset()`.
3. JWT'ler `JWT_SECRET` ile sunucu ile aynı HS256 anahtarıyla üretilir (`scripts/perf/load/prep.js` mantığı).
4. İstek başına SQL: `pg_stat_statements` `sum(calls)` farkı / istek sayısı; Redis: `INFO stats total_commands_processed` farkı.
5. A2-01: `EXPLAIN (ANALYZE, BUFFERS)` — `FollowService.suggestions` SQL'i, `me.id=5000`. A2-07: aynı akış sorgusu, en az takip eden kullanıcı. A2-08: `BEGIN; EXPLAIN ANALYZE DELETE FROM notification WHERE id IN (SELECT id ... LIMIT 5000); ROLLBACK;`.
