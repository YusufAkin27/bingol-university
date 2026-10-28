#!/usr/bin/env bash
# CI kapisi (M33): GERCEK PostgreSQL + Redis'e karsi "migration zinciri + ddl-auto=validate".
# H2 testleri Flyway'i kapatir (create-drop); bu yuzden migration hatasi, entity-sema kaymasi ve PostgreSQL'e ozel SQL
# (UPDATE..RETURNING, SKIP LOCKED, tsvector) CI'da gorunmezdi. Bu betik uygulamayi Flyway ACIK ve Hibernate `validate` ile
# bos bir PostgreSQL'e karsi baslatir; /actuator/health UP gelmezse (migration/validate hatasi dahil) basarisiz olur.
#
# Kullanim (repo kokunden):   bash scripts/ci/flyway-validate.sh
# Ortam (varsayilanlar CI services ile uyumlu):
#   DB_URL (jdbc:postgresql://localhost:5432/bingol)  DB_USER (bingol)  DB_PASSWORD (bingol)  REDIS_HOST (localhost)
#   PORT (18080)  JAR (bos: backend'i `mvn package -DskipTests` ile derler)  WAIT_SECONDS (240)
#   SMOKE=1  -> dogrulamadan sonra scripts/smoke.sh ve smoke-support.sh'i ayni uygulamaya karsi calistirir (docker kabugu ile
#               `docker compose logs backend` / `redis-cli flushall` taklit edilir). Duman hatalari SMOKE_STRICT=1 degilse
#               yalniz uyari verir (bilgilendirme; kapi Flyway/validate'tir).
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
ROOT="$(pwd)"

PORT="${PORT:-18080}"
DB_URL="${DB_URL:-jdbc:postgresql://localhost:5432/bingol}"
DB_USER="${DB_USER:-bingol}"
DB_PASSWORD="${DB_PASSWORD:-bingol}"
REDIS_HOST="${REDIS_HOST:-localhost}"
WAIT_SECONDS="${WAIT_SECONDS:-240}"
WORK="$(mktemp -d)"
LOG="$WORK/backend.log"
APP_PID=""

stop_app() {
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    for _ in $(seq 1 20); do kill -0 "$APP_PID" 2>/dev/null || break; sleep 1; done
    kill -9 "$APP_PID" 2>/dev/null || true
  fi
}
cleanup() { stop_app; }
trap cleanup EXIT

tail_log() { echo "---- backend.log (son 120 satir) ----"; tail -n 120 "$LOG" 2>/dev/null || true; echo "----"; }

JAR="${JAR:-}"
if [ -z "$JAR" ]; then
  echo "::group::backend derleniyor (testsiz)"
  (cd backend && mvn -B -q -DskipTests package)
  echo "::endgroup::"
  JAR="$(ls backend/target/*.jar | grep -v '\.original$' | head -n 1)"
fi
[ -f "$JAR" ] || { echo "jar bulunamadi: $JAR" >&2; exit 1; }

# Taze veritabani sart: onceki kalinti migration zincirini maskelerdi
echo "uygulama baslatiliyor: Flyway ACIK, ddl-auto=validate, INITIAL_FILL=false (kaynak siteye istek atilmaz)"
env \
  DB_URL="$DB_URL" DB_USER="$DB_USER" DB_PASSWORD="$DB_PASSWORD" REDIS_HOST="$REDIS_HOST" \
  SERVER_PORT="$PORT" \
  SPRING_FLYWAY_ENABLED=true SPRING_JPA_HIBERNATE_DDL_AUTO=validate \
  INITIAL_FILL=false MAIL_ENABLED=false \
  ADMIN_EMAILS="${ADMIN_EMAIL:-boss@bingol.edu.tr}" \
  STORAGE_DIR="$WORK/uploads" \
  JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xmx768m}" \
  nohup java -jar "$JAR" > "$LOG" 2>&1 &
APP_PID=$!

echo "saglik bekleniyor (en cok ${WAIT_SECONDS} sn): http://localhost:$PORT/actuator/health"
ok=0
for ((i = 0; i < WAIT_SECONDS; i += 2)); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "::error::uygulama kapandi (migration/validate hatasi olabilir)"; tail_log; exit 1
  fi
  if curl -fsS -m 3 "http://localhost:$PORT/actuator/health" 2>/dev/null | grep -q '"UP"'; then ok=1; break; fi
  sleep 2
