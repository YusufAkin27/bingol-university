#!/usr/bin/env bash
# T5 guvenlik denetimi: BOLA/IDOR taramasi.
# `{id}` iceren uclar backend/src/main/java/**/*Controller.java dosyalarindan cikarilmistir
# (bkz. docs/SECURITY_AUDIT.md "Uc listesi"). Iki normal kullanici (U1, U2) ile U1'in kendi
# kaynagini U2 uzerinden okumaya/degistirmeye calisir. Tekrar calistirilabilir, yikici degildir
# (yalnizca bu betigin kendi olusturdugu test verisine dokunur).
set -u
BASE=${BASE:-http://localhost:8105}
A=$BASE/api
PASS=Sifre1234
RUN=$(date +%s)

pass() { echo "[OK]      $1"; }
fail() { echo "[FINDING] $1"; }
info() { echo "[info]    $1"; }

mk_user() {
  local email=$1 name=$2
  curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/register" \
    -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"displayName\":\"$name\",\"acceptTerms\":true}"
  sleep 1
  local code
  code=$(docker compose logs backend 2>&1 | grep "$email icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  [ -n "$code" ] && curl -s -o /dev/null -X POST -H 'Content-Type: application/json' "$A/auth/verify-email" \
    -d "{\"email\":\"$email\",\"code\":\"$code\"}"
}
login() {
  curl -s -X POST -H 'Content-Type: application/json' "$A/auth/login" \
    -d "{\"email\":\"$1\",\"password\":\"$PASS\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4
}
jwt_sub() {
  local p=$(echo "$1" | cut -d. -f2 | tr '_-' '/+')
  case $(( ${#p} % 4 )) in 2) p="${p}==";; 3) p="${p}=";; esac
  echo "$p" | base64 -d 2>/dev/null | grep -o '"sub":"[0-9]*' | cut -d'"' -f4
}
# HTTP durum kodunu doner; govdeyi $BODY_FILE'a yazar.
req() { # method url token [data]
  local m=$1 u=$2 t=$3 d=${4:-}
  BODY_FILE=$(mktemp)
  if [ -n "$d" ]; then
    curl -s -o "$BODY_FILE" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' "$u" -d "$d"
  else
    curl -s -o "$BODY_FILE" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" "$u"
  fi
}
# U2 kendi token'iyla U1'in kaynagina erismeye calisir; beklenen 403/404 ise OK, 2xx ise FINDING.
expect_blocked() {
  local label=$1 code=$2
  if [[ "$code" =~ ^2 ]]; then
    fail "$label -> HTTP $code, govde: $(head -c 200 "$BODY_FILE")"
  else
    pass "$label engellendi (HTTP $code)"
  fi
  rm -f "$BODY_FILE"
}

E1="sec-t5-bola1-$RUN@bingol.edu.tr"
E2="sec-t5-bola2-$RUN@bingol.edu.tr"
mk_user "$E1" "Bola U1"
mk_user "$E2" "Bola U2"
T1=$(login "$E1"); T2=$(login "$E2")
if [ -z "$T1" ] || [ -z "$T2" ]; then
  echo "[HATA] test kullanicilari hazirlanamadi (olasi rate limit; 'docker compose exec -T redis redis-cli flushall' deneyin)" >&2
  exit 1
fi
U1=$(jwt_sub "$T1"); U2=$(jwt_sub "$T2")
info "U1 id=$U1, U2 id=$U2"

echo "=== 1) Mesajlasma IDOR (messaging) ==="
req POST "$A/conversations" "$T1" "{\"userId\":$U2}"; CONV_ID=$(grep -o '"id":[0-9]*' "$BODY_FILE" | head -1 | cut -d: -f2)
rm -f "$BODY_FILE"
# U1-U2 birebir konusma; U1 bir mesaj gonderir
req POST "$A/conversations/$CONV_ID/messages" "$T1" '{"text":"gizli mesaj","clientId":"bola-1"}'; rm -f "$BODY_FILE"
# U3: konusmaya dahil olmayan ucuncu kullanici
E3="sec-t5-bola3-$RUN@bingol.edu.tr"; mk_user "$E3" "Bola U3"; T3=$(login "$E3")
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $T3" "$A/conversations/$CONV_ID")
expect_blocked "yabanci kullanici baskasinin konusmasini GET /api/conversations/{id} ile okudu" "$CODE"
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$A/conversations/$CONV_ID/messages" -H "Authorization: Bearer $T3")
expect_blocked "yabanci kullanici GET /api/conversations/{id}/messages ile mesajlari okudu" "$CODE"
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST -H "Authorization: Bearer $T3" -H 'Content-Type: application/json' \
  "$A/conversations/$CONV_ID/messages" -d '{"text":"sahte mesaj","clientId":"bola-x"}')
expect_blocked "yabanci kullanici POST /api/conversations/{id}/messages ile mesaj enjekte etti" "$CODE"
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X DELETE -H "Authorization: Bearer $T3" "$A/conversations/$CONV_ID/members/$U1")
expect_blocked "yabanci kullanici DELETE members/{userId} ile U1'i konusmadan cikardi" "$CODE"
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PATCH -H "Authorization: Bearer $T3" -H 'Content-Type: application/json' \
  "$A/conversations/$CONV_ID" -d '{"title":"ele gecirildi"}')
expect_blocked "yabanci kullanici PATCH /api/conversations/{id} ile basligi degistirdi" "$CODE"
# mesaj raporlama ucu baskasinin mesaj id'si icin de calisir (rapor kendisi zarar vermez, ama var olmayan/erismedigi id 404 vermeli)
MSG_ID=$(curl -s -H "Authorization: Bearer $T1" "$A/conversations/$CONV_ID/messages" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X GET -H "Authorization: Bearer $T2" "$A/users/$U1/presence")
info "U2, U1 presence okudu (herkese acik tasarlanmis olabilir) -> HTTP $CODE: $(head -c 150 "$BODY_FILE")"
rm -f "$BODY_FILE"

echo "=== 2) Profil / kullanici IDOR ==="
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PATCH -H "Authorization: Bearer $T2" -H 'Content-Type: application/json' \
  "$A/users/me" -d '{"displayName":"U2 degisti"}')
info "U2 kendi profilini guncelledi -> HTTP $CODE"
rm -f "$BODY_FILE"
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $T2" "$A/users/$U1")
pass_or_info_user() {
  if [[ "$1" =~ ^2 ]]; then info "GET /api/users/{id}: baskasinin genel profili goruntulenebiliyor (HTTP $1) - tasarim geregi olabilir, PII sizintisi icin govdeyi kontrol edin: $(head -c 200 "$BODY_FILE")"; else pass "GET /api/users/{id} erisimi kisitli (HTTP $1)"; fi
}
pass_or_info_user "$CODE"
rm -f "$BODY_FILE"
# Not: DELETE /api/users/me sifre onayi ister (DeleteAccountRequest.password); yikici oldugundan burada cagrilmaz.

echo "=== 3) Topluluk (kulup) IDOR ==="
SLUG="bola-club-$RUN"
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST -H "Authorization: Bearer $T1" -H 'Content-Type: application/json' \
  "$A/communities" -d "{\"name\":\"Bola Kulup\",\"slug\":\"$SLUG\",\"description\":\"test\"}")
COMM_ID=$(grep -o '"id":[0-9]*' "$BODY_FILE" | head -1 | cut -d: -f2)
info "topluluk olusturuldu id=$COMM_ID (HTTP $CODE)"
rm -f "$BODY_FILE"
if [ -n "$COMM_ID" ]; then
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PATCH -H "Authorization: Bearer $T2" -H 'Content-Type: application/json' \
    "$A/communities/$COMM_ID" -d '{"description":"ele gecirildi"}')
  expect_blocked "yabanci kullanici (uye olmayan) PATCH /api/communities/{id} ile kulubu degistirdi" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PUT -H "Authorization: Bearer $T2" -H 'Content-Type: application/json' \
    "$A/communities/$COMM_ID/members/$U1/role" -d '{"role":"MODERATOR"}')
  expect_blocked "yabanci kullanici PUT members/{userId}/role ile rol atadi" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X DELETE -H "Authorization: Bearer $T2" "$A/communities/$COMM_ID/members/$U1")
  expect_blocked "yabanci kullanici DELETE members/{userId} ile sahibi kulupten cikardi" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST -H "Authorization: Bearer $T2" -H 'Content-Type: application/json' \
    "$A/communities/$COMM_ID/posts" -d '{"text":"yetkisiz gonderi"}')
  info "yabanci kullanici (uye olmayan) POST posts -> HTTP $CODE (acik kulupte uye olmayan gonderi yapabiliyorsa inceleyin): $(head -c 150 "$BODY_FILE")"
  rm -f "$BODY_FILE"
