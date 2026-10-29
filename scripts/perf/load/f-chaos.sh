#!/usr/bin/env bash
# Senaryo F: KARISIK COKME TESTI (yalniz test yigini!). Hafif okuma yuku altinda:
#   F1) kilit zaman asimi: bir tabloya ACCESS EXCLUSIVE kilidi -> uygulama oturumundaki lock_timeout=3s calismali (kisa 503/hata, takili kalma yok)
#   F2) veritabani 5 sn donar (docker pause) -> 503 DB_TIMEOUT / toparlanma, surec cokmez, restart yok
#   F3) Redis 5 sn donar -> auth/hiz siniri davranisi, toparlanma
# Kullanim: OUT_DIR=... FX_HOST=... bash f-chaos.sh   (run-load.sh cagirir; docker konteyner adlari: bu_ld_app/pg/redis)
# Ortam: BASE_HOST (http://localhost:18480), PSQL_CMD, PG_CT, REDIS_CT, APP_CT
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:?}"; FX_HOST="${FX_HOST:?}"
BASE_HOST="${BASE_HOST:-http://localhost:18480}"
PG_CT="${PG_CT:-bu_ld_pg}"; REDIS_CT="${REDIS_CT:-bu_ld_redis}"; APP_CT="${APP_CT:-bu_ld_app}"
PSQL="${PSQL_CMD:-docker exec -i $PG_CT psql -U bingol -d bingol}"
winp() { (cd "$1" && (pwd -W 2>/dev/null || pwd)); }
FXW="$(winp "$FX_HOST")"
TOKEN="$(node -e "const f=require(process.argv[1]);console.log(require(process.argv[2])[7])" "$FXW/fixtures.json" "$FXW/tokens.json")"
LOG="$OUT_DIR/F-chaos.log"; : > "$LOG"
say() { echo "$@" | tee -a "$LOG"; }

probe() { # 1 saniyede bir: ad, http kodu, sure
  local end=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    curl -s -o /tmp/ld_probe_body -w "%{http_code} %{time_total}" --max-time 45 -H "Authorization: Bearer $TOKEN" -H "X-Forwarded-For: 10.250.0.1" "$BASE_HOST/api/me/summary" > /tmp/ld_probe_out
    echo "$(date +%H:%M:%S) $(cat /tmp/ld_probe_out) $(head -c 90 /tmp/ld_probe_body | tr '\n' ' ')" >> "$2"
    sleep 1
  done
}

STARTED_BEFORE="$(docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' "$APP_CT")"
say "uygulama baslangic/restart (once): $STARTED_BEFORE"

# arka plan yuku: 100 VU okuma karisimi, 150 sn
( OUT_DIR="$OUT_DIR" FX_HOST="$FX_HOST" bash "$HERE/run-one.sh" F-chaos-bg b-read.js -e VUS=100 -e DURATION=270s -e WARMUP_S=15 -e RAMP_S=5 > "$OUT_DIR/F-chaos-bg.out" 2>&1 ) &
BG=$!
sleep 40

say "== F1: lock_timeout (notification tablosu 12 sn ACCESS EXCLUSIVE)"
( echo "BEGIN; LOCK TABLE notification IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(12); COMMIT;" | $PSQL >/dev/null 2>&1 ) &
LK=$!
sleep 1
T0=$(date +%s.%N)
curl -s -o /tmp/ld_f1_body -w "http=%{http_code} sure=%{time_total}s\n" --max-time 30 -H "Authorization: Bearer $TOKEN" -H "X-Forwarded-For: 10.250.0.2" "$BASE_HOST/api/notifications?size=5" | tee -a "$LOG"
say "govde: $(head -c 200 /tmp/ld_f1_body)"
wait $LK
say "(beklenen: ~3 sn sonra 503/hata; 12 sn takili kalma = lock_timeout calismiyor)"
sleep 8

say "== F2: veritabani 5 sn donar (docker pause)"
probe 30 "$OUT_DIR/F2-probe.txt" &
PR=$!
sleep 8
docker pause "$PG_CT" >/dev/null; say "pg PAUSE $(date +%H:%M:%S)"
sleep 5
docker unpause "$PG_CT" >/dev/null; say "pg UNPAUSE $(date +%H:%M:%S)"
wait $PR
say "F2 prob zaman cizelgesi (saat kod sure govde):"; cat "$OUT_DIR/F2-probe.txt" | tee -a "$LOG" | sed -n 1,40p
sleep 5

say "== F2b: veritabani 36 sn donar (JDBC socketTimeout=30 sn: istek ~30 sn sonra 503 DB_TIMEOUT ile bitmeli, sonsuz beklememeli)"
probe 70 "$OUT_DIR/F2b-probe.txt" &
PR=$!
sleep 6
docker pause "$PG_CT" >/dev/null; say "pg PAUSE $(date +%H:%M:%S)"
sleep 36
docker unpause "$PG_CT" >/dev/null; say "pg UNPAUSE $(date +%H:%M:%S)"
wait $PR
awk '{print $1, $2, $3}' "$OUT_DIR/F2b-probe.txt" | tee -a "$LOG" | sed -n 1,80p
sleep 10

say "== F3: Redis 5 sn donar"
probe 25 "$OUT_DIR/F3-probe.txt" &
PR=$!
sleep 6
docker pause "$REDIS_CT" >/dev/null; say "redis PAUSE $(date +%H:%M:%S)"
sleep 5
docker unpause "$REDIS_CT" >/dev/null; say "redis UNPAUSE $(date +%H:%M:%S)"
wait $PR
cat "$OUT_DIR/F3-probe.txt" | tee -a "$LOG" | sed -n 1,40p

wait $BG
STARTED_AFTER="$(docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' "$APP_CT")"
say "uygulama baslangic/restart (sonra): $STARTED_AFTER"
[ "$STARTED_BEFORE" = "$STARTED_AFTER" ] && say "SUREC CALISMAYA DEVAM ETTI (yeniden baslama yok)" || say "UYARI: uygulama yeniden basladi"
curl -s "$BASE_HOST/actuator/health" | tee -a "$LOG"; echo | tee -a "$LOG"
tail -5 "$OUT_DIR/F-chaos-bg.out" | tee -a "$LOG"
