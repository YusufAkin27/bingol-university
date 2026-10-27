#!/usr/bin/env bash
# Kulup yasam dongusu + etkinlik kapatma/iptal + "Etkinliklerim" duman testi (calisan compose yigina karsi).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-club-lifecycle.sh
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur). Oncesinde: docker compose exec -T redis redis-cli flushall
# Kapsam: kulup kur (auto-approve), duzenle, istek akisi, katil/ayril -> sohbet kaybolur ve gecmise erisilemez,
# sahip ayrilamaz, kulup sil; etkinlik kur/kapat/yeniden ac/iptal; RSVP -> Etkinliklerim modlari.
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' bulunamadi)"; FAIL=1; fi; }
lacks() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  FAIL $1 ('$2' beklenmedik sekilde var)"; FAIL=1; else echo "  ok   $1"; fi; }
call() { # METHOD YOL TOKEN [JSON]
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    printf '%s' "$d" > "$TMP.req"
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" --data-binary "@$(cygpath -m "$TMP.req" 2>/dev/null || echo "$TMP.req")")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }
iso() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }

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
T1=$(register "ksahip$SFX@bingol.edu.tr" "Kulup Sahibi")
T2=$(register "kuye$SFX@bingol.edu.tr" "Kulup Uyesi")
T3=$(register "kistek$SFX@bingol.edu.tr" "Istekci Kisi")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "kayit basarisiz"; exit 1; }
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)

echo "== kulup kur (auto-approve) ve duzenle"
call POST /communities "$T1" "{\"name\":\"Yasam Dongusu $SFX\",\"description\":\"ilk\",\"category\":\"teknoloji\"}"
if [ "$CODE" = "201" ]; then
  echo "  ok   olusturma 201 (auto-approve acik)"
  contains "status ACTIVE" '"status":"ACTIVE"' "$BODY"
else
  echo "  not  olusturma $CODE (auto-approve kapali olabilir; yonetici onayi gerekir, kalan adimlar atlandi)"
  exit 0
fi
CID=$(printf '%s' "$BODY" | idof)
step "duzenle (sahip)" 200 PATCH /communities/$CID "$T1" '{"description":"guncel aciklama","joinPolicy":"APPROVAL","category":"kultur"}'
contains "aciklama guncel" "guncel aciklama" "$BODY"
step "duzenle (uye olmayan) 403" 403 PATCH /communities/$CID "$T3" '{"description":"hack"}'
step "sahip ayrilamaz" 409 DELETE /communities/$CID/membership "$T1"

echo "== istek akisi (APPROVAL)"
step "istek gonder" 200 POST /communities/$CID/join "$T3" '{}'
contains "PENDING" "PENDING" "$BODY"
step "istekler (sahip)" 200 GET /communities/$CID/requests "$T1"
step "istekler (yabanci) 403" 403 GET /communities/$CID/requests "$T2"
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
step "reddet" 204 POST /communities/$CID/requests/$ID3/reject "$T1"
step "tekrar istek" 200 POST /communities/$CID/join "$T3" '{}'
step "onayla" 204 POST /communities/$CID/requests/$ID3/approve "$T1"

echo "== uye katil -> sohbet -> ayril"
step "uye istegi" 200 POST /communities/$CID/join "$T2" '{}'
step "uye onay" 204 POST /communities/$CID/requests/$ID2/approve "$T1"
step "sohbet (uye)" 200 GET /communities/$CID/chat "$T2"
CONV=$(printf '%s' "$BODY" | idof)
step "mesaj gonder (sahip)" 201 POST /conversations/$CONV/messages "$T1" '{"text":"merhaba kulup","clientId":"c-'$SFX'-1"}'
step "uye mesajlari gorur" 200 GET /conversations/$CONV/messages "$T2"
contains "mesaj var" "merhaba kulup" "$BODY"
call GET /conversations "$T2"
contains "sohbet listede" "\"id\":$CONV" "$BODY"
step "ayril" 204 DELETE /communities/$CID/membership "$T2"
call GET /conversations "$T2"
lacks "sohbet listeden kayboldu" "\"id\":$CONV," "$BODY"
step "gecmis erisimi 404" 404 GET /conversations/$CONV/messages "$T2"
step "mesaj gonderme 404" 404 POST /conversations/$CONV/messages "$T2" '{"text":"x","clientId":"c-'$SFX'-2"}'
step "okundu 404" 404 POST /conversations/$CONV/read "$T2" '{"lastMessageId":1}'
step "kulup sohbeti (ayrilmis) 404" 404 GET /communities/$CID/chat "$T2"
step "yeniden katil" 200 POST /communities/$CID/join "$T2" '{}'
step "yeniden onay" 204 POST /communities/$CID/requests/$ID2/approve "$T1"
step "sohbet yeniden" 200 GET /communities/$CID/chat "$T2"
step "mesajlar (yeniden katilim)" 200 GET /conversations/$CONV/messages "$T2"
lacks "eski mesaj gorunmez" "merhaba kulup" "$BODY"

echo "== etkinlik: kur / kapat / yeniden ac / RSVP / Etkinliklerim"
S=$(iso "+2 days"); E=$(iso "+2 days 2 hours")
call POST /events "$T1" "{\"title\":\"Smoke Etkinlik $SFX\",\"startsAt\":\"$S\",\"endsAt\":\"$E\",\"location\":\"Salon\",\"communityId\":$CID}"
check "etkinlik olustur" 201 "$CODE"
EV=$(printf '%s' "$BODY" | idof)
contains "registrationClosed false" '"registrationClosed":false' "$BODY"
step "RSVP GOING (uye)" 200 PUT /events/$EV/rsvp "$T2" '{"status":"GOING"}'
step "kapat (yabanci) 403" 403 POST /events/$EV/close "$T3"
step "kapat (sahip)" 200 POST /events/$EV/close "$T1"
contains "registrationClosed true" '"registrationClosed":true' "$BODY"
step "yeni RSVP kapali 409" 409 PUT /events/$EV/rsvp "$T3" '{"status":"GOING"}'
contains "hata kodu" "EVENT_REGISTRATION_CLOSED" "$BODY"
step "mevcut RSVP etkilenmez" 200 PUT /events/$EV/rsvp "$T2" '{"status":"GOING"}'
step "etkinlik gorunur" 200 GET /events/$EV "$T3"
step "yeniden ac" 200 POST /events/$EV/reopen "$T1"
step "RSVP (yeniden acik)" 200 PUT /events/$EV/rsvp "$T3" '{"status":"GOING"}'

step "Etkinliklerim upcoming" 200 GET "/events/me?mode=upcoming" "$T2"
contains "upcoming'de var" "\"id\":$EV" "$BODY"
step "Etkinliklerim going" 200 GET "/events/me?mode=going" "$T3"
contains "going'de var" "\"id\":$EV" "$BODY"
step "Etkinliklerim created (sahip)" 200 GET "/events/me?mode=created" "$T1"
contains "created'da var" "\"id\":$EV" "$BODY"
step "Etkinliklerim created (uye) bos" 200 GET "/events/me?mode=created" "$T2"
lacks "created'da yok" "\"id\":$EV" "$BODY"
step "Etkinliklerim past" 200 GET "/events/me?mode=past" "$T2"
lacks "past'ta yok (gelecek etkinlik)" "\"id\":$EV" "$BODY"
step "eski uc /me/events" 200 GET "/me/events?mode=attending" "$T2"

echo "== RSVP degisiklik siniri (dakikada 5)"
LAST=0
for i in 1 2 3 4 5 6 7; do
  call PUT /events/$EV/rsvp "$T3" '{"status":"INTERESTED"}'; LAST=$CODE
  call PUT /events/$EV/rsvp "$T3" '{"status":"GOING"}'
  if [ "$CODE" = "429" ] || [ "$LAST" = "429" ]; then break; fi
done
check "429 doner" 429 "$([ "$CODE" = "429" ] || [ "$LAST" = "429" ] && echo 429 || echo "$CODE")"

echo "== etkinlik iptal"
step "iptal (POST cancel)" 204 POST /events/$EV/cancel "$T1"
call GET /events/$EV "$T1"
contains "CANCELLED" "CANCELLED" "$BODY"

echo "== kulup sil"
call POST /events "$T1" "{\"title\":\"Silinecek Etkinlik $SFX\",\"startsAt\":\"$S\",\"endsAt\":\"$E\",\"communityId\":$CID}"
EV2=$(printf '%s' "$BODY" | idof)
step "yabanci silemez" 403 DELETE /communities/$CID "$T3"
step "sahip siler" 204 DELETE /communities/$CID "$T1"
step "silinen kulup 404" 404 GET /communities/$CID "$T1"
sleep 1
call GET /events/$EV2 "$T1"
echo "  info silinen kulubun etkinligi: $CODE"
call GET /conversations "$T1"
lacks "kulup sohbeti listeden dustu" "\"id\":$CONV," "$BODY"
step "silinen kulup sohbeti 404" 404 GET /conversations/$CONV/messages "$T1"

[ $FAIL -eq 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }
