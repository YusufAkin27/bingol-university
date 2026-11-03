#!/usr/bin/env bash
# T-003 dogrulamasi: Redis kesilince devre kesici (kimlikli uclar hizli 503 + Retry-After, herkese acik uclar 200).
# UYARI: `docker compose stop redis` calistirir -> YALNIZ yalitilmis test yiginida kullanin (paylasimli yigina degil).
# Kullanim: BASE=http://localhost:18110 COMPOSE_PROJECT_NAME=bu_w1a ./scripts/redis-breaker-check.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur). smoke-all.sh'a DAHIL DEGILDIR (adi smoke-* degil, bilerek).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
PW='Zk7-Qmv-Lpx92w'
CONC=${CONC:-250}
FAIL=0
check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }

EMAIL="breaker$RANDOM$RANDOM@bingol.edu.tr"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"displayName\":\"Devre Kesici\",\"acceptTerms\":true}"
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
TOKEN=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"password\":\"$PW\"}" |
  grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
[ -n "$TOKEN" ] || { echo "kayit/dogrulama basarisiz"; exit 1; }
AUTH="Authorization: Bearer $TOKEN"
check "Redis acikken /auth/me" 200 "$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" $A/auth/me)"

echo "== Redis durduruluyor"
docker compose stop redis >/dev/null 2>&1
trap 'docker compose start redis >/dev/null 2>&1' EXIT

# ilk istek devreyi acar (en cok komut zaman asimi kadar bekler)
T0=$(date +%s%N)
FIRST=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" $A/auth/me)
T1=$(date +%s%N)
check "ilk kimlikli istek 503" 503 "$FIRST"
echo "  ilk istek suresi: $(( (T1 - T0) / 1000000 )) ms"

HDRS=$(curl -s -D - -o /dev/null -H "$AUTH" $A/auth/me)
case "$HDRS" in *[Rr]etry-[Aa]fter:*) check "Retry-After basligi var" 1 1;; *) check "Retry-After basligi var" 1 0;; esac
BODY=$(curl -s -H "$AUTH" $A/auth/me)
case "$BODY" in *'"code":"REDIS_UNAVAILABLE"'*) check "govde code REDIS_UNAVAILABLE" 1 1;; *) check "govde code ($BODY)" 1 0;; esac

echo "== $CONC eszamanli kimlikli istek (devre acik)"
OUT=$(mktemp)
T0=$(date +%s%N)
seq 1 "$CONC" | xargs -P 50 -I{} curl -s -o /dev/null -w '%{http_code} %{time_total}\n' -H "$AUTH" $A/auth/me > "$OUT"
T1=$(date +%s%N)
TOTAL_MS=$(( (T1 - T0) / 1000000 ))
N503=$(grep -c '^503 ' "$OUT")
MAXT=$(awk '{ if ($2 > m) m = $2 } END { printf "%.3f", m }' "$OUT")
echo "  toplam $TOTAL_MS ms, en yavas istek ${MAXT}s"
check "tum istekler 503" "$CONC" "$N503"
awk -v m="$MAXT" 'BEGIN { exit !(m < 1.0) }' && echo "  ok   en yavas istek < 1 sn" || { echo "  FAIL en yavas istek >= 1 sn ($MAXT)"; FAIL=1; }
rm -f "$OUT"

echo "== herkese acik uclar Redis'siz calisir"
check "GET /api/news (token yok)" 200 "$(curl -s -o /dev/null -w '%{http_code}' $A/news)"
check "GET /api/news (token ile)" 200 "$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" $A/news)"
check "GET /api/status" 200 "$(curl -s -o /dev/null -w '%{http_code}' $A/status)"
check "POST /auth/login Redis'siz 503 (fail-closed)" 503 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")"

echo "== Redis geri aciliyor"
docker compose start redis >/dev/null 2>&1
trap - EXIT
for i in $(seq 1 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" $A/auth/me)" = "200" ] && break
  sleep 1
done
check "Redis donunca kimlikli istek 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" $A/auth/me)"

echo
[ "$FAIL" = 0 ] && echo "REDIS DEVRE KESICI: TAMAM" || { echo "REDIS DEVRE KESICI: HATA VAR"; exit 1; }
