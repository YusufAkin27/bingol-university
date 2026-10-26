#!/usr/bin/env bash
# Etkinlik ekstralari (T14) uctan uca: ortak organizator, toplu duyuru (+gunluk sinir), ICS, haftalik seri,
# anket, katilim sertifikasi (+herkese acik dogrulama).
# Kullanim: BASE=http://localhost:8114 COMPOSE_PROJECT_NAME=wt_t14 ./scripts/event-extras-e2e.sh
# Onkosul: compose'ta MAIL_ENABLED=false; betik calisan postgres konteynerine psql ile yazar (etkinligi gecmise
# cekmek ve yoklama eklemek icin). Tekrar calistirilabilir (rastgele kullanicilar).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' yok)"; FAIL=1; fi; }
call() { # METHOD YOL TOKEN [JSON]
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
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }
sql() { docker compose exec -T postgres psql -U bingol -d bingol -tA -c "$1" >/dev/null; }

register() { # email ad
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
TO=$(register "xorg$SFX@bingol.edu.tr" "Organizator")
TC=$(register "xco$SFX@bingol.edu.tr" "Ortak Org")
TP=$(register "xpa$SFX@bingol.edu.tr" "Katilimci")
TS=$(register "xst$SFX@bingol.edu.tr" "Yabanci")
[ -n "$TO" ] && [ -n "$TS" ] || { echo "kullanici hazirlanamadi"; exit 1; }
UC=$(curl -s -H "Authorization: Bearer $TC" $A/auth/me | idof)
UP=$(curl -s -H "Authorization: Bearer $TP" $A/auth/me | idof)
US=$(curl -s -H "Authorization: Bearer $TS" $A/auth/me | idof)
UO=$(curl -s -H "Authorization: Bearer $TO" $A/auth/me | idof)

echo "== etkinlik"
call POST /events "$TO" "{\"title\":\"Extras; Test, $SFX\",\"description\":\"Satir1\\nSatir2\",\"startsAt\":\"$(iso '+2 days')\",\"endsAt\":\"$(iso '+2 days 2 hours')\",\"location\":\"Salon A, Kat 2\",\"capacity\":50}"
EV=$(printf '%s' "$BODY" | idof)
[ -n "$EV" ] || { echo "etkinlik olusturulamadi: $BODY"; exit 1; }
step "katilimci GOING" 200 PUT /events/$EV/rsvp "$TP" '{"status":"GOING"}'

echo "== ortak organizator"
step "yabanci ortak ekleyemez (403/404)" 403 POST /events/$EV/co-organizers "$TS" "{\"userId\":$US}" || true
step "organizator ortak ekler" 201 POST /events/$EV/co-organizers "$TO" "{\"userId\":$UC}"
step "ayni kisiyi tekrar" 409 POST /events/$EV/co-organizers "$TO" "{\"userId\":$UC}"
step "olusturanı ortak ekleme" 400 POST /events/$EV/co-organizers "$TO" "{\"userId\":$UO}"
step "ortak organizator katilimci listesini gorur" 200 GET /events/$EV/attendees "$TC"
step "ortak organizator baska ortak EKLEYEMEZ (yukseltme korumasi)" 403 POST /events/$EV/co-organizers "$TC" "{\"userId\":$US}"
step "ortak organizator baskasini cikaramaz" 403 DELETE /events/$EV/co-organizers/$UO "$TC"
step "yabanci ortak listesini goremez" 403 GET /events/$EV/co-organizers "$TS"
step "ortak listesi" 200 GET /events/$EV/co-organizers "$TO"
contains "listede ortak var" "Ortak Org" "$BODY"
# En fazla 5: 4 ek kullanici daha + altinci reddedilir
EXTRA_IDS=""
for i in 1 2 3 4; do
  T=$(register "xe$i$SFX@bingol.edu.tr" "Ek $i")
  U=$(curl -s -H "Authorization: Bearer $T" $A/auth/me | idof)
  step "ek ortak $i" 201 POST /events/$EV/co-organizers "$TO" "{\"userId\":$U}"
done
step "altinci ortak reddedilir" 409 POST /events/$EV/co-organizers "$TO" "{\"userId\":$US}"
contains "hata kodu" "CO_ORGANIZER_LIMIT" "$BODY"

echo "== toplu duyuru"
step "ortak organizator duyuru gonderir" 200 POST /events/$EV/announcements "$TC" '{"title":"Salon degisti","message":"Yeni salon B blok"}'
contains "alici sayisi 1" '"recipients":1' "$BODY"
call GET /notifications "$TP"
contains "katilimci bildirimi aldi" "Salon degisti" "$BODY"
step "katilimci duyuru gonderemez" 403 POST /events/$EV/announcements "$TP" '{"title":"x","message":"y"}'
step "ikinci duyuru" 200 POST /events/$EV/announcements "$TO" '{"title":"2","message":"b"}'
step "ucuncu duyuru" 200 POST /events/$EV/announcements "$TO" '{"title":"3","message":"c"}'
step "dorduncu duyuru gunluk sinir" 429 POST /events/$EV/announcements "$TO" '{"title":"4","message":"d"}'
contains "hata kodu" "ANNOUNCEMENT_LIMIT" "$BODY"

echo "== ICS"
ICS=$(curl -s -D "$TMP" -H "Authorization: Bearer $TP" $A/events/$EV/ics)
contains "content-type" "text/calendar" "$(cat $TMP)"
contains "VCALENDAR" "BEGIN:VCALENDAR" "$ICS"
contains "UID" "UID:event-$EV@bingol.edu.tr" "$ICS"
contains "TZID" "DTSTART;TZID=Europe/Istanbul" "$ICS"
contains "virgul kacisi" 'LOCATION:Salon A\\, Kat 2' "$ICS"
contains "noktali virgul kacisi" 'SUMMARY:Extras\\; Test\\,' "$ICS"
contains "satir sonu CRLF" "$(printf '\r')" "$ICS"
MY=$(curl -s -H "Authorization: Bearer $TP" $A/me/events.ics)
contains "benim takvimim etkinligi icerir" "event-$EV@bingol.edu.tr" "$MY"
step "olmayan etkinlik ICS 404" 404 GET /events/99999999/ics "$TP"

echo "== haftalik seri"
step "seri 12 tekrar reddedilir" 400 POST /events/$EV/series "$TO" '{"count":12}'
step "seri 3 tekrar" 201 POST /events/$EV/series "$TO" '{"count":3}'
call GET /events/$EV/series "$TP"
SERIES_N=$(printf '%s' "$BODY" | grep -o '"eventId"' | wc -l)
check "seri 4 etkinlik" 4 "$SERIES_N"
step "ikinci seri 409" 409 POST /events/$EV/series "$TO" '{"count":2}'
LAST=$(printf '%s' "$BODY" | grep -o '"eventId":[0-9]*' | tail -1 | cut -d: -f2)
step "tek tekrar iptali (son)" 204 DELETE /events/$LAST "$TO"
step "seri iptali (bu ve sonrasi)" 200 DELETE /events/$EV/series "$TO"
contains "iptal sayisi" '"cancelled"' "$BODY"

echo "== anket + sertifika (etkinligi gecmise cekip yoklama ekler)"
call POST /events "$TO" "{\"title\":\"Gecmis Test $SFX\",\"startsAt\":\"$(iso '+1 hour')\",\"endsAt\":\"$(iso '+2 hours')\",\"location\":\"X\"}"
EV2=$(printf '%s' "$BODY" | idof)
step "rsvp" 200 PUT /events/$EV2/rsvp "$TP" '{"status":"GOING"}'
step "etkinlik bitmeden anket 409" 409 POST /events/$EV2/feedback "$TP" '{"rating":5}'
contains "hata kodu" "FEEDBACK_NOT_OPEN" "$BODY"
sql "UPDATE user_event SET starts_at = now() - interval '3 hours', ends_at = now() - interval '1 hour' WHERE id = $EV2"
step "yoklamasiz anket 403" 403 POST /events/$EV2/feedback "$TP" '{"rating":5}'
step "yoklamasiz sertifika 403" 403 GET /events/$EV2/certificate "$TP"
sql "INSERT INTO event_attendance (event_id, user_id, present, method, marked_by) VALUES ($EV2, $UP, true, 'MANUAL', $UO)"
step "puan 6 reddedilir" 400 POST /events/$EV2/feedback "$TP" '{"rating":6}'
step "anket" 201 POST /events/$EV2/feedback "$TP" '{"rating":4,"comment":"guzeldi"}'
step "ikinci anket" 409 POST /events/$EV2/feedback "$TP" '{"rating":5}'
step "benim anketim" 200 GET /events/$EV2/feedback/mine "$TP"
step "ozet (organizator)" 200 GET /events/$EV2/feedback/summary "$TO"
contains "ortalama 4" '"average":4' "$BODY"
step "ozet katilimciya kapali" 403 GET /events/$EV2/feedback/summary "$TP"
step "liste (organizator)" 200 GET /events/$EV2/feedback "$TO"
contains "yorum" "guzeldi" "$BODY"
call GET /events/$EV2/feedback "$TO"
if printf '%s' "$BODY" | grep -q '"userId"'; then echo "  FAIL liste anonim degil"; FAIL=1; else echo "  ok   liste anonim"; fi

step "sertifika" 200 GET /events/$EV2/certificate "$TP"
CODEV=$(printf '%s' "$BODY" | field code)
check "kod uzunlugu" 20 "${#CODEV}"
step "sertifika idempotent" 200 GET /events/$EV2/certificate "$TP"
check "ayni kod" "$CODEV" "$(printf '%s' "$BODY" | field code)"
PUB=$(curl -s -o "$TMP" -w '%{http_code}' $A/certificates/verify/$CODEV)
check "herkese acik dogrulama (token yok)" 200 "$PUB"
contains "gecerli" '"valid":true' "$(cat $TMP)"
PUB=$(curl -s -o "$TMP" -w '%{http_code}' $A/certificates/verify/AAAAAAAAAAAAAAAAAAAA)
check "bilinmeyen kod 404" 404 "$PUB"
PUB=$(curl -s -o "$TMP" -w '%{http_code}' $A/certificates/verify/kisa)
check "bicimsiz kod 404" 404 "$PUB"
sql "UPDATE event_attendance SET present = false WHERE event_id = $EV2 AND user_id = $UP"
curl -s $A/certificates/verify/$CODEV > "$TMP"
contains "yoklama geri alininca gecersiz" '"valid":false' "$(cat $TMP)"

echo "== verify hiz siniri (IP basina 20/dk)"
LIM=0
for i in $(seq 1 30); do
  c=$(curl -s -o /dev/null -w '%{http_code}' $A/certificates/verify/BBBBBBBBBBBBBBBBBBBB)
  [ "$c" = "429" ] && LIM=1
done
check "429 goruldu" 1 "$LIM"

echo "== KVKK disa aktarim"
call GET /users/me/export "$TP"
contains "eventExtras bolumu" "eventExtras" "$BODY"

[ "$FAIL" = 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }
