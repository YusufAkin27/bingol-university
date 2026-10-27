#!/usr/bin/env bash
# docs/openapi.json'u otomatik uretir.
#   scripts/openapi-export.sh           -> calisan backend varsa canli (openapi-gen.js), yoksa Docker Maven + OpenApiExportTest
#   scripts/openapi-export.sh --check   -> uretir ve commit'teki docs/openapi.json ile yol/islem kumesini karsilastirir (CI; surum kaymasinda 1)
# Ortam: BASE (varsayilan http://localhost:8080), ADMIN_PASSWORD (canli mod), MODE=live|test (secimi zorla)
set -euo pipefail
cd "$(dirname "$0")/.."
BASE="${BASE:-http://localhost:8080}"
MODE="${MODE:-auto}"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

if [ "$MODE" = "auto" ]; then
  if curl -fsS -m 5 "$BASE/actuator/health" >/dev/null 2>&1; then MODE=live; else MODE=test; fi
fi

if [ "$MODE" = "live" ]; then
  if [ "$CHECK" = 1 ]; then
    OUT="$(mktemp)" BASE="$BASE" node scripts/openapi-gen.js
    echo "openapi-export: canli moddan uretildi; karsilastirma icin: DRIFT=1 node scripts/openapi-check.js"
  else
    BASE="$BASE" node scripts/openapi-gen.js
  fi
  exit 0
fi

# Test modu: Docker Maven konteynerinde OpenApiExportTest (sunucu gerekmez)
timeout 20 docker info >/dev/null 2>&1 || { echo "openapi-export: Docker yanitsiz ve canli backend yok" >&2; exit 2; }
if [ "$CHECK" = 1 ]; then
  PROP="-Dopenapi.check=/docs/openapi.json"
else
  PROP="-Dopenapi.out=/docs/openapi.json"
fi
MODE_MOUNT=rw; [ "$CHECK" = 1 ] && MODE_MOUNT=ro
MSYS_NO_PATHCONV=1 docker run --rm -v bu-m2:/root/.m2 \
  -v "$(pwd -W 2>/dev/null || pwd)/backend:/src:ro" \
  -v "$(pwd -W 2>/dev/null || pwd)/docs:/docs:$MODE_MOUNT" \
  maven:3-eclipse-temurin-17 sh -c \
  "mkdir /work && tar -C /src --exclude=target -cf - . | tar -C /work -xf - && cd /work && mvn -B -q -Djacoco.skip=true -Dtest=OpenApiExportTest $PROP test"
echo "openapi-export: tamam"
