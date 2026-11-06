#!/usr/bin/env bash
# Cok oturum + Cihazlarim (GET/DELETE /api/auth/sessions) icin uctan uca duman testi.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-multi-session.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur) ve AUTH_SINGLE_MOBILE_SESSION tanimsiz/false (varsayilan).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0
PW='Zk7-Qmv-Lpx92w'

check() { if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi; }
has()  { if echo "$3" | grep -qF -- "$2"; then echo "  ok   $1"; else echo "  FAIL $1 (aranan: $2) -> $(echo "$3" | head -c 300)"; FAIL=1; fi; }
hasnt() { if echo "$3" | grep -qF -- "$2"; then echo "  FAIL $1 (bulunmamali: $2)"; FAIL=1; else echo "  ok   $1"; fi; }
field() { grep -o "\"$1\":\"[^\"]*" | head -1 | cut -d'"' -f4; }

EMAIL="coklu$RANDOM$RANDOM@bingol.edu.tr"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"displayName\":\"Coklu Oturum\",\"acceptTerms\":true}"
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
curl -s -o /dev/null -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"password\":\"$PW\"}"

# $1 = cihaz kimligi (X-Device-Id, 8+ karakter), $2 = cihaz adi
login() {
  curl -s -X POST -H "$H" -H "X-Device-Id: $1" -H "X-Device-Name: $2" -H "X-Device-Platform: ANDROID" -H "X-App-Version: 2.2.0" \
    $A/auth/login -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"client\":\"mobile\"}"
}
status() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $1" $A/auth/me; }
sessions() { curl -s -H "Authorization: Bearer $1" $A/auth/sessions; }
nsessions() { sessions "$1" | grep -o '"id":"' | wc -l | tr -d ' '; }

echo "== iki mobil cihaz birbirini kapatmaz"
DA=$(login smokedevA0000001 "Pixel 8"); ATA=$(echo "$DA" | field accessToken); RTA=$(echo "$DA" | field refreshToken)
check "cihaz A istegi" 200 "$(status "$ATA")"
DB=$(login smokedevB0000002 "iPhone 15"); ATB=$(echo "$DB" | field accessToken); RTB=$(echo "$DB" | field refreshToken)
check "cihaz B istegi" 200 "$(status "$ATB")"
check "cihaz A eski token hala gecerli" 200 "$(status "$ATA")"

echo "== Cihazlarim listesi"
LA=$(sessions "$ATA")
check "iki oturum listelenir" 2 "$(nsessions "$ATA")"
has "A listesinde Pixel 8" '"deviceName":"Pixel 8"' "$LA"
has "A listesinde iPhone 15" '"deviceName":"iPhone 15"' "$LA"
has "platform" '"platform":"ANDROID"' "$LA"
has "bu cihaz isaretli" '"current":true' "$LA"
has "IP maskeli (son iki sekizli gizli)" '.*.*"' "$LA"
SIDA=$(echo "$LA" | field id)
LB=$(sessions "$ATB"); SIDB=$(echo "$LB" | field id)
[ -n "$SIDA" ] && [ -n "$SIDB" ] && [ "$SIDA" != "$SIDB" ] && echo "  ok   her cihazin kendi oturum kimligi (current basta)" || { echo "  FAIL oturum kimlikleri ($SIDA / $SIDB)"; FAIL=1; }
check "kimliksiz liste" 401 "$(curl -s -o /dev/null -w '%{http_code}' $A/auth/sessions)"

echo "== bildirimler tum cihazlara: iki cihaz kaydi"
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $ATA" $A/devices -d '{"fcmToken":"tok-multi-A-0123456789aaaaaa","platform":"ANDROID"}'
curl -s -o /dev/null -X POST -H "$H" -H "Authorization: Bearer $ATB" $A/devices -d '{"fcmToken":"tok-multi-B-0123456789bbbbbb","platform":"IOS"}'
DEVS=$(curl -s -H "Authorization: Bearer $ATA" $A/devices)
check "ikinci giris birincinin push kaydini silmedi (2 kayit)" 2 "$(echo "$DEVS" | grep -o '"tokenSuffix"' | wc -l | tr -d ' ')"

echo "== yeni cihaz girisi bildirimi (A'ya)"
NOTIFS=$(curl -s -H "Authorization: Bearer $ATA" "$A/notifications")
has "Yeni cihazdan giris bildirimi" 'Yeni cihazdan giriş' "$NOTIFS"
has "yonlendirme hedefi" 'SECURITY' "$NOTIFS"

