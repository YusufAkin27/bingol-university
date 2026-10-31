#!/usr/bin/env bash
# CI kapisi (T-144 / A17-02): application*.properties'in okudugu her ortam degiskeni docker-compose.prod.yml'de backend'e
# ILETILIYOR olmali (aksi halde belgelerde ".env.prod'a yazin" denen ayar sessizce etkisiz kalir). Iki denetim:
#   1) STATIK: `${AD` ile okunan her degisken backend environment anahtari mi (iletilmeyecekler MUAF listesinde, gerekceli).
#   2) DINAMIK: ornek bir env-dosyasinda tanimlanan degerler `docker compose config` ciktisinda backend'e AYNEN gecer;
#      tanimsiz iletilen degisken bos dize olarak DEGIL, hic gecmez (null: uygulamanin kendi varsayilani gecerli kalir).
# Gerekli: docker compose >= 2.24, python3/python. Calistirma: bash scripts/ci/compose-env-check.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
PY=""; for c in python3 python; do "$c" -c "" >/dev/null 2>&1 && { PY="$c"; break; }; done; [ -n "$PY" ] || { echo "python gerekli" >&2; exit 2; }
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
LEGAL_ENFORCE_REACCEPT=true
FCM_CREDENTIALS_FILE=/run/secrets/fcm.json
DB_POOL_MAX=41
OBS_ALERT_EMAIL=ops@example.test
BLOCK_ANONYMIZERS=true
BAN_CACHE_TTL_SECONDS=7
APP_MAIL_ALLOW_LOG_ONLY=true
BACKUP_REMOTE=s3crypt:bu-yedek
ENV
JSON="$(docker compose -f docker-compose.prod.yml --env-file "$ENVF" config --format json)" \
  || { echo "FAIL: docker compose config gecersiz"; exit 1; }
printf '%s' "$JSON" | "$PY" -c '
import json, re, sys, glob
cfg = json.load(sys.stdin)
env = cfg["services"]["backend"].get("environment") or {}
# Muaf (gerekceli): compose bu degerleri sabitler ya da baska bir degisken adiyla iletir.
EXEMPT = {
    "DB_URL": "compose sabit: jdbc:postgresql://postgres:5432/bingol",
    "DB_USER": "compose sabit: bingol",
    "REDIS_HOST": "compose sabit: redis",
    "REDIS_PORT": "compose agi ici sabit 6379",
}
names = set()
for f in glob.glob("backend/src/main/resources/application*.properties"):
    for line in open(f, encoding="utf-8"):
        if line.lstrip().startswith("#"):
            continue
        names.update(re.findall(r"\$\{([A-Z][A-Z0-9_]+)", line))
missing = sorted(n for n in names if n not in env and n not in EXEMPT)
fail = 0
if missing:
    print("FAIL statik: backend environment\x27ina ILETILMEYEN degiskenler (docker-compose.prod.yml\x27e `AD:` satiri ekleyin):")
    for n in missing:
        print("   -", n)
    fail = 1
else:
    print("ok   statik: %d degisken backend\x27e iletiliyor (%d muaf)" % (len(names - set(EXEMPT)), len(EXEMPT)))
want = {"LEGAL_ENFORCE_REACCEPT": "true", "FCM_CREDENTIALS_FILE": "/run/secrets/fcm.json", "DB_POOL_MAX": "41",
        "OBS_ALERT_EMAIL": "ops@example.test", "BLOCK_ANONYMIZERS": "true", "BAN_CACHE_TTL_SECONDS": "7",
        "APP_MAIL_ALLOW_LOG_ONLY": "true", "BACKUP_REMOTE": "s3crypt:bu-yedek"}
bad = [k for k, v in want.items() if env.get(k) != v]
# tanimsiz iletilen degisken bos dize olmamali (Spring bos dizeyi varsayilanin ustune yazar)
unset = [k for k in ("DB_POOL_MIN_IDLE", "CHAT_ROOM_MAX_MEMBERS", "BAN_LOG_RETENTION_DAYS") if env.get(k) not in (None,)]
if bad or unset:
    print("FAIL dinamik: beklenen deger gecmedi:", bad, "| tanimsizken null olmasi gerekirken dolu:", unset)
    fail = 1
else:
    print("ok   dinamik: .env.prod degerleri backend\x27e geciyor; tanimsizlar iletilmiyor")
sys.exit(fail)
'
