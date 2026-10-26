#!/usr/bin/env bash
# Kulup ve etkinlik sohbetleri: GET /communities/{id}/chat ve GET /events/{id}/chat (getir-ya-da-olustur).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-chat-groups.sh
# Onkosul: compose'ta MAIL_ENABLED=false ve ADMIN_EMAILS=$ADMIN_EMAIL. Tekrar calistirilabilir (rastgele sonek).
# Betikler arasinda: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' bulunamadi)"; FAIL=1; fi; }
call() {
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" -d "$d")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c tok
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  tok=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$tok" ]; then
    tok=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$tok"
}

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "gsahip$SFX@bingol.edu.tr" "Sahip Kisi")
T2=$(register "guye$SFX@bingol.edu.tr" "Uye Kisi")
T3=$(register "gyabanci$SFX@bingol.edu.tr" "Yabanci Kisi")
TA=$(register "$ADMIN_EMAIL" "Sistem Yoneticisi")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] && [ -n "$TA" ] || { echo "kayit basarisiz"; exit 1; }

echo "== kulup sohbeti"
step "kulup olustur" 202 POST /communities "$T1" "{\"name\":\"Sohbet Kulubu $SFX\",\"description\":\"chat\",\"visibility\":\"PUBLIC\",\"joinPolicy\":\"OPEN\"}"
C=$(printf '%s' "$BODY" | idof)
step "onaysiz kulupte sohbet yok" 404 GET /communities/$C/chat "$T1"
step "admin onayla" 204 POST /admin/communities/$C/approve "$TA"
step "sahip sohbeti alir" 200 GET /communities/$C/chat "$T1"
contains "tur CLUB" '"type":"CLUB"' "$BODY"
contains "communityId dolu" "\"communityId\":$C" "$BODY"
CONV=$(printf '%s' "$BODY" | idof)
step "yabanci alamaz" 404 GET /communities/$C/chat "$T3"
step "uye katilir" 200 POST /communities/$C/join "$T2"
step "uye sohbeti alir" 200 GET /communities/$C/chat "$T2"
step "ikinci cagri ayni konusma" 200 GET /communities/$C/chat "$T2"
contains "ayni id" "\"id\":$CONV" "$BODY"
step "uye mesaj yazar" 201 POST /conversations/$CONV/messages "$T2" "{\"text\":\"selam kulup\",\"clientId\":\"g$SFX-1\"}"
step "listede CLUB gorunur" 200 GET /conversations "$T2"
contains "liste CLUB" '"type":"CLUB"' "$BODY"
step "gruptan ayrilma yok" 400 POST /conversations/$CONV/leave "$T2"
step "uye ayrilir" 204 DELETE /communities/$C/membership "$T2"
step "ayrilan alamaz" 404 GET /communities/$C/chat "$T2"
step "ayrilan yazamaz" 404 POST /conversations/$CONV/messages "$T2" "{\"text\":\"hala mi\",\"clientId\":\"g$SFX-2\"}"

echo "== etkinlik sohbeti"
NOW=$(date -u +%s)
S=$(date -u -d "@$((NOW + 172800))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r $((NOW + 172800)) +%Y-%m-%dT%H:%M:%SZ)
E=$(date -u -d "@$((NOW + 180000))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r $((NOW + 180000)) +%Y-%m-%dT%H:%M:%SZ)
step "etkinlik olustur (onay bekler)" 202 POST /events "$T1" "{\"title\":\"Sohbet Etkinligi $SFX\",\"description\":\"chat\",\"startsAt\":\"$S\",\"endsAt\":\"$E\",\"location\":\"Salon\"}"
EV=$(printf '%s' "$BODY" | idof)
step "admin onayla" 204 POST /admin/events/$EV/approve "$TA"
step "RSVP'siz yabanci 403" 403 GET /events/$EV/chat "$T3"
step "T3 ilgileniyor" 200 PUT /events/$EV/rsvp "$T3" '{"status":"INTERESTED"}'
step "RSVP'li sohbeti alir" 200 GET /events/$EV/chat "$T3"
contains "tur EVENT" '"type":"EVENT"' "$BODY"
contains "eventId dolu" "\"eventId\":$EV" "$BODY"
ECONV=$(printf '%s' "$BODY" | idof)
step "organizator sohbeti alir" 200 GET /events/$EV/chat "$T1"
step "mesaj yazar" 201 POST /conversations/$ECONV/messages "$T3" "{\"text\":\"selam etkinlik\",\"clientId\":\"e$SFX-1\"}"
step "RSVP iptal" 204 DELETE /events/$EV/rsvp "$T3"
step "iptalden sonra yazamaz" 404 POST /conversations/$ECONV/messages "$T3" "{\"text\":\"hala mi\",\"clientId\":\"e$SFX-2\"}"
step "iptalden sonra sohbet 403" 403 GET /events/$EV/chat "$T3"

[ "$FAIL" = 0 ] && echo "TUMU GECTI" || { echo "BAZI ADIMLAR BASARISIZ"; exit 1; }
