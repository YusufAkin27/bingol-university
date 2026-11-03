#!/usr/bin/env bash
# Tek cihaz (tek oturum) kurali icin uctan uca duman testi (mobil istemciler).
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-single-session.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur). Betik arasi: redis flushall gerekmez (tek kayit).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 200)"; FAIL=1; fi; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }

EMAIL="tek$RANDOM$RANDOM@bingol.edu.tr"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"displayName\":\"Tek Oturum\",\"acceptTerms\":true}"
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
curl -s -o /dev/null -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"password\":\"Zk7-Qmv-Lpx92w\"}"

login() { # $1 = client (mobile|web|bos)
  if [ -n "${1:-}" ]; then
    curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"Zk7-Qmv-Lpx92w\",\"client\":\"$1\"}"
  else
    curl -s -X POST -H "$H" $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"Zk7-Qmv-Lpx92w\"}"
  fi
}
me() { curl -s -w '\n%{http_code}' -H "Authorization: Bearer $1" -H "Accept-Language: ${2:-tr}" $A/auth/me; }
status() { me "$@" | tail -1; }
body() { me "$@" | head -n -1; }

echo "== iki mobil cihaz"
D1=$(login mobile); AT1=$(echo "$D1" | field accessToken); RT1=$(echo "$D1" | field refreshToken)
check "cihaz 1 istegi" 200 "$(status "$AT1")"
D2=$(login mobile); AT2=$(echo "$D2" | field accessToken); RT2=$(echo "$D2" | field refreshToken)
check "cihaz 2 hemen sonra istegi" 200 "$(status "$AT2")"
check "cihaz 1 eski token" 401 "$(status "$AT1")"
has "SESSION_REPLACED (tr)" '"code":"SESSION_REPLACED"' "$(body "$AT1")"
has "mesaj en" "another device" "$(body "$AT1" en)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$RT1\"}")
check "cihaz 1 refresh" 401 "$(echo "$R" | tail -1)"
has "refresh SESSION_REPLACED" '"code":"SESSION_REPLACED"' "$R"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/refresh -d '{"refreshToken":"bilinmeyen-token-degeri"}')
has "bilinmeyen refresh genel kod" '"code":"INVALID_REFRESH_TOKEN"' "$R"
R=$(curl -s -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$RT2\"}")
AT2B=$(echo "$R" | field accessToken)
[ -n "$AT2B" ] && echo "  ok   cihaz 2 refresh calisir" || { echo "  FAIL cihaz 2 refresh"; FAIL=1; }
check "cihaz 2 yenilenmis token" 200 "$(status "$AT2B")"

echo "== web ve mobil bagimsiz"
W1=$(login web); WAT=$(echo "$W1" | field accessToken)
check "web girisi mobili kapatmaz" 200 "$(status "$AT2B")"
check "web istegi" 200 "$(status "$WAT")"
W2=$(login); WAT2=$(echo "$W2" | field accessToken)
check "ikinci web (client yok) birincisini kapatmaz" 200 "$(status "$WAT")"
check "ikinci web istegi" 200 "$(status "$WAT2")"
D3=$(login mobile); AT3=$(echo "$D3" | field accessToken)
check "yeni mobil giris" 200 "$(status "$AT3")"
check "web oturumu mobil giristen etkilenmez" 200 "$(status "$WAT")"
check "onceki mobil kapandi" 401 "$(status "$AT2B")"

echo "== refresh idempotansi: kaybolan yanit yeniden denemesi (W1-A T-007)"
W3=$(login web); RTW=$(echo "$W3" | field refreshToken); ATW=$(echo "$W3" | field accessToken)
RA=$(curl -s -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$RTW\"}"); NEWA=$(echo "$RA" | field refreshToken)
RB=$(curl -s -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$RTW\"}"); NEWB=$(echo "$RB" | field refreshToken)
[ -n "$NEWA" ] && check "ayni eski token tekrar: AYNI yeni refresh doner" "$NEWA" "$NEWB" || { echo "  FAIL ilk refresh bos"; FAIL=1; }
RC=$(curl -s -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$NEWA\"}"); NEWC=$(echo "$RC" | field refreshToken)
[ -n "$NEWC" ] && echo "  ok   yeni cift hala calisir (oturumlar kapanmadi)" || { echo "  FAIL yeni refresh"; FAIL=1; }
ATC=$(echo "$RC" | field accessToken)
check "yeniden deneme sonrasi oturum acik" 200 "$(status "$ATC")"

echo "== logout-all FCM cihaz kayitlarini siler (W1-A T-008)"
D5=$(login mobile); AT5=$(echo "$D5" | field accessToken)
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $AT5" $A/devices -d '{"fcmToken":"tok-w1a-smoke-0123456789","platform":"ANDROID"}'
NDEV=$(curl -s -H "Authorization: Bearer $AT5" $A/devices | grep -o '"tokenSuffix":"456789"' | wc -l)
check "cihaz kaydi var" 1 "$NDEV"
curl -s -o /dev/null -X POST -H "Authorization: Bearer $AT5" $A/auth/logout-all
D6=$(login web); AT6=$(echo "$D6" | field accessToken)
NDEV=$(curl -s -H "Authorization: Bearer $AT6" $A/devices | grep -o '"tokenSuffix":"456789"' | wc -l)
check "logout-all sonrasi cihaz kaydi yok" 0 "$NDEV"
AT3=$(login mobile | field accessToken); WAT=$(login web | field accessToken)

echo "== logout-all tum istemcileri kapatir"
curl -s -o /dev/null -X POST -H "Authorization: Bearer $AT3" $A/auth/logout-all
check "mobil" 401 "$(status "$AT3")"
check "web" 401 "$(status "$WAT")"
has "logout-all kodu" '"code":"SESSION_REPLACED"' "$(body "$WAT")"

echo
[ "$FAIL" = 0 ] && echo "TEK OTURUM: TAMAM" || { echo "TEK OTURUM: HATA VAR"; exit 1; }
