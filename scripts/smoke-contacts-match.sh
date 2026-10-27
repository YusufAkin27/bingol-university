#!/usr/bin/env bash
# Rehber eslestirme duman testi (PostgreSQL: email_sha256 sutunu/indeksi, native sorgu).
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
  curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}

S=$RANDOM
EA="rehber.a$S@bingol.edu.tr"; EB="rehber.b$S@bingol.edu.tr"; EC="rehber.c$S@bingol.edu.tr"
TA=$(register "$EA" "Rehber A"); TB=$(register "$EB" "Rehber B"); TC=$(register "$EC" "Rehber C")
IDB=$(curl -s -H "Authorization: Bearer $TB" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
IDC=$(curl -s -H "Authorization: Bearer $TC" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
HB=$(sha "$EB"); HC=$(sha "$EC"); HA=$(sha "$EA"); HX=$(sha "yok$S@gmail.com")
match() { curl -s -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match -d "$1"; }

echo "== eslesme"
R=$(match "{\"hashes\":[\"$HB\",\"$HB\",\"$HC\",\"$HA\",\"$HX\"]}")
check "B eslesti" 1 "$(echo "$R" | grep -c "\"userId\":$IDB")"
check "C eslesti" 1 "$(echo "$R" | grep -c "\"userId\":$IDC")"
check "kendi hesabi yok" 0 "$(echo "$R" | grep -c "$HA")"
check "alan disi yok" 0 "$(echo "$R" | grep -c "$HX")"
check "hash yanitta" 1 "$(echo "$R" | grep -c "\"hash\":\"$HB\"")"

echo "== engel iki yonlu"
curl -s -o /dev/null -X POST -H "Authorization: Bearer $TC" $A/users/$(curl -s -H "Authorization: Bearer $TA" $A/users/me | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)/block
R=$(match "{\"hashes\":[\"$HC\"]}")
check "engelli C gelmez" 0 "$(echo "$R" | grep -c "\"userId\":$IDC")"

echo "== 501 hash"
BIG=$(for i in $(seq 1 501); do printf '"%064x",' $i; done); BIG=${BIG%,}
check "501 -> 400" 400 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match -d "{\"hashes\":[$BIG]}")"
check "kimliksiz -> 401" 401 "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" $A/users/contacts/match -d '{"hashes":[]}')"

echo "== rate limit (saatte 6)"
CODE=0
for i in 1 2 3 4 5 6 7; do CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$H" -H "Authorization: Bearer $TA" $A/users/contacts/match -d '{"hashes":[]}'); done
check "7. istek 429" 429 "$CODE"

[ $FAIL -eq 0 ] && echo "TAMAM" || { echo "BASARISIZ"; exit 1; }
