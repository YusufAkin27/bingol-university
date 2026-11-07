#!/usr/bin/env bash
# Biten/iptal etkinliklerin normal kullanicidan gizlenmesi duman testi (docs/changes/event.md "Biten ve iptal edilen etkinlikler").
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-events-expired.sh   (canli yigina KOSMAYIN; yerel/test yigini)
# Onkosul: MAIL_ENABLED=false ve ADMIN_EMAILS=$ADMIN_EMAIL. Gecmis tarihli etkinlik API'den acilamadigi icin biten etkinlik
# kurali birim/entegrasyon testlerinde (EventLivenessTest, EventCalendarTest) dogrulanir; burada iptal + gecmis-sinir kontrolu.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' yok)"; FAIL=1; fi; }
absent() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 ('$2' var)"; FAIL=1; else echo "  ok   $1"; fi; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Zk7-Qmv-Lpx92w\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Zk7-Qmv-Lpx92w\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}

SFX=$RANDOM
TA=$(register "$ADMIN_EMAIL" "Yonetici")
T1=$(register "bitis$SFX@bingol.edu.tr" "Bitis Bir")
[ -n "$TA" ] && [ -n "$T1" ] || { echo "kayit basarisiz"; exit 1; }

CRES=$(curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/communities -d "{\"name\":\"Bitis Kulubu $SFX\",\"description\":\"bitis\"}")
CID=$(printf '%s' "$CRES" | idof)
[ -n "$CID" ] || { echo "kulup olusmadi: $CRES"; exit 1; }
printf '%s' "$CRES" | grep -q '"status":"ACTIVE"' || curl -s -o /dev/null -X POST -H "Authorization: Bearer $TA" $A/admin/communities/$CID/approve

mk() { curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/events \
  -d "{\"title\":\"$1\",\"startsAt\":\"$(iso "+$2 days")\",\"endsAt\":\"$(iso "+$2 days 2 hours")\",\"location\":\"Salon\",\"communityId\":$CID}" | idof; }
E1=$(mk "Gizlenecek $SFX" 10)
E2=$(mk "Kalacak $SFX" 11)
[ -n "$E1" ] && [ -n "$E2" ] || { echo "etkinlik olusmadi"; exit 1; }

echo "== yaklasan etkinlikler listede"
L=$(curl -s -H "Authorization: Bearer $T1" "$A/events?communityId=$CID")
contains "E1 listede" "\"id\":$E1" "$L"
contains "E2 listede" "\"id\":$E2" "$L"

echo "== RSVP verip iptal"
check "rsvp" 200 "$(curl -s -o /dev/null -w '%{http_code}' -X PUT -H "$H" -H "Authorization: Bearer $T1" $A/events/$E1/rsvp -d '{"status":"GOING"}')"
check "iptal" 200 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/events/$E1/cancel -d '{"reason":"deneme"}')"

echo "== iptal edilen etkinlik normal listelerde yok"
L=$(curl -s -H "Authorization: Bearer $T1" "$A/events?communityId=$CID")
absent "liste: E1 yok" "\"id\":$E1," "$L"
contains "liste: E2 var" "\"id\":$E2" "$L"
CAL=$(curl -s -H "Authorization: Bearer $T1" "$A/events/calendar?month=$(date -u -d '+10 days' +%Y-%m)")
absent "takvim: E1 yok" "\"id\":$E1," "$CAL"
S=$(curl -s -H "Authorization: Bearer $T1" "$A/search?q=Gizlenecek&type=EVENT")
absent "arama: E1 yok" "\"id\":$E1," "$S"

echo "== gecmis sinir: from=2000 gecmis etkinlik dondurmez"
L=$(curl -s -H "Authorization: Bearer $T1" "$A/events?from=2000-01-01T00:00:00Z&size=50")
absent "gecmis: iptal edilen yok" "\"id\":$E1," "$L"

echo "== RSVP'li katilimci iptal durumunu ayrintida gorur (derin baglanti 404 vermez)"
D=$(curl -s -H "Authorization: Bearer $T1" $A/events/$E1)
contains "detay: CANCELLED" '"status":"CANCELLED"' "$D"

echo "== bildirim kutusu eventState"
N=$(curl -s -H "Authorization: Bearer $T1" "$A/notifications?size=30")
contains "bildirimde eventState" '"eventState":"CANCELLED"' "$N"

[ $FAIL -eq 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }
