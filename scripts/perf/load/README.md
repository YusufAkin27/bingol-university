# 20 bin kullanıcılık yük testi paketi (k6)

Mobilin ana yollarını, yazma/yarış durumlarını, WebSocket'i, yönetim panelini ve çökme dayanıklılığını ölçer; sonuçları
`docs/perf-results/<tarih>/` altına yazar. Yorum ve bulgular: [docs/PERFORMANCE.md](../../../docs/PERFORMANCE.md) "20k yük testi".
Eski/ilişkisiz araçlar: `scripts/perf/perf-api.js` (tek kullanıcı, hızlı), `scripts/load/*` (T6, Node tabanlı), `scripts/k6/*` (duman).

> **YALNIZ test yığını!** Seed betikleri `-v confirm=I_AM_DEV_ONLY` ister ve gerçek kullanıcı varsa durur; `prep.js` sunucunun
> `JWT_SECRET`'ı ile token üretir (giriş/bcrypt maliyeti ve hız sınırı ölçümü bozmasın diye). Üretime ASLA çalıştırmayın.

## Dosyalar

| Dosya | Amaç |
|---|---|
| `run-load.sh` | Hepsini yapar: (yerel modda) yığını kurar, seed eder, ısınır, senaryoları koşar, bütünlüğü denetler, özet yazar, yığını siler |
| `seed-load-extra.sql` | `scripts/perf/seed-20k.sql` üstüne: yönetici, gerçek bcrypt parolası, 100 kulüp/5 bin üyelik, 200 etkinlik + RSVP, kapasite yarışı etkinliği, 30 bin gönderi (+görsel kaydı), 300 bin takip, 3000 haber, menü, 21 anket |
| `prep.js` | Veritabanından kimlikleri okur, `tokens.json` (20 bin JWT) + `fixtures.json` yazar (`.fixtures/`) |
| `lib.js` | Ortak yardımcılar: istek sarmalayıcı (429 ve hata ayrı sayılır), VU başına `X-Forwarded-For`, ısınma/ölçüm ayrımı (`phase`), özet |
| `a-auth.js` | A: 500 eşzamanlı giriş + refresh (+ arka plan yükü ile) |
| `b-read.js` | B: okuma karışımı (ana sayfa, akış + imleç, sohbet, bildirim, etkinlik, kulüp, haber, menü, arama); VU basamakları |
| `c-write.js`, `c-race.js` | C: mesaj/beğeni/takip/RSVP yazma karışımı; kapasite ve tek-oy yarışları |
| `d-ws.js` | D: 1000 eşzamanlı STOMP bağlantısı, teslim/ack gecikmesi, presence |
| `e-admin.js` | E: yönetici listeleri/raporlar + 20k satır CSV |
| `f-chaos.sh` | F: kilit zaman aşımı, DB/Redis 5 sn donma, toparlanma |
| `g-endpoints.js` | G: uç başına kapasite (kapalı döngü, RPS) — en pahalı yolları bulur |
| `run-one.sh`, `sample.js`, `collect-db.sh` | Tek koşu: sayaç sıfırla, JVM/konteyner örnekle, k6, `pg_stat_statements`/seq scan/önbellek/kilit/Redis topla |
| `integrity.sql` | Kapasite aşımı, çift oy, çift sayaç, mükerrer mesaj denetimi (hepsi 0 olmalı) |
| `jfr-top.js` | JFR örneklerinden CPU sıcak noktaları (`jfr print --stack-depth 40 --events jdk.ExecutionSample`) |
| `summarize.js` | Senaryo JSON'larını `SUMMARY.md` + `results.json` olarak toplar |

## Yerelde (Docker, VPS'i taklit eden sınırlar)

Gereken: Docker (≥ 7 GB), Node 22+, `grafana/k6` imajı (otomatik çekilir). Yığın `bu_ld_*` adlarıyla ayrı ağda kurulur
(mevcut compose yığınlarına dokunmaz). Sınırlar: PostgreSQL 2 GB / 2 CPU (üretim `postgresql.conf` değerleri,
`pg_stat_statements` açık), uygulama 2 GB / 2 CPU / `-Xmx1g` / Hikari 30, Redis 300 MB (`maxmemory 200mb volatile-lru`).

```bash
# repo kökünden (Git Bash)
bash scripts/perf/load/run-load.sh                  # hepsi (~1,5 saat)
SCENARIOS="B" CAPACITY="100 200" bash scripts/perf/load/run-load.sh   # yalnız okuma karışımı
KEEP=1 bash scripts/perf/load/run-load.sh           # bitince yığını silme
```

Yük üreticisi aynı makinede çalışır: ölçüm, k6'nın kendi CPU'sundan etkilenir (12 çekirdekli makinede k6 genelde 1-2 çekirdek).

## VPS'te (gerçek ölçüm)

Hedef: 4 vCPU / 8 GB. **Üretim veritabanına değil**, aynı özellikte bir *staging* kopyasına koşun (seed, `app_user` tablosunda
gerçek veri varsa durur). Yük üretici ayrı bir makineden gelmeli (aksi halde sunucu kaynağını paylaşır). Staging'de
`JWT_SECRET`'ı bilmek, `ADMIN_EMAILS` içine `ld.admin@bingol.edu.tr` yazmak, `/actuator/metrics`'e erişim (isteğe bağlı) gerekir.

```bash
# 1) k6 kurulu bir yük makinesinde (veya Docker); staging'e erişen bir psql komutu verin
export MODE=remote BASE=https://staging.ornek.net JWT_SECRET='<staging-sirri>'
export PSQL_CMD='ssh vps "docker compose -f docker-compose.prod.yml exec -T postgres psql -U bingol -d bingol"'
export REDIS_CMD='ssh vps "docker compose -f docker-compose.prod.yml exec -T redis redis-cli"'
export K6_CMD='k6 run' SEED=1 SCENARIOS="G B C D E"      # F (chaos) docker pause kullanir: VPS'te elle/yerelde
bash scripts/perf/load/run-load.sh
```

`TRUSTED_PROXIES`: k6'nın gönderdiği `X-Forwarded-For` yalnızca güvenilir proxy'den (Caddy) geliyorsa dikkate alınır; staging'de
yük makinesini önündeki proxy aracılığıyla çalıştırın ya da `APP_SECURITY_TRUSTED_PROXIES` içine yük makinesini ekleyin, aksi halde
tüm istekler tek IP sayılır ve giriş/refresh hız sınırlarına (200/15 dk, 300/15 dk) takılır (gerçek kampüs NAT riski ile aynı etki).

## Okuma kılavuzu

- **Isınma şart:** soğuk JVM'de ilk dakikalarda aynı yük 10-20 kat yavaştır (JIT). `run-load.sh` 4 dk ısınır; kendi koşunuzda
  `WARMUP_S` ile (örn. 240) uzatın. Soğuk açılış davranışı da bir bulgudur (bkz. PERFORMANCE.md).
- Eşikler: okuma p95 < 400 ms, yazma p95 < 800 ms, hata ≈ 0 (429 ayrı sayılır). k6 çıkış kodu 99 = bir eşik aşıldı.
- `*.db.txt`: en yavaş/en çok çağrılan sorgular, seq scan, önbellek isabeti. `*.res.summary.json`: CPU/heap/GC/Hikari.
- `integrity.txt`: tüm ihlal sayıları **0** olmalı.
