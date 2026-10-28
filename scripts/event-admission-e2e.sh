#!/usr/bin/env bash
# Etkinlik katilim yonetimi (T9) uctan uca: basvuru -> kabul/ret -> bekleme -> vazgecme -> otomatik terfi -> yoklama,
# kapasite yarisi (kapasite 1, 5 eszamanli basvuru/kabul, ardindan iptal), limitler, disa aktarim.
# Kullanim: BASE=http://localhost:8109 COMPOSE_PROJECT_NAME=wt_t9 ./scripts/event-admission-e2e.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur). Tekrar calistirilabilir (rastgele kullanicilar).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
WORK=$(mktemp -d)
trap 'rm -rf "$TMP" "$WORK"' EXIT

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
num() { grep -o "\"$1\":[0-9]*" | head -1 | cut -d: -f2; }
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }

register() { # email ad
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

new_event() { # token kapasite -> id (APPROVAL modunda, 2 soru)
  call POST /events "$1" "{\"title\":\"Admission Test $RANDOM\",\"startsAt\":\"$(iso '+3 minutes')\",\"endsAt\":\"$(iso '+3 hours')\",\"location\":\"Salon\",\"capacity\":$2}"
  local id; id=$(printf '%s' "$BODY" | idof)
  call PUT /events/$id/admission "$1" '{"mode":"APPROVAL","questions":["Neden katilmak istiyorsunuz?","Bolumunuz?"]}' >/dev/null
  echo "$id"
}
APPLY='{"note":"merhaba","answers":["ogrenmek","bilgisayar"]}'
status_of() { # token event -> basvuru durumu
  call GET /events/$2/applications/mine "$1"; printf '%s' "$BODY" | field status
}
summary() { call GET /events/$2/applications/summary "$1"; }

SFX=$RANDOM
echo "== kullanicilar"
TO=$(register "org$SFX@bingol.edu.tr" "Organizator")
T1=$(register "a1x$SFX@bingol.edu.tr" "Aday Bir")
T2=$(register "a2x$SFX@bingol.edu.tr" "Aday Iki")
T3=$(register "a3x$SFX@bingol.edu.tr" "Aday Uc")
T4=$(register "a4x$SFX@bingol.edu.tr" "Aday Dort")
T5=$(register "a5x$SFX@bingol.edu.tr" "Aday Bes")
T6=$(register "a6x$SFX@bingol.edu.tr" "Aday Alti")
U1=$(curl -s -H "Authorization: Bearer $T1" $A/auth/me | idof)
U2=$(curl -s -H "Authorization: Bearer $T2" $A/auth/me | idof)
U3=$(curl -s -H "Authorization: Bearer $T3" $A/auth/me | idof)
[ -n "$TO" ] && [ -n "$T6" ] && [ -n "$U1" ] || { echo "kullanici hazirlanamadi"; exit 1; }

echo "== etkinlik (yonetici onayi yok -> dogrudan yayinda)"
call POST /events "$TO" "{\"title\":\"Katilim Testi\",\"startsAt\":\"$(iso '+3 minutes')\",\"endsAt\":\"$(iso '+3 hours')\",\"location\":\"Salon\",\"capacity\":1}"
check "etkinlik 201 (onay beklemez)" 201 "$CODE"
EV=$(printf '%s' "$BODY" | idof)
contains "durum ACTIVE" '"status":"ACTIVE"' "$BODY"
step "varsayilan mod OPEN" 200 GET /events/$EV/admission "$T1"
contains "OPEN" '"mode":"OPEN"' "$BODY"
step "baskasi modu degistiremez" 403 PUT /events/$EV/admission "$T1" '{"mode":"APPROVAL"}'
step "4 soru reddedilir" 400 PUT /events/$EV/admission "$TO" '{"mode":"APPROVAL","questions":["a","b","c","d"]}'
step "APPROVAL + 2 soru" 200 PUT /events/$EV/admission "$TO" '{"mode":"APPROVAL","questions":["Neden katilmak istiyorsunuz?","Bolumunuz?"]}'
step "organizator kendine basvuramaz" 409 POST /events/$EV/applications "$TO" "$APPLY"

echo "== basvuru"
step "dogrudan GOING engellenir" 409 PUT /events/$EV/rsvp "$T1" '{"status":"GOING"}'
contains "APPLICATION_REQUIRED" "APPLICATION_REQUIRED" "$BODY"
step "INTERESTED serbest" 200 PUT /events/$EV/rsvp "$T6" '{"status":"INTERESTED"}'
step "yanitsiz basvuru" 400 POST /events/$EV/applications "$T1" '{"note":"x"}'
step "basvuru u1" 201 POST /events/$EV/applications "$T1" "$APPLY"
contains "PENDING" '"status":"PENDING"' "$BODY"
step "tekrar basvuru" 409 POST /events/$EV/applications "$T1" "$APPLY"
step "basvuru u2" 201 POST /events/$EV/applications "$T2" "$APPLY"
step "basvuru u3" 201 POST /events/$EV/applications "$T3" "$APPLY"
step "baskasi listeyi goremez" 403 GET /events/$EV/applications "$T2"
step "organizator liste" 200 GET "/events/$EV/applications?status=PENDING" "$TO"
contains "u1 listede" '"displayName":"Aday Bir"' "$BODY"
summary "$TO" $EV; check "ozet pending=3" 3 "$(printf '%s' "$BODY" | num pending)"
call GET /me/applications "$T1"; contains "benim basvurularim" '"status":"PENDING"' "$BODY"
A1=$(curl -s -H "Authorization: Bearer $TO" "$A/events/$EV/applications?size=50" | grep -o '"id":[0-9]*,"userId":'$U1 | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
A2=$(curl -s -H "Authorization: Bearer $TO" "$A/events/$EV/applications?size=50" | grep -o '"id":[0-9]*,"userId":'$U2 | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
A3=$(curl -s -H "Authorization: Bearer $TO" "$A/events/$EV/applications?size=50" | grep -o '"id":[0-9]*,"userId":'$U3 | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
[ -n "$A1" ] && [ -n "$A2" ] && [ -n "$A3" ] || { echo "basvuru kimlikleri okunamadi"; exit 1; }

echo "== kabul / otomatik bekleme listesi / yoklama"
step "baskasi kabul edemez" 403 POST /events/$EV/applications/$A1/accept "$T2"
step "u1 kabul" 200 POST /events/$EV/applications/$A1/accept "$TO"
contains "ACCEPTED" '"status":"ACCEPTED"' "$BODY"
step "u2 kabul (dolu -> bekleme)" 200 POST /events/$EV/applications/$A2/accept "$TO"
contains "WAITLISTED" '"status":"WAITLISTED"' "$BODY"
step "u3 elle bekleme" 200 POST /events/$EV/applications/$A3/waitlist "$TO"
call GET /events/$EV/applications/mine "$T3"; check "u3 sirasi 2" 2 "$(printf '%s' "$BODY" | num queuePosition)"
call GET /events/$EV/applications/mine "$T2"; check "u2 sirasi 1" 1 "$(printf '%s' "$BODY" | num queuePosition)"
call GET /events/$EV "$TO"; check "goingCount 1" 1 "$(printf '%s' "$BODY" | num goingCount)"
call GET /events/$EV/checkin-code "$TO"; CODE_QR=$(printf '%s' "$BODY" | field code)
step "bekleyen QR okutamaz" 403 POST /events/$EV/check-in "$T2" "{\"code\":\"$CODE_QR\"}"
step "kabul edilen QR okutur" 200 POST /events/$EV/check-in "$T1" "{\"code\":\"$CODE_QR\"}"
step "bekleyene elle yoklama yok" 409 PUT /events/$EV/attendance/$U2 "$TO" '{"present":true}'
contains "NOT_ACCEPTED" "NOT_ACCEPTED" "$BODY"
step "kabul edilene elle yoklama" 204 PUT /events/$EV/attendance/$U1 "$TO" '{"present":true}'

echo "== vazgecme -> otomatik terfi (adil sira)"
step "u1 vazgecer" 200 DELETE /events/$EV/applications/mine "$T1"
check "u1 CANCELLED" CANCELLED "$(status_of "$T1" $EV)"
check "u2 terfi etti" ACCEPTED "$(status_of "$T2" $EV)"
call GET /events/$EV/applications/mine "$T3"; check "u3 sirasi 1" 1 "$(printf '%s' "$BODY" | num queuePosition)"
call GET /events/$EV "$TO"; check "goingCount 1 (tutarli)" 1 "$(printf '%s' "$BODY" | num goingCount)"
step "u2 yoklamaya girebilir (GOING)" 200 GET /events/$EV/my-attendance "$T2"
step "organizator u2'yi cikarir" 204 DELETE /events/$EV/participants/$U2 "$TO"
check "u2 REJECTED" REJECTED "$(status_of "$T2" $EV)"
check "u3 terfi etti (cikarma)" ACCEPTED "$(status_of "$T3" $EV)"
step "olmayan katilimci" 404 DELETE /events/$EV/participants/$U2 "$TO"
step "cikarilan tekrar basvuramaz" 409 POST /events/$EV/applications "$T2" "$APPLY"
step "cikarilan GOING diyemez" 409 PUT /events/$EV/rsvp "$T2" '{"status":"GOING"}'
step "u1 yeniden basvurabilir" 201 POST /events/$EV/applications "$T1" "$APPLY"

echo "== ret + kapasite artisi"
step "u4 basvuru" 201 POST /events/$EV/applications "$T4" "$APPLY"
call GET "/events/$EV/applications?status=PENDING" "$TO"
A4=$(printf '%s' "$BODY" | grep -o '"id":[0-9]*,"userId":[0-9]*,"displayName":"Aday Dort' | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
step "u4 reddedilir" 200 POST /events/$EV/applications/$A4/reject "$TO" '{"reason":"kontenjan"}'
check "u4 REJECTED" REJECTED "$(status_of "$T4" $EV)"
step "reddedilen vazgecemez" 409 DELETE /events/$EV/applications/mine "$T4"
step "u5 basvuru" 201 POST /events/$EV/applications "$T5" "$APPLY"
call GET "/events/$EV/applications?status=PENDING" "$TO"
A5=$(printf '%s' "$BODY" | grep -o '"id":[0-9]*,"userId":[0-9]*,"displayName":"Aday Bes' | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
A1B=$(printf '%s' "$BODY" | grep -o '"id":[0-9]*,"userId":'$U1 | head -1 | grep -o '^"id":[0-9]*' | cut -d: -f2)
step "toplu: u5 + u1 kabul (dolu -> bekleme)" 200 POST /events/$EV/applications/decisions "$TO" "{\"ids\":[$A5,$A1B,999999],\"action\":\"ACCEPT\"}"
contains "olmayan kimlik raporlanir" "APPLICATION_NOT_FOUND" "$BODY"
check "u5 bekliyor" WAITLISTED "$(status_of "$T5" $EV)"
step "kapasite 2'ye cikar" 200 PATCH /events/$EV "$TO" '{"capacity":2}'
check "u5 kapasite artisiyla terfi" ACCEPTED "$(status_of "$T5" $EV)"
check "u1 hala bekliyor" WAITLISTED "$(status_of "$T1" $EV)"
step "kapasite < kabul edilen" 409 PATCH /events/$EV "$TO" '{"capacity":1}'

echo "== eszamanlilik: kapasite 1, 5 eszamanli basvuru"
EV2=$(new_event "$TO" 1)
TOK=("$T1" "$T2" "$T3" "$T4" "$T5")
for i in 0 1 2 3 4; do
  ( curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer ${TOK[$i]}" $A/events/$EV2/applications -d "$APPLY" > "$WORK/apply$i" ) &
done
wait
OKS=0; for i in 0 1 2 3 4; do [ "$(cat $WORK/apply$i)" = "201" ] && OKS=$((OKS+1)); done
check "5 basvurunun 5'i de 201" 5 "$OKS"
summary "$TO" $EV2; check "pending=5" 5 "$(printf '%s' "$BODY" | num pending)"
IDS=$(curl -s -H "Authorization: Bearer $TO" "$A/events/$EV2/applications?size=50" | grep -o '"id":[0-9]*,"userId"' | cut -d: -f2 | cut -d, -f1)
for id in $IDS; do
  ( curl -s -o /dev/null -X POST -H "Authorization: Bearer $TO" $A/events/$EV2/applications/$id/accept ) &
done
wait
summary "$TO" $EV2
check "tam 1 kabul" 1 "$(printf '%s' "$BODY" | num accepted)"
check "4 bekleme" 4 "$(printf '%s' "$BODY" | num waitlisted)"
check "goingCount 1" 1 "$(printf '%s' "$BODY" | num goingCount)"
ACC=""; for i in 0 1 2 3 4; do [ "$(status_of "${TOK[$i]}" $EV2)" = "ACCEPTED" ] && ACC=$i; done
[ -n "$ACC" ] && echo "  ok   kabul edilen bulundu (u$((ACC+1)))" || { echo "  FAIL kabul edilen yok"; FAIL=1; ACC=0; }

echo "== eszamanli iptal: kabul edilen + bekleyen biri ayni anda vazgecer"
WAIT=$(( (ACC+1) % 5 ))
( curl -s -o /dev/null -X DELETE -H "Authorization: Bearer ${TOK[$ACC]}" $A/events/$EV2/applications/mine ) &
( curl -s -o /dev/null -X DELETE -H "Authorization: Bearer ${TOK[$WAIT]}" $A/events/$EV2/applications/mine ) &
wait
summary "$TO" $EV2
check "hala tam 1 kabul" 1 "$(printf '%s' "$BODY" | num accepted)"
check "goingCount 1" 1 "$(printf '%s' "$BODY" | num goingCount)"
check "2 bekleme kaldi" 2 "$(printf '%s' "$BODY" | num waitlisted)"
echo "== kalan herkes ayni anda vazgecer -> bos"
for i in 0 1 2 3 4; do
  ( curl -s -o /dev/null -X DELETE -H "Authorization: Bearer ${TOK[$i]}" $A/events/$EV2/applications/mine ) &
done
wait
summary "$TO" $EV2
check "kabul 0" 0 "$(printf '%s' "$BODY" | num accepted)"
check "goingCount 0" 0 "$(printf '%s' "$BODY" | num goingCount)"
check "bekleme 0" 0 "$(printf '%s' "$BODY" | num waitlisted)"

echo "== OPEN mod: mevcut davranis"
call POST /events "$TO" "{\"title\":\"Acik Etkinlik\",\"startsAt\":\"$(iso '+1 day')\",\"endsAt\":\"$(iso '+1 day 2 hours')\",\"capacity\":1}"
EV3=$(printf '%s' "$BODY" | idof)
step "OPEN: basvuru gerekmez" 409 POST /events/$EV3/applications "$T1" "$APPLY"
step "OPEN: dogrudan GOING" 200 PUT /events/$EV3/rsvp "$T1" '{"status":"GOING"}'
step "OPEN: dolu" 409 PUT /events/$EV3/rsvp "$T2" '{"status":"GOING"}'
step "OPEN: organizator cikarir" 204 DELETE /events/$EV3/participants/$U1 "$TO"
step "OPEN: yer acildi" 200 PUT /events/$EV3/rsvp "$T2" '{"status":"GOING"}'

echo "== acma sinirlari (varsayilan: 5 acik etkinlik)"
TL=$(register "lim$SFX@bingol.edu.tr" "Sinir Kisi")
for i in 1 2 3 4 5; do
  call POST /events "$TL" "{\"title\":\"Sinir $i\",\"startsAt\":\"$(iso '+1 day')\",\"endsAt\":\"$(iso '+1 day 2 hours')\"}"
done
check "5. etkinlik acildi" 201 "$CODE"
step "6. etkinlik sinira takilir" 409 POST /events "$TL" "{\"title\":\"Sinir 6\",\"startsAt\":\"$(iso '+1 day')\",\"endsAt\":\"$(iso '+1 day 2 hours')\"}"
contains "EVENT_LIMIT_OPEN" "EVENT_LIMIT_OPEN" "$BODY"

echo "== KVKK disa aktarim"
call GET /users/me/export "$T1"
contains "eventApplications bolumu" "eventApplications" "$BODY"

echo
[ "$FAIL" = 0 ] && echo "TUMU GECTI" || { echo "BAZI ADIMLAR BASARISIZ"; exit 1; }
