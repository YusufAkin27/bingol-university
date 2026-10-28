#!/usr/bin/env bash
# T25: etkinlik sohbet odasi uctan uca testi (calisan compose yigina karsi, tekrar calistirilabilir).
# Kullanim: BASE=http://localhost:8081 ./scripts/event-chat-e2e.sh   (COMPOSE_PROJECT_NAME yigininki ile ayni olmali)
# Onkosul: MAIL_ENABLED=false (kod log'dan okunur), ADMIN_EMAILS=$ADMIN_EMAIL (admin etkinligi dogrudan ACTIVE olur).
# Betikler arasi: docker compose exec -T redis redis-cli flushall (kayit ucu IP basina saatte 10).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
contains() { if printf '%s' "$3" | grep -q -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 ('$2' yok: $3)"; FAIL=1; fi; }
call() {
  local m=$1 p=$2 t=$3 d=${4:-}
  if [ -n "$d" ]; then
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "$H" -H "Authorization: Bearer $t" "$A$p" -d "$d")
  else
    CODE=$(curl -s -o "$TMP" -w '%{http_code}' -X "$m" -H "Authorization: Bearer $t" "$A$p")
  fi
  BODY=$(cat "$TMP")
}
step() { local name=$1 exp=$2; shift 2; call "$@"; check "$name" "$exp" "$CODE"; }
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
echo "== kullanicilar"
TA=$(register "$ADMIN_EMAIL" "Yonetici")
T2=$(register "kat$SFX@bingol.edu.tr" "Katilimci")
T3=$(register "yab$SFX@bingol.edu.tr" "Yabanci")
T4=$(register "ort$SFX@bingol.edu.tr" "OrtakOrg")
[ -n "$TA" ] && [ -n "$T2" ] && [ -n "$T3" ] && [ -n "$T4" ] || { echo "kayit basarisiz"; exit 1; }
ID2=$(curl -s -H "Authorization: Bearer $T2" $A/users/me | idof)
ID4=$(curl -s -H "Authorization: Bearer $T4" $A/users/me | idof)

echo "== etkinlik (organizator = admin)"
step "etkinlik olustur" 201 POST /events "$TA" \
  "{\"title\":\"Sohbet Etkinligi $SFX\",\"startsAt\":\"$(iso '+2 days')\",\"endsAt\":\"$(iso '+2 days 2 hours')\",\"capacity\":10}"
E=$(printf '%s' "$BODY" | idof)

echo "== oda acma yetkisi"
step "katilimci acamaz 403" 403 POST /events/$E/chat-room "$T2"
step "oda yokken uye olmayan GET 404" 404 GET /events/$E/chat-room "$T2"
step "organizator acar" 201 POST /events/$E/chat-room "$TA"
contains "conversationId" '"conversationId":' "$BODY"
CID=$(printf '%s' "$BODY" | grep -o '"conversationId":[0-9]*' | cut -d: -f2)
step "tekrar ac idempotent" 201 POST /events/$E/chat-room "$TA"

echo "== uyelik senkronu"
step "GOING olmadan join 404" 404 POST /events/$E/chat-room/join "$T2"
step "RSVP GOING" 200 PUT /events/$E/rsvp "$T2" '{"status":"GOING"}'
step "GOING -> odada" 200 GET /events/$E/chat-room "$T2"
contains "joined true" '"joined":true' "$BODY"
step "yabanci GET 404 (IDOR)" 404 GET /events/$E/chat-room "$T3"
step "yabanci join 404" 404 POST /events/$E/chat-room/join "$T3"
step "katilimci mesaj gonderir" 201 POST /conversations/$CID/messages "$T2" '{"text":"Merhaba oda","clientId":"ec-1"}'
step "yabanci mesaj gonderemez" 404 POST /conversations/$CID/messages "$T3" '{"text":"icerdeyim","clientId":"ec-2"}'
step "kendi istegiyle ayril" 204 DELETE /events/$E/chat-room/membership "$T2"
step "ayrilinca mesaj 404" 404 POST /conversations/$CID/messages "$T2" '{"text":"x","clientId":"ec-3"}'
step "hala GOING: geri gir" 200 POST /events/$E/chat-room/join "$T2"
step "GOING vazgec" 204 DELETE /events/$E/rsvp "$T2"
step "vazgecen oda GET 404" 404 GET /events/$E/chat-room "$T2"
step "vazgecen join 404" 404 POST /events/$E/chat-room/join "$T2"
step "yeniden GOING -> otomatik giris" 200 PUT /events/$E/rsvp "$T2" '{"status":"GOING"}'
step "tekrar odada" 200 GET /events/$E/chat-room "$T2"

echo "== ortak organizator"
step "ortak organizator ekle" 201 POST /events/$E/co-organizers "$TA" "{\"userId\":$ID4}"
step "ortak org oda GET (yonetebilir)" 200 GET /events/$E/chat-room "$T4"
step "ortak org join" 200 POST /events/$E/chat-room/join "$T4"
contains "ortak org joined" '"joined":true' "$BODY"

echo "== kapat / ac"
step "katilimci kapatamaz 403" 403 PUT /events/$E/chat-room/closed "$T2" '{"closed":true}'
step "organizator kapatir" 200 PUT /events/$E/chat-room/closed "$TA" '{"closed":true}'
contains "closed true" '"closed":true' "$BODY"
step "kapaliyken katilimci GET 404" 404 GET /events/$E/chat-room "$T2"
step "kapaliyken join 409" 409 POST /events/$E/chat-room/join "$T2"
step "organizator acar" 200 PUT /events/$E/chat-room/closed "$TA" '{"closed":false}'
step "acilinca GOING geri eklenir" 200 GET /events/$E/chat-room "$T2"
contains "joined true" '"joined":true' "$BODY"
step "gecersiz govde 400" 400 PUT /events/$E/chat-room/closed "$TA" '{}'

echo "== iptal -> oda hemen kapanir"
step "etkinligi iptal et" 204 DELETE /events/$E "$TA"
step "iptalde katilimci GET 404" 404 GET /events/$E/chat-room "$T2"
step "iptalde acma 409" 409 POST /events/$E/chat-room "$TA"
contains "EVENT_NOT_OPEN" 'EVENT_NOT_OPEN' "$BODY"

echo "== otomatik kapanma (bakim isi): app.chat.room-purge-ms kisa verilirse kontrol edilir; elle SQL ile dogrulama"
echo "   docker compose exec -T postgres psql -U bingol -c \"UPDATE user_event SET starts_at=now()-interval '9 days', ends_at=now()-interval '8 days' WHERE id=<id>\" ; bakim gorevi sonrasi chat_room_link.closed=true olmali"

[ "$FAIL" = 0 ] && echo "TUMU GECTI" || { echo "BAZI ADIMLAR BASARISIZ"; exit 1; }
