# API hiz testi (perf-api.js)

Calisan yigina karsi mobil ana yollarini olcer. Harici paket gerekmez (Node 24).

```bash
docker compose up -d --build
BASE=http://localhost:8080 node scripts/perf/perf-api.js
```

Ortam degiskenleri:

| Ad | Varsayilan | Anlam |
|---|---|---|
| `BASE` | `http://localhost:8080` | Backend adresi |
| `PERF_EMAIL` / `PERF_PASSWORD` | `mobil.test@bingol.edu.tr` / `BuTest2026x` | Test kullanicisi (kayitli ve dogrulanmis olmali) |
| `PERF_N` | 50 | Uc basina olcum istegi |
| `PERF_C` | 5 | Eszamanlilik |
| `PERF_WARMUP` | 5 | Isinma istegi |
| `PERF_P95_MS` | 400 | p95 esigi (ms) |

Cikti: p50/p90/p95/p99/ortalama/max (ms), hata, 429 sayisi, yanit boyutu (bayt), ETag/304 sonucu.
Sonuc `scripts/perf/last-run.json` dosyasina yazilir (gitignore).

Cikis kodu: 0 = tum uclar esik icinde; 1 = esik asimi veya hata; 2 = giris/betik hatasi.

Notlar: 429 hata sayilmaz, ayrica sayilir ve betik geri ceker. Betik her kosuda yalnizca bir kez giris yapar. `/api/me/summary` 404 donerse atlanir. Rate limit sik tetiklenirse `docker compose exec -T redis redis-cli flushall` calistirin. Yorumlama: `docs/PERFORMANCE.md`.
