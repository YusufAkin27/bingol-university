#!/usr/bin/env bash
# Stitch bildirim tasarimi arka ucu duman testi (NOTIF-BE): kutu kart alanlari + kategori suzgeci, menu tercihi,
# guvenlik bildirimleri (yeni cihaz, sifre degisti), "bu ben degilim". Gercek PostgreSQL + Redis gerekir.
# Kullanim: BASE=http://localhost:8080 ./scripts/smoke-notif-cards.sh
# Onkosul: compose'ta MAIL_ENABLED=false (kod log'dan okunur). FCM kimligi gerekmez (kutu satiri yine yazilir).
set -u
BASE=${BASE:-http://localhost:8080}
A=$BASE/api
H='Content-Type: application/json'
FAIL=0

check() { # ad beklenen gercek
  if [ "$2" = "$3" ]; then echo "  ok   $1 ($3)"; else echo "  FAIL $1 (beklenen $2, gelen $3)"; FAIL=1; fi
}
has() { # ad metin desen
  if echo "$2" | grep -q "$3"; then echo "  ok   $1"; else echo "  FAIL $1 (yok: $3) :: $(echo "$2" | head -c 200)"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

SFX=$RANDOM
EMAIL="notifcard$SFX@bingol.edu.tr"
PW='Zk7-Qmv-Lpx92w'
NEWPW='Yt4-Hnb-Wqe83v'

curl -s -o /dev/null -X POST -H "$H" $A/auth/register -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"displayName\":\"Kart Test\",\"acceptTerms\":true}"
sleep 1
CODE=$(docker compose logs backend 2>&1 | grep "$EMAIL icin" | grep -o 'kodu: [0-9]*' | tail -1 | cut -d' ' -f2)
T=$(curl -s -X POST -H "$H" -H 'X-Device-Id: smoke-device-aaaaaaaa' $A/auth/verify-email \
  -d "{\"email\":\"$EMAIL\",\"code\":\"$CODE\",\"password\":\"$PW\",\"client\":\"mobile\"}" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
[ -n "$T" ] || { echo "kayit basarisiz"; exit 1; }
AU="Authorization: Bearer $T"

echo "== bildirim kutusu: kategori suzgeci ve kart alanlari"
check "kategori=all 200" 200 "$(code -H "$AU" "$A/notifications?category=all")"
check "kategori=social 200" 200 "$(code -H "$AU" "$A/notifications?category=social")"
check "gecersiz kategori 400" 400 "$(code -H "$AU" "$A/notifications?category=bogus")"
MSG=$(curl -s -H "$AU" "$A/notifications?category=messages")
has "messages her zaman bos" "$MSG" '"items":\[\]'

echo "== tercihler: menuDaily varsayilan kapali, guvenlik alt turu listede yok"
P=$(curl -s -H "$AU" $A/notifications/preferences)
has "menuDaily false" "$P" '"menuDaily":false'
has "MENU_DAILY alt turu var" "$P" '"MENU_DAILY"'
has "UNIT_ANNOUNCEMENT alt turu var" "$P" '"UNIT_ANNOUNCEMENT"'
if echo "$P" | grep -q 'SECURITY'; then echo "  FAIL guvenlik alt turu tercihte gorunuyor"; FAIL=1; else echo "  ok   guvenlik alt turu tercihte yok"; fi
P2=$(curl -s -X PUT -H "$AU" -H "$H" $A/notifications/preferences -d '{"menuDaily":true}')
has "menuDaily acildi" "$P2" '"menuDaily":true'

echo "== sifre degisti -> guvenlik bildirimi (kutu)"
CP=$(curl -s -X POST -H "$AU" -H "$H" -H 'X-Device-Id: smoke-device-aaaaaaaa' $A/auth/change-password \
  -d "{\"currentPassword\":\"$PW\",\"newPassword\":\"$NEWPW\"}")
T2=$(echo "$CP" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
[ -n "$T2" ] || { echo "  FAIL sifre degisimi (token yok): $CP"; exit 1; }
AU2="Authorization: Bearer $T2"
SYS=$(curl -s -H "$AU2" "$A/notifications?category=system")
has "SECURITY_PASSWORD karti" "$SYS" '"card":"SECURITY_PASSWORD"'
has "eylem reset_password" "$SYS" '"reset_password"'
has "kanal security" "$SYS" '"channelId":"security"'

echo "== yeni cihazdan giris -> guvenlik bildirimi"
# ayni cihaz: yeni cihaz uyarisi YOK; farkli cihaz: var
curl -s -o /dev/null -X POST -H "$H" -H 'X-Device-Id: smoke-device-aaaaaaaa' -H 'X-Device-Model: Pixel 8' $A/auth/login \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$NEWPW\",\"client\":\"web\"}"
S1=$(curl -s -H "$AU2" "$A/notifications?category=system")
if echo "$S1" | grep -q 'SECURITY_NEW_DEVICE'; then echo "  FAIL bilinen cihazdan yeni cihaz uyarisi geldi"; FAIL=1; else echo "  ok   bilinen cihaz: uyari yok"; fi
LG=$(curl -s -X POST -H "$H" -H 'X-Device-Id: smoke-device-bbbbbbbb' -H 'X-Device-Model: Samsung Galaxy S24' $A/auth/login \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$NEWPW\",\"client\":\"web\"}")
T3=$(echo "$LG" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
AU3="Authorization: Bearer ${T3:-$T2}"
S2=$(curl -s -H "$AU3" "$A/notifications?category=system")
has "SECURITY_NEW_DEVICE karti" "$S2" '"card":"SECURITY_NEW_DEVICE"'
has "eylemler not_me,view" "$S2" '"actions":\["not_me","view"\]'
has "cihaz modeli govdede" "$S2" 'Samsung Galaxy S24'
if echo "$S2" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then echo "  FAIL govdede IP benzeri metin"; FAIL=1; else echo "  ok   IP yok"; fi

echo "== bu ben degilim"
check "girissiz 401" 401 "$(code -X POST $A/security/not-me)"
NM=$(curl -s -X POST -H "$AU3" $A/security/not-me)
has "genel yanit" "$NM" '"resetPasswordRecommended":true'
check "oturum kapandi (me 401)" 401 "$(code -H "$AU3" $A/auth/me)"
check "eski token da kapandi" 401 "$(code -H "$AU2" $A/auth/me)"

echo
if [ "$FAIL" = 0 ]; then echo "smoke-notif-cards: TAMAM"; else echo "smoke-notif-cards: BASARISIZ"; exit 1; fi
