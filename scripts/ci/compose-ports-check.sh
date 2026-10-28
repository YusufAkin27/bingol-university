#!/usr/bin/env bash
# CI kapisi (H3/M24): docker-compose.prod.yml (tek basina, staging ve izleme bindirmeleriyle) gecerli olmali ve internete
# YALNIZ Caddy'nin 80/443 portu yayinlanmali (izleme portlari yalniz 127.0.0.1). Kok docker-compose.yml ile yanlislikla
# birlestirilse bile `ports: !reset []` 8080/8090'i sifirlamali. Gerekli: docker compose >= 2.24.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
ENVF="$(mktemp)"; trap 'rm -f "$ENVF"' EXIT
cat > "$ENVF" <<ENV
DOMAIN=example.test
ACME_EMAIL=ops@example.test
DB_PASSWORD=x
JWT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ADMIN_PASSWORD=x
CORS_ORIGINS=https://example.test
PUBLIC_WEB_URL=https://example.test
CRYPTO_MASTER_KEYS=k1:AAAA
CRYPTO_ACTIVE_KEY_ID=k1
BACKUP_AGE_RECIPIENT=age1x
GRAFANA_ADMIN_PASSWORD=x
ENV
PY=""; for c in python3 python; do "$c" -c "" >/dev/null 2>&1 && { PY="$c"; break; }; done; [ -n "$PY" ] || { echo "python gerekli" >&2; exit 2; }; fail=0
check() { # ad dosya-argumanlari...
  local name="$1"; shift
  local out
  out="$(docker compose "$@" --env-file "$ENVF" config --format json)" || { echo "FAIL $name: config gecersiz"; fail=1; return; }
  # host portlari: "ip:port" ; 0.0.0.0/bos ip yalniz 80/443 olabilir
  local bad
  bad="$(printf '%s' "$out" | "$PY" -c '
import json,sys
d=json.load(sys.stdin); bad=[]
for n,s in d.get("services",{}).items():
    for p in s.get("ports",[]) or []:
        ip=p.get("host_ip") or "0.0.0.0"; pub=str(p.get("published",""))
        if ip in ("127.0.0.1","::1"): continue
        if n=="caddy" and pub in ("80","443"): continue
        bad.append("%s:%s:%s"%(n,ip,pub))
print(" ".join(bad))')"
  if [ -n "$bad" ]; then echo "FAIL $name: disariya acik port(lar): $bad"; fail=1; else echo "ok   $name"; fi
}
check "prod (tek basina)"            -f docker-compose.prod.yml
check "prod + staging"               -f docker-compose.prod.yml -f docker-compose.staging.yml
check "prod + izleme"                -f docker-compose.prod.yml -f monitoring/docker-compose.monitoring.yml
check "prod + staging + izleme"      -f docker-compose.prod.yml -f docker-compose.staging.yml -f monitoring/docker-compose.monitoring.yml
check "YANLIS birlestirme (kok+prod)" -f docker-compose.yml -f docker-compose.prod.yml
exit $fail
