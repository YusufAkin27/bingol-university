# Performans / yük testi (T6)

Araçlar `scripts/load/` altındadır; hepsi tekrar çalıştırılabilir, harici araç gerektirmez (Node 22+, Docker). Bu belge: ölçüm yöntemi, kabul ölçütleri, **ölçülmüş** bulgular, V59 gerekçeleri, kod değişikliği önerileri (T19 uygular) ve **TEST AŞAMASI İÇİN** bekleyen işler.

> Durum: seed, REST yükü, EXPLAIN ve indeks A/B ölçümleri bir kez koşuldu (aşağıdaki tablolar gerçek çıktıdır). Koordinatör kararıyla yığınlar durduruldu; `ws-load.js` ve `nplus1.js` **yazıldı ama hiç koşturulmadı**, Hikari/Tomcat denemeleri yapılmadı (bkz. §7).

## 1. Araçlar

| Dosya | Amaç |
|---|---|
| `seed.sh`, `seed-perf.sql`, `clean-perf.sql` | `demoperf` önekli veri: 20k kullanıcı, 500k mesaj (16k konuşma, çarpık dağılım), 51k RSVP, 5k haber, 2k topluluk (+20k üye, 10k gönderi), 3k etkinlik, 200k bildirim, 20 WS grubu. ~70 sn. `--clean` yalnız bu kayıtları siler. Tüm parolalar `Sifre1234` (login yükü gerçek bcrypt çalıştırır). |
| `load.js` | REST eşzamanlı yük: news_list, news_search, search, notifications, conversations, messages, login, admin_*, mixed. p50/p95/p99, hata %, 429 ayrı. JWT'yi ortak gizli anahtarla üretir (kayıt/giriş hız sınırına takılmaz). `thresholds.json` aşılırsa çıkış kodu 1. |
| `ws-load.js` | 200-500 STOMP bağlantısı, gruplarda eşzamanlı gönderim, teslim ve ack gecikmesi, kayıp %. |
| `explain.sh` + `explain-queries.sql` | 24 sıcak sorgu için `EXPLAIN (ANALYZE, BUFFERS)` özeti (süre, tarama türü, tampon). |
| `ab-indexes.sh` | V59 indekslerini AYNI ısınmış JVM üzerinde açık-kapalı-açık A/B yükler. |
| `nplus1.js` | Uç başına tek istek → `pg_stat_statements` ile SQL sayısı; 2+ kez çalışan sorgu = N+1 şüphesi. |
| `compose.perf.yml` | `pg_stat_statements`, `track_io_timing`, Hibernate istatistikleri, Hikari/Tomcat/JVM deney değişkenleri (`PERF_HIKARI_MAX`, `PERF_TOMCAT_MAX`, `PERF_JAVA_OPTS`). |

Çalıştırma (repo kökünden):
```bash
export COMPOSE_PROJECT_NAME=wt_t6 BACKEND_PORT=8106 BASE=http://localhost:8106
docker compose -f docker-compose.yml -f scripts/load/compose.perf.yml up -d --build postgres redis backend
docker compose exec -T postgres psql -U bingol -d bingol -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements"
bash scripts/make-user.sh boss@bingol.edu.tr Boss      # admin_* senaryoları için (ADMIN_EMAILS listesinde)
bash scripts/load/seed.sh
FLUSH_RL=1 LABEL=run1 WARMUP=10 node scripts/load/load.js        # tüm REST senaryoları
CONNS=500 node scripts/load/ws-load.js
node scripts/load/nplus1.js ; bash scripts/load/explain.sh ; bash scripts/load/ab-indexes.sh
```
Notlar: `PUBLIC` gibi ortam adları Windows'ta sistem değişkenidir (bu yüzden `PUB_SCEN`). Paylaşımlı makinede (başka ajan yığınları) REST ölçümü çok gürültülüdür: aynı kurulumda 277 rps ile 810 rps arası gözlendi. Bu yüzden indeks kararları EXPLAIN tampon sayısına ve aynı JVM'de A/B'ye dayanır; mutlak rps karşılaştırması yapılmaz.

## 2. Kabul ölçütleri (`thresholds.json`)
CONC=32, ısınmış JVM, seed verisi: haber listesi p95 ≤ 100 ms; haber araması ≤ 250; genel arama ≤ 400; bildirim ≤ 100; konuşma listesi ≤ 150; mesaj geçmişi ≤ 150; login ≤ 900 (bcrypt); karışık ≤ 200; admin liste/arama ≤ 150, overview ≤ 400, engagement ≤ 500. Hata ≤ %0,1 (429 hata sayılmaz, ayrı raporlanır). WebSocket: bağlantı hatası 0, kayıp %0, teslim p95 ≤ 250 ms, p99 ≤ 500 ms (500 bağlantı, ~250 mesaj/sn teklif edilen yük).

## 3. Ölçülen taban çizgisi (V59 öncesi, soğuk JVM, CONC=32, 15 sn — yalnız yön gösterir)
| senaryo | rps | p50 | p95 | p99 | hata % |
|---|---|---|---|---|---|
| news_list | 277 | 102 | 237 | 346 | 0 |
| news_search | 242 | 119 | 277 | 413 | 0 |
| search (kullanıcı başı 60/dk limiti) | 60 | 513 | 843 | 1043 | 0 |
| notifications | 383 | 72 | 172 | 236 | 0 |
| conversations | 205 | 141 | 298 | 416 | 0 |
| messages | 380 | 71 | 180 | 256 | 0 |
| login (bcrypt, limit temizlenerek) | 73 | 421 | 778 | 1076 | 0 |
| mixed | 233 | 108 | 362 | 500 | 0 |

Isınmış JVM'de (aynı yığın, WARMUP=10): news_list 810 rps p95 80 ms; notifications 886 rps p95 70 ms; conversations 366 rps p95 193 ms; messages 355 rps p95 238 ms. Yani sıcak yollar kabul ölçütlerine yakın; `search` ve `login` yapısal olarak yavaş (aşağıda). Hiçbir senaryoda 5xx görülmedi.

pg_stat_statements (yük sonrası, toplam süreye göre): (1) haber arama isabetleri 38 ms ort., (2) arama sayfası 18 ms, (3) `count(*) news_item WHERE type AND hidden` 7,8 ms × her liste isteği, (4) etkinlik/topluluk `ILIKE` 15/7,5 ms (genel arama içinde), (5) okunmamış sayacı 2,5 ms (bazı kullanıcılarda 18 ms). Admin tarafında: overview 144 ms (tek sorguda 20 alt-sorgu, 5M tampon/570 çağrı), günlük mesaj serisi 261 ms, kullanıcı listesi 46 ms, kullanıcı araması 53 ms.

## 4. V59 indeksleri: önce/sonra (EXPLAIN, tampon, ms)
| sorgu | önce | sonra | indeks |
|---|---|---|---|
| haber `count(*)` tür+gizli | 5,6 ms, 874 tampon, Seq Scan | 0,55 ms, 11 tampon, Index Only | `idx_perf_news_type_hidden_date` |
| haber `count(*)` gizli | 5,5 ms, 874 | 0,93 ms, 22, Index Only | `idx_perf_news_hidden_date` |
| okunmamış sayacı (`msg_unread_counts`) | 18,4 ms, 1987 tampon (uq_message_client + heap) | 0,79 ms, 21, Index Only | `idx_perf_message_unread` |
| admin kullanıcı araması | 35,1 ms Seq Scan | 5,3 ms (BitmapOr trigram) | `idx_perf_user_name_trgm`, `idx_perf_user_email_trgm` |
| admin arama `count` | 25,6 ms | 3,1 ms | aynı |
| admin kullanıcı listesi (offset 8000) | 34,0 ms Seq+Sort | 22,9 ms Index Scan | `idx_perf_user_created_desc` |
| günlük mesaj serisi (30 gün) | 186 ms, 4076 tampon | 129 ms, 474 tampon, Index Only | `idx_perf_message_visible_created` |

Aynı ısınmış JVM'de indeks açık/kapalı yük A/B'si (admin, CONC=8, 10 sn; `ab-indexes.sh` ilk iki tur):
| senaryo | kapalı rps / p95 | açık rps / p95 |
|---|---|---|
| admin_users | 94,5 / 165 ms | 139,8 / 117 ms |
| admin_users_q | 64,2 / 224 ms | 110,0 / 144 ms |
| admin_overview | 47,7 / 315 ms | 41,8 / 444 ms (fark gürültü içinde; sorgu tek başına indeksle hızlanmıyor, bkz. §5.4) |
| admin_engagement | 24,9 / 543 ms | 25,2 / 530 ms |

Üçüncü tur (açık-2) ve public senaryoların A/B'si çalıştırılamadı (ilkinde `PUBLIC` ortam çakışması betik hatası, sonra yığın durduruldu) → §7.

