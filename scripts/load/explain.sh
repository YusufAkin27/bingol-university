#!/usr/bin/env bash
# explain-queries.sql'i calistirir ve sorgu basina ozet verir: calisma suresi, tarama turleri, tampon sayisi.
# Kullanim: COMPOSE_PROJECT_NAME=wt_t6 ./scripts/load/explain.sh [tam|ozet]   (varsayilan: ozet)
#   Cikti her sorgu icin 3 kez calistirilir (2 isinma turu, sonuncusu raporlanir).
set -eu
DIR=$(cd "$(dirname "$0")" && pwd)
MODE=${1:-ozet}
run() { docker compose exec -T postgres psql -U bingol -d bingol -v ON_ERROR_STOP=1 < "$DIR/explain-queries.sql"; }
if [ "$MODE" = "tam" ]; then run; exit 0; fi
run >/dev/null; run >/dev/null   # isinma
run | awk '
  /^@@ /      { if (name != "") out(); name = $2; t = ""; scans = ""; buf = ""; next }
  /Execution Time:/ { t = $3 }
  /Seq Scan on|Index Scan|Index Only Scan|Bitmap Index Scan|Bitmap Heap Scan/ {
      s = $0; gsub(/^ *(->)? */, "", s); sub(/ \(cost.*/, "", s); scans = scans (scans == "" ? "" : "; ") s }
  /^ *Buffers: shared/ && buf == "" { buf = $0; gsub(/^ *Buffers: /, "", buf) }
  function out() { printf "%-28s %9s ms | %s\n    %s\n", name, t, buf, scans }
  END { out() }'
