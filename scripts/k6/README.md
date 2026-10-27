# k6 yük testleri

Senaryolar: `smoke.js` (hafif duman), `feed.js` (akış okuma + beğeni), `chat.js` (sohbet REST + STOMP/WebSocket), `auth.js` (giriş/refresh, hız sınırı davranışı). Ortak: `lib.js`. Eşikler: p95 < 500 ms, hata < %1 (`chat_ack_ms` p95 < 800 ms).

## Önkoşullar

- Yalnızca **staging** veya yerel yığın. Üretime çalıştırmayın.
- Test hesapları önceden oluşturulmuş ve doğrulanmış olmalı (`scripts/make-user.sh`). Giriş uç noktası hız sınırlıdır (IP başına 30/15 dk, e-posta başına 10/15 dk); token'lar `setup()` içinde bir kez alınır. Access token 15 dk geçerlidir: senaryoları ~12 dakikayı geçirmeyin.
- Sohbet senaryosu için hesabın en az bir sohbeti olmalı (bkz. `scripts/seed-demo-chat.js`).

## Ortam değişkenleri

| Değişken | Anlam |
|---|---|
| `BASE_URL` | API kökü (varsayılan `http://localhost:8080`) |
| `K6_EMAIL`, `K6_PASSWORD` | Birinci test hesabı; `K6_EMAIL_2`/`K6_PASSWORD_2` ... `_10` ek hesaplar (VU'lar dağıtılır) |
| `VUS`, `DURATION`, `RAMP`, `HOLD` | Senaryoya göre yük ayarı |
| `WS_URL` | WebSocket tabanı (varsayılan `BASE_URL` şemasının `ws(s)` karşılığı) |
| `WRITE_POSTS=1` | `feed.js` içinde seyrek gönderi oluşturur (varsayılan kapalı) |

## Çalıştırma

k6 kuruluysa:

```bash
k6 run -e BASE_URL=http://localhost:8080 -e K6_EMAIL=ogrenci@bingol.edu.tr -e K6_PASSWORD=... scripts/k6/smoke.js
```

Kurulu değilse Docker ile (repo kökünden, Git Bash):

```bash
MSYS_NO_PATHCONV=1 docker run --rm -i -v "$(pwd -W):/work" -w /work \
  -e BASE_URL=http://host.docker.internal:8080 -e K6_EMAIL -e K6_PASSWORD \
  grafana/k6 run scripts/k6/feed.js
```

GitHub Actions: **k6 load** iş akışı (elle tetiklenir; `K6_EMAIL`/`K6_PASSWORD` sırları, `STAGING_URL` değişkeni).

Sözdizimi doğrulama (k6 olmadan): `node --check` ES modülü import'larını çalıştırmaz; `scripts/check-workflows.js` yalnızca iş akışlarını denetler. k6 betikleri için `node --input-type=module --check < dosya.js` kullanılır.

## Yorum

- `http_req_duration{name:...}` ile uç nokta bazında bakın; URL'ler `name` etiketiyle normalize edilmiştir.
- 429 yanıtları `feed.js`/`chat.js` içinde "beklenen" sayılır (hız sınırı çalışıyor demektir); çok fazla 429 görürseniz VU sayısını ya da hesap sayısını artırın.
- Sunucu tarafı: Grafana "BU Uygulama" panosunda (docs/OBSERVABILITY.md) aynı anda CPU, havuz ve gecikmeyi izleyin.
