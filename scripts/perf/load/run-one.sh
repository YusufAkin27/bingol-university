#!/usr/bin/env bash
# Tek senaryo kosusu: sayaclari sifirla -> kaynak ornekleyici baslat -> k6 -> ornekleyici durdur -> DB/Redis sonuclarini topla.
# Kullanim: run-one.sh <etiket> <betik.js> [k6 -e K=V ...]
# Ortam (run-load.sh ayarlar): OUT_DIR (sonuc klasoru), FX_HOST (prep.js ciktisi, ana makine yolu), K6_CMD (varsayilan docker),
#   APP_BASE_HOST (ornekleyicinin actuator adresi), PSQL_CMD, REDIS_CMD, NET (k6 ag adi), K6_BASE (k6'nin gordugu adres)
set -u
LABEL="$1"; SCRIPT="$2"; shift 2
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:?OUT_DIR gerekli}"; FX_HOST="${FX_HOST:?FX_HOST gerekli}"
PSQL="${PSQL_CMD:-docker exec -i bu_ld_pg psql -U bingol -d bingol}"
REDIS="${REDIS_CMD:-docker exec bu_ld_redis redis-cli}"
K6_BASE="${K6_BASE:-http://ldapp:8080}"
NET="${NET:-bu_ld_net}"
mkdir -p "$OUT_DIR"
winp() { (cd "$1" && (pwd -W 2>/dev/null || pwd)); }
FX_HOST_DOCKER="$(winp "$FX_HOST")"; OUT_DIR_DOCKER="$(winp "$OUT_DIR")"

# sayaclar + hiz siniri anahtarlari temiz baslasin (onceki senaryonun 429'lari tasinmasin)
echo "SELECT pg_stat_statements_reset(); SELECT pg_stat_reset();" | $PSQL >/dev/null 2>&1
$REDIS eval "for _,k in ipairs(redis.call('keys','rl:*')) do redis.call('del',k) end return 1" 0 >/dev/null 2>&1

TOKEN="$(node -e "console.log(require(process.argv[1]).adminToken)" "$FX_HOST_DOCKER/fixtures.json")"
BASE="${APP_BASE_HOST:-http://localhost:18480}" TOKEN="$TOKEN" OUT="$OUT_DIR/$LABEL.res" node "$HERE/sample.js" > "$OUT_DIR/$LABEL.res.summary.json" &
SAMPLER=$!

if [ -n "${K6_CMD:-}" ]; then
  # VPS/yerel k6: K6_CMD="k6 run" gibi; FX_DIR/OUT_DIR/BASE ortami betiklere gecer
  SCEN_NAME="$LABEL" FX_DIR="$FX_HOST" OUT_DIR="$OUT_DIR" BASE="$K6_BASE" $K6_CMD --summary-trend-stats="min,med,avg,p(90),p(95),p(99),max" "$HERE/$SCRIPT" "$@"
else
  MSYS_NO_PATHCONV=1 docker run --rm --network "$NET" -m 2g -e GOMEMLIMIT=1500MiB -v "$(cd "$HERE" && (pwd -W 2>/dev/null || pwd)):/load:ro" \
    -v "$FX_HOST_DOCKER:/fx:ro" -v "$OUT_DIR_DOCKER:/out" -e BASE="$K6_BASE" -e "SCEN_NAME=$LABEL" \
    grafana/k6 run --quiet --no-usage-report "$@" "/load/$SCRIPT"
fi
RC=$?

touch "$OUT_DIR/$LABEL.res.stop"; wait $SAMPLER 2>/dev/null
PSQL_CMD="$PSQL" REDIS_CMD="$REDIS" bash "$HERE/collect-db.sh" "$LABEL" "$OUT_DIR" >/dev/null
echo "[$LABEL] k6 cikis kodu=$RC; kaynak ozeti: $(cat "$OUT_DIR/$LABEL.res.summary.json" 2>/dev/null | head -c 600)"
exit 0
