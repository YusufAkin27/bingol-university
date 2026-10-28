#!/usr/bin/env bash
# Gelistirme: kullanici olusturur ve e-postasini dogrular (kod docker compose log'undan okunur).
# Kullanim: BASE=http://localhost:8080 ./scripts/make-user.sh ad@bingol.edu.tr "Gorunen Ad" [Sifre1234]
# Yonetici yapmak icin e-posta backend'in ADMIN_EMAILS listesinde olmali.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
EMAIL=${1:?e-posta gerekli}
NAME=${2:-Kullanici}
PASS=${3:-Sifre1234}
H='Content-Type: application/json'

curl -s -o /dev/null -X POST -H "$H" $A/auth/register \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"displayName\":\"$NAME\",\"acceptTerms\":true}"
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
TOKEN=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"password\":\"$PASS\"}" |
  grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
if [ -z "$TOKEN" ]; then
  TOKEN=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
fi
[ -n "$TOKEN" ] && echo "tamam: $EMAIL" || { echo "basarisiz: $EMAIL"; exit 1; }
