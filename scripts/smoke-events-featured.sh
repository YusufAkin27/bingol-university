#!/usr/bin/env bash
# Etkinlik kapagi (PUT/DELETE /events/{id}/cover) ve one cikan etkinlik (GET /events/featured) duman testi.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-events-featured.sh
# Onkosul: MAIL_ENABLED=false ve ADMIN_EMAILS=$ADMIN_EMAIL (admin etkinligi dogrudan ACTIVE olur).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
PNG=$(mktemp --suffix=.png)
trap 'rm -f "$TMP" "$PNG"' EXIT
cp "$(dirname "$0")/fixtures/media/tiny.png" "$PNG"
PNGW=$(cygpath -m "$PNG" 2>/dev/null || echo "$PNG")

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' yok)"; FAIL=1; fi; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}

SFX=$RANDOM
TA=$(register "$ADMIN_EMAIL" "Yonetici")
T1=$(register "kapak$SFX@bingol.edu.tr" "Kapak Bir")
T2=$(register "kapak2$SFX@bingol.edu.tr" "Kapak Iki")
[ -n "$TA" ] && [ -n "$T1" ] && [ -n "$T2" ] || { echo "kayit basarisiz"; exit 1; }

# Etkinlik yalniz kulup adina acilir: yonetici once bir kulup kurar (auto-approve kapaliysa onaylar).
CRES=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/communities -d "{\"name\":\"Kapak Kulubu $SFX\",\"description\":\"kapak\"}")
CID=$(printf '%s' "$CRES" | idof)
[ -n "$CID" ] || { echo "kulup olusmadi: $CRES"; exit 1; }
printf '%s' "$CRES" | grep -q '"status":"ACTIVE"' || curl -s -o /dev/null -X POST -H "Authorization: Bearer $TA" $A/admin/communities/$CID/approve

mk() { # baslik gun -> id (kulup adina, yonetici olusturur, ACTIVE)
  curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/events \
    -d "{\"title\":\"$1\",\"startsAt\":\"$(iso "+$2 days")\",\"endsAt\":\"$(iso "+$2 days 2 hours")\",\"location\":\"Salon\",\"communityId\":$CID}" | idof
}
E1=$(mk "Kapak testi A $SFX" 20)
E2=$(mk "Kapak testi B $SFX" 21)

echo "== kapak"
check "yabanci kapak yukleyemez" 403 "$(curl -s -o /dev/null -w '%{http_code}' -X PUT -H "Authorization: Bearer $T1" -F "file=@$PNGW;type=image/png" $A/events/$E1/cover)"
CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X PUT -H "Authorization: Bearer $TA" -F "file=@$PNGW;type=image/png" $A/events/$E1/cover)
check "PUT kapak" 200 "$CODE"
contains "coverUrl dolu" '"coverUrl":"/files/covers/' "$(cat "$TMP")"
check "detayda coverUrl" 0 "$(curl -s -H "Authorization: Bearer $T1" $A/events/$E1 | grep -c '"coverUrl":null')"
CAL=$(curl -s -H "Authorization: Bearer $T1" "$A/events/calendar?month=$(date -u -d '+20 days' +%Y-%m)")
contains "takvimde imageUrl" '/files/covers/' "$CAL"
check "DELETE kapak" 204 "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -H "Authorization: Bearer $TA" $A/events/$E1/cover)"
contains "kapak kalkti" '"coverUrl":null' "$(curl -s -H "Authorization: Bearer $T1" $A/events/$E1)"

echo "== one cikan"
curl -s -o /dev/null -X PUT -H "$H" -H "Authorization: Bearer $T1" $A/events/$E2/rsvp -d '{"status":"GOING"}'
curl -s -o /dev/null -X PUT -H "$H" -H "Authorization: Bearer $T2" $A/events/$E2/rsvp -d '{"status":"GOING"}'
CODE=$(curl -s -o "$TMP" -w '%{http_code}' -H "Authorization: Bearer $T1" $A/events/featured)
check "featured 200" 200 "$CODE"
F=$(cat "$TMP")
contains "featured en cok katilimcili (>=2)" '"goingCount":' "$F"
contains "myRsvp alani var" '"myRsvp":' "$F"
ET=$(curl -s -D - -o /dev/null -H "Authorization: Bearer $T1" $A/events/featured | grep -i '^etag' | cut -d' ' -f2 | tr -d '\r')
if [ -n "$ET" ]; then
  check "ETag ile 304" 304 "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $T1" -H "If-None-Match: $ET" $A/events/featured)"
fi
check "kimliksiz 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' $A/events/featured)"

[ $FAIL -eq 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }
