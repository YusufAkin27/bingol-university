#!/usr/bin/env bash
# Rehber eslestirme duman testi (PostgreSQL: email_sha256 sutunu/indeksi, native sorgu, profile_privacy.contacts_discoverable).
# T-061: "Rehberden bulunabilirim" anahtari (varsayilan KAPALI), karsilikli eslesme, gunluk 2000 aday tavani.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-contacts-match.sh
# Onkosul: MAIL_ENABLED=false (dogrulama kodu log'dan okunur). Oncesinde: docker compose exec -T redis redis-cli flushall
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
sha() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }

register() { # email ad
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true}"
  sleep 1
  local c
  c=$(docker compose logs backend 2>&1 | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
discoverable() { # token true|false
  curl -s -o /dev/null -w '%{http_code}' -X PUT -H "$H" -H "Authorization: Bearer $1" $A/users/contacts/discoverable -d "{\"enabled\":$2}"
}

S=$RANDOM
EA="rehber.a$S@bingol.edu.tr"; EB="rehber.b$S@bingol.edu.tr"; EC="rehber.c$S@bingol.edu.tr"; ED="rehber.d$S@bingol.edu.tr"
TA=$(register "$EA" "Rehber A"); TB=$(register "$EB" "Rehber B"); TC=$(register "$EC" "Rehber C"); TD=$(register "$ED" "Rehber D")
IDB=$(curl -s -H "Authorization: Bearer $TB" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
IDC=$(curl -s -H "Authorization: Bearer $TC" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
IDD=$(curl -s -H "Authorization: Bearer $TD" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
HB=$(sha "$EB"); HC=$(sha "$EC"); HD=$(sha "$ED"); HA=$(sha "$EA"); HX=$(sha "yok$S@gmail.com")
match() { curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match -d "$1"; }
matchcode() { curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match -d "$1"; }

echo "== varsayilan KAPALI ve karsilikli"
check "A varsayilan bulunabilir degil" 1 "$(curl -s -H "Authorization: Bearer $TA" $A/users/contacts/discoverable | grep -c '"enabled":false')"
check "A kapaliyken eslestirme 403" 403 "$(matchcode "{\"hashes\":[\"$HB\"]}")"
check "A acik onay verir" 200 "$(discoverable "$TA" true)"
check "A artik acik" 1 "$(curl -s -H "Authorization: Bearer $TA" $A/users/contacts/discoverable | grep -c '"enabled":true')"

echo "== yalniz bulunabilir diyenler doner"
check "B acik onay verir" 200 "$(discoverable "$TB" true)"
check "D acik onay verir" 200 "$(discoverable "$TD" true)"
R=$(match "{\"hashes\":[\"$HB\",\"$HB\",\"$HC\",\"$HA\",\"$HX\"]}")
check "B eslesti (acik onay)" 1 "$(echo "$R" | grep -c "\"userId\":$IDB")"
check "C eslesmedi (acik onay yok)" 0 "$(echo "$R" | grep -c "\"userId\":$IDC")"
check "kendi hesabi yok" 0 "$(echo "$R" | grep -c "$HA")"
check "alan disi yok" 0 "$(echo "$R" | grep -c "$HX")"
check "hash yanitta" 1 "$(echo "$R" | grep -c "\"hash\":\"$HB\"")"
check "B kapatinca bulunmaz" 200 "$(discoverable "$TB" false)"
check "kapali B donmez" 0 "$(match "{\"hashes\":[\"$HB\"]}" | grep -c "\"userId\":$IDB")"

echo "== engel iki yonlu"
IDA=$(curl -s -H "Authorization: Bearer $TA" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
curl -s -o /dev/null -X POST -H "Authorization: Bearer $TD" $A/users/$IDA/block
R=$(match "{\"hashes\":[\"$HD\"]}")
check "engelli D gelmez" 0 "$(echo "$R" | grep -c "\"userId\":$IDD")"

echo "== 501 hash"
BIGF=$(mktemp); trap 'rm -f "$BIGF"' EXIT
BIG=$(for i in $(seq 1 501); do printf '"%064x",' $i; done); BIG=${BIG%,}
printf '{"hashes":[%s]}' "$BIG" > "$BIGF"  # Windows komut satiri siniri nedeniyle govde dosyadan gonderilir
check "501 -> 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match --data-binary @"$BIGF")"
check "kimliksiz -> 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" $A/users/contacts/match -d '{"hashes":[]}')"
check "kimliksiz discoverable -> 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' $A/users/contacts/discoverable)"

echo "== rate limit (saatte 6)"
CODE=0
for i in 1 2 3 4 5 6 7; do CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match -d '{"hashes":[]}'); done
check "7. istek 429" 429 "$CODE"

echo "== gunluk aday tavani (2000 tekil aday/gun; yeni kullanici E)"
EE="rehber.e$S@bingol.edu.tr"
TE=$(register "$EE" "Rehber E")
check "E acik onay verir" 200 "$(discoverable "$TE" true)"
CAPCODE=0
for r in 1 2 3 4 5; do
  CF=$(mktemp)
  B=$(for i in $(seq 1 500); do printf '"%064x",' $((r * 1000 + i)); done); B=${B%,}
  printf '{"hashes":[%s]}' "$B" > "$CF"
  CAPCODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TE" $A/users/contacts/match --data-binary @"$CF")
  rm -f "$CF"
  if [ "$r" -le 4 ]; then check "istek $r (toplam $((r * 500)) aday) 200" 200 "$CAPCODE"; fi
done
check "5. istek (2500 aday) tavani asar -> 429" 429 "$CAPCODE"

[ $FAIL -eq 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }
