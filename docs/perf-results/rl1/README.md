# RL1b: tek ankete eş zamanlı oy ölçümü (2026-10-29)

Amaç: tek ankete 300-600 eş zamanlı oyda `lock_timeout` aşımı (503 `DB_TIMEOUT`) ve Hikari havuzunun dolmasını önlemek.
Yöntem: `scripts/perf/load/rl1/run-rl1.sh` (`poll-burst.mjs`), proje adı `rl1b`, gerçek PostgreSQL 16 (2 CPU / 2 GB, `lock_timeout=3 s`, `statement_timeout=8 s`), uygulama 2 CPU / 2 GB / `-Xmx1g` / Hikari 30, Redis, **soğuk JVM** (ölçümden önce yalnız 3 giriş + 100 oyluk ısınma turu). Her tur: N kullanıcı aynı anda oy verir; ilk 50 kullanıcı AYNI ANDA ikinci (farklı seçenekli) istek de yollar (çift/yarış denemesi): 100 için 150, 300 için 350, 600 için 650 istek.

- **ÖNCE:** `HEAD` (20b258d) kaynağından derlenen jar (anket satırı `FOR UPDATE` ile kilitlenir). Dosyalar: `poll-*-once.json`.
- **SONRA:** `HEAD` + `PollBallotRepository` / `PollRepository` / `PollVoteService` değişikliği (anket satırı kilitlenmez; kullanıcı ballot kilidi + sıralı atomik sayaç `UPDATE`). `sonra`, `sonra2` = ilk taslak (lock_timeout yeniden denemesi YOK); `sonra3`, `sonra4` = son kod (lock_timeout için en çok 2 kısa yeniden deneme).
- Uyarı: bu bir **kıyaslama** ölçümüdür, mutlak kapasite değildir. İstemci (node) aynı makinede çalışır, JVM soğuktur, 2 CPU sınırlıdır; gecikmeler bu yüzden yüksektir. Hikari havuz zirvesi örnekleyicisi (`hikariPeak`) `/actuator/metrics` erişimi olmadığından 0 döndü: **havuz doluluğu bu turlarda ölçülemedi**, dolaylı kanıt 503/`ETIMEDOUT` sayısı ve PostgreSQL kilit bekleme günlüğüdür.

| N (istek) | Kod | 200 | 503 DB_TIMEOUT | diğer | 200'lerde p50 | p95 | tur süresi | PG "still waiting" / lock_timeout iptali (3 tur toplamı) |
|---|---|---|---|---|---|---|---|---|
| 100 (150) | önce | 148 | 2 | 0 | 17,6 sn | 19,5 sn | 20,3 sn | 33 / 0 |
| 300 (350) | önce | 347 | 3 | 0 | 17,4 sn | 23,1 sn | 24,2 sn | |
| 600 (650) | önce | 640 | 10 | 0 | 25,2 sn | 35,0 sn | 36,0 sn | |
| 100 (150) | sonra3 | 150 | 0 | 0 | 7,9 sn | 9,0 sn | 9,2 sn | 12 / 2 |
| 300 (350) | sonra3 | 350 | 0 | 0 | 10,3 sn | 12,7 sn | 13,1 sn | |
| 600 (650) | sonra3 | 650 | 0 | 0 | 11,8 sn | 17,6 sn | 18,1 sn | |
| 100 (150) | sonra4 | 150 | 0 | 0 | 7,1 sn | 7,9 sn | 8,1 sn | 14 / 0 |
| 300 (350) | sonra4 | 350 | 0 | 0 | 8,7 sn | 10,7 sn | 11,1 sn | |
| 600 (650) | sonra4 | 650 | 0 | 0 | 11,8 sn | 17,1 sn | 17,4 sn | |

Taslak kodla (yeniden denemesiz) ek turlar: `sonra`: 150/350/650 isteğin tamamı 200 (3 turda 0 hata); `sonra2`: 600 turunda 1 `503 DB_TIMEOUT` + 1 istemci `ECONNRESET` (tek bir `lock_timeout` iptali) -> bu nedenle lock_timeout yeniden denemesi eklendi. İlk, ardışık olmayan bir `sonra` denemesi iki ölçüm betiğinin aynı proje adına çakışması yüzünden geçersizdi ve bu tablodan çıkarıldı (dosyalar aynı etiketle ardışık koşuyla yeniden yazıldı).

## Veri bütünlüğü (her tur, hem önce hem sonra)
`integrity.ok = true`: `poll_ballot` satırı = `poll.voter_count` = `poll_vote` satırı = `poll_option.vote_count` toplamı; çift ballot 0, çift oy 0; her seçeneğin sayacı kendi oy satırı sayısına eşit. (Gizli oy: `poll_vote.user_id` yalnız tekillik için tutulur, hiçbir uç göstermez; değişmedi.) Tek-oy kuralı: aynı kullanıcının aynı anda gönderdiği iki farklı seçenekli istek -> biri ilk oy, diğeri değişiklik (ya da aynı oy idempotent); sonuçta kullanıcı başına tek ballot.

## Kampüs NAT girişi (RL1, `nat-sonra.json`)
Tek IP'den 300 farklı kullanıcı: giriş 300/300 `200` (p50 615 ms, p95 1102 ms), refresh 300/300 `200` (p95 223 ms); tek hesaba kaba kuvvet 11. denemede `429` (10 yanlış `401`); aynı NAT'ta başka cihazdan kurban ve başka kullanıcı `200`; dağıtık 80 IP'li kaba kuvvet e-posta başına 60. denemeden sonra `429`. Bu ölçüm yalnız RL1 sonrası kodla yapıldı (RL1 öncesi kod yeniden koşturulmadı).
