#!/usr/bin/env bash
# 20 bin kullanicilik yuk testi paketi: (yerel modda) izole Docker yigini kurar, seed'ler, senaryolari sirayla kosar,
# veri butunlugunu denetler ve sonuclari docs/perf-results/<tarih>/ altina yazar.
#
# YEREL (varsayilan, VPS'i taklit eden sinirlar: pg 2 GB/2 CPU, uygulama 2 GB/2 CPU, redis 300 MB):
#   JAR=/yol/backend.jar JWT_SECRET=... bash scripts/perf/load/run-load.sh
#   (JAR yoksa 'mvn -DskipTests package' icin Docker'daki maven imaji kullanilir; ortak kilit: /tmp/mvn.lock)
# UZAK / VPS (yigin ve veri zaten var; yalniz yuk uretilir):
#   MODE=remote BASE=https://staging.ornek.net JWT_SECRET=<sunucudaki> PSQL_CMD="docker compose exec -T postgres psql -U bingol -d bingol" \
#   REDIS_CMD="docker compose exec -T redis redis-cli" K6_CMD="k6 run" bash scripts/perf/load/run-load.sh
#   (docs/PERFORMANCE.md "VPS'te nasil kosulur": seed icin SEED=1, UYARI: yalniz bos/test veritabani!)
#
# Ortam: SCENARIOS="G A B C D E F H" (varsayilan hepsi; H = soguk baslangic), VUS_B=300, CAPACITY="100 200 400", STRESS=1, WARM_MIN=4 (JVM isinma, dk),
#        OUT_ROOT=docs/perf-results, KEEP=1 (bitince yigini silme), SEED=1 (uzak modda da seed), SKIP_SEED=1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
MODE="${MODE:-docker}"
SCENARIOS="${SCENARIOS:-G A B C D E F H}"
VUS_B="${VUS_B:-300}"; CAPACITY="${CAPACITY:-100 200 400}"; WARM_MIN="${WARM_MIN:-4}"
JWT_SECRET="${JWT_SECRET:-ld-load-test-jwt-secret-0123456789abcdef}"
STAMP="${STAMP:-$(date +%Y-%m-%d)}"
OUT_ROOT="${OUT_ROOT:-$ROOT/docs/perf-results}"
OUT_DIR="$OUT_ROOT/$STAMP"; mkdir -p "$OUT_DIR"
FX_HOST="${FX_HOST:-$HERE/.fixtures}"; mkdir -p "$FX_HOST"
export OUT_DIR FX_HOST JWT_SECRET
winp() { (cd "$1" && (pwd -W 2>/dev/null || pwd)); }

if [ "$MODE" = "docker" ]; then
  APP=bu_ld_app; PG=bu_ld_pg; RD=bu_ld_redis; NET=bu_ld_net; DB_PASS="${DB_PASS:-ldpass-12345}"
  export PSQL_CMD="docker exec -i $PG psql -U bingol -d bingol" REDIS_CMD="docker exec $RD redis-cli"
  export K6_BASE="http://ldapp:8080" APP_BASE_HOST="http://localhost:${APP_PORT:-18480}" NET
  docker network create $NET >/dev/null 2>&1
  docker run -d --name $PG --network $NET --network-alias postgres -m 2g --cpus 2 --shm-size 256m \
    -e POSTGRES_DB=bingol -e POSTGRES_USER=bingol -e POSTGRES_PASSWORD="$DB_PASS" postgres:16-alpine postgres \
    -c shared_preload_libraries=pg_stat_statements -c pg_stat_statements.max=5000 -c shared_buffers=512MB -c effective_cache_size=1280MB \
    -c work_mem=8MB -c maintenance_work_mem=128MB -c max_connections=100 -c max_wal_size=2GB -c min_wal_size=256MB \
    -c checkpoint_completion_target=0.9 -c random_page_cost=1.1 -c effective_io_concurrency=200 -c autovacuum_max_workers=4 \
    -c autovacuum_naptime=30s -c autovacuum_vacuum_cost_limit=800 -c log_min_duration_statement=500 -c log_lock_waits=on \
    -c log_temp_files=10MB -c temp_file_limit=2GB -c track_io_timing=on >/dev/null
  docker run -d --name $RD --network $NET --network-alias redis -m 300m redis:7-alpine redis-server --maxmemory 200mb --maxmemory-policy volatile-lru --save "" >/dev/null
  until docker exec $PG pg_isready -U bingol >/dev/null 2>&1; do sleep 2; done
  echo "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" | $PSQL_CMD >/dev/null

  JAR="${JAR:-$HERE/.build/backend.jar}"
  if [ ! -f "$JAR" ]; then
    mkdir -p "$HERE/.build/src" && cp -r "$ROOT/backend/src" "$ROOT/backend/pom.xml" "$HERE/.build/src/"
    until mkdir /tmp/mvn.lock 2>/dev/null; do sleep 15; done
    MSYS_NO_PATHCONV=1 docker run --rm -m 3g -v "$(winp "$HERE/.build/src"):/app" -v bu-m2:/root/.m2 -w /app maven:3-eclipse-temurin-17 mvn -B -q -DskipTests package
    rmdir /tmp/mvn.lock
    cp "$HERE/.build/src/target/"*.jar "$JAR"
  fi
  mkdir -p "$HERE/.build/storage"
  # Uygulama: uretim ayarlari (Hikari 30, rate limit varsayilanlari); dev profili yalniz actuator/metrics icin, log INFO
  MSYS_NO_PATHCONV=1 docker run -d --name $APP --network $NET --network-alias ldapp -m 2g --cpus 2 -p "${APP_PORT:-18480}:8080" \
    -v "$(winp "$(dirname "$JAR")")/$(basename "$JAR"):/app/app.jar:ro" -v "$(winp "$HERE/.build/storage"):/data/uploads" \
    -e SPRING_PROFILES_ACTIVE=dev -e LOGGING_LEVEL_EDU_BINGOL=INFO -e DB_URL=jdbc:postgresql://postgres:5432/bingol -e DB_USER=bingol -e DB_PASSWORD="$DB_PASS" \
    -e REDIS_HOST=redis -e JWT_SECRET="$JWT_SECRET" -e ADMIN_PASSWORD=test-admin-sifre-12 -e ADMIN_EMAILS=ld.admin@bingol.edu.tr \
    -e MAIL_ENABLED=false -e LEGAL_ENFORCE_REACCEPT=false -e STORAGE_DIR=/data/uploads -e INITIAL_FILL=false -e CRYPTO_MIGRATE_MESSAGES=false \
    -e CRYPTO_MASTER_KEYS="dev1:AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=" -e CRYPTO_ACTIVE_KEY_ID=dev1 \
    -e JAVA_TOOL_OPTIONS=-Xmx1g -e TZ=Europe/Istanbul eclipse-temurin:17-jre java -jar /app/app.jar >/dev/null
  until curl -sf "$APP_BASE_HOST/actuator/health" >/dev/null; do sleep 3; done
else
  : "${BASE:?uzak modda BASE gerekli}"; : "${PSQL_CMD:?uzak modda PSQL_CMD gerekli}"; : "${K6_CMD:?uzak modda K6_CMD gerekli}"
  export K6_BASE="$BASE" APP_BASE_HOST="$BASE" REDIS_CMD="${REDIS_CMD:-true}" CONTAINERS=""
fi

# --- veri ---
if [ "${SKIP_SEED:-0}" != "1" ] && { [ "$MODE" = "docker" ] || [ "${SEED:-0}" = "1" ]; }; then
  echo "== seed (20k kullanici) =="; $PSQL_CMD -v confirm=I_AM_DEV_ONLY -f - < "$ROOT/scripts/perf/seed-20k.sql" > "$OUT_DIR/seed1.log" 2>&1
  $PSQL_CMD -v confirm=I_AM_DEV_ONLY -f - < "$HERE/seed-load-extra.sql" > "$OUT_DIR/seed2.log" 2>&1
fi
node "$HERE/prep.js" || { echo "prep.js basarisiz"; exit 2; }
echo "SELECT pg_stat_statements_reset();" | $PSQL_CMD >/dev/null 2>&1

one() { bash "$HERE/run-one.sh" "$@" 2>&1 | grep -v '^time='; }

# JVM isinma (JIT): soguk JVM'de ilk dakikalar 10-20 kat yavastir (docs/PERFORMANCE.md); olcume katilmaz
echo "== JVM isinma ($WARM_MIN dk) =="
one warmup b-read.js -e VUS=150 -e DURATION=$((WARM_MIN * 60))s -e WARMUP_S=0 >/dev/null
rm -f "$OUT_DIR"/warmup.* 2>/dev/null

for s in $SCENARIOS; do
  case "$s" in
    G) one G-endpoints g-endpoints.js ;;
    A) one A-auth a-auth.js -e VUS=500
       one A-auth-with-load a-auth.js -e VUS=500 -e BG=1 -e BG_VUS=100 -e USER_OFFSET=8000 ;;
    B) one B-read-$VUS_B b-read.js -e VUS=$VUS_B -e DURATION=300s -e WARMUP_S=60
       for v in $CAPACITY; do one B-read-$v b-read.js -e VUS=$v -e DURATION=180s -e WARMUP_S=60; done
       [ "${STRESS:-1}" = "1" ] && one B-stress-400 b-read.js -e VUS=400 -e DURATION=180s -e WARMUP_S=60 -e THINK_MIN=0.05 -e THINK_MAX=0.25 ;;
    C) one C1-write c-write.js -e VUS=150 -e DURATION=300s -e WARMUP_S=60
       $PSQL_CMD -f - < "$HERE/reset-race.sql" >/dev/null 2>&1
       one C2-race c-race.js ;;
    D) one D-ws d-ws.js -e VUS=1000 -e HOLD_S=90 ;;
    E) one E-admin e-admin.js ;;
    F) OUT_DIR="$OUT_DIR" FX_HOST="$FX_HOST" bash "$HERE/f-chaos.sh" ;;
    H) # soguk baslangic: uygulama yeniden baslar baslamaz 150 VU (yalniz docker modu); JIT isinmasi etkisi
       if [ "$MODE" = "docker" ]; then docker restart $APP >/dev/null; until curl -sf "$APP_BASE_HOST/actuator/health" >/dev/null; do sleep 2; done
         one H-cold b-read.js -e VUS=150 -e DURATION=240s -e WARMUP_S=0; fi ;;
  esac
done

echo "== veri butunlugu ==" | tee "$OUT_DIR/integrity.txt"
$PSQL_CMD -f - < "$HERE/integrity.sql" 2>&1 | tee -a "$OUT_DIR/integrity.txt"
node "$HERE/summarize.js" "$OUT_DIR"

if [ "$MODE" = "docker" ] && [ "${KEEP:-0}" != "1" ]; then
  docker rm -f bu_ld_app bu_ld_pg bu_ld_redis >/dev/null 2>&1; docker network rm bu_ld_net >/dev/null 2>&1
  echo "yigin silindi (KEEP=1 ile korunur)"
fi
echo "sonuclar: $OUT_DIR/SUMMARY.md"