Reddedilen/kanıtsız bulunanlar (mevcut indeksler yeterli, EXPLAIN'de Index Scan): bildirim sayfası/okunmamış sayı (0,2 ms), konuşma listesi (0,2 ms), mesaj geçmişi (0,2 ms), giriş (e-posta unique), RSVP/üyelik kullanıcıya göre. `idx_message_created`, `idx_message_sender`, `idx_rsvp_created`, `idx_post_created` V40'ta zaten var (yeniden eklenmedi).

Yazma maliyeti: 100k mesaj toplu ekleme, 2 ek mesaj indeksi açık/kapalı: 12,7/13,4 sn ve 17,2/11,8 sn — gürültü etkiden büyük, anlamlı fark yok (~125 µs/satır). Üretimde büyük tablolara `CREATE INDEX CONCURRENTLY` (Flyway dışı) tercih edilir; haber tablosu küçüktür, mesaj tablosu büyüyünce dikkat.

## 5. Kod değişikliği önerileri (T19 için, öncelik sırasıyla)
1. **Haber araması: saklı tsvector sütunu.** `ts_rank(to_tsvector(...))` her eşleşen satırda yeniden hesaplanıyor (sıcak terimde 267 satır → 16-18 ms). Prototip (`ALTER TABLE news_item ADD COLUMN search_vec tsvector GENERATED ALWAYS AS (to_tsvector('turkish', title || ' ' || coalesce(summary,''))) STORED` + GIN, sorguda `n.search_vec @@ ...` ve `ts_rank(n.search_vec, ...)`) aynı sorguyu 2,4-7 ms'e indirdi. Yeni migration (V59 dışı; tablo değişikliği) + `NewsRepository.VEC`/`idx_news_fts` güncellemesi gerekir. `searchHits` ve `searchPage` aynı sabiti kullanır.
2. **Haber liste uçlarında `content` TEXT'i çekilmiyor olmalı.** `findByHiddenFalse`/`findByTypeAndHiddenFalse` tüm varlığı (içerik dahil, ~1 KB × 20) okuyor; liste için projeksiyon (`id,type,title,summary,imageUrl,publishedDate`). Ayrıca Spring `Page` her istekte ayrı `count(*)` çalıştırıyor: V59 ile 0,5 ms'e indi; sayfa çok derinse `Slice`/keyset düşünün.
3. **Her istekte 2 yazma:** `ActivityTracker` → `INSERT activity_daily ... ON CONFLICT` + `UPDATE app_user SET last_seen_at` (0,6-0,7 ms × 2, ilk istek/kullanıcı/5 dk). Redis `seen:` kısıtı var; yük altında yine de WAL baskısı yaratır. Öneri: yazmaları toplu (batch) ya da asenkron kuyruğa alın.
4. **Yönetici `overview`:** tek SQL'de 20 alt-sorgu; `count(*) FROM message` (500k satır seq scan) ve `app_user` sayımları 144 ms ort. Öneri: toplam sayılar için `pg_class.reltuples` yaklaşığı veya 30-60 sn önbellek (Redis/Caffeine); `messagesPerDay`, `rsvpsPerDay` için günlük özet tablosu veya önbellek. `engagement` benzer (gün serileri).
5. **`app_user` yönetici listesi:** derin `OFFSET` (sayfa 400 → 8000 satır atlama, 23 ms). Büyürse keyset (created_at,id) sayfalama.
6. **Genel arama (`/api/search`)**: 513 ms p50 yük altında; 5 sağlayıcı sırayla çalışıyor (haber×3 tür, topluluk, etkinlik). Sağlayıcıları paralel çalıştırın ya da `NEWS` türlerini tek sorguda birleştirin (`searchHits` tür başına ayrı rank sorgusu). Etkinlik/topluluk `ILIKE '%q%'` şu an 3k/2k satırda seq scan, ucuz; **100k+ satırda** `pg_trgm` GIN gerekir (§7).
7. **Basic auth yönetici girişi her istekte bcrypt çalıştırır** (~100+ ms taban). Yönetim paneli JWT kullanıyor, sorun değil; betik/CI Basic auth kullanıyorsa bunu bilin.
8. **Login**: bcrypt maliyet 10, ~70 giriş/sn/çekirdek-grubu tavanı (CPU sınırlı, p50 420 ms @32 eşzamanlı). Tasarım gereği; rate limit (30/15 dk/IP) zaten kötüye kullanımı sınırlar. Kampüs NAT'ında IP limiti çok sıkı olabilir (CLAUDE.md §8 ile uyumlu not).

### 5.1 N+1 avı
Hibernate istatistik log'u ve `pg_stat_statements` ile yapılacak; araç `nplus1.js` (21 uç). Şimdilik yalnız depo imzalarından çıkarım (ölçüm değil): konuşma listesi için üye (`findByConversationIdInAndLeftAtIsNull`) ve `unreadCounts` sorguları `IN (...)` ile toplu yazılmış; `pg_stat_statements` yükünde de uç başına sabit sayıda sorgu göründü. Topluluk/etkinlik uçları ve `users/{id}` ölçülmedi (§7).

## 6. Havuz / Tomcat / JVM önerileri (ölçülmeden, kod ve gözlemlerle)
- **Hikari**: varsayılan `maximum-pool-size=10`. Postgres `max_connections=100`; tek backend için 20-30 uygun (formül: çekirdek×2 + disk, ~20). Çoklu replikada `replika × havuz < ~80`. `connection-timeout` 30 sn varsayılan çok uzun; kuyruk birikirse istekler 30 sn asılır → `spring.datasource.hikari.connection-timeout=5000` önerilir. Deney: `PERF_HIKARI_MAX=10/20/40` ile `mixed` CONC=128.
- **Tomcat**: varsayılan 200 iş parçacığı; sorgular ~1-5 ms olduğundan 200 thread havuzdan 10 bağlantıyı bekleyerek birikir. Havuz büyütülmezse `server.tomcat.threads.max=100` anlamlıdır. `server.tomcat.accept-count` ve WebSocket için ayrı kaynak yok (WS, Tomcat NIO bağlantılarını tutar; 500 bağlantı sorun değil, `ws-load` ile doğrulanacak).
- **JVM**: imaj `-XX:MaxRAMPercentage=75` kullanıyor, compose'ta konteyner bellek sınırı yok → heap, host RAM'inin %75'ine büyüyebilir (bu makinede ~6 GB). Gözlenen RSS yük altında ~740 MB. Öneri: compose'ta `mem_limit: 1g` (heap ≈ 750 MB) ve `-XX:+UseG1GC` (varsayılan), `-Xlog:gc` ile GC duraklamaları izlenmeli (`PERF_JAVA_OPTS`).
- **Postgres**: `shared_buffers=128MB` varsayılan, seed veri tabanı 255 MB; üretimde RAM'in %25'i (örn. 512 MB-1 GB), `work_mem` 4 MB yeterli, `random_page_cost=1.1` (SSD).
- **Basit önbellek**: `/api/news` ve `/api/menu` herkese açık ve günde bir değişir; `WebConfig` ETag zaten var, 30-60 sn `Cache-Control: public, max-age` eklemek tüm haber trafiğini ucuzlatır.

## 7. TEST AŞAMASI İÇİN (yığın açılınca)
1. `bash scripts/load/seed.sh && bash scripts/load/ab-indexes.sh` — `PUB_SCEN` (news_list, conversations, messages) A/B ve açık-2 turunu tamamla; V59 migration'ının Flyway'de uygulandığını (`flyway_schema_history` 59 = t) doğrula (önceki koşuda uygulandı).
2. `CONNS=500 node scripts/load/ws-load.js` ve `CONNS=200`: kayıp %0, p95 ≤ 250 ms; `RATE=0.5 SENDERS=10` ile limit testi; sunucu CPU/bellek (`docker stats`) ve `wc -l` bağlantı sayısı. WS el sıkışma limiti IP başına 600/dk: betik `rl:ws:*` temizler.
3. `node scripts/load/nplus1.js` — çıktıdaki "şüpheli" sütunu boş olmayan uçlar için düzeltme önerisi ekleyin.
4. Hikari 10/20/40 × Tomcat 100/200 ile `mixed` CONC=64/128 (aynı JVM ısınma süresiyle).
5. İndeks adayları (kanıt bekliyor, V59'a **yazılmadı**): `user_event`/`community` için `pg_trgm` GIN (3k/2k satırda planlayıcı seq scan'i seçiyor; satır sayısı 50k+ olunca yeniden ölç); `notification (user_id) WHERE read_at IS NULL` (kullanıcı başı ~10 bildirimde kazanç yok; bir kullanıcıda binlerce okunmamış olursa); `news_item` tür+tarih sayfa sorgusu planlayıcı hâlâ `idx_news_date`'i seçiyor (küçük tablo) — yeni indeks 100k+ satırda kullanılmalı, doğrula.
6. `explain.sh`'ı V59 sonrası tekrar koş, bu belgedeki "sonra" sütununu yük altındaki `pg_stat_statements` ort. sürelerle teyit et.
7. `mvn -B test` (V59 H2 testlerini etkilemez; Flyway testlerde kapalı) ve `smoke-*.sh` regresyonu.
