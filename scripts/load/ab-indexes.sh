#!/usr/bin/env bash
# V59 indekslerinin A/B olcumu: AYNI isinmis JVM uzerinde indeksler ACIK -> KAPALI -> ACIK sirasiyla yuk calistirilir.
# (Paylasimli makinede ayri yigin yeniden baslatmalari arasindaki gurultuyu ortadan kaldirir.)
# Kullanim: COMPOSE_PROJECT_NAME=wt_t6 BASE=http://localhost:8106 ./scripts/load/ab-indexes.sh
# Ortam: PUB_SCEN="news_list,conversations,messages"  ADMIN="admin_users,admin_users_q,admin_overview,admin_engagement"
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
MIG="$DIR/../../backend/src/main/resources/db/migration/V59__perf_indexes.sql"
PUB_SCEN=${PUB_SCEN:-news_list,conversations,messages}
ADMIN=${ADMIN:-admin_users,admin_users_q,admin_overview,admin_engagement}
psqlc() { docker compose exec -T postgres psql -U bingol -d bingol -v ON_ERROR_STOP=1 "$@"; }
drop() {
  psqlc -Atc "SELECT 'DROP INDEX IF EXISTS ' || indexname || ';' FROM pg_indexes WHERE indexname LIKE 'idx_perf_%'" | psqlc >/dev/null
  psqlc -c "VACUUM ANALYZE" >/dev/null
}
create() { drop; psqlc < "$MIG" >/dev/null; psqlc -c "VACUUM ANALYZE" >/dev/null; }
pass() {
  echo "## $1"
  LABEL="ab-$1-public" WARMUP=8 DURATION=15 CONC=32 FLUSH_RL=1 node "$DIR/load.js" "$PUB_SCEN" | tail -n +3
  LABEL="ab-$1-admin" WARMUP=5 DURATION=10 CONC=8 node "$DIR/load.js" "$ADMIN" | tail -n +3
}
create; pass indexler-acik-1
drop;   pass indexler-kapali
create; pass indexler-acik-2
