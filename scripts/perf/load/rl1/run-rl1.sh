#!/usr/bin/env bash
# RL1 olcumu (YALNIZ test yigini): kampus NAT girisi + tek ankete es zamanli oy. Kullanim (Git Bash, repo kokunden):
#   JAR=/yol/backend.jar LABEL=once bash scripts/perf/load/rl1/run-rl1.sh
# Ortam: JAR (zorunlu), PROJ (compose proje adi, varsayilan rl1), LABEL (cikti dosya eki), APP_PORT (18611), VOTES="300 600", OUT (varsayilan docs/perf-results/rl1),
#        SKIP_NAT=1 / SKIP_POLL=1, KEEP=1 (bitince yigini silme; varsayilan: compose -p $PROJ down -v)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${JAR:?JAR gerekli}"
LABEL="${LABEL:-run}"; APP_PORT="${APP_PORT:-18611}"; VOTES="${VOTES:-300 600}"
OUT="${OUT:-$HERE/../../../../docs/perf-results/rl1}"; mkdir -p "$OUT"
export APP_PORT JAR="$(cd "$(dirname "$JAR")" && pwd -W 2>/dev/null || pwd)/$(basename "$JAR")"
export MSYS_NO_PATHCONV=1
export JWT_SECRET=rl1-load-test-jwt-secret-0123456789abcdef BASE="http://localhost:$APP_PORT"
PROJ="${PROJ:-rl1}"   # compose proje adi (paralel ajanlar icin: PROJ=rl1b)
HW="$(cd "$HERE" && pwd -W 2>/dev/null || pwd)"   # docker.exe icin Windows yolu
DC() { docker compose -p "$PROJ" -f "$HW/compose.yml" "$@"; }   # yolda bosluk olabilir
PSQL() { DC exec -T postgres psql -U bingol -d bingol "$@"; }
export PSQL_CMD="docker exec -i $PROJ-postgres-1 psql -U bingol -d bingol"

DC down -v >/dev/null 2>&1
DC up -d >/dev/null || exit 1
until curl -sf "$BASE/actuator/health" >/dev/null 2>&1; do sleep 3; done
PSQL -v confirm=I_AM_DEV_ONLY -f - < "$HERE/seed-rl1.sql" > "$OUT/seed-$LABEL.log" 2>&1
# Isinma (JIT): ilgisiz giris/okuma istekleri olcume katilmaz
for i in 1 2 3; do curl -s -o /dev/null -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d '{"email":"rl1u700@bingol.edu.tr","password":"LoadTest-2026!","client":"web"}'; done

if [ "${SKIP_NAT:-0}" != "1" ]; then
  docker exec $PROJ-redis-1 redis-cli flushall >/dev/null
  echo "== NAT girisi ($LABEL) =="; (cd "$HERE" && node nat-login.mjs) | tee "$OUT/nat-$LABEL.json"
fi
if [ "${SKIP_POLL:-0}" != "1" ]; then
  for n in $VOTES; do
    echo "== anket oyu N=$n ($LABEL) =="
    (cd "$HERE" && N=$n DOUBLE=50 node poll-burst.mjs) | tee "$OUT/poll-$n-$LABEL.json"
  done
  echo "pg log: kilit bekleme satiri = $(DC logs postgres 2>/dev/null | grep -c 'still waiting for'), lock timeout iptali = $(DC logs postgres 2>/dev/null | grep -c 'due to lock timeout')" | tee "$OUT/poll-pglog-$LABEL.txt"
fi
[ "${KEEP:-0}" = "1" ] || { DC down -v >/dev/null 2>&1; echo "yigin silindi (down -v)"; }