echo "== refresh oturum kimligini korur"
R=$(curl -s -X POST -H "$H" -H "X-Device-Id: smokedevB0000002" -H "X-Device-Name: iPhone 15" $A/auth/refresh -d "{\"refreshToken\":\"$RTB\"}")
ATB2=$(echo "$R" | field accessToken); RTB2=$(echo "$R" | field refreshToken)
check "B yenilendi" 200 "$(status "$ATB2")"
SIDB2=$(sessions "$ATB2" | field id)
check "B oturum kimligi degismedi" "$SIDB" "$SIDB2"
check "hala iki oturum" 2 "$(nsessions "$ATB2")"

echo "== B, A cihazindan cikis yapar"
check "A'dan cikis 204" 204 "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -H "Authorization: Bearer $ATB2" $A/auth/sessions/$SIDA)"
check "A access token artik 401" 401 "$(status "$ATA")"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$H" $A/auth/refresh -d "{\"refreshToken\":\"$RTA\"}")
check "A refresh 401" 401 "$(echo "$R" | tail -1)"
has "A refresh SESSION_REPLACED" '"code":"SESSION_REPLACED"' "$R"
check "B etkilenmedi" 200 "$(status "$ATB2")"
check "tek oturum kaldi" 1 "$(nsessions "$ATB2")"
DEVS=$(curl -s -H "Authorization: Bearer $ATB2" $A/devices)
has "B'nin push kaydi duruyor" '"tokenSuffix":"bbbbbb"' "$DEVS"
check "yalniz A'nin push kaydi silindi (1 kayit)" 1 "$(echo "$DEVS" | grep -o '"tokenSuffix"' | wc -l | tr -d ' ')"
R=$(curl -s -w '\n%{http_code}' -X DELETE -H "Authorization: Bearer $ATB2" $A/auth/sessions/$SIDA)
check "ayni oturumu tekrar kapatma 404" 404 "$(echo "$R" | tail -1)"
has "404 kodu" '"code":"SESSION_NOT_FOUND"' "$R"
R=$(curl -s -w '\n%{http_code}' -X DELETE -H "Authorization: Bearer $ATB2" $A/auth/sessions/0123456789abcdef0123456789abcdef)
check "bilinmeyen oturum 404" 404 "$(echo "$R" | tail -1)"

echo "== baska kullanicinin oturumu silinemez"
EMAIL2="coklu$RANDOM$RANDOM@bingol.edu.tr"
curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$EMAIL2\",\"password\":\"$PW\",\"displayName\":\"Baska Kisi\",\"acceptTerms\":true}"
sleep 1
CODE2=$(docker compose logs backend 2>&1 | grep "$EMAIL2 icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
D2=$(curl -s -X POST -H "$H" $A/auth/verify-email -d "{\"email\":\"$EMAIL2\",\"code\":\"$CODE2\",\"password\":\"$PW\",\"client\":\"mobile\"}")
AT2=$(echo "$D2" | field accessToken)
R=$(curl -s -w '\n%{http_code}' -X DELETE -H "Authorization: Bearer $AT2" $A/auth/sessions/$SIDB)
check "baskasinin oturumu 404" 404 "$(echo "$R" | tail -1)"
check "B hala acik" 200 "$(status "$ATB2")"

echo "== normal cikis yalniz o cihazi kapatir"
DC=$(login smokedevC0000003 "Tablet"); ATC=$(echo "$DC" | field accessToken); RTC=$(echo "$DC" | field refreshToken)
check "C acik" 200 "$(status "$ATC")"
curl -s -o /dev/null -X POST -H "$H" $A/auth/logout -d "{\"refreshToken\":\"$RTC\"}"
check "C access token cikistan sonra 401" 401 "$(status "$ATC")"
check "B hala acik" 200 "$(status "$ATB2")"
check "C listeden dustu (1 oturum)" 1 "$(nsessions "$ATB2")"

echo "== logout-all hepsini kapatir"
DD=$(login smokedevD0000004 "Eski Telefon"); ATD=$(echo "$DD" | field accessToken)
check "iki oturum" 2 "$(nsessions "$ATD")"
curl -s -o /dev/null -X POST -H "Authorization: Bearer $ATD" $A/auth/logout-all
check "B kapandi" 401 "$(status "$ATB2")"
check "D kapandi" 401 "$(status "$ATD")"
ATE=$(login smokedevE0000005 "Yeni Telefon" | field accessToken)
check "logout-all sonrasi yeni giris listesi 1" 1 "$(nsessions "$ATE")"

echo
[ "$FAIL" = 0 ] && echo "COKLU OTURUM: TAMAM" || { echo "COKLU OTURUM: HATA VAR"; exit 1; }
