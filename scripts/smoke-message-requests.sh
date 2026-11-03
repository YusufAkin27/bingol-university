#!/usr/bin/env bash
# Mesaj istegi (T-026 / K-08) duman testi: ortak baglami olmayan ilk DM alici icin istek olur, kabul edilene kadar
# listede/bildirimde yok, gonderen en fazla 3 mesaj yazar; kabul/red; grup daveti.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-message-requests.sh
# Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu log'dan okunur). NOT: bu betik henuz kosturulmadi (Docker yok).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
idof() { grep -o '"id":[0-9]*' | head -1 | cut -d: -f2; }

register() { # email ad -> access token
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"481952\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c t
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"481952\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  [ -n "$t" ] || t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"481952\"}" |
    grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  echo "$t"
}
send() { # token cid clientId
  code -X POST -H "$H" -H "Authorization: Bearer $1" $A/conversations/$2/messages -d "{\"text\":\"selam\",\"clientId\":\"$3\"}"
}

SFX=$RANDOM
echo "== kullanicilar"
T1=$(register "rq1x$SFX@bingol.edu.tr" "Istek Bir"); T2=$(register "rq2x$SFX@bingol.edu.tr" "Istek Iki")
T3=$(register "rq3x$SFX@bingol.edu.tr" "Istek Uc")
[ -n "$T1" ] && [ -n "$T2" ] && [ -n "$T3" ] || { echo "kayit basarisiz"; exit 1; }
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID3=$(curl -s -H "Authorization: Bearer $T3" $A/users/me | idof)
AUTH1="Authorization: Bearer $T1"; AUTH2="Authorization: Bearer $T2"; AUTH3="Authorization: Bearer $T3"

echo "== ilk DM (ortak baglam yok) alici icin istek"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"userId\":$ID2}")
check "olustur 201" 201 "${R##* }"
CID=$(echo "$R" | idof)
check "alici ana listede gormez" 0 "$(curl -s -H "$AUTH2" $A/conversations | grep -c "\"id\":$CID,")"
check "istek sayisi 1" '{"count":1}' "$(curl -s -H "$AUTH2" $A/conversations/requests/count)"
check "istek listesinde PENDING" 1 "$(curl -s -H "$AUTH2" $A/conversations/requests | grep -c '"requestState":"PENDING"')"
check "gonderen 1. mesaj" 201 "$(send "$T1" $CID m1)"
check "gonderen 2. mesaj" 201 "$(send "$T1" $CID m2)"
check "gonderen 3. mesaj" 201 "$(send "$T1" $CID m3)"
check "gonderen 4. mesaj 409 (istek kabul edilmedi)" 409 "$(send "$T1" $CID m4)"
check "alici yine ana listede yok" 0 "$(curl -s -H "$AUTH2" $A/conversations | grep -c "\"id\":$CID,")"

echo "== kabul"
check "kabul 200" 200 "$(code -X POST -H "$AUTH2" $A/conversations/$CID/accept)"
check "kabul tekrar 200 (idempotent)" 200 "$(code -X POST -H "$AUTH2" $A/conversations/$CID/accept)"
check "alici artik ana listede" 1 "$(curl -s -H "$AUTH2" $A/conversations | grep -c "\"id\":$CID,")"
check "istek sayisi 0" '{"count":0}' "$(curl -s -H "$AUTH2" $A/conversations/requests/count)"
check "gonderen artik sinirsiz" 201 "$(send "$T1" $CID m5)"
check "kabul edilmis konusmada red 409" 409 "$(code -X POST -H "$AUTH2" $A/conversations/$CID/decline)"

echo "== red (gonderen reddedildigini ogrenmez)"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH3" $A/conversations -d "{\"userId\":$ID2}")
CID2=$(echo "$R" | idof)
check "istek 201" 201 "${R##* }"
check "red 204" 204 "$(code -X POST -H "$AUTH2" $A/conversations/$CID2/decline)"
check "gonderen 1" 201 "$(send "$T3" $CID2 d1)"
check "gonderen 2" 201 "$(send "$T3" $CID2 d2)"
check "gonderen 3" 201 "$(send "$T3" $CID2 d3)"
check "gonderen 4 ayni 409 (reddedildigi gorunmez)" 409 "$(send "$T3" $CID2 d4)"
check "reddeden listede gormez" 0 "$(curl -s -H "$AUTH2" $A/conversations | grep -c "\"id\":$CID2,")"
check "reddeden istek listesinde de yok" 0 "$(curl -s -H "$AUTH2" $A/conversations/requests | grep -c "\"id\":$CID2,")"
check "reddeden sohbeti kendisi acarsa kabul olur" 200 "$(code -X POST -H "$H" -H "$AUTH2" $A/conversations -d "{\"userId\":$ID3}")"

echo "== grup daveti"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H "$AUTH1" $A/conversations -d "{\"title\":\"Istek Grubu\",\"memberIds\":[$ID3]}")
check "grup 201" 201 "${R##* }"
GID=$(echo "$R" | idof)
check "davetli ana listede gormez" 0 "$(curl -s -H "$AUTH3" $A/conversations | grep -c "\"id\":$GID,")"
check "davet istek listesinde" 1 "$(curl -s -H "$AUTH3" $A/conversations/requests | grep -c "\"id\":$GID,")"
check "davet red 204 (gruptan ayrilir)" 204 "$(code -X POST -H "$AUTH3" $A/conversations/$GID/decline)"
check "reddeden artik uye degil 404" 404 "$(code -H "$AUTH3" $A/conversations/$GID)"

echo
[ "$FAIL" = 0 ] && echo "TUMU OK" || { echo "HATA VAR"; exit 1; }