done
if [ "$ok" != 1 ]; then echo "::error::/actuator/health UP olmadi"; tail_log; exit 1; fi
echo "UYGULAMA AYAKTA: migration zinciri uygulandi ve ddl-auto=validate gecti"

# Flyway kayitlari: basarisiz migration olmamali
PSQL_CONN=""
if command -v psql >/dev/null 2>&1; then
  HOSTPORT="${DB_URL#jdbc:postgresql://}"; HOSTPORT="${HOSTPORT%%/*}"; DBNAME="${DB_URL##*/}"; DBNAME="${DBNAME%%\?*}"
  PH="${HOSTPORT%%:*}"; PP="${HOSTPORT##*:}"; [ "$PP" != "$HOSTPORT" ] || PP=5432
  q() { PGPASSWORD="$DB_PASSWORD" psql -h "$PH" -p "$PP" -U "$DB_USER" -d "$DBNAME" -Atqc "$1"; }
  FAILED_N="$(q "select count(*) from flyway_schema_history where not success")"
  APPLIED_N="$(q "select count(*) from flyway_schema_history where version is not null and success")"
  FILES_N="$(ls backend/src/main/resources/db/migration/V*.sql | wc -l | tr -d ' ')"
  echo "Flyway: uygulanan $APPLIED_N, basarisiz $FAILED_N, dosya $FILES_N"
  [ "$FAILED_N" = 0 ] || { echo "::error::basarisiz migration kaydi var"; exit 1; }
  [ "$APPLIED_N" -ge "$FILES_N" ] || { echo "::error::uygulanan migration sayisi ($APPLIED_N) dosya sayisindan ($FILES_N) az"; exit 1; }
else
  echo "::warning::psql yok: flyway_schema_history ayrintisi atlandi (saglik + validate yine gecti)"
fi

# --- istege bagli: duman betikleri (docker kabugu ile compose bagimliliklari taklit edilir) ---
SMOKE_RC=0
if [ "${SMOKE:-0}" = 1 ]; then
  SHIM="$WORK/shim"; mkdir -p "$SHIM"
  cat > "$SHIM/docker" <<SHIMEOF
#!/usr/bin/env bash
# Yalniz duman betiklerinin kullandigi iki komutu taklit eder.
[ "\${1:-}" = compose ] || { echo "docker-shim: desteklenmiyor: \$*" >&2; exit 1; }
shift
case "\$*" in
  "logs backend"*) cat "$LOG";;
  "exec -T redis redis-cli flushall")
    exec 3<>/dev/tcp/$REDIS_HOST/6379; printf '*1\r\n\$8\r\nFLUSHALL\r\n' >&3; head -n1 <&3 >/dev/null; exec 3>&-;;
  *) echo "docker-shim: desteklenmiyor: compose \$*" >&2; exit 1;;
esac
SHIMEOF
  chmod +x "$SHIM/docker"
  for s in smoke.sh smoke-support.sh; do
    echo "::group::duman: scripts/$s"
    # Kayit ucu IP basina saatte 10 ile sinirli: betikler arasi Redis temizlenir
    PATH="$SHIM:$PATH" docker compose exec -T redis redis-cli flushall || true
    if ! PATH="$SHIM:$PATH" BASE="http://localhost:$PORT" ADMIN_EMAIL="${ADMIN_EMAIL:-boss@bingol.edu.tr}" bash "scripts/$s"; then
      SMOKE_RC=1
      echo "::warning::scripts/$s hata verdi (bilgilendirme; SMOKE_STRICT=1 ise kapi basarisiz olur)"
    fi
    echo "::endgroup::"
  done
fi

if [ "$SMOKE_RC" != 0 ] && [ "${SMOKE_STRICT:-0}" = 1 ]; then tail_log; exit 1; fi
echo "TAMAM: PostgreSQL migration zinciri + validate$([ "${SMOKE:-0}" = 1 ] && echo ' + duman betikleri') gecti"
