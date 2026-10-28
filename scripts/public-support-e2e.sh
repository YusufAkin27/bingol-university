#!/usr/bin/env bash
# T27: herkese acik destek talebi uctan uca betigi (hesapsiz form -> e-posta kodu -> dogrulama -> yonetim -> yanit -> durum baglantisi).
# Kullanim: BASE=http://localhost:8080 ADMIN_EMAIL=boss@bingol.edu.tr ./scripts/public-support-e2e.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod/baglanti `docker compose logs backend` satirindan okunur), ADMIN_EMAILS=$ADMIN_EMAIL.
# Betik oncesi/sonrasi: docker compose exec -T redis redis-cli flushall (IP basina saatte 5 talep siniri vardir).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
P=$A/public/support
ADMIN_EMAIL=${ADMIN_EMAIL:-boss@bingol.edu.tr}
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 250)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamaliydi: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
logs() { docker compose logs backend 2>&1; }

# kayit + dogrulama -> access token (yonetici JWT'si yanit yazari olarak gerekir)
register() {
  curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$1\",\"password\":\"Sifre1234\",\"displayName\":\"$2\",\"acceptTerms\":true,\"language\":\"tr\"}"
  sleep 1
  local c t
  c=$(logs | grep "$1 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
  t=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$1\",\"code\":\"$c\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  if [ -z "$t" ]; then
    t=$(curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$1\",\"password\":\"Sifre1234\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
  fi
  echo "$t"
}
# e-postaya giden son dogrulama kodu (6 hane)
last_code() { logs | grep "$1 icin e-posta" | grep -iE 'verification code|dogrulama kodunuz|kodunuz' | tail -1 | grep -oE ': [0-9]{6}' | tail -1 | tr -d ': '; }
# e-postadaki son durum baglantisi anahtari
last_token() { logs | grep "$1 icin e-posta" | grep -o 'support/track?token=[A-Za-z0-9_-]*' | tail -1 | cut -d= -f2; }
submit_body() { # email lang-independent govde; $2 honeypot, $3 elapsedMs, $4 mesaj
  echo "{\"name\":\"Ali Veli\",\"email\":\"$1\",\"category\":\"TECHNICAL\",\"message\":\"$4\",\"website\":\"$2\",\"elapsedMs\":$3}"
}

SFX=$RANDOM
EM="pub$SFX@example.com"
MSG="Uygulama acilmiyor $SFX, yardim eder misiniz?"

echo "== yonetici"
TA=$(register "$ADMIN_EMAIL" "Admin")
[ -n "$TA" ] || { echo "yonetici token yok"; exit 1; }
AAD="Authorization: Bearer $TA"

echo "== mevcut girisli uc bozulmadi"
C0=$(code $A/support/tickets); [ "$C0" = "401" ] || [ "$C0" = "403" ] && C0=denied
check "girissiz /support/tickets reddedilir" denied "$C0"
check "girissiz /public/support/track gecersiz govde 400" 400 "$(code -X POST -H "$H" $P/track -d '{}')"

echo "== bal kabagi ve cok hizli gonderim sessizce elenir"
check "honeypot -> genel 202" 202 "$(code -X POST -H "$H" $P/tickets -d "$(submit_body "hp$SFX@example.com" 'http://spam' 9000 "$MSG")")"
check "cok hizli -> genel 202" 202 "$(code -X POST -H "$H" $P/tickets -d "$(submit_body "fast$SFX@example.com" '' 300 "$MSG")")"
sleep 1
check "honeypot icin kod/e-posta uretilmedi" "" "$(last_code "hp$SFX@example.com")"
check "hizli gonderim icin kod uretilmedi" "" "$(last_code "fast$SFX@example.com")"

echo "== istemci hatalari"
check "gecersiz e-posta" 400 "$(code -X POST -H "$H" $P/tickets -d "$(submit_body 'not-an-email' '' 9000 "$MSG")")"
check "kisa mesaj" 400 "$(code -X POST -H "$H" $P/tickets -d "$(submit_body "$EM" '' 9000 'kisa')")"

echo "== gonderim (Accept-Language: en) -> dogrulanmamis talep"
R=$(curl -s -w ' %{http_code}' -X POST -H "$H" -H 'Accept-Language: en' $P/tickets -d "$(submit_body "$EM" '' 9000 "$MSG")")
has "202 CODE_SENT" "CODE_SENT" "$R"
sleep 1
CODE=$(last_code "$EM")
[ -n "$CODE" ] && echo "  ok   kod e-postaya gitti (log)" || { echo "  FAIL kod logda yok"; FAIL=1; }
has "e-posta konusu EN" "Support request verification code" "$(logs | grep "$EM icin e-posta" | tail -1)"
has "kod e-postasi EN" "verification code" "$(logs | grep "$EM icin e-posta" | tail -1)"

echo "== dogrulanmamis talep yonetim listesinde YOK"
LIST=$(curl -s -H "$AAD" "$A/admin/support/tickets?size=100")
hasnt "admin listesinde gorunmez" "$EM" "$LIST"

echo "== yanlis kod / dogru kod"
check "yanlis kod 400" 400 "$(code -X POST -H "$H" $P/tickets/verify -d "{\"email\":\"$EM\",\"code\":\"000000\"}")"
check "bilinmeyen e-posta ayni 400" 400 "$(code -X POST -H "$H" $P/tickets/verify -d "{\"email\":\"nobody$SFX@example.com\",\"code\":\"123456\"}")"
V=$(curl -s -X POST -H "$H" $P/tickets/verify -d "{\"email\":\"$EM\",\"code\":\"$CODE\"}")
has "dogru kod: trackToken" '"trackToken"' "$V"
TID=$(echo "$V" | grep -o '"ticketId":[0-9]*' | cut -d: -f2)
TOKEN=$(echo "$V" | grep -o '"trackToken":"[^"]*' | cut -d'"' -f4)
check "token uzunlugu >= 32" 1 "$([ ${#TOKEN} -ge 32 ] && echo 1 || echo 0)"
check "kod tek kullanimlik (tekrar 400)" 400 "$(code -X POST -H "$H" $P/tickets/verify -d "{\"email\":\"$EM\",\"code\":\"$CODE\"}")"
sleep 1
has "alindi e-postasi baglanti icerir" "support/track?token=" "$(logs | grep "$EM icin e-posta" | tail -1)"

echo "== yonetim listesi: herkese acik etiketi"
LIST=$(curl -s -H "$AAD" "$A/admin/support/tickets?size=100")
has "talep listede" "\"id\":$TID" "$LIST"
has "publicTicket etiketi" '"publicTicket":true' "$LIST"
has "publicOnly filtresi" "\"id\":$TID" "$(curl -s -H "$AAD" "$A/admin/support/tickets?publicOnly=true&size=100")"
D=$(curl -s -H "$AAD" "$A/admin/support/tickets/$TID")
has "admin detay: iletisim e-postasi" "$EM" "$D"

echo "== durum baglantisi"
T=$(curl -s -X POST -H "$H" $P/track -d "{\"token\":\"$TOKEN\"}")
has "kullanici kendi mesajini gorur" "Uygulama acilmiyor" "$T"
check "yanlis token 404" 404 "$(code -X POST -H "$H" $P/track -d '{"token":"yanlis-token-yanlis-token-yanlis-token"}')"

echo "== yonetici yaniti -> e-posta"
RP=$(curl -s -X POST -H "$H" -H "$AAD" $A/admin/support/tickets/$TID/reply -d '{"text":"Uygulamayi guncelleyin <b>lutfen</b>."}')
has "emailStatus SENT" '"emailStatus":"SENT"' "$RP"
sleep 1
RL=$(logs | grep "$EM icin e-posta" | tail -1)
has "yanit e-postasi konusu" "Your support request #$TID" "$RL"
has "yanit metni e-postada" "Uygulamayi guncelleyin" "$RL"
TOKEN2=$(last_token "$EM")
[ -n "$TOKEN2" ] && [ "$TOKEN2" != "$TOKEN" ] && echo "  ok   yanit e-postasinda yeni baglanti" || { echo "  FAIL yeni baglanti yok"; FAIL=1; }
T=$(curl -s -X POST -H "$H" $P/track -d "{\"token\":\"$TOKEN2\"}")
has "yeni baglanti yaniti gosterir" "Uygulamayi guncelleyin" "$T"
has "durum ANSWERED" '"status":"ANSWERED"' "$T"
has "eski baglanti hala gecerli" "Uygulama acilmiyor" "$(curl -s -X POST -H "$H" $P/track -d "{\"token\":\"$TOKEN\"}")"

echo "== kullanici ek mesaj -> talep tekrar acik"
M=$(curl -s -X POST -H "$H" $P/track/messages -d "{\"token\":\"$TOKEN\",\"text\":\"Tesekkurler, ek bilgi: Android 14\"}")
has "mesaj eklendi" "Android 14" "$M"
has "durum OPEN" '"status":"OPEN"' "$M"
has "admin kuyrugunda yeni mesaj" "Android 14" "$(curl -s -H "$AAD" "$A/admin/support/tickets/$TID")"

echo "== kapali talep ek mesajla yeniden acilir"
check "admin kapatir" 204 "$(code -X POST -H "$AAD" $A/admin/support/tickets/$TID/close)"
M=$(curl -s -X POST -H "$H" $P/track/messages -d "{\"token\":\"$TOKEN\",\"text\":\"Tekrar acar misiniz?\"}")
has "yeniden OPEN" '"status":"OPEN"' "$M"

echo "== hiz siniri (IP basina saatte 5 talep)"
GOT429=0
for i in 1 2 3 4 5 6 7; do
  c=$(code -X POST -H "$H" $P/tickets -d "$(submit_body "rl$SFX$i@example.com" '' 9000 "$MSG")")
  [ "$c" = "429" ] && GOT429=1
done
check "sinir asilinca 429" 1 "$GOT429"

echo
if [ "$FAIL" = "0" ]; then echo "TUM KONTROLLER GECTI"; else echo "BAZI KONTROLLER BASARISIZ"; exit 1; fi