fi

echo "=== 4) Etkinlik IDOR ==="
START=$(date -u -d '+2 days' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+2d +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u -d '+2 days 2 hours' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+2d -v+2H +%Y-%m-%dT%H:%M:%SZ)
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X POST -H "Authorization: Bearer $T1" -H 'Content-Type: application/json' \
  "$A/events" -d "{\"title\":\"Bola Etkinlik\",\"description\":\"test\",\"startsAt\":\"$START\",\"endsAt\":\"$END\",\"location\":\"Kampus\"}")
EVENT_ID=$(grep -o '"id":[0-9]*' "$BODY_FILE" | head -1 | cut -d: -f2)
info "etkinlik olusturuldu id=$EVENT_ID (HTTP $CODE): $(head -c 200 "$BODY_FILE")"
rm -f "$BODY_FILE"
if [ -n "$EVENT_ID" ]; then
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PATCH -H "Authorization: Bearer $T2" -H 'Content-Type: application/json' \
    "$A/events/$EVENT_ID" -d '{"title":"ele gecirildi"}')
  expect_blocked "yabanci kullanici PATCH /api/events/{id} ile baskasinin etkinligini degistirdi" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X DELETE -H "Authorization: Bearer $T2" "$A/events/$EVENT_ID")
  expect_blocked "yabanci kullanici DELETE /api/events/{id} ile baskasinin etkinligini sildi" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $T2" "$A/events/$EVENT_ID/attendees")
  info "attendees listesi (herkese acik olabilir) -> HTTP $CODE"
  rm -f "$BODY_FILE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $T2" "$A/events/$EVENT_ID/checkin-code")
  expect_blocked "yabanci kullanici organizatore ozel checkin-code'u okudu" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X PUT -H "Authorization: Bearer $T2" "$A/events/$EVENT_ID/attendance/$U1" -H 'Content-Type: application/json' -d '{"status":"PRESENT"}')
  expect_blocked "yabanci kullanici organizatore ozel yoklama (attendance/{userId}) ucunu kullandi" "$CODE"
  CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -H "Authorization: Bearer $T2" "$A/events/$EVENT_ID/attendance.csv")
  expect_blocked "yabanci kullanici attendance.csv (katilimci listesi) indirdi" "$CODE"
fi

echo "=== 5) Moderasyon / bildirim IDOR ==="
CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' -X DELETE -H "Authorization: Bearer $T2" "$A/devices/baskasinin-token-degeri")
info "cihaz silme (kendi token'i olmayan) -> HTTP $CODE (idempotent/404 beklenir)"
rm -f "$BODY_FILE"

echo "=== bitti ==="
